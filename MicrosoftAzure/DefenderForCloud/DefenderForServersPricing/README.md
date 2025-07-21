# ResourceLevelPricingAtScale PowerShell Module

## Overview

This PowerShell module provides functionality to configure Azure Defender for Cloud pricing settings at the resource level for Virtual Machines, Virtual Machine Scale Sets, and Azure Arc-enabled machines.

## Features

- ✅ **Resource Group targeting**: Configure pricing for all resources within a specific Resource Group
- ✅ **Tag-based targeting**: Configure pricing for all resources with specific tag name/value pairs
- ✅ **Multiple actions**: Read, Free, Standard (P1), or Delete pricing configurations
- ✅ **Interactive and automated modes**: Supports both interactive prompts and parameter-based automation
- ✅ **Comprehensive validation**: Resource group existence validation with exit options
- ✅ **Smart token management**: Optimized Azure token handling with automatic refresh
- ✅ **Enhanced user experience**: Clean output with emojis and clear section separators

## Prerequisites

- **PowerShell 5.1** or later
- **Azure PowerShell modules**:
  - Az.Accounts
  - Az.Profile
  - Az.Resources
- **Azure permissions**: Appropriate permissions for the target subscription and Azure Defender for Cloud

## Installation

1. Copy the module files to your PowerShell modules directory:
   ```powershell
   # Copy to user modules directory
   Copy-Item -Path "D:\Repo\PSScripts\MDC" -Destination "$env:USERPROFILE\Documents\PowerShell\Modules\ResourceLevelPricingAtScale" -Recurse
   
   # Or copy to system modules directory (requires admin)
   Copy-Item -Path "D:\Repo\PSScripts\MDC" -Destination "$env:ProgramFiles\PowerShell\Modules\ResourceLevelPricingAtScale" -Recurse
   ```

2. Import the module:
   ```powershell
   Import-Module ResourceLevelPricingAtScale
   ```

## Usage

### Interactive Mode

Run the script without parameters for interactive prompts:

```powershell
.\ResourceLevelPricingAtScale.ps1
```

### Automated Mode

Use parameters for automation scenarios:

```powershell
# Configure Standard pricing for all VMs in a Resource Group
.\ResourceLevelPricingAtScale.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -Mode "RG" -ResourceGroupName "myResourceGroup" -Action "standard"

# Read pricing configuration for resources with specific tags
.\ResourceLevelPricingAtScale.ps1 -Mode "TAG" -TagName "Environment" -TagValue "Production" -Action "read"

# Set Free pricing for all resources in a Resource Group
.\ResourceLevelPricingAtScale.ps1 -Mode "RG" -ResourceGroupName "testRG" -Action "free"
```

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `SubscriptionId` | String | No | Azure subscription ID. If not provided, user will be prompted |
| `ResourceGroupName` | String | No | Resource group name (when using RG mode) |
| `TagName` | String | No | Tag name (when using TAG mode) |
| `TagValue` | String | No | Tag value (when using TAG mode) |
| `Mode` | String | No | Operation mode: 'RG' or 'TAG' |
| `Action` | String | No | Action to perform: 'read', 'free', 'standard', or 'delete' |

## Actions

| Action | Description |
|--------|-------------|
| **READ** | View current pricing configuration |
| **FREE** | Remove Defender protection (set to Free tier) |
| **STANDARD** | Enable Defender for Cloud Plan 1 (P1) |
| **DELETE** | Remove resource-level configuration (inherit from parent) |

## Examples

### Example 1: Interactive Resource Group Configuration
```powershell
.\ResourceLevelPricingAtScale.ps1
# Follow the interactive prompts to:
# 1. Select subscription
# 2. Choose RG mode
# 3. Enter resource group name
# 4. Select action (read/free/standard/delete)
```

### Example 2: Automated Tag-Based Configuration
```powershell
.\ResourceLevelPricingAtScale.ps1 -Mode "TAG" -TagName "CostCenter" -TagValue "Finance" -Action "standard"
```

### Example 3: Reading Current Configuration
```powershell
.\ResourceLevelPricingAtScale.ps1 -SubscriptionId "your-sub-id" -Mode "RG" -ResourceGroupName "prod-rg" -Action "read"
```

## Output Sections

The script provides clear, organized output with the following sections:

1. 🔑 **Authentication & Setup**
2. 📋 **Subscription Selection**
3. 🎯 **Operation Mode Selection**
4. 📁 **Resource Configuration**
5. 🔐 **Token Acquisition**
6. 🔍 **Resource Discovery**
7. 📊 **Resource Summary**
8. ⚙️ **Action Selection**
9. 🔄 **Resource Processing**
10. 📊 **Final Summary**

## Error Handling

The script includes comprehensive error handling:

- ✅ Azure authentication validation
- ✅ Subscription existence validation
- ✅ Resource group existence validation with exit option
- ✅ Token expiration handling with automatic refresh
- ✅ API error handling with detailed error messages

## Security Considerations

- 🔒 Uses managed Azure authentication tokens
- 🔒 Implements token refresh only when needed (5-minute buffer)
- 🔒 No hardcoded credentials or sensitive information
- 🔒 Follows Azure PowerShell security best practices

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   ```powershell
   Connect-AzAccount
   Set-AzContext -SubscriptionId "your-subscription-id"
   ```

2. **Module Import Issues**
   ```powershell
   Import-Module Az.Accounts -Force
   Import-Module Az.Resources -Force
   ```

3. **Permission Issues**
   - Ensure you have appropriate Azure RBAC permissions
   - Verify Azure Defender for Cloud permissions

## Disclaimer

⚠️ **Important**: This script is provided "AS IS" without warranty of any kind. Use at your own risk. Always test in a non-production environment first. The authors are not responsible for any damage or data loss that may occur from using this script.

Please ensure you have appropriate permissions and understand the implications of changing Azure Defender for Cloud pricing configurations before proceeding.

## Version History

### v2.0.0
- Added comprehensive parameter support for automation
- Improved resource group validation with exit option  
- Added disclaimer and module-ready structure
- Enhanced user experience with emojis and clear sections
- Optimized token management for better performance
- Added line separators for better output organization
- Fixed PowerShell verb compliance issues

### v1.0.0
- Initial release with basic functionality

## Support

For issues and questions, please refer to the Azure Defender for Cloud documentation or contact your Azure administrator.
