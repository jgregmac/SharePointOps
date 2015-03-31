 function enumerateWebParts($Url) {
     $site = new-object Microsoft.SharePoint.SPSite $Url    
     foreach($web in $site.AllWebs) {
        if ([Microsoft.SharePoint.Publishing.PublishingWeb]::IsPublishingWeb($web)) {
             $pWeb = [Microsoft.SharePoint.Publishing.PublishingWeb]::GetPublishingWeb($web)
             $pages = $pWeb.PagesList
             foreach ($item in $pages.Items) {
                 $fileUrl = $webUrl + “/” + $item.File.Url
                 $manager = $item.file.GetLimitedWebPartManager([System.Web.UI.WebControls.Webparts.PersonalizationScope]::Shared);
                 $wps = $manager.webparts
                 $wps | select-object @{Expression={$pWeb.Url};Label=”Web URL”},@{Expression={$fileUrl};Label=”Page URL”}, DisplayTitle, IsVisible, @{Expression={$_.GetType().ToString()};Label=”Type”}
             }
        }
        else {
             $pages = $null
             $pages = $web.Lists["Site Pages"]            
             if ($pages) {
                 foreach ($item in $pages.Items) {
                     $fileUrl = $webUrl + “/” + $item.File.Url
                     $manager = $item.file.GetLimitedWebPartManager([System.Web.UI.WebControls.Webparts.PersonalizationScope]::Shared);
                     $wps = $manager.webparts
                     $wps | select-object @{Expression={$pWeb.Url};Label=”Web URL”},@{Expression={$fileUrl};Label=”Page URL”}, DisplayTitle, IsVisible, @{Expression={$_.GetType().ToString()};Label=”Type”}
                 }
             }
             else {
             }
        }
        Write-Host “… completed processing” $web
     }
 }
 
 $row = enumerateWebParts(‘http://spwinauth.uvm.edu/sites/FDC’)
 $row | Out-GridView