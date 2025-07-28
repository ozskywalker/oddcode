<#
.SYNOPSIS
  Checks that screensaver is enabled with 10-minute timeout and password protection.

.DESCRIPTION
  This script is intended for use with Level.io RMM as a monitor.
  - If everything is compliant, it returns "SUCCESS:" and exit code 0.
  - If there are issues, it returns "ERROR:" and non-zero exit code.

.NOTES
  - Compatible with Windows 10, Windows 11, and Windows Server.
  - Checks both user preferences and Group Policy settings.
  - Exit codes:
    0 = All checks passed (compliant)
    1 = Screensaver configuration non-compliant
    2 = System error or unable to read configuration
#>

Set-StrictMode -Version Latest

# Expected configuration values
$ExpectedTimeout = "600"  # 10 minutes in seconds
$ExpectedActive = "1"     # Screensaver enabled
$ExpectedSecure = "1"     # Password required on resume

# Initialize error tracking
$ErrorCode = 0
$Issues = @()

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

function Test-ScreensaverCompliance {
    Write-Host "Checking screensaver configuration..."
    
    try {
        # Primary registry location for user preferences
        $regPath = "HKCU:\Control Panel\Desktop"
        
        # Check if screensaver is enabled
        $screenSaveActive = Get-ItemProperty -Path $regPath -Name "ScreenSaveActive" -ErrorAction SilentlyContinue
        $currentActive = if ($screenSaveActive) { $screenSaveActive.ScreenSaveActive } else { $null }
        
        Write-Host " Current ScreenSaveActive: $currentActive"
        if ($currentActive -ne $ExpectedActive) {
            $Issues += "Screensaver is not enabled (Expected: $ExpectedActive, Current: $currentActive)"
        }
        
        # Check timeout setting
        $screenSaveTimeout = Get-ItemProperty -Path $regPath -Name "ScreenSaveTimeOut" -ErrorAction SilentlyContinue
        $currentTimeout = if ($screenSaveTimeout) { $screenSaveTimeout.ScreenSaveTimeOut } else { $null }
        
        Write-Host " Current ScreenSaveTimeOut: $currentTimeout seconds"
        if ($currentTimeout -ne $ExpectedTimeout) {
            $timeoutMinutes = if ($currentTimeout) { [math]::Round([int]$currentTimeout / 60, 1) } else { "Not Set" }
            $Issues += "Screensaver timeout is not 10 minutes (Expected: 10 min, Current: $timeoutMinutes min)"
        }
        
        # Check if password is required
        $screenSaverSecure = Get-ItemProperty -Path $regPath -Name "ScreenSaverIsSecure" -ErrorAction SilentlyContinue
        $currentSecure = if ($screenSaverSecure) { $screenSaverSecure.ScreenSaverIsSecure } else { $null }
        
        Write-Host " Current ScreenSaverIsSecure: $currentSecure"
        if ($currentSecure -ne $ExpectedSecure) {
            $Issues += "Screensaver password protection is not enabled (Expected: $ExpectedSecure, Current: $currentSecure)"
        }
        
        # Check if any screensaver is configured (not "None")
        $screenSaverExe = Get-ItemProperty -Path $regPath -Name "SCRNSAVE.EXE" -ErrorAction SilentlyContinue
        $currentScreensaver = if ($screenSaverExe) { $screenSaverExe.'SCRNSAVE.EXE' } else { $null }
        
        Write-Host " Current SCRNSAVE.EXE: $currentScreensaver"
        if (-not $currentScreensaver -or $currentScreensaver -eq "") {
            $Issues += "No screensaver is configured (set to 'None')"
        }
        
        # Check for Group Policy overrides that might prevent user changes
        $userPolicyPath = "HKCU:\Software\Policies\Microsoft\Windows\Control Panel\Desktop"
        $computerPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop"
        
        $hasUserPolicy = Test-Path $userPolicyPath
        $hasComputerPolicy = Test-Path $computerPolicyPath
        
        if ($hasUserPolicy -or $hasComputerPolicy) {
            Write-Host " Group Policy settings detected - checking for overrides..."
            
            # Check if Group Policy is enforcing different settings
            foreach ($policyPath in @($computerPolicyPath, $userPolicyPath)) {
                if (Test-Path $policyPath) {
                    $policyActive = Get-ItemProperty -Path $policyPath -Name "ScreenSaveActive" -ErrorAction SilentlyContinue
                    $policyTimeout = Get-ItemProperty -Path $policyPath -Name "ScreenSaveTimeOut" -ErrorAction SilentlyContinue
                    
                    if ($policyActive -and $policyActive.ScreenSaveActive -ne $ExpectedActive) {
                        Write-Host " WARNING: Group Policy may be overriding screensaver enabled setting"
                    }
                    if ($policyTimeout -and $policyTimeout.ScreenSaveTimeOut -ne $ExpectedTimeout) {
                        Write-Host " WARNING: Group Policy may be overriding screensaver timeout setting"
                    }
                }
            }
        }
        
    } catch {
        Write-Host " ERROR: Failed to check screensaver configuration - $($_.Exception.Message)"
        return 2
    }
    
    Write-Host ""
    
    # Return appropriate error code
    if ($Issues.Count -gt 0) {
        return 1
    } else {
        return 0
    }
}

# Main execution
Write-Banner

$complianceResult = Test-ScreensaverCompliance

# Output results in Level.io format
if ($complianceResult -eq 0) {
    Write-Host "SUCCESS: Screensaver is properly configured with 10-minute timeout and password protection"
    Write-Host " - Screensaver enabled: $ExpectedActive"
    Write-Host " - Timeout: 10 minutes ($ExpectedTimeout seconds)"
    Write-Host " - Password required: $ExpectedSecure"
    Write-Host " - Screensaver configured (not 'None')"
} elseif ($complianceResult -eq 1) {
    Write-Host "ERROR: Screensaver configuration is not compliant"
    foreach ($issue in $Issues) {
        Write-Host " - $issue"
    }
} else {
    Write-Host "ERROR: Unable to check screensaver configuration due to system error"
}

Write-Host "========================================"
Write-Host "Script completed with exit code: $complianceResult"
Write-Host "========================================"

exit $complianceResult