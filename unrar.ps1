$unrar = {   
    
    $path_to_winrar = -join($args[0].path_to_winrar, "unrar.exe")
    
    while(1){
        
        Write-Output ";;;;;"

        Write-Output "(unrar) checking for downloaded archives"

        $stopped = Invoke-WebRequest -Headers @{"Content-type"="application/json"} -Method Post -Body "{`"jsonrpc`":`"2.0`",`"id`":`"qwer`",`"method`":`"aria2.tellStopped`",`"params`":[`"token:premiumizer`",-1,50]}" http://192.168.0.23:6800/jsonrpc -SessionVariable aria2csession | ConvertFrom-Json

        $finished = $stopped.result

        if($finished -ne $null) {

            foreach($download in $finished){

                if($download.files.path.Contains(".rar")){
        
                    $dirfile = $download.files.path

                    $dirdestination = $download.dir

                    if(Test-Path -LiteralPath $dirfile -PathType Leaf){
                        
                        $text = -join("(unrar) testing archive: ", $dirfile)

                        Write-Output $text
                             
                        $log = [string](&$path_to_winrar t $dirfile)

                        if($log.Contains("All OK")){
                            
                            $text = -join("(unrar) extracting archive: ", $dirfile)

                            Write-Output $text
                
                            $log = [string](&$path_to_winrar x -y -o- $dirfile $dirdestination)

                            if($log.Contains("All OK")){

                                $text = -join("(unrar) deleting archives in: ", $dirdestination)
                                
                                Write-Output $text

                                $dirremove = -join($dirdestination, "\*.rar")
                
                                Remove-Item -LiteralPath $dirremove

                            }
                        }
                    }

                }

            }
        }

    Sleep 30

    }

}