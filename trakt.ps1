﻿# Trakt Script
#
# Creates a table of collected and queued content
#

function trakt($settings, $exceptions) {

    $trakt_client_id = $settings.trakt_client_id
    $trakt_client_secret = $settings.trakt_client_secret
    $trakt_access_token = $settings.trakt_access_token
    $real_debrid_token = $settings.real_debrid_token
    $path_to_downloads = $settings.path_to_downloads


    #download trakt.tv collections and watchlist

            $Header = @{
                "Content-type" = "application/json"
                "trakt-api-key" = "$trakt_client_id"
                "trakt-api-version" = "2"
                "Authorization" = "Bearer $trakt_access_token"
    
            }

            $trakt = new-object system.collections.arraylist

            $traktignored = new-object system.collections.arraylist

    # get_ignored_shows
            
            $get_lists_response = Invoke-RestMethod -Uri "https://api.trakt.tv/users/me/lists" -Method Get -Headers $Header -SessionVariable traktsession            
                
            if(-Not @($get_lists_response.name).Contains("Ignored")){
                
                $post_ignored = @{
                    name = "Ignored"
                    description = "Shows that couldnt be found by scraper"
                    privacy = "public"
                }
                
                $post_ignored = ConvertTo-Json -Depth 10 -InputObject $post_ignored 

                $post_ignored_response = Invoke-RestMethod -Uri "https://api.trakt.tv/users/me/lists" -Method Post -Headers $Header -Body $post_ignored  -SessionVariable traktsession

            }
            
            $get_lists_response = Invoke-RestMethod -Uri "https://api.trakt.tv/users/me/lists" -Method Get -Headers $Header -SessionVariable traktsession

            $ignored_list = $get_lists_response | Where-Object {$_.name -eq "Ignored"}

            $ignored_list_id = $ignored_list.ids.slug
            
            $get_ignored_response = Invoke-RestMethod -Uri "https://api.trakt.tv/users/me/lists/$ignored_list_id/items/show" -Method Get -Headers $Header -SessionVariable traktsession                       

            Foreach ($entry in $get_ignored_response) {

                $entry.show | Add-Member -type NoteProperty -name type -Value "tv"  -Force
                
                $show_id = $entry.show.ids.trakt

                $progress = Invoke-RestMethod -Uri "https://api.trakt.tv/shows/$show_id/progress/collection?hidden=false&specials=false&count_specials=true" -Method Get -Headers $Header -WebSession $traktsession           
        
                $episode = "{0:d2}" -f $progress.next_episode.number            

                $season = "{0:d2}" -f $progress.next_episode.season 

                $title = $entry.show.title  -replace('\.|:|`|´|,|!|\?|\s-|''','') ` -replace('\s+','.') ` -replace('&','and')
                             
                $predb = -join($title,".S",$season,"E",$episode,".") 
                
                $entry.show | Add-Member -type NoteProperty -name predb -Value $predb  -Force     
                
                $traktignored += $entry.show

            }

            $get_ignored_response = Invoke-RestMethod -Uri "https://api.trakt.tv/users/me/lists/$ignored_list_id/items/movie" -Method Get -Headers $Header -SessionVariable traktsession                       

            Foreach ($entry in $get_ignored_response) {
                
                $entry.movie | Add-Member -type NoteProperty -name type -Value "movie"  -Force

                $title = $entry.movie.title -replace('\.|:|`|´|,|!|\?|\s-|''','') ` -replace('\s+','.') ` -replace('&','and')

                $predb = @(-join($title,".",$entry.movie.year))

                $entry.movie | Add-Member -type NoteProperty -name predb -Value $predb  -Force

                $traktignored += $entry.movie

            }

            Foreach($entry in $traktignored){

                $entry | Add-Member -type NoteProperty -name download_type -Value "ignored" -Force

                #get predb releases

                $query = $entry.predb

                $predb = Invoke-RestMethod -Uri "https://predb.ovh/api/v1/?q=$query"

                $predbcount = $predb.data.rowCount

                $entry | Add-Member -type NoteProperty -name predb -Value $predbcount -Force

                $status = switch($predbcount) {
                    0 {"<span class=`"badge badge-soft-secondary font-size-11`">predb: 0 releases</span>"}   
                    1 {"<span class=`"badge badge-soft-secondary font-size-11`">predb: 1 release</span>"}                                                 
                    default {"<span class=`"badge badge-soft-secondary font-size-11`">predb: $predbcount releases</span>"}
                }

                $entry | Add-Member -type NoteProperty -name release_wait -Value $status -Force

            }

            
    
    # get_collection_shows
    
            $get_collection_response = Invoke-RestMethod -Uri "https://api.trakt.tv/sync/collection/shows" -Method Get -Headers $Header -SessionVariable traktsession

            Foreach ($entry in $get_collection_response) { 
                
                if(-not @($traktignored.title).Contains($entry.show.title)){
                      
                    $trakt += $entry.show

                }

            }

            

    # get_watchlist_shows
  
            $get_watchlist_response = Invoke-RestMethod -Uri "https://api.trakt.tv/sync/watchlist/shows" -Method Get -Headers $Header -WebSession $traktsession
      
            Foreach ($entry in $get_watchlist_response) {
               
                if(-Not @($trakt.title).Contains($entry.show.title) -and -not @($traktignored.title).Contains($entry.show.title)) { 
            
                    $trakt += $entry.show

                }

            }


    
    # add special show stuff
            
            $traktignored_ = new-object system.collections.arraylist

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
                if($show.next_episode -ne $null){
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

                    if(-Not @($entry0.number).Contains(0)){
                
                        $entrynumber = $show_next_season-1
            
                    }else{
               
                        $entrynumber = $show_next_season
            
                    }

                    $show.next_season_id = $entry0.ids[$entrynumber]
                
                    $entry1 = Invoke-RestMethod -Uri "https://api.trakt.tv/shows/$show_id/seasons/$show_next_season/episodes/$show_next_episode ?extended=full" -Method Get -Headers $Header -WebSession $traktsession            
                
                    $first_aired_long = $entry1.first_aired

                    $delay = New-TimeSpan -Hours 2

                    if((get-date $now) -lt (get-date $first_aired_long)+$delay) {
                    
                        $show.download_type = $null

                        $start = (get-date $first_aired_long)+$delay

                        $till_release = New-TimeSpan -Start (get-date $now) -End $start

                        $release_wait = "{0:dd}d:{0:hh}h:{0:mm}m" -f $till_release
                        
                        $show.release_wait = "<span class=`"badge badge-soft-secondary font-size-11`">airs: $release_wait</span>"                                
                
                    } else {
                    
                        $season = "{0:d2}" -f $show_next_season

                        $episode = "{0:d2}" -f $show_next_episode  

                        $title = $show.title  -replace('\.|:|`|´|,|!|\?|\s-|''','') ` -replace('\s+','.') ` -replace('&','and')

                        $year = $show.year

                        $release_year = (get-date $first_aired_long -Format "yyyy")

                        $release_month = "{0:d2}" -f (get-date $first_aired_long -Format "MM")

                        $release_day = "{0:d2}" -f (get-date $first_aired_long -Format "dd")

                        $season_title = $entry0.title[$entrynumber] -replace('\.|:|`|´|,|!|\?|\s-|''','') ` -replace('\s+','.') ` -replace('&','and')

                        $episode_title = $entry1.title -replace('\.|:|`|´|,|!|\?|\s-|''','') ` -replace('\s+','.') ` -replace('&','and')

                        $show.download_type = "show"

                        #prefer multilang releases

                        $lang = $settings.lang

                        $title_de = @(@(Invoke-RestMethod -Uri "https://api.trakt.tv/shows/$show_id/translations/$lang" -Method Get -Headers $Header -WebSession $traktsession).title)[0]

                        if($title_de -ne $null -and $title_de -ne "") {

                             $title_de = $title_de -replace('\.|:|`|´|,|!|\?|\s-|''','') ` -replace('\s+','.') ` -replace('ü','ue') ` -replace('ä','ae') ` -replace('ö','oe') ` -replace('ß','ss')
                        
                             $show.query += ,@(-join($title_de,".S",$season,"."),(-join($title_de,".",$year,".S",$season,".")))

                             $show.query += ,@(-join($title_de,".S",$season,"E",$episode,"."),(-join($title_de,".",$year,".S",$season,"E",$episode,".")))

                        }

                        $imdbid = $show.ids.imdb

                        $show.query += ,@(-join($title,".S",$season,"."),(-join($title,".",$year,".S",$season,".")),(-join($imdbid)))
                    
                        $show.query += ,@(-join($title,".S",$season,"E",$episode,"."),(-join($title,".",$year,".S",$season,"E",$episode,".")),(-join($imdbid))) 
                        
                        if($exceptions.($show.title) -ne $null) {
                            
                            iex $exceptions.($show.title).command

                        }

                        $traktignored_ += new-object psobject -property @{$show.title = @($show.next)}

                    }                

                }

            }

    # get_collection_movies

            $get_collection_response = Invoke-RestMethod -Uri "https://api.trakt.tv/sync/collection/movies" -Method Get -Headers $Header -WebSession $traktsession
       
            Foreach ($entry in $get_collection_response) {
                
                if(-not @($traktignored.title).Contains($entry.movie.title)){

                    $trakt += $entry.movie
                
                }

            }

    # get_watchlist_movies

            $get_watchlist_response = Invoke-RestMethod -Uri "https://api.trakt.tv/sync/watchlist/movies" -Method Get -Headers $Header -WebSession $traktsession
   
            Foreach ($entry in $get_watchlist_response) {
               
                if(-Not $trakt.title.Contains($entry.movie.title)-and -not @($traktignored.title).Contains($entry.movie.title)) {

                    $title = $entry.movie.title -replace('\.|:|`|´|,|!|\?|\s-|''','') ` -replace('\s+','.') ` -replace('&','and')

                    $movie_id = $entry.movie.ids.trakt

                    $query = @()

                    #prefer multilang releases

                    $lang = $settings.lang
                   
                    $title_de = @(@(Invoke-RestMethod -Uri "https://api.trakt.tv/movies/$movie_id/translations/$lang" -Method Get -Headers $Header -WebSession $traktsession).title)[0]

                    $title_de = $title_de -replace('\.|:|`|´|,|!|\?|\s-|''','') ` -replace('\s+','.') ` -replace('ü','ue') ` -replace('ä','ae') ` -replace('ö','oe') ` -replace('ß','ss')
                        
                    if($title_de -ne $null -and $title_de -ne "") {

                        $query += @(-join($title_de,".",$entry.movie.year))

                    }
                    
                    $query += @(-join($title,".",$entry.movie.year)) 

                    $entry.movie | Add-Member -type NoteProperty -name download_type -Value "movie" -Force

                    $entry.movie | Add-Member -type NoteProperty -name type -Value "movie"  -Force

                    $entry.movie | Add-Member -type NoteProperty -name query -Value $query  -Force
            
                    $trakt += $entry.movie

                    $traktignored_ += new-object psobject -property @{$entry.movie.title = @($entry.movie.title)}

                }
            }

    # handle ignored stuff

            if(-Not (Test-Path .\query.log -PathType Leaf)) {
                $fuck = $null
                $fuck | Export-Clixml -Path .\query.log  
            }

            $traktignored_old = Import-Clixml -Path .\query.log

            foreach($old in $traktignored_old){
        
                $oldtitle = $old  | Get-Member -MemberType NoteProperty | select -ExpandProperty Name

                $traktignored_ | Where-Object {( $_ | Get-Member -MemberType NoteProperty | select -ExpandProperty Name) -eq $oldtitle} |  % { $_.$oldtitle += $old.$oldtitle }
        
            }

            foreach($ignoredshow in $traktignored_){
    
                $shownames = $ignoredshow | Get-Member -MemberType NoteProperty | select -ExpandProperty Name

                    foreach($name in $shownames) {
                
                        $retries_ignoredshow = $ignoredshow.$name | group | Select -ExpandProperty Count

                        if($retries_ignoredshow -gt 5){
                            
                            $shows = @()

                            $movies = @()

                            #remove show from query.log to allow re-enabling the search for the show.

                            $traktignored_ | Where-Object {( $_ | Get-Member -MemberType NoteProperty | select -ExpandProperty Name) -eq $name} |  % {$_.$name = $null}

                            #add show to trakt ignored list to ignore it until user removes it from the list

                            $object = $trakt | Where-Object {$_.title -eq $name}

                            $object_ = $object.ids

                            $candidateProps = $object_.psobject.properties.Name

                            $nonNullProps = $candidateProps.Where({ $null -ne $object_.$_ })

                            $nonnullids = $object_ | Select-Object $nonNullProps

                            if ($object.type.Contains("movie")){

                                $ids= $nonnullids

                                $movie_id = @{"ids"= $ids}

                                $movies += $movie_id

                            }
        
                            if($object.type.Contains("tv")) {

                                $ids= $nonnullids 

                                $show_id = @{"ids"= $ids}

                                $shows += $show_id

                            }

                            $ignored_add = ConvertTo-Json -Depth 10 -InputObject @{
                                movies=$movies
                                shows=$shows
                            }

                            $post_ignored_add = Invoke-RestMethod -Uri "https://api.trakt.tv/users/me/lists/$ignored_list_id/items" -Method Post -Headers $Header -Body $ignored_add -SessionVariable traktsession

                        }

                    }
            }
      
            $traktignored_ | Export-Clixml -Path .\query.log  

            $trakt

            $traktignored

}

#$settings = Import-Clixml -Path C:\Users\Ronald\Desktop\ttrd\v3\settings.xml

#$trakt = trakt $settings