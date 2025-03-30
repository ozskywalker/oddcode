# Converts FSUTIL output into an object for easy parsing

$lines = (fsutil volume diskfree C:).Trim() | Where-Object {$_}

$tmpHashTable = @{}
$lines | Select-Object | ForEach-Object {
    $columns = ($_ -split ':').Trim() | Where-Object { $_ }
    $key = $columns[0]
    $value = (($columns[1] -split '\(').Trim())[0]
    
    $tmpHashTable[$key] = $value
}

$fsutilResults = [pscustomobject]$tmpHashTable