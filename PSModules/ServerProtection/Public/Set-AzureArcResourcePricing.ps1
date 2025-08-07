function Set-AzureArcResourcePricing {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
<#
.SYNOPSIS
    Configure Azure Defender for Cloud pricing at resource level for Virtual Machines, Virtual Machine Scale Sets, and ARC machines.

.DESCRIPTION
    This function allows you to configure Azure Defender for Cloud pricing settings at the resource level for:
    - Virtual Machines
    - Virtual Machine Scale Sets
    - Azure Arc-enabled machines

    You can target resources either by Resource Group or by Tag, and perform the following actions:
    - READ: View current pricing configuration
    - FREE: Remove Defender protection (set to Free tier)
    - STANDARD: Enable Defender for Cloud Plan 1 (P1)
    - DELETE: Remove resource-level configuration (inherit from parent)

    This function is designed to be used as a post-deployment script after Azure Arc onboarding
    to ensure proper Defender for Servers pricing configuration.

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
    Set-AzureArcResourcePricing
    Runs the function in interactive mode with prompts for all parameters.

.EXAMPLE
    Set-AzureArcResourcePricing -Mode "RG" -ResourceGroupName "myRG" -Action "read"
    Reads pricing configuration for all resources in the specified resource group.

.EXAMPLE
    Set-AzureArcResourcePricing -Mode "TAG" -TagName "Environment" -TagValue "Production" -Action "standard"
    Enables Defender for Cloud P1 for all resources with the specified tag.

.NOTES
    Author: Microsoft / Lessi Coulibaly
    Version: 2.0
    Last Updated: July 2025
    Module: ServerProtection

    Requirements:
    - Azure PowerShell module (Az)
    - Appropriate Azure permissions for the target subscription and resources
    - Azure Defender for Cloud permissions

.DISCLAIMER
    This function is provided "AS IS" without warranty of any kind. Use at your own risk.
    Always test in a non-production environment first. The authors are not responsible
    for any damage or data loss that may occur from using this function.

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

# MANDATORY: Initialize standardized environment at the very beginning
# This ensures the folder selection menu is ALWAYS shown and AzureArc folder is configured
$environment = Initialize-StandardizedEnvironment -ScriptName "Set-AzureArcResourcePricing" -RequiredFileTypes @("DeviceLog")

# Check if user chose to quit (return to main menu)
if ($environment.UserQuit) {
    Write-Host "Returning to main menu..." -ForegroundColor Yellow
    return
}

# Check if initialization failed
if (-not $environment.Success) {
    Write-Host "Failed to initialize environment. Exiting..." -ForegroundColor Red
    return
}

# Set up paths from standardized environment
$workingFolder = $environment.FolderPath
$logFile = $environment.FilePaths["DeviceLog"]

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
Write-Host "`[*`] Azure Authentication `& Setup" -ForegroundColor Cyan

Clear-Host

# Use standardized authentication and subscription selection
$authResult = Initialize-AzureAuthenticationAndSubscription -SubscriptionId $SubscriptionId
if (-not $authResult.Success) {
    Write-Host "`[-`] Azure authentication or subscription selection failed: $($authResult.Message)" -ForegroundColor Red
    Write-Host "Script execution aborted.`n" -ForegroundColor Gray
    return
}

# Use the authenticated context and subscription details
$subName = $authResult.SubscriptionName
$subId = $authResult.SubscriptionId

#endregion

#region Operation Mode Selection
Write-Host "`[*`] Operation Mode Selection" -ForegroundColor Cyan

# Use provided mode or prompt user
if ($Mode) {
    Write-Host "`[+`] Using provided mode: $Mode" -ForegroundColor Green
    $mode = $Mode
} else {
    $choices = @("RG", "TAG")
    Write-Host ""
    Write-Host "`[*`] Operation Mode:" -ForegroundColor Green
    Write-Host "1. RG: `t`tSet pricing for all resources under a Resource Group"
    Write-Host "2. TAG: `tSet pricing for all resources with a specific tag"
    $defaultChoice = 1
    $choice = Read-Host "`nEnter your choice (1 or 2, default: $defaultChoice)"
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = $defaultChoice }
    while ($choice -notin 1..2) {
        Write-Host -ForegroundColor Yellow "[-] Invalid choice. Please enter a number between 1 and 2"
        $choice = Read-Host "`nEnter your choice (1 or 2, default: $defaultChoice)"
        if ([string]::IsNullOrWhiteSpace($choice)) { $choice = $defaultChoice }
    }
    $mode = $choices[$choice - 1]
}

#endregion

#region Resource Group/Tag Configuration
Write-Host "`[*`] Resource Configuration" -ForegroundColor Cyan

# Only show resource groups if RG mode is selected
if ($mode.ToLower() -eq "rg") {
    $azRGs = @()
    $azRGs += (Get-AzResourceGroup).ResourceGroupName

    if (-not $ResourceGroupName) {
        Write-Host ""
        Write-Host "`[*`] Resource groups in '$subName' subscription:" -ForegroundColor Green
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
                Write-Host "`[*`] Exiting script as requested." -ForegroundColor Yellow
                exit 0
            }

            if ([string]::IsNullOrWhiteSpace($resourceGroupName)) {
                Write-Host "`[-`] Resource group name cannot be empty. Please enter a valid name or 'exit' to quit." -ForegroundColor Red
                continue
            }

            # Verify the resource group exists
            try {
                $rg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction Stop
                Write-Host "`[+`] Found resource group: $($rg.ResourceGroupName) in location: $($rg.Location)" -ForegroundColor Green
                break
            }
            catch {
                Write-Host "`[-`] Resource group '$resourceGroupName' not found in subscription '$subName'." -ForegroundColor Red
                Write-Host "Please verify the resource group name, enter a valid name, or type 'exit' to quit." -ForegroundColor Yellow
            }
        } while ($true)
    } else {
        # Verify provided resource group exists
        try {
            $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
            Write-Host "`[+`] Using provided resource group: $($rg.ResourceGroupName) in location: $($rg.Location)" -ForegroundColor Green
            $resourceGroupName = $ResourceGroupName
        }
        catch {
            Write-Host "`[-`] Resource group '$ResourceGroupName' not found in subscription '$subName'." -ForegroundColor Red
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
        Write-Host "`[*`] Getting token for tenant: $tenantName" -ForegroundColor Cyan

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

        Write-Host "`[+`] Token obtained successfully" -ForegroundColor Green

        return @{
            Token = $tokenValue
            ExpiresOn = $tokenInfo.ExpiresOn.LocalDateTime
        }
    }
    catch {
        Write-Host "`[-`] Failed to get access token: $($_.Exception.Message)" -ForegroundColor Red
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
        Write-Host "`[*`] Token is about to expire, refreshing..." -ForegroundColor Yellow
        try {
            $tokenInfo = Get-FreshAccessToken
            $AccessToken.Value = $tokenInfo.Token
            $ExpiresOn.Value = $tokenInfo.ExpiresOn
            Write-Host "`[+`] Token refreshed successfully. New expiry: $($ExpiresOn.Value)" -ForegroundColor Green
        }
        catch {
            Write-Host "`[-`] Failed to refresh token: $($_.Exception.Message)" -ForegroundColor Red
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
        [string]$ResourceName,
        [Parameter(Mandatory=$false)]
        $ResourceDetails
    )

    Write-Host ""
    Write-Host "---------------------------------------------------------------------------------------------------"
    Write-Host "DEFENDER FOR SERVERS CONFIGURATION REPORT - Resource: $ResourceName"
    Write-Host "---------------------------------------------------------------------------------------------------"
    Write-Host ""

    # Resource Information Section
    if ($ResourceDetails) {
        Write-Host "RESOURCE INFORMATION"
        Write-Host ""
        if ($ResourceDetails.location) {
            Write-Host "  Location              : $($ResourceDetails.location)"
        }
        if ($ResourceDetails.type) {
            Write-Host "  Resource Type         : $($ResourceDetails.type)"
        }
        if ($ResourceDetails.id) {
            Write-Host "  Resource ID           : $($ResourceDetails.id)"
        }
        if ($ResourceDetails.tags -and $ResourceDetails.tags.PSObject.Properties.Count -gt 0) {
            Write-Host "  Tags                  :"
            $ResourceDetails.tags.PSObject.Properties | ForEach-Object {
                Write-Host "    $($_.Name) = $($_.Value)"
            }
        }
        Write-Host ""
    }

    # Pricing Configuration Section
    Write-Host "DEFENDER FOR SERVERS PRICING CONFIGURATION"
    Write-Host ""

    if ($PricingResponse -and $PricingResponse.properties) {
        $props = $PricingResponse.properties

        # Pricing Tier
        if ($props.pricingTier) {
            $tier = $props.pricingTier.ToUpper()
            Write-Host "  Pricing Tier          : $tier"

            if ($tier -eq "STANDARD") {
                Write-Host "  Status                : Defender for Servers ENABLED"
            } else {
                Write-Host "  Status                : Defender for Servers DISABLED"
            }
        }

        # Sub Plan
        if ($props.subPlan) {
            Write-Host "  Sub Plan              : $($props.subPlan)"
        }

        # Enablement Time
        if ($props.enablementTime) {
            $enablementDate = try { [DateTime]::Parse($props.enablementTime).ToString("yyyy-MM-dd HH:mm:ss UTC") } catch { $props.enablementTime }
            Write-Host "  Enabled On            : $enablementDate"
        }

        # Free Trial Information
        if ($props.freeTrialRemainingTime) {
            Write-Host "  Free Trial Remaining  : $($props.freeTrialRemainingTime)"
        }

        # Deprecated Status
        if ($props.deprecated -eq $true) {
            Write-Host "  Deprecated            : YES"
        }

    } else {
        Write-Host "  Status                : NO PRICING CONFIGURATION FOUND"
        Write-Host "  Note                  : Resource inherits parent configuration"
    }

    Write-Host ""

    # Security Extensions Section
    if ($PricingResponse -and $PricingResponse.properties -and $PricingResponse.properties.extensions -and $PricingResponse.properties.extensions.Count -gt 0) {
        Write-Host "SECURITY EXTENSIONS & FEATURES"
        Write-Host ""

        foreach ($extension in $PricingResponse.properties.extensions) {
            $extensionName = $extension.name
            $isEnabled = $extension.isEnabled
            $statusText = if ($isEnabled -eq $true) { "ENABLED" } else { "DISABLED" }

            Write-Host "  Extension: $extensionName"
            Write-Host "    Status              : $statusText"
            Write-Host ""
        }
    }

    # Check for Microsoft Defender for Endpoint (MDE) on Azure Arc machines
    if ($ResourceDetails -and $ResourceDetails.type -eq "Microsoft.HybridCompute/machines") {
        Write-Host "MICROSOFT DEFENDER FOR ENDPOINT (MDE) STATUS"
        Write-Host ""

        try {
            # Get fresh access token for the extension query
            Update-TokenIfNeeded -AccessToken ([ref]$script:accessToken) -ExpiresOn ([ref]$script:expireson)

            # Query for MDE extension
            $extensionsUrl = "https://management.azure.com$($ResourceDetails.id)/extensions?api-version=2022-12-27"
            $extensionsResponse = Invoke-RestMethod -Method Get -Uri $extensionsUrl -Headers @{Authorization = "Bearer $script:accessToken"} -TimeoutSec 120

            # Look for MDE.Windows extension
            $mdeExtension = $extensionsResponse.value | Where-Object { $_.properties.type -eq "MDE.Windows" }

            if ($mdeExtension) {
                $provisioningState = $mdeExtension.properties.provisioningState
                $typeHandlerVersion = $mdeExtension.properties.typeHandlerVersion

                Write-Host "  MDE Extension         : $provisioningState"
                Write-Host "  Extension Name        : $($mdeExtension.name)"
                Write-Host "  Type Handler Version  : $typeHandlerVersion"

                # Additional MDE extension properties
                if ($mdeExtension.properties.publisher) {
                    Write-Host "  Publisher             : $($mdeExtension.properties.publisher)"
                }

                if ($mdeExtension.properties.enableAutomaticUpgrade) {
                    Write-Host "  Auto Upgrade          : $($mdeExtension.properties.enableAutomaticUpgrade)"
                }

            } else {
                Write-Host "  MDE Extension         : NOT INSTALLED"
                Write-Host "  Note                  : Microsoft Defender for Endpoint extension not found"
            }

        } catch {
            Write-Host "  MDE Extension         : UNABLE TO QUERY"
            Write-Host "  Error                 : $($_.Exception.Message)"
        }

        Write-Host ""
    }

    # Azure Arc Agent Status (for Arc machines only)
    if ($ResourceDetails -and $ResourceDetails.type -eq "Microsoft.HybridCompute/machines" -and $ResourceDetails.properties) {
        Write-Host "AZURE ARC AGENT STATUS"
        Write-Host ""

        $props = $ResourceDetails.properties

        if ($props.status) {
            Write-Host "  Connection Status     : $($props.status)"
        }

        if ($props.agentVersion) {
            Write-Host "  Agent Version         : $($props.agentVersion)"
        }

        if ($props.lastStatusChange) {
            $lastChange = try { [DateTime]::Parse($props.lastStatusChange).ToString("yyyy-MM-dd HH:mm:ss UTC") } catch { $props.lastStatusChange }
            Write-Host "  Last Status Change    : $lastChange"
        }

        if ($props.osName) {
            Write-Host "  Operating System      : $($props.osName)"
        }

        if ($props.osVersion) {
            Write-Host "  OS Version            : $($props.osVersion)"
        }

        if ($props.vmId) {
            Write-Host "  VM ID                 : $($props.vmId)"
        }

        Write-Host ""
    }

    # Resource Configuration Summary
    Write-Host "CONFIGURATION SUMMARY"
    Write-Host ""
    if ($PricingResponse.name) {
        Write-Host "  Configuration Name    : $($PricingResponse.name)"
    }
    if ($PricingResponse.type) {
        Write-Host "  Configuration Type    : $($PricingResponse.type)"
    }
    Write-Host "  Report Generated      : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"
    Write-Host ""
    Write-Host "---------------------------------------------------------------------------------------------------"
    Write-Host ""
}

#region Token Acquisition
Write-Host "`[*`] Token Acquisition" -ForegroundColor Cyan

# Get initial token
try {
    Write-Host "`[*`] Obtaining access token..." -ForegroundColor Yellow
    $tokenInfo = Get-FreshAccessToken
    $script:accessToken = $tokenInfo.Token
    $script:expireson = $tokenInfo.ExpiresOn
    Write-Host "`[+`] Token obtained successfully. Expires: $script:expireson" -ForegroundColor Green
}
catch {
    Write-Host "`[-`] Failed to obtain access token: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please run 'Connect-AzAccount' and try again." -ForegroundColor Yellow
    exit 1
}

# Define variables for authentication and resource group
$SubscriptionId = $subId

#endregion

#region Resource Discovery
Write-Host "`[*`] Resource Discovery" -ForegroundColor Cyan

if ($mode.ToLower() -eq "rg") {
    # Fetch resources under a given Resource Group
    try {
        Write-Host "`[*`] Fetching resources from Resource Group '$resourceGroupName'..." -ForegroundColor Yellow

        # Check if token needs refresh before API calls
        Update-TokenIfNeeded -AccessToken ([ref]$script:accessToken) -ExpiresOn ([ref]$script:expireson)

        # Get all virtual machines, VMSSs, and ARC machines in the resource group
        $vmUrl = "https://management.azure.com/subscriptions/" + $SubscriptionId + "/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines?api-version=2021-04-01"

        do{
            $vmResponse = Invoke-RestMethod -Method Get -Uri $vmUrl -Headers @{Authorization = "Bearer $script:accessToken"} -TimeoutSec 120
            $vmResponseMachines += $vmResponse.value
            $vmUrl = $vmResponse.nextLink
        } while (![string]::IsNullOrEmpty($vmUrl))
        Write-Host "`[+`] Found $($vmResponseMachines.Count) VMs" -ForegroundColor Green

        $vmssUrl = "https://management.azure.com/subscriptions/" + $SubscriptionId + "/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachineScaleSets?api-version=2021-04-01"
        do{
            $vmssResponse = Invoke-RestMethod -Method Get -Uri $vmssUrl -Headers @{Authorization = "Bearer $script:accessToken"} -TimeoutSec 120
            $vmssResponseMachines += $vmssResponse.value
            $vmssUrl = $vmssResponse.nextLink
        } while (![string]::IsNullOrEmpty($vmssUrl))
        Write-Host "`[+`] Found $($vmssResponseMachines.Count) VMSSs" -ForegroundColor Green

        $arcUrl = "https://management.azure.com/subscriptions/" + $SubscriptionId + "/resourceGroups/$resourceGroupName/providers/Microsoft.HybridCompute/machines?api-version=2022-12-27"
        do{
            $arcResponse = Invoke-RestMethod -Method Get -Uri $arcUrl -Headers @{Authorization = "Bearer $script:accessToken"} -TimeoutSec 120
            # Get detailed information for each Arc machine
            foreach ($arcMachine in $arcResponse.value) {
                # Get full details for the Arc machine
                $detailUrl = "https://management.azure.com$($arcMachine.id)?api-version=2022-12-27"
                try {
                    $detailResponse = Invoke-RestMethod -Method Get -Uri $detailUrl -Headers @{Authorization = "Bearer $script:accessToken"} -TimeoutSec 120
                    $arcResponseMachines += $detailResponse
                } catch {
                    # If detailed call fails, use basic info
                    $arcResponseMachines += $arcMachine
                }
            }
            $arcUrl = $arcResponse.nextLink
        } while (![string]::IsNullOrEmpty($arcUrl))
        Write-Host "`[+`] Found $($arcResponseMachines.Count) ARC machines" -ForegroundColor Green
    }
    catch {
        Write-Host "`[-`] Failed to get resources!" -ForegroundColor Red
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
        Write-Host "`[+`] Using provided tag name: $tagName" -ForegroundColor Green
    }

    if (-not $TagValue) {
        $defaultTagValue = "Production"
        $tagValue = Read-Host "Enter the value of the tag (default: $defaultTagValue)"
        if ([string]::IsNullOrWhiteSpace($tagValue)) { $tagValue = $defaultTagValue }
    } else {
        $tagValue = $TagValue
        Write-Host "`[+`] Using provided tag value: $tagValue" -ForegroundColor Green
    }

    try {
        Write-Host "`[*`] Fetching resources by tag '$tagName=$tagValue'..." -ForegroundColor Yellow

        # Check if token needs refresh before API calls
        Update-TokenIfNeeded -AccessToken ([ref]$script:accessToken) -ExpiresOn ([ref]$script:expireson)

        # Get all virtual machines, VMSSs, and ARC machines based on the given tag
        $vmUrl = "https://management.azure.com/subscriptions/" + $SubscriptionId + "/resources?`$filter=resourceType eq 'Microsoft.Compute/virtualMachines'`&api-version=2021-04-01"
        do{
            $vmResponse = Invoke-RestMethod -Method Get -Uri $vmUrl -Headers @{Authorization = "Bearer $script:accessToken"} -TimeoutSec 120
            $vmResponseMachines += $vmResponse.value | Where-Object {$_.tags.$tagName -eq $tagValue}
            $vmUrl = $vmResponse.nextLink
        } while (![string]::IsNullOrEmpty($vmUrl))
        Write-Host "`[+`] Found $($vmResponseMachines.Count) VMs with tag '$tagName=$tagValue'" -ForegroundColor Green

        $vmssUrl = "https://management.azure.com/subscriptions/" + $SubscriptionId + "/resources?`$filter=resourceType eq 'Microsoft.Compute/virtualMachineScaleSets'`&api-version=2021-04-01"
        do{
            $vmssResponse = Invoke-RestMethod -Method Get -Uri $vmssUrl -Headers @{Authorization = "Bearer $script:accessToken"} -TimeoutSec 120
            $vmssResponseMachines += $vmssResponse.value | Where-Object {$_.tags.$tagName -eq $tagValue}
            $vmssUrl = $vmssResponse.nextLink
        } while (![string]::IsNullOrEmpty($vmssUrl))
        Write-Host "`[+`] Found $($vmssResponseMachines.Count) VMSSs with tag '$tagName=$tagValue'" -ForegroundColor Green

        $arcUrl = "https://management.azure.com/subscriptions/" + $SubscriptionId + "/resources?`$filter=resourceType eq 'Microsoft.HybridCompute/machines'`&api-version=2023-07-01"
        do{
            $arcResponse = Invoke-RestMethod -Method Get -Uri $arcUrl -Headers @{Authorization = "Bearer $script:accessToken"} -TimeoutSec 120
            $filteredArcMachines = $arcResponse.value | Where-Object {$_.tags.$tagName -eq $tagValue}
            # Get detailed information for each filtered Arc machine
            foreach ($arcMachine in $filteredArcMachines) {
                # Get full details for the Arc machine
                $detailUrl = "https://management.azure.com$($arcMachine.id)?api-version=2022-12-27"
                try {
                    $detailResponse = Invoke-RestMethod -Method Get -Uri $detailUrl -Headers @{Authorization = "Bearer $script:accessToken"} -TimeoutSec 120
                    $arcResponseMachines += $detailResponse
                } catch {
                    # If detailed call fails, use basic info
                    $arcResponseMachines += $arcMachine
                }
            }
            $arcUrl = $arcResponse.nextLink
        } while (![string]::IsNullOrEmpty($arcUrl))
        Write-Host "`[+`] Found $($arcResponseMachines.Count) ARC machines with tag '$tagName=$tagValue'" -ForegroundColor Green
    }
    catch {
        Write-Host "`[-`] Failed to get resources!" -ForegroundColor Red
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
    Write-Host "`[-`] Entered invalid mode. Exiting script." -ForegroundColor Red
    exit 1;
}

#endregion

#region Resource Summary
Write-Host "`[*`] Resource Summary" -ForegroundColor Cyan

# Display found resources
Write-Host "`[*`] Found the following resources:" -ForegroundColor Green

Write-Host "`n[*] Virtual Machines ($($vmResponseMachines.Count)):" -ForegroundColor Cyan
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

Write-Host "`n[*] Virtual Machine Scale Sets ($($vmssResponseMachines.Count)):" -ForegroundColor Cyan
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

Write-Host "`n[*] ARC Machines ($($arcResponseMachines.Count)):" -ForegroundColor Cyan
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
Write-Host "`[*`] Action Selection" -ForegroundColor Cyan

# Use provided action or prompt user
if ($Action) {
    Write-Host "`[+`] Using provided action: $($Action.ToUpper())" -ForegroundColor Green
    $PricingTier = $Action.ToLower()
} else {
    Write-Host ""
    Write-Host "`[*`] Choose your action:" -ForegroundColor Green
    Write-Host "1. READ: `tRead the current configuration"
    Write-Host "2. FREE: `tRemove the Defender protection"
    Write-Host "3. STANDARD: `tEnable 'P1'"
    Write-Host "4. DELETE: `tThe resource will inherit the parent's configuration"

    $choices = @("read", "free", "standard", "delete")
    Write-Host
    $defaultPricingChoice = 1
    $choice = Read-Host "Enter your choice (1-4, default: $defaultPricingChoice)"
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = $defaultPricingChoice }
    while ($choice -notin 1..4) {
        Write-Host -ForegroundColor Yellow "[-] Invalid choice. Please enter a number between 1 and 4"
        $choice = Read-Host "Enter the number corresponding to your choice (default: $defaultPricingChoice)"
        if ([string]::IsNullOrWhiteSpace($choice)) { $choice = $defaultPricingChoice }
    }
    $PricingTier = $choices[$choice - 1]
}

#endregion

#region Resource Processing
Write-Host "`[*`] Resource Processing" -ForegroundColor Cyan

# Process Virtual Machines
if ($vmResponseMachines.Count -gt 0) {
    Write-Host "`[*`] Processing Virtual Machines:" -ForegroundColor Cyan
    Write-Host ""
    foreach ($machine in $vmResponseMachines) {
        # Check if token needs refresh, refresh only if needed
        Update-TokenIfNeeded -AccessToken ([ref]$script:accessToken) -ExpiresOn ([ref]$script:expireson)

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
        Write-Host "`[*`] Processing pricing configuration for '$($machine.name)':"
        try {
            if($PricingTier.ToLower() -eq "delete") {
                $pricingResponse = Invoke-RestMethod -Method Delete -Uri $pricingUrl -Headers @{Authorization = "Bearer $script:accessToken"} -ContentType "application/json" -TimeoutSec 120
                Write-Host "`[+`] Successfully deleted pricing configuration for $($machine.name)" -ForegroundColor Green
                $successCount++
                $vmSuccessCount++
            } elseif ($PricingTier.ToLower() -eq "read") {
                $pricingResponse = Invoke-RestMethod -Method Get -Uri $pricingUrl -Headers @{Authorization = "Bearer $script:accessToken"} -ContentType "application/json" -TimeoutSec 120
                Write-Host "`[+`] Successfully read pricing configuration for $($machine.name)" -ForegroundColor Green
                Format-PricingConfiguration -PricingResponse $pricingResponse -ResourceName $machine.name -ResourceDetails $machine
                $successCount++
                $vmSuccessCount++
            } else {
                $pricingResponse = Invoke-RestMethod -Method Put -Uri $pricingUrl -Headers @{Authorization = "Bearer $script:accessToken"} -Body ($pricingBody | ConvertTo-Json) -ContentType "application/json" -TimeoutSec 120
                Write-Host "`[+`] Successfully updated pricing configuration for $($machine.name)" -ForegroundColor Green
                $successCount++
                $vmSuccessCount++
            }
        }
        catch {
            $failureCount++
            Write-Host "`[-`] Failed to update pricing configuration for $($machine.name)" -ForegroundColor Red
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
    Write-Host "`[*`] Processing Virtual Machine Scale Sets:" -ForegroundColor Cyan
    Write-Host ""
    foreach ($machine in $vmssResponseMachines) {
        # Check if token needs refresh, refresh only if needed
        Update-TokenIfNeeded -AccessToken ([ref]$script:accessToken) -ExpiresOn ([ref]$script:expireson)

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
        Write-Host "`[*`] Processing pricing configuration for '$($machine.name)':"
        try {
            if($PricingTier.ToLower() -eq "delete") {
                $pricingResponse = Invoke-RestMethod -Method Delete -Uri $pricingUrl -Headers @{Authorization = "Bearer $script:accessToken"} -ContentType "application/json" -TimeoutSec 120
                Write-Host "`[+`] Successfully deleted pricing configuration for $($machine.name)" -ForegroundColor Green
                $successCount++
                $vmssSuccessCount++
            } elseif ($PricingTier.ToLower() -eq "read") {
                $pricingResponse = Invoke-RestMethod -Method Get -Uri $pricingUrl -Headers @{Authorization = "Bearer $script:accessToken"} -ContentType "application/json" -TimeoutSec 120
                Write-Host "`[+`] Successfully read pricing configuration for $($machine.name)" -ForegroundColor Green
                Format-PricingConfiguration -PricingResponse $pricingResponse -ResourceName $machine.name -ResourceDetails $machine
                $successCount++
                $vmssSuccessCount++
            } else {
                $pricingResponse = Invoke-RestMethod -Method Put -Uri $pricingUrl -Headers @{Authorization = "Bearer $script:accessToken"} -Body ($pricingBody | ConvertTo-Json) -ContentType "application/json" -TimeoutSec 120
                Write-Host "`[+`] Successfully updated pricing configuration for $($machine.name)" -ForegroundColor Green
                $successCount++
                $vmssSuccessCount++
            }
        }
        catch {
            $failureCount++
            Write-Host "`[-`] Failed to update pricing configuration for $($machine.name)" -ForegroundColor Red
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
    Write-Host "`[*`] Processing ARC Machines:" -ForegroundColor Cyan
    Write-Host ""
    foreach ($machine in $arcResponseMachines) {
        # Check if token needs refresh, refresh only if needed
        Update-TokenIfNeeded -AccessToken ([ref]$script:accessToken) -ExpiresOn ([ref]$script:expireson)

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
        Write-Host "`[*`] Processing pricing configuration for '$($machine.name)':" -ForegroundColor Cyan
        try {
            if($PricingTier.ToLower() -eq "delete") {
                $pricingResponse = Invoke-RestMethod -Method Delete -Uri $pricingUrl -Headers @{Authorization = "Bearer $script:accessToken"} -ContentType "application/json" -TimeoutSec 120
                Write-Host "`[+`] Successfully deleted pricing configuration for $($machine.name)" -ForegroundColor Green
                $successCount++
                $arcSuccessCount++
            } elseif ($PricingTier.ToLower() -eq "read") {
                $pricingResponse = Invoke-RestMethod -Method Get -Uri $pricingUrl -Headers @{Authorization = "Bearer $script:accessToken"} -ContentType "application/json" -TimeoutSec 120
                Write-Host "`[+`] Successfully read pricing configuration for $($machine.name)" -ForegroundColor Green
                Format-PricingConfiguration -PricingResponse $pricingResponse -ResourceName $machine.name -ResourceDetails $machine
                $successCount++
                $arcSuccessCount++
            } else {
                $pricingResponse = Invoke-RestMethod -Method Put -Uri $pricingUrl -Headers @{Authorization = "Bearer $script:accessToken"} -Body ($pricingBody | ConvertTo-Json) -ContentType "application/json" -TimeoutSec 120
                Write-Host "`[+`] Successfully updated pricing configuration for $($machine.name)" -ForegroundColor Green
                $successCount++
                $arcSuccessCount++
            }
        }
        catch {
            $failureCount++
            Write-Host "`[-`] Failed to update pricing configuration for $($machine.name)" -ForegroundColor Red
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
Write-Host "`[*`] Final Summary" -ForegroundColor Cyan

Write-Host "`[*`] Summary of Pricing API Results:" -ForegroundColor Green

Write-Host ""
Write-Host "`[*`] Virtual Machines:" -ForegroundColor Cyan
Write-Host "   Found: $vmCount" -ForegroundColor White
Write-Host "   [+] Successful: $vmSuccessCount" -ForegroundColor Green
Write-Host "   [-] Failed: $($vmCount - $vmSuccessCount)" -ForegroundColor $(if ($($vmCount - $vmSuccessCount) -gt 0) {'Red'} else {'Green'})

Write-Host ""
Write-Host "`[*`] Virtual Machine Scale Sets:" -ForegroundColor Cyan
Write-Host "   Found: $vmssCount" -ForegroundColor White
Write-Host "   [+] Successful: $vmssSuccessCount" -ForegroundColor Green
Write-Host "   [-] Failed: $($vmssCount - $vmssSuccessCount)" -ForegroundColor $(if ($($vmssCount - $vmssSuccessCount) -gt 0) {'Red'} else {'Green'})

Write-Host ""
Write-Host "`[*`] ARC Machines:" -ForegroundColor Cyan
Write-Host "   Found: $arcCount" -ForegroundColor White
Write-Host "   [+] Successful: $arcSuccessCount" -ForegroundColor Green
Write-Host "   [-] Failed: $($arcCount - $arcSuccessCount)" -ForegroundColor $(if ($($arcCount - $arcSuccessCount) -gt 0) {'Red'} else {'Green'})

Write-Host ""
Write-Host "`[*`] Overall Results:" -ForegroundColor Magenta
Write-Host "   [+] Total Successful: $successCount" -ForegroundColor Green
Write-Host "   [-] Total Failures: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) {'Red'} else {'Green'})

Write-Host ""
Write-Host "Function execution completed!`n" -ForegroundColor Green
#endregion

}



