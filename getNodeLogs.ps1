#
# Retrieve the grids logs
# it will prompt you for grid credentials
# Works on 13.3 and 13.4
#
#	Usage:
#		getNodeLogs.ps1 -GridUrl https://ifldev-bel1.cloud.infor.com:63906
#
#	-htmlOutput output to html
#	-funkyStuff enables some of the more complex filtering
#		-GreaterThan 'yyyy-MM-dd HH:mm:ss' greater than or equal to date
#		-SystemName <name> eg. M3Auto (case sensitive)
#		-LastDays <days> number of days prior to DateTime::Now
#
#	Example
#		.\getNodeLogs.ps1 -GridUrl https://ifldev-bel1.cloud.infor.com:63906 -funkyStuff -GreaterThan '2017-09-20' -SystemName M3Auto -htmlOutput >d:\data.html
#	writes an html to d:\data which is greater than or equal to '2017-09-20' related to the M3Auto system


param([Parameter(Mandatory = $true)][string]$GridUrl, [switch]$htmlOutput, [switch]$funkyStuff, [string]$GreaterThan, [string]$SystemName, [string]$LastDays)

$credentials = Get-Credential

$baseURL = $GridUrl + '/grid/rest/nodes/'

$processedLogs = New-Object System.Collections.Generic.List[System.Object]

$lastDate

function getdate($entry)
{
	$parsedDate = [DateTime]::MinValue
	
	if($entry.Length -gt 18)
	{
		$extractedDate = $entry.Substring(0,19)
		$result = [DateTime]::TryParse($extractedDate,[ref]$parsedDate)
	}
	
	return $parsedDate
}

function getRawDate($entry)
{
	$result = ""
	
	$parsedDate = getdate($entry)
	
	if($parsedDate -ne [DateTime]::MinValue)
	{
		$position = $entry.IndexOf("Z")
		
		if($position -ne -1)
		{
			if($entry.Length -gt $position)
			{
				$result = $entry.Substring(0, ($position + 1))
			}
		}
	}
	
	return $result
}

function getLogEntry($entry)
{
	$result = $entry;
	
	$rawDate = getRawDate($entry)
	
	if($rawDate.Length -gt 0)
	{
		$result = $entry.Substring($rawDate.Length)
	}
	
	return $result
}

function createLogObject 
{
	Param($Name, $EntryType, $entry)
	$result = New-Object PSObject

	Add-Member -InputObject $result -Name Name -MemberType NoteProperty -Value $Name
	Add-Member -InputObject $result -Name EntryType -MemberType NoteProperty -Value $EntryType

	$newDate = getdate($entry)

	$logEntry = getLogEntry($entry)
	$rawDate = getRawDate($entry)
	
	if($newDate -ne [DateTime]::MinValue)
	{
		$lastDate = $newDate
		$processedLogs.Add($result)
	}
	
	Add-Member -InputObject $result -Name LogDate -MemberType NoteProperty -Value $lastDate
	Add-Member -InputObject $result -Name LogDateRaw -MemberType NoteProperty -Value $rawDate
	Add-Member -InputObject $result -Name LogEntry -MemberType NoteProperty -Value $logEntry


	if($newDate -eq [DateTime]::MinValue)
	{
		if($processedLogs.Count -gt 0)
		{
			$separator = [Environment]::NewLine
			# if($htmlOutput -eq $true)
			# {
				# $separator = "::"
			# }
		
			$processedLogs[$processedLogs.Count - 1].LogEntry += ($separator + $entry)
		}
	}
	
	#return $result
}

function update($log)
{
	$processedEntries  = New-Object System.Collections.Generic.List[System.Object]
	#$log.Log | ForEach-Object { if($_.Length -gt 31) { $newDate = getdate($_); $lastDate; if($newDate -ne [DateTime]::MinValue) { $lastDate = $newDate};$entry = New-Object PSObject; Add-Member -InputObject $entry -Name LogDate -MemberType NoteProperty -Value $lastDate; Add-Member -InputObject $entry -Name LogDateRaw -MemberType NoteProperty -Value $_.Substring(0,31); Add-Member -InputObject $entry -MemberType NoteProperty -Name LogEntry -Value $_}}; $processedEntries.Add($entry);
	$log.Log | ForEach-Object { if($_.Length -gt 31) { $newDate = getdate($_); $rawDate = getRawDate($_); $logEntry = getLogEntry($_); $lastDate; if($newDate -ne [DateTime]::MinValue) { $lastDate = $newDate};$entry = New-Object PSObject; Add-Member -InputObject $entry -Name LogDate -MemberType NoteProperty -Value $lastDate; Add-Member -InputObject $entry -Name LogDateRaw -MemberType NoteProperty -Value $rawDate; Add-Member -InputObject $entry -MemberType NoteProperty -Name LogEntry -Value $logEntry}}; $processedEntries.Add($entry);
	Add-Member -InputObject $log -Name ProcessedLogs -MemberType NoteProperty -Value $processedEntries
}

function processLogEntry 
{
	Param($Name, $EntryType, $log)
	$log.Log | ForEach-Object { $newObject = createLogObject $Name $EntryType $_}
}

$nodes = Invoke-RestMethod -Uri $baseURL -Credential $credentials
#$nodes | Format-Table

$notes = $nodes | Where-Object {$_.loggerErrorCount -gt 0 -or $_.loggerWarningCount -gt 0} | select @{n='node';e={$baseURL + $_.jvmID + "/log?filter=NOTE"}},name
$errors = $nodes | Where-Object {$_.loggerErrorCount -gt 0} | select @{n='node';e={$baseURL + $_.jvmID + "/log?filter=ERROR"}},name
$warnings = $nodes | Where-Object {$_.loggerWarningCount -gt 0} | select @{n='node';e={$baseURL + $_.jvmID + "/log?filter=WARN"}},name

if($funkyStuff -eq $false)
{
	if($htmlOutput -eq $false)
	{
		$errors | ForEach-Object { Write-Output $_.name;Write-Output "=ERROR======E"; Invoke-RestMethod -Uri $_.node -Credential $credentials;Write-Output "===========E" }
		$warnings | ForEach-Object { Write-Output $_.name;Write-Output "=WARN=======W"; Invoke-RestMethod -Uri $_.node -Credential $credentials;Write-Output "===========W" }
		$notes | ForEach-Object { Write-Output $_.name;Write-Output "=NOTE=======N"; Invoke-RestMethod -Uri $_.node -Credential $credentials;Write-Output "===========N" }
	}
	else
	{
		Write-Output "<html><body>"
		
		$errors | ForEach-Object 	{ 		Write-Output "<h1>";		Write-Output $_.name;		Write-Output "</h1><p>";		Write-Output "<h2>Errors</h2><br><table border=1><tr><td>";		((Invoke-RestMethod -Uri $_.node -Credential $credentials) | %{$_ -split "`n"}  | %{$_ + "<br>"});		Write-Output "</td><tr></table>" 	}
		
		Write-Output "</body></html>"
		
	}
}
else
{
	$logEntries = New-Object System.Collections.Generic.List[System.Object]
	#$errors | ForEach-Object { $log = New-Object PSObject; Add-Member -InputObject $log -MemberType NoteProperty -Name Name -Value $_.name; Add-Member -InputObject $log -MemberType NoteProperty -Name Log -Value (Invoke-RestMethod -Uri $_.node -Credential $credentials);$logEntries.Add($log); }
	$errors | ForEach-Object { $log = New-Object PSObject; Add-Member -InputObject $log -MemberType NoteProperty -Name EntryType -Value 'ERROR'; Add-Member -InputObject $log -MemberType NoteProperty -Name Name -Value $_.name; Add-Member -InputObject $log -MemberType NoteProperty -Name Log -Value ((Invoke-RestMethod -Uri $_.node -Credential $credentials) | %{$_ -split "`n"});$logEntries.Add($log); }
	$warnings | ForEach-Object { $log = New-Object PSObject; Add-Member -InputObject $log -MemberType NoteProperty -Name EntryType -Value 'WARN'; Add-Member -InputObject $log -MemberType NoteProperty -Name Name -Value $_.name; Add-Member -InputObject $log -MemberType NoteProperty -Name Log -Value ((Invoke-RestMethod -Uri $_.node -Credential $credentials) | %{$_ -split "`n"}) ;$logEntries.Add($log); }
	$notes | ForEach-Object { $log = New-Object PSObject; Add-Member -InputObject $log -MemberType NoteProperty -Name EntryType -Value 'NOTE'; Add-Member -InputObject $log -MemberType NoteProperty -Name Name -Value $_.name; Add-Member -InputObject $log -MemberType NoteProperty -Name Log -Value ((Invoke-RestMethod -Uri $_.node -Credential $credentials) | %{$_ -split "`n"}) ;$logEntries.Add($log); }
	
	#$logEntries | ForEach-Object { update($_) }
	
	$logEntries | ForEach-Object { processLogEntry $_.Name $_.EntryType $_ }
	
	$result = $processedLogs
	
	$greaterThanDate = [DateTime]::MinValue
	$validDate = [DateTime]::TryParse($GreaterThan,[ref]$greaterThanDate)
	
	if($true -eq $validDate)
	{
		$result = $result | where {$_.LogDate -ge $greaterThanDate}
	}
	
	if($false -eq [String]::IsNullOrEmpty($SystemName))
	{
		$result = $result | where {$_.Name -eq $SystemName}
	}

	if($false -eq [String]::IsNullOrEmpty($LastDays))
	{
		$days = 0
		$validDays = [Int32]::TryParse($LastDays, [ref]$days)
		
		if($validDays -eq $true)
		{
			$days *= -1
			$filterDate = [DateTime]::Now.AddDays($days)
			$result = $result | where {$_.LogDate -ge $filterDate}
		}
	}
	
	if($htmlOutput -eq $false)
	{
		$result | Format-Table
	}
	else
	{
		$result | ConvertTo-Html
	}
	
}


