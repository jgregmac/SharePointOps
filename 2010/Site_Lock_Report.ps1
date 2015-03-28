Add-pssnapin Microsoft.SharePoint.Powershell -ErrorAction silentlycontinue
    $sites = get-spsite -limit all | foreach {
      write-host "Checking lock for site collection: " $_.url -foregroundcolor blue
        #if ($_.ReadOnly -eq $false -and $_.ReadLocked -eq $false -and $_.WriteLocked -eq $false)
        #   { write-host "The site lock value for the site collection"$_.url "is:  Unlocked" -foregroundcolor Green}
       
        if ($_.ReadOnly -eq $false -and $_.ReadLocked -eq $false -and $_.WriteLocked -eq $true)
           { write-host "The site lock value for the site collection"$_.url "is:  WriteLocked" -foregroundcolor Green}
        elseif ($_.ReadLocked -eq $true )
           { write-host "The site lock value for the site collection"$_.url "is:  ReadLocked" -foregroundcolor Green}
		elseif ($_.ReadOnly -eq $true -and $_.ReadLocked -eq $false -and $_.WriteLocked -eq $true )
           { write-host "The site lock value for the site collection"$_.url "is:  ReadOnly" -foregroundcolor Green}
        elseif ($_.ReadOnly -eq $null -and $_.ReadLocked -eq $null -and $_.WriteLocked -eq $null)
           { write-host "The site lock value for the site collection"$_.url "is:  No Access" -foregroundcolor Green}
		elseif ($_.lockissue -ne $null) {
             write-host "The additional text was provided for the lock: " $_.LockIssue -foregroundcolor Green}
    }
