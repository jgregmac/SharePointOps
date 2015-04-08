<#
.NAME
   sp_site_backup.ps1

.SYNOPSIS
   Creates discrete backups for sharepoint sites

.DESCRIPTION
   The script is intended to perform nightly backups of sharepoint
   site collections that have change the the last N days. The script
   uses the Sharepoint .NET assembly to access site information and
   to set and remove lock information. It uses STSADM to perform
   the actual backup.

.PARAMETER SiteUrl (required)
   URL to the SharePoint WebApplication
   
.PARAMETER Destination (required)
   Location in which to save backup files and log

.PARAMETER Days
.PARAMETER Hours
   If specified, SharePoint site collections modified during that
   interval (days + hours) will be backed up. If neither parameter
   is specified, all site collections will be backed up.

.PARAMETER WhatIf
   If specified, no backups will be performed. Log and output will show
   actions that would have been taken.
   
.NOTES
   Author: Geoffrey Duke
#>   
[cmdletBinding()]
param (

    # URL to the Sharepoint site root
    [string] $siteurl,

    # path in which to place backup files, logs
    [string] $destination,

    # Backup sites modified within the interval specified
    # (multiple intervals are summed: -days 1 -hours 12 = 36 hours
    [int] $days,
    [int] $hours,

    # WhatIf
    [switch] $WhatIf
)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#                      Script configuration
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

set-psdebug -strict

function USAGE {
    $out = @"Usage:
sharepoint_backup.ps1 [-siteurl] <URL> [-destination] <PATH> [-days <INT>] [-hours <INT>] [-whatif]

E.G:
 Back up all sites that have been modified in the last 25 hours:
 sharepoint_backup.ps1 https://sharepoint.uvm.edu -destination E:\backup -hours 25

"@
    return $out 
}


if ( -not ( $siteurl -and $destination ) ) {
    usage
    exit
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Additional Script configuration and setup
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Old Library file from 2007/2010 release.  
#I don't think we need this because we no longer explicitly check site locks, and I moved the
#"Get-FilenameFromPath function into this file.

# Path to scripts
#$SCRIPTHOME         = & { split-path $myInvocation.ScriptName }
#$LIBRARY_SPBACKUP   = join-path $SCRIPTHOME 'UVM-SharePoint.psm1'
#
# Check dependecies             
#if ( -not (test-path $LIBRARY_SPBACKUP) ) {
#    write-error "`nRequired file not found:`n$LIBRARY_SPBACKUP"
#    exit
#}

# Source the library module
#Import-Module $LIBRARY_SPBACKUP

# Some timekeeping variables
$timestamp_start = get-date
$iso_date        = get-date -date $TIMESTAMP_Start -format yyyy-MM-ddTHHmm

# log file path
$logfile = '\_sharepoint_backup.' + $ISO_DATE + '.log'
$logfile = join-path $destination $logfile

if ( test-path $logfile ) {
    remove-item $logfile
}


# Misc variables
$limit = 0  # for testing, limit number of SPSites connected backed-up

# Output helpers
$blankline = ''
$dashline  = '-' * 70
$indent    = ' ' *  4

# Create date against which SharePoint site modification will be compared
if ($days -or $hours) {
    $interval  = new-object System.TimeSpan $days,$hours,0,0
    $threshold = $timestamp_start.Subtract($interval)
    $afterdate = '{0:f}' -f $threshold
}
else {
    $afterdate = $false
    $threshold = get-date 1  #a long long time ago
}

#Load SharePoint PSSnapin
Add-PSSnapin Microsoft.SharePoint.PowerShell
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
# Function definitions
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Tee-Log
# emit messages to both log (appending) and screen
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function Tee-Log ($message ) {
    if ( $WhatIf.IsPresent ) {
        $message = 'What if: ' + $message
    }
    out-file -inputObject $message -filepath $logfile -append
    out-host -inputObject $message
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Out-Log
# emit messages to log (appending)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function Out-Log ($message ) {
    if ( $WhatIf.IsPresent ) {
        $message = 'What if: ' + $message
    }
    out-file -inputObject $message -filepath $logfile -append
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Get-LogHeader
#   Simple set of strings to start the log
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function Get-LogHeader {
    "Sharepoint Site Backups beginning  ::  $timestamp_start"
    $dashline
    ""
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Get-LogFooter
#   Simple set of strings to start the log
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function Get-LogFooter {
    ""
    "Sharepoint Site Backups finished  ::  $(get-date)"
    $dashline
    ""
}

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
# Begin Main Routine
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Tee-Log (Get-LogHeader)
Tee-Log "Connecting to $siteurl"
Tee-Log "Backup destination $destination"

if ( $afterdate ) {
    Tee-Log "Backing up sites changed after $afterdate"
}

# Connect to SharePoint WebApp
$sharepoint = Get-SPWebApplication $siteurl
if ( $sharepoint -eq $null ) {
    throw "Unable to find SharePoint WebApp at $siteurl"
}

if ( $limit ) {
    Tee-Log "Limit set to $limit sites"
}
tee-log $blankline

$sitecount  = 0;
$errorcount = 0;

:NEXTSITE foreach ($site in $sharepoint.sites) {

    # Stop if limit has been reached
    if ( ( $limit -gt 0) -and ( $sitecount -gt $limit ) ) {
        tee-log "Limit reached; ending"
        $site.dispose()
        break
    }

    # Retrieve needed info about site collection
    $path = $site.ServerRelativeUrl

    # Had some problems with "Ghost Sites"
    # if LastContentModified is Null, note Ghost Site and move on
    if ( $site.LastContentModifiedDate -eq $null ) {
        tee-log "   ( skipping $path , ghost site )"
        tee-log $blankline
        $site.dispose()
        continue NEXTSITE
    }

    # Determine most recent modification date/time
    $ContentModified  = $site.LastContentModifiedDate.ToLocalTime()
    $SecurityModified = $site.LastSecurityModifiedDate.ToLocalTime()
    if ($ContentModified -gt $SecurityModified ) {
        $modified = $ContentModified
    }
    else {
        $modified = $SecurityModified
    }

    # if an interval was specified, skip sites not modified in interval
    if ( $threshold -and ( $threshold -gt $modified ) ) {
        tee-log "   ( skipping $path , modified $modified )"
        tee-log $blankline
        $site.dispose()
        continue NEXTSITE
    }

    # This site needs to be backed up
    $sitecount++
    $filename = Get-FilenameFromPath($path)
    #$size = [math]::round( ([long]$site.usage.storage/1MB), 2 )
    tee-log "Backing-up $path"
    out-log "    modified   $modified"
    #out-log "    size (MB)  $size"
    out-log "    filename   $filename"

    $filename = join-path $destination $filename

    # If the WhatIf parameter was specified, don't really 
    # lock or backup the SharePoint site collection

    if ( $WhatIf.IsPresent ) {
        tee-log "Performing backup operations for $path"
        tee-log $blankline
        $site.dispose()
        continue NEXTSITE
    }


    ## Backup the site
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    $url = $site.Url

    Write-Debug " >> Backing-up site $path`n"
    #capture the error stream in the output
    $errorActionPreference = 'continue'
    $result = &STSADM -o Backup -url $url -filename $filename -overwrite 2>&1

    # Get the next-to-last line from the output
    if ( $result[-2] -ne 'Operation completed successfully.' ) {
        tee-log "ERROR encountered in backup"
        out-log $result[-2].TargetObject
        write-warning $result[-2].TargetObject
        tee-log $blankline
        $site.dispose()
        $errorcount++
        continue NEXTSITE
    }
    else {
        tee-log $result[-22]
    }

    ## Clean-up
    tee-log $blankline

    $site.Dispose()
}

# Report time to complete backup operation
$duration = (get-date) - $timestamp_start
$format   = "{0:D}h {1:D2}m {2:00.#}s"

$runtime  = $format -f ($duration.Days * 24 + $duration.Hours),
                 $duration.Minutes, 
                ($duration.Seconds + $duration.Milliseconds/1000)

Tee-Log "Backup opertion runtime: $runtime"
Tee-Log (Get-LogFooter)
