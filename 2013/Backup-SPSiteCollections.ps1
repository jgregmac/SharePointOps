<#
.SYNOPSIS
   Creates discrete backups for all SharePoint Site Collections in a specified 
   SharePoint web application.  Optionally, backups can be limited to sites 
   that have been modified within a specified period of time.

.DESCRIPTION
   The script is intended to perform nightly backups of sharepoint
   site collections that have change the the last N days. The script
   uses the Sharepoint .NET assembly to access site information and
   to set and remove lock information. It uses STSADM to perform
   the actual backup.

.PARAMETER webApplication (required)
   URL to the SharePoint WebApplication
   
.PARAMETER Destination (required)
   Location in which to save backup files and log

.PARAMETER Days
.PARAMETER Hours
   If specified, SharePoint site collections modified during that
   interval (days + hours) will be backed up. If neither parameter
   is specified, all site collections will be backed up.

   Multiple intervals are summed: -days 1 -hours 12 = 36 hours

.PARAMETER Limit
   Used for testing.  If specified, the number of site collections backed up will be limited to this value.

.PARAMETER WhatIf
   If specified, no backups will be performed. Log and output will show
   actions that would have been taken.

.EXAMPLE
  PS C:\>.\Backup-SPSiteCollections.ps1 -webApplication https://sharepoint.mydomain.com -destination E:\backup -hours 25

  Backup all sites in the web application at https://sharepoint.mydomain.com that have been modified in the last 25 hours.

.NOTES
   Original Author (2007): Geoffrey Duke
   Revisions by (2010-2013): J. Greg Mackinnon
#>   
[cmdletBinding()]
param (
    [parameter(Mandatory=$true)][string]$webApplication,
    [parameter(Mandatory=$true)][string]$destination,
    [int]$days,
    [int]$hours,
    [int]$limit = 0,
    [switch] $WhatIf
)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#                    Begin Script configuration
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set-psdebug -strict

# timekeeping variables
$timestamp_start = get-date
$iso_date        = get-date -date $TIMESTAMP_Start -format yyyy-MM-ddTHHmm

# log file path
$logfile = '\_sharepoint_backup.' + $ISO_DATE + '.log'
$logfile = join-path $destination $logfile

if (test-path $logfile) {
    remove-item $logfile
}

# Output helpers
[string]$blankline = ''

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
#                      End Script configuration
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
# Begin Function definitions
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Tee-Log
# emit messages to both log (appending) and screen
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function Tee-Log {
    param(
        [string]$message,
        [string]$logfile
    )
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
function Out-Log {
    param(
        [string]$message,
        [string]$logfile
    )
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
    [string]$dashline  = '-' * 70
    Write-Output ""
    Write-Output "Sharepoint Site Backups beginning  ::  $timestamp_start"
    Write-output $dashline
    Write-Output ""
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Get-LogFooter
#   Simple set of strings to start the log
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function Get-LogFooter {
    [string]$dashline  = '-' * 70
    Write-Output ""
    Write-Output "Sharepoint Site Backups finished  ::  $(get-date)"
    Write-Output $dashline
    Write-Output ""
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Get-FilenameFromPath
# given the path portion of the URL (from ServerRelativeUrl prop)
# return a reasonable filename
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function Get-FilenameFromPath {
    param($path)
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
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
# End Function definitions
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Begin Main Routine
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Get-LogHeader | % {Tee-Log $_ -logfile $logfile}
Tee-Log "Connecting to $webApplication" -logfile $logfile
Tee-Log "Backup destination $destination" -logfile $logfile

if ( $afterdate ) {
    Tee-Log "Backing up sites changed after $afterdate" -logfile $logfile
}

# Connect to SharePoint WebApp
$webApp = Get-SPWebApplication $webApplication
if ( $webApp -eq $null ) {
    throw "Unable to find SharePoint WebApp at $webApplication"
}

if ( $limit ) {
    Tee-Log "Limit set to $limit sites" -logfile $logfile
}
tee-log $blankline -logfile $logfile

$sitecount  = 0;
$errorcount = 0;

:NEXTSITE foreach ($site in $webApp.sites) {

    # Stop if limit has been reached
    if ( ($limit -gt 0) -and ($sitecount -gt $limit) ) {
        tee-log "Limit reached; ending" -logfile $logfile
        $site.dispose()
        break
    }

    # Retrieve needed info about site collection
    $path = $site.ServerRelativeUrl

    # Had some problems with "Ghost Sites"
    # if LastContentModified is Null, note Ghost Site and move on
    if ($site.LastContentModifiedDate -eq $null) {
        tee-log "   ( skipping $path , ghost site )" -logfile $logfile
        tee-log $blankline -logfile $logfile
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
    if ($threshold -and ($threshold -gt $modified) ) {
        tee-log "   ( skipping $path , modified $modified )" -logfile $logfile
        tee-log $blankline -logfile $logfile
        $site.dispose()
        continue NEXTSITE
    }

    # This site needs to be backed up
    $sitecount++
    $filename = Get-FilenameFromPath($path)
    #$size = [math]::round( ([long]$site.usage.storage/1MB), 2 )
    tee-log "Backing-up $path" -logfile $logfile
    out-log "    modified   $modified" -logfile $logfile
    #out-log "    size (MB)  $size" -logfile $logfile
    out-log "    filename   $filename" -logfile $logfile

    $filename = join-path $destination $filename

    # If the WhatIf parameter was specified, don't really 
    # lock or backup the SharePoint site collection

    if ($WhatIf.IsPresent) {
        tee-log "Performing backup operations for $path" -logfile $logfile
        tee-log $blankline -logfile $logfile
        $site.dispose()
        continue NEXTSITE
    }


    ## Backup the site
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    $url = $site.Url
    Write-Debug " >> Backing-up site $path`n"
    # STSADM is deprecated.  Use Backup-SPSite instead.
    # (If not using SQL Server Enterprise Edition, you must exclude "-UseSqlSnapshot".)
    try {
        Backup-SPSite -Identity $url -Path $filename -Force -Confirm:$false -ea Stop #-UseSqlSnapshot
    } catch {
        tee-log "ERROR encountered in backup" -logfile $logfile
        out-log $_.exception -logfile $logfile
        write-warning $_.exception
        tee-log $blankline -logfile $logfile
        $errorcount++
        continue NEXTSITE
    } finally {
        $site.dispose()
    }
    tee-log "Backup of the site collection at $url completed successfully." -logfile $logfile
    tee-log $blankline -logfile $logfile
}

# Report time to complete backup operation
$duration = (get-date) - $timestamp_start
$format   = "{0:D}h {1:D2}m {2:00.#}s"

$runtime  = $format -f ($duration.Days * 24 + $duration.Hours),
                 $duration.Minutes, 
                ($duration.Seconds + $duration.Milliseconds/1000)

Tee-Log "Backup opertion runtime: $runtime" -logfile $logfile
Get-LogFooter | % {Tee-Log $_ -logfile $logfile}
