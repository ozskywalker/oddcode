# Get-CloudFlareNTPEnforcementStatus.ps1
# Checks if Windows machine is using CloudFlare for NTP based on registry settings
# Exit codes: 0 = CloudFlare NTP configured, 1 = Windows default, 2 = Other NTP server

try {
    # Check NTP server configuration
    $ntpServer = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "NtpServer" -ErrorAction SilentlyContinue
    $announceFlags = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config" -Name "AnnounceFlags" -ErrorAction SilentlyContinue
    $specialPollInterval = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient" -Name "SpecialPollInterval" -ErrorAction SilentlyContinue
    $ntpClientEnabled = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient" -Name "Enabled" -ErrorAction SilentlyContinue

    if (-not $ntpServer) {
        Write-Host "ERROR: Unable to read NTP server configuration from registry" -ForegroundColor Red
        exit 2
    }

    $currentNtpServer = $ntpServer.NtpServer
    $currentAnnounceFlags = $announceFlags.AnnounceFlags
    $currentPollInterval = $specialPollInterval.SpecialPollInterval
    $currentEnabled = $ntpClientEnabled.Enabled

    # Check for CloudFlare NTP configuration
    if ($currentNtpServer -eq "time.cloudflare.com,0x9" -and 
        $currentAnnounceFlags -eq 5 -and 
        $currentPollInterval -eq 3600 -and 
        $currentEnabled -eq 1) {
        
        Write-Host "SUCCESS: NTP is configured to use CloudFlare (NTP Server: $currentNtpServer, Announce Flags: $currentAnnounceFlags, Poll Interval: $currentPollInterval seconds, NTP Client Enabled: $currentEnabled)" -ForegroundColor Green
        exit 0
    }

    # Check for Windows default NTP servers
    $windowsDefaults = @(
        "time.windows.com,0x9",
        "time.nist.gov,0x9",
        "pool.ntp.org,0x9"
    )

    if ($currentNtpServer -in $windowsDefaults) {
        Write-Host "ERROR: NTP is set to Windows default server (NTP Server: $currentNtpServer, Announce Flags: $currentAnnounceFlags, Poll Interval: $currentPollInterval seconds, NTP Client Enabled: $currentEnabled)" -ForegroundColor Yellow
        exit 1
    }

    # Any other NTP configuration
    Write-Host "ERROR: NTP is set to a non-CloudFlare server (NTP Server: $currentNtpServer, Announce Flags: $currentAnnounceFlags, Poll Interval: $currentPollInterval seconds, NTP Client Enabled: $currentEnabled)" -ForegroundColor Red
    exit 2

} catch {
    Write-Host "ERROR: Failed to check NTP configuration - $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}