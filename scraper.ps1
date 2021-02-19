# Scraper Script
#
# the scraper function recieves a trakt object with the properties title,year,ids(trakt,slug,tvdb,imdb,tmdb),type(tv,movie), and a lot more.
#
# the scraper function must return an object with the following properties:
#      
# title = Name of Torrent
# seeders = Number of Seeders
# download = Magnet Link 
#           
# download must be a magnet link, not a torrent file. 
# This is because the Script extracts the hash from the magnet link and explicitly posts a magnet link to the debrid services. 
# 



function scrape_torrents($object) {

    $query = "The.Expanse.S04E01"#$object.query #e.g. "The.Hobbit.2004" or "Breaking.Bad.S01E01"
    
    $tmdb = $object.ids.tmdb #tmdb ID

    $imdb = $object.ids.imdb #imdb ID


    #rarbg
        #build the uri
        $uri = -join ('https://torrentapi.org/pubapi_v2.php?mode=search&search_string=', $query, '&category=52;51;50;49;48;45;44;41;17;14&token=lnjzy73ucv&format=json_extended&app_id=lol')
        #make the api call
        $response = Invoke-WebRequest $uri -SessionVariable rarbgsession | ConvertFrom-Json
        #output the required properties
        $response.torrent_results | select title,seeders,download

    #magnetdl
        #build the uri, replace "." in the query with "+", e.g. The+Expanse+S04E01
        #$uri = -join ('https://www.magnetdl.com/search/?q=', $query.Replace(".","+"), '&m=1&x=0&y=0')
        #make the api call
        #$response = Invoke-WebRequest $uri -SessionVariable rarbgsession
        #output the required properties, Turn HTML table into Powershell object (unfinished)
        #$response.ParsedHTML.getElementsByTagName('table')[0].innerHTML
        
}