Set-PSDebug -Strict

[string] $waUrl = "https://sharepoint2010.uvm.edu"
[string] $log = "c:\local\temp\convertPartnerPointUsers.log"

if ((Get-PSSnapin -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue) -eq $null) {
	Add-PSSnapin Microsoft.SharePoint.PowerShell
}

## Initialize output log:
if (Test-Path -LiteralPath $log) {
	Remove-Item -LiteralPath $log -Force
}
[string]$out = "ppUser,gnUser,SPWeb,bMoveCompleted,DisplayName,bDisplayNameSet"
$out | Out-File -FilePath $log 

## Get account transformation data:
$pparr = @()
$pparr = Import-Csv -Path c:\local\scripts\pp_migration_mappings.csv
#remove extraneous data from import file
$pparr = $pparr | Select-Object -Property ppname,gnname 
#Initialize as Hash table.
$pptable = @{}
#Convert the standard array to a hash table:
foreach ($usr in $pparr) { 
	$pptable[$usr.ppname] = $usr.gnname
}

##Begin Main Loop:

#Get All SharePoint sites:
$sites = Get-SPSite -WebApplication $waUrl -Limit All

foreach ($site in $sites) {
	$webs = @()
	# Gets webs in current site
	$webs = $site | Get-SPWeb -Limit All 
	foreach ($web in $webs) {
		#"Site: " + $site.ServerRelativeUrl + " Web: " + $web.ServerRelativeUrl
		#Array containing all external users in the current Web: 
		$usrs = @()
		$usrs = $web | Get-SPUser -Limit All | ? {$_.UserLogin -match "adamuser:"} #| ? {$_.UserLogin -match "GUEST\\"}  
		if ($usrs) { #test to see if users were found
			foreach ($usr in $usrs) {
				[string] $ppusr = $usr.UserLogin #get the original User ID
				#extract the CN component, since this is in our hash table
				[string] $ppCn = $ppusr.Split(":") | Select-Object -Last 1 
				if ($gnusr) {Clear-Variable gnusr} #clean environment before test
					#Commented code block used for testing results on specific users:
					<#if ($ppusr -match "jgreg") {
						$ppSpUsr = Get-SPUser -Identity $ppusr -Web $web
						$out = "$ppSpUsr is in site: " + $web.url
						$out 
						$out = "Display Name is: " + $ppSpUsr.Name
						$out
					}#>
				$gnusr = $pptable.get_Item($ppCn) #lookup the new user ID.
				if ($gnusr) {#Test to see if the user has a new ID
					# write-host "PP User: $ppusr With GN entry: $gnusr"
					
					# "Move" the SharePoint entry (meaning, migrate the account to the new directory provider):
					[string] $gnSam = 'GUEST\' + $gnusr
					[string] $out = $ppusr + ',' + $gnSam + ',' + $web.Url + ','
					#Get the SharePoint User object for the user to move.
					$ppSpUsr = Get-SPUser -Identity $ppusr -Web $web 
					Move-SPUser -Identity $ppSpUsr -NewAlias $gnSam -IgnoreSID -Confirm:$false
					$out += [string]$? + ','
					
					#Update the Display Name in SharePoint
					$gnDispNm = (Get-ADUser -Identity $gnusr -Server guest.uvm.edu -Properties DisplayName).DisplayName
					$out += $gnDispNm + ','
					$ppSpUsr.Name = $gnDispNm
					$ppSpUsr.Update()
					$out += [string]$?			
					$out | Out-File -Append -FilePath $log	
				}
			}
		}
	}
}