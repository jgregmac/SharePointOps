<#
.Synopsis
	Use this PowerShell script to set the Lock State of a SharePoint Web Application to Unlock, ReadOnly, NoAdditions or NoAccess.
.Description
	This PowerShell script uses Set-SPSiteAdministration to set the Lock State of a SharePoint Web Application.
.Parameter AllContentWebApplications
    Switch value.  If specified, the specified LockState will be applied to all site collections in all content web applications in the local farm.
    (Central Administration web applications will be exempted.)
.Parameter WebAppUrl
    String value representing the URL of a valid SharePoint Web Application.
    If specfied, lock actions will be performed against this Web Application only.
.Parameter SiteUrl
    String value representing the URL of a valid SharePoint Site Collection.
    If specfied, lock actions will be performed against this Site Collection only.
.Parameter LockState
    Constrained set of values representing the lock state to which all site collections in the Web Application will be set.  Must be one of: 'Unlock','NoAdditions','ReadOnly', or 'NoAccess'.
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
#>
[CmdletBinding()]
Param(
    [string]$WebAppUrl,
    [string]$siteUrl,
    [parameter(Mandatory=$true)]
        [ValidateSet('Unlock','NoAdditions','ReadOnly','NoAccess')]
        [string]$LockState,
    [switch]$AllContentWebApplications
)

Add-PSSnapin Microsoft.SharePoint.PowerShell -erroraction SilentlyContinue

$allSites = @()

Start-SPAssignment -Global

#Collect sites to lock based on input parameters:
if ($AllContentWebApplications) {
    Write-Host "Setting all web applications to $($LockState)..."
    $WebApp = Get-SPWebApplication
    $WebApp | ForEach-Object {
        $AllSites += $WebApp | Get-SPSite -Limit All -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }
} elseif ($webAppUrl) {
    Write-Host "Setting all sites in the webapp: $WebAppUrl to: $lockState..." -ForegroundColor Yellow
    $WebApp = Get-SPWebApplication $WebAppUrl
    $AllSites += $WebApp | Get-SPSite -Limit All -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
} elseif ($siteUrl) {
    Write-Host "Setting just the site: $SiteUrl to: $lockState..." -ForegroundColor Yellow
    $AllSites += Get-SPSite -Identity $siteUrl -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
}
#Lock the sites collected in $AllSites:
$AllSites | ForEach-Object {
    $out = "Setting site " + $_.url + " to $lockState..."
    Write-Host $out -ForegroundColor Gray
    Set-SPSiteAdministration -LockState $LockState -Identity $_.url
}

Stop-SPAssignment -Global
Write-Host "Finished!" -ForegroundColor Green
