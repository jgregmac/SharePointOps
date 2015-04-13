<# Original Source:
http://blogs.msdn.com/b/russmax/archive/2012/01/28/sharepoint-powershell-script-series-part-5-exporting-the-crawl-log-to-a-csv-file.aspx

Note that the "Microsoft.Office.Server.search.Administration.Logviewer" 
class is not present in SharePoint 2013, so this script will not work
on that platform.  Boo!

Use Microsoft.Office.Search.Administration.CrawlLog instead.
#>

<# ============================================================== 
// 
// Microsoft provides programming examples for illustration only, 
// without warranty either expressed or implied, including, but not 
// limited to, the implied warranties of merchantability and/or 
// fitness for a particular purpose. 
// 
// This sample assumes that you are familiar with the programming 
// language being demonstrated and the tools used to create and debug 
// procedures. Microsoft support professionals can help explain the 
// functionality of a particular procedure, but they will not modify 
// these examples to provide added functionality or construct 
// procedures to meet your specific needs. If you have limited 
// programming experience, you may want to contact a Microsoft 
// Certified Partner or the Microsoft fee-based consulting line at 
// (800) 936-5200. 
// 
// For more information about Microsoft Certified Partners, please 
// visit the following Microsoft Web site: 
// https://partner.microsoft.com/global/30000104 
// 
// Author: Russ Maxwell (russmax@microsoft.com) 
// 
// ----------------------------------------------------------  #>


[Void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint") 
[Void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Server.Search") 

Start-SPAssignment -Global

############################# 
#Function to Export the Data# 
############################# 
function exportThis 
{ 
    $output = Read-Host "Enter a location for the output file (For Example: c:\logs\)" 
    $filename = Read-Host "Enter a filename" 
    $stores = $ssa.CrawlStores 
    $storectr = $stores.count 
    $name = $output + "\" + $filename + ".csv" 
    
    if($storectr -eq '1') 
    { 
        $logViewer = New-Object Microsoft.Office.Server.Search.Administration.Logviewer $ssa 
        $i = 0 
        $urlOutput = $logViewer.GetCurrentCrawlLogData($crawlLogFilters, ([ref] $i)) 
        Write-Host "# of Crawl Entries Produced" $urlOutput.Rows.Count 
        $urlOutput | Export-Csv $name -NoTypeInformation 
        Write-Host "Your results were exported to: " $name 
    } 
    
    elseif($storectr -gt '1') 
    { 
        $f = 1 
        foreach($store in $stores) 
        { 
            Write-Host "In the " $f " iteration of store object" 
            $logViewer = New-Object Microsoft.Office.Server.Search.Administration.Logviewer $store 
            $i = 0 
            $urlOutput = $logViewer.GetCurrentCrawlLogData($crawlLogFilters, ([ref] $i))  
            $ctr = $urlOutput.Rows.Count 
            $officialCTR += $ctr 
                  
            if($f -eq '1') 
            { 
                $finalDT = New-Object System.Data.DataTable 
                $finalDT = $urlOutput.Copy() 
            } 
            else 
            { 
                $finalDT.Merge($urlOutput) 
            } 
          
            $f++ 
          
        } 
    }        
    $finalDT | Export-Csv $name -NoTypeInformation          
    Write-Host "# of Crawl Entries Produced" $officialCTR 
}



##################################### 
#Choose a Search Service Application# 
##################################### 
$ssa = Get-SPEnterpriseSearchServiceApplication 
$ssaName = $ssa | ForEach-Object {$_.Name} 
Write-Host "Choose a Search Service Application to review crawl logs" 
Write-Host 
$num = 1

Foreach($sa in $ssa) 
{
    Write-Host $num $sa.Name 
    $num++ 
}

Write-Host 
$result = Read-Host "Enter the number next to the desired Search Service Application and press enter"

$num = 1 
Foreach($i in $ssa) 
{ 
    if($num -eq $result) {$ssa = $i} 
    $num++ 
} 
Write-Host 

############################################### 
#Create a Logviewer and Crawl Log FilterObject# 
############################################### 
$crawlLogFilters = New-Object Microsoft.Office.Server.Search.Administration.CrawlLogFilters 

###################### 
#Let the Admin choose# 
###################### 
Write-Host "How would you like to filter the crawl log?" 
Write-Host "1 Filter Based on a URL" 
Write-Host "2 Filter Based on Content Source" 
Write-Host "3 Export without a Filter" 
Write-Host 
$choice = Read-Host "Enter 1, 2, or 3 and press enter" 
Write-Host 
Write-Host 
Write-Host "1 Export only errors" 
Write-Host "2 Export All (Success, Warning, and Errors" 
$type = Read-Host "Enter 1 or 2 and press enter" 
Write-Host


if($choice -eq '1') 
{ 
    $url = Read-Host "Enter the URL to filter on" 
                
    ################################### 
    #Create Property and add to filter# 
    ################################### 
    $totalentryProp = New-Object Microsoft.Office.Server.Search.Administration.CrawlLogFilterProperty 
    $totalentryProp = [Microsoft.Office.Server.Search.Administration.CrawlLogFilterProperty]::TotalEntries 
    $urlProp = New-Object Microsoft.Office.Server.Search.Administration.CrawlLogFilterProperty 
    $urlProp = [Microsoft.Office.Server.Search.Administration.CrawlLogFilterProperty]::Url 
    $stringOp = New-Object Microsoft.Office.Server.Search.Administration.StringFilterOperator 
    $stringOp = [Microsoft.Office.Server.Search.Administration.StringFilterOperator]::Contains 
    $crawlLogFilters.AddFilter($urlProp, $stringOp,$url) 
    $crawlLogFilters.AddFilter($totalentryProp, "1,000,000") 
                
    if($type -eq '1') 
    { 
        $typeEnum = New-Object Microsoft.Office.Server.Search.Administration.MessageType 
        $typeEnum = [Microsoft.Office.Server.Search.Administration.MessageType]::Error 
        $crawlLogFilters.AddFilter($typeEnum) 
    } 
                                
    #Calling exportThisfunction 
    exportThis 
}

elseif($choice -eq '2') 
{             
    ######################### 
    #Choose a content source# 
    ######################### 
    $content = New-Object Microsoft.Office.Server.Search.Administration.Content($ssa) 
    $contentsources = $content.ContentSources 
                
    Write-Host "Choose a Content Source to filter on" 
    Write-Host 
    $num = 1

    Foreach($c in $contentsources) 
    { 
        Write-Host $num": " $c.Name 
        $num++ 
    }

    $result = Read-Host "Enter the associated # press enter"

    $num = 1 
    Foreach($c in $contentsources) 
    { 
        if($num -eq $result) {$contentSource = $c} 
        $num++ 
    } 
    Write-Host "You chose" $contentSource.Name 
    $id = $contentSource.Id      
                
    ################################### 
    #Create Property and add to filter# 
    ################################### 
    $totalentryProp = New-Object Microsoft.Office.Server.Search.Administration.CrawlLogFilterProperty 
    $totalentryProp = [Microsoft.Office.Server.Search.Administration.CrawlLogFilterProperty]::TotalEntries 
    $csProp = New-Object Microsoft.Office.Server.Search.Administration.CrawlLogFilterProperty 
    $csProp = [Microsoft.Office.Server.Search.Administration.CrawlLogFilterProperty]::ContentSourceId 
    $crawlLogFilters.AddFilter($csProp, $id) 
    $crawlLogFilters.AddFilter($totalentryProp, "1,000,000") 
                
    if($type -eq '1') 
    { 
        $typeEnum = New-Object Microsoft.Office.Server.Search.Administration.MessageType 
        $typeEnum = [Microsoft.Office.Server.Search.Administration.MessageType]::Error 
        $crawlLogFilters.AddFilter($typeEnum) 
    } 
                
    #Calling exportThisfunction# 
    exportThis             
}    
elseif($choice -eq '3') 
{ 
    $catProp = New-Object Microsoft.Office.Server.Search.Administration.CatalogType 
    $catProp = [Microsoft.Office.Server.Search.Administration.CatalogType]::PortalContent 
    $crawlLogFilters.AddFilter($catProp) 
    $catProp2 = New-Object Microsoft.Office.Server.Search.Administration.CatalogType 
    $catProp2 = [Microsoft.Office.Server.Search.Administration.CatalogType]::ProfileContent 
    $crawlLogFilters.AddFilter($catProp2) 
    $totalentryProp = New-Object Microsoft.Office.Server.Search.Administration.CrawlLogFilterProperty 
    $totalentryProp = [Microsoft.Office.Server.Search.Administration.CrawlLogFilterProperty]::TotalEntries 
    $crawlLogFilters.AddFilter($totalentryProp, "1,000,000") 
                
    if($type -eq '1') 
    { 
        $typeEnum = New-Object Microsoft.Office.Server.Search.Administration.MessageType 
        $typeEnum = [Microsoft.Office.Server.Search.Administration.MessageType]::Error 
        $crawlLogFilters.AddFilter($typeEnum) 
    } 
                
    #Calling exportThisfunction 
    exportThis 
} 
     
Stop-SPAssignment –Global
