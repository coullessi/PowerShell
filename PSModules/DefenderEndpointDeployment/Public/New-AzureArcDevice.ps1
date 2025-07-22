function New-AzureArcDevice {
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

    .PARAMETER ResourceGroupName
        Optional name for the Azure resource group. If not provided, user will be prompted.

    .PARAMETER Location
        Optional Azure region for resource deployment. If not provided, user will be prompted.

    .PARAMETER SharePath
        Optional path for the remote share used for Group Policy deployment. If not provided, user will be prompted.

    .PARAMETER Force
        Skip confirmation prompts and proceed with default values where applicable.

    .EXAMPLE
        New-AzureArcDevice
        
        Interactively creates Azure Arc device configuration with user prompts for all parameters.

    .EXAMPLE
        New-AzureArcDevice -ResourceGroupName "rg-azurearc-prod" -Location "eastus" -Force
        
        Creates Azure Arc configuration with specified parameters and minimal prompting.

    .NOTES
        Author: Lessi Coulibaly
        Organization: Less-IT (AI and CyberSecurity)
        Website: https://lessit.net
        
        Prerequisites:
        - Azure PowerShell modules (Az.Accounts, Az.Resources)
        - Valid Azure subscription with appropriate permissions
        - Active Directory environment with Group Policy management capabilities
        - Network access to Azure endpoints
        - Run Test-AzureArcPrerequisites first to ensure all requirements are met
    #>

    [CmdletBinding()]
    param(
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
        $SharePath = Remove-PathQuotes -Path $SharePath
    }

    Clear-Host

    Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ ======================== AZURE ARC DEVICE DEPLOYMENT ========================  ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # User Consent and Confirmation
    if (-not $Force) {
        Write-Host "🔍 SCRIPT OVERVIEW:" -ForegroundColor Yellow
        Write-Host "   This script automates the complete Azure Arc device deployment process" -ForegroundColor White
        Write-Host "   using Group Policy for enterprise-scale onboarding." -ForegroundColor White
        Write-Host ""
        Write-Host "📋 ACTIONS TO BE PERFORMED:" -ForegroundColor Yellow
        Write-Host "   • Create or validate Azure resource groups and deployment parameters" -ForegroundColor White
        Write-Host "   • Download Azure Connected Machine Agent and Group Policy templates" -ForegroundColor White
        Write-Host "   • Create service principals with appropriate Azure Arc permissions" -ForegroundColor White
        Write-Host "   • Configure remote file shares for Group Policy deployment" -ForegroundColor White
        Write-Host "   • Create and deploy Group Policy objects to specified organizational units" -ForegroundColor White
        Write-Host "   • Generate PowerShell scripts for automated Azure Arc agent installation" -ForegroundColor White
        Write-Host "   • Link Group Policy objects to target organizational units" -ForegroundColor White
        Write-Host ""
        Write-Host "⚠️  IMPORTANT CONSIDERATIONS:" -ForegroundColor Red
        Write-Host "   • This script will make changes to your Azure environment" -ForegroundColor White
        Write-Host "   • Service principals will be created with Azure Arc deployment permissions" -ForegroundColor White
        Write-Host "   • Group Policy objects will be created and linked to specified OUs" -ForegroundColor White
        Write-Host "   • Files will be downloaded and deployed to shared network locations" -ForegroundColor White
        Write-Host "   • Azure Arc agents will be deployed to devices in the targeted OUs" -ForegroundColor White
        Write-Host "   • Internet connectivity is required for downloading components" -ForegroundColor White
        Write-Host "   • Administrative privileges are required for Group Policy operations" -ForegroundColor White
        Write-Host ""
        Write-Host "🛡️  SECURITY & COMPLIANCE:" -ForegroundColor Green
        Write-Host "   • Service principals are created with minimal required permissions" -ForegroundColor White
        Write-Host "   • All Azure operations use official Microsoft Azure PowerShell modules" -ForegroundColor White
        Write-Host "   • Group Policy deployment follows Microsoft recommended practices" -ForegroundColor White
        Write-Host "   • No sensitive data is stored in plain text" -ForegroundColor White
        Write-Host ""
        Write-Host "📊 PREREQUISITES:" -ForegroundColor Magenta
        Write-Host "   • Azure PowerShell modules (Az.Accounts, Az.Resources) must be installed" -ForegroundColor White
        Write-Host "   • Valid Azure subscription with appropriate permissions" -ForegroundColor White
        Write-Host "   • Active Directory environment with Group Policy management capabilities" -ForegroundColor White
        Write-Host "   • Network access to Azure endpoints and target devices" -ForegroundColor White
        Write-Host "   • Administrative privileges on the local machine" -ForegroundColor White
        Write-Host ""
        Write-Host "⚖️  DISCLAIMER & LIABILITY:" -ForegroundColor Magenta
        Write-Host "   • This script is provided 'AS IS' without warranty of any kind" -ForegroundColor White
        Write-Host "   • The author is not liable for any damages, data loss, or other" -ForegroundColor White
        Write-Host "     consequences that may result from running this script" -ForegroundColor White
        Write-Host "   • You assume full responsibility for testing and validating" -ForegroundColor White
        Write-Host "     this script in your environment before production use" -ForegroundColor White
        Write-Host ""
        Write-Host "═════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

        do {
            $consent = Read-Host "Do you consent to proceed with Azure Arc device deployment? [Y/N] (default: Y)"

            # Use default if user pressed Enter without input
            if ([string]::IsNullOrWhiteSpace($consent)) {
                $consent = 'Y'
                Write-Host "✅ Using default choice: Yes" -ForegroundColor Yellow
            }

            switch ($consent.ToUpper()) {
                'Y' { 
                    Write-Host "✅ Proceeding with Azure Arc device deployment..." -ForegroundColor Green
                    break 
                }
                'N' { 
                    Write-Host "`n❌ Script execution cancelled by user." -ForegroundColor Red
                    Write-Host "No actions have been performed. Exiting...`n" -ForegroundColor Gray
                    return
                }
                default { 
                    Write-Host "Please enter 'Y' to proceed or 'N' to cancel." -ForegroundColor Yellow 
                }
            }
        } while ($consent.ToUpper() -ne 'Y' -and $consent.ToUpper() -ne 'N')
        
        Write-Host ""
        Write-Host "🚀 Initializing Azure Arc Device Deployment..." -ForegroundColor Cyan
        Write-Host ""
    }

    # Prerequisites validation should be completed before running this script
    # Run Test-AzureArcPrerequisites.ps1 first to ensure all requirements are met
    
    # Verify Azure context is available (from prerequisites script)
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Host "❌ No Azure context found. Attempting to authenticate..." -ForegroundColor Red
            
            # Try to authenticate
            $authSuccess = Confirm-AzureAuthentication
            if (-not $authSuccess) {
                Write-Host "❌ Azure authentication failed. Please run Test-AzureArcPrerequisites first." -ForegroundColor Red
                return
            }
            
            # Get context again after authentication
            $context = Get-AzContext
        }
        
        Write-Host "✅ Using Azure context: $($context.Account.Id)" -ForegroundColor Green
        $subId = $context.Subscription.Id
        $TenantId = $context.Tenant.Id
    }
    catch {
        Write-Host "❌ Azure PowerShell context not available. Please run Test-AzureArcPrerequisites first." -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    # 1. Get resource group and location information
    Write-Host "`n📋 Azure Resource Configuration" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    
    # Prompt for resource group
    if ([string]::IsNullOrWhiteSpace($ResourceGroupName)) {
        $defaultResourceGroup = "rg-azurearc-$(Get-Date -Format 'yyyyMMdd')"
        $resourceGroup = Read-Host "`nProvide a resource group name for your Azure Arc deployment [default: $defaultResourceGroup]"
        
        # Use default if user pressed Enter without input
        if ([string]::IsNullOrWhiteSpace($resourceGroup)) {
            $resourceGroup = $defaultResourceGroup
            Write-Host "✅ Using default resource group: $resourceGroup" -ForegroundColor Green
        } else {
            Write-Host "✅ Resource group: $resourceGroup" -ForegroundColor Green
        }
    } else {
        $resourceGroup = $ResourceGroupName
        Write-Host "✅ Using provided resource group: $resourceGroup" -ForegroundColor Green
    }
    
    # Prompt for location
    if ([string]::IsNullOrWhiteSpace($Location)) {
        $defaultLocation = "eastus"
        $location = Read-Host "`nProvide an Azure region for your deployment [default: $defaultLocation] (e.g., westus2, westeurope)"
        
        # Use default if user pressed Enter without input
        if ([string]::IsNullOrWhiteSpace($location)) {
            $location = $defaultLocation
            Write-Host "✅ Using default location: $location" -ForegroundColor Green
        } else {
            $validLocations = @("eastus", "eastus2", "westus", "westus2", "westeurope", "northeurope", "southeastasia", "eastasia", "australiaeast", "uksouth", "canadacentral", "francecentral", "germanywestcentral", "japaneast", "koreacentral", "southafricanorth", "uaenorth", "brazilsouth", "southcentralus", "northcentralus", "centralus", "westcentralus", "westus3")
            
            while ($validLocations -notcontains $location.ToLower()) {
                Write-Host "❌ Invalid location: '$location'" -ForegroundColor Red
                Write-Host "💡 Common locations: eastus, westus2, westeurope, eastasia, australiaeast" -ForegroundColor Yellow
                $location = Read-Host "Provide a valid Azure region for your deployment [default: $defaultLocation]"
                
                # Use default if user pressed Enter without input
                if ([string]::IsNullOrWhiteSpace($location)) {
                    $location = $defaultLocation
                    break
                }
            }
            Write-Host "✅ Location: $location" -ForegroundColor Green
        }
    } else {
        $location = $Location
        Write-Host "✅ Using provided location: $location" -ForegroundColor Green
    }
    
    # 2. Create a resource group
    Write-Host "`n🏗️  Creating Azure Resource Group" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "Creating resource group '$resourceGroup' in '$location'..." -ForegroundColor Yellow
    try {
        New-AzResourceGroup -Name $resourceGroup -Location $location | Out-Null
        Write-Host "✅ Resource group created successfully!" -ForegroundColor Green
    }
    catch {
        if ($_.Exception.Message -match "already exists") {
            Write-Host "⚠️  Resource group already exists - continuing..." -ForegroundColor Yellow
        } else {
            Write-Host "❌ Failed to create resource group: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
    }

    # 3. Create a remote share
    Write-Host "`n📁 Remote Share Configuration" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    
    try {
        $DomainName = (Get-ADDomain).DNSRoot
    }
    catch {
        Write-Host "❌ Unable to retrieve Active Directory domain information. Ensure this is run on a domain-joined machine." -ForegroundColor Red
        throw
    }
    
    # Prompt user for remote share path
    if ([string]::IsNullOrWhiteSpace($SharePath)) {
        $defaultPath = "$env:HOMEDRIVE\AzureArc"
        Write-Host "`n💡 The remote share will store Azure Arc deployment files and scripts." -ForegroundColor Yellow
        $path = Read-Host "Provide the full or relative path for the Azure Arc remote share [default: $defaultPath]"
        
        # Remove quotes if user entered them
        $path = Remove-PathQuotes -Path $path
        
        # Use default if user pressed Enter without input
        if ([string]::IsNullOrWhiteSpace($path)) {
            $path = $defaultPath
            Write-Host "✅ Using default path: $path" -ForegroundColor Green
        } else {
            # Convert relative path to absolute if needed
            if (-not [System.IO.Path]::IsPathRooted($path)) {
                $path = Join-Path (Get-Location) $path
            }
            Write-Host "✅ Using specified path: $path" -ForegroundColor Green
        }
    } else {
        $path = $SharePath
        # Remove quotes if user entered them in parameter
        $path = Remove-PathQuotes -Path $path
        if (-not [System.IO.Path]::IsPathRooted($path)) {
            $path = Join-Path (Get-Location) $path
        }
        Write-Host "✅ Using provided path: $path" -ForegroundColor Green
    }
    
    # Extract share name from the last directory in the path
    $shareName = Split-Path -Leaf $path
    Write-Host "✅ Share name will be: $shareName" -ForegroundColor Green
    
    # Check if share name already exists and points to a different path
    $existingShare = Get-SmbShare | Where-Object { $_.Name -eq $shareName } -ErrorAction SilentlyContinue
    $useExistingShare = $false
    
    if ($existingShare -and $existingShare.Path -ne $path) {
        Write-Host "⚠️  Share '$shareName' already exists and points to: $($existingShare.Path)" -ForegroundColor Yellow
        Write-Host "🔄 You specified a different path: $path" -ForegroundColor Yellow
        
        # Create a unique share name by appending a timestamp
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $originalShareName = $shareName
        $shareName = "$originalShareName`_$timestamp"
        Write-Host "✅ Using unique share name: $shareName" -ForegroundColor Green
    } elseif ($existingShare -and $existingShare.Path -eq $path) {
        Write-Host "✅ Share '$shareName' already exists and points to the correct path" -ForegroundColor Green
        $useExistingShare = $true
    }
    
    # Create directory and share if needed
    Write-Host "`nCreating remote share..." -ForegroundColor Yellow
    
    If (!(Test-Path -PathType container $path)) {
        New-Item -Path $path -ItemType Directory | Out-Null
        Write-Host "✅ Directory created: $path" -ForegroundColor Green
    } else {
        Write-Host "✅ Directory already exists: $path" -ForegroundColor Green
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
            Write-Host "✅ SMB share '$shareName' created successfully!" -ForegroundColor Green
        }
        catch {
            if ($_.Exception.Message -match "already exists" -or $_.Exception.Message -match "already shared" -or $_.Exception.Message -match "name has already been shared") {
                Write-Host "⚠️  SMB share '$shareName' already exists" -ForegroundColor Yellow
            } else {
                Write-Host "❌ Failed to create SMB share: $($_.Exception.Message)" -ForegroundColor Red
                throw
            }
        }
    }
    
    # Set the remote share name for use in GPO deployment
    $RemoteShare = $shareName
    Write-Host "✅ Remote share '$RemoteShare' is ready for deployment" -ForegroundColor Green
    Write-Host "📁 All files will be stored in: $path" -ForegroundColor Gray

    # 4. Download and prepare Azure Arc Components (enhanced functionality)
    Write-Host "`n📥 Downloading Azure Arc Components" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    
    # Download Azure Connected Machine Agent with enhanced error handling
    Write-Host "📦 Downloading Azure Connected Machine Agent..." -ForegroundColor Yellow
    $agentPath = "$path\AzureConnectedMachineAgent.msi"
    
    try {
        # Check if agent already exists
        if (Test-Path $agentPath) {
            Write-Host "⚠️  Agent installer already exists. Checking if update is needed..." -ForegroundColor Yellow
            $overwrite = Read-Host "Do you want to download a fresh copy? [Y/N] (default: N)"
            if ($overwrite.ToUpper() -eq 'Y') {
                Remove-Item $agentPath -Force
                Write-Host "🗑️  Existing installer removed" -ForegroundColor Gray
            } else {
                Write-Host "✅ Using existing Azure Connected Machine Agent installer" -ForegroundColor Green
            }
        }
        
        if (-not (Test-Path $agentPath)) {
            $downloadUrl = "https://aka.ms/AzureConnectedMachineAgent"
            Write-Host "🌐 Downloading from: $downloadUrl" -ForegroundColor Gray
            
            # Download with progress indication
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($downloadUrl, $agentPath)
            $webClient.Dispose()
            
            # Verify download
            if (Test-Path $agentPath) {
                $fileSize = (Get-Item $agentPath).Length / 1MB
                Write-Host "✅ Azure Connected Machine Agent downloaded successfully" -ForegroundColor Green
                Write-Host "📊 File size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Gray
            } else {
                throw "Download completed but file not found"
            }
        }
        
        # Optional: Install agent locally for testing
        $installLocally = Read-Host "`n🔧 Would you like to install the Azure Connected Machine Agent on this machine for testing? [Y/N] (default: N)"
        if ($installLocally.ToUpper() -eq 'Y') {
            Write-Host "🔧 Installing Azure Connected Machine Agent locally..." -ForegroundColor Yellow
            
            try {
                # Check if already installed
                $existingAgent = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*Azure Connected Machine Agent*" }
                
                if ($existingAgent -and -not $Force) {
                    Write-Host "✅ Azure Connected Machine Agent is already installed locally" -ForegroundColor Green
                } else {
                    if ($existingAgent) {
                        Write-Host "⚠️  Agent already installed, but Force parameter specified. Reinstalling..." -ForegroundColor Yellow
                    }
                    
                    $installArgs = @("/i", $agentPath, "/quiet", "/norestart")
                    $installProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
                    
                    if ($installProcess.ExitCode -eq 0) {
                        Write-Host "✅ Azure Connected Machine Agent installed successfully on local machine" -ForegroundColor Green
                        Write-Host "💡 Agent is installed but not connected. Use Group Policy or manual connection for onboarding." -ForegroundColor Yellow
                    } else {
                        Write-Host "⚠️  Agent installation completed with exit code: $($installProcess.ExitCode)" -ForegroundColor Yellow
                        Write-Host "💡 This may indicate a reboot is required or agent was already installed" -ForegroundColor Gray
                    }
                }
            }
            catch {
                Write-Host "❌ Failed to install agent locally: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "💡 Agent file is still available for Group Policy deployment" -ForegroundColor Yellow
            }
        } else {
            Write-Host "⏭️  Skipping local installation. Agent available for Group Policy deployment." -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "❌ Failed to download Azure Connected Machine Agent: $($_.Exception.Message)" -ForegroundColor Red
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
        
        Write-Host "✅ Latest version found: $latestVersion" -ForegroundColor Green
        Write-Host "📦 File: $fileName" -ForegroundColor Gray
        
        # Download the latest version
        Write-Host "Downloading $fileName..." -ForegroundColor Yellow
        $localFilePath = "$path\$fileName"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $localFilePath
        Write-Host "✅ ArcEnabledServersGroupPolicy downloaded successfully" -ForegroundColor Green
        
        # Extract the archive
        Write-Host "Extracting $fileName..." -ForegroundColor Yellow
        
        # Remove file extension to get folder name
        $extractFolderName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
        $extractPath = "$path\$extractFolderName"
        
        # Remove existing extraction folder if it exists
        if (Test-Path $extractPath) {
            Remove-Item $extractPath -Recurse -Force
            Write-Host "🗑️  Removed existing extraction folder" -ForegroundColor Gray
        }
        
        Expand-Archive -LiteralPath $localFilePath -DestinationPath $path -Force
        Write-Host "✅ Archive extracted successfully" -ForegroundColor Green
        
        # Set location to the extracted folder
        Set-Location -Path $extractPath
        Write-Host "📂 Working directory set to: $extractPath" -ForegroundColor Gray
        
    }
    catch {
        Write-Host "❌ Failed to download latest ArcEnabledServersGroupPolicy: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "⚠️  Falling back to hardcoded version 1.0.5..." -ForegroundColor Yellow
        
        try {
            # Fallback to hardcoded version
            $fallbackUrl = "https://github.com/Azure/ArcEnabledServersGroupPolicy/releases/download/1.0.5/ArcEnabledServersGroupPolicy_v1.0.10.zip"
            $fallbackFile = "$path\ArcEnabledServersGroupPolicy_v1.0.10.zip"
            
            Invoke-WebRequest -Uri $fallbackUrl -OutFile $fallbackFile
            Write-Host "✅ Fallback version downloaded successfully" -ForegroundColor Green
            
            Expand-Archive -LiteralPath $fallbackFile -DestinationPath $path -Force
            Set-Location -Path "$path\ArcEnabledServersGroupPolicy_v1.0.10"
            Write-Host "✅ Fallback archive extracted successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Fallback download also failed: $($_.Exception.Message)" -ForegroundColor Red
            throw "Failed to download ArcEnabledServersGroupPolicy from both latest and fallback sources"
        }
    }

    # 5. Create a service principal for the Azure Connected Machine Agent (enhanced functionality)
    Write-Host "`n🔐 Creating Service Principal" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "Creating Azure Arc service principal for onboarding..." -ForegroundColor Yellow
    
    $date = Get-Date
    $ArcServerOnboardingDetail = New-Item -ItemType File -Path "$path\ArcServerOnboarding.txt"
    "------------------------------------------------------------------------------" | Out-File -FilePath $ArcServerOnboardingDetail -Append
    "`nService principal creation date: $date`nSecret expiration date: $($date.AddDays(30))" | Out-File -FilePath $ArcServerOnboardingDetail -Append
    
    try {
        # Enhanced service principal creation with better configuration
        $displayName = "Azure Arc Deployment Account - DefenderEndpointDeployment"
        $expirationDate = $date.AddDays(30)  # Longer expiration period
        $scope = "/subscriptions/$subId/resourceGroups/$resourceGroup"
        
        Write-Host "📋 Service Principal Configuration:" -ForegroundColor Yellow
        Write-Host "  Display Name: $displayName" -ForegroundColor Gray
        Write-Host "  Scope: $scope" -ForegroundColor Gray
        Write-Host "  Expiration: $($expirationDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray

        # Create the service principal with enhanced error handling
        $ServicePrincipal = New-AzADServicePrincipal -DisplayName $displayName -Role "Azure Connected Machine Onboarding" -Scope $scope -EndDate $expirationDate
        
        if ($ServicePrincipal) {
            Write-Host "✅ Service principal created successfully!" -ForegroundColor Green
            
            # Save detailed service principal information
            $spDetails = @"
Service Principal Details:
Application ID: $($ServicePrincipal.AppId)
Object ID: $($ServicePrincipal.Id)
Display Name: $($ServicePrincipal.DisplayName)
Tenant ID: $TenantId
Subscription ID: $subId
Resource Group: $resourceGroup
Scope: $scope
Creation Date: $($date.ToString('yyyy-MM-dd HH:mm:ss'))
Expiration Date: $($expirationDate.ToString('yyyy-MM-dd HH:mm:ss'))
"@
            $spDetails | Out-File -FilePath $ArcServerOnboardingDetail -Append
            
            $AppId = $ServicePrincipal.AppId
            $Secret = $ServicePrincipal.PasswordCredentials.SecretText
            
            Write-Host "✅ Service principal details saved to: $($ArcServerOnboardingDetail.FullName)" -ForegroundColor Green
            Write-Host "🔑 Application ID: $AppId" -ForegroundColor Gray
            Write-Host "⚠️  Secret: [HIDDEN FOR SECURITY - Use from memory during deployment]" -ForegroundColor Yellow
            Write-Host "⏰ Secret expires: $($expirationDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
            
            Write-Host "`n⚠️  IMPORTANT SECURITY NOTES:" -ForegroundColor Red
            Write-Host "  • Store the client secret securely - it cannot be retrieved again" -ForegroundColor Yellow
            Write-Host "  • The secret expires on $($expirationDate.ToString('yyyy-MM-dd'))" -ForegroundColor Yellow
            Write-Host "  • Limit access to these credentials to authorized personnel only" -ForegroundColor Yellow
        } else {
            Write-Host "❌ Failed to create service principal" -ForegroundColor Red
            throw "Service principal creation failed"
        }
    }
    catch {
        Write-Host "❌ Failed to create service principal: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }

    # 6. Deploy the group policy object and link it to the selected organizational units
    try {
        $DC = Get-ADDomainController
        $DomainFQDN = $DC.Domain
        $ReportServerFQDN = $DC.HostName
    }
    catch {
        Write-Host "❌ Unable to retrieve Active Directory domain controller information." -ForegroundColor Red
        throw
    }

    Write-Host "`n🔧 Deploying Group Policy Object" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    
    # Check if DeployGPO.ps1 exists
    if (-not (Test-Path ".\DeployGPO.ps1")) {
        Write-Host "❌ DeployGPO.ps1 not found in current directory: $(Get-Location)" -ForegroundColor Red
        Write-Host "💡 Expected to find it in the extracted ArcEnabledServersGroupPolicy folder" -ForegroundColor Yellow
        
        # Try to find it in the path
        $deployGPOPath = Get-ChildItem -Path $path -Recurse -Name "DeployGPO.ps1" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($deployGPOPath) {
            $fullDeployGPOPath = Join-Path $path $deployGPOPath
            Write-Host "✅ Found DeployGPO.ps1 at: $fullDeployGPOPath" -ForegroundColor Green
            Set-Location (Split-Path $fullDeployGPOPath -Parent)
        } else {
            Write-Host "❌ Could not locate DeployGPO.ps1 in any subdirectory" -ForegroundColor Red
            throw "DeployGPO.ps1 script not found"
        }
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
            -Location $Location `
            -TenantId $TenantId
        
        Write-Host "✅ Group Policy deployment completed" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to deploy Group Policy: $($_.Exception.Message)" -ForegroundColor Red
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
            Write-Host "✅ Found newly created GPO: $GPOName" -ForegroundColor Green
        }
    }
    
    # Method 2: Fallback to specific Azure Arc related patterns
    if (-not $GPOName) {
        Write-Host "⚠️  Attempting to find GPO using pattern matching..." -ForegroundColor Yellow
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
            Write-Host "✅ Found Azure Arc GPO: $GPOName" -ForegroundColor Green
        }
    }
    
    # Method 3: Final fallback to MSFT pattern (original method)
    if (-not $GPOName) {
        Write-Host "⚠️  Using fallback pattern matching for MSFT..." -ForegroundColor Yellow
        $msftGPO = Get-GPO -All -Domain $DomainFQDN | Where-Object { $_.DisplayName -Like "*MSFT*" } | Sort-Object CreationTime -Descending | Select-Object -First 1
        if ($msftGPO) {
            $GPOName = $msftGPO.DisplayName
            Write-Host "⚠️  Found MSFT GPO: $GPOName" -ForegroundColor Yellow
            Write-Host "💡 Note: This may not be the correct Azure Arc GPO if multiple MSFT GPOs exist" -ForegroundColor Yellow
        }
    }
    
    # Validate we found a GPO
    if (-not $GPOName) {
        Write-Host "❌ Could not identify the Azure Arc GPO. Please check the DeployGPO.ps1 output." -ForegroundColor Red
        Write-Host "💡 Available GPOs in domain:" -ForegroundColor Yellow
        Get-GPO -All -Domain $DomainFQDN | Sort-Object DisplayName | ForEach-Object { 
            Write-Host "  • $($_.DisplayName)" -ForegroundColor Gray 
        }
        return
    }
    
    Write-Host "🎯 Using GPO for OU linking: $GPOName" -ForegroundColor Cyan

    # Prompt user for OU configuration
    Write-Host "`n🏢 Organizational Units Configuration" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "💡 You need to specify which Organizational Units (OUs) should have the Azure Arc GPO applied." -ForegroundColor Yellow
    
    $defaultOUFile = "AzureArc_OUs.txt"
    $ouFile = Read-Host "Provide the filename for the list of Organizational Units [default: $defaultOUFile]"
    
    # Remove quotes if user entered them
    $ouFile = Remove-PathQuotes -Path $ouFile
    
    # Use default if user pressed Enter without input
    if ([string]::IsNullOrWhiteSpace($ouFile)) {
        $ouFile = $defaultOUFile
        Write-Host "✅ Using default OU file: $ouFile" -ForegroundColor Green
    } else {
        Write-Host "✅ Using specified OU file: $ouFile" -ForegroundColor Green
    }
    
    # Check if file exists, create if it doesn't
    if (-not (Test-Path $ouFile)) {
        Write-Host "⚠️  OU file '$ouFile' does not exist. Creating with default OUs..." -ForegroundColor Yellow
        
        # Create default OU file with common Arc deployment targets
        $defaultOUs = @(
            "# Azure Arc Organizational Units Configuration",
            "# Add one OU name per line (without quotes)",
            "# Lines starting with # are comments and will be ignored",
            "# Examples:",
            "#   Servers",
            "#   Production Servers", 
            "#   Arc Enabled Devices",
            "",
            "Computers"
        )
        
        $defaultOUs | Out-File -FilePath $ouFile -Encoding UTF8
        Write-Host "✅ Created default OU file: $ouFile" -ForegroundColor Green
        Write-Host "💡 Please review and modify the OU file as needed, then run the script again." -ForegroundColor Yellow
        Write-Host "📝 Current default OU: Computers" -ForegroundColor Gray
        
        # Ask user if they want to continue with defaults or edit the file
        if (-not $Force) {
            $defaultChoice = "C"
            $choice = Read-Host "`nDo you want to (C)ontinue with default OUs or (E)dit the file first? [C/E] (default: C)"
            
            # Use default if user pressed Enter without input
            if ([string]::IsNullOrWhiteSpace($choice)) {
                $choice = $defaultChoice
                Write-Host "✅ Using default choice: Continue with defaults" -ForegroundColor Green
            }
            if ($choice.ToUpper() -eq 'E') {
                Write-Host "📝 Opening file for editing. Please save and close when done." -ForegroundColor Yellow
                try {
                    Start-Process notepad.exe -ArgumentList $ouFile -Wait
                }
                catch {
                    Write-Host "⚠️  Could not open notepad. Please edit the file manually: $ouFile" -ForegroundColor Yellow
                }
            }
        }
    }
    
    # Read OU names from file
    Write-Host "`n📖 Reading OU configuration from '$ouFile'..." -ForegroundColor Yellow
    try {
        $ouNames = Get-Content $ouFile | Where-Object { 
            $_.Trim() -ne "" -and -not $_.Trim().StartsWith("#") 
        } | ForEach-Object { $_.Trim() }
        
        if ($ouNames.Count -eq 0) {
            Write-Host "❌ No valid OU names found in '$ouFile'. Please add OU names to the file." -ForegroundColor Red
            return
        }
        
        Write-Host "✅ Found $($ouNames.Count) OU(s) in configuration file:" -ForegroundColor Green
        $ouNames | ForEach-Object { Write-Host "  • $_" -ForegroundColor Gray }
        
        # Get actual OU distinguished names
        Write-Host "`n🔍 Looking up OU distinguished names..." -ForegroundColor Yellow
        $OUs = @()
        $notFoundOUs = @()
        
        foreach ($ouName in $ouNames) {
            try {
                $ou = Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -ErrorAction Stop
                if ($ou) {
                    if ($ou -is [array]) {
                        # Multiple OUs with same name found
                        Write-Host "⚠️  Multiple OUs found with name '$ouName':" -ForegroundColor Yellow
                        $ou | ForEach-Object { Write-Host "     - $($_.DistinguishedName)" -ForegroundColor Gray }
                        $OUs += $ou[0].DistinguishedName  # Use first one
                        Write-Host "✅ Using first match: $($ou[0].DistinguishedName)" -ForegroundColor Green
                    } else {
                        $OUs += $ou.DistinguishedName
                        Write-Host "✅ Found OU: $($ou.DistinguishedName)" -ForegroundColor Green
                    }
                } else {
                    $notFoundOUs += $ouName
                }
            }
            catch {
                Write-Host "❌ Error finding OU '$ouName': $($_.Exception.Message)" -ForegroundColor Red
                $notFoundOUs += $ouName
            }
        }
        
        if ($notFoundOUs.Count -gt 0) {
            Write-Host "`n⚠️  The following OUs were not found:" -ForegroundColor Yellow
            $notFoundOUs | ForEach-Object { Write-Host "  • $_" -ForegroundColor Red }
            
            if (-not $Force) {
                $continueChoice = Read-Host "`nDo you want to continue with the found OUs? [Y/n] (default: Y)"
                if ([string]::IsNullOrWhiteSpace($continueChoice)) {
                    $continueChoice = 'Y'
                }
                if ($continueChoice.ToUpper() -ne 'Y') {
                    Write-Host "❌ Deployment cancelled by user" -ForegroundColor Red
                    return
                }
            }
        }
        
        if ($OUs.Count -eq 0) {
            Write-Host "❌ No valid OUs found. Cannot proceed with GPO linking." -ForegroundColor Red
            return
        }
        
    }
    catch {
        Write-Host "❌ Error reading OU file '$ouFile': $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    Write-Host "`n🔗 Linking GPO to Organizational Units" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "`nLinking the GPO '$GPOName' to the selected organizational units..." -ForegroundColor Yellow
    foreach ($OU in $OUs) {
        try {
            New-GPLink -Name $GPOName -Target $OU -ErrorAction Stop | Out-Null
            Write-Host "✅ Linked GPO to: $OU" -ForegroundColor Green
        }
        catch {
            if ($_.Exception.Message -match "already linked") {
                Write-Host "⚠️  GPO already linked to: $OU" -ForegroundColor Yellow
            } else {
                Write-Host "❌ Failed to link GPO to $OU`: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    Write-Host "`n✅ Azure Arc deployment completed successfully!" -ForegroundColor Green
    Write-Host "📄 Service principal details saved to: $($ArcServerOnboardingDetail.FullName)" -ForegroundColor Gray
    Write-Host "⚠️  Note: Service principal secret was not saved to file for security reasons." -ForegroundColor Yellow
    Write-Host "📁 Remote share created: \\$env:COMPUTERNAME\$RemoteShare" -ForegroundColor Gray
    Write-Host "🔗 GPO '$GPOName' linked to $($OUs.Count) organizational unit(s)" -ForegroundColor Gray
    Write-Host
    Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Verify GPO settings in Group Policy Management Console" -ForegroundColor White
    Write-Host "  2. Run 'gpupdate /force' on target devices or wait for automatic refresh" -ForegroundColor White
    Write-Host "  3. Monitor Azure Arc onboarding in Azure portal" -ForegroundColor White
    Write-Host "  4. Check device compliance in Microsoft Defender for Cloud" -ForegroundColor White
    Write-Host
}
