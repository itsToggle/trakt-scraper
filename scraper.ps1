# Scraper Script
#
# the scraper functions recieve a query in the form of "The.Hobbit.2004" or "Breaking.Bad.S01E01"
#
# the scraper functions must return an object with the following properties:
#      
# title = Name of Torrent
# seeders = Number of Seeders
# download = Magnet Link 
#           
# download must be a magnet link, not a torrent file. 
# This is because the Script extracts the hash from the magnet link and explicitly posts a magnet link to the debrid services. 
# 



function scrape_torrents($query) {
    
    #rarbg
        #build the uri
        $uri = -join ('https://torrentapi.org/pubapi_v2.php?mode=search&search_string=', $query, '&category=52;51;50;49;48;45;44;41;17;14&token=lnjzy73ucv&format=json_extended&app_id=lol')
        #make the api call
        $response = Invoke-WebRequest $uri -SessionVariable rarbgsession | ConvertFrom-Json
        #output the required properties
        $response.torrent_results | select title,seeders,download

    #other scraper
        #build the uri
        #...
        #make the api call
        #...
        #output the required properties
        
}

