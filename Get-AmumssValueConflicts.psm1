function Get-AmumssValueConflicts {
	param(
		# The root directory of your AMUMSS install
		[string]$AmumssDir = "S:\AMUMSS\install",
		
		# The path of "REPORT.lua" relative to $AmumssDir
		[string]$ReportLuaRelativeFilePath = "REPORT.lua",
		
		# Regex to identify lines in REPORT.lua containing conflict information
		[string]$ConflictBlockRegex = '(?m)\[\[CONFLICT\]\] on "(.*)" \((.*)\)\r\n((.|\r\n)*?)IGNORE',
		[string]$ConflictLuaRegex = '- "SCRIPT in (.*)"',
		
		[switch]$Log,
		
		[string]$LogRelativePath = "Get-AmumssValueConflicts_$(Get-Date -Format "FileDateTime").log",
		
		[switch]$Quiet,
		
		[string]$Indent = "    ",
		
		[switch]$PassThru
	)
	
	function log {
		param(
			[string]$Msg,
			[int]$L = 0
		)
		
		for($i = 0; $i -lt $L; $i += 1) {
			$Msg = "$($Indent)$($Msg)"
		}
		
		$ts = Get-Date -Format "HH:mm:ss"
		$Msg = "[$ts] $Msg"
		
		if(-not $Quiet) {
			Write-Host $Msg
		}
		
		if($Log) {
			$logPath = "$AmumssDir\$LogRelativePath"
			if(-not (Test-Path -PathType "Leaf" -Path $logPath)) {
				New-Item -ItemType "File" -Force -Path $Log | Out-Null
				log "Logging to `"$logPath`"."
			}
			$Msg | Out-File -Path $logPath -Append
		}
	}

	function Get-MbinFilesWithConflicts {
		$reportLuaFilePath = "$AmumssDir\$ReportLuaRelativeFilePath"
		log "Getting MBIN files with conflicts from `"$reportLuaFilePath`"..."
		
		$reportLuaFile = Get-Item -Path $reportLuaFilePath
		if(-not $reportLuaFile) {
			Throw "File `"$reportLuaFilePath`" not found!"
		}
		
		$reportLuaFileContent = $reportLuaFile | Get-Content -Raw
		if(-not $reportLuaFileContent) {
			Throw "No content found in `"$reportLuaFilePath`"!"
		}
		
		$conflictLinesMatchInfo = $reportLuaFileContent | Select-String -AllMatches -Pattern $ConflictBlockRegex
		if(-not $conflictLinesMatchInfo) {
			log "No conflicts found in `"$reportLuaFilePath`"." -L 1
			return
		}
		
		if(-not $conflictLinesMatchInfo.Matches) {
			Throw "Conflicts found, but no matches data was returned!"
		}
		
		$conflictLinesCount = @($conflictLinesMatchInfo.Matches).count
		if($conflictLinesCount -lt 1) {
			Throw "Conflicts found, and match data was returned, but the match count was <1!"
		}
		
		log "Found $conflictLinesCount MBIN files with conflicts:" -L 1
		$conflictFiles = $conflictLinesMatchInfo.Matches | ForEach-Object {
			$conflictMatch = $_
			$mbin = $conflictMatch.Groups[1].Value
			$pak = $conflictMatch.Groups[2].Value
			log "$mbin ($pak)" -L 2
			
			$luaString = $conflictMatch.Groups[3].Value
			$luaMatchInfo = $luaString | Select-String -AllMatches -Pattern $ConflictLuaRegex
			if(-not $luaMatchInfo) {
				Throw "No Lua file paths recognized!"
			}
			
			if(-not $luaMatchInfo.Matches) {
				Throw "Lua files recognized, but no match data was returned!"
			}
			
			$luaCount = @($luaMatchInfo.Matches).count
			if($luaCount -lt 1) {
				Throw "Lua files recognized, and match data was returned, but the match count was <1!"
			}
			
			$luaFiles = $luaMatchInfo.Matches | ForEach-Object {
				$luaMatch = $_
				$luaFilePath = $luaMatch.Groups[1].Value
				log $luaFilePath -L 3
				$luaFilePathParts = $luaFilePath -split '\\'
				$luaFileNameIndex = $luaFilePathParts.length - 1
				$luaFileName = $luaFilePathParts[$luaFileNameIndex]
				$luaFileRelativeParentPath = $luaFilePath.Replace("\$luaFileName","")
				[PSCustomObject]@{
					"RelativeParentPath" = $luaFileRelativeParentPath
					"FileName" = $luaFileName
					"FilePath" = "$($AmumssDir)\$($luaFilePath)"
				}
			}
			
			
			[PSCustomObject]@{
				"Mbin" = $mbin
				"Pak" = $pak
				"Luas" = $luaFiles
				"Line" = $line.Value
			}
		}
		
		$conflictFiles
	}
	
	function Do-Stuff {
		$conflictFiles = Get-MbinFilesWithConflicts
		
		if($PassThru) {
			$conflictFiles
		}
	}
		
	Do-Stuff
	
	log "EOF"
}