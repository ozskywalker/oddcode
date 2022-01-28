#requires -Version 2

#
# Courtesy of https://gist.github.com/ijprest/1a0ec4dc734a87fd22bd
#

Add-Type -Name _e9b6b3c331bdc58f488487320803ad89 -namespace _e95bcd88febe44bf44ad6600fdd509e7 -MemberDefinition @'
[DllImport("kernel32",CharSet=CharSet.Unicode)] public static extern int GetPrivateProfileStringW(string section, string key, string def, IntPtr retVal, int size, string filePath);
[DllImport("kernel32",CharSet=CharSet.Unicode)] public static extern int GetPrivateProfileStringW(string section, IntPtr key, string def, IntPtr retVal, int size, string filePath);
[DllImport("kernel32",CharSet=CharSet.Unicode)] public static extern int GetPrivateProfileStringW(IntPtr section, IntPtr key, string def, IntPtr retVal, int size, string filePath);
[DllImport("kernel32",CharSet=CharSet.Unicode)] public static extern long WritePrivateProfileStringW(string section, string key, string val, string filePath);
'@
function Read-IniFile {
    <#
    .SYNOPSIS
        Read an INI file from disk
    .DESCRIPTION
        Reads a file in the standard Windows INI file format and returns a
        hash table with the content.
    .EXAMPLE
        $winini = Read-IniFile -Name "C:\Windows\Win.ini"
    .OUTPUTS
        [Hashtable]
    #>
    [CmdletBinding()]
    param (
        # The filename of the INI file to read
        [Parameter(Mandatory=$true)][string]$Name
    )
    $buffer = [System.Runtime.InteropServices.Marshal]::AllocCoTaskMem(65536)
    try {
        $IniApi = [_e95bcd88febe44bf44ad6600fdd509e7._e9b6b3c331bdc58f488487320803ad89]
        $len = $IniApi::GetPrivateProfileStringW([IntPtr]0, [IntPtr]0, '', $buffer, 65536/2, $Name)
        if($len -le 0) { return }
        $sections = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($buffer, $len-1).Split(0)
        $result = @{}
        foreach($section in $sections) {
            $result[$section] = @{}
            $len = $IniApi::GetPrivateProfileStringW($section, [IntPtr]0, '', $buffer, 65536/2, $Name)
            if($len -gt 0) {
                $keys = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($buffer, $len-1).Split(0)
                foreach($key in $keys) {
                    $len = $IniApi::GetPrivateProfileStringW($section, $key, '', $buffer, 65536/2, $Name)
                    if($len -gt 0) {
                        $result[$section][$key] = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($buffer, $len)
                    }
                }
            }
        }
        return $result
    } finally {
        [System.Runtime.InteropServices.Marshal]::FreeCoTaskMem($buffer)
    }    
}