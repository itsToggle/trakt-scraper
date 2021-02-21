# Scraper Script
#
# the scraper functions recieve a trakt object with the properties title,year,ids(trakt,slug,tvdb,imdb,tmdb),type(tv,movie), and a lot more.
#


function scrape_torrents($object) {
    
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

    $query = $object.query #e.g. "The.Hobbit.2004" or "Breaking.Bad.S01E01"
    
    $tmdb = $object.ids.tmdb #tmdb ID

    $imdb = $object.ids.imdb #imdb ID

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

function scrape_hosters($object) {
    
    # the scrape_hosters function must return an object with the following properties:
    #      
    # title = Name of Torrent
    # files = Array of the contents filenames e.g. "title.s01e01.episode.title.mkv"
    # download = Array of the download links. Atm only one provider per download supported.
    #           
    # download must be a magnet link, not a torrent file. 
    # This is because the Script extracts the hash from the magnet link and explicitly posts a magnet link to the debrid services. 
    # 
    
    $query = $object.query #e.g. "The.Hobbit.2004" or "Breaking.Bad.S01E01"
    
    $tmdb = $object.ids.tmdb #tmdb ID

    $imdb = $object.ids.imdb #imdb ID 
        
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

#scrape_torrents $trakt[3]
