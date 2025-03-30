Write-Host "[+] Creating VSS snapshot for C:"

$s1 = (Get-WmiObject -List Win32_ShadowCopy).Create("C:\\", "ClientAccessible")
$s2 = Get-WmiObject Win32_ShadowCopy | Where-Object { $_.ID -eq $s1.ShadowID }
$d  = $s2.DeviceObject + "\\"
Write-Host "[+] We have a snap, ID is $($s2)"

Write-Host "[+] Mounting $d to C:\shadowcopy"
cmd /c mklink /d C:\shadowcopy "$d"
# could also use /j instead of /d

Write-Host "[+] Do things here"

Write-Host "[-] Unmounting $d"
Remove-Item C:\shadowcopy -Confirm:$false -Force

Write-Host "[-] Deleting VSS snapshot $s2"
$s2.Delete()
