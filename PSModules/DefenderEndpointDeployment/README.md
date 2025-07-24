# DefenderEndpointDeployment PowerShell Module

> **Enterprise-Grade Azure Arc Device Deployment & Microsoft Defender Endpoint Integration**

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Azure Arc](https://img.shields.io/badge/Azure%20Arc-Enabled-green.svg)](https://azure.microsoft.com/en-us/services/azure-arc/)
[![Version](https://img.shields.io/badge/Version-1.1.0-brightgreen.svg)](#)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 📋 Overview

The **DefenderEndpointDeployment** module provides a comprehensive, enterprise-grade PowerShell solution for managing Azure Arc-enabled servers and Microsoft Defender for Endpoint (MDE) integration across large-scale environments. This module delivers professional-quality automation tools with an intuitive interactive interface, extensive validation capabilities, and robust error handling for mission-critical deployments.

### 🎯 Key Features

- **🔍 Comprehensive Prerequisites Testing** - Complete system validation including TLS requirements, network connectivity, and Azure authentication
- **🏗️ Automated Device Deployment** - Azure Arc device creation with Group Policy deployment for enterprise environments
- **📊 Advanced Diagnostics** - Professional troubleshooting and log collection capabilities
- **💰 Pricing Management** - Post-deployment Defender for Servers pricing configuration
- **📁 Unified File Management** - Standardized directory system ensures all generated files are organized in user-chosen locations
- **🎮 Interactive Interface** - User-friendly menu system with built-in help and guidance
- **🔐 Seamless Authentication** - Automated Azure authentication and subscription management

## 🚀 Core Functions

> **🎯 QUICK START REMINDER**: Always begin with `Deploy-DefenderForServers`! This interactive command center is your gateway to all Azure Arc deployment operations.

The module provides five main functions. **Always start with `Deploy-DefenderForServers`** - the interactive command center that provides access to all other functions:

### 1️⃣ Deploy-DefenderForServers ⭐ **START HERE**
**Interactive Command Center - Your Main Entry Point**
- 🎮 **Menu-Driven Interface** - Numbered commands for all major operations
- 📖 **Built-in Help System** - Comprehensive documentation and guidance
- ✅ **Operation Confirmation** - User-controlled execution with confirmations
- 🔄 **Seamless Navigation** - Intuitive flow between functions
- 📊 **Status Management** - Clear operation results and next steps

```powershell
# Launch the interactive menu (RECOMMENDED STARTING POINT)
Deploy-DefenderForServers
```

> **💡 Best Practice**: Always begin your Azure Arc deployment journey with `Deploy-DefenderForServers`. This interactive menu provides guided access to all other functions and ensures proper workflow execution.

### 2️⃣ Test-AzureArcPrerequisite
**Comprehensive Azure Arc Prerequisites Validation**
- ✅ **System Requirements** - Windows version, PowerShell, .NET Framework validation
- ✅ **Network Connectivity** - Azure Arc endpoints, DNS resolution, proxy configuration
- ✅ **TLS Security** - TLS 1.2+ support, strong cipher suites, certificate validation
- ✅ **Azure Integration** - Authentication, resource providers, subscription permissions
- ✅ **Multi-Device Support** - Batch validation across multiple devices
- ✅ **Detailed Reporting** - Comprehensive logs and remediation guidance

```powershell
# Basic prerequisites check
Test-AzureArcPrerequisite

# Comprehensive validation with TLS testing
Test-AzureArcPrerequisite -TestTLSVersion -NetworkTestMode Comprehensive

# Use standardized directory for organized file storage
Test-AzureArcPrerequisite -UseStandardizedDirectory -GenerateRemediationScript
```

### 3️⃣ New-AzureArcDevice  
**Enterprise Azure Arc Device Deployment**
- 🏗️ **Resource Creation** - Azure resource groups and deployment configuration
- 👥 **Service Principal Management** - Automated identity creation and permissions
- 📋 **Group Policy Deployment** - Enterprise-scale automated agent installation
- 📁 **Remote Share Configuration** - Centralized deployment file management
- 🔗 **OU Integration** - Active Directory organizational unit linking

```powershell
# Interactive device creation
New-AzureArcDevice

# Automated deployment with parameters
New-AzureArcDevice -ResourceGroupName "rg-azurearc" -Location "eastus" -Force

# Use standardized directory for deployment files
New-AzureArcDevice -UseStandardizedDirectory
```

### 4️⃣ Get-AzureArcDiagnostic
**Advanced Azure Arc Diagnostics & Troubleshooting**
- 🔍 **Agent Health Validation** - Service status, configuration integrity
- 📋 **Log Collection** - Comprehensive diagnostic data gathering
- 🌐 **Connectivity Testing** - Azure endpoint validation and network analysis
- 🛠️ **Issue Resolution** - Automated problem detection and guidance
- 📊 **Performance Analysis** - System resource and network performance metrics

```powershell
# Basic diagnostics
Get-AzureArcDiagnostic

# Comprehensive diagnostics with custom log path
Get-AzureArcDiagnostic -LogPath "C:\AzureArcDiagnostics"

# Use standardized directory for organized logs
Get-AzureArcDiagnostic -UseStandardizedDirectory
```

### 5️⃣ Set-AzureArcResourcePricing
**Microsoft Defender for Servers Pricing Management**
- 💰 **Pricing Tier Control** - Free, Standard P1, and P2 tier management
- 🎯 **Flexible Targeting** - Resource Group, Tag, or individual resource targeting
- 📊 **Batch Operations** - Configure multiple resources simultaneously
- 🔍 **Cost Optimization** - Read current pricing configurations for analysis
- ✅ **Validation & Reporting** - Comprehensive operation results and status

```powershell
# Configure pricing for Resource Group
Set-AzureArcResourcePricing -Mode "RG" -ResourceGroupName "rg-production" -Action "standard"

# Configure pricing based on tags
Set-AzureArcResourcePricing -Mode "TAG" -TagName "Environment" -TagValue "Production" -Action "standard"

# Read current pricing configuration
Set-AzureArcResourcePricing -Mode "RG" -ResourceGroupName "rg-production" -Action "read"
```

## 📁 Unified File Management System

All module functions support a standardized directory system for organized file management:

### 🎯 UseStandardizedDirectory Parameter
When you use the `-UseStandardizedDirectory` parameter with any function:
1. **First Function Call** - You're prompted once to select your preferred directory
2. **Subsequent Calls** - The same directory is automatically reused
3. **File Co-location** - All generated files are stored in your chosen location

### 📋 Supported File Types
- **Prerequisites Logs** - Comprehensive validation reports
- **Device Lists** - Target device inventories  
- **Diagnostic Data** - Azure Arc agent diagnostics and troubleshooting logs
- **Deployment Files** - Azure Arc agent installation and Group Policy files
- **Remediation Scripts** - Automated fix scripts for identified issues

### 💡 Usage Examples
```powershell
# RECOMMENDED: Start with the interactive menu
Deploy-DefenderForServers

# All functions support standardized directory for organized output
Test-AzureArcPrerequisite -UseStandardizedDirectory
Get-AzureArcDiagnostic -UseStandardizedDirectory  
New-AzureArcDevice -UseStandardizedDirectory

# Traditional approach (still supported)
Test-AzureArcPrerequisite -ConsolidatedLogPath "C:\MyLogs"
Get-AzureArcDiagnostic -LogPath "C:\MyLogs"
New-AzureArcDevice -SharePath "C:\MyDeployment"
```

## 🚀 Quick Start

### Installation

#### Method 1: PowerShell Gallery (Recommended)
```powershell
# Install from PowerShell Gallery
Install-PSResource DefenderEndpointDeployment

# Update to latest version
Update-PSResource DefenderEndpointDeployment

# Import the module
Import-Module DefenderEndpointDeployment
```

#### Method 2: Manual Installation
```powershell
# Clone the repository
git clone <YOUR-GITHUB-REPOSITORY-URL>

# Import the module
Import-Module .\DefenderEndpointDeployment\DefenderEndpointDeployment.psd1
```

### Getting Started

**🎯 ALWAYS START HERE - Use the Interactive Menu:**
```powershell
# Import and run the module - THIS IS YOUR STARTING POINT
Import-Module DefenderEndpointDeployment
Deploy-DefenderForServers
```

> **⚠️ Important**: `Deploy-DefenderForServers` is your main entry point. This interactive command center provides guided access to all other functions and ensures proper workflow execution. Never skip this step!

The interactive interface provides:
- 🎯 **Numbered Commands** (1-4) for all major operations
- 📖 **Built-in Help System** (H) with detailed documentation  
- ✅ **Confirmation Prompts** for all operations
- 🔄 **User-Controlled Navigation** with "Press any key to continue"
- 🚀 **Guided Workflow** ensuring you follow the correct deployment sequence

### Interactive Menu Commands

> **🔥 Start Here**: Launch `Deploy-DefenderForServers` to access the interactive menu system

| Command | Function | Description |
|---------|----------|-------------|
| **MENU** | Deploy-DefenderForServers | **🎯 MAIN ENTRY POINT** - Interactive command center providing guided access to all functions |
| **1** | Test-AzureArcPrerequisite | • Validates system requirements and network connectivity<br>• Checks PowerShell environment and Azure modules<br>• Multi-device validation support with TLS testing |
| **2** | New-AzureArcDevice | • Creates and configures Azure Arc devices<br>• Service principal management and Group Policy deployment<br>• Enterprise-scale automated deployment |
| **3** | Get-AzureArcDiagnostic | • Comprehensive Azure Arc agent diagnostics<br>• Log collection and troubleshooting capabilities<br>• Health validation and connectivity testing |
| **4** | Set-AzureArcResourcePricing | • Post-deployment Defender for Servers pricing configuration<br>• Resource-level pricing management (Free/Standard P1/P2)<br>• Resource Group and Tag-based targeting |
| **H** | Show Help Documentation | Display detailed help and documentation |
| **Q** | Exit | Exit the interactive menu |

## 📊 System Requirements

### Prerequisites
- **PowerShell**: 5.1 or higher (PowerShell 7+ recommended)
- **Azure PowerShell**: Az.Accounts, Az.Resources modules
- **Permissions**: Local administrator rights, Azure subscription access
- **Network**: Internet connectivity for Azure endpoint validation

### Azure Requirements
- Active Azure subscription
- Azure Arc service enabled
- Appropriate RBAC permissions (Contributor or custom roles)
- Network connectivity to Azure endpoints

### Supported Operating Systems
- Windows Server 2012 R2 or later
- Windows Server Core installations supported

### Network Requirements
- Outbound HTTPS (443) access to Azure endpoints
- DNS resolution for Microsoft domains
- TLS 1.2 or higher support
- Proxy server support (if configured)

## 🛠️ Troubleshooting

### Common Issues

**Azure Authentication Fails**
```powershell
# Clear cached credentials and re-authenticate
Clear-AzContext -Force
Connect-AzAccount
```

**PowerShell Remoting Issues**
```powershell
# Enable PS Remoting on target machines
Enable-PSRemoting -Force
Set-WSManQuickConfig -Force
```

**Network Connectivity Problems**
```powershell
# Test connectivity using the built-in network testing
Test-AzureArcPrerequisite -NetworkTestMode Comprehensive -TestTLSVersion
```

**Module Import Errors**
```powershell
# Check PowerShell execution policy
Get-ExecutionPolicy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Verify module installation
Get-Module DefenderEndpointDeployment -ListAvailable
```

**TLS/SSL Certificate Issues**
```powershell
# Test TLS requirements specifically
Test-AzureArcPrerequisite -TestTLSVersion -ShowDetailedNetworkResults
```

### Advanced Diagnostics

**Comprehensive System Validation**
```powershell
Test-AzureArcPrerequisite -NetworkTestMode Comprehensive -TestTLSVersion -CheckSystemRequirements -ValidateDefenderConfiguration -GenerateRemediationScript
```

**File Organization Issues**
```powershell
# Use standardized directory system for organized output
Test-AzureArcPrerequisite -UseStandardizedDirectory
Get-AzureArcDiagnostic -UseStandardizedDirectory
```

## 🔄 Version History

### v1.1.0 (Current)
- 🚀 **Enhanced Functionality** - Improved module stability and performance optimizations
- 📋 **Documentation Updates** - Comprehensive README refresh with better organization and clarity  
- 🔧 **Code Quality** - Refined function implementations with better parameter validation
- 🎮 **User Experience** - Enhanced interactive menu system with improved navigation
- ✅ **Compatibility** - Extended compatibility testing and validation across environments
- 🔐 **Authentication** - Improved Azure authentication handling and error recovery
- 📁 **File Management** - Enhanced file organization and standardized directory support
- 🛠️ **Troubleshooting** - Better error reporting and diagnostic capabilities

### v1.0.0
- 🎯 **Initial Release** - Core Azure Arc functionality and comprehensive prerequisites validation
- 📊 **Device Onboarding** - Complete device creation and management capabilities
- 🔐 **Azure Integration** - Azure authentication and subscription management
- 📋 **Interactive Menu** - Professional command-line interface for function selection
- 🔍 **Prerequisites Testing** - Comprehensive system and network validation with detailed reporting
- 🏗️ **Azure Arc Device Creation** - Automated device onboarding with Group Policy support
- 📊 **Diagnostic Capabilities** - Advanced troubleshooting and log collection
- 💰 **Pricing Management** - Resource-level Defender for Servers pricing configuration
- 🎮 **Interactive Menu System** - Enhanced user interface with better navigation
- 🔐 **Authentication Handling** - Azure authentication and error recovery
- 🏢 **Enterprise Support** - Multi-device batch processing capabilities
- 🖥️ **Server-Focused Architecture** - Optimized for Windows Server environments

## 🏢 Author & Organization

- **👨‍💻 Author**: Lessi Coulibaly
- **🏢 Organization**: Less-IT (AI and CyberSecurity)
- **🌐 Website**: [https://lessit.net](https://lessit.net)
- **📧 Contact**: support@lessit.net


## 🤝 Contributing

I welcome contributions! Please reach out: support@lessit.net

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**© 2025 Less-IT (AI and CyberSecurity). All rights reserved.**

*Making Azure Arc deployment simple, reliable, and enterprise-ready.*
