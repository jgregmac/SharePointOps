$ServiceApps = Get-SPServiceApplication
$UserProfileServiceApp = ""
foreach ($sa in $ServiceApps)
  {if ($sa.DisplayName -eq "User Profile") 
    {$UserProfileServiceApp = $sa}
  }
$UserProfileServiceApp.NetBIOSDomainNamesEnabled = 1
$UserProfileServiceApp.Update()