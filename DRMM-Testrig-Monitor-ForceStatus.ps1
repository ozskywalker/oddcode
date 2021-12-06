# Script monitor for Datto RMM (DRMM) that lets you force any status or message
# Useful to test alerts, response components and other activities related to monitoring DRMM endpoints

$resultMessage = $env:ResultMessage
$resultStatus = $env:ResultStatus
$diag = $env:diagMessage

Write-Host "<-Start Result->"
Write-Host "$resultStatus=$resultMessage"
Write-Host "<-End Result->"

Write-Host "<-Start Diagnostic->"
Write-Host $diag
Write-Host "<-End Diagnostic->"

exit $env:exitCodeToUse