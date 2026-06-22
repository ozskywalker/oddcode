<#
.SYNOPSIS
  Enforces a chosen default search engine on Microsoft Edge, Google Chrome, and
  Mozilla Firefox via browser policy.

.DESCRIPTION
  Writes the HKLM Policies registry values that lock the default search engine for
  every installed, supported browser to the engine selected by $DesiredEngine.
  - Microsoft Edge / Google Chrome: sets the Chromium DefaultSearchProvider* policies.
  - Mozilla Firefox: sets the Enterprise Policy SearchEngines\Default value, and adds
    the engine via SearchEngines\Add if it is not one of Firefox's built-in engines
    in every locale (e.g. Ecosia).
  Browsers that are not installed are skipped. Each write is verified by reading the
  value back immediately after setting it.

.NOTES
  - Must run elevated (as Administrator, or as SYSTEM via an RMM agent/component).
    All registry writes target HKLM (machine-wide browser policy), never HKCU, so
    there is no per-user vs. per-machine conflict - running as SYSTEM is fine and
    is how most RMM platforms (including Level.io) execute scripts/components by
    default. Running as a regular, non-elevated user will fail with a
    SecurityException on every Set-ItemProperty call under HKLM.
  - Applicable to Windows 10 / Windows 11 / Windows Server.
  - Users must restart their browser(s) for the change to take effect.
  - Override the desired engine per-deployment by setting an RMM script variable named
    'DesiredSearchEngine' (exposed as environment variable $env:DesiredSearchEngine);
    otherwise the $DesiredEngine default below is used.
  - Supported engine keys: duckduckgo, ecosia, google. Add more by extending
    $SearchEngineCatalog identically in both this script and Get-DefaultSearchEngineStatus.ps1.
  - IMPORTANT: Chrome and Edge treat the default search provider policy as "protected".
    They will silently ignore these registry values unless the device is domain-joined,
    Entra ID (Azure AD) joined, or enrolled for MDM/device management. Firefox has no
    such restriction. Run Get-DefaultSearchEngineStatus.ps1 to check a device's join
    state if enforcement doesn't appear to take effect on Edge/Chrome.
  - Exit codes:
    0 = Desired engine successfully enforced (and verified) on all installed browsers
    1 = Unsupported $DesiredEngine value
    2 = Script is not running elevated (Administrator/SYSTEM required for HKLM writes)
    3 = One or more browsers failed to configure
#>

Set-StrictMode -Version Latest

# Desired default search engine to enforce. Valid keys: duckduckgo, ecosia, google
# Override per-deployment with an RMM script variable named DesiredSearchEngine.
$DesiredEngine = if ($env:DesiredSearchEngine) { $env:DesiredSearchEngine.Trim().ToLower() } else { 'duckduckgo' }

# Keep this catalog identical to the one in Get-DefaultSearchEngineStatus.ps1.
$SearchEngineCatalog = @{
    'google' = @{
        DisplayName     = 'Google'
        SearchURL       = 'https://www.google.com/search?q={searchTerms}'
        Keyword         = 'google.com'
        FirefoxName     = 'Google'
        FirefoxNeedsAdd = $false
    }
    'duckduckgo' = @{
        DisplayName     = 'DuckDuckGo'
        SearchURL       = 'https://duckduckgo.com/?q={searchTerms}'
        Keyword         = 'duckduckgo.com'
        FirefoxName     = 'DuckDuckGo'
        FirefoxNeedsAdd = $false
    }
    'ecosia' = @{
        DisplayName     = 'Ecosia'
        SearchURL       = 'https://www.ecosia.org/search?q={searchTerms}'
        Keyword         = 'ecosia.org'
        FirefoxName     = 'Ecosia'
        FirefoxNeedsAdd = $true
        FirefoxIconURL  = 'https://www.ecosia.org/favicon.ico'
    }
}

function Test-IsElevated {
    # HKLM writes (used for every browser policy in this script) require an elevated
    # process - either an interactive Administrator session, or SYSTEM (the context
    # most RMM agents/components run scripts under, including Level.io by default).
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return ($identity.IsSystem -or $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator))
}

function Write-Banner {
    $timeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $hostName  = $env:COMPUTERNAME
    $timeZone  = try { (Get-TimeZone).Id } catch { 'Unknown' }
    $osInfo    = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $osCaption = if ($osInfo) { $osInfo.Caption } else { 'Unknown OS' }
    $osVersion = if ($osInfo) { $osInfo.Version } else { 'Unknown Version' }

    Write-Host "========================================"
    Write-Host " Default Search Engine Enforcement"
    Write-Host " Date/Time: $timeStamp"
    Write-Host " Hostname:  $hostName"
    Write-Host " TimeZone:  $timeZone"
    Write-Host " OS:        $osCaption ($osVersion)"
    Write-Host "========================================"
    Write-Host ""
}

function Set-EdgeSearchEngine {
    param($Engine)

    $edgePath    = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    $edgePathX64 = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    if (-not ((Test-Path $edgePath) -or (Test-Path $edgePathX64))) {
        Write-Host "Microsoft Edge not detected, skipping."
        return 'Skipped'
    }

    Write-Host "Configuring Microsoft Edge default search engine to '$($Engine.DisplayName)'..."
    try {
        $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }

        Remove-ItemProperty -Path $regPath -Name 'DefaultSearchProviderEnabled' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $regPath -Name 'DefaultSearchProviderName' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $regPath -Name 'DefaultSearchProviderSearchURL' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $regPath -Name 'DefaultSearchProviderKeyword' -ErrorAction SilentlyContinue

        Set-ItemProperty -Path $regPath -Name 'DefaultSearchProviderEnabled' -Value 1 -Type DWord
        Set-ItemProperty -Path $regPath -Name 'DefaultSearchProviderName' -Value $Engine.DisplayName -Type String
        Set-ItemProperty -Path $regPath -Name 'DefaultSearchProviderSearchURL' -Value $Engine.SearchURL -Type String
        Set-ItemProperty -Path $regPath -Name 'DefaultSearchProviderKeyword' -Value $Engine.Keyword -Type String

        $verify = Get-ItemProperty -Path $regPath -Name 'DefaultSearchProviderName' -ErrorAction SilentlyContinue
        if (-not $verify -or $verify.DefaultSearchProviderName -ne $Engine.DisplayName) {
            Write-Host "  ERROR: Verification failed - registry value did not stick."
            return 'Failed'
        }

        Write-Host "  Edge configured and verified successfully."
        return 'Success'
    } catch {
        Write-Host "  ERROR: Failed to configure Edge - $($_.Exception.Message)"
        return 'Failed'
    }
}

function Set-ChromeSearchEngine {
    param($Engine)

    $chromePath    = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    $chromePathX64 = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
    if (-not ((Test-Path $chromePath) -or (Test-Path $chromePathX64))) {
        Write-Host "Google Chrome not detected, skipping."
        return 'Skipped'
    }

    Write-Host "Configuring Google Chrome default search engine to '$($Engine.DisplayName)'..."
    try {
        $regPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }

        Remove-ItemProperty -Path $regPath -Name 'DefaultSearchProviderEnabled' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $regPath -Name 'DefaultSearchProviderName' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $regPath -Name 'DefaultSearchProviderSearchURL' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $regPath -Name 'DefaultSearchProviderKeyword' -ErrorAction SilentlyContinue

        Set-ItemProperty -Path $regPath -Name 'DefaultSearchProviderEnabled' -Value 1 -Type DWord
        Set-ItemProperty -Path $regPath -Name 'DefaultSearchProviderName' -Value $Engine.DisplayName -Type String
        Set-ItemProperty -Path $regPath -Name 'DefaultSearchProviderSearchURL' -Value $Engine.SearchURL -Type String
        Set-ItemProperty -Path $regPath -Name 'DefaultSearchProviderKeyword' -Value $Engine.Keyword -Type String

        $verify = Get-ItemProperty -Path $regPath -Name 'DefaultSearchProviderName' -ErrorAction SilentlyContinue
        if (-not $verify -or $verify.DefaultSearchProviderName -ne $Engine.DisplayName) {
            Write-Host "  ERROR: Verification failed - registry value did not stick."
            return 'Failed'
        }

        Write-Host "  Chrome configured and verified successfully."
        return 'Success'
    } catch {
        Write-Host "  ERROR: Failed to configure Chrome - $($_.Exception.Message)"
        return 'Failed'
    }
}

function Set-FirefoxSearchEngine {
    param($Engine)

    $firefoxPath    = "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"
    $firefoxPathX64 = "$env:ProgramFiles\Mozilla Firefox\firefox.exe"
    if (-not ((Test-Path $firefoxPath) -or (Test-Path $firefoxPathX64))) {
        Write-Host "Mozilla Firefox not detected, skipping."
        return 'Skipped'
    }

    Write-Host "Configuring Mozilla Firefox default search engine to '$($Engine.DisplayName)'..."
    try {
        $regPath = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\SearchEngines"
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }

        Remove-ItemProperty -Path $regPath -Name 'Default' -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $regPath -Name 'Default' -Value $Engine.FirefoxName -Type String

        $addPath = Join-Path $regPath 'Add\1'
        if ($Engine.FirefoxNeedsAdd) {
            Write-Host "  '$($Engine.DisplayName)' is not built into Firefox in every locale; adding it via policy."
            if (-not (Test-Path $addPath)) {
                New-Item -Path $addPath -Force | Out-Null
            }
            Set-ItemProperty -Path $addPath -Name 'Name' -Value $Engine.FirefoxName -Type String
            Set-ItemProperty -Path $addPath -Name 'URLTemplate' -Value $Engine.SearchURL -Type String
            Set-ItemProperty -Path $addPath -Name 'Method' -Value 'GET' -Type String
            if ($Engine.FirefoxIconURL) {
                Set-ItemProperty -Path $addPath -Name 'IconURL' -Value $Engine.FirefoxIconURL -Type String
            }
        } elseif (Test-Path $addPath) {
            Write-Host "  Removing custom engine definition added by a previous run."
            Remove-Item -Path $addPath -Recurse -Force -ErrorAction SilentlyContinue
        }

        $verify = Get-ItemProperty -Path $regPath -Name 'Default' -ErrorAction SilentlyContinue
        if (-not $verify -or $verify.Default -ne $Engine.FirefoxName) {
            Write-Host "  ERROR: Verification failed - registry value did not stick."
            return 'Failed'
        }

        Write-Host "  Firefox configured and verified successfully."
        return 'Success'
    } catch {
        Write-Host "  ERROR: Failed to configure Firefox - $($_.Exception.Message)"
        return 'Failed'
    }
}

# --- MAIN SCRIPT EXECUTION ---

Write-Banner

if (-not (Test-IsElevated)) {
    Write-Host "ERROR: This script must run elevated (as Administrator or as SYSTEM)."
    Write-Host " - All registry writes target HKLM, which requires an elevated process."
    Write-Host " - If running manually, re-launch PowerShell with 'Run as Administrator'."
    Write-Host " - If running via an RMM agent (Level.io, Datto RMM, etc.), this is normally"
    Write-Host "   satisfied automatically since scripts/components execute as SYSTEM."
    Write-Host "========================================"
    Write-Host "Script completed with exit code: 2"
    Write-Host "========================================"
    exit 2
}

if (-not $SearchEngineCatalog.ContainsKey($DesiredEngine)) {
    Write-Host "ERROR: Unsupported DesiredEngine value '$DesiredEngine'."
    Write-Host " - Supported values: $($SearchEngineCatalog.Keys -join ', ')"
    Write-Host "========================================"
    Write-Host "Script completed with exit code: 1"
    Write-Host "========================================"
    exit 1
}

$engine = $SearchEngineCatalog[$DesiredEngine]
Write-Host "Enforcing default search engine: $($engine.DisplayName)"
Write-Host ""

$results = [ordered]@{
    Edge    = Set-EdgeSearchEngine -Engine $engine
    Chrome  = Set-ChromeSearchEngine -Engine $engine
    Firefox = Set-FirefoxSearchEngine -Engine $engine
}

Write-Host ""
$failed = $results.GetEnumerator() | Where-Object { $_.Value -eq 'Failed' }

if ($failed) {
    $failedNames = $failed | ForEach-Object { $_.Key }
    Write-Host "ERROR: Failed to enforce '$($engine.DisplayName)' on: $($failedNames -join ', ')"
    $results.GetEnumerator() | ForEach-Object { Write-Host " - $($_.Key): $($_.Value)" }
    $ErrorCode = 3
} else {
    Write-Host "SUCCESS: Default search engine enforced to '$($engine.DisplayName)' on all installed browsers."
    $results.GetEnumerator() | ForEach-Object { Write-Host " - $($_.Key): $($_.Value)" }
    Write-Host ""
    Write-Host "Note: Users must restart their browser(s) for the change to take effect."
    Write-Host "Note: Edge/Chrome will only honor this if the device is domain-joined, Entra ID"
    Write-Host "      joined, or MDM-enrolled. Run Get-DefaultSearchEngineStatus.ps1 to verify."
    $ErrorCode = 0
}

Write-Host "========================================"
Write-Host "Script completed with exit code: $ErrorCode"
Write-Host "========================================"

exit $ErrorCode
