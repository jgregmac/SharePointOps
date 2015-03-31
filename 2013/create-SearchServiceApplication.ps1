Set-PSDebug -Strict
Add-PSSnapin microsoft.sharepoint.powershell -ErrorAction SilentlyContinue
$VerbosePreference = 'Continue'

#==============================================================
     #Search Service Application Configuration Settings
#==============================================================
  
 [string]$SearchApplicationPoolName = " SharePoint-SearchApplication"
 [string]$SearchApplicationPoolAccountName = "sa_spf2013_services"
 [string]$SearchServiceApplicationName = "Search Service Application"
 [string]$SearchServiceApplicationProxyName = "Search Service Application Proxy"
 [string]$DatabaseServer = "msdbag1"
 [string]$DatabaseName = "SP_SearchService"
 [string]$IndexPart1Path = "E:\SharePoint\Search\Index1"
 mkdir -Path $IndexPart1Path -Force
 [string]$server1 = "spaz1"
 [string]$server2 = "spaz2"
  
 #==============================================================
           #Search Application Pool
 #==============================================================
 Write-Host -ForegroundColor DarkGray "Checking if Search Application Pool exists"
 $SPServiceApplicationPool = Get-SPServiceApplicationPool -Identity $SearchApplicationPoolName -ErrorAction SilentlyContinue
  
 if (!$SPServiceApplicationPool)
 {
     Write-Host -ForegroundColor Yellow "Creating Search Application Pool"
     $SPServiceApplicationPool = New-SPServiceApplicationPool -Name $SearchApplicationPoolName -Account $SearchApplicationPoolAccountName -Verbose
 }
  
 #==============================================================
          #Start Search Service Instance on Servers
 #==============================================================
 [array]$servers = @($server1,$server2)
 foreach ($server in $servers) {
     $SearchServiceInstance = Get-SPEnterpriseSearchServiceInstance -Identity $server
     Write-Host -ForegroundColor DarkGray "Checking if SSI is Online on $Server"
     if ($SearchServiceInstance.Status -ne "Online"){
        Write-Host -ForegroundColor Yellow "Starting Search Service Instance..."
        Start-SPEnterpriseSearchServiceInstance -Identity $SearchServiceInstance
        While ($SearchServiceInstance.Status -ne "Online") {
            Start-Sleep -s 5
            #Refresh the search service instance with updated status...
            $SearchServiceInstance = Get-SPEnterpriseSearchServiceInstance -Identity $server
        }
        Write-Host -ForegroundColor Yellow "SSI on $Server is started"
    }
    
    $QueryProcServiceInstance = Get-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance -Identity $server
    Write-Host -ForegroundColor DarkGray "Checking if Query and Site Settings Service is Online on $Server"
    if ($QueryProcServiceInstance.Status -ne "Online") {
        Write-Host -ForegroundColor Yellow "Starting Query And Processing Service Instance..."
        Start-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance $QueryProcServiceInstance -ErrorAction SilentlyContinue
        While ($QueryProcServiceInstance.Status -ne "Online") {
            Start-Sleep -s 5
            $QueryProcServiceInstance = Get-SPEnterpriseSearchQueryAndSiteSettingsServiceInstance -Identity $server
        }
        Write-Host -ForegroundColor Yellow "Query and Site Settings Service is Online on $Server"
    }
}

Write-Host "You must now reboot any remote servers involved in this setup before continuing."
Write-Host "Press any key to continue ..."
#$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
#remove-variable x
  
 #==============================================================
           #Search Service Application
 #==============================================================
 Write-Host -ForegroundColor DarkGray "Checking if SSA exists"
 $SearchServiceApplication = Get-SPEnterpriseSearchServiceApplication -Identity $SearchServiceApplicationName -ErrorAction SilentlyContinue
 if (!$SearchServiceApplication)
 {
     Write-Host -ForegroundColor Yellow "Creating Search Service Application"
     $SearchServiceApplication = New-SPEnterpriseSearchServiceApplication -Name $SearchServiceApplicationName -ApplicationPool $SPServiceApplicationPool.Name -DatabaseServer  $DatabaseServer -DatabaseName $DatabaseName
 }
  
 Write-Host -ForegroundColor DarkGray "Checking if SSA Proxy exists"
 $SearchServiceApplicationProxy = Get-SPEnterpriseSearchServiceApplicationProxy -Identity $SearchServiceApplicationProxyName -ErrorAction SilentlyContinue
 if (!$SearchServiceApplicationProxy)
 {
     Write-Host -ForegroundColor Yellow "Creating SSA Proxy"
     New-SPEnterpriseSearchServiceApplicationProxy -Name $SearchServiceApplicationProxyName -SearchApplication $SearchServiceApplicationName
 }

 
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
 $SearchServiceInstanceServer1 = Get-SPEnterpriseSearchServiceInstance -Identity $server1
 $SearchServiceInstanceServer2 = Get-SPEnterpriseSearchServiceInstance -Identity $server2
 New-SPEnterpriseSearchAnalyticsProcessingComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer1
 New-SPEnterpriseSearchContentProcessingComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer1
 New-SPEnterpriseSearchQueryProcessingComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer1
 New-SPEnterpriseSearchCrawlComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer1 
 New-SPEnterpriseSearchAdminComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer1
  
 #==============================================================
 #Search Service Application Components on Server2.
 #Crawl, Query, and CPC
 #==============================================================
 <#New-SPEnterpriseSearchAnalyticsProcessingComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer2
 New-SPEnterpriseSearchContentProcessingComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer2
 New-SPEnterpriseSearchQueryProcessingComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer2
 New-SPEnterpriseSearchCrawlComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer2 
 New-SPEnterpriseSearchAdminComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer2#>

 #==============================================================
         #Index Components with replicas
 #==============================================================
  
 New-SPEnterpriseSearchIndexComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer1  -IndexPartition 0 -RootDirectory $IndexPart1Path 
 <#New-SPEnterpriseSearchIndexComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer2  -IndexPartition 0 -RootDirectory $IndexPart1Path #>
 #New-SPEnterpriseSearchIndexComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer2  -IndexPartition 1 -RootDirectory $IndexLocationServer2 
 #New-SPEnterpriseSearchIndexComponent -SearchTopology $NewSearchTopology -SearchServiceInstance $SearchServiceInstanceServer1  -IndexPartition 1 -RootDirectory $IndexLocationServer1 

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