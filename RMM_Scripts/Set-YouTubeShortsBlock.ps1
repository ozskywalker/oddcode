<#
.SYNOPSIS
  Enforces a URLBlocklist policy on Microsoft Edge and Google Chrome to block YouTube
  Shorts.

.DESCRIPTION
  Adds the YouTube Shorts URL patterns to the HKLM Policies URLBlocklist for every
  installed, policy-capable browser (Edge, Chrome). Existing, unrelated URLBlocklist
  entries (e.g. ones you've added for other sites) are preserved - this script only adds
  the Shorts patterns if they're missing, using the next free numbered value; it never
  clears or rewrites the whole list. Each write is verified by reading the policy back
  immediately after setting it. Browsers that are not installed are skipped.

  Opera Stable and Opera GX are detected (best-effort) and reported, but nothing is
  written for them: Opera does not support Chrome's enterprise policy engine at all, so
  there is no registry key this script could set that Opera would honor.

.NOTES
  - Must run elevated (as Administrator, or as SYSTEM via an RMM agent/component). All
    registry writes target HKLM (machine-wide browser policy), never HKCU, so there is no
    per-user vs. per-machine conflict - running as SYSTEM is fine and is how most RMM
    platforms (including Level.io) execute scripts/components by default. Running as a
    regular, non-elevated user will fail with a SecurityException on every
    Set-ItemProperty call under HKLM.
  - Applicable to Windows 10 / Windows 11 / Windows Server.
  - Users must restart their browser(s) for the change to take effect.
  - REAL LIMITATION - verify on your own Edge/Chrome version before relying on this: the
    URLBlocklist policy is enforced by a navigation throttle that only fires on top-level/
    renderer-initiated navigations - typed URLs, bookmarks, external links, new tabs, and
    page refreshes. YouTube is a single-page app and opens most in-feed Shorts (home feed
    shelf, sidebar, autoplay-next) via history.pushState, which does not go through that
    throttle: the address bar updates and the Short plays with no block screen. Refreshing
    that same tab afterwards WILL then be blocked. In practice this reliably stops direct/
    typed/bookmarked/externally-linked Shorts URLs, but is not a complete stop for a kid
    already inside an open youtube.com tab who taps into the in-feed Shorts shelf.
  - IMPORTANT: Opera (Stable) and Opera GX cannot be enforced this way - see the companion
    Get-YouTubeShortsBlockStatus.ps1 header for the full explanation and options if that
    gap matters to you.
  - Exit codes:
    0 = Blocklist successfully enforced (and verified) on all installed, policy-capable
        browsers (Edge/Chrome). Check output for an Opera detection note.
    1 = Script is not running elevated (Administrator/SYSTEM required for HKLM writes)
    2 = One or more browsers failed to configure
#>

Set-StrictMode -Version Latest

# Keep this list identical to the one in Get-YouTubeShortsBlockStatus.ps1.
$ShortsBlockPatterns = @(
    'youtube.com/shorts',
    'm.youtube.com/shorts'
)

function Test-IsElevated {
    # HKLM writes (used for every browser policy in this script) require an elevated
    # process - either an interactive Administrator session, or SYSTEM (the context most
    # RMM agents/components run scripts under, including Level.io by default).
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
    Write-Host " YouTube Shorts Block Enforcement"
    Write-Host " Date/Time: $timeStamp"
    Write-Host " Hostname:  $hostName"
    Write-Host " TimeZone:  $timeZone"
    Write-Host " OS:        $osCaption ($osVersion)"
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

function Add-ChromiumPolicyListValues {
    # Adds any of $RequiredValues that aren't already present under a Chromium "list"
    # policy subkey, using the next free numeric value name. Never touches existing
    # entries, so unrelated blocklist entries the admin added some other way survive.
    param(
        [string]$PolicyRegPath,
        [string[]]$RequiredValues
    )

    if (-not (Test-Path $PolicyRegPath)) {
        New-Item -Path $PolicyRegPath -Force | Out-Null
    }

    $existing = Get-ChromiumPolicyListValues -PolicyRegPath $PolicyRegPath
    $item = Get-Item -Path $PolicyRegPath
    $usedIndexes = $item.Property | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
    $nextIndex = if ($usedIndexes) { ($usedIndexes | Measure-Object -Maximum).Maximum + 1 } else { 1 }

    foreach ($val in $RequiredValues) {
        if ($existing -notcontains $val) {
            Set-ItemProperty -Path $PolicyRegPath -Name "$nextIndex" -Value $val -Type String
            Write-Host "  Added URLBlocklist[$nextIndex] = '$val'"
            $nextIndex++
        } else {
            Write-Host "  '$val' already present in URLBlocklist."
        }
    }
}

function Set-EdgeShortsBlock {
    $edgePath    = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    $edgePathX64 = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    if (-not ((Test-Path $edgePath) -or (Test-Path $edgePathX64))) {
        Write-Host "Microsoft Edge not detected, skipping."
        return 'Skipped'
    }

    Write-Host "Configuring Microsoft Edge to block YouTube Shorts..."
    try {
        $blocklistPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\URLBlocklist'
        Add-ChromiumPolicyListValues -PolicyRegPath $blocklistPath -RequiredValues $ShortsBlockPatterns

        $verify = Get-ChromiumPolicyListValues -PolicyRegPath $blocklistPath
        $missing = $ShortsBlockPatterns | Where-Object { $verify -notcontains $_ }
        if ($missing) {
            Write-Host "  ERROR: Verification failed - still missing: $($missing -join ', ')"
            return 'Failed'
        }

        Write-Host "  Edge configured and verified successfully."
        return 'Success'
    } catch {
        Write-Host "  ERROR: Failed to configure Edge - $($_.Exception.Message)"
        return 'Failed'
    }
}

function Set-ChromeShortsBlock {
    $chromePath    = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    $chromePathX64 = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
    if (-not ((Test-Path $chromePath) -or (Test-Path $chromePathX64))) {
        Write-Host "Google Chrome not detected, skipping."
        return 'Skipped'
    }

    Write-Host "Configuring Google Chrome to block YouTube Shorts..."
    try {
        $blocklistPath = 'HKLM:\SOFTWARE\Policies\Google\Chrome\URLBlocklist'
        Add-ChromiumPolicyListValues -PolicyRegPath $blocklistPath -RequiredValues $ShortsBlockPatterns

        $verify = Get-ChromiumPolicyListValues -PolicyRegPath $blocklistPath
        $missing = $ShortsBlockPatterns | Where-Object { $verify -notcontains $_ }
        if ($missing) {
            Write-Host "  ERROR: Verification failed - still missing: $($missing -join ', ')"
            return 'Failed'
        }

        Write-Host "  Chrome configured and verified successfully."
        return 'Success'
    } catch {
        Write-Host "  ERROR: Failed to configure Chrome - $($_.Exception.Message)"
        return 'Failed'
    }
}

function Test-OperaPresence {
    # Best-effort presence check for Opera/Opera GX. Opera has no policy engine to write
    # to, so all this can do is tell you whether the unenforceable browser is there.
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

if (-not (Test-IsElevated)) {
    Write-Host "ERROR: This script must run elevated (as Administrator or as SYSTEM)."
    Write-Host " - All registry writes target HKLM, which requires an elevated process."
    Write-Host " - If running manually, re-launch PowerShell with 'Run as Administrator'."
    Write-Host " - If running via an RMM agent (Level.io, Datto RMM, etc.), this is normally"
    Write-Host "   satisfied automatically since scripts/components execute as SYSTEM."
    Write-Host "========================================"
    Write-Host "Script completed with exit code: 1"
    Write-Host "========================================"
    exit 1
}

$results = [ordered]@{
    Edge   = Set-EdgeShortsBlock
    Chrome = Set-ChromeShortsBlock
}

Write-Host ""
$operaStable = Test-OperaPresence -FolderName 'Opera'
$operaGx     = Test-OperaPresence -FolderName 'Opera GX'
$operaDetected = @()
if ($operaStable) { $operaDetected += 'Opera Stable' }
if ($operaGx) { $operaDetected += 'Opera GX' }
if ($operaDetected.Count -gt 0) {
    Write-Host "NOTE: $($operaDetected -join ' and ') detected but NOT configured - Opera does not"
    Write-Host "      support registry/group policy of any kind, so there is nothing to write."
    Write-Host "      YouTube Shorts remain fully accessible there regardless of this script."
    Write-Host ""
}

$failed = $results.GetEnumerator() | Where-Object { $_.Value -eq 'Failed' }

if ($failed) {
    $failedNames = $failed | ForEach-Object { $_.Key }
    Write-Host "ERROR: Failed to block YouTube Shorts on: $($failedNames -join ', ')"
    $results.GetEnumerator() | ForEach-Object { Write-Host " - $($_.Key): $($_.Value)" }
    $ErrorCode = 2
} else {
    Write-Host "SUCCESS: YouTube Shorts blocklist enforced on all installed, policy-capable browsers."
    $results.GetEnumerator() | ForEach-Object { Write-Host " - $($_.Key): $($_.Value)" }
    Write-Host ""
    Write-Host "Note: Users must restart their browser(s) for the change to take effect."
    Write-Host "Note: See this script's header comments for a real caveat around in-app SPA navigation"
    Write-Host "      (in-feed Shorts clicked from within an already-open youtube.com tab)."
    $ErrorCode = 0
}

Write-Host "========================================"
Write-Host "Script completed with exit code: $ErrorCode"
Write-Host "========================================"

exit $ErrorCode
