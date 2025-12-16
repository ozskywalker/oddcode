$WebServer = "http://whats-your-webserver-name:81/SearchSvc/CVWebService.svc"
$username = "setuserhere"
$password = "setpasshere"

$SCPClientArray = @()
$SubClientPolicyName = "Laptop plan Windows subclient policy"

$headers = @{}
$headers["Accept"] = "application/json"

$Body = @{ 
    username = $username
    password = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($password))
}

# Login to Commvault REST API
$Result = Invoke-RestMethod -Method POST -Uri "$WebServer/Login" -Headers $headers -ContentType "application/json" -Body $($Body | ConvertTo-Json) -UseBasicParsing

# Save QSDK token
$headers["Authtoken"] = $Result.token

# Override accept header - qcommand only works with XML
# Set qoperation execscript command
# And do the work
$headers["Accept"] = "application/xml"
$Body = "qoperation execscript -sn GetSubclientPolicy.sql -si scp=$SubClientPolicyName"
$Result = Invoke-RestMethod -Method POST -Uri "$WebServer/QCommand" -Headers $headers -Body $Body -UseBasicParsing

If ($Result.CVGui_GenericResp.errorCode) { 
    # Error handling
    Write-Host "something went wrong, do something"
} else {
    $ResponseXML.ExecScriptOutput.FieldValue.Clientname | ForEach-Object {
        If($_ -notlike "*GetSubclientPolicycompleted*") {
            $SCPClientArray += $_ 
        }
    }

    Write-Host $SCPClientArray
}
