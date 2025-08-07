function New-AzureArcDevice {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    <#
    .SYNOPSIS
        Creates and configures Azure Arc-enabled devices with Group Policy deployment.

    .DESCRIPTION
        This function automates the process of setting up Azure Arc for device onboarding using Group Policy.
        It creates the necessary Azure resources, downloads required components, configures service principals,
        and deploys Group Policy objects for automated Azure Arc agent installation across multiple devices.

        The function performs the following operations:
        - Validates Azure authentication and prerequisites
        - Creates Azure resource groups and configures deployment parameters
        - Sets up remote file shares for Group Policy deployment
        - Downloads Azure Connected Machine Agent and Group Policy templates
        - Creates service principals with appropriate permissions
        - Deploys and links Group Policy objects to specified organizational units

    .PARAMETER SubscriptionId
        Optional Azure subscription ID to use. If not provided, user will be prompted to select.

    .PARAMETER ResourceGroupName
        Optional name for the Azure resource group. If not provided, user will be prompted.

    .PARAMETER Location
        Optional Azure region for resource deployment. If not provided, user will be prompted.

    .PARAMETER SharePath
        Optional path for the remote share used for Group Policy deployment. If not provided, the standardized AzureArc folder on desktop will be used.

    .PARAMETER Force
        Skip confirmation prompts and proceed with default values where applicable.

    .EXAMPLE
        New-AzureArcDevice

        Interactively creates Azure Arc device configuration with user prompts for all parameters.

    .EXAMPLE
        New-AzureArcDevice -SubscriptionId "12345678-1234-1234-1234-123456789012" -ResourceGroupName "rg-azurearc-prod" -Location "eastus" -Force

        Creates Azure Arc configuration with specified parameters and minimal prompting.

    .NOTES
        Author: Lessi Coulibaly
        Organization: Less-IT (AI and CyberSecurity)
        Website: https://github.com/coullessi/PowerShell

        Prerequisites:
        - Azure PowerShell modules (Az.Accounts, Az.Resources)
        - Valid Azure subscription with appropriate permissions
        - Active Directory environment with Group Policy management capabilities
        - Network access to Azure endpoints
        - Run Get-AzureArcPrerequisites first to ensure all requirements are met
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $false)]
        [string]$Location,

        [Parameter(Mandatory = $false)]
        [string]$SharePath,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    # Remove quotes from parameters if provided
    if (-not [string]::IsNullOrWhiteSpace($SharePath)) {
        $SharePath = Remove-PathQuote -Path $SharePath
    }

    # Initialize standardized environment
    $environment = Initialize-StandardizedEnvironment -ScriptName "New-AzureArcDevice" -RequiredFileTypes @("DeviceLog", "OrgUnitList")

    # Check if user chose to quit
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
    $orgUnitsFile = $environment.FilePaths["OrgUnitList"]

    Clear-Host

    Write-Host "" -ForegroundColor Cyan
    Write-Host " ======================== AZURE ARC DEVICE DEPLOYMENT ========================  " -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan
    Write-Host ""

    Write-Host " Initializing Azure Arc Device Deployment..." -ForegroundColor Cyan
    Write-Host ""

    # Log session start
    ("=" * 100) | Out-File -FilePath $logFile
    "AZURE ARC DEVICE DEPLOYMENT SESSION" | Out-File -FilePath $logFile -Append
    ("=" * 100) | Out-File -FilePath $logFile -Append
    "Started: $(Get-Date)" | Out-File -FilePath $logFile -Append
    "Working Folder: $workingFolder" | Out-File -FilePath $logFile -Append
    "" | Out-File -FilePath $logFile -Append

    # Azure Authentication and Subscription Selection
    $authResult = Initialize-AzureAuthenticationAndSubscription -SubscriptionId $SubscriptionId
    if (-not $authResult.Success) {
        Write-Host " Azure authentication or subscription selection failed: $($authResult.Message)" -ForegroundColor Red
        "FAILED: Azure authentication - $($authResult.Message)" | Out-File -FilePath $logFile -Append
        return
    }

    Write-Host " Using Azure context: $($authResult.Context.Account.Id)" -ForegroundColor Green
    $subId = $authResult.SubscriptionId
    $TenantId = $authResult.Context.Tenant.Id

    # 1. Get resource group and location information
    Write-Host "`n Azure Resource Configuration" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan

    # Prompt for resource group
    if ([string]::IsNullOrWhiteSpace($ResourceGroupName)) {
        $defaultResourceGroup = "rg-azurearc-$(Get-Date -Format 'yyyyMMdd')"
        $resourceGroup = Read-Host "`nProvide a resource group name for your Azure Arc deployment `n[default: $defaultResourceGroup]"

        # Use default if user pressed Enter without input
        if ([string]::IsNullOrWhiteSpace($resourceGroup)) {
            $resourceGroup = $defaultResourceGroup
            Write-Host " Using default resource group: $resourceGroup" -ForegroundColor Green
        } else {
            Write-Host " Resource group: $resourceGroup" -ForegroundColor Green
        }
    } else {
        $resourceGroup = $ResourceGroupName
        Write-Host " Using provided resource group: $resourceGroup" -ForegroundColor Green
    }

    # Prompt for location
    if ([string]::IsNullOrWhiteSpace($Location)) {
        $defaultLocation = "eastus"
        $location = Read-Host "`nProvide an Azure region for your deployment [default: $defaultLocation] (e.g., westus2, westeurope)"

        # Use default if user pressed Enter without input
        if ([string]::IsNullOrWhiteSpace($location)) {
            $location = $defaultLocation
            Write-Host " Using default location: $location" -ForegroundColor Green
        } else {
            $validLocations = @("eastus", "eastus2", "westus", "westus2", "westeurope", "northeurope", "southeastasia", "eastasia", "australiaeast", "uksouth", "canadacentral", "francecentral", "germanywestcentral", "japaneast", "koreacentral", "southafricanorth", "uaenorth", "brazilsouth", "southcentralus", "northcentralus", "centralus", "westcentralus", "westus3")

            while ($validLocations -notcontains $location.ToLower()) {
                Write-Host " Invalid location: '$location'" -ForegroundColor Red
                Write-Host " Common locations: eastus, westus2, westeurope, eastasia, australiaeast" -ForegroundColor Yellow
                $location = Read-Host "Provide a valid Azure region for your deployment [default: $defaultLocation]"

                # Use default if user pressed Enter without input
                if ([string]::IsNullOrWhiteSpace($location)) {
                    $location = $defaultLocation
                    break
                }
            }
            Write-Host " Location: $location" -ForegroundColor Green
        }
    } else {
        $location = $Location
        Write-Host " Using provided location: $location" -ForegroundColor Green
    }

    # 2. Create a resource group
    Write-Host "`n  Creating Azure Resource Group" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan

    # Check if resource group already exists
    $existingRG = Get-AzResourceGroup -Name $resourceGroup -ErrorAction SilentlyContinue

    if ($existingRG) {
        if ($existingRG.Location -eq $location) {
            # Same location - resource group already exists, just continue
            Write-Host " Resource group '$resourceGroup' already exists in '$location' - continuing..." -ForegroundColor Yellow
        } else {
            # Different location - not allowed by Azure, show clear error
            Write-Host " ERROR: Resource group '$resourceGroup' already exists in '$($existingRG.Location)'" -ForegroundColor Red
            Write-Host " Azure does not allow resource groups with the same name in different locations within the same subscription." -ForegroundColor Yellow
            Write-Host " Please choose a different resource group name or use the existing location '$($existingRG.Location)'." -ForegroundColor Yellow
            throw "Resource group name conflict: '$resourceGroup' already exists in '$($existingRG.Location)'"
        }
    } else {
        # Resource group doesn't exist - create it
        Write-Host "Creating resource group '$resourceGroup' in '$location'..." -ForegroundColor Yellow
        try {
            New-AzResourceGroup -Name $resourceGroup -Location $location | Out-Null
            Write-Host " Resource group created successfully!" -ForegroundColor Green
        }
        catch {
            Write-Host " Failed to create resource group: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
    }

    # 3. Configure remote share using standardized folder
    Write-Host "`n Remote Share Configuration" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan

    try {
        $DomainName = (Get-ADDomain).DNSRoot
    }
    catch {
        Write-Host " Unable to retrieve Active Directory domain information. Ensure this is run on a domain-joined machine." -ForegroundColor Red
        "FAILED: Active Directory domain information retrieval" | Out-File -FilePath $logFile -Append
        throw
    }

    # Use the standardized working folder for the remote share
    $path = $workingFolder
    Write-Host " Using standardized working folder for remote share: $path" -ForegroundColor Green
    "Remote share location: $path" | Out-File -FilePath $logFile -Append

    # Extract share name from the last directory in the path
    $shareName = Split-Path -Leaf $path
    Write-Host " Share name will be: $shareName" -ForegroundColor Green

    # Check if share name already exists and points to a different path
    $existingShare = Get-SmbShare | Where-Object { $_.Name -eq $shareName } -ErrorAction SilentlyContinue
    $useExistingShare = $false

    if ($existingShare -and $existingShare.Path -ne $path) {
        Write-Host "  Share '$shareName' already exists and points to: $($existingShare.Path)" -ForegroundColor Yellow
        Write-Host " You specified a different path: $path" -ForegroundColor Yellow

        # Create a unique share name by appending a timestamp
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $originalShareName = $shareName
        $shareName = "$originalShareName`_$timestamp"
        Write-Host " Using unique share name: $shareName" -ForegroundColor Green
    } elseif ($existingShare -and $existingShare.Path -eq $path) {
        Write-Host " Share '$shareName' already exists and points to the correct path" -ForegroundColor Green
        $useExistingShare = $true
    }

    # Create directory and share if needed
    Write-Host "`nCreating remote share..." -ForegroundColor Yellow

    # Verify the directory exists (it should have been created by Test-ValidPath if needed)
    if (-not (Test-Path -PathType container $path)) {
        Write-Host " [FAIL] Directory does not exist and could not be created: $path" -ForegroundColor Red
        throw "Directory validation failed: $path"
    } else {
        Write-Host " Directory verified: $path" -ForegroundColor Green
    }

    # Create share if it doesn't exist or if we need a new unique name
    if (-not $useExistingShare) {
        $parameters = @{
            Name         = $shareName
            Path         = "$($path)"
            FullAccess   = "$env:USERDOMAIN\$env:USERNAME", "$DomainName\Domain Admins"
            ChangeAccess = "$DomainName\Domain Users", "$DomainName\Domain Computers", "$DomainName\Domain Controllers"
        }
        try {
            New-SmbShare @parameters -ErrorAction Stop | Out-Null
            Write-Host " SMB share '$shareName' created successfully!" -ForegroundColor Green
        }
        catch {
            if ($_.Exception.Message -match "already exists" -or $_.Exception.Message -match "already shared" -or $_.Exception.Message -match "name has already been shared") {
                Write-Host "  SMB share '$shareName' already exists" -ForegroundColor Yellow
            } else {
                Write-Host " Failed to create SMB share: $($_.Exception.Message)" -ForegroundColor Red
                throw
            }
        }
    }

    # Set the remote share name for use in GPO deployment
    $RemoteShare = $shareName
    Write-Host " Remote share '$RemoteShare' is ready for deployment" -ForegroundColor Green
    Write-Host " All files will be stored in: $path" -ForegroundColor Gray

    # 4. Download and prepare Azure Arc Components (enhanced functionality)
    Write-Host "`n Downloading Azure Arc Components" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan

    # Download Azure Connected Machine Agent with enhanced error handling
    Write-Host " Downloading Azure Connected Machine Agent..." -ForegroundColor Yellow
    $agentPath = "$path\AzureConnectedMachineAgent.msi"

    try {
        # Check if agent already exists
        if (Test-Path $agentPath) {
            Write-Host "  Agent installer already exists. Checking if update is needed..." -ForegroundColor Yellow
            $overwrite = Read-Host "Do you want to download a fresh copy? [Y/N] (default: N)"
            if ($overwrite.ToUpper() -eq 'Y') {
                Remove-Item $agentPath -Force
                Write-Host "  Existing installer removed" -ForegroundColor Gray
            } else {
                Write-Host " Using existing Azure Connected Machine Agent installer" -ForegroundColor Green
            }
        }

        if (-not (Test-Path $agentPath)) {
            $downloadUrl = "https://aka.ms/AzureConnectedMachineAgent"
            Write-Host " Downloading from: $downloadUrl" -ForegroundColor Gray

            # Download with progress indication
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($downloadUrl, $agentPath)
            $webClient.Dispose()

            # Verify download
            if (Test-Path $agentPath) {
                $fileSize = (Get-Item $agentPath).Length / 1MB
                Write-Host " Azure Connected Machine Agent downloaded successfully" -ForegroundColor Green
                Write-Host " File size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Gray
            } else {
                throw "Download completed but file not found"
            }
        }
    }
    catch {
        Write-Host " Failed to download Azure Connected Machine Agent: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }

    # Get the latest ArcEnabledServersGroupPolicy release
    Write-Host "Fetching latest ArcEnabledServersGroupPolicy release information..." -ForegroundColor Yellow
    try {
        # Get latest release information from GitHub API
        $releaseApiUrl = "https://api.github.com/repos/Azure/ArcEnabledServersGroupPolicy/releases/latest"
        $releaseInfo = Invoke-RestMethod -Uri $releaseApiUrl -Method Get

        # Find the zip file asset
        $zipAsset = $releaseInfo.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1

        if (-not $zipAsset) {
            throw "No zip file found in the latest release"
        }

        $latestVersion = $releaseInfo.tag_name
        $downloadUrl = $zipAsset.browser_download_url
        $fileName = $zipAsset.name

        Write-Host " Latest version found: $latestVersion" -ForegroundColor Green
        Write-Host " File: $fileName" -ForegroundColor Gray

        # Download the latest version
        Write-Host "Downloading $fileName..." -ForegroundColor Yellow
        $localFilePath = "$path\$fileName"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $localFilePath
        Write-Host " ArcEnabledServersGroupPolicy downloaded successfully" -ForegroundColor Green

        # Extract the archive
        Write-Host "Extracting $fileName..." -ForegroundColor Yellow

        # Remove file extension to get folder name
        $extractFolderName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
        $extractPath = "$path\$extractFolderName"

        # Remove existing extraction folder if it exists
        if (Test-Path $extractPath) {
            Remove-Item $extractPath -Recurse -Force
            Write-Host "  Removed existing extraction folder" -ForegroundColor Gray
        }

        Expand-Archive -LiteralPath $localFilePath -DestinationPath $path -Force
        Write-Host " Archive extracted successfully" -ForegroundColor Green

        # Set location to the extracted folder
        Set-Location -Path $extractPath
        Write-Host " Working directory set to: $extractPath" -ForegroundColor Gray

    }
    catch {
        Write-Host " Failed to download latest ArcEnabledServersGroupPolicy: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Falling back to hardcoded version 1.0.5..." -ForegroundColor Yellow

        try {
            # Fallback to hardcoded version
            $fallbackUrl = "https://github.com/Azure/ArcEnabledServersGroupPolicy/releases/download/1.0.5/ArcEnabledServersGroupPolicy_v1.0.10.zip"
            $fallbackFile = "$path\ArcEnabledServersGroupPolicy_v1.0.10.zip"

            Invoke-WebRequest -Uri $fallbackUrl -OutFile $fallbackFile
            Write-Host " Fallback version downloaded successfully" -ForegroundColor Green

            Expand-Archive -LiteralPath $fallbackFile -DestinationPath $path -Force
            Set-Location -Path "$path\ArcEnabledServersGroupPolicy_v1.0.10"
            Write-Host " Fallback archive extracted successfully" -ForegroundColor Green
        }
        catch {
            Write-Host " Fallback download also failed: $($_.Exception.Message)" -ForegroundColor Red
            throw "Failed to download ArcEnabledServersGroupPolicy from both latest and fallback sources"
        }
    }

    # 5. Create a service principal for the Azure Connected Machine Agent (enhanced functionality)
    Write-Host "`n Creating Service Principal" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan
    Write-Host "Creating Azure Arc service principal for onboarding..." -ForegroundColor Yellow

    $date = Get-Date
    $ArcServerOnboardingDetail = New-Item -ItemType File -Path "$path\ArcServerOnboarding.txt"
    "------------------------------------------------------------------------------" | Out-File -FilePath $ArcServerOnboardingDetail -Append
    "`nService principal creation date: $date`nSecret expiration date: $($date.AddDays(30))" | Out-File -FilePath $ArcServerOnboardingDetail -Append

    try {
        # Enhanced service principal creation with better configuration
        $displayName = "Azure Arc Deployment Account - ServerProtection"
        $expirationDate = $date.AddDays(30)  # Longer expiration period
        $scope = "/subscriptions/$subId/resourceGroups/$resourceGroup"

        Write-Host " Service Principal Configuration:" -ForegroundColor Yellow
        Write-Host "  Display Name: $displayName" -ForegroundColor Gray
        Write-Host "  Scope: $scope" -ForegroundColor Gray
        Write-Host "  Expiration: $($expirationDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray

        # Create the service principal with enhanced error handling
        Write-Host " Creating service principal..." -ForegroundColor Yellow
        $ServicePrincipal = New-AzADServicePrincipal -DisplayName $displayName -EndDate $expirationDate

        if ($ServicePrincipal) {
            Write-Host " Service principal created successfully!" -ForegroundColor Green
            Write-Host " Waiting for Azure propagation..." -ForegroundColor Yellow
            Start-Sleep -Seconds 10  # Wait for Azure to propagate the service principal

            # Assign the role with retry logic
            $maxRetries = 3
            $retryCount = 0
            $roleAssigned = $false

            while (-not $roleAssigned -and $retryCount -lt $maxRetries) {
                try {
                    $retryCount++
                    Write-Host " Attempting role assignment (attempt $retryCount of $maxRetries)..." -ForegroundColor Yellow

                    New-AzRoleAssignment -ObjectId $ServicePrincipal.Id -RoleDefinitionName "Azure Connected Machine Onboarding" -Scope $scope -ErrorAction Stop
                    $roleAssigned = $true
                    Write-Host " Role assignment completed successfully!" -ForegroundColor Green
                }
                catch {
                    Write-Host "  Role assignment attempt $retryCount failed: $($_.Exception.Message)" -ForegroundColor Yellow
                    if ($retryCount -lt $maxRetries) {
                        Write-Host "  Waiting 15 seconds before retry..." -ForegroundColor Gray
                        Start-Sleep -Seconds 15
                    } else {
                        Write-Host " All role assignment attempts failed. Service principal created but role not assigned." -ForegroundColor Red
                        Write-Host " You may need to manually assign the 'Azure Connected Machine Onboarding' role to the service principal." -ForegroundColor Yellow
                    }
                }
            }

            # Save detailed service principal information
            $spDetails = @"
Service Principal Details:
Application ID: $($ServicePrincipal.AppId)
Object ID: $($ServicePrincipal.Id)
Display Name: $($ServicePrincipal.DisplayName)
Subscription: $($authResult.SubscriptionName)
Resource Group: $resourceGroup
Scope: $scope
Creation Date: $($date.ToString('yyyy-MM-dd HH:mm:ss'))
Expiration Date: $($expirationDate.ToString('yyyy-MM-dd HH:mm:ss'))
"@
            $spDetails | Out-File -FilePath $ArcServerOnboardingDetail -Append

            $AppId = $ServicePrincipal.AppId
            $Secret = $ServicePrincipal.PasswordCredentials.SecretText

            Write-Host " Service principal details saved to: $($ArcServerOnboardingDetail.FullName)" -ForegroundColor Green
            Write-Host " Application ID: $AppId" -ForegroundColor Gray
            Write-Host "  Secret: [HIDDEN FOR SECURITY - Use from memory during deployment]" -ForegroundColor Yellow
            Write-Host " Secret expires: $($expirationDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray

            Write-Host "`n  IMPORTANT SECURITY NOTES:" -ForegroundColor Red
            Write-Host "   Store the client secret securely - it cannot be retrieved again" -ForegroundColor Yellow
            Write-Host "   The secret expires on $($expirationDate.ToString('yyyy-MM-dd'))" -ForegroundColor Yellow
            Write-Host "   Limit access to these credentials to authorized personnel only" -ForegroundColor Yellow
        } else {
            Write-Host " Failed to create service principal" -ForegroundColor Red
            throw "Service principal creation failed"
        }
    }
    catch {
        Write-Host " Failed to create service principal: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }

    # 6. Deploy the group policy object and link it to the selected organizational units
    try {
        $DC = Get-ADDomainController
        $DomainFQDN = $DC.Domain
        $ReportServerFQDN = $DC.HostName
    }
    catch {
        Write-Host " Unable to retrieve Active Directory domain controller information." -ForegroundColor Red
        throw
    }

    Write-Host "`n Deploying Group Policy Object" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan

    # Check if DeployGPO.ps1 exists with enhanced validation
    $deployGPOFound = $false
    $deployGPOPath = ".\DeployGPO.ps1"

    # First check current directory
    if (Test-Path $deployGPOPath) {
        $deployGPOValidation = Test-ValidPath -Path $deployGPOPath -PathType File -RequireExists
        if ($deployGPOValidation.IsValid) {
            Write-Host " Found DeployGPO.ps1 in current directory" -ForegroundColor Green
            $deployGPOFound = $true
        }
    }

    # If not found, search in the path directory
    if (-not $deployGPOFound) {
        Write-Host " DeployGPO.ps1 not found in current directory: $(Get-Location)" -ForegroundColor Yellow
        Write-Host " Searching in extracted ArcEnabledServersGroupPolicy folder..." -ForegroundColor Yellow

        try {
            $foundPath = Get-ChildItem -Path $path -Recurse -Name "DeployGPO.ps1" -ErrorAction Stop | Select-Object -First 1
            if ($foundPath) {
                $fullDeployGPOPath = Join-Path $path $foundPath
                $deployGPOValidation = Test-ValidPath -Path $fullDeployGPOPath -PathType File -RequireExists

                if ($deployGPOValidation.IsValid) {
                    Write-Host " Found DeployGPO.ps1 at: $fullDeployGPOPath" -ForegroundColor Green
                    $parentDir = Split-Path $fullDeployGPOPath -Parent

                    # Validate we can access the parent directory
                    $parentDirValidation = Test-ValidPath -Path $parentDir -PathType Directory -RequireExists
                    if ($parentDirValidation.IsValid) {
                        Set-Location $parentDir
                        Write-Host " Changed working directory to: $parentDir" -ForegroundColor Green
                        $deployGPOFound = $true
                    } else {
                        Write-Host " Cannot access directory containing DeployGPO.ps1: $($parentDirValidation.Error)" -ForegroundColor Red
                    }
                }
            }
        } catch {
            Write-Host " Error searching for DeployGPO.ps1: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Final validation
    if (-not $deployGPOFound) {
        Write-Host " Could not locate DeployGPO.ps1 in any accessible directory" -ForegroundColor Red
        Write-Host " Please ensure the ArcEnabledServersGroupPolicy archive was properly extracted" -ForegroundColor Yellow
        throw "DeployGPO.ps1 script not found or not accessible"
    }

    # Get GPO count before deployment to identify the new GPO
    $gpoCountBefore = (Get-GPO -All -Domain $DomainFQDN).Count
    Write-Host "Current GPO count: $gpoCountBefore" -ForegroundColor Gray

    try {
        .\DeployGPO.ps1 -DomainFQDN $DomainFQDN `
            -ReportServerFQDN $ReportServerFQDN `
            -ArcRemoteShare $RemoteShare `
            -ServicePrincipalSecret $Secret `
            -ServicePrincipalClientId $AppId `
            -SubscriptionId $subId `
            -ResourceGroup $resourceGroup `
            -Location $location `
            -TenantId $TenantId *>&1 | Out-Null

        Write-Host " Group Policy deployment completed" -ForegroundColor Green
    }
    catch {
        Write-Host " Failed to deploy Group Policy: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }

    # Identify the newly created GPO
    Write-Host "Identifying the newly created Azure Arc GPO..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2  # Give time for GPO creation to complete

    $gpoCountAfter = (Get-GPO -All -Domain $DomainFQDN).Count
    Write-Host "GPO count after deployment: $gpoCountAfter" -ForegroundColor Gray

    # Try multiple methods to find the correct GPO
    $GPOName = $null

    # Method 1: Look for newly created GPO if count increased
    if ($gpoCountAfter -gt $gpoCountBefore) {
        $allGPOs = Get-GPO -All -Domain $DomainFQDN | Sort-Object CreationTime -Descending
        $newestGPO = $allGPOs | Where-Object { $_.DisplayName -like "*Azure*" -or $_.DisplayName -like "*Arc*" -or $_.DisplayName -like "*MSFT*" } | Select-Object -First 1
        if ($newestGPO) {
            $GPOName = $newestGPO.DisplayName
            Write-Host " Found newly created GPO: $GPOName" -ForegroundColor Green
        }
    }

    # Method 2: Fallback to specific Azure Arc related patterns
    if (-not $GPOName) {
        Write-Host "  Attempting to find GPO using pattern matching..." -ForegroundColor Yellow
        $arcGPOs = Get-GPO -All -Domain $DomainFQDN | Where-Object {
            $_.DisplayName -like "*Azure Arc*" -or
            $_.DisplayName -like "*ArcEnabled*" -or
            $_.DisplayName -like "*ConnectedMachine*"
        }
        if ($arcGPOs) {
            if ($arcGPOs -is [array]) {
                $GPOName = ($arcGPOs | Sort-Object CreationTime -Descending | Select-Object -First 1).DisplayName
            } else {
                $GPOName = $arcGPOs.DisplayName
            }
            Write-Host " Found Azure Arc GPO: $GPOName" -ForegroundColor Green
        }
    }

    # Method 3: Final fallback to MSFT pattern (original method)
    if (-not $GPOName) {
        Write-Host "  Using fallback pattern matching for MSFT..." -ForegroundColor Yellow
        $msftGPO = Get-GPO -All -Domain $DomainFQDN | Where-Object { $_.DisplayName -Like "*MSFT*" } | Sort-Object CreationTime -Descending | Select-Object -First 1
        if ($msftGPO) {
            $GPOName = $msftGPO.DisplayName
            Write-Host "  Found MSFT GPO: $GPOName" -ForegroundColor Yellow
            Write-Host " Note: This may not be the correct Azure Arc GPO if multiple MSFT GPOs exist" -ForegroundColor Yellow
        }
    }

    # Validate we found a GPO
    if (-not $GPOName) {
        Write-Host " Could not identify the Azure Arc GPO. Please check the DeployGPO.ps1 output." -ForegroundColor Red
        Write-Host " Available GPOs in domain:" -ForegroundColor Yellow
        Get-GPO -All -Domain $DomainFQDN | Sort-Object DisplayName | ForEach-Object {
            Write-Host "   $($_.DisplayName)" -ForegroundColor Gray
        }
        return
    }

    Write-Host " Using GPO for OU linking: $GPOName" -ForegroundColor Cyan

    # Prompt user for OU configuration
    Write-Host "`n Organizational Units Configuration" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan
    Write-Host " You can create a file containing the list of Organizational Units (OUs)" -ForegroundColor Yellow
    Write-Host " for future GPO linking. This file will be stored in the working folder." -ForegroundColor Yellow

    # Use the standardized OU file from environment initialization
    $ouFileFullPath = $orgUnitsFile
    $ouFileName = [System.IO.Path]::GetFileName($ouFileFullPath)

    Write-Host "`nChoose OU configuration method:" -ForegroundColor Yellow
    Write-Host " 1. Create/edit OU file: $ouFileName" -ForegroundColor Gray
    Write-Host " 2. Skip OU file creation (link GPO manually later)" -ForegroundColor Gray

    if (-not $Force) {
        $defaultChoice = "1"
        $configChoice = Read-Host "Select option [1/2] (default: 1)"

        # Use default if user pressed Enter without input
        if ([string]::IsNullOrWhiteSpace($configChoice)) {
            $configChoice = $defaultChoice
            Write-Host " Using default choice: Create/edit OU file" -ForegroundColor Green
        }
    } else {
        $configChoice = "1"
    }

    $createOUFile = $true

    switch ($configChoice) {
        "2" {
            $createOUFile = $false
            Write-Host " Skipping OU file creation. You can link the GPO manually later." -ForegroundColor Yellow
            "OU file creation skipped by user choice" | Out-File -FilePath $logFile -Append
        }
        default {
            Write-Host " Using default OU file: $defaultOUFile" -ForegroundColor Green
        }
    }

    if ($createOUFile) {
        # Get domain information for better examples
        try {
            $domainInfo = Get-ADDomain
            $domainDN = $domainInfo.DistinguishedName
            $domainNetBIOS = $domainInfo.NetBIOSName
            Write-Host " Domain: $($domainInfo.DNSRoot) ($domainNetBIOS)" -ForegroundColor Gray
        }
        catch {
            Write-Host " Could not retrieve domain information" -ForegroundColor Yellow
            $domainDN = "DC=domain,DC=com"
        }

        # Check if file already exists
        if (Test-Path $ouFileFullPath) {
            Write-Host " OU file '$(Split-Path $ouFileFullPath -Leaf)' already exists." -ForegroundColor Green
            Write-Host "  File location: $ouFileFullPath" -ForegroundColor Gray

            if (-not $Force) {
                $editChoice = Read-Host "Do you want to (E)dit the existing file or (C)reate a new one? [E/C] (default: E)"
                if ([string]::IsNullOrWhiteSpace($editChoice)) {
                    $editChoice = "E"
                }

                if ($editChoice.ToUpper() -eq "C") {
                    Write-Host " Creating new OU file (overwriting existing)..." -ForegroundColor Yellow
                    $createNewFile = $true
                } else {
                    Write-Host " Will edit existing file" -ForegroundColor Green
                    $createNewFile = $false
                }
            } else {
                $createNewFile = $false
            }
        } else {
            Write-Host " OU file '$(Split-Path $ouFileFullPath -Leaf)' does not exist." -ForegroundColor Yellow
            Write-Host " Creating new OU file..." -ForegroundColor Yellow
            $createNewFile = $true
        }

        # Create new file if needed
        if ($createNewFile) {
            # Get available OUs for better examples
            try {
                $availableOUs = Get-ADOrganizationalUnit -Filter * | Select-Object -First 10 Name | Sort-Object Name
                $ouExamples = @()
                if ($availableOUs.Count -gt 0) {
                    $ouExamples = $availableOUs | Select-Object -First 5 | ForEach-Object { "#   $($_.Name)" }
                } else {
                    $ouExamples = @("#   Servers", "#   Workstations", "#   Production")
                }
            }
            catch {
                $ouExamples = @("#   Servers", "#   Workstations", "#   Production")
            }

            # Create comprehensive OU file template
            $ouFileContent = @(
                "# Azure Arc Organizational Units Configuration",
                "# Add one OU name per line (simple names, not full distinguished names)",
                "# Lines starting with # are comments and will be ignored",
                "# ",
                "# INSTRUCTIONS:",
                "# 1. Add the names of OUs where you want to apply the Azure Arc GPO",
                "# 2. Use simple OU names (e.g., 'Servers', 'Workstations')",
                "# 3. Use special keyword 'DOMAIN' to apply to the entire domain",
                "# 4. Save this file and close Notepad to continue",
                "# ",
                "# IMPORTANT: GPOs can only be linked to Organizational Units (OUs) and domains,",
                "# NOT to built-in containers like Computers, Users, etc.",
                "# ",
                "# Available OUs in your domain:"
            ) + $ouExamples + @(
                "# ",
                "# Examples of VALID entries:",
                "#   DOMAIN",
                "#   Servers",
                "#   Workstations",
                "#   Production Servers",
                "# ",
                "# Examples of INVALID entries (containers - will be ignored):",
                "#   Computers",
                "#   Users",
                "#   Builtin",
                "# ",
                "# Default example (remove # to use):",
                "# DOMAIN",
                "",
                "# Add your OU names below (one per line):",
                ""
            )

            $ouFileContent | Out-File -FilePath $ouFileFullPath -Encoding UTF8

            # Validate the file was created successfully
            $ouFileValidation = Test-ValidPath -Path $ouFileFullPath -PathType File -RequireExists
            if (-not $ouFileValidation.IsValid) {
                Write-Host " Failed to create OU file: $($ouFileValidation.Error)" -ForegroundColor Red
                throw "Failed to create OU configuration file"
            }

            Write-Host " Created OU file template: $(Split-Path $ouFileFullPath -Leaf)" -ForegroundColor Green
        }

        # Always open file for editing (mandatory user interaction)
        Write-Host "`n Opening OU file for editing..." -ForegroundColor Cyan
        Write-Host " File location: $ouFileFullPath" -ForegroundColor Gray
        Write-Host "" -ForegroundColor Yellow
        Write-Host " INSTRUCTIONS:" -ForegroundColor Yellow
        Write-Host "  1. Add the names of OUs where you want to link the Azure Arc GPO" -ForegroundColor White
        Write-Host "  2. Use simple OU names (e.g., 'Servers', 'Workstations')" -ForegroundColor White
        Write-Host "  3. Use 'DOMAIN' to apply to the entire domain" -ForegroundColor White
        Write-Host "  4. Save the file and close Notepad to continue" -ForegroundColor White
        Write-Host "" -ForegroundColor Yellow

        try {
            Write-Host " Opening Notepad..." -ForegroundColor Yellow
            Start-Process notepad.exe -ArgumentList $ouFileFullPath -Wait
            Write-Host " Notepad closed. Continuing with deployment..." -ForegroundColor Green
        }
        catch {
            Write-Host " Could not open Notepad automatically." -ForegroundColor Red
            Write-Host " Please edit the file manually: $ouFileFullPath" -ForegroundColor Yellow
            if (-not $Force) {
                Read-Host "Press Enter when you have finished editing the file"
            }
        }

        # Verify file exists and validate accessibility
        $ouFileValidation = Test-ValidPath -Path $ouFileFullPath -PathType File -RequireExists
        if ($ouFileValidation.IsValid) {
            Write-Host " OU file ready: $(Split-Path $ouFileFullPath -Leaf)" -ForegroundColor Green

            # Show file contents for confirmation and prepare for linking
            try {
                $ouNames = Get-Content $ouFileFullPath -ErrorAction Stop | Where-Object {
                    $_.Trim() -ne "" -and -not $_.Trim().StartsWith("#")
                } | ForEach-Object {
                    # Remove quotes and trim all whitespace (including spaces, tabs, etc.)
                    $cleaned = Remove-PathQuote -Path $_.Trim()
                    $cleaned.Trim()
                } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

                if ($ouNames.Count -gt 0) {
                    Write-Host " OU file contains $($ouNames.Count) target(s):" -ForegroundColor Gray
                    $ouNames | ForEach-Object { Write-Host "   '$_'" -ForegroundColor Gray }

                    # Ask user if they want to link the GPO now
                    if (-not $Force) {
                        $linkChoice = Read-Host "`nDo you want to link the GPO '$GPOName' to these OUs now? [Y/N] (default: Y)"
                        if ([string]::IsNullOrWhiteSpace($linkChoice)) {
                            $linkChoice = "Y"
                        }
                    } else {
                        $linkChoice = "Y"
                    }

                    if ($linkChoice.ToUpper() -eq "Y") {
                        Write-Host "`n Linking GPO to Organizational Units" -ForegroundColor Cyan
                        Write-Host "" -ForegroundColor Cyan

                        # Get domain information for better OU resolution
                        try {
                            $domainInfo = Get-ADDomain
                            $domainDN = $domainInfo.DistinguishedName
                            Write-Host " Domain DN: $domainDN" -ForegroundColor Gray
                        }
                        catch {
                            Write-Host " Could not retrieve domain information" -ForegroundColor Red
                            $domainDN = $null
                        }

                        $validTargets = @()
                        $skippedTargets = @()

                        foreach ($ouName in $ouNames) {
                            # Ensure no leading/trailing spaces
                            $cleanOUName = $ouName.Trim()
                            Write-Host " Processing OU: '$cleanOUName'" -ForegroundColor Yellow

                            try {
                                # Handle special keyword 'DOMAIN' for domain root
                                if ($cleanOUName.ToUpper() -eq "DOMAIN") {
                                    if ($domainDN) {
                                        $validTargets += $domainDN
                                        Write-Host "   Resolved to domain root: $domainDN" -ForegroundColor Green
                                    } else {
                                        Write-Host "   ERROR: Could not determine domain DN" -ForegroundColor Red
                                        $skippedTargets += @{Name = $cleanOUName; Reason = "Could not determine domain DN"}
                                    }
                                }
                                # Skip known container names that can't have GPOs linked
                                elseif (@("Computers", "Users", "Builtin") -contains $cleanOUName) {
                                    Write-Host "   SKIPPED: '$cleanOUName' is a container, not an OU" -ForegroundColor Red
                                    Write-Host "   REASON: GPOs cannot be linked to built-in containers" -ForegroundColor Yellow
                                    $skippedTargets += @{Name = $cleanOUName; Reason = "Built-in container - GPOs cannot be linked to containers"}
                                }
                                # Look up actual OU by name
                                else {
                                    Write-Host "   Searching for OU name: '$cleanOUName'" -ForegroundColor Gray

                                    # Search for OU by name across the entire domain
                                    $ou = Get-ADOrganizationalUnit -Filter "Name -eq '$cleanOUName'" -ErrorAction SilentlyContinue
                                    if ($ou) {
                                        if ($ou -is [array]) {
                                            # Multiple OUs with same name found
                                            Write-Host "   WARNING: Multiple OUs found with name '$cleanOUName':" -ForegroundColor Yellow
                                            $ou | ForEach-Object { Write-Host "      - $($_.DistinguishedName)" -ForegroundColor Gray }
                                            $selectedOU = $ou[0].DistinguishedName  # Use first one
                                            Write-Host "   Using first match: $selectedOU" -ForegroundColor Green
                                            $validTargets += $selectedOU
                                        } else {
                                            Write-Host "   Found OU: $($ou.DistinguishedName)" -ForegroundColor Green
                                            $validTargets += $ou.DistinguishedName
                                        }
                                    } else {
                                        Write-Host "   ERROR: OU '$cleanOUName' not found in domain" -ForegroundColor Red
                                        $skippedTargets += @{Name = $cleanOUName; Reason = "OU not found in domain"}

                                        # Show available OUs as suggestion
                                        try {
                                            $availableOUs = Get-ADOrganizationalUnit -Filter * | Select-Object -First 10 Name | Sort-Object Name
                                            if ($availableOUs.Count -gt 0) {
                                                Write-Host "   Available OUs (first 10):" -ForegroundColor Gray
                                                $availableOUs | ForEach-Object { Write-Host "      $($_.Name)" -ForegroundColor Gray }
                                            }
                                        }
                                        catch {
                                            Write-Host "   Could not retrieve available OUs" -ForegroundColor Gray
                                        }
                                    }
                                }
                            }
                            catch {
                                Write-Host "   ERROR: Failed to process OU '$cleanOUName': $($_.Exception.Message)" -ForegroundColor Red
                                $skippedTargets += @{Name = $cleanOUName; Reason = "Processing error: $($_.Exception.Message)"}
                            }
                        }

                        # Show summary of targets
                        if ($validTargets.Count -gt 0) {
                            Write-Host "`n Valid targets for GPO linking ($($validTargets.Count)):" -ForegroundColor Green
                            $validTargets | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
                        }

                        if ($skippedTargets.Count -gt 0) {
                            Write-Host "`n Skipped targets ($($skippedTargets.Count)):" -ForegroundColor Yellow
                            $skippedTargets | ForEach-Object {
                                Write-Host "   $($_.Name): $($_.Reason)" -ForegroundColor Red
                            }
                        }

                        # Proceed with linking if we have valid targets
                        if ($validTargets.Count -gt 0) {
                            Write-Host "`n Proceeding with GPO linking..." -ForegroundColor Cyan
                            $successCount = 0
                            $failureCount = 0

                            foreach ($target in $validTargets) {
                                try {
                                    Write-Host " Linking GPO '$GPOName' to: $target" -ForegroundColor Yellow
                                    New-GPLink -Name $GPOName -Target $target -ErrorAction Stop | Out-Null
                                    Write-Host "   SUCCESS: GPO linked successfully" -ForegroundColor Green
                                    $successCount++
                                }
                                catch {
                                    if ($_.Exception.Message -match "already linked") {
                                        Write-Host "   INFO: GPO already linked to this target" -ForegroundColor Yellow
                                        $successCount++  # Count as success since it's already linked
                                    } else {
                                        Write-Host "   ERROR: Failed to link GPO" -ForegroundColor Red
                                        Write-Host "   REASON: $($_.Exception.Message)" -ForegroundColor Red
                                        $failureCount++
                                    }
                                }
                            }

                            # Show final linking summary
                            Write-Host "`n GPO Linking Summary:" -ForegroundColor Cyan
                            Write-Host "   Successful links: $successCount" -ForegroundColor Green
                            Write-Host "   Failed links: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { "Red" } else { "Gray" })
                            Write-Host "   Skipped targets: $($skippedTargets.Count)" -ForegroundColor $(if ($skippedTargets.Count -gt 0) { "Yellow" } else { "Gray" })

                        } else {
                            Write-Host "`n No valid targets found for GPO linking." -ForegroundColor Red
                            Write-Host " Please review the OU names in the file and ensure they exist in your domain." -ForegroundColor Yellow
                        }
                    } else {
                        Write-Host " GPO linking skipped by user choice." -ForegroundColor Yellow
                    }
                } else {
                    Write-Host " OU file is empty (no targets specified)" -ForegroundColor Yellow
                    Write-Host " You can manually link the GPO '$GPOName' later using Group Policy Management Console" -ForegroundColor Gray
                }
            }
            catch {
                Write-Host " Could not read OU file contents: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host " File may be corrupted or inaccessible" -ForegroundColor Yellow
            }
        } else {
            Write-Host " Error accessing OU file: $($ouFileValidation.Error)" -ForegroundColor Red
            Write-Host " OU file validation failed - GPO linking cannot proceed automatically" -ForegroundColor Yellow
            Write-Host " You can manually link the GPO '$GPOName' later using Group Policy Management Console" -ForegroundColor Gray
        }
    }


    Write-Host "`n Azure Arc deployment completed successfully!" -ForegroundColor Green
    Write-Host " Service principal details saved to: $($ArcServerOnboardingDetail.FullName)" -ForegroundColor Gray
    Write-Host "  Note: Service principal secret was not saved to file for security reasons." -ForegroundColor Yellow
    Write-Host " Remote share created: \\$env:COMPUTERNAME\$RemoteShare" -ForegroundColor Gray
    Write-Host " GPO '$GPOName' created and ready" -ForegroundColor Gray

    if ($createOUFile -and (Test-Path $ouFileFullPath)) {
        Write-Host " OU configuration file: $(Split-Path $ouFileFullPath -Leaf)" -ForegroundColor Gray
        Write-Host "  File location: $ouFileFullPath" -ForegroundColor Gray
    }

    Write-Host
    Write-Host " Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Verify GPO settings and linking in Group Policy Management Console" -ForegroundColor White
    if ($createOUFile) {
        Write-Host "     - Check if GPO '$GPOName' is properly linked to your desired OUs" -ForegroundColor White
    }
    Write-Host "  2. Run 'gpupdate /force' on target devices or wait for automatic refresh" -ForegroundColor White
    Write-Host "  3. Monitor Azure Arc onboarding in Azure portal" -ForegroundColor White
    Write-Host "  4. Check device compliance in Microsoft Defender for Cloud" -ForegroundColor White
    Write-Host
}



