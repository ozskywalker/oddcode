# what this script could do:
#  - check if UDF is empty
#  - check if Automatic or Manual configuration

$addrs = @();
Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object ServerAddresses |% { $addrs += $_.ServerAddresses }; 
$DNS = ($addrs | select -uniq) -join ","; 
if ($DNS) {
    Write-Host "We're documenting the following DNS servers: $DNS"
    New-ItemProperty "HKLM:\SOFTWARE\CentraStage" -Name "Custom$env:UDFNumber" -PropertyType string -Value $DNS -Force
}
