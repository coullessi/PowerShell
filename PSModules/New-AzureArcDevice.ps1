# https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-group-policy-powershell
# Run the script in PowerShell as administrator
#
# PREREQUISITES:
# Before running this script, ensure you have completed the prerequisites check by running:
# Test-AzureArcPrerequisites.ps1
#
# This script assumes that:
# - Azure PowerShell is installed and configured
# - Azure authentication is completed
# - Required Azure resource providers are registered
# - Network connectivity to Azure endpoints is verified

function New-AzureArcDevice {

    Clear-Host

    # Prerequisites validation should be completed before running this script
    # Run Test-AzureArcPrerequisites.ps1 first to ensure all requirements are met
    
    # Verify Azure context is available (from prerequisites script)
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Host "❌ No Azure context found. Please run Test-AzureArcPrerequisites.ps1 first." -ForegroundColor Red
            return
        }
        Write-Host "✅ Using existing Azure context: $($context.Account.Id)" -ForegroundColor Green
        $subId = $context.Subscription.Id
        $TenantId = $context.Tenant.Id
    }
    catch {
        Write-Host "❌ Azure PowerShell context not available. Please run Test-AzureArcPrerequisites.ps1 first." -ForegroundColor Red
        return
    }


    # 1. Get resource group and location information
    Write-Host "`n📋 Azure Resource Configuration" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    
    # Prompt for resource group
    $defaultResourceGroup = "rg-azurearc-$(Get-Date -Format 'yyyyMMdd')"
    $resourceGroup = Read-Host "`nProvide a resource group name for your Azure Arc deployment [default: $defaultResourceGroup]"
    
    # Use default if user pressed Enter without input
    if ([string]::IsNullOrWhiteSpace($resourceGroup)) {
        $resourceGroup = $defaultResourceGroup
        Write-Host "✅ Using default resource group: $resourceGroup" -ForegroundColor Green
    } else {
        Write-Host "✅ Resource group: $resourceGroup" -ForegroundColor Green
    }
    
    # Prompt for location
    $defaultLocation = "eastus"
    $location = Read-Host "`nProvide an Azure region for your deployment [default: $defaultLocation] (e.g., westus2, westeurope)"
    
    # Use default if user pressed Enter without input
    if ([string]::IsNullOrWhiteSpace($location)) {
        $location = $defaultLocation
        Write-Host "✅ Using default location: $location" -ForegroundColor Green
    } else {
        $validLocations = @("eastus", "eastus2", "westus", "westus2", "westeurope", "northeurope", "southeastasia", "eastasia", "australiaeast", "uksouth", "canadacentral", "francecentral", "germanywestcentral", "japaneast", "koreacentral", "southafricanorth", "uaenorth", "brazilsouth", "southcentralus", "northcentralus", "centralus", "westcentralus", "westus3", "east us", "east us 2", "west us", "west us 2", "west europe", "north europe", "southeast asia", "east asia", "australia east", "uk south", "canada central", "france central", "germany west central", "japan east", "korea central", "south africa north", "uae north", "brazil south", "south central us", "north central us", "central us", "west central us", "west us 3")
        
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
    $DomainName = (Get-ADDomain).DNSRoot
    
    # Prompt user for remote share path
    $defaultPath = "$env:HOMEDRIVE\AzureArc"
    Write-Host "`n💡 The remote share will store Azure Arc deployment files and scripts." -ForegroundColor Yellow
    $path = Read-Host "Provide the full or relative path for the Azure Arc remote share [default: $defaultPath]"
    
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
                Write-Host "❌ Failed to create SMB share '$shareName': $($_.Exception.Message)" -ForegroundColor Red
                throw
            }
        }
    }
    
    # Set the remote share name for use in GPO deployment
    $RemoteShare = $shareName
    Write-Host "✅ Remote share '$RemoteShare' is ready for deployment" -ForegroundColor Green
    Write-Host "📁 All files will be stored in: $path" -ForegroundColor Gray

    # 4. Download the onboarding files
    Write-Host "`n📥 Downloading Azure Arc Components" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    
    # Download Azure Connected Machine Agent
    Write-Host "Downloading Azure Connected Machine Agent..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri "https://aka.ms/AzureConnectedMachineAgent" -OutFile "$path\AzureConnectedMachineAgent.msi"
        Write-Host "✅ Azure Connected Machine Agent downloaded successfully" -ForegroundColor Green
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

    # 5. Create a service principal for the Azure Connected Machine Agent
    Write-Host "`n🔐 Creating Service Principal" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "Creating Azure Arc service principal for onboarding..." -ForegroundColor Yellow
    
    $date = Get-Date
    $ArcServerOnboardingDetail = New-Item -ItemType File -Path "$path\ArcServerOnboarding.txt"
    "------------------------------------------------------------------------------" | Out-File -FilePath $ArcServerOnboardingDetail -Append
    "`nService principal creation date: $date`nSecret expiration date: $($date.AddDays(7))" | Out-File -FilePath $ArcServerOnboardingDetail -Append
    
    try {
        $ServicePrincipal = New-AzADServicePrincipal -EndDate $date.AddDays(7) -DisplayName "Azure Arc Onboarding Account - Windows" -Role "Azure Connected Machine Onboarding" -Scope "/subscriptions/$subId/resourceGroups/$resourceGroup"
        Write-Host "✅ Service principal created successfully!" -ForegroundColor Green
        
        # Save only non-sensitive information to file (no secret for security)
        $ServicePrincipal | Format-Table AppId, DisplayName, @{ Name = "Role"; Expression = { "Azure Connected Machine Onboarding" } } | Out-File -FilePath $ArcServerOnboardingDetail -Append
        "`n------------------------------------------------------------------------------" | Out-File -FilePath $ArcServerOnboardingDetail -Append
        
        $AppId = $ServicePrincipal.AppId
        $Secret = $ServicePrincipal.PasswordCredentials.SecretText
        
        Write-Host "✅ Service principal details saved to: $($ArcServerOnboardingDetail.FullName)" -ForegroundColor Green
        Write-Host "🔑 Application ID: $AppId" -ForegroundColor Gray
        Write-Host "⚠️  Secret: [HIDDEN FOR SECURITY - Use from memory during deployment]" -ForegroundColor Yellow
        Write-Host "⏰ Secret expires: $($date.AddDays(7).ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    }
    catch {
        Write-Host "❌ Failed to create service principal: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }

    # 6. Deploy the group policy object and link it to the selected organizational units
    $DC = Get-ADDomainController
    $DomainFQDN = $DC.Domain
    $ReportServerFQDN = $DC.HostName

    Write-Host "`n🔧 Deploying Group Policy Object" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    
    # Get GPO count before deployment to identify the new GPO
    $gpoCountBefore = (Get-GPO -All -Domain $DomainFQDN).Count
    Write-Host "Current GPO count: $gpoCountBefore" -ForegroundColor Gray

    .\DeployGPO.ps1 -DomainFQDN $DomainFQDN `
        -ReportServerFQDN $ReportServerFQDN `
        -ArcRemoteShare $RemoteShare `
        -ServicePrincipalSecret $Secret `
        -ServicePrincipalClientId $AppId `
        -SubscriptionId $subId `
        -ResourceGroup $resourceGroup `
        -Location $Location `
        -TenantId $TenantId

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

    # TODO: Implement and call the Select-OU function
    # Select-OU

    # Prompt user for OU file
    Write-Host "`n🏢 Organizational Units Configuration" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "💡 You need to specify which Organizational Units (OUs) should have the Azure Arc GPO applied." -ForegroundColor Yellow
    
    $defaultOUFile = "AzureArc_OUs.txt"
    $ouFile = Read-Host "Provide the filename for the list of Organizational Units [default: $defaultOUFile]"
    
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
            "Arc Servers",
            "Domain Controllers"
        )
        
        $defaultOUs | Out-File -FilePath $ouFile -Encoding UTF8
        Write-Host "✅ Created default OU file: $ouFile" -ForegroundColor Green
        Write-Host "💡 Please review and modify the OU file as needed, then run the script again." -ForegroundColor Yellow
        Write-Host "📝 Current default OUs: Arc Servers, Domain Controllers" -ForegroundColor Gray
        
        # Ask user if they want to continue with defaults or edit the file
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
                Write-Host "✅ File editing completed." -ForegroundColor Green
            }
            catch {
                Write-Host "⚠️  Could not open notepad. Please edit '$ouFile' manually and run the script again." -ForegroundColor Yellow
                return
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
                $foundOU = Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -ErrorAction Stop
                if ($foundOU) {
                    if ($foundOU -is [array]) {
                        # Multiple OUs with same name found
                        Write-Host "⚠️  Multiple OUs found with name '$ouName':" -ForegroundColor Yellow
                        $foundOU | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
                        $OUs += $foundOU.DistinguishedName
                    } else {
                        $OUs += $foundOU.DistinguishedName
                        Write-Host "✅ Found OU: $ouName" -ForegroundColor Green
                    }
                } else {
                    $notFoundOUs += $ouName
                    Write-Host "❌ OU not found: $ouName" -ForegroundColor Red
                }
            }
            catch {
                $notFoundOUs += $ouName
                Write-Host "❌ Error finding OU '$ouName': $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        if ($notFoundOUs.Count -gt 0) {
            Write-Host "`n⚠️  The following OUs were not found:" -ForegroundColor Yellow
            $notFoundOUs | ForEach-Object { Write-Host "  • $_" -ForegroundColor Red }
            
            $defaultContinue = "Y"
            $continue = Read-Host "`nDo you want to continue with the found OUs? [Y/N] (default: Y)"
            
            # Use default if user pressed Enter without input
            if ([string]::IsNullOrWhiteSpace($continue)) {
                $continue = $defaultContinue
                Write-Host "✅ Using default choice: Yes, continuing with found OUs" -ForegroundColor Green
            }
            if ($continue.ToUpper() -ne 'Y') {
                Write-Host "❌ Operation cancelled. Please update the OU file and try again." -ForegroundColor Red
                return
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
            New-GPLink -Name "$GPOName" -Target "$OU" -LinkEnabled Yes | Out-Null
            Write-Host "✅ GPO linked to: $OU" -ForegroundColor Green
        }
        catch {
            if ($_.Exception.Message -match "already linked") {
                Write-Host "⚠️  GPO already linked to: $OU" -ForegroundColor Yellow
            } else {
                Write-Host "❌ Failed to link GPO to: $OU - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    Write-Host "`n✅ Azure Arc deployment completed successfully!" -ForegroundColor Green
    Write-Host "📄 Service principal details saved to: $($ArcServerOnboardingDetail.FullName)" -ForegroundColor Gray
    Write-Host "⚠️  Note: Service principal secret was not saved to file for security reasons." -ForegroundColor Yellow
    Write-Host
}

# Auto-execute the function when script is run directly (not when dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {
    New-AzureArcDevice
}
