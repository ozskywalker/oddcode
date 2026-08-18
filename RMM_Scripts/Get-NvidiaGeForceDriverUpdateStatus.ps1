<#
.SYNOPSIS
  Checks whether a newer NVIDIA GeForce display driver is available for download.

.DESCRIPTION
  This script is intended for use with RMM solutions (Datto RMM, Level.io, etc.) as a monitor.
  It reads the currently installed NVIDIA driver version from WMI, then queries NVIDIA's
  public GeForce driver lookup service for the latest driver matching the installed GPU
  model, OS, and driver channel (DCH vs standard). No files are downloaded by this script -
  see the companion Set-NvidiaGeForceDriverUpdate.ps1 script to actually install an update.
  - If the installed driver is current, it returns "SUCCESS:" and exit code 0.
  - If a newer driver is available, it returns "ERROR:" and exit code 1.

.NOTES
  - Compatible with Windows 10, Windows 11, and Windows Server, on any system with a
    supported NVIDIA GeForce GPU installed.
  - Only inspects the first NVIDIA GPU reported by Win32_VideoController.
  - Only covers consumer GeForce driver releases. Quadro/NVS/Tesla cards are not present
    in NVIDIA's GeForce lookup dataset and will be reported as "unable to determine".
  - Relies on the community-maintained GPU/OS ID datasets at
    https://github.com/ZenitH-AT/nvidia-data and NVIDIA's public AjaxDriverService.php
    endpoint. Requires outbound internet (HTTPS) access - no API key needed.
  - Exit codes:
    0 = Driver is up to date (compliant)
    1 = Newer driver is available (non-compliant, remediation needed)
    2 = System or network error - unable to determine update status
    3 = No supported NVIDIA GeForce GPU detected (not applicable)
#>

Set-StrictMode -Version Latest

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {}

$OsDataUrl = "https://raw.githubusercontent.com/ZenitH-AT/nvidia-data/main/os-data.json"
$GpuDataUrl = "https://raw.githubusercontent.com/ZenitH-AT/nvidia-data/main/gpu-data.json"
$DriverLookupBaseUrl = "https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php"
$NotebookChassisTypes = @(8, 9, 10, 11, 12, 14, 18, 21, 31, 32)
$CleanGpuNameRegex = "(?<=NVIDIA )(.*(?= \([A-Z]+\))|.*(?= [0-9]+GB)|.*(?= COLLECTORS EDITION)|.*(?= with Max-Q Design)|.*)"

function Write-Banner {
    $timeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $hostName = $env:COMPUTERNAME
    $timeZone = try { (Get-TimeZone).Id } catch { "Unknown" }
    $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $osCaption = if ($osInfo) { $osInfo.Caption } else { "Unknown OS" }
    $osVersion = if ($osInfo) { $osInfo.Version } else { "Unknown Version" }

    Write-Host "========================================"
    Write-Host " Script Execution Timestamp:  $timeStamp"
    Write-Host " Hostname:                    $hostName"
    Write-Host " TimeZone:                    $timeZone"
    Write-Host " OS Name:                     $osCaption"
    Write-Host " OS Version:                  $osVersion"
    Write-Host "========================================"
    Write-Host ""
}

function Get-InstalledNvidiaGpu {
    # Returns the first NVIDIA GPU reported by WMI, or $null if none is present
    Get-CimInstance -Class Win32_VideoController -ErrorAction Stop |
        Where-Object { $_.Name -match '^NVIDIA' -and $_.DriverVersion } |
        Select-Object -First 1
}

function Get-CleanGpuName {
    # Strips the "NVIDIA " prefix plus memory/OEM/Max-Q suffixes to match the
    # community GPU ID dataset's naming, e.g. "NVIDIA GeForce RTX 4070 8GB" -> "GeForce RTX 4070"
    param([Parameter(Mandatory)][string]$RawName)

    if ($RawName -notmatch $CleanGpuNameRegex) {
        return $null
    }
    ($Matches[0]).Replace("Super", "SUPER").Trim()
}

function Get-GpuType {
    # Desktop vs notebook, based on chassis type - selects which table of the GPU ID dataset to use
    try {
        $chassisTypes = (Get-CimInstance -Class Win32_SystemEnclosure -ErrorAction Stop).ChassisTypes
        if ($chassisTypes | Where-Object { $_ -in $NotebookChassisTypes }) {
            return "notebook"
        }
    } catch {}
    return "desktop"
}

function ConvertTo-NvidiaVersionString {
    # NVIDIA's WMI-reported DriverVersion (eg "32.0.15.6614") encodes the public driver
    # version (eg "566.14") in its last 5 digits once the dots are stripped out.
    param([Parameter(Mandatory)][string]$WmiDriverVersion)

    $digitsOnly = $WmiDriverVersion -replace '\.', ''
    if ($digitsOnly.Length -lt 5) {
        throw "Unexpected DriverVersion format: $WmiDriverVersion"
    }
    $last5 = $digitsOnly.Substring($digitsOnly.Length - 5)
    $last5.Insert(3, '.')
}

function Test-DchDriver {
    # DCH is the only packaging NVIDIA has published for current GeForce cards since ~2021;
    # standard (non-DCH) packages only apply to pre-Win10 systems.
    try {
        $buildNumber = (Get-CimInstance -Class Win32_OperatingSystem -ErrorAction Stop).BuildNumber
        return [int]$buildNumber -ge 10240
    } catch {
        return $true
    }
}

function Get-LatestNvidiaDriverInfo {
    # Looks up the latest published driver for the given GPU/OS/channel via NVIDIA's
    # public GeForce driver lookup service. Returns an object with Version/DownloadUrl.
    param(
        [Parameter(Mandatory)][string]$CleanGpuName,
        [Parameter(Mandatory)][string]$GpuType
    )

    $gpuData = Invoke-RestMethod -Uri $GpuDataUrl -UseBasicParsing -ErrorAction Stop
    $pfid = $gpuData.$GpuType.$CleanGpuName
    if (-not $pfid) {
        throw "GPU '$CleanGpuName' ($GpuType) not found in NVIDIA GPU ID dataset"
    }

    $osData = Invoke-RestMethod -Uri $OsDataUrl -UseBasicParsing -ErrorAction Stop
    $osVersionCode = "$([Environment]::OSVersion.Version.Major).$([Environment]::OSVersion.Version.Minor)"
    $osBits = if ([Environment]::Is64BitOperatingSystem) { "64" } else { "32" }
    $osEntry = $osData | Where-Object { $_.code -eq $osVersionCode -and $_.name -match $osBits } | Select-Object -First 1
    if (-not $osEntry) {
        throw "No matching OS entry found for Windows $osVersionCode ($osBits-bit)"
    }

    $dch = if (Test-DchDriver) { 1 } else { 0 }
    $lookupUri = "$($DriverLookupBaseUrl)?func=DriverManualLookup&pfid=$pfid&osID=$($osEntry.id)&dch=$dch&sort1=0&numberOfResults=1"
    $response = Invoke-RestMethod -Uri $lookupUri -UseBasicParsing -ErrorAction Stop

    if ($response.Success -ne 1 -or -not $response.IDS -or $response.IDS.Count -eq 0) {
        throw "NVIDIA driver lookup service returned no results"
    }

    $downloadInfo = $response.IDS[0].downloadInfo
    [PSCustomObject]@{
        Version     = $downloadInfo.Version
        DownloadUrl = $downloadInfo.DownloadURL
    }
}

# Main execution
Write-Banner

$exitCode = 0
$statusMessage = ""
$details = @()

try {
    $gpu = Get-InstalledNvidiaGpu
    if (-not $gpu) {
        $exitCode = 3
        $statusMessage = "No NVIDIA GPU detected on this system"
    } else {
        Write-Host "Detected GPU: $($gpu.Name)"
        Write-Host "Raw WMI DriverVersion: $($gpu.DriverVersion)"

        $cleanName = Get-CleanGpuName -RawName $gpu.Name
        if (-not $cleanName) {
            throw "Unable to parse GPU name '$($gpu.Name)' - unrecognised format"
        }
        $gpuType = Get-GpuType
        Write-Host "Clean GPU name: $cleanName ($gpuType)"

        $localVersion = ConvertTo-NvidiaVersionString -WmiDriverVersion $gpu.DriverVersion
        Write-Host "Installed driver version: $localVersion"

        $latest = Get-LatestNvidiaDriverInfo -CleanGpuName $cleanName -GpuType $gpuType
        Write-Host "Latest available driver version: $($latest.Version)"

        if ([version]$latest.Version -gt [version]$localVersion) {
            $exitCode = 1
            $statusMessage = "NVIDIA driver update available: $localVersion -> $($latest.Version)"
            $details = @(
                "GPU: $($gpu.Name)",
                "Installed version: $localVersion",
                "Latest version: $($latest.Version)",
                "Download URL: $($latest.DownloadUrl)"
            )
        } else {
            $exitCode = 0
            $statusMessage = "NVIDIA driver is up to date (version $localVersion)"
            $details = @(
                "GPU: $($gpu.Name)",
                "Installed version: $localVersion",
                "Latest version: $($latest.Version)"
            )
        }
    }
} catch {
    $exitCode = 2
    $statusMessage = "Unable to determine NVIDIA driver update status - $($_.Exception.Message)"
}

Write-Host ""
if ($exitCode -eq 1 -or $exitCode -eq 2) {
    Write-Host "ERROR: $statusMessage"
} else {
    Write-Host "SUCCESS: $statusMessage"
}
foreach ($line in $details) {
    Write-Host " - $line"
}

Write-Host ""
Write-Host "========================================"
Write-Host "Script completed with exit code: $exitCode"
Write-Host "========================================"

exit $exitCode
