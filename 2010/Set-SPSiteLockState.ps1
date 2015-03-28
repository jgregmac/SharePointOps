<#
.Synopsis
	Use this PowerShell script to set the Lock State of a SharePoint Web Application to Unlock, ReadOnly, NoAdditions or NoAccess.
.Description
	This PowerShell script uses Set-SPSiteAdministration to set the Lock State of a SharePoint Web Application.
.Example
	C:\PS>Set-SPSiteLockState -WebAppUrl http://intranet -LockState ReadOnly
	This example sets all site collections in a web application at http://intranet to read-only.
.Example
	C:\PS>Set-SPSiteLockState -AllContentWebApplications -LockState ReadOnly
	This example sets all web applications to read-only.
.Notes
	Name: Set-SPSiteLockState
	Author: Ryan Dennis
	Last Edit: 10/14/2011
	Keywords: Set Lock State, Set-SPSiteAdministration, Set-SPSiteLockState
.Link
	http://www.sharepointryan.com
 	http://twitter.com/SharePointRyan
.Inputs
	None
.Outputs
	None
#Requires -Version 2.0
#>
[CmdletBinding()]
Param(
[string]$WebAppUrl,
[string]$LockState=(Read-Host "Please enter a Lock State (Examples: Unlock, NoAccess, ReadOnly)"),
[switch]$AllContentWebApplications
)
Add-PSSnapin Microsoft.SharePoint.PowerShell -erroraction SilentlyContinue
Start-SPAssignment -Global
if($AllContentWebApplications){
Write-Host "Setting all web applications to $($LockState)..."
$WebApp = Get-SPWebApplication
	$WebApp | ForEach-Object{
	$AllSites = $WebApp | Get-SPSite -Limit All -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
		$AllSites | ForEach-Object{
		Set-SPSiteAdministration -LockState $LockState -Identity $_.url
		}
	}
}
else{
$WebApp = Get-SPWebApplication $WebAppUrl
$AllSites = $WebApp | Get-SPSite -Limit All -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
Write-Host "Setting $WebAppUrl to $lockState..." -ForegroundColor Yellow
$AllSites | ForEach-Object { Set-SPSiteAdministration -LockState $lockState -Identity $_.url }
}

Stop-SPAssignment -Global
Write-Host "Finished!" -ForegroundColor Green
