# Removes all users from the SharePoint webapplication specified in -webApplication where the 
# UserLogin value matches the RegEx string provided by -matchFilter.
# Generates a CSV report of all actions to -csvPath + -csvName.
# If -reportOnly is specified, no users will be removed, but the CSV report still will be generated.
param (
    $webApplication = 'https://spwinauth.uvm.edu',
    $matchFilter = '^adamuser:',
    $csvPath = 'c:\local\temp',
    $csvName = 'adamUsersReport.csv',
    [switch]$reportOnly
)

#Report file initialization:
$outPath = Join-Path $csvPath $csvName
if (Test-Path $outPath) {Remove-Item $outPath -Force -confirm:$false}

#Collection array for all matching "adamusers" found in SharePoint:
$objCSV = @()

$wa = Get-SPWebApplication -Identity $webApplication
$sites = Get-SPSite -WebApplication $wa -Limit All
foreach ($site in $sites) {
	$webs = @() #needed to prevent the next foreach from attempting to loop a non-array variable
    $webs = $site.AllWebs

    foreach ($web in $webs) {
        # Get all of the users in a site
		$users = @()
        #added "-limit" since some webs may have large user lists.
        $users = get-spuser -web $web -Limit All | ? {$_.UserLogin -match $matchFilter}

        # Loop through each of the users in the site
        foreach ($user in $users) {
            $out = "Discovered user: " + $user.UserLogin 
            Write-Host $out -ForegroundColor Gray
            if ($reportOnly) {
                [bool]$deleteStatus = $false
            } else {
                #Attempt to remove the user from the web:
                try {
                    remove-spuser -Identity $user -web $web -Confirm:$false -ea Stop
                    [bool]$deleteStatus = $true
                    $out = "Deleted user: " + $user.UserLogin
                    Write-Host $out -ForegroundColor White
                } catch {
                    $out = "Could not delete user: " + $user.UserLogin
                    Write-Host $out -ForegroundColor Yellow
                    [bool]$deleteStatus = $false
                }
            }
            # Create a property bag that will contain the user information:
            $displayname = $user.DisplayName
            $userlogin = $user.UserLogin
            $props = @{
                'UserLogin'      = $userLogin;
                'DisplayName'    = $displayname;
                'SiteCollection' = $web.Url;
                'Deleted'        = $deleteStatus
            }
            $objCSV += New-Object -TypeName PSObject -Property $props
        }
        $web.Dispose()
    }
    $site.Dispose()
}


$objCSV | Export-Csv $outPath -NoTypeInformation -Force