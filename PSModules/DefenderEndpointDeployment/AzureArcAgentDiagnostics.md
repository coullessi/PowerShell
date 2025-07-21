# Azure Arc Agent Diagnostics - Integrated Module Function

> **✨ New in v1.1.0**: Now integrated as `Test-AzureArcDiagnostics` function with smooth, animated progress bar and realistic collection phases!

## Quick Start

### 1. Import the Module
```powershell
# Import the DefenderEndpointDeployment module
Import-Module DefenderEndpointDeployment
```

### 2. Access via Interactive Menu
```powershell
# Launch the interactive interface
Deploy-DefenderForServers

# Select option [9] Test-AzureArcDiagnostics from the menu
```

### 3. Direct Function Call
```powershell
# Run diagnostics directly
Test-AzureArcDiagnostics
```

### 4. Follow the Prompts
- When prompted for log storage location, press **Enter** to accept default `C:\ArcAgentLogs`
- Or type **N** and provide a custom path like `D:\MyLogs`

### 5. Wait for Completion
The function will:
- ✅ Test Azure connectivity
- ✅ Show machine metadata  
- ✅ List installed extensions
- ✅ Navigate to target directory
- ✅ Create log archive with smooth, animated progress showing collection phases

### 6. Find Your Logs
Look for the ZIP file in your chosen directory (default: `C:\ArcAgentLogs`)

## What's New in v1.1.0? 🎉
- **Integrated Module Function**: Now part of the DefenderEndpointDeployment module
- **Interactive Menu Access**: Available as option 9 in the main interactive interface  
- **Enhanced PowerShell Function**: Proper parameter support and help documentation
- **Smooth Animation**: Fluid progress bar with subtle animation effects
- **Realistic Phases**: Progress reflects actual collection phases:
  - **Initial Phase** (0-20%): Quick startup and initialization  
  - **Collection Phase** (20-60%): Gathering log files from various sources
  - **Compression Phase** (60-85%): Creating the ZIP archive
  - **Finalization Phase** (85-100%): Completing and verifying the archive
- **Better Integration**: Consistent styling with module branding
- **Enhanced Error Handling**: Improved job result processing and error reporting

## Function Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-LogPath` | Custom log storage path | User prompted |
| `-Location` | Azure region for testing | "eastus" |
| `-Silent` | Run without prompts | False |
| `-SkipPrompt` | Skip confirmation prompts | False |
| `-Force` | Force operation without confirmation | False |

## Usage Examples

### Interactive Mode
```powershell
Test-AzureArcDiagnostics
```

### Custom Path and Region
```powershell
Test-AzureArcDiagnostics -LogPath "D:\Logs" -Location "westus2"
```

### Silent/Automated Mode
```powershell
Test-AzureArcDiagnostics -LogPath "C:\ArcDiagnostics" -Silent -Force
```

## Troubleshooting

### ❌ "azcmagent not found"
- Install Azure Arc agent first
- Run as Administrator

### ❌ "Function not available"
- Ensure DefenderEndpointDeployment module is imported
- Verify module version is 1.1.0 or later:
```powershell
Get-Module DefenderEndpointDeployment | Select-Object Version
```

### ❌ "Access denied"
- Run PowerShell as Administrator
- Check folder permissions

### ❌ "Execution policy"
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Getting Help
Use PowerShell's built-in help system for detailed parameter information:
```powershell
Get-Help Test-AzureArcDiagnostics -Detailed
Get-Help Test-AzureArcDiagnostics -Examples
Get-Help Test-AzureArcDiagnostics -Full
```

## Need More Help?
See the full module documentation in `README.md` for comprehensive information and troubleshooting.
