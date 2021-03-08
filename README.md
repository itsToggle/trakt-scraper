# Trakt-Scraper

A Powershell script to manage your media collection through trakt, with torrent/filehoster scraping and debrid support.

Im not a professional programmer. This script is only ment as a starting point for very bored people who want a completely costomizable alternative to radarr/sonarr/flexget.

## Disclaimer:
***Im not responsible for what content you download, as this script only has the capacity to act as a middle man between different services.
The script itself does not provide the ability search for media content. The script itself does not provide the ability to download media content. 
It only connects different services. This project is ment as a fun way to explore the programming of API's.***

## How it looks:

![alt text](https://i.ibb.co/ZN9Gkgy/Screenshot-20210217-112410-Chrome.jpg)

## Features:

| Feature |      State    |
| -------- | :------: |
| Entirely managed through Trakt.tv | :white_check_mark: |
| Sync collection and watchlist with Trakt.tv |  :white_check_mark: |
| Display time till release |  :white_check_mark: |
| Torrent Scraping [ rarbg, 1337x, magnetdl ]| :white_check_mark: |
| Filehoster Scraping [ hdencode ] | :white_check_mark: |
| Cache Check (instant downloads) for RealDebrid and Premiumize | :white_check_mark: |
| Background Monitoring of Realdebrid | :white_check_mark: |
| Season Pack support | :white_check_mark: |
| Partial Season Pack Support | :white_check_mark: |
| Customizable search exceptions (for date-formatted releases) | :white_check_mark: |
| Unraring of finished downloads | :white_check_mark: |
| WebUI | :white_check_mark: |
| Jacket/a4kscrapers integration | :x: |
| snahp.it/adit-HD integration | :x: |

# Getting started:

0. **What You need:** 
    - A Trakt.tv Account
    - A Real Debrid Account is mandatory. Without it the script wont work.
    - (Premiumize Account) This is optional. It will improve the chances of finding a chached torrent.
    - Aria2c
    - WinRar
1. **Trakt Preperation:**
    - Clean Up a little :)
    - *Everything* in your collection will be monitored for new episodes.
    - *Everything* in your watchlist (that isnt already in your collection) will be downloaded. 
2. **First Launch**:
    - The main script will ask for the needed inputs on the first start. You will need to connect it to Trakt.tv, your Debrid Services, Aria2c and WinRar.
3. **WebUI Setup**:
    - The Script runs a local WebUI. The local server needs a netsh command to function, which is explained in this post here: 
    - https://stackoverflow.com/questions/4019466/httplistener-access-denied/4115328.
    - The command in this case is: netsh http add urlacl url=http://+:8008/ user=YOUR-USERNAME-HERE
    - After all that is done, start the script and head over to "http://YOUR-PC-NAME-HERE:8008/". The consol window only updates if a Webrequest is recieved.
    

# The Script's Procedure:
1. **trakt:**
    - Your trakt collection is monitored for newly released content.
    - Your watchlist acts as a download queue for content you havent collected.
    
2. **queries for scraping:**
    - If new content is found, the following search queries are generated in the displayed order:
    - **movies**:
        - title.year
    - **shows**: 
        - title.SXX             (season pack releases)
        - title.year.SXX        (season pack releases)    
        - title.SXXEXX          (epsiode releases)
        - title.year.SXXEXX     (episode releases)
        - **to allow for date-formatted releases (or any other release-format) exceptions can be made that overwrite the standart search queries.**
                 
3. **scraping:**
    - **torrents**: for each search query, a scraper for rarbg, 1337x and magnetdl searches for the best quality/best seeded torrent
    - **filehosters**: If no torrent is found, hdencode.com is scraped for each search query
    
    - **movies**:
        - each movie release that was found by the scrapers is accepted.   
    - **shows**:
        - for each show release that was found by the scrapers, a filelist is compiled.
        - the filelists are scanned for filenames that contain an episode in the format: **SXXEXX**
            - *if a show is formatted via an exception, the filelists are ignored and all discovered releases are accepted.*
        - **If the scan contains the episode that is searched for and not the last episode that was collected, the release is accepted.** 
    
4. **debrid:** 
    - **torrents**:
        - Debrid Services (Real Debrid and Premiumize) are searched for a cached version of the scraped torrent
        - If a cached version is found, the direct download link gets send to Aria2c, a download manager
            - If no cached torrents are available, the best seeded torrent is added to RealDebrids download queue
            - **RealDebrid is monitored in the background. Once a torrent is available for direct download, the links are sent to Aria2c**
        - Once added to Aria2c the torrent is deleted from the Debrid Service.
        - **finished Downloads are unrar'ed**
        
    - **filehosters**:
        - Realdebird is used to unrestrict the filehoster links that were found by the filehoster scraper.
        - The direct download links are sent to Aria2c
        - **finished Downloads are unrar'ed**
      
5. **trakt:**
    - Downloaded content is added to the trakt collection. Season packs are collected by episode. This way partial season packs work flawlessly.
    - Downloaded content is removed from the watchlist.
    - **If no torrent/filehoster upload was found after 5 retries, the show/movie in question is added to a trakt list called "Ignored". Items in this playlist will not be scraped for.**

    

## Exceptions to Search-Queries:

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
    episode title   -  $episode_title     # e.g. an.episode.title, etc
    release year    -  $release_year      # e.g. 2021, 1996, etc
    release month   -  $release_month     # e.g. 01, 10, etc
    release day     -  $release_day       # e.g. 01, 13, etc
    
    Please do keep in mind that both the 'exceptions.txt' and the commands in it are executed. Beware of the commands you put in there.
    

## Known Bugs:
        
        - If an upcoming episode was recently announced, trakt is a little slow with providing the release date. My current release wait merhod attempts to download it right away.
        - The Script crashes if you select text in the consol window. No idea why that is...
        - Special Characters. Ive tried to think of every Character that could pop up in a Movie/Show Title, but I could always miss one.


## Future To-Do's
            
        - More filehoster scrapers. HDEncode.com is pretty much the best, but there are some forums that have more releases. These could be accessable if a username and password are provided by the user.
        - Maybe Add Scraper Support for Services like: Jacket, a4kscrapers,.. I will probaply stick with my own format.
        - I cant get the Console to update indepently from the WebUI.
        - Premiumize *is* currently searched for chached torrents, but torrents that arent cached are only added to RealDebrid and *not* Premiumize.
