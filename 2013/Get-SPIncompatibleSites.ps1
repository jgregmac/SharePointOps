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

#Initialize log file:
if (Test-Path $allWebsFile) {Remove-Item $allWebsFile -Force -Confirm:$false}
[string[]]$allWebs = @()
#Add header row for CSV:
[string]$out = 'template,templateID,WebUrl,SiteUrl,SiteAdmins,contentDB,webLastModified'
$out | out-file -FilePath $allWebsFile -Append

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
            if ($src[0] -eq $fea) {
                $out = "    Source-only feature found: " + $src[1]
                write-verbose $out
                [bool]$Matched = $true
                [bool]$Excluded = $false
                $out = "    Matched boolean set to: " + $Matched
                write-debug $out
                foreach ($exclude in $excludeArray) {
                    if ($exclude -eq $src[0]) {
                        write-verbose "        Feature is excluded from reporting.  Skipping."
                        $Excluded = $true
                        $out = "        Excluded boolean set to: " + $Excluded
                        write-debug $out
                    }
                }
                if (-not $Excluded) {
                    write-verbose "        Feature is not excluded.  Reporting..."
                    # Cast the returned site info to an array:
                    $badFeas += ,@($src)
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

#Collect all FeatureIDs in the farm:
$srcFeatures = @()
$srcFeatures += Get-SPFeature | Select-Object -Property Id,DisplayName,Scope

#[array[]]$srcFeasNrm = @() #Normalized version of $srcFeas
#$srcFeasNrm | %{$src2 += ,@($_.id.tostring(),$_.displayname,$_.scope.tostring())}

#Add logic to load featureIDs in the farm to which we will migrate
#Essentially, we will do the same step as above on the destination Farm, export to file, and have this script import the the data to "destFeatures"
[array]$dstFeatures = Import-Csv c:\local\temp\2013Features.csv

# Let's get just the feature IDs. These are object type GUID, so need to convert to string for comparison:
[array[]]$s = @()
$s += $srcFeatures | %{,@($_.id.toString(),$_.displayName,$_.scope.toString())}
# Destination IDs already are string format:
[array]$d = @()
$d += $dstFeatures | %{,@($_.id,$_.displayName,$_.scope)}
remove-variable srcFeatures,dstFeatures

#Now collect the features that are present only in 2010 farm:
[array]$srcOnly = Compare-Object $s $d | ? {$_.sideIndicator -eq '<='} | % {,@($_.inputobject)}
remove-variable s,d

#Office WebApps feature IDs... these will be excluded from reporting:
$oWebApps = @(`
    '8dfaf93d-e23c-4471-9347-07368668ddaf',`
    '893627d9-b5ef-482d-a3bf-2a605175ac36',`
    '738250ba-9327-4dc0-813a-a76928ba1842',`
    '1663ee19-e6ab-4d47-be1b-adeb27cfd9d2',`
    '3d433d02-cf49-4975-81b4-aede31e16edf',`
    'e995e28b-9ba8-4668-9933-cf5c146d7a9f',`
    '3cb475e7-4e87-45eb-a1f3-db96ad7cf313',`
    '5709298b-1876-4686-b257-f101a923f58d'`
)

# What are the names of these features?
$srcOnly | %{$_[1]} | sort

Write-Host "Collecting all sites..." -ForegroundColor Cyan
#[array]$Sites = Get-SPSite -WebApplication $webApplication -Limit All
[array]$sites = get-spsite https://sharepoint.uvm.edu/sites/FDC

[array[]]$badSites2 = @()
[array[]]$badWebs2 = @()

Write-host "Finding sites and webs that use bad features..."
foreach ($site in $sites) {
    #Add logic to this loop that will flag any site that uses features that are not in the destination farm.
    #Problem here is that if only one bad feature is discovered, the result is an array of three items, instead 
    # of an array of one array with three items.  Must Fix!
    #maybe stop trying to manage this array of arrays.  It is needlessly confusing.
    $badSites2 += Test-SPFeatures -PSObj $site -testArray $srcOnly -excludeArray $oWebApps -verbose
    #if ($badFeas.count -gt 0) {
    #    $badSites2 += ,@($site.url,$badFeas)
    #}
    $webs = @()
    $webs += $site.allwebs
    foreach ($web in $webs) {
        $badWebs2 += Test-SPFeatures -PSObj $web -testArray $srcOnly -excludeArray $oWebApps -verbose
        $web.Dispose()
    }
    $site.Dispose()
}


write-host "Gathering information about all webs..." -ForegroundColor Cyan
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
