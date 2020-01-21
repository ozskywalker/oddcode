param([string]$User)
function Get-SecurityList { 
    param($list)
    $list | ForEach-Object { 
        if ($_.GroupCategory -eq "Security") { Write-Host $_.name }
    }
}

if (-not (Get-Module -Name "ActiveDirectory")) {
    Import-Module ActiveDirectory
}

Get-SecurityList $(Get-ADPrincipalGroupMembership $User)