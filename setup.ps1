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

    Read-Host -Prompt 'To use the script, you need to connect it to Trakt.tv and specify a few parameters. Press Enter to continue'

    Write-Host "Connect the Script to Trakt. Go to  trakt.tv/activate  and within 60 seconds enter the code:" $get_token_response.user_code 

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

    Write-Host "Successfully connected to Trakt!" 
    
    $trakt_access_token = $poll_token_response.access_token

    Write-Host

    Write-Host "Connect the Script to Debrid Services. If promted for a Service you do not intent to use, just press Enter."

    Write-Host

    $real_debrid_token = Read-Host -Prompt 'Real Debrid - enter your API token'

    Write-Host

    $premiumize_api_key = Read-Host -Prompt 'Premiumize - enter your API key'

    clear

    Write-Host "Successfully connected to Debrid Services!"

    Write-Host
    
    Write-Host "The Script starts an instance of the download manager Aria2c in the background. To function properly, please provide the path to your Aria2c.exe"
    
    $path_to_aria2c = "C:\aria2c.exe"

    Write-Host

    while(-Not(Test-Path (-join($path_to_aria2c,"aria2c.exe")) -PathType Leaf)){

        $path_to_aria2c = Read-Host -Prompt 'Please enter the path in the format C:\path\to\'

        if((Test-Path $path_to_aria2c -PathType Leaf)){
            clear
            Write-Host "Successfully connected to Aria2c!"
        }else{
            Write-Host "Path seems to be wrong."
        }
    }

    Write-Host
    
    Write-Host "The Script starts an instance of WinRar's unrar.exe in the background. To function properly, please provide the path to your unrar.exe"
    
    $path_to_winrar = "C:\unrar.exe"

    Write-Host

    while(-Not(Test-Path (-join($path_to_winrar,"unrar.exe")) -PathType Leaf)){

        $path_to_winrar = Read-Host -Prompt 'Please enter the path in the format C:\path\to\'

        if((Test-Path $path_to_winrar -PathType Leaf)){
            clear
            Write-Host "Successfully connected to WinRar!"
        }else{
            Write-Host "Path seems to be wrong."
        }
    }

    clear

    Write-Host "The Script creates the following folders for your downloads: tv,movie,default."

    Write-Host

    $path_to_downloads = Read-Host -Prompt "Please enter the path in the format: D:\path\to\downloads\" 

    clear

    Write-Host "Success! Your parameters will now be saved as parameters.xml. You can edit this file any time."

    $paramsini = @{
        trakt_client_id = "$trakt_client_id"
        trakt_client_secret = "$trakt_client_secret"
        trakt_access_token = $trakt_access_token
        real_debrid_token = $real_debrid_token
        premiumize_api_key = $premiumize_api_key 
        path_to_aria2c = $path_to_aria2c
        path_to_winrar = $path_to_winrar
        path_to_downloads = $path_to_downloads
    }

    $paramsini

    $paramsini | Export-Clixml -Path .\parameters.xml

    Write-Host

    Write-Host "Please ensure all paramters are correct. If youve made any mistakes, delete the parameters.xml file before restarting."

    Write-Host

    Write-Host "The Script uses a WebUI to function. To allow the local webserver to be run, you need to run the following command with admin rights:"

    Write-Host "netsh http add urlacl url=http://+:8008/ user=YOUR-USERNAME-HERE"

    Write-Host

    Read-Host -Prompt 'Please restart the Script. Press Enter to exit'

}