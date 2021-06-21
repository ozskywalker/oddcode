# Inspiration from https://gist.github.com/d4rkeagle65/b9bc42a26be44a6d66c4858a4c3bc944 by d4rkeagle65
# And taken from https://gist.github.com/Diagg/73275dff62381eb85ad96c6fc15fea81
# Output to object by Diagg/OSD-Couture.com
$Dsregcmd = New-Object PSObject ; Dsregcmd /status | Where {$_ -match ' : '}|ForEach {$Item = $_.Trim() -split '\s:\s'; $Dsregcmd|Add-Member -MemberType NoteProperty -Name $($Item[0] -replace '[:\s]','') -Value $Item[1] -EA SilentlyContinue}
# to vue full objest type : $Dsregcmd
# to vue property TenantID : $Dsregcmd.TenantId