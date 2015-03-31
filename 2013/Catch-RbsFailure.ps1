if ( (Get-PSSnapin -Name MySnapin -ErrorAction SilentlyContinue) -eq $null )
{ 
    add-pssnapin microsoft.sharepoint.powershell;
}
$cbd = Get-SPContentDatabase -Identity SP_WebApp_Content_2;
$rbs = $cdb.RemoteBlobStorageSettings


try {
    $rbs.Migrate() 
} catch [system.exception] {
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    $StackTrace = $_.Exception.StackTrace
    "Error Message: $ErrorMessage" | out-file c:\local\migrateFail.log -append
    "Failed Item: $FailedItem" | out-file c:\local\migrateFail.log -append
    "Stack Trace: $StackTrace" | out-file c:\local\migrateFail.log -append
    $myError = $_
    Break
} finally {
    $Time=Get-Date
    "This script failed at $Time" | out-file c:\local\migrateFail.log -append
}