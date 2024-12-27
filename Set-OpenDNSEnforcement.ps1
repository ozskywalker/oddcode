<#
.SYNOPSIS
  Remediation script to enforce OpenDNS, disable IPv6 DNS, disable DoH,
  and comment out YouTube hosts entries.

.DESCRIPTION
  1. Sets all active (non-Bluetooth, non-Loopback) adapters to use OpenDNS (208.67.222.222, 208.67.220.220).
  2. Removes any configured IPv6 DNS servers.
  3. Disables DNS-over-HTTPS by removing DoH server entries (if supported).
  4. Comments out YouTube-related lines in the hosts file, leaving a timestamp comment.

.NOTES
  - Run as Administrator.
  - Applicable to Windows 10 / Windows 11.
  - May require a reboot or network reset in some edge cases for changes to fully apply.
#>

Set-StrictMode -Version Latest

function Get-ValidNetAdapters {
    # Retrieves all active, physical (non-Bluetooth, non-Loopback) adapters, 
    # excluding Tailscale, excluding vEthernet with no IPv4/IPv6 gateway.
    Get-NetAdapter -Physical | Where-Object {
        $_.Status -eq 'Up' -and
        $_.InterfaceDescription -notmatch 'Bluetooth' -and
        $_.InterfaceDescription -notmatch 'Loopback' -and
        $_.InterfaceDescription -notmatch 'Tailscale'
    } | ForEach-Object {
        if ($_.InterfaceDescription -match 'vEthernet') {
            $netIPConf = Get-NetIPConfiguration -InterfaceAlias $_.Name
            if (($netIPConf.IPv4DefaultGateway -and $netIPConf.IPv4DefaultGateway.Count -gt 0) -or
                ($netIPConf.IPv6DefaultGateway -and $netIPConf.IPv6DefaultGateway.Count -gt 0)) {
                $_
            }
        }
        else {
            $_
        }
    }
}

function Set-OpenDNS {
    Write-Host "Forcing DNS servers to OpenDNS for valid adapters..."

    $adapters = Get-ValidNetAdapters
    foreach ($adapter in $adapters) {
        $alias = $adapter.Name
        Write-Host "  Setting DNS for '$alias' to 208.67.222.222 and 208.67.220.220"
        Set-DnsClientServerAddress -InterfaceAlias $alias -ServerAddresses @('208.67.222.222','208.67.220.220') -ErrorAction SilentlyContinue
    }
}

function Disable-IPv6DNS {
    Write-Host "Disabling IPv6 DNS for valid adapters..."

    $adapters = Get-ValidNetAdapters
    foreach ($adapter in $adapters) {
        $alias = $adapter.Name
        Write-Host "  Clearing IPv6 DNS for '$alias'"
        # Set IPv6 DNS servers to empty array to disable
        Set-DnsClientServerAddress -InterfaceAlias $alias -ServerAddresses @() -ErrorAction SilentlyContinue
    }
}

function Disable-DoH {
    Write-Host "Disabling DNS-over-HTTPS (DoH)..."
    try {
        # This cmdlet is available on newer Windows 10 and Windows 11 builds
        $dohServers = Get-DnsClientDohServerAddress -ErrorAction Stop
        if ($dohServers) {
            foreach ($doh in $dohServers) {
                Write-Host "  Removing DoH server: $($doh.ServerAddress)"
                Remove-DnsClientDohServerAddress -ServerAddress $doh.ServerAddress -ErrorAction SilentlyContinue
            }
        }
        else {
            Write-Host "  No DoH servers configured."
        }
    }
    catch {
        Write-Host "  DNS-over-HTTPS check not supported or cmdlet not found on this system."
        Write-Host "  (Skipping DoH removal step.)"
    }
}

function Revoke-YouTubeEntriesInHostsFile {
    Write-Host "Commenting out YouTube entries in hosts file..."

    $hostsPath = 'C:\Windows\System32\drivers\etc\hosts'
    if (-not (Test-Path $hostsPath)) {
        Write-Host "  Hosts file not found at $hostsPath. Skipping."
        return
    }

    $hostsContent = Get-Content -Path $hostsPath -ErrorAction SilentlyContinue
    if (-not $hostsContent) {
        Write-Host "  Hosts file is empty or unreadable. Skipping."
        return
    }

    # Domains to look for:
    $youtubeDomains = @(
        'youtube.com',
        'youtu.be',
        'googlevideo.com'
    )

    $dateStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $modifiedContent = foreach ($line in $hostsContent) {
        $trimmed = $line.Trim()
        # Check if line is non-empty, not already commented, and references any youtube domain
        if (
            $trimmed -and 
            $trimmed -notlike '#*' -and
            ($youtubeDomains | ForEach-Object { if ($trimmed -match $_) { return $true } }) -eq $true
        ) {
            "# $line # Commented out on $dateStamp by remediation script"
        }
        else {
            $line
        }
    }

    # If we modified the hosts file, re-write it
    if ($modifiedContent -ne $hostsContent) {
        try {
            Set-Content -Path $hostsPath -Value $modifiedContent
            Write-Host "  Updated hosts file with commented YouTube entries."
        }
        catch {
            Write-Host "  ERROR: Failed to write to hosts file: $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "  No YouTube entries found to comment out."
    }
}

Write-Host "========================================"
Write-Host "  Remediation Script Starting"
Write-Host "  Date/Time: $(Get-Date)"
Write-Host "========================================`n"

Set-OpenDNS
Disable-IPv6DNS
Disable-DoH
Revoke-YouTubeEntriesInHostsFile

Write-Host "`nDone. Remediation actions completed."
exit 0
