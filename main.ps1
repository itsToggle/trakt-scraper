$traktscraper = {

sleep 1

$trakt_client_id = $args[0].trakt_client_id
$trakt_client_secret = $args[0].trakt_client_secret
$trakt_access_token = $args[0].trakt_access_token
$real_debrid_token = $args[0].real_debrid_token
$premiumize_api_key = $args[0].premiumize_api_key
$path_to_downloads = $args[0].path_to_downloads

function main {
    
    $timer =  [system.diagnostics.stopwatch]::StartNew()

    $count = 0

    $countRD = 0

    $countPM = 0

    while(1) {

        #download trakt.tv collections and watchlist

            $Header = @{
                "Content-type" = "application/json"
                "trakt-api-key" = "$trakt_client_id"
                "trakt-api-version" = "2"
                "Authorization" = "Bearer $trakt_access_token"
    
            }

            $trakt = new-object system.collections.arraylist
    
            # get_collection_shows
    
            $get_collection_response = Invoke-RestMethod -Uri "https://api.trakt.tv/sync/collection/shows" -Method Get -Headers $Header -SessionVariable traktsession

            Foreach ($entry in $get_collection_response) {
                      
                $trakt += $entry.show

            }

            $count++

            # get_watchlist_shows
  
            $get_watchlist_response = Invoke-RestMethod -Uri "https://api.trakt.tv/sync/watchlist/shows" -Method Get -Headers $Header -WebSession $traktsession
      
            Foreach ($entry in $get_watchlist_response) {
               
            if(-Not $trakt.title.Contains($entry.show.title)) {
            
                    $trakt += $entry.show

                }
            }

            $count++

            # add special show stuff

            Foreach ($show in $trakt) {
        
                $show | Add-Member -type NoteProperty -name type -Value "tv"  -Force
    
                $show | Add-Member -type NoteProperty -name query -Value $null  -Force

                $show | Add-Member -type NoteProperty -name last_episode -Value 1   -Force

                $show | Add-Member -type NoteProperty -name last_season -Value 1  -Force

                $show | Add-Member -type NoteProperty -name collected -Value $null  -Force

                $show | Add-Member -type NoteProperty -name next_episode -Value 1  -Force

                $show | Add-Member -type NoteProperty -name next_episode_id -Value $null  -Force

                $show | Add-Member -type NoteProperty -name next -Value $null  -Force

                $show | Add-Member -type NoteProperty -name next_season -Value 1  -Force

                $show | Add-Member -type NoteProperty -name next_season_id -Value $null  -Force

                $show_id = $show.ids.trakt

                $entry = Invoke-RestMethod -Uri "https://api.trakt.tv/shows/$show_id/progress/collection?hidden=false&specials=false&count_specials=true" -Method Get -Headers $Header -WebSession $traktsession
        
                $count++
        
                $show.next_episode = $entry.next_episode.number            
        
                $show.next_episode_id = $entry.next_episode.ids

                $show.next_season = $entry.next_episode.season
        
                $show.last_episode = $entry.last_episode.number         
        
                $show.last_season = $entry.last_episode.season
                
                $nseason = "{0:d2}" -f $show.next_season
                $nepisode = "{0:d2}" -f $show.next_episode
                $cseason = "{0:d2}" -f $show.last_season
                $cepisode = "{0:d2}" -f $show.last_episode
                if($show.last_episode -ne $null){
                    $collected= -join("S",$cseason," E",$cepisode)
                }else{
                    $collected = $null
                }
                if($show.next_episode -ne $null -and $show.last_episode -ne $null){
                    $next= -join("S",$nseason," E",$nepisode)                
                }else{
                    $next = $null
                }

                $show.collected = $collected

                $show.next = $next

                #check airing

                $now = Get-Date -Format "o"
    
                $show | Add-Member -type NoteProperty -name download_type -Value $null -Force

                $show | Add-Member -type NoteProperty -name release_wait -Value $null -Force

                $show_next_season = $show.next_season

                $show_next_episode = $show.next_episode

                if ($show.next_episode -ne $null) {

                    $entry0 = Invoke-RestMethod -Uri "https://api.trakt.tv/shows/$show_id/seasons?extended=full" -Method Get -Headers $Header -WebSession $traktsession
            
                    $count++
                    
                    $seasonnumbers = $entry0.number

                    if($seasonnumbers.GetType().Name -eq "Int32"){

                        $entrynumber = $show_next_season-1

                    }elseif(-Not $entry0.number.Contains(0)){
                
                        $entrynumber = $show_next_season-1
            
                    }else{
               
                        $entrynumber = $show_next_season
            
                    }

                    $show.next_season_id = $entry0.ids[$entrynumber]

                    if($entry0.episode_count[$entrynumber] -ne $entry0.aired_episodes[$entrynumber]) {
                
                        $entry = Invoke-RestMethod -Uri "https://api.trakt.tv/shows/$show_id/seasons/$show_next_season/episodes/$show_next_episode ?extended=full" -Method Get -Headers $Header -WebSession $traktsession
               
                        $count++
                
                        $first_aired_long = $entry.first_aired

                        $delay = New-TimeSpan -Hours 1

                        if((get-date $now) -lt (get-date $first_aired_long)+$delay) {
                    
                            $show.download_type = $null

                            $start = (get-date $first_aired_long)+$delay

                            $till_release = New-TimeSpan -Start (get-date $now) -End $start

                            $show.release_wait = "{0:dd}d:{0:hh}h:{0:mm}m" -f $till_release                                
                
                        } else {
                    
                            $season = "{0:d2}" -f $show_next_season

                            $episode = "{0:d2}" -f $show_next_episode

                            $title = $show.title -replace('\s','.') ` -replace(':','') ` -replace('`','') ` -replace("'",'') ` -replace('´','')

                            $show.download_type = "episode"
                    
                            $show.query = -join($title,".S",$season,"E",$episode)                
                    
                        }

                    } elseif($show.next_episode -eq "1") {
                
                        $season = "{0:d2}" -f $show_next_season

                        $title = $show.title-replace('\s','.') ` -replace(':','') ` -replace('`','') ` -replace("'",'') ` -replace('´','')

                        $show.download_type = "season"
                
                        $show.query = -join($title,".S",$season)
                
                    } else {
                       
                        $season = "{0:d2}" -f $show_next_season

                        $episode = "{0:d2}" -f $show_next_episode

                        $title = $show.title -replace('\s','.') ` -replace(':','') ` -replace('`','') ` -replace("'",'') ` -replace('´','')

                        $show.download_type = "episode"
                    
                        $show.query = -join($title,".S",$season,"E",$episode)
                                              
                    }

                }
            }    

            # get_collection_movies

            $get_collection_response = Invoke-RestMethod -Uri "https://api.trakt.tv/sync/collection/movies" -Method Get -Headers $Header -WebSession $traktsession
    
            $count++
   
            Foreach ($entry in $get_collection_response) {
        
                $trakt += $entry.movie

            }

            #get_watchlist_movies

            $get_watchlist_response = Invoke-RestMethod -Uri "https://api.trakt.tv/sync/watchlist/movies" -Method Get -Headers $Header -WebSession $traktsession
   
            $count++
   
            Foreach ($entry in $get_watchlist_response) {
               
                if(-Not $trakt.title.Contains($entry.movie.title)) {

                    $title = $entry.movie.title -replace('\s','.') ` -replace(':','') ` -replace('`','') ` -replace("'",'') ` -replace('´','')

                    $query = -join($title,".",$entry.movie.year) 

                    $entry.movie | Add-Member -type NoteProperty -name download_type -Value "movie" -Force

                    $entry.movie | Add-Member -type NoteProperty -name type -Value "movie"  -Force

                    $entry.movie | Add-Member -type NoteProperty -name query -Value $query  -Force
            
                    $trakt += $entry.movie

                }
            }


            Foreach ($object in $trakt){

                $object | Add-Member -type NoteProperty -name scraper -Value $null -Force

                $object | Add-Member -type NoteProperty -name cached -Value $null -Force

                $object | Add-Member -type NoteProperty -name hashed -Value $null -Force

                $object | Add-Member -type NoteProperty -name status -Value 1 -Force

            }

            Clear-Host

            $Date = Get-Date
            
            $delimiter = ";"

            Write-Output $delimiter

            Write-Output $trakt  | Where-Object {$_.next_season -ne $null -or $_.download_type -ne $null} |  Sort-Object -Property release_wait | Format-Table -Property @{ e='title'; width = 30 },@{ e='collected'; width = 15 },@{ e='next'; width = 15 },@{ e='download_type'; width = 15 },@{ e='release_wait'; width = 15 }

            

        #api safety call

            if([math]::Round($timer.Elapsed.TotalSeconds,0) -ge 300) {

                $timer.Stop()

                $seconds =  [math]::Round($timer.Elapsed.TotalSeconds,0)

                $time = Get-Date
    
                $timer =  [system.diagnostics.stopwatch]::StartNew()

                if($count -gt 900) {
        
                    Write-Host "Pausing for 5 Minutes to cool down API ..."
        
                    Sleep 300
                }

                $count = 0

            }


            if(-not $trakt.download_type.Contains("episode") -or -not $trakt.download_type.Contains("season")){

                Sleep 60

            }else{

                Sleep 5

            }

        #add scraper to $trakt            

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


                        #rarbg

                        $rarbg = new-object system.collections.arraylist 

                        $uri = -join ('https://torrentapi.org/pubapi_v2.php?mode=search&search_string=', $query, '&category=52;51;50;49;48;45;44;41;17;14&token=lnjzy73ucv&format=json_extended&app_id=lol')

                        $response = Invoke-WebRequest $uri -SessionVariable rarbgsession | ConvertFrom-Json

                        $items = $response.torrent_results

                        Foreach ($item in $items) {
                            
                            $title = $item.title
                            
                            $quality = [regex]::matches($title, "(1080)|(720)|(2160)").value 
                            
                            $category = $item.category
                            
                            $download = $item.download
                            
                            $seeders = $item.seeders
                            
                            $imdb = $item.episode_info.imdb
                            
                            $hash = [regex]::matches($download, "(?<=btih:).*?(?=&)").value
                            
                            if (([regex]::matches($title, "($query\.)", "IgnoreCase").value -or [regex]::matches($title, "($query_fallback\.)", "IgnoreCase").value)  -And -Not [regex]::matches($title, "(REMUX)|(\.3D\.)", "IgnoreCase").value) {
                                
                                $files = @()
                                
                                $response = Invoke-WebRequest -Uri http://magnet2torrent.com/upload/ -Body @{magnet = "$download"} -Method Post

                                $filestext = [regex]::matches($response.RawContent, "(S[0-9].E[0-9].)", "IgnoreCase").value

                                foreach($file in $filestext){
    
                                    $season = [int][regex]::matches($file, "(?<=S)..?(?=E)", "IgnoreCase").value
                                    $episode = [int][regex]::matches($file, "(?<=E)..?", "IgnoreCase").value
                                    $files += new-object psobject -property @{season=$season;episode=$episode}
                                }
                                if($object.download_type -eq "movie") {

                                    $rarbg += new-object psobject -property @{title=$title;quality=[int]$quality;category=$category;magnets=$download;seeders=[int]$seeders;imdb=$imdb;hashes=$hash;files=$files}

                                }elseif($files.season.Contains($object.next_season) -and $files.episode.Contains($object.next_episode)){

                                    $rarbg += new-object psobject -property @{title=$title;quality=[int]$quality;category=$category;magnets=$download;seeders=[int]$seeders;imdb=$imdb;hashes=$hash;files=$files}
                                
                                }

                                Sleep 1

                            }
                        }

                        $object.scraper += @( $rarbg | Sort-Object -Property quality,seeders -Descending )

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

                            traktsync $object

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

                    traktsync $reference

                    $count++

                    $count++

                }

            }

            Sleep 10

        }
}

function traktsync($reference) {

            Sleep 1

            $movies = @()

            $shows = @()

            $shows_ = @()

            $seasons = @()

            $seasons_ = @()

            $episodes = @()

            $e = @()

            $object = $reference.next_season_id

            $candidateProps = $object.psobject.properties.Name

            $nonNullProps = $candidateProps.Where({ $null -ne $object.$_ })

            $season_id = $object | Select-Object $nonNullProps


            $object = $reference.next_episode_id

            $candidateProps = $object.psobject.properties.Name

            $nonNullProps = $candidateProps.Where({ $null -ne $object.$_ })

            $episode_id = $object | Select-Object $nonNullProps


            $object = $reference.ids

            $candidateProps = $object.psobject.properties.Name

            $nonNullProps = $candidateProps.Where({ $null -ne $object.$_ })

            $nonnullids = $object | Select-Object $nonNullProps


            if($reference.download_type.Contains("season")) {
         
                foreach($enumber in $reference.files.episode){

                    $e += @{"number"=$enumber}

                }

                $episodes += $e

                $snumber = $reference.next_season

                $s = @{"number"=$snumber;"episodes"=$episodes}

                $seasons_ += $s
               
                $reference | Add-Member -type NoteProperty -name seasons -Value $seasons_ -Force
               
                $shows_ += $reference | Select title, year, ids, seasons

            }elseif ($reference.download_type.Contains("episode")){

                $enumber = $reference.next_episode

                $e = @{"number"=$enumber}

                $episodes += $e

                $snumber = $reference.next_season

                $s = @{"number"=$snumber;"episodes"=$episodes}

                $seasons_ += $s
               
                $reference | Add-Member -type NoteProperty -name seasons -Value $seasons_ -Force
               
                $shows_ += $reference | Select title, year, ids, seasons   

            }
        
            if ($reference.type.Contains("movie")){

                $ids= $nonnullids

                $movie_id = @{"ids"= $ids}

                $movies += $movie_id

            }
        
            if($reference.type.Contains("tv")) {

                $ids= $nonnullids 

                $show_id = @{"ids"= $ids}

                $shows += $show_id

            }
        
            $watchlist_remove = ConvertTo-Json -Depth 10 -InputObject @{
                movies = $movies
                shows=$shows
            }
        
            Sleep 1
                    
            $post_watchlist_remove = Invoke-RestMethod -Uri "https://api.trakt.tv/sync/watchlist/remove" -Method Post -Body $watchlist_remove -Headers @{"Content-type" = "application/json";"trakt-api-key" = "$trakt_client_id";"trakt-api-version" = "2";"Authorization" = "Bearer $trakt_access_token"} -WebSession $traktsession
            
            $count++
   
            $collection_add = ConvertTo-Json -Depth 10 -InputObject @{
                seasons=$seasons
                shows=$shows_
                movies = $movies
            }

            Sleep 1
                    
            $post_collection_add = Invoke-RestMethod -Uri "https://api.trakt.tv/sync/collection" -Method Post -Body $collection_add -Headers @{"Content-type" = "application/json";"trakt-api-key" = "$trakt_client_id";"trakt-api-version" = "2";"Authorization" = "Bearer $trakt_access_token"}  -WebSession $traktsession
            
            $count++  

            $reference.status = 1

}

main

} 

if(-Not (Test-Path .\params.xml -PathType Leaf)) {

    $Header = @{
        "Content-type" = "application/json"
        "trakt-api-key" = "$trakt_client_id"
        "trakt-api-version" = "2"
        "Authorization" = "Bearer $trakt_access_token"
    
    }

    $trakt_client_id = "bf93b45f96cd6ed2d0217d660f36ebd8f4337446a875b53a1f9332a326ef61ea"
    
    $trakt_client_secret = "cc6051d03aa726c9a98019d661be891c23b6a96db0e2a7c53a8fc433f080bbc4"

    $get_token = ConvertTo-Json -InputObject @{
        client_id = $trakt_client_id
    }
   
    $get_token_response = Invoke-RestMethod -Uri "https://api.trakt.tv/oauth/device/code" -Method Post -Body $get_token -Headers $Header

    clear

    Read-Host -Prompt 'To use the script, you need to connect it to Trakt.tv and specify a few parameters. Press Enter to continue'

    Write-Host "Connect the Script to Trakt. Go to  trakt.tv/activate  and within 60 seconds enter the code:" $get_token_response.user_code 

    $device_code = $get_token_response.device_code

    $poll_token = ConvertTo-Json -InputObject @{
        code = $device_code
        client_id = $trakt_client_id
        client_secret = $trakt_client_secret
    }

    $http_valid_response = $false

    while(-Not $http_valid_response) {
        
        $http_valid_response = $true

        sleep $get_token_response.interval

        try { 
    
            $poll_token_response = Invoke-RestMethod -Uri "https://api.trakt.tv/oauth/device/token" -Method Post -Body $poll_token -Headers $Header
    
        } catch {
        
        $http_valid_response = $false

        }   
    }

    clear

    Write-Host "Successfully connected to Trakt!" 
    
    $trakt_access_token = $poll_token_response.access_token

    Write-Host

    Write-Host "Connect the Script to Debrid Services. If promted for a Service you do not intent to use, just press Enter."

    Write-Host

    $real_debrid_token = Read-Host -Prompt 'Real Debrid - enter your API token'

    Write-Host

    $premiumize_api_key = Read-Host -Prompt 'Premiumize - enter your API key'

    clear

    Write-Host "Successfully connected to Debrid Services!"

    Write-Host
    
    Write-Host "The Script starts an instance of the download manager Aria2c in the background. To function properly, please provide the path to your Aria2c.exe"
    
    $path_to_aria2c = "C:\aria2c.exe"

    Write-Host

    while(-Not(Test-Path (-join($path_to_aria2c,"aria2c.exe")) -PathType Leaf)){

        $path_to_aria2c = Read-Host -Prompt 'Please enter the path in the format C:\path\to\'

        if((Test-Path $path_to_aria2c -PathType Leaf)){
            clear
            Write-Host "Successfully connected to Aria2c!"
        }else{
            Write-Host "Path seems to be wrong."
        }
    }

    clear

    Write-Host "The Script creates the following folders for your downloads: tv,movie,default."

    Write-Host

    $path_to_downloads = Read-Host -Prompt "Please enter the path in the format: D:\path\to\downloads\" 

    clear

    Write-Host "Success! Your parameters will now be saved as params.ini. You can edit this file any time."

    $paramsini = @{
        trakt_client_id = "bf93b45f96cd6ed2d0217d660f36ebd8f4337446a875b53a1f9332a326ef61ea"
        trakt_client_secret = "cc6051d03aa726c9a98019d661be891c23b6a96db0e2a7c53a8fc433f080bbc4"
        trakt_access_token = $trakt_access_token
        real_debrid_token = $real_debrid_token
        premiumize_api_key = $premiumize_api_key 
        path_to_aria2c = $path_to_aria2c
        path_to_downloads = $path_to_downloads
    }

    $paramsini

    $paramsini | Export-Clixml -Path .\params.xml

    Write-Host

    Write-Host "Please ensure all paramters are correct. If youve made any mistakes, delete the params.ini file before restarting."

    Write-Host

    Write-Host "The Script uses a WebUI to function. To allow the local webserver to be run, you need to run the following command with admin rights:"

    Write-Host "netsh http add urlacl url=http://+:8008/ user=YOUR-USERNAME-HERE"

    Write-Host

    Read-Host -Prompt 'Please restart the Script. Press Enter to exit'

}else {

    $settings = Import-Clixml -Path .\params.xml

    $env:Path += $settings.path_to_aria2c

    Start-Job -Name Aria2c -ScriptBlock {
    
        aria2c --disable-ipv6=true --enable-rpc --rpc-allow-origin-all --rpc-listen-all --rpc-listen-port=6800 --rpc-secret=premiumizer --max-connection-per-server=16 --file-allocation=none --disk-cache=0 --max-concurrent-downloads=1 --continue=true
    
    }

    Start-Job -Name TraktScraper -ScriptBlock $traktscraper -ArgumentList $settings
    
    function tohtml {

		#------------------------------------------------------------------------------
		# Copyright 2006-2007 Adrian Milliner (ps1 at soapyfrog dot com)
		# http://ps1.soapyfrog.com
		#
		# This work is licenced under the Creative Commons 
		# Attribution-NonCommercial-ShareAlike 2.5 License. 
		# To view a copy of this licence, visit 
		# http://creativecommons.org/licenses/by-nc-sa/2.5/ 
		# or send a letter to 
		# Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.
		#------------------------------------------------------------------------------

		# $Id: get-bufferhtml.ps1 162 2007-01-26 16:30:12Z adrian $

		#------------------------------------------------------------------------------
		# This script grabs text from the console buffer and outputs to the pipeline
		# lines of HTML that represent it.
		#
		# Usage: get-bufferhtml [args]
		#
		# Where args are:
		#
		# -last n       - how many lines back from current line to grab
		#                 default is (effectively) everything
		# -all          - grab all lines in console, overrides -last
		# -trim         - trims blank space from the right of each line
		#                 this is ok unless you have lots of text with
		#                 varying background colours
		# -font s       - optional css font name. default is nothing which
		#                 means the browser will use whatever is default for a
		#                 <pre> tag. "Courier New" is quite a good alternative
		# -fontsize s   - optional css font size, eg "9pt" or "80%"
		# -style s      - optional addition css, eg "overflow:hidden"
		# -palette p    - choose a colour palette, one of:
		#                 "powershell" normal for a PowerShell window (ie with
		#                              strange colours for darkmagenta and darkyellow
		#                 "standard"   normal ansi colours as used by a standard
		#                              cmd.exe session
		#                 "print"      like powershell, but with colours handy
		#                              for printing where you want to save ink.
		#
		# The output is one large wrapped <pre> tag to keep whitespace intact.
		#

		param(
		  [int]$last = 50000,             
		  [switch]$all,                   
		  [switch]$trim,                  
		  [string]$font=$null,            
		  [string]$fontsize=$null,        
		  [string]$style="",              
		  [string]$palette="powershell"   
		  )
		$ui = $host.UI.RawUI
		[int]$start = 0
		if ($all) { 
		  [int]$end = $ui.BufferSize.Height  
		  [int]$start = 0
		}
		else { 
		  [int]$end = ($ui.CursorPosition.Y - 1)
		  [int]$start = $end - $last
		  if ($start -le 0) { $start = 0 }
		}
		$height = $end - $start
		if ($height -le 0) {
		  write-warning "There must be one or more lines to get"
		  return
		}
		$width = $ui.BufferSize.Width
		$dims = 0,$start,($width-1),($end-1)
		$rect = new-object Management.Automation.Host.Rectangle -argumentList $dims
		$cells = $ui.GetBufferContents($rect)

		# set default colours
		$fg = $ui.ForegroundColor; $bg = $ui.BackgroundColor
		$defaultfg = $fg; $defaultbg = $bg

		# character translations
		# wordpress weirdness means I do special stuff for < and \
		$cmap = @{
			[char]"<" = "&lt;"# "<span>&lt;</span>"
			[char]"\" = "&#x5c;"
			[char]">" = "&gt;"
			[char]"'" = "&#39;"
			[char]"`"" = "&#34;"
			[char]"&" = "&amp;"
		}

		# console colour mapping
		# the powershell console has some odd colour choices, 
		# marked with a 6-char hex codes below
		$palettes = @{}
		$palettes.powershell = @{
			"Black"       ="#000"
			"DarkBlue"    ="#008"
			"DarkGreen"   ="#080"
			"DarkCyan"    ="#088"
			"DarkRed"     ="#800"
			"DarkMagenta" ="#012456"
			"DarkYellow"  ="#eeedf0"
			"Gray"        ="#ccc"
			"DarkGray"    ="#888"
			"Blue"        ="#00f"
			"Green"       ="#0f0"
			"Cyan"        ="#0ff"
			"Red"         ="#f00"
			"Magenta"     ="#f0f"
			"Yellow"      ="#ff0"
			"White"       ="#fff"
		  }
		# now a variation for the standard console (used by cmd.exe) based
		# on ansi colours
		$palettes.standard = ($palettes.powershell).Clone()
		$palettes.standard.DarkMagenta = "#808"
		$palettes.standard.DarkYellow = "#880"

		# this is a weird one... takes the normal powershell one and
		# inverts a few colours so normal ps1 output would save ink when
		# printed (eg from a web page).
		$palettes.print = ($palettes.powershell).Clone()
		$palettes.print.DarkMagenta = "#eee"
		$palettes.print.DarkYellow = "#000"
		$palettes.print.Yellow = "#440"
		$palettes.print.Black = "#fff"
		$palettes.print.White = "#000"

		$comap = $palettes[$palette]

		# inner function to translate a console colour to an html/css one
		function c2h{return $comap[[string]$args[0]]}
		$f=""
		if ($font) { $f += " font-family: `"$font`";" }
		if ($fontsize) { $f += " font-size: $fontsize;" }
		$line  = "<!DOCTYPE html><html lang=`"en`"><head><meta charset=`"utf-16`"><meta http-equiv=`"refresh`" content=`"5`"></head><body style=`"background-color: $(c2h $bg);`"><pre style='color: $(c2h $fg); background-color: $(c2h $bg);$f $style'>" 
		for ([int]$row=0; $row -lt $height; $row++ ) {
		  for ([int]$col=0; $col -lt $width; $col++ ) {
			$cell = $cells[$row,$col]
			# do we need to change colours?
			$cfg = [string]$cell.ForegroundColor
			$cbg = [string]$cell.BackgroundColor
			if ($fg -ne $cfg -or $bg -ne $cbg) {
			  if ($fg -ne $defaultfg -or $bg -ne $defaultbg) { 
				$line += "</span>" # remove any specialisation
				$fg = $defaultfg; $bg = $defaultbg;
			  }
			  if ($cfg -ne $defaultfg -or $cbg -ne $defaultbg) { 
				# start a new colour span
				$line += "<span style='color: $(c2h $cfg); background-color: $(c2h $cbg)'>" 
			  }
			  $fg = $cfg
			  $bg = $cbg
			}
			$ch = $cell.Character
			$ch2 = $cmap[$ch]; if ($ch2) { $ch = $ch2 }
			$line += $ch
			#$line += "<br>"
		  }
		  if ($trim) { $line = $Line.TrimEnd() }
		  $line += "<br>"
		  $line
		  $line=""
		}
		if ($fg -ne $defaultfg -or $bg -ne $defaultbg) { "</span>" } # close off any specialisation of colour
		"</pre></body></html>"


	}

    $http = [System.Net.HttpListener]::new()

    $http.Prefixes.Add("http://+:8008/")

    $http.Start()

    $twice = $false

    $box1 = [string][char]9608

    $box2 = [string][char]9617

    $barLength = 30

    while ($http.IsListening) {
        
        $context = $http.GetContext()
        
        if ($context.Request.HttpMethod -eq 'GET') {
            
            Clear-Host

            Write-Host " Trakt: "

            $Job = Get-Job -Name TraktScraper

            $new = $Job.ChildJobs.Output | Out-String

            $TraktScraperOutput = $new.Split(";")

            $TraktScraperOutput[-1]            

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

            [string]$html = tohtml -Raw -Encoding utf8 #Get-Content -Path .\out.html                              

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response

        }
        
    }

}
