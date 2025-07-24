# oddcode

A collection of useful scripts and code snippets gathered over the years.
Use & modify as you wish.

- [System Administration](#system-administration)
- [Windows Automation](#windows-automation)
- [Datto RMM](#datto-rmm)
- [Cloud & DevOps](#cloud--devops)
- [Commvault, TSM, Veeam](#commvault)
- [Media Processing](#media-processing)
- [Network & Security](#network--security)
- [Utilities](#utilities)
- [Script-Specific Instructions](#script-specific-instructions)

## Linux Systems Administration

* **[check-linux-updates-and-push-to-ntfy.sh](Linux_Systems_Administration/check-linux-updates-and-push-to-ntfy.sh)** - Checks a Ubuntu/Debian Linux server for package updates and notifies via Ntfy.sh

## Windows Systems Administration

* **[Administrator-SelfElevate.ps1](Windows_Systems_Administration/Administrator-SelfElevate.ps1)** - Make your PowerShell scripts self elevate to run as an Administrator
* **[Convert-DsRegCmd.ps1](Windows_Systems_Administration/Convert-DsRegCmd.ps1)** - Take DSREGCMD /status output and turn into a PSObject. Very handy stub for a variety of scripting tasks
* **[Convert-FSUtilToObject.ps1](Windows_Systems_Administration/Convert-FSUtilToObject.ps1)** - Converts FSUTIL output into a powershell custom object for easy parsing
* **[Dump-Env.ps1](Windows_Systems_Administration/Dump-Env.ps1)** - Outputs all ENVIRON variables (Env:) to stdout, useful for Datto RMM / DRMM work
* **[EnableDisable-FileSecurity.ps1](Windows_Systems_Administration/EnableDisable-FileSecurity.ps1)** - Powershell byte-sized one-liners for disabling then re-enabling that pesky "Open File - Security Warning" dialog
* **[Enable-WindowsSandbox-OnHomeEdition.ps1](Windows_Systems_Administration/Enable-WindowsSandbox-OnHomeEdition.ps1)** - Enable Windows Sandbox on Windows 10 & 11 Home Edition
* **[Get-ActiveSpeaker.ps1](Windows_Systems_Administration/Get-ActiveSpeaker.ps1)** - Returns active speaker on a Windows 10/11 machine
* **[Get-PendingReboot.ps1](Windows_Systems_Administration/Get-PendingReboot.ps1)** - PSH Function to check server if a pending reboot condition exists
* **[Get-ProcessByCPUUsage.ps1](Windows_Systems_Administration/Get-ProcessByCPUUsage.ps1)** - Get a sorted list of processes using more than 5% CPU
* **[Get-NetworkStatistics.ps1](Windows_Systems_Administration/Get-NetworkStatistics.ps1)** - For troubleshooting script - get network stats
* **[Get-ServicesUsingServiceAccounts.ps1](Windows_Systems_Administration/Get-ServicesUsingServiceAccounts.ps1)** - One-liner to show all services on a machine using something other than SYSTEM/LocalService/NetworkService
* **[Get-UserSecurityGroups.ps1](Windows_Systems_Administration/Get-UserSecurityGroups.ps1)** - Get security groups for a given user
* **[Get-WindowsUpdates.ps1](Windows_Systems_Administration/Get-WindowsUpdates.ps1)** - Get a list of Windows Updates and the status of that individual patch (& whether it was installed/uninstalled)
* **[NewMachine_InstallChrome.ps1](Windows_Systems_Administration/NewMachine_InstallChrome.ps1)** - Downloads Chrome installer using BITSTransfer and installs it
* **[Read-IniFile.psm1](Windows_Systems_Administration/Read-IniFile.psm1)** - Function to read INI files in as a PowerShell Object
* **[Remove-Notepad.ps1](Windows_Systems_Administration/Remove-Notepad.ps1)** - Remove Notepad++ across a fleet of machines
* **[ReregisterApp.ps1](Windows_Systems_Administration/ReregisterApp.ps1)** - Re-registers applications on Windows (handy when Calculator starts freezing like crazy)
* **[Show-DiskUsage.ps1](Windows_Systems_Administration/Show-DiskUsage.ps1)** - du -h for Windows
* **[Update-WSLDistros.ps1](Windows_Systems_Administration/Update-WSLDistros.ps1)** - Powershell script to update all WSL distros via RMM script
* **[wmi_poll_servers.ps1](Windows_Systems_Administration/wmi_poll_servers.ps1)** - Poll servers via WMI and extract key information into CSV/Excel

## RMM Scripts

* **[Disable-MicrosoftCopilot.ps1](RMM_Scripts/Disable-MicrosoftCopilot.ps1)** - Disables Microsoft Copilot by removing the Appx package & changing the GPO reg key if it exists
* **[DRMM-CheckRefreshRate.ps1](RMM_Scripts/DRMM-CheckRefreshRate.ps1)** - Monitor component - checks that the refresh rate across all screens doesn't fall below a minimum value
* **[DRMM-Testrig-Monitor-ForceStatus.ps1](RMM_Scripts/DRMM-Testrig-Monitor-ForceStatus.ps1)** - Monitor component - forces a specific status/message for testing monitoring processes
* **[DRMM-PopulateUDFwithDNSServers.ps1](RMM_Scripts/DRMM-PopulateUDFwithDNSServers.ps1)** - Script - populates a UDF with the DNS servers addresses on a Windows machine
* **[DRMM-macOS-CheckForNonAPFSvols.sh](RMM_Scripts/DRMM-macOS-CheckForNonAPFSvols.sh)** - Monitor component - looks for non-APFS vols by calling diskutil
* **[DRMM-macOS-disable-ipv6.sh](RMM_Scripts/DRMM-macOS-disable-ipv6.sh)** - Disables IPv6 on all interfaces on a given macOS endpoint
* **[Get-NextDNSEnforcementStatus.ps1](RMM_Scripts/Get-NextDNSEnforcementStatus.ps1)** - Script for RMM to monitor NextDNS and avoid common bypasses
* **[Set-NextDNSEnforcement.ps1](RMM_Scripts/Set-NextDNSEnforcement.ps1)** - Script for RMM to enforce NextDNS and avoid common bypasses
* **[Get-NTPtoCloudFlareStatus.ps1](Windows_Systems_Administration/Set-NTPtoCloudFlare.ps1)** - Forces Windows 10 & 11 to use CloudFlare's NTP servers
* **[Set-NTPtoCloudFlare.ps1](Windows_Systems_Administration/Set-NTPtoCloudFlare.ps1)** - Forces Windows 10 & 11 to use CloudFlare's NTP servers
* **[Set-DisableSleeponACPower.ps1](RMM_Scripts/Set-DisableSleeponACPower.ps1)** - Script for RMM to disable sleep on AC power and lid close, and disable Hibernation entirely (helps Bitlocker stay active)
* **[Get-WhosLoggedIn.ps1](RMM_Scripts/Get-WhosLoggedIn.ps1)** - Pull list of logged on users on the local machine

## Cloud & DevOps

* **[docker_update.ps1](Cloud_DevOps/docker_update.ps1)** - Update all docker images on local workstation (Windows/PowerShell)
* **[docker_update.sh](Cloud_DevOps/docker_update.sh)** - Update all docker images on local workstation (macOS-Linux/Bash)
* **[droplet_get_ip.py](Cloud_DevOps/droplet_get_ip.py)** - Get IP Address of a DigitalOcean Droplet
* **[Get-DockerRestartString.sh](Cloud_DevOps/Get-DockerRestartString.sh)** - Returns the docker commandline for an existing container so you can restart it
* **[lambda_autoShutdown.py](Cloud_DevOps/lambda_autoShutdown.py)** - AWS Lambda function to auto-shutdown instances, unless it has a specified ignoreTag
* **[Update-Route53.ps1](Cloud_DevOps/Update-Route53.ps1)** - Runs at time of EC2 start to update/create CNAME record based on instance's public host name

## Commvault, TSM, Veeam
note: these backup software scripts are significantly out-of-date and being retained only for archival purposes

### Commvault
* **[CV-RESTAPI-DumpEdgeDriveContentsToHTML.ps1](Commvault_TSM_Veeam/Commvault/CV-RESTAPI-DumpEdgeDriveContentsToHTML.ps1)** - Script to dump the contents for a given Commvault Edge Drive path out to HTML
* **[CV-RESTAPI-ExecuteWorkflowAsGETCall.ps1](Commvault_TSM_Veeam/Commvault/CV-RESTAPI-ExecuteWorkflowAsGETCall.ps1)** - Script to call Commvault workflow
* **[CV-RESTAPI-QOperationExecute-DisableAllJobActivity.ps1](Commvault_TSM_Veeam/Commvault/CV-RESTAPI-QOperationExecute-DisableAllJobActivity.ps1)** - Script to submit into XML message bus
* **[CV-RESTAPI-QOperationExecute.ps1](Commvault_TSM_Veeam/Commvault/CV-RESTAPI-QOperationExecute.ps1)** - Script to perform example QOperation Execute command for Commvault

### Veeam
* **[veeam_cbtbug_fix.ps1](Commvault_TSM_Veeam/Veeam/veeam_cbtbug_fix.ps1)** - Workaround script for Veeam KB 2090639

### TSM
* **[parseTSM.py](Commvault_TSM_Veeam/TSM/parseTSM.py)** - Scrapes backup completion times from TSM mmbackup log entries

### General Backup work, testing, etc.
* **[Generate_MSSQL_Activity.ps1](Commvault_TSM_Veeam/General/Generate_MSSQL_Activity.ps1)** - Generates random activity in an AdventureWorks2022 database for LAB environments
* **[FindVMsbyUUID.ps1](Commvault_TSM_Veeam/General/FindVMsbyUUID.ps1)** - Find VMware VMs by UUID (requires PowerCLI)
* **[PowerCLI-VMware-FindVMsbyUUID.ps1](Commvault_TSM_Veeam/General/PowerCLI-VMware-FindVMsbyUUID.ps1)** - One-liner powershell script to find VMs by UUID
* **[vss_mount_and_work.ps1](Commvault_TSM_Veeam/General/vss_mount_and_work.ps1)** - Script to create and mount a VSS snapshot, do work, then clean up

## Media Processing

* **[convert_mov_to_mp4.sh](Media_Processing/convert_mov_to_mp4.sh)** - Converts .MOV (or any movie file) to MP4 using FFMPEG
* **[exif_plot.py](Media_Processing/exif_plot.py)** - Extracts GPS Info via EXIF from files and plots on Google Maps
* **[ffmpeg-ConvertAC3toAAC.ps1](Media_Processing/ffmpeg-ConvertAC3toAAC.ps1)** - Converts all AC3 files in a directory to AAC files using ffmpeg

## Network & Security

* **[Force-TLS12forPowershell.ps1](Network_Security/Force-TLS12forPowershell.ps1)** - Stub to force TLS12 or better as the default for Powershell
* **[Get-SChannelCipherList.ps1](Network_Security/Get-SChannelCipherList.ps1)** - Determines what SSL & TLS ciphers are supported on Windows
* **[Test-TLSConnection.ps1](Network_Security/Test-TLSConnection.ps1)** - Attempts TLS connections with specific TLS versions
* **[validate_tls_version.sh](Network_Security/validate_tls_version.sh)** - Validates if a HTTPS server will accept a specific TLS version using cURL

## Utilities

* **[ETL_MSSQL.py](Utilities/ETL_MSSQL.py)** - Rudimentary ETL load left-to-right with pyodbc & MS-SQL
* **[exceltricks_formatToGB.txt](Utilities/exceltricks_formatToGB.txt)** - Excel Trick for formatting a given number into MB/TB/GB/PB
* **[facebook-messenger-archive-everything.md](Utilities/facebook-messenger-archive-everything.md)** - Archive all your Facebook Messenger chats
* **[Get-FolderSize.ps1](Utilities/Get-FolderSize.ps1)** - Scan folder recursively and output CSV file with file & sizes
* **[lease_check.py](Utilities/lease_check.py)** - Quick check on value of a car lease (US)
* **[Send-Pushbullet.ps1](Utilities/Send-Pushbullet.ps1)** - Pushbullet notification for uTorrent
* **[SortDropboxCameraUploads.ps1](Utilities/SortDropboxCameraUploads.ps1)** - Sorts Dropbox Camera Uploads folder by year/month into Photos folder


## Script-Specific Instructions

### Send-Pushbullet

To be wrapped with a batch file - uTorrent calls this batch file, which then calls this PSH:

* To setup in uTorrent:
  1. Open Preferences
  2. Under Advanced, select Run Program
  3. Set "Run this program when a torrent finishes:" to "<path to batch file> %N"

Batchfile contents:
```
@echo off
powershell.exe -ExecutionPolicy unrestricted -command "& { . D:\Send-Pushbullet.ps1 -Body %1 }"
```
