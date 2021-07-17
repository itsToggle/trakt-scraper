Get-Process Powershell  | Where-Object { $_.ID -ne $pid } | Stop-Process

. .\setup.ps1

. .\unrar.ps1

. .\cnl.ps1

. .\download.ps1

$traktscraper = {

    $settings = $args[0]

    $exceptions = $args[2]

    $trakt_client_id = $settings.trakt_client_id
    $trakt_client_secret = $settings.trakt_client_secret
    $trakt_access_token = $settings.trakt_access_token
    $real_debrid_token = $settings.real_debrid_token
    $premiumize_api_key = $settings.premiumize_api_key
    $path_to_downloads = $settings.path_to_downloads

    Set-Location $args[1]

    function main {
    
        . .\trakt.ps1

        . .\download.ps1

        while(1) {
    
            $trakt = trakt $settings $exceptions

            Write-Output ";end;"

            $trakt  | Where-Object {$_.next_season -ne $null -or $_.download_type -ne $null} |  Sort-Object -Property release_wait 

            Write-Output ";start;"
            
            if($trakt.download_type.Contains("show") -or $trakt.download_type.Contains("movie")){

                Sleep 10

                download $trakt $settings $exceptions

            }else{

                Write-Output "<p>nothing to scrape! all content is up to date.</p>;"

                Sleep 60

            }

            monitor-debrid

        }
            
    }

    main

} 

if(-Not (Test-Path .\settings.xml -PathType Leaf)) {

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

    Write-Host "Setup started. Please follow the instructions."

    Write-Host

    Write-Host "The Program runs a WebUI server. To allow the local webserver to run, the following commands will be excecuted with admin rights:"

    Write-Host "Webui server: netsh http add urlacl url=http://+:8008/ user=YOUR-USERNAME-HERE"

    Write-Host "Click n Load (CNL) server: netsh http add urlacl url=http://*:9666/ user=YOUR-USERNAME-HERE"
    
    Write-Host

    Write-Host "To read more on the subject, visit: https://stackoverflow.com/questions/4019466/httplistener-access-denied/4115328."
    
    Write-Host
    
    Read-Host -Prompt 'Press Enter to continue.'

    if(([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        netsh http add urlacl url=http://+:8008/ user=$(whoami) 
        netsh http add urlacl url=http://*:9666/ user=$(whoami) 
    }else{
        Start-Process powershell -Verb runAs -ArgumentList "-command `"netsh http add urlacl url=http://+:8008/ user=$(whoami)`""
        Start-Process powershell -Verb runAs -ArgumentList "-command `"netsh http add urlacl url=http://*:9666/ user=$(whoami)`""
    }
    

    setup

}else {
    
    [string]$exceptionstext = Get-Content -Path .\exceptions.txt

    $exceptionstext = $exceptionstext.replace("`n","").replace("`r","")

    iex $exceptionstext

    $settings = Import-Clixml -Path .\settings.xml

    $webuisettings = Import-Clixml -Path .\webuisettings.xml

    Start-Job -Name Aria2c -ArgumentList $settings -ScriptBlock {

        Set-Location $args[0].path_to_aria2c
    
        .\aria2c.exe --disable-ipv6=true --enable-rpc --rpc-allow-origin-all --rpc-listen-all --rpc-listen-port=6800 --rpc-secret=premiumizer --max-connection-per-server=16 --file-allocation=none --disk-cache=0 --max-concurrent-downloads=1 --continue=true
    
    }

    Start-Job -Name UnRar -ScriptBlock $unrar -ArgumentList $settings, $pwd

    Start-Job -Name TraktScraper -ScriptBlock $traktscraper -ArgumentList $settings, $pwd, $exceptions

    Start-Job -Name CnL -ScriptBlock $cnl -ArgumentList $settings, $pwd

    $http = [System.Net.HttpListener]::new()

    Add-Type -AssemblyName System.Web

    $http.Prefixes.Add("http://+:8008/")

    $http.Start()

    while ($http.IsListening) {
        
        $context = $http.GetContext()                 
        
        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/') {
                       
            $html = Get-Content -Path ".\webserver.html"

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response

        }

        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/logs') {
                       
            $html = Get-Content -Path ".\logs.html"

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response

        }

        if ($context.Request.HttpMethod -eq 'POST' -and $context.Request.RawUrl -eq '/download') {

                $request = [System.IO.StreamReader]::new($context.Request.InputStream).ReadToEnd()

                $request = $request.Split([Environment]::NewLine)

                $links = $request

                #unrestrict links

                    $path_to_downloads = $settings.path_to_downloads

                    $releases = new-object system.collections.arraylist

                    $uncached = new-object system.collections.arraylist

                    $hashstring = [regex]::matches($links, "(?<=btih:).*?(?=&)").value
                    
					if($hashstring -ne $null){

                        $links = [string]$links
						
						#check instant available files

						$Post_Hash = @{
							Method = "GET"
							Uri =  "https://api.real-debrid.com/rest/1.0/torrents/instantAvailability/$hashstring"
							Headers = $Header
						}

						$check_cache_RD = Invoke-WebRequest @Post_Hash -WebSession $realdebridsession

						$fuck = $check_cache_RD.content | ConvertFrom-Json
									
						$cachedid = @()

						$cachedfiles = @()

						#$check_cache_RD.$hashstring.rd[0] perhaps?

						foreach($entry in $fuck.$hashstring.rd){
							if($entry -ne $null){
							$entryobject = $entry | Get-Member -MemberType Properties | Select-Object Name
							$cachedid += $entryobject.Name 
							}
						}

						$cachedid = $cachedid | Sort -Unique  

						for($i=0; $i -lt $cachedid.length; $i++) {
							$id = @($cachedid)[$i]
							[string]$filename = $fuck.$hashstring.rd.$id.filename | Sort -Unique  
							if($filename.Contains(".txt") -or $filename.Contains(".exe") -or $filename.Contains(".nfo") -or $filename.Contains(".sub") -or $filename.Contains(".idx") -or $filename.Contains(".srt")){
								$cachedid[$i]=$null
							}else{
								$cachedfiles += $filename
							}
						}
						
						$cachedid = $cachedid | Where-Object {$_} 

						#post magnet

						$Post_Magnet = @{
							Method = "POST"
							Uri =  "https://api.real-debrid.com/rest/1.0/torrents/addMagnet"
							Headers = $Header
							Body = @{ magnet = $links }
						}

						$response = Invoke-RestMethod @Post_Magnet -WebSession $realdebridsession

						sleep 0.5

						$torrent_id = $response.id
						
						#get torrent info

						$Get_Torrent_Info = @{
							Method = "GET"
							Uri = "https://api.real-debrid.com/rest/1.0/torrents/info/$torrent_id"
							Headers = $Header
						}

						$response = Invoke-RestMethod @Get_Torrent_Info -WebSession $realdebridsession

						sleep 0.5

						$torrent_status = $response.status

						if($torrent_status -eq "magnet_conversion"){
							Sleep 5
							$response = Invoke-RestMethod @Get_Torrent_Info
						}

						if($cachedid.Length -ge 1) {

							#post file selection

							$cachedid = @{files = $cachedid -join ',' }

							$Post_File_Selection = @{
								Method = "POST"
								Uri =  "https://api.real-debrid.com/rest/1.0/torrents/selectFiles/$torrent_id"
								Headers = $Header
								Body = $cachedid
				
							}

							$throwaway=Invoke-RestMethod @Post_File_Selection -WebSession $realdebridsession
							
							sleep 2

							#get direct links
								
							$response = Invoke-RestMethod @Get_Torrent_Info -WebSession $realdebridsession

							sleep 0.5

							$links = $response.links
						
						}       
						
						#delete torrent

						$Delete_Torrent = @{
							Method = "DELETE"
							Uri =  "https://api.real-debrid.com/rest/1.0/torrents/delete/$torrent_id"
							Headers = @{"authorization" = "Bearer $real_debrid_token"}
						}
								
						$throwaway=Invoke-RestMethod @Delete_Torrent -WebSession $realdebridsession

						sleep 0.5

					}else{
                        
                    }

					#unrestrict Links

					$hashstring = [regex]::matches($links, "(?<=btih:).*?(?=&)").value
                    
                    $download = @()

					if($hashstring -eq $null){

						if($links -ne $null){
						
							foreach($link in $links){

								if($link -ne $null){
									
									$Post_Unrestrict_Link = @{
										Method = "POST"
										Uri =  "https://api.real-debrid.com/rest/1.0/unrestrict/link"
										Headers = $Header
										Body = @{link = $link}
									}
								
									try{
										$response=Invoke-RestMethod @Post_Unrestrict_Link  -WebSession $realdebridsession
									}catch{
										$download = $null
										break
									} 
								
									$download += $response.download
							
								}
						
							}

						}

					}

                $releases = @($download | Where-Object {[regex]::matches($_, "(?<=btih:).*?(?=&)").value -eq $null -and $_ -ne $null})

                $type = "default"

                if($releases.Count -gt 0){

                    foreach($directdownload in $releases){
    
                        $shit=Invoke-WebRequest -Headers @{"Content-type"="application/json"} -Method Post -Body "{`"jsonrpc`":`"2.0`",`"id`":`"qwer`",`"method`":`"aria2.addUri`",`"params`":[`"token:premiumizer`",[`"$directdownload`"], {`"dir`": `"$path_to_downloads\$type`"}]}" http://192.168.0.23:6800/jsonrpc -SessionVariable aria2csession

                    }
                
                }

                $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
                $Context.Response.StatusCode = 200
                $context.Response.ContentLength64 = $buffer.Length
                $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
                $context.Response.OutputStream.Close() # close the response

            
        }

        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/logscraperfull') {
                       
            $html = Get-Content -Path ".\scraper.log"

            $html = $html -join("`r`n") 

            $html = -join("<pre>",$html,"</pre>") ` -replace(";","") 

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response

        }

        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/logunrarfull') {
                       
            $html = Get-Content -Path ".\unrar.log"

            $html = $html -join("`r`n")

            $html = -join("<pre>",[string]$html,"</pre>") ` -replace(";","") 

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response

        }

        if ($context.Request.HttpMethod -eq 'POST' -and $context.Request.RawUrl -eq '/webuisettings') {
                
                $webuisettings = Import-Clixml -Path .\webuisettings.xml

                $request = [System.IO.StreamReader]::new($context.Request.InputStream).ReadToEnd()

                $request = $request | ConvertFrom-Json

                $source = $request.data.source

                $webuisettings.$source = $request.data.value

                Export-Clixml -InputObject $webuisettings -Depth 10 -Path .\webuisettings.xml

                $html = "200"

                $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
                $Context.Response.StatusCode = 200
                $context.Response.ContentLength64 = $buffer.Length
                $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
                $context.Response.OutputStream.Close() # close the response

            
        }

        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/webuisettings'){
                
                $webuisettings = Import-Clixml -Path .\webuisettings.xml

                $html = @{
                    "hdencode"   = $webuisettings."hdencode"
                    "nima4k"     = $webuisettings."nima4k"
                    "ddlwarez"   = $webuisettings."ddlwarez"
                    "rarbg"      = $webuisettings."rarbg"
                    "magnetdl"   = $webuisettings."magnetdl"
                    "1337x"      = $webuisettings."1337x"
                    "2160"       = $webuisettings."2160"
                    "1080"       = $webuisettings."1080"
                    "720"        = $webuisettings."720"
                    "exclude"    = $webuisettings."exclude"
                    "include"    = $webuisettings."include"
                    "hcaptcha"   = $webuisettings."hcaptcha"
                    "tmdb"       = $webuisettings."tmdb"
                } | ConvertTo-Json -Depth 10                

                $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
                $context.Response.ContentLength64 = $buffer.Length
                $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
                $context.Response.OutputStream.Close() # close the response
            
        }

        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/webuisettingshtml'){
                
                $webuisettings = Import-Clixml -Path .\webuisettings.xml

                $html = "                                   <div class=`"row`">
																<div class=`"col-12`">
																	<div class=`"page-title-box d-sm-flex align-items-center justify-content-between`">
																		<h4 class=`"mb-sm-0 font-size-18`" style=`"text-transform:none;`">Source Settings</h4>
																	</div>
																</div>
															</div>
															
															<div class=`"row`">
																<div class=`"col-xl-6`">
																	<div class=`"card`">
																		<div class=`"card-body`">
																		
																			<h4 class=`"card-title`">Sources</h4>
                                                                            <p class=`"card-title-desc`">Select which sources to scrape.</p>
																			
																			<div>"

                $count = 0

                $sources = $webuisettings | Get-Member -MemberType Properties | Select-Object Name

                $sources = $sources.Name

                $scrapersources = $sources | Where-Object {$_ -ne "2160" -and $_ -ne "1080" -and $_ -ne "720" -and $_ -ne "exclude" -and $_ -ne "include" -and $_ -ne "tmdb" -and $_ -ne "hcaptcha"}

                Foreach($source in $scrapersources){

                    if($source -eq "1337x" -or $source -eq "rarbg" -or $source -eq "magnetdl"){$type = "torrent"}else{$type = "hoster"}
                    
                    if($source -eq "ddlwarez" -or $source -eq "nima4k"){$lang = "de/en"}else{$lang = "en"}

                    if([int]$webuisettings.$source){$checked = "checked"}else{$checked = "unchecked"}
                    
                    $count++
                
                    $html +=                                                    "<div class=`"pb-1 task-list`">
																					
																					<div class=`"card task-box`" id=`"source$count`" style=`"margin-bottom:5px;margin-top:5px`">
																						<div class=`"card-body`" style=`"padding: 2px 2px; margin-bottom:0px`">
																							<div class=`"float-end ms-2`">
                                                                                                <span class=`"badge badge-soft-secondary font-size-12`" id=`"task-status`">$lang</span>
                                                                                                <span class=`"badge badge-soft-secondary font-size-12`" id=`"task-status`">$type</span>
																							</div>
																							<div>
																								<div class=`"form-check form-switch style=margin-bottom:2px;`">
																									<input class=`"form-check-input`" type=`"checkbox`" id=`"flexSwitchCheckDefault`" data-toggle=`"toggle`" $checked data-off=`"Disabled`" data-on=`"Enabled`" value=`"$source`">
																									<label class=`"form-check-label`" for=`"flexSwitchCheckDefault`">$source</label>
																								</div>
																							</div>
																						</div>
																					</div>
																					
																				</div>"
                }
                
                if($webuisettings."2160"){$checked2160 = "checked"}else{$checked2160 = "unchecked"}
                if($webuisettings."1080"){$checked1080 = "checked"}else{$checked1080 = "unchecked"}
                if($webuisettings."720"){$checked720 = "checked"}else{$checked720 = "unchecked"}

                $exclude = $webuisettings."exclude"
                $include = $webuisettings."include"
                
                $html += -join("                                                  </div>
																		</div>
																	</div>
																</div>
                                                                <div class=`"col-xl-6`">
																	<div class=`"card`">
																		<div class=`"card-body`">
																		
																			<h4 class=`"card-title`">Multilanguage releases - UNDER CONSTRUCTION</h4>
                                                                            <p class=`"card-title-desc`">If multi-lang sources are selected, multi-lang releases are prefered. To help find multi-lang releases, non-english media titles can be scraped for by enabling this feature and specifying a 2-letter language code.</p>
																			
																			<div class=`"col-md-12`">
                                                                                <input class=`"form-control`" type=`"text`" value=`"de`" id=`"language`">
                                                                            </div>
																			
																		</div>
																	</div>
																</div>
                                                            </div>
														    <div class=`"row`">
																<div class=`"col-12`">
																	<div class=`"page-title-box d-sm-flex align-items-center justify-content-between`">
																		<h4 class=`"mb-sm-0 font-size-18`" style=`"text-transform:none;`">Quality Settings</h4>
																	</div>
																</div>
															</div>
                                                            
                                                            <div class=`"row`">
																<div class=`"col-xl-6`">
																	<div class=`"card`">
                                                                        <div class=`"card-header bg-transparent border-bottom`">
                                                                            <h4 class=`"card-title`" style=`"margin-bottom: 0px;`">Ranking</h4>
                                                                        </div>

                                                                        <div class=`"card-body`" style=`"padding-bottom: 0;`">
                                                                            <p class=`"card-title-desc`" style=`"margin-bottom: .5rem;`">Releases are ranked according to the specified settings. The best ranking release will be downloaded.</p>
                                                                            <p class=`"card-title-desc`" style=`"margin-bottom: 0`">Releases are ranked in the following order:</p>
																		</div>
                                                                        
                                                                        <div class=`"card-body`" style=`"padding-bottom: 0;`">
																		
																			<h4 class=`"card-title`">1.) Prefered Resolution</h4>
                                                                            <p class=`"card-title-desc`">Group releases by resolution. If no resolution is selected, only ranking terms apply. To exclude a specific resolution, add it to the exclusion terms.</p>
																			
																			<div class=`"pb-1 task-list`">
																					
																					<div class=`"card task-box`" id=`"quality1`" style=`"margin-bottom:5px;margin-top:5px`">
																						<div class=`"card-body`" style=`"padding: 2px 2px; margin-bottom:0px`">
																							<div>
																								<div class=`"form-check form-switch style=margin-bottom:2px;`">
																									<input class=`"form-check-input`" type=`"checkbox`" id=`"flexSwitchCheckDefault`" data-toggle=`"toggle`" ",$checked2160," data-off=`"Disabled`" data-on=`"Enabled`" value=`"2160`">
																									<label class=`"form-check-label`" for=`"flexSwitchCheckDefault`">2160p</label>
																								</div>
																							</div>
																						</div>
																					</div>
                                                                                    <div class=`"card task-box`" id=`"quality2`" style=`"margin-bottom:5px;margin-top:5px`">
																						<div class=`"card-body`" style=`"padding: 2px 2px; margin-bottom:0px`">
																							<div>
																								<div class=`"form-check form-switch style=margin-bottom:2px;`">
																									<input class=`"form-check-input`" type=`"checkbox`" id=`"flexSwitchCheckDefault`" data-toggle=`"toggle`" ",$checked1080," data-off=`"Disabled`" data-on=`"Enabled`" value=`"1080`">
																									<label class=`"form-check-label`" for=`"flexSwitchCheckDefault`">1080p</label>
																								</div>
																							</div>
																						</div>
																					</div>
                                                                                    <div class=`"card task-box`" id=`"quality3`" style=`"margin-bottom:5px;margin-top:5px`">
																						<div class=`"card-body`" style=`"padding: 2px 2px; margin-bottom:0px`">
																							<div>
																								<div class=`"form-check form-switch style=margin-bottom:2px;`">
																									<input class=`"form-check-input`" type=`"checkbox`" id=`"flexSwitchCheckDefault`" data-toggle=`"toggle`" ",$checked720," data-off=`"Disabled`" data-on=`"Enabled`" value=`"720`">
																									<label class=`"form-check-label`" for=`"flexSwitchCheckDefault`">720p</label>
																								</div>
																							</div>
																						</div>
																					</div>
																					
																		    </div>
																			
																		</div>
																	
                                                                        <div class=`"card-body`">
																		
																			<h4 class=`"card-title`">2.) Ranking Terms</h4>
                                                                            <p class=`"card-title-desc`">Rank releases of the same resolution by prefered/unprefered terms. Specify unprefered terms by negating with a preceding '!'. Seperate multiple terms via comma. Case-Insensitive</p>
																			
																			<div class=`"col-md-12`">
                                                                                <input class=`"form-control`" type=`"text`" value=`"$include`" id=`"include`">
                                                                            </div>
																			
																		</div>
                                                                    </div>
																</div>

																<div class=`"col-xl-6`">
																	<div class=`"card`">
                                                                        <div class=`"card-header bg-transparent border-bottom`">
                                                                            <h4 class=`"card-title`" style=`"margin-bottom: 0px;`">Exclusion</h4>
                                                                        </div>
																		<div class=`"card-body`">
																		
																			<h4 class=`"card-title`">Exclusion Terms</h4>
                                                                            <p class=`"card-title-desc`">Exclude releases that match specific terms. If any terms match, the release is rejected. Seperate multiple terms via comma. Case-Insensitive.</p>
																			
																			<div class=`"col-md-12`">
                                                                                <input class=`"form-control`" type=`"text`" value=`"$exclude`" id=`"exclude`">
                                                                            </div>
																			
																		</div>
																	</div>
																</div>
                                                                
															</div>	
                                                        ")                            

                $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
                $context.Response.ContentLength64 = $buffer.Length
                $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
                $context.Response.OutputStream.Close() # close the response
            
        }

        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/onlinecheck') {
            
            $html = "<span class=`"logo-sm`" style=`"font-size:3rem; line-height:3rem; text-align: center;`">
									<i class=`"bx bx-cloud-light-rain`" style=`"color:#34c38f`"></i>
								</span>            
								<span class=`"logo-lg`" style=`"font-size:3rem; line-height:3rem; text-align: center;`">
									<i class=`"bx bx-cloud-light-rain`" style=`"color:#34c38f`"></i>
								</span>"                  

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response
        }  

        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/trakt') {
            
            $Job = Get-Job -Name TraktScraper     

            $traktoutputtemp = $Job.ChildJobs.Output

            $traktoutput = new-object system.collections.arraylist 

            $fetch = $false

            for ($i = $traktoutputtemp.Length-1 ; $i -ge 0; $i -= 1) {
                if($traktoutputtemp[$i] -eq ";start;"){
                    $fetch = $true
                    $i -= 1
                }elseif($traktoutputtemp[$i] -eq ";end;" -and $i -ne ($traktoutputtemp.Length-1)){
                    break
                }

                if($fetch){
                    $traktoutput += $traktoutputtemp[$i]
                }
            }

            $tmdbkey = $webuisettings.tmdb

            $traktoutput = $traktoutput | Sort-Object -Property release_wait

            $tablecontent = foreach($item in $traktoutput){ 
                                              
                                              if($item.type -eq "movie"){
                                                  $uri = -join("https://api.themoviedb.org/3/movie/",@($item).ids.tmdb,"?api_key=$tmdbkey")
                                              }else{
                                                  $uri = -join("https://api.themoviedb.org/3/tv/",@($item).ids.tmdb,"?api_key=$tmdbkey")
                                              }
                   
                                              $tmdb = Invoke-RestMethod -Uri $uri
                                                
                                              $uri = -join("https://image.tmdb.org/t/p/w500",$tmdb.poster_path)
                                                                                             
                                              $status = switch($item.download_type) {
                                                    "" {"<span class=`"badge badge-pill badge-soft-success font-size-11`">waiting for release</span>"}       
                                                    "ignored" {"<span class=`"badge badge-pill badge-soft-danger font-size-11`">ignored by scraper</span>"}                                              
                                                    default {"<span class=`"badge badge-pill badge-soft-warning font-size-11`">downloading</span>"}
                                              }

                                              if($item.download_type -eq "ignored"){

                                                  $status = switch($item.predb) {
                                                      0 {"<span class=`"badge badge-pill badge-soft-danger font-size-11`">ignored by scraper</span>"}                                                     
                                                      default {"<span class=`"badge badge-pill badge-soft-warning font-size-11`">ignored by scraper</span>"}
                                                  }

                                              }
            
                                              -join("<tr>
                                                        <td><img src=`"$uri`" alt=`"`" class=`"img rounded avatar-sm`" id=`"poster`"></td>                                                      
                                                        <td><a class=`"text-body fw-bold`">",@($item).title, "</a></td>
                                                        <td>",@($item).collected,"</td>       
                                                        <td>",@($item).next,"</td>
                                                        <td>$status</td>
                                                        <td>",@($item).release_wait,"</td>
                                                        <td><button type=`"button`" class=`"btn waves-effect`" id=`"ignoretrakt`" value=`"",@($item).download_type,"`" data-value=`"",@($item).ids.trakt,"`" data-value3=`"",@($item).type,"`"><i class=`"bx bx-x-circle `" style=`"color:#f46a6a;`"></i></button></td>  
                                                    </tr>")
            
            }

            $html = -join("<table class=`"table align-middle table-nowrap mb-0`">
                                                <thead class=`"table-light`">
                                                    <tr>
                                                        <th class=`"align-middle`" style=`"width:50px;`">Title</th> 
                                                        <th class=`"align-middle`"></th>
                                                        <th class=`"align-middle`">Collected</th>
                                                        <th class=`"align-middle`">Next</th>
                                                        <th class=`"align-middle`">Status</th>
                                                        <th class=`"align-middle`">Release</th>
                                                        <th class=`"align-middle`"><button type=`"button`" class=`"btn waves-effect`"><i class=`"bx bx-x-circle`"></i></button></th>
                                                    </tr>
                                                </thead>
                                                <tbody>
                                                    $tablecontent   
                                                </tbody>
                                            </table>")                        

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response
        }

        if ($context.Request.HttpMethod -eq 'POST' -and $context.Request.RawUrl -eq '/ignoretrakt') {
            
            $ignoretrakt = [System.IO.StreamReader]::new($context.Request.InputStream).ReadToEnd()

            $ignoretrakt = $ignoretrakt | ConvertFrom-Json

            $trakt_client_id = $settings.trakt_client_id
            $trakt_client_secret = $settings.trakt_client_secret
            $trakt_access_token = $settings.trakt_access_token

            $traktheader = @{
                "Content-type" = "application/json"
                "trakt-api-key" = "$trakt_client_id"
                "trakt-api-version" = "2"
                "Authorization" = "Bearer $trakt_access_token"
    
            }

            $get_lists_response = Invoke-RestMethod -Uri "https://api.trakt.tv/users/me/lists" -Method Get -Headers $traktheader -SessionVariable traktsession

            $ignored_list = $get_lists_response | Where-Object {$_.name -eq "Ignored"}

            $ignored_list_id = $ignored_list.ids.slug

            $shows = @()

            $movies = @()

            $nonnullids = @{"trakt" = $ignoretrakt.data.ids}

            if ($ignoretrakt.data.type.Contains("movie")){

                $ids= $nonnullids

                $movie_id = @{"ids"= $ids}

                $movies += $movie_id

            }
        
            if($ignoretrakt.data.type.Contains("tv")) {

                $ids= $nonnullids 

                $show_id = @{"ids"= $ids}

                $shows += $show_id

            }

            $ignored_item = ConvertTo-Json -Depth 10 -InputObject @{
                movies=$movies
                shows=$shows
            }
            
            if($ignoretrakt.data.source.Contains("ignored")){
                
                $post_ignored_remove = Invoke-RestMethod -Uri "https://api.trakt.tv/users/me/lists/$ignored_list_id/items/remove" -Method Post -Headers $traktheader -Body $ignored_item -SessionVariable traktsession

            }else{
            
                $post_ignored_add = Invoke-RestMethod -Uri "https://api.trakt.tv/users/me/lists/$ignored_list_id/items" -Method Post -Headers $traktheader -Body $ignored_item -SessionVariable traktsession
            }

            $html = "200"

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $Context.Response.StatusCode = 200
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response
        }

        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/debrid') {

            $real_debrid_token = $settings.real_debrid_token

            $Header = @{
                "authorization" = "Bearer $real_debrid_token"
            }

            $Get_Torrents = @{
                Method = "GET"
                Uri = "https://api.real-debrid.com/rest/1.0/torrents"
                Headers = $Header
            }
            
            $debridresponse = Invoke-RestMethod @Get_Torrents -WebSession $realdebridsession
            
            $debrid_count = 0

            $debrid_speed = 0

            foreach($download in $debridresponse) {

                $debrid_speed += [math]::Round($download.speed / 1000000,1)

                if($download.status -ne "downloaded"){
                    $debrid_count++
                }

            }

            if($debridresponse -ne $null){

                foreach($download in $debridresponse) {

                    if($download.status -eq "queued") {
                        $completedSize = 0
                        $remainingSize = 1
                        $percentdownload = "0 %"
                        $name = $download.filename
                        $speed = 0
                        $gb = [math]::Round($download.bytes / 1000000000,2)
                        $download | Add-Member -type NoteProperty -name completedSize -Value $completedSize  -Force
                        $download | Add-Member -type NoteProperty -name remainingSize -Value $remainingSize  -Force
                        $download | Add-Member -type NoteProperty -name percentdownload -Value $percentdownload  -Force
                        $download | Add-Member -type NoteProperty -name name -Value $name  -Force
                        $download | Add-Member -type NoteProperty -name speed -Value $speed  -Force
                        $download | Add-Member -type NoteProperty -name gb -Value $gb  -Force
        
                        
                    }else{ 
                        $completedSize = [math]::Round($download.bytes / 1000000000 * $download.progress / 100,2)
                        $remainingSize = [math]::Round($download.bytes / 1000000000,2) - $completedSize
                        $percentdownload = "{0:P2}" -f ($download.progress/100)
                        $name = $download.filename
                        $speed = [math]::Round($download.speed / 1000000,1)
                        $gb = [math]::Round($download.bytes / 1000000000,2)
                        $download | Add-Member -type NoteProperty -name completedSize -Value $completedSize  -Force
                        $download | Add-Member -type NoteProperty -name remainingSize -Value $remainingSize  -Force
                        $download | Add-Member -type NoteProperty -name percentdownload -Value $percentdownload  -Force
                        $download | Add-Member -type NoteProperty -name name -Value $name  -Force
                        $download | Add-Member -type NoteProperty -name speed -Value $speed  -Force
                        $download | Add-Member -type NoteProperty -name gb -Value $gb  -Force
                    }

                }

            }

            $tablecontent = foreach($item in $debridresponse){ 
                                              
                                              $status = switch($item.status) {
                                                    "queued" {"<span class=`"badge badge-pill badge-soft-secondary font-size-11`">queued</span>"}
                                                    "waiting_files_selection" {"<span class=`"badge badge-pill badge-soft-secondary font-size-11`">file selection</span>"}
                                                    "downloading" {"<span class=`"badge badge-pill badge-soft-warning font-size-11`">downloading</span>"}
                                                    "downloaded" {"<span class=`"badge badge-pill badge-soft-success font-size-11`">finished</span>"}
                                                    "default" {"<span class=`"badge badge-pill badge-soft-secondary font-size-11`">error</span>"}
                                              }
            
                                              -join("<tr>                                                      
                                                        <td><a class=`"text-body fw-bold`">",@($item).name, "</a> </td>
                                                        <td>",@($item).seeders,"</td>       
                                                        <td>",@($item).gb," GB</td>
                                                        <td>$status</td>
                                                        <td>
                                                            <div class=`"progress progress-lg progress-bar-striped rounded`" style=`"width:100px;`">
                                                                <div class=`"progress-bar bg-success rounded`" role=`"progressbar`" style=`"width: ",@($item).progress,"%`" aria-valuenow=`"",@($item).progress,"`" aria-valuemin=`"0`" aria-valuemax=`"100`"> 
                                                                    ",@($item).progress," %
                                                                </div>
                                                            </div>
                                                        </td>
                                                        <td>",@($item).speed," MB/s</td>
                                                        <td><button type=`"button`" class=`"btn waves-effect`" id=`"deletetorrent`" value=`"",@($item).id,"`"><i class=`"bx bx-x-circle`" style=`"color:#f46a6a;`"></i></button></td>  
                                                    </tr>")
            
            }

            $html = -join("<table class=`"table align-middle table-nowrap mb-0`">
                                                <thead class=`"table-light`">
                                                    <tr>
                                                        <th class=`"align-middle`">Torrent</th>
                                                        <th class=`"align-middle`">Seeders</th>
                                                        <th class=`"align-middle`">Size</th>
                                                        <th class=`"align-middle`">Status</th>
                                                        <th class=`"align-middle`">Progress</th>
                                                        <th class=`"align-middle`">Speed</th>
                                                        <th class=`"align-middle`"><button type=`"button`" class=`"btn waves-effect`" id=`"deletetorrent`" value=`"all`"><i class=`"bx bx-x-circle`" style=`"color:#f46a6a;`"></button></i></th>
                                                    </tr>
                                                </thead>
                                                <tbody>
                                                    $tablecontent      
                                                </tbody>
                                            </table>")                        

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response
        }

        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/aria2c') {

            $downloads = @()

            $active = Invoke-WebRequest -Headers @{"Content-type"="application/json"} -Method Post -Body "{`"jsonrpc`":`"2.0`",`"id`":`"qwer`",`"method`":`"aria2.tellActive`",`"params`":[`"token:premiumizer`"]}" http://192.168.0.23:6800/jsonrpc -SessionVariable aria2csession | ConvertFrom-Json

            $waiting = Invoke-WebRequest -Headers @{"Content-type"="application/json"} -Method Post -Body "{`"jsonrpc`":`"2.0`",`"id`":`"qwer`",`"method`":`"aria2.tellWaiting`",`"params`":[`"token:premiumizer`",-1,100]}" http://192.168.0.23:6800/jsonrpc -SessionVariable aria2csession | ConvertFrom-Json

            $stopped = Invoke-WebRequest -Headers @{"Content-type"="application/json"} -Method Post -Body "{`"jsonrpc`":`"2.0`",`"id`":`"qwer`",`"method`":`"aria2.tellStopped`",`"params`":[`"token:premiumizer`",-1,100]}" http://192.168.0.23:6800/jsonrpc -SessionVariable aria2csession | ConvertFrom-Json

            $aria2c_speed = 0

            $aria2c_count = $active.result.Length + $waiting.result.Length

            $downloads += $waiting.result

            $downloads += $active.result

            $downloads += $stopped.result
            
            if($downloads -ne $null){

                foreach($download in $downloads) {

                    if($download.totalLength -eq 0) {
                        $completedSize = 0
                        $remainingSize = 1
                        $percentdownload = 0
                        $name = $download.dir.Split("\")[-1]
                        $speed = 0
                        $gb = "?"
                        $download | Add-Member -type NoteProperty -name completedSize -Value $completedSize  -Force
                        $download | Add-Member -type NoteProperty -name remainingSize -Value $remainingSize  -Force
                        $download | Add-Member -type NoteProperty -name percentdownload -Value $percentdownload  -Force
                        $download | Add-Member -type NoteProperty -name name -Value $name  -Force
                        $download | Add-Member -type NoteProperty -name speed -Value $speed  -Force
                        $download | Add-Member -type NoteProperty -name gb -Value $gb  -Force
                        $download | Add-Member -type NoteProperty -name status -Value "queued"  -Force
        
                        
                    }else{ 
                        $completedSize = $download.completedLength / $download.totalLength
                        $remainingSize = ($download.totalLength -$download.completedLength)/$download.totalLength 
                        $percentdownload =  [math]::Round(100*$CompletedSize)
                        $name = $download.files.path.Split("/")[-1]
                        $speed = [math]::Round($download.downloadSpeed / 1000000,1)
                        $gb = [math]::Round($download.totalLength / 1000000000,2)
                        $download | Add-Member -type NoteProperty -name completedSize -Value $completedSize  -Force
                        $download | Add-Member -type NoteProperty -name remainingSize -Value $remainingSize  -Force
                        $download | Add-Member -type NoteProperty -name percentdownload -Value $percentdownload  -Force
                        $download | Add-Member -type NoteProperty -name name -Value $name  -Force
                        $download | Add-Member -type NoteProperty -name speed -Value $speed  -Force
                        $download | Add-Member -type NoteProperty -name gb -Value $gb  -Force
                        $download | Add-Member -type NoteProperty -name status -Value "downloading"  -Force
                        if($completedSize -eq 1){ $download | Add-Member -type NoteProperty -name status -Value "finished"  -Force}
                    }

                    $aria2c_speed += $download.speed

                }
            }            

            $tablecontent = foreach($item in $downloads){ 
                                              
                                              $status = switch($item.status) {
                                                    queued {"<span class=`"badge badge-pill badge-soft-secondary font-size-11`">queued</span>"}
                                                    downloading {"<span class=`"badge badge-pill badge-soft-warning font-size-11`">downloading</span>"}
                                                    finished {"<span class=`"badge badge-pill badge-soft-success font-size-11`">finished</span>"}
                                              }

                                              -join("<tr>                                                      
                                                        <td><a class=`"text-body fw-bold`">",@($item).name, "</a> </td> 
                                                        <td></td>    
                                                        <td>",@($item).gb," GB</td>
                                                        <td>$status</td>
                                                        <td>
                                                            <div class=`"progress progress-lg progress-bar-striped rounded`" style=`"width:100px;`">
                                                                <div class=`"progress-bar bg-success rounded`" role=`"progressbar`" style=`"width: ",@($item).percentdownload,"%`" aria-valuenow=`"",@($item).percentdownload,"`" aria-valuemin=`"0`" aria-valuemax=`"100`"> 
                                                                    ",@($item).percentdownload,"
                                                                </div>
                                                            </div>
                                                        </td>
                                                        <td>",@($item).speed," MB/s</td>
                                                        <td><button type=`"button`" class=`"btn waves-effect`" id=`"deletearia2c`" value=`"",@($item).gid,"`"><i class=`"bx bx-x-circle`" style=`"color:#f46a6a;`"></i></button></td>   
                                                    </tr>")
            
            }

            $html = -join("<table class=`"table align-middle table-nowrap mb-0`">
                                                <thead class=`"table-light`">
                                                    <tr>
                                                        <th class=`"align-middle`">Filename</th>
                                                        <th class=`"align-middle`"></th>
                                                        <th class=`"align-middle`">Size</th>
                                                        <th class=`"align-middle`">Status</th>
                                                        <th class=`"align-middle`">Progress</th>
                                                        <th class=`"align-middle`">Speed</th>
                                                        <th class=`"align-middle`"><button type=`"button`" class=`"btn waves-effect`" id=`"deletearia2c`" value=`"all`"><i class=`"bx bx-x-circle`" style=`"color:#f46a6a;`"></i></button></th>
                                                    </tr>
                                                </thead>
                                                <tbody>
                                                    $tablecontent     
                                                </tbody>
                                            </table>")                        

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response
        }
        
        #maybe add graph
        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/speedometer') {
            
            $html = "<p class=`"text-muted text-truncate mb-0`"><i class=`"mdi mdi-cloud-download-outline ms-1 text-success`"></i> $debrid_speed MB/s</p>
                     <p class=`"text-muted text-truncate mb-0`"><i class=`"mdi mdi-arrow-down ms-1 text-success`"></i> $aria2c_speed MB/s</p></div>"                        

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response
        }        

        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/logscraper') {
            
            $job = Get-Job -Name TraktScraper

            $job_output = $job.ChildJobs.Output | Out-String

            $job_output = $job_output -split(";start;")

            $job_output = $job_output[-1] -split(";")

            $log = ""

            for ($i = 0; $i -lt $job_output.Length-1; $i += 1) {
                
                if($i -lt $job_output.Length-2){
                    
                    $log += -join("<li class=`"event-list`"  style=`"padding: 0px 0px 5px 30px;`">
                                   <div class=`"event-timeline-dot`">
                                   <i class=`"bx bx-right-arrow-circle font-size-18`"></i>
                                   </div>
                                   <div class=`"d-flex`">
                                       <div class=`"flex-shrink-0 me-3`">
                                   </div>
                                       <div class=`"flex-grow-1`">
                                           <div>",$job_output[$i],"</div>
                                       </div>
                                   </div>
                                   </li>")

                }else{

                    $log += -join("<li class=`"event-list active`"  style=`"padding: 0px 0px 5px 30px;`">
                                   <div class=`"event-timeline-dot`">
                                   <i class=`"bx bxs-right-arrow-circle font-size-18 bx-fade-right`"></i>
                                   </div>
                                   <div class=`"d-flex`">
                                       <div class=`"flex-shrink-0 me-3`">
                                   </div>
                                       <div class=`"flex-grow-1`">
                                           <div>",$job_output[$i],"</div>
                                       </div>
                                   </div>
                                   </li>")                        
                
                }               

            }

            $html = $log                     

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response
        } 

        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/logunrar') {

            $job = Get-Job -Name UnRar

            $job_output = $job.ChildJobs.Output | Out-String

            $job_output = $job_output -split(";;;;;")

            $job_output = $job_output[-1] -split(";")

            $log = ""

            for ($i = 0; $i -lt $job_output.Length-1; $i += 1) {
                
                if($i -lt $job_output.Length-2){
                    
                    $log += -join("<li class=`"event-list`"  style=`"padding: 0px 0px 5px 30px;`">
                                   <div class=`"event-timeline-dot`">
                                   <i class=`"bx bx-right-arrow-circle font-size-18`"></i>
                                   </div>
                                   <div class=`"d-flex`">
                                       <div class=`"flex-shrink-0 me-3`">
                                   </div>
                                       <div class=`"flex-grow-1`">
                                           <div>",$job_output[$i],"</div>
                                       </div>
                                   </div>
                                   </li>")

                }else{

                    $log += -join("<li class=`"event-list active`"  style=`"padding: 0px 0px 5px 30px;`">
                                   <div class=`"event-timeline-dot`">
                                   <i class=`"bx bxs-right-arrow-circle font-size-18 bx-fade-right`"></i>
                                   </div>
                                   <div class=`"d-flex`">
                                       <div class=`"flex-shrink-0 me-3`">
                                   </div>
                                       <div class=`"flex-grow-1`">
                                           <div>",$job_output[$i],"</div>
                                       </div>
                                   </div>
                                   </li>")                        
                
                }               

            }

            $html = $log                     

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response
        }

        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/logcnl') {
            
            $job = Get-Job -Name CnL

            $job_output = $job.ChildJobs.Output | Out-String

            $job_output = $job_output -split(";;;;;")

            $job_output = $job_output[-1] -split(";")

            $log = ""

            for ($i = 0; $i -lt $job_output.Length-1; $i += 1) {
                
                if($i -lt $job_output.Length-2){
                    
                    $log += -join("<li class=`"event-list`"  style=`"padding: 0px 0px 5px 30px;`">
                                   <div class=`"event-timeline-dot`">
                                   <i class=`"bx bx-right-arrow-circle font-size-18`"></i>
                                   </div>
                                   <div class=`"d-flex`">
                                       <div class=`"flex-shrink-0 me-3`">
                                   </div>
                                       <div class=`"flex-grow-1`">
                                           <div>",$job_output[$i],"</div>
                                       </div>
                                   </div>
                                   </li>")

                }else{

                    $log += -join("<li class=`"event-list active`"  style=`"padding: 0px 0px 5px 30px;`">
                                   <div class=`"event-timeline-dot`">
                                   <i class=`"bx bxs-right-arrow-circle font-size-18 bx-fade-right`"></i>
                                   </div>
                                   <div class=`"d-flex`">
                                       <div class=`"flex-shrink-0 me-3`">
                                   </div>
                                       <div class=`"flex-grow-1`">
                                           <div>",$job_output[$i],"</div>
                                       </div>
                                   </div>
                                   </li>")                        
                
                }               

            }

            $html = $log                       

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response
        }

        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/traktcount') {
            
            $html = $traktoutput.Length
            
            if($html -eq 0){$html = ""}                     

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response
        } 

        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/debridcount') {
            
            $html = $debrid_count   
            
            if($html -eq 0){$html = ""}                   

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response
        }

        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/aria2ccount') {
            
            $html = $aria2c_count  
            
            if($html -eq 0){$html = ""}                    

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response
        } 

        if ($context.Request.HttpMethod -eq 'POST' -and $context.Request.RawUrl -eq '/deletetorrent') {
            
            $torrent_id = [System.IO.StreamReader]::new($context.Request.InputStream).ReadToEnd()

            if($torrent_id -eq "all"){
                foreach($download in $debridresponse){
                    $torrent_id = $download.id
                    $Delete_Torrent = @{
                        Method = "DELETE"
                        Uri =  "https://api.real-debrid.com/rest/1.0/torrents/delete/$torrent_id"
                        Headers = @{"authorization" = "Bearer $real_debrid_token"}
                    }
                    Invoke-RestMethod @Delete_Torrent -WebSession $realdebridsession
                }
            }else{
                $Delete_Torrent = @{
                    Method = "DELETE"
                    Uri =  "https://api.real-debrid.com/rest/1.0/torrents/delete/$torrent_id"
                    Headers = @{"authorization" = "Bearer $real_debrid_token"}
                }
                Invoke-RestMethod @Delete_Torrent -WebSession $realdebridsession
            } 

            $html = "200"

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $Context.Response.StatusCode = 200
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response
        } 

        if ($context.Request.HttpMethod -eq 'POST' -and $context.Request.RawUrl -eq '/deletearia2c') {
            
            $aria2c_id = [System.IO.StreamReader]::new($context.Request.InputStream).ReadToEnd()

            if($aria2c_id -eq "all"){
                foreach($download in @($active).result){
                    $aria2c_id = $download.gid
                    Invoke-WebRequest -Headers @{"Content-type"="application/json"} -Method Post -Body "{`"jsonrpc`":`"2.0`",`"id`":`"qwer`",`"method`":`"aria2.forceRemove`",`"params`":[`"token:premiumizer`", `"$aria2c_id`"]}" http://192.168.0.23:6800/jsonrpc -SessionVariable aria2csession | ConvertFrom-Json 
                }
                Invoke-WebRequest -Headers @{"Content-type"="application/json"} -Method Post -Body "{`"jsonrpc`":`"2.0`",`"id`":`"qwer`",`"method`":`"aria2.purgeDownloadResult`",`"params`":[`"token:premiumizer`"]}" http://192.168.0.23:6800/jsonrpc -SessionVariable aria2csession | ConvertFrom-Json 
            }else{
                if(@($active).result.gid -contains $aria2c_id){
                    Invoke-WebRequest -Headers @{"Content-type"="application/json"} -Method Post -Body "{`"jsonrpc`":`"2.0`",`"id`":`"qwer`",`"method`":`"aria2.forceRemove`",`"params`":[`"token:premiumizer`", `"$aria2c_id`"]}" http://192.168.0.23:6800/jsonrpc -SessionVariable aria2csession | ConvertFrom-Json 
                }
                Invoke-WebRequest -Headers @{"Content-type"="application/json"} -Method Post -Body "{`"jsonrpc`":`"2.0`",`"id`":`"qwer`",`"method`":`"aria2.removeDownloadResult`",`"params`":[`"token:premiumizer`", `"$aria2c_id`"]}" http://192.168.0.23:6800/jsonrpc -SessionVariable aria2csession | ConvertFrom-Json 
            }

            
            $html = "200"

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $Context.Response.StatusCode = 200
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response
        }

        if ($context.Request.HttpMethod -eq 'POST' -and $context.Request.RawUrl -eq '/deletelog') {
            
            $log = [System.IO.StreamReader]::new($context.Request.InputStream).ReadToEnd()

            $placeholder = Get-Date

            if($log -eq "scraper"){
                [string]$placeholder | Out-File .\scraper.log
            }else{
                [string]$placeholder | Out-File .\unrar.log
            }

            
            $html = "200"

            $buffer = [System.Text.Encoding]::utf8.GetBytes("$html") # convert htmtl to bytes
            $Context.Response.StatusCode = 200
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
            $context.Response.OutputStream.Close() # close the response
        }
    }

}