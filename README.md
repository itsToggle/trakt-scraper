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
| ClicknLoad (DLC) functionality for manual filehoster downloads | :white_check_mark: |
| Cache Check (instant downloads) for RealDebrid and Premiumize | :white_check_mark: |
| If no cached torrent is found, filehosters are scraped | :white_check_mark: |
| If no cached torrent and no filehoster upload are found, the best quality torrent is added to RealDebrid | :white_check_mark: |
| RealDebrid is monitored for finished torrents in the background | :white_check_mark: |
| Season Pack support | :white_check_mark: |
| Partial Season Pack Support | :white_check_mark: |
| Customizable search exceptions (for date-formatted releases) | :white_check_mark: |
| Unraring of finished downloads | :white_check_mark: |
| WebUI | :white_check_mark: |
| [filehosters]: Integration of filecrypt.cc and similar container sites | :x: |
| [filehosters]: Perform an "alive test" before accepting release links | :x: |
| Prompt captchas that cant be bypassed to user | :x: |
| Console updates indepently from WebUI | :x: |
| Stop Scripts high RAM usage and random downloads after long runtime | :x: |

# Getting started:

0. **What You need:** 
    - A Trakt.tv Account
    - A Real Debrid Account is mandatory. Without it the script wont work. If you dont have one yet, create one here: http://real-debrid.com/?id=5708990
    - (Premiumize Account) This is optional. It will improve the chances of finding a chached torrent.
    - Aria2c
    - WinRar
1. **Trakt Preperation:**
    - Clean Up a little :)
    - *Everything* in your collection will be monitored for new episodes.
    - *Everything* in your watchlist (that isnt already in your collection) will be downloaded. 
2. **First Launch**:
    - The main script will ask for the needed inputs on the first start. You will need to connect it to Trakt.tv, your Debrid Services, Aria2c and WinRar.
    - You can find your Real-Debrid API key at: https://real-debrid.com/apitoken
3. **WebUI Setup**:
    - The Script runs a local WebUI. The local server needs a netsh command to function, which is explained in this post here: 
    - https://stackoverflow.com/questions/4019466/httplistener-access-denied/4115328.
    - The command in this case is: netsh http add urlacl url=http://+:8008/ user=YOUR-USERNAME-HERE
    - After all that is done, start the script and head over to "http://YOUR-PC-NAME-HERE:8008/". The consol window only updates if a Webrequest is recieved.
    
    

## Known Bugs:
        
        - If an upcoming episode was recently announced, trakt is a little slow with providing the release date. My current release wait merhod attempts to download it right away.
        - The Script crashes if you select text in the consol window. No idea why that is...
        - Special Characters. Ive tried to think of every Character that could pop up in a Movie/Show Title, but I could always miss one.
