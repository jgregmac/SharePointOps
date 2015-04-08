<#
Name
   Library-SPBackup.ps1
.Synopsis
   Collection of functions for working with SharePoint Backup
.Description
   This script uses the Sharepoint .NET assembly to provide
   access to SharePoint sites and sitecollections.
#>

# Constants ( shouldn't change except during Sharepoint upgrades )
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Sharepoint .NET Assembly Full Name
set-variable  SP_ASSEMBLY -option constant `
   -value 'Microsoft.SharePoint'
   
set-variable  STSADM -option constant `
   -value "$env:programfiles\Common Files\Microsoft Shared\Web Server Extensions\14\BIN\STSADM.EXE"


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Additional Script configuration
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

set-PSDebug -strict                 # Like Perl's "use strict;" pragma

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Script initialization and parameter checking
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Load Sharepoint .NET Assembly
# (Do we even need this anymore?)
[void] [System.Reflection.Assembly]::LoadWithPartialName($SP_ASSEMBLY)

$emptyString = ''


# # # # # # # # # # # #  F U N C T I O N S  # # # # # # # # # # # # # # 

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Follows best practices regarding disposal of SPSite and RootWeb objects
# see: http://msdn.microsoft.com/en-us/library/aa973248.aspx
# and: http://sharepoint.microsoft.com/blogs/zach/Lists/Posts/Post.aspx?ID=7
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Get-FilenameFromPath
# given the path portion of the URL (from ServerRelativeUrl prop)
# return a reasonable filename
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function Get-FilenameFromPath ($path) {

    # creating a regex pattern to match anything
    # that ISN'T a good (simple) filename character

    $notfilename  = [regex] '[<>:"/\\|?\* ]'
	
    $filename = ''
	if ( $path -eq '/' ) {
		$filename = '_sp_root'
	}
	else {
		$filename = $path     -replace('/sites/' , '' )
		$filename = $filename -replace( $notfilename , '_')
	}

    $filename += '.spbak'
	$filename.ToLower()
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# New-SiteLock -read $true -write $true -issue "No Access - backing up"
# Creates a custom object to track site lock attributes
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function New-SiteLock ( 
    [bool]   $readonly    = $false ,
    [bool]   $readlocked  = $false , 
    [bool]   $writelocked = $false , 
    [string] $issue       = $emptyString
    ) 
{
    $newlock = new-object System.Object
    $newlock | Add-member -type NoteProperty -Name ReadOnly    -value $readonly
    $newlock | Add-member -type NoteProperty -Name ReadLocked  -value $readlocked
    $newlock | Add-member -type NoteProperty -Name WriteLocked -value $writelocked
    $newlock | Add-member -type NoteProperty -Name LockIssue   -value $issue

    #write-debug "Created new SiteLock object"
    #Show-Sitelock -lock $newlock
    write-output $newlock
}


# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
# Get-SiteLock -url <site collection url>
# Connects to the site collection via SPSiteAdministration class and
# retrieves the current lock status of the site collection, returning
# an appropriately populated SiteLock object
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

function Get-SiteLock( 
    $url = $(throw "url parameter missing from call to Get-SiteLock") ) 
{
    $siteadmin = new-object Microsoft.Sharepoint.Administration.SPSiteAdministration($url)
    if ($siteadmin -eq $null) {
        write-warning "Couldn't connect to $url"
        return $null
    }

    $getlock = New-SiteLock -readonly    $siteadmin.ReadOnly    `
                            -readlocked  $siteadmin.ReadLocked  `
                            -writelocked $siteadmin.WriteLocked `
                            -issue       $siteadmin.LockIssue 


    Show-Sitelock -lock $getlock -label 'Get-SiteLock retrieved'

    # Calling SPSiteAdministration Dispose method, just for good measure
    $siteadmin.Dispose()
    $siteadmin = $null

    write-output $getlock
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set-SiteLock ( $url <siteurl>, $lock <sitelock object> )
# Connects to the site collection via SPSiteAdministration class and
# updates the lock attributes with values corresponding to those of
# the SiteLock object parameter, then checks lock status
# Returns $true if lock matches desired settings, $false if not
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function Set-SiteLock( 
    $url  = $( throw "url parameter missing from call to Set-SiteLock" ) ,
    $lock = $( throw "lock parameter missing from call to Set-SiteLock")   
    ) 
{
    $siteadmin = new-object Microsoft.Sharepoint.Administration.SPSiteAdministration($url)
    if ($siteadmin -eq $null) {
        write-warning "Couldn't connect to $url"
        return $null
    }

    $siteadmin.ReadOnly    = $lock.ReadOnly
    $siteadmin.ReadLocked  = $lock.ReadLocked
    $siteadmin.WriteLocked = $lock.WriteLocked
    $siteadmin.LockIssue   = $lock.LockIssue

    # Calling SPSiteAdministration Dispose method, just for good measure
    $siteadmin.Dispose()
    $siteadmin = $null

    #now, verify that the current values match the desired values
    $lockcheck = Get-SiteLock -url $url

    Show-Sitelock -lock $lock -label 'SiteLock values we tried to set'

    $result = Compare-SiteLock $lock  $lockcheck
    return $result

}


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Show-SiteLock ( $lock <sitelock object> [$label <string>] ) 
# Writes the current sitelock properties to debug
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function Show-SiteLock ( 
    $lock = $( throw "Duh! How can I show a lock if you don't give me one!?" ),
    [string] $label
    )
{
    if ( $label ) {
        write-debug $label
    }
    write-debug @"

        readonly   : $( $lock.ReadOnly    )
        readlocked : $( $lock.ReadLocked  )
        writelocked: $( $lock.WriteLocked )
        lockissue  : $( $lock.LockIssue   )

"@
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Compare-SiteLock <SiteLock Object> <SitelockObject>
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function Compare-SiteLock( $lock1, $lock2 )
{
    # mostly big logic tree, with a debugging option
    $locksEqual = ( 
            ( $lock1.ReadOnly    -eq $lock2.ReadOnly    ) -and
            ( $lock1.ReadLocked  -eq $lock2.ReadLocked  ) -and
            ( $lock1.WriteLocked -eq $lock2.WriteLocked ) -and
            ( $lock1.LockIssue   -eq $lock2.LockIssue   ) )
#        ) -and ( 
            # accomodating strange null vs empty string issue
#            ( $lock1.LockIssue -eq $lock2.LockIssue     ) -or
#            ( [string]::IsNullorEmpty($lock1.LockIssue) -and
#              [string]::IsNullorEmpty($lock2.LockIssue) )
#        )

    if ( ! $locksEqual ) {
        $host.UI.WriteLine("** Compare-SiteLock: Locks not equal. Check it out. **")
        $host.EnterNestedPrompt()
    }

    return $locksEqual

}

Export Get-FilenameFromPath,Get-SiteLock,New-SiteLock,Set-SiteLock
