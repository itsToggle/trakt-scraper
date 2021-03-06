# trakt-scraper

A Powershell script to manage your media collection through trakt, with torrent and filehoster scraping and debrid support.

This script is not going to be maintained. Im not a professional programmer. This script is only ment as a starting point for very bored people who want a completely costomizable alternative to radarr/sonarr/flexget.



What it does:
    
    1. trakt:
               - Your trakt collection is monitored for newly released content.
               - Your watchlist acts as a download queue for content you havent collected.
    
    2. queries for scraping:
               - If new content is found, search queries for the scrapers are generated:
               - for movies the query is:
                    - title.year
               - for shows, the following standard search queries are generated in the displayed order:
                    - title.SXX             (season pack releases)
                    - title.year.SXX        (season pack releases)    
                    - title.SXXEXX          (epsiode releases)
                    - title.year.SXXEXX     (episode releases)
               - to allow for date-formatted releases (or any other release-format) exceptions can be made that overwrite the standart search queries.
                 
    3. scraping:
               - torrents: for each search query, a scraper for rarbg, 1337x and magnetdl searches for the best quality/best seeded torrent
               - filehosters: If no torrent is found, hdencode.com is scraped for each search query
               
               - The scrapers search for season packs first. If a season pack is found, its filelist is compiled.
               - If the filelist contains the episode that is searched for and not the last episode that was collected, the release is accepted. 
                 (This way partial season packs work as well as full season packs.)
               - If no season pack is found, the scrapers search for episode releases.
    
    4. debrid: 
               - Debrid Services (Real Debrid and Premiumize) are searched for a cached version of the scraped torrent
               - If a cached version is found, the direct download link gets send to Aria2c, a download manager
               - If no cached torrents are available, the best seeded torrent is added to a debrid service's download queue
               - The download is monitored in the background. Once its available for direct download, it gets send to Aria2c
               - Once added to Aria2c the torrent is deleted from the Debrid Service.
               - finished Downloads are unrar'ed
               
    5. trakt:
               - Downloaded content is added to the trakt collection. Season packs are collected by episode. This way partial season packs work flawlessly.
               - Downloaded content is removed from the watchlist.

    
Getting started:

    0. What You need: 
            - A Trakt.tv Account
            - A Real Debrid Account is mandatory. Without it the script wont work.
            - (Premiumize Account) This is optional. It will improve the chances of finding a chached torrent.
            - Aria2c
            - WinRar
    1. Trakt Preperation:
            - Clean Up a little :)
            - Everything in your collection will be monitored for new episodes.
            - Everything in your watchlist (that isnt already in your collection) will be downloaded. 
    2. First Launch:
            - The main script will ask for the needed inputs on the first start. You will need to connect it to Trakt.tv, your Debrid Services, Aria2c and WinRar.
    3. WebUI Setup:
            - The Script runs a local WebUI. The local server needs a netsh command to function, which is explained in this post here: 
            - https://stackoverflow.com/questions/4019466/httplistener-access-denied/4115328.
            - The command in this case is: netsh http add urlacl url=http://+:8008/ user=YOUR-USERNAME-HERE
            - After all that is done, start the script and head over to "http://YOUR-PC-NAME-HERE:8008/". The consol window only updates if a Webrequest is recieved.
    

Exceptions:

    The Script now allows for exceptions to be made to the search queries of shows. 
    
    The standard search queries are:
    title.SXX
    title.year.SXX
    title.SXXEXX
    title.year.SXXEXX
    
    If a show cannot be found with these queries, define an exception:
    
    After the first proper run of the script, 'exceptions.txt' is created. This file contains a few examples on how to use this feature.
    
    Take for example "The Tonight Show starring Jimmy Fallon". This show is released in the format "Jimmy.Fallon.Year.Month.Day".
    So neither the title nor the episode format matches the standard search queries.
    To allow the scrapers to find the show in this format, an executable string is provided in the 'exceptions.txt' under the shows trakt name.
    The executable string in this case is: $show.query = -join("Jimmy.Fallon",".",$release_year,".",$release_month,".",$release_day)
    Which translates to the following query (example): Jimmy.Fallon.2021.03.02
    
    If a trakt show matches one of the titles in the exceptions.txt, the query is overwritten.
    
    To add new exceptions, just add them directly to the exception.txt file. Stick with the format shown in the examples. 
    
    The variables currently available are:
    
    episode         -  $show_next_episode # e.g. 01, 13, etc
    season          -  $show_next_season  # e.g. 01, 13, etc
    season title    -  $season_title      # e.g. a.season.title, etc
    episode title   -  $episode_title     # e.g. an.pisode.title, etc
    release year    -  $release_year      # e.g. 2021, 1996, etc
    release month   -  $release_month     # e.g. 01, 10, etc
    release day     -  $release_day       # e.g. 01, 13, etc
    
    Please do keep in mind that both the 'exceptions.txt' and the commands in it are executed. Beware of the commands you put in there.
    
WebUi:

![alt text](https://i.ibb.co/ZN9Gkgy/Screenshot-20210217-112410-Chrome.jpg)

Log:

![alt text](https://i.ibb.co/7Cn0KXn/Screenshot-20210223-090840-Chrome.jpg)
![alt text](https://i.ibb.co/r3zQH8D/Screenshot-20210223-090519-Chrome.jpg)


Known Bugs:
        
        - If an upcoming episode was recently announced, trakt is a little slow with providing the release date. My current release wait merhod attempts to download it right away.
        - The Script crashes if you select text in the consol window. No idea why that is...
        - Special Characters. Ive tried to think of every Character that could pop up in a Movie/Show Title, but I could always miss one.


Future To-Do's
            
        - More filehoster scrapers. HDEncode.com is pretty much the best, but there are some forums that have more releases. These could be accessable if a username and password are provided by the user.
        - Maybe Add Scraper Support for Services like: Jacket, a4kscrapers,.. I will probaply stick with my own format.
        - I cant get the Console to update indepently from the WebUI.
        - Premiumize *is* currently searched for chached torrents, but torrents that arent cached are only added to RealDebrid and *not* Premiumize.
