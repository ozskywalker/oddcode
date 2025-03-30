# One-liner to find VMs by UUID
# CSV assumes "Key", "Value" headers

$vmSearchList = @{} ; Import-CSV C:\tmp\VMUUIDs.csv | %{ $vmSearchList[$_.Key] = $_.Value } ; Get-VM | %{ $uuid = (Get-View $_.Id).config.uuid; if($vmSearchList.ContainsKey($uuid)) { $vmSearchList[$uuid] = $_.Name } } ; $vmSearchList.GetEnumerator() | sort-object Name | export-csv c:\tmp\output.csv
