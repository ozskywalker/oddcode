param(
[parameter(Mandatory = $true)][string]$clients,
[string]$fqdndomain=".mydomain.com",
[string]$timeout="0:0:20",
[switch]$dontautoadddomain
)

function Get-WMICustom([string]$query,[string]$computername,$credential,[string]$timeout='0:0:5',[string]$namespace="Root\CIMV2")
{
	$wmi = [WMISearcher]''
	$wmi.options.timeout = $timeout
	$wmi.psbase.options.timeout = $timeout
	$wmi.scope.options.timeout = $timeout
	$wmi.scope.path = "\\$computername\$namespace"
	$wmi.scope.options.username = $credential.Username
	$wmi.scope.options.password = $credential.GetNetworkCredential().Password
	$wmi.scope.options.authentication = "PacketPrivacy"
	$wmi.query = $query
	
	return $wmi.Get()
}

Write-Host "Obtaining credentials..."
$Credential = Get-Credential

Write-Host "Preparing excel spreadsheet..."
$excel = New-Object -comobject Excel.Application
$excel.visible = $True
$book = $excel.Workbooks.Add()
$wsheet = $book.Worksheets.Item(1)
$wsheet.Cells.Item(1,1) = "Server Name"
$wsheet.Cells.Item(1,2) = "Hostname / IP Address"
$wsheet.Cells.Item(1,3) = "Physical / Virtual"
$wsheet.Cells.Item(1,4) = "Operating System"
$wsheet.Cells.Item(1,5) = "Allocated Disk Space"
$wsheet.Cells.Item(1,6) = "Daily Rate of Change"
$wsheet.Cells.Item(1,7) = "Network Speed"
$wsheet.Cells.Item(1,8) = "Behind a Firewall"
$wsheet.Cells.Item(1,9) = "Connected to SAN Storage"
$wsheet.Cells.Item(1,10) = "Clustered?"
$wsheet.Cells.Item(1,11) = "Backup Frequency"
$wsheet.Cells.Item(1,12) = "Backup Selection Points"
$wsheet.Cells.Item(1,13) = "Indexed for Search"
$header = $wsheet.UsedRange
$header.Font.Bold = $True
$intRow = 2

Write-Host "Using client list [" $clients "] `n"
foreach ($svr in Get-Content $clients)
{
    if (!$svr.EndsWith($fqdndomain)) {
		if (!$dontautoadddomain) {
			if (!$fqdndomain.StartsWith(".")) {
				$svr += "." + $fqdndomain
			} else {
				$svr += $fqdndomain
			}
		}
    }

	Write-Host "$svr..."
	$wsheet.Cells.Item($intRow, 1) = $svr
	
	try {
		$OS = Get-WMICustom -query "select Caption from Win32_OperatingSystem" -computername $svr -credential $Credential -timeout $timeout
		$wsheet.Cells.Item($intRow, 4) = $OS.Caption
		
		$Computer = Get-WMICustom -query "select Manufacturer from Win32_ComputerSystem" -computername $svr -credential $Credential -timeout $timeout
		if ($Computer.Manufacturer -eq "VMware, Inc.") {
			$PhysicalVirtual = "Virtual"
		} else {
			$PhysicalVirtual = "Physical"
		}
		$wsheet.Cells.Item($intRow, 3) = $PhysicalVirtual
		
		$Network = Get-WMICustom -query "select IPAddress from Win32_NetworkAdapterConfiguration where IpEnabled = TRUE" -computername $svr -credential $Credential -timeout $timeout
		#$wsheet.Cells.Item($intRow, 2) = ($Network | ? { $_.IPAddress -ne $null }).ipaddress
		$IPs = ""
		foreach ($adapter in $Network) { if ($adapter.IPAddress -ne "0.0.0.0") { $IPs += $adapter.IPAddress + "`n" } }
		$wsheet.Cells.Item($intRow, 2) = $IPs
		
		$Disk = Get-WMICustom -query "select DeviceID,VolumeName from Win32_LogicalDisk where DriveType = 3" -computername $svr -credential $Credential -timeout $timeout
		$wsheet.Cells.Item($intRow, 5) = $Disk | Select-Object DeviceID,FreeSpace,ProviderName,Size,VolumeName |Format-Table -Auto
		
		$wsheet.Cells.Item($intRow, 13) = "No"
	}
	catch {
		$wsheet.Cells.Item($intRow, 2) = "failed to query: " + $_
	}
		
	$intRow = $intRow + 1
}

$tmp = $header.EntireColumn.AutoFit()
Write-Host "`ndone.."
