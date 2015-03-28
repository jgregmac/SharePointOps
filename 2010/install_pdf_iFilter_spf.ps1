################################
# Thierry BUISSON
# http://www.thierrybuisson.fr
#
# Activate pdf extention for Foundation 2010 Search
# source http://support.microsoft.com/kb/2518465
################################

function AddExtention([string] $extension){

    if ($extension -eq $null) {
		Write-host "No extention Found"
	}
	else{
		Write-host "Activating extension $extension"
		
		$gadmin = new-object -comobject "SPSearch4.GatherMgr.1" -strict
				
		Foreach ($application in $gadmin.GatherApplications)
		{
			write-host "application name is $application.name"
			Foreach ($project in $application.GatherProjects)
			{
				write-host $project.Extensions
				$project.Gather.Extensions.Add($extension)
			}

		}
	}
}

function AddPdfRegKey(){
	
	$pdfKey = "HKLM:\SOFTWARE\Microsoft\Shared Tools\Web Server Extensions\14.0\Search\Setup\ContentIndexCommon\Filters\Extension\.pdf"
	
	$pdfguid = "{E8978DA6-047F-4E3D-9C78-CDBE46041603}"
	
	if (Test-Path $pdfKey) {  
		write-host "Pdf registry key already exists" 
		
		$key = Get-Item $pdfKey
		$values = Get-ItemProperty $key.PSPath
		foreach ($value in $key.Property) { $value + "=" + $values.$value }
	}
	else {  
		Write-host "creating key $pdfKey"
		
		#create key
		New-Item -Path $pdfKey
		
		#Set default value to good guid
		$defaultKeyName = "(default)"
		Set-ItemProperty -Path $pdfKey -Name $defaultKeyName -Value $pdfguid
	}
	
	
}
	
AddExtention "pdf"
AddPdfRegKey

& net stop SPSearch4
& net start SPSearch4

Write-host "running a fullcrawlstart..."
&stsadm -o spsearch -action fullcrawlstart
