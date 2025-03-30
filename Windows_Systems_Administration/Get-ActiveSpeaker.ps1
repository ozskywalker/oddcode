Add-Type -TypeDefinition @"
    using System.Runtime.InteropServices;
    public class Audio {
        [DllImport("winmm.dll")]
        public static extern int waveOutGetDevCaps(int deviceID, ref WAVEOUTCAPS pwoc, int cbwoc);
        public struct WAVEOUTCAPS {
            public ushort wMid;
            public ushort wPid;
            public uint vDriverVersion;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
            public string szPname;
            public ushort dwFormats;
            public ushort wChannels;
            public ushort wReserved1;
            public ushort dwSupport;
        }
    }
"@

function Get-ActiveSpeaker {
    $deviceID = 0
    $woc = New-Object Audio+WAVEOUTCAPS
    [Audio]::waveOutGetDevCaps($deviceID, [ref]$woc, [Runtime.InteropServices.Marshal]::SizeOf($woc)) | Out-Null
    return $woc.szPname
}

Get-ActiveSpeaker