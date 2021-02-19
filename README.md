# trakt-scraper

A Powershell script to manage your media collection through trakt, with torrent scraping and debrid support.

This script is not going to be maintained. Im not a professional programmer. This script is only ment as a starting point for very bored people who want a completely costomizable alternative to radarr/sonarr/flexget.



What it does:
    
    1. trakt:
               - Your trakt collection is monitored for newly released content.
               - Your watchlist acts as a download queue for content you havent collected.
    
    2. rarbg:
               - If new content is found, a scraper for rarbg.to searches for the best quality/best seeded torrent
               - If a season of a tv show is fully released, season packs are prefered.
               - Releases that contain partial seasons (e.g. title.S01.Part1) are now fully supported
    
    3. debrid: 
               - Debrid Services (Real Debrid and Premiumize) are searched for a cached version of the scraped torrent
               - If a cached version is found, the direct download link gets send to Aria2c, a download manager
               - If no cached torrents are available, the best seeded torrent is added to a debrid service's download queue
               - The download is monitored in the background. Once its available for direct download, it gets send to Aria2c
               - Once added to Aria2c the torrent is deleted from the Debrid Service.
               
    4. trakt:
               - Downloaded content is added to the trakt collection
               - The watchlist is cleared.

    
    
    Getting started:
        - Ive added a bit of UI to the setup so its easier to understand.
        - The Script will ask for the needed inputs on the first start. You will need to connect it to Trakt.tv, your Debrid Services and Aria2c.
        - The Script runs a local WebUI. The local server needs a netsh command to function, which is explained in this post here: 
        - https://stackoverflow.com/questions/4019466/httplistener-access-denied/4115328.
        - The command in this case is: netsh http add urlacl url=http://+:8008/ user=YOUR-USERNAME-HERE
        - After all that is done, start the script and head over to "http://YOUR-PC-NAME-HERE:8008/". The consol window only updates if a Webrequest is recieved.
    
WebUi:

![alt text](https://i.ibb.co/9wVss8n/Screenshot-20210217-105536-Chrome.jpg)

![alt text](https://i.ibb.co/kS3Q7Yt/Screenshot-20210217-112410-Chrome.jpg)

Programming Stuff:

        -The Script first checks if the params.xml file is present in the current dir.
            -If not, the first launch setup is started. The user inputs are saved in the params.xml file.
        -The params.xml is imported.
        -Aria2c is launched as a Background Job.
        -The Trakt Scraper is started as a Background Job.
            -New content is determined with an API call to trakt.tv
                -The trakt "collection" is searched for upcoming or newly released episodes. These are processed further.
                -The trakt "watchlist" is compared to the collection. Everything that isnt collected is processed further.
            -If the as "new" determined content is released, it is written out as a search query
                -If the content is a movie, the query is in format: Title.Year (Movie)
                -If a season is fully released, the query is in format: Title.S01 / Title.Year.S01 (Season Pack)
                -If a season isnt fully released, the query is in format: Title.S01E01 / Title.Year.S01E01 (Episode)
            -An API call to rarbg.to's API is made with the query
            -The response is sorted by video quality and seeders
                -An API call to magnets2torrents.com is made to gather the torrents file lists.
                -If an episode cant be found, a fallback to search for a season pack containing the episode is made.
            -An API call to the debrid services is made for each torrent (or magnet link to be more precise)
            -If one of the torrents is cached, the direct links are send to Aria2c via an API call
                -The trakt collection is updated with the newly downloaded content.
                -Seasons Packs are collected by the episodes found in the torrents file list
            -If none are chached, the best quality torrent is added to the debrid services for cloud download
                -The trakt collection is updated with the new content.
                -Seasons Packs are collected by the episodes found in the torrents file list
            -The debrid services are periodically checked for finished torrents via an API call
            -If a torrent is finished, the direct links are sent to Aria2c via an API call.
            -Finished torrents are removed from the debrid services
        -The HTML Server is started
            -A "GET" request is recieved
                - The Output from the Trakt Scraper Background Job is displayed as a Table
                - An API call to Aria2c is made to get information on waiting/running/finished downloads
                - The Output is displayed as a Table
                - An API call to RealDebrid is made to get information on waiting/running/finished torrents
                - The Output is displayed as a Table
                - The Function "tohtml" is called
                    - This turns everything currently displayed on the console window into an html format
                    - A Header is added that tells the website to refresh itself every 5 seconds. This means a new Get request is sent every 5s.
                - The html formatted string is sent to the recipient.


Future To-Do's
        
        - With the support for partial season packs came a high dependency on the "magnets2torrents" website. I might change this to realdebrids' file list API call
        - I cant get the Console to update indepently from the WebUI.
        - Only Rarbg is currently scraped
        - Premiumize *is* currently searched for chached torrents, but torrents that arent cached are only added to RealDebrid and *not* Premiumize.
