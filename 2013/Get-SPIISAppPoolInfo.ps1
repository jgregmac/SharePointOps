Function Get-SPIISAppPoolInfo {
  <#
  .SYNOPSIS
  This PowerShell function fully automates the task of identifying which SharePoint (2010 or 2013)
  Web and Service Applications are associated with which IIS Application Pools

   
  .DESCRIPTION
  This PowerShell function fully automates the task of identifying which SharePoint (2010 or 2013)
  Web and Service Applications are associated with which IIS Application Pools
  I have verified that this function will work with:
  ---SharePoint 2013 on Windows Server 2012 (IIS 8)
  ---SharePoint 2013 on Windows Server 2008 R2 (IIS 7.5)
  ---SharePoint 2010 on Windows Server 2008 R2 (IIS 7.5) 

  .EXAMPLE
  Get-SPIISAppPoolInfo

  This example will return a custom PSObject collection containing all SharePont Web and Service Applications and their associated IIS Application Pool.

  .EXAMPLE
  Get-SPIISAppPoolInfo -Verbose

  This example will return a custom PSObject collection containing all SharePont Web and Service Applications and their associated IIS Application Pool.

  This example will also out Verbose function information as it executes.

  .EXAMPLE
  Get-SPIISAppPoolInfo | Group TypeString

  This example will return a custom PSObject collection containing all SharePont Web and Service Applications and their associated IIS Application Pool and group the results by "WebApp" and "ServiceApp"

  .EXAMPLE
  Get-SPIISAppPoolInfo | where {$_.TypeString -eq "WebApp"}

  This example will return a custom PSObject collection containing all SharePont Web Applications and their associated IIS Application Pool. Change the where parameter to "ServiceApp" for Service Applications.

  .EXAMPLE
  Get-SPIISAppPoolInfo | where {$_.TypeString -eq "WebApp"} | Group IISAppPoolName

  This example will return a custom PSObject collection containing all SharePont Web Applications and their associated IIS Application Pool and group the results by the IISAppPoolName

  .EXAMPLE
  Get-SPIISAppPoolInfo | where {$_.TypeString -eq "ServiceApp"} | Group SPAppPoolName

  This example will return a custom PSObject collection containing all SharePont Service Applications and their associated IIS Application Pool and group the results by the SPAppPoolName, which is the Service Application Pool name stored in SharePoint for the Service Application.

  .EXAMPLE
  Get-SPIISAppPoolInfo | where {$_.IISAppPoolName -eq "Your IIS Application Pool Name Here"}

  This example will return a custom PSObject collection containing all SharePont Web Applications and their associated IIS Application Pool where the IIS Application Pool name is "Your IIS Application Pool Name Here"

  .Notes
  Name: Get-SPIISAppPoolInfo
  Author: Craig Lussier
  Last Edit: February 16th, 2013
  .Link
  http://www.craiglussier.com
  http://twitter.com/craiglussier
  http://social.technet.microsoft.com/profile/craig%20lussier/

  # Requires PowerShell Version 2.0 or Version 3.0
  # Requires to be executed as an Administrator
  #>
  [CmdletBinding()]
  Param()

    Begin {
        Write-Verbose "Entering Begin Block"

        If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
        {
           Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
           Exit
        }

        try {
            Write-Verbose "Importing WebAdministration module"
            Import-Module WebAdministration
        }
        catch {

            Write-Error "There was an issue loading the WebAdministration module. Exit function."
            Write-Error $_
            Exit

        }

        try {
            $SPSnapin = "Microsoft.SharePoint.PowerShell"
            if (Get-PSSnapin $SPSnapin -ErrorAction SilentlyContinue) {
                Write-Verbose "Microsoft.SharePoint.PowerShell Snappin already registered and loaded"
            }
            elseif (Get-PSSnapin $SPSnapin -Registered -ErrorAction SilentlyContinue) {
                Add-PSSnapin $SPSnapin 
                Write-Verbose "Microsoft.SharePoint.PowerShell Snappin is registered and has been loaded for script operation"
            }
            else {
                Write-Error "Microsoft.SharePoint.PowerShell Snappin not found. Exit function."
                Exit
            }

        }
        catch {

            Write-Error "There was an issue loading the Microsoft.SharePoint.PowerShell Snappin. Exit function."
            Exit
        }

        Write-Verbose "Leaving Begin Block"
    } 

    Process {

        Write-Verbose "Entering Process Block"

        Write-Verbose "Get IIS Application Pools using the WebAdministration module"
        $IISApplicationPools = Get-ChildItem -Path IIS:\AppPools

        Write-Verbose "Create an array which will contain custom PSObjects"
        $collection = @()

        Write-Verbose "Get SharePoint Web Applications - include Central Administration"
        $webapplications = Get-SPWebApplication -includecentraladministration

        Write-Verbose "Start Loop - Process SharePoint Web Applications"
        foreach($webapplication in $webapplications) {
            
            $webAppName = $webapplication.DisplayName
            Write-Verbose "-Processing Web Application: $webAppName"

            Write-Verbose "--Get IIS Application Pool name"
            $appPoolName = [string]($webapplication.ApplicationPool.Name)
            
            Write-Verbose "--Create custom PSObject for Web Application"
            $object = New-Object PSObject -Property @{                           
                TypeString       = "WebApp"              
                ApplicationName  = $webAppName 
                IISAppPoolName   = $appPoolName                
                SPAppPoolName    = $appPoolName
                ProcessAccountName = $webapplication.ApplicationPool.UserName                                       
       
            } 
            Write-Verbose "--Add Web Application to collection array"
            $collection += $object

            Write-Verbose "--Completed processing Web Application: $webAppName"

        }
        Write-Verbose "End Loop - Process SharePoint Web Applications"


        Write-Verbose "Get SharePoint Service Applications which utilize an Application Pool in IIS"
        $serviceapplications = Get-SPServiceApplication | where ApplicationPool -ne $null

        Write-Verbose "Start Loop - Process SharePoint Service Applications"
        foreach($serviceapplication in $serviceapplications) {

            $serviceAppName = $serviceapplication.DisplayName
            Write-Verbose "-Processing Service Application: $serviceAppName"

            Write-Verbose "--Get Service Application friendly Application Pool name"
            # Some app pools use the friendly name as the app pool name in IIS - we need to check
            $appPoolFriendlyName = [string]($serviceapplication.ApplicationPool.Name)
            
           
            Write-Verbose "--Get Service Application - Application Pool GUID"
            # Some app pools use the guid as the app pool name in IIS (with dashes stripped) - we need to check
            $appPoolGuidName     = ([string]$serviceapplication.ApplicationPool.Id).Replace("-","")
            
            Write-Verbose "--Determine if associated Application Pool Name is the friendly name or a GUID"
            $testName1 = $IISApplicationPools | where {$_.Name -eq $appPoolFriendlyName}
            $testName2 = $IISApplicationPools | where {$_.Name -eq $appPoolGuidName}
            $iisAppPoolName = ""
            if($testName1 -ne $null) {
                $iisAppPoolName = $appPoolFriendlyName
            }
            if($testName2 -ne $null) {
                $iisAppPoolName = $appPoolGuidName
            }

            Write-Verbose "--Create custom PSObject for Service Application"
            $object = New-Object PSObject -Property @{                         
                TypeString       = "ServiceApp"              
                ApplicationName      = $serviceAppName 
                IISAppPoolName   = $iisAppPoolName                
                SPAppPoolName = $appPoolFriendlyName
                ProcessAccountName = $serviceapplication.ApplicationPool.ProcessAccountName                                       
       
            } 
            Write-Verbose "--Add Service Application to collection array"
            $collection += $object

        }
        Write-Verbose "End Loop - Process SharePoint Service Applications"

        Write-Verbose "Output custom PSObject collection to the pipeline" 
        Write-Output $collection | select TypeString, ApplicationName, IISAppPoolName, SPAppPoolName, ProcessAccountName | sort TypeString, IISAppPoolName, ApplicationName

        Write-Verbose "Leaving Process Block"
    }
}