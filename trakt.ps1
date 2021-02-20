# Trakt Script
#
# Creates a table of collected and queued content
#

function trakt($settings) {


    $trakt_client_id = $settings.trakt_client_id
    $trakt_client_secret = $settings.trakt_client_secret
    $trakt_access_token = $settings.trakt_access_token
    $real_debrid_token = $settings.real_debrid_token
    $premiumize_api_key = $settings.premiumize_api_key
    $path_to_downloads = $settings.path_to_downloads


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

            

    # get_watchlist_shows
  
            $get_watchlist_response = Invoke-RestMethod -Uri "https://api.trakt.tv/sync/watchlist/shows" -Method Get -Headers $Header -WebSession $traktsession
      
            Foreach ($entry in $get_watchlist_response) {
               
            if(-Not $trakt.title.Contains($entry.show.title)) {
            
                    $trakt += $entry.show

                }
            }

            

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

     # check airing

                $now = Get-Date -Format "o"
    
                $show | Add-Member -type NoteProperty -name download_type -Value $null -Force

                $show | Add-Member -type NoteProperty -name release_wait -Value $null -Force

                $show_next_season = $show.next_season

                $show_next_episode = $show.next_episode

                if ($show.next_episode -ne $null) {

                    $entry0 = Invoke-RestMethod -Uri "https://api.trakt.tv/shows/$show_id/seasons?extended=full" -Method Get -Headers $Header -WebSession $traktsession
            
                    
                    
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
    
            
   
            Foreach ($entry in $get_collection_response) {
        
                $trakt += $entry.movie

            }

    # get_watchlist_movies

            $get_watchlist_response = Invoke-RestMethod -Uri "https://api.trakt.tv/sync/watchlist/movies" -Method Get -Headers $Header -WebSession $traktsession
   
            
   
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

            $trakt

}

$settings = Import-Clixml -Path .\params.xml

$trakt = trakt $settings