<#
.SYNOPSIS
  Configures screensaver settings to ensure 10-minute timeout with password protection.

.DESCRIPTION
  This script enforces screensaver compliance by:
  1. Enabling screensaver functionality
  2. Setting timeout to 10 minutes (600 seconds)
  3. Enabling password protection on resume
  4. Setting to Blank screensaver ONLY if no screensaver is currently configured

.NOTES
  - Run as Administrator for best results.
  - Compatible with Windows 10, Windows 11, and Windows Server.
  - Will preserve existing screensaver choice if one is already configured.
  - Only sets to Blank screensaver if currently set to "None".
#>

Set-StrictMode -Version Latest

# Configuration values
$TargetTimeout = "600"     # 10 minutes in seconds
$EnableActive = "1"        # Enable screensaver
$EnableSecure = "1"        # Require password on resume
$BlankScreensaver = "scrnsave.scr"  # Blank screensaver filename

function Write-Banner {
    $timeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $hostName = $env:COMPUTERNAME
    $timeZone = try { (Get-TimeZone).Id } catch { "Unknown" }
    $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $osCaption = if ($osInfo) { $osInfo.Caption } else { "Unknown OS" }
    $osVersion = if ($osInfo) { $osInfo.Version } else { "Unknown Version" }

    Write-Host "========================================"
    Write-Host " ScreenSaver Compliance Script Starting"
    Write-Host " Date/Time: $timeStamp"
    Write-Host " Hostname: $hostName"
    Write-Host " TimeZone: $timeZone"
    Write-Host " OS: $osCaption ($osVersion)"
    Write-Host "========================================"
    Write-Host ""
}

function Set-ScreensaverConfiguration {
    Write-Host "Configuring screensaver settings..."
    
    try {
        $regPath = "HKCU:\Control Panel\Desktop"
        
        # Ensure the registry path exists
        if (-not (Test-Path $regPath)) {
            Write-Host " Creating registry path: $regPath"
            New-Item -Path $regPath -Force | Out-Null
        }
        
        # 1. Enable screensaver
        Write-Host " Setting ScreenSaveActive to enabled ($EnableActive)"
        Set-ItemProperty -Path $regPath -Name "ScreenSaveActive" -Value $EnableActive -Type String
        
        # 2. Set 10-minute timeout
        Write-Host " Setting ScreenSaveTimeOut to 10 minutes ($TargetTimeout seconds)"
        Set-ItemProperty -Path $regPath -Name "ScreenSaveTimeOut" -Value $TargetTimeout -Type String
        
        # 3. Enable password protection
        Write-Host " Setting ScreenSaverIsSecure to enabled ($EnableSecure)"
        Set-ItemProperty -Path $regPath -Name "ScreenSaverIsSecure" -Value $EnableSecure -Type String
        
        # 3b. Additional password protection setting (some systems require this)
        Write-Host " Setting ScreenSaveUsePassword to enabled ($EnableSecure)"
        Set-ItemProperty -Path $regPath -Name "ScreenSaveUsePassword" -Value $EnableSecure -Type String -ErrorAction SilentlyContinue
        
        # 4. Check if screensaver is currently set to "None" and set to Blank if needed
        $currentScreensaver = Get-ItemProperty -Path $regPath -Name "SCRNSAVE.EXE" -ErrorAction SilentlyContinue
        
        if (-not $currentScreensaver -or -not $currentScreensaver.'SCRNSAVE.EXE' -or $currentScreensaver.'SCRNSAVE.EXE' -eq "") {
            Write-Host " No screensaver currently configured (set to 'None')"
            Write-Host " Setting screensaver to Blank ($BlankScreensaver)"
            
            # Verify the blank screensaver file exists
            $screensaverPath = Join-Path $env:SystemRoot "System32\$BlankScreensaver"
            if (Test-Path $screensaverPath) {
                Set-ItemProperty -Path $regPath -Name "SCRNSAVE.EXE" -Value $BlankScreensaver -Type String
                Write-Host " Successfully set screensaver to: $BlankScreensaver"
            } else {
                Write-Host " WARNING: $BlankScreensaver not found at $screensaverPath"
                Write-Host " Attempting to use system default blank screensaver..."
                
                # Try alternative blank screensaver names
                $alternatives = @("ssText3d.scr", "Bubbles.scr", "Mystify.scr")
                $found = $false
                
                foreach ($alt in $alternatives) {
                    $altPath = Join-Path $env:SystemRoot "System32\$alt"
                    if (Test-Path $altPath) {
                        Set-ItemProperty -Path $regPath -Name "SCRNSAVE.EXE" -Value $alt -Type String
                        Write-Host " Set screensaver to available alternative: $alt"
                        $found = $true
                        break
                    }
                }
                
                if (-not $found) {
                    Write-Host " ERROR: No screensaver files found in System32 directory"
                    return $false
                }
            }
        } else {
            Write-Host " Existing screensaver detected: $($currentScreensaver.'SCRNSAVE.EXE')"
            Write-Host " Preserving current screensaver choice"
        }
        
        # 5. Force system to refresh screensaver settings
        Write-Host " Refreshing system screensaver settings..."
        try {
            # Update system parameters to force refresh
            Add-Type -TypeDefinition @"
                using System;
                using System.Runtime.InteropServices;
                public class SystemParams {
                    [DllImport("user32.dll", SetLastError = true)]
                    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);
                }
"@
            # SPI_SETSCREENSAVEACTIVE = 0x0011, SPIF_SENDCHANGE = 0x02
            [SystemParams]::SystemParametersInfo(0x0011, 1, [IntPtr]::Zero, 0x02) | Out-Null
            Write-Host " System parameters updated successfully"
        } catch {
            Write-Host " Warning: Could not refresh system parameters - $($_.Exception.Message)"
        }
        
        return $true
        
    } catch {
        Write-Host " ERROR: Failed to configure screensaver settings - $($_.Exception.Message)"
        return $false
    }
}

function Test-ConfigurationApplied {
    Write-Host "Verifying configuration was applied successfully..."
    
    try {
        $regPath = "HKCU:\Control Panel\Desktop"
        
        # Check each setting
        $active = Get-ItemProperty -Path $regPath -Name "ScreenSaveActive" -ErrorAction SilentlyContinue
        $timeout = Get-ItemProperty -Path $regPath -Name "ScreenSaveTimeOut" -ErrorAction SilentlyContinue
        $secure = Get-ItemProperty -Path $regPath -Name "ScreenSaverIsSecure" -ErrorAction SilentlyContinue
        $screensaver = Get-ItemProperty -Path $regPath -Name "SCRNSAVE.EXE" -ErrorAction SilentlyContinue
        
        $success = $true
        
        if (-not $active -or $active.ScreenSaveActive -ne $EnableActive) {
            Write-Host " ❌ ScreenSaveActive verification failed"
            $success = $false
        } else {
            Write-Host " ✅ ScreenSaveActive: $($active.ScreenSaveActive)"
        }
        
        if (-not $timeout -or $timeout.ScreenSaveTimeOut -ne $TargetTimeout) {
            Write-Host " ❌ ScreenSaveTimeOut verification failed"
            $success = $false
        } else {
            $minutes = [math]::Round([int]$timeout.ScreenSaveTimeOut / 60, 1)
            Write-Host " ✅ ScreenSaveTimeOut: $($timeout.ScreenSaveTimeOut) seconds ($minutes minutes)"
        }
        
        if (-not $secure -or $secure.ScreenSaverIsSecure -ne $EnableSecure) {
            Write-Host " ❌ ScreenSaverIsSecure verification failed"
            $success = $false
        } else {
            Write-Host " ✅ ScreenSaverIsSecure: $($secure.ScreenSaverIsSecure)"
        }
        
        if (-not $screensaver -or -not $screensaver.'SCRNSAVE.EXE' -or $screensaver.'SCRNSAVE.EXE' -eq "") {
            Write-Host " ❌ SCRNSAVE.EXE verification failed (still set to None)"
            $success = $false
        } else {
            Write-Host " ✅ SCRNSAVE.EXE: $($screensaver.'SCRNSAVE.EXE')"
        }
        
        return $success
        
    } catch {
        Write-Host " ERROR: Failed to verify configuration - $($_.Exception.Message)"
        return $false
    }
}

# Main execution
Write-Banner

$configResult = Set-ScreensaverConfiguration

if ($configResult) {
    Write-Host ""
    $verifyResult = Test-ConfigurationApplied
    
    if ($verifyResult) {
        Write-Host ""
        Write-Host "SUCCESS: Screensaver compliance configuration completed"
        Write-Host " - Screensaver enabled with 10-minute timeout"
        Write-Host " - Password protection enabled"
        Write-Host " - Screensaver properly configured"
        Write-Host ""
        Write-Host "Note: Changes will take effect immediately. Users may need to log off/on for some settings to fully apply."
        exit 0
    } else {
        Write-Host ""
        Write-Host "ERROR: Configuration applied but verification failed"
        Write-Host " - Some settings may not have been applied correctly"
        Write-Host " - Check system permissions and Group Policy settings"
        exit 1
    }
} else {
    Write-Host ""
    Write-Host "ERROR: Failed to configure screensaver compliance"
    Write-Host " - Check system permissions and registry access"
    Write-Host " - Ensure script is running with sufficient privileges"
    exit 1
}