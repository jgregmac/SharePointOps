Add-PSSnapin microsoft.sharepoint.powershell

$IndexLocationServer1 = "E:\SharePoint\Search\Index"  
mkdir -Path $IndexLocationServer1 -Force 
$IndexLocationServer2 = "E:\SharePoint\Search\Index"  
mkdir -Path $IndexLocationServer2 -Force 
$server2 = "spaz2"
# Server1 is the local server where the script is run. 

$SearchServiceApplication = Get-SPEnterpriseSearchServiceApplication -ErrorAction SilentlyContinue
 if (!$SearchServiceApplication) {
    Write-Host "No Search Service Application Exists... Exiting"
    exit
}
 
 #==============================================================
          #Start Search Service Instance on Server1
 #==============================================================
 $SearchServiceInstanceServer1 = Get-SPEnterpriseSearchServiceInstance -local
 Write-Host -ForegroundColor DarkGray "Checking if SSI is Online on Server1"
 if($SearchServiceInstanceServer1.Status -ne "Online")
 {
   Write-Host -ForegroundColor Yellow "Starting Search Service Instance"
   Start-SPEnterpriseSearchServiceInstance -Identity $SearchServiceInstanceServer1
   While ($SearchServiceInstanceServer1.Status -ne "Online")
   {
       Start-Sleep -s 5
   }
   Write-Host -ForegroundColor Yellow "SSI on $env:computername was started"
 } else {
    Write-Host -ForegroundColor Yellow "SSI on $env:computername is already started"
 }
  
 #==============================================================
         #Start Search Service Instance on Server2
 #==============================================================
 $SearchServiceInstanceServer2 = Get-SPEnterpriseSearchServiceInstance -Identity $server2
 Write-Host -ForegroundColor DarkGray "Checking if SSI is Online on Server2"
 if($SearchServiceInstanceServer2.Status -ne "Online")
 {
   Write-Host -ForegroundColor Yellow "Starting Search Service Instance"
   Start-SPEnterpriseSearchServiceInstance -Identity $SearchServiceInstanceServer2
   While ($SearchServiceInstanceServer2.Status -ne "Online")
   {
       Start-Sleep -s 5
   }
   Write-Host -ForegroundColor Yellow "SSI on $server2 was started"
 } else {
    Write-Host -ForegroundColor Yellow "SSI on $server2 is already started"
 }

 ### HOLD UP BUBBY!
 # If you just started the search service on server2, you /will/ need to reboot the host before continuing.
 # (/Unless/ your service accounts have local admin rights, which they really should not.)
 pause
 
 #==============================================================
  #Cannot make changes to topology in Active State.
  #Create new topology to add components
 #==============================================================
  
 $InitialSearchTopology = $SearchServiceApplication | Get-SPEnterpriseSearchTopology -Active 
 $NewSearchTopology = $SearchServiceApplication | New-SPEnterpriseSearchTopology
  
 #==============================================================
         #Search Service Application Components on Server1
         #Creating all components except Index (created later)     
 #==============================================================
 New-SPEnterpriseSearchAnalyticsProcessingComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer1
 New-SPEnterpriseSearchContentProcessingComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer1
 New-SPEnterpriseSearchQueryProcessingComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer1
 New-SPEnterpriseSearchCrawlComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer1 
 New-SPEnterpriseSearchAdminComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer1
  
 #==============================================================
 #Search Service Application Components on Server2.
 #Crawl, Query, and CPC
 #==============================================================
 New-SPEnterpriseSearchAnalyticsProcessingComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer2
 New-SPEnterpriseSearchContentProcessingComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer2
 New-SPEnterpriseSearchQueryProcessingComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer2
 New-SPEnterpriseSearchCrawlComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer2 
 New-SPEnterpriseSearchAdminComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer2

 #==============================================================
         #Index Components with replicas
 #==============================================================
  
 New-SPEnterpriseSearchIndexComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer1  -IndexPartition 0 -RootDirectory $IndexLocationServer1 
 New-SPEnterpriseSearchIndexComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer2  -IndexPartition 0 -RootDirectory $IndexLocationServer2 
 New-SPEnterpriseSearchIndexComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer2  -IndexPartition 1 -RootDirectory $IndexLocationServer2 
 New-SPEnterpriseSearchIndexComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer1  -IndexPartition 1 -RootDirectory $IndexLocationServer1 

 #==============================================================
   #Setting Search Topology using Set-SPEnterpriseSearchTopology
 #==============================================================
 Set-SPEnterpriseSearchTopology -Identity $NewSearchTopology

 #==============================================================
                 #Clean-Up Operation
 #==============================================================
 Write-Host -ForegroundColor DarkGray "Deleting old topology"
 Remove-SPEnterpriseSearchTopology -Identity $InitialSearchTopology -Confirm:$false
 Write-Host -ForegroundColor Yellow "Old topology deleted"
 
 #==============================================================
                 #Check Search Topology
 #==============================================================
 Get-SPEnterpriseSearchStatus -SearchApplication $SearchServiceApplication -Text
 Write-Host -ForegroundColor Yellow "Search Service Application and Topology is configured!!"