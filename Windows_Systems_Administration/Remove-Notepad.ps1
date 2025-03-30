foreach ($computer in $computers) {
    $testconnection = Test-Connection $computer -count 1 -ErrorAction SilentlyContinue

    If ( $null -ne $testconnection ) { 
        Write-Host "Working on $computer" |
        Invoke-Command -ComputerName $computer -ScriptBlock { Start-Process -FilePath “C:\Program Files (x86)\Notepad++\uninstall.exe” -ArgumentList "/S" -wait | rmdir “C:\Program Files (x86)\Notepad++" }
    } else { 
        Write-Host "Computer offline" 
    }
}
