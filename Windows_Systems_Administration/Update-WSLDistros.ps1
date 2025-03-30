# must always run as Current User, never LocalSystem
if ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -eq "NT AUTHORITY\SYSTEM") {
    Write-Error "This script cannot be run as SYSTEM." 
    exit 1
}

# Borrowed from Sven Groot, thank you.
# Original @ https://raw.githubusercontent.com/SvenGroot/WslManagementPS/refs/heads/main/Wsl.psm1

# Represents the state of a distribution.
enum WslDistributionState {
    Stopped
    Running
    Installing
    Uninstalling
    Converting
}

# Represents the format of a distribution to export or import.
enum WslExportFormat {
    Auto
    Tar
    Vhd
}

# Represents a WSL distribution.
class WslDistribution
{
    WslDistribution()
    {
        $this | Add-Member -Name FileSystemPath -Type ScriptProperty -Value {
            return "\\wsl.localhost\$($this.Name)"
        }

        $defaultDisplaySet = "Name","State","Version","Default"

        #Create the default property display set
        $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet("DefaultDisplayPropertySet",[string[]]$defaultDisplaySet)
        $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
        $this | Add-Member MemberSet PSStandardMembers $PSStandardMembers
    }

    [string] ToString()
    {
        return $this.Name
    }

    [string]$Name
    [WslDistributionState]$State
    [int]$Version
    [bool]$Default
    [Guid]$Guid
    [string]$BasePath
    [string]$VhdPath
}

# Provides the versions of various WSL components.
class WslVersionInfo {
    [Version]$Wsl
    [Version]$Kernel
    [Version]$WslG
    [Version]$Msrdc
    [Version]$Direct3D
    [Version]$DXCore
    [Version]$Windows
    [int]$DefaultDistroVersion
}

# Provides the details of online distributions
class WslDistributionOnline {
    [string]$Name
    [string]$FriendlyName
}

# $IsWindows can be used on PowerShell 6+ to determine if we're running on Windows or not.
# On Windows PowerShell 5.1, this variable does not exist so we assume we're running on Windows.
# N.B. We don't assign directly to $IsWindows because that causes a PSScriptAnalyzer warning, since
#      it's an automatic variable. All checks should use $IsWindowsOS instead.
if ($PSVersionTable.PSVersion.Major -lt 6) {
    $IsWindowsOS = $true

} else {
    $IsWindowsOS = $IsWindows
}

if ($IsWindowsOS) {
    $wslPath = "$env:windir\system32\wsl.exe"
    $wslgPath = "$env:windir\system32\wslg.exe"
    if (-not [System.Environment]::Is64BitProcess) {
        # Allow launching WSL from 32 bit powershell
        $wslPath = "$env:windir\sysnative\wsl.exe"
        $wslgPath = "$env:windir\sysnative\wslg.exe"
    }

} else {
    # If running inside WSL, rely on wsl.exe being in the path.
    $wslPath = "wsl.exe"
    $wslgPath = "wslg.exe"
}

function Get-UnresolvedProviderPath([string]$Path)
{
    if ($IsWindowsOS) {
        return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)

    } else {
        # Don't translate on Linux, because absolute Linux paths will never work, and relative ones
        # will.
        return $Path
    }
}

# Helper that will launch wsl.exe, correctly parsing its output encoding, and throwing an error
# if it fails.
function Invoke-Wsl([string[]]$WslArgs, [Switch]$IgnoreErrors)
{
    try {
        $encoding = [System.Text.Encoding]::Unicode
        if ($IsLinux) {
            # If running inside WSL, we can't easily determine the value WSL_UTF8 had in Windows,
            # so set it explicitly. It is set to zero to ensure compatibility with older WSL
            # versions that don't support this variable.
            $originalWslUtf8 = $env:WSL_UTF8
            $originalWslEnv = $env:WSLENV
            $env:WSL_UTF8 = "0"
            $env:WSLENV += ":WSL_UTF8"

        } elseif ($env:WSL_UTF8 -eq "1") {
            $encoding = [System.Text.Encoding]::Utf8
        }

        $hasError = $false
        if ($PSVersionTable.PSVersion.Major -lt 6 -or $PSVersionTable.PSVersion.Major -ge 7) {
            try {
                $oldOutputEncoding = [System.Console]::OutputEncoding
                [System.Console]::OutputEncoding = $encoding
                $output = &$wslPath @WslArgs
                if ($LASTEXITCODE -ne 0) {
                    $hasError = $true
                }

            } finally {
                [System.Console]::OutputEncoding = $oldOutputEncoding
            }

        } else {
            # Using Console.OutputEncoding is broken on PowerShell 6, so use an alternative method of
            # starting wsl.exe.
            # See: https://github.com/PowerShell/PowerShell/issues/10789
            $startInfo = New-Object System.Diagnostics.ProcessStartInfo $wslPath
            $WslArgs | ForEach-Object { $startInfo.ArgumentList.Add($_) }
            $startInfo.RedirectStandardOutput = $true
            $startInfo.StandardOutputEncoding = $encoding
            $process = [System.Diagnostics.Process]::Start($startInfo)
            $output = @()
            while ($null -ne ($line = $process.StandardOutput.ReadLine())) {
                if ($line.Length -gt 0) {
                    $output += $line
                }
            }

            $process.WaitForExit()
            if ($process.ExitCode -ne 0) {
                $hasError = $true
            }
        }

    } finally {
        if ($IsLinux) {
            $env:WSL_UTF8 = $originalWslUtf8
            $env:WSLENV = $originalWslEnv
        }
    }

    # $hasError is used so there's no output in case error action is silently continue.
    if ($hasError) {
        if (-not $IgnoreErrors) {
            throw "Wsl.exe failed: $output"
        }

        return @()
    }

    return $output
}

# Helper to parse the output of wsl.exe --list.
# Also used by the tab completion function.
function Get-WslDistributionHelper()
{
    Invoke-Wsl "--list","--verbose" -IgnoreErrors | Select-Object -Skip 1 | ForEach-Object {
        $fields = $_.Split(@(" "), [System.StringSplitOptions]::RemoveEmptyEntries) 
        $defaultDistro = $false
        if ($fields.Count -eq 4) {
            $defaultDistro = $true
            $fields = $fields | Select-Object -Skip 1
        }

        [WslDistribution]@{
            "Name" = $fields[0]
            "State" = $fields[1]
            "Version" = [int]$fields[2]
            "Default" = $defaultDistro
        }
    }
}

# Helper to get additional distribution properties from the registry.
function Get-WslDistributionProperties([WslDistribution]$Distribution)
{
    $key = Get-ChildItem "hkcu:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss" | Get-ItemProperty | Where-Object { $_.DistributionName -eq $Distribution.Name }
    if ($key) {
        $Distribution.Guid = $key.PSChildName
        $Distribution.BasePath = $key.BasePath
        if ($Distribution.BasePath.StartsWith("\\?\")) {
            $Distribution.BasePath = $Distribution.BasePath.Substring(4)
        }

        if ($Distribution.Version -eq 2) {
            $vhdFile = "ext4.vhdx"
            if ($key.VhdFileName) {
                $vhdFile = $key.VhdFileName
            }

            $Distribution.VhdPath = Join-Path $Distribution.BasePath $vhdFile
        }
    }
}

<#
.EXTERNALHELP
Wsl-help.xml
#>
function Get-WslDistribution
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false, ValueFromPipeline = $true)]
        [Alias("DistributionName")]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]$Name,
        [Parameter(Mandatory=$false)]
        [Switch]$Default,
        [Parameter(Mandatory=$false)]
        [WslDistributionState]$State,
        [Parameter(Mandatory=$false)]
        [int]$Version
    )

    process {
        $distributions = Get-WslDistributionHelper
        if ($Default) {
            $distributions = $distributions | Where-Object {
                $_.Default
            }
        }

        if ($PSBoundParameters.ContainsKey("State")) {
            $distributions = $distributions | Where-Object {
                $_.State -eq $State
            }
        }

        if ($PSBoundParameters.ContainsKey("Version")) {
            $distributions = $distributions | Where-Object {
                $_.Version -eq $Version
            }
        }

        if ($Name.Length -gt 0) {
            $distributions = $distributions | Where-Object {
                foreach ($pattern in $Name) {
                    if ($_.Name -ilike $pattern) {
                        return $true
                    }
                }
                
                return $false
            }
        }

        # The additional registry properties aren't available if running inside WSL.
        if ($IsWindowsOS) {
            $distributions | ForEach-Object {
                Get-WslDistributionProperties $_
            }
        }

        return $distributions
    }
}

<#
.EXTERNALHELP
Wsl-help.xml
#>
function Invoke-WslCommand
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Distribution")]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "DistributionName")]
        [ValidateNotNullOrEmpty()]
        [string]$Command,
        [Parameter(Mandatory = $true, ParameterSetName = "DistributionNameRaw")]
        [Parameter(Mandatory = $true, ParameterSetName = "DistributionRaw")]
        [Switch]$RawCommand,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ParameterSetName = "DistributionName", Position = 1)]
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ParameterSetName = "DistributionNameRaw")]
        [Alias("DistributionName")]
        [ValidateNotNullOrEmpty()]
        [SupportsWildCards()]
        [string[]]$Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "Distribution")]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "DistributionRaw")]
        [WslDistribution[]]$Distribution,
        [Parameter(Mandatory = $false, Position = 2, ParameterSetName = "Distribution")]
        [Parameter(Mandatory = $false, Position = 2, ParameterSetName = "DistributionName")]
        [Parameter(Mandatory = $false, ParameterSetName = "DistributionRaw")]
        [Parameter(Mandatory = $false, ParameterSetName = "DistributionNameRaw")]
        [ValidateNotNullOrEmpty()]
        [string]$User,
        [Parameter(Mandatory = $false)]
        [Alias("wd", "cd")]
        [ValidateNotNullOrEmpty()]
        [string]$WorkingDirectory,
        [Parameter(Mandatory = $false)]
        [Alias("st")]
        [ValidateSet("Standard", "Login", "None")]
        [string]$ShellType,
        [Parameter(Mandatory = $false)]
        [Switch]$System,
        [Parameter(Mandatory = $false)]
        [Switch]$Graphical,
        [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true, ParameterSetName = "DistributionRaw")]
        [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true, ParameterSetName = "DistributionNameRaw")]
        [ValidateNotNullOrEmpty()]
        [string[]]$Remaining
    )

    process {
        if ($Distribution) {
            $distros = $Distribution

        } else {
            if ($Name) {
                $distros = Get-WslDistribution $Name
                if (-not $distros) {
                    throw "There is no distribution with the name '$Name'."
                }

            } else {
                $distros = Get-WslDistribution -Default
                if (-not $distros) {
                    throw "There is no default distribution."
                }
            }

        }

        $distros | ForEach-Object {
            $wslArgs = @("--distribution", $_.Name)
            if ($System) {
                $wslArgs += "--system"
            }

            if ($User) {
                $wslArgs += @("--user", $User)
            }

            if ($WorkingDirectory) {
                if (-not $WorkingDirectory.StartsWith("~") -and -not $WorkingDirectory.StartsWith("/")) {
                    $WorkingDirectory = Get-UnresolvedProviderPath $WorkingDirectory
                }

                $wslArgs += @("--cd", $WorkingDirectory)
            }

            if ($ShellType) {
                $wslArgs += @("--shell-type", $ShellType.ToLowerInvariant())
            }

            if ($RawCommand) {
                $wslArgs += "--"
                $wslArgs += $Remaining

            } else {
                # Invoke /bin/sh so the whole command can be passed as a single argument.
                $wslArgs += @("/bin/sh", "-c", $Command)
            }

            if ($PSCmdlet.ShouldProcess($_.Name, "Invoke Command; args: $wslArgs")) {
                if ($Graphical) {
                    &$wslgPath $wslArgs

                } else {
                    &$wslPath $wslArgs
                }
                if ($LASTEXITCODE -ne 0) {
                    # Note: this could be the exit code of wsl.exe, or of the launched command.
                    throw "Wsl.exe returned exit code $LASTEXITCODE"
                }    
            }
        }
    }
}

<#
.EXTERNALHELP
Wsl-help.xml
#>
function Enter-WslDistribution
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ParameterSetName = "DistributionName", Position = 0)]
        [Alias("DistributionName")]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "Distribution")]
        [WslDistribution]$Distribution,
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$User,
        [Parameter(Mandatory = $false)]
        [Alias("wd", "cd")]
        [ValidateNotNullOrEmpty()]
        [string]$WorkingDirectory,
        [Parameter(Mandatory = $false)]
        [Alias("st")]
        [ValidateSet("Standard", "Login")]
        [string]$ShellType,
        [Parameter(Mandatory = $false)]
        [Switch]$System
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq "Distribution") {
            $Name = $Distribution.Name
        }

        $wslArgs = @()
        if ($Name) {
            $wslArgs = @("--distribution", $Name)
        }

        if ($System) {
            $wslArgs += "--system"
        }

        if ($User) {
            $wslArgs = @("--user", $User)
        }

        if ($WorkingDirectory) {
            if (-not $WorkingDirectory.StartsWith("~") -and -not $WorkingDirectory.StartsWith("/")) {
                $WorkingDirectory = Get-UnresolvedProviderPath $WorkingDirectory
            }

            $wslArgs += @("--cd", $WorkingDirectory)
        }

        if ($ShellType) {
            $wslArgs += @("--shell-type", $ShellType.ToLowerInvariant())
        }

        if ($PSCmdlet.ShouldProcess($Name, "Enter WSL; args: $wslArgs")) {
            &$wslPath $wslArgs
            if ($LASTEXITCODE -ne 0) {
                # Note: this could be the exit code of wsl.exe, or of the shell.
                throw "Wsl.exe returned exit code $LASTEXITCODE"
            }
        }
    }
}

#Invoke-WslCommand -User root -Command "cat /etc/lsb-release" -DistributionName $((Get-WslDistribution)[0])

$rawDistros = Get-WslDistribution
$excludedDistros = @("rancher-desktop", "rancher-desktop-data")

$filteredDistros = $rawDistros | Where-Object { $excludedDistros -notcontains $_.Name }
foreach ($distro in $filteredDistros) {
    Write-Host "************************"
    Write-Host "*** Updating $distro ***"
    Write-Host "************************"

    Invoke-WslCommand -User root -Command "DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y upgrade && DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade && DEBIAN_FRONTEND=noninteractive apt-get -y autoremove" -DistributionName $distro

    Write-Host "*******************************"
    Write-Host "*** Invoke done for $distro ***"
    Write-Host "*******************************"
}
