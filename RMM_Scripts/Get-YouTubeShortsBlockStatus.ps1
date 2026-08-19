<#
.SYNOPSIS
  Checks whether Microsoft Edge and Google Chrome are enforcing a URLBlocklist policy
  that blocks YouTube Shorts, and flags any installed browser that cannot be enforced
  this way at all (Opera Stable, Opera GX).

.DESCRIPTION
  This script is intended for use with RMM solutions (Level.io, Datto RMM, etc.) as a monitor.
  - If Shorts are blocked on every installed, policy-capable browser (Edge/Chrome) and no
    unenforceable browser (Opera/Opera GX) is present, it returns "SUCCESS:" and exit code 0.
  - If an installed Edge/Chrome is not blocking Shorts, it returns "ERROR:" and a non-zero
    exit code.
  - If Opera Stable or Opera GX is installed, it is reported as a compliance gap (exit code 4)
    even when Edge/Chrome are fully compliant, because nothing can be done about it via
    registry policy. See .NOTES.
  - Browsers that are not installed are skipped and do not affect the result.

.NOTES
  - Compatible with Windows 10, Windows 11, and Windows Server.
  - Checks the same HKLM Policies registry values that Set-YouTubeShortsBlock.ps1 writes.
  - REAL LIMITATION - verify on your own Edge/Chrome version before relying on this: the
    URLBlocklist policy is enforced by a navigation throttle that only fires on top-level/
    renderer-initiated navigations - typed URLs, bookmarks, external links, new tabs, and
    page refreshes. YouTube is a single-page app and opens most in-feed Shorts (home feed
    shelf, sidebar, autoplay-next) via history.pushState, which does not go through that
    throttle: the address bar updates and the Short plays with no block screen. Refreshing
    that same tab afterwards WILL then be blocked. In practice this reliably stops direct/
    typed/bookmarked/externally-linked Shorts URLs, but is not a complete stop for a kid
    already inside an open youtube.com tab who taps into the in-feed Shorts shelf. Your
    existing NextDNS time allocation still applies regardless of this gap. A force-installed
    content-blocking extension (ExtensionInstallForcelist policy) is the next escalation if
    this gap matters to you, but is out of scope for this script.
  - IMPORTANT: Opera (Stable) and Opera GX are Chromium-based, but Opera Software has not
    implemented Chrome's enterprise policy engine at all - confirmed via Opera's own
    community forums (no ADMX, no HKLM\SOFTWARE\Policies\... support of any kind, for any
    policy, not just URLBlocklist). There is no registry key this script - or any
    registry-based tool - can set that Opera will honor. If that gap matters to you, the
    realistic options are: block/remove Opera and Opera GX entirely (e.g. Software
    Restriction Policies/AppLocker) so they can't be used as a Shorts loophole, or accept
    the gap since your NextDNS restrictions still apply system-wide to Opera (just not the
    Shorts-specific URL block).
  - Detection of Opera/Opera GX is a best-effort folder-existence check: Program Files (for
    machine-wide/enterprise installs) plus every C:\Users\<profile>\AppData\Local\Programs\
    Opera[ GX] (for the default per-user install), since this script commonly runs as
    SYSTEM, whose own profile would never see a per-user install.
  - Exit codes:
    0 = All installed, policy-capable browsers (Edge/Chrome) are blocking Shorts, and no
        unenforceable browser (Opera/Opera GX) was detected
    1 = Microsoft Edge is not blocking Shorts
    2 = Google Chrome is not blocking Shorts
    3 = Multiple browsers (Edge and Chrome) are not blocking Shorts
    4 = Edge/Chrome are compliant (or not installed), but Opera Stable and/or Opera GX is
        installed and cannot be enforced via registry policy
    5 = System error
#>

Set-StrictMode -Version Latest

# YouTube Shorts URL patterns required in each browser's URLBlocklist policy.
# Filter format: [scheme://][.]host[:port][/path] - a bare host (no leading dot) matches
# that host and all its subdomains, so 'youtube.com/shorts' should already cover the
# www./m. subdomains; both are listed explicitly anyway as defense in depth.
# Keep this list identical to the one in Set-YouTubeShortsBlock.ps1.
$ShortsBlockPatterns = @(
    'youtube.com/shorts',
    'm.youtube.com/shorts'
)

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

function Get-ChromiumPolicyListValues {
    # Reads all values under a Chromium "list" policy subkey (e.g. ...\URLBlocklist),
    # regardless of the numeric names (1, 2, 3, ...) they are stored under.
    param([string]$PolicyRegPath)

    $values = @()
    if (Test-Path $PolicyRegPath) {
        $item = Get-Item -Path $PolicyRegPath
        foreach ($valueName in $item.Property) {
            $values += Get-ItemPropertyValue -Path $PolicyRegPath -Name $valueName -ErrorAction SilentlyContinue
        }
    }
    return $values
}

function Test-EdgeShortsBlock {
    $result = [PSCustomObject]@{ Installed = $false; Compliant = $true; Detail = @() }

    $edgePath    = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    $edgePathX64 = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    if (-not ((Test-Path $edgePath) -or (Test-Path $edgePathX64))) {
        Write-Host "Microsoft Edge not detected, skipping check."
        Write-Host ""
        return $result
    }
    $result.Installed = $true

    Write-Host "Checking Microsoft Edge YouTube Shorts block..."
    $blocklistPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\URLBlocklist'
    $existingValues = Get-ChromiumPolicyListValues -PolicyRegPath $blocklistPath

    if ($existingValues.Count -gt 0) {
        Write-Host "  Existing URLBlocklist entries: $($existingValues -join ', ')"
    } else {
        Write-Host "  URLBlocklist policy not configured."
    }

    foreach ($pattern in $ShortsBlockPatterns) {
        if ($existingValues -notcontains $pattern) {
            $result.Compliant = $false
            $result.Detail += "Edge URLBlocklist is missing '$pattern'."
        }
    }

    Write-Host ""
    return $result
}

function Test-ChromeShortsBlock {
    $result = [PSCustomObject]@{ Installed = $false; Compliant = $true; Detail = @() }

    $chromePath    = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    $chromePathX64 = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
    if (-not ((Test-Path $chromePath) -or (Test-Path $chromePathX64))) {
        Write-Host "Google Chrome not detected, skipping check."
        Write-Host ""
        return $result
    }
    $result.Installed = $true

    Write-Host "Checking Google Chrome YouTube Shorts block..."
    $blocklistPath = 'HKLM:\SOFTWARE\Policies\Google\Chrome\URLBlocklist'
    $existingValues = Get-ChromiumPolicyListValues -PolicyRegPath $blocklistPath

    if ($existingValues.Count -gt 0) {
        Write-Host "  Existing URLBlocklist entries: $($existingValues -join ', ')"
    } else {
        Write-Host "  URLBlocklist policy not configured."
    }

    foreach ($pattern in $ShortsBlockPatterns) {
        if ($existingValues -notcontains $pattern) {
            $result.Compliant = $false
            $result.Detail += "Chrome URLBlocklist is missing '$pattern'."
        }
    }

    Write-Host ""
    return $result
}

function Test-OperaPresence {
    # Best-effort presence check for Opera/Opera GX. Opera has no policy engine to check
    # instead, so all this can do is tell you whether the unenforceable browser is there.
    param([string]$FolderName)  # 'Opera' or 'Opera GX'

    $machinePaths = @(
        "$env:ProgramFiles\$FolderName",
        "${env:ProgramFiles(x86)}\$FolderName"
    )
    foreach ($p in $machinePaths) {
        if (Test-Path $p) { return $true }
    }

    $usersRoot = "$env:SystemDrive\Users"
    if (Test-Path $usersRoot) {
        $profileDirs = Get-ChildItem -Path $usersRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') }
        foreach ($profileDir in $profileDirs) {
            $perUserPath = Join-Path $profileDir.FullName "AppData\Local\Programs\$FolderName"
            if (Test-Path $perUserPath) { return $true }
        }
    }

    return $false
}

# --- MAIN SCRIPT EXECUTION ---

Write-Banner

try {
    $edgeResult   = Test-EdgeShortsBlock
    $chromeResult = Test-ChromeShortsBlock

    Write-Host "Checking for browsers that cannot be enforced via registry policy..."
    $operaStable = Test-OperaPresence -FolderName 'Opera'
    $operaGx     = Test-OperaPresence -FolderName 'Opera GX'
    if ($operaStable) { Write-Host "  Opera Stable detected." }
    if ($operaGx)     { Write-Host "  Opera GX detected." }
    if (-not $operaStable -and -not $operaGx) { Write-Host "  None detected." }
    Write-Host ""
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

$operaDetected = @()
if ($operaStable) { $operaDetected += 'Opera Stable' }
if ($operaGx) { $operaDetected += 'Opera GX' }

if ($operaDetected.Count -gt 0) {
    Write-Host "NOTE: $($operaDetected -join ' and ') installed on this device and CANNOT be enforced"
    Write-Host "      via registry/group policy - Opera has not implemented Chrome's policy engine."
    Write-Host "      YouTube Shorts remain fully accessible in $($operaDetected -join '/') regardless"
    Write-Host "      of this script's result. See .NOTES in this script for background and options."
    Write-Host ""
}

if ($nonCompliant.Count -eq 0 -and $operaDetected.Count -eq 0) {
    $ErrorCode = 0
    Write-Host "SUCCESS: YouTube Shorts are blocked on all installed, policy-capable browsers."
    if (-not $edgeResult.Installed -and -not $chromeResult.Installed) {
        Write-Host " - No policy-capable browsers (Edge/Chrome) detected on this system."
    }
} elseif ($nonCompliant.Count -gt 1) {
    $ErrorCode = 3
    Write-Host "ERROR: Multiple browsers are not blocking YouTube Shorts: $($nonCompliant -join ', ')"
    $edgeResult.Detail | ForEach-Object { Write-Host " - $_" }
    $chromeResult.Detail | ForEach-Object { Write-Host " - $_" }
} elseif ($nonCompliant -contains 'Edge') {
    $ErrorCode = 1
    Write-Host "ERROR: Microsoft Edge is not blocking YouTube Shorts."
    $edgeResult.Detail | ForEach-Object { Write-Host " - $_" }
} elseif ($nonCompliant -contains 'Chrome') {
    $ErrorCode = 2
    Write-Host "ERROR: Google Chrome is not blocking YouTube Shorts."
    $chromeResult.Detail | ForEach-Object { Write-Host " - $_" }
} else {
    # Edge/Chrome are compliant (or not installed) - the only remaining gap is Opera.
    $ErrorCode = 4
    Write-Host "ERROR: Opera browser(s) present that cannot be enforced (see NOTE above)."
}

Write-Host "========================================"
Write-Host "Script completed with exit code: $ErrorCode"
Write-Host "========================================"

exit $ErrorCode
