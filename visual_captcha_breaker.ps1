#not implemented yet
 
 function break_visual_captcha($url){
    $header = @{
        apikey = "843a00bd7788957"
    }

    $body = @{
        url = $url
        scale = "true"
        OCREngine=2
    }

    $shit = Invoke-RestMethod -uri https://api.ocr.space/parse/image -Method Post -Headers $header -Body $body

    $shit.ParsedResults.ParsedText
}

break_visual_captcha "https://elliscountysheriff.com/ecso/templates/jpeople/custom_php/captcha.png"
