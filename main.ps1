#main script
 #
 
 . .\setup.ps1

. .\tohtml.ps1

. .\webui.ps1

. .\unrar.ps1

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

            if($trakt.download_type.Contains("show")){

                Sleep 10

            }else{

                Sleep 60

            }
        
            download $trakt $settings

        }
            
    }

    main

} 

if(-Not (Test-Path .\parameters.xml -PathType Leaf)) {

    setup

}else {
    
    if(-Not (Test-Path .\exceptions.xml -PathType Leaf)) {

        $exceptions = @{
            
            'The Tonight Show Starring Jimmy Fallon' = '$show.query = @(-join("Jimmy.Fallon",".",$release_year,".",$release_month,".",$release_day))'

            'Jimmy Kimmel Live' = '$show.query = @(-join("Jimmy.Kimmel",".",$release_year,".",$release_month,".",$release_day))'
            
            'Cosmos' = '$show.query = @(-join("Cosmos",".",$season_title))'

        }
        
        $exceptions | Export-Clixml -Path .\exceptions.xml
    
    }

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

            #unrarlog

            $unrarjob = Get-Job -Name UnRar

            $unrarjob_output = $unrarjob.ChildJobs.Output | Out-String

            $unrarjob_output = $unrarjob_output -split(";;;;;")

            $unrarjob_output[-1]

            Write-Host

            [string]$html = tohtml -Raw -Encoding utf8 #Get-Content -Path .\out.html                              

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response

        }
        
    }

}
