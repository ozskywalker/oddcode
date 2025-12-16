param(
[parameter(Mandatory = $True)][string]$body
)

$APIkey = "<your API key here>";

##
## To be wrapped with this batch file
## uTorrent calls this batch file, which then calls this PSH..
## to setup in uTorrent
##  1. Open Preferences
##  2. Under Advanced, select Run Program
##  3. Set "Run this program when a torrent finishes:" to "<path to batch file> %N"
##
## batchfile contents:
## @echo off
## powershell.exe -ExecutionPolicy unrestricted -command "& { . D:\Send-Pushbullet.ps1 -Body %1 }"
##
## Customise as you wish
##

$bodyblock = @{"type"="note"; "title"="uTorrent PULL"; "body"=$body};

Invoke-RestMethod -Uri "https://api.pushbullet.com/v2/pushes" -Method POST -Headers @{"Authorization" = "Bearer " + $APIkey} -ContentType "application/json" -Body (ConvertTo-Json $bodyblock) -UseBasicParsing;
