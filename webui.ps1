#WebUI Script

function WebUi {
    
    $box1 = [string][char]9608

    $box2 = [string][char]9617

    $barLength = 30

    Clear-Host

    Write-Host " Trakt: "

    $Job = Get-Job -Name TraktScraper

    $new = $Job.ChildJobs.Output | Out-String

    $TraktScraperOutput = $new -split(";;;;;")

    $TraktScraperOutput[-2]            

    $real_debrid_token = $settings.real_debrid_token

    $Header = @{
        "authorization" = "Bearer $real_debrid_token"
    }

    $Get_Torrents = @{
         Method = "GET"
         Uri = "https://api.real-debrid.com/rest/1.0/torrents"
         Headers = $Header
    }
            
    $debridresponse = Invoke-RestMethod @Get_Torrents -WebSession $realdebridsession

    if($debridresponse -ne $null){

          Write-Host "Debrid:"

                foreach($download in $debridresponse) {

                    if($download.status -eq "queued") {
                        $completedSize = 0
                        $remainingSize = 1
                        $percentdownload = "0 %"
                        $name = $download.filename
                        $speed = 0
                        $gb = [math]::Round($download.bytes / 1000000000,2)
                        $download | Add-Member -type NoteProperty -name completedSize -Value $completedSize  -Force
                        $download | Add-Member -type NoteProperty -name remainingSize -Value $remainingSize  -Force
                        $download | Add-Member -type NoteProperty -name percentdownload -Value $percentdownload  -Force
                        $download | Add-Member -type NoteProperty -name name -Value $name  -Force
                        $download | Add-Member -type NoteProperty -name speed -Value $speed  -Force
                        $download | Add-Member -type NoteProperty -name gb -Value $gb  -Force
        
                        
                    }else{ 
                        $completedSize = [math]::Round($download.bytes / 1000000000 * $download.progress / 100,2)
                        $remainingSize = [math]::Round($download.bytes / 1000000000,2) - $completedSize
                        $percentdownload = "{0:P2}" -f ($download.progress/100)
                        $name = $download.filename
                        $speed = [math]::Round($download.speed / 1000000,1)
                        $gb = [math]::Round($download.bytes / 1000000000,2)
                        $download | Add-Member -type NoteProperty -name completedSize -Value $completedSize  -Force
                        $download | Add-Member -type NoteProperty -name remainingSize -Value $remainingSize  -Force
                        $download | Add-Member -type NoteProperty -name percentdownload -Value $percentdownload  -Force
                        $download | Add-Member -type NoteProperty -name name -Value $name  -Force
                        $download | Add-Member -type NoteProperty -name speed -Value $speed  -Force
                        $download | Add-Member -type NoteProperty -name gb -Value $gb  -Force
                    }
                }

                $debridresponse | Format-Table  @{
                    Label = "torrent"
                    Expression = {-join($_.name.Substring(0,27), "...")}
                    Width = 30
                }, @{
                    Label = "size"
                    Expression = {-join($_.gb, " GB")}
                    Width = 10
                }, @{
                    Label = "seeders"
                    Expression = {$_.seeders}
                    Width = 10
                }, @{
                    Label = "speed"
                    Expression = {-join($_.speed, " MB/s")}
                    Width = 10
                }, @{
                    Label = "percent"
                    Expression = {$_.percentdownload}
                    Width = 10
                }, @{
                    Label = "progress"
                    Expression = {$e = [char]27;"$e[92m$("$box1"*(($_.progress/100) * $barLength))$e[97m$("$box2"*((1-$_.progress/100) * $barLength))${e}[0m"}
                    Width = 45
                }
            }
                        

            $downloads = @()

            $active = Invoke-WebRequest -Headers @{"Content-type"="application/json"} -Method Post -Body "{`"jsonrpc`":`"2.0`",`"id`":`"qwer`",`"method`":`"aria2.tellActive`",`"params`":[`"token:premiumizer`"]}" http://192.168.0.23:6800/jsonrpc -SessionVariable aria2csession | ConvertFrom-Json

            $waiting = Invoke-WebRequest -Headers @{"Content-type"="application/json"} -Method Post -Body "{`"jsonrpc`":`"2.0`",`"id`":`"qwer`",`"method`":`"aria2.tellWaiting`",`"params`":[`"token:premiumizer`",-1,50]}" http://192.168.0.23:6800/jsonrpc -SessionVariable aria2csession | ConvertFrom-Json

            $stopped = Invoke-WebRequest -Headers @{"Content-type"="application/json"} -Method Post -Body "{`"jsonrpc`":`"2.0`",`"id`":`"qwer`",`"method`":`"aria2.tellStopped`",`"params`":[`"token:premiumizer`",-1,50]}" http://192.168.0.23:6800/jsonrpc -SessionVariable aria2csession | ConvertFrom-Json

            $downloads += $waiting.result

            $downloads += $active.result

            $downloads += $stopped.result
            
            if($downloads -ne $null){

                Write-Host

                Write-Host "Aria2c: "

                foreach($download in $downloads) {

                    if($download.totalLength -eq 0) {
                        $completedSize = 0
                        $remainingSize = 1
                        $percentdownload = "{0:P2}" -f $CompletedSize
                        $name = $download.dir.Split("\")[-1]
                        $speed = 0
                        $gb = "?"
                        $download | Add-Member -type NoteProperty -name completedSize -Value $completedSize  -Force
                        $download | Add-Member -type NoteProperty -name remainingSize -Value $remainingSize  -Force
                        $download | Add-Member -type NoteProperty -name percentdownload -Value $percentdownload  -Force
                        $download | Add-Member -type NoteProperty -name name -Value $name  -Force
                        $download | Add-Member -type NoteProperty -name speed -Value $speed  -Force
                        $download | Add-Member -type NoteProperty -name gb -Value $gb  -Force
        
                        
                    }else{ 
                        $completedSize = $download.completedLength / $download.totalLength
                        $remainingSize = ($download.totalLength -$download.completedLength)/$download.totalLength 
                        $percentdownload = "{0:P2}" -f $CompletedSize
                        $name = $download.files.path.Split("/")[-1]
                        $speed = [math]::Round($download.downloadSpeed / 1000000,1)
                        $gb = [math]::Round($download.totalLength / 1000000000,2)
                        $download | Add-Member -type NoteProperty -name completedSize -Value $completedSize  -Force
                        $download | Add-Member -type NoteProperty -name remainingSize -Value $remainingSize  -Force
                        $download | Add-Member -type NoteProperty -name percentdownload -Value $percentdownload  -Force
                        $download | Add-Member -type NoteProperty -name name -Value $name  -Force
                        $download | Add-Member -type NoteProperty -name speed -Value $speed  -Force
                        $download | Add-Member -type NoteProperty -name gb -Value $gb  -Force
                    }
                }
            
                $downloads | Format-Table  @{
                    Label = "file"
                    Expression = {-join($_.name.Substring(0,27), "...")}
                    Width = 30
                }, @{
                    Label = "size"
                    Expression = {-join($_.gb, " GB")}
                    Width = 10
                }, @{
                    Label = "speed"
                    Expression = {-join($_.speed, " MB/s")}
                    Width = 10
                }, @{
                    Label = "percent"
                    Expression = {$_.percentdownload}
                    Width = 10
                }, @{
                    Label = "progress"
                    Expression = {$e = [char]27;"$e[92m$("$box1"*($_.completedSize * $barLength))$e[97m$("$box2"*($_.remainingSize * $barLength))${e}[0m"}
                    Width = 45
                }
            
            }

            Write-Host

            Write-Host "Disks: "

            $diskData = gwmi win32_logicaldisk -ComputerName $env:COMPUTERNAME -Filter "DriveType = 3"
            $charCount = "="*75 
            $usedSpace = " "*20 
            $freeSpace = " "*10 
  
            foreach($disk in $diskData) { 
                
                $usedSpaceSize = ($disk.size -$disk.FreeSpace)/$disk.Size 
                $freeSpaceDisk =  $disk.FreeSpace/$disk.Size 
                $percentDisk = "{0:P2}" -f $freeSpaceDisk
                $gb = [math]::Round($disk.FreeSpace / 1000000000)
                $id = $disk.DeviceID

                $disk | Add-Member -type NoteProperty -name usedSpaceSize -Value $usedSpaceSize  -Force
                $disk | Add-Member -type NoteProperty -name freeSpaceDisk -Value $freeSpaceDisk  -Force
                $disk | Add-Member -type NoteProperty -name percentDisk -Value $percentDisk  -Force
                $disk | Add-Member -type NoteProperty -name gb -Value $gb  -Force
                $disk | Add-Member -type NoteProperty -name id -Value $id  -Force
            } 
            
            $diskData | Format-Table  @{
                    Label = "drive"
                    Expression = {$_.id}
                }, @{
                    Label = "free"
                    Expression = {-join($_.percentDisk, "  ", $_.gb, " GB")}
                }, @{
                    Label = "size"
                    Expression = {$e = [char]27;"$e[92m$("$box1"*($_.usedSpaceSize * $barLength))$e[97m$("$box2"*($_.freeSpaceDisk * $barLength))${e}[0m"}
                }
            
            Write-Host

            Write-Host "Log:"

            $TraktScraperOutput[-1]
            
            Write-Host    

}