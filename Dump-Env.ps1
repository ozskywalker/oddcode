# handy for Datto RMM (DRMM) script testing
# needs PoSh =>5.1

$(Get-ChildItem env:* | Sort-Object name) | ForEach-Object { 
  Write-Host $_.Name "=" $_.Value 
}