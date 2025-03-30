# oddcode
Odd bits and pieces written or collected over the years.

Use how you wish, at your own risk.

* Administrator-SelfElevate.ps1 - Make your PowerShell scripts self elevate to run as an Administrator
* check-linux-updates-and-push-to-ntfy.sh - Checks a Ubuntu/Debian Linux server for package updates and notifies via Ntfy.sh
* Convert-DsRegCmd.ps1 - Take DSREGCMD /status output and turn into a PSObject.  Very handy stub for a variety of scripting tasks.
* convert_mov_to_mp4.sh - Converts .MOV (or any movie file really) to MP4. Uses FFMPEG. Intended for quick 'n easy screen recording work on macOS (quicktime screen recording -> .mov -> compress to .mp4)
* facebook-messenger-archive-everything.md - Archive all your Facebook Messenger chats, clean that right up
* Force-TLS12forPowershell.ps1 - stub to force TLS12 or better as the default for Powershell
* Convert-FSUtilToObject.ps1 - Converts FSUTIL output into a powershell custom object for easy parsing
* CV-RESTAPI-DumpEdgeDriveContentsToHTML.ps1 - Powershell script to dump the contents for a given Commvault Edge Drive path out to HTML
* CV-RESTAPI-ExecuteWorkflowAsGETCall.ps1 - Powershell script to call Commvault workflow
* CV-RESTAPI-QOperationExecute-DisableAllJobActivity.ps1 - Powershell script to submit into XML message bus
* CV-RESTAPI-QOperationExecute.ps1 - Powershell script to perform example QOperation Execute command for Commvault
* DRMM-CheckRefreshRate.ps1 - Datto RMM monitor component - checks that the refresh rate across all screens doesn't fall below a minimum value (defaults to 59 (=59.00 Hz))
* DRMM-Testrig-Monitor-ForceStatus.ps1 - Datto RMM monitor component - forces a specific status/message useful for testing out monitoring and related processes (response components, email alerts, etc.)
* DRMM-PopulateUDFwithDNSServers.ps1 - Datto RMM script - populates a UDF with the DNS servers addresses on a Windows machine (string joined with comma)
* DRMM-macOS-CheckForNonAPFSvols.sh - Datto RMM monitor component - looks for non-APFS vols by calling diskutil
* DRMM-macOS-disable-ipv6.sh - Disables IPv6 on all interfaces on a given macOS endpoint
* docker_update.ps1 - Update all docker images on local workstation (Windows/PowerShell)
* docker_update.sh - Update all docker images on local workstation (macOS-Linux/Bash)
* droplet_get_ip.py - Get IP Address of a DigitalOcean Droplet
* Dump-Env.ps1 - outputs all ENVIRON variables (Env:) to stdout, useful for Datto RMM / DRMM work
* EnableDisable-FileSecurity.ps1 - Powershell byte-sized one-liners for disabling then re-enabling that pesky "Open File - Security Warning" dialog when trying to execute an installer (grumble..)
* Enable-WindowsSandbox-OnHomeEdition.ps1 - Enable Windows Sandbox on Windows 10 & 11
* lease_check.py - quick check on value of a car lease (US)
* ETL_MSSQL.py - Rudimentary ETL load left-to-right with pyodbc & MS-SQL
* exceltricks_formatToGB.txt - Excel Trick for formatting a given number into MB/TB/GB/PB
* exif_plot.py - Extracts GPS Info via EXIF from single file or whole directory and plots on Google Maps
* ffmpeg-ConvertAC3toAAC.ps1 - Converts all AC3 files in a directory, to AAC files, using ffmpeg
* FindVMsbyUUID.ps1 - Find VMware VMs by UUID (requires PowerCLI)
* Get-ActiveSpeaker.ps1 - returns active speaker on a Windows 10/11 machine
* Get-DockerRestartString.sh - returns the docker commandline for an existing container so you can restart it
* Get-FolderSize.ps1 - Scan folder recursively and spit out CSV file with file & sizes
* Get-NetworkStatistics.ps1 - For troubleshooting script - get network stats
* Get-PendingReboot.ps1 - PSH Function to check server if a pending reboot condition exists
* Get-ProcessByCPUUsage.ps1 - Get a sorted list of processes using more than 5% CPU
* Get-UserSecurityGroups.ps1 - Get security groups for a given user
* Get-SChannelCipherList.ps1 - Calls SChannel to determine what SSL & TLS ciphers are supported on Windows (compatible w/Server 2012 R2 & newer / PowerShell 4.0 & newer)
* Get-NextDNSEnforcementStatus.ps1 / Set-NextDNSEnforcement.ps1 - Scripts for RMM to monitor & enforce NextDNS and avoid common bypasses.
* Get-ServicesUsingServiceAccounts.ps1 - one-liner to show all services on a machine using something other than SYSTEM/LocalService/NetworkService
* Get-WindowsUpdates.ps1 - Get a list of Windows Updates and the status of that individual patch (& whether it was installed/uninstalled)
* Generate_MSSQL_Activity.ps1 - Generates random activity in an AdventureWorks2022 database (MS SQL Server 2022) for LAB environments
* NewMachine_InstallChrome.ps1 - Downloads Chrome installer using BITSTransfer and installs it
* parseTSM.py - scrapes backup completion times from TSM mmbackup log entries
* PowerCLI-VMware-FindVMsbyUUID.ps1 - One-liner powershell script to find VMs by UUID
* python_logging_block.py - Boilerplate Python 3 logging block
* Read-IniFile.psm1 - Function to read INI files in as a PowerShell Object
* Remove-Notepad.ps1 - Remove Notepad++ across a fleet of machines
* ReregisterApp.ps1 - Re-registers applications on Windows (handy when Calculator starts freezing like crazy)
* Set-NTPtoCloudFlare.ps1 - Forces Windows 10 & 11 to use CloudFlare's NTP servers
* Send-Pushbullet.ps1 - Pushbullet notification for uTorrent
* Show-DiskUsage.ps1 - du -h for Windows
* SortDropboxCameraUploads.ps1 - Takes Dropbox Camera Uploads folder and sorts everything by year/month into Photos folder
* lambda_autoShutdown.py - AWS Lambda function to auto-shutdown instances, unless it has a specified ignoreTag
* Update-Route53.ps1 - Powershell script to run at time of EC2 start, will update (or create) CNAME record based on instance's current public host name
* Update-WSLDistros.ps1 - Powershell script to update all WSL distros via RMM script. Many thanks to [SvenGroot's WslManagementPS script](https://github.com/SvenGroot/WslManagementPS), I've simply just wrapped their good work.
* Test-TLSConnection.ps1 - Powershell script to attempt TLS connections with specific TLS versions. Some warning - Windows registry keys may force the client to upgrade, and .NET won't tell us who forced the upgrade (Client or Server).
* validate_tls_version.sh - Bash script to validate if a HTTPS server will accept a specific TLS version.  Uses cURL.
* veeam_cbtbug_fix.ps1 - workaround script for Veeam KB 2090639
* vss_mount_and_work.ps1 - quick 'n dirty powershell shim to create and mount a VSS snapshot, do work against the snapshot, then unmount & delete snapshot afterwards.
* WhosLoggedIn.ps1 - pull list of logged on users on the local machine
* wmi_poll_servers.ps1 - Poll servers via WMI and extract key information into CSV/Excel

# Script-specific instructions...

## Send-Pushbullet

To be wrapped with a batch file - uTorrent calls this batch file, which then calls this PSH..
* To setup in uTorrent
1. Open Preferences
2. Under Advanced, select Run Program
3. Set "Run this program when a torrent finishes:" to "<path to batch file> %N"

Batchfile contents:
```
@echo off
powershell.exe -ExecutionPolicy unrestricted -command "& { . D:\Send-Pushbullet.ps1 -Body %1 }"
```
