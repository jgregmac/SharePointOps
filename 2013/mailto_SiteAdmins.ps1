<# mailTo_Site_Admins PowerShell Script:
2012-11-09, J. Greg Mackinnon
- Discovers all current site administrators in the SharePoint Web Application defined in $waUrl.
- Strips out sites owned by service accounts and "system".
- Removes common "admininstrator" account prefixes/suffixes.
- Sends the message defined in $bodyTemplate to the site owner. (Assumes the site UserLogon is a valid email when appending "@uvm.edu").
#>
param(
    [string]$waUrl = "https://spwinauth.uvm.edu",
    [string]$SmtpServer = "smtp.uvm.edu",
    [string]$From = "saa-ad@uvm.edu",
    [string]$subjTemplate = 'Pending Upgrade for your site "-siteURL-"',
    [string]$templatePath = 'upgradeMailTemplate.html'
)
Set-PSDebug -Strict
Add-PSSnapin -Name microsoft.SharePoint.PowerShell

[string]$bodyTemplate = Get-Content -Path $templatePath

$sites = Get-SPSite -WebApplication $waUrl -Limit All
$allAdmins = @()
foreach ($site in $wa.sites) {
	#Write-Host "Working with site: " + $site.url
	$siteAdmins = @()
	$siteAdmins = $site.RootWeb.SiteAdministrators
	ForEach ($admin in $siteAdmins) {
		#Write-Host "Adding Admin: " + $admin.UserLogin
		[string]$a = $($admin.UserLogin).Replace("i:0e.t|adfs.uvm.edu|","")
		[string]$a = $a.Replace("@campus.ad.","@")
		[string]$a = $a.replace(".adm","")
		[string]$a = $a.replace("-admin","")
		[string]$a = $a.replace("admin-","")
		if ($a -notmatch "sa_|\\system") { $allAdmins += , @($a; [string]$site.Url) }
	}
	$site.Dispose()
}

#Production clause:
#$allAdmins = $allAdmins | Sort-Object -Unique
#During testing, I am filtering for one user (me) and limiting results to four sites:
$allAdmins = $allAdmins | ? {$_[0] -match "jgm"} | Select-Object -Last 4

foreach ($admin in $allAdmins) {
	[string] $to = $admin[0]
	[string] $siteUrl = $admin[1]
	$siteUrl = $siteUrl.Replace('spwinauth.uvm.edu','sharepoint2013.uvm.edu')
	[string] $body = $bodyTemplate.Replace("-siteURL-",$siteUrl)
	$siteUrl = $siteUrl.Replace('sharepoint2013.','sharepoint.')
	[string] $subj = $subjTemplate.Replace("-siteURL-",$siteUrl)
	Send-MailMessage -To $to -From $From -SmtpServer $SmtpServer -Subject $subj -BodyAsHtml $body
	write-host "Sent to: " + $to + " from: " + $from + " subject: " + $subj
	#write-host "body: " + $body
}
