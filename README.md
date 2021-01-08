# trakt-scraper

A Powershell script to manage your media collection through trakt, with torrent scraping and debrid support.

This script is not going to be maintained. Im not a professional programmer. This script is only ment as a starting point for very bored people who want a completely costomizable alternative to radarr/sonarr/flexget.

Powershell UI:

![alt text](https://lh3.googleusercontent.com/taE-pNtYfs6TXtQeFcHc5a1rhvqvy4_4PDWd_xXDcj8bQjyFhZd8pBljJ9xIhoh0Wdaal_UG3ToUtFbGM8g55Dwsz-v_pocqg12c24VgYT8SpTNK885A4o-Ya6XzbdN17tnOa-j8UgZvxd2g5zVUookeqH7LOFGiiDO3bfK3AhtS_8QlpazXYYkVI4o2wNzbTTF3WILfx51ADUEoRK4FbypTTefrP5CPjvgUzTSEr_16wBpWCVJStkBxdTp7q1w1vR24QS-CusI3RIyLn6YhT9bE_mPWdqtDPYKPpNbnKBRQbZtO16s7Mgykiiz3irmunUbGkLn8SrjNJgnCFRtAX_RC9IkoT_ANZeyQNivrgF6ftr6n5WD0kxIgG6jPbSH3UB8X3eR9Jte696yhS98JVemADLbffFagVDL40VeeIBYDTmOhUo0eIvXnZd-uIrdYGgiXnGQVJhAZFaozEhUCo8_6cTVw-rzQbXQpLzraVdcoHOPWrdBkEPBrTnUuEO4m3HrrLaCLVRDxdRx5wRnTygOcyPVmS_UH9gPOFePzAz9utgkSk1xmSHkTxKpavAYU1pBN5JEghC_9bnn7usftLDPIXl8JBP-XEaTjFcmOhzn9077fg3orRDzKfVZf7o_7bY4H6CreVpCf3s8bK2k3QgwZ16-gIMWD3JDUQHzcQEYREye5HnvGXydkjiNE9Q=w1354-h863-no?authuser=0)

WebUI:

![alt text](https://lh3.googleusercontent.com/k66CfSLDX42_3it0xwDR4CcTwOMW4qdnbXaDjqU1SkWzTUjYzcv-i-dQeBdi8l7-8ibjqS9OhRVMZ8FfqC3coAgislMBOuGfdhK2qVo169K3D75V7X5zy5uQrtBrVol3UKj1eDbRk3Rh9pnmeow-0pTX1uZdq1UscXSo7AGkwV01ouye7s9E_epDUaH5Vv4Kb0RmxVrikK-jbRe-bIOz0JQ67ZnQQqv1W8JJTEFaLwPr9pr_6R-rC5Y7mQgZYhFFdzL5MUyhOepgWrVnyAcZqhG8u8aTBid2pw5O05qD_8zIK2VHZqVA1aiAsBUcyUwW5D5OmMnJrHj85_FYPfWfjfLWLT_3p2d4ZhhElK2GIE4lieal3T3t2Fc_axKOSXAePDs3CUz5LoACrzKieIFm2NZlbfrOZ7_bK3QOIu3xE6JkLvOLSK69vmRgi6oEFU3HIZAcERFYWuuLzr5pt5Xa-O2rGGtKsN3xKddn2MatZGZ5_ezboCv03t6i9EXxYwqqXapsDWeWVprIUV296OQxb9eo6fHaCmjYAhQ0FcvMMyEudNRpZWjMGREFpGlYFTR0j32nbvSBBFCD-oa3kNbU2Xgt34TtUWLIEijO2ji3bIuFhO2la7IUwMkConVaEbqRy2catbQUfbybXifpbY8UGdJy9PKmwve7e7Pzv2c8W0Zc1aY8oYHRt6ZSrRFJSA=w1354-h867-no?authuser=0)

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
