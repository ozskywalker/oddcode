<#
Adapted from https://level.io/library/script-windows-disable-sleep-on-ac-power
with a few modifications to disable hibernation and lid close action on AC power.
#>
# Disable sleep on AC power and completely disable hibernation
Write-Host "Disabling sleep on AC power and hibernation..." -ForegroundColor Green
# Set the AC power setting for sleep timeout to never (0)
#powercfg /CHANGE "SCHEME_CURRENT" "SUB_SLEEP" "STANDBYAC" 0
powercfg -change standby-timeout-ac 0
# Set AC power setting for sleep when lid is closed to never (0)
powercfg -setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
# Completely disable hibernation
powercfg -h off

# Verify the changes
# Verify Sleep Timeout on AC
$acSleepTimeout = (powercfg /QUERY SCHEME_CURRENT SUB_SLEEP | Select-String "STANDBYIDLE AC" | ForEach-Object { ($_ -split '\s+')[-1] }) -as [int]
# Verify Lid Action on AC
$lidActionAC = (powercfg /QUERY SCHEME_CURRENT SUB_BUTTONS | Select-String "LIDACTION:" | ForEach-Object { ($_ -split '\s+')[-1] }) -as [int]
# Verify Hibernation Status
$hibernationStatus = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled" -ErrorAction SilentlyContinue

# Expected values
$expectedSleepTimeout = 0
$expectedLidAction = 0  # 0 = "Do Nothing"
$expectedHibernationStatus = 0  # 0 = Disabled

# Check Sleep Timeout
if ($acSleepTimeout -eq $expectedSleepTimeout) {
    Write-Host "✅ Sleep on AC power has been disabled successfully." -ForegroundColor Green
} else {
    Write-Host "❌ Sleep on AC power is NOT disabled. Current Setting: $acSleepTimeout" -ForegroundColor Red
}
# Check Lid Action
if ($lidActionAC -eq $expectedLidAction) {
    Write-Host "✅ Lid close action on AC is set to 'Do Nothing'." -ForegroundColor Green
} else {
    Write-Host "❌ Lid close action on AC is NOT set to 'Do Nothing'. Current Setting: $lidActionAC" -ForegroundColor Red
}
# Check Hibernation Status
if ($hibernationStatus -eq $null -or $hibernationStatus.HibernateEnabled -eq $expectedHibernationStatus) {
    Write-Host "✅ Hibernation has been completely disabled." -ForegroundColor Green
} else {
    Write-Host "❌ Hibernation is NOT disabled. Current Setting: $($hibernationStatus.HibernateEnabled)" -ForegroundColor Red
}