# DefenderEndpointDeployment Module - Installation Guide

## 📦 Installation from PowerShell Gallery

### Using PSResourceGet (Recommended)

```powershell
# Install the module
Install-PSResource DefenderEndpointDeployment

# Import and run
Import-Module DefenderEndpointDeployment
Deploy-DefenderForServers
```

### Using PowerShellGet (Legacy)

```powershell
# Install the module  
Install-Module DefenderEndpointDeployment -Scope CurrentUser

# Import and run
Import-Module DefenderEndpointDeployment
Deploy-DefenderForServers
```

## 🚀 Quick Start

After installation, use the interactive menu system:

# Run validation tests
.\Test-Module.ps1

# Import and test the module
Import-Module .\DefenderEndpointDeployment.psd1 -Force

# Verify functions are available
Get-Command -Module DefenderEndpointDeployment

```powershell
# Start the interactive interface
Deploy-DefenderForServers

# Get help for specific functions
Get-Help New-AzureArcDevice -Full
Get-Help Test-AzureArcPrerequisites -Full
```

## � Requirements

- **PowerShell**: 5.1 or higher
- **Operating System**: Windows Server 2016+, Windows 10/11
- **Azure PowerShell**: Az.Accounts, Az.Resources modules
- **Permissions**: Local administrator rights, Azure subscription access

## 🏢 Author Information

- **Author**: Lessi Coulibaly
- **Organization**: Less-IT (AI and CyberSecurity)
- **Website**: https://lessit.net
