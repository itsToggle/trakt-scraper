$releases = new-object system.collections.arraylist

$uncached = new-object system.collections.arraylist

function download($trakt, $settings, $exceptions) {
              
    Foreach($object in $trakt) {

        if ($object.query -ne $null) {
    
            $object | Add-Member -type NoteProperty -name files -Value $null -Force

            $object | Add-Member -type NoteProperty -name download -Value $null -Force

            $object | Add-Member -type NoteProperty -name release -Value $null -Force
        
            Foreach($query in $object.query) {
                              
                $global:releases = new-object system.collections.arraylist

                Foreach($equivalent_query in $query){

                    if($equivalent_query -ne $null){

                        $text = -join("<p>scraping torrent and filehoster providers: ",$equivalent_query, "</p>;")

                        $text | Out-File scraper.log -Append

                        Write-Output $text
     
                        scrape $equivalent_query $settings

                        $releasecount = $global:releases.Count
                
                        $text = -join("<p>$releasecount total releases found</p>;")

                        $text | Out-File scraper.log -Append

				        Write-Output $text
                    }
                }

                if($global:releases.Count -gt 0){

                    check-debrid $query $settings

                    $text = -join("<p>",$global:releases.Count," instantly available releases found</p>;")

                    $text | Out-File scraper.log -Append

				    Write-Output $text

				    select-release $object $query $exceptions

				    if($object.download -ne $null) {

					    $text = -join("<p>adding downloads to aria2c</p>;")

					    Write-Output $text
					
					    aria2c $object $settings

					    $text = -join("<p>trakt sucessfully synced for item: ",$object.title,"</p>;")

					    Write-Output $text

					    sync $object $settings

                        break

				    }
                
                }
            
            }

            if($object.download -eq $null) {

                $text = -join("<p>",$global:uncached.Count," uncached releases found</p>;")

                $text | Out-File scraper.log -Append

				Write-Output $text
                
                if($global:uncached.Count -gt 0) {

                    $global:releases = $global:uncached

                    Foreach($query in $object.query) {
                    
                        select-release $object $query $exceptions

                        if($object.download -ne $null) {

                            $text = -join("<p>selected release: ",$object.release,"</p>;")

                            $text | Out-File scraper.log -Append

					        Write-Output $text

                            $text = -join("<p>adding uncached torrent to realdebrid</p>;")

                            $text | Out-File scraper.log -Append

					        Write-Output $text

                            $real_debrid_token = $settings.real_debrid_token
                       
                            $Header = @{
                                "authorization" = "Bearer $real_debrid_token"
                            }
                       
                            $Post_Magnet = @{
                                Method = "POST"
                                Uri =  "https://api.real-debrid.com/rest/1.0/torrents/addMagnet"
                                Headers = $Header
                                Body = @{ magnet = $object.download }
                            }

                            $response = Invoke-RestMethod @Post_Magnet -WebSession $realdebridsession

                            $torrent_id = $response.id

                            $Post_File_Selection = @{
                                Method = "POST"
                                Uri =  "https://api.real-debrid.com/rest/1.0/torrents/selectFiles/$torrent_id"
                                Headers = $Header
                                Body = @{ files = "all" }
    
                            }

                            $throwaway=Invoke-RestMethod @Post_File_Selection -WebSession $realdebridsession

                            $text = -join("<p>trakt sucessfully synced for item: ",$object.title,"</p>;")

					        Write-Output $text

					        sync $object $settings

                        }else{
                            
                            $text = -join("<p>no release found</p>;")

                            $text | Out-File scraper.log -Append

					        Write-Output $text

                        }

                    }

                }

            }

        }

    }

}

function scrape ($query, $settings) {
    
    # The scrape function combines instantly available torrents and filehoster links. 
    # It does this by converting them both to unrestricted debrid links via the "debrid" function. 
    # 
    # The scrape function must pass an object with the following properties to the debrid function:
    #      
    # filehoster source: 
    #                    title    = Release Name
    #                    files    = Array of the contents filenames e.g. "title.s01e01.episode.title.mkv".
    #                    download = Array of the download links. Atm only one provider per download supported.
    #
    # torrent source:
    #                    title    = Release Name
    #                    download = magnet link (NOT torrent file, since the torrents hash is extracted from the magnet link)
    #           
    # 
    
    #
    # Captcha bypasses are implemented and taylored for each site. Captcha prompts are done via promtcaptcha function and are taylored for filecrypt.cc.
    # Captcha prompts pause the script until the captcha is solved.
    #

    $webuisettings = Invoke-RestMethod -Uri "http://localhost:8008/webuisettings" -Method Get 
    
    #$webuisettings = Import-Clixml -Path .\webuisettings.xml

    $hdencode   = [int] $webuisettings."hdencode"  # english          / captcha (simple javascript) is bypassed
    $nima4k     = [int] $webuisettings."nima4k"    # german, english  / captcha (gcaptcha, cutcaptcha, javascript) needs to be solved by user
    $ddlwarez   = [int] $webuisettings."ddlwarez"  # german, english  / captcha (hcaptcha) is bypassed via accessability cookie
    $rarbg      = [int] $webuisettings."rarbg"     # english          / no captcha
    $magnetdl   = [int] $webuisettings."magnetdl"  # english          / no captcha
    $1337x      = [int] $webuisettings."1337x"     # english          / no captcha
    
    $qualityselect = @()

    if($webuisettings.720){$qualityselect += "(720)"}
    if($webuisettings.1080){$qualityselect += "(1080)"}
    if($webuisettings.2160){$qualityselect += "(2160)"}

    $qualityselect=$qualityselect -join("|")

    $exclude = $webuisettings.exclude.Split(",")
    $exclude = $exclude -join(")|(") ` -replace("\.", "\.")
    $exclude = -join("(",$exclude,")")

    $include = $webuisettings.include.Split(",")
    $includepositive = $include | Where-Object {-not $_.Contains("!")}
    $includenegative = $include | Where-Object {$_.Contains("!")}
    $includepositive = $includepositive -join(")|(") ` -replace("\.", "\.")
    $includepositive = -join("(",$includepositive,")")
    $includenegative = $includenegative -join(")|(") ` -replace("\.", "\.") ` -replace("!", "")
    $includenegative = -join("(",$includenegative,")")

    $hcaptcha = $webuisettings.hcaptcha

    #
    # begin output to log
    #

    Get-Date | Out-File scraper.log -Append

    $query | Out-File scraper.log -Append

    #
    # Scrapers:
    #
   
    #ddlwarez
    if($ddlwarez){
        $text = -join("<p>scraping ddlwarez</p>;")
        $text | Out-File scraper.log -Append
        Write-Output $text
        #build the uri
        $uri = -join('https://ddl-warez.to/?search=',$query,'&kategorie=')
        #make the api call
        $response = Invoke-WebRequest $uri -Method Get        
        $table = $response.ParsedHtml.getElementsByClassName("table table-striped table-hover pull-left table-condensed")[0].innerHTML.replace("`n","").replace("`r","")       
        $table = [regex]::matches($table, "(?<=<TR>).*?(?=</TR>)", "IgnoreCase").value
        $ddlwarezpre = new-object system.collections.arraylist
        foreach($entry in $table){
            $online =$false
            $langs = $null
            $page = [regex]::matches($entry, "(download/.*?/$query).*?(?=/)", "IgnoreCase").value | Select -Unique
            $online = switch([regex]::matches($entry, "(?<=Rapidgator.net`" style=`"HEIGHT: 14px; MARGIN-LEFT: 4px; box-shadow: 0px 0px 2px 1px #).*?(?=`")").value){00CC00 {$true}; FF6600 {$false}}
            if($online -and $page -ne $null){
                $title = [regex]::matches($page, "(?<=[0-9]+\/)(.*)").value
                $quality = [int][regex]::matches($title, "$qualityselect").value
                $langstext = [regex]::matches($entry, "(?<=images/sprache_).*?(?=\.png)")[0].value
                switch($langstext){
                    de {$langs = 0}
                    multide {$langs = 1}
                    dl {$langs = 2}
                }
                $prefer = [regex]::matches($title, "$includepositive", "IgnoreCase").value.Count - [regex]::matches($title, "$includenegative", "IgnoreCase").value.Count
                $page = -join("https://ddl-warez.to/",$page,"/")
                if(-not [regex]::matches($title, "$exclude", "IgnoreCase").Success){
                    $item = new-object psobject -property @{quality = $quality;title=$title; langs = $langs; preference = $prefer; page = $page; download = $null; files = $null}
                    $ddlwarezpre += $item
                }
            }
        }   
        $ddlwarez = $ddlwarezpre | sort -Property langs, quality, preference -Descending | Select -First 1
        $attempt = 0;
        $parts = $null
        if($ddlwarez -ne $null){
            #The links are in subpages
            #use ie to allow accessability cookie
            $iedw = New-Object -ComObject InternetExplorer.Application
            $iedw.visible = $false     
            while($attempt -lt 5){  
                $attempt++         
                $iedw.navigate($ddlwarez[0].page)
                while ($iedw.Busy) { Start-Sleep -Seconds 1 }
                (@($iedw.Document.getElementsByTagName("span")) | Where-Object {$_.outerText -eq " Download Mirror 2 "}).click()
                while ($iedw.Busy) { Start-Sleep -Seconds 1 }
                sleep 3
                if(@($iedw.Document.getElementById("download_ajax_2"))[0].outerText.Length -gt 2){
                    $parts = [regex]::matches(@($iedw.Document.getElementById("download_ajax_2"))[0].outerText,"((http|https)://rapidgator.*?)(?=(\\|'))").Value | Where-Object {-not $_.Contains("readme")} 
                    $ddlwarez[0].download = $parts
                    $ddlwarez[0].files = setfileinfo $query
                    $iedw.quit()
                    break
                } 
                if($attempt -ge 3){
                    #if captcha is promted, reactivate the accessability cookie and retry
                    $iedw.navigate("https://accounts.hcaptcha.com/verify_email/$hcaptcha")
                    while ($iedw.Busy) { Start-Sleep -Seconds 1 }
                    sleep 5
                    (@($iedw.Document.getElementsByTagName("button")) | Where-Object {$_.innerText -eq "Set Cookie"}).click()
                    sleep 5
                }
            }
        }
        #output to log
        $ddlwarez | select title,files,download,langs | Out-File scraper.log -Append
        #output the required properties
        $global:releases += $ddlwarez | select title,files,download,uncached,langs
    }

    #nima4k
    if($nima4k){
        $text = -join("<p>scraping nima4k</p>;")
        $text | Out-File scraper.log -Append
        Write-Output $text
        ##build the uri
        $uri = "https://nima4k.org/search"
        #make the api call
        $response = Invoke-WebRequest $uri -Method Post -Body @{"search" = $query} -SessionVariable rarbgsession
        #The links are in subpages
        $links = @()
        foreach($link in $response.Links.href){
            if($link.Contains("/release/")){
                $links += -join("https://nima4k.org",$link)
            }
        }
        $links = $links | sort -Unique
        $nima4kpre = new-object system.collections.arraylist
        if($links -ne $null){
            $wshell = New-Object -ComObject Wscript.Shell
            $captcha = $wshell.Popup("NIMA-4K: Start solving captchas?",0,"Captcha Solver",0x4 + 4096)            
        }
        if($captcha -eq "6"){
            foreach($link in $links){
                $response = Invoke-WebRequest $link -SessionVariable rarbgsession
                $title = $response.ParsedHTML.getElementsbyClassName("subtitle")[0].innerText
                $langs = @()
                $langstext = @([regex]::matches($response.ParsedHTML.getElementsbyClassName("uk-text-nowrap")[0].innerText, "(?<=Sprache ).*", "IgnoreCase").value) -split(", ")
                foreach($lang in $langstext){$langs+=@($lang.Split(" "))[0]}
                $langs = $langs | sort -Unique
                $filecrypt = $response.ParsedHTML.getElementsbyClassName("btn btn-orange dl-button") | Where-Object {$_.TextContent -eq "Rapidgator"}
                $filecrypt = -join("https://nima4k.org/", $filecrypt.pathname)
                $parts = $null
                #a little pre-sorting so you only solve minimum captchas
                if(-not [regex]::matches($title, "$exclude", "IgnoreCase").Success){
                    $parts = promtcaptcha $filecrypt
                }
                $files = [regex]::matches($parts, "(S[0-9]+E[0-9]+)", "IgnoreCase").value | sort -Unique
                if($parts -ne $null){
                    $item = new-object psobject -property @{title=$title; download = $parts; files = $files; langs = $langs}
                    $nima4kpre += $item
                }
            }
        }
        #prefer multilanguage releases
        $nima4k = new-object system.collections.arraylist
        $nima4k = $nima4kpre | Where-Object {$_.langs.Length -ge 2}
        if($nima4k -eq $null){$nima4k = $nima4kpre}
        #output to log
        $nima4k | select title,files,download,langs | Out-File scraper.log -Append
        #output the required properties
        $global:releases += $nima4k | select title,files,download,uncached,langs
    }
        
    #hdencode
    if($hdencode){
        $text = -join("<p>scraping hdencode</p>;")
        $text | Out-File scraper.log -Append
        Write-Output $text
        #build the uri
        $uri = -join ('https://hdencode.org/?s=', $query)
        #make the api call
        $response = Invoke-WebRequest $uri -SessionVariable rarbgsession
        #The links are in subpages
        $querysubpage = $query.replace('.','-')
        $response = $response.ParsedHTML.body.getElementsByClassName("item_2 items")[0].innerHTML
        $subpages = [regex]::matches($response, "(https://hdencode.org/$querysubpage).*?(?=`")", "IgnoreCase").value | Select -Unique
        $hdencode = new-object system.collections.arraylist
        foreach($page in $subpages) {
            #the links are hidden behind some recaptcha shit. This is easily circumvented with a little use of fiddler. The precise post request can be captured this way.
            $token = Invoke-WebRequest $page -SessionVariable rarbgsession
            #first get the required tokens from the blocked webpage
            $form = $token.ParsedHTML.forms | Where-Object {[regex]::matches($_.id, "(content-protector).*?")}
            $body = -join("content-protector-captcha=",$form[0].Value,"&content-protector-token=",$form[1].Value,"&content-protector-ident=",$form[2].Value,"&g-recaptcha-response=",$form[3].Value,"&content-protector-submit=Access+the+links&maZQ-D=Mqy%5B67&IAwfYR_ghPQtnk=B36jCD7hq%5DJ%40x9&maZQ-D=Mqy%5B67&IAwfYR_ghPQtnk=B36jCD7hq%5DJ%40x9")
            #then post those tokens back to the webpage to unblock :)
            $unrestrict = Invoke-WebRequest $page -Method Post -Body $body -SessionVariable rarbgsession
            $files = [regex]::matches($unrestrict.ParsedHtml.body.innerText, "(?<=Filename\.*: ).*", "IgnoreCase").value
            $title = @($unrestrict.ParsedHtml).title.Split()[0]
            $parts = @($unrestrict.ParsedHtml.Links).href -match('rapidgator|uploaded')
            $item = new-object psobject -property @{title=($title.Replace('"','')); download = $parts; files = $files; langs = 0}
            $hdencode += $item
            Sleep 1
        }
        #output to log
        $hdencode | select title,files,download,langs | Out-File scraper.log -Append
        #output the required properties
        $global:releases += $hdencode | select title,files,download,uncached,langs
    }

    #rarbg
    if($rarbg){
        $text = -join("<p>scraping rarbg</p>;")
        $text | Out-File scraper.log -Append
        Write-Output $text 
        #the "do while" is because rarbgs api is unreliable.
        $apidown = $true
        $retries = 0
        do{
            #build the uri
            if([regex]::matches($query, "(tt[0-9]+)").value -ne $null){
                $uri = -join ('https://torrentapi.org/pubapi_v2.php?mode=search&search_imdb=', $query, '&category=52;51;50;49;48;45;44;41;17;14&token=lnjzy73ucv&format=json_extended&app_id=lol')
            }else{
                $uri = -join ('https://torrentapi.org/pubapi_v2.php?mode=search&search_string=', $query, '&category=52;51;50;49;48;45;44;41;17;14&token=lnjzy73ucv&format=json_extended&app_id=lol')
            }
            #make the api call
            $response = Invoke-WebRequest $uri -SessionVariable rarbgsession | ConvertFrom-Json
            $rarbg = $response.torrent_results | select title,seeders,download
            
            if($response.torrent_results -eq $null){
                sleep 2
                $retries ++
            }else{
                $apidown = $false
            }

        }while($apidown -and $retries -le 3)
        foreach($item in $rarbg){
            $item | Add-Member -type NoteProperty -name langs -Value 0  -Force
        }
        #output to log
        $rarbg | select title,files,download,langs | Out-File scraper.log -Append
        #output the required properties
        $global:releases += $rarbg | select title,files,download,uncached,langs
    }

    #magnetdl
    if($magnetdl){
        $text = -join("<p>scraping magnetdl</p>;")
        $text | Out-File scraper.log -Append
        Write-Output $text
        #build the uri, replace "." in the query with "+", e.g. The+Expanse+S04E01
        $uri = -join ('https://www.magnetdl.com/search/?q=', $query.Replace(".","+"), '&m=1&x=0&y=0')
        #make the api call
        $response = Invoke-WebRequest $uri -SessionVariable rarbgsession
        #Turn HTML table into Powershell object
        $rows = $response.ParsedHTML.getElementsByTagName('table')[0].rows
        $magnetdl = new-object system.collections.arraylist 
        foreach($row in $rows) {
            $download = [regex]::matches($row.InnerHTML, "(magnet).*?(?=`")").value
            $title = [regex]::matches($row.InnerHTML, "(?<=<TD class=n><A title=).*?(?= href)").value
            $seeders = [regex]::matches($row.InnerHTML, "(?<=<TD class=s>).*?(?=</TD>)").value
            if($title -ne $null){
                $item = new-object psobject -property @{title=($title.Replace('"','') -replace(' ',''));download=$download;seeders=[int]$seeders;langs=0}                           
                $magnetdl += $item
            }
        }
        #output to log
        $magnetdl | select title,files,download,langs | Out-File scraper.log -Append
        #output the required properties
        $global:releases += $magnetdl | select title,files,download,uncached,langs
    }
        
    #1337x
    if($1337x){
        $text = -join("<p>scraping 1337x</p>;")
        $text | Out-File scraper.log -Append
        Write-Output $text
        #build the uri
        $uri = -join ('https://1337x.to/srch?search=', $query)
        #make the api call
        $response = Invoke-WebRequest $uri -SessionVariable rarbgsession
        #Turn HTML table into Powershell object
        $rows = $response.ParsedHTML.getElementsByTagName('table')[0].rows | select -skip 1
        $1337x = new-object system.collections.arraylist 
        foreach($row in $rows) {
            #1337x has the magnet link on a subpage
            $subpage = [regex]::matches($row.Cells[0].innerHTML, "(?<=<a href=`").*?(?=`")").value
            $title = $row.Cells[0].innerText -replace('â','') #fucky
            $seeders = $row.Cells[1].innerText 
            if($subpage -ne $null){
                $subpage = -join ('https://1337x.to', $subpage)
                $responsesubpage = Invoke-WebRequest $subpage -SessionVariable rarbgsession
                $download = [regex]::matches($responsesubpage.ParsedHtml.body.innerHTML, "(magnet).*?(?=`")").value[0]
                $item = new-object psobject -property @{title=($title.Replace('"','') -replace(' ',''));download=$download;seeders=[int]$seeders;langs=0}                           
                $1337x += $item
            }
        }
        #output to log
        $1337x | select title,files,download,langs | Out-File scraper.log -Append
        #output the required properties
        $global:releases += $1337x | select title,files,download,uncached,langs
    }

    #other scraper
        #build the uri
        #...
        #make the api call
        #...
        #Output the required properties
        #...
    

}

function check-debrid ($query, $settings) {
        
    $real_debrid_token = $settings.real_debrid_token
                       
    $Header = @{
        "authorization" = "Bearer $real_debrid_token"
    }

    #pre-sort by query matching

    $query = $query -join(")|(")

    $releasesbefore = $global:releases.Count

    $global:releases = $global:releases | Where-Object {[regex]::matches($_.title, "($query)", "IgnoreCase").value -ne $null}

    $releasesafter = $global:releases.Count

    $releasesrejected = $releasesbefore - $releasesafter
    
    if($releasesrejected -ne 0){
        $text = -join("<p>rejected releases: $releasesrejected releases dont match queries: ($query)</p>;")
    }

    $text | Out-File scraper.log -Append

    Write-Output $text

    $text = -join("<p>checking $releasesafter releases for instant availability</p>;")

    $text | Out-File scraper.log -Append

    Write-Output $text

    #debrid check
            
    foreach($source in $global:releases){
        
        $links = $source.download

        #if torrent:

        $hashstring = [regex]::matches($links, "(?<=btih:).*?(?=&)").value

        if($hashstring -ne $null){
            
            $source | Add-Member -type NoteProperty -name files -Value @()  -Force

            $source | Add-Member -type NoteProperty -name source -Value "torrent"  -Force
            
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
            
            $source.files = $cachedfiles
            
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

            if($source.files.Length -eq 0){

                $source.files = $response.files.path
            
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

            $source | Add-Member -type NoteProperty -name source -Value "hoster"  -Force

        }

        #unrestrict Links

        $hashstring = [regex]::matches($links, "(?<=btih:).*?(?=&)").value

        if($hashstring -eq $null){

            $source.download = @()

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
                            $source.download = $null
                            break
                        } 
                    
                        $source.download += $response.download
                
                    }
            
                }

            }

        }else{

            $source.download = $links

        }
    }

    $global:uncached = @($global:releases  | Where-Object {[regex]::matches($_.download, "(?<=btih:).*?(?=&)").value -ne $null -and $_.download -ne $null -and $_.files -ne $null})

    $global:releases = @($global:releases | Where-Object {([regex]::matches($_.download, "(?<=btih:).*?(?=&)").value -eq $null -and $_.download -ne $null -and $_.files -ne $null) -or ($_.source -eq "hoster" -and $_.download -ne $null)})

}

function promtcaptcha($link) {
    
    Sleep 1

    $ie = New-Object -ComObject InternetExplorer.Application
    $ie.AddressBar = $false
    $ie.visible = $true
    $ie.navigate($link)

    while ($ie.Busy) { Start-Sleep -Seconds 1 }

    while(-not $ie.LocationURL.Contains("filecrypt")){
        Sleep 1
    }

    while ($ie.Busy) { Start-Sleep -Seconds 1 }

    while($ie.Document.getElementsbyClassName("cnlform")[0].outerHTML -eq $null){
        Sleep 1
    }

    while ($ie.Busy) { Start-Sleep -Seconds 1 }

    $ie.visible = $false

    $html = $ie.Document.getElementsByClassName("cnlform")[0].outerHTML

    $ie.quit()

    $pass = [regex]::matches($html,"\d{32}").Value
    $data = [regex]::matches($html,"(?<=\d{32}', ')(.*)(?=', ')(.*)(?=', ')").Value

    $links = decrypt $pass $data

    $links = $links.Split([Environment]::NewLine) | where {$_ -ne ""}

    $links

}

function decrypt([string] $key, $data) {
            
    # decode key
    $key = $key.ToUpper();

    [string] $decKey = "";

    for ($i = 0; $i -lt $key.Length; $i += 2) {
        $decKey += [char] [System.Convert]::ToUInt16($key.Substring($i, 2), 16)
    }

    # decode data
    $dataByte = [System.Convert]::FromBase64String($data)

    # decrypt that shit!
    $rDel = new-Object System.Security.Cryptography.RijndaelManaged
    $aEc = [System.Text.ASCIIEncoding]::new();
    
    $rDel.Key = $aEc.GetBytes($decKey)
    $rDel.IV = $aEc.GetBytes($decKey)
    $rDel.Mode = [System.Security.Cryptography.CipherMode]::CBC

    $rDel.Padding = [System.Security.Cryptography.PaddingMode]::none
    $cTransform = $rDel.CreateDecryptor();
    $resultArray = $cTransform.TransformFinalBlock($dataByte, 0, $dataByte.Length)

    $rawLinks = $aEc.GetString($resultArray)

    # replace empty paddings
    $cleanLinks = $rawLinks.Replace("\u0000+$", "")

    # replace newlines
    $cleanLinks = $cleanLinks.Replace("\n+","\r\n")

    $cleanLinks;
 
 }

function setfileinfo($query) {
    $season = [int][regex]::matches($query, "(?<=S)[0-9][0-9]", "IgnoreCase").value
    $episode = [int][regex]::matches($query, "(?<=S[0-9][0-9]E)[0-9][0-9]", "IgnoreCase").value
    if($episode -ne 0){
        -join("S",("{0:d2}" -f $season), "E", ("{0:d2}" -f $episode))
    } elseif ($season -ne 0) {
        for($i=1; $i -lt 100; $i++){
            -join("S",("{0:d2}" -f $season), "E", ("{0:d2}" -f $i))
        }
    }
}

function select-release ($object, $query, $exceptions) {

    $global:releases | select title,files,download,langs | Out-File scraper.log -Append
    
    $scraper = new-object system.collections.arraylist 

    $webuisettings = Invoke-RestMethod -Uri "http://localhost:8008/webuisettings" -Method Get 

    $qualityselect = @()

    if($webuisettings.720){$qualityselect += "(720)"}
    if($webuisettings.1080){$qualityselect += "(1080)"}
    if($webuisettings.2160){$qualityselect += "(2160)"}

    $qualityselect=$qualityselect -join("|")

    $exclude = $webuisettings.exclude.Split(",")
    $exclude = $exclude -join(")|(") ` -replace("\.", "\.")
    $exclude = -join("(",$exclude,")")

    $include = $webuisettings.include.Split(",")
    $includepositive = $include | Where-Object {-not $_.Contains("!")}
    $includenegative = $include | Where-Object {$_.Contains("!")}
    $includepositive = $includepositive -join(")|(") ` -replace("\.", "\.")
    $includepositive = -join("(",$includepositive,")")
    $includenegative = $includenegative -join(")|(") ` -replace("\.", "\.") ` -replace("!", "")
    $includenegative = -join("(",$includenegative,")")

    Foreach ($item in $global:releases) {
                            
            $title = $item.title

            $query = $query -join(")|(")
                            
            $quality = [regex]::matches($title, $qualityselect).value 

            if($quality -eq $null){$quality=0}
                            
            $download = $item.download

            $prefer = [regex]::matches($title, "$includepositive", "IgnoreCase").value.Count - [regex]::matches($title, "$includenegative", "IgnoreCase").value.Count
                                                        
            if ([regex]::matches($title, "($query)", "IgnoreCase").value -ne $null) {

                if([regex]::matches($title, "$exclude", "IgnoreCase").value -eq $null){
                                            
                	if($object.download_type -ne "movie") {
					
						$files = @()

						$filestext = [regex]::matches($item.files, "(S[0-9].E[0-9].)", "IgnoreCase").value

						foreach($file in $filestext){
							$season = [int][regex]::matches($file, "(?<=S)..?(?=E)", "IgnoreCase").value
							$episode = [int][regex]::matches($file, "(?<=E)..?", "IgnoreCase").value
							$files += new-object psobject -property @{season=$season;episode=$episode}
						}
									
					}

					if(($object.download_type -eq "movie") -or ($exceptions.($object.title) -ne $null)) {
						
						if($exceptions.($object.title) -ne $null) {
							if($exceptions.($object.title).format -eq "date"){
								$files = new-object psobject -property @{season=$object.next_season;episode=$object.next_episode}
							}
						}

                        $text = -join("<p>accepted release: entire release: ",$title," preference ranking: $prefer</p>;")

						$text | Out-File scraper.log -Append

                        Write-Output $text

						$scraper += new-object psobject -property @{title=$title;quality=[int]$quality;download=$download;files=$files;langs=$item.langs;preference=$prefer}

					}elseif((@($files.season).Contains($object.next_season) -and @($files.episode).Contains($object.next_episode))){
					    
                        if(($object.next_season -lt $object.last_season) -or ($object.next_season -eq $object.last_season -and $object.next_episode -lt $object.last_episode)){

                            $files = new-object psobject -property @{season=$object.next_season;episode=$object.next_episode}

                            $ssn = "{0:d2}" -f $object.next_season

                            $eps = "{0:d2}" -f $object.next_episode

                            $regcon = -join ("(S",$ssn,"E",$eps,")")

                            $download = $item.download | Where-Object {[regex]::matches($_, "$regcon", "IgnoreCase").value -ne $null}

                            if($download -ne $null){

                                $text = -join("<p>accepted release: backtracking episode ", $regcon,": ",$title," preference ranking: $prefer</p>;")

						        $text | Out-File scraper.log -Append

                                Write-Output $text

                                $scraper += new-object psobject -property @{title=$title;quality=[int]$quality;download=$download;files=$files;langs=$item.langs;preference=$prefer}

                            }else{

                                $text = -join("<p>rejected release: ",$title," contains collected episode/s. Could not download backtracking episode.</p>;")

						        $text | Out-File scraper.log -Append

                                Write-Output $text
                           
                            }

                        }elseif(-not (@($files.season).Contains($object.last_season) -and @($files.episode).Contains($object.last_episode))){
                            
                            $text = -join("<p>accepted release: entire release: ",$title," preference ranking: $prefer</p>;")

						    $text | Out-File scraper.log -Append

                            Write-Output $text
                                    
					        $scraper += new-object psobject -property @{title=$title;quality=[int]$quality;download=$download;files=$files;langs=$item.langs;preference=$prefer}			
					
                        }elseif(@($files.episode).Contains($object.last_episode)){
                            
                            $files = $files | Where-Object {$_.episode -gt $object.last_episode}

                            $download = @()

                            foreach($file in $files){
                                
                                $ssn = "{0:d2}" -f $file.season

                                $eps = "{0:d2}" -f $file.episode

                                $regcon = -join ("(S",$ssn,"E",$eps,")")

                                $download += $item.download | Where-Object {[regex]::matches($_, "$regcon", "IgnoreCase").value -ne $null}

                            }

                            if($download -ne $null -and $files -ne $null){

                                $text = -join("<p>accepted release: partial release: ",$title," preference ranking: $prefer</p>;")

						        $text | Out-File scraper.log -Append

                                Write-Output $text

                                $scraper += new-object psobject -property @{title=$title;quality=[int]$quality;download=$download;files=$files;langs=$item.langs;preference=$prefer}

                            }else{

                                $text = -join("<p>rejected release: ",$title," contains collected episode/s. Could not download partial release.</p>;")

						        $text | Out-File scraper.log -Append

                                Write-Output $text
                           
                            }

                        }

                    }

                }else{

                    $excludematches = [regex]::matches($title, "$exclude", "IgnoreCase").value -join(", ")

                    $text = -join("<p>rejected release: ",$title," matches exclusion term/s: ",$excludematches,"</p>;")

                    $text | Out-File scraper.log -Append

                    Write-Output $text

                }


            }else{
                
                $text = -join("<p>rejected release: ",$title," doesnt match query: ",$query,"</p>;")

                $text | Out-File scraper.log -Append

                Write-Output $text

            }

    }

    $selected_release = $scraper | sort -Property langs,quality,preference -Descending | Select -First 1
    
    if($selected_release -ne $null){

        $object.release = $selected_release.title
    
        $object.files = $selected_release.files
    
        $object.download = $selected_release.download

        $prefer = $selected_release.preference

        $text = -join("<p>selected release: ",$object.release," preference ranking: $prefer</p>;")

        $text | Out-File scraper.log -Append

		Write-Output $text

    }

}

function aria2c ($object, $settings) {

    $type = $object.type
    $name = $object.release
    $path_to_downloads = $settings.path_to_downloads

    foreach($download in $object.download){
    
        $shit=Invoke-WebRequest -Headers @{"Content-type"="application/json"} -Method Post -Body "{`"jsonrpc`":`"2.0`",`"id`":`"qwer`",`"method`":`"aria2.addUri`",`"params`":[`"token:premiumizer`",[`"$download`"], {`"dir`": `"$path_to_downloads\$type\\$name`"}]}" http://192.168.0.23:6800/jsonrpc -SessionVariable aria2csession
    
    }

}

function sync($object, $settings) {

    $trakt_client_id = $settings.trakt_client_id
    $trakt_client_secret = $settings.trakt_client_secret
    $trakt_access_token = $settings.trakt_access_token
    $real_debrid_token = $settings.real_debrid_token
    $path_to_downloads = $settings.path_to_downloads

    Sleep 1

    $movies = @()

    $shows = @()

    $shows_ = @()

    $seasons = @()

    $seasons_ = @()

    $episodes = @()

    $e = @()

    $object_ = $object.next_season_id

    $candidateProps = $object_.psobject.properties.Name

    $nonNullProps = $candidateProps.Where({ $null -ne $object_.$_ })

    $season_id = $object_ | Select-Object $nonNullProps


    $object_ = $object.next_episode_id

    $candidateProps = $object_.psobject.properties.Name

    $nonNullProps = $candidateProps.Where({ $null -ne $object_.$_ })

    $episode_id = $object_ | Select-Object $nonNullProps


    $object_ = $object.ids

    $candidateProps = $object_.psobject.properties.Name

    $nonNullProps = $candidateProps.Where({ $null -ne $object_.$_ })

    $nonnullids = $object_ | Select-Object $nonNullProps

    if($object.download_type.Contains("show")) {
         
        foreach($enumber in $object.files.episode){

            $e += @{"number"=$enumber}

        }

        $episodes += $e

        $snumber = $object.next_season

        $s = @{"number"=$snumber;"episodes"=$episodes}

        $seasons_ += $s
               
        $object | Add-Member -type NoteProperty -name seasons -Value $seasons_ -Force
               
        $shows_ += $object | Select title, year, ids, seasons

    }
        
    if ($object.type.Contains("movie")){

        $ids= $nonnullids

        $movie_id = @{"ids"= $ids}

        $movies += $movie_id

    }
        
    if($object.type.Contains("tv")) {

        $ids= $nonnullids 

        $show_id = @{"ids"= $ids}

        $shows += $show_id

    }
        
    $watchlist_remove = ConvertTo-Json -Depth 10 -InputObject @{
        movies = $movies
        shows=$shows
    }
        
    Sleep 1
                    
    $post_watchlist_remove = Invoke-RestMethod -Uri "https://api.trakt.tv/sync/watchlist/remove" -Method Post -Body $watchlist_remove -Headers @{"Content-type" = "application/json";"trakt-api-key" = "$trakt_client_id";"trakt-api-version" = "2";"Authorization" = "Bearer $trakt_access_token"} -WebSession $traktsession
            
    $collection_add = ConvertTo-Json -Depth 10 -InputObject @{
        seasons=$seasons
        shows=$shows_
        movies = $movies
    }

    Sleep 1
                    
    $post_collection_add = Invoke-RestMethod -Uri "https://api.trakt.tv/sync/collection" -Method Post -Body $collection_add -Headers @{"Content-type" = "application/json";"trakt-api-key" = "$trakt_client_id";"trakt-api-version" = "2";"Authorization" = "Bearer $trakt_access_token"}  -WebSession $traktsession

}

function monitor-debrid {

            Write-Output "<p>checking debrid for finished torrents</p>;"

            $Header = @{
                "authorization" = "Bearer $real_debrid_token"
            }

            $Get_Torrents = @{
                Method = "GET"
                Uri = "https://api.real-debrid.com/rest/1.0/torrents"
                Headers = $Header
            }
    
            $response = Invoke-RestMethod @Get_Torrents -WebSession $realdebridsession
    
            $torrents = $response | Select id, filename, status, links, hash   

            Foreach ($torrent in $torrents) {

                $torrent_hash = $torrent.hash

                $torrent_name = $torrent.filename

                if($torrent.status -eq "downloaded"){
            
                    $links = $torrent.links
                    
                    $torrent_name = $torrent.filename
                    
                    $torrent_id = $torrent.id
  
                    if([regex]::matches($torrent_name, ".*?(?=\.s[0-9]{2})", "IgnoreCase").Success) {
                        
                        $type = "tv"
                    
                    }elseif([regex]::matches($torrent_name, ".*?(?=.[0-9]{4}\.)").Success){
                    
                        $type = "movie"
                    
                    }else{
                    
                        $type = "default"
                    
                    }   

                    Foreach ($link in $links) {

                        $RD_link = $link

                        $Post_Unrestrict_Link = @{
                            Method = "POST"
                            Uri =  "https://api.real-debrid.com/rest/1.0/unrestrict/link"
                            Headers = @{"authorization" = "Bearer $real_debrid_token"}
                            Body = @{link = "$RD_link"}
                        }
                
                        $response=Invoke-RestMethod @Post_Unrestrict_Link  -WebSession $realdebridsession      
   
                        $download = $response.download

                        $shit=Invoke-WebRequest -Headers @{"Content-type"="application/json"} -Method Post -Body "{`"jsonrpc`":`"2.0`",`"id`":`"qwer`",`"method`":`"aria2.addUri`",`"params`":[`"token:premiumizer`",[`"$download`"], {`"dir`": `"$path_to_downloads\$type\\$torrent_name`"}]}" http://192.168.0.23:6800/jsonrpc -SessionVariable aria2csession

                    }
                    
                    Sleep 5
                    
                    $Delete_Torrent = @{
                        Method = "DELETE"
                        Uri =  "https://api.real-debrid.com/rest/1.0/torrents/delete/$torrent_id"
                        Headers = @{"authorization" = "Bearer $real_debrid_token"}
                    }
                    
                    Invoke-RestMethod @Delete_Torrent -WebSession $realdebridsession 
                }


            }

}

#$settings = Import-Clixml -Path .\settings.xml

#$trakt = new-object system.collections.arraylist
#$trakt += new-object psobject -property @{download_type="movie";query=@("Black.Widow.2021");type="movie"}

#download $trakt $settings $null

#scrape "Lost.S01." $settings