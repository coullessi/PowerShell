# Azure Arc & Microsoft Defender for Endpoint Prerequisites Validator

## Overview

The `Test-AzureArcPrerequisite` function provides comprehensive validation of all technical requirements for Azure Arc onboarding and Microsoft Defender for Endpoint (MDE) integration through Microsoft Defender for Cloud (Defender for Servers).

## Key Features

### 🔍 Comprehensive Validation Categories

#### 1. **Operating System Requirements**
- Windows version compatibility (Windows 10/11, Server 2012 R2+)
- Windows architecture support (x64, ARM64)
- System drive space requirements (minimum 2GB free)
- Memory requirements (minimum 4GB RAM)
- Administrative privileges validation

#### 2. **PowerShell & Execution Environment**
- PowerShell version compatibility (requires 5.1+)
- .NET Framework version (4.7.2+ required)
- PowerShell execution policy configuration
- Windows Management Framework (WMF) version
- Azure PowerShell (Az) module availability and version

#### 3. **Network Connectivity & Security**
- Comprehensive Azure Arc endpoint connectivity testing
- Microsoft Defender for Cloud endpoint connectivity
- TLS 1.2+ protocol validation and cipher suite compatibility
- Firewall and proxy configuration validation
- DNS resolution testing for critical domains
- Internet connectivity speed and latency testing
- Certificate store validation for Azure root certificates

#### 4. **Azure Arc Agent Requirements**
- Azure Connected Machine Agent installation status and version
- Agent service status and health validation
- Agent configuration file integrity
- Required Windows services status (WinRM, Windows Update, etc.)
- Local System account permissions validation

#### 5. **Microsoft Defender Integration**
- Microsoft Defender for Endpoint service compatibility
- Windows Defender Antivirus status and configuration
- Real-time protection and cloud protection settings
- Microsoft Defender for Cloud extension status
- Security Center workspace connectivity
- Log Analytics workspace connectivity validation

#### 6. **Windows System Requirements**
- Windows Update service availability
- Windows Management Instrumentation (WMI) functionality
- Windows Event Log service status
- Required Windows features installation
- System file integrity validation
- Registry permissions and configuration

#### 7. **Security & Compliance**
- Windows Security settings validation
- Group Policy conflicts detection
- Antivirus exclusions recommendations
- Windows Defender Application Control (WDAC) compatibility
- Secure Boot and TPM status (if available)

### 🚀 Enterprise Features

- **Multi-Device Batch Processing**: Validate multiple devices simultaneously
- **Automated Remediation Scripts**: Generate PowerShell scripts to fix identified issues
- **Flexible Validation Modes**: Basic, Critical, or Comprehensive testing levels
- **Detailed Reporting**: Comprehensive logs and consolidated reports
- **Network Testing Options**: Include optional endpoints and TLS validation
- **Remote Device Support**: Test devices remotely via PowerShell remoting

## Quick Start

### Basic Usage
```powershell
Test-AzureArcPrerequisite
```

### Advanced Usage
```powershell
Test-AzureArcPrerequisite -DeviceListPath "C:\devices.txt" -ValidateDefenderConfiguration -CheckSystemRequirements -GenerateRemediationScript
```

### Network-Focused Testing
```powershell
Test-AzureArcPrerequisite -NetworkTestMode Comprehensive -IncludeOptionalEndpoints -TestTLSVersion -ShowDetailedNetworkResults
```

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `DeviceListPath` | Path to file containing device names (one per line) | Prompted |
| `Force` | Skip user consent prompts | False |
| `NetworkTestMode` | Level of network testing: Basic, Critical, Comprehensive | Comprehensive |
| `IncludeOptionalEndpoints` | Include optional Azure Arc endpoints in testing | False |
| `TestTLSVersion` | Perform TLS version validation on connections | False |
| `ShowDetailedNetworkResults` | Display detailed network connectivity results | False |
| `NetworkLogPath` | Path to save detailed network connectivity logs | None |
| `SkipInteractiveChecks` | Skip checks requiring user interaction | False |
| `ValidateDefenderConfiguration` | Deep validation of Defender for Endpoint configuration | False |
| `CheckSystemRequirements` | Validate hardware and system requirements | False |
| `GenerateRemediationScript` | Generate PowerShell remediation scripts | False |

## Device List File Format

Create a text file with device names (one per line):

```text
# Azure Arc Device List Configuration File
# Lines starting with # are comments

# Production servers
server01.contoso.com
server02.contoso.com

# Workstations
workstation-01
workstation-02

# Local testing
localhost
```

## Output Examples

### Successful Validation
```
✅ COMPREHENSIVE PREREQUISITES CHECK COMPLETED!
📊 Comprehensive validation completed for 3 device(s)
📁 Detailed results saved to: AzureArc_MDE_Checks_Consolidated.log

🎯 NEXT STEPS:
1. Review the comprehensive results above for each device
2. Address any critical errors or warnings identified
3. Run generated remediation scripts if available
4. Proceed with Azure Arc onboarding for ready devices
5. Enable Microsoft Defender for Servers in Azure Security Center
```

### Issues Detected
```
🚨 CRITICAL ISSUES (Must Fix Before Arc Onboarding):
• Network Connectivity
  Affected devices: server01
  Impact: Blocks Azure Arc onboarding process
• Windows Services
  Affected devices: workstation-02
  Impact: Blocks Azure Arc onboarding process

💡 RECOMMENDED REMEDIATION ACTIONS:
1. Configure firewall to allow outbound HTTPS (TCP 443) to failed URLs
2. Verify DNS resolution for failed domains
3. Configure proxy server if required
4. Start required Windows services
```

## Network Connectivity Testing

### Tested Endpoints
- **Core Azure Endpoints**: management.azure.com, login.microsoftonline.com
- **Azure Arc Service**: gbl.his.arc.azure.com, agentserviceapi.guestconfiguration.azure.com
- **Downloads & Updates**: download.microsoft.com, packages.microsoft.com
- **Optional Endpoints**: Azure Monitor, Log Analytics, Defender for Cloud

### Test Modes
- **Basic**: Core Azure Arc endpoints only (fastest)
- **Critical**: Essential endpoints for basic functionality
- **Comprehensive**: All required and optional endpoints (recommended)

## Requirements

### System Requirements
- **PowerShell**: Version 5.1 or later
- **Operating System**: Windows 10 1709+, Windows 11, Windows Server 2012 R2+
- **Network**: Internet connectivity to Azure endpoints
- **Permissions**: Administrative privileges recommended

### Azure Requirements
- **Azure Subscription**: Valid subscription with appropriate permissions
- **Azure PowerShell**: Az module (automatically installed if missing)
- **Resource Providers**: Registered for Azure Arc (script can register)

## Enterprise Deployment

### Large-Scale Validation
1. Create device list files for different environments
2. Use `-Force` parameter for automated execution
3. Configure network logging with `-NetworkLogPath`
4. Generate remediation scripts with `-GenerateRemediationScript`
5. Review consolidated reports for deployment planning

### CI/CD Integration
```powershell
# Automated validation in deployment pipeline
Test-AzureArcPrerequisite -DeviceListPath "production-servers.txt" -Force -GenerateRemediationScript -CheckSystemRequirements
```

## Troubleshooting

### Common Issues
- **Network connectivity failures**: Check firewall rules and DNS resolution
- **PowerShell execution policy**: Set to RemoteSigned or Bypass
- **Azure authentication**: Ensure account has appropriate permissions
- **WinRM connectivity**: Enable PowerShell remoting on target devices

### Support
- **Documentation**: Complete help available via `Get-Help Test-AzureArcPrerequisite -Full`
- **Verbose Output**: Use `-Verbose` for detailed execution information
- **Logs**: Review consolidated log files for detailed diagnostics

## Version History

### v2.0.0 (Current)
- ✅ Comprehensive validation across 8 categories
- ✅ Multi-device batch processing
- ✅ Enterprise-grade reporting
- ✅ Automated remediation script generation
- ✅ Flexible network testing modes
- ✅ TLS validation capabilities
- ✅ Enhanced error handling and user experience

---

**Author**: Lessi Coulibaly  
**Organization**: Less-IT (AI and CyberSecurity)  
**Website**: https://lessit.net
