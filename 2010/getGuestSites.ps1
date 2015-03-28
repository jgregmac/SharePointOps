Set-PSDebug -Strict

[string] $waUrl = "https://sharepoint.uvm.edu"
[string] $SmtpServer = "smtp.uvm.edu"
[string] $From = "saa-ad@uvm.edu"
[string] $log = "c:\local\temp\getGuestSites.log"

[string] $subjTemplate = 'PartnerPoint information for your site: "-siteURL-"'
[string] $bodyTemplate = @"
<!DOCTYPE html>
<html>
  <head>
    <meta content="text/html; charset=windows-1252" http-equiv="content-type">
  </head>
  <body>
    <p>Greetings PartnerPoint Users:</p>
    <p>As announced previously, the Windows SharePoint Services installation at
      <a href="https://sharepoint.uvm.edu">https://sharepoint.uvm.edu</a> was
      upgraded to SharePoint Foundation 2010.&nbsp; As part of this upgrade, the
      SharePoint guest access tool known as "PartnerPoint" was retired.&nbsp; We
      have replaced PartnerPoint with extensions to the existing UVM GuestNet
      system.</p>
    <p>To ease the transition to GuestNet, we have created new GuestNet accounts
      for all non-expired PartnerPoint users.&nbsp; We also remapped existing
      permissions in SharePoint to these new GuestNet accounts.&nbsp; However,
      GuestNet users will not be able to log in with their old PartnerPoint
      credentials.&nbsp; Usernames and passwords have been updated for
      compatibility with GuestNet.&nbsp; PartnerPoint accounts used an email
      address for the account username, but this convention cannot be supported
      in GuestNet.&nbsp; Instead, GuestNet accounts follow the naming convention
      of [sponsorNetID].[firstLetterFirstName][firstSixCharsLastName].&nbsp; For
      example, an account sponsored by John Doe for a guest named Myron Kapoodle
      would take the default name "jdoe.mkapood".&nbsp; When authenticating to
      SharePoint, guests will have to enter their username in the format "GUEST\[GuestNetID]"
      (i.e "GUEST\jdoe.mkapood").</p>
    <p>To view the new usernames and passwords, you will need to visit <a href="https://account.uvm.edu">https://account.uvm.edu</a>,
      and follow the link under "Account Services" to <a href="https://account.uvm.edu/cgi-bin/accounts/guestnet-admin">Share
        computing resources with a campus guest</a>.&nbsp; From this page, you
      may add and delete guest accounts, and retrieve password data for existing
      accounts. </p>
    <p>Members of our team will be adding functionality to the GuestNet
      administration interface over the next week.&nbsp; Planned improvements
      include the ability to specify an expiration date for new accounts, the
      ability to extend the validity of existing accounts, the ability to email
      a welcome message (including password) to new or existing GuestNet users,
      and a bulk account creation interface.&nbsp; Additionally, in-line
      instructions for the use of the GuestNet management interface is under
      development.</p>
    <p>SharePoint-specific instructions for GuestNet access are under
      development here:<br>
      <a href="https://sharepoint.uvm.edu/SharePoint%20Howto/ExternalUsers.aspx">https://sharepoint.uvm.edu/SharePoint%20Howto/ExternalUsers.aspx</a></p>
    <p>In the meantime, if you are having problems with SharePoint and GuestNet
      integration, please do not hesitate to contact our team by writing to <a

        href="mailto:saa-ad@uvm.edu">saa-ad@uvm.edu</a>.&nbsp; If your needs are
      pressing, you can call my office number (802-656-8251), or page us in the
      event of an emergency (send text-only mail to <a href="mailto:winpage@status.uvm.edu">winpage@status.uvm.edu</a>).</p>
    <p>Thank you for your patience during this major service upgrade.</p>
    <p>Sincerely,</p>
    <p>J. Greg Mackinnon<br>
      ETS Systems Architecture and Administration<br>
      802-656-8251</p>
  </body>
</html>

"@

if ((Get-PSSnapin -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue) -eq $null) {
	Add-PSSnapin Microsoft.SharePoint.PowerShell
}

## Initialize output log:
if (Test-Path -LiteralPath $log) {
	Remove-Item -LiteralPath $log -Force
}

##Begin Main Loop:

#Get All SharePoint sites:
$sites = Get-SPSite -WebApplication $waUrl -Limit All
$ppwebs = @()

foreach ($site in $sites) {
	$webs = @()
	# Gets webs in current site
	$webs = $site | Get-SPWeb -Limit All 
	foreach ($web in $webs) {
		#"Site: " + $site.ServerRelativeUrl + " Web: " + $web.ServerRelativeUrl
		#Array containing all external users in the current Web: 
		$usrs = @()
		$usrs = $web | Get-SPUser -Limit All | ? {$_.UserLogin -match "adamuser:|GUEST\\"}
		if ($usrs.count -gt 0) {
			$ppwebs += $web
		}
	}
}

$ppsites = @()
foreach ($web in $ppwebs) {
	$ppsites += $web.Site
}
$ppsites = $ppsites | Sort-Object -Unique

$allAdmins = @()
foreach ($site in $ppsites) {
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
#$allAdmins = $allAdmins | ? {$_[0] -match "gcincott"}

foreach ($admin in $allAdmins) {
	[string] $to = $admin[0] + "@uvm.edu"
	[string] $siteUrl = $admin[1]
	#[string] $body = $bodyTemplate.Replace("-siteURL-",$siteUrl)
	$body = $bodyTemplate
	#$siteUrl = $siteUrl.Replace('2010','')
	[string] $subj = $subjTemplate.Replace("-siteURL-",$siteUrl)
	#Send-MailMessage -To $to -From $From -SmtpServer $SmtpServer -Subject $subj -BodyAsHtml $body 
	write-host "Sent to: " + $to + " from: " + $from + " subject: " + $subj
	#write-host "body: " + $body
}