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
    
    3. debrid: 
               - Debrid Services (Real Debrid and Premiumize) are searched for a cached version of the scraped torrent
               - If a cached version is found, the direct download link gets send to Aria2c, a download manager
               - If no cached torrents are available, the best seeded torrent is added to a debrid service's download queue
               - The download is monitored in the background. Once its available for direct download, it gets send to Aria2c
               - Once added to Aria2c the torrent is deleted from the Debrid Service.
               
    4. trakt:
               - Downloaded content is added to the trakt collection
               - The watchlist is cleared.

(Update 18.02.21): 
    - Ive added a bit of UI to the setup so its easier to understand.
    - The Script will ask for the needed inputs on the first start. You will need to connect it to Trakt.tv, your Debrid Services and Aria2c.
    - The Script runs a local WebUI. The local server needs a netsh command to function, which is explained in this post here: 
    - https://stackoverflow.com/questions/4019466/httplistener-access-denied/4115328.
    - The command in this case is: netsh http add urlacl url=http://+:8008/ user=YOUR-USERNAME-HERE
    - After all that is done, start the script and head over to "http://YOUR-PC-NAME-HERE:8008/". The consol window only updates if a Webrequest is recieved.
    
WebUi:

![alt text](https://i.ibb.co/9wVss8n/Screenshot-20210217-105536-Chrome.jpg)

![alt text](https://i.ibb.co/kS3Q7Yt/Screenshot-20210217-112410-Chrome.jpg)
