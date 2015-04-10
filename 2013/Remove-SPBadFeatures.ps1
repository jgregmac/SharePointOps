<#
.SYNOPSIS
    Disables all Site or Web-scoped features that were reported as problematic in the SharePoint
    ULS Upgrade Error logs.
.DESCRIPTION
    During the SharePoint Content Database upgrade process, features that are activated in a site 
    or web and that also are not present on the local farm will cause errors to be logged.

    This script will identify all of the feature GUIDs within the Upgrade Error logs, and then
    loop though all sites and webs on the local farm and attempt to deactivate these features.  
    This will not solve the problem completely, because any web parts that make use of the removed 
    feature likely will break.

    The script returns an array of all features that were removed, the url of the SharePoint object
    from which they were removed, and the result of the removal action (success or failure).

.PARAMETER waName
    URL of the SharePoint WebApplication from which to remove null features
.PARAMETER limit
    Number of site collections from which to remove the null features.  Default is all site 
    collections in the web application.
.PARAMETER upgradeLogDir
    Location of the SharePoint ULS logs (including any Upgrade-*-Error.log files).
.PARAMETER logFile
    CSV file that will be used to record all feature removal actions.
.PARAMETER WhatIf
    Simulates the run by reporting features to be removed, but does not actually remove the features.
#>
[cmdletBinding()]
param(
    [string]$waName = 'https://spwinauth.uvm.edu',
    [string]$limit = 'All',
    [string]$upgradeLogDir = 'E:\SharePoint\Logs',
    [string]$logFile = 'c:\local\temp\Remove-SPBadFeatures.csv',
    [switch]$WhatIf
)

#Array that will contain the results of this script:
$outArray = @()

#Load the SharePoint PowerShell cmdlets:
Add-PSSnapin microsoft.sharepoint.powershell

#Get failing feature GUIDs from the SharePoint Upgrade error logs:
push-location $upgradeLogDir
[string[]]$badGuids = Get-Content Upgrade-*-error.log | % {
  $_ -match 'feature.+\[(?<guid>[0-9a-z]+-[0-9a-z-]+[^\]]+)\]' `
  | % {if ($matches.guid) {$matches.guid} } } | sort -Unique
pop-location
#If there are no bad features reported, there is no need to continue...
if ($badGuids.count -eq 0) {
    Write-Host "No missing features have been reported in the upgrade logs.  Exiting..." -ForegroundColor Yellow
    Exit 0
}

function Disable-SPFlaggedFeatures {
#Removes features from the specified SharePoint object (where the object must be a 
# PSSite or PSWeb) that match any entry in the input array "guids".
    [cmdletBinding()]
    param(
        [parameter(Mandatory=$true)]$SPObject,
        [parameter(Mandatory=$true)][array]$guids,
        [switch]$WhatIf
    )
    #Array for holding results of this function:
    $returns = @()
    #Console output formatting:
    [string]$indent = ''
    [ConsoleColor]$color = 'Cyan'
    [string]$out = $indent + "Evaluating object: " + $SPObject.url
    Write-Host $out -ForegroundColor $color
    #Determine the SharePoint object type:
    if ($SPObject -is [Microsoft.Sharepoint.SPSite]) {
        [string]$objType = 'Site'
        $indent = '  '
        $color = 'White'
    } elseif ($SPObject -is [Microsoft.Sharepoint.SPWeb]) {
        [string]$objType = 'Web'
        $indent = '    '
        $color = 'Gray'   
    }
    #Collect features in the site or web that are scoped to that object, 
    # AND that have a DefinitionID matching the list provided in the -guids parameter:
    [array]$features = $site.features | ? {
        ($_.FeatureDefinitionScope -eq $ObjType) -and ($guids -contains $_.definitionId)
    }
    #If we get any matching features:
    if ($features.count -gt 0) {
        [string]$out = $indent + 'Removing features from ' + $objType + ' : ' + $site.url
        write-host $out -ForegroundColor $color
        foreach ($fea in $features) {
            $out = $indent + "    Removing [" + $fea.DefinitionId + "] from '" + $fea.parent.url + "'."
            write-host $out -ForegroundColor Yellow
            if ($WhatIf) { 
                continue #skip the rest of this foreach loop pass...
            }
            try { #Try to disable the feature:
                Disable-SPFeature -Identity $fea.DefinitionId -url $fea.parent.url -force -confirm:$false -ea Stop
                [bool]$success = $true
            } catch {
                #If disabling the feature failed:
                [bool]$success = $false
                $out = "Error removing feature: [" + $fea.DefinitionId + "]`r`n"
                $Out += 'Message: ' + $_.Exception
                Write-Error $out
            } finally {
                #Build a property bag containing the results of the Disable-SPFeature command:
                $props = @{
                    ObjectType  = $objType
                    FeatureGuid = $fea.DefinitionId 
                    Url         = $SPObject.Url
                    Success     = $success
                } # End Props
            } #End Try/Catch/Finally
            $returns += New-Object -TypeName PSObject -Property $props
        } #End Foreach $fea
    } # End If $features.count
    return $returns
} #End Function

#####################################################################
# Begin Main Loop:
write-host "Collecting all sites..." -ForegroundColor Cyan
[array]$sites = Get-SPSite -WebApplication $waName -Limit $limit
#Loop though all sites:
foreach ($site in $sites) {
    #Attempt to remove features from the site collection:
    if ($WhatIf) {
        $WhatIfPreference = $true
        $outArray += Disable-SPFlaggedFeatures -spObject $site -guids $badGuids
        $WhatIfPreference = $false
    }
    [array]$webs = Get-SPWeb -Site $site.url -Limit All
    #Loop though all webs in the site collection:
    foreach ($web in $webs) {
        if ($WhatIf) {
            $WhatIfPreference = $true
            #Attempt to remove features from the web:
            $outArray += Disable-SPFlaggedFeatures -spObject $web -guids $badGuids
            $WhatIfPreference = $false
        }
        $web.dispose()
    }
    $site.dispose()
}

if ($logFile) {
    if (Test-Path $logFile) {remove-item $logFile -Force -Confirm:$false}
    $outArray | Export-Csv -Path $logFile -Append 
}
return $outArray
# End Main Loop
#####################################################################

#Problem with this loop:
# If the scope is "farm", we have a problem because I don't think we can remove farm features that do not exist.
