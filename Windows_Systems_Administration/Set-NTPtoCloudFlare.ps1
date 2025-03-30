# You must run PowerShell as Administrator to execute this script

Stop-Service w32time -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "NtpServer" -Value "time.cloudflare.com,0x9"

# Configure the Windows Time service to use NTP mode
# Set a polling interval (adjust as needed; 3600 seconds = 1 hour)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config" -Name "AnnounceFlags" -Value 5
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient" -Name "SpecialPollInterval" -Value 3600

# Forcefully ensure NtpClient is enabled and restart the Windows Time service
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient" -Name "Enabled" -Value 1
Start-Service w32time

# Resynchronize & verify the time server
w32tm /resync
w32tm /query /status
