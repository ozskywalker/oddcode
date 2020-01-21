# oddcode
Odd bits and pieces written or collected over the years.

Use how you wish, at your own risk.

* CV-RESTAPI-DumpEdgeDriveContentsToHTML.ps1 - Powershell script to dump the contents for a given Commvault Edge Drive path out to HTML
* CV-RESTAPI-ExecuteWorkflowAsGETCall.ps1 - Powershell script to call Commvault workflow
* CV-RESTAPI-QOperationExecute-DisableAllJobActivity.ps1 - Powershell script to submit into XML message bus
* CV-RESTAPI-QOperationExecute.ps1 - Powershell script to perform example QOperation Execute command for Commvault
* docker_update.sh - Update all docker images on local workstation
* droplet_get_ip.py - Get IP Address of a DigitalOcean Droplet
* EnableDisable-FileSecurity.ps1 - Powershell byte-sized one-liners for disabling then re-enabling that pesky "Open File - Security Warning" dialog when trying to execute an installer (grumble..)
* lease_check.py - quick check on value of a car lease (US)
* ETL_MSSQL.py - Rudimentary ETL load left-to-right with pyodbc & MS-SQL
* exceltricks_formatToGB.txt - Excel Trick for formatting a given number into MB/TB/GB/PB
* exif_plot.py - Extracts GPS Info via EXIF from single file or whole directory and plots on Google Maps
* ffmpeg-ConvertAC3toAAC.ps1 - Converts all AC3 files in a directory, to AAC files, using ffmpeg
* FindVMsbyUUID.ps1 - Find VMs by UUID
* Get-FolderSize.ps1 - Scan folder recursively and spit out CSV file with file & sizes
* Get-NetworkStatistics.ps1 - For troubleshooting script - get network stats
* Get-PendingReboot.ps1 - PSH Function to check server if a pending reboot condition exists
* Get-UserSecurityGroups.ps1 - Get security groups for a given user
* NewMachine_InstallChrome.ps1 - Downloads Chrome installer using BITSTransfer and installs it
* parseTSM.py - scrapes backup completion times from TSM mmbackup log entries
* PowerCLI-VMware-FindVMsbyUUID.ps1 - One-liner powershell script to find VMs by UUID
* python_logging_block.py - Boilerplate Python 3 logging block
* Send-Pushbullet.ps1 - Pushbullet notification for uTorrent
* SortDropboxCameraUploads.ps1 - Takes Dropbox Camera Uploads folder and sorts everything by year/month into Photos folder
* lambda_autoShutdown.py - AWS Lambda function to auto-shutdown instances, unless it has a specified ignoreTag
* Update-Route53.ps1 - Powershell script to run at time of EC2 start, will update (or create) CNAME record based on instance's current public host name
* veeam_cbtbug_fix.ps1 - workaround script for Veeam KB 2090639
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
