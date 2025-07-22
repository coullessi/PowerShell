# DefenderEndpointDeployment PowerShell Module

> **Enterprise-Grade Azure Arc Device Deployment & Microsoft Defender Endpoint Integration**

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Azure Arc](https://img.shields.io/badge/Azure%20Arc-Enabled-green.svg)](https://azure.microsoft.com/en-us/services/azure-arc/)
[![Version](https://img.shields.io/badge/Version-1.1.0-brightgreen.svg)](#)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 📋 Overview

The **DefenderEndpointDeployment** module provides a comprehensive, enterprise-grade PowerShell solution for managing Azure Arc-enabled servers and Microsoft Defender for Endpoint (MDE) integration across large-scale environments. This module delivers professional-quality automation tools with an intuitive interactive interface, extensive validation capabilities, and robust error handling for mission-critical deployments.

### 🌟 What's New in v1.1.0

| Feature | Description |
|---------|-------------|
| ✅ **Enhanced Prerequisites Testing** | Comprehensive Azure Arc prerequisites validation |
| 🔧 **Azure Arc Device Creation** | Streamlined device onboarding with Group Policy support |
| 🔍 **Comprehensive Diagnostics** | Advanced troubleshooting and log collection |
| 🎮 **Interactive Menu System** | Selection of a function to run |
| 🔐 **Automated Authentication** | Seamless Azure authentication handling |

### 🚀 Quick Start

**Use the interactive entry point for the best experience:**

```powershell
# Import and run the module
Import-Module DefenderEndpointDeployment
Deploy-DefenderForServers
```

The interactive interface provides a professional menu system with:
- 🎯 **Numbered Commands** (1-3) for all major operations
- 📖 **Built-in Help System** (H) with detailed documentation
- ✅ **Confirmation Prompts** for all operations
- 🔄 **User-Controlled Navigation** with "Press any key to continue"

### 🎯 Core Functions

The module provides four main functions accessible through an interactive menu:

#### 1️⃣ Test-AzureArcPrerequisite
- Comprehensive system validation for Azure Arc onboarding
- Network connectivity testing to Azure endpoints
- PowerShell environment and module validation
- Multi-device support with detailed reporting

#### 2️⃣ New-AzureArcDevice  
- Azure Arc device creation and configuration
- Service principal management
- Group Policy deployment for enterprise environments
- Agent installation and setup

#### 3️⃣ Get-AzureArcDiagnostics
- Comprehensive Azure Arc diagnostics and troubleshooting
- Agent log collection and analysis
- Connectivity validation and health checks
- Automated diagnostic report generation

#### 4️⃣ Deploy-DefenderForServers
- Interactive menu system for all functions
- Built-in help and guidance system
- User-friendly navigation and operation flow

## 🏢 Author & Organization

- **👨‍💻 Author**: Lessi Coulibaly
- **🏢 Organization**: Less-IT (AI and CyberSecurity)
- **🌐 Website**: [https://lessit.net](https://lessit.net)
- **📧 Contact**: support@lessit.net

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

### Quick Start

Launch the interactive menu for the best experience:

```powershell
# Import and start the module
Import-Module DefenderEndpointDeployment
Deploy-DefenderForServers
```

### Interactive Menu Commands

| Command | Function | Description |
|---------|----------|-------------|
| **1** | Test-AzureArcPrerequisite | • Validates system requirements and network connectivity<br>• Checks PowerShell environment and Azure modules<br>• Multi-device validation support |
| **2** | New-AzureArcDevice | • Creates and configures Azure Arc devices<br>• Service principal management and Group Policy deployment<br>• Enterprise-scale automated deployment |
| **3** | Get-AzureArcDiagnostics | • Comprehensive Azure Arc agent diagnostics<br>• Log collection and connectivity testing<br>• Troubleshooting and support report generation |
| **H** | Show Help Documentation | Display detailed help and documentation |
| **Q** | Exit | Exit the interactive menu |

### Direct Function Usage

```powershell
# Test prerequisites for multiple devices
Test-AzureArcPrerequisite -DeviceListPath "C:\devices.txt"

# Create Azure Arc device with Group Policy
New-AzureArcDevice -ResourceGroupName "rg-azurearc" -Location "eastus"

# Run diagnostics with log collection
Get-AzureArcDiagnostics -CollectLogs -CreateArchive
```

## 📊 Requirements

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
Test-AzureArcPrerequisite -NetworkTestMode Comprehensive
```

## 🔄 Version History

### v1.1.0 (Current)
- ✅ **Enhanced Prerequisites Testing** - Comprehensive system and network validation
- ✅ **Azure Arc Device Creation** - Automated device onboarding with Group Policy support  
- ✅ **Advanced Diagnostics** - Professional troubleshooting and log collection
- ✅ **Multi-Device Support** - Enterprise-scale batch processing capabilities

### v1.0.0
- 🎯 Initial release with core Azure Arc functionality
- 📊 Basic prerequisites validation and device onboarding

## 🤝 Contributing

I welcome contributions! Please reach out: support@lessit.net

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **🌐 Website**: [https://lessit.net](https://lessit.net)
- **📧 Email**: support@lessit.net

---

**© 2025 Less-IT (AI and CyberSecurity). All rights reserved.**

*Making Azure Arc deployment simple, reliable, and enterprise-ready.*