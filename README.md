# oddcode
Odd bits and pieces that I've written for odd jobs, or found useful and liberally copypasta'd it :)

* EnableDisable-FileSecurity.ps1 - Powershell byte-sized one-liners for disabling then re-enabling that pesky "Open File - Security Warning" dialog when trying to execute an installer (grumble..)
* exceltricks_formatToGB.txt - Excel Trick for formatting a given number into MB/TB/GB/PB
* droplet_get_ip - Get IP Address of a DigitalOcean Droplet
* Get-PendingReboot - PSH Function to check server if a pending reboot condition exists
* NewMachine_InstallChrome - Downloads Chrome installer using BITSTransfer and installs it
* Send-Pushbullet - Pushbullet notification for uTorrent
* SortDropboxCameraUploads - Takes Dropbox Camera Uploads folder and sorts everything by year/month into Photos folder
* wmi_poll_servers - Poll servers via WMI and extract key information into CSV/Excel

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
