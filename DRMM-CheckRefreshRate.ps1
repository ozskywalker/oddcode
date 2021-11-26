<# Datto RMM Monitor component :: check monitor refresh rate :: build 2

   checks that the refresh rate across all screens doesn't fall below a minimum value
   default: 59 (=59.00 Hz)

   changelog:
    build 2 -> filters out Hyper-V & RDP display adapters 
#>

$desiredRefreshRate = 59;
$lowestRate = 999;
$DriverFilterList = @("wvmbusvideo.inf", "rdpidd.inf")

Get-WmiObject Win32_VideoController | ForEach-Object {
    if (!$DriverFilterList.Contains($_.InfFilename)) {
        if (($_.CurrentRefreshRate -is [uint32]) -and ($_.CurrentRefreshRate -lt $lowestRate)) {
            $lowestRate = $_.CurrentRefreshRate
        }
    }
}

if ($lowestRate -lt $desiredRefreshRate) {
    Write-Host "<-Start Result->"
    Write-Host "min=$lowestRate"
    Write-Host "<-End Result->"

    Write-Host "<-Start Diagnostic->"
    Write-Host (Get-WmiObject Win32_VideoController | Out-String)
    Write-Host "<-End Diagnostic->"
    exit 1
} else {
    Write-Host "<-Start Result->"
    
    if ($lowestRate -eq 999) {
        Write-Host "No physical adapters or displays detected.  All OK."
    } else {
        Write-Host "min=$lowestRate"
    }

    Write-Host "<-End Result->"
    exit 0
}
