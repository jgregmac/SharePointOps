<# mailTo_Site_Admins PowerShell Script:
2012-11-09, J. Greg Mackinnon
- Discovers all current site administrators in the SharePoint Web Application defined in $waUrl.
- Strips out sites owned by service accounts and "system".
- Removes common "admininstrator" account prefixes/suffixes.
- Sends the message defined in $bodyTemplate to the site owner. (Assumes the site UserLogon is a valid email when appending "@uvm.edu").
#>
param (
    [string] $waUrl = "https://sharepoint2010.uvm.edu"
    [string] $SmtpServer = "smtp.uvm.edu"
    [string] $From = "saa-ad@uvm.edu"
)
Set-PSDebug -Strict
Add-PSSnapin -Name microsoft.SharePoint.PowerShell

$allAdmins = @()

[string] $subjTemplate = 'Pending Upgrade for your site "-siteURL-"'
#What /might/ be better would be to change this variable to take input from a text file, but maybe not.
[string] $bodyTemplate = @"
<html>
  <head>
    <meta http-equiv="content-type" content="text/html;
      charset=ISO-8859-1">
  </head>
  <body>
    Hello again, SharePoint User...<br>
    <br>
    The SharePoint upgrade previously planned for December 2012 was cenceled
	owing to unresolved problems in the upgrade process.  We believe that we
	have addressed these problems, and now are planning to complete the 
	upgrade before the end of Spring Break 2013 (March 8th, 2013).
    <br>
    <br>
    Again, given the significant visual and functional changes in the new
    version of SharePoint, we want to give you a final chance to preview the
    new look and feel of your site before the final upgrade.&nbsp; You now
    can view an upgraded copy of your site, in read-only mode, at the
    following URL:<br>
    <a href="-siteURL-">-siteURL-</a><br>
    <br>
    If you want to make modifications to this preview site to assist in
    preparation for the final upgrade, please write to "<a
      href="mailto:saa-ad@uvm.edu">saa-ad@uvm.edu</a>" with your site
    information.&nbsp; Please keep in mind that all changes made to this
    preview site will be destroyed during the final upgrade process.<br>
    <br>
    The upgrade will involve several major changes to SharePoint:<br>
    <ul>
      <li>Upgrade of the core technology from "Windows SharePoint
        Services 3.0" to "SharePoint 2010 Foundation" <br>
        (see: <a
href="http://sharepoint.microsoft.com/en-us/product/Related-Technologies/Pages/SharePoint-Foundation.aspx">http://sharepoint.microsoft.com/en-us/product/Related-Technologies/Pages/SharePoint-Foundation.aspx</a>
        ).<br>
        and: <a
href="http://sharepoint.microsoft.com/en-us/buy/pages/editions-comparison.aspx">http://sharepoint.microsoft.com/en-us/buy/pages/editions-comparison.aspx</a>).</li>
      <li>A full visual upgrade of all existing sites to SharePoint 2010
        themes <br>
        (see: <a
          href="http://msdn.microsoft.com/en-us/library/gg454789.aspx">http://msdn.microsoft.com/en-us/library/gg454789.aspx</a>).</li>
      <li>Replacement of SharePoint-only "PartnerPoint" external user
        accounts with more-flexible UVM GuestNet accounts <br>
        (see: <a href="https://guestnet.uvm.edu/">https://guestnet.uvm.edu/</a>).<br>
      </li>
      <li>Implementation of "Office WebApps" to allow in-browser viewing
        and editing of MS Office documents stored in SharePoint (even on
        client systems that do not have MS Office installed)<br>
        (see: <a href="http://office.microsoft.com/en-us/web-apps/">http://office.microsoft.com/en-us/web-apps/</a>).<br>
      </li>
      <li>Retirement of the "sharepointlite.uvm.edu" and
        "partnerpoint.uvm.edu" alternate-access names for SharePoint <br>
        (see: <a
          href="https://sharepoint.uvm.edu/SharePoint%20Howto/SharePointURLs.aspx">https://sharepoint.uvm.edu/SharePoint%20Howto/SharePointURLs.aspx</a>).</li>
    </ul>
    <p>In the nexy week we will be providing more details on the
      PartnerPoint to GuestNet account migration plan, and will provide
      site maintainers with an opportunity to test the upgrade process.<br>
    </p>
    <p>Following the upgrade, we will begin active planning for the
      upgrade to an edition of SharePoint 2013.&nbsp; The new version of
      SharePoint became generally available this month.&nbsp; The upgrade to
      SharePoint 2010 is a necessary precursor to implementing
      SharePoint 2013.<br>
    </p>
    <p>-J. Greg Mackinnon | ETS Systems Architecture and Administration
      | x68251 <br>
    </p>
  </body>
</html>
"@

$wa = Get-SPWebApplication -Identity $waUrl

foreach ($site in $wa.sites) {
	#Write-Host "Working with site: " + $site.url
	$siteAdmins = @()
	$siteAdmins = $site.RootWeb.SiteAdministrators
	ForEach ($admin in $siteAdmins) {
		#Write-Host "Adding Admin: " + $admin.UserLogin
		[string]$a = $($admin.UserLogin).Replace("CAMPUS\","")
		[string]$a = $a.replace(".adm","")
		[string]$a = $a.replace("-admin","")
		[string]$a = $a.replace("admin-","")
		if ($a -notmatch "sa_|\\system") { $allAdmins += , @($a; [string]$site.Url) }
	}
	$site.Dispose()
}

$allAdmins = $allAdmins | Sort-Object -Unique
#$allAdmins = $allAdmins | ? {$_[0] -match "jgm"} | Select-Object -Last 4

foreach ($admin in $allAdmins) {
	[string] $to = $admin[0] + "@uvm.edu"
	[string] $siteUrl = $admin[1]
	[string] $body = $bodyTemplate.Replace("-siteURL-",$siteUrl)
	$siteUrl = $siteUrl.Replace('2010','')
	[string] $subj = $subjTemplate.Replace("-siteURL-",$siteUrl)
	Send-MailMessage -To $to -From $From -SmtpServer $SmtpServer -Subject $subj -BodyAsHtml $body
	write-host "Sent to: " + $to + " from: " + $from + " subject: " + $subj
	#write-host "body: " + $body
}
