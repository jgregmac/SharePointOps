add-pssnapin microsoft.sharepoint.powershell 		
$dbs = @('sp_webapp_content_1','sp_webapp_content_2','sp_webapp_content_3')

$block = {
    Mount-SPContentDatabase -name $input -DatabaseServer msdbag1 -WebApplication https://spwinauth.uvm.edu
}

Foreach ($db in $dbs) {
    Start-Job -InputObject $db -ScriptBlock $block -Name $db
}

[bool]$jobsComplete = $false
do {
    if (
        (get-job -Name 'sp_webapp_content_1').state = 'Completed' -and
        (get-job -Name 'sp_webapp_content_2').state = 'Completed' -and
        (get-job -Name 'sp_webapp_content_3').state = 'Completed'
    ) {
        write-host "Database mounting jobs are now complete."
        $jobsComplete = $true
    } else {
        write-host "Jobs are not complete.  Will check again in 60 seconds..."
        Start-Sleep -Seconds 60
    }
    
} while (
    $jobsComplete = $false
)

get-job | Receive-Job

Remove-SPSite -Identity https://spwinauth.uvm.edu/sites/Qreports -Confirm:$false -GradualDelete:$false
start-sleep -Seconds 30
Mount-SPContentDatabase -name 'sp_webapp_content_4' -DatabaseServer msdbag1 -webApplication https://spwinauth.uvm.edu