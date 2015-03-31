# Migrate-MassUsers.ps1
# J. Greg Mackinnon, 2015-03-23, adapted from Internet sources.
# Stupid name... should be "convert/migrate-spUserFormat", or some such.
[cmdletBinding(DefaultParameterSetName='convert')]
param (
    [parameter(
        ParameterSetName='document',
        Mandatory=$true,
        HelpMessage='Enter the Old Provider Name (Example -> Domain\ or i:0#.f|MembershipProvider|)'
    )]
    [string]$oldProvider,
    [parameter(
        ParameterSetName='document',
        Mandatory=$true,
        HelpMessage='Enter the New User Provider Name (Examples -> "Domain\" or "i:0e.t|MembershipProvider|")'
    )]
    [string]$newProvider,
    [parameter(
        ParameterSetName='document',
        Mandatory=$true,
        HelpMessage='Enter the UPN suffix for the new provider, if desired (Example -> "@domain.com")'
    )]
    [string]$newSuffix,
    [parameter(
        ParameterSetName='document',
        Mandatory=$true,
        HelpMessage='Enter the New Group Provider Name (Examples -> "Domain\", "c:0-.t|MembershipProvider|domain.com\")'
    )]
    [string]$newGroupProvider,
    [parameter(
        ParameterSetName='document',
        Mandatory=$false,
        HelpMessage='Provide the URL of the WebApplication for which to migrate users."'
    )]
    [ValidatePattern('^http[s]*://[A-Za-z]+\.[A-Za-z]+')]
    [string]$webApplication,
    [parameter(
        ParameterSetName='document',
        Mandatory=$false,
        HelpMessage='Provide the URL of the SharePoint site collection for which to migrate users."'
    )]
    [ValidatePattern('^http[s]*://\w+\.\w+')]
    [string]$site,
	[parameter(
		ParameterSetName='convert',
		Mandatory=$true
	)]
	[switch]$convert,
    [parameter(
        Mandatory=$true,
        HelpMessage='Please enter the path to which to save the MigrateUsers.csv file. (i.e. C:\migration)'
    )]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]$csvPath
)
Set-PSDebug -Strict
add-pssnapin microsoft.sharepoint.powershell -erroraction 0

$objCSV = @()

switch($PSCmdlet.ParameterSetName) {
    "convert" {
	    $objCSV = Import-CSV "$csvPath\MigrateUsers.csv"
        foreach ($object in $objCSV) {
            $user = Get-SPUser -identity $object.OldLogin -web $object.SiteCollection 
            write-host "Moving user:" $user "to:" $object.NewLogin "in site:" $object.SiteCollection 
            move-spuser -identity $user -newalias $object.NewLogin -ignoresid -Confirm:$false
        }
    } # End "convert" 

    "document" {
        Write-Host ""
        $sites = @()
        if($WebApplication) {
            $sites = get-spsite -WebApplication $webApplication -Limit All
        }
        elseif($site) {
            $sites = get-spsite $site
        }
        else {
            $sites = get-spsite -Limit All
        }

        foreach($site in $sites) {
		    $webs = @() #needed to prevent the next foreach from attempting to loop a non-array variable
            $webs = $site.AllWebs

            foreach($web in $webs) {
                # Get all of the users in a site
			    $users = @()
                $users = get-spuser -web $web -Limit All #added "-limit" since some webs may have large user lists.

                # Loop through each of the users in the site
                foreach($user in $users) {
                    # Create an array that will be used to split the user name from the domain/membership provider
                    $a=@()
                    $displayname = $user.DisplayName
                    $userlogin = $user.UserLogin

                    if(($userlogin -like "$oldprovider*") -and ($objCSV.OldLogin -notcontains $userlogin)) {
                        # Separate the user name from the domain/membership provider
                        if($userlogin.Contains('|')) {
                            $a = $userlogin.split("|")
                            $username = $a[1]

                            if($username.Contains('\')) {
                                $a = $username.split("\")
                                $username = $a[1]
                            }
                        }
                        elseif($userlogin.Contains('\')) {
                            $a = $userlogin.split("\")
                            $username = $a[1]
                        }
    
                        # Create the new username based on the given input
					    if ($user.IsDomainGroup) {
						    [string]$newalias = $newGroupProvider + $username
					    } else {
						    [string]$newalias = $newprovider + $username + $newsuffix
					    }
                    
                        $objUser = "" | select OldLogin,NewLogin,SiteCollection
	                    $objUser.OldLogin = $userLogin
                        $objUser.NewLogin = $newAlias
	                    $objUser.SiteCollection = $site.Url

	                    $objCSV += $objUser
                    }   
                } #End foreach user
				$web.dispose()
            } #End foreach web
            $site.Dispose()
        } #End foreach site
        $objCSV | Export-Csv "$csvPath\MigrateUsers.csv" -NoTypeInformation -Force
    } # End "document"

} # End switch
