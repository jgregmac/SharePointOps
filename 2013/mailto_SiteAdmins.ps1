<# mailTo_Site_Admins PowerShell Script:
2012-11-09, J. Greg Mackinnon
- Discovers all current site administrators in the SharePoint Web Application defined in $waUrl.
- Strips out sites owned by service accounts and "system".
- Removes common "admininstrator" account prefixes/suffixes.
- Sends the message defined in $bodyTemplate to the site owner. (Assumes the site UserLogon is a valid email when appending "@uvm.edu").
#>
[cmdletBinding()]
param(
    [string]$waUrl = "https://spwinauth.uvm.edu",
    [string]$SmtpServer = "smtp.uvm.edu",
    [string]$From = "saa-ad@uvm.edu",
    [string]$subjTemplate = 'Pending Upgrade for your site "-siteURL-"',
    [string]$templateName = 'upgradeMailTemplate.html',
    [string]$claimsPrefix = "i:0e.t|adfs.uvm.edu|",
    [string]$filter,
    [int]$limit
)
Set-PSDebug -Strict

#Cast the output varaible as a string to avoid type confusion later:
[string]$out = ''

Add-PSSnapin -Name microsoft.SharePoint.PowerShell

Write-Host "Loading the message body template..." -ForegroundColor Cyan
try {
    $templatePath = Join-Path -Path $PSScriptRoot -ChildPath $templateName
    [string]$bodyTemplate = Get-Content -Path $templatePath -ea stop
} catch {
    write-error "Could not read the message body template file."
    write-error $_.exception
    exit 100
}

Write-Host "Gathering all site collections..." -ForegroundColor Cyan
$sites = Get-SPSite -WebApplication $waUrl -Limit All -ea Stop -Verbose:$false
$allAdmins = @()
foreach ($site in $sites) {
    $out = ("  Working with site: " + $site.url)
	Write-Verbose $out
	$siteAdmins = @()
	$siteAdmins = $site.RootWeb.SiteAdministrators
	ForEach ($admin in $siteAdmins) {
		$out =  "  Found site Admin: " + $admin.UserLogin
        $out += "`r`n    Transforming the admin name to an email address..." 
        Write-Verbose $out
		[string]$a = $($admin.UserLogin).Replace($claimsPrefix,"")
		$a = $a.replace("@campus.ad.","@")
		$a = $a.replace(".adm","")
		$a = $a.replace("-admin","")
		$a = $a.replace("admin-","")
        $a = $a.replace("-tech","")
        #Convert the internal WebApp url to the user-facing, external Url:
        [string]$siteUrl = $site.url.Replace($waUrl,'https://sharepoint2013.uvm.edu')
        #Filter out system, service account, and windows-auth only users:
		if ($a -notmatch "sa_|\\system|i:0#\.w") { $allAdmins += , @($a; $siteUrl) }
        $out = "  Admin transformed to email address: " + $a
        Write-Verbose $out
	}
	$site.Dispose()
}

Write-Host "Filtering results..." -ForegroundColor Cyan
#Eliminate duplicates:
$allAdmins = $allAdmins | Sort-Object -Unique
#Additional filtering/limiting of results, if requested:
if ($filter) {
    $allAdmins = $allAdmins | ? {$_[0] -match $filter}
}
if ($limit) {
    $allAdmins = $allAdmins | Select-Object -First $limit
}

foreach ($admin in $allAdmins) {
	[string] $to = $admin[0]
    #
	[string] $siteUrl = $admin[1]
	[string] $body = $bodyTemplate.Replace("-siteURL-",$siteUrl)
    #The subject line will reference the current site url, not the upgrade url.  Transform...
	$siteUrl = $siteUrl.Replace('sharepoint2013.','sharepoint.')
	[string] $subj = $subjTemplate.Replace("-siteURL-",$siteUrl)
    try {
	    Send-MailMessage -To $to -From $From -SmtpServer $SmtpServer -Subject $subj -BodyAsHtml $body -ea stop
    } catch {
        write-error "Error sending mail message:"
        write-error $_.exception
        exit 200
    }
	$out = "  Sent mail to: " + $to + "`r`n  For site: `r`n    " + $siteUrl + "`r`n"
    write-host $out -ForegroundColor Gray
    #Add loop delay to prevent flooding:
    Start-Sleep -Seconds 3
}
