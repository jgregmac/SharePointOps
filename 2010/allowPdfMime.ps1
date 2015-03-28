$webApp = Get-SPWebApplication "https://sharepoint2010.uvm.edu"
 If ($webApp.AllowedInlineDownloadedMimeTypes -notcontains "application/pdf")
 {
   Write-Host -ForegroundColor White "Adding Pdf MIME Type..."
   $webApp.AllowedInlineDownloadedMimeTypes.Add("application/pdf")
   $webApp.Update()
   Write-Host -ForegroundColor White "Added and saved."
 } Else {
   Write-Host -ForegroundColor White "Pdf MIME type is already added."
 }