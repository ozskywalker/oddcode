# oddcode
Odd bits and pieces that I've written for odd jobs

* Send-Pushbullet - Pushbullet notification for uTorrent

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
