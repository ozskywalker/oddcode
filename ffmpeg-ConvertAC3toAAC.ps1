param(
[parameter(Mandatory = $True)][bool]$dryrun = $True,
[parameter(Mandatory = $True)][string]$scan,
[parameter(Mandatory = $True)][string]$tmpdir
)

Get-ChildItem $scan -Recurse | Where-Object {
    $cmdstr = "cmd /c C:\ffmpeg\bin\ffprobe.exe -show_streams `"" + $_.FullName + "`" 2>&1"
    $result = Invoke-Expression $cmdstr

    foreach ($element in $result) {
        if ($element -eq "codec_name=ac3") {
            if($dryrun) {
                Write-Host $_.FullName
            } else {
                $tmpfile = $tmpdir + "\temp.mkv"
                $cmdstr = "cmd /c C:\ffmpeg\bin\ffmpeg.exe -i `"" + $_.FullName + "`" -vcodec copy -strict -2 -acodec aac " + $tmpfile
                $result = Invoke-Expression $cmdstr
                $tmpfile = 
                Move-Item $tmpfile $_.FullName -Force
            }
        }
    }
}