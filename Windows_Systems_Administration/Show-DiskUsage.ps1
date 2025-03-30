<#
    Emulates "du --max-depth=2 -h" in PowerShell.
    Usage: Save this script as du.ps1 and run:
           .\du.ps1 -Path "C:\SomeDirectory" -MaxDepth 2
    If no parameters are specified, it defaults to the current directory and a max depth of 2.
#>

function ConvertTo-HumanSize {
    param(
        [long]$Bytes
    )
    if ($Bytes -ge 1TB) {
        "{0:N2} TB" -f ($Bytes / 1TB)
    } elseif ($Bytes -ge 1GB) {
        "{0:N2} GB" -f ($Bytes / 1GB)
    } elseif ($Bytes -ge 1MB) {
        "{0:N2} MB" -f ($Bytes / 1MB)
    } elseif ($Bytes -ge 1KB) {
        "{0:N2} KB" -f ($Bytes / 1KB)
    } else {
        "$Bytes B"
    }
}

function Show-DiskUsage {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [int]$MaxDepth,
        [int]$CurrentDepth = 0
    )
    # Recursively calculate the total size of files under the current directory.
    $size = (Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Sum Length).Sum
    if (-not $size) { $size = 0 }
    
    # Use indentation to visually represent directory depth.
    $indent = " " * ($CurrentDepth * 2)
    Write-Output ("{0}{1}`t{2}" -f $indent, (ConvertTo-HumanSize -Bytes $size), $Path)
    
    # If we haven't reached the max depth, process immediate subdirectories.
    if ($CurrentDepth -lt $MaxDepth) {
        $subDirs = Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue
        foreach ($dir in $subDirs) {
            Show-DiskUsage -Path $dir.FullName -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1)
        }
    }
}

param(
    [string]$Path = ".",
    [int]$MaxDepth = 2
)

Show-DiskUsage -Path $Path -MaxDepth $MaxDepth
