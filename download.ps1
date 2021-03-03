# Torrent Download Script

function download($trakt, $settings) {
    
    . .\scraper.ps1

    . .\sync.ps1

    $trakt_client_id = $settings.trakt_client_id
    $trakt_client_secret = $settings.trakt_client_secret
    $trakt_access_token = $settings.trakt_access_token
    $real_debrid_token = $settings.real_debrid_token
    $premiumize_api_key = $settings.premiumize_api_key
    $path_to_downloads = $settings.path_to_downloads

# Test-Objects
#$trakt = new-object system.collections.arraylist
#$trakt += new-object psobject -property @{status=1;download_type="show";query=@("MeatEater.S09");scraper=$null;cached=$null;hashed=$null;type="tv";next_season=9;next_episode=7;year="2021";title="MeatEater"}

    Foreach ($object in $trakt) {

                $object | Add-Member -type NoteProperty -name files -Value $null -Force

                if ($object.query -ne $null) { 

                    torrent $object $settings

                    #check debrid services for scraped magnets. If magnet is cached, direct download. Premiumize prefered for cached downloads.

                    debrid_cached $object $settings

                    if($object.scraper.hashes -eq $null){
                        
                        $files = @()

                        $object.scraper | Add-Member -type NoteProperty -name hoster -Value $null  -Force

                        hoster $object

                        if($object.scraper.hoster -ne $null){

                            debrid_direct $object

                            $text = -join("(traktscraper) Trakt sucessfully synced for item: ",$object.title)

                            Write-Output $text

                            sync $object $settings

                        }

                    }

                }

            } 

            #monitor debrid services for completion of added magnets - At the moment only RD. Premiumize torrents are only accepted if cached and downloaded directly.      
    
            debrid_monitor $trakt $settings

            Sleep 10      

}

function debrid_cached($object, $settings) {
                
                . .\scraper.ps1

                . .\sync.ps1

                Write-Output "(traktscraper) checking debrid for cached torrents..."

                $object | Add-Member -type NoteProperty -name service -Value $null -Force
            
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

                        $fuck = $check_cache_RD.content | ConvertFrom-Json
                        
                        $cachedid = @()

                        foreach($entry in $fuck.$hashstring.rd){
                            if($entry -ne $null){
                                $entryobject = $entry | Get-Member -MemberType Properties | Select-Object Name
                                $cachedid += $entryobject.Name 
                            }
                        }

                        $cachedid = $cachedid | Sort -Unique  

                        $check_cache_PM = Invoke-RestMethod -Uri $body_pm -Method Get -SessionVariable premiumizesession                 

                        if($check_cache_PM.response){
                            
                            Write-Output "(traktscraper) Premiumize cache found"
                    
                            $object.service = "PM"
							
							$uri_pm = -join("https://www.premiumize.me/api/transfer/directdl?apikey=",$premiumize_api_key)
							
                            $get_link = Invoke-RestMethod -Uri $uri_pm -Method Post -Body @{src=$magnet} -H @{"Content-Type" = "application/x-www-form-urlencoded"}  -SessionVariable premiumizesession

                            $torrent_name = $check_cache_PM.filename

                            $type = $object.type

                            Foreach ($download in $get_link.content.link){
                        
                                $shit=Invoke-WebRequest -Headers @{"Content-type"="application/json"} -Method Post -Body "{`"jsonrpc`":`"2.0`",`"id`":`"qwer`",`"method`":`"aria2.addUri`",`"params`":[`"token:premiumizer`",[`"$download`"], {`"dir`": `"$path_to_downloads\$type\\$torrent_name`"}]}" http://192.168.0.23:6800/jsonrpc -SessionVariable aria2csession

                                Sleep 2

                            }

                            $text = -join("(traktscraper) Trakt sucessfully synced for item: ",$object.title)

                            Write-Output $text

                            sync $object $settings

                            break

                        }elseif([int]$check_cache_RD.RawContentLength -gt [int]"60") {

                            Write-Output "(traktscraper) RealDebrid cache found"

                            $object.service = "RD"
 
                            $object.cached = $item.magnets

                            $hashes = $item.hashes

                            $object.hashed = $hashes

                            $text = -join("(traktscraper) Trakt sucessfully synced for item: ",$object.title)

                            Write-Output $text

                            sync $object $settings

                            break

                        }
               
                        Sleep 5
                    }

                    Sleep 5

                }

                #Add selected Magnet to RD

                if($object.scraper.magnets -ne $null -and $object.status -le 3 -and $object.service -eq "RD") {
            
                    $magnet = $object.scraper.magnets[0]

                    $cached_files = @{ files = "all" }

                    if($object.cached -ne $null) {                       
                        $magnet = $object.cached
                        $cached_files = @{files = $cachedid -join ',' }
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
                        Body = $cached_files
    
                    }

                    $object.status = 4

                    Invoke-RestMethod @Post_File_Selection -WebSession $realdebridsession

                    $countRD++
            
                }
            
}

function debrid_monitor($trakt, $settings) {
            
            . .\scraper.ps1

            . .\sync.ps1

            Write-Output "(traktscraper) checking debrid for finished torrents"

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

                $object = $trakt | where hashed -CContains "$torrent_hash"

                if($torrent.status -eq "downloaded"){
            
                    $links = $torrent.links
                    
                    $torrent_name = $torrent.filename
                    
                    $torrent_id = $torrent.id

                    $type = $object.type

                    if($object.type -eq $null) {       
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


            }
}

function debrid_direct($object, $settings) {
            
            Write-Output "(traktscraper) checking debrid for finished direct links"

            $type = $object.type
            $name = $object.scraper[0].title
            
            $Header = @{
                "authorization" = "Bearer $real_debrid_token"
            }
            
            foreach($link in $object.scraper[0].hoster){

                $Post_Unrestrict_Link = @{
                    Method = "POST"
                    Uri =  "https://api.real-debrid.com/rest/1.0/unrestrict/link"
                    Headers = $Header
                    Body = @{link = $link}
                }
                
                $response=Invoke-RestMethod @Post_Unrestrict_Link  -WebSession $realdebridsession      
   
                $download = $response.download

                $shit=Invoke-WebRequest -Headers @{"Content-type"="application/json"} -Method Post -Body "{`"jsonrpc`":`"2.0`",`"id`":`"qwer`",`"method`":`"aria2.addUri`",`"params`":[`"token:premiumizer`",[`"$download`"], {`"dir`": `"$path_to_downloads\$type\\$name`"}]}" http://192.168.0.23:6800/jsonrpc -SessionVariable aria2csession
            
            }
}

#$settings = Import-Clixml -Path .\parameters.xml

#download $trakt $settings