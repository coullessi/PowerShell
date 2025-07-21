# DefenderEndpointDeployment - Usage Examples

This document provides examples for using the DefenderEndpointDeployment PowerShell module.

## Basic Usage

### Interactive Menu System

```powershell
# Start the interactive interface
Import-Module DefenderEndpointDeployment
Deploy-DefenderForServers
```

### Prerequisites Check

```powershell
# Test prerequisites
Test-AzureArcPrerequisites
```

### Azure Arc Onboarding

```powershell
# Basic onboarding
New-AzureArcDevice -ResourceGroupName "rg-azurearc" -Location "East US"
```

### Connectivity Testing

```powershell
# Test Azure connectivity
Test-AzureConnectivity
```

## Function Examples

### Service Principal Creation

```powershell
# Create service principal for Azure Arc
New-ArcServicePrincipal -ServicePrincipalName "MyArcSP"
```

### Install Azure Connected Machine Agent

```powershell
# Install the agent
Install-AzureConnectedMachineAgent
```

### Register Azure Resource Providers

```powershell
# Register required providers
Register-AzureResourceProviders
```

### Deploy Group Policy

```powershell
# Deploy GPO for enterprise deployment
Deploy-ArcGroupPolicy -GPOName "Azure Arc Deployment"
```

---
**Author**: Lessi Coulibaly  
**Organization**: Less-IT (AI and CyberSecurity)  
**Website**: https://lessit.net
    "FIN-APP-01", "FIN-APP-02", "FIN-DB-01", 
    "FIN-WEB-01", "FIN-WEB-02", "FIN-FILE-01"
)

# Prerequisites check with user consent
Test-AzureArcPrerequisites -DeviceList $financeServers -RequireUserConsent

# Onboard with department-specific settings
New-AzureArcDevice `
    -ResourceGroupName "rg-finance-azurearc" `
    -Location "East US 2" `
    -ServicePrincipalName "Finance-ArcSP" `
    -GPOName "Finance Azure Arc Policy" `
    -TargetOUs @("OU=Finance,OU=Departments,DC=contoso,DC=com") `
    -Tags @{
        Department = "Finance"
        CostCenter = "CC-FIN-001"
        Environment = "Production"
        Owner = "finance-it@contoso.com"
    }
```

### 2. Multi-Location Deployment

```powershell
# Define locations and their servers
$locations = @{
    "NYC" = @{
        Servers = @("NYC-WEB-01", "NYC-APP-01", "NYC-DB-01")
        ResourceGroup = "rg-nyc-azurearc"
        Location = "East US"
        OU = "OU=NYC,OU=Locations,DC=contoso,DC=com"
    }
    "LAX" = @{
        Servers = @("LAX-WEB-01", "LAX-APP-01", "LAX-DB-01")
        ResourceGroup = "rg-lax-azurearc"
        Location = "West US 2"
        OU = "OU=LAX,OU=Locations,DC=contoso,DC=com"
    }
}

# Deploy to each location
foreach ($location in $locations.Keys) {
    $config = $locations[$location]
    
    Write-Host "🌎 Deploying Azure Arc for $location" -ForegroundColor Cyan
    
    # Test prerequisites
    Test-AzureArcPrerequisites -DeviceList $config.Servers
    
    # Deploy Azure Arc
    New-AzureArcDevice `
        -ResourceGroupName $config.ResourceGroup `
        -Location $config.Location `
        -ServicePrincipalName "$location-ArcSP" `
        -GPOName "$location Azure Arc Policy" `
        -TargetOUs @($config.OU) `
        -Tags @{
            Location = $location
            Environment = "Production"
        }
}
```

### 3. Staged Production Deployment

```powershell
# Phase 1: Development Environment
$devServers = @("DEV-WEB-01", "DEV-APP-01")

Write-Host "🧪 Phase 1: Development Environment" -ForegroundColor Green
Test-AzureArcPrerequisites -DeviceList $devServers
New-AzureArcDevice `
    -ResourceGroupName "rg-dev-azurearc" `
    -Location "East US" `
    -ServicePrincipalName "Dev-ArcSP" `
    -Tags @{ Environment = "Development" }

# Wait for validation
Read-Host "Press Enter after validating development deployment..."

# Phase 2: Staging Environment
$stagingServers = @("STG-WEB-01", "STG-APP-01", "STG-DB-01")

Write-Host "🔄 Phase 2: Staging Environment" -ForegroundColor Yellow
Test-AzureArcPrerequisites -DeviceList $stagingServers
New-AzureArcDevice `
    -ResourceGroupName "rg-staging-azurearc" `
    -Location "East US" `
    -ServicePrincipalName "Staging-ArcSP" `
    -Tags @{ Environment = "Staging" }

# Wait for validation
Read-Host "Press Enter after validating staging deployment..."

# Phase 3: Production Environment
$prodServers = Get-Content "C:\DeploymentLists\production-servers.txt"

Write-Host "🚀 Phase 3: Production Environment" -ForegroundColor Red
Test-AzureArcPrerequisites -DeviceList $prodServers -RequireUserConsent
New-AzureArcDevice `
    -ResourceGroupName "rg-prod-azurearc" `
    -Location "East US 2" `
    -ServicePrincipalName "Prod-ArcSP" `
    -GPOName "Production Azure Arc Policy" `
    -TargetOUs @("OU=Production,DC=contoso,DC=com") `
    -Tags @{ Environment = "Production" }
```

## Troubleshooting Examples

### 1. Connectivity Issues

```powershell
# Diagnose connectivity problems
$problemServers = @("PROBLEM-SRV-01", "PROBLEM-SRV-02")

foreach ($server in $problemServers) {
    Write-Host "🔍 Diagnosing $server" -ForegroundColor Cyan
    
    # Basic connectivity
    if (Test-Connection $server -Count 2 -Quiet) {
        Write-Host "  ✅ Ping successful" -ForegroundColor Green
        
        # PowerShell remoting
        try {
            Invoke-Command -ComputerName $server -ScriptBlock { Get-ComputerInfo } -ErrorAction Stop
            Write-Host "  ✅ PowerShell remoting works" -ForegroundColor Green
        } catch {
            Write-Host "  ❌ PowerShell remoting failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Azure connectivity
        Test-AzureConnectivity -ComputerName $server
    } else {
        Write-Host "  ❌ Ping failed - server unreachable" -ForegroundColor Red
    }
}
```

### 2. Authentication Troubleshooting

```powershell
# Clear and re-establish Azure connection
Write-Host "🔄 Clearing Azure authentication cache..." -ForegroundColor Yellow
Clear-AzContext -Force

Write-Host "🔐 Re-authenticating to Azure..." -ForegroundColor Yellow
Connect-AzAccount

# Verify authentication
$context = Get-AzContext
if ($context) {
    Write-Host "✅ Authentication successful" -ForegroundColor Green
    Write-Host "  Account: $($context.Account.Id)" -ForegroundColor Gray
    Write-Host "  Subscription: $($context.Subscription.Name)" -ForegroundColor Gray
    Write-Host "  Tenant: $($context.Tenant.Id)" -ForegroundColor Gray
} else {
    Write-Host "❌ Authentication failed" -ForegroundColor Red
}
```

### 3. Resource Provider Issues

```powershell
# Check and fix resource provider registration
Write-Host "🔍 Checking Azure resource provider status..." -ForegroundColor Cyan

$requiredProviders = @(
    "Microsoft.HybridCompute",
    "Microsoft.GuestConfiguration",
    "Microsoft.AzureArcData",
    "Microsoft.HybridConnectivity"
)

foreach ($provider in $requiredProviders) {
    $providerStatus = Get-AzResourceProvider -ProviderNamespace $provider
    $status = $providerStatus.RegistrationState
    
    Write-Host "  $provider`: $status" -ForegroundColor $(
        if ($status -eq "Registered") { "Green" } else { "Red" }
    )
    
    if ($status -ne "Registered") {
        Write-Host "    🔄 Registering $provider..." -ForegroundColor Yellow
        Register-AzResourceProvider -ProviderNamespace $provider
    }
}

# Re-run registration function
Register-AzureResourceProviders -ProviderNamespaces $requiredProviders
```

## Automation Scripts

### 1. Scheduled Prerequisites Check

```powershell
# Daily-PrerequisitesCheck.ps1
# Schedule this script to run daily via Task Scheduler

param(
    [string]$ServerListFile = "C:\Scripts\server-list.txt",
    [string]$LogFile = "C:\Logs\arc-prerequisites-$(Get-Date -Format 'yyyy-MM-dd').log"
)

# Start transcript
Start-Transcript -Path $LogFile -Append

try {
    # Import module
    Import-Module DefenderEndpointDeployment -Force
    
    # Get server list
    $servers = Get-Content $ServerListFile -ErrorAction Stop
    
    Write-Host "🔍 Starting daily prerequisites check for $($servers.Count) servers" -ForegroundColor Cyan
    
    # Run prerequisites check
    $result = Test-AzureArcPrerequisites -DeviceList $servers
    
    # Log results
    if ($result.OverallSuccess) {
        Write-Host "✅ All servers passed prerequisites check" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Some servers failed prerequisites check - review log for details" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Error during prerequisites check: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Stop-Transcript
}
```

### 2. Bulk Deployment Script

```powershell
# Bulk-ArcDeployment.ps1
# Deploy Azure Arc to multiple server groups

param(
    [string]$ConfigFile = "C:\Scripts\deployment-config.json"
)

# Load configuration
$config = Get-Content $ConfigFile | ConvertFrom-Json

foreach ($deployment in $config.Deployments) {
    Write-Host "🚀 Starting deployment: $($deployment.Name)" -ForegroundColor Cyan
    
    try {
        # Prerequisites check
        $prereqResult = Test-AzureArcPrerequisites -DeviceList $deployment.Servers
        
        if ($prereqResult.OverallSuccess) {
            # Deploy Azure Arc
            New-AzureArcDevice `
                -ResourceGroupName $deployment.ResourceGroup `
                -Location $deployment.Location `
                -ServicePrincipalName $deployment.ServicePrincipalName `
                -GPOName $deployment.GPOName `
                -TargetOUs $deployment.TargetOUs `
                -Tags $deployment.Tags
                
            Write-Host "✅ Deployment '$($deployment.Name)' completed successfully" -ForegroundColor Green
        } else {
            Write-Host "❌ Prerequisites failed for deployment '$($deployment.Name)'" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Error in deployment '$($deployment.Name)': $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Wait between deployments
    if ($deployment -ne $config.Deployments[-1]) {
        Write-Host "⏱️  Waiting 60 seconds before next deployment..." -ForegroundColor Yellow
        Start-Sleep -Seconds 60
    }
}
```

### 3. Health Check and Reporting

```powershell
# Arc-HealthCheck.ps1
# Generate health report for Azure Arc enabled servers

param(
    [string]$OutputPath = "C:\Reports\ArcHealthReport-$(Get-Date -Format 'yyyy-MM-dd-HHmm').html"
)

# Import module
Import-Module DefenderEndpointDeployment -Force

# Get Arc-enabled servers from Azure
$arcServers = Get-AzConnectedMachine

# Generate HTML report
$htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Azure Arc Health Report - $(Get-Date -Format 'yyyy-MM-dd HH:mm')</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .healthy { color: green; }
        .warning { color: orange; }
        .error { color: red; }
    </style>
</head>
<body>
    <h1>Azure Arc Health Report</h1>
    <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    <p>Total Arc-enabled servers: $($arcServers.Count)</p>
    
    <table>
        <tr>
            <th>Server Name</th>
            <th>Status</th>
            <th>OS</th>
            <th>Last Heartbeat</th>
            <th>Agent Version</th>
        </tr>
"@

foreach ($server in $arcServers) {
    $statusClass = switch ($server.Status) {
        "Connected" { "healthy" }
        "Disconnected" { "error" }
        default { "warning" }
    }
    
    $htmlReport += @"
        <tr>
            <td>$($server.Name)</td>
            <td class="$statusClass">$($server.Status)</td>
            <td>$($server.OSName)</td>
            <td>$($server.LastStatusChange)</td>
            <td>$($server.AgentVersion)</td>
        </tr>
"@
}

$htmlReport += @"
    </table>
</body>
</html>
"@

# Save report
$htmlReport | Out-File -FilePath $OutputPath -Encoding UTF8
Write-Host "📊 Health report generated: $OutputPath" -ForegroundColor Green
```

## Best Practices

### 1. Pre-Deployment Planning

```powershell
# Create deployment checklist
$checklist = @(
    "✅ Azure subscription and permissions verified",
    "✅ Network connectivity to Azure endpoints tested",
    "✅ Target servers inventory completed",
    "✅ Service principal strategy defined",
    "✅ Resource group naming convention established",
    "✅ Group Policy deployment plan created",
    "✅ Rollback procedure documented",
    "✅ Monitoring and alerting configured"
)

Write-Host "📋 Azure Arc Deployment Checklist:" -ForegroundColor Cyan
$checklist | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
```

### 2. Error Handling Template

```powershell
function Deploy-ArcWithErrorHandling {
    param(
        [string[]]$DeviceList,
        [string]$ResourceGroupName,
        [string]$Location
    )
    
    try {
        # Prerequisites check with error handling
        Write-Host "🔍 Checking prerequisites..." -ForegroundColor Yellow
        $prereqResult = Test-AzureArcPrerequisites -DeviceList $DeviceList
        
        if (-not $prereqResult.OverallSuccess) {
            throw "Prerequisites check failed for one or more devices"
        }
        
        # Azure Arc deployment with error handling
        Write-Host "🚀 Deploying Azure Arc..." -ForegroundColor Yellow
        $deployResult = New-AzureArcDevice -ResourceGroupName $ResourceGroupName -Location $Location
        
        if ($deployResult.Success) {
            Write-Host "✅ Deployment completed successfully" -ForegroundColor Green
            return $true
        } else {
            throw "Azure Arc deployment failed"
        }
        
    } catch {
        Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        
        # Log error details
        $errorDetails = @{
            Timestamp = Get-Date
            Error = $_.Exception.Message
            DeviceList = $DeviceList
            ResourceGroup = $ResourceGroupName
            Location = $Location
        }
        
        $errorDetails | ConvertTo-Json | Out-File "C:\Logs\arc-deployment-errors.json" -Append
        
        return $false
    }
}

# Usage
$success = Deploy-ArcWithErrorHandling -DeviceList @("SERVER01") -ResourceGroupName "rg-test" -Location "eastus"
```

### 3. Configuration Management

```powershell
# Standard deployment configuration
$standardConfig = @{
    # Development Environment
    Development = @{
        ResourceGroupPrefix = "rg-dev-azurearc"
        Location = "East US"
        ServicePrincipalPrefix = "Dev-ArcSP"
        Tags = @{
            Environment = "Development"
            CostCenter = "IT-DEV"
            AutoShutdown = "Yes"
        }
    }
    
    # Production Environment
    Production = @{
        ResourceGroupPrefix = "rg-prod-azurearc"
        Location = "East US 2"
        ServicePrincipalPrefix = "Prod-ArcSP"
        Tags = @{
            Environment = "Production"
            CostCenter = "IT-PROD"
            AutoShutdown = "No"
            Backup = "Required"
        }
    }
}

# Use standard configuration
function Deploy-WithStandardConfig {
    param(
        [ValidateSet("Development", "Production")]
        [string]$Environment,
        [string[]]$DeviceList,
        [string]$Department
    )
    
    $config = $standardConfig[$Environment]
    
    New-AzureArcDevice `
        -ResourceGroupName "$($config.ResourceGroupPrefix)-$Department" `
        -Location $config.Location `
        -ServicePrincipalName "$($config.ServicePrincipalPrefix)-$Department" `
        -Tags ($config.Tags + @{ Department = $Department })
}
```

This examples file provides comprehensive real-world scenarios that demonstrate the full capabilities of the DefenderEndpointDeployment module. Users can adapt these examples to their specific enterprise environments and requirements.
