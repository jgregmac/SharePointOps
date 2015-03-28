[cmdletBinding()]
param(
	[parameter(Mandatory=$true,HelpMessage='Enter a username in samAccountName format.')][string][ValidatePattern('\b\w{1,8}\b')]$user, #match up to eight bounded alphanumerics 
	[parameter()][ValidatePattern('\b\w{1,16}\b')][string]$domain = 'CAMPUS',
	[parameter()][ValidatePattern('^http[s]*://\w+\.\w+')][string]$webApplication = 'https://sharepoint.uvm.edu',
	[string]$logPath = 'c:\local\temp\findSiteUser.log'
)
Set-PSDebug -Strict
if ((Get-PSSnapin -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue) -eq $null) {
	Add-PSSnapin Microsoft.SharePoint.PowerShell
}

## Initialize output log:
if (Test-Path -LiteralPath $logPath) {
	Remove-Item -LiteralPath $logPath -Force
}
[string]$out = "spUser,SPWeb"
$out | Out-File -FilePath $logPath 

#Set up a regex for matching the user in domain\username format:
if ($user -match '\.') {
	$userMatch = $user.Replace('.','\.')
} else {
	$userMatch = $user
}
$regexUser = '^' + $domain + '\\' + $userMatch + '$'

#Get All SharePoint sites:
$sites = Get-SPSite -WebApplication $webApplication -Limit All

##Begin Main Loop:
foreach ($site in $sites) {
	$webs = @()
	# Gets webs in current site
	$webs = $site | % {Get-SPWeb -Site $_ -Limit All; $_.Dispose()}
	foreach ($web in $webs) {
		Write-Host "Testing web:" $web.url -ForegroundColor cyan 
		$webUsers = @()
		$webUsers = $web | Get-SPUser -Limit All 
		foreach ($webUser in $webUsers) {
			#write-host "    Testing web user:" $webUser.UserLogin "using regex" $regexUser -ForegroundColor white
			if ($webUser.UserLogin -match $regexUser) {
				write-host "    Found match for" $regexUser "in" $webUser.UserLogin -ForegroundColor yellow
				[string] $out = $user + ',' + $web.Url
				$out | Out-File -Append -FilePath $logPath
			}
		}
		$web.Dispose()
	}
}