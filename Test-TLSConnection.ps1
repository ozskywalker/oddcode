<#
.SYNOPSIS
    Tests TLS protocols on a given host and port.

.DESCRIPTION
    This script tests the specified TLS protocols on a given host and port by attempting to establish a connection and performing a TLS handshake.

.PARAMETER testhost
    The hostname or IP address of the server to test.

.PARAMETER port
    The port number to connect to (default is 445).

.PARAMETER protocols
    The list of TLS protocols to test (default is Tls12, Tls11. Tls13 is optional.).

.EXAMPLE
    .\Test-TLSConnection.ps1 -Server example.com -Port 443 -Protocols Tls12,Tls13

    Tests TLS 1.2 and TLS 1.3 protocols on example.com at port 443.

.EXAMPLE
    .\Test-TLSConnection.ps1 -Server 192.168.1.1

    Tests default TLS protocols on 192.168.1.1 at port 443.
#>

[CmdletBinding()]
Param(
    [string]$Server,
    [int]$Port = 443,
    [Net.SecurityProtocolType[]]$Protocols = @('Tls12','Tls11')
)

# Initialize counters
$global:successCount = 0
$global:partialSuccessCount = 0
$global:failureCount = 0

function Show-Usage {
    Write-Host "Usage: .\Test-TLSConnection.ps1 -Server <hostname> [-Port <port>] [-Protocols <protocols>]"
    Write-Host
    Write-Host "Parameters:"
    Write-Host "  -Server   The hostname or IP address of the server to test."
    Write-Host "  -Port       The port number to connect to (default is 443)."
    Write-Host "  -Protocols  The list of TLS protocols to test (default is Tls12,Tls11. Tls13 is optional.)."
    Write-Host
    Write-Host "Examples:"
    Write-Host "  .\Test-TLSConnection.ps1 -Server example.com -Port 443 -Protocols Tls12,Tls13"
    Write-Host "  .\Test-TLSConnection.ps1 -Server 192.168.1.1"
}

# Validate parameters
$ErrorFound = $false

if (-not $Server) {
    Write-Host "Error: You must specify a hostname or IP address to test."
    $ErrorFound = $true
}

if ($Port -lt 1 -or $Port -gt 65535) {
    Write-Host "Error: Port must be between 1 and 65535."
    $ErrorFound = $true
}

# Validate protocols
$validProtocols = @('Tls13','Tls12','Tls11')
foreach ($protocol in $Protocols) {
    if ($validProtocols -notcontains $protocol.ToString()) {
        Write-Host "Error: Invalid protocol '$protocol'. Valid protocols are: $($validProtocols -join ', ')"
        $ErrorFound = $true
    }
}

if ($ErrorFound) {
    Show-Usage
    exit 1
}

# Function to test connection using a specific TLS version
function Test-TlsVersion {
    param (
        [string]$Server,
        [int]$Port,
        [System.Net.SecurityProtocolType]$Protocol
    )
    try {
        # Set the desired TLS version
        [System.Net.ServicePointManager]::SecurityProtocol = $Protocol

        # Create a TCP client and connect to the server
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($Server, $Port)

        # Get the network stream and wrap it in an SslStream for TLS/SSL handshake
        $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, { $true })

        # Attempt to authenticate as client
        $sslStream.AuthenticateAsClient($Server)

        # Check the negotiated protocol version and the certificate
        $negotiatedProtocol = $sslStream.SslProtocol
        $certificate = $sslStream.RemoteCertificate

        # Compare the desired protocol with the negotiated protocol
        if ([int]$protocol -eq [int]$negotiatedProtocol) {
            $global:successCount++
            Write-Host "[*] $($protocol) -> Success! $($Server):$($Port)"
            Write-Host "  Requested Protocol     : $($protocol)"
            Write-Host "  Negotiated Protocol    : $($negotiatedProtocol)"
            Write-Host "  Certificate Subject    : $($certificate.Subject)"
            Write-Host "  Certificate Issuer     : $($certificate.Issuer)"
            Write-Host "  Certificate Thumbprint : $($certificate.Thumbprint)"
            Write-Host
        }
        else {
            $global:partialSuccessCount++
            # Output the result indicating server forced protocol upgrade
            Write-Host "[?] $($protocol) -> Partial success: $($Server):$($Port)" 
            Write-Host "  Requested Protocol     : $($protocol)"
            Write-Host "  Negotiated Protocol    : $($negotiatedProtocol)"
            Write-Host "  Certificate Subject    : $($certificate.Subject)"
            Write-Host "  Certificate Issuer     : $($certificate.Issuer)"
            Write-Host "  Certificate Thumbprint : $($certificate.Thumbprint)"
            Write-Host
        }

        # Close the streams and client
        $sslStream.Close()
        $tcpClient.Close()
    }
    catch {
        $global:failureCount++
        Write-Host "[x] $($Protocol) -> Failed: connection / TLS handshake failed."
        Write-Host "    Exception Type    : $($_.Exception.GetType().FullName)"
        Write-Host "    Exception Message : $($_.Exception.Message)"
        if ($_.Exception.InnerException) {
            Write-Host "    Inner Exception Type    : $($_.Exception.InnerException.GetType().FullName)"
            Write-Host "    Inner Exception Message : $($_.Exception.InnerException.Message)"
        }
        Write-Host
    }
}


# Loop through the list of protocols to test
foreach ($protocol in $Protocols) {
    Test-TlsVersion -Server $Server -Port $Port -Protocol $protocol
}

# Provide a summary of the results
Write-Host "`n==== Summary ===="
Write-Host "  Successes         : $successCount"
Write-Host "  Partial Successes : $partialSuccessCount"
Write-Host "  Failures          : $failureCount"
