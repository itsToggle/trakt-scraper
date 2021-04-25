function tohtml {

	    param(
		  [int]$last = 50000,             
		  [switch]$all,                   
		  [switch]$trim,                  
		  [string]$font=$null,            
		  [string]$fontsize=$null,        
		  [string]$style="",              
		  [string]$palette="powershell"   
		  )
		$ui = $host.UI.RawUI
		[int]$start = 0
		if ($all) { 
		  [int]$end = $ui.BufferSize.Height  
		  [int]$start = 0
		}
		else { 
		  [int]$end = ($ui.CursorPosition.Y - 1)
		  [int]$start = $end - $last
		  if ($start -le 0) { $start = 0 }
		}
		$height = $end - $start
		if ($height -le 0) {
		  write-warning "There must be one or more lines to get"
		  return
		}
		$width = $ui.BufferSize.Width
		$dims = 0,$start,($width-1),($end-1)
		$rect = new-object Management.Automation.Host.Rectangle -argumentList $dims
		$cells = $ui.GetBufferContents($rect)

		# set default colours
		$fg = $ui.ForegroundColor; $bg = $ui.BackgroundColor
		$defaultfg = $fg; $defaultbg = $bg

		# character translations
		# wordpress weirdness means I do special stuff for < and \
		$cmap = @{
			[char]"<" = "&lt;"# "<span>&lt;</span>"
			[char]"\" = "&#x5c;"
			[char]">" = "&gt;"
			[char]"'" = "&#39;"
			[char]"`"" = "&#34;"
			[char]"&" = "&amp;"
		}

		# console colour mapping
		# the powershell console has some odd colour choices, 
		# marked with a 6-char hex codes below
		$palettes = @{}
		$palettes.powershell = @{
			"Black"       ="#000"
			"DarkBlue"    ="#008"
			"DarkGreen"   ="#080"
			"DarkCyan"    ="#088"
			"DarkRed"     ="#800"
			"DarkMagenta" ="#012456"
			"DarkYellow"  ="#eeedf0"
			"Gray"        ="#ccc"
			"DarkGray"    ="#888"
			"Blue"        ="#00f"
			"Green"       ="#0f0"
			"Cyan"        ="#0ff"
			"Red"         ="#f00"
			"Magenta"     ="#f0f"
			"Yellow"      ="#ff0"
			"White"       ="#fff"
		  }
		# now a variation for the standard console (used by cmd.exe) based
		# on ansi colours
		$palettes.standard = ($palettes.powershell).Clone()
		$palettes.standard.DarkMagenta = "#808"
		$palettes.standard.DarkYellow = "#880"

		# this is a weird one... takes the normal powershell one and
		# inverts a few colours so normal ps1 output would save ink when
		# printed (eg from a web page).
		$palettes.print = ($palettes.powershell).Clone()
		$palettes.print.DarkMagenta = "#eee"
		$palettes.print.DarkYellow = "#000"
		$palettes.print.Yellow = "#440"
		$palettes.print.Black = "#fff"
		$palettes.print.White = "#000"

		$comap = $palettes[$palette]

		# inner function to translate a console colour to an html/css one
		function c2h{return $comap[[string]$args[0]]}
		$f=""
		if ($font) { $f += " font-family: `"$font`";" }
		if ($fontsize) { $f += " font-size: $fontsize;" }
		$line  = "<!DOCTYPE html><html lang=`"en`"><head><meta charset=`"utf-16`"><meta http-equiv=`"refresh`" content=`"5`"></head><body style=`"background-color: $(c2h $bg);`"><pre style='color: $(c2h $fg); background-color: $(c2h $bg);$f $style'>" 
		for ([int]$row=0; $row -lt $height; $row++ ) {
		  for ([int]$col=0; $col -lt $width; $col++ ) {
			$cell = $cells[$row,$col]
			# do we need to change colours?
			$cfg = [string]$cell.ForegroundColor
			$cbg = [string]$cell.BackgroundColor
			if ($fg -ne $cfg -or $bg -ne $cbg) {
			  if ($fg -ne $defaultfg -or $bg -ne $defaultbg) { 
				$line += "</span>" # remove any specialisation
				$fg = $defaultfg; $bg = $defaultbg;
			  }
			  if ($cfg -ne $defaultfg -or $cbg -ne $defaultbg) { 
				# start a new colour span
				$line += "<span style='color: $(c2h $cfg); background-color: $(c2h $cbg)'>" 
			  }
			  $fg = $cfg
			  $bg = $cbg
			}
			$ch = $cell.Character
			$ch2 = $cmap[$ch]; if ($ch2) { $ch = $ch2 }
			$line += $ch
			#$line += "<br>"
		  }
		  if ($trim) { $line = $Line.TrimEnd() }
		  $line += "<br>"
		  $line
		  $line=""
		}
		if ($fg -ne $defaultfg -or $bg -ne $defaultbg) { "</span>" } # close off any specialisation of colour
		"</pre></body></html>"


	}