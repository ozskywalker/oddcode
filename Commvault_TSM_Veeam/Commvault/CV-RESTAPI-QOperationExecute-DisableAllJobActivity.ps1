# This is messy, please forgive me :<

# Can call either to
# - WebServer: :81/SearchSvc/CVWebService.svc
# - WebConsole: /webconsole/api/
$CVRESTAPIEndpoint = "http://webserver_name_here:81/SearchSvc/CVWebService.svc"
$username = "<username>"
$password = "<password>"

$headers = @{}
$headers["Accept"] = "application/json"

$Body = @{ 
    username = $username
    password = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($password))
}

try {
    # Login to Commvault REST API
    $Result = Invoke-RestMethod -Method POST -Uri "$CVRESTAPIEndpoint/Login" -Headers $headers -Body $($Body | ConvertTo-Json) -ContentType "application/json" -UseBasicParsing

    # Save QSDK token
    $headers["Authtoken"] = $Result.token

    Write-Host "[*] Successful login to" $CVRESTAPIEndpoint
} catch {
    Write-Host "Failed to login - received status code" $_.Exception.Response.StatusCode.value__
    Write-Host "StatusDesc:" $_.Exception.Response.StatusDescription
    Write-Host "errList"
    Write-Host $Result.errList
    Write-Host "JSON response"
    Write-Host $Result
}

# Construct Body
$DisableAllActivity_Body = @{
    command = "qoperation execute"
    inputRequestXML = @"
<App_SetCommCellPropertiesReq>
    <commCellInfo>
        <commCellActivityControlInfo>
            <activityControlOptions activityType="128" enableAfterADelay="0" enableActivityType="0" />
        </commCellActivityControlInfo>
    </commCellInfo>
</App_SetCommCellPropertiesReq>
"@
}

$EnableAllActivity_Body = @{
    command = "qoperation execute"
    inputRequestXML = @"
<App_SetCommCellPropertiesReq>
 <commCellInfo>
 <commCellActivityControlInfo>
 <activityControlOptions activityType="128" enableAfterADelay="0" enableActivityType="1" />
 </commCellActivityControlInfo>
 </commCellInfo>
</App_SetCommCellPropertiesReq>
"@
}

# Call Workflow
try {
    $Result = Invoke-RestMethod -Method POST -Uri "$CVRESTAPIEndpoint/ExecuteQCommand" -Headers $headers -Body $DisableAllActivity_Body -UseBasicParsing

    # Sloppy reporting
    If ($Result.Response.errorCode == 0) {
        Write-Host "[*] Successfully submitted change!"
    } else {
        Write-Host "[!] Something went wrong"
        Write-Host $Result.response
    }
    
} catch {
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__
    Write-Host "StatusDesc:" $_.Exception.Response.StatusDescription
    Write-Host "errList"
    Write-Host $Result.errList
    Write-Host "Full response"
    Write-Host $Result.response
}
