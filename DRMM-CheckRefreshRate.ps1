<# Datto RMM Monitor component :: check monitor refresh rate :: build 1

   checks that the refresh rate across all screens doesn't fall below a minimum value
   default: 59 (=59.00 Hz)
#>

$desiredRefreshRate = 59;
$lowestRate = 999;

Get-WmiObject Win32_VideoController | ForEach-Object {
    if (($_.CurrentRefreshRate -is [uint32]) -and ($_.CurrentRefreshRate -lt $lowestRate)) {
        $lowestRate = $_.CurrentRefreshRate
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
    Write-Host "min=$lowestRate"
    Write-Host "<-End Result->"
    exit 0
}
