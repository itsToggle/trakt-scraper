# Trakt Sync Script
#
# Collects content and clears the watchlist

function sync($reference, $settings) {

    $trakt_client_id = $settings.trakt_client_id
    $trakt_client_secret = $settings.trakt_client_secret
    $trakt_access_token = $settings.trakt_access_token
    $real_debrid_token = $settings.real_debrid_token
    $premiumize_api_key = $settings.premiumize_api_key
    $path_to_downloads = $settings.path_to_downloads

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
            
    $collection_add = ConvertTo-Json -Depth 10 -InputObject @{
        seasons=$seasons
        shows=$shows_
        movies = $movies
    }

    Sleep 1
                    
    $post_collection_add = Invoke-RestMethod -Uri "https://api.trakt.tv/sync/collection" -Method Post -Body $collection_add -Headers @{"Content-type" = "application/json";"trakt-api-key" = "$trakt_client_id";"trakt-api-version" = "2";"Authorization" = "Bearer $trakt_access_token"}  -WebSession $traktsession
            
    $reference.status = 1

}