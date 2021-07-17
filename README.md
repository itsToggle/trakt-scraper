# Trakt-Scraper

A Powershell script to manage your media collection through trakt, with torrent/filehoster scraping and RealDebrid integration.

Im not a professional programmer. This script is only ment as a starting point for very bored people who want a completely costomizable alternative to radarr/sonarr/flexget.

## Disclaimer:
***Im not responsible for what content you download, as this script only has the capacity to act as a middle man between different services.
The script itself does not provide the ability search for media content. The script itself does not provide the ability to download media content. 
It only connects different services. This project is ment as a fun way to explore the programming of API's. The pictures shown here are merely examples 
of how the WebUI might look and are fabricated by inserting example text into the html files.***

## How it looks:

![alt text](https://i.ibb.co/W0mdVYg/Screenshot-2021-07-17-160007.png)
![alt text](https://i.ibb.co/yXSVb7R/Screenshot-2021-07-17-161717.png)
![alt text](https://i.ibb.co/DCwchD1/Screenshot-2021-07-17-160029.png)
![alt text](https://i.ibb.co/8DPXHrC/Screenshot-2021-07-17-155950.png)

# How it works:

**1) Trakt:**
  - Your Trakt Collection is monitored for new Content.
  - Your Trakt Watchlist is monitored for content that you havent collected.

**2) Scraper:**
  - If new content is found, selected Torrent and Filehoster sources are scraped.
  - Releases are checked for instant availability
     - If instant available releases are found, the best release (according to the Ranking settings) is directly downloaded.
     - If no instant available releases are found, the best uncached release (according to the Ranking settings) is added to RealDebrid.
  - Once an uncached release has finished downloading on RealDebrid, it is directly downloaded.

**3) Trakt:**
  - Content is marked as collected

# Getting started:

0. **What You need:** 
    - A Trakt.tv Account
    - A Real Debrid Account is mandatory. Without it the script wont work. If you dont have one yet, create one here: http://real-debrid.com/?id=5708990
    - Aria2c
    - WinRar
1. **Trakt Preperation:**
    - Clean Up a little :)
    - *Everything* in your collection will be monitored for new episodes.
    - *Everything* in your watchlist (that isnt already in your collection) will be downloaded. 
2. **First Launch**:
    - The main script will ask for the needed inputs on the first start. You will need to connect it to Trakt.tv, your Debrid Services, Aria2c and WinRar.
    - You can find your Real-Debrid API key at: https://real-debrid.com/apitoken
3. **After all that is done, start the script and head over to "http://YOUR-PC-NAME-HERE:8008/".**
