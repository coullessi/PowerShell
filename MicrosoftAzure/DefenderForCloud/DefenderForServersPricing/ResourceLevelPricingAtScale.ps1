<#
.SYNOPSIS
    Configure Azure Defender for Cloud pricing at resource level for Virtual Machines, Virtual Machine Scale Sets, and ARC machines.

.DESCRIPTION
    This script allows you to configure Azure Defender for Cloud pricing settings at the resource level for:
    - Virtual Machines
    - Virtual Machine Scale Sets  
    - Azure Arc-enabled machines
    
    You can target resources either by Resource Group or by Tag, and perform the following actions:
    - READ: View current pricing configuration
    - FREE: Remove Defender protection (set to Free tier)
    - STANDARD: Enable Defender for Cloud Plan 1 (P1)
    - DELETE: Remove resource-level configuration (inherit from parent)

.PARAMETER SubscriptionId
    Optional. Azure subscription ID to use. If not provided, user will be prompted to select.

.PARAMETER ResourceGroupName
    Optional. Resource group name when using RG mode. If not provided, user will be prompted.

.PARAMETER TagName
    Optional. Tag name when using TAG mode. If not provided, user will be prompted.

.PARAMETER TagValue
    Optional. Tag value when using TAG mode. If not provided, user will be prompted.

.PARAMETER Mode
    Optional. Operation mode: 'RG' for Resource Group or 'TAG' for Tag-based selection.

.PARAMETER Action
    Optional. Action to perform: 'read', 'free', 'standard', or 'delete'.

.EXAMPLE
    .\ResourceLevelPricingAtScale.ps1
    Runs the script in interactive mode with prompts for all parameters.

.EXAMPLE
    .\ResourceLevelPricingAtScale.ps1 -Mode "RG" -ResourceGroupName "myRG" -Action "read"
    Reads pricing configuration for all resources in the specified resource group.

.NOTES
    Author: Microsoft
    Version: 2.0
    Last Updated: July 2025
    
    Requirements:
    - Azure PowerShell module (Az)
    - Appropriate Azure permissions for the target subscription and resources
    - Azure Defender for Cloud permissions

.DISCLAIMER
    This script is provided "AS IS" without warranty of any kind. Use at your own risk.
    Always test in a non-production environment first. The authors are not responsible 
    for any damage or data loss that may occur from using this script.
    
    Please ensure you have appropriate permissions and understand the implications 
    of changing Azure Defender for Cloud pricing configurations before proceeding.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$TagName,
    
    [Parameter(Mandatory=$false)]
    [string]$TagValue,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('RG', 'TAG')]
    [string]$Mode,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('read', 'free', 'standard', 'delete')]
    [string]$Action
)

# Initialize counters and arrays
$failureCount = 0
$successCount = 0
$vmSuccessCount = 0
$vmssSuccessCount = 0
$arcSuccessCount = 0
$vmCount = 0
$vmssCount = 0
$arcCount = 0
$vmResponseMachines = @()
$vmssResponseMachines = @()
$arcResponseMachines = @()

#region Authentication and Setup
Write-Host "🔑 Azure Authentication & Setup" -ForegroundColor Cyan

Clear-Host

# Check if user is authenticated, if not, authenticate
try {
    $context = Get-AzContext -ErrorAction Stop
    if (-not $context -or -not $context.Account) {
        Write-Host "🔑 No Azure authentication found. Authenticating..." -ForegroundColor Yellow
        Connect-AzAccount -ErrorAction Stop | Out-Null
        $context = Get-AzContext
    }
    Write-Host "✅ Authenticated as: $($context.Account.Id)" -ForegroundColor Green
}
catch {
    Write-Host "❌ Authentication failed. Please try again." -ForegroundColor Red
    Connect-AzAccount -ErrorAction Stop | Out-Null
    $context = Get-AzContext
    Write-Host "✅ Authenticated as: $($context.Account.Id)" -ForegroundColor Green
}

#endregion

#region Subscription Selection
Write-Host "📋 Subscription Selection" -ForegroundColor Cyan

$subs = @()
$subs += Get-AzSubscription
if ($subs.Count -eq 0) {
    Write-Host "❌ No subscription found. Exiting..." -ForegroundColor Red
    exit 1
}

# Use provided subscription or prompt user
if ($SubscriptionId) {
    $selectedSub = $subs | Where-Object { $_.Id -eq $SubscriptionId }
    if (-not $selectedSub) {
        Write-Host "❌ Subscription ID '$SubscriptionId' not found. Please check and try again." -ForegroundColor Red
        exit 1
    }
    $subName = $selectedSub.Name
    $subId = $selectedSub.Id
    Write-Host "✅ Using provided subscription: $subName" -ForegroundColor Green
} else {
    # Display available subscriptions
    Write-Host ""
    Write-Host "📋 Available subscription(s):" -ForegroundColor Green
    $subRanks = @()
    for ($i = 0; $i -lt $subs.Count; $i++) {
        "[$($i+1)] $($subs[$i].Name)"
        $subRanks += $i + 1
    }
    Write-Host
    $defaultSub = 1
    $subRank = Read-Host "Select a subscription (default: $defaultSub)"
    if ([string]::IsNullOrWhiteSpace($subRank)) { $subRank = $defaultSub }
    while ($subRank -notin $subRanks) {
        Write-Host "❌ Enter a valid number. The number must be between 1 and $($subRanks.Count)" -ForegroundColor Yellow
        $subRank = Read-Host "Select a subscription (default: $defaultSub)"
        if ([string]::IsNullOrWhiteSpace($subRank)) { $subRank = $defaultSub }
    }

    $subName = $subs[$subRank - 1].Name
    $subId = (Get-AzSubscription | Where-Object { $_.Name -like "*$subName*" }).Id
}

Set-AzContext -SubscriptionId $subId | Out-Null
#endregion

#region Operation Mode Selection
Write-Host "🎯 Operation Mode Selection" -ForegroundColor Cyan

# Use provided mode or prompt user
if ($Mode) {
    Write-Host "✅ Using provided mode: $Mode" -ForegroundColor Green
    $mode = $Mode
} else {
    $choices = @("RG", "TAG")
    Write-Host ""
    Write-Host "🎯 Operation Mode:" -ForegroundColor Green
    Write-Host "1. RG: `t`tSet pricing for all resources under a Resource Group"
    Write-Host "2. TAG: `tSet pricing for all resources with a specific tag"
    $defaultChoice = 1
    $choice = Read-Host "`nEnter your choice (1 or 2, default: $defaultChoice)"
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = $defaultChoice }
    while ($choice -notin 1..2) {
        Write-Host -ForegroundColor Yellow "❌ Invalid choice. Please enter a number between 1 and 2"
        $choice = Read-Host "`nEnter your choice (1 or 2, default: $defaultChoice)"
        if ([string]::IsNullOrWhiteSpace($choice)) { $choice = $defaultChoice }
    }
    $mode = $choices[$choice - 1]
}

#endregion

#region Resource Group/Tag Configuration
Write-Host "📁 Resource Configuration" -ForegroundColor Cyan

# Only show resource groups if RG mode is selected
if ($mode.ToLower() -eq "rg") {
    $azRGs = @()
    $azRGs += (Get-AzResourceGroup).ResourceGroupName

    if (-not $ResourceGroupName) {
        Write-Host ""
        Write-Host "📁 Resource groups in '$subName' subscription:" -ForegroundColor Green
        $rgNumbers = @()
        for ($i = 0; $i -lt $azRGs.Count; $i++) {
            "$($i+1). $($azRGs[$i])"
            $rgNumbers += $i + 1
        }
        Write-Host ""
        Write-Host "Note: Enter a valid resource group name or type 'exit' to quit the script." -ForegroundColor Yellow
        
        do {
            $resourceGroupName = Read-Host "Enter the name of the resource group"
            
            if ($resourceGroupName.ToLower() -eq 'exit') {
                Write-Host "👋 Exiting script as requested." -ForegroundColor Yellow
                exit 0
            }
            
            if ([string]::IsNullOrWhiteSpace($resourceGroupName)) {
                Write-Host "❌ Resource group name cannot be empty. Please enter a valid name or 'exit' to quit." -ForegroundColor Red
                continue
            }
            
            # Verify the resource group exists
            try {
                $rg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction Stop
                Write-Host "✅ Found resource group: $($rg.ResourceGroupName) in location: $($rg.Location)" -ForegroundColor Green
                break
            }
            catch {
                Write-Host "❌ Resource group '$resourceGroupName' not found in subscription '$subName'." -ForegroundColor Red
                Write-Host "Please verify the resource group name, enter a valid name, or type 'exit' to quit." -ForegroundColor Yellow
            }
        } while ($true)
    } else {
        # Verify provided resource group exists
        try {
            $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
            Write-Host "✅ Using provided resource group: $($rg.ResourceGroupName) in location: $($rg.Location)" -ForegroundColor Green
            $resourceGroupName = $ResourceGroupName
        }
        catch {
            Write-Host "❌ Resource group '$ResourceGroupName' not found in subscription '$subName'." -ForegroundColor Red
            exit 1
        }
    }
}

#endregion

# Function to get fresh access token
function Get-FreshAccessToken {
    try {
        # Ensure we have a valid Azure context first
        $context = Get-AzContext -ErrorAction Stop
        if (-not $context -or -not $context.Account) {
            throw "No Azure context found. Please run Connect-AzAccount first."
        }
        
        # Get tenant name instead of ID
        $tenant = Get-AzTenant -TenantId $context.Tenant.Id -ErrorAction SilentlyContinue
        $tenantName = if ($tenant -and $tenant.Name) { $tenant.Name } else { "Unknown Tenant" }
        Write-Host "🏢 Getting token for tenant: $tenantName" -ForegroundColor Cyan
        
        # Get token specifically for Azure Resource Manager with explicit tenant
        $tokenInfo = Get-AzAccessToken -ResourceUrl "https://management.azure.com/" -TenantId $context.Tenant.Id -ErrorAction Stop
        
        # Handle both current string format and future SecureString format
        $tokenValue = $tokenInfo.Token
        if ($tokenValue -is [System.Security.SecureString]) {
            # Convert SecureString to plain text
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenValue)
            $tokenValue = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
        
        Write-Host "✅ Token obtained successfully" -ForegroundColor Green
        
        return @{
            Token = $tokenValue
            ExpiresOn = $tokenInfo.ExpiresOn.LocalDateTime
        }
    }
    catch {
        Write-Host "❌ Failed to get access token: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please ensure you are logged in to Azure with 'Connect-AzAccount'" -ForegroundColor Yellow
        throw $_
    }
}

# Function to check if token needs refresh and refresh if needed
function Update-TokenIfNeeded {
    param(
        [ref]$AccessToken,
        [ref]$ExpiresOn
    )
    
    $currentTime = Get-Date
    $bufferMinutes = 5  # Refresh token 5 minutes before expiry
    
    if ($currentTime.AddMinutes($bufferMinutes) -ge $ExpiresOn.Value) {
        Write-Host "🔄 Token is about to expire, refreshing..." -ForegroundColor Yellow
        try {
            $tokenInfo = Get-FreshAccessToken
            $AccessToken.Value = $tokenInfo.Token
            $ExpiresOn.Value = $tokenInfo.ExpiresOn
            Write-Host "✅ Token refreshed successfully. New expiry: $($ExpiresOn.Value)" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Failed to refresh token: $($_.Exception.Message)" -ForegroundColor Red
            throw $_
        }
    }
}

# Function to format pricing configuration as a readable table
function Format-PricingConfiguration {
    param(
        [Parameter(Mandatory=$true)]
        $PricingResponse,
        [Parameter(Mandatory=$true)]
        [string]$ResourceName
    )
    
    Write-Host "📋 Pricing Configuration for: $ResourceName" -ForegroundColor Cyan
    
    if ($PricingResponse -and $PricingResponse.properties) {
        $props = $PricingResponse.properties
        
        # Create a custom object for table formatting
        $configTable = [PSCustomObject]@{
            'Property' = @()
            'Value' = @()
        }
        
        # Add basic properties
        if ($props.pricingTier) {
            $configTable.Property += "Pricing Tier"
            $configTable.Value += $props.pricingTier.ToUpper()
        }
        
        if ($props.subPlan) {
            $configTable.Property += "Sub Plan"
            $configTable.Value += $props.subPlan
        }
        
        if ($props.freeTrialRemainingTime) {
            $configTable.Property += "Free Trial Remaining"
            $configTable.Value += $props.freeTrialRemainingTime
        }
        
        if ($props.enablementTime) {
            $configTable.Property += "Enablement Time"
            $configTable.Value += $props.enablementTime
        }
        
        if ($props.deprecated) {
            $configTable.Property += "Deprecated"
            $configTable.Value += $props.deprecated
        }
        
        # Display the formatted table
        for ($i = 0; $i -lt $configTable.Property.Count; $i++) {
            $property = $configTable.Property[$i]
            $value = $configTable.Value[$i]
            Write-Host ("{0,-25}: {1}" -f $property, $value) -ForegroundColor White
        }
        
        # Display extensions if they exist
        if ($props.extensions -and $props.extensions.Count -gt 0) {
            Write-Host "`n🔧 Extensions:" -ForegroundColor Yellow
            foreach ($extension in $props.extensions) {
                Write-Host ("  Name: {0}" -f $extension.name) -ForegroundColor White
                if ($extension.isEnabled) {
                    Write-Host ("  Status: {0}" -f $(if ($extension.isEnabled -eq $true) { "Enabled" } else { "Disabled" })) -ForegroundColor $(if ($extension.isEnabled -eq $true) { "Green" } else { "Red" })
                }
                if ($extension.additionalExtensionProperties) {
                    Write-Host "  Additional Properties:" -ForegroundColor Gray
                    $extension.additionalExtensionProperties.PSObject.Properties | ForEach-Object {
                        Write-Host ("    {0}: {1}" -f $_.Name, $_.Value) -ForegroundColor Gray
                    }
                }
                Write-Host ""
            }
        }
    }
    else {
        Write-Host "⚠️ No pricing configuration data available" -ForegroundColor Yellow
    }
    
    # Display resource metadata
    if ($PricingResponse.name) {
        Write-Host "`n📝 Resource Information:" -ForegroundColor Magenta
        Write-Host ("Configuration Name: {0}" -f $PricingResponse.name) -ForegroundColor White
    }
    if ($PricingResponse.type) {
        Write-Host ("Resource Type: {0}" -f $PricingResponse.type) -ForegroundColor White
    }
}

#region Token Acquisition
Write-Host "🔐 Token Acquisition" -ForegroundColor Cyan

# Get initial token
try {
    Write-Host "🔐 Obtaining access token..." -ForegroundColor Yellow
    $tokenInfo = Get-FreshAccessToken
    $accessToken = $tokenInfo.Token
    $expireson = $tokenInfo.ExpiresOn
    Write-Host "✅ Token obtained successfully. Expires: $expireson" -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to obtain access token: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please run 'Connect-AzAccount' and try again." -ForegroundColor Yellow
    exit 1
}

# Define variables for authentication and resource group
$SubscriptionId = $subId

#endregion

#region Resource Discovery
Write-Host "🔍 Resource Discovery" -ForegroundColor Cyan

if ($mode.ToLower() -eq "rg") {
    # Fetch resources under a given Resource Group
    try {
        Write-Host "🔄 Fetching resources from Resource Group '$resourceGroupName'..." -ForegroundColor Yellow
        
        # Check if token needs refresh before API calls
        Update-TokenIfNeeded -AccessToken ([ref]$accessToken) -ExpiresOn ([ref]$expireson)
        
        # Get all virtual machines, VMSSs, and ARC machines in the resource group
        $vmUrl = "https://management.azure.com/subscriptions/" + $SubscriptionId + "/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines?api-version=2021-04-01"
        
        do{
            $vmResponse = Invoke-RestMethod -Method Get -Uri $vmUrl -Headers @{Authorization = "Bearer $accessToken"} -TimeoutSec 120
            $vmResponseMachines += $vmResponse.value 
            $vmUrl = $vmResponse.nextLink
        } while (![string]::IsNullOrEmpty($vmUrl))
        Write-Host "✅ Found $($vmResponseMachines.Count) VMs" -ForegroundColor Green

        $vmssUrl = "https://management.azure.com/subscriptions/" + $SubscriptionId + "/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachineScaleSets?api-version=2021-04-01"
        do{
            $vmssResponse = Invoke-RestMethod -Method Get -Uri $vmssUrl -Headers @{Authorization = "Bearer $accessToken"} -TimeoutSec 120
            $vmssResponseMachines += $vmssResponse.value
            $vmssUrl = $vmssResponse.nextLink
        } while (![string]::IsNullOrEmpty($vmssUrl))
        Write-Host "✅ Found $($vmssResponseMachines.Count) VMSSs" -ForegroundColor Green
        
        $arcUrl = "https://management.azure.com/subscriptions/" + $SubscriptionId + "/resourceGroups/$resourceGroupName/providers/Microsoft.HybridCompute/machines?api-version=2022-12-27"
        do{
            $arcResponse = Invoke-RestMethod -Method Get -Uri $arcUrl -Headers @{Authorization = "Bearer $accessToken"} -TimeoutSec 120
            $arcResponseMachines += $arcResponse.value
            $arcUrl = $arcResponse.nextLink
        } while (![string]::IsNullOrEmpty($arcUrl))
        Write-Host "✅ Found $($arcResponseMachines.Count) ARC machines" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to get resources!" -ForegroundColor Red
        if ($_.Exception.Response.StatusCode.value__ -eq 401) {
            Write-Host "Authentication failed. Token may be invalid or expired." -ForegroundColor Red
            Write-Host "Please try running 'Connect-AzAccount' and run the script again." -ForegroundColor Yellow
        }
        Write-Host "Response StatusCode:" $_.Exception.Response.StatusCode.value__  -ForegroundColor Red
        Write-Host "Response StatusDescription:" $_.Exception.Response.StatusDescription -ForegroundColor Red
        Write-Host "Error from response:" $_.ErrorDetails -ForegroundColor Red
        exit 1
    }
} elseif ($mode.ToLower() -eq "tag") {
    # Fetch resources with a given tagName and tagValue
    if (-not $TagName) {
        $defaultTagName = "Environment"
        $tagName = Read-Host "Enter the name of the tag (default: $defaultTagName)"
        if ([string]::IsNullOrWhiteSpace($tagName)) { $tagName = $defaultTagName }
    } else {
        $tagName = $TagName
        Write-Host "✅ Using provided tag name: $tagName" -ForegroundColor Green
    }
    
    if (-not $TagValue) {
        $defaultTagValue = "Production"
        $tagValue = Read-Host "Enter the value of the tag (default: $defaultTagValue)"
        if ([string]::IsNullOrWhiteSpace($tagValue)) { $tagValue = $defaultTagValue }
    } else {
        $tagValue = $TagValue
        Write-Host "✅ Using provided tag value: $tagValue" -ForegroundColor Green
    }
    
    try {
        Write-Host "🔄 Fetching resources by tag '$tagName=$tagValue'..." -ForegroundColor Yellow
        
        # Check if token needs refresh before API calls
        Update-TokenIfNeeded -AccessToken ([ref]$accessToken) -ExpiresOn ([ref]$expireson)
        
        # Get all virtual machines, VMSSs, and ARC machines based on the given tag
        $vmUrl = "https://management.azure.com/subscriptions/" + $SubscriptionId + "/resources?`$filter=resourceType eq 'Microsoft.Compute/virtualMachines'&api-version=2021-04-01"
        do{
            $vmResponse = Invoke-RestMethod -Method Get -Uri $vmUrl -Headers @{Authorization = "Bearer $accessToken"} -TimeoutSec 120
            $vmResponseMachines += $vmResponse.value | Where-Object {$_.tags.$tagName -eq $tagValue}
            $vmUrl = $vmResponse.nextLink
        } while (![string]::IsNullOrEmpty($vmUrl))
        Write-Host "✅ Found $($vmResponseMachines.Count) VMs with tag '$tagName=$tagValue'" -ForegroundColor Green
        
        $vmssUrl = "https://management.azure.com/subscriptions/" + $SubscriptionId + "/resources?`$filter=resourceType eq 'Microsoft.Compute/virtualMachineScaleSets'&api-version=2021-04-01"
        do{
            $vmssResponse = Invoke-RestMethod -Method Get -Uri $vmssUrl -Headers @{Authorization = "Bearer $accessToken"} -TimeoutSec 120
            $vmssResponseMachines += $vmssResponse.value | Where-Object {$_.tags.$tagName -eq $tagValue}
            $vmssUrl = $vmssResponse.nextLink
        } while (![string]::IsNullOrEmpty($vmssUrl))
        Write-Host "✅ Found $($vmssResponseMachines.Count) VMSSs with tag '$tagName=$tagValue'" -ForegroundColor Green
        
        $arcUrl = "https://management.azure.com/subscriptions/" + $SubscriptionId + "/resources?`$filter=resourceType eq 'Microsoft.HybridCompute/machines'&api-version=2023-07-01"
        do{
            $arcResponse = Invoke-RestMethod -Method Get -Uri $arcUrl -Headers @{Authorization = "Bearer $accessToken"} -TimeoutSec 120
            $arcResponseMachines += $arcResponse.value | Where-Object {$_.tags.$tagName -eq $tagValue}
            $arcUrl = $arcResponse.nextLink
        } while (![string]::IsNullOrEmpty($arcUrl))
        Write-Host "✅ Found $($arcResponseMachines.Count) ARC machines with tag '$tagName=$tagValue'" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to get resources!" -ForegroundColor Red
        if ($_.Exception.Response.StatusCode.value__ -eq 401) {
            Write-Host "Authentication failed. Token may be invalid or expired." -ForegroundColor Red
            Write-Host "Please try running 'Connect-AzAccount' and run the script again." -ForegroundColor Yellow
        }
        Write-Host "Response StatusCode:" $_.Exception.Response.StatusCode.value__  -ForegroundColor Red
        Write-Host "Response StatusDescription:" $_.Exception.Response.StatusDescription -ForegroundColor Red
        Write-Host "Error from response:" $_.ErrorDetails -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "❌ Entered invalid mode. Exiting script." -ForegroundColor Red
    exit 1;
}

#endregion

#region Resource Summary
Write-Host "📊 Resource Summary" -ForegroundColor Cyan

# Display found resources
Write-Host "🔍 Found the following resources:" -ForegroundColor Green

Write-Host "`n💻 Virtual Machines ($($vmResponseMachines.Count)):" -ForegroundColor Cyan
if ($vmResponseMachines.Count -gt 0) {
    $count = 0
    foreach ($machine in $vmResponseMachines) {
        $count++
        Write-Host "  $count. $($machine.name)" -ForegroundColor White
        $vmCount = $count
    }
} else {
    Write-Host "  No virtual machines found" -ForegroundColor Gray
}

Write-Host "`n🔧 Virtual Machine Scale Sets ($($vmssResponseMachines.Count)):" -ForegroundColor Cyan
if ($vmssResponseMachines.Count -gt 0) {
    $count = 0
    foreach ($machine in $vmssResponseMachines) {
        $count++
        Write-Host "  $count. $($machine.name)" -ForegroundColor White
        $vmssCount = $count
    }
} else {
    Write-Host "  No virtual machine scale sets found" -ForegroundColor Gray
}

Write-Host "`n🖥️ ARC Machines ($($arcResponseMachines.Count)):" -ForegroundColor Cyan
if ($arcResponseMachines.Count -gt 0) {
    $count = 0
    foreach ($machine in $arcResponseMachines) {
        $count++
        Write-Host "  $count. $($machine.name)" -ForegroundColor White
        $arcCount = $count
    }
} else {
    Write-Host "  No ARC machines found" -ForegroundColor Gray
}

#endregion

#region Action Selection
Write-Host "⚙️ Action Selection" -ForegroundColor Cyan

# Use provided action or prompt user
if ($Action) {
    Write-Host "✅ Using provided action: $($Action.ToUpper())" -ForegroundColor Green
    $PricingTier = $Action.ToLower()
} else {
    Write-Host ""
    Write-Host "⚙️ Choose your action:" -ForegroundColor Green
    Write-Host "1. READ: `tRead the current configuration"
    Write-Host "2. FREE: `tRemove the Defender protection"
    Write-Host "3. STANDARD: `tEnable 'P1'"
    Write-Host "4. DELETE: `tThe resource will inherit the parent's configuration"

    $choices = @("read", "free", "standard", "delete")
    Write-Host
    $defaultPricingChoice = 1
    $choice = Read-Host "Enter your choice (1, 2, 3, or 4, default: $defaultPricingChoice)"
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = $defaultPricingChoice }
    while ($choice -notin 1..4) {
        Write-Host -ForegroundColor Yellow "❌ Invalid choice. Please enter a number between 1 and 4"
        $choice = Read-Host "Enter the number corresponding to your choice (default: $defaultPricingChoice)"
        if ([string]::IsNullOrWhiteSpace($choice)) { $choice = $defaultPricingChoice }
    }
    $PricingTier = $choices[$choice - 1]
}

#endregion

#region Resource Processing
Write-Host "🔄 Resource Processing" -ForegroundColor Cyan

# Process Virtual Machines
if ($vmResponseMachines.Count -gt 0) {
    Write-Host "🔄 Processing Virtual Machines:" -ForegroundColor Cyan
    foreach ($machine in $vmResponseMachines) {
        # Check if token needs refresh, refresh only if needed
        Update-TokenIfNeeded -AccessToken ([ref]$accessToken) -ExpiresOn ([ref]$expireson)
        
        $pricingUrl = "https://management.azure.com$($machine.id)/providers/Microsoft.Security/pricings/virtualMachines?api-version=2024-01-01"
        if($PricingTier.ToLower() -eq "free") {
            $pricingBody = @{
                "properties" = @{
                    "pricingTier" = $PricingTier
                }
            }
        } else {
            $subplan = "P1"
            $pricingBody = @{
                "properties" = @{
                    "pricingTier" = $PricingTier
                    "subPlan" = $subplan
                }
            }
        }
        Write-Host "🔄 Processing pricing configuration for '$($machine.name)':"
        try {
            if($PricingTier.ToLower() -eq "delete") {
                $pricingResponse = Invoke-RestMethod -Method Delete -Uri $pricingUrl -Headers @{Authorization = "Bearer $accessToken"} -ContentType "application/json" -TimeoutSec 120
                Write-Host "✅ Successfully deleted pricing configuration for $($machine.name)" -ForegroundColor Green
                $successCount++
                $vmSuccessCount++
            } elseif ($PricingTier.ToLower() -eq "read") {
                $pricingResponse = Invoke-RestMethod -Method Get -Uri $pricingUrl -Headers @{Authorization = "Bearer $accessToken"} -ContentType "application/json" -TimeoutSec 120
                Write-Host "✅ Successfully read pricing configuration for $($machine.name)" -ForegroundColor Green
                Format-PricingConfiguration -PricingResponse $pricingResponse -ResourceName $machine.name
                $successCount++
                $vmSuccessCount++
            } else {
                $pricingResponse = Invoke-RestMethod -Method Put -Uri $pricingUrl -Headers @{Authorization = "Bearer $accessToken"} -Body ($pricingBody | ConvertTo-Json) -ContentType "application/json" -TimeoutSec 120
                Write-Host "✅ Successfully updated pricing configuration for $($machine.name)" -ForegroundColor Green
                $successCount++
                $vmSuccessCount++
            }
        }
        catch {
            $failureCount++
            Write-Host "❌ Failed to update pricing configuration for $($machine.name)" -ForegroundColor Red
            Write-Host "Response StatusCode:" $_.Exception.Response.StatusCode.value__  -ForegroundColor Red
            Write-Host "Response StatusDescription:" $_.Exception.Response.StatusDescription -ForegroundColor Red
            Write-Host "Error from response:" $_.ErrorDetails -ForegroundColor Red
        }
        Write-Host ""
        Start-Sleep -Seconds 0.3
    }
    Write-Host "-" * 80 -ForegroundColor DarkGray
}

# Process Virtual Machine Scale Sets
if ($vmssResponseMachines.Count -gt 0) {
    Write-Host "🔄 Processing Virtual Machine Scale Sets:" -ForegroundColor Cyan
    foreach ($machine in $vmssResponseMachines) {
        # Check if token needs refresh, refresh only if needed
        Update-TokenIfNeeded -AccessToken ([ref]$accessToken) -ExpiresOn ([ref]$expireson)
        
        $pricingUrl = "https://management.azure.com$($machine.id)/providers/Microsoft.Security/pricings/virtualMachines?api-version=2024-01-01"
        if($PricingTier.ToLower() -eq "free") {
            $pricingBody = @{
                "properties" = @{
                    "pricingTier" = $PricingTier
                }
            }
        } else {
            $subplan = "P1"
            $pricingBody = @{
                "properties" = @{
                    "pricingTier" = $PricingTier
                    "subPlan" = $subplan
                }
            }
        }
        Write-Host "🔄 Processing pricing configuration for '$($machine.name)':"
        try {
            if($PricingTier.ToLower() -eq "delete") {
                $pricingResponse = Invoke-RestMethod -Method Delete -Uri $pricingUrl -Headers @{Authorization = "Bearer $accessToken"} -ContentType "application/json" -TimeoutSec 120
                Write-Host "✅ Successfully deleted pricing configuration for $($machine.name)" -ForegroundColor Green
                $successCount++
                $vmssSuccessCount++
            } elseif ($PricingTier.ToLower() -eq "read") {
                $pricingResponse = Invoke-RestMethod -Method Get -Uri $pricingUrl -Headers @{Authorization = "Bearer $accessToken"} -ContentType "application/json" -TimeoutSec 120
                Write-Host "✅ Successfully read pricing configuration for $($machine.name)" -ForegroundColor Green
                Format-PricingConfiguration -PricingResponse $pricingResponse -ResourceName $machine.name
                $successCount++
                $vmssSuccessCount++
            } else {
                $pricingResponse = Invoke-RestMethod -Method Put -Uri $pricingUrl -Headers @{Authorization = "Bearer $accessToken"} -Body ($pricingBody | ConvertTo-Json) -ContentType "application/json" -TimeoutSec 120
                Write-Host "✅ Successfully updated pricing configuration for $($machine.name)" -ForegroundColor Green
                $successCount++
                $vmssSuccessCount++
            }
        }
        catch {
            $failureCount++
            Write-Host "❌ Failed to update pricing configuration for $($machine.name)" -ForegroundColor Red
            Write-Host "Response StatusCode:" $_.Exception.Response.StatusCode.value__  -ForegroundColor Red
            Write-Host "Response StatusDescription:" $_.Exception.Response.StatusDescription -ForegroundColor Red
            Write-Host "Error from response:" $_.ErrorDetails -ForegroundColor Red
        }
        Write-Host ""
        Start-Sleep -Seconds 0.3
    }
    Write-Host "-" * 80 -ForegroundColor DarkGray
}

# Process ARC Machines
if ($arcResponseMachines.Count -gt 0) {
    Write-Host "🔄 Processing ARC Machines:" -ForegroundColor Cyan
    foreach ($machine in $arcResponseMachines) {
        # Check if token needs refresh, refresh only if needed
        Update-TokenIfNeeded -AccessToken ([ref]$accessToken) -ExpiresOn ([ref]$expireson)
        
        $pricingUrl = "https://management.azure.com$($machine.id)/providers/Microsoft.Security/pricings/virtualMachines?api-version=2024-01-01"
        if($PricingTier.ToLower() -eq "free") {
            $pricingBody = @{
                "properties" = @{
                    "pricingTier" = $PricingTier
                }
            }
        } else {
            $subplan = "P1"
            $pricingBody = @{
                "properties" = @{
                    "pricingTier" = $PricingTier
                    "subPlan" = $subplan
                }
            }
        }
        Write-Host "🔄 Processing pricing configuration for '$($machine.name)':"
        try {
            if($PricingTier.ToLower() -eq "delete") {
                $pricingResponse = Invoke-RestMethod -Method Delete -Uri $pricingUrl -Headers @{Authorization = "Bearer $accessToken"} -ContentType "application/json" -TimeoutSec 120
                Write-Host "✅ Successfully deleted pricing configuration for $($machine.name)" -ForegroundColor Green
                $successCount++
                $arcSuccessCount++
            } elseif ($PricingTier.ToLower() -eq "read") {
                $pricingResponse = Invoke-RestMethod -Method Get -Uri $pricingUrl -Headers @{Authorization = "Bearer $accessToken"} -ContentType "application/json" -TimeoutSec 120
                Write-Host "✅ Successfully read pricing configuration for $($machine.name)" -ForegroundColor Green
                Format-PricingConfiguration -PricingResponse $pricingResponse -ResourceName $machine.name
                $successCount++
                $arcSuccessCount++
            } else {
                $pricingResponse = Invoke-RestMethod -Method Put -Uri $pricingUrl -Headers @{Authorization = "Bearer $accessToken"} -Body ($pricingBody | ConvertTo-Json) -ContentType "application/json" -TimeoutSec 120
                Write-Host "✅ Successfully updated pricing configuration for $($machine.name)" -ForegroundColor Green
                $successCount++
                $arcSuccessCount++
            }
        }
        catch {
            $failureCount++
            Write-Host "❌ Failed to update pricing configuration for $($machine.name)" -ForegroundColor Red
            Write-Host "Response StatusCode:" $_.Exception.Response.StatusCode.value__  -ForegroundColor Red
            Write-Host "Response StatusDescription:" $_.Exception.Response.StatusDescription -ForegroundColor Red
            Write-Host "Error from response:" $_.ErrorDetails -ForegroundColor Red
        }
        Write-Host ""
        Start-Sleep -Seconds 0.3
    }
}

#endregion

#region Final Summary
Write-Host "📊 Final Summary" -ForegroundColor Cyan

Write-Host "📊 Summary of Pricing API Results:" -ForegroundColor Green

Write-Host ""
Write-Host "💻 Virtual Machines:" -ForegroundColor Cyan
Write-Host "   Found: $vmCount" -ForegroundColor White
Write-Host "   ✅ Successful: $vmSuccessCount" -ForegroundColor Green
Write-Host "   ❌ Failed: $($vmCount - $vmSuccessCount)" -ForegroundColor $(if ($($vmCount - $vmSuccessCount) -gt 0) {'Red'} else {'Green'})

Write-Host ""
Write-Host "🔧 Virtual Machine Scale Sets:" -ForegroundColor Cyan
Write-Host "   Found: $vmssCount" -ForegroundColor White
Write-Host "   ✅ Successful: $vmssSuccessCount" -ForegroundColor Green
Write-Host "   ❌ Failed: $($vmssCount - $vmssSuccessCount)" -ForegroundColor $(if ($($vmssCount - $vmssSuccessCount) -gt 0) {'Red'} else {'Green'})

Write-Host ""
Write-Host "🖥️ ARC Machines:" -ForegroundColor Cyan
Write-Host "   Found: $arcCount" -ForegroundColor White
Write-Host "   ✅ Successful: $arcSuccessCount" -ForegroundColor Green
Write-Host "   ❌ Failed: $($arcCount - $arcSuccessCount)" -ForegroundColor $(if ($($arcCount - $arcSuccessCount) -gt 0) {'Red'} else {'Green'})

Write-Host ""
Write-Host "🎯 Overall Results:" -ForegroundColor Magenta
Write-Host "   ✅ Total Successful: $successCount" -ForegroundColor Green
Write-Host "   ❌ Total Failures: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) {'Red'} else {'Green'})

Write-Host ""
Write-Host "Script execution completed!`n" -ForegroundColor Green
#endregion
