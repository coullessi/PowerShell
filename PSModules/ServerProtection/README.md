# ServerProtection PowerShell Module (ARC-DFS)

> **Enterprise-Grade Server Protection through Azure Arc Device Deployment & Microsoft Defender for Servers Integration**

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Version](https://img.shields.io/badge/Version-1.0.1-brightgreen.svg)](https://github.com/coullessi/PowerShell/releases)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/coullessi/PowerShell/blob/main/LICENSE)
[![PowerShell Gallery](https://img.shields.io/badge/PowerShell%20Gallery-ServerProtection-blue.svg)](https://www.powershellgallery.com/packages/ServerProtection)

## Table of Contents

- [Overview](#overview)
- [Microsoft Defender for Servers Integration](#microsoft-defender-for-servers-integration)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Functions](#functions)
- [System Requirements](#system-requirements)
- [Use Cases](#use-cases)
- [Version History](#version-history)
- [Author](#author)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Purpose

The **ServerProtection** PowerShell module is a professional enterprise tool designed to simplify and automate the deployment of Azure Arc and Microsoft Defender for Servers across Windows Server environments. This module addresses the complex requirements of enterprise Azure Arc deployments while providing comprehensive validation, automated deployment, and ongoing management capabilities.

### 🔧 Core Capabilities

- **Azure Arc Prerequisites Validation** - Test servers for Azure Arc compatibility with detailed reporting
- **Automated Azure Arc Device Creation** - Generate deployment resources and Group Policy objects
- **Enterprise Group Policy Deployment** - Streamlined agent deployment across multiple servers
- **Advanced Diagnostics and Troubleshooting** - Monitor agent health and resolve deployment issues
- **Defender for Servers Pricing Management** - Configure and optimize security pricing tiers
- **Interactive Management Interface** - Professional menu-driven experience for all operations
- **Professional Error Handling** - User-friendly error messages with technical details logged separately

## Microsoft Defender for Servers Integration

Microsoft Defender for Servers provides advanced threat protection for your server workloads in Microsoft Defender for Cloud. This module streamlines the deployment process by automating Azure Arc agent installation and enabling seamless Defender for Servers protection across your infrastructure.

**Defender for Servers Key Benefits:**
- **🛡️ Advanced Threat Detection** - Behavioral analytics and machine learning-based threat detection
- **🔍 Vulnerability Assessment** - Continuous vulnerability scanning and management
- **🔐 Just-in-Time VM Access** - Reduce attack surface with controlled VM access
- **🛠️ Adaptive Application Controls** - Machine learning-based application allowlisting
- **📊 Security Recommendations** - Actionable security recommendations and compliance monitoring
- **🔗 Integration** - Seamless integration with Azure Security Center and Azure Sentinel

**Key Features:**
- **🔍 Comprehensive Prerequisites Testing** - Complete system validation including TLS requirements, network connectivity, and Azure authentication
- **🏗️ Automated Device Deployment** - Azure Arc device creation with Group Policy deployment for enterprise environments  
- **📊 Advanced Diagnostics** - Professional troubleshooting and log collection capabilities
- **💰 Pricing Management** - Post-deployment Defender for Servers pricing configuration at resource level
- **📁 Unified File Management** - Standardized directory system for organized file output
- **🎮 Simplified ARC-DFS Interface** - Clean, streamlined menu system with focused functionality
- **🔐 Enterprise Authentication** - Automated Azure authentication and subscription management

## Installation

### PowerShell Gallery (Recommended)
```powershell
# Install the module from PowerShell Gallery
Install-PSResource ServerProtection

# Import the module
Import-Module ServerProtection

# Verify installation
Get-Module ServerProtection -ListAvailable

# Start the interactive interface
Start-ServerProtection
```

### GitHub (Development)
```powershell
# Clone the repository
git clone https://github.com/coullessi/PowerShell.git
cd PowerShell\PSModules\ServerProtection

# Import the development version
Import-Module .\ServerProtection.psd1 -Force
```

## Quick Start

> **⭐ Always start with the interactive menu for guided operations**

```powershell
Import-Module ServerProtection
Start-ServerProtection
```

The interactive interface provides:
- **Menu-driven navigation** with numbered commands
- **Built-in help system** with comprehensive documentation
- **Operation confirmations** for safe execution
- **Guided workflow** ensuring proper deployment sequence
- **Professional error handling** with color-coded results (Green=Success, Yellow=Warning, Red=Failure)
- **Clean user experience** with technical details automatically logged to files

## Functions

The module provides five main functions designed to work together for complete Azure Arc deployment:

### Start-ServerProtection ⭐
**Interactive Command Center - Your Main Entry Point**

Launch the menu-driven interface that provides guided access to all module functions.

```powershell
Start-ServerProtection
```

### Get-AzureArcPrerequisite
**Comprehensive Azure Arc Prerequisites Validation**

Validates system requirements, network connectivity, TLS configuration, and Azure authentication. Supports multi-device batch processing and generates detailed reports with remediation guidance.

```powershell
# Basic prerequisites check
Get-AzureArcPrerequisite

# Comprehensive validation with TLS testing
Get-AzureArcPrerequisite -TestTLSVersion -NetworkTestMode Comprehensive

# Generate remediation scripts for identified issues
Get-AzureArcPrerequisite -UseStandardizedDirectory -GenerateRemediationScript
```

### New-AzureArcDevice
**Enterprise Azure Arc Device Deployment**

Creates Azure Arc devices with automated resource group setup, service principal management, and Group Policy deployment files for enterprise-scale installations.

```powershell
# Interactive device creation with guided prompts
New-AzureArcDevice

# Automated deployment with specific parameters
New-AzureArcDevice -ResourceGroupName "rg-azurearc" -Location "eastus" -Force

# Use standardized directory for organized deployment files
New-AzureArcDevice -UseStandardizedDirectory
```

### Get-AzureArcDiagnostic
**Advanced Azure Arc Diagnostics & Troubleshooting**

Collects comprehensive diagnostic data including agent health, connectivity testing, log collection, and performance analysis for troubleshooting Azure Arc deployments.

```powershell
# Basic diagnostic collection
Get-AzureArcDiagnostic

# Comprehensive diagnostics with organized output
Get-AzureArcDiagnostic -UseStandardizedDirectory
```

### Set-AzureArcResourcePricing
**Microsoft Defender for Servers Pricing Management**

Manages pricing tiers (Free, Standard P1, P2) for Microsoft Defender for Servers with flexible targeting by Resource Group, Tags, or individual resources.

```powershell
# Configure pricing for entire Resource Group
Set-AzureArcResourcePricing -Mode "RG" -ResourceGroupName "rg-production" -Action "standard"

# Configure pricing based on resource tags
Set-AzureArcResourcePricing -Mode "TAG" -TagName "Environment" -TagValue "Production" -Action "standard"

# Read current pricing configuration
Set-AzureArcResourcePricing -Mode "RG" -ResourceGroupName "rg-production" -Action "read"
```

## System Requirements

#### 🛡️ Enhanced Error Handling

The ServerProtection module implements professional-grade error handling designed for enterprise environments:

#### 🎨 User-Friendly Experience
- **Clean Output** - Only user-relevant information displayed in the console
- **Color-Coded Results** - Green for success, Yellow for warnings, Red for failures
- **No Technical Exceptions** - Raw PowerShell errors never shown to end users
- **Simple Status Reporting** - Clear Yes/No readiness indicators

#### 📊 Technical Logging
- **Detailed Logging** - All technical details automatically logged to files
- **Troubleshooting Support** - Complete error information available for support teams
- **Separate Log Files** - Different operations maintain separate log files for easy analysis
- **Timestamp Tracking** - All log entries include precise timestamps

#### 🔍 Error Categories
- **Prerequisites Failures** - Clear indication of missing requirements with remediation guidance
- **Network Issues** - User-friendly network connectivity problem descriptions
- **Authentication Problems** - Simplified Azure authentication failure messages
- **System Compatibility** - Easy-to-understand system requirement violations

This approach ensures that end users see only actionable, professional feedback while technical teams have access to comprehensive diagnostic information when needed.

---

## 📋 Prerequisites
- **PowerShell**: 5.1 or higher (PowerShell 7+ recommended)
- **Azure PowerShell**: Az.Accounts (v2.12.1+), Az.Resources (v6.0.0+)
- **Permissions**: Local administrator rights, Azure subscription access
- **Network**: Internet connectivity for Azure endpoint validation

### Azure Requirements
- Active Azure subscription
- Azure Arc service enabled in subscription
- Appropriate RBAC permissions (Contributor or custom roles)
- Network connectivity to Azure Arc endpoints

### Supported Operating Systems
- Windows Server 2012 R2 or later
- Windows Server Core installations supported
- Windows 10/11 (for testing purposes)

### Network Requirements
- Outbound HTTPS (443) access to Azure endpoints
- DNS resolution for Microsoft domains
- TLS 1.2 or higher support
- Proxy server support (if configured)

## Use Cases

### Enterprise Scenarios
- **Large-scale Azure Arc deployment** across multiple servers
- **Centralized prerequisites validation** before mass deployment
- **Group Policy-based agent installation** for domain-joined servers
- **Post-deployment pricing management** for cost optimization
- **Comprehensive diagnostics** for troubleshooting and support

### Typical Workflow
1. **Prerequisites Testing** - Validate all target servers meet requirements
2. **Device Creation** - Set up Azure Arc resources and deployment files
3. **Agent Deployment** - Use generated Group Policy for automated installation
4. **Diagnostics** - Monitor and troubleshoot deployed agents
5. **Pricing Management** - Configure Defender for Servers pricing tiers

## Version History

### v1.0.1 (Released - August 2025)
- **🔧 Code Quality Improvements** - Fixed PSScriptAnalyzer warnings for unused parameters
- **📋 Enhanced Documentation** - Updated publishing checklist and quality standards
- **✅ Validated Module Integrity** - Confirmed all functions work correctly after optimizations
- **🛡️ Maintained Professional Error Handling** - User-friendly messages with comprehensive technical logging
- **🎨 Preserved Enhanced User Experience** - Color-coded output with clean, professional feedback

### v1.0.0 (Released - August 2025)
- **🎯 Initial Release** - Complete enterprise-grade Azure Arc deployment solution
- **🔍 Prerequisites Testing** - Comprehensive system and network validation with TLS verification
- **🏗️ Device Creation** - Automated Azure Arc device setup with Group Policy deployment
- **📊 Diagnostics** - Advanced troubleshooting and log collection capabilities
- **💰 Pricing Management** - Resource-level Defender for Servers pricing configuration
- **🎮 Interactive Menu** - Professional command-line interface with guided workflows
- **📁 File Management** - Standardized directory system for organized output
- **🏢 Enterprise Support** - Multi-device batch processing and enterprise deployment features
- **📦 PowerShell Gallery** - Published and available for installation via Install-PSResource
- **🧹 Code Quality** - PowerShell Script Analyzer validated with production-ready code quality
- **🛡️ Professional Error Handling** - User-friendly messages with comprehensive technical logging
- **🎨 Enhanced User Experience** - Color-coded output with clean, professional feedback

## Author

**Lessi Coulibaly** - Less-IT (AI and CyberSecurity)
- 🌐 Website: [https://lessit.net](https://lessit.net)
- 📧 Contact: support@lessit.net
- 💼 Organization: Less-IT (AI and CyberSecurity)

*Specializing in enterprise Azure security solutions and PowerShell automation.*

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Follow PowerShell coding standards
4. Add appropriate help documentation
5. Test on Windows Server environments
6. Submit a pull request

For bugs and feature requests, use [GitHub Issues](https://github.com/coullessi/PowerShell/issues).

## Publishing Information

This module is available on the PowerShell Gallery and can be installed using:

```powershell
# Install the module
Install-PSResource ServerProtection

# Import and start using
Import-Module ServerProtection
Start-ServerProtection
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**© 2025 Less-IT (AI and CyberSecurity). All rights reserved.**
