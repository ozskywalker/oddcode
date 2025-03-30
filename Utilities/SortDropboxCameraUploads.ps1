# Many thanks to /u/sysmadmin for this
# Added OSX support

$DryRun = $False

#Creating the structure within the Dropbox folder, following the Dropbox\Photos\Year\Month\Images method of sorting. The root of the Dropbox directory must be set, e.g. I:\Dropbox
If ($IsWindows -eq $True) {
    $DropboxRoot = "E:\Dropbox"
    $DropboxCameraPath = $DropboxRoot + "\Camera Uploads\"
    $DropboxPhotos = $DropboxRoot + "\Photos\"
} elseif ($IsMacOS -eq $True) {
    $DropboxRoot = "/Users/sky/Dropbox"
    $DropboxCameraPath = $DropboxRoot + "/Camera Uploads/"
    $DropboxPhotos = $DropboxRoot + "/Photos/"
} else {
    Write-Host "ERROR: Platform not Windows or macOS!"
    Exit
}

#Sorts all of the images in Camera Uploads, and sets the earliest year as the "FirstYear" to start creating, then checks the current year to know when to create the new years structure
$FirstPhoto = ((Get-ChildItem -Path "$DropboxCameraPath" | Sort-Object -Property Name) | Select-Object -First 1)
$FirstYear = ($FirstPhoto.Name[0] + $FirstPhoto.Name[1] + $FirstPhoto.Name[2] + $FirstPhoto.Name[3])
$CurrentYear = (Get-Date -UFormat %Y)

#Verifying the Photos directory exists, and creates it if not. This only matters the first time the script is run
If ((Test-Path $DropboxPhotos) -ne $True) {
    New-Item -Path "$DropboxRoot" -Name "Photos" -ItemType Directory
}

$FirstYear..$CurrentYear | Foreach {
    $YearPath = $DropboxPhotos + $_
    # Check if path exists, if not, let's create it
    If ((Test-Path $YearPath) -ne $True)
    {
        Write-Host "[*] Creating directory" $_
        If($DryRun) {
            Write-Host "DRYRUN: would have created $YearPath"
        } else {
            New-Item -Path "$DropboxPhotos" -Name $_ -ItemType Directory
            $i = 1
            while ($i -lt 13) {
                New-Item -ItemType Directory -Name ((Get-Date -UFormat %m -Month $i) + " - " + (Get-Date -UFormat %B -Month $i)) -Path "$YearPath"; $i++
            }
        }
    }
}

#Getting all images in the Camera Uploads folder (limit this with (Get-ChildItem * -Include 2014-08-01*) for example, when testing); Excluding .* to skip the Dropbox files
$Pictures = (Get-ChildItem -Path "$DropboxCameraPath" -Exclude .*)
Write-Host "[*]" $Pictures.length.tostring() "pictures found in $DropboxCameraPath"

# Loop through all images, move to folder containing the year (indices 0-3), and then the folder containing the month (indices 5-6*) -asterisk required on Move-Item , as the folder names contain the numeric representation as well as the full month name
Foreach ($Pic in $Pictures){
    $temp = $Pic.Name.Split('-')
    $YearDirectory = $temp[0]
    $MonthDirectory = $temp[1]

    if($MonthDirectory.length -lt 2 -Or $MonthDirectory.length -gt 2) {
        Write-Host "ERROR: Can't process $Pic"
    } else {
        $MonthDirectory = ((Get-Date -UFormat %m -Month $MonthDirectory) + " - " + (Get-Date -UFormat %B -Month $MonthDirectory))
        Write-Host "[*] Moving $pic into $DropboxPhotos -> $YearDirectory -> $MonthDirectory"

        if($DryRun) {
            Write-Host "DRYRUN: Would have moved $pic into $DropboxPhotos$YearDirectory/$MonthDirectory/"
        } else {
            Try {
                If ($IsWindows -eq $True) {
                    Move-Item "$Pic" -Destination "$DropboxPhotos$YearDirectory\$MonthDirectory/"
                } elseif ($IsMacOS -eq $True) {
                    Move-Item "$Pic" -Destination "$DropboxPhotos$YearDirectory/$MonthDirectory/"
                } else {
                    Write-Host "ERROR: Platform not Windows or macOS! (Should not fail here either!)"
                    Exit
                }
                # Verify variables with below:
                #$Destination + "\" + $MonthDirectory
            }
            Catch {
                Write-Host "ERROR moving file"
                Write-Host $_.Exception.Message
                Write-Host $_.Exception.ItemName
                Exit
            }
        }
    }
}
