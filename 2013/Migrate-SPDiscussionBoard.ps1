# Source: http://sharepoint.stackexchange.com/questions/8600/moving-a-discussion-from-a-discussion-board-to-another
# Has various limitations related to post author, esp. if the author no longer exists in the directory.
# Not recommended for production use, more of an example of possible mechanisms for migrating content.
Param (
    [string]$srcWebUrl,
    [string]$dstWebUrl
)
Set-PSDebug -Strict
Add-PSSnapin Microsoft.SharePoint.PowerShell -ea SilentlyContinue

function New-SPList {
    <#
    .Synopsis
        Use New-SPList to create a new SharePoint List or Library.
    .Description
        This advanced PowerShell function uses the Add method of a SPWeb object to create new lists and libraries in a SharePoint Web
        specified in the -Web parameter.
    .Example
        C:\PS>New-SPList -Web http://intranet -ListTitle "My Documents" -ListUrl "MyDocuments" -Description "This is my library" -Template "Document Library"
        This example creates a standard Document Library in the http://intranet site.
    .Example
        C:\PS>New-SPList -Web http://intranet -ListTitle "My Announcements" -ListUrl "MyAnnouncements" -Description "These are company-wide announcements." -Template "Announcements"
        This example creates an Announcements list in the http://intranet site.
    .Notes
        You must use the 'friendly' name for the type of list or library.  To retrieve the available Library Templates, use Get-SPListTemplates.
    .Link
        http://www.iccblogs.com/blogs/rdennis
            http://twitter.com/SharePointRyan
    .Inputs
        None
    .Outputs
        None
    #>   
        [CmdletBinding()]
        Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$Web,
        [Parameter(Mandatory=$true)]
        [string]$ListTitle,
        [Parameter(Mandatory=$true)]
        [string]$UriTitle,
        [Parameter(Mandatory=$false)]
        [string]$Description,
        [Parameter(Mandatory=$true)]
        [string]$Template
        )
    Start-SPAssignment -Global
    $SPWeb = Get-SPWeb -Identity $Web
    $listTemplate = $SPWeb.ListTemplates[$Template]
    $SPWeb.Lists.Add($UriTitle,$Description,$listTemplate)
    $list = $SPWeb.Lists[$UriTitle]
    $list.Title = $ListTitle
    $list.Update()
    $SPWeb.Dispose()
    Stop-SPAssignment -Global
}

#Get the SP Web objects for the specified web site URLs:
$srcWeb = Get-SPWeb -Identity $srcWebURL
$dstWeb = Get-SPWeb -Identity $dstWebUrl
#Get the site-specific portion of the web site URL for the source and destination sites:
$srcShortName = $srcWeb.Url.Substring(($srcWeb.Url.LastIndexOf('/') + 1))
$dstShortName = $dstWeb.Url.Substring(($dstWeb.Url.LastIndexOf('/') + 1))

#Get all Discussion Board Lists from the source site:
$discLists = $srcWeb.Lists | ? {$_.BaseTemplate -eq 'DiscussionBoard'} | ? {$_.DefaultViewUrl -match 'im lost youre found'}

foreach ($sourceList in $discLists) {
    #Generate a new URI for the destination board:
    $dstUri = $sourceList.DefaultViewUrl.Replace($srcShortName,$dstShortName)
    $shortTitle = $dstUri.substring(($dstUri.IndexOf('Lists/') + 6))
    $shortTitle = $shortTitle.substring(0,($shortTitle.IndexOf('/')))
    #Create a new discussion board in the destination web site: (need to handle situation where it already exists...)
    New-SPList -Web $dstWebUrl -ListTitle ($sourceList.Title) -UriTitle $shortTitle -Description ($sourceList.Description) -Template 'Discussion Board'
    #Get the new list in the destination web:
    $dstWeb.Dispose() #May not be necessary.. making sure most recent web info is in memory.
    $dstWeb = Get-SPWeb $dstWebUrl
    $destinationList = $dstweb.lists | ? {$_.DefaultViewUrl -match $shortTitle}
    #$destinationList = $dstWeb.GetList($shortTitle)
    
    $sourceListItems = $sourceList.Folders

    foreach($item in $sourceListItems) {
        write-host $item['ID']
        #Get desired discussion by ID (or use some other identifier eg. ID)
        $sourceDiscussion = $sourceList.Folders | Where-Object {$_.ID -eq $item['ID']}

        #Add new discussion to destination list
        $destinationDiscussion = [Microsoft.SharePoint.Utilities.SPUtility]::CreateNewDiscussion($destinationList.Items, $sourceDiscussion.Title)
        #Copy basic field values (you can copy some custom fields if needed)
        $destinationDiscussion["Body"] = $sourceDiscussion["Body"]
        $destinationDiscussion["Author"] = $sourceDiscussion["Author"]
        $destinationDiscussion["Editor"] = $sourceDiscussion["Editor"]
        $destinationDiscussion["Modified"] = $sourceDiscussion["Modified"]
        $destinationDiscussion["Created"] = $sourceDiscussion["Created"]
        $destinationDiscussion["Last Updated"] = $sourceDiscussion["Last Updated"]
        #Add discussion
        $destinationDiscussion.SystemUpdate($false)

        #Get all discussion messages (maybe there is better way to get it but this works)
        $caml='<Where><Eq><FieldRef Name="ParentFolderId" /><Value Type="Integer">{0}</Value></Eq></Where>' -f $sourceDiscussion.ID
        $query = new-object Microsoft.SharePoint.SPQuery
        $query.Query = $caml
        $query.ViewAttributes = "Scope='Recursive'";
        $sourceMessages = $sourceList.GetItems($query)

        foreach ($sourceMessage in $sourceMessages) {
            #Add new message to discussion
            $destinationMessage = [Microsoft.SharePoint.Utilities.SPUtility]::CreateNewDiscussionReply($destinationDiscussion)
            #Copy basic field values (you can copy some custom fields if needed)
            $destinationMessage["Body"] = $sourceMessage["Body"]
            $destinationMessage["TrimmedBody"] = $sourceMessage["TrimmedBody"]
            $destinationMessage["Author"] = $sourceMessage["Author"]
            $destinationMessage["Editor"] = $sourceMessage["Editor"]
            $destinationMessage["Modified"] = $sourceMessage["Modified"]
            $destinationMessage["Created"] = $sourceMessage["Created"]
            #Add message
            $destinationMessage.SystemUpdate($false)

        }

    }

}