# Scraper Script
#
# the scraper functions recieve a query. e.g. "The.Hobbit.2004" or "Breaking.Bad.S01E01"
#

function scrape_magnets($query) {
    
    # the scrape_torrents function must return an object with the following properties:
    #      
    # title = Name of Torrent
    # seeders = Number of Seeders
    # download = Magnet Link 
    #           
    # download must be a magnet link, not a torrent file. 
    # This is because the Script extracts the hash from the magnet link and explicitly posts a magnet link to the debrid services. 
    # 

    $apidown = $true

    $retries = 0

    #
    # enable or disable the scrapers you want:
    #

    $rarbg = $true

    $magnetdl = $false

    $1337x = $false


    #
    # Scrapers:
    #



    #rarbg
    if($rarbg){ 
        #the "do while" is because rarbgs api is unreliable.
        do{
            #build the uri
            $uri = -join ('https://torrentapi.org/pubapi_v2.php?mode=search&search_string=', $query, '&category=52;51;50;49;48;45;44;41;17;14&token=lnjzy73ucv&format=json_extended&app_id=lol')
            #make the api call
            $response = Invoke-WebRequest $uri -SessionVariable rarbgsession | ConvertFrom-Json
            $rarbg = $response.torrent_results | select title,seeders,download
            
            if($response.torrent_results -eq $null){
                sleep 2
                $retries ++
            }else{
                $apidown = $false
            }

        }while($apidown -and $retries -le 3)

        #output the required properties
        $rarbg | select title,seeders,download
    }

    #magnetdl
    if($magnetdl){
        #build the uri, replace "." in the query with "+", e.g. The+Expanse+S04E01
        $uri = -join ('https://www.magnetdl.com/search/?q=', $query.Replace(".","+"), '&m=1&x=0&y=0')
        #make the api call
        $response = Invoke-WebRequest $uri -SessionVariable rarbgsession
        #Turn HTML table into Powershell object
        $rows = $response.ParsedHTML.getElementsByTagName('table')[0].rows
        $magnetdl = new-object system.collections.arraylist 
        foreach($row in $rows) {
            $download = [regex]::matches($row.InnerHTML, "(magnet).*?(?=`")").value
            $title = [regex]::matches($row.InnerHTML, "(?<=<TD class=n><A title=).*?(?= href)").value
            $seeders = [regex]::matches($row.InnerHTML, "(?<=<TD class=s>).*?(?=</TD>)").value
            if($title -ne $null){
                $item = new-object psobject -property @{title=($title.Replace('"','') -replace(' ',''));download=$download;seeders=[int]$seeders}                           
                $magnetdl += $item
            }
        }
        #Output the required properties
        $magnetdl | select title,seeders,download
    }
        
    #1337x
    if($1337x){
        #build the uri
        $uri = -join ('https://1337x.to/srch?search=', $query)
        #make the api call
        $response = Invoke-WebRequest $uri -SessionVariable rarbgsession
        #Turn HTML table into Powershell object
        $rows = $response.ParsedHTML.getElementsByTagName('table')[0].rows | select -skip 1
        $1337x = new-object system.collections.arraylist 
        foreach($row in $rows) {
            #1337x has the magnet link on a subpage
            $subpage = [regex]::matches($row.Cells[0].innerHTML, "(?<=<a href=`").*?(?=`")").value
            $title = $row.Cells[0].innerText -replace('â','') #fucky
            $seeders = $row.Cells[1].innerText 
            if($subpage -ne $null){
                $subpage = -join ('https://1337x.to', $subpage)
                $responsesubpage = Invoke-WebRequest $subpage -SessionVariable rarbgsession
                $download = [regex]::matches($responsesubpage.ParsedHtml.body.innerHTML, "(magnet).*?(?=`")").value[0]
                $item = new-object psobject -property @{title=($title.Replace('"','') -replace(' ',''));download=$download;seeders=[int]$seeders}                           
                $1337x += $item
            }
        }
        #Output the required properties
        $1337x | select title,seeders,download
    }

    #other scraper
        #build the uri
        #...
        #make the api call
        #...
        #Output the required properties
        #...
}

function scrape_hosters($query) {
    
    # the scrape_hosters function must return an object with the following properties:
    #      
    # title = Name of Torrent
    # files = Array of the contents filenames e.g. "title.s01e01.episode.title.mkv"
    # download = Array of the download links. Atm only one provider per download supported.
    #           
    # download must be a magnet link, not a torrent file. 
    # This is because the Script extracts the hash from the magnet link and explicitly posts a magnet link to the debrid services. 
    # 
    
        
    #hdencode
        #build the uri
        $uri = -join ('https://hdencode.com/?s=', $query)
        #make the api call
        $response = Invoke-WebRequest $uri -SessionVariable rarbgsession
        #The links are in subpages
        $querysubpage = $query.replace('.','-')
        $response = $response.ParsedHTML.body.getElementsByClassName("item_2 items")[0].innerHTML
        $subpages = [regex]::matches($response, "(https://hdencode.com/$querysubpage).*?(?=`")", "IgnoreCase").value | Select -Unique
        $hdencode = new-object system.collections.arraylist
        foreach($page in $subpages) {
            #the links are hidden behind some recaptcha shit. This is easily circumvented with a little use of fiddler. The precise post request can be captured this way.
            $token = Invoke-WebRequest $page -SessionVariable rarbgsession
            #first get the required tokens from the blocked webpage
            $form = $token.ParsedHTML.forms | Where-Object {[regex]::matches($_.id, "(content-protector).*?")}
            $body = -join("content-protector-captcha=",$form[0].Value,"&content-protector-token=",$form[1].Value,"&content-protector-ident=",$form[2].Value,"&g-recaptcha-response=",$form[3].Value,"&content-protector-submit=Access+the+links&maZQ-D=Mqy%5B67&IAwfYR_ghPQtnk=B36jCD7hq%5DJ%40x9&maZQ-D=Mqy%5B67&IAwfYR_ghPQtnk=B36jCD7hq%5DJ%40x9")
            #then post those tokens back to the webpage to unblock :)
            $unrestrict = Invoke-WebRequest $page -Method Post -Body $body -SessionVariable rarbgsession
            $files = [regex]::matches($unrestrict.ParsedHtml.body.innerText, "(?<=Filename\.*: ).*", "IgnoreCase").value
            $title = @($unrestrict.ParsedHtml).title.Split()[0]
            $parts = @($unrestrict.ParsedHtml.Links).href -match 'rapidgator' #if you prefer nitroshare, go ahead and change this.
            $item = new-object psobject -property @{title=($title.Replace('"','')); download = $parts; files = $files}
            $hdencode += $item
            Sleep 1
        }
        #Output the required properties
        $hdencode
   
    #other scraper
        #build the uri
        #...
        #make the api call
        #...
        #Output the required properties
        #...
}

function torrent($object, $settings){
     
     $scraper = new-object system.collections.arraylist 

     Foreach($query in $object.query) {

        $text = -join("(traktscraper) scraping torrents: ", $query)

        Write-Output $text

        $items = scrape_magnets $query

        Foreach ($item in $items) {
                            
            $title = $item.title
                            
            $quality = [regex]::matches($title, "(1080)|(720)|(2160)").value 
                            
            $download = $item.download
                            
            $seeders = $item.seeders
                            
            $hash = [regex]::matches($download, "(?<=btih:).*?(?=&)").value
                            
            if ([regex]::matches($title, "($query\.)", "IgnoreCase").value  -And -Not [regex]::matches($title, "(REMUX)|(\.3D\.)", "IgnoreCase").value) {
                                            
                if($object.download_type -ne "movie") {
                
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

                    $retries_ = 0

                    sleep 1

                    while( $torrent_status -eq "magnet_conversion" -and $retries_ -le 1){
                        $retries_++
                        Sleep 2
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
                                
                }

                if($object.download_type -eq "movie") {

                    $scraper += new-object psobject -property @{title=$title;quality=[int]$quality;category=$category;magnets=$download;seeders=[int]$seeders;imdb=$imdb;hashes=$hash;files=$files}

                }elseif(@($files.season).Contains($object.next_season) -and @($files.episode).Contains($object.next_episode)){
                
                    $text = -join("(traktscraper) result contains next episode: ", $item.title)

                    Write-Output $text

                    $scraper += new-object psobject -property @{title=$title;quality=[int]$quality;category=$category;magnets=$download;seeders=[int]$seeders;imdb=$imdb;hashes=$hash;files=$files}
                                
                }

                Sleep 1
            }

        }

        if($scraper -ne $null){
            break
        }
    
    }

    $scraper = $scraper | Sort-Object -Property quality,seeders -Descending

    $object.scraper += @( $scraper )

    $object.scraper | Format-Table

    $object.status = 2

    Sleep 5

}

function hoster($object) {
     
     $scraper = new-object system.collections.arraylist 
     
     Foreach($query in $object.query) {

        $text = -join("(traktscraper) scraping hosters: ",$query)

        Write-Output $text
     
        $items = scrape_hosters $query

        Foreach ($item in $items) {
                            
            $title = $item.title
                            
            $quality = [regex]::matches($title, "(1080)|(720)|(2160)").value 
                            
            $download = $item.download
                                                        
            if ([regex]::matches($title, "($query\.)", "IgnoreCase").value  -And -Not [regex]::matches($title, "(REMUX)|(\.3D\.)", "IgnoreCase").value) {
                                            
                if($object.download_type -ne "movie") {
                
                    $files = @()

                    $filestext = [regex]::matches($item.files, "(S[0-9].E[0-9].)", "IgnoreCase").value

                    foreach($file in $filestext){
                        $season = [int][regex]::matches($file, "(?<=S)..?(?=E)", "IgnoreCase").value
                        $episode = [int][regex]::matches($file, "(?<=E)..?", "IgnoreCase").value
                        $files += new-object psobject -property @{season=$season;episode=$episode}
                    }
                                
                }

                if($object.download_type -eq "movie") {

                    $scraper += new-object psobject -property @{title=$title;quality=[int]$quality;hoster=$download;files=$files}

                }elseif(@($files.season).Contains($object.next_season) -and @($files.episode).Contains($object.next_episode)){
                
                    $text = -join("(traktscraper) result contains next episode: ", $item.title)

                    Write-Output $text

                    $scraper += new-object psobject -property @{title=$title;quality=[int]$quality;hoster=$download;files=$files}

                    $object.files = $files
                                
                }

                Sleep 1
            }

        }

        if($scraper -ne $null){
            break
        }

    }

    $scraper = $scraper | Sort-Object -Property quality -Descending

    $object.scraper += @( $scraper )

    $object.scraper | Format-Table

    $object.status = 2

    Sleep 5
}
