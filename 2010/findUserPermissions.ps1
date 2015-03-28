#findUserPermissions.ps1
#J. Greg Mackinnon, 2015-03-25
#
#Recurses though the web application provided in -webAppplication for the users (samaccountname format) provided in -Users,
#for the domain provided in -Domain.
#
# Requires: Microsoft.SharePoint.PowerShell PSSnapin
#          ActiveDirectory PowerShell module
#
# Provides: Comma-separated value file with user, permission, and site data for all discovered permissions, 
#          at path provided in the -logPath parameter.          
[cmdletBinding()]
param(
    [parameter(
        Mandatory=$true,
        HelpMessage='Enter a username or comma-separated list of usernames in samAccountName format.')]
        [ValidatePattern('^\b[\w\.-]{1,20}\b$')]
        [string[]]$users,
    [parameter()]
        [ValidatePattern('\b[\w\.-]{1,15}\b')]
        [string]$domain = 'CAMPUS',
    [parameter(
        HelpMessage='Enter the URL of the SharePoint web application for which all webs will be searched.')]
        [ValidatePattern('^http[s]*://\w+\.\w+')]
        [string]$webApplication,
    [parameter(
        HelpMessage='Enter the URL of the single SharePoint site for which all subwebs will be searched.')]
        [ValidatePattern('^http[s]*://\w+\.\w+')]
        [string]$spSite,
    [string]$logPath = 'c:\local\temp\findUserPermissions.log'
)
Set-PSDebug -Strict

function getPermType($mask) {
    #SharePoint permissions/roles are exposed programatically as "PermissionMask" attribute of the SPWeb.Permissions.Member objects.
    #Most of these masks are numeric.  This function will convert the numeric value into a "friendly" string, derived by examining 
    #site permissions in a web browser:
    [string]$return = switch ($mask) {
        'FullMask'   {[string]'FullControl'}
        '1012866047' {[string]'Design'}
        '1011028719' {[string]'Contribute'}
        '138612833'  {[string]'Read'}
        '138612801'  {[string]'ViewOnly'}
        '134287360'  {[string]'List-Library:UnknownAccess'} #Note that this mask has the label "Limited Access" in the GUI.
        default      {[string]"Unknown:$mask"}
    }
    return $return
}

function checkADGroupMembers {
    param ([string]$adGroupName,[string]$adGroupSid,[string]$userRegex)
    #Searches the AD Group provided in -adGroup for matches against the regex provided in -userRegex.
    #Search is performed against the domain of the computer running the script.
    #The userRegex value can be generated using the "regexifyDomainUser" function. It MUST capture the 
    # username/samAccountName to a named capture group called 'name'.
    #Returns boolean true/false.
    #Need to add ability to return RegEx match objects from the search.
    #Optional ability to specify the domain to search?
    
    [Int32]$i = $adGroupName.IndexOf('\')
    [string]$groupSam = $adGroupName.Substring($i + 1)
    #write-host "Getting members of:" $groupSam
    
    [String[]]$returns = @()
    
    #Domain Users could take a long time to process, so let's just assume that the user is a domain user:
    if (($groupSam -eq 'domain users') -or ($groupSam -eq 'authenticated users')) {
        $returns += "!AllUsers!"
        return $returns
        break
    }
    #Get-ADGroupMember will error frequently because SharePoint contains a lot of orphaned groups.
    #Use "ErrorAction Stop" for force an breaking error when this happens, and just set $match to $false/
    try {
        [array]$grpMembers = @()
        if ($adGroupSid) {
            $grpMembers += Get-ADGroupMember -Recursive -Identity $adGroupSid -ErrorAction Stop `
                | Select-Object -ExpandProperty SamAccountName 
        } else {
            $grpMembers += Get-ADGroupMember -Recursive -Identity $groupSam -ErrorAction Stop `
                | Select-Object -ExpandProperty SamAccountName 
        }
    } catch {
        write-host "    AD group $groupSam does not exist" -ForegroundColor Red
        $returns = $null
        break
    }
    if ($grpMembers.count -gt 0) {
        foreach ($memb in $grpMembers) {
            #write-host "testing" $memb "against" $userregex
            if ($memb -match $userRegex) {
                #write-host "regexmatch found: " $matches.user
                #Return the current regex named group "user".  THis is just showing off...
                #I could simply skip the capture groups and just return $memb.
                $returns += $matches.user
            }
        }
    } else {
        write-host "    AD group $groupSam has no members" -ForegroundColor Red
    }
    if ($returns.count -gt 0) {
        return $returns
    } else {
        return $null
    }
}

function regexifyDomainUser {
    param ([string]$user,[string]$domain)
    #Converts the provided domain\username pair into a regex that can 
    #be used to search for the same pattern in a larger string.
    #This regex will return the username in a capture group named "user".
    if ($user -match '\.') {
        $userMatch = $user.Replace('.','\.')
    } else {
        $userMatch = $user
    }
    [string]$regexUser = '^' + $domain + '\\(?<user>' + $userMatch + ')$'
    return $regexUser
}
function regexifyUser {
    #Converts the provided username into a regex that can 
    #be used to search for the same pattern in a larger string.
    #This regex will return the username in a capture group named "user".
    param ([string]$user)
    if ($user -match '\.') {
        $userMatch = $user.Replace('.','\.')
    } else {
        $userMatch = $user
    }
    [string]$regexUser = '^(?<user>' + $userMatch + ')$'
    return $regexUser
}

if ((Get-PSSnapin -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue) -eq $null) {
    Add-PSSnapin Microsoft.SharePoint.PowerShell
}
Import-Module ActiveDirectory

#Set up regex strings that contain all of the samAccountNames provided in the input parameters.
#We want to be able to match all possible users with one regex for processing efficiency.

#DomainUsers will match against DOMAIN\username.
[string]$regexDomainUsers = regexifyDomainUser -user $users[0] -domain $domain
#Users will match againstjust username.
[string]$regexUsers = regexifyUser -user $users[0]
if ($users.count -gt 1) {
    for ($i=1; $i -lt $users.count; $i++) {
        #Set up a regex for matching the user in domain\username format:
        [string]$regexDomainUser = '|' + $(regexifyDomainUser -user $users[$i] -domain $domain)
        $regexDomainUsers += $regexDomainUser
        [string]$regexUser = '|' + $(regexifyUser -user $users[$i])
        $regexUsers += $regexUser
    }
}

## Initialize output log:
if (Test-Path -LiteralPath $logPath) {
    Remove-Item -LiteralPath $logPath -Force
}
#CSV header row:
[string]$out = "user,Role,WebUrl,aceDetails"
$out | Out-File -FilePath $logPath 

#Get selected SharePoint sites:
[array]$sites = @()
if ($spSite) {                 #If spSite is specified, search only one site:
    $sites += Get-SPSite -Identity $spSite -Limit All
} elseif ($webApplication){    #If webApplication is specified, search all sites in the webapp:
    $sites += Get-SPSite -WebApplication $webApplication -Limit All
} else {                       #Otherwise, search all web applications defined on the local farm:
    $sites += Get-SPSite -Limit All
}

##Begin Main Loop:
foreach ($site in $sites) {
    $webs = @()
    # Gets webs in current site
    $webs = $site | % {Get-SPWeb -Site $_ -Limit All}
    foreach ($web in $webs) {
        Write-Host "Testing web:" $web.url -ForegroundColor cyan 
        $webPerms = @()
        $webPerms = $web.Permissions
        foreach ($perm in $webPerms) {
            #Scenario 1: ACL entry is for this specific user:
            if ($perm.member.loginName -match $regexDomainUsers) {
                [string]$user = ($perm.member.loginName).split('\') | select -Last 1
                write-host "    Found match $user in the web ACL list." -ForegroundColor yellow
                [string]$aclData = 'Acl:Direct'
                [string]$out = $user + ',' + (getPermType($perm.PermissionMask)) + ',' + $web.Url + ',' + $aclData
                $out | Out-File -Append -FilePath $logPath
            }
            #Scenario 2: ACL entry is an Active Directory Group
            if ($perm.Member.IsDomainGroup) {
                [String[]]$ADGroupusers = @()
                $ADGroupUsers = checkADGroupMembers -adGroupName $perm.Member.LoginName -adGroupSid $perm.Member.Sid -userRegex $regexUsers
                if ($ADGroupUsers.count -gt 0) {
                    foreach ($user in $ADGroupUsers) {
                        write-host "    Found user $user in AD Group:" $perm.member.loginName ", which is on the web ACL list." -ForegroundColor yellow
                        [string]$aclData = 'Acl:Embedded:' + $perm.Member.LoginName 
                        [string]$out = $user + ',' + (getPermType($perm.PermissionMask)) + ',' + $web.Url + ',' + $aclData 
                        $out | Out-File -Append -FilePath $logPath
                    }
                }
            }
            #Scenarios: ACE is for a SharePoint group:
            if ($perm.Member.GetType().Name -eq 'SPGroup') {
                $members = @()
                $members += $perm.member.users
                foreach ($member in $members) {
                    #Scenario 3: ACL is a SharePoint group, and the group contains a matching user:
                    if ($member.loginName -match $regexDomainUsers) {
                        [string]$user = ($member.loginName).split('\') | select -Last 1
                        write-host "    Found match for" $user "in a Sharepoint group that is in the web site ACL." -ForegroundColor yellow

                        [string]$aclData = 'SPGroup:Direct:' + $perm.Member.LoginName
                        [string]$out = $user + ',' + (getPermType($perm.PermissionMask)) + ',' + $web.Url + ',' + $aclData
                        $out | Out-File -Append -FilePath $logPath
                    } #End Scenario 3
                    #Scenario 4: ACL is a SharePoint group, and the group contains an AD group that contains a matching user:
                    if ($Member.IsDomainGroup) {
                        [String[]]$ADGroupUsers = @()
                        $ADGroupUsers = checkADGroupMembers -adGroupName $Member.LoginName -adGroupSod $Member.LoginName.Sid -userRegex $regexUsers
                        if ($ADGroupUsers.count -gt 0) {
                            foreach ($user in $ADGroupUsers) {
                                write-host "    Found user $user in an AD Group that is found in a SharePoint group that appears in the web site ACL." -ForegroundColor yellow
                                [string]$aclData = 'SPGroup:Embedded:' + $perm.Member.LoginName + ':' + $member.loginName
                                [string]$out = $user + ',' + (getPermType($perm.PermissionMask)) + ',' + $web.Url + ',' + $aclData
                                $out | Out-File -Append -FilePath $logPath
                            }
                        }
                    } #End Scenario 4
                }
            } #End SPGroup Eval
        } #End foreach $perm
        foreach ($admin in $web.SiteAdministrators) {
            #Enumerate Web Site Administrators (should be at least two)
            if ($admin.LoginName -match $regexDomainUsers) {
                [string]$user = $matches.user
                write-host "    Found web site administrator match for:" $user -ForegroundColor yellow
                [string]$out = $user + ',' + 'webSiteAdministrator,' + $web.Url
                $out | Out-File -Append -FilePath $logPath
                #exit #for debugging
            }
        }
        $web.Dispose()
    }
    if ($site.owner.UserLogin -match $regexDomainUsers) {
        #Discover Site Owner (should be only one)
        [string]$user = $matches.user
        write-host "    Found site collection owned by:" $user -ForegroundColor yellow
        [string]$out = $user + ',' + 'SiteCollectionOwner,' + $site.Url
        $out | Out-File -Append -FilePath $logPath
        #exit #for debugging
    }
    $site.Dispose()
}