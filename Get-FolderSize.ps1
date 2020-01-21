clear-host  
$volumes = "c:\","e:\","f:\","x:\" 
foreach ($startFolder in $volumes){ 
$colItems = (Get-ChildItem $startFolder | Where-Object {$_.PSIsContainer -eq $True} | Sort-Object) 
foreach ($i in $colItems) 
	{ 
		$subFolderItems = (Get-ChildItem $i.FullName -Recurse | Measure-Object -property length -sum) 
		$count = @((Get-ChildItem $i.FullName -force -recurse  | where {$_.length -ge 0} )).Count 
		if($count -eq 0)  
			{ 
			if($subFolderItems.sum -lt 1) 
				{ 
				$avgsize = 0 
				$totalsize = 0 
				} 
			else 
				{ 
				$avgsize = "Not possible" 
				$totalsize = "Not possible" 
				} 
			} 
		else 
			{ 
			$avgsize = [math]::round($subFolderItems.sum/$count / 1MB,2) 
			$totalsize = [math]::round($subFolderItems.sum / 1MB,2) 
			} 
		$output_final = $startFolder + ",",$i.FullName + ",",$totalsize + " MB,",$count + ",",$avgsize + " MB"  
		$output_final | Out-File -Append 'folder-size-log.csv' -Encoding ASCII  
	}  
}  
