function Get-AmumssValueConflicts {
	param(
		# If specified, we'll look for conflicts between the given Lua files instead of those reported by AMUMSS as having conflicts
		[string[]]$LuaFilePaths,
		
		# The root directory of your AMUMSS install
		[string]$AmumssDir = "S:\AMUMSS\install",
		
		# The path of "REPORT.lua" relative to $AmumssDir
		[string]$ReportLuaRelativeFilePath = "REPORT.lua",
		
		# Regex to identify lines in REPORT.lua containing conflict information
		[string]$ConflictBlockRegex = '(?m)\[\[CONFLICT\]\] on "(.*)" \((.*)\)\r\n((.|\r\n)*?)IGNORE',
		[string]$ConflictLuaRegex = '- "SCRIPT in (.*)"',
		
		[string]$LuaTableJsonScriptPath = "S:\Git\Get-AmumssValueConflicts\getLuaTableJson.lua",
		
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
		$conflictMbins = $conflictLinesMatchInfo.Matches | ForEach-Object {
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
		
		$conflictMbins
	}
	
	function Get-LuaFilesWithConflicts($conflictMbins) {
		# Currently we have a list of MBIN files.
		# Each MBIN file has a list of Luas that are trying to contribute to it.
		# Some Lua files may be contributing to multiple conflicts.
		# We only really care about the Lua files and which other Lua files they conflict with.
		# So instead, munge the data so that it's a list of Lua files, which each have a list of which other Lua files they conflict with.
		
		log "Munging data..."
		
		# Get unique Lua files
		$conflictLuas = $conflictMbins | ForEach-Object {
			$_.Luas | ForEach-Object {
				$_
			}
		} | Sort "FilePath" -Unique
		
		# For each Lua file record the list of MBINs it contributes to
		$conflictLuas = $conflictLuas | ForEach-Object {
			$lua = $_
			$mbins = $conflictMbins | ForEach-Object {
				if($_.Luas.FilePath -contains $lua.FilePath) {
					$_
				}
			}
			$lua | Add-Member -NotePropertyName "Mbins" -NotePropertyValue $mbins -PassThru
		}
		
		# For Lua file, generate a list of other Luas it conflicts with
		$conflictLuas = $conflictLuas | ForEach-Object {
			$lua = $_
			
			$conflictingLuaPaths = $lua.Mbins | ForEach-Object {
				$_.Luas | ForEach-Object {
					$_.FilePath
				}
			} | Sort
			$conflictingOtherLuaPaths = $conflictingLuaPaths | Where { $_ -ne $lua.FilePath }
			$conflictingOtherUniqueLuaPaths = $conflictingOtherLuaPaths | Select -Unique
			
			$lua | Add-Member -NotePropertyName "ConflictingLuas" -NotePropertyValue $conflictingOtherUniqueLuaPaths -PassThru
		}
		
		log "Unique Luas:" -L 1
		$conflictLuas | ForEach-Object {
			log $_.FilePath -L 2
			log "Contributing to MBINs:" -L 3
			$_.Mbins | ForEach-Object {
				log "$($_.Mbin) ($($_.Pak))" -L 4
			}
			log "Conflicting Luas:" -L 3
			$_.ConflictingLuas | ForEach-Object {
				log $_ -L 4
			}
		}
		
		$conflictLuas
	}
	
	function Get-GivenLuaFiles {
		log "Building Lua data from given Lua paths..."
		
		$conflictLuas = $LuaFilePaths | ForEach-Object {
			$lua = $_
			$otherLuas = $LuaFilePaths | Where { $_ -ne $lua }
			[PSCustomObject]@{
				"FilePath" = $lua
				"ConflictingLuas" = $otherLuas
			}
		}
		
		log "Unique Luas:" -L 1
		$conflictLuas | ForEach-Object {
			log $_.FilePath -L 2
			log "Conflicting Luas:" -L 3
			$_.ConflictingLuas | ForEach-Object {
				log $_ -L 4
			}
		}
		
		$conflictLuas
	}
	
	function Test-ConflictPairIsUnique($targetPair, $pairs) {
		#log "Testing if `"$($targetPair.Luas)`" is unique..." -L 2
		$unique = $true
		$pairs | ForEach-Object {
			$thisPair = $_.Luas
			$commonMembers = 0
			$targetPair.Luas | ForEach-Object {
				#log "Testing if `"$_`" is in `"$thisPair`"..." -L 3
				if($_ -in $thisPair) {
					#log "It is." -L 4
					$commonMembers += 1
				}
				else {
					#log "It's not." -L 4
				}
			}
			if($commonMembers -gt 1) {
				#log "Not unique." -L 5
				$unique = $false
			}
		}
		
		if($unique) {
			#log "Unique." -L 5
		}
		
		$unique
	}
	
	function Get-ConflictPairs($conflictLuas) {
		# Get full list of individual, 1-on-1 conflict pairings
		log "Getting conflict pairings..."
		
		log "Getting all pairings..." -L 1
		$conflictPairs = $conflictLuas | ForEach-Object {
			$lua = $_
			$_.ConflictingLuas | ForEach-Object {
				[PSCustomObject]@{
					"Luas" = @($lua.FilePath, $_)
				}
			}
		}
		
		<#
		log "Conflict pairs:" -L 2
		$conflictPairs | ForEach-Object {
			$pair = $_.Luas
			$a = $pair[0]
			$b = $pair[1]
			log "`"$a`" <> `"$b`"" -L 3
		}
		#>
		
		# Every pairing will be duplicated
		log "Getting unique pairings..." -L 1
		$uniqueConflictPairs = $conflictPairs | ForEach-Object {
			$pair = $_
			$pair.Luas = $pair.Luas | Sort
			$pair
		} | Sort { $_.Luas[0],$_.Luas[1] } -Unique
		
		log "Unique conflict pairs:" -L 2
		$uniqueConflictPairs | ForEach-Object {
			$pair = $_.Luas
			$a = $pair[0]
			$b = $pair[1]
			log "`"$a`" <> `"$b`"" -L 3
		}
		
		$data = [PSCustomObject]@{
			"Luas" = $conflictLuas
			"ConflictPairs" = $uniqueConflictPairs
		}
		
		$data
	}
	
	function Get-LuaData($data) {
		# For each Lua file, get its NMS_MOD_DEFINITION_CONTAINER table and parse its data into forms that facilitate later comparison
		log "Getting Lua file data..."
		
		$data.Luas = $data.Luas | ForEach-Object {
			$lua = $_
			log "Processing `"$($lua.FilePath)`"..." -L 1
			
			# Get the Lua's effective NMS_MOD_DEFINITION_CONTAINER table data by executing the Lua script and passing that variable back
			$lua = Get-LuaTable $lua
			# Validate the table to make sure there aren't any anomalies
			Validate-LuaTable $lua
			
			# Parse the table data into convenient forms
			
			# Parse value changes. These are the most common change that Luas perform.
			# file:///S:/AMUMSS/install/README/README-AMUMSS_Script_Rules.html#VALUE_CHANGE_TABLE
			$lua = Get-ValueChanges $lua
			
			# Parse other possible functions: file:///S:/AMUMSS/install/README/README-AMUMSS_Script_Rules.html#NMS_MOD_DEFINITION_CONTAINER
			
			# file:///S:/AMUMSS/install/README/README-AMUMSS_Script_Rules.html#ADD
			#$lua = Get-Additions $lua
			
			# file:///S:/AMUMSS/install/README/README-AMUMSS_Script_Rules.html#REMOVE
			#$lua = Get-Removals $lua
			
			$lua
		}
		
		$data
	}
	
	function Get-LuaTable($lua) {
		log "Getting NMS_MOD_DEFINITION_CONTAINER table data..." -L 2
		
		$luaExeRelativePath = "MODBUILDER\Extras\lua_x64\bin\lua.exe"
		$luaExe = "$($AmumssDir)\$($luaExeRelativePath)"
		$luaScript = $LuaTableJsonScriptPath
		
		log "Executing lua file table-to-JSON script: `"$luaScript`"..." -L 3
		try {
			$luaExeResult = & $luaExe $luaScript $lua.FilePath *>&1
		}
		catch {
			log "Failed to execute script!" -L 4
			log $_.Exception.Message -L 5
		}
		
		if($LASTEXITCODE -ne 0) {
			log "Script executed, but lua.exe returned a non-zero exit code!" -L 4
			log $luaExeResult -L 5
		}
		else {
			log "Script succeeded." -L 4
			if($luaExeResult) {
				log "Result returned; interpreting as JSON." -L 3
				$tableJson = $luaExeResult
				
				#log "Table data JSON string:" -L 3
				#log $tableJson -L 4
				
				log "Converting JSON into PowerShell object..." -L 3
				try {
					$table = $tableJson | ConvertFrom-Json
				}
				catch {
					log "Failed to convert JSON!" -L 4
					log $_.Exception.Message -L 5
				}
			}
			else {
				log "No result was returned!" -L 3
			}
		}
		
		$lua | Add-Member -NotePropertyName "TableJson" -NotePropertyValue $tableJson
		$lua | Add-Member -NotePropertyName "Table" -NotePropertyValue $table -PassThru
	}
	
	function Validate-LuaTable($lua) {
		log "Validating table data..."
		
		# Make sure the MODIFICATIONS property is a table which has only one un-named property that is a sub-table
		# Note: While everything in Lua is technically a table (https://www.lua.org/pil/11.html), going forward I'm going to use the term "array" to refer to tables whose only members are multiple un-named properties that are themselves tables. It's just simpler to say "an array of X members", or just "array" to differentiate a table being used as a bucket of things from a table being used to host data and/or represent an object.
		# Anyway, technically, the spec says that the MODIFICATIONS property is an "array", that can have multiple sub-tables: file:///S:/AMUMSS/install/README/README-AMUMSS_Script_Rules.html#MODIFICATIONS
		# However it seems nobody actually does this, and I don't know how that should be handled.
		# Babscoole said this was used "a little bit in the early days, but didn't pan out".
		#TODO: Check that MODIFICATIONS array contains only one member.
		
		# MBIN_CHANGE_TABLE is the only valid property of the (hopefully one) MODIFICATIONS array member. It is a required property.
		#TODO: Check for existence of the MBIN_CHANGE_TABLE property.
		
		# MBIN_CHANGE_TABLE is an array.
		#TODO: Check that MBIN_CHANGE_TABLE is an array with 1 or more members.
		
		# Each member represents an action of some sort to enact upon a given MBIN file.
		# Each member will have required MBIN_FILE_SOURCE and EXML_CHANGE_TABLE properties, and possibly a COMMENT property.
		# The only other valid actions besides changing an MBIN are discarding an MBIN, and performing REGEX actions, which seem to be pretty rare.
		#TODO: Check for the existence of the MBIN_FILE_SOURCE property
		#TODO: Check for the existence of the EXML_CHANGE_TABLE property
		
		# EXML_CHANGE_TABLE is an array.
		#TODO: Check that EXML_CHANGE_TABLE is an array with 1 or more members.
		
		# Each member represents a change or set of changes to perform on one or more EXML values within the given MBIN file.
		# There are several types of changes that can be defined as part of an EXML_CHANGE_TABLE member: file:///S:/AMUMSS/install/README/README-AMUMSS_Script_Rules.html#EXML_CHANGE_TABLE
		# However the VALUE_CHANGE_TABLE type of change is by far the most common.
		#TODO: Check that VALUE_CHANGE_TABLE exists. If not warn that checking for conflicts with other types of changes is not implemented yet.
		
		
	}
	
	function Get-ValueChanges($lua) {
		log "Identifying value changes..."
		
		$table = $lua.
		
		$lua
	}
	
	function Compare-Luas($data) {
		log "Comparing Lua files..."
		
		$data.ConflictPairs | ForEach-Object {
			$a = $_.Luas[0]
			$b = $_.Luas[1]
			log "$a <> $b" -L 1
			
			$data = Compare-ValueChanges $data
			#$data = Compare-Additions $data
			# and other possible functions: file:///S:/AMUMSS/install/README/README-AMUMSS_Script_Rules.html#NMS_MOD_DEFINITION_CONTAINER
		}
		
		$data
	}
	
	function Compare-ValueChanges($data) {
		log "Comparing value changes..." -L 2
		
		log "NOT YET IMPLEMENTED!" -L 3
		
		$data
	}
	
	function Do-Stuff {
		if($LuaFilePaths) {
			$conflictLuas = Get-GivenLuaFiles
		}
		else {
			$conflictMbins = Get-MbinFilesWithConflicts
			$conflictLuas = Get-LuaFilesWithConflicts $conflictMbins
		}
		$data = Get-ConflictPairs $conflictLuas
		$data = Get-LuaData $data
		
		$data = Compare-Luas $data
		
		if($PassThru) {
			$data
		}
	}
		
	Do-Stuff
	
	log "EOF"
}