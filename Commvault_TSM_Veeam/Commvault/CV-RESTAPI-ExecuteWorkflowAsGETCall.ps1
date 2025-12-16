$WebServer = "http://whats-your-webserver-name:81/SearchSvc/CVWebService.svc"
$username = "setuserhere"
$password = "setpasshere"

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
$Result = Invoke-RestMethod -Method GET -Uri "$WebServer/wapi/Demo_CheckReadiness?ClientGroupName=Media Agents" -Headers $headers -UseBasicParsing
