# Bad webs and sites in this context are webs that were created using templates
# that are not supported under SharePoint 2013.
param(
    [string]$webApplication = "https://spwinauth.uvm.edu",
    [string]$outDir = "C:\local\temp\"
)
set-psdebug -Strict

# Output file paths:
[string]$allWebs = $outDir + 'allWebs.csv'
[string]$badWebs = $outdir + 'badWebs.csv'
[string]$badSites = $outDir + 'badSites.txt'

if (Test-Path $allWebs) {Remove-Item $allWebs -Force -Confirm:$false}
[string]$out = 'template,templateID,WebUrl,SiteUrl,SiteAdmins,contentDB,webLastModified'

Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
Write-Host "Collecting all sites..." -ForegroundColor Cyan
$Sites = Get-SPSite -WebApplication $webApplication -Limit All

write-host "Gathering information about sites..." -ForegroundColor Cyan
#Enumerate all webs and their template types:
foreach ($site in $sites) {
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
            + $site.lastItemModifiedDate.ToShortDateString() + '"'
        $out | out-file -FilePath $allWebs -Append
 
        $web.Dispose()
    }
    $site.Dispose()
}

write-host "Determing if the web uses an unsupported template..." -ForegroundColor Cyan
#Find Webs using unsupported templates:
get-content $allWebs | select-string -NotMatch `
  '^STS|^WIKI|^MPS|^SGS|^BLOG|^,90' > $badWebs

<# Pointless code...
write-host "Generating a simple list of sites containing bad webs..." -ForegroundColor Yellow
#Find Sites containing bad webs:
Get-Content $badWebs | % {$_.split(',') | Select-Object -index 2} `
  | % {get-spweb -Identity $_} | % {$_.site} | Sort-Object -Unique > $badSites
#>