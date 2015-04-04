# Bad webs and sites in this context are webs that were created using templates
# that are not supported under SharePoint 2013.
param(
    [string]$webApplication = "https://sharepoint.uvm.edu",
    [string]$outDir = "C:\local\temp\"
)
set-psdebug -Strict

# Output file paths:
[string]$allWebsFile = $outDir + 'allWebs.csv'
[string]$badWebsFile = $outdir + 'badWebs.csv'
[string]$badSitesFile = $outDir + 'badSites.txt'

# Initialize log file:
if (Test-Path $allWebsFile) {Remove-Item $allWebsFile -Force -Confirm:$false}
[string[]]$allWebs = @()
# Add header row for CSV:
#[string]$out = 'template,templateID,WebUrl,SiteUrl,SiteAdmins,contentDB,webLastModified'
#$out | out-file -FilePath $allWebsFile -Append

# Load SharePoint PowerShell CmdLets:
Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue

function Test-SPFeatures {
    <#
    Takes an input SharePoint web or site object, loops though the features, and compares them
    to items in the test array.  Any matches are returned.  If excludeArray is provided, these
    results will be omitted.
    #>
    [cmdletBinding()]
    param(
        $PSObj,
        $testArray,
        $excludeArray
    )
    [string[]]$features = $PSObj.features | % {$_.DefinitionID.ToString()}
    #Hey... what about features that have a blank definition id?
    [array[]]$badFeas = @()
    foreach ($fea in $features) {
        $out = "Testing: " + $fea
        write-verbose $out
        [bool]$Matched = $false
        foreach ($src in $testArray){
            if ($src -eq $fea) {
                $out = "    Source-only feature found: " + $src
                write-verbose $out
                [bool]$Matched = $true
                [bool]$Excluded = $false
                $out = "    Matched boolean set to: " + $Matched
                write-debug $out
                foreach ($exclude in $excludeArray) {
                    if ($exclude -eq $src) {
                        write-verbose "        Feature is excluded from reporting.  Skipping."
                        $Excluded = $true
                        $out = "        Excluded boolean set to: " + $Excluded
                        write-debug $out
                    }
                }
                if (-not $Excluded) {
                    write-verbose "        Feature is not excluded.  Reporting..."
                    # Cast the returned site info to an array:
                    $badFeas += $src
                }
            } 
        }
        if (-not $Matched) {
            write-verbose "        Feature is not in the test array. Skipping."
        }
    }
    if ($badFeas.count -gt 0) {
        return $badFeas
    }
}

function New-BadSiteReport {
    [cmdletBinding()]
    param(
        $web,
        [string[]]$badFeatNames
    )
    if ($web.IsRootWeb) {
        [string]$rootWeb = $web.Url
    } else {
        [string]$rootWeb = $web.Site.Url
    }
    [array]$admins = @()
    $admins += $web.SiteAdministrators | % {$_.UserLogin}
    $properties = @{
        'WebTemplate'     = $web.webTemplate;
        #'webTemplateId'   = $web.webTemplateID; 
        'WebUrl'          = $web.Url;
        'SiteUrl'         = $rootWeb;
        'Admins'          = $admins;
        'Owner'           = $web.site.owner.userLogin;
        'BadFeatures'     = $badFeatNames;
        'ContentDatabase' = $web.site.contentdatabase.name;
        'LastModified'    = $web.lastItemModifiedDate.ToShortDateString()
    }
    $web.Dispose()
    $object = New-Object -TypeName PSObject -Prop $properties
    return $object
}

#Collect all FeatureIDs in the farm:
$srcFeatures = @()
$srcFeatures += Get-SPFeature | Select-Object -Property Id,DisplayName,Scope

[array]$nrmSrcFeatures = @()
foreach ($src in $srcFeatures) {
    $properties = @{'id'=$src.id.toString();
                    'displayName'=$src.displayName;
                    'scope'=$src.scope.toString()}
    $object = New-Object –TypeName PSObject –Prop $properties
    $nrmSrcFeatures += $object
}
remove-variable srcFeatures

# Extract the feature IDs from Get-SPFeatures in string format:
[string[]]$srcs = @()
$srcs += $nrmSrcFeatures | % {$_.id} 

# Load featureIDs from the farm to which we will migrate
# Data comes from the Get-SPAllFeatures.ps1 script, run on the destination farm:
[array]$dstFeatures = Import-Csv c:\local\temp\2013Features.csv
[string[]]$dsts = @()
$dsts += $dstFeatures | % {$_.id} 

remove-variable dstFeatures

#Now collect the features that are present only in 2010 farm:
[array]$srcOnly = Compare-Object $srcs $dsts | ? {$_.sideIndicator -eq '<='} | % {,@($_.inputobject)}

remove-variable srcs,dsts

#Office WebApps feature IDs... these will be excluded from reporting:
[string[]]$okFeatures = @(`
    '8dfaf93d-e23c-4471-9347-07368668ddaf',`
    '893627d9-b5ef-482d-a3bf-2a605175ac36',`
    '738250ba-9327-4dc0-813a-a76928ba1842',`
    '1663ee19-e6ab-4d47-be1b-adeb27cfd9d2',`
    '3d433d02-cf49-4975-81b4-aede31e16edf',`
    'e995e28b-9ba8-4668-9933-cf5c146d7a9f',`
    '3cb475e7-4e87-45eb-a1f3-db96ad7cf313',`
    '5709298b-1876-4686-b257-f101a923f58d'`
)

#Hashtable for Template ID to Name lookups:
$srcOnlyHash = @{}
foreach ($obj in $nrmSrcFeatures) {
    foreach ($src in $srcOnly) {
        if ($obj.id -eq $src) {
            $srcOnlyHash.add($obj.id,$obj.displayName)
        }
    }
}

# What are the names of these features?
Write-host 'Bad Features:' -ForegroundColor DarkMagenta
$srcOnly | %{$srcOnlyHash.$($_)} | sort
write-host
write-host 'Not so bad features:' -ForegroundColor Green
$okFeatures | %{$srcOnlyHash.$($_)} | sort

Write-Host "Collecting all sites..." -ForegroundColor Cyan
[array]$Sites = Get-SPSite -WebApplication $webApplication -Limit All
#[array]$sites = get-spsite https://sharepoint.uvm.edu/sites/FDC

#[array[]]$badSites2 = @()
[array[]]$badWebs2 = @()

Write-host "Finding sites and webs that use bad features..."
foreach ($site in $sites) {
    [string[]]$badFeatIds = @()
    $badFeatIds += Test-SPFeatures -PSObj $site -testArray $srcOnly -excludeArray $okFeatures #-verbose
    [string[]]$badFeatNames = @()
    $badFeatNames += $badFeatIds | %{$srcOnlyHash.$($_)}
    $webs = @()
    $webs += $site.allwebs
    foreach ($web in $webs) {
        $badFeatIds += Test-SPFeatures -PSObj $web -testArray $srcOnly -excludeArray $okFeatures #-verbose
        # Don't re-initialize the array... we will aggregate site and web features together.
        #[string[]]$badFeatNames = @()
        $badFeatNames += $badFeatIds | %{$srcOnlyHash.$($_)}
        $badFeatNames = $badFeatNames | Sort -Unique
        $badWebs2 += New-BadSiteReport -web $web -badFeatNames $badFeatNames
        $web.Dispose()
    }
    $site.Dispose()
}

<#write-host "Gathering information about all webs..." -ForegroundColor Cyan
foreach ($site in $sites) {
    #Add logic to this loop that will flag any site that uses features that are not in the destination farm.
    $webs = @()
    $webs += $site.allwebs
    foreach ($web in $webs) {
        if ($web.IsRootWeb) {
            [string]$rootWeb = $web.Url
        } else {
            [string]$rootWeb = $web.Site.Url
        }
        [string]$admins = ''
        $web.SiteAdministrators | % {$admins += ($_.UserLogin + ';')}
        $admins += $web.SiteAdministrators | % {$_.UserLogin}
        [string]$out = $web.webTemplate + ',' `
            + $web.webTemplateID + ',' `
            + $web.Url.ToString() + ',' `
            + $rootWeb + ',' `
            + $admins + ',' `
            + $site.contentdatabase.name + ',"' `
            + $web.lastItemModifiedDate.ToShortDateString() + '"'
        $allWebs += $out
        $web.Dispose()
    }
    $site.Dispose()
}
$allWebs | Out-File -Append $allWebsFile

write-host "Reporting on webs that use an unsupported template..." -ForegroundColor Cyan
[array]$badWebs = @()
$badWebs += $allWebs | ? {$_ -notMatch '^STS|^WIKI|^MPS|^SGS|^BLOG|^,90'}
$badWebs > $badWebsFile
  
write-host "Writing a second report that contains just the site collection url and content database:" -ForegroundColor cyan
[array]$badSites = @()
foreach ($entry in $badWebs) {
    [array]$keep = $entry.split(',') | Select-Object -index 2,5 
    [string]$out = $keep[0] + ',' + $keep[1]
    $badSites += $out
}
$badSites | Sort-Object -Unique > $badSitesFile
#>