# Define the necessary C# code for P/Invoke and marshaling
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class BCryptWrapper
{
    const uint CRYPT_LOCAL = 0x00000001;
    const uint NCRYPT_SCHANNEL_INTERFACE = 0x00010002;

    [DllImport("Bcrypt.dll", CharSet = CharSet.Unicode)]
    private static extern int BCryptEnumContextFunctions(
        uint dwTable,
        string pszContext,
        uint dwInterface,
        out uint pcbBuffer,
        out IntPtr ppBuffer
    );

    [DllImport("Bcrypt.dll")]
    private static extern void BCryptFreeBuffer(
        IntPtr pvBuffer
    );

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct CRYPT_CONTEXT_FUNCTIONS
    {
        public uint cFunctions;
        public IntPtr rgpszFunctions; // IntPtr to an array of PWSTRs
    }

    public static int GetCipherSuites(out string[] cipherSuites)
    {
        cipherSuites = null;
        uint pcbBuffer = 0;
        IntPtr ppBuffer = IntPtr.Zero;
        int status = BCryptEnumContextFunctions(
            CRYPT_LOCAL,
            "SSL",
            NCRYPT_SCHANNEL_INTERFACE,
            out pcbBuffer,
            out ppBuffer
        );

        if (status != 0)
        {
            return status;
        }

        if (ppBuffer == IntPtr.Zero)
        {
            return -1; // Error code for null buffer
        }

        try
        {
            CRYPT_CONTEXT_FUNCTIONS contextFunctions = (CRYPT_CONTEXT_FUNCTIONS)Marshal.PtrToStructure(
                ppBuffer, typeof(CRYPT_CONTEXT_FUNCTIONS)
            );

            cipherSuites = new string[contextFunctions.cFunctions];

            int sizeOfIntPtr = Marshal.SizeOf(typeof(IntPtr));

            for (int i = 0; i < contextFunctions.cFunctions; i++)
            {
                IntPtr ptr = Marshal.ReadIntPtr(
                    new IntPtr(contextFunctions.rgpszFunctions.ToInt64() + i * sizeOfIntPtr)
                );

                string functionName = Marshal.PtrToStringUni(ptr);
                cipherSuites[i] = functionName;
            }
        }
        finally
        {
            BCryptFreeBuffer(ppBuffer);
        }

        return status;
    }
}
"@

# Call the C# method from PowerShell
$cipherSuites = $null
$status = [BCryptWrapper]::GetCipherSuites([ref]$cipherSuites)

# Check for errors
if ($status -ne 0) {
    Write-Host "`n**** Error 0x{0:X} returned by BCryptEnumContextFunctions" -f $status
    return
}

if ($cipherSuites -eq $null) {
    Write-Host "`n**** Error: cipherSuites is null"
    return
}

# Output the cipher suites
Write-Host "`n`n Listing Cipher Suites"
foreach ($suite in $cipherSuites) {
    Write-Host $suite
}
