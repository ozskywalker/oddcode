<#
.SYNOPSIS
  Checks that system DNS is configured to use only NextDNS for IPv4 and IPv6, 
  and that DNS-over-HTTPS and DNS-over-TLS/QUIC are properly configured.
  
.DESCRIPTION
  This script is intended for use with RMM solutions (Action1, Level, etc.) as a monitor.
  - If everything is OK, it returns exit code 0.
  - If there are issues, it returns a non-zero exit code.
  
.NOTES
  - Ignores adapters with "Bluetooth" or "Loopback" in their names.
  - Compatible with Windows 10 and newer.
  - Exit codes:
    0 = All checks passed
    1 = IPv4 DNS not properly configured
    2 = IPv6 DNS not properly configured
    3 = DNS-over-HTTPS issue detected
    4 = DNS-over-TLS/QUIC issue detected
    5 = YouTube HOSTS file bypass detected
    6 = Other DNS circumvention detected
#>

Set-StrictMode -Version Latest

# Specify allowed NextDNS servers
$AllowedDNSv4 = @('45.90.28.95', '45.90.30.95')
$AllowedDNSv6 = @('2a07:a8c0::33:bd86', '2a07:a8c1::33:bd86')
$nextDnsId = '33bd86'

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

function Get-ValidNetAdapters {
    # Retrieves all active network adapters, excluding ones we want to ignore
    Get-NetAdapter | Where-Object {
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

function Test-OtherCircumventionMethods {
    $result = $false
    Write-Host "Checking for other potential DNS circumvention methods..."

    # Check for proxies
    $proxyEnabled = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" | Select-Object -ExpandProperty ProxyEnable
    if ($proxyEnabled -eq 1) {
        Write-Host " WARNING: System proxy is enabled, which could bypass DNS settings."
        $result = $true
    }
    
    # Check for VPN connections
    $vpnConnections = Get-VpnConnection -ErrorAction SilentlyContinue | Where-Object { $_.ConnectionStatus -eq "Connected" }
    if ($vpnConnections) {
        Write-Host " WARNING: Active VPN connection detected that may use its own DNS servers:"
        foreach ($vpn in $vpnConnections) {
            Write-Host "  - $($vpn.Name)"
        }
        $result = $true
    }
    
    # Check for alternate DNS client settings in registry (could be added later)
    
    Write-Host ""
    return $result
}
function Test-NextDNSv4Configuration {
    $result = $false
    Write-Host "Checking IPv4 DNS servers..."

    $adapters = Get-ValidNetAdapters
    
    if (-not $adapters) {
        Write-Host "No active network adapters found to check."
        Write-Host ""
        return $false
    }

    foreach ($adapter in $adapters) {
        $config = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4
        $dnsServers = $config.ServerAddresses
        
        Write-Host " Adapter: $($adapter.Name) (Index: $($adapter.ifIndex))"
        Write-Host " IPv4 DNS Servers: $($dnsServers -join ', ')"

        # Check if all configured servers are in allowed list
        foreach ($server in $dnsServers) {
            if ($server -and $AllowedDNSv4 -notcontains $server) {
                Write-Host "  ERROR: IPv4 DNS server $server is not in the allowed list."
                $result = $true
            }
        }

        # Check if all allowed servers are configured
        foreach ($allowed in $AllowedDNSv4) {
            if ($dnsServers -notcontains $allowed) {
                Write-Host "  ERROR: Missing NextDNS server $allowed on adapter $($adapter.Name)."
                $result = $true
            }
        }
    }
    Write-Host ""
    return $result
}

function Test-NextDNSv6Configuration {
    $result = $false
    Write-Host "Checking IPv6 DNS servers..."

    $adapters = Get-ValidNetAdapters
    
    if (-not $adapters) {
        Write-Host "No active network adapters found to check."
        Write-Host ""
        return $false
    }

    foreach ($adapter in $adapters) {
        # First check if IPv6 is enabled on this adapter
        $ipv6Enabled = Get-NetAdapterBinding -InterfaceAlias $adapter.Name -ComponentID 'ms_tcpip6' | 
                       Select-Object -ExpandProperty Enabled
        
        if (-not $ipv6Enabled) {
            Write-Host " Adapter: $($adapter.Name) (Index: $($adapter.ifIndex))"
            Write-Host " IPv6 is disabled on this adapter."
            continue
        }
        
        # Try both methods to get IPv6 DNS servers
        $dnsServers = @()
        
        # Method 1: Get-DnsClientServerAddress
        $dnsConfig = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv6 -ErrorAction SilentlyContinue
        if ($dnsConfig -and $dnsConfig.ServerAddresses) {
            $dnsServers = @($dnsConfig.ServerAddresses)
        }
        
        # Method 2: Get-NetIPConfiguration (backup method)
        if (-not $dnsServers -or $dnsServers.Count -eq 0) {
            $netConfig = Get-NetIPConfiguration -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue
            if ($netConfig -and $netConfig.DNSServer) {
                # Extract only IPv6 servers
                $dnsServers = @($netConfig.DNSServer.ServerAddresses | Where-Object {
                    $_ -match ':' # Simple check for IPv6 format
                })
            }
        }
        
        Write-Host " Adapter: $($adapter.Name) (Index: $($adapter.ifIndex))"
        Write-Host " IPv6 DNS Servers: $($dnsServers -join ', ')"
        
        # If no IPv6 DNS servers found, check registry directly as a last resort
        if (-not $dnsServers -or $dnsServers.Count -eq 0) {
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\Interfaces\$($adapter.InterfaceGuid)"
            if (Test-Path $regPath) {
                $regDns = Get-ItemProperty -Path $regPath -Name NameServer -ErrorAction SilentlyContinue
                if ($regDns -and $regDns.NameServer) {
                    $dnsServers = @($regDns.NameServer -split ',')
                    Write-Host " IPv6 DNS Servers (from registry): $($dnsServers -join ', ')"
                }
            }
        }

        # Check for any non-link-local servers
        $nonLinkLocalServers = @($dnsServers | Where-Object { 
            $_ -and $_ -notmatch '^fe80::' -and $_ -notmatch '^fec0:0:0:ffff::' -and $_ -ne ''
        })
        
        # If there are no non-link-local servers configured, that's ok
        if ($nonLinkLocalServers.Length -eq 0) {
            Write-Host "  No non-link-local IPv6 DNS servers configured."
            continue
        }
        
        # If there are non-link-local servers, they should match our allowed list
        $allCorrectServers = $true
        foreach ($server in $nonLinkLocalServers) {
            if ($AllowedDNSv6 -notcontains $server) {
                Write-Host "  ERROR: Unauthorized IPv6 DNS server $server configured."
                $result = $true
                $allCorrectServers = $false
            }
        }

        # Check if all expected NextDNS IPv6 servers are present
        $foundCount = 0
        foreach ($allowed in $AllowedDNSv6) {
            if ($nonLinkLocalServers -contains $allowed) {
                $foundCount++
            }
        }
        
        if ($foundCount -ne $AllowedDNSv6.Count -and $nonLinkLocalServers.Length -gt 0) {
            Write-Host "  ERROR: Not all required NextDNS IPv6 servers are configured."
            $result = $true
        }
    }
    
    Write-Host ""
    return $result
}

function Test-DoHConfiguration {
    $result = $false
    Write-Host "Checking DNS-over-HTTPS configuration..."

    try {
        $dohServers = Get-DnsClientDohServerAddress -ErrorAction Stop
        
        if (-not $dohServers) {
            Write-Host " ERROR: No DNS-over-HTTPS servers configured."
            return $true
        }

        # Get the hostname formatted for DoH to check against
        $hostname = [System.Net.Dns]::GetHostName()
        try {
            Add-Type -AssemblyName System.Web
            $encodedHostname = [System.Web.HttpUtility]::UrlEncode($hostname)
            $expectedDoH = "https://dns.nextdns.io/$nextDnsId/$encodedHostname"
        }
        catch {
            # Fallback to basic URL if we can't encode hostname
            $expectedDoH = "https://dns.nextdns.io/$nextDnsId"
        }
        
        $foundCorrectDoH = $false
        foreach ($doh in $dohServers) {
            Write-Host " DoH Server: $($doh.ServerAddress)"
            
            # Check if this is our NextDNS DoH server (with or without hostname)
            if ($doh.ServerAddress -like "https://dns.nextdns.io/$nextDnsId*") {
                $foundCorrectDoH = $true
            }
            # If it's not our NextDNS DoH, it's an error
            else {
                Write-Host "  ERROR: Unauthorized DoH server found: $($doh.ServerAddress)"
                $result = $true
            }
        }
        
        if (-not $foundCorrectDoH) {
            Write-Host "  ERROR: NextDNS DoH server not configured."
            $result = $true
        }
    }
    catch {
        Write-Host " DNS-over-HTTPS not supported on this OS version or command not found."
        Write-Host " (Skipping DoH check.)"
    }
    
    Write-Host ""
    return $result
}

function Test-DoTConfiguration {
    $result = $false
    Write-Host "Checking DNS-over-TLS/QUIC configuration..."

    try {
        # Check if the command exists
        if (-not (Get-Command -Name 'Get-DnsClientDotServerAddress' -ErrorAction SilentlyContinue)) {
            Write-Host " DNS-over-TLS/QUIC not supported on this OS version or command not found."
            Write-Host " (Skipping DoT check.)"
            return $false
        }

        $dotServers = Get-DnsClientDotServerAddress -ErrorAction Stop
        
        if (-not $dotServers) {
            Write-Host " ERROR: No DNS-over-TLS/QUIC servers configured."
            return $true
        }

        # Get the hostname formatted for DoT to check against
        $hostname = [System.Net.Dns]::GetHostName()
        try {
            $formatted = $hostname -replace ' ', '--'
            $formatted = [Regex]::Replace($formatted, '[^a-zA-Z0-9\-]', '')
            $expectedDoT = "$formatted-$nextDnsId.dns.nextdns.io"
        }
        catch {
            # Fallback to basic server name if we can't format hostname
            $expectedDoT = "$nextDnsId.dns.nextdns.io"
        }
        
        $foundCorrectDoT = $false
        foreach ($dot in $dotServers) {
            Write-Host " DoT Server: $($dot.ServerAddress)"
            
            # Check if this is our NextDNS DoT server (with or without hostname)
            if ($dot.ServerAddress -like "*$nextDnsId.dns.nextdns.io") {
                $foundCorrectDoT = $true
            }
            # If it's not our NextDNS DoT, it's an error
            else {
                Write-Host "  ERROR: Unauthorized DoT/DoQ server found: $($dot.ServerAddress)"
                $result = $true
            }
        }
        
        if (-not $foundCorrectDoT) {
            Write-Host "  ERROR: NextDNS DoT/DoQ server not configured."
            $result = $true
        }
    }
    catch {
        Write-Host " DNS-over-TLS/QUIC check error: $($_.Exception.Message)"
        Write-Host " (Skipping DoT check.)"
    }
    
    Write-Host ""
    return $result
}

function Test-YouTubeHostsBypass {
    $result = $false
    Write-Host "Checking HOSTS file for YouTube bypass..."
    
    $hostsPath = 'C:\Windows\System32\drivers\etc\hosts'
    
    if (-not (Test-Path $hostsPath -PathType Leaf)) {
        Write-Host " WARNING: Hosts file not found at: $hostsPath"
        Write-Host ""
        return $false
    }

    $hostsContent = Get-Content -Path $hostsPath -ErrorAction SilentlyContinue
    
    # Domains to check
    $youtubeDomains = @(
        'youtube.com',
        'www.youtube.com',
        'youtu.be',
        'googlevideo.com'
    )
    
    $foundBypass = $false
    foreach ($line in $hostsContent) {
        $trimLine = $line.Trim()
        
        # Skip commented or empty lines
        if ($trimLine -like '#*' -or [string]::IsNullOrWhiteSpace($trimLine)) {
            continue
        }
        
        foreach ($domain in $youtubeDomains) {
            if ($trimLine -match $domain) {
                Write-Host " Hosts file override found: '$line'"
                $foundBypass = $true
            }
        }
    }

    if ($foundBypass) {
        Write-Host " ERROR: One or more YouTube-related entries were found in the hosts file."
        $result = $true
    }
    else {
        Write-Host " OK! No YouTube-related entries found in the hosts file."
    }
    
    Write-Host ""
    return $result
}

function Test-BrowserDohSettings {
    $result = $false
    Write-Host "Checking browser DoH settings..."
    
    # Check each browser
    $edgeResult = Test-EdgeDohSettings
    $chromeResult = Test-ChromeDohSettings
    $firefoxResult = Test-FirefoxDohSettings
    
    # If any browser check returned true, set the overall result to true
    if ($edgeResult -or $chromeResult -or $firefoxResult) {
        $result = $true
    }
    
    Write-Host ""
    return $result
}

function Test-EdgeDohSettings {
    $result = $false
    Write-Host "Checking Microsoft Edge DoH settings..."
    $edgePath = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    $edgePathX64 = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    
    if (-not ((Test-Path $edgePath) -or (Test-Path $edgePathX64))) {
        Write-Host "  Microsoft Edge not detected, skipping check."
        return $false
    }
    
    # Check registry settings
    $edgeRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    if (-not (Test-Path $edgeRegPath)) {
        Write-Host "  ERROR: Edge policy registry path not found."
        return $true
    }
    
    # Get DoH mode setting
    $dohMode = Get-ItemProperty -Path $edgeRegPath -Name "DnsOverHttpsMode" -ErrorAction SilentlyContinue
    if (-not $dohMode -or $dohMode.DnsOverHttpsMode -ne "automatic") {
        Write-Host "  ERROR: Edge DoH mode not set to 'automatic'."
        $result = $true
    }
    
    # Get DoH templates setting
    $dohTemplates = Get-ItemProperty -Path $edgeRegPath -Name "DnsOverHttpsTemplates" -ErrorAction SilentlyContinue
    if (-not $dohTemplates) {
        Write-Host "  ERROR: Edge DoH templates not configured."
        $result = $true
    } 
    else {
        # Check if NextDNS is configured
        $templateValue = $dohTemplates.DnsOverHttpsTemplates
        if (-not $templateValue -or -not ($templateValue -like "https://dns.nextdns.io/$nextDnsId*")) {
            Write-Host "  ERROR: Edge DoH template not set to NextDNS. Current value: $templateValue"
            $result = $true
        }
        else {
            Write-Host "  Edge DoH properly configured with NextDNS: $templateValue"
        }
    }
    
    return $result
}

function Test-ChromeDohSettings {
    $result = $false
    Write-Host "Checking Google Chrome DoH settings..."
    $chromePath = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    $chromePathX64 = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
    
    if (-not ((Test-Path $chromePath) -or (Test-Path $chromePathX64))) {
        Write-Host "  Google Chrome not detected, skipping check."
        return $false
    }
    
    # Check registry settings
    $chromeRegPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
    if (-not (Test-Path $chromeRegPath)) {
        Write-Host "  ERROR: Chrome policy registry path not found."
        return $true
    }
    
    # Get DoH mode setting
    $dohMode = Get-ItemProperty -Path $chromeRegPath -Name "DnsOverHttpsMode" -ErrorAction SilentlyContinue
    if (-not $dohMode -or $dohMode.DnsOverHttpsMode -ne "automatic") {
        Write-Host "  ERROR: Chrome DoH mode not set to 'automatic'."
        $result = $true
    }
    
    # Get DoH templates setting
    $dohTemplates = Get-ItemProperty -Path $chromeRegPath -Name "DnsOverHttpsTemplates" -ErrorAction SilentlyContinue
    if (-not $dohTemplates) {
        Write-Host "  ERROR: Chrome DoH templates not configured."
        $result = $true
    } 
    else {
        # Check if NextDNS is configured
        $templateValue = $dohTemplates.DnsOverHttpsTemplates
        if (-not $templateValue -or -not ($templateValue -like "https://dns.nextdns.io/$nextDnsId*")) {
            Write-Host "  ERROR: Chrome DoH template not set to NextDNS. Current value: $templateValue"
            $result = $true
        }
        else {
            Write-Host "  Chrome DoH properly configured with NextDNS: $templateValue"
        }
    }
    
    return $result
}

function Test-FirefoxDohSettings {
    $result = $false
    Write-Host "Checking Mozilla Firefox DoH settings..."
    $firefoxPath = "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"
    $firefoxPathX64 = "$env:ProgramFiles\Mozilla Firefox\firefox.exe"
    
    if (-not ((Test-Path $firefoxPath) -or (Test-Path $firefoxPathX64))) {
        Write-Host "  Mozilla Firefox not detected, skipping check."
        return $false
    }
    
    # Find Firefox profiles
    $profilesPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
    if (-not (Test-Path $profilesPath)) {
        Write-Host "  Firefox profiles directory not found, skipping check."
        return $false
    }
    
    $profiles = Get-ChildItem -Path $profilesPath -Directory
    if ($profiles.Count -eq 0) {
        Write-Host "  No Firefox profiles found, skipping check."
        return $false
    }
    
    $anyProfileMisconfigured = $false
    
    foreach ($profile in $profiles) {
        $profileName = $profile.Name
        $prefsPath = Join-Path $profile.FullName "prefs.js"
        
        if (-not (Test-Path $prefsPath)) {
            Write-Host "  WARNING: prefs.js not found for profile $profileName, skipping."
            continue
        }
        
        Write-Host "  Checking profile: $profileName"
        $prefsContent = Get-Content -Path $prefsPath -ErrorAction SilentlyContinue
        
        # Look for DoH configuration
        $trrMode = $prefsContent | Where-Object { $_ -match 'user_pref\("network\.trr\.mode",\s*(\d+)\);' }
        if ($trrMode -match 'user_pref\("network\.trr\.mode",\s*(\d+)\);') {
            $modeValue = [int]$Matches[1]
            if ($modeValue -ne 2) {
                Write-Host "    ERROR: Firefox TRR mode not set to 2 (DoH with fallback). Current value: $modeValue"
                $anyProfileMisconfigured = $true
            }
        } else {
            Write-Host "    ERROR: Firefox TRR mode not configured."
            $anyProfileMisconfigured = $true
        }
        
        # Check for NextDNS URI
        $trrUri = $prefsContent | Where-Object { $_ -match 'user_pref\("network\.trr\.uri",\s*"([^"]+)"\);' }
        if ($trrUri -match 'user_pref\("network\.trr\.uri",\s*"([^"]+)"\);') {
            $uriValue = $Matches[1]
            if (-not ($uriValue -like "https://dns.nextdns.io/$nextDnsId*")) {
                Write-Host "    ERROR: Firefox TRR URI not set to NextDNS. Current value: $uriValue"
                $anyProfileMisconfigured = $true
            }
        } else {
            Write-Host "    ERROR: Firefox TRR URI not configured."
            $anyProfileMisconfigured = $true
        }
        
        # Check for NextDNS custom URI
        $trrCustomUri = $prefsContent | Where-Object { $_ -match 'user_pref\("network\.trr\.custom_uri",\s*"([^"]+)"\);' }
        if ($trrCustomUri -match 'user_pref\("network\.trr\.custom_uri",\s*"([^"]+)"\);') {
            $customUriValue = $Matches[1]
            if (-not ($customUriValue -like "https://dns.nextdns.io/$nextDnsId*")) {
                Write-Host "    ERROR: Firefox TRR custom URI not set to NextDNS. Current value: $customUriValue"
                $anyProfileMisconfigured = $true
            }
        } else {
            Write-Host "    ERROR: Firefox TRR custom URI not configured."
            $anyProfileMisconfigured = $true
        }
    }
    
    $result = $anyProfileMisconfigured
    return $result
}

# --- MAIN SCRIPT EXECUTION ---

Write-Banner

# Store test results
$ipv4Result = Test-NextDNSv4Configuration
$ipv6Result = Test-NextDNSv6Configuration
$dohResult = Test-DoHConfiguration
$dotResult = Test-DoTConfiguration
$browserResult = Test-BrowserDohSettings
$hostsResult = Test-YouTubeHostsBypass
$otherResult = Test-OtherCircumventionMethods

# Evaluate results and set error code
if ($ipv4Result) { 
    $ErrorCode = 1 
    Write-Host "ERROR: IPv4 DNS configuration issues detected."
}
elseif ($ipv6Result) { 
    $ErrorCode = 2 
    Write-Host "ERROR: IPv6 DNS configuration issues detected."
}
elseif ($dohResult) { 
    $ErrorCode = 3 
    Write-Host "ERROR: DNS-over-HTTPS configuration issues detected."
}
elseif ($dotResult) { 
    $ErrorCode = 4 
    Write-Host "ERROR: DNS-over-TLS/QUIC configuration issues detected."
}
elseif ($browserResult) {
    $ErrorCode = 7
    Write-Host "ERROR: Browser DoH configuration issues detected."
}
elseif ($hostsResult) { 
    $ErrorCode = 5 
    Write-Host "ERROR: YouTube HOSTS file bypass detected."
}
elseif ($otherResult) { 
    $ErrorCode = 6 
    Write-Host "ERROR: Other DNS circumvention methods detected."
}
else {
    Write-Host "SUCCESS: All DNS configuration checks passed."
}

Write-Host "========================================"
Write-Host "Script completed with exit code: $ErrorCode"
Write-Host "========================================"

exit $ErrorCode