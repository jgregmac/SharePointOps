# Bad Features in this context are features that are referenced in a site but 
# do not have matching assemblies available on the local server.  These
# features will not work, and likely will create errors on page load.﻿

Add-PSSnapin microsoft.sharepoint.powershell
[string] $waName = 'https://spwinauth.uvm.edu'
[string] $logDir = 'e:\SharePoint\Logs\'

$badGuids = Get-Content Upgrade-*-error.log | % {
  $_ -match 'feature.+\[(?<guid>[0-9a-z]+-[0-9a-z-]+[^\]]+)\]' `
  | % {if ($matches.guid) {$matches.guid} } } | sort -Unique

write-host "Collecting all sites..." -ForegroundColor Cyan
[array] $sites = Get-SPSite -Limit All -WebApplication $waName
write-host "Collecting all webs..." -ForegroundColor Cyan
$webs = @()
[array] $webs += $sites | % {Get-SPWeb -Site $_ -Limit All}


# Bad feature discovery method... find all features with a null feature
# definition under the site or web object "features" property.
write-host "Finding bad site-scoped features..." -ForegroundColor Cyan
$badSiteFeatures = $sites | % {$_.features | ? {$_.Definition -eq $null}}
write-host "Finding bad web-scoped features..." -ForegroundColor Cyan
$badWebFeatures = $webs | % {$_.features | ? {$_.Definition -eq $null}}

# Alternate discovery method... find all features with definitionId contained
# in the badGuids array (no idea if this works... need to test on a fresh
# import):
write-host "Finding bad site-scoped features..." -ForegroundColor Cyan
$badSiteFeatures = $sites | % {$_.features | ? {$badGuids.Contains($_.DefinitionId)}}
write-host "Finding bad web-scoped features..." -ForegroundColor Cyan
$badWebFeatures = $webs | % {$_.features | ? {$badGuids.Contains($_.DefinitionId)}}

#Report of all bad site and web feature guids:
[string[]] $badSiteFeatureGuids = @()
$badSiteFeatureGuids += $badSiteFeatures | % {$_.definitionid} | sort -Unique
[string[]] $badWebFeatureGuids = @()
$badWebFeatureGuids += $badWebFeatures | % {$_.definitionid} | sort -Unique
#End report

# Deactivate bad features in the site collection scope:
write-host "Now removing site-scoped bad features..." -ForegroundColor Green
foreach ($fea in $badSiteFeatures) {
    write-host "    Removing ["$fea.DefinitionId"] from '"$fea.parent.url"'." -ForegroundColor Gray
    Disable-SPFeature -Identity $fea.DefinitionId -url $fea.parent.url -force -confirm:$false
}

# Deactivate bad features in the web site scope:
write-host "Now removing web-scoped bad features..." -ForegroundColor Green
foreach ($fea in $badWebFeatures) {
    write-host "    Removing ["$fea.DefinitionId"] from '"$fea.parent.url"'." -ForegroundColor Gray
    Disable-SPFeature -Identity $fea.DefinitionId -url $fea.parent.url -force -confirm:$false
    write-host "    Just in case... Removing ["$fea.DefinitionId"] from '"$fea.parent.site.url"'." `
        -ForegroundColor Gray
    Disable-SPFeature -Identity $fea.DefinitionId -url $fea.parent.site.url -force -confirm:$false
}
#Maybe we should do this at the web application layer as well?  SPWebApplication object have a 
# "features" property as well...
#Nope!  Investigation shows that there are no null feature definitions at the WebApp layer (not 
# surprising really, since we did not migrate the webapp itself)

#A different approach would be use use a dictionary of known bad feature IDs.  Loop though the sites
# matching each feature against the bad feature dictionary:
#[array] $badGuids = @('badGuid1','badGuid2', ...)
<#
foreach ($site in $sites) {
   #write-host $site.url -ForegroundColor Yellow;
    $guids = $site.features.deinitionid.guid
    foreach ($guid in $guids){
        if ($badGuids.Contains($guid)) {
            write-host $site.url 'has a bad feature with guid' $guid
            #Disable-SPFeature $site.features.definitionid.guid -URL $site.url -force -confirm:$false ;
           #$site.dispose() ;
        }

    }
}

foreach ($web in $webs) {
   write-host $web.url -ForegroundColor Yellow;
    $guids = $web.features.deinitionid.guid
    foreach ($guid in $guids){
        if ($badGuids.Contains($guid)) {
            write-host $web.url 'has a bad feature with guid' $guid
            #Disable-SPFeature $site.features.definitionid.guid -URL $site.url -force -confirm:$false ;
           #$site.dispose() ;
        }
    }
}
#>
