# Reset Windows Hello and NGC (Next Generation Credentials)
# This script must be run as Administrator

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Windows Hello / NGC Reset Script" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator', then run this script again." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

Write-Host "[1/6] Checking current NGC status..." -ForegroundColor Yellow

# Check for existing NGC containers
$userNgcPath = "$env:LOCALAPPDATA\Microsoft\Ngc"
$systemNgcPath = "C:\Windows\ServiceProfiles\LocalService\AppData\Local\Microsoft\Ngc"

if (Test-Path $userNgcPath) {
    Write-Host "  Found user NGC data at: $userNgcPath" -ForegroundColor Gray
} else {
    Write-Host "  No user NGC data found" -ForegroundColor Gray
}

if (Test-Path $systemNgcPath) {
    Write-Host "  Found system NGC data at: $systemNgcPath" -ForegroundColor Gray
} else {
    Write-Host "  No system NGC data found" -ForegroundColor Gray
}

Write-Host ""
Write-Host "[2/6] Stopping Windows Hello services..." -ForegroundColor Yellow

try {
    Stop-Service -Name NgcSvc -Force -ErrorAction SilentlyContinue
    Write-Host "  Stopped NgcSvc (Microsoft Passport)" -ForegroundColor Green
} catch {
    Write-Host "  NgcSvc was not running or could not be stopped" -ForegroundColor Gray
}

try {
    Stop-Service -Name NgcCtnrSvc -Force -ErrorAction SilentlyContinue
    Write-Host "  Stopped NgcCtnrSvc (Microsoft Passport Container)" -ForegroundColor Green
} catch {
    Write-Host "  NgcCtnrSvc was not running or could not be stopped" -ForegroundColor Gray
}

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "[3/6] Deleting NGC data..." -ForegroundColor Yellow

# Delete user NGC data
try {
    if (Test-Path $userNgcPath) {
        Remove-Item -Path "$userNgcPath\*" -Recurse -Force -ErrorAction Stop
        Write-Host "  Deleted user NGC data" -ForegroundColor Green
    } else {
        Write-Host "  No user NGC data to delete" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Warning: Could not delete user NGC data: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Delete system NGC data
try {
    if (Test-Path $systemNgcPath) {
        Remove-Item -Path "$systemNgcPath\*" -Recurse -Force -ErrorAction Stop
        Write-Host "  Deleted system NGC data" -ForegroundColor Green
    } else {
        Write-Host "  No system NGC data to delete" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Warning: Could not delete system NGC data: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[4/6] Clearing Windows Hello registry keys..." -ForegroundColor Yellow

# Clear user Hello settings
try {
    if (Test-Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\HelloSettings") {
        Remove-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\HelloSettings" -Recurse -Force -ErrorAction Stop
        Write-Host "  Cleared user Hello settings" -ForegroundColor Green
    } else {
        Write-Host "  No user Hello settings to clear" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Warning: Could not clear Hello settings: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Try to use certutil to delete Hello container
Write-Host ""
Write-Host "[5/6] Using certutil to delete Hello containers..." -ForegroundColor Yellow
try {
    $certutilOutput = certutil -deleteHelloContainer 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Successfully deleted Hello containers" -ForegroundColor Green
    } else {
        Write-Host "  certutil reported: $certutilOutput" -ForegroundColor Gray
    }
} catch {
    Write-Host "  certutil command not available or failed" -ForegroundColor Gray
}

Write-Host ""
Write-Host "[6/6] Restarting Windows Hello services..." -ForegroundColor Yellow

try {
    Start-Service -Name NgcSvc -ErrorAction SilentlyContinue
    Write-Host "  Started NgcSvc (Microsoft Passport)" -ForegroundColor Green
} catch {
    Write-Host "  Warning: Could not start NgcSvc: $($_.Exception.Message)" -ForegroundColor Yellow
}

try {
    Start-Service -Name NgcCtnrSvc -ErrorAction SilentlyContinue
    Write-Host "  Started NgcCtnrSvc (Microsoft Passport Container)" -ForegroundColor Green
} catch {
    Write-Host "  Warning: Could not start NgcCtnrSvc: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Reset Complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Restart your computer" -ForegroundColor White
Write-Host "2. After restart, go to Settings > Accounts > Sign-in options" -ForegroundColor White
Write-Host "3. Set up a new Windows Hello PIN" -ForegroundColor White
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
