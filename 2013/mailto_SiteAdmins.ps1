<# mailTo_Site_Admins PowerShell Script:
2012-11-09, J. Greg Mackinnon
- Discovers all current site administrators in the SharePoint Web Application defined in $waUrl.
- Strips out sites owned by service accounts and "system".
- Removes common "admininstrator" account prefixes/suffixes.
- Sends the message defined in $bodyTemplate to the site owner. (Assumes the site UserLogon is a valid email when appending "@uvm.edu").
#>
Set-PSDebug -Strict
Add-PSSnapin -Name microsoft.SharePoint.PowerShell

[string] $waUrl = "https://sharepoint2013.uvm.edu"
[string] $SmtpServer = "smtp.uvm.edu"
[string] $From = "saa-ad@uvm.edu"

[string] $subjTemplate = 'Pending Upgrade for your site "-siteURL-"'
[string] $bodyTemplate = @"
<html>
  <head>
    <meta http-equiv="content-type" content="text/html;
      charset=ISO-8859-1">
  </head>
  <body>
    Hello again, SharePoint Users...<br>
    <br>
    You are being contacted because you are listed as a site collection administrator
	for an existing site hosted in https://sharepoint.uvm.edu.  We are planning to 
	upgrade this instance of SharePoint from the current "2010 Foundation" edition 
	to "2013 Standard" edition somtime in early June of 2014.
    <br>
    <br>
	Given the significant visual and functional changes in the new version of 
	SharePoint, we want to give you a chance to preview the new look and feel of 
	your site before the final upgrade.&nbsp; You now can view an upgraded copy of 
	your site, in read-only mode, at the following URL:<br>
    <a href="-siteURL-">-siteURL-</a><br>
    <br>
    If you need to make modifications to this preview site as part of your preparation for 
	the final upgrade, please write to:<br>
	"<ahref="mailto:saa-ad@uvm.edu">saa-ad@uvm.edu</a>" <br>
	with your site information.&nbsp Please keep in mind that all changes made to 
	this preview site will be destroyed during the final upgrade process.<br>
    <br>
    The upgrade will involve several major changes to SharePoint:<br>
    <ul>
      <li>Upgrade of the core technology from "SharePoint 2010 Foundation" 
        to "SharePoint 2013 Standard" <br>
        (see: <a
href="http://office.microsoft.com/en-us/support/whats-new-in-microsoft-sharepoint-server-2013-HA102785546.aspx">http://office.microsoft.com/en-us/support/whats-new-in-microsoft-sharepoint-server-2013-HA102785546.aspx</a>
        ).<br>
        and: <a
href="http://technet.microsoft.com/en-us/library/jj819267.aspx#bkmk_FeaturesOnPremise">http://technet.microsoft.com/en-us/library/jj819267.aspx#bkmk_FeaturesOnPremise</a>).</li>
      <li>A full visual upgrade of all existing sites to SharePoint 2013
        themes.</li>
      <li>Replacement of SharePoint-only "PartnerPoint" external user
        accounts with more-flexible UVM GuestNet accounts <br>
        (see: <a href="https://guestnet.uvm.edu/">https://guestnet.uvm.edu/</a>).<br>
      </li>
      <li>Replacement of Windows-integrated authentication with UVM's unified "Web 
	     Login" interface.
	  </li>
	  <li>
	    Introduction of "Managed Metadata Services" as part of the Standard Edition upgrade.<br>
		 (See: <a href="http://technet.microsoft.com/en-us/library/ee424402(v=office.15).aspx">http://technet.microsoft.com/en-us/library/ee424402(v=office.15).aspx</a>
	  </li>
    </ul>
    <p>At present, Guest authentication is not working, but we will have this functionality 
	in place before the final upgrade.<br>
    </p>
    <p>This upgrade is following a more aggressive timeline than is typical for our 
	department.  However, we feel it is critical that this upgrade be performed while
	human resources are available to complete the work.<br>
    </p>
    <p>-J. Greg Mackinnon | ETS Systems Architecture and Administration
      | x68251 <br>
    </p>
  </body>
</html>
"@

$wa = Get-SPWebApplication -Identity $waUrl

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

#$allAdmins = $allAdmins | Sort-Object -Unique
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
