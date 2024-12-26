<#
.SYNOPSIS
  Checks that system DNS is configured to use only OpenDNS for IPv4, that no IPv6 DNS is in use, 
  that DNS-over-HTTPS is not configured, and that YouTube is not set in HOSTS file.
  
.DESCRIPTION
  This script is intended for use with RMM solutions (Action1, Level, etc.) as a monitor.
  - If everything is OK, it returns exit code 0.
  - If there are issues, it returns a non-zero exit code.
  
.NOTES
  - Ignores adapters with "Bluetooth" or "Loopback" in their names.
  - Compatible with Windows 10 and newer.
#>

Set-StrictMode -Version Latest

# Specify allowed OpenDNS IPv4 servers:
$AllowedDNSv4 = @('208.67.222.222','208.67.220.220')

# Initialize error code
$ErrorCode = 0

function Write-Banner {
    $timeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $hostName  = $env:COMPUTERNAME
    $timeZone  = (Get-TimeZone).Id
    $osInfo    = Get-CimInstance Win32_OperatingSystem
    $osCaption = $osInfo.Caption
    $osVersion = $osInfo.Version

    Write-Host "========================================"
    Write-Host " Script Execution Timestamp:  $timeStamp"
    Write-Host " Hostname:                    $hostName"
    Write-Host " TimeZone:                    $timeZone"
    Write-Host " OS Name:                     $osCaption"
    Write-Host " OS Version:                  $osVersion"
    Write-Host "========================================"
    Write-Host ""
}

function Test-OnlyOpenDNSUsedForIPv4 {
    $result = $false
    Write-Host "Checking IPv4 DNS servers..."

    # Retrieve the IPv4 DNS servers from all active network adapters, 
    # Ignoring Bluetooth/Loopback/vEthernet/Tailscale adapters
    # & ignoring Hyper-V adapters with no default gateway
    $allIPv4Configs = Get-NetIPConfiguration |
        Where-Object {
            $null -ne $_.IPv4Address -and
            $null -ne $_.DNSServer -and
            $_.InterfaceAlias -notmatch 'Bluetooth' -and
            $_.InterfaceAlias -notmatch 'Loopback' -and
            $_.InterfaceAlias -notmatch 'Tailscale' -and
            -not (
                # Skip if interface alias starts with "vEthernet"
                # AND has no IPv4 default gateway
                ($_.InterfaceAlias -like 'vEthernet*') -and (
                    $null -eq $_.IPv4DefaultGateway -or
                    $_.IPv4DefaultGateway.Count -eq 0
                )
            )
        }

    if (-not $allIPv4Configs) {
        Write-Host "No active IPv4 configurations found (or only Bluetooth/Loopback/vEthernet/Tailscale)."
        Write-Host "This is unusual if you are expecting a standard network interface."
        Write-Host ""
        $result = $true
        return $result
    }

    foreach ($config in $allIPv4Configs) {
        # Filter out only valid IPv4 addresses in the DNS server list
        $dnsServers = $config.DnsServer.ServerAddresses | Where-Object {
            # Attempt to parse as IP, then check if AddressFamily is InterNetwork (IPv4)
            $parsed = $null
            if ([System.Net.IPAddress]::TryParse($_, [ref] $parsed)) {
                $parsed.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork
            }
        }

        Write-Host " Adapter Index: $($config.InterfaceIndex) (Alias: $($config.InterfaceAlias))"
        Write-Host " IPv4 DNS Servers:   $($dnsServers -join ', ')"

        # Check if every DNS server in this adapter is in the allowed list
        foreach ($server in $dnsServers) {
            if ($AllowedDNSv4 -notcontains $server) {
                Write-Host "  ERROR: IPv4 DNS server $server is not in the allowed list."
                $result = $true
            }
        }

        # Also check if the adapter is missing any required OpenDNS servers
        foreach ($allowed in $AllowedDNSv4) {
            if ($dnsServers -notcontains $allowed) {
                Write-Host "  ERROR: Missing OpenDNS server $allowed on adapter index $($config.InterfaceIndex)."
                $result = $true
            }
        }
    }
    Write-Host ""
    return $result
}


function Test-OnlyOpenDNSUsedForIPv6 {
    $result = $false
    Write-Host "Checking IPv6 DNS servers..."

    # Retrieve the IPv6 DNS servers from all active adapters (no AddressFamily param). 
    # Ignoring Bluetooth/Loopback/vEthernet/Tailscale adapters
    # & ignoring Hyper-V adapters with no default gateway
    $allIPv6Configs = Get-NetIPConfiguration |
        Where-Object {
            $null -ne $_.IPv6Address -and
            $null -ne $_.DnsServer -and
            $_.InterfaceAlias -notmatch 'Bluetooth' -and
            $_.InterfaceAlias -notmatch 'Loopback' -and
            $_.InterfaceAlias -notmatch 'Tailscale' -and
            -not (
                ($_.InterfaceAlias -like 'vEthernet*') -and (
                    $null -eq $_.IPv6DefaultGateway -or
                    $_.IPv6DefaultGateway.Count -eq 0
                )
            )
        }

    if ($allIPv6Configs) {
        foreach ($config in $allIPv6Configs) {
            $dnsServers = $config.DnsServer.ServerAddresses
            Write-Host " Adapter Index: $($config.InterfaceIndex) (Alias: $($config.InterfaceAlias))"
            Write-Host " IPv6 DNS Servers:   $($dnsServers -join ', ')"

            # If we find any addresses that are NOT fe80:: or fec0:0:0:ffff::, fail
            foreach ($server in $dnsServers) {
                # Adjusted to ignore fec0:0:0:ffff:: as well
                if (
                    $server -notmatch '^fe80::' -and
                    $server -notmatch '^fec0:0:0:ffff::'
                ) {
                    Write-Host " ERROR: Non link-local IPv6 DNS server found ($server). IPv6 DNS not allowed."
                    $result = $true
                }
            }
        }
    }
    else {
        Write-Host "No non-link-local IPv6 DNS servers found."
    }
    Write-Host ""
    return $result
}

function Test-DoHNotInUse {
    $result = $false
    Write-Host "Checking DNS-over-HTTPS configuration..."

    # The cmdlet Get-DnsClientDohServerAddress is only available on newer builds.
    # We'll try/catch to handle older versions gracefully.
    try {
        $dohServers = Get-DnsClientDohServerAddress -ErrorAction Stop
        if ($dohServers) {
            # If any DoH servers are configured
            Write-Host " ERROR: DNS-over-HTTPS servers are configured, which may bypass OpenDNS."
            $result = $true
        }
        else {
            Write-Host " No DNS-over-HTTPS servers configured."
        }
    }
    catch {
        Write-Host " DNS-over-HTTPS check not supported on this OS version or command not found."
        Write-Host " (Skipping DoH check.)"
    }
    Write-Host ""
    return $result
}

function Test-YouTubeHostsBypass {
    Write-Host " ...checking HOSTS file for YouTube bypass"
    $hostsPath = 'C:\Windows\System32\drivers\etc\hosts'
    
    if (-not (Test-Path $hostsPath -PathType Leaf)) {
        Write-Host " WARNING: Hosts file not found at: $hostsPath"
        return $false
    }

    $hostsContent = Get-Content -Path $hostsPath -ErrorAction SilentlyContinue
    
    # Domains to check (can be expanded)
    $youtubeDomains = @(
        'youtube.com',
        'www.youtube.com',
        'youtu.be',
        'googlevideo.com'
    )
    
    # We'll look for any non-commented lines referencing these domains.
    # Note: The hosts file often uses whitespace or tabs, so we'll trim each line.
    
    $foundBypass = $false
    foreach ($line in $hostsContent) {
        $trimLine = $line.Trim()
        
        # Skip commented or empty lines
        if ($trimLine -like '#*' -or [string]::IsNullOrWhiteSpace($trimLine)) {
            continue
        }
        
        foreach ($domain in $youtubeDomains) {
            if ($trimLine -match $domain) {
                Write-Host "Hosts file override found: '$line'"
                $foundBypass = $true
            }
        }
    }

    if ($foundBypass) {
        Write-Host " ERROR: One or more YouTube-related entries were found in the hosts file."
        Write-Host ""
        return $true
    }
    else {
        Write-Host " OK! No YouTube-related entries found in the hosts file."
        Write-Host ""
        return $false
    }
}

function Test-ReCheckDNSServers {
    Write-Host " ...re-checking DNS server entries"
    $allConfigs = Get-NetIPConfiguration | 
        Where-Object { 
            $null -ne $_.DNSServer -and 
            'Bluetooth' -notmatch $_.InterfaceAlias -and
            'Loopback' -notmatch $_.InterfaceAlias
        }

    foreach ($config in $allConfigs) {
        foreach ($server in $config.DnsServer.ServerAddresses) {
            if (
                $server -notin $AllowedDNSv4 -and
                $server -notmatch '^fe80::'
            ) {
                Write-Host " WARNING: Unrecognized DNS server $server could circumvent OpenDNS."
                return $true
            }
        }
    }

    return $false
}

function Test-OtherCircumventionMethods {
    $result = $false
    Write-Host "Checking for other potential DNS circumvent methods..."
    # This is a placeholder for further checks, e.g., checking if a VPN is up, 
    # hosts file modifications, custom tunnels, proxies, etc.

    # Re-check all DNS servers. If any server is not in $AllowedDNSv4,
    # and not a link-local IPv6 address, it might be circumventing OpenDNS.
    # if (Test-ReCheckDNSServers -eq $true) {
    #     $ErrorCode = 6
    # }

    # Check for HOSTS file bypass for YouTube
    if (Test-YouTubeHostsBypass) {
        $result = $true
    }
    Write-Host ""
    return $result
}

# --- MAIN SCRIPT EXECUTION ---

Write-Banner
$ErrorCode = 0

# Run tests
if (Test-OnlyOpenDNSUsedForIPv4) { $ErrorCode = 1 }
if (Test-OnlyOpenDNSUsedForIPv6) { $ErrorCode = 2 }
if (Test-DoHNotInUse) { $ErrorCode = 3 }
if (Test-OtherCircumventionMethods) { $ErrorCode = 4 }

Write-Host "========================================"
Write-Host "Script completed with exit code: $ErrorCode"
Write-Host "========================================"

exit $ErrorCode
