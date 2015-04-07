[string]$outpath = "\\sharepoint3p\c$\local\temp\2013Features.csv"
add-pssnapin microsoft.sharepoint.powershell

$Features = @()
$Features += Get-SPFeature | Select-Object -Property Id,DisplayName,Scope

$Features | export-csv -path $outpath -Force
