# DefenderEndpointDeployment PowerShell Module

> **Enterprise-Grade Azure Arc Device Deployment & Microsoft Defender Endpoint Integration**

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Azure Arc](https://img.shields.io/badge/Azure%20Arc-Enabled-green.svg)](https://azure.microsoft.com/en-us/services/azure-arc/)
[![Version](https://img.shields.io/badge/Version-1.1.0-brightgreen.svg)](#)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 📋 Overview

The **DefenderEndpointDeployment** module provides a comprehensive, enterprise-grade PowerShell solution for managing Azure Arc-enabled servers and Microsoft Defender for Endpoint (MDE) integration across large-scale environments. This module delivers professional-quality automation tools with an intuitive interactive interface, extensive validation capabilities, and robust error handling for mission-critical deployments.

### 🌟 What's New in v2.0.0

- 🔄 **Streamlined Workflow** - Consolidated functions for better user experience
- ⚡ **Automated Resource Provider Registration** - Now integrated into prerequisites testing
- 🏗️ **Unified Azure Arc Deployment** - Service principal creation, agent installation, and Group Policy deployment combined
- 📋 **Simplified Menu Interface** - Reduced from 8 to 3 main functions for easier navigation
- � **Enhanced Function Integration** - Better workflow efficiency with fewer manual steps
- 📚 **Updated Documentation** - Comprehensive updates reflecting the new structure

### 🚀 Quick Start

**Use the interactive entry point for the best experience:**

```powershell
# Import and run the module
Import-Module DefenderEndpointDeployment
Deploy-DefenderForServers
```

The interactive interface provides a professional menu system with:
- 🎯 **Numbered Commands** (1-7) for all major operations
- 📖 **Built-in Help System** (H) with detailed documentation
- ✅ **Confirmation Prompts** for all operations
- 🔄 **User-Controlled Navigation** with "Press any key to continue"

### 🎯 Key Features

#### 🎮 Interactive Interface
- **Professional Menu System**: Clean, organized interface with ASCII art
- **Color-Coded Output**: Visual indicators for success, warnings, and errors
- **Confirmation Prompts**: User confirmation for all destructive operations
- **Built-in Help**: Comprehensive help system accessible via 'H' command

#### 🚀 Azure Arc Deployment
- **Automated Device Registration**: Streamlined Azure Arc onboarding process
- **Multi-Device Support**: Bulk operations across enterprise environments
- **Service Principal Management**: Automated SP creation with proper permissions
- **Group Policy Integration**: Enterprise-scale deployment via GPO

#### ✅ Prerequisites Validation
- **Comprehensive System Checks**: PowerShell version, execution policy, modules
- **Multi-Device Validation**: Parallel checking across device lists
- **Network Connectivity Testing**: Detailed Azure endpoint validation
- **TLS 1.2+ Verification**: Security protocol compliance checking

#### 🔍 Diagnostics & Troubleshooting
- **Azure Arc Agent Diagnostics**: Comprehensive validation and log collection
- **Connectivity Testing**: Detailed Azure endpoint and network validation
- **Automated Log Archives**: ZIP file creation for support scenarios
- **Progress Animations**: Smooth, professional progress indicators
- **Silent Mode Support**: Automated execution for scripting scenarios

#### 🔐 Security & Authentication
- **Azure Authentication**: Secure session management with auto-login
- **Permission Validation**: Role and subscription permission checks
- **Service Principal Creation**: Automated SP setup with least-privilege principles
- **Credential Management**: Secure handling of authentication tokens

#### 📊 Advanced Reporting
- **Consolidated Results**: Unified reporting across all devices
- **Priority-Based Recommendations**: Actionable guidance by severity
- **Detailed Diagnostics**: Device-by-device analysis with remediation steps
- **Export Capabilities**: Results export for compliance and documentation

#### 🛡️ Enterprise Features
- **Robust Error Handling**: Comprehensive error management with recovery options
- **Logging**: Detailed activity logging for audit and troubleshooting
- **Scalability**: Designed for large enterprise environments
- **Compliance**: Built-in compliance checks and reporting

## 🏢 Author & Organization

- **👨‍💻 Author**: Lessi Coulibaly
- **🏢 Organization**: Less-IT (AI and CyberSecurity)
- **🌐 Website**: [https://lessit.net](https://lessit.net)
- **📧 Contact**: [Contact via website](https://lessit.net)

## 📦 Installation

### Method 1: PowerShell Gallery (Recommended)

```powershell
# Install from PowerShell Gallery
Install-PSResource DefenderEndpointDeployment

# Update to latest version
Update-PSResource DefenderEndpointDeployment

# Import the module
Import-Module DefenderEndpointDeployment
```

### Method 2: Manual Installation

```powershell
# Clone the repository (when available)
git clone <YOUR-GITHUB-REPOSITORY-URL>

# Import the module
Import-Module .\DefenderEndpointDeployment\DefenderEndpointDeployment.psd1
```

### Prerequisites

- **PowerShell 5.1+** or **PowerShell Core 7.0+**
- **Azure PowerShell Module** (Az)
- **Azure Account** with appropriate permissions
- **Internet Connectivity** for Azure endpoint validation
- **Administrative Privileges** on target devices

## 🎮 Usage Guide

### Interactive Interface

The primary entry point provides a professional interactive menu:

```powershell
Deploy-DefenderForServers
```

**Available Commands:**
```
1 - Test Azure Arc Prerequisites                   (Test-AzureArcPrerequisite)
   • Validates Azure prerequisites and network connectivity
   • Registers required Azure resource providers automatically
   • Generates detailed prerequisite and connectivity reports

2 - Create Azure Arc Device                        (New-AzureArcDevice)
   • Complete Azure Arc deployment with Group Policy
   • Creates service principals with appropriate permissions
   • Downloads and installs Azure Connected Machine Agent
   • Configures Group Policy objects for automated deployment

3 - Run Azure Arc Diagnostics                     (Get-AzureArcDiagnostics)
   • Runs comprehensive Azure Arc diagnostics
   • Collects agent logs and system information
   • Generates diagnostic reports for troubleshooting

H - Show Help Documentation
Q - Exit
```

### ⚡ Workflow Changes in v2.0.0

**Streamlined Process:** The module has been restructured for better workflow efficiency:

- **Resource Provider Registration** is now automatically integrated into the prerequisites testing function
- **Service Principal Creation**, **Agent Installation**, and **Group Policy Deployment** are now combined in the `New-AzureArcDevice` function for a streamlined workflow
- **Simplified Menu** with only 3 main functions for easier navigation

### Command Reference

#### 1️⃣ Test Azure Arc Prerequisites (Enhanced)
```powershell
Test-AzureArcPrerequisite
    [-DeviceListPath <String>]           # Path to file containing device names
    [-Force]                             # Skip user consent prompts
    [-NetworkTestMode <String>]          # Network testing mode (Basic, Comprehensive)
    [-IncludeOptionalEndpoints]          # Include optional Azure endpoints in testing
    [-TestTLSVersion]                    # Test TLS version compatibility
    [-ShowDetailedNetworkResults]        # Show detailed network test results
    [-NetworkLogPath <String>]           # Custom network log file path
```

**Key Features:**
- Comprehensive prerequisites validation for Azure Arc and MDE integration
- **Automatic Azure resource provider registration** (eliminates manual step)
- Network connectivity testing to Azure Arc endpoints
- Multi-device support with detailed reporting
- Enhanced security and system requirements validation

**Example:**
```powershell
# Interactive prerequisites check with comprehensive validation
Test-AzureArcPrerequisite

# Test specific devices with enhanced network testing
Test-AzureArcPrerequisite -DeviceListPath 'C:\devices.txt' -NetworkTestMode Comprehensive -IncludeOptionalEndpoints
```

#### 2️⃣ Create Azure Arc Device (Complete Deployment)
```powershell
New-AzureArcDevice
    [-ResourceGroupName <String>]    # Azure resource group name (optional)
    [-Location <String>]             # Azure region (optional)
    [-SharePath <String>]            # Remote share path for Group Policy (optional)
    [-Force]                         # Skip confirmation prompts
```

**Integrated Functionality:**
- **Service Principal Creation** - Automatically creates service principals with appropriate permissions
- **Agent Installation** - Downloads and optionally installs Azure Connected Machine Agent locally
- **Group Policy Configuration** - Creates and deploys Group Policy objects for enterprise deployment
- File share setup for Group Policy deployment
- OU linking and configuration management

**Example:**
```powershell
# Interactive complete Azure Arc deployment
New-AzureArcDevice

# Automated deployment with specific parameters
New-AzureArcDevice -ResourceGroupName "rg-azurearc-prod" -Location "eastus" -Force
```

#### 3️⃣ Run Azure Arc Diagnostics
```powershell
Get-AzureArcDiagnostics
    [-LogPath <String>]              # Custom diagnostic log path
    [-DeviceListPath <String>]       # Path to file containing device names
    [-SkipPrompt]                    # Skip user prompts
    [-CollectLogs]                   # Collect comprehensive logs
    [-CreateArchive]                 # Create ZIP archive for support
```

**Example:**
```powershell
# Interactive diagnostics collection
Get-AzureArcDiagnostics

# Automated diagnostics with custom path
Get-AzureArcDiagnostics -LogPath 'C:\ArcDiagnostics' -SkipPrompt -CollectLogs
```

#### 4️⃣ Interactive Menu System
```powershell
Deploy-DefenderForServers
```

**Features:**
- Interactive menu-driven interface for the entire workflow
- Streamlined 3-option menu system
- Built-in help and guidance
- Error handling and validation

**Example:**
```powershell
# Launch interactive menu system
Deploy-DefenderForServers
```

## 📊 Output Examples

### Connectivity Test Results
```
✅ Azure Arc Connectivity Test Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Endpoint: https://management.azure.com
Status: ✅ Connected (Response: 200ms)
TLS Version: TLS 1.3 ✅

Endpoint: https://login.microsoftonline.com  
Status: ✅ Connected (Response: 156ms)
TLS Version: TLS 1.3 ✅

Summary: All 8 endpoints validated successfully
Recommendation: System ready for Azure Arc deployment
```

### Prerequisites Test Results
```
🔍 Azure Arc Prerequisites Validation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Device: SERVER01
  ✅ PowerShell Version: 5.1.19041.1682
  ✅ Execution Policy: RemoteSigned  
  ✅ Azure Module: Installed (Az 8.3.0)
  ✅ Network Connectivity: All endpoints reachable
  ✅ TLS Configuration: TLS 1.2+ enabled

Overall Status: ✅ READY FOR DEPLOYMENT
```

### Diagnostics Test Results
```
🔍 Azure Arc Agent Diagnostics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Agent Status: Azure Arc agent is functional
✅ Connectivity: All Azure endpoints accessible
✅ Extensions: 3 extensions installed and healthy
🔄 Log Collection: Creating comprehensive archive...

[Initial Phase] [████████████████████████████████████████] 100%
📁 Logs saved: C:\ArcAgentLogs\ArcDiagnostics_20250720_143052.zip
```

## 🔧 Advanced Configuration

### Environment Variables
```powershell
# Set default Azure subscription
$env:AZURE_SUBSCRIPTION_ID = "your-subscription-id"

# Set default resource group
$env:ARC_RESOURCE_GROUP = "your-resource-group"

# Set default region
$env:ARC_LOCATION = "eastus"
```

### Custom Device Lists
Create a device list file for bulk operations:

```powershell
# devices.txt
SERVER01
SERVER02  
SERVER03
WORKSTATION01
WORKSTATION02

# Use with commands
$devices = Get-Content .\devices.txt
Test-AzureArcPrerequisite -DeviceListPath ".\devices.txt"
```

### Logging Configuration
```powershell
# Enable detailed logging
$VerbosePreference = "Continue"
$InformationPreference = "Continue"

# Custom log path
Test-AzureArcPrerequisite -NetworkLogPath "C:\Logs\ArcDeployment.log"
```

## 🛠️ Troubleshooting

### Common Issues & Solutions

#### ❌ "ExecutionPolicy Restricted" Error
```powershell
# Solution: Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### ❌ "Azure Module Not Found" Error
```powershell
# Solution: Install Azure PowerShell module
Install-Module -Name Az -Repository PSGallery -Force
```

#### ❌ "TLS 1.2 Not Enabled" Error
```powershell
# Solution: Enable TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

#### ❌ "Insufficient Permissions" Error
- Verify Azure account has **Contributor** or **Owner** role
- Ensure **Azure Arc Administrator** role is assigned
- Check subscription-level permissions

#### ❌ "Network Connectivity Failed" Error
```powershell
# Network connectivity testing is now integrated into prerequisites testing
Test-AzureArcPrerequisite -NetworkTestMode Comprehensive -ShowDetailedNetworkResults

# Check firewall and proxy settings
Test-NetConnection -ComputerName "management.azure.com" -Port 443
```

### Debug Mode
```powershell
# Enable debug output for troubleshooting
$DebugPreference = "Continue"
Deploy-DefenderForServers
```

### Logging Locations
- **Module Logs**: `%TEMP%\DefenderEndpointDeployment\`
- **Azure Arc Logs**: `C:\ProgramData\AzureConnectedMachineAgent\Logs\`
- **Windows Event Logs**: Applications and Services > Azure Arc

## 🔐 Security Best Practices

### Service Principal Security
- **Principle of Least Privilege**: Assign minimal required permissions
- **Regular Rotation**: Rotate service principal secrets every 90 days
- **Secure Storage**: Store credentials in Azure Key Vault
- **Audit Access**: Monitor service principal usage

### Network Security
- **Firewall Rules**: Configure outbound rules for Azure endpoints
- **Proxy Configuration**: Configure proxy settings for Azure connectivity
- **Certificate Validation**: Ensure proper TLS certificate validation
- **Network Segmentation**: Isolate Arc-enabled servers appropriately

### Authentication
- **Multi-Factor Authentication**: Enable MFA for Azure accounts
- **Conditional Access**: Configure conditional access policies
- **Privileged Access**: Use Azure PIM for elevated permissions
- **Session Management**: Monitor and audit Azure sessions

## 📈 Performance Optimization

### Bulk Operations
```powershell
# Process devices in parallel for large environments
$deviceListFile = ".\devices.txt"
# Note: Individual device testing is now handled by the DeviceListPath parameter
Test-AzureArcPrerequisite -DeviceListPath $deviceListFile -NetworkLogPath "C:\Logs\AllDevices.log"
```

### Memory Management
```powershell
# Clear variables after large operations
Remove-Variable -Name devices, results -ErrorAction SilentlyContinue
[System.GC]::Collect()
```

### Caching
- **Azure Session**: Reuse authenticated sessions
- **Results**: Cache validation results for repeated operations
- **Endpoints**: Cache endpoint connectivity results

## 🔄 Version History

### v1.2.1 (Current)
- ✨ Enhanced interactive menu with "Press any key" functionality
- 📚 Comprehensive help documentation overhaul
- 🔄 Improved user experience and navigation
- 📊 Advanced connectivity testing options
- 🛡️ Better error handling and validation

### v1.2.0
- 🎮 Interactive menu system implementation
- 🎨 ASCII art interface with color coding
- 📊 Consolidated reporting features
- 🔐 Enhanced security validation

### v1.1.0
- 🚀 Azure Arc deployment automation
- ✅ Prerequisites validation system
- 🌐 Network connectivity testing
- 📋 Multi-device support

### v1.0.0
- 🎯 Initial release
- 🔧 Core cmdlets implementation
- 📖 Basic documentation

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Development Setup
```powershell
# Clone the repository
git clone https://github.com/lessit/DefenderEndpointDeployment.git
cd DefenderEndpointDeployment

# Install development dependencies
Install-Module -Name Pester, PSScriptAnalyzer -Force

# Run tests
Invoke-Pester

# Run static analysis
Invoke-ScriptAnalyzer -Path .\
```

### Code Standards
- Follow **PowerShell Style Guide**
- Include **comment-based help** for all functions
- Add **Pester tests** for new functionality
- Ensure **PSScriptAnalyzer** compliance

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

## 📞 Support & Contact

- **🌐 Website**: [https://lessit.net](https://lessit.net)
- **📧 Email**: Contact via website
- **🐛 Issues**: GitHub Issues (when repository is available)
- **💬 Discussions**: GitHub Discussions (when repository is available)

## ⭐ Acknowledgments

- **Microsoft Azure Arc Team** for the excellent documentation
- **PowerShell Community** for best practices and guidance
- **Azure Security Team** for security recommendations
- **Enterprise Customers** for real-world testing and feedback

---

> **📢 Note**: This module is actively maintained and regularly updated. Star the repository to stay updated with the latest features and improvements!

**Made with ❤️ by [Less-IT](https://lessit.net) - AI and CyberSecurity Specialists**
```

### 🌐 Enhanced Network Testing (v1.1.0+)

The module now includes comprehensive Azure Arc network requirements testing based on the latest Microsoft documentation:

#### **Core Endpoints Tested:**
- **Azure Management**: `management.azure.com:443`
- **Microsoft Entra ID**: `login.microsoftonline.com:443`, `login.microsoft.com:443`, `pas.windows.net:443`
- **Azure Arc Services**: `*.his.arc.azure.com:443`, `*.guestconfiguration.azure.com:443`
- **Notification Services**: `guestnotificationservice.azure.com:443`, Service Bus endpoints
- **Installation Endpoints**: `download.microsoft.com:443` (Windows agent), `packages.microsoft.com:443` (Linux agent)

#### **Optional Endpoints (Scenario-Specific):**
- **Windows Admin Center**: `*.waconazure.com:443`
- **Arc Data Services**: `*.arcdataservices.com:443` (for SQL Server enabled by Azure Arc)
- **Azure Storage**: `*.blob.core.windows.net:443` (for extensions)
- **Certificate Services**: `www.microsoft.com:443` (for ESU/certificate updates)

#### **TLS Protocol Verification:**
- Tests TLS 1.2+ support (required for Azure Arc)
- Identifies systems with insufficient TLS support (Windows Server 2012 and below)

#### **Service Tags Coverage:**
- AzureActiveDirectory
- AzureResourceManager  
- AzureArcInfrastructure
- Storage
- WindowsAdminCenter

```powershell
# Comprehensive connectivity testing is now integrated into prerequisites testing
Test-AzureArcPrerequisite -NetworkTestMode Comprehensive -IncludeOptionalEndpoints -TestTLSVersion
```

## 🔧 Requirements

### System Requirements
- **PowerShell**: 5.1 or higher (PowerShell 7+ recommended)
- **Operating System**: Windows Server 2016+, Windows 10/11
- **Azure PowerShell**: Az.Accounts, Az.Resources modules
- **Permissions**: Local administrator rights, Azure subscription access

### Azure Requirements
- Active Azure subscription
- Azure Arc service enabled
- Appropriate RBAC permissions (Contributor or custom roles)
- Network connectivity to Azure endpoints
- Group Policy management permissions
- Active Directory PowerShell module

## 🚀 Quick Start

### Option 1: Interactive Entry Point (Recommended)

```powershell
# Run the interactive entry point directly
.\Deploy-DefenderForServers.ps1

# Or import the module and use the interactive function
Import-Module .\DefenderEndpointDeployment.psd1
Deploy-DefenderForServers
```

The interactive interface provides:
- 📋 Numbered menu system for all commands
- 🆘 Built-in help system
- 🎨 Professional ASCII art interface
- 🔄 Continuous operation until you choose to quit

### Option 2: Individual Commands

### 1. Prerequisites Check

```powershell
# Test system readiness for Azure Arc (create device list file first)
"SERVER01" | Out-File -FilePath "C:\devices.txt"
"SERVER02" | Out-File -FilePath "C:\devices.txt" -Append  
"SERVER03" | Out-File -FilePath "C:\devices.txt" -Append
Test-AzureArcPrerequisite -DeviceListPath "C:\devices.txt"

# Test with force option (skip prompts)
Test-AzureArcPrerequisite -DeviceListPath "C:\devices.txt" -Force
```

### 2. Azure Arc Onboarding

```powershell
# Basic onboarding
New-AzureArcDevice -ResourceGroupName "rg-azurearc-prod" -Location "East US"

# Advanced onboarding with custom settings
New-AzureArcDevice -ResourceGroupName "rg-azurearc-prod" -Location "East US" -ServicePrincipalName "Arc-SP-Prod" -GPOName "Azure Arc Policy" -TargetOUs @("CN=Servers,DC=contoso,DC=com")
```

## 📚 Usage Examples

### Prerequisites Testing

```powershell
# Test system readiness for Azure Arc
Test-AzureArcPrerequisite
```

### Azure Arc Onboarding

```powershell
# Basic onboarding
New-AzureArcDevice -ResourceGroupName "rg-azurearc" -Location "East US"
```

## 📚 Documentation

- **EXAMPLES.md** - Usage examples and scenarios
- **INSTALLATION-GUIDE.md** - Installation instructions  
- **PUBLISHING-GUIDE.md** - Publishing information

## 🔧 Available Functions

- `Deploy-DefenderForServers` - Interactive main menu
- `Test-AzureArcPrerequisite` - Prerequisites validation (enhanced with automatic resource provider registration)
- `New-AzureArcDevice` - Complete Azure Arc deployment (includes service principal creation, agent installation, and Group Policy deployment)
- `Get-AzureArcDiagnostics` - Comprehensive Azure Arc diagnostics and troubleshooting

## 🤝 Support

For support, please contact Lessi Coulibaly at Less-IT (AI and CyberSecurity).

---
**Author**: Lessi Coulibaly  
**Organization**: Less-IT (AI and CyberSecurity)  
**Website**: https://lessit.net

```powershell
# Production deployment example
New-AzureArcDevice `
    -ResourceGroupName "rg-prod-azurearc" `
    -Location "East US 2" `
    -ServicePrincipalName "ArcOnboarding-Prod" `
    -GPOName "Azure Arc Servers Policy" `
    -TargetOUs @(
        "OU=Servers,OU=Production,DC=contoso,DC=com",
        "OU=WebServers,OU=Production,DC=contoso,DC=com"
    ) `
    -Tags @{
        Environment = "Production"
        Owner = "IT-Operations"
        CostCenter = "CC-001"
    } `
    -Verbose
```

### Utility Functions

The module provides a streamlined workflow through three main functions:

```powershell
# Test prerequisites with automatic resource provider registration
Test-AzureArcPrerequisite -DeviceListPath "C:\devices.txt" -NetworkTestMode Comprehensive

# Complete Azure Arc deployment (service principal + agent + Group Policy)
New-AzureArcDevice -ResourceGroupName "rg-azurearc" -Location "eastus"

# Run comprehensive diagnostics
Get-AzureArcDiagnostics -LogPath "C:\ArcDiagnostics" -CollectLogs
```

## 🔐 Authentication

The module handles Azure authentication automatically:

```powershell
# Automatic authentication check and login prompt
Test-AzureArcPrerequisite -DeviceListPath @("SERVER01")

# Manual authentication verification
$authResult = Confirm-AzureAuthentication
if ($authResult) {
    Write-Host "✅ Azure authentication successful"
}
```

**Authentication Features:**
- 🔄 Automatic session validation
- 🔐 Interactive login prompts when needed
- ⚡ Session reuse for multiple operations
- 🛡️ Secure credential handling

## 📊 Output Examples

### Prerequisites Test Output

```
🔍 Azure Arc Prerequisites Check
─────────────────────────────────────────────────────────

📋 Test Configuration:
  Target Devices: 3
  Timeout: 60 seconds
  User Consent: Required

✅ User consent granted. Proceeding with tests...

🔐 Azure Authentication Check
  ✅ Azure session active
  ✅ Required modules available

🔧 Azure Resource Providers Check
  ✅ Microsoft.HybridCompute: Registered
  ✅ Microsoft.GuestConfiguration: Registered
  ✅ Microsoft.AzureArcData: Registered

📡 Device Connectivity Tests
  🔄 Testing SERVER01...
    ✅ Device online and accessible
    ✅ PowerShell remoting enabled
    ✅ Administrative access confirmed
    ✅ OS version compatible
  🔄 Testing SERVER02...
    ✅ Device online and accessible
    ✅ PowerShell remoting enabled
    ✅ Administrative access confirmed
    ✅ OS version compatible
```

📊 **Prerequisites Summary:**

| Device   | Online | PowerShell | OS Compatible |
|----------|--------|------------|---------------|
| SERVER01 | ✅ Yes | ✅ Yes     | ✅ Yes        |
| SERVER02 | ✅ Yes | ✅ Yes     | ✅ Yes        |
| SERVER03 | ✅ Yes | ✅ Yes     | ✅ Yes        |

```
✅ All prerequisites checks passed! Ready for Azure Arc onboarding.
```

### Device Onboarding Output

```
🚀 Azure Arc Device Onboarding
─────────────────────────────────────────────────────────

📋 Onboarding Configuration:
  Resource Group: rg-azurearc-prod
  Location: East US
  Service Principal: Arc-SP-DefenderEndpointMgmt
  GPO Name: Azure Arc Onboarding Policy

🔐 Azure Authentication
  ✅ Authenticated as: user@contoso.com
  ✅ Subscription: Production (12345678-1234-1234-1234-123456789012)

🏗️  Resource Group Setup
  ✅ Resource group 'rg-azurearc-prod' ready

🔐 Service Principal Creation
  ✅ Service principal created successfully
  📊 Application ID: 87654321-4321-4321-4321-210987654321

🔧 Group Policy Deployment
  ✅ GPO 'Azure Arc Onboarding Policy' created
  ✅ Linked to OU: CN=Servers,DC=contoso,DC=com
  ✅ Policy configured successfully

✅ Azure Arc onboarding setup completed successfully!

💡 Next Steps:
  1. Run 'gpupdate /force' on target machines
  2. Monitor device registration in Azure portal
  3. Verify Arc agent installation and connectivity
```

## 🔧 Advanced Configuration

### Custom Resource Provider Registration

```powershell
# Resource providers are now automatically registered during prerequisites testing
Test-AzureArcPrerequisite -DeviceListPath "C:\devices.txt" -Force
```

### Batch Device Processing

```powershell
# Process large device lists efficiently
$deviceList = Get-Content "C:\DeviceLists\prod-servers.txt"
Test-AzureArcPrerequisite -DeviceListPath "C:\DeviceLists\prod-servers.txt" -NetworkTestMode Comprehensive
```

### Custom Error Handling

```powershell
try {
    $result = New-AzureArcDevice -ResourceGroupName "rg-test" -Location "eastus"
    if ($result.Success) {
        Write-Host "✅ Onboarding completed successfully"
    }
}
catch {
    Write-Error "❌ Onboarding failed: $($_.Exception.Message)"
    # Custom error handling logic
}
```

## 🛠️ Troubleshooting

### Common Issues

**1. Azure Authentication Fails**
```powershell
# Clear cached credentials and re-authenticate
Clear-AzContext -Force
Connect-AzAccount
```

**2. PowerShell Remoting Issues**
```powershell
# Enable PS Remoting on target machines
Enable-PSRemoting -Force
Set-WSManQuickConfig -Force
```

**3. Network Connectivity Problems**
```powershell
# Test network connectivity using integrated testing
Test-AzureArcPrerequisite -NetworkTestMode Comprehensive -ShowDetailedNetworkResults
```

**4. Resource Provider Registration Stuck**
```powershell
# Resource provider registration is now automatic during prerequisites testing
# If manual registration is needed, run:
Test-AzureArcPrerequisite -Force
```

### Debug Mode

Enable verbose output for detailed troubleshooting:

```powershell
# Enable verbose and debug output
$VerbosePreference = "Continue"
$DebugPreference = "Continue"

Test-AzureArcPrerequisite -DeviceListPath "C:\SERVER01.txt" -ShowDetailedNetworkResults
```

## 📈 Performance Considerations

### Large-Scale Deployments

For enterprise deployments with hundreds of servers:

1. **Batch Processing**: Process devices in batches of 50-100
2. **Parallel Execution**: Use `-Parallel` parameter where available
3. **Off-Peak Hours**: Run large deployments during maintenance windows
4. **Network Optimization**: Ensure adequate bandwidth for agent downloads
5. **Monitoring**: Implement monitoring for deployment progress

### Resource Management

```powershell
# Batch processing is now handled automatically with device list files
# Create device list files for each batch and process them sequentially
for ($i = 1; $i -le $totalBatches; $i++) {
    $batchFile = "C:\DeviceBatch$i.txt"
    Test-AzureArcPrerequisite -DeviceListPath $batchFile
    Start-Sleep -Seconds 30  # Rate limiting
}
```

## 🔄 Version History

### v2.0.0 (Current)
- 🚀 **Major restructure**: Consolidated 8 functions into 3 streamlined workflows
- ✅ **Enhanced Test-AzureArcPrerequisite**: Now includes automatic Azure resource provider registration
- ✅ **Enhanced New-AzureArcDevice**: Complete deployment including service principal creation, agent installation, and Group Policy deployment
- ✅ **Simplified menu system**: Reduced from 8 options to 3 main functions
- ✅ **Improved user experience**: Automated workflow with fewer manual steps
- ✅ **Updated documentation**: Comprehensive guide reflecting new structure

### v1.0.9
- ✅ Updated to use modern PowerShell Gallery publishing with PSResourceGet
- ✅ Cleaned up documentation and removed unnecessary content
- ✅ Improved module metadata for better PowerShell Gallery presentation

### v1.0.7
- ✅ Company branding update: Updated organization name to "Less-IT (AI and CyberSecurity)"
- ✅ Enhanced module metadata for better PowerShell Gallery presentation

### v1.0.6
- ✅ Enhanced user experience with default prompts
- ✅ Graceful handling of missing Azure modules
- ✅ Improved sample file creation and editing

### v1.0.5
- ✅ Enhanced error handling and user feedback
- ✅ Improved Azure authentication flow
- ✅ Added utility functions for granular control
- ✅ Performance optimizations for large-scale deployments
- ✅ Comprehensive documentation and examples

### v1.0.1
- ✅ Initial Group Policy deployment functionality
- ✅ Service principal creation automation
- ✅ Enhanced connectivity testing

### v1.0.0
- ✅ Initial release
- ✅ Basic Azure Arc onboarding capabilities
- ✅ Prerequisites validation framework

## 🤝 Contributing

I welcome contributions! Please reach out: [lessic@lessit.net](mailto:lessic@lessit.net)

### Development Setup

```powershell
# Clone the repository (when available)
git clone <YOUR-GITHUB-REPOSITORY-URL>
cd DefenderEndpointDeployment

# Install development dependencies
Install-Module -Name Pester, PSScriptAnalyzer -Scope CurrentUser

# Run tests
Invoke-Pester -Path .\Tests\
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

### Community Support
- **GitHub Issues**: Report bugs and request features (when repository is available)
- **Discussions**: Community Q&A and discussions (when repository is available)

### Professional Support
- **Email**: [support@lessit.net](mailto:support@lessit.net)
- **Website**: [https://lessit.net/support](https://lessit.net/support)

## 🙏 Acknowledgments

- Microsoft Azure Arc team for excellent documentation
- PowerShell community for best practices and feedback
- Enterprise customers who provided real-world testing scenarios

---

**© 2025 Less-IT (AI and CyberSecurity). All rights reserved.**

*Making Azure Arc deployment simple, reliable, and enterprise-ready.*
