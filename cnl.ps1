$cnl = {
    
    Write-Output ";;;;;" 

    Add-Type -AssemblyName System.Web

    $settings = $args[0]

    Set-Location $args[1]

    $http = [System.Net.HttpListener]::new()

    $http.Prefixes.Add("http://*:9666/")

    $http.Start()

    $retries = 0

    $response = ""

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

    while ($http.IsListening) {

        Write-Output "<p>checking for cnl requests</p>;"
    
        $context = $http.GetContext()

        Write-Output ";;;;;" 

        $context.Response.StatusCode = 200;
    
        $context.Response.Headers.Add("Content-Type: text/html")
    
        if( $context.Request.RawUrl -eq "/jdcheck.js" ) {

            Write-Output "<p>received jdcheck</p>;"
         
            $response = "jdownloader=true; var version='18507';"

        }elseif($context.Request.RawUrl.StartsWith("/flash")){

            $links = $null

            $name = $null
        
            if ($context.Request.RawUrl.Contains("addcrypted2")){

                Write-Output "<p>received encrypted links</p>;"
            
                $body = $context.Request.InputStream

                $reader = [System.IO.StreamReader]::new($body, $context.Request.ContentEncoding)

                $requestBody = [System.Web.HttpUtility]::UrlDecode($reader.ReadToEnd())
                                      
                $data = [regex]::matches($requestBody,"crypted=(.*?)(&|$)").Groups[1].Value
                                     
                $pass = [regex]::matches($requestBody,"(?<=return ')(.*?)(?=')").Value

                $name = [regex]::matches($requestBody,"(?<=package=)(.*?)(?= - NIMA4K.org)").Value
                    
                $links = decrypt $pass $data
                    
                $links = $links.Split([Environment]::NewLine) | where {$_ -ne ""}
          
                $response = "success\r\n";

            } else {

                Write-Output "<p>received plaintext links</p>;"
            
                $body = $context.Request.InputStream

                $reader = [System.IO.StreamReader]::new($body, $context.Request.ContentEncoding)

                $requestBody = [System.Web.HttpUtility]::UrlDecode($reader.ReadToEnd())

                $links = [regex]::matches($requestBody,"(?s)(?<=urls=).*").Value
                
                $links = $links.Split([Environment]::NewLine) | where {$_ -ne ""}
                
                $response = "success\r\n";

            }

            $real_debrid_token = $settings.real_debrid_token
            $path_to_downloads = $settings.path_to_downloads
                
            if([regex]::matches($name, ".*?(?=\.s[0-9]{2})", "IgnoreCase").Success) {
                $type = "tv"
            }elseif([regex]::matches($name, ".*?(?=.[0-9]{4}\.)").Success){
                $type = "movie"
            }else{
                $type = "default"
            }

            $Header = @{
                "authorization" = "Bearer $real_debrid_token"
            }

            Write-Output "<p>posting links to Aria2c through RealDebrid</p>;"
            
            foreach($link in $links){

                $Post_Unrestrict_Link = @{
                    Method = "POST"
                    Uri =  "https://api.real-debrid.com/rest/1.0/unrestrict/link"
                    Headers = $Header
                    Body = @{link = $link}
                }
                
                $response = Invoke-RestMethod @Post_Unrestrict_Link  -WebSession $realdebridsession      
                   
                Sleep 2

                $download = $response.download

                $shit=Invoke-WebRequest -Headers @{"Content-type"="application/json"} -Method Post -Body "{`"jsonrpc`":`"2.0`",`"id`":`"qwer`",`"method`":`"aria2.addUri`",`"params`":[`"token:premiumizer`",[`"$download`"], {`"dir`": `"$path_to_downloads\$type\\$name`"}]}" http://192.168.0.23:6800/jsonrpc -SessionVariable aria2csession
            
            }

        } else {
            
            Write-Output "<p>received unknown request</p>;"

            $context.Response.StatusCode = 400;
    
        }

        $buffer = [System.Text.Encoding]::utf8.GetBytes("$response") # convert htmtl to bytes
        $context.Response.ContentLength64 = $buffer.Length
        $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
        $context.Response.OutputStream.Close() # close the response

        Write-Output ";;;;;" 

    }

}

#$settings = Import-Clixml -Path .\parameters.xml

#Start-Job -Name CnL -ScriptBlock $cnl -ArgumentList $settings, $pwd