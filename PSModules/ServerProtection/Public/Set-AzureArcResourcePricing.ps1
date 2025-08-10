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
    Write-Host "Returning to main menu..."
    return
}

# Check if initialization failed
if (-not $environment.Success) {
    Write-Host "Failed to initialize environment. Exiting..."
    return
}

# Set up paths from standardized environment
$workingFolder = $environment.FolderPath
$logFile = $environment.FilePaths["DeviceLog"]
$startTime = Get-Date

# Initialize log file
try {
    ("=" * 120) | Out-File -FilePath $logFile
    "AZURE ARC RESOURCE PRICING CONFIGURATION SESSION - COMPREHENSIVE REPORT" | Out-File -FilePath $logFile -Append
    ("=" * 120) | Out-File -FilePath $logFile -Append
    "Session Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')" | Out-File -FilePath $logFile -Append
    "Working Folder: $workingFolder" | Out-File -FilePath $logFile -Append
    "PowerShell Version: $($PSVersionTable.PSVersion)" | Out-File -FilePath $logFile -Append
    "User: $($env:USERNAME)" | Out-File -FilePath $logFile -Append
    "Computer: $($env:COMPUTERNAME)" | Out-File -FilePath $logFile -Append
    "Script Version: 2.0" | Out-File -FilePath $logFile -Append
    "" | Out-File -FilePath $logFile -Append
    Write-Host "`[+`] Comprehensive log file initialized: $logFile" -ForegroundColor Green
} catch {
    Write-Host "`[-`] Warning: Failed to initialize log file: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "    Continuing without logging..."
    $logFile = $null
}

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

# Helper function to safely write to log file
function Write-SafeLog {
    param([string]$Message)
    if ($logFile) {
        try {
            $Message | Out-File -FilePath $logFile -Append
        } catch {
            # Silently continue if logging fails
        }
    }
}

# Helper function to log detailed resource information
function Write-ResourceDetailsToLog {
    param(
        [Parameter(Mandatory=$true)]
        $Resource,
        [Parameter(Mandatory=$true)]
        [string]$ResourceType,
        [Parameter(Mandatory=$true)]
        [string]$Action,
        [Parameter(Mandatory=$false)]
        [string]$Result = "",
        [Parameter(Mandatory=$false)]
        [string]$ErrorDetails = "",
        [Parameter(Mandatory=$false)]
        $PricingResponse = $null
    )
    
    if (-not $logFile) { return }
    
    try {
        Write-SafeLog ""
        Write-SafeLog ("-" * 80)
        Write-SafeLog "RESOURCE PROCESSING DETAILS"
        Write-SafeLog ("-" * 80)
        Write-SafeLog "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"
        Write-SafeLog "Resource Type: $ResourceType"
        Write-SafeLog "Resource Name: $($Resource.name)"
        Write-SafeLog "Resource ID: $($Resource.id)"
        Write-SafeLog "Location: $($Resource.location)"
        Write-SafeLog "Action Performed: $($Action.ToUpper())"
        Write-SafeLog "Result: $Result"
        
        # Log resource tags if available
        if ($Resource.tags -and $Resource.tags.PSObject.Properties.Count -gt 0) {
            Write-SafeLog "Resource Tags:"
            $Resource.tags.PSObject.Properties | ForEach-Object {
                Write-SafeLog "  - $($_.Name): $($_.Value)"
            }
        } else {
            Write-SafeLog "Resource Tags: None"
        }
        
        # Log pricing response details if available
        if ($PricingResponse -and $PricingResponse.properties) {
            Write-SafeLog "Pricing Configuration Details:"
            Write-SafeLog "  - Pricing Tier: $($PricingResponse.properties.pricingTier)"
            if ($PricingResponse.properties.subPlan) {
                Write-SafeLog "  - Sub Plan: $($PricingResponse.properties.subPlan)"
            }
            if ($PricingResponse.properties.enablementTime) {
                Write-SafeLog "  - Enabled On: $($PricingResponse.properties.enablementTime)"
            }
            if ($PricingResponse.properties.freeTrialRemainingTime) {
                Write-SafeLog "  - Free Trial Remaining: $($PricingResponse.properties.freeTrialRemainingTime)"
            }
            if ($PricingResponse.properties.deprecated) {
                Write-SafeLog "  - Deprecated: $($PricingResponse.properties.deprecated)"
            }
            
            # Log extensions if available
            if ($PricingResponse.properties.extensions -and $PricingResponse.properties.extensions.Count -gt 0) {
                Write-SafeLog "  - Security Extensions:"
                foreach ($extension in $PricingResponse.properties.extensions) {
                    Write-SafeLog "    * $($extension.name): $(if ($extension.isEnabled) { 'ENABLED' } else { 'DISABLED' })"
                }
            }
        }
        
        # Log additional details for Arc machines
        if ($ResourceType -eq "ARC" -and $Resource.properties) {
            Write-SafeLog "Azure Arc Agent Details:"
            Write-SafeLog "  - Connection Status: $($Resource.properties.status)"
            Write-SafeLog "  - Agent Version: $($Resource.properties.agentVersion)"
            Write-SafeLog "  - OS Name: $($Resource.properties.osName)"
            Write-SafeLog "  - OS Version: $($Resource.properties.osVersion)"
            if ($Resource.properties.lastStatusChange) {
                Write-SafeLog "  - Last Status Change: $($Resource.properties.lastStatusChange)"
            }
            if ($Resource.properties.vmId) {
                Write-SafeLog "  - VM ID: $($Resource.properties.vmId)"
            }
        }
        
        # Log error details if provided
        if (-not [string]::IsNullOrEmpty($ErrorDetails)) {
            Write-SafeLog "Error Details:"
            Write-SafeLog "  $ErrorDetails"
        }
        
        Write-SafeLog ("-" * 80)
    } catch {
        # Silently continue if detailed logging fails
    }
}

#region Authentication and Setup
Write-Host "`[*`] Azure Authentication `& Setup"

Clear-Host

# Use standardized authentication and subscription selection
$authResult = Initialize-AzureAuthenticationAndSubscription -SubscriptionId $SubscriptionId
if (-not $authResult.Success) {
    $errorMsg = "`[-`] Azure authentication or subscription selection failed: $($authResult.Message)"
    Write-Host $errorMsg
    Write-SafeLog $errorMsg
    Write-Host "Script execution aborted.`n"
    Write-SafeLog "Script execution aborted."
    return
}

# Use the authenticated context and subscription details
$subName = $authResult.SubscriptionName
$subId = $authResult.SubscriptionId

# Log successful authentication
Write-SafeLog ""
Write-SafeLog "AUTHENTICATION & SUBSCRIPTION DETAILS"
Write-SafeLog ("=" * 50)
Write-SafeLog "Authentication Status: SUCCESS"
Write-SafeLog "Subscription Name: $subName"
Write-SafeLog "Subscription ID: $subId"
Write-SafeLog "Azure Context Account: $((Get-AzContext).Account.Id)"
Write-SafeLog "Azure Context Tenant: $((Get-AzContext).Tenant.Id)"
Write-SafeLog "Authentication Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"
Write-SafeLog ""

#endregion

#region Operation Mode Selection
Write-Host "`[*`] Operation Mode Selection"

# Use provided mode or prompt user
if ($Mode) {
    Write-Host "`[+`] Using provided mode: $Mode"
    $mode = $Mode
    Write-SafeLog "OPERATION CONFIGURATION"
    Write-SafeLog ("=" * 50)
    Write-SafeLog "Operation Mode: $Mode (provided as parameter)"
} else {
    $choices = @("RG", "TAG")
    Write-Host ""
    Write-Host "`[*`] Operation Mode:"
    Write-Host "1. RG: `t`tSet pricing for all resources under a Resource Group"
    Write-Host "2. TAG: `tSet pricing for all resources with a specific tag"
    $defaultChoice = 1
    $choice = Read-Host "`nEnter your choice (1 or 2, default: $defaultChoice)"
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = $defaultChoice }
    while ($choice -notin 1..2) {
        Write-Host "[-] Invalid choice. Please enter a number between 1 and 2" -ForegroundColor Green
        $choice = Read-Host "`nEnter your choice (1 or 2, default: $defaultChoice)"
        if ([string]::IsNullOrWhiteSpace($choice)) { $choice = $defaultChoice }
    }
    $mode = $choices[$choice - 1]
    Write-SafeLog "OPERATION CONFIGURATION"
    Write-SafeLog ("=" * 50)
    Write-SafeLog "Operation Mode: $mode (selected interactively - choice $choice)"
}

#endregion

#region Resource Group/Tag Configuration
Write-Host "`[*`] Resource Configuration"

# Only show resource groups if RG mode is selected
if ($mode.ToLower() -eq "rg") {
    $azRGs = @()
    $azRGs += (Get-AzResourceGroup).ResourceGroupName

    if (-not $ResourceGroupName) {
        Write-Host ""
        Write-Host "`[*`] Resource groups in '$subName' subscription:"
        $rgNumbers = @()
        for ($i = 0; $i -lt $azRGs.Count; $i++) {
            "$($i+1). $($azRGs[$i])"
            $rgNumbers += $i + 1
        }
        Write-Host ""
        Write-Host "Note: Enter a valid resource group name or type 'exit' to quit the script."

        do {
            $resourceGroupName = Read-Host "Enter the name of the resource group"

            if ($resourceGroupName.ToLower() -eq 'exit') {
                Write-Host "`[*`] Exiting script as requested."
                exit 0
            }

            if ([string]::IsNullOrWhiteSpace($resourceGroupName)) {
                Write-Host "`[-`] Resource group name cannot be empty. Please enter a valid name or 'exit' to quit."
                continue
            }

            # Verify the resource group exists
            try {
                $rg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction Stop
                Write-Host "`[+`] Found resource group: $($rg.ResourceGroupName) in location: $($rg.Location)"
                Write-SafeLog "Resource Group Selection: $($rg.ResourceGroupName)"
                Write-SafeLog "Resource Group Location: $($rg.Location)"
                Write-SafeLog "Resource Group ID: $($rg.ResourceId)"
                Write-SafeLog "Selection Method: Interactive user input"
                break
            }
            catch {
                Write-Host "`[-`] Resource group '$resourceGroupName' not found in subscription '$subName'."
                Write-Host "Please verify the resource group name, enter a valid name, or type 'exit' to quit."
            }
        } while ($true)
    } else {
        # Verify provided resource group exists
        try {
            $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
            Write-Host "`[+`] Using provided resource group: $($rg.ResourceGroupName) in location: $($rg.Location)"
            Write-SafeLog "Resource Group Selection: $($rg.ResourceGroupName)"
            Write-SafeLog "Resource Group Location: $($rg.Location)"
            Write-SafeLog "Resource Group ID: $($rg.ResourceId)"
            Write-SafeLog "Selection Method: Provided as parameter"
            $resourceGroupName = $ResourceGroupName
        }
        catch {
            Write-Host "`[-`] Resource group '$ResourceGroupName' not found in subscription '$subName'."
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
        Write-Host "`[*`] Getting token for tenant: $tenantName"

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

        Write-Host "`[+`] Token obtained successfully"

        return @{
            Token = $tokenValue
            ExpiresOn = $tokenInfo.ExpiresOn.LocalDateTime
        }
    }
    catch {
        Write-Host "`[-`] Failed to get access token: $($_.Exception.Message)"
        Write-Host "Please ensure you are logged in to Azure with 'Connect-AzAccount'"
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
        Write-Host "`[*`] Token is about to expire, refreshing..."
        try {
            $tokenInfo = Get-FreshAccessToken
            $AccessToken.Value = $tokenInfo.Token
            $ExpiresOn.Value = $tokenInfo.ExpiresOn
            Write-Host "`[+`] Token refreshed successfully. New expiry: $($ExpiresOn.Value)"
        }
        catch {
            Write-Host "`[-`] Failed to refresh token: $($_.Exception.Message)"
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
            Write-Host "  Tags                  :" -ForegroundColor Yellow
            $ResourceDetails.tags.PSObject.Properties | ForEach-Object {
                Write-Host "    $($_.Name) = $($_.Value)"
            }
        }
        Write-Host ""
    }

    # Pricing Configuration Section
    Write-Host "DEFENDER FOR SERVERS PRICING CONFIGURATION" -ForegroundColor Yellow
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
        Write-Host "SECURITY EXTENSIONS & FEATURES" -ForegroundColor Yellow
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

            # Look for various MDE extension types (Windows and Linux)
            $mdeExtensions = $extensionsResponse.value | Where-Object { 
                $_.properties.type -eq "MDE.Windows" -or 
                $_.properties.type -eq "MDE.Linux" -or 
                $_.name -like "*MDE*" -or 
                $_.properties.publisher -eq "Microsoft.Azure.AzureDefenderForServers"
            }

            if ($mdeExtensions -and $mdeExtensions.Count -gt 0) {
                foreach ($mdeExtension in $mdeExtensions) {
                    $provisioningState = $mdeExtension.properties.provisioningState
                    $typeHandlerVersion = $mdeExtension.properties.typeHandlerVersion
                    $extensionType = $mdeExtension.properties.type

                    Write-Host "  MDE Extension         : $provisioningState"
                    Write-Host "  Extension Name        : $($mdeExtension.name)"
                    Write-Host "  Extension Type        : $extensionType"
                    Write-Host "  Type Handler Version  : $typeHandlerVersion"

                    # Additional MDE extension properties
                    if ($mdeExtension.properties.publisher) {
                        Write-Host "  Publisher             : $($mdeExtension.properties.publisher)"
                    }

                    if ($mdeExtension.properties.enableAutomaticUpgrade) {
                        Write-Host "  Auto Upgrade          : $($mdeExtension.properties.enableAutomaticUpgrade)"
                    }

                    # Show settings if available
                    if ($mdeExtension.properties.settings) {
                        Write-Host "  Configuration         : Available"
                    }

                    Write-Host ""
                }
            } else {
                Write-Host "  MDE Extension         : NOT INSTALLED"
                Write-Host "  Note                  : Microsoft Defender for Endpoint extension not found"
                Write-Host "  Available Extensions  :"
                
                # List all extensions for debugging
                if ($extensionsResponse.value -and $extensionsResponse.value.Count -gt 0) {
                    foreach ($ext in $extensionsResponse.value) {
                        Write-Host "    - $($ext.name) ($($ext.properties.type))"
                    }
                } else {
                    Write-Host "    - No extensions found on this machine"
                }
            }

        } catch {
            Write-Host "  MDE Extension         : UNABLE TO QUERY"
            Write-Host "  Error                 : $($_.Exception.Message)"
            Write-SafeLog "ERROR: Failed to query MDE extension for $($ResourceDetails.name): $($_.Exception.Message)"
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
Write-Host "`[*`] Token Acquisition"

# Get initial token
try {
    Write-Host "`[*`] Obtaining access token..."
    $tokenInfo = Get-FreshAccessToken
    $script:accessToken = $tokenInfo.Token
    $script:expireson = $tokenInfo.ExpiresOn
    Write-Host "`[+`] Token obtained successfully. Expires: $script:expireson"
}
catch {
    Write-Host "`[-`] Failed to obtain access token: $($_.Exception.Message)"
    Write-Host "Please run 'Connect-AzAccount' and try again."
    exit 1
}

# Define variables for authentication and resource group
$SubscriptionId = $subId

#endregion

#region Resource Discovery
Write-Host "`[*`] Resource Discovery"

if ($mode.ToLower() -eq "rg") {
    # Fetch resources under a given Resource Group
    try {
        Write-Host "`[*`] Fetching resources from Resource Group '$resourceGroupName'..."

        # Check if token needs refresh before API calls
        Update-TokenIfNeeded -AccessToken ([ref]$script:accessToken) -ExpiresOn ([ref]$script:expireson)

        # Get all virtual machines, VMSSs, and ARC machines in the resource group
        $vmUrl = "https://management.azure.com/subscriptions/" + $SubscriptionId + "/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines?api-version=2021-04-01"

        do{
            $vmResponse = Invoke-RestMethod -Method Get -Uri $vmUrl -Headers @{Authorization = "Bearer $script:accessToken"} -TimeoutSec 120
            $vmResponseMachines += $vmResponse.value
            $vmUrl = $vmResponse.nextLink
        } while (![string]::IsNullOrEmpty($vmUrl))
        Write-Host "`[+`] Found $($vmResponseMachines.Count) VMs"
        Write-SafeLog ""
        Write-SafeLog "RESOURCE DISCOVERY SUMMARY"
        Write-SafeLog ("=" * 50)
        Write-SafeLog "Discovery Method: Resource Group"
        Write-SafeLog "Target Resource Group: $resourceGroupName"
        Write-SafeLog "Virtual Machines Found: $($vmResponseMachines.Count)"
        if ($vmResponseMachines.Count -gt 0) {
            Write-SafeLog "VM Details:"
            foreach ($vm in $vmResponseMachines) {
                Write-SafeLog "  - $($vm.name) (Location: $($vm.location), Type: $($vm.type))"
            }
        }

        $vmssUrl = "https://management.azure.com/subscriptions/" + $SubscriptionId + "/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachineScaleSets?api-version=2021-04-01"
        do{
            $vmssResponse = Invoke-RestMethod -Method Get -Uri $vmssUrl -Headers @{Authorization = "Bearer $script:accessToken"} -TimeoutSec 120
            $vmssResponseMachines += $vmssResponse.value
            $vmssUrl = $vmssResponse.nextLink
        } while (![string]::IsNullOrEmpty($vmssUrl))
        Write-Host "`[+`] Found $($vmssResponseMachines.Count) VMSSs"
        Write-SafeLog "Virtual Machine Scale Sets Found: $($vmssResponseMachines.Count)"
        if ($vmssResponseMachines.Count -gt 0) {
            Write-SafeLog "VMSS Details:"
            foreach ($vmss in $vmssResponseMachines) {
                Write-SafeLog "  - $($vmss.name) (Location: $($vmss.location), Type: $($vmss.type))"
            }
        }

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
        Write-Host "`[+`] Found $($arcResponseMachines.Count) ARC machines"
        Write-SafeLog "Azure Arc Machines Found: $($arcResponseMachines.Count)"
        if ($arcResponseMachines.Count -gt 0) {
            Write-SafeLog "Arc Machine Details:"
            foreach ($arc in $arcResponseMachines) {
                $osInfo = if ($arc.properties.osName) { " (OS: $($arc.properties.osName))" } else { "" }
                $statusInfo = if ($arc.properties.status) { " [Status: $($arc.properties.status)]" } else { "" }
                Write-SafeLog "  - $($arc.name) (Location: $($arc.location))$osInfo$statusInfo"
            }
        }
    }
    catch {
        Write-Host "`[-`] Failed to get resources!"
        if ($_.Exception.Response.StatusCode.value__ -eq 401) {
            Write-Host "Authentication failed. Token may be invalid or expired."
            Write-Host "Please try running 'Connect-AzAccount' and run the script again."
        }
        Write-Host "Response StatusCode:" -ForegroundColor Yellow
        Write-Host "Response StatusDescription:" -ForegroundColor Yellow
        Write-Host "Error from response:" -ForegroundColor Yellow
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
        Write-Host "`[+`] Using provided tag name: $tagName"
    }

    if (-not $TagValue) {
        $defaultTagValue = "Production"
        $tagValue = Read-Host "Enter the value of the tag (default: $defaultTagValue)"
        if ([string]::IsNullOrWhiteSpace($tagValue)) { $tagValue = $defaultTagValue }
    } else {
        $tagValue = $TagValue
        Write-Host "`[+`] Using provided tag value: $tagValue"
    }

    Write-SafeLog "Tag Name: $tagName"
    Write-SafeLog "Tag Value: $tagValue"
    Write-SafeLog "Selection Method: $(if ($TagName -and $TagValue) { 'Provided as parameters' } else { 'Interactive user input' })"

    try {
        Write-Host "`[*`] Fetching resources by tag '$tagName=$tagValue'..."

        # Check if token needs refresh before API calls
        Update-TokenIfNeeded -AccessToken ([ref]$script:accessToken) -ExpiresOn ([ref]$script:expireson)

        # Get all virtual machines, VMSSs, and ARC machines based on the given tag
        $vmUrl = "https://management.azure.com/subscriptions/" + $SubscriptionId + "/resources?`$filter=resourceType eq 'Microsoft.Compute/virtualMachines'`&api-version=2021-04-01"
        do{
            $vmResponse = Invoke-RestMethod -Method Get -Uri $vmUrl -Headers @{Authorization = "Bearer $script:accessToken"} -TimeoutSec 120
            $vmResponseMachines += $vmResponse.value | Where-Object {$_.tags.$tagName -eq $tagValue}
            $vmUrl = $vmResponse.nextLink
        } while (![string]::IsNullOrEmpty($vmUrl))
        Write-Host "`[+`] Found $($vmResponseMachines.Count) VMs with tag '$tagName=$tagValue'"

        $vmssUrl = "https://management.azure.com/subscriptions/" + $SubscriptionId + "/resources?`$filter=resourceType eq 'Microsoft.Compute/virtualMachineScaleSets'`&api-version=2021-04-01"
        do{
            $vmssResponse = Invoke-RestMethod -Method Get -Uri $vmssUrl -Headers @{Authorization = "Bearer $script:accessToken"} -TimeoutSec 120
            $vmssResponseMachines += $vmssResponse.value | Where-Object {$_.tags.$tagName -eq $tagValue}
            $vmssUrl = $vmssResponse.nextLink
        } while (![string]::IsNullOrEmpty($vmssUrl))
        Write-Host "`[+`] Found $($vmssResponseMachines.Count) VMSSs with tag '$tagName=$tagValue'"

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
        Write-Host "`[+`] Found $($arcResponseMachines.Count) ARC machines with tag '$tagName=$tagValue'"
        
        Write-SafeLog ""
        Write-SafeLog "RESOURCE DISCOVERY SUMMARY"
        Write-SafeLog ("=" * 50)
        Write-SafeLog "Discovery Method: Tag-based"
        Write-SafeLog "Tag Filter: $tagName = $tagValue"
        Write-SafeLog "Virtual Machines Found: $($vmResponseMachines.Count)"
        Write-SafeLog "Virtual Machine Scale Sets Found: $($vmssResponseMachines.Count)"
        Write-SafeLog "Azure Arc Machines Found: $($arcResponseMachines.Count)"
        Write-SafeLog "Total Resources Found: $(($vmResponseMachines.Count) + ($vmssResponseMachines.Count) + ($arcResponseMachines.Count))"
    }
    catch {
        $errorMsg = "`[-`] Failed to get resources! Error: $($_.Exception.Message)"
        Write-Host $errorMsg
        Write-SafeLog $errorMsg
        
        if ($_.Exception.Response.StatusCode.value__ -eq 401) {
            $authErrorMsg = "Authentication failed. Token may be invalid or expired. Please try running 'Connect-AzAccount' and run the script again."
            Write-Host $authErrorMsg
            Write-SafeLog $authErrorMsg
        }
        
        Write-SafeLog "Response StatusCode: $($_.Exception.Response.StatusCode.value__)"
        Write-SafeLog "Response StatusDescription: $($_.Exception.Response.StatusDescription)"
        Write-SafeLog "Full Error Details: $($_.Exception.ToString())"
        
        Write-Host "Response StatusCode:" -ForegroundColor Yellow
        Write-Host "Response StatusDescription:" -ForegroundColor Yellow
        Write-Host "Error from response:" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "`[-`] Entered invalid mode. Exiting script."
    exit 1;
}

#endregion

#region Resource Summary
Write-Host "`[*`] Resource Summary"

# Display found resources
Write-Host "`[*`] Found the following resources:"

Write-Host "`n[*] Virtual Machines ($($vmResponseMachines.Count)):" -ForegroundColor Green
if ($vmResponseMachines.Count -gt 0) {
    $count = 0
    foreach ($machine in $vmResponseMachines) {
        $count++
        Write-Host "  $count. $($machine.name)"
        $vmCount = $count
    }
} else {
    Write-Host "  No virtual machines found"
}

Write-Host "`n[*] Virtual Machine Scale Sets ($($vmssResponseMachines.Count)):" -ForegroundColor Green
if ($vmssResponseMachines.Count -gt 0) {
    $count = 0
    foreach ($machine in $vmssResponseMachines) {
        $count++
        Write-Host "  $count. $($machine.name)"
        $vmssCount = $count
    }
} else {
    Write-Host "  No virtual machine scale sets found"
}

Write-Host "`n[*] ARC Machines ($($arcResponseMachines.Count)):" -ForegroundColor Green
if ($arcResponseMachines.Count -gt 0) {
    $count = 0
    foreach ($machine in $arcResponseMachines) {
        $count++
        Write-Host "  $count. $($machine.name)"
        $arcCount = $count
    }
} else {
    Write-Host "  No ARC machines found"
}

#endregion

#region Action Selection
Write-Host "`[*`] Action Selection"

# Use provided action or prompt user
if ($Action) {
    Write-Host "`[+`] Using provided action: $($Action.ToUpper())"
    $PricingTier = $Action.ToLower()
    Write-SafeLog ""
    Write-SafeLog "ACTION CONFIGURATION"
    Write-SafeLog ("=" * 50)
    Write-SafeLog "Action Selected: $($Action.ToUpper())"
    Write-SafeLog "Selection Method: Provided as parameter"
    Write-SafeLog "Configuration Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"
} else {
    Write-Host ""
    Write-Host "`[*`] Choose your action:"
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
        Write-Host "[-] Invalid choice. Please enter a number between 1 and 4" -ForegroundColor Green
        $choice = Read-Host "Enter the number corresponding to your choice (default: $defaultPricingChoice)"
        if ([string]::IsNullOrWhiteSpace($choice)) { $choice = $defaultPricingChoice }
    }
    $PricingTier = $choices[$choice - 1]
    Write-SafeLog ""
    Write-SafeLog "ACTION CONFIGURATION"
    Write-SafeLog ("=" * 50)
    Write-SafeLog "Action Selected: $($PricingTier.ToUpper())"
    Write-SafeLog "Selection Method: Interactive user input (choice $choice)"
    Write-SafeLog "Configuration Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"
    
    # Log action description
    $actionDescription = switch ($PricingTier.ToLower()) {
        "read" { "Read current pricing configuration without making changes" }
        "free" { "Remove Defender for Servers protection (set to Free tier)" }
        "standard" { "Enable Defender for Servers Plan 1 (P1)" }
        "delete" { "Remove resource-level configuration (inherit from parent)" }
    }
    Write-SafeLog "Action Description: $actionDescription"
}

#endregion

#region Resource Processing
Write-Host "`[*`] Resource Processing"

# Log the start of resource processing
Write-SafeLog ""
Write-SafeLog "RESOURCE PROCESSING PHASE INITIATED"
Write-SafeLog ("=" * 50)
Write-SafeLog "Processing Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"
Write-SafeLog "Total Resources to Process: $(($vmResponseMachines.Count) + ($vmssResponseMachines.Count) + ($arcResponseMachines.Count))"
Write-SafeLog "Action to Perform: $($PricingTier.ToUpper())"
Write-SafeLog ""

# Process Virtual Machines
if ($vmResponseMachines.Count -gt 0) {
    Write-Host "`[*`] Processing Virtual Machines:"
    Write-SafeLog "PROCESSING VIRTUAL MACHINES ($($vmResponseMachines.Count) resources)"
    Write-SafeLog ("-" * 40)
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
        Write-SafeLog "Processing VM: $($machine.name) with action: $($PricingTier.ToUpper())"
        
        try {
            if($PricingTier.ToLower() -eq "delete") {
                $pricingResponse = Invoke-RestMethod -Method Delete -Uri $pricingUrl -Headers @{Authorization = "Bearer $script:accessToken"} -ContentType "application/json" -TimeoutSec 120
                Write-Host "`[+`] Successfully deleted pricing configuration for $($machine.name)"
                Write-ResourceDetailsToLog -Resource $machine -ResourceType "VM" -Action $PricingTier -Result "SUCCESS - Configuration deleted"
                $successCount++
                $vmSuccessCount++
            } elseif ($PricingTier.ToLower() -eq "read") {
                $pricingResponse = Invoke-RestMethod -Method Get -Uri $pricingUrl -Headers @{Authorization = "Bearer $script:accessToken"} -ContentType "application/json" -TimeoutSec 120
                Write-Host "`[+`] Successfully read pricing configuration for $($machine.name)"
                Write-ResourceDetailsToLog -Resource $machine -ResourceType "VM" -Action $PricingTier -Result "SUCCESS - Configuration read" -PricingResponse $pricingResponse
                Format-PricingConfiguration -PricingResponse $pricingResponse -ResourceName $machine.name -ResourceDetails $machine
                $successCount++
                $vmSuccessCount++
            } else {
                $pricingResponse = Invoke-RestMethod -Method Put -Uri $pricingUrl -Headers @{Authorization = "Bearer $script:accessToken"} -Body ($pricingBody | ConvertTo-Json) -ContentType "application/json" -TimeoutSec 120
                Write-Host "`[+`] Successfully updated pricing configuration for $($machine.name)"
                Write-ResourceDetailsToLog -Resource $machine -ResourceType "VM" -Action $PricingTier -Result "SUCCESS - Configuration updated to $($PricingTier.ToUpper())" -PricingResponse $pricingResponse
                $successCount++
                $vmSuccessCount++
            }
        }
        catch {
            $failureCount++
            $errorMessage = "Error processing VM $($machine.name): $($_.Exception.Message)"
            Write-Host "`[-`] Failed to update pricing configuration for $($machine.name)"
            Write-ResourceDetailsToLog -Resource $machine -ResourceType "VM" -Action $PricingTier -Result "FAILED" -ErrorDetails $errorMessage
            
            Write-Host "Response StatusCode:" -ForegroundColor Yellow
            Write-Host "Response StatusDescription:" -ForegroundColor Yellow
            Write-Host "Error from response:" -ForegroundColor Yellow
        }
        Write-Host ""
        Start-Sleep -Seconds 0.3
    }
    Write-Host "-" * 80
}

# Process Virtual Machine Scale Sets
if ($vmssResponseMachines.Count -gt 0) {
    Write-Host "`[*`] Processing Virtual Machine Scale Sets:"
    Write-SafeLog ""
    Write-SafeLog "PROCESSING VIRTUAL MACHINE SCALE SETS ($($vmssResponseMachines.Count) resources)"
    Write-SafeLog ("-" * 40)
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
                Write-Host "`[+`] Successfully deleted pricing configuration for $($machine.name)"
                Write-ResourceDetailsToLog -Resource $machine -ResourceType "VMSS" -Action $PricingTier -Result "SUCCESS - Configuration deleted"
                $successCount++
                $vmssSuccessCount++
            } elseif ($PricingTier.ToLower() -eq "read") {
                $pricingResponse = Invoke-RestMethod -Method Get -Uri $pricingUrl -Headers @{Authorization = "Bearer $script:accessToken"} -ContentType "application/json" -TimeoutSec 120
                Write-Host "`[+`] Successfully read pricing configuration for $($machine.name)"
                Write-ResourceDetailsToLog -Resource $machine -ResourceType "VMSS" -Action $PricingTier -Result "SUCCESS - Configuration read" -PricingResponse $pricingResponse
                Format-PricingConfiguration -PricingResponse $pricingResponse -ResourceName $machine.name -ResourceDetails $machine
                $successCount++
                $vmssSuccessCount++
            } else {
                $pricingResponse = Invoke-RestMethod -Method Put -Uri $pricingUrl -Headers @{Authorization = "Bearer $script:accessToken"} -Body ($pricingBody | ConvertTo-Json) -ContentType "application/json" -TimeoutSec 120
                Write-Host "`[+`] Successfully updated pricing configuration for $($machine.name)"
                Write-ResourceDetailsToLog -Resource $machine -ResourceType "VMSS" -Action $PricingTier -Result "SUCCESS - Configuration updated to $($PricingTier.ToUpper())" -PricingResponse $pricingResponse
                $successCount++
                $vmssSuccessCount++
            }
        }
        catch {
            $failureCount++
            $errorMessage = "Error processing VMSS $($machine.name): $($_.Exception.Message)"
            Write-Host "`[-`] Failed to update pricing configuration for $($machine.name)"
            Write-ResourceDetailsToLog -Resource $machine -ResourceType "VMSS" -Action $PricingTier -Result "FAILED" -ErrorDetails $errorMessage
            
            Write-Host "Response StatusCode:" -ForegroundColor Yellow
            Write-Host "Response StatusDescription:" -ForegroundColor Yellow
            Write-Host "Error from response:" -ForegroundColor Yellow
        }
        Write-Host ""
        Start-Sleep -Seconds 0.3
    }
    Write-Host "-" * 80
}

# Process ARC Machines
if ($arcResponseMachines.Count -gt 0) {
    Write-Host "`[*`] Processing ARC Machines:"
    Write-SafeLog ""
    Write-SafeLog "PROCESSING AZURE ARC MACHINES ($($arcResponseMachines.Count) resources)"
    Write-SafeLog ("-" * 40)
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
        Write-Host "`[*`] Processing pricing configuration for '$($machine.name)':"
        try {
            if($PricingTier.ToLower() -eq "delete") {
                $pricingResponse = Invoke-RestMethod -Method Delete -Uri $pricingUrl -Headers @{Authorization = "Bearer $script:accessToken"} -ContentType "application/json" -TimeoutSec 120
                Write-Host "`[+`] Successfully deleted pricing configuration for $($machine.name)"
                Write-ResourceDetailsToLog -Resource $machine -ResourceType "ARC" -Action $PricingTier -Result "SUCCESS - Configuration deleted"
                $successCount++
                $arcSuccessCount++
            } elseif ($PricingTier.ToLower() -eq "read") {
                $pricingResponse = Invoke-RestMethod -Method Get -Uri $pricingUrl -Headers @{Authorization = "Bearer $script:accessToken"} -ContentType "application/json" -TimeoutSec 120
                Write-Host "`[+`] Successfully read pricing configuration for $($machine.name)"
                Write-ResourceDetailsToLog -Resource $machine -ResourceType "ARC" -Action $PricingTier -Result "SUCCESS - Configuration read" -PricingResponse $pricingResponse
                Format-PricingConfiguration -PricingResponse $pricingResponse -ResourceName $machine.name -ResourceDetails $machine
                $successCount++
                $arcSuccessCount++
            } else {
                $pricingResponse = Invoke-RestMethod -Method Put -Uri $pricingUrl -Headers @{Authorization = "Bearer $script:accessToken"} -Body ($pricingBody | ConvertTo-Json) -ContentType "application/json" -TimeoutSec 120
                Write-Host "`[+`] Successfully updated pricing configuration for $($machine.name)"
                Write-ResourceDetailsToLog -Resource $machine -ResourceType "ARC" -Action $PricingTier -Result "SUCCESS - Configuration updated to $($PricingTier.ToUpper())" -PricingResponse $pricingResponse
                $successCount++
                $arcSuccessCount++
            }
        }
        catch {
            $failureCount++
            $errorMessage = "Error processing ARC machine $($machine.name): $($_.Exception.Message)"
            Write-Host "`[-`] Failed to update pricing configuration for $($machine.name)"
            Write-ResourceDetailsToLog -Resource $machine -ResourceType "ARC" -Action $PricingTier -Result "FAILED" -ErrorDetails $errorMessage
            
            Write-Host "Response StatusCode:" -ForegroundColor Yellow
            Write-Host "Response StatusDescription:" -ForegroundColor Yellow
            Write-Host "Error from response:" -ForegroundColor Yellow
        }
        Write-Host ""
        Start-Sleep -Seconds 0.3
    }
}

#endregion

#region Final Summary
Write-Host "`[*`] Final Summary"

Write-Host "`[*`] Summary of Pricing API Results:"

Write-Host ""
Write-Host "`[*`] Virtual Machines:"
Write-Host "   Found: $vmCount"
Write-Host "   [+] Successful: $vmSuccessCount" -ForegroundColor Green
$vmFailedColor = if ($($vmCount - $vmSuccessCount) -gt 0) { 'Red' } else { 'Green' }
Write-Host "   [-] Failed: $($vmCount - $vmSuccessCount)" -ForegroundColor $vmFailedColor

Write-Host ""
Write-Host "`[*`] Virtual Machine Scale Sets:"
Write-Host "   Found: $vmssCount"
Write-Host "   [+] Successful: $vmssSuccessCount" -ForegroundColor Green
$vmssFailedColor = if ($($vmssCount - $vmssSuccessCount) -gt 0) { 'Red' } else { 'Green' }
Write-Host "   [-] Failed: $($vmssCount - $vmssSuccessCount)" -ForegroundColor $vmssFailedColor

Write-Host ""
Write-Host "`[*`] ARC Machines:"
Write-Host "   Found: $arcCount"
Write-Host "   [+] Successful: $arcSuccessCount" -ForegroundColor Green
$arcFailedColor = if ($($arcCount - $arcSuccessCount) -gt 0) { 'Red' } else { 'Green' }
Write-Host "   [-] Failed: $($arcCount - $arcSuccessCount)" -ForegroundColor $arcFailedColor

Write-Host ""
Write-Host "`[*`] Overall Results:"
Write-Host "   [+] Total Successful: $successCount" -ForegroundColor Green
$totalFailedColor = if ($failureCount -gt 0) { 'Red' } else { 'Green' }
Write-Host "   [-] Total Failures: $failureCount" -ForegroundColor $totalFailedColor

Write-Host ""
Write-Host "Function execution completed!`n"

# Write final summary to log file
Write-SafeLog ""
Write-SafeLog ("=" * 120)
Write-SafeLog "COMPREHENSIVE SESSION SUMMARY & ANALYSIS"
Write-SafeLog ("=" * 120)
Write-SafeLog "Session Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"
Write-SafeLog "Total Processing Time: $((Get-Date) - $startTime)"
Write-SafeLog ""
Write-SafeLog "CONFIGURATION SUMMARY:"
Write-SafeLog "- Operation Mode: $mode"
if ($mode.ToLower() -eq "rg") {
    Write-SafeLog "- Target Resource Group: $resourceGroupName"
} else {
    Write-SafeLog "- Tag Filter: $tagName = $tagValue"
}
Write-SafeLog "- Action Performed: $($PricingTier.ToUpper())"
Write-SafeLog "- Subscription: $subName ($subId)"
Write-SafeLog ""
Write-SafeLog "PROCESSING RESULTS BY RESOURCE TYPE:"
Write-SafeLog "┌─────────────────────────────────┬───────────┬─────────────┬────────────┬─────────────────┐"
Write-SafeLog "│ Resource Type                   │ Found     │ Successful  │ Failed     │ Success Rate    │"
Write-SafeLog "├─────────────────────────────────┼───────────┼─────────────┼────────────┼─────────────────┤"
$vmSuccessRate = if ($vmCount -gt 0) { [math]::Round(($vmSuccessCount / $vmCount) * 100, 1) } else { 0 }
Write-SafeLog "│ Virtual Machines                │ $($vmCount.ToString().PadLeft(9)) │ $($vmSuccessCount.ToString().PadLeft(11)) │ $(($vmCount - $vmSuccessCount).ToString().PadLeft(10)) │ $($vmSuccessRate.ToString().PadLeft(13))%  │"
$vmssSuccessRate = if ($vmssCount -gt 0) { [math]::Round(($vmssSuccessCount / $vmssCount) * 100, 1) } else { 0 }
Write-SafeLog "│ Virtual Machine Scale Sets      │ $($vmssCount.ToString().PadLeft(9)) │ $($vmssSuccessCount.ToString().PadLeft(11)) │ $(($vmssCount - $vmssSuccessCount).ToString().PadLeft(10)) │ $($vmssSuccessRate.ToString().PadLeft(13))%  │"
$arcSuccessRate = if ($arcCount -gt 0) { [math]::Round(($arcSuccessCount / $arcCount) * 100, 1) } else { 0 }
Write-SafeLog "│ Azure Arc Machines              │ $($arcCount.ToString().PadLeft(9)) │ $($arcSuccessCount.ToString().PadLeft(11)) │ $(($arcCount - $arcSuccessCount).ToString().PadLeft(10)) │ $($arcSuccessRate.ToString().PadLeft(13))%  │"
Write-SafeLog "└─────────────────────────────────┴───────────┴─────────────┴────────────┴─────────────────┘"
Write-SafeLog ""
$totalResources = $vmCount + $vmssCount + $arcCount
$overallSuccessRate = if ($totalResources -gt 0) { [math]::Round(($successCount / $totalResources) * 100, 1) } else { 0 }
Write-SafeLog "OVERALL STATISTICS:"
Write-SafeLog "- Total Resources Processed: $totalResources"
Write-SafeLog "- Total Successful Operations: $successCount"
Write-SafeLog "- Total Failed Operations: $failureCount"
Write-SafeLog "- Overall Success Rate: $overallSuccessRate%"
Write-SafeLog ""
if ($failureCount -gt 0) {
    Write-SafeLog "RECOMMENDATIONS:"
    Write-SafeLog "- Review failed operations above for detailed error information"
    Write-SafeLog "- Verify Azure permissions for Defender for Cloud pricing management"
    Write-SafeLog "- Check network connectivity and authentication status"
    Write-SafeLog "- Consider re-running failed operations individually"
} else {
    Write-SafeLog "RESULT: All operations completed successfully!"
}
Write-SafeLog ""
Write-SafeLog "AUDIT TRAIL:"
Write-SafeLog "- Log File Location: $logFile"
Write-SafeLog "- PowerShell Version: $($PSVersionTable.PSVersion)"
Write-SafeLog "- Execution User: $($env:USERNAME)"
Write-SafeLog "- Execution Computer: $($env:COMPUTERNAME)"
Write-SafeLog "- Script Version: 2.0"
Write-SafeLog ("=" * 120)

if ($logFile) {
    Write-Host "`[*`] Session log saved to: $logFile" -ForegroundColor Green
}
#endregion

}












