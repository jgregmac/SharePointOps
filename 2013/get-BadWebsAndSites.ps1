$waName = "https://spwinauth.uvm.edu"
$outDir = "C:\local\temp\"

set-psdebug -Strict
Add-PSSnapin Microsoft.SharePoint.Powershell -ErrorAction SilentlyContinue
$Sites = Get-SPSite -WebApplication $waName -Limit All

#Enumerate all webs and their template types:
[string] $allWebs = $outDir + 'allWebsWithTemplates.csv'
$Sites | % {$_.allWebs} | % { [string]$( $_.webTemplate + ',' + $_.webTemplateID + ',' + $_.Url.ToString() + ',"' + $_.site.lastContentModifiedDate.ToShortDateString() + '"' ) } > $allWebs

#Find Webs using unsupported templates:
[string] $badWebs = $outdir + 'badWebsWithTemplates.csv'
get-content $allWebs | select-string -NotMatch '^STS|^WIKI|^MPS|^SGS|^BLOG|^,90' > $badWebs

#Find Sites containing bad webs:
[string] $badSites = $outDir + 'badSites.txt'
Get-Content $badWebs | % {$_.split(',') | Select-Object -index 2} | % {get-spweb -Identity $_} | % {$_.site} | Sort-Object -Unique > $badSites
