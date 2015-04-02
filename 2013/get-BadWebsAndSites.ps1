# Bad webs and sites in this context are webs that were created using templates
# that are not supported under SharePoint 2013.
set-psdebug -Strict

# Web Application to search:
[string]$waName = "https://spwinauth.uvm.edu"
# Output file paths:
[string]$outDir = "C:\local\temp\"
[string]$allWebs = $outDir + 'allWebs.csv'
[string]$badWebs = $outdir + 'badWebs.csv'
[string]$badSites = $outDir + 'badSites.txt'

Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
$Sites = Get-SPSite -WebApplication $waName -Limit All

#Enumerate all webs and their template types:
foreach ($site in $sites) {
    $webs = @()
    $webs += $site.allwebs
    foreach ($web in $webs) {
        [string]$out = $web.webTemplate + ',' ` 
            + $web.webTemplateID + ',' `
            + $web.Url.ToString() + ',' `
            + $site.contentdatabase.name + ',"' `
            + $site.lastContentModifiedDate.ToShortDateString() + '"'
        $out | out-file -FilePath $allWebs -Force
    }
}

#Find Webs using unsupported templates:
get-content $allWebs | select-string -NotMatch `
  '^STS|^WIKI|^MPS|^SGS|^BLOG|^,90' > $badWebs

#Find Sites containing bad webs:
Get-Content $badWebs | % {$_.split(',') | Select-Object -index 2} `
  | % {get-spweb -Identity $_} | % {$_.site} | Sort-Object -Unique > $badSites
