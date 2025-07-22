# PowerShell Gallery Publishing Guide

## Module: DefenderEndpointDeployment v1.0.9

This guide provides instructions for publishing the DefenderEndpointDeployment module to the PowerShell Gallery using modern PowerShell commands.

## Pre-Publication Checklist ✅

- ✅ Module manifest validated (DefenderEndpointDeployment.psd1)
- ✅ All functions tested and working
- ✅ Documentation files present (README.md)
- ✅ License file present
- ✅ Version updated to 1.1.0

## Publishing Commands

### 1. Test Publishing (Dry Run)
```powershell
# Test the package before publishing
Publish-PSResource -Path . -Repository PSGallery -WhatIf -Verbose
```

### 2. Publish to PowerShell Gallery
```powershell
# Publish to PowerShell Gallery (requires API key)
Publish-PSResource -Path . -Repository PSGallery -ApiKey "Your-API-Key-Here" -Verbose
```

## Required Prerequisites

1. **PowerShell Gallery Account**: Create account at https://www.powershellgallery.com/
2. **API Key**: Generate API key from your PowerShell Gallery profile
3. **Microsoft.PowerShell.PSResourceGet Module**: Ensure you have latest version
   ```powershell
   Install-Module Microsoft.PowerShell.PSResourceGet -Force
   ```

## Post-Publication

After successful publication, users can install with:
```powershell
Install-PSResource DefenderEndpointDeployment
```

---
**Author**: Lessi Coulibaly  
**Company**: Less-IT (AI and CyberSecurity)  
**Website**: https://lessit.net
