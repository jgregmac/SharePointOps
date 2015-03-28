param (
    [string] $waUrl = "https://sharepoint2010.uvm.edu"
    [string] $inFile = "c:\local\scripts\guestnet-users.csv"
    [string] $SmtpServer = "smtp.uvm.edu"
    [string] $From = "gregory.mackinnon@uvm.edu"
    [string] $subj = 'Changes to partnerpoint.uvm.edu NIPN site'
    
)

Set-PSDebug -Strict

Add-PSSnapin -Name microsoft.SharePoint.PowerShell

[string] $bodyTemplate = @"
<!DOCTYPE html>
<html>
  <head>
    <meta content="text/html; charset=ISO-8859-1" http-equiv="content-type">
    <title></title>
  </head>
  <body>
    <p>Greetings user of the National Improvement Partnership Network
      "PartnerPoint" site:</p>
    <p>You are being contracted because UVM has retired the "PartnerPoint"
      system for guest access to our SharePoint services.&nbsp; This service has
      been replaced by our new "GuestNet" authentication system.&nbsp; As of
      March 10th 2013, "partnerpoint.uvm.edu" is offline.&nbsp; You now must use
      the following URL for access to the NIPN site:</p>
    <p> <a href="https://sharepoint.uvm.edu/sites/nipn">https://sharepoint.uvm.edu/sites/nipn</a></p>
    <p>Additionally, log-in procedures for the site have changed. Your original 
      PartnerPoint ID "--ppId--" no longer is valid.  Instead, please use your new 
      SharePoint GuestNet credentials, provided below:</p>
    <p>Username: GUEST\--user--<br>
      Password: --pass--</p>
    <p>Your account sponsor, Ginny Cincotta, can verify the authenticity of this
      message, and will be able to handle requests for password resets, account
      retirement, or additional access privileges. Her contact information
      follows:</p>
    <p>Ginny Cincotta<br>
      VCHIP Executive Assistant<br>
      University of Vermont<br>
      Phone: 802-656-8309<br>
      Email: <a href="mailto:ginny.cincotta@uvm.edu">ginny.cincotta@uvm.edu</a></p>
    <p>We have made every effort to ensure a smooth transition to our new
      GuestNet account system. However, all service migrations have their
      difficulties. If Ginny cannot help you to resolve any access problems that
      you may experience, my team will work with her to reach a timely
      resolution.</p>
    <p>-J. Greg Mackinnon<br>
      ETS Systems Architecture and Administration<br>
      University of Vermont</p>
  </body>
</html>
"@

$mailList = Import-Csv -Path $inFile

#$mailList = $mailList | select -First 2

foreach ($person in $mailList) {
	$to = $person.'Email Address'
	$body = $bodyTemplate.Replace('--ppId--',$person.'Email Address')
	$body = $body.Replace('--user--',$person.Username)
	$body = $body.Replace('--pass--',$person.Password)
	Send-MailMessage -To $to -From $From -SmtpServer $SmtpServer -Subject $subj -BodyAsHtml $body
	write-host "Sent to: " + $to 
	#Write-Host $to
	#Write-Host $body
}