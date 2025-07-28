# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a collection of utility scripts and code snippets for system administration, automation, and operational tasks. The repository is organized into functional categories with scripts written primarily in PowerShell, Python, and Bash.

## Repository Structure

- **RMM_Scripts/**: Remote Monitoring and Management scripts for Datto RMM/DRMM
- **Windows_Systems_Administration/**: PowerShell utilities for Windows system management
- **Linux_Systems_Administration/**: Bash scripts for Linux system operations
- **Cloud_DevOps/**: Docker, AWS, and cloud infrastructure automation
- **Network_Security/**: TLS/SSL testing and network security tools
- **Utilities/**: General-purpose utilities and data processing scripts
- **Media_Processing/**: Video/audio conversion and EXIF processing tools
- **Commvault_TSM_Veeam/**: Legacy backup software automation (archival)

## Script Categories and Conventions

### RMM Scripts
RMM scripts follow a dual-pattern architecture for compliance monitoring and enforcement:

#### Monitor Scripts (Get-*Status.ps1)
- **Exit Codes**: Use specific exit codes for different failure states (0=compliant, 1=configuration issue, 2=system error, 3+ specific error types)
- Datto RMM looks for Start Result/End Result for monitor scripts
- Level io looks for the existence of a phrase (ERROR, SUCCESS) for monitor scripts
- **Structured Output for Datto RMM**:
  ```powershell
  Write-Host "<-Start Result->"
  Write-Host "status_key=status_value"
  Write-Host "<-End Result->"
  
  Write-Host "<-Start Diagnostic->"
  Write-Host "Detailed diagnostic information"
  Write-Host "<-End Diagnostic->"
  ```
- **Structured Output for Level.io**:
  ```powershell
  Write-Host "SUCCESS: This thing worked great"
  Write-Host " - additional information"

  Write-Host "ERROR: This thing failed"
  Write-Host " - optional additional info on why it failed"
  ```
- **Banner Functions**: Include system information headers with timestamp, hostname, timezone, and OS details
- **Comprehensive Checking**: Validate all aspects of a configuration (ie. IPv4/IPv6 DNS, DoH/DoT, browser settings, bypass detection)
- **Error Handling**: Try-catch blocks with meaningful error messages and appropriate exit codes

#### Enforcement Scripts (Set-*.ps1)
- **Comprehensive Remediation**: Address all configuration aspects that the monitor checks
- **Backup Existing Settings**: Remove/comment existing configurations before applying new ones
- **Progress Reporting**: Clear output showing each configuration step and its result
- **Error Recovery**: Handle missing commands/features gracefully with fallback options
- **Verification**: Validate changes were applied successfully

#### Configuration Patterns
- **Registry Settings**: Check specific HKLM paths, values, and data types
- **Network Adapters**: Filter active, physical adapters (exclude Bluetooth, Loopback, VirtualBox, WSL, Tailscale)
- **Service States**: Validate Windows services are properly configured and running
- **File System**: Check hosts files, browser profiles, and configuration files
- **Platform Compatibility**: Test for Windows version support and feature availability

#### Common Functions
- **Get-ValidNetAdapters**: Standardized network adapter filtering
- **Write-Banner**: System information output for troubleshooting
- **Test-*Configuration**: Modular functions for specific compliance checks
- **Set-*Configuration**: Corresponding enforcement functions

### PowerShell Scripts
- Most Windows administration scripts use PowerShell 5.1+ compatible syntax, but you may be on older machines (Windows 10, Server 2016, Server 2012) in where checking for what powershell we have can modify your approach.
- Functions often include comprehensive help documentation with `.SYNOPSIS` and `.DESCRIPTION`
- Scripts may include self-elevation capabilities for administrator privileges
- Output is typically formatted for both human readability and programmatic consumption

### Security and Network Scripts
- TLS/SSL validation tools use specific cipher suites and protocol versions
- Scripts include both Windows (PowerShell) and Linux (Bash/cURL) implementations
- Network testing scripts provide detailed output for troubleshooting

## Key Script Functions

### System Information Gathering
- Registry parsing and Windows configuration detection
- Service account enumeration and security group analysis
- Pending reboot detection and system state monitoring

### Automation and Maintenance
- Docker container management and updates
- Windows Update checking and reporting
- File system operations and disk usage analysis

### Cloud and Infrastructure
- AWS Lambda functions for instance management
- Route53 DNS updates and DigitalOcean integration
- Container restart string generation for maintenance

## No Build System
This repository contains standalone scripts that do not require compilation or build processes. Scripts are executed directly using their respective interpreters (PowerShell, Python, Bash).

## Testing
Individual scripts should be tested in isolated environments before deployment. Many RMM scripts include built-in error handling and exit codes for monitoring integration.