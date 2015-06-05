<# mailTo_badSiteAdmins PowerShell Script:
2015-4-29, J. Greg Mackinnon
- Pulls data concerning non-migratable web sites from 'badwebs.xml', a file generated by 'get-spincompatiblesites.ps1'.
- Sends the message defined in $bodyTemplate to the site administrators (if they are valid accounts). (Assumes the site UserLogon is a valid email when appending "@uvm.edu").
#>
[cmdletBinding()]
param(
    [string]$waUrl = "https://sharepoint.uvm.edu",
    [string]$SmtpServer = "smtp.uvm.edu",
    [string]$From = "saa-ad@uvm.edu",
    [string]$subjTemplate = 'Problem upgrading your site "-siteURL-"',
    [string]$templateName = 'badSiteMailTemplate2.html',
    [string]$filter,
    [int]$limit
)
Set-PSDebug -Strict

#Cast the output varaible as a string to avoid type confusion later:
[string]$out = ''

Add-PSSnapin -Name microsoft.SharePoint.PowerShell -ea SilentlyContinue

Write-Host "Loading the message body template..." -ForegroundColor Cyan
#try {
#    write-host $PSScriptRoot $templateName
#    $templatePath = Join-Path -Path $PSScriptRoot -ChildPath $templateName
    [string]$bodyTemplate = Get-Content -Path $templateName -ea stop
#} catch {
#    write-error "Could not read the message body template file."
#    write-error $_.exception
#    exit 100
#}

Write-Host "Getting the badWebs report..." -ForegroundColor Cyan
$badwebs = Import-Clixml -Path C:\local\temp\badWebs.xml
$badWebs = $badWebs | ? {$_.ContentDB -eq 'SP_WebApp_Content_Bad2'}

#Additional filtering/limiting of results, if requested:
if ($filter) {
    Write-Host "Filtering results..." -ForegroundColor Cyan
    $badWebs = $badWebs | ? {$_.admins.admin -match $filter}
}
if ($limit) {
    $badWebs = $badWebs | Select-Object -Last $limit
}

$utf8 = [system.text.encoding]::UTF8
foreach ($web in $badWebs) {
    $allAdmins = $web.admins | ? {$_.exists}
    foreach ($admin in $allAdmins) {
        if ($admin.exists) {
        	[string] $to = ($admin.admin.split('\') | select -last 1) + '@uvm.edu'
            #$to = 'jgm@uvm.edu'
        	[string] $siteUrl = $web.SiteUrl
        	[string] $body = $bodyTemplate.Replace("-siteURL-",$siteUrl)
            [string] $webUrl = $web.WebUrl
            $body = $body.Replace("-webURL-",$webUrl)
        	[string] $subj = $subjTemplate.Replace("-siteURL-",$siteUrl)
            try {
        	    Send-MailMessage -To $to -From $From -SmtpServer $SmtpServer `
                  -Subject $subj -BodyAsHtml $body -Encoding $utf8 -ea stop
            } catch {
                write-error "Error sending mail message:"
                write-error $_.exception
                exit 200
            }
        	$out = "  Sent mail to: " + $to + "`r`n  For site: `r`n    " + $siteUrl + "`r`n"
            write-host $out -ForegroundColor Gray
            #Add loop delay to prevent flooding:
            Start-Sleep -Seconds 1
        }
    }
}
