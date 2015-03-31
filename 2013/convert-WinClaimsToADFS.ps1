[string] $groupprefix = "c:0-.t|adfs.uvm.edu|"
[string] $userprefix = "i:05.t|adfs.uvm.edu|"
[string] $usersuffix = "@campus.ad.uvm.edu"  

# Get all of the users in a web application 
[string] $url = "https://spwinauth.uvm.edu"
$users = Get-SPUser -web $url 

# Loop through each of the users in the web app 
foreach($user in $users) { 
    # Create an array that will be used to split the user name 
    $a=@() 
    $displayname = $user.DisplayName 
    $userlogin = $user.UserLogin 
    [string] $username = ""

    if($userlogin.Contains("i:") -and $userlogin.Contains("campus")) {
		#for users 
        $a = $userlogin.split('\') 
        $username = $userprefix + $a[1] + $usersuffix
    } 
	elseif($userlogin.Contains("c:") -and $userlogin.Contains("campus")) {
		#for groups 
        $a = $displayname.split('\') 
        $username = $groupprefix + $a[1] 
    }     
	
	if ($username.length -ne 0) {
	#if(!$userlogin.Contains("spsitecoladmin1")) { #leave one of the site collection admin
		Write-Host $userlogin $username | tee-object -filepath "c:\users\jgm.adm\desktop\convert.log" -append
		Move-SPUser –Identity $user –NewAlias $username -ignoresid -Confirm:$false
    }
}
