# oddcode
Odd bits and pieces that I've written for odd jobs, or found useful and liberally copypasta'd it :)

* python_logging_block.py - Boilerplate Python 3 logging block
* parseTSM.py - scrapes backup completion times from TSM mmbackup log entries
* PowerCLI-VMware-FindVMsbyUUID.ps1 - One-liner powershell script to find VMs by UUID
* CV-RESTAPI-ExecuteWorkflowAsGETCall.ps1 - Powershell script to call Commvault workflow
* CV-RESTAPI-QOperationExecute.ps1 - Powershell script to perform example QOperation Execute command for Commvault
* CV-RESTAPI-QOperationExecute-DisableAllJobActivity.ps1 - Powershell script to submit into XML message bus
* CV-RESTAPI-DumpEdgeDriveContentsToHTML.ps1 - Powershell script to dump the contents for a given Commvault Edge Drive path out to HTML
* docker_update.sh - Update all docker images on local workstation
* ETL_MSSQL.py - Rudimentary ETL load left-to-right with pyodbc & MS-SQL
* Update-Route53.ps1 - Powershell script to run at time of EC2 start, will update (or create) CNAME record based on instance's current public host name
* EnableDisable-FileSecurity.ps1 - Powershell byte-sized one-liners for disabling then re-enabling that pesky "Open File - Security Warning" dialog when trying to execute an installer (grumble..)
* exceltricks_formatToGB.txt - Excel Trick for formatting a given number into MB/TB/GB/PB
* droplet_get_ip - Get IP Address of a DigitalOcean Droplet
* Get-PendingReboot - PSH Function to check server if a pending reboot condition exists
* NewMachine_InstallChrome - Downloads Chrome installer using BITSTransfer and installs it
* Send-Pushbullet - Pushbullet notification for uTorrent
* SortDropboxCameraUploads - Takes Dropbox Camera Uploads folder and sorts everything by year/month into Photos folder
* wmi_poll_servers - Poll servers via WMI and extract key information into CSV/Excel
* exif_plot.py - Extracts GPS Info via EXIF from single file or whole directory and plots on Google Maps

# Something resembling instructions...

## Send-Pushbullet

To be wrapped with a batch file - uTorrent calls this batch file, which then calls this PSH..
* To setup in uTorrent
1. Open Preferences
2. Under Advanced, select Run Program
3. Set "Run this program when a torrent finishes:" to "<path to batch file> %N"

batchfile contents
```
@echo off
powershell.exe -ExecutionPolicy unrestricted -command "& { . D:\Send-Pushbullet.ps1 -Body %1 }"
```

Customise as you wish
