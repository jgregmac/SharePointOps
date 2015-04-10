<#
.SYNOPSIS
    Disables all Site or Web-scoped features with NULL definition ids.
.DESCRIPTION
    Each SharePoint feature that is activated in a Site Collection or Web should have a defined 
    "Definition" (str format), which is a lookup value taken from the "DefinitionID" GUID value.
    If this ID field is NULL, then the feature is not installed on the local farm, and the 
    feature sshould be deactivated in its current scope to prevent errors.

    This script will loop though all sites and webs on the local farm and attempt to deactivate 
    these features.  This will not solve the problem completely, because any web parts that make 
    use of the removed feature likely will break.
#>
[cmdletBinding()]
param([string]$waName = 'https://spwinauth.uvm.edu')

Add-PSSnapin microsoft.sharepoint.powershell

function Disable-SPNullFeaturesInScope {
    [cmdletBinding()]
    param(
        [parameter(Mandatory=$true)]$SPObject,
        [switch]$WhatIf
    )
    [string]$indent = ''
    [ConsoleColor]$color = 'Cyan'
    [string]$out = $indent + "Evaluating object: " + $SPObject.url
    Write-Host $out -ForegroundColor $color
    if ($SPObject -is [Microsoft.Sharepoint.SPSite]) {
        [string]$objType = 'Site'
        $indent = '  '
        $color = 'White'
    } elseif ($SPObject -is [Microsoft.Sharepoint.SPWeb]) {
        [string]$objType = 'Web'
        $indent = '    '
        $color = 'Gray'   
    }
    [array]$features = $site.features | ? {
        ($_.FeatureDefinitionScope -eq $ObjType) -and ($_.Definition -eq $null)
    }
    if ($features.count -gt 0) {
        [string]$out = $indent + 'Removing features from ' + $objType + ' : ' + $site.url
        write-host $out -ForegroundColor $color
        foreach ($fea in $features) {
            $out = $indent + "    Removing [" + $fea.DefinitionId + "] from '" + $fea.parent.url + "'."
            write-host $out -ForegroundColor Yellow
            if ($WhatIf) { continue }
            Disable-SPFeature -Identity $fea.DefinitionId -url $fea.parent.url -force -confirm:$false
        }
    }
}

$wa = Get-SPWebApplication $waName
write-host "Collecting all sites..." -ForegroundColor Cyan
[array]$sites = $wa.Sites
foreach ($site in $sites) {
    Disable-SPNullFeaturesInScope -spObject $site -WhatIf
    [array]$webs = Get-SPWeb -Site $site.url -Limit All
    foreach ($web in $webs) {
        Disable-SPNullFeaturesInScope -spObject $web -WhatIf
        $web.dispose()
    }
    $site.dispose()
}


#Problem with this loop:
# If the scope is "farm", we have a problem because I don't think we can remove farm features that do not exist.

#We also need a reporting feature here... which features were removed from which sites?  Which features could we not remove?

