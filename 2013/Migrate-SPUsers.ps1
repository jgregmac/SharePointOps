<#
.SYNOPSIS
    Migrate-SPUsers Script, by J. Greg Mackinnon (derrived from unattributed script found on the Internet)
    Used to document and convert user and group entries in SharePoint from Windows or Claims provider format to a new Claims provider format.
.DESCRIPTION
    This script can be executed in two modes:
        In "Document" mode (the default), a CSV file will be generated that enumerates all SharePoint users and groups recorded in all SharePoint "webs", and shows the new account details that will be applied.
        In "Convert" mode, the changes generated in the CSV files from "Document" mode will be applied.
    This two-step process makes it possible to review the planned migration before committing. 
.PARAMETER oldProvider 
    Mandatory string variable.
    Specifies the original Windows account domain or claims provider prefix.
    Enter the Old Provider Name (Example -> Domain\ or i:0#.f|MembershipProvider|)
.PARAMETER newProvider
    Mandatory string variable.
    Specifies the new claims provider prefix to which users and groups will be migrated.
    Enter the New User Provider Name (Examples -> "Domain\" or "i:0e.t|MembershipProvider|")
.PARAMETER newSuffix
    Mandatory string variable.
    Specifies the new UPN-style sufix to be appended to user accounts at conversion time.
    Enter the UPN suffix for the new provider, if desired (Example -> "@domain.com")
.PARAMETER newGroupProvider
    Mandatory string variable.
    Specifies the new claim prefix to be applied to existing group assignments at conversion time.
    Enter the New Group Provider Name (Examples -> "Domain\", "c:0-.t|MembershipProvider|domain.com\")
.PARAMETER webApplication
    Optional string variable.
    If supplied, the documentation process will be processed for the all sites within the specified Web Application
    Provide the URL of the WebApplication for which to migrate users.
.PARAMETER SPSite
    Optional string variable.
    If supplied, the documentation process will 
    Provide the URL of the SharePoint site collection for which to migrate users.
.PARAMETER convert
    Switch parameter.  If specified, the script will run in "convert" mode.  If excluded, the script will run in the default "document" mode.
.PARAMETER csvPath
    Mandatory string parameter.
    Enter the path to which to save the MigrateUsers.csv file. (i.e. C:\migration)
.EXAMPLE
    .\Migrate-SPUsers.ps1 -webApplication 'https://sharepoint.myschool.edu' -oldProvider 'GUEST\' -newProvider 'i:0e.t|adfs.myschool.edu|' -newSuffix '@guest.myschool.edu' -csvPath c:\local\temp -newGroupProvider 'c:0-.t|adfs.myschool.edu|guest.myschool.edu\'
    Documents the migration process for all users in the Web Application "https://sharepoint.myschool.edu".  The generated CSV file will be saved to c:\local\temp\MigrateUsers.csv
.EXAMPLE
    .\migrate-SPUsers.ps1 -convert -csvPath C:\local\temp
    Processes all users documented in the MigrateUsers.csv file under c:\local\temp, performing the user/group migrations generated by the "document" process in the previous example.
#>
[cmdletBinding(DefaultParameterSetName='document')]
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
    [string]$SPSite,
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
        elseif($SPSite) {
            $sites = get-spsite $SPSite
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