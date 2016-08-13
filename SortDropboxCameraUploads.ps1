#
# Many thanks to /u/sysmadmin for this
#
#Creating the structure within the Dropbox folder, following the Dropbox\Photos\Year\Month\Images method of sorting. The root of the Dropbox directory must be set, e.g. I:\Dropbox
$DropboxRoot = "E:\Dropbox"

#Sorts all of the images in Camera Uploads, and sets the earliest year as the "FirstYear" to start creating, then checks the current year to know when to create the new years structure
$FirstPhoto = ((Get-ChildItem -Path "$DropboxRoot\Camera Uploads" | Sort-Object -Property Name) | Select-Object -First 1)
$FirstYear = ($FirstPhoto.Name[0] + $FirstPhoto.Name[1] + $FirstPhoto.Name[2] + $FirstPhoto.Name[3])
$CurrentYear = (Get-Date -UFormat %Y)

#Verifying the Photos directory exists, and creates it if not. This only matters the first time the script is run
If ((Test-Path "$DropboxRoot\Photos") -ne $True){New-Item -Path "$DropboxRoot\" -Name Photos -ItemType Directory}


$FirstYear..$CurrentYear | Foreach {
    If ((Test-Path "$DropboxRoot\Photos\$_") -ne $True)
    {
        New-Item -Path "$DropboxRoot\Photos\" -Name $_ -ItemType Directory
        $i = 1
        while ($i -lt 13)
        {New-Item -ItemType Directory -Name ((Get-Date -UFormat %m -Month $i) + " - " + (Get-Date -UFormat %B -Month $i)) -Path "$DropboxRoot\Photos\$_"; $i++}
    }
}

#Getting all images in the Camera Uploads folder (limit this with (Get-ChildItem * -Include 2014-08-01*) for example, when testing); Excluding .* to skip the Dropbox files
$Pictures = (Get-ChildItem -Path "$DropboxRoot\Camera Uploads" -Exclude .*)

# Loop through all images, move to folder containing the year (indices 0-3), and then the folder containing the month (indices 5-6*) -asterisk required on Move-Item , as the folder names contain the numeric representation as well as the full month name
Foreach ($Pic in $Pictures){
    $YearDirectory = ($Pic.Name[0] + $Pic.Name[1] + $Pic.Name[2] + $Pic.Name[3])
    $MonthDirectory = ($Pic.Name[5] + $Pic.Name[6])
    Move-Item $Pic -Destination "$DropboxRoot\Photos\$YearDirectory\$MonthDirectory*"
    # Verify variables with below:
    #$Destination + "\" + $MonthDirectory
}
