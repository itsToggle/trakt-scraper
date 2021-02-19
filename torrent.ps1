﻿# Torrent Download Script


function torrent($trakt, $settings) {
    
    . .\scraper.ps1

    . .\sync.ps1

    $trakt_client_id = $settings.trakt_client_id
    $trakt_client_secret = $settings.trakt_client_secret
    $trakt_access_token = $settings.trakt_access_token
    $real_debrid_token = $settings.real_debrid_token
    $premiumize_api_key = $settings.premiumize_api_key
    $path_to_downloads = $settings.path_to_downloads

    Foreach ($object in $trakt) {

                if ($object.query -ne $null -and $object.status -le 1) { 

                    [int]$retries = 0
            
                    do { 
                
                        $retries++

                        $query = $object.query
                        
                        $query_fallback = $object.query


                        if($object.download_type -eq "episode" -and $retries -eq 5) {
                            
                            $retries = 0
                            
                            $object.download_type = "season"
                             
                            $season = "{0:d2}" -f $object.next_season

                            $year = $object.year

                            $title = $object.title -replace('\s','.') ` -replace(':','') ` -replace('`','') ` -replace("'",'') ` -replace('´','')

                            $object.query = -join($title,".S",$season)

                        }

                        if($object.download_type -eq "episode") {
                            
                            $season = "{0:d2}" -f $object.next_season

                            $episode = "{0:d2}" -f $object.next_episode

                            $year = $object.year

                            $title = $object.title -replace('\s','.') ` -replace(':','') ` -replace('`','') ` -replace("'",'') ` -replace('´','')
                    
                            $query_fallback = -join($title,".",$year,".S",$season,"E",$episode)                  
                            
                        
                        }elseif($object.download_type -eq "season") {
                            
                            $season = "{0:d2}" -f $object.next_season

                            $year = $object.year

                            $title = $object.title -replace('\s','.') ` -replace(':','') ` -replace('`','') ` -replace("'",'') ` -replace('´','')
                    
                            $query_fallback = -join($title,".",$year,".S",$season)                  
                            
                        }

                        $scraper = new-object system.collections.arraylist 

                        $items = scrape_torrents $object

                        Foreach ($item in $items) {
                            
                            $title = $item.title
                            
                            $quality = [regex]::matches($title, "(1080)|(720)|(2160)").value 
                            
                            $download = $item.download
                            
                            $seeders = $item.seeders
                            
                            $hash = [regex]::matches($download, "(?<=btih:).*?(?=&)").value
                            
                            if (([regex]::matches($title, "($query\.)", "IgnoreCase").value -or [regex]::matches($title, "($query_fallback\.)", "IgnoreCase").value)  -And -Not [regex]::matches($title, "(REMUX)|(\.3D\.)", "IgnoreCase").value) {
                                
                                $files = @()
                                
                                $Header = @{
                                    "authorization" = "Bearer $real_debrid_token"
                                }

                                $Post_Magnet = @{
                                    Method = "POST"
                                    Uri =  "https://api.real-debrid.com/rest/1.0/torrents/addMagnet"
                                    Headers = $Header
                                    Body = @{ magnet = $download }
                                }

                                $response = Invoke-RestMethod @Post_Magnet -WebSession $realdebridsession

                                $torrent_id = $response.id

                                $Get_Torrent_Info = @{
                                    Method = "GET"
                                    Uri = "https://api.real-debrid.com/rest/1.0/torrents/info/$torrent_id"
                                    Headers = $Header
                                }

                                $response = Invoke-RestMethod @Get_Torrent_Info -WebSession $realdebridsession

                                $torrent_status = $response.status

                                $retries = 0

                                sleep 1

                                while( $torrent_status -eq "magnet_conversion" -and $retries -lt 1){
                                    $retries++
                                    Sleep 10
                                    $response = Invoke-RestMethod @Get_Torrent_Info
                                    $torrent_status = $response.status
                                }

                                $Delete_Torrent = @{
                                    Method = "DELETE"
                                    Uri =  "https://api.real-debrid.com/rest/1.0/torrents/delete/$torrent_id"
                                    Headers = @{"authorization" = "Bearer $real_debrid_token"}
                                }
                    
                                $piss = Invoke-RestMethod @Delete_Torrent -WebSession $realdebridsession

                                $filestext = [regex]::matches($response.files.path, "(S[0-9].E[0-9].)", "IgnoreCase").value

                                foreach($file in $filestext){
    
                                    $season = [int][regex]::matches($file, "(?<=S)..?(?=E)", "IgnoreCase").value
                                    $episode = [int][regex]::matches($file, "(?<=E)..?", "IgnoreCase").value
                                    $files += new-object psobject -property @{season=$season;episode=$episode}
                                }
                                if($object.download_type -eq "movie") {

                                    $scraper += new-object psobject -property @{title=$title;quality=[int]$quality;category=$category;magnets=$download;seeders=[int]$seeders;imdb=$imdb;hashes=$hash;files=$files}

                                }elseif($files.season.Contains($object.next_season) -and $files.episode.Contains($object.next_episode)){

                                    $scraper += new-object psobject -property @{title=$title;quality=[int]$quality;category=$category;magnets=$download;seeders=[int]$seeders;imdb=$imdb;hashes=$hash;files=$files}
                                
                                }

                                Sleep 1

                            }
                        }

                        $object.scraper += @( $scraper | Sort-Object -Property quality,seeders -Descending )

                        $object.status = 2

                        Sleep 5


                    } while ($object.scraper.hashes -eq $null -and $retries -le 5)


                }

            }
 
        #check debrid services for scraped magnets. If magnet is cached, direct download. Premiumize prefered for cached downloads.

            Foreach ($object in $trakt) {

                $object | Add-Member -type NoteProperty -name service -Value $null -Force

                $object | Add-Member -type NoteProperty -name files -Value $null -Force
            
                if($object.scraper.hashes -ne $null -and $object.status -le 2) {

                    $object.status = 3
                
                    Foreach ($item in $object.scraper) {

                        $object.files = $item.files
                
                        $hashstring = $item.hashes

                        $magnet = $item.magnets
  
                        $Header = @{
                            "authorization" = "Bearer $real_debrid_token"
                        }

                        $Post_Hash = @{
                            Method = "GET"
                            Uri =  "https://api.real-debrid.com/rest/1.0/torrents/instantAvailability/$hashstring"
                            Headers = $Header
                        }

                        $body_pm = -join("https://www.premiumize.me/api/cache/check?items%5B%5D=",$magnet,"&apikey=",$premiumize_api_key)

                        $check_cache_RD = Invoke-WebRequest @Post_Hash -WebSession $realdebridsession
                
                        $check_cache_PM = Invoke-RestMethod -Uri $body_pm -Method Get -SessionVariable premiumizesession

                        

                        if($check_cache_PM.response){
                    
                            $object.service = "PM"
							
							$uri_pm = -join("https://www.premiumize.me/api/transfer/directdl?apikey=",$premiumize_api_key)
							
                            $get_link = Invoke-RestMethod -Uri $uri_pm -Method Post -Body @{src=$magnet} -H @{"Content-Type" = "application/x-www-form-urlencoded"}  -SessionVariable premiumizesession

                            $torrent_name = $check_cache_PM.filename

                            $type = $object.type

                            Foreach ($download in $get_link.content.link){
                        
                                $shit=Invoke-WebRequest -Headers @{"Content-type"="application/json"} -Method Post -Body "{`"jsonrpc`":`"2.0`",`"id`":`"qwer`",`"method`":`"aria2.addUri`",`"params`":[`"token:premiumizer`",[`"$download`"], {`"dir`": `"$path_to_downloads\$type\\$torrent_name`"}]}" http://192.168.0.23:6800/jsonrpc -SessionVariable aria2csession

                                Sleep 2

                            }

                            sync $object $settings

                            $count++

                            $count++

                            $countPM++

                            break

                        }elseif([int]$check_cache_RD.RawContentLength -gt [int]"60") {

                            $object.service = "RD"
 
                            $object.cached = $item.magnets

                            $hashes = $item.hashes

                            $object.hashed = $hashes

                            break

                        }
               
                        Sleep 5
                    }

                    Sleep 5

                }

                #Add selected Magnet to RD

                if($object.scraper.magnets -ne $null -and $object.status -le 3 -and $object.service -eq "RD") {
            
                    $magnet = $object.scraper.magnets[0]

                    if($object.cached -ne $null) {
                        
                        $magnet = $object.cached
                    }
    
                    $Header = @{
                        "authorization" = "Bearer $real_debrid_token"
                    }

                    $Post_Magnet = @{
                        Method = "POST"
                        Uri =  "https://api.real-debrid.com/rest/1.0/torrents/addMagnet"
                        Headers = $Header
                        Body = @{ magnet = $magnet }
                    }

                    $response = Invoke-RestMethod @Post_Magnet -WebSession $realdebridsession

                    $torrent_id = $response.id

                    $Get_Torrent_Info = @{
                        Method = "GET"
                        Uri = "https://api.real-debrid.com/rest/1.0/torrents/info/$torrent_id"
                        Headers = $Header
                    }

                    $response = Invoke-RestMethod @Get_Torrent_Info -WebSession $realdebridsession

                    $torrent_status = $response.status

                    while( $torrent_status -eq "magnet_conversion"){
                        Sleep 15
                        $response = Invoke-RestMethod @Get_Torrent_Info
                        $torrent_status = $response.status
                    }

                    $Post_File_Selection = @{
                        Method = "POST"
                        Uri =  "https://api.real-debrid.com/rest/1.0/torrents/selectFiles/$torrent_id"
                        Headers = $Header
                        Body = @{ files = "all" }
    
                    }

                    $object.status = 4

                    Invoke-RestMethod @Post_File_Selection -WebSession $realdebridsession

                    $countRD++
            
                }
            }

        #monitor debrid services for completion of added magnets - At the moment only RD. Premiumize torrents are only accepted if cached and downloaded directly.      
    
            $Header = @{
                "authorization" = "Bearer $real_debrid_token"
            }

            $Get_Torrents = @{
                Method = "GET"
                Uri = "https://api.real-debrid.com/rest/1.0/torrents"
                Headers = $Header
            }

            $Post_Unrestrict_Link = @{
                Method = "POST"
                Uri =  "https://api.real-debrid.com/rest/1.0/unrestrict/link"
                Headers = $Header
                Body = @{link = $rd_link}
            }   
    
            $response = Invoke-RestMethod @Get_Torrents -WebSession $realdebridsession
    
            $torrents = $response | Select id, filename, status, links, hash   

            Foreach ($torrent in $torrents) {

                $torrent_hash = $torrent.hash

                $torrent_name = $torrent.filename

                $reference = $trakt | where hashed -CContains "$torrent_hash"

                if($torrent.status -eq "downloaded"){
            
                    $links = $torrent.links
                    
                    $torrent_name = $torrent.filename
                    
                    $torrent_id = $torrent.id

                    $type = $reference.type

                    if($reference.type -eq $null) {       
                        if([regex]::matches($torrent_name, ".*?(?=\.s[0-9]{2})", "IgnoreCase").Success) {
                            $type = "tv"
                        }elseif([regex]::matches($torrent_name, ".*?(?=.[0-9]{4}\.)").Success){
                            $type = "movie"
                        }else{
                            $type = "default"
                        }
                    }

                    Foreach ($link in $links) {

                        $RD_link = $link

                        $Post_Unrestrict_Link = @{
                            Method = "POST"
                            Uri =  "https://api.real-debrid.com/rest/1.0/unrestrict/link"
                            Headers = @{"authorization" = "Bearer $real_debrid_token"}
                            Body = @{link = "$RD_link"}
                        }
                
                        $response=Invoke-RestMethod @Post_Unrestrict_Link  -WebSession $realdebridsession      
   
                        $download = $response.download

                        $shit=Invoke-WebRequest -Headers @{"Content-type"="application/json"} -Method Post -Body "{`"jsonrpc`":`"2.0`",`"id`":`"qwer`",`"method`":`"aria2.addUri`",`"params`":[`"token:premiumizer`",[`"$download`"], {`"dir`": `"$path_to_downloads\$type\\$torrent_name`"}]}" http://192.168.0.23:6800/jsonrpc -SessionVariable aria2csession

                    }
                    
                    Sleep 5
                    
                    $Delete_Torrent = @{
                        Method = "DELETE"
                        Uri =  "https://api.real-debrid.com/rest/1.0/torrents/delete/$torrent_id"
                        Headers = @{"authorization" = "Bearer $real_debrid_token"}
                    }
                    
                    Invoke-RestMethod @Delete_Torrent -WebSession $realdebridsession 
                }

                if($reference.type -ne $null) {

                    sync $reference $settings

                    $count++

                    $count++

                }

            }

            Sleep 10      

}