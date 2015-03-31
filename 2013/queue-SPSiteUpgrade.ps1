Add-PSSnapin -Name microsoft.sharepoint.powershell
$wa = Get-SPWebApplication -Identity https://spwinauth.uvm.edu

#Discover all Sites
$sites = Get-spSite -webapplication $wa -limit All

$sites | upgrade-spsite -versionupgrade -queueonly

$stats = @()

$cdbs = Get-SPContentDatabase -WebApplication $wa
foreach ($cdb in $cdbs) {
   $stats += Get-SPSiteUpgradeSessionInfo -ContentDatabase $cdb -ShowCompleted -ShowInProgress -ShowFailed | Select-Object -Property status
}

#$(Get-SPSiteUpgradeSessionInfo -ContentDatabase sp_webapp_content_1 -ShowCompleted -ShowInProgress -ShowFailed | Select-Object -Property status | ? {$_.status -match "completed"}).count