# trakt-scraper
A Powershell script to manage your media collection through trakt, with torrent scraping and debrid support.

![alt text](https://i.ibb.co/p2MT1VM/Screenshot-20210107-112846-Parsec.jpg)

- This script is not going to be maintained -

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
               
    4. trakt:
               - Downloaded content is added to the trakt collection
               - The watchlist is cleared.
