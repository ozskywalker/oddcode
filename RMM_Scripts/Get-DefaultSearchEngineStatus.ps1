<#
.SYNOPSIS
  Checks whether Microsoft Edge, Google Chrome, and Mozilla Firefox are enforcing
  the desired default search engine via browser policy.

.DESCRIPTION
  This script is intended for use with RMM solutions (Level.io, Datto RMM, etc.) as a monitor.
  - If the desired engine is enforced on every installed, supported browser, it returns
    "SUCCESS:" and exit code 0.
  - If any installed browser does not have the desired engine enforced, it returns
    "ERROR:" and a non-zero exit code.
  - Browsers that are not installed are skipped and do not affect the result.

.NOTES
  - Compatible with Windows 10, Windows 11, and Windows Server.
  - Checks the same HKLM Policies registry values that Set-DefaultSearchEngine.ps1 writes.
  - Override the desired engine per-deployment by setting an RMM script variable named
    'DesiredSearchEngine' (exposed as environment variable $env:DesiredSearchEngine);
    otherwise the $DesiredEngine default below is used.
  - Supported engine keys: duckduckgo, ecosia, google. Add more by extending
    $SearchEngineCatalog identically in both this script and Set-DefaultSearchEngine.ps1.
  - IMPORTANT: Chrome and Edge treat the default search provider policy as a "protected"
    policy. They silently ignore it unless the device is domain-joined, Entra ID
    (Azure AD) joined, or enrolled for MDM/device management. Firefox has no such
    restriction. This script detects and reports the device's join state so a failure
    on an unmanaged workgroup PC can be told apart from a real misconfiguration.
  - Exit codes:
    0 = All installed browsers compliant
    1 = Microsoft Edge non-compliant
    2 = Google Chrome non-compliant
    3 = Mozilla Firefox non-compliant
    4 = Multiple browsers non-compliant
    5 = Unsupported $DesiredEngine value or system error
#>

Set-StrictMode -Version Latest

# Desired default search engine to enforce. Valid keys: duckduckgo, ecosia, google
# Override per-deployment with an RMM script variable named DesiredSearchEngine.
$DesiredEngine = if ($env:DesiredSearchEngine) { $env:DesiredSearchEngine.Trim().ToLower() } else { 'duckduckgo' }

# Keep this catalog identical to the one in Set-DefaultSearchEngine.ps1.
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

function Write-Banner {
    $timeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $hostName  = $env:COMPUTERNAME
    $timeZone  = try { (Get-TimeZone).Id } catch { 'Unknown' }
    $osInfo    = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $osCaption = if ($osInfo) { $osInfo.Caption } else { 'Unknown OS' }
    $osVersion = if ($osInfo) { $osInfo.Version } else { 'Unknown Version' }

    Write-Host "========================================"
    Write-Host " Script Execution Timestamp:  $timeStamp"
    Write-Host " Hostname:                    $hostName"
    Write-Host " TimeZone:                    $timeZone"
    Write-Host " OS Name:                     $osCaption"
    Write-Host " OS Version:                  $osVersion"
    Write-Host "========================================"
    Write-Host ""
}

function Get-DeviceManagementStatus {
    # Reports domain-join / Entra ID (Azure AD) join state, since Chrome and Edge
    # silently ignore the default search provider policy unless one of these is true.
    $status = [PSCustomObject]@{
        DomainJoined = $false
        AzureAdJoined = $false
        Managed = $false
    }

    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $status.DomainJoined = [bool]$cs.PartOfDomain
    } catch {
        Write-Host " WARNING: Could not determine domain join state - $($_.Exception.Message)"
    }

    try {
        $dsreg = & dsregcmd.exe /status 2>$null
        if ($dsreg -match 'AzureAdJoined\s*:\s*YES') {
            $status.AzureAdJoined = $true
        }
    } catch {
        Write-Host " WARNING: Could not determine Entra ID (Azure AD) join state - $($_.Exception.Message)"
    }

    $status.Managed = $status.DomainJoined -or $status.AzureAdJoined

    Write-Host "Checking device management state (affects whether Edge/Chrome will honor the policy)..."
    Write-Host " Domain-joined:            $($status.DomainJoined)"
    Write-Host " Entra ID (Azure AD) joined: $($status.AzureAdJoined)"
    if (-not $status.Managed) {
        Write-Host " NOTE: This device is neither domain-joined nor Entra ID joined. Chrome and Edge"
        Write-Host "       treat the default search provider as a protected policy and will silently"
        Write-Host "       ignore it on unmanaged/workgroup devices, even though the registry values"
        Write-Host "       are present and correct. MDM/Intune enrollment also satisfies this check."
    }
    Write-Host ""

    return $status
}

function Test-EdgeSearchEngine {
    param($Engine)

    $result = [PSCustomObject]@{ Installed = $false; Compliant = $true; Detail = @() }

    $edgePath    = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    $edgePathX64 = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    if (-not ((Test-Path $edgePath) -or (Test-Path $edgePathX64))) {
        Write-Host "Microsoft Edge not detected, skipping check."
        Write-Host ""
        return $result
    }
    $result.Installed = $true

    Write-Host "Checking Microsoft Edge default search engine..."
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    if (-not (Test-Path $regPath)) {
        $result.Compliant = $false
        $result.Detail += "Edge policy registry path not found ($regPath)."
        Write-Host "  ERROR: $($result.Detail[-1])"
        Write-Host ""
        return $result
    }

    $enabled = Get-ItemProperty -Path $regPath -Name 'DefaultSearchProviderEnabled' -ErrorAction SilentlyContinue
    $name    = Get-ItemProperty -Path $regPath -Name 'DefaultSearchProviderName' -ErrorAction SilentlyContinue
    $url     = Get-ItemProperty -Path $regPath -Name 'DefaultSearchProviderSearchURL' -ErrorAction SilentlyContinue

    Write-Host "  DefaultSearchProviderEnabled:   $($enabled.DefaultSearchProviderEnabled)"
    Write-Host "  DefaultSearchProviderName:      $($name.DefaultSearchProviderName)"
    Write-Host "  DefaultSearchProviderSearchURL: $($url.DefaultSearchProviderSearchURL)"

    if (-not $enabled -or $enabled.DefaultSearchProviderEnabled -ne 1) {
        $result.Compliant = $false
        $result.Detail += "Edge DefaultSearchProviderEnabled is not set to 1."
    }
    if (-not $name -or $name.DefaultSearchProviderName -ne $Engine.DisplayName) {
        $result.Compliant = $false
        $result.Detail += "Edge default search engine name is not '$($Engine.DisplayName)'."
    }
    if (-not $url -or $url.DefaultSearchProviderSearchURL -ne $Engine.SearchURL) {
        $result.Compliant = $false
        $result.Detail += "Edge default search engine URL is not '$($Engine.SearchURL)'."
    }

    Write-Host ""
    return $result
}

function Test-ChromeSearchEngine {
    param($Engine)

    $result = [PSCustomObject]@{ Installed = $false; Compliant = $true; Detail = @() }

    $chromePath    = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    $chromePathX64 = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
    if (-not ((Test-Path $chromePath) -or (Test-Path $chromePathX64))) {
        Write-Host "Google Chrome not detected, skipping check."
        Write-Host ""
        return $result
    }
    $result.Installed = $true

    Write-Host "Checking Google Chrome default search engine..."
    $regPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
    if (-not (Test-Path $regPath)) {
        $result.Compliant = $false
        $result.Detail += "Chrome policy registry path not found ($regPath)."
        Write-Host "  ERROR: $($result.Detail[-1])"
        Write-Host ""
        return $result
    }

    $enabled = Get-ItemProperty -Path $regPath -Name 'DefaultSearchProviderEnabled' -ErrorAction SilentlyContinue
    $name    = Get-ItemProperty -Path $regPath -Name 'DefaultSearchProviderName' -ErrorAction SilentlyContinue
    $url     = Get-ItemProperty -Path $regPath -Name 'DefaultSearchProviderSearchURL' -ErrorAction SilentlyContinue

    Write-Host "  DefaultSearchProviderEnabled:   $($enabled.DefaultSearchProviderEnabled)"
    Write-Host "  DefaultSearchProviderName:      $($name.DefaultSearchProviderName)"
    Write-Host "  DefaultSearchProviderSearchURL: $($url.DefaultSearchProviderSearchURL)"

    if (-not $enabled -or $enabled.DefaultSearchProviderEnabled -ne 1) {
        $result.Compliant = $false
        $result.Detail += "Chrome DefaultSearchProviderEnabled is not set to 1."
    }
    if (-not $name -or $name.DefaultSearchProviderName -ne $Engine.DisplayName) {
        $result.Compliant = $false
        $result.Detail += "Chrome default search engine name is not '$($Engine.DisplayName)'."
    }
    if (-not $url -or $url.DefaultSearchProviderSearchURL -ne $Engine.SearchURL) {
        $result.Compliant = $false
        $result.Detail += "Chrome default search engine URL is not '$($Engine.SearchURL)'."
    }

    Write-Host ""
    return $result
}

function Test-FirefoxSearchEngine {
    param($Engine)

    $result = [PSCustomObject]@{ Installed = $false; Compliant = $true; Detail = @() }

    $firefoxPath    = "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"
    $firefoxPathX64 = "$env:ProgramFiles\Mozilla Firefox\firefox.exe"
    if (-not ((Test-Path $firefoxPath) -or (Test-Path $firefoxPathX64))) {
        Write-Host "Mozilla Firefox not detected, skipping check."
        Write-Host ""
        return $result
    }
    $result.Installed = $true

    Write-Host "Checking Mozilla Firefox default search engine..."
    $regPath = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\SearchEngines"
    if (-not (Test-Path $regPath)) {
        $result.Compliant = $false
        $result.Detail += "Firefox SearchEngines policy not found ($regPath)."
        Write-Host "  ERROR: $($result.Detail[-1])"
        Write-Host ""
        return $result
    }

    $default = Get-ItemProperty -Path $regPath -Name 'Default' -ErrorAction SilentlyContinue
    Write-Host "  SearchEngines\Default: $($default.Default)"

    if (-not $default -or $default.Default -ne $Engine.FirefoxName) {
        $result.Compliant = $false
        $result.Detail += "Firefox default search engine is not '$($Engine.FirefoxName)'."
    }

    if ($Engine.FirefoxNeedsAdd) {
        $addPath = Join-Path $regPath 'Add\1'
        if (-not (Test-Path $addPath)) {
            $result.Compliant = $false
            $result.Detail += "Firefox custom engine '$($Engine.FirefoxName)' has not been added via policy."
        } else {
            $addName = Get-ItemProperty -Path $addPath -Name 'Name' -ErrorAction SilentlyContinue
            $addUrl  = Get-ItemProperty -Path $addPath -Name 'URLTemplate' -ErrorAction SilentlyContinue
            Write-Host "  SearchEngines\Add\1\Name:        $($addName.Name)"
            Write-Host "  SearchEngines\Add\1\URLTemplate: $($addUrl.URLTemplate)"
            if (-not $addName -or $addName.Name -ne $Engine.FirefoxName -or
                -not $addUrl -or $addUrl.URLTemplate -ne $Engine.SearchURL) {
                $result.Compliant = $false
                $result.Detail += "Firefox custom engine '$($Engine.FirefoxName)' definition does not match the expected URL."
            }
        }
    }

    Write-Host ""
    return $result
}

# --- MAIN SCRIPT EXECUTION ---

Write-Banner

if (-not $SearchEngineCatalog.ContainsKey($DesiredEngine)) {
    Write-Host "ERROR: Unsupported DesiredEngine value '$DesiredEngine'."
    Write-Host " - Supported values: $($SearchEngineCatalog.Keys -join ', ')"
    Write-Host "========================================"
    Write-Host "Script completed with exit code: 5"
    Write-Host "========================================"
    exit 5
}

$engine = $SearchEngineCatalog[$DesiredEngine]
Write-Host "Desired default search engine: $($engine.DisplayName)"
Write-Host ""

try {
    $managementStatus = Get-DeviceManagementStatus
    $edgeResult    = Test-EdgeSearchEngine -Engine $engine
    $chromeResult  = Test-ChromeSearchEngine -Engine $engine
    $firefoxResult = Test-FirefoxSearchEngine -Engine $engine
} catch {
    Write-Host "ERROR: System error while checking browser configuration - $($_.Exception.Message)"
    Write-Host "========================================"
    Write-Host "Script completed with exit code: 5"
    Write-Host "========================================"
    exit 5
}

$nonCompliant = @()
if ($edgeResult.Installed -and -not $edgeResult.Compliant) { $nonCompliant += 'Edge' }
if ($chromeResult.Installed -and -not $chromeResult.Compliant) { $nonCompliant += 'Chrome' }
if ($firefoxResult.Installed -and -not $firefoxResult.Compliant) { $nonCompliant += 'Firefox' }

if ($nonCompliant.Count -eq 0) {
    $ErrorCode = 0
    Write-Host "SUCCESS: Default search engine is enforced to '$($engine.DisplayName)' on all installed browsers."
    if (-not $edgeResult.Installed -and -not $chromeResult.Installed -and -not $firefoxResult.Installed) {
        Write-Host " - No supported browsers detected on this system."
    }
} elseif ($nonCompliant.Count -gt 1) {
    $ErrorCode = 4
    Write-Host "ERROR: Multiple browsers are not enforcing '$($engine.DisplayName)' as the default search engine: $($nonCompliant -join ', ')"
    if (-not $managementStatus.Managed) {
        Write-Host " - This device is unmanaged (not domain/Entra ID joined); see note above re: Edge/Chrome."
    }
} elseif ($nonCompliant -contains 'Edge') {
    $ErrorCode = 1
    Write-Host "ERROR: Microsoft Edge is not enforcing '$($engine.DisplayName)' as the default search engine."
    $edgeResult.Detail | ForEach-Object { Write-Host " - $_" }
    if (-not $managementStatus.Managed) {
        Write-Host " - This device is unmanaged (not domain/Entra ID joined); Edge may be silently ignoring the policy."
    }
} elseif ($nonCompliant -contains 'Chrome') {
    $ErrorCode = 2
    Write-Host "ERROR: Google Chrome is not enforcing '$($engine.DisplayName)' as the default search engine."
    $chromeResult.Detail | ForEach-Object { Write-Host " - $_" }
    if (-not $managementStatus.Managed) {
        Write-Host " - This device is unmanaged (not domain/Entra ID joined); Chrome may be silently ignoring the policy."
    }
} else {
    $ErrorCode = 3
    Write-Host "ERROR: Mozilla Firefox is not enforcing '$($engine.DisplayName)' as the default search engine."
    $firefoxResult.Detail | ForEach-Object { Write-Host " - $_" }
}

Write-Host "========================================"
Write-Host "Script completed with exit code: $ErrorCode"
Write-Host "========================================"

exit $ErrorCode
