<#
.SYNOPSIS
  Remediation script to enforce NextDNS, configure IPv6 DNS, enable DoH,
  configure DoT/DoQ, and comment out YouTube hosts entries.

.DESCRIPTION
  1. Sets all active (non-Bluetooth, non-Loopback) adapters to use NextDNS
  2. Configures IPv6 DNS servers for NextDNS
  3. Enables DNS-over-HTTPS with NextDNS DoH server
  4. Configures DNS-over-TLS/QUIC if supported
  5. Configures browser settings for DoH (Edge, Chrome, Firefox [FF is untested])
  6. Comments out YouTube-related lines in the hosts file, leaving a timestamp comment.

.NOTES
  - Run as Administrator.
  - Applicable to Windows 10 / Windows 11.
  - May require a reboot or network reset in some edge cases for changes to fully apply.
#>

Set-StrictMode -Version Latest

# NextDNS configuration details
$nextDnsIPv4 = @('xxx', 'yyy') # Replace with your NextDNS IPv4 addresses
$nextDnsIPv6 = @('xxx', 'yyy') # Replace with your NextDNS IPv6 addresses
$nextDnsId = 'xxx-yyy' # Replace with your NextDNS ID

# Get the hostname and format it for DNS services
function Get-FormattedHostname {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('DoH', 'DoT')]
        [string]$FormatType
    )
    
    try {
        $hostname = [System.Net.Dns]::GetHostName()
        
        if ($FormatType -eq 'DoT') {
            # For DoT: Replace spaces with -- and only keep alphanumeric chars and hyphens
            $formatted = $hostname -replace ' ', '--'
            $formatted = [Regex]::Replace($formatted, '[^a-zA-Z0-9\-]', '')
            return "$formatted-$nextDnsId.dns.nextdns.io"
        }
        else { # DoH
            # For DoH: URL encode the hostname
            $encoded = [System.Web.HttpUtility]::UrlEncode($hostname)
            return "https://dns.nextdns.io/$nextDnsId/$encoded"
        }
    }
    catch {
        Write-Host "  WARNING: Could not format hostname: $($_.Exception.Message)"
        # Return default endpoints if hostname formatting fails
        if ($FormatType -eq 'DoT') {
            return "$nextDnsId.dns.nextdns.io"
        }
        else { # DoH
            return "https://dns.nextdns.io/$nextDnsId"
        }
    }
}

# Add System.Web for UrlEncode
Add-Type -AssemblyName System.Web

# Get formatted endpoints
$nextDnsDoH = Get-FormattedHostname -FormatType 'DoH'
$nextDnsDoT = Get-FormattedHostname -FormatType 'DoT'

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

function Set-NextDNS {
    Write-Host "Setting NextDNS IPv4 servers for valid adapters..."

    $adapters = Get-ValidNetAdapters
    foreach ($adapter in $adapters) {
        $alias = $adapter.Name
        Write-Host "  Setting IPv4 DNS for '$alias' to $($nextDnsIPv4 -join ' and ')"
        Set-DnsClientServerAddress -InterfaceAlias $alias -ServerAddresses $nextDnsIPv4 -ErrorAction SilentlyContinue
    }
}

function Set-IPv6DNS {
    Write-Host "Setting NextDNS IPv6 DNS for valid adapters..."

    $adapters = Get-ValidNetAdapters
    foreach ($adapter in $adapters) {
        $alias = $adapter.Name
        Write-Host "  Setting IPv6 DNS for '$alias' to $($nextDnsIPv6 -join ' and ')"
        # Need to use separate cmdlet specifically for IPv6
        # The -ServerAddresses parameter accepts both IPv4 and IPv6 addresses
        # Use the specific IPv6 cmdlet instead
        try {
            # Get interface index for this adapter
            $interfaceIndex = $adapter.ifIndex
            # Set IPv6 DNS servers using lower-level command
            Set-DnsClientServerAddress -InterfaceIndex $interfaceIndex -ServerAddresses $nextDnsIPv6 -ErrorAction Stop
        }
        catch {
            Write-Host "  WARNING: Failed to set IPv6 DNS for '$alias': $($_.Exception.Message)"
        }
    }
}

function Set-DnsOverHttps {
    Write-Host "Configuring DNS-over-HTTPS (DoH)..."
    try {
        # Check if the command exists on this system
        if (-not (Get-Command -Name 'Add-DnsClientDohServerAddress' -ErrorAction SilentlyContinue)) {
            Write-Host "  DNS-over-HTTPS configuration not supported on this version of Windows."
            return
        }
        
        # First try to clear any existing DoH servers
        $dohServers = Get-DnsClientDohServerAddress -ErrorAction Stop
        if ($dohServers) {
            foreach ($doh in $dohServers) {
                Write-Host "  Removing existing DoH server: $($doh.ServerAddress)"
                Remove-DnsClientDohServerAddress -ServerAddress $doh.ServerAddress -ErrorAction SilentlyContinue
            }
        }
        else {
            Write-Host "  No existing DoH servers configured."
        }
        
        # Apply DoH template to each NextDNS IPv4 address
        foreach ($ipv4 in $nextDnsIPv4) {
            Write-Host "  Adding DoH configuration for NextDNS IPv4 server: $ipv4 with template: $nextDnsDoH"
            Add-DnsClientDohServerAddress -ServerAddress $ipv4 -DohTemplate $nextDnsDoH -ErrorAction Stop
        }
        
        # Apply DoH template to each NextDNS IPv6 address
        foreach ($ipv6 in $nextDnsIPv6) {
            Write-Host "  Adding DoH configuration for NextDNS IPv6 server: $ipv6 with template: $nextDnsDoH"
            Add-DnsClientDohServerAddress -ServerAddress $ipv6 -DohTemplate $nextDnsDoH -ErrorAction Stop
        }
        
        Write-Host "  DoH configuration successful."
    }
    catch {
        Write-Host "  DNS-over-HTTPS configuration not supported on this system: $($_.Exception.Message)"
        Write-Host "  (Skipping DoH configuration step.)"
    }
}

function Set-DnsOverTLS {
    Write-Host "Configuring DNS-over-TLS/QUIC..."
    try {
        # Check for command availability
        if (-not (Get-Command -Name 'Get-DnsClientDotServerAddress' -ErrorAction SilentlyContinue)) {
            Write-Host "  DNS-over-TLS/QUIC is not supported on this version of Windows."
            return
        }
        
        # Remove any existing DoT servers
        $dotServers = Get-DnsClientDotServerAddress -ErrorAction Stop
        if ($dotServers) {
            foreach ($dot in $dotServers) {
                Write-Host "  Removing existing DoT server: $($dot.ServerAddress)"
                Remove-DnsClientDotServerAddress -ServerAddress $dot.ServerAddress -ErrorAction SilentlyContinue
            }
        }
        else {
            Write-Host "  No existing DoT servers configured."
        }
        
        # Add NextDNS DoT server
        Write-Host "  Adding NextDNS DoT server: $nextDnsDoT"
        Add-DnsClientDotServerAddress -ServerAddress $nextDnsDoT -ErrorAction Stop
        Write-Host "  DoT configuration successful."
    }
    catch {
        Write-Host "  DNS-over-TLS/QUIC configuration not supported on this system: $($_.Exception.Message)"
        Write-Host "  (Skipping DoT configuration step.)"
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

function Set-BrowserDohSettings {
    Write-Host "Configuring browser DoH settings for NextDNS..."
    
    # Check for browsers and configure each one found
    Set-EdgeDohSettings
    Set-ChromeDohSettings
    #Set-FirefoxDohSettings
}

function Set-EdgeDohSettings {
    Write-Host "Checking for Microsoft Edge..."
    $edgePath = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    $edgePathX64 = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    
    if ((Test-Path $edgePath) -or (Test-Path $edgePathX64)) {
        Write-Host "  Microsoft Edge detected, configuring DoH settings..."
        try {
            # Create registry path if it doesn't exist
            $edgeRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
            if (-not (Test-Path $edgeRegPath)) {
                New-Item -Path $edgeRegPath -Force | Out-Null
            }
            
            # Remove any existing DoH settings
            Remove-ItemProperty -Path $edgeRegPath -Name "DnsOverHttpsMode" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $edgeRegPath -Name "DnsOverHttpsTemplates" -ErrorAction SilentlyContinue
            
            # Configure DoH settings for NextDNS
            Write-Host "  Setting Edge DoH mode to 'automatic'"
            Set-ItemProperty -Path $edgeRegPath -Name "DnsOverHttpsMode" -Value "automatic" -Type String
            
            Write-Host "  Setting Edge DoH template to NextDNS: $nextDnsDoH"
            Set-ItemProperty -Path $edgeRegPath -Name "DnsOverHttpsTemplates" -Value $nextDnsDoH -Type String
            
            Write-Host "  Edge DoH configuration successful."
        }
        catch {
            Write-Host "  ERROR: Failed to configure Edge DoH settings: $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "  Microsoft Edge not detected, skipping configuration."
    }
}

function Set-ChromeDohSettings {
    Write-Host "Checking for Google Chrome..."
    $chromePath = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    $chromePathX64 = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
    
    if ((Test-Path $chromePath) -or (Test-Path $chromePathX64)) {
        Write-Host "  Google Chrome detected, configuring DoH settings..."
        try {
            # Create registry path if it doesn't exist
            $chromeRegPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
            if (-not (Test-Path $chromeRegPath)) {
                New-Item -Path $chromeRegPath -Force | Out-Null
            }
            
            # Remove any existing DoH settings
            Remove-ItemProperty -Path $chromeRegPath -Name "DnsOverHttpsMode" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $chromeRegPath -Name "DnsOverHttpsTemplates" -ErrorAction SilentlyContinue
            
            # Configure DoH settings for NextDNS
            Write-Host "  Setting Chrome DoH mode to 'automatic'"
            Set-ItemProperty -Path $chromeRegPath -Name "DnsOverHttpsMode" -Value "automatic" -Type String
            
            Write-Host "  Setting Chrome DoH template to NextDNS: $nextDnsDoH"
            Set-ItemProperty -Path $chromeRegPath -Name "DnsOverHttpsTemplates" -Value $nextDnsDoH -Type String
            
            Write-Host "  Chrome DoH configuration successful."
        }
        catch {
            Write-Host "  ERROR: Failed to configure Chrome DoH settings: $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "  Google Chrome not detected, skipping configuration."
    }
}

function Set-FirefoxDohSettings {
    Write-Host "Checking for Mozilla Firefox..."
    $firefoxPath = "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"
    $firefoxPathX64 = "$env:ProgramFiles\Mozilla Firefox\firefox.exe"
    
    if ((Test-Path $firefoxPath) -or (Test-Path $firefoxPathX64)) {
        Write-Host "  Mozilla Firefox detected, configuring DoH settings..."
        try {
            # Find all Firefox profiles
            $profilesPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
            if (Test-Path $profilesPath) {
                $profiles = Get-ChildItem -Path $profilesPath -Directory
                
                if ($profiles.Count -eq 0) {
                    Write-Host "  No Firefox profiles found, skipping configuration."
                    return
                }
                
                foreach ($profile in $profiles) {
                    $profileName = $profile.Name
                    $prefsPath = Join-Path $profile.FullName "prefs.js"
                    
                    if (Test-Path $prefsPath) {
                        Write-Host "  Configuring DoH for Firefox profile: $profileName"
                        
                        # Read the current prefs file
                        $prefsContent = Get-Content -Path $prefsPath
                        
                        # Remove existing DoH settings
                        $prefsContent = $prefsContent | Where-Object {
                            $_ -notmatch 'user_pref\("network\.trr\.mode",' -and
                            $_ -notmatch 'user_pref\("network\.trr\.uri",' -and
                            $_ -notmatch 'user_pref\("network\.trr\.custom_uri",'
                        }
                        
                        # Add NextDNS DoH settings
                        # Mode 2 = DoH enabled with fallback to normal DNS
                        $prefsContent += 'user_pref("network.trr.mode", 2);'
                        $prefsContent += 'user_pref("network.trr.uri", "' + $nextDnsDoH + '");'
                        $prefsContent += 'user_pref("network.trr.custom_uri", "' + $nextDnsDoH + '");'
                        
                        # Write back the updated prefs file
                        Set-Content -Path $prefsPath -Value $prefsContent
                        Write-Host "  Firefox profile $profileName configured successfully for NextDNS DoH."
                    }
                    else {
                        Write-Host "  WARNING: prefs.js not found for profile $profileName, skipping."
                    }
                }
            }
            else {
                Write-Host "  No Firefox profiles directory found, skipping configuration."
            }
        }
        catch {
            Write-Host "  ERROR: Failed to configure Firefox DoH settings: $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "  Mozilla Firefox not detected, skipping configuration."
    }
}

Write-Host "========================================"
Write-Host "  Remediation Script Starting"
Write-Host "  Date/Time: $(Get-Date)"
Write-Host "========================================"
Write-Host "Using NextDNS endpoints:"
Write-Host "  DoH: $nextDnsDoH"
Write-Host "  DoT: $nextDnsDoT"
Write-Host "========================================`n"

Set-NextDNS
Set-IPv6DNS
Set-DnsOverHttps
Set-DnsOverTLS
Set-BrowserDohSettings
#Revoke-YouTubeEntriesInHostsFile

Write-Host "`nDone. Remediation actions completed."
exit 0
