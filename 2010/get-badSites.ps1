Add-PSSnapin -Name microsoft.sharepoint.powershell
$wa = Get-SPWebApplication -Identity https://sharepoint.uvm.edu

#Discover all Sites
$sites = Get-spSite -webapplication $wa -limit All
$webs = $sites | % {Get-SPWeb -Site $_ -Limit All}

#Discover bad site and web features:
$badSiteFeatures = $sites | % {$_.features | ? {$_.Definition -eq $null}}
$badWebFeatures = $webs | % {$_.features | ? {$_.Definition -eq $null}}