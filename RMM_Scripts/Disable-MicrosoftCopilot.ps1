# Script to check and reset Windows Copilot settings
$registryPath = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
$propertyName = "TurnOffWindowsCopilot"

# Function to check if Windows Copilot registry key exists and its value
function Get-CopilotRegistryStatus {
    # Check if registry path exists
    if (Test-Path -Path $registryPath) {
        Write-Host "Registry path exists: $registryPath"
        
        # Check if property exists
        if (Get-ItemProperty -Path $registryPath -Name $propertyName -ErrorAction SilentlyContinue) {
            $currentValue = (Get-ItemProperty -Path $registryPath -Name $propertyName).$propertyName
            return $currentValue
        } else {
            Write-Host "Registry key exists but value not set. Will force reset."
            return 1
        }
    } else {
        Write-Host "Registry key doesn't exist."
        return $null
    }
}

# Function to check if Copilot package is installed
function Get-CopilotPackageStatus {
    $copilotAppx = Get-AppxPackage -Name "Microsoft.Copilot" -ErrorAction SilentlyContinue
    if ($copilotAppx) {
        return $copilotAppx
    } else {
        return $null
    }
}

# Function to remove Copilot package
function Remove-CopilotPackage {
    param($package)
    
    try {
        Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
        Write-Host "✅ Copilot package removed successfully."
        return $true
    } catch {
        Write-Error "⚠️ Failed to remove Copilot package: $_"
        return $false
    }
}

# Function to reset registry value from 1 to 0
function Reset-CopilotRegistryValue {
    try {
        Set-ItemProperty -Path $registryPath -Name $propertyName -Value 0 -Type DWord -Force
        Write-Host "✅ SUCCESS: Windows Copilot registry value reset to 0."
        return $true
    } catch {
        Write-Error "⚠️ Failed to reset Windows Copilot registry value: $_"
        return $false
    }
}

# Main script execution
Write-Host "Checking Windows Copilot status..." -ForegroundColor Cyan

# Check if Copilot package is installed
$copilotPackage = Get-CopilotPackageStatus
if ($copilotPackage) {
    Write-Host "📦 Windows Copilot package is installed. Removing..." -ForegroundColor Yellow
    Remove-CopilotPackage -package $copilotPackage
} else {
    Write-Host "👍 No Windows Copilot package found."
}

# Check registry key status
$registryValue = Get-CopilotRegistryStatus
if ($null -ne $registryValue) {
    if ($registryValue -eq 1) {
        Write-Host "🔄 ShowCopiloty regkey is set to 1. Resetting to 0..." -ForegroundColor Yellow
        Reset-CopilotRegistryValue
    } else {
        Write-Host "👍 ShowCopilot regkey is already set to 0. No changes needed."
    }
} else {
    Write-Host "👍 No registry key to modify."
}

Write-Host "Script completed." -ForegroundColor Green