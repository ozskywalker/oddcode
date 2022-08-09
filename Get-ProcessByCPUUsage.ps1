(Get-Counter '\Process(*)\% Processor Time').CounterSamples | 
Where-Object {$_.CookedValue -gt 5 -and $_.InstanceName -ne "idle" -and $_.InstanceName -ne "_total"} | 
Sort-Object -Descending CookedValue,InstanceName |
ft Path, InstanceName, @{Label="CPU %";Expression={"{0:P}" -f ($_.CookedValue/100)}}
