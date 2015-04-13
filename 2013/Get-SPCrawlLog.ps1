#Attempts to get data out of the SharePoint crawl logs... FAIL!
#These calls to "GetCrawlHistory" return summary data, not specific URLs that are returning errors.  Sigh.

################################################################################
# One approach:
# https://social.technet.microsoft.com/Forums/en-US/9b1a8d7d-9211-4265-ad64-46dd74f0db25/monitoring-search-with-crawl-and-query-log-using-powershell?forum=sharepointadmin
################################################################################

Add-PSSnapin "Microsoft.SharePoint.PowerShell" -ErrorAction Stop;
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Server.Search");
$ssa = Get-SPEnterpriseSearchServiceApplication;
$sscContent = Get-SPEnterpriseSearchCrawlContentSource -SearchApplication $ssa 
$contentSource = Get-SPEnterpriseSearchCrawlContentSource -SearchApplication $ssa -Identity "SharePoint - sharepoint2013.uvm.edu";
$crawlLog = New-Object Microsoft.Office.Server.Search.Administration.CrawlLog $ssa;
$crawlLog.GetCrawlHistory(1000,$contentSource.Id);


################################################################################
# A different approach:
# http://cameron-verhelst.be/blog/2014/06/13/powershell-search-crawl-history/
################################################################################
$numberOfResults = 10
$contentSourceName = "SharePoint - sharepoint2013.uvm.edu"

[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Server.Search.Administration")

$ssa = Get-SPEnterpriseSearchServiceApplication
$contentSources = Get-SPEnterpriseSearchCrawlContentSource -SearchApplication $ssa
$contentSource = $contentSources | ? { $_.Name -eq $contentSourceName }

$crawlLog = new-object Microsoft.Office.Server.Search.Administration.CrawlLog($ssa)
$crawlHistory = $crawlLog.GetCrawlHistory($numberOfResults, $contentSource.Id)
$crawlHistory.Columns.Add("CrawlTypeName", [String]::Empty.GetType()) | Out-Null

# Label the crawl type
$labeledCrawlHistory = $crawlHistory | % {
 $_.CrawlTypeName = [Microsoft.Office.Server.Search.Administration.CrawlType]::Parse([Microsoft.Office.Server.Search.Administration.CrawlType], $_.CrawlType).ToString()
 return $_
}

$labeledCrawlHistory | Out-GridView