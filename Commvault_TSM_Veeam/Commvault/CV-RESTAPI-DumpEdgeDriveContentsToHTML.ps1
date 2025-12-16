$WebServer = "http://webserver-endpoint-here:81/SearchSvc/CVWebService.svc/"
$username = "<userhere>"
$password = "<passhere>"

$path = "\"

$headers = @{}
$headers["Accept"] = "application/json"

$Body = @{ 
    username = $username
    password = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($password))
}

# Login to Commvault REST API
$Result = Invoke-RestMethod -Method POST -Uri "$WebServer/Login" -Headers $headers -Body $($Body | ConvertTo-Json) -ContentType "application/json" -UseBasicParsing

# Save QSDK token
$headers["Authtoken"] = $Result.token

# Call Workflow
$Result = Invoke-RestMethod -Method POST -Uri "$WebServer/Drive/action/list?path=$path" -Headers $headers -UseBasicParsing

# Here's what a sample response looks like under $Result.fileResources
#
# owner            : 
# modifiedTime     : 1513708263
# previewUrl       : /drive/file/f9242b7d7e684264b8f84ecdec03b810/action/preview
# parentPath       : \
# GUID             : f9242b7d7e684264b8f84ecdec03b810
# sizeinBytes      : 531359
# downloadUrl      : /drive/file/f9242b7d7e684264b8f84ecdec03b810/action/download
# versionGUID      : dab2d11bf050c8f256f782e9bbdbdfa4
# path             : \GarbageFile.xlsx
# file             : True
# parentGuid       : 5f1749e853384694935d751ce007e07a
# name             : GarbageFile.xlsx
# customProperties : @{nameValues=System.Object[]}
#

#$Result.fileResources |% { Write-Host $_.path }
$Result.fileResources | Select-Object owner, path, sizeinBytes | ConvertTo-HTML | Out-File .\output.html

Invoke-Expression .\output.html
