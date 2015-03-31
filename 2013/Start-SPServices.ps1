##################
##Start Services##
##################
Write-Host "Starting Services" -foregroundcolor yellow 
Set-Service -Name "SPTimerV4" -startuptype Automatic
Set-Service -Name "IISADMIN" -startuptype Automatic

##Grabbing local server and starting services##
$servername = hostname
$server = get-spserver $servername

$srv2 = get-service "SPTimerV4"
$srv2.start()
$srv3 = get-service "IISADMIN"
$srv3.start()
$srv4 = get-service "OSearch15"
$srv5 = get-service "SPSearchHostController"

###Ensuring Search Services were stopped by script before Starting"
if($srch4srvctr -eq 2) {
    set-service -Name "OSearch15" -startuptype Automatic
    $srv4.start()
}
if($srch5srvctr -eq 2) {
    Set-service "SPSearchHostController" -startuptype Automatic
    $srv5.start()
}

###Resuming Search Service Application if paused###
if($srchctr -eq 2) {
    Write-Host "Resuming the Search Service Application" -foregroundcolor yellow
    $ssa = get-spenterprisesearchserviceapplication
    $ssa.resume()
}

Write-Host "Services are Started" -foregroundcolor green
Write-Host
Write-Host
Write-Host "Script Duration" -foregroundcolor yellow
Write-Host "Started: " $starttime -foregroundcolor yellow
Write-Host "Finished: " $finishtime -foregroundcolor yellow
Write-Host "Script Complete"
