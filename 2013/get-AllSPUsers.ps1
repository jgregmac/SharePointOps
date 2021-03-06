$csvPath = 'c:\local\temp'
$objCSV = @()

$wa = Get-SPWebApplication -Identity 'https://spwinauth.uvm.edu'
$sites = Get-SPSite -WebApplication $wa -Limit All
foreach ($site in $sites) {
	$webs = @() #needed to prevent the next foreach from attempting to loop a non-array variable
    $webs = $site.AllWebs

    foreach ($web in $webs) {
        # Get all of the users in a site
		$users = @()
        $users = get-spuser -web $web -Limit All #added "-limit" since some webs may have large user lists.

        # Loop through each of the users in the site
        foreach ($user in $users) {
            # Create an array that will be used to split the user name from the domain/membership provider
            $displayname = $user.DisplayName
            $userlogin = $user.UserLogin
           
            $objUser = "" | select UserLogin,SiteCollection
            $objUser.UserLogin = $userLogin
            $objUser.SiteCollection = $site.Url

            $objCSV += $objUser
        }   
    }
$site.Dispose()
}


$objCSV | Export-Csv "$csvPath\UserReport.csv" -NoTypeInformation -Force