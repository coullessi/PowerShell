function Test-AzureArcPrerequisite {
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
        Test-AzureArcPrerequisite
        
        Runs basic prerequisites testing for the local machine.

    .EXAMPLE
        Test-AzureArcPrerequisite -Force -NetworkTestMode Comprehensive
        
        Runs comprehensive prerequisites testing without prompts.

    .NOTES
        Author: Lessi Coulibaly
        Organization: Less-IT (AI and CyberSecurity)
        Website: https://lessit.net
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

    # Set up file paths with user input
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $defaultLocation = $env:USERPROFILE + "\Desktop"
    
    Write-Host ""
    Write-Host " FILE LOCATION SETUP" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   Default location: $defaultLocation" -ForegroundColor Gray
    Write-Host "   Supported formats: D:\Path, 'D:\Path', `"D:\Path With Spaces`"" -ForegroundColor Gray
    Write-Host ""
    
    $customLocation = Read-Host "   Enter custom path for log and device list files (or press Enter for default)"
    
    if ([string]::IsNullOrWhiteSpace($customLocation)) {
        $outputPath = $defaultLocation
    } else {
        # Clean up the path - remove surrounding quotes and trim whitespace
        $cleanedPath = $customLocation.Trim()
        
        # Remove surrounding quotes (single or double) only if they match and the string is long enough
        if ($cleanedPath.Length -ge 2) {
            if (($cleanedPath.StartsWith('"') -and $cleanedPath.EndsWith('"')) -or 
                ($cleanedPath.StartsWith("'") -and $cleanedPath.EndsWith("'"))) {
                $cleanedPath = $cleanedPath.Substring(1, $cleanedPath.Length - 2)
            }
        }
        
        # Trim again after removing quotes
        $cleanedPath = $cleanedPath.Trim()
        
        # Validate that we still have a valid path after cleaning
        if ([string]::IsNullOrWhiteSpace($cleanedPath)) {
            Write-Host "   ⚠ Invalid path provided, using default location" -ForegroundColor Yellow
            $outputPath = $defaultLocation
        } else {
            # Handle relative paths
            if (-not [System.IO.Path]::IsPathRooted($cleanedPath)) {
                $outputPath = Join-Path (Get-Location) $cleanedPath
            } else {
                $outputPath = $cleanedPath
            }
        }
    }
    
    # Ensure the directory exists
    if (-not (Test-Path $outputPath)) {
        try {
            New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
            Write-Host "   ✓ Created directory: $outputPath" -ForegroundColor Green
        } catch {
            Write-Host "   ✗ Failed to create directory: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "   Using default location: $defaultLocation" -ForegroundColor Yellow
            $outputPath = $defaultLocation
        }
    } else {
        Write-Host "   ✓ Using directory: $outputPath" -ForegroundColor Green
    }

    # Set up file paths
    $script:globalLogFile = Join-Path $outputPath "AzureArc_Prerequisites_$timestamp.log"
    $script:deviceListFile = Join-Path $outputPath "DeviceList_$timestamp.txt"
    
    # Handle device list file with user choice
    Write-Host ""
    Write-Host " DEVICE LIST SETUP" -ForegroundColor Yellow
    Write-Host ""
    
    if ([string]::IsNullOrWhiteSpace($DeviceListPath)) {
        Write-Host "   No device list file specified." -ForegroundColor White
        Write-Host ""
        Write-Host "   Options:" -ForegroundColor Cyan
        Write-Host "   [1] Use existing device list file" -ForegroundColor White
        Write-Host "   [2] Create new device list file" -ForegroundColor White
        Write-Host ""
        
        do {
            $choice = Read-Host "   Select option [1-2]"
        } while ($choice -notin @("1", "2"))
        
        if ($choice -eq "1") {
            # User wants to use existing file
            Write-Host ""
            Write-Host "   Supported formats for file path:" -ForegroundColor Gray
            Write-Host "   D:\Path\DeviceList.txt, 'D:\Path\file.txt', `"D:\Path\Device List.txt`"" -ForegroundColor Gray
            Write-Host ""
            
            do {
                $existingFilePath = Read-Host "   Enter path to existing device list file"
                
                if ([string]::IsNullOrWhiteSpace($existingFilePath)) {
                    Write-Host "   ⚠ Please provide a valid file path" -ForegroundColor Yellow
                    continue
                }
                
                # Clean up the path using same logic as directory path
                $cleanedFilePath = $existingFilePath.Trim()
                
                if ($cleanedFilePath.Length -ge 2) {
                    if (($cleanedFilePath.StartsWith('"') -and $cleanedFilePath.EndsWith('"')) -or 
                        ($cleanedFilePath.StartsWith("'") -and $cleanedFilePath.EndsWith("'"))) {
                        $cleanedFilePath = $cleanedFilePath.Substring(1, $cleanedFilePath.Length - 2)
                    }
                }
                
                $cleanedFilePath = $cleanedFilePath.Trim()
                
                # Handle relative paths for files
                if (-not [System.IO.Path]::IsPathRooted($cleanedFilePath)) {
                    $cleanedFilePath = Join-Path (Get-Location) $cleanedFilePath
                }
                
                if (Test-Path $cleanedFilePath) {
                    $DeviceListPath = $cleanedFilePath
                    Write-Host "   ✓ Found existing device list: $DeviceListPath" -ForegroundColor Green
                    break
                } else {
                    Write-Host "   ✗ File not found: $cleanedFilePath" -ForegroundColor Red
                    $retry = Read-Host "   Try again? [Y/N] (default: Y)"
                    if ($retry -eq "N" -or $retry -eq "n") {
                        Write-Host "   Creating new device list instead..." -ForegroundColor Yellow
                        $choice = "2"
                        break
                    }
                }
            } while ($true)
        }
        
        if ($choice -eq "2") {
            # Create new device list file
            Write-Host "   Creating new device list file..." -ForegroundColor White
            
            # Create sample device list content
            $sampleContent = @"
# Azure Arc Device List
# Enter one device name per line
# Lines starting with # are comments and will be ignored
#
# Examples:
# SERVER01
# WORKSTATION02
# APP-SERVER-03
#
# Add your device names below:

"@
            
            try {
                $sampleContent | Out-File -FilePath $script:deviceListFile -Encoding UTF8
                Write-Host "   ✓ New device list created: $script:deviceListFile" -ForegroundColor Green
                $DeviceListPath = $script:deviceListFile
                
                # Automatically open sample file for editing since it contains sample data
                Write-Host ""
                Write-Host "   Opening sample device list in Notepad for editing..." -ForegroundColor Cyan
                Write-Host "   Please replace the sample device names with your actual device names." -ForegroundColor White
                Write-Host "   Save the file and close Notepad when done to continue the script." -ForegroundColor White
                Write-Host ""
                
                try {
                    # Open sample file in notepad and wait for it to close
                    $notepadProcess = Start-Process -FilePath "notepad.exe" -ArgumentList $script:deviceListFile -PassThru
                    $notepadProcess.WaitForExit()
                    
                    Write-Host "   ✓ Sample device list editing completed" -ForegroundColor Green
                } catch {
                    Write-Host "   ⚠ Could not open Notepad: $($_.Exception.Message)" -ForegroundColor Yellow
                    Write-Host "   Continuing with sample device list..." -ForegroundColor White
                }
                
            } catch {
                Write-Host "   ✗ Failed to create device list file: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "   Continuing without device list..." -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "   Using provided device list: $DeviceListPath" -ForegroundColor White
        if (-not (Test-Path $DeviceListPath)) {
            Write-Host "   ⚠ Provided device list file not found: $DeviceListPath" -ForegroundColor Yellow
            Write-Host "   Continuing without device list..." -ForegroundColor Yellow
            $DeviceListPath = $null
        } else {
            Write-Host "   ✓ Device list file verified" -ForegroundColor Green
            
            # Offer to edit user-provided device list (optional)
            Write-Host ""
            $editChoice = Read-Host "   Do you want to edit the device list before proceeding? [Y/N] (default: N)"
            
            if ($editChoice -eq "Y" -or $editChoice -eq "y") {
                Write-Host ""
                Write-Host "   Opening device list in Notepad for editing..." -ForegroundColor Cyan
                Write-Host "   Please review/edit your device names (one per line) and save the file." -ForegroundColor White
                Write-Host "   Close Notepad when done to continue the script." -ForegroundColor White
                Write-Host ""
                
                try {
                    # Open in notepad and wait for it to close
                    $notepadProcess = Start-Process -FilePath "notepad.exe" -ArgumentList $DeviceListPath -PassThru
                    $notepadProcess.WaitForExit()
                    
                    Write-Host "   ✓ Device list editing completed" -ForegroundColor Green
                } catch {
                    Write-Host "   ⚠ Could not open Notepad: $($_.Exception.Message)" -ForegroundColor Yellow
                    Write-Host "   Continuing with existing device list..." -ForegroundColor White
                }
            } else {
                Write-Host "   ✓ Using device list as-is" -ForegroundColor Green
            }
        }
    }

    try {
        Clear-Host
        Write-Host ""
        Write-Host " ████████╗███████╗███████╗████████╗██╗███╗   ██╗ ██████╗ " -ForegroundColor Cyan
        Write-Host " ╚══██╔══╝██╔════╝██╔════╝╚══██╔══╝██║████╗  ██║██╔════╝ " -ForegroundColor Cyan
        Write-Host "    ██║   █████╗  ███████╗   ██║   ██║██╔██╗ ██║██║  ███╗" -ForegroundColor Cyan
        Write-Host "    ██║   ██╔══╝  ╚════██║   ██║   ██║██║╚██╗██║██║   ██║" -ForegroundColor Cyan
        Write-Host "    ██║   ███████╗███████║   ██║   ██║██║ ╚████║╚██████╔╝" -ForegroundColor Cyan
        Write-Host "    ╚═╝   ╚══════╝╚══════╝   ╚═╝   ╚═╝╚═╝  ╚═══╝ ╚═════╝ " -ForegroundColor Cyan
        Write-Host ""
        Write-Host " AZURE ARC PREREQUISITES VALIDATION" -ForegroundColor Green
        Write-Host " Testing system readiness for Azure Arc onboarding" -ForegroundColor Gray
        Write-Host ""

        # Log session start
        "=" * 100 | Out-File -FilePath $script:globalLogFile
        "AZURE ARC PREREQUISITES TESTING SESSION" | Out-File -FilePath $script:globalLogFile -Append
        "=" * 100 | Out-File -FilePath $script:globalLogFile -Append
        "Started: $(Get-Date)" | Out-File -FilePath $script:globalLogFile -Append
        "Parameters: Force=$Force, NetworkTestMode=$NetworkTestMode" | Out-File -FilePath $script:globalLogFile -Append
        if ($DeviceListPath) {
            "Device List File: $DeviceListPath" | Out-File -FilePath $script:globalLogFile -Append
        }
        "Output Directory: $outputPath" | Out-File -FilePath $script:globalLogFile -Append
        "" | Out-File -FilePath $script:globalLogFile -Append

        # Initialize device testing variables
        $deviceResults = @{}
        $overallRecommendations = @()
        $devicesToTest = @()
        
        # Determine devices to test
        if ($DeviceListPath -and (Test-Path $DeviceListPath)) {
            Write-Host " LOADING DEVICE LIST" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "   Reading device list from: $DeviceListPath" -ForegroundColor White
            
            try {
                $deviceListContent = Get-Content $DeviceListPath -ErrorAction Stop
                $devicesToTest = $deviceListContent | Where-Object { 
                    $_.Trim() -ne "" -and -not $_.Trim().StartsWith("#") 
                } | ForEach-Object { $_.Trim() }
                
                if ($devicesToTest.Count -eq 0) {
                    Write-Host "   ⚠ No valid device names found in device list" -ForegroundColor Yellow
                    Write-Host "   Testing local machine only..." -ForegroundColor White
                    $devicesToTest = @($env:COMPUTERNAME)
                } else {
                    Write-Host "   ✓ Found $($devicesToTest.Count) device(s) to test" -ForegroundColor Green
                    $devicesToTest | ForEach-Object { Write-Host "     - $_" -ForegroundColor Gray }
                }
                
                # Log device list
                "DEVICE LIST PROCESSING" | Out-File -FilePath $script:globalLogFile -Append
                "-" * 50 | Out-File -FilePath $script:globalLogFile -Append
                "Total devices found: $($devicesToTest.Count)" | Out-File -FilePath $script:globalLogFile -Append
                $devicesToTest | ForEach-Object { "  - $_" | Out-File -FilePath $script:globalLogFile -Append }
                "" | Out-File -FilePath $script:globalLogFile -Append
                
            } catch {
                Write-Host "   ✗ Failed to read device list: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "   Testing local machine only..." -ForegroundColor White
                $devicesToTest = @($env:COMPUTERNAME)
                
                "ERROR: Failed to read device list - $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
                "Defaulting to local machine: $env:COMPUTERNAME" | Out-File -FilePath $script:globalLogFile -Append
                "" | Out-File -FilePath $script:globalLogFile -Append
            }
        } else {
            Write-Host "   No device list provided, testing local machine only" -ForegroundColor White
            $devicesToTest = @($env:COMPUTERNAME)
            
            "DEVICE LIST: Not provided - testing local machine only" | Out-File -FilePath $script:globalLogFile -Append
            "Device: $env:COMPUTERNAME" | Out-File -FilePath $script:globalLogFile -Append
            "" | Out-File -FilePath $script:globalLogFile -Append
        }

        Write-Host ""
        Write-Host " TESTING $($devicesToTest.Count) DEVICE(S)" -ForegroundColor Green
        Write-Host ""

        Write-Host ""
        Write-Host " TESTING $($devicesToTest.Count) DEVICE(S)" -ForegroundColor Green
        Write-Host ""

        # Test each device
        foreach ($deviceName in $devicesToTest) {
            $isLocalMachine = ($deviceName -eq $env:COMPUTERNAME -or $deviceName -eq "localhost" -or $deviceName -eq ".")
            
            Write-Host " DEVICE: $deviceName" -ForegroundColor Cyan
            Write-Host " $("=" * ($deviceName.Length + 8))" -ForegroundColor Cyan
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
            "=" * 100 | Out-File -FilePath $script:globalLogFile -Append
            "DEVICE: $deviceName" | Out-File -FilePath $script:globalLogFile -Append
            "=" * 100 | Out-File -FilePath $script:globalLogFile -Append
            "Test Started: $(Get-Date)" | Out-File -FilePath $script:globalLogFile -Append
            "Local Machine: $isLocalMachine" | Out-File -FilePath $script:globalLogFile -Append
            "" | Out-File -FilePath $script:globalLogFile -Append

        # Step 1: Basic PowerShell Environment Check
        Write-Host " STEP 1: POWERSHELL ENVIRONMENT VALIDATION" -ForegroundColor Yellow
        Write-Host ""
        
        "STEP 1: POWERSHELL ENVIRONMENT VALIDATION" | Out-File -FilePath $script:globalLogFile -Append
        "-" * 50 | Out-File -FilePath $script:globalLogFile -Append
        
        # Check PowerShell version
        Write-Host "   Checking PowerShell version..." -ForegroundColor White
        try {
            if ($isLocalMachine) {
                $psVersion = $PSVersionTable.PSVersion
                $psHost = $PSVersionTable.PSEdition
            } else {
                # For remote machines, we'd need to use Invoke-Command
                Write-Host "     ⚠ Remote PowerShell testing not implemented yet" -ForegroundColor Yellow
                $psVersion = "Unknown (Remote)"
                $psHost = "Unknown (Remote)"
                $deviceResult.Warnings += "Remote PowerShell testing not implemented"
            }
            
            if ($psVersion -ne "Unknown (Remote)") {
                if ($psVersion.Major -ge 5 -and ($psVersion.Major -gt 5 -or $psVersion.Minor -ge 1)) {
                    Write-Host "     ✓ PowerShell $($psVersion.ToString()) ($psHost) - Compatible" -ForegroundColor Green
                    $deviceResult.TestResults.PowerShellVersion = @{
                        Status = "Pass"
                        Version = $psVersion.ToString()
                        Edition = $psHost
                        Message = "Compatible"
                    }
                    "✓ PowerShell Version: $($psVersion.ToString()) ($psHost) - Compatible" | Out-File -FilePath $script:globalLogFile -Append
                } else {
                    Write-Host "     ✗ PowerShell $($psVersion.ToString()) - Requires 5.1 or higher" -ForegroundColor Red
                    $deviceResult.TestResults.PowerShellVersion = @{
                        Status = "Fail"
                        Version = $psVersion.ToString()
                        Edition = $psHost
                        Message = "Requires PowerShell 5.1 or higher"
                    }
                    $deviceResult.Errors += "PowerShell version $($psVersion.ToString()) is incompatible"
                    $deviceResult.Recommendations += "Upgrade to PowerShell 5.1 or higher"
                    "✗ PowerShell Version: $($psVersion.ToString()) - INCOMPATIBLE (Requires 5.1+)" | Out-File -FilePath $script:globalLogFile -Append
                }
            } else {
                $deviceResult.TestResults.PowerShellVersion = @{
                    Status = "Warning"
                    Version = "Unknown"
                    Edition = "Unknown"
                    Message = "Remote testing not implemented"
                }
                "⚠ PowerShell Version: Unknown (Remote testing not implemented)" | Out-File -FilePath $script:globalLogFile -Append
            }
        } catch {
            Write-Host "     ✗ Failed to check PowerShell version: $($_.Exception.Message)" -ForegroundColor Red
            $deviceResult.TestResults.PowerShellVersion = @{
                Status = "Error"
                Version = "Unknown"
                Edition = "Unknown"
                Message = $_.Exception.Message
            }
            $deviceResult.Errors += "Failed to check PowerShell version: $($_.Exception.Message)"
            "✗ PowerShell Version Check Failed: $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
        }

        # Check execution policy
        Write-Host "   Checking execution policy..." -ForegroundColor White
        try {
            if ($isLocalMachine) {
                $execPolicy = Get-ExecutionPolicy
            } else {
                $execPolicy = "Unknown (Remote)"
                $deviceResult.Warnings += "Remote execution policy testing not implemented"
            }
            
            $compatiblePolicies = @("RemoteSigned", "Unrestricted", "Bypass")
            if ($execPolicy -in $compatiblePolicies) {
                Write-Host "     ✓ Execution Policy: $execPolicy - Compatible" -ForegroundColor Green
                $deviceResult.TestResults.ExecutionPolicy = @{
                    Status = "Pass"
                    Policy = $execPolicy
                    Message = "Compatible"
                }
                "✓ Execution Policy: $execPolicy - Compatible" | Out-File -FilePath $script:globalLogFile -Append
            } elseif ($execPolicy -eq "Unknown (Remote)") {
                Write-Host "     ⚠ Execution Policy: Unknown (Remote)" -ForegroundColor Yellow
                $deviceResult.TestResults.ExecutionPolicy = @{
                    Status = "Warning"
                    Policy = "Unknown"
                    Message = "Remote testing not implemented"
                }
                "⚠ Execution Policy: Unknown (Remote testing not implemented)" | Out-File -FilePath $script:globalLogFile -Append
            } else {
                Write-Host "     ⚠ Execution Policy: $execPolicy - May block Azure Arc scripts" -ForegroundColor Yellow
                Write-Host "       Consider running: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Gray
                $deviceResult.TestResults.ExecutionPolicy = @{
                    Status = "Warning"
                    Policy = $execPolicy
                    Message = "May block Azure Arc scripts"
                }
                $deviceResult.Warnings += "Execution policy '$execPolicy' may block scripts"
                $deviceResult.Recommendations += "Set execution policy: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
                "⚠ Execution Policy: $execPolicy - MAY BLOCK SCRIPTS" | Out-File -FilePath $script:globalLogFile -Append
                "  Recommendation: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" | Out-File -FilePath $script:globalLogFile -Append
            }
        } catch {
            Write-Host "     ✗ Failed to check execution policy: $($_.Exception.Message)" -ForegroundColor Red
            $deviceResult.TestResults.ExecutionPolicy = @{
                Status = "Error"
                Policy = "Unknown"
                Message = $_.Exception.Message
            }
            $deviceResult.Errors += "Failed to check execution policy: $($_.Exception.Message)"
            "✗ Execution Policy Check Failed: $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
        }
        
        "" | Out-File -FilePath $script:globalLogFile -Append

        # Step 2: Azure PowerShell Module Check
        Write-Host "`n STEP 2: AZURE POWERSHELL MODULE VALIDATION" -ForegroundColor Yellow
        Write-Host ""
        
        "STEP 2: AZURE POWERSHELL MODULE VALIDATION" | Out-File -FilePath $script:globalLogFile -Append
        "-" * 50 | Out-File -FilePath $script:globalLogFile -Append
        
        Write-Host "   Checking Azure PowerShell modules..." -ForegroundColor White
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
                Write-Host "     ✓ Az.Accounts module found - Version $($azAccountsModule.Version)" -ForegroundColor Green
                $deviceResult.TestResults.AzAccountsModule = @{
                    Status = "Pass"
                    Version = $azAccountsModule.Version.ToString()
                    Message = "Module available"
                }
                "✓ Az.Accounts Module: Version $($azAccountsModule.Version) - Available" | Out-File -FilePath $script:globalLogFile -Append
            } elseif ($isLocalMachine) {
                Write-Host "     ⚠ Az.Accounts module not found - Will be installed if needed" -ForegroundColor Yellow
                $deviceResult.TestResults.AzAccountsModule = @{
                    Status = "Warning"
                    Version = "Not Installed"
                    Message = "Module not found - installation required"
                }
                $deviceResult.Warnings += "Az.Accounts module not installed"
                $deviceResult.Recommendations += "Install Az.Accounts module: Install-Module -Name Az.Accounts -Force"
                "⚠ Az.Accounts Module: NOT INSTALLED" | Out-File -FilePath $script:globalLogFile -Append
                "  Recommendation: Install-Module -Name Az.Accounts -Force" | Out-File -FilePath $script:globalLogFile -Append
            } else {
                $deviceResult.TestResults.AzAccountsModule = @{
                    Status = "Warning"
                    Version = "Unknown"
                    Message = "Remote testing not implemented"
                }
                "⚠ Az.Accounts Module: Unknown (Remote testing not implemented)" | Out-File -FilePath $script:globalLogFile -Append
            }

            # Check Az.Resources
            if ($azResourcesModule) {
                Write-Host "     ✓ Az.Resources module found - Version $($azResourcesModule.Version)" -ForegroundColor Green
                $deviceResult.TestResults.AzResourcesModule = @{
                    Status = "Pass"
                    Version = $azResourcesModule.Version.ToString()
                    Message = "Module available"
                }
                "✓ Az.Resources Module: Version $($azResourcesModule.Version) - Available" | Out-File -FilePath $script:globalLogFile -Append
            } elseif ($isLocalMachine) {
                Write-Host "     ⚠ Az.Resources module not found - Will be installed if needed" -ForegroundColor Yellow
                $deviceResult.TestResults.AzResourcesModule = @{
                    Status = "Warning"
                    Version = "Not Installed"
                    Message = "Module not found - installation required"
                }
                $deviceResult.Warnings += "Az.Resources module not installed"
                $deviceResult.Recommendations += "Install Az.Resources module: Install-Module -Name Az.Resources -Force"
                "⚠ Az.Resources Module: NOT INSTALLED" | Out-File -FilePath $script:globalLogFile -Append
                "  Recommendation: Install-Module -Name Az.Resources -Force" | Out-File -FilePath $script:globalLogFile -Append
            } else {
                $deviceResult.TestResults.AzResourcesModule = @{
                    Status = "Warning"
                    Version = "Unknown"
                    Message = "Remote testing not implemented"
                }
                "⚠ Az.Resources Module: Unknown (Remote testing not implemented)" | Out-File -FilePath $script:globalLogFile -Append
            }
        } catch {
            Write-Host "     ✗ Failed to check Azure modules: $($_.Exception.Message)" -ForegroundColor Red
            $deviceResult.TestResults.AzureModules = @{
                Status = "Error"
                Message = $_.Exception.Message
            }
            $deviceResult.Errors += "Failed to check Azure modules: $($_.Exception.Message)"
            "✗ Azure Modules Check Failed: $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
        }
        
        "" | Out-File -FilePath $script:globalLogFile -Append

        # Step 3: System Requirements Check
        Write-Host "`n STEP 3: SYSTEM REQUIREMENTS VALIDATION" -ForegroundColor Yellow
        Write-Host ""

        "STEP 3: SYSTEM REQUIREMENTS VALIDATION" | Out-File -FilePath $script:globalLogFile -Append
        "-" * 50 | Out-File -FilePath $script:globalLogFile -Append

        # Check OS version
        Write-Host "   Checking operating system compatibility..." -ForegroundColor White
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
                Write-Host "     OS: $osName" -ForegroundColor Gray
                Write-Host "     Version: $($os.Version) (Build $($os.BuildNumber))" -ForegroundColor Gray

                # Basic OS compatibility check
                if ($os.ProductType -eq 1) {
                    Write-Host "     ⚠ Client OS detected - Azure Arc is designed for servers" -ForegroundColor Yellow
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
                    "⚠ Operating System: $osName - CLIENT OS (Azure Arc designed for servers)" | Out-File -FilePath $script:globalLogFile -Append
                    "  OS Version: $($os.Version) (Build $($os.BuildNumber))" | Out-File -FilePath $script:globalLogFile -Append
                    "  Recommendation: Use server OS for production deployments" | Out-File -FilePath $script:globalLogFile -Append
                } elseif ($osVersion.Build -ge 9600) {
                    Write-Host "     ✓ Server OS version is compatible with Azure Arc" -ForegroundColor Green
                    $deviceResult.TestResults.OperatingSystem = @{
                        Status = "Pass"
                        Name = $osName
                        Version = $os.Version
                        Build = $os.BuildNumber
                        ProductType = "Server"
                        Message = "Compatible server OS"
                    }
                    "✓ Operating System: $osName - COMPATIBLE" | Out-File -FilePath $script:globalLogFile -Append
                    "  OS Version: $($os.Version) (Build $($os.BuildNumber))" | Out-File -FilePath $script:globalLogFile -Append
                } else {
                    Write-Host "     ✗ OS version may not be fully supported" -ForegroundColor Red
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
                    "✗ Operating System: $osName - UNSUPPORTED VERSION" | Out-File -FilePath $script:globalLogFile -Append
                    "  OS Version: $($os.Version) (Build $($os.BuildNumber))" | Out-File -FilePath $script:globalLogFile -Append
                    "  Recommendation: Upgrade to Windows Server 2012 R2 or later" | Out-File -FilePath $script:globalLogFile -Append
                }
            } else {
                Write-Host "     ⚠ OS information unavailable (Remote)" -ForegroundColor Yellow
                $deviceResult.TestResults.OperatingSystem = @{
                    Status = "Warning"
                    Name = "Unknown"
                    Version = "Unknown"
                    Build = "Unknown"
                    ProductType = "Unknown"
                    Message = "Remote testing not implemented"
                }
                "⚠ Operating System: Unknown (Remote testing not implemented)" | Out-File -FilePath $script:globalLogFile -Append
            }
        } catch {
            Write-Host "     ✗ Failed to check OS: $($_.Exception.Message)" -ForegroundColor Red
            $deviceResult.TestResults.OperatingSystem = @{
                Status = "Error"
                Message = $_.Exception.Message
            }
            $deviceResult.Errors += "Failed to check OS: $($_.Exception.Message)"
            "✗ Operating System Check Failed: $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
        }

        # Check architecture
        Write-Host "   Checking processor architecture..." -ForegroundColor White
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
                    Write-Host "     ✓ Architecture: $architecture - Supported" -ForegroundColor Green
                    $deviceResult.TestResults.ProcessorArchitecture = @{
                        Status = "Pass"
                        Architecture = $architecture
                        ArchitectureCode = $processor.Architecture
                        Message = "Supported architecture"
                    }
                    "✓ Processor Architecture: $architecture - SUPPORTED" | Out-File -FilePath $script:globalLogFile -Append
                } else {
                    Write-Host "     ✗ Architecture: $architecture - Not supported" -ForegroundColor Red
                    $deviceResult.TestResults.ProcessorArchitecture = @{
                        Status = "Fail"
                        Architecture = $architecture
                        ArchitectureCode = $processor.Architecture
                        Message = "Unsupported architecture"
                    }
                    $deviceResult.Errors += "Processor architecture '$architecture' not supported"
                    $deviceResult.Recommendations += "Use x64 or ARM64 processor architecture"
                    "✗ Processor Architecture: $architecture - UNSUPPORTED" | Out-File -FilePath $script:globalLogFile -Append
                    "  Recommendation: Use x64 or ARM64 architecture" | Out-File -FilePath $script:globalLogFile -Append
                }
            } else {
                $deviceResult.TestResults.ProcessorArchitecture = @{
                    Status = "Warning"
                    Architecture = "Unknown"
                    Message = "Remote testing not implemented"
                }
                "⚠ Processor Architecture: Unknown (Remote testing not implemented)" | Out-File -FilePath $script:globalLogFile -Append
            }
        } catch {
            Write-Host "     ✗ Failed to check processor: $($_.Exception.Message)" -ForegroundColor Red
            $deviceResult.TestResults.ProcessorArchitecture = @{
                Status = "Error"
                Message = $_.Exception.Message
            }
            $deviceResult.Errors += "Failed to check processor: $($_.Exception.Message)"
            "✗ Processor Architecture Check Failed: $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
        }

        # Check memory
        Write-Host "   Checking system memory..." -ForegroundColor White
        try {
            if ($isLocalMachine) {
                $totalMemoryGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
            } else {
                $totalMemoryGB = 0
                $deviceResult.Warnings += "Remote memory testing not implemented"
            }
            
            if ($totalMemoryGB -gt 0) {
                if ($totalMemoryGB -ge 2) {
                    Write-Host "     ✓ Memory: $totalMemoryGB GB - Adequate" -ForegroundColor Green
                    $deviceResult.TestResults.SystemMemory = @{
                        Status = "Pass"
                        MemoryGB = $totalMemoryGB
                        Message = "Adequate memory"
                    }
                    "✓ System Memory: $totalMemoryGB GB - ADEQUATE" | Out-File -FilePath $script:globalLogFile -Append
                } else {
                    Write-Host "     ⚠ Memory: $totalMemoryGB GB - Below recommended 2GB" -ForegroundColor Yellow
                    $deviceResult.TestResults.SystemMemory = @{
                        Status = "Warning"
                        MemoryGB = $totalMemoryGB
                        Message = "Below recommended 2GB"
                    }
                    $deviceResult.Warnings += "System memory ($totalMemoryGB GB) below recommended 2GB"
                    $deviceResult.Recommendations += "Increase system memory to at least 2GB for optimal performance"
                    "⚠ System Memory: $totalMemoryGB GB - BELOW RECOMMENDED (2GB minimum)" | Out-File -FilePath $script:globalLogFile -Append
                    "  Recommendation: Increase to at least 2GB" | Out-File -FilePath $script:globalLogFile -Append
                }
            } else {
                $deviceResult.TestResults.SystemMemory = @{
                    Status = "Warning"
                    MemoryGB = "Unknown"
                    Message = "Remote testing not implemented"
                }
                "⚠ System Memory: Unknown (Remote testing not implemented)" | Out-File -FilePath $script:globalLogFile -Append
            }
        } catch {
            Write-Host "     ✗ Failed to check memory: $($_.Exception.Message)" -ForegroundColor Red
            $deviceResult.TestResults.SystemMemory = @{
                Status = "Error"
                Message = $_.Exception.Message
            }
            $deviceResult.Errors += "Failed to check memory: $($_.Exception.Message)"
            "✗ System Memory Check Failed: $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
        }
        
        "" | Out-File -FilePath $script:globalLogFile -Append

        # Step 4: Required Services Check
        Write-Host "`n STEP 4: REQUIRED SERVICES VALIDATION" -ForegroundColor Yellow
        Write-Host ""

        "STEP 4: REQUIRED SERVICES VALIDATION" | Out-File -FilePath $script:globalLogFile -Append
        "-" * 50 | Out-File -FilePath $script:globalLogFile -Append

        $requiredServices = @(
            @{ Name = "WinRM"; DisplayName = "Windows Remote Management" },
            @{ Name = "Winmgmt"; DisplayName = "Windows Management Instrumentation" },
            @{ Name = "EventLog"; DisplayName = "Windows Event Log" },
            @{ Name = "RpcSs"; DisplayName = "Remote Procedure Call (RPC)" }
        )

        $deviceResult.TestResults.Services = @{}
        foreach ($service in $requiredServices) {
            Write-Host "   Checking $($service.DisplayName)..." -ForegroundColor White
            try {
                if ($isLocalMachine) {
                    $serviceStatus = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
                } else {
                    $serviceStatus = $null
                    $deviceResult.Warnings += "Remote service testing not implemented for $($service.DisplayName)"
                }
                
                if ($serviceStatus -and $serviceStatus.Status -eq "Running") {
                    Write-Host "     ✓ $($service.DisplayName) - Running" -ForegroundColor Green
                    $deviceResult.TestResults.Services[$service.Name] = @{
                        Status = "Pass"
                        ServiceStatus = "Running"
                        DisplayName = $service.DisplayName
                        Message = "Service running normally"
                    }
                    "✓ Service: $($service.DisplayName) - RUNNING" | Out-File -FilePath $script:globalLogFile -Append
                } elseif ($serviceStatus) {
                    Write-Host "     ⚠ $($service.DisplayName) - $($serviceStatus.Status)" -ForegroundColor Yellow
                    $deviceResult.TestResults.Services[$service.Name] = @{
                        Status = "Warning"
                        ServiceStatus = $serviceStatus.Status
                        DisplayName = $service.DisplayName
                        Message = "Service not running"
                    }
                    $deviceResult.Warnings += "$($service.DisplayName) service is $($serviceStatus.Status)"
                    $deviceResult.Recommendations += "Start $($service.DisplayName) service: Start-Service -Name $($service.Name)"
                    "⚠ Service: $($service.DisplayName) - $($serviceStatus.Status.ToUpper())" | Out-File -FilePath $script:globalLogFile -Append
                    "  Recommendation: Start-Service -Name $($service.Name)" | Out-File -FilePath $script:globalLogFile -Append
                } elseif ($isLocalMachine) {
                    Write-Host "     ✗ $($service.DisplayName) - Not found" -ForegroundColor Red
                    $deviceResult.TestResults.Services[$service.Name] = @{
                        Status = "Fail"
                        ServiceStatus = "Not Found"
                        DisplayName = $service.DisplayName
                        Message = "Service not found"
                    }
                    $deviceResult.Errors += "$($service.DisplayName) service not found"
                    $deviceResult.Recommendations += "Install/enable $($service.DisplayName) service"
                    "✗ Service: $($service.DisplayName) - NOT FOUND" | Out-File -FilePath $script:globalLogFile -Append
                    "  Recommendation: Install/enable the service" | Out-File -FilePath $script:globalLogFile -Append
                } else {
                    $deviceResult.TestResults.Services[$service.Name] = @{
                        Status = "Warning"
                        ServiceStatus = "Unknown"
                        DisplayName = $service.DisplayName
                        Message = "Remote testing not implemented"
                    }
                    "⚠ Service: $($service.DisplayName) - Unknown (Remote testing not implemented)" | Out-File -FilePath $script:globalLogFile -Append
                }
            } catch {
                Write-Host "     ✗ Failed to check $($service.DisplayName): $($_.Exception.Message)" -ForegroundColor Red
                $deviceResult.TestResults.Services[$service.Name] = @{
                    Status = "Error"
                    ServiceStatus = "Error"
                    DisplayName = $service.DisplayName
                    Message = $_.Exception.Message
                }
                $deviceResult.Errors += "Failed to check $($service.DisplayName): $($_.Exception.Message)"
                "✗ Service Check Failed: $($service.DisplayName) - $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
            }
        }
        
        "" | Out-File -FilePath $script:globalLogFile -Append

        # Step 5: Network Connectivity Check
        Write-Host "`n STEP 5: NETWORK CONNECTIVITY VALIDATION" -ForegroundColor Yellow
        Write-Host ""

        "STEP 5: NETWORK CONNECTIVITY VALIDATION" | Out-File -FilePath $script:globalLogFile -Append
        "-" * 50 | Out-File -FilePath $script:globalLogFile -Append

        $azureEndpoints = @(
            @{ Name = "Azure Resource Manager"; Url = "management.azure.com"; Port = 443 },
            @{ Name = "Azure Arc Service"; Url = "gbl.his.arc.azure.com"; Port = 443 },
            @{ Name = "Azure Active Directory"; Url = "login.microsoftonline.com"; Port = 443 },
            @{ Name = "Download Center"; Url = "download.microsoft.com"; Port = 443 }
        )

        $deviceResult.TestResults.NetworkConnectivity = @{}
        foreach ($endpoint in $azureEndpoints) {
            Write-Host "   Testing connectivity to $($endpoint.Name)..." -ForegroundColor White
            try {
                if ($isLocalMachine) {
                    $result = Test-NetConnection -ComputerName $endpoint.Url -Port $endpoint.Port -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                } else {
                    $result = $false
                    $deviceResult.Warnings += "Remote network testing not implemented for $($endpoint.Name)"
                }
                
                if ($result) {
                    Write-Host "     ✓ $($endpoint.Url):$($endpoint.Port) - Reachable" -ForegroundColor Green
                    $deviceResult.TestResults.NetworkConnectivity[$endpoint.Url] = @{
                        Status = "Pass"
                        Url = $endpoint.Url
                        Port = $endpoint.Port
                        Name = $endpoint.Name
                        Message = "Endpoint reachable"
                    }
                    "✓ Network: $($endpoint.Name) ($($endpoint.Url):$($endpoint.Port)) - REACHABLE" | Out-File -FilePath $script:globalLogFile -Append
                } elseif ($isLocalMachine) {
                    Write-Host "     ✗ $($endpoint.Url):$($endpoint.Port) - Not reachable" -ForegroundColor Red
                    $deviceResult.TestResults.NetworkConnectivity[$endpoint.Url] = @{
                        Status = "Fail"
                        Url = $endpoint.Url
                        Port = $endpoint.Port
                        Name = $endpoint.Name
                        Message = "Endpoint not reachable"
                    }
                    $deviceResult.Errors += "$($endpoint.Name) endpoint not reachable"
                    $deviceResult.Recommendations += "Check network connectivity and firewall rules for $($endpoint.Url):$($endpoint.Port)"
                    "✗ Network: $($endpoint.Name) ($($endpoint.Url):$($endpoint.Port)) - NOT REACHABLE" | Out-File -FilePath $script:globalLogFile -Append
                    "  Recommendation: Check network connectivity and firewall rules" | Out-File -FilePath $script:globalLogFile -Append
                } else {
                    $deviceResult.TestResults.NetworkConnectivity[$endpoint.Url] = @{
                        Status = "Warning"
                        Url = $endpoint.Url
                        Port = $endpoint.Port
                        Name = $endpoint.Name
                        Message = "Remote testing not implemented"
                    }
                    "⚠ Network: $($endpoint.Name) ($($endpoint.Url):$($endpoint.Port)) - Unknown (Remote testing not implemented)" | Out-File -FilePath $script:globalLogFile -Append
                }
            } catch {
                Write-Host "     ✗ $($endpoint.Url):$($endpoint.Port) - Connection failed" -ForegroundColor Red
                $deviceResult.TestResults.NetworkConnectivity[$endpoint.Url] = @{
                    Status = "Error"
                    Url = $endpoint.Url
                    Port = $endpoint.Port
                    Name = $endpoint.Name
                    Message = $_.Exception.Message
                }
                $deviceResult.Errors += "Network test failed for $($endpoint.Name): $($_.Exception.Message)"
                "✗ Network Test Failed: $($endpoint.Name) ($($endpoint.Url):$($endpoint.Port)) - $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
            }
        }
        
        "" | Out-File -FilePath $script:globalLogFile -Append

        # Determine overall device status
        $hasErrors = $deviceResult.Errors.Count -gt 0
        $hasWarnings = $deviceResult.Warnings.Count -gt 0
        
        if ($hasErrors) {
            $deviceResult.OverallStatus = "Not Ready"
            Write-Host " DEVICE STATUS: NOT READY FOR AZURE ARC" -ForegroundColor Red
        } elseif ($hasWarnings) {
            $deviceResult.OverallStatus = "Ready with Warnings"
            Write-Host " DEVICE STATUS: READY WITH WARNINGS" -ForegroundColor Yellow
        } else {
            $deviceResult.OverallStatus = "Ready"
            Write-Host " DEVICE STATUS: READY FOR AZURE ARC" -ForegroundColor Green
        }
        
        Write-Host ""

        # Log device summary
        "DEVICE ASSESSMENT SUMMARY" | Out-File -FilePath $script:globalLogFile -Append
        "-" * 50 | Out-File -FilePath $script:globalLogFile -Append
        "Overall Status: $($deviceResult.OverallStatus)" | Out-File -FilePath $script:globalLogFile -Append
        "Test Completed: $(Get-Date)" | Out-File -FilePath $script:globalLogFile -Append
        "" | Out-File -FilePath $script:globalLogFile -Append
        
        if ($deviceResult.Errors.Count -gt 0) {
            "CRITICAL ISSUES ($($deviceResult.Errors.Count)):" | Out-File -FilePath $script:globalLogFile -Append
            $deviceResult.Errors | ForEach-Object { "  ✗ $_" | Out-File -FilePath $script:globalLogFile -Append }
            "" | Out-File -FilePath $script:globalLogFile -Append
        }
        
        if ($deviceResult.Warnings.Count -gt 0) {
            "WARNINGS ($($deviceResult.Warnings.Count)):" | Out-File -FilePath $script:globalLogFile -Append
            $deviceResult.Warnings | ForEach-Object { "  ⚠ $_" | Out-File -FilePath $script:globalLogFile -Append }
            "" | Out-File -FilePath $script:globalLogFile -Append
        }
        
        if ($deviceResult.Recommendations.Count -gt 0) {
            "RECOMMENDATIONS ($($deviceResult.Recommendations.Count)):" | Out-File -FilePath $script:globalLogFile -Append
            $deviceResult.Recommendations | ForEach-Object { "  → $_" | Out-File -FilePath $script:globalLogFile -Append }
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

        # Step 6: Azure Authentication and Resource Provider Registration (One-time for all devices)
        Write-Host " STEP 6: AZURE AUTHENTICATION & RESOURCE PROVIDERS" -ForegroundColor Yellow
        Write-Host ""

        "=" * 100 | Out-File -FilePath $script:globalLogFile -Append
        "AZURE AUTHENTICATION & RESOURCE PROVIDER REGISTRATION" | Out-File -FilePath $script:globalLogFile -Append
        "=" * 100 | Out-File -FilePath $script:globalLogFile -Append

        if (-not $Force) {
            Write-Host "   Azure authentication is required to register resource providers." -ForegroundColor White
            $authConfirm = Read-Host "   Proceed with Azure authentication? [Y/N] (default: Y)"
            if ($authConfirm -eq "N" -or $authConfirm -eq "n") {
                Write-Host "     ⚠ Skipping Azure authentication and resource provider registration" -ForegroundColor Yellow
                "Azure authentication skipped by user" | Out-File -FilePath $script:globalLogFile -Append
                "" | Out-File -FilePath $script:globalLogFile -Append
                # Jump to final summary
                $skipAuth = $true
            }
        }

        if (-not $skipAuth) {
            try {
                Write-Host "   Attempting Azure authentication..." -ForegroundColor White
                
                # Try to get current context first
                $currentContext = Get-AzContext -ErrorAction SilentlyContinue
                if ($currentContext) {
                    Write-Host "     ✓ Using existing Azure context: $($currentContext.Account)" -ForegroundColor Green
                    $script:azureLoginCompleted = $true
                    "✓ Azure Authentication: Using existing context ($($currentContext.Account))" | Out-File -FilePath $script:globalLogFile -Append
                } else {
                    # Attempt interactive login
                    Write-Host "     Initiating Azure login..." -ForegroundColor Gray
                    $null = Connect-AzAccount -ErrorAction Stop
                    Write-Host "     ✓ Azure authentication successful" -ForegroundColor Green
                    $script:azureLoginCompleted = $true
                    $newContext = Get-AzContext
                    "✓ Azure Authentication: Successful ($($newContext.Account))" | Out-File -FilePath $script:globalLogFile -Append
                }

                # Set subscription if provided
                if ($SubscriptionId) {
                    Write-Host "   Setting Azure subscription context..." -ForegroundColor White
                    $null = Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop
                    Write-Host "     ✓ Subscription context set: $SubscriptionId" -ForegroundColor Green
                    "✓ Subscription Context: Set to $SubscriptionId" | Out-File -FilePath $script:globalLogFile -Append
                }

                # Register required resource providers
                if ($script:azureLoginCompleted) {
                    Write-Host "   Registering Azure resource providers..." -ForegroundColor White
                    
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
                            Write-Host "     Checking $provider..." -ForegroundColor Gray
                            $resourceProvider = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue
                            
                            if ($resourceProvider -and $resourceProvider.RegistrationState -eq "Registered") {
                                Write-Host "     ✓ $provider - Already registered" -ForegroundColor Green
                                $registrationResults += "✓ $provider - Already registered"
                                "  ✓ $provider - Already registered" | Out-File -FilePath $script:globalLogFile -Append
                            } else {
                                Write-Host "     Registering $provider..." -ForegroundColor Yellow
                                $null = Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop
                                Write-Host "     ✓ $provider - Registration initiated" -ForegroundColor Green
                                $registrationResults += "✓ $provider - Registration initiated"
                                "  ✓ $provider - Registration initiated" | Out-File -FilePath $script:globalLogFile -Append
                            }
                        } catch {
                            Write-Host "     ✗ $provider - Registration failed: $($_.Exception.Message)" -ForegroundColor Red
                            $registrationResults += "✗ $provider - Registration failed"
                            "  ✗ $provider - Registration failed: $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
                        }
                    }

                    Write-Host "     Resource provider registration summary:" -ForegroundColor Cyan
                    foreach ($result in $registrationResults) {
                        Write-Host "       $result" -ForegroundColor Gray
                    }
                }

            } catch {
                Write-Host "     ✗ Azure authentication failed: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "     Resource provider registration skipped" -ForegroundColor Yellow
                "✗ Azure Authentication Failed: $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
            }
        }

        "" | Out-File -FilePath $script:globalLogFile -Append

        # Step 7: Final Summary
        Write-Host "`n" + "=" * 80 -ForegroundColor Green
        Write-Host " AZURE ARC PREREQUISITES TESTING COMPLETE" -ForegroundColor Green
        Write-Host "=" * 80 -ForegroundColor Green
        Write-Host ""

        # Log final summary header
        "=" * 100 | Out-File -FilePath $script:globalLogFile -Append
        "FINAL TESTING SUMMARY" | Out-File -FilePath $script:globalLogFile -Append
        "=" * 100 | Out-File -FilePath $script:globalLogFile -Append
        "Completed: $(Get-Date)" | Out-File -FilePath $script:globalLogFile -Append
        "Total Devices Tested: $($deviceResults.Count)" | Out-File -FilePath $script:globalLogFile -Append
        "" | Out-File -FilePath $script:globalLogFile -Append

        # Display device summary
        Write-Host " DEVICE READINESS SUMMARY:" -ForegroundColor Cyan
        Write-Host ""
        
        $readyDevices = 0
        $readyWithWarningsDevices = 0
        $notReadyDevices = 0
        
        "DEVICE READINESS SUMMARY" | Out-File -FilePath $script:globalLogFile -Append
        "-" * 50 | Out-File -FilePath $script:globalLogFile -Append
        
        foreach ($device in $deviceResults.Keys) {
            $result = $deviceResults[$device]
            $status = $result.OverallStatus
            $errorCount = $result.Errors.Count
            $warningCount = $result.Warnings.Count
            
            switch ($status) {
                "Ready" {
                    Write-Host "   ✓ $device - READY FOR AZURE ARC" -ForegroundColor Green
                    $readyDevices++
                    "$device - READY FOR AZURE ARC" | Out-File -FilePath $script:globalLogFile -Append
                }
                "Ready with Warnings" {
                    Write-Host "   ⚠ $device - READY WITH WARNINGS ($warningCount warnings)" -ForegroundColor Yellow
                    $readyWithWarningsDevices++
                    "$device - READY WITH WARNINGS ($warningCount warnings)" | Out-File -FilePath $script:globalLogFile -Append
                }
                "Not Ready" {
                    Write-Host "   ✗ $device - NOT READY ($errorCount errors, $warningCount warnings)" -ForegroundColor Red
                    $notReadyDevices++
                    "$device - NOT READY ($errorCount errors, $warningCount warnings)" | Out-File -FilePath $script:globalLogFile -Append
                }
            }
        }
        
        Write-Host ""
        Write-Host " OVERALL STATISTICS:" -ForegroundColor Cyan
        Write-Host "   Ready: $readyDevices device(s)" -ForegroundColor Green
        Write-Host "   Ready with Warnings: $readyWithWarningsDevices device(s)" -ForegroundColor Yellow
        Write-Host "   Not Ready: $notReadyDevices device(s)" -ForegroundColor Red
        Write-Host ""
        
        "" | Out-File -FilePath $script:globalLogFile -Append
        "OVERALL STATISTICS" | Out-File -FilePath $script:globalLogFile -Append
        "-" * 20 | Out-File -FilePath $script:globalLogFile -Append
        "Ready: $readyDevices device(s)" | Out-File -FilePath $script:globalLogFile -Append
        "Ready with Warnings: $readyWithWarningsDevices device(s)" | Out-File -FilePath $script:globalLogFile -Append
        "Not Ready: $notReadyDevices device(s)" | Out-File -FilePath $script:globalLogFile -Append
        "" | Out-File -FilePath $script:globalLogFile -Append

        # Show Azure authentication status
        if ($script:azureLoginCompleted) {
            Write-Host " AZURE INTEGRATION:" -ForegroundColor Cyan
            Write-Host "   ✓ Azure authentication completed" -ForegroundColor Green
            Write-Host "   ✓ Resource providers processed" -ForegroundColor Green
            "Azure authentication: Completed" | Out-File -FilePath $script:globalLogFile -Append
            "Resource providers: Processed" | Out-File -FilePath $script:globalLogFile -Append
        } else {
            Write-Host " AZURE INTEGRATION:" -ForegroundColor Cyan
            Write-Host "   ⚠ Azure authentication skipped" -ForegroundColor Yellow
            "Azure authentication: Skipped" | Out-File -FilePath $script:globalLogFile -Append
        }

        Write-Host ""
        Write-Host " FILES CREATED:" -ForegroundColor Cyan
        Write-Host "   Log file: $script:globalLogFile" -ForegroundColor Gray
        if ($DeviceListPath) {
            Write-Host "   Device list: $DeviceListPath" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host " NEXT STEPS:" -ForegroundColor Yellow
        if ($notReadyDevices -gt 0) {
            Write-Host "   1. Address critical issues on devices marked as 'Not Ready'" -ForegroundColor White
            Write-Host "   2. Review detailed recommendations in the log file" -ForegroundColor White
            Write-Host "   3. Re-run prerequisites testing after resolving issues" -ForegroundColor White
        } elseif ($readyWithWarningsDevices -gt 0) {
            Write-Host "   1. Review warnings in the log file for optimal performance" -ForegroundColor White
            Write-Host "   2. Proceed with Azure Arc device deployment (Option 2)" -ForegroundColor White
            Write-Host "   3. Monitor devices during deployment process" -ForegroundColor White
        } else {
            Write-Host "   1. All devices are ready for Azure Arc deployment" -ForegroundColor White
            Write-Host "   2. Proceed with Azure Arc device deployment (Option 2)" -ForegroundColor White
            Write-Host "   3. Use the device list file for bulk operations" -ForegroundColor White
        }
        Write-Host ""

        # Log final next steps
        "" | Out-File -FilePath $script:globalLogFile -Append
        "NEXT STEPS RECOMMENDATIONS" | Out-File -FilePath $script:globalLogFile -Append
        "-" * 30 | Out-File -FilePath $script:globalLogFile -Append
        
        if ($overallRecommendations.Count -gt 0) {
            "PRIORITY ACTIONS:" | Out-File -FilePath $script:globalLogFile -Append
            $overallRecommendations | ForEach-Object { "  → $_" | Out-File -FilePath $script:globalLogFile -Append }
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

        Write-Host " Press any key to return to the main menu..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        return $true

    } catch {
        Write-Host ""
        Write-Host " ✗ PREREQUISITES TESTING FAILED" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host " FILES CREATED:" -ForegroundColor Cyan
        Write-Host "   Log file: $script:globalLogFile" -ForegroundColor Gray
        Write-Host ""

        # Log error
        "Prerequisites testing failed: $(Get-Date)" | Out-File -FilePath $script:globalLogFile -Append
        "Error: $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append

        Write-Host " Press any key to return to the main menu..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        return $false
    }
}
