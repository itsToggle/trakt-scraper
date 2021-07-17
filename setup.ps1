# Initialization Script

function setup {

    $Header = @{
        "Content-type" = "application/json"
        "trakt-api-key" = "$trakt_client_id"
        "trakt-api-version" = "2"
        "Authorization" = "Bearer $trakt_access_token"
    
    }
    
    $trakt_client_id = "bf93b45f96cd6ed2d0217d660f36ebd8f4337446a875b53a1f9332a326ef61ea"
    
    $trakt_client_secret = "cc6051d03aa726c9a98019d661be891c23b6a96db0e2a7c53a8fc433f080bbc4"

    $get_token = ConvertTo-Json -InputObject @{
        client_id = $trakt_client_id
    }
   
    $get_token_response = Invoke-RestMethod -Uri "https://api.trakt.tv/oauth/device/code" -Method Post -Body $get_token -Headers $Header

    clear

    Write-Host "                                                  
                                                  
                                                  
                   ((((((((((((,                  
                /(((*        .((((                
             .((((,             (((               
           ((((.       Rain      (((/             
          (((                    //((((/          
          (((      (((      (((      /((,         
          *(((     ((( ,((/ (((      (((          
            *((((  ((( ,((/ (((  (((((/           
                   ((( ,((/ (((                   
                       ,((/                       
                       ,((/                       
                                                  
                                                  "
    
    Write-Host

    Read-Host -Prompt 'The program needs to be connected to Trakt.tv. Pess Enter to continue'

    Write-Host "Connect the Script to Trakt. Go to  trakt.tv/activate and within 60 seconds enter the code:" $get_token_response.user_code 

    $device_code = $get_token_response.device_code

    $poll_token = ConvertTo-Json -InputObject @{
        code = $device_code
        client_id = $trakt_client_id
        client_secret = $trakt_client_secret
    }

    $http_valid_response = $false

    while(-Not $http_valid_response) {
        
        $http_valid_response = $true

        sleep $get_token_response.interval

        try { 
    
            $poll_token_response = Invoke-RestMethod -Uri "https://api.trakt.tv/oauth/device/token" -Method Post -Body $poll_token -Headers $Header
    
        } catch {
        
        $http_valid_response = $false

        }   
    }

    clear

    Write-Host "                                                  
                                                  
                                                  
                   ((((((((((((,                  
                /(((*        .((((                
             .((((,             (((               
           ((((.       Rain      (((/             
          (((                    //((((/          
          (((      (((      (((      /((,         
          *(((     ((( ,((/ (((      (((          
            *((((  ((( ,((/ (((  (((((/           
                   ((( ,((/ (((                   
                       ,((/                       
                       ,((/                       
                                                  
                                                  "
    
    Write-Host

    Write-Host "Successfully connected to Trakt!" 
    
    $trakt_access_token = $poll_token_response.access_token

    Write-Host

    Write-Host "The program needs to be connected to RealDebrid."

    Write-Host

    $real_debrid_token = Read-Host -Prompt 'Real Debrid - enter your API token (https://real-debrid.com/apitoken)'

    clear

    Write-Host "                                                  
                                                  
                                                  
                   ((((((((((((,                  
                /(((*        .((((                
             .((((,             (((               
           ((((.       Rain      (((/             
          (((                    //((((/          
          (((      (((      (((      /((,         
          *(((     ((( ,((/ (((      (((          
            *((((  ((( ,((/ (((  (((((/           
                   ((( ,((/ (((                   
                       ,((/                       
                       ,((/                       
                                                  
                                                  "
    
    Write-Host

    Write-Host "Successfully connected to Debrid Services!"

    Write-Host
    
    Write-Host "The program runs an instance of the download manager Aria2c in the background. To function properly, please provide the path to Aria2c.exe"
    
    $path_to_aria2c = "C:\aria2c.exe"

    Write-Host

    while(-Not(Test-Path (-join($path_to_aria2c,"aria2c.exe")) -PathType Leaf)){

        $path_to_aria2c = Read-Host -Prompt 'Please enter the path in the format C:\path\to\'

        if((Test-Path (-join($path_to_aria2c,"aria2c.exe")) -PathType Leaf)){
            clear

            Write-Host "                                                  
                                                  
                                                  
                   ((((((((((((,                  
                /(((*        .((((                
             .((((,             (((               
           ((((.       Rain      (((/             
          (((                    //((((/          
          (((      (((      (((      /((,         
          *(((     ((( ,((/ (((      (((          
            *((((  ((( ,((/ (((  (((((/           
                   ((( ,((/ (((                   
                       ,((/                       
                       ,((/                       
                                                  
                                                  "
    
            Write-Host

            Write-Host "Successfully connected to Aria2c!"
        }else{
            Write-Host "Path seems to be wrong."
        }
    }

    Write-Host
    
    Write-Host "The program runs an instance of WinRar's unrar.exe in the background. To function properly, please provide the path to unrar.exe"
    
    $path_to_winrar = "C:\unrar.exe"

    Write-Host

    while(-Not(Test-Path (-join($path_to_winrar,"unrar.exe")) -PathType Leaf)){

        $path_to_winrar = Read-Host -Prompt 'Please enter the path in the format C:\path\to\'

        if((Test-Path (-join($path_to_winrar,"unrar.exe")) -PathType Leaf)){
            clear

            Write-Host "                                                  
                                                  
                                                  
                   ((((((((((((,                  
                /(((*        .((((                
             .((((,             (((               
           ((((.       Rain      (((/             
          (((                    //((((/          
          (((      (((      (((      /((,         
          *(((     ((( ,((/ (((      (((          
            *((((  ((( ,((/ (((  (((((/           
                   ((( ,((/ (((                   
                       ,((/                       
                       ,((/                       
                                                  
                                                  "
    
            Write-Host

            Write-Host "Successfully connected to WinRar!"
        }else{
            Write-Host "Path seems to be wrong."
        }
    }
    
    Write-Host

    Write-Host "The Script creates the following folders for your downloads: tv,movie,default."

    Write-Host

    $path_to_downloads = Read-Host -Prompt "Please enter the path in the format: D:\path\to\downloads\" 

    clear

    Write-Host "                                                  
                                                  
                                                  
                   ((((((((((((,                  
                /(((*        .((((                
             .((((,             (((               
           ((((.       Rain      (((/             
          (((                    //((((/          
          (((      (((      (((      /((,         
          *(((     ((( ,((/ (((      (((          
            *((((  ((( ,((/ (((  (((((/           
                   ((( ,((/ (((                   
                       ,((/                       
                       ,((/                       
                                                  
                                                  "
    
    Write-Host

    Write-Host "Success! Your parameters will now be saved as settings.xml. You can edit this file any time."

    $paramsini = @{
        trakt_client_id = "$trakt_client_id"
        trakt_client_secret = "$trakt_client_secret"
        trakt_access_token = $trakt_access_token
        real_debrid_token = $real_debrid_token
        path_to_aria2c = $path_to_aria2c
        path_to_winrar = $path_to_winrar
        path_to_downloads = $path_to_downloads
    }

    $paramsini

    $paramsini = @{
        trakt_client_id = "$trakt_client_id"
        trakt_client_secret = "$trakt_client_secret"
        trakt_access_token = $trakt_access_token
        real_debrid_token = $real_debrid_token
        path_to_aria2c = $path_to_aria2c
        path_to_winrar = $path_to_winrar
        path_to_downloads = $path_to_downloads
        lang = "de"
    }

    $paramsini | Export-Clixml -Path .\settings.xml

    Write-Host

    Write-Host "Please ensure all paramters are correct. If youve made any mistakes, edit the settings.xml directly or delete the file before restarting."

    Write-Host

    Read-Host -Prompt 'Pess Enter to continue'

    clear

    Write-Host "                                                  
                                                  
                                                  
                   ((((((((((((,                  
                /(((*        .((((                
             .((((,             (((               
           ((((.       Rain      (((/             
          (((                    //((((/          
          (((      (((      (((      /((,         
          *(((     ((( ,((/ (((      (((          
            *((((  ((( ,((/ (((  (((((/           
                   ((( ,((/ (((                   
                       ,((/                       
                       ,((/                       
                                                  
                                                  "
    
    Write-Host

    Write-Host "Success! Setup is finished. To start the Program, restart the script and head to: http://YOUR-PC-NAME-OR-IP-HERE:8008/."

    Write-Host

    Write-Host "Before starting the Program, make sure that you've done the following:"

    Write-Host

    Write-Host "1.) Trakt Preperation:
    - Clean Up a little :)
    - EVERYTHING in your collection will be monitored for new episodes.
    - EVERYTHING in your watchlist (that isnt already in your collection) will be downloaded."

    Write-Host

    Write-Host "1.) Debrid Preperation:
    - Clean Up a little :)
    - ALL finished torrents in the RealDebrid torrent section will be downloaded. So remove everything you dont intend to download again."

    Write-Host

    Read-Host -Prompt 'Please restart the Script. Press Enter to exit'

}