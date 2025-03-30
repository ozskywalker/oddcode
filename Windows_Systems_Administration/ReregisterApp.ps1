param([parameter(Mandatory = $True)][string]$App)

$manifest = (Get-AppxPackage "*$App*").InstallLocation + '\AppxManifest.xml'
Add-AppxPackage -DisableDevelopmentMode -Register $manifest