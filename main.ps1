. .\setup.ps1

. .\tohtml.ps1

. .\webui.ps1

$traktscraper = {

    $settings = $args[0]

    $trakt_client_id = $settings.trakt_client_id
    $trakt_client_secret = $settings.trakt_client_secret
    $trakt_access_token = $settings.trakt_access_token
    $real_debrid_token = $settings.real_debrid_token
    $premiumize_api_key = $settings.premiumize_api_key
    $path_to_downloads = $settings.path_to_downloads

    Set-Location $args[1]

    function main {
    
        . .\trakt.ps1

        . .\download.ps1

        while(1) {
    
            $trakt = trakt $settings

            Clear-Host

            Write-Output ";;;;;"

            Write-Output $trakt  | Where-Object {$_.next_season -ne $null -or $_.download_type -ne $null} |  Sort-Object -Property release_wait | Format-Table -Property @{ e='title'; width = 30 },@{ e='collected'; width = 15 },@{ e='next'; width = 15 },@{ e='download_type'; width = 15 },@{ e='release_wait'; width = 15 }
            
            Write-Output ";;;;;"

            if($trakt.download_type.Contains("episode") -or $trakt.download_type.Contains("season")){

                Sleep 10

            }else{

                Sleep 60

            }
        
            download $trakt $settings

        }
            
    }

    main

} 

$unrar = {   
    
    $path_to_winrar = -join($args[0].path_to_winrar, "unrar.exe")
    
    while(1){
        
        Write-Output "Running..."

        $stopped = Invoke-WebRequest -Headers @{"Content-type"="application/json"} -Method Post -Body "{`"jsonrpc`":`"2.0`",`"id`":`"qwer`",`"method`":`"aria2.tellStopped`",`"params`":[`"token:premiumizer`",-1,50]}" http://192.168.0.23:6800/jsonrpc -SessionVariable aria2csession | ConvertFrom-Json

        $finished = $stopped.result

        if($finished -ne $null) {

            foreach($download in $finished){

                if($download.files.path.Contains(".rar")){
        
                    $dirfile = $download.files.path

                    $dirdestination = $download.dir

                    if(Test-Path $dirfile -PathType Leaf){

                        Write-Output "Testing File: " $dirfile
                             
                        $log = [string](&$path_to_winrar t $dirfile)

                        if($log.Contains("All OK")){

                            Write-Output "Unrar: " $dirfile
                
                            $log = [string](&$path_to_winrar x -y -o- $dirfile $dirdestination)

                            if($log.Contains("All OK")){
                                
                                Write-Output "Deleting files: " $dirdestination

                                $dirremove = -join($dirdestination, "\*.rar")
                
                                Remove-Item $dirremove

                            }
                        }
                    }

                }

            }
        }

    Sleep 10

    }

}

if(-Not (Test-Path .\parameters.xml -PathType Leaf)) {

    setup

}else {

    $settings = Import-Clixml -Path .\parameters.xml

    $env:Path += $settings.path_to_aria2c

    Start-Job -Name Aria2c -ScriptBlock {
    
        aria2c --disable-ipv6=true --enable-rpc --rpc-allow-origin-all --rpc-listen-all --rpc-listen-port=6800 --rpc-secret=premiumizer --max-connection-per-server=16 --file-allocation=none --disk-cache=0 --max-concurrent-downloads=1 --continue=true
    
    }

    Start-Job -Name UnRar -ScriptBlock $unrar -ArgumentList $settings

    Start-Job -Name TraktScraper -ScriptBlock $traktscraper -ArgumentList $settings, $pwd

    $http = [System.Net.HttpListener]::new()

    $http.Prefixes.Add("http://+:8008/")

    $http.Start()

    while ($http.IsListening) {
        
        $context = $http.GetContext()
        
        if ($context.Request.HttpMethod -eq 'GET') {
            
            WebUI

            [string]$html = tohtml -Raw -Encoding utf8 #Get-Content -Path .\out.html                              

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response

        }
        
    }

}