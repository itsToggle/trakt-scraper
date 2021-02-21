# trakt-scraper

A Powershell script to manage your media collection through trakt, with torrent and filehoster scraping and debrid support.

This script is not going to be maintained. Im not a professional programmer. This script is only ment as a starting point for very bored people who want a completely costomizable alternative to radarr/sonarr/flexget.



What it does:
    
    1. trakt:
               - Your trakt collection is monitored for newly released content.
               - Your watchlist acts as a download queue for content you havent collected.
    
    2. torrent scraping:
               - If new content is found, a scraper for rarbg, 1337x and magnetdl searches for the best quality/best seeded torrent
               - If a season of a tv show is fully released, season packs are prefered.
               - Releases that contain partial seasons (e.g. title.S01.Part1) are now fully supported
    
    2.5. Filehoster scraping:
               - If no torrent is found, hdencode.com gets scraped for a matching filehoster upload
               - The downloads arent currently unrar'ed after download.
               - Multihoster download is not yet supported.
               - I might add a switch so you can choose to only download from one source.
    
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

    0. What You need: 
            - A Trakt.tv Account
            - A Real Debrid Account is mandatory. Without it the script wont work.
            - (Premiumize Account) This is optional. It will improve the chances of finding a chached torrent.
            - Aria2c
    1. Trakt Preperation:
            - Clean Up a little :)
            - Everything in your collection will be monitored for new episodes.
            - Everything in your watchlist (that isnt already in your collection) will be downloaded. 
    2. First Launch:
            - The main script will ask for the needed inputs on the first start. You will need to connect it to Trakt.tv, your Debrid Services and Aria2c.
    3. WebUI Setup:
            - The Script runs a local WebUI. The local server needs a netsh command to function, which is explained in this post here: 
            - https://stackoverflow.com/questions/4019466/httplistener-access-denied/4115328.
            - The command in this case is: netsh http add urlacl url=http://+:8008/ user=YOUR-USERNAME-HERE
            - After all that is done, start the script and head over to "http://YOUR-PC-NAME-HERE:8008/". The consol window only updates if a Webrequest is recieved.
    
    
WebUi:

![alt text](https://i.ibb.co/ZN9Gkgy/Screenshot-20210217-112410-Chrome.jpg)

Future To-Do's
        - More filehoster scrapers. HDEncode.com is pretty much the best, but there are some forums that have more releases. These could be accessable if a username and password are provided by the user.
        - Maybe Add Scraper Support for Services like: Jacket, a4kscrapers,.. I will probaply stick with my own format.
        - I cant get the Console to update indepently from the WebUI.
        - Premiumize *is* currently searched for chached torrents, but torrents that arent cached are only added to RealDebrid and *not* Premiumize.
