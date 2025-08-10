function Get-AzureArcPrerequisite {
    <#
    .SYNOPSIS
        Tests Azure Arc prerequisites and automatically registers resource providers.

    .DESCRIPTION
        This enhanced function validates all prerequisites for Azure Arc deployment
        including PowerShell version, Azure modules, execution policy, and network
        connectivity. It also automatically registers required Azure resource providers.

    .PARAMETER SubscriptionId
        The Azure subscription ID to use for resource provider registration.

    .PARAMETER DeviceListPath
        Path to a text file containing a list of device names to test (one per line).

    .PARAMETER Force
        Skip confirmation prompts and proceed with automated testing.

    .PARAMETER NetworkTestMode
        Network testing mode: Basic, Standard, or Comprehensive.

    .PARAMETER IncludeOptionalEndpoints
        Include testing of optional Azure Arc endpoints.

    .PARAMETER TestTLSVersion
        Test TLS version compatibility with Azure endpoints.

    .PARAMETER ShowDetailedNetworkResults
        Display detailed network connectivity test results.

    .PARAMETER NetworkLogPath
        Custom path for network test log files.

    .EXAMPLE
        Get-AzureArcPrerequisite

        Runs basic prerequisites testing for the local machine.

    .EXAMPLE
        Get-AzureArcPrerequisite -Force -NetworkTestMode Comprehensive

        Runs comprehensive prerequisites testing without prompts.

    .NOTES
        Author: Lessi Coulibaly
        Organization: Less-IT (AI and CyberSecurity)
        Website: https://github.com/coullessi/PowerShell
        Version: 2.0.0
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [string]$DeviceListPath,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Basic", "Standard", "Comprehensive")]
        [string]$NetworkTestMode = "Standard",

        [Parameter(Mandatory = $false)]
        [switch]$IncludeOptionalEndpoints,

        [Parameter(Mandatory = $false)]
        [switch]$TestTLSVersion,

        [Parameter(Mandatory = $false)]
        [switch]$ShowDetailedNetworkResults,

        [Parameter(Mandatory = $false)]
        [string]$NetworkLogPath
    )

    # Initialize script-level variables
    $script:allResults = @{}
    $script:deviceOSVersions = @{}
    $script:azureLoginCompleted = $false
    $script:resourceProvidersChecked = $false
    $script:unregisteredProviders = @()
    $script:remediationScriptContent = @()

    # Initialize standardized environment
    $environment = Initialize-StandardizedEnvironment -ScriptName "Get-AzureArcPrerequisite" -RequiredFileTypes @("DeviceList", "PrerequisiteLog")

    # Check if user chose to quit
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
    $script:deviceListFile = $environment.FilePaths["DeviceList"]
    $script:globalLogFile = $environment.FilePaths["PrerequisiteLog"]

    # Device file selection
    if ([string]::IsNullOrWhiteSpace($DeviceListPath)) {
        # Use the new device file selection menu
        $DeviceListPath = Get-DeviceFileSelection -WorkingDirectory $workingFolder -DefaultDeviceFile $script:deviceListFile
    } else {
        # DeviceListPath was provided as parameter - validate it
        Write-Host ""
        Write-Host " Using provided device list parameter: $DeviceListPath"

        if (-not (Test-Path -Path $DeviceListPath -PathType Leaf)) {
            Write-Host " [WARN] Provided device list file not found: $DeviceListPath" -ForegroundColor Green
            Write-Host " Continuing without device list..."
            $DeviceListPath = $null
        } else {
            Write-Host " [OK] Device list file verified" -ForegroundColor Green
        }
    }

    try {
        Clear-Host
        Write-Host ""
        Write-Host " AZURE ARC PREREQUISITES VALIDATION"
        Write-Host " Testing system readiness for Azure Arc onboarding"
        Write-Host ""

        # Log session start
        ("=" * 100) | Out-File -FilePath $script:globalLogFile
        "AZURE ARC PREREQUISITES TESTING SESSION" | Out-File -FilePath $script:globalLogFile -Append
        ("=" * 100) | Out-File -FilePath $script:globalLogFile -Append
        "Started: $(Get-Date)" | Out-File -FilePath $script:globalLogFile -Append
        "Parameters: Force=$Force, NetworkTestMode=$NetworkTestMode" | Out-File -FilePath $script:globalLogFile -Append
        if ($DeviceListPath) {
            "Device List File: $DeviceListPath" | Out-File -FilePath $script:globalLogFile -Append
        }
        "Log File Directory: $([System.IO.Path]::GetDirectoryName($script:globalLogFile))" | Out-File -FilePath $script:globalLogFile -Append
        "" | Out-File -FilePath $script:globalLogFile -Append

        # Initialize device testing variables
        $deviceResults = @{}
        $overallRecommendations = @()
        $devicesToTest = @()

        # Determine devices to test
        if ($DeviceListPath -and (Test-Path $DeviceListPath)) {
            Write-Host " LOADING DEVICE LIST"
            Write-Host ""
            Write-Host "   Reading device list from: $DeviceListPath"

            try {
                $deviceListContent = Get-Content $DeviceListPath -ErrorAction Stop
                $devicesToTest = $deviceListContent | Where-Object {
                    $_.Trim() -ne "" -and -not $_.Trim().StartsWith("#")
                } | ForEach-Object { $_.Trim() }

                if ($devicesToTest.Count -eq 0) {
                    Write-Host "   [WARN] No valid device names found in device list" -ForegroundColor Green
                    Write-Host "   Testing local machine only..."
                    $devicesToTest = @($env:COMPUTERNAME)
                } else {
                    Write-Host "   [OK] Found $($devicesToTest.Count) device(s) to test" -ForegroundColor Green
                    $devicesToTest | ForEach-Object { Write-Host "     - $_" }
                }

                # Log device list
                "DEVICE LIST PROCESSING" | Out-File -FilePath $script:globalLogFile -Append
                ("-" * 50) | Out-File -FilePath $script:globalLogFile -Append
                "Total devices found: $($devicesToTest.Count)" | Out-File -FilePath $script:globalLogFile -Append
                $devicesToTest | ForEach-Object { "  - $_" | Out-File -FilePath $script:globalLogFile -Append }
                "" | Out-File -FilePath $script:globalLogFile -Append

            } catch {
                Write-Host "   [FAIL] Failed to read device list: $($_.Exception.Message)" -ForegroundColor Green
                Write-Host "   Testing local machine only..."
                $devicesToTest = @($env:COMPUTERNAME)

                "ERROR: Failed to read device list - $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
                "Defaulting to local machine: $env:COMPUTERNAME" | Out-File -FilePath $script:globalLogFile -Append
                "" | Out-File -FilePath $script:globalLogFile -Append
            }
        } else {
            Write-Host "   No device list provided, testing local machine only"
            $devicesToTest = @($env:COMPUTERNAME)

            "DEVICE LIST: Not provided - testing local machine only" | Out-File -FilePath $script:globalLogFile -Append
            "Device: $env:COMPUTERNAME" | Out-File -FilePath $script:globalLogFile -Append
            "" | Out-File -FilePath $script:globalLogFile -Append
        }

        # Azure Authentication and Resource Provider Registration (One-time for all devices)
        Write-Host ""
        Write-Host " AZURE AUTHENTICATION & RESOURCE PROVIDERS"
        Write-Host ""

        ("=" * 100) | Out-File -FilePath $script:globalLogFile -Append
        "AZURE AUTHENTICATION `& RESOURCE PROVIDER REGISTRATION" | Out-File -FilePath $script:globalLogFile -Append
        ("=" * 100) | Out-File -FilePath $script:globalLogFile -Append

        $skipAuth = $false
        if (-not $Force) {
            Write-Host "   Azure authentication is required to register resource providers."
            $authConfirm = Read-Host "   Proceed with Azure authentication? [Y/N] (default: Y)"
            if ($authConfirm -eq "N" -or $authConfirm -eq "n") {
                Write-Host "     [WARN] Skipping Azure authentication and resource provider registration" -ForegroundColor Green
                "Azure authentication skipped by user" | Out-File -FilePath $script:globalLogFile -Append
                "" | Out-File -FilePath $script:globalLogFile -Append
                $skipAuth = $true
            }
        }

        if (-not $skipAuth) {
            try {
                Write-Host "   Attempting Azure authentication..."

                # Try to get current context first
                $currentContext = Get-AzContext -ErrorAction SilentlyContinue
                if ($currentContext) {
                    Write-Host "     [OK] Using existing Azure context: $($currentContext.Account)" -ForegroundColor Green
                    $script:azureLoginCompleted = $true
                    "SUCCESS: Azure Authentication: Using existing context ($($currentContext.Account))" | Out-File -FilePath $script:globalLogFile -Append
                } else {
                    # Attempt interactive login
                    Write-Host "     Initiating Azure login..."
                    $null = Connect-AzAccount -ErrorAction Stop
                    Write-Host "     [OK] Azure authentication successful" -ForegroundColor Green
                    $script:azureLoginCompleted = $true
                    $newContext = Get-AzContext
                    "SUCCESS: Azure Authentication: Successful ($($newContext.Account))" | Out-File -FilePath $script:globalLogFile -Append
                }

                # Set subscription if provided
                if ($SubscriptionId) {
                    Write-Host "   Setting Azure subscription context..."
                    $null = Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop
                    Write-Host "     [OK] Subscription context set: $SubscriptionId" -ForegroundColor Green
                    "SUCCESS: Subscription Context: Set to $SubscriptionId" | Out-File -FilePath $script:globalLogFile -Append
                }

                # Register required resource providers
                if ($script:azureLoginCompleted) {
                    Write-Host "   Registering Azure resource providers..."

                    $providers = @(
                        "Microsoft.HybridCompute",
                        "Microsoft.GuestConfiguration",
                        "Microsoft.AzureArcData",
                        "Microsoft.HybridConnectivity"
                    )

                    "Resource Provider Registration:" | Out-File -FilePath $script:globalLogFile -Append
                    $registrationResults = @()
                    foreach ($provider in $providers) {
                        try {
                            Write-Host "     Checking $provider..."
                            $resourceProvider = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue

                            if ($resourceProvider -and $resourceProvider.RegistrationState -eq "Registered") {
                                Write-Host "     [OK] $provider - Already registered" -ForegroundColor Green
                                $registrationResults += "SUCCESS: $provider - Already registered"
                                "  SUCCESS: $provider - Already registered" | Out-File -FilePath $script:globalLogFile -Append
                            } else {
                                Write-Host "     Registering $provider..."
                                $null = Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop
                                Write-Host "     [OK] $provider - Registration initiated" -ForegroundColor Green
                                $registrationResults += "SUCCESS: $provider - Registration initiated"
                                "  SUCCESS: $provider - Registration initiated" | Out-File -FilePath $script:globalLogFile -Append
                            }
                        } catch {
                            Write-Host "     [FAIL] $provider - Registration failed: $($_.Exception.Message)" -ForegroundColor Green
                            $registrationResults += "[FAIL] $provider - Registration failed"
                            "  [FAIL] $provider - Registration failed: $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
                        }
                    }

                    Write-Host "     Resource provider registration summary:" -ForegroundColor Yellow
                    foreach ($result in $registrationResults) {
                        Write-Host "       $result"
                    }
                }

            } catch {
                Write-Host "     [FAIL] Azure authentication failed: $($_.Exception.Message)" -ForegroundColor Green
                Write-Host "     Resource provider registration skipped"
                "[FAIL] Azure Authentication Failed: $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
            }
        }

        "" | Out-File -FilePath $script:globalLogFile -Append

        Write-Host ""
        Write-Host " TESTING $($devicesToTest.Count) DEVICE(S)"
        Write-Host ""

        # Test each device
        foreach ($deviceName in $devicesToTest) {
            $isLocalMachine = ($deviceName -eq $env:COMPUTERNAME -or $deviceName -eq "localhost" -or $deviceName -eq ".")

            Write-Host " DEVICE: $deviceName"
            Write-Host " $("=" * ($deviceName.Length + 8))"
            Write-Host ""

            # Initialize device result
            $deviceResult = @{
                DeviceName = $deviceName
                IsLocalMachine = $isLocalMachine
                TestResults = @{}
                OverallStatus = "Unknown"
                Recommendations = @()
                Warnings = @()
                Errors = @()
                TestDateTime = Get-Date
            }

            # Log device section start
            ("=" * 100) | Out-File -FilePath $script:globalLogFile -Append
            "DEVICE: $deviceName" | Out-File -FilePath $script:globalLogFile -Append
            ("=" * 100) | Out-File -FilePath $script:globalLogFile -Append
            "Test Started: $(Get-Date)" | Out-File -FilePath $script:globalLogFile -Append
            "Local Machine: $isLocalMachine" | Out-File -FilePath $script:globalLogFile -Append
            "" | Out-File -FilePath $script:globalLogFile -Append

        # Step 1: Basic PowerShell Environment Check
        Write-Host " STEP 1: POWERSHELL ENVIRONMENT VALIDATION"
        Write-Host ""

        "STEP 1: POWERSHELL ENVIRONMENT VALIDATION" | Out-File -FilePath $script:globalLogFile -Append
        ("-" * 50) | Out-File -FilePath $script:globalLogFile -Append

        # Check PowerShell version
        Write-Host "   Checking PowerShell version..."
        try {
            if ($isLocalMachine) {
                $psVersion = $PSVersionTable.PSVersion
                $psHost = $PSVersionTable.PSEdition
            } else {
                # For remote machines, we'd need to use Invoke-Command
                Write-Host "     [WARN] Remote PowerShell testing not implemented yet" -ForegroundColor Green
                $psVersion = "Unknown (Remote)"
                $psHost = "Unknown (Remote)"
                $deviceResult.Warnings += "Remote PowerShell testing not implemented"
            }

            if ($psVersion -ne "Unknown (Remote)") {
                if ($psVersion.Major -ge 5 -and ($psVersion.Major -gt 5 -or $psVersion.Minor -ge 1)) {
                    Write-Host "     [OK] PowerShell $($psVersion.ToString()) ($psHost) - Compatible" -ForegroundColor Green
                    $deviceResult.TestResults.PowerShellVersion = @{
                        Status = "Pass"
                        Version = $psVersion.ToString()
                        Edition = $psHost
                        Message = "Compatible"
                    }
                    "SUCCESS: PowerShell Version: $($psVersion.ToString()) ($psHost) - Compatible" | Out-File -FilePath $script:globalLogFile -Append
                } else {
                    Write-Host "     [FAIL] PowerShell $($psVersion.ToString()) - Requires 5.1 or higher" -ForegroundColor Green
                    $deviceResult.TestResults.PowerShellVersion = @{
                        Status = "Fail"
                        Version = $psVersion.ToString()
                        Edition = $psHost
                        Message = "Requires PowerShell 5.1 or higher"
                    }
                    $deviceResult.Errors += "PowerShell version $($psVersion.ToString()) is incompatible"
                    $deviceResult.Recommendations += "Upgrade to PowerShell 5.1 or higher"
                    "[FAIL] PowerShell Version: $($psVersion.ToString()) - INCOMPATIBLE (Requires 5.1+)" | Out-File -FilePath $script:globalLogFile -Append
                }
            } else {
                $deviceResult.TestResults.PowerShellVersion = @{
                    Status = "Warning"
                    Version = "Unknown"
                    Edition = "Unknown"
                    Message = "Remote testing not implemented"
                }
                "[WARN] PowerShell Version: Unknown (Remote testing not implemented)" | Out-File -FilePath $script:globalLogFile -Append
            }
        } catch {
            Write-Host "     [FAIL] Failed to check PowerShell version: $($_.Exception.Message)" -ForegroundColor Green
            $deviceResult.TestResults.PowerShellVersion = @{
                Status = "Error"
                Version = "Unknown"
                Edition = "Unknown"
                Message = $_.Exception.Message
            }
            $deviceResult.Errors += "Failed to check PowerShell version: $($_.Exception.Message)"
            "[FAIL] PowerShell Version Check Failed: $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
        }

        # Check execution policy
        Write-Host "   Checking execution policy..."
        try {
            if ($isLocalMachine) {
                $execPolicy = Get-ExecutionPolicy
            } else {
                $execPolicy = "Unknown (Remote)"
                $deviceResult.Warnings += "Remote execution policy testing not implemented"
            }

            $compatiblePolicies = @("RemoteSigned", "Unrestricted", "Bypass")
            if ($execPolicy -in $compatiblePolicies) {
                Write-Host "     [OK] Execution Policy: $execPolicy - Compatible" -ForegroundColor Green
                $deviceResult.TestResults.ExecutionPolicy = @{
                    Status = "Pass"
                    Policy = $execPolicy
                    Message = "Compatible"
                }
                "SUCCESS: Execution Policy: $execPolicy - Compatible" | Out-File -FilePath $script:globalLogFile -Append
            } elseif ($execPolicy -eq "Unknown (Remote)") {
                Write-Host "     [WARN] Execution Policy: Unknown (Remote)" -ForegroundColor Green
                $deviceResult.TestResults.ExecutionPolicy = @{
                    Status = "Warning"
                    Policy = "Unknown"
                    Message = "Remote testing not implemented"
                }
                "[WARN] Execution Policy: Unknown (Remote testing not implemented)" | Out-File -FilePath $script:globalLogFile -Append
            } else {
                Write-Host "     [WARN] Execution Policy: $execPolicy - May block Azure Arc scripts" -ForegroundColor Green
                Write-Host "       Consider running: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
                $deviceResult.TestResults.ExecutionPolicy = @{
                    Status = "Warning"
                    Policy = $execPolicy
                    Message = "May block Azure Arc scripts"
                }
                $deviceResult.Warnings += "Execution policy '$execPolicy' may block scripts"
                $deviceResult.Recommendations += "Set execution policy: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
                "[WARN] Execution Policy: $execPolicy - MAY BLOCK SCRIPTS" | Out-File -FilePath $script:globalLogFile -Append
                "  Recommendation: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" | Out-File -FilePath $script:globalLogFile -Append
            }
        } catch {
            Write-Host "     [FAIL] Failed to check execution policy: $($_.Exception.Message)" -ForegroundColor Green
            $deviceResult.TestResults.ExecutionPolicy = @{
                Status = "Error"
                Policy = "Unknown"
                Message = $_.Exception.Message
            }
            $deviceResult.Errors += "Failed to check execution policy: $($_.Exception.Message)"
            "[FAIL] Execution Policy Check Failed: $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
        }

        "" | Out-File -FilePath $script:globalLogFile -Append

        # Step 2: Azure PowerShell Module Check
        Write-Host "`n STEP 2: AZURE POWERSHELL MODULE VALIDATION"
        Write-Host ""

        "STEP 2: AZURE POWERSHELL MODULE VALIDATION" | Out-File -FilePath $script:globalLogFile -Append
        ("-" * 50) | Out-File -FilePath $script:globalLogFile -Append

        Write-Host "   Checking Azure PowerShell modules..."
        try {
            if ($isLocalMachine) {
                $azAccountsModule = Get-Module -ListAvailable -Name Az.Accounts | Select-Object -First 1
                $azResourcesModule = Get-Module -ListAvailable -Name Az.Resources | Select-Object -First 1
            } else {
                $azAccountsModule = $null
                $azResourcesModule = $null
                $deviceResult.Warnings += "Remote Azure module testing not implemented"
            }

            # Check Az.Accounts
            if ($azAccountsModule) {
                Write-Host "     [OK] Az.Accounts module found - Version $($azAccountsModule.Version)" -ForegroundColor Green
                $deviceResult.TestResults.AzAccountsModule = @{
                    Status = "Pass"
                    Version = $azAccountsModule.Version.ToString()
                    Message = "Module available"
                }
                "[OK] Az.Accounts Module: Version $($azAccountsModule.Version) - Available" | Out-File -FilePath $script:globalLogFile -Append
            } elseif ($isLocalMachine) {
                Write-Host "     [WARN] Az.Accounts module not found - Will be installed if needed" -ForegroundColor Green
                $deviceResult.TestResults.AzAccountsModule = @{
                    Status = "Warning"
                    Version = "Not Installed"
                    Message = "Module not found - installation required"
                }
                $deviceResult.Warnings += "Az.Accounts module not installed"
                $deviceResult.Recommendations += "Install Az.Accounts module: Install-Module -Name Az.Accounts -Force"
                "[WARN] Az.Accounts Module: NOT INSTALLED" | Out-File -FilePath $script:globalLogFile -Append
                "  Recommendation: Install-Module -Name Az.Accounts -Force" | Out-File -FilePath $script:globalLogFile -Append
            } else {
                $deviceResult.TestResults.AzAccountsModule = @{
                    Status = "Warning"
                    Version = "Unknown"
                    Message = "Remote testing not implemented"
                }
                "[WARN] Az.Accounts Module: Unknown (Remote testing not implemented)" | Out-File -FilePath $script:globalLogFile -Append
            }

            # Check Az.Resources
            if ($azResourcesModule) {
                Write-Host "     [OK] Az.Resources module found - Version $($azResourcesModule.Version)" -ForegroundColor Green
                $deviceResult.TestResults.AzResourcesModule = @{
                    Status = "Pass"
                    Version = $azResourcesModule.Version.ToString()
                    Message = "Module available"
                }
                "[OK] Az.Resources Module: Version $($azResourcesModule.Version) - Available" | Out-File -FilePath $script:globalLogFile -Append
            } elseif ($isLocalMachine) {
                Write-Host "     [WARN] Az.Resources module not found - Will be installed if needed" -ForegroundColor Green
                $deviceResult.TestResults.AzResourcesModule = @{
                    Status = "Warning"
                    Version = "Not Installed"
                    Message = "Module not found - installation required"
                }
                $deviceResult.Warnings += "Az.Resources module not installed"
                $deviceResult.Recommendations += "Install Az.Resources module: Install-Module -Name Az.Resources -Force"
                "[WARN] Az.Resources Module: NOT INSTALLED" | Out-File -FilePath $script:globalLogFile -Append
                "  Recommendation: Install-Module -Name Az.Resources -Force" | Out-File -FilePath $script:globalLogFile -Append
            } else {
                $deviceResult.TestResults.AzResourcesModule = @{
                    Status = "Warning"
                    Version = "Unknown"
                    Message = "Remote testing not implemented"
                }
                "[WARN] Az.Resources Module: Unknown (Remote testing not implemented)" | Out-File -FilePath $script:globalLogFile -Append
            }
        } catch {
            Write-Host "     [FAIL] Failed to check Azure modules: $($_.Exception.Message)" -ForegroundColor Green
            $deviceResult.TestResults.AzureModules = @{
                Status = "Error"
                Message = $_.Exception.Message
            }
            $deviceResult.Errors += "Failed to check Azure modules: $($_.Exception.Message)"
            "[FAIL] Azure Modules Check Failed: $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
        }

        "" | Out-File -FilePath $script:globalLogFile -Append

        # Step 3: System Requirements Check
        Write-Host "`n STEP 3: SYSTEM REQUIREMENTS VALIDATION"
        Write-Host ""

        "STEP 3: SYSTEM REQUIREMENTS VALIDATION" | Out-File -FilePath $script:globalLogFile -Append
        ("-" * 50) | Out-File -FilePath $script:globalLogFile -Append

        # Check OS version
        Write-Host "   Checking operating system compatibility..."
        try {
            if ($isLocalMachine) {
                $os = Get-CimInstance Win32_OperatingSystem
                $osVersion = [Version]$os.Version
                $osName = $os.Caption
            } else {
                # For remote machines, we'd use Invoke-Command
                $os = $null
                $osVersion = $null
                $osName = "Unknown (Remote)"
                $deviceResult.Warnings += "Remote OS testing not implemented"
            }

            if ($os) {
                Write-Host "     OS: $osName"
                Write-Host "     Version: $($os.Version) (Build $($os.BuildNumber))"

                # Basic OS compatibility check
                if ($os.ProductType -eq 1) {
                    Write-Host "     [WARN] Client OS detected - Azure Arc is designed for servers" -ForegroundColor Green
                    $deviceResult.TestResults.OperatingSystem = @{
                        Status = "Warning"
                        Name = $osName
                        Version = $os.Version
                        Build = $os.BuildNumber
                        ProductType = "Client"
                        Message = "Client OS - Azure Arc designed for servers"
                    }
                    $deviceResult.Warnings += "Client OS detected - Azure Arc is designed for servers"
                    $deviceResult.Recommendations += "Consider using server OS for production Azure Arc deployments"
                    "[WARN] Operating System: $osName - CLIENT OS (Azure Arc designed for servers)" | Out-File -FilePath $script:globalLogFile -Append
                    "  OS Version: $($os.Version) (Build $($os.BuildNumber))" | Out-File -FilePath $script:globalLogFile -Append
                    "  Recommendation: Use server OS for production deployments" | Out-File -FilePath $script:globalLogFile -Append
                } elseif ($osVersion.Build -ge 9600) {
                    Write-Host "     [OK] Server OS version is compatible with Azure Arc" -ForegroundColor Green
                    $deviceResult.TestResults.OperatingSystem = @{
                        Status = "Pass"
                        Name = $osName
                        Version = $os.Version
                        Build = $os.BuildNumber
                        ProductType = "Server"
                        Message = "Compatible server OS"
                    }
                    "[OK] Operating System: $osName - COMPATIBLE" | Out-File -FilePath $script:globalLogFile -Append
                    "  OS Version: $($os.Version) (Build $($os.BuildNumber))" | Out-File -FilePath $script:globalLogFile -Append
                } else {
                    Write-Host "     [FAIL] OS version may not be fully supported" -ForegroundColor Green
                    $deviceResult.TestResults.OperatingSystem = @{
                        Status = "Fail"
                        Name = $osName
                        Version = $os.Version
                        Build = $os.BuildNumber
                        ProductType = if ($os.ProductType -eq 1) { "Client" } else { "Server" }
                        Message = "OS version may not be supported"
                    }
                    $deviceResult.Errors += "OS version may not be fully supported"
                    $deviceResult.Recommendations += "Upgrade to a supported OS version (Windows Server 2012 R2 or later)"
                    "[FAIL] Operating System: $osName - UNSUPPORTED VERSION" | Out-File -FilePath $script:globalLogFile -Append
                    "  OS Version: $($os.Version) (Build $($os.BuildNumber))" | Out-File -FilePath $script:globalLogFile -Append
                    "  Recommendation: Upgrade to Windows Server 2012 R2 or later" | Out-File -FilePath $script:globalLogFile -Append
                }
            } else {
                Write-Host "     [WARN] OS information unavailable (Remote)"
                $deviceResult.TestResults.OperatingSystem = @{
                    Status = "Warning"
                    Name = "Unknown"
                    Version = "Unknown"
                    Build = "Unknown"
                    ProductType = "Unknown"
                    Message = "Remote testing not implemented"
                }
                "[WARN] Operating System: Unknown (Remote testing not implemented)" | Out-File -FilePath $script:globalLogFile -Append
            }
        } catch {
            Write-Host "     [FAIL] Failed to check OS: $($_.Exception.Message)" -ForegroundColor Green
            $deviceResult.TestResults.OperatingSystem = @{
                Status = "Error"
                Message = $_.Exception.Message
            }
            $deviceResult.Errors += "Failed to check OS: $($_.Exception.Message)"
            "[FAIL] Operating System Check Failed: $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
        }

        # Check architecture
        Write-Host "   Checking processor architecture..."
        try {
            if ($isLocalMachine) {
                $processor = Get-CimInstance Win32_Processor
                $architecture = switch ($processor.Architecture) {
                    0 { "x86" }
                    9 { "x64" }
                    12 { "ARM64" }
                    default { "Unknown" }
                }
            } else {
                $processor = $null
                $architecture = "Unknown (Remote)"
                $deviceResult.Warnings += "Remote processor testing not implemented"
            }

            if ($processor) {
                if ($processor.Architecture -in @(9, 12)) {
                    Write-Host "     [OK] Architecture: $architecture - Supported" -ForegroundColor Green
                    $deviceResult.TestResults.ProcessorArchitecture = @{
                        Status = "Pass"
                        Architecture = $architecture
                        ArchitectureCode = $processor.Architecture
                        Message = "Supported architecture"
                    }
                    "[OK] Processor Architecture: $architecture - SUPPORTED" | Out-File -FilePath $script:globalLogFile -Append
                } else {
                    Write-Host "     [FAIL] Architecture: $architecture - Not supported" -ForegroundColor Green
                    $deviceResult.TestResults.ProcessorArchitecture = @{
                        Status = "Fail"
                        Architecture = $architecture
                        ArchitectureCode = $processor.Architecture
                        Message = "Unsupported architecture"
                    }
                    $deviceResult.Errors += "Processor architecture '$architecture' not supported"
                    $deviceResult.Recommendations += "Use x64 or ARM64 processor architecture"
                    "[FAIL] Processor Architecture: $architecture - UNSUPPORTED" | Out-File -FilePath $script:globalLogFile -Append
                    "  Recommendation: Use x64 or ARM64 architecture" | Out-File -FilePath $script:globalLogFile -Append
                }
            } else {
                $deviceResult.TestResults.ProcessorArchitecture = @{
                    Status = "Warning"
                    Architecture = "Unknown"
                    Message = "Remote testing not implemented"
                }
                "[WARN] Processor Architecture: Unknown (Remote testing not implemented)" | Out-File -FilePath $script:globalLogFile -Append
            }
        } catch {
            Write-Host "     [FAIL] Failed to check processor: $($_.Exception.Message)" -ForegroundColor Green
            $deviceResult.TestResults.ProcessorArchitecture = @{
                Status = "Error"
                Message = $_.Exception.Message
            }
            $deviceResult.Errors += "Failed to check processor: $($_.Exception.Message)"
            "[FAIL] Processor Architecture Check Failed: $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
        }

        # Check memory
        Write-Host "   Checking system memory..."
        try {
            if ($isLocalMachine) {
                $totalMemoryGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
            } else {
                $totalMemoryGB = 0
                $deviceResult.Warnings += "Remote memory testing not implemented"
            }

            if ($totalMemoryGB -gt 0) {
                if ($totalMemoryGB -ge 2) {
                    Write-Host "     [OK] Memory: $totalMemoryGB GB - Adequate" -ForegroundColor Green
                    $deviceResult.TestResults.SystemMemory = @{
                        Status = "Pass"
                        MemoryGB = $totalMemoryGB
                        Message = "Adequate memory"
                    }
                    "[OK] System Memory: $totalMemoryGB GB - ADEQUATE" | Out-File -FilePath $script:globalLogFile -Append
                } else {
                    Write-Host "     [WARN] Memory: $totalMemoryGB GB - Below recommended 2GB" -ForegroundColor Green
                    $deviceResult.TestResults.SystemMemory = @{
                        Status = "Warning"
                        MemoryGB = $totalMemoryGB
                        Message = "Below recommended 2GB"
                    }
                    $deviceResult.Warnings += "System memory ($totalMemoryGB GB) below recommended 2GB"
                    $deviceResult.Recommendations += "Increase system memory to at least 2GB for optimal performance"
                    "[WARN] System Memory: $totalMemoryGB GB - BELOW RECOMMENDED (2GB minimum)" | Out-File -FilePath $script:globalLogFile -Append
                    "  Recommendation: Increase to at least 2GB" | Out-File -FilePath $script:globalLogFile -Append
                }
            } else {
                $deviceResult.TestResults.SystemMemory = @{
                    Status = "Warning"
                    MemoryGB = "Unknown"
                    Message = "Remote testing not implemented"
                }
                "[WARN] System Memory: Unknown (Remote testing not implemented)" | Out-File -FilePath $script:globalLogFile -Append
            }
        } catch {
            Write-Host "     [FAIL] Failed to check memory: $($_.Exception.Message)" -ForegroundColor Green
            $deviceResult.TestResults.SystemMemory = @{
                Status = "Error"
                Message = $_.Exception.Message
            }
            $deviceResult.Errors += "Failed to check memory: $($_.Exception.Message)"
            "[FAIL] System Memory Check Failed: $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
        }

        "" | Out-File -FilePath $script:globalLogFile -Append

        # Step 4: Required Services Check
        Write-Host "`n STEP 4: REQUIRED SERVICES VALIDATION"
        Write-Host ""

        "STEP 4: REQUIRED SERVICES VALIDATION" | Out-File -FilePath $script:globalLogFile -Append
        ("-" * 50) | Out-File -FilePath $script:globalLogFile -Append

        $requiredServices = @(
            @{ Name = "WinRM"; DisplayName = "Windows Remote Management" },
            @{ Name = "Winmgmt"; DisplayName = "Windows Management Instrumentation" },
            @{ Name = "EventLog"; DisplayName = "Windows Event Log" },
            @{ Name = "RpcSs"; DisplayName = "Remote Procedure Call (RPC)" }
        )

        $deviceResult.TestResults.Services = @{}
        foreach ($service in $requiredServices) {
            Write-Host "   Checking $($service.DisplayName)..."
            try {
                if ($isLocalMachine) {
                    $serviceStatus = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
                } else {
                    $serviceStatus = $null
                    $deviceResult.Warnings += "Remote service testing not implemented for $($service.DisplayName)"
                }

                if ($serviceStatus -and $serviceStatus.Status -eq "Running") {
                    Write-Host "     [OK] $($service.DisplayName) - Running" -ForegroundColor Green
                    $deviceResult.TestResults.Services[$service.Name] = @{
                        Status = "Pass"
                        ServiceStatus = "Running"
                        DisplayName = $service.DisplayName
                        Message = "Service running normally"
                    }
                    "[OK] Service: $($service.DisplayName) - RUNNING" | Out-File -FilePath $script:globalLogFile -Append
                } elseif ($serviceStatus) {
                    Write-Host "     [WARN] $($service.DisplayName) - $($serviceStatus.Status)" -ForegroundColor Green
                    $deviceResult.TestResults.Services[$service.Name] = @{
                        Status = "Warning"
                        ServiceStatus = $serviceStatus.Status
                        DisplayName = $service.DisplayName
                        Message = "Service not running"
                    }
                    $deviceResult.Warnings += "$($service.DisplayName) service is $($serviceStatus.Status)"
                    $deviceResult.Recommendations += "Start $($service.DisplayName) service: Start-Service -Name $($service.Name)"
                    "[WARN] Service: $($service.DisplayName) - $($serviceStatus.Status.ToUpper())" | Out-File -FilePath $script:globalLogFile -Append
                    "  Recommendation: Start-Service -Name $($service.Name)" | Out-File -FilePath $script:globalLogFile -Append
                } elseif ($isLocalMachine) {
                    Write-Host "     [FAIL] $($service.DisplayName) - Not found" -ForegroundColor Green
                    $deviceResult.TestResults.Services[$service.Name] = @{
                        Status = "Fail"
                        ServiceStatus = "Not Found"
                        DisplayName = $service.DisplayName
                        Message = "Service not found"
                    }
                    $deviceResult.Errors += "$($service.DisplayName) service not found"
                    $deviceResult.Recommendations += "Install/enable $($service.DisplayName) service"
                    "[FAIL] Service: $($service.DisplayName) - NOT FOUND" | Out-File -FilePath $script:globalLogFile -Append
                    "  Recommendation: Install/enable the service" | Out-File -FilePath $script:globalLogFile -Append
                } else {
                    $deviceResult.TestResults.Services[$service.Name] = @{
                        Status = "Warning"
                        ServiceStatus = "Unknown"
                        DisplayName = $service.DisplayName
                        Message = "Remote testing not implemented"
                    }
                    "[WARN] Service: $($service.DisplayName) - Unknown (Remote testing not implemented)" | Out-File -FilePath $script:globalLogFile -Append
                }
            } catch {
                Write-Host "     [FAIL] Failed to check $($service.DisplayName): $($_.Exception.Message)" -ForegroundColor Green
                $deviceResult.TestResults.Services[$service.Name] = @{
                    Status = "Error"
                    ServiceStatus = "Error"
                    DisplayName = $service.DisplayName
                    Message = $_.Exception.Message
                }
                $deviceResult.Errors += "Failed to check $($service.DisplayName): $($_.Exception.Message)"
                "[FAIL] Service Check Failed: $($service.DisplayName) - $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
            }
        }

        "" | Out-File -FilePath $script:globalLogFile -Append

        # Step 5: Network Connectivity Check
        Write-Host "`n STEP 5: NETWORK CONNECTIVITY VALIDATION"
        Write-Host ""

        "STEP 5: NETWORK CONNECTIVITY VALIDATION" | Out-File -FilePath $script:globalLogFile -Append
        ("-" * 50) | Out-File -FilePath $script:globalLogFile -Append

        $azureEndpoints = @(
            @{ Name = "Azure Resource Manager"; Url = "management.azure.com"; Port = 443 },
            @{ Name = "Azure Arc Service"; Url = "gbl.his.arc.azure.com"; Port = 443 },
            @{ Name = "Azure Active Directory"; Url = "login.microsoftonline.com"; Port = 443 },
            @{ Name = "Download Center"; Url = "download.microsoft.com"; Port = 443 }
        )

        $deviceResult.TestResults.NetworkConnectivity = @{}
        foreach ($endpoint in $azureEndpoints) {
            Write-Host "   Testing connectivity to $($endpoint.Name)..."
            try {
                if ($isLocalMachine) {
                    # Use .NET TcpClient for completely silent network testing with proper cleanup
                    $result = $false
                    $tcpClient = $null
                    try {
                        $tcpClient = New-Object System.Net.Sockets.TcpClient
                        $tcpClient.ReceiveTimeout = 3000  # Reduced timeout
                        $tcpClient.SendTimeout = 3000     # Reduced timeout

                        # Use async connect with timeout
                        $connectTask = $tcpClient.BeginConnect($endpoint.Url, $endpoint.Port, $null, $null)
                        $success = $connectTask.AsyncWaitHandle.WaitOne(3000, $false)  # 3 second timeout

                        if ($success) {
                            try {
                                $tcpClient.EndConnect($connectTask)
                                $result = $tcpClient.Connected
                            } catch {
                                $result = $false
                            }
                        } else {
                            $result = $false
                        }
                    } catch {
                        $result = $false
                    } finally {
                        # Ensure proper cleanup
                        if ($tcpClient) {
                            try {
                                if ($tcpClient.Connected) {
                                    $tcpClient.Close()
                                }
                                $tcpClient.Dispose()
                            } catch {
                                # Ignore cleanup errors
                            }
                        }
                    }
                } else {
                    $result = $false
                    $deviceResult.Warnings += "Remote network testing not implemented for $($endpoint.Name)"
                }

                if ($result) {
                    Write-Host "     [OK] $($endpoint.Url):$($endpoint.Port) - Reachable" -ForegroundColor Green
                    $deviceResult.TestResults.NetworkConnectivity[$endpoint.Url] = @{
                        Status = "Pass"
                        Url = $endpoint.Url
                        Port = $endpoint.Port
                        Name = $endpoint.Name
                        Message = "Endpoint reachable"
                    }
                    "[OK] Network: $($endpoint.Name) ($($endpoint.Url):$($endpoint.Port)) - REACHABLE" | Out-File -FilePath $script:globalLogFile -Append
                } elseif ($isLocalMachine) {
                    Write-Host "     [FAIL] $($endpoint.Url):$($endpoint.Port) - Not reachable" -ForegroundColor Green
                    $deviceResult.TestResults.NetworkConnectivity[$endpoint.Url] = @{
                        Status = "Fail"
                        Url = $endpoint.Url
                        Port = $endpoint.Port
                        Name = $endpoint.Name
                        Message = "Endpoint not reachable"
                    }
                    $deviceResult.Errors += "$($endpoint.Name) endpoint not reachable"
                    $deviceResult.Recommendations += "Check network connectivity and firewall rules for $($endpoint.Url):$($endpoint.Port)"
                    "[FAIL] Network: $($endpoint.Name) ($($endpoint.Url):$($endpoint.Port)) - NOT REACHABLE" | Out-File -FilePath $script:globalLogFile -Append
                    "  Recommendation: Check network connectivity and firewall rules" | Out-File -FilePath $script:globalLogFile -Append
                } else {
                    $deviceResult.TestResults.NetworkConnectivity[$endpoint.Url] = @{
                        Status = "Warning"
                        Url = $endpoint.Url
                        Port = $endpoint.Port
                        Name = $endpoint.Name
                        Message = "Remote testing not implemented"
                    }
                    "[WARN] Network: $($endpoint.Name) ($($endpoint.Url):$($endpoint.Port)) - Unknown (Remote testing not implemented)" | Out-File -FilePath $script:globalLogFile -Append
                }
            } catch {
                Write-Host "     [FAIL] $($endpoint.Url):$($endpoint.Port) - Connection failed" -ForegroundColor Green
                $deviceResult.TestResults.NetworkConnectivity[$endpoint.Url] = @{
                    Status = "Error"
                    Url = $endpoint.Url
                    Port = $endpoint.Port
                    Name = $endpoint.Name
                    Message = $_.Exception.Message
                }
                $deviceResult.Errors += "Network test failed for $($endpoint.Name): $($_.Exception.Message)"
                "[FAIL] Network Test Failed: $($endpoint.Name) ($($endpoint.Url):$($endpoint.Port)) - $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
            }
        }

        "" | Out-File -FilePath $script:globalLogFile -Append

        # Determine overall device status
        $hasErrors = $deviceResult.Errors.Count -gt 0
        $hasWarnings = $deviceResult.Warnings.Count -gt 0

        Write-Host ""

        if ($hasErrors) {
            $deviceResult.OverallStatus = "Not Ready"
            Write-Host " DEVICE STATUS: NOT READY FOR AZURE ARC"
        } elseif ($hasWarnings) {
            $deviceResult.OverallStatus = "Ready with Warnings"
            Write-Host " DEVICE STATUS: READY WITH WARNINGS"
        } else {
            $deviceResult.OverallStatus = "Ready"
            Write-Host " DEVICE STATUS: READY FOR AZURE ARC"
        }

        Write-Host ""

        # Log device summary
        "DEVICE ASSESSMENT SUMMARY" | Out-File -FilePath $script:globalLogFile -Append
        ("-" * 50) | Out-File -FilePath $script:globalLogFile -Append
        "Overall Status: $($deviceResult.OverallStatus)" | Out-File -FilePath $script:globalLogFile -Append
        "Test Completed: $(Get-Date)" | Out-File -FilePath $script:globalLogFile -Append
        "" | Out-File -FilePath $script:globalLogFile -Append

        if ($deviceResult.Errors.Count -gt 0) {
            "CRITICAL ISSUES ($($deviceResult.Errors.Count)):" | Out-File -FilePath $script:globalLogFile -Append
            $deviceResult.Errors | ForEach-Object { "  [FAIL] $_" | Out-File -FilePath $script:globalLogFile -Append }
            "" | Out-File -FilePath $script:globalLogFile -Append
        }

        if ($deviceResult.Warnings.Count -gt 0) {
            "WARNINGS ($($deviceResult.Warnings.Count)):" | Out-File -FilePath $script:globalLogFile -Append
            $deviceResult.Warnings | ForEach-Object { "  [WARN] $_" | Out-File -FilePath $script:globalLogFile -Append }
            "" | Out-File -FilePath $script:globalLogFile -Append
        }

        if ($deviceResult.Recommendations.Count -gt 0) {
            "RECOMMENDATIONS ($($deviceResult.Recommendations.Count)):" | Out-File -FilePath $script:globalLogFile -Append
            $deviceResult.Recommendations | ForEach-Object { "  => $_" | Out-File -FilePath $script:globalLogFile -Append }
            "" | Out-File -FilePath $script:globalLogFile -Append
        }

        # Store device result
        $deviceResults[$deviceName] = $deviceResult

        # Add overall recommendations
        if ($hasErrors) {
            $overallRecommendations += "Device '$deviceName' has critical issues that must be resolved before Azure Arc deployment"
        } elseif ($hasWarnings) {
            $overallRecommendations += "Device '$deviceName' has warnings that should be addressed for optimal Azure Arc performance"
        }

        Write-Host ""
        } # End of device loop

        # Step 6: Final Summary
        Write-Host ""
        Write-Host ("=" * 80)
        Write-Host " AZURE ARC PREREQUISITES TESTING COMPLETE"
        Write-Host ("=" * 80)
        Write-Host ""

        # Log final summary header
        ("=" * 100) | Out-File -FilePath $script:globalLogFile -Append
        "FINAL TESTING SUMMARY" | Out-File -FilePath $script:globalLogFile -Append
        ("=" * 100) | Out-File -FilePath $script:globalLogFile -Append
        "Completed: $(Get-Date)" | Out-File -FilePath $script:globalLogFile -Append
        "Total Devices Tested: $($deviceResults.Count)" | Out-File -FilePath $script:globalLogFile -Append
        "" | Out-File -FilePath $script:globalLogFile -Append

        # Display device summary
        Write-Host " DEVICE READINESS SUMMARY:" -ForegroundColor Yellow
        Write-Host ""

        $readyDevices = 0
        $readyWithWarningsDevices = 0
        $notReadyDevices = 0

        "DEVICE READINESS SUMMARY" | Out-File -FilePath $script:globalLogFile -Append
        ("-" * 50) | Out-File -FilePath $script:globalLogFile -Append

        foreach ($device in $deviceResults.Keys) {
            $result = $deviceResults[$device]
            $status = $result.OverallStatus
            $errorCount = $result.Errors.Count
            $warningCount = $result.Warnings.Count

            switch ($status) {
                "Ready" {
                    Write-Host "   [OK] $device - READY FOR AZURE ARC" -ForegroundColor Green
                    $readyDevices++
                    "$device - READY FOR AZURE ARC" | Out-File -FilePath $script:globalLogFile -Append
                }
                "Ready with Warnings" {
                    Write-Host "   [WARN] $device - READY WITH WARNINGS ($warningCount warnings)" -ForegroundColor Green
                    $readyWithWarningsDevices++
                    "$device - READY WITH WARNINGS ($warningCount warnings)" | Out-File -FilePath $script:globalLogFile -Append
                }
                "Not Ready" {
                    Write-Host "   [FAIL] $device - NOT READY ($errorCount errors, $warningCount warnings)" -ForegroundColor Green
                    $notReadyDevices++
                    "$device - NOT READY ($errorCount errors, $warningCount warnings)" | Out-File -FilePath $script:globalLogFile -Append
                }
            }
        }

        Write-Host ""
        Write-Host " OVERALL STATISTICS:" -ForegroundColor Yellow
        Write-Host "   Ready: $readyDevices device(s)"
        Write-Host "   Ready with Warnings: $readyWithWarningsDevices device(s)"
        Write-Host "   Not Ready: $notReadyDevices device(s)"
        Write-Host ""

        "" | Out-File -FilePath $script:globalLogFile -Append
        "OVERALL STATISTICS" | Out-File -FilePath $script:globalLogFile -Append
        ("-" * 20) | Out-File -FilePath $script:globalLogFile -Append
        "Ready: $readyDevices device(s)" | Out-File -FilePath $script:globalLogFile -Append
        "Ready with Warnings: $readyWithWarningsDevices device(s)" | Out-File -FilePath $script:globalLogFile -Append
        "Not Ready: $notReadyDevices device(s)" | Out-File -FilePath $script:globalLogFile -Append
        "" | Out-File -FilePath $script:globalLogFile -Append

        # Show Azure authentication status
        if ($script:azureLoginCompleted) {
            Write-Host " AZURE INTEGRATION:" -ForegroundColor Yellow
            Write-Host "   [OK] Azure authentication completed" -ForegroundColor Green
            Write-Host "   [OK] Resource providers processed" -ForegroundColor Green
            "Azure authentication: Completed" | Out-File -FilePath $script:globalLogFile -Append
            "Resource providers: Processed" | Out-File -FilePath $script:globalLogFile -Append
        } else {
            Write-Host " AZURE INTEGRATION:" -ForegroundColor Yellow
            Write-Host "   [WARN] Azure authentication skipped" -ForegroundColor Green
            "Azure authentication: Skipped" | Out-File -FilePath $script:globalLogFile -Append
        }

        Write-Host ""
        Write-Host " FILES CREATED:" -ForegroundColor Yellow
        Write-Host "   Log file: $script:globalLogFile"
        if ($DeviceListPath) {
            Write-Host "   Device list: $DeviceListPath"
        }

        Write-Host ""
        Write-Host " NEXT STEPS:" -ForegroundColor Yellow
        if ($notReadyDevices -gt 0) {
            Write-Host "   1. Address critical issues on devices marked as 'Not Ready'"
            Write-Host "   2. Review detailed recommendations in the log file"
            Write-Host "   3. Re-run prerequisites testing after resolving issues"
        } elseif ($readyWithWarningsDevices -gt 0) {
            Write-Host "   1. Review warnings in the log file for optimal performance"
            Write-Host "   2. Proceed with Azure Arc device deployment (Option 2)"
            Write-Host "   3. Monitor devices during deployment process"
        } else {
            Write-Host "   1. All devices are ready for Azure Arc deployment"
            Write-Host "   2. Proceed with Azure Arc device deployment (Option 2)"
            Write-Host "   3. Use the device list file for bulk operations"
        }
        Write-Host ""

        # Log final next steps
        "" | Out-File -FilePath $script:globalLogFile -Append
        "NEXT STEPS RECOMMENDATIONS" | Out-File -FilePath $script:globalLogFile -Append
        ("-" * 30) | Out-File -FilePath $script:globalLogFile -Append

        if ($overallRecommendations.Count -gt 0) {
            "PRIORITY ACTIONS:" | Out-File -FilePath $script:globalLogFile -Append
            $overallRecommendations | ForEach-Object { "  => $_" | Out-File -FilePath $script:globalLogFile -Append }
            "" | Out-File -FilePath $script:globalLogFile -Append
        }

        if ($notReadyDevices -gt 0) {
            "Critical: Address issues on $notReadyDevices device(s) before Azure Arc deployment" | Out-File -FilePath $script:globalLogFile -Append
        } elseif ($readyWithWarningsDevices -gt 0) {
            "Recommended: Review warnings for optimal Azure Arc performance" | Out-File -FilePath $script:globalLogFile -Append
        } else {
            "All devices ready: Proceed with Azure Arc deployment" | Out-File -FilePath $script:globalLogFile -Append
        }

        "" | Out-File -FilePath $script:globalLogFile -Append
        "Log file location: $script:globalLogFile" | Out-File -FilePath $script:globalLogFile -Append
        "Report generated: $(Get-Date)" | Out-File -FilePath $script:globalLogFile -Append

        # Ensure all background processes are complete
        Start-Sleep -Milliseconds 500

        # Clean up any remaining background jobs or processes
        Get-Job -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue

        # Force garbage collection to clean up network connections
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()

        # Additional delay to ensure all network operations complete
        Start-Sleep -Milliseconds 500

        return $true

    } catch {
        Write-Host ""
        Write-Host " [FAIL] PREREQUISITES TESTING FAILED" -ForegroundColor Green
        Write-Host "   Error: $($_.Exception.Message)"
        Write-Host ""
        Write-Host " FILES CREATED:" -ForegroundColor Yellow
        Write-Host "   Log file: $script:globalLogFile"
        Write-Host ""

        # Log error
        "Prerequisites testing failed: $(Get-Date)" | Out-File -FilePath $script:globalLogFile -Append
        "Error: $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append

        # Ensure all background processes are complete
        Start-Sleep -Milliseconds 500

        return $false
    }
}







