<#
.SYNOPSIS
  Downloads and silently installs the latest NVIDIA GeForce display driver, if a newer
  version is available than what's currently installed.

.DESCRIPTION
  Companion enforcement script to Get-NvidiaGeForceDriverUpdateStatus.ps1. Performs the
  same GPU/OS/driver-channel lookup against NVIDIA's public GeForce driver service, and if
  a newer driver is published, downloads the installer and runs it unattended
  (-s -passive -noreboot -noeula -nofinish). Does not force a reboot; some driver
  components may not take effect until the machine restarts.

.NOTES
  - Run as Administrator (or via an RMM agent already running as SYSTEM).
  - Compatible with Windows 10, Windows 11, and Windows Server.
  - Downloads the full NVIDIA installer package (several hundred MB) to
    $env:TEMP\NvidiaDriverUpdate and removes it afterwards.
  - Requires outbound internet (HTTPS) access to raw.githubusercontent.com,
    gfwsl.geforce.com, and NVIDIA's download CDN.
  - Idempotent: if the installed driver is already current, no download/install occurs.
  - Exit codes:
    0 = Driver installed successfully, or already up to date (no action needed)
    1 = Driver installer ran but returned a non-zero exit code
    2 = System or network error - unable to complete the update
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
$InstallArgs = "-s -passive -noreboot -noeula -nofinish"

function Write-Banner {
    $timeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $hostName = $env:COMPUTERNAME
    $timeZone = try { (Get-TimeZone).Id } catch { "Unknown" }
    $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $osCaption = if ($osInfo) { $osInfo.Caption } else { "Unknown OS" }
    $osVersion = if ($osInfo) { $osInfo.Version } else { "Unknown Version" }

    Write-Host "========================================"
    Write-Host " NVIDIA GeForce Driver Update Starting"
    Write-Host " Date/Time: $timeStamp"
    Write-Host " Hostname:  $hostName"
    Write-Host " TimeZone:  $timeZone"
    Write-Host " OS:        $osCaption ($osVersion)"
    Write-Host "========================================"
    Write-Host ""

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "WARNING: Not running with Administrator privileges - installation may fail"
        Write-Host ""
    }
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
$resultLines = @()
$workDir = Join-Path $env:TEMP "NvidiaDriverUpdate"
$installerPath = Join-Path $workDir "nvidia-driver-install.exe"

try {
    $gpu = Get-InstalledNvidiaGpu
    if (-not $gpu) {
        $exitCode = 3
        $resultLines += "No NVIDIA GPU detected on this system - nothing to do"
    } else {
        Write-Host "Detected GPU: $($gpu.Name)"
        $cleanName = Get-CleanGpuName -RawName $gpu.Name
        if (-not $cleanName) {
            throw "Unable to parse GPU name '$($gpu.Name)' - unrecognised format"
        }
        $gpuType = Get-GpuType
        $localVersion = ConvertTo-NvidiaVersionString -WmiDriverVersion $gpu.DriverVersion
        Write-Host "Installed driver version: $localVersion"

        $latest = Get-LatestNvidiaDriverInfo -CleanGpuName $cleanName -GpuType $gpuType
        Write-Host "Latest available driver version: $($latest.Version)"

        if ([version]$latest.Version -le [version]$localVersion) {
            $exitCode = 0
            $resultLines += "NVIDIA driver is already up to date (version $localVersion) - no action taken"
        } else {
            Write-Host "Update available: $localVersion -> $($latest.Version)"
            Write-Host "Downloading installer from $($latest.DownloadUrl)"

            if (Test-Path $workDir) {
                Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            New-Item -Path $workDir -ItemType Directory -Force | Out-Null

            Invoke-WebRequest -Uri $latest.DownloadUrl -OutFile $installerPath -UseBasicParsing -ErrorAction Stop

            Write-Host "Running silent install (this can take several minutes)..."
            $proc = Start-Process -FilePath $installerPath -ArgumentList $InstallArgs -Wait -PassThru -ErrorAction Stop
            Write-Host "Installer exit code: $($proc.ExitCode)"

            if ($proc.ExitCode -eq 0) {
                $exitCode = 0
                $resultLines += "NVIDIA driver updated to version $($latest.Version)"
                $resultLines += "A reboot may be required for the update to fully take effect"
            } else {
                $exitCode = 1
                $resultLines += "NVIDIA driver installer exited with code $($proc.ExitCode)"
            }
        }
    }
} catch {
    $exitCode = 2
    $resultLines += "Failed to update NVIDIA driver - $($_.Exception.Message)"
} finally {
    if (Test-Path $workDir) {
        Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "SUCCESS: $($resultLines[0])"
} else {
    Write-Host "ERROR: $($resultLines[0])"
}
foreach ($line in $resultLines | Select-Object -Skip 1) {
    Write-Host " - $line"
}

Write-Host ""
Write-Host "========================================"
Write-Host "Script completed with exit code: $exitCode"
Write-Host "========================================"

exit $exitCode
