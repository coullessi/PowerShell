# ServerProtection PowerShell Module

> **Enterprise-Grade Server Protection through Azure Arc Device Deployment & Microsoft Defender Endpoint Integration**

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Version](https://img.shields.io/badge/Version-1.0.0-brightgreen.svg)](https://github.com/LessIT/ServerProtection/releases)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PowerShell Gallery](https://img.shields.io/badge/PowerShell%20Gallery-ServerProtection-blue.svg)](https://www.powershellgallery.com/packages/ServerProtection)

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Functions](#functions)
- [System Requirements](#system-requirements)
- [Use Cases](#use-cases)
- [Version History](#version-history)
- [Author](#author)
- [Contributing](#contributing)
- [License](#license)

## Overview

The **ServerProtection** module provides a comprehensive PowerShell solution for enterprise server protection through Azure Arc-enabled servers and Microsoft Defender for Endpoint integration. Designed for large-scale environments, it delivers professional automation tools with an intuitive interactive interface and robust error handling for mission-critical deployments.

**Key Features:**
- **🔍 Comprehensive Prerequisites Testing** - Complete system validation including TLS requirements, network connectivity, and Azure authentication
- **🏗️ Automated Device Deployment** - Azure Arc device creation with Group Policy deployment for enterprise environments  
- **📊 Advanced Diagnostics** - Professional troubleshooting and log collection capabilities
- **💰 Pricing Management** - Post-deployment Defender for Servers pricing configuration
- **📁 Unified File Management** - Standardized directory system for organized file output
- **🎮 Interactive Interface** - User-friendly menu system with built-in help and guidance
- **🔐 Enterprise Authentication** - Automated Azure authentication and subscription management

## Installation

### PowerShell Gallery (Recommended)
```powershell
Install-PSResource ServerProtection
Import-Module ServerProtection
```

### GitHub
```powershell
git clone https://github.com/coullessi/ServerProtection.git
cd ServerProtection
Import-Module .\ServerProtection.psd1
```

## Quick Start

> **⭐ Always start with the interactive menu for guided operations**

```powershell
Import-Module ServerProtection
Start-ServerProtection
```

The interactive interface provides:
- **Menu-driven navigation** with numbered commands (1-5)
- **Built-in help system** with comprehensive documentation
- **Operation confirmations** for safe execution
- **Guided workflow** ensuring proper deployment sequence

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

### Prerequisites
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

### v1.0.0 (Current - July 2025)
- **🎯 Initial Release** - Complete enterprise-grade Azure Arc deployment solution
- **🔍 Prerequisites Testing** - Comprehensive system and network validation with TLS verification
- **🏗️ Device Creation** - Automated Azure Arc device setup with Group Policy deployment
- **📊 Diagnostics** - Advanced troubleshooting and log collection capabilities
- **💰 Pricing Management** - Resource-level Defender for Servers pricing configuration
- **🎮 Interactive Menu** - Professional command-line interface with guided workflows
- **📁 File Management** - Standardized directory system for organized output
- **🏢 Enterprise Support** - Multi-device batch processing and enterprise deployment features

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

For bugs and feature requests, use [GitHub Issues](https://github.com/LessIT/ServerProtection/issues).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**© 2025 Less-IT (AI and CyberSecurity). All rights reserved.**
