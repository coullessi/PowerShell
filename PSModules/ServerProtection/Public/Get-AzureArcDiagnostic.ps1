function Get-AzureArcDiagnostic {
    <#
    .SYNOPSIS
        Performs comprehensive Azure Arc agent diagnostics and collects detailed logs for troubleshooting.

    .DESCRIPTION
        This function provides comprehensive diagnostic capabilities for Azure Arc Connected Machine Agent
        troubleshooting and analysis. It systematically executes a series of diagnostic commands to assess
        the health, configuration, and operational status of the Azure Arc agent on the local machine.

        The function performs the following diagnostic operations:

        AZURE ARC AGENT STATUS ANALYSIS:
        - Retrieves comprehensive agent configuration and status information
        - Displays current connection state and registration details
        - Shows resource metadata and Azure resource identifiers
        - Validates agent version and update status
        - Reports extension status and installed capabilities

        CONNECTIVITY AND HEALTH VALIDATION:
        - Performs comprehensive connectivity tests to Azure Arc endpoints
        - Validates network reachability and authentication status
        - Tests certificate validation and TLS connectivity
        - Checks proxy configuration and firewall accessibility
        - Verifies DNS resolution for required Azure domains

        COMPREHENSIVE LOG COLLECTION:
        - Generates complete diagnostic log archive using Azure Arc agent
        - Collects system logs, agent logs, and configuration files
        - Includes network traces and connectivity diagnostics
        - Captures Windows Event Logs related to Azure Arc operations
        - Creates timestamped ZIP archive for support analysis

        DIAGNOSTIC WORKFLOW AND COMMANDS:
        The script executes the following commands in sequence:

        | Command | Description |
        |---------|-------------|
        | azcmagent show | Displays current agent configuration, connection status, and metadata |
        | azcmagent check | Performs comprehensive connectivity and health validation tests |
        | azcmagent logs --full | Generates complete diagnostic log archive with all available data |

        FEATURES AND CAPABILITIES:
        - Interactive folder selection with intelligent defaults
        - Comprehensive error handling and validation
        - Detailed progress tracking and status reporting
        - Professional logging with timestamped entries
        - Support for multiple path formats (relative, absolute, quoted)
        - Automatic folder creation and permission validation
        - Rich console output with color-coded status indicators
        - Enterprise-ready diagnostic reporting

        OUTPUT AND DELIVERABLES:
        The function generates two primary outputs in the specified directory:
        1. Detailed diagnostic log file with all command outputs and recommendations
        2. Complete ZIP archive containing comprehensive Azure Arc diagnostic data

        This function is essential for troubleshooting Azure Arc connectivity issues,
        validating agent health, and preparing diagnostic information for Microsoft Support.

    .PARAMETER LogPath
        Specifies the directory path where diagnostic logs and files will be stored.
        Supports multiple path formats including:
        - Relative paths: .\AzureArcLog, ..\Diagnostics
        - Absolute paths: C:\AzureArcLog, D:\Temp\Diagnostics
        - Quoted paths: "C:\Azure Arc Logs", 'C:\Program Files\Logs'
        
        If not specified, the function will prompt the user interactively.
        The default suggestion is the current working directory.

    .PARAMETER DeviceListPath
        Path to a text file containing a list of device names to diagnose (one per line).
        Supports multiple path formats including:
        - Relative paths: .\DeviceList.txt, ..\Devices.txt
        - Absolute paths: C:\DeviceList.txt, D:\Temp\Devices.txt
        - Quoted paths: "C:\Device List.txt", 'C:\Azure Arc Devices.txt'
        
        If not specified, the function will prompt the user interactively.
        Lines starting with # are treated as comments and ignored.
        Empty lines are also ignored.

    .PARAMETER Force
        When specified, skips interactive prompts and proceeds with diagnostics
        using either the provided LogPath or the current directory as default.

    .PARAMETER Quiet
        When specified, suppresses non-essential output and displays only
        critical information and results.

    .EXAMPLE
        Get-AzureArcDiagnostic
        
        # Interactive mode - prompts user for log directory and device list selection
        # Uses current directory as default suggestion for logs
        # Creates default device list with sample entries for editing
        # Displays comprehensive progress and status information

    .EXAMPLE
        Get-AzureArcDiagnostic -LogPath "C:\AzureArcDiagnostics"
        
        # Specifies custom directory for diagnostic output
        # Prompts for device list interactively
        # Creates directory if it doesn't exist
        # Stores all logs and ZIP files in specified location

    .EXAMPLE
        Get-AzureArcDiagnostic -DeviceListPath "C:\DeviceList.txt" -LogPath ".\Logs"
        
        # Uses existing device list file and relative path for log storage
        # Processes all devices listed in the file
        # Creates separate diagnostic logs for each device

    .EXAMPLE
        Get-AzureArcDiagnostic -DeviceListPath ".\Devices.txt" -Force -Quiet
        
        # Uses relative path for device list
        # Skips interactive prompts with Force parameter
        # Suppresses detailed output with Quiet parameter
        # Proceeds directly with diagnostic collection for all listed devices

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        System.Boolean
        Returns $true if all diagnostic operations completed successfully,
        $false if any critical errors occurred during execution.

        The function also generates the following files:
        - AzureArc_Diagnostic_[Timestamp].log: Detailed diagnostic log
        - [AgentLogArchive].zip: Complete Azure Arc agent diagnostic archive

    .NOTES
        REQUIREMENTS:
        - Administrative privileges (recommended for complete diagnostics)
        - Azure Connected Machine Agent installed and accessible
        - Network connectivity to Azure Arc endpoints
        - Sufficient disk space for log file generation (minimum 100MB recommended)

        SUPPORTED PLATFORMS:
        - Windows Server 2012 R2 and later
        - PowerShell 5.1 or later

        SECURITY CONSIDERATIONS:
        - Diagnostic logs may contain sensitive system information
        - Review log contents before sharing with external parties
        - Store diagnostic files in secure locations with appropriate access controls

        TROUBLESHOOTING:
        - If azcmagent commands fail, verify Azure Arc agent installation
        - Ensure PowerShell execution policy allows script execution
        - Check network connectivity if connectivity tests fail
        - Verify sufficient disk space for log file creation

    .LINK
        https://docs.microsoft.com/en-us/azure/azure-arc/servers/troubleshoot-agent-onboard

    .LINK
        https://docs.microsoft.com/en-us/azure/azure-arc/servers/agent-overview

    .LINK
        https://lessit.net/projects/ServerProtection
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Directory path for storing diagnostic logs and files")]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath,

        [Parameter(Mandatory = $false, HelpMessage = "Path to a text file containing a list of device names to diagnose (one per line)")]
        [string]$DeviceListPath,

        [Parameter(Mandatory = $false, HelpMessage = "Skip interactive prompts")]
        [switch]$Force,

        [Parameter(Mandatory = $false, HelpMessage = "Suppress non-essential output")]
        [switch]$Quiet,
        
        [Parameter(Mandatory = $false, HelpMessage = "Use standardized output directory from other module functions")]
        [switch]$UseStandardizedDirectory
    )

    begin {
        # Function to clean and validate paths (same as Get-AzureArcPrerequisite)
        function Get-CleanPath {
            param([string]$InputPath, [bool]$IsDirectory = $true)
            
            if ([string]::IsNullOrWhiteSpace($InputPath)) {
                return $null
            }
            
            # Clean up the path - remove surrounding quotes and trim whitespace
            $cleanedPath = $InputPath.Trim()
            
            # Remove surrounding quotes (single or double) only if they match and the string is long enough
            if ($cleanedPath.Length -ge 2) {
                if (($cleanedPath.StartsWith('"') -and $cleanedPath.EndsWith('"')) -or 
                    ($cleanedPath.StartsWith("'") -and $cleanedPath.EndsWith("'"))) {
                    $cleanedPath = $cleanedPath.Substring(1, $cleanedPath.Length - 2)
                }
            }
            
            # Validate that it's a valid path format
            try {
                $cleanedPath = [System.IO.Path]::GetFullPath($cleanedPath)
                return $cleanedPath
            } catch {
                return $null
            }
        }

        # Initialize script-level variables
        $script:allResults = @{}
        $script:deviceResults = @{}
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $defaultLocation = $env:USERPROFILE + "\Desktop"

        # Check if Azure Arc agent is available (but don't fail immediately - wait until actual diagnostic execution)
        $script:azcmagentAvailable = $false
        try {
            $azcmagentPath = Get-Command "azcmagent" -ErrorAction Stop
            $script:azcmagentAvailable = $true
            if (-not $Quiet) {
                Write-Host "Azure Connected Machine Agent found: $($azcmagentPath.Source)" -ForegroundColor Green
            }
        }
        catch {
            # Don't fail here - we'll handle this during actual diagnostic execution
            if (-not $Quiet) {
                Write-Host "Azure Connected Machine Agent (azcmagent) not found in PATH" -ForegroundColor Yellow
                Write-Host "Note: Agent installation will be required for diagnostic execution" -ForegroundColor Gray
            }
        }
    }

    process {
        # Set up device list handling with simplified logic (same as Get-AzureArcPrerequisite)
        if (-not $Quiet) {
            Write-Host ""
            Write-Host " DEVICE LIST SETUP" -ForegroundColor Yellow
            Write-Host ""
        }
        
        if ([string]::IsNullOrWhiteSpace($DeviceListPath)) {
            if (-not $Force) {
                Write-Host "   Supported formats: D:\Path\DeviceList.txt, 'D:\Path\file.csv', `"D:\Path\Device List.txt`"" -ForegroundColor Gray
                Write-Host ""
                
                $deviceFileInput = Read-Host "   Enter device list file path (or press Enter for local machine only)"
                
                if ([string]::IsNullOrWhiteSpace($deviceFileInput)) {
                    # No device list - use local machine only
                    if (-not $Quiet) {
                        Write-Host "   Using local machine only: $env:COMPUTERNAME" -ForegroundColor White
                    }
                } else {
                    # User provided a device file path
                    $cleanedFilePath = Get-CleanPath -InputPath $deviceFileInput -IsDirectory $false
                    
                    if (-not $cleanedFilePath) {
                        Write-Host "   [WARN] Invalid file path format. Using local machine only..." -ForegroundColor Yellow
                    } elseif (Test-Path $cleanedFilePath) {
                        # Existing file found
                        $DeviceListPath = $cleanedFilePath
                        if (-not $Quiet) {
                            Write-Host "   [OK] Found existing device list: $DeviceListPath" -ForegroundColor Green
                        }
                        
                        $editChoice = Read-Host "   Edit the device list before proceeding? [Y/N] (default: N)"
                        if ($editChoice -eq "Y" -or $editChoice -eq "y") {
                            if (-not $Quiet) {
                                Write-Host ""
                                Write-Host "   Opening device list in Notepad for editing..." -ForegroundColor Cyan
                                Write-Host "   Close Notepad when done to continue the script." -ForegroundColor White
                                Write-Host ""
                            }
                            
                            try {
                                $notepadProcess = Start-Process -FilePath "notepad.exe" -ArgumentList $DeviceListPath -PassThru
                                $notepadProcess.WaitForExit()
                                if (-not $Quiet) {
                                    Write-Host "   [OK] Device list editing completed" -ForegroundColor Green
                                }
                            } catch {
                                if (-not $Quiet) {
                                    Write-Host "   [WARN] Could not open Notepad: $($_.Exception.Message)" -ForegroundColor Yellow
                                    Write-Host "   Continuing with existing device list..." -ForegroundColor White
                                }
                            }
                        } else {
                            if (-not $Quiet) {
                                Write-Host "   [OK] Using device list as-is" -ForegroundColor Green
                            }
                        }
                    } else {
                        # File doesn't exist - create default device list
                        $fileInfo = [System.IO.FileInfo]$cleanedFilePath
                        $directory = $fileInfo.DirectoryName
                        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileInfo.Name)
                        $extension = $fileInfo.Extension
                        
                        if ([string]::IsNullOrEmpty($extension)) {
                            $extension = ".txt"
                        }
                        
                        $timestampedFileName = "${baseName}_${timestamp}${extension}"
                        $script:deviceListFile = Join-Path $directory $timestampedFileName
                        
                        # Ensure directory exists
                        if (-not (Test-Path $directory)) {
                            try {
                                New-Item -Path $directory -ItemType Directory -Force | Out-Null
                                if (-not $Quiet) {
                                    Write-Host "   [OK] Created directory: $directory" -ForegroundColor Green
                                }
                            } catch {
                                Write-Host "   [FAIL] Failed to create directory: $($_.Exception.Message)" -ForegroundColor Red
                                Write-Host "   Using default location instead..." -ForegroundColor Yellow
                                $script:deviceListFile = Join-Path $defaultLocation "DeviceList_$timestamp.txt"
                            }
                        }
                        
                        # Create default device list content
                        $defaultContent = @"
# Azure Arc Device List for Diagnostics
# Enter one device name per line
# Lines starting with # are comments and will be ignored
#
# Examples:
# SERVER01
# SERVER02
#
# Add your device names below:
$env:COMPUTERNAME
"@
                        
                        try {
                            $defaultContent | Out-File -FilePath $script:deviceListFile -Encoding UTF8
                            if (-not $Quiet) {
                                Write-Host "   [OK] Default device list created: $script:deviceListFile" -ForegroundColor Green
                            }
                            $DeviceListPath = $script:deviceListFile
                            
                            if (-not $Quiet) {
                                Write-Host ""
                                Write-Host "   Opening device list in Notepad for editing..." -ForegroundColor Cyan
                                Write-Host "   Review/edit your device names and save the file." -ForegroundColor White
                                Write-Host "   Close Notepad when done to continue the script." -ForegroundColor White
                                Write-Host ""
                            }
                            
                            try {
                                $notepadProcess = Start-Process -FilePath "notepad.exe" -ArgumentList $script:deviceListFile -PassThru
                                $notepadProcess.WaitForExit()
                                if (-not $Quiet) {
                                    Write-Host "   [OK] Device list editing completed" -ForegroundColor Green
                                }
                            } catch {
                                if (-not $Quiet) {
                                    Write-Host "   [WARN] Could not open Notepad: $($_.Exception.Message)" -ForegroundColor Yellow
                                    Write-Host "   Continuing with default device list..." -ForegroundColor White
                                }
                            }
                            
                        } catch {
                            Write-Host "   [FAIL] Failed to create device list file: $($_.Exception.Message)" -ForegroundColor Red
                            Write-Host "   Using local machine only..." -ForegroundColor Yellow
                            $DeviceListPath = $null
                        }
                    }
                }
            } else {
                # Force mode - use local machine only
                if (-not $Quiet) {
                    Write-Host "   Force mode: Using local machine only: $env:COMPUTERNAME" -ForegroundColor White
                }
            }
        } else {
            # DeviceListPath was provided as parameter - validate and clean it
            if (-not $Quiet) {
                Write-Host "   Using provided device list parameter: $DeviceListPath" -ForegroundColor White
            }
            
            $cleanedDeviceListPath = Get-CleanPath -InputPath $DeviceListPath -IsDirectory $false
            
            if (-not $cleanedDeviceListPath) {
                Write-Host "   [WARN] Invalid device list path format provided" -ForegroundColor Yellow
                Write-Host "   Using local machine only..." -ForegroundColor Yellow
                $DeviceListPath = $null
            } elseif (-not (Test-Path $cleanedDeviceListPath)) {
                Write-Host "   [WARN] Provided device list file not found: $cleanedDeviceListPath" -ForegroundColor Yellow
                Write-Host "   Using local machine only..." -ForegroundColor Yellow
                $DeviceListPath = $null
            } else {
                $DeviceListPath = $cleanedDeviceListPath
                if (-not $Quiet) {
                    Write-Host "   [OK] Device list file verified" -ForegroundColor Green
                }
            }
        }
        
        # Set up log file path (use same directory as device list or default) - Same as Get-AzureArcPrerequisite
        if ($DeviceListPath) {
            $logDirectory = [System.IO.Path]::GetDirectoryName($DeviceListPath)
            $script:globalLogFile = Join-Path $logDirectory "AzureArc_Diagnostics_$timestamp.log"
        } else {
            $script:globalLogFile = Join-Path $defaultLocation "AzureArc_Diagnostics_$timestamp.log"
        }

        try {
            Clear-Host
            Write-Host ""
            Write-Host " ██████╗ ██╗ █████╗  ██████╗ ███╗   ██╗ ██████╗ ███████╗████████╗██╗ ██████╗███████╗" -ForegroundColor Cyan
            Write-Host " ██╔══██╗██║██╔══██╗██╔════╝ ████╗  ██║██╔═══██╗██╔════╝╚══██╔══╝██║██╔════╝██╔════╝" -ForegroundColor Cyan
            Write-Host " ██║  ██║██║███████║██║  ███╗██╔██╗ ██║██║   ██║███████╗   ██║   ██║██║     ███████╗" -ForegroundColor Cyan
            Write-Host " ██║  ██║██║██╔══██║██║   ██║██║╚██╗██║██║   ██║╚════██║   ██║   ██║██║     ╚════██║" -ForegroundColor Cyan
            Write-Host " ██████╔╝██║██║  ██║╚██████╔╝██║ ╚████║╚██████╔╝███████║   ██║   ██║╚██████╗███████║" -ForegroundColor Cyan
            Write-Host " ╚═════╝ ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝ ╚═════╝╚══════╝" -ForegroundColor Cyan
            Write-Host ""
            Write-Host " AZURE ARC DIAGNOSTIC COLLECTION" -ForegroundColor Green
            Write-Host " Comprehensive Agent Health and Connectivity Analysis" -ForegroundColor Gray
            Write-Host ""

            # Log session start
            ("=" * 100) | Out-File -FilePath $script:globalLogFile
            "AZURE ARC DIAGNOSTIC COLLECTION SESSION" | Out-File -FilePath $script:globalLogFile -Append
            ("=" * 100) | Out-File -FilePath $script:globalLogFile -Append
            "Started: $(Get-Date)" | Out-File -FilePath $script:globalLogFile -Append
            "Parameters: Force=$Force, Quiet=$Quiet, UseStandardizedDirectory=$UseStandardizedDirectory" | Out-File -FilePath $script:globalLogFile -Append
            if ($DeviceListPath) {
                "Device List File: $DeviceListPath" | Out-File -FilePath $script:globalLogFile -Append
            }
            "Log File Directory: $([System.IO.Path]::GetDirectoryName($script:globalLogFile))" | Out-File -FilePath $script:globalLogFile -Append
            "" | Out-File -FilePath $script:globalLogFile -Append

            # Initialize device testing variables
            $deviceResults = @{}
            $overallRecommendations = @()
            $devicesToDiagnose = @()
            
            # Determine devices to diagnose
            if ($DeviceListPath -and (Test-Path $DeviceListPath)) {
                Write-Host " LOADING DEVICE LIST" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "   Reading device list from: $DeviceListPath" -ForegroundColor White
                
                try {
                    $deviceListContent = Get-Content $DeviceListPath -ErrorAction Stop
                    $devicesToDiagnose = $deviceListContent | Where-Object { 
                        $_.Trim() -ne "" -and -not $_.Trim().StartsWith("#") 
                    } | ForEach-Object { $_.Trim() }
                    
                    if ($devicesToDiagnose.Count -eq 0) {
                        Write-Host "   [WARN] No valid device names found in device list" -ForegroundColor Yellow
                        Write-Host "   Using local machine only..." -ForegroundColor White
                        $devicesToDiagnose = @($env:COMPUTERNAME)
                    } else {
                        if (-not $Quiet) {
                            Write-Host "   [OK] Found $($devicesToDiagnose.Count) device(s) to diagnose" -ForegroundColor Green
                            $devicesToDiagnose | ForEach-Object { Write-Host "     - $_" -ForegroundColor Gray }
                        }
                    }
                    
                    # Log device list
                    "DEVICE LIST PROCESSING" | Out-File -FilePath $script:globalLogFile -Append
                    ("-" * 50) | Out-File -FilePath $script:globalLogFile -Append
                    "Total devices found: $($devicesToDiagnose.Count)" | Out-File -FilePath $script:globalLogFile -Append
                    $devicesToDiagnose | ForEach-Object { "  - $_" | Out-File -FilePath $script:globalLogFile -Append }
                    "" | Out-File -FilePath $script:globalLogFile -Append
                    
                } catch {
                    Write-Host "   [FAIL] Failed to read device list: $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host "   Using local machine only..." -ForegroundColor White
                    $devicesToDiagnose = @($env:COMPUTERNAME)
                    
                    "ERROR: Failed to read device list - $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
                    "Defaulting to local machine: $env:COMPUTERNAME" | Out-File -FilePath $script:globalLogFile -Append
                    "" | Out-File -FilePath $script:globalLogFile -Append
                }
            } else {
                Write-Host "   No device list provided, using local machine only" -ForegroundColor White
                $devicesToDiagnose = @($env:COMPUTERNAME)
                
                "DEVICE LIST: Not provided - using local machine only" | Out-File -FilePath $script:globalLogFile -Append
                "Device: $env:COMPUTERNAME" | Out-File -FilePath $script:globalLogFile -Append
                "" | Out-File -FilePath $script:globalLogFile -Append
            }

            Write-Host ""
            Write-Host " RUNNING DIAGNOSTICS ON $($devicesToDiagnose.Count) DEVICE(S)" -ForegroundColor Green
            Write-Host ""

            # Validate Azure Arc agent is available before proceeding with diagnostics
            if (-not $script:azcmagentAvailable) {
                Write-Host ""
                Write-Host " AZURE ARC AGENT REQUIRED" -ForegroundColor Red
                Write-Host ""
                Write-Host "   The Azure Connected Machine Agent (azcmagent) is required for diagnostic collection." -ForegroundColor White
                Write-Host "   Please install the agent before running diagnostics." -ForegroundColor White
                Write-Host ""
                Write-Host "   Download from: https://aka.ms/AzureConnectedMachineAgent" -ForegroundColor Cyan
                Write-Host ""
                
                # Log the requirement
                "AZURE ARC AGENT REQUIREMENT CHECK" | Out-File -FilePath $script:globalLogFile -Append
                ("-" * 50) | Out-File -FilePath $script:globalLogFile -Append
                "FAILED: Azure Connected Machine Agent (azcmagent) not found in PATH" | Out-File -FilePath $script:globalLogFile -Append
                "RESOLUTION: Install Azure Arc agent from https://aka.ms/AzureConnectedMachineAgent" | Out-File -FilePath $script:globalLogFile -Append
                "Diagnostic collection cannot proceed without the agent" | Out-File -FilePath $script:globalLogFile -Append
                "" | Out-File -FilePath $script:globalLogFile -Append
                
                if (-not $Force) {
                    $continueChoice = Read-Host "   Continue anyway (diagnostics will fail)? [y/N]"
                    if ($continueChoice -ne "y" -and $continueChoice -ne "Y") {
                        Write-Host "   Diagnostic collection cancelled by user." -ForegroundColor Yellow
                        return $false
                    }
                    Write-Host "   Proceeding with diagnostic collection (expect failures)..." -ForegroundColor Yellow
                } else {
                    Write-Host "   Force mode: Proceeding with diagnostic collection (expect failures)..." -ForegroundColor Yellow
                }
                Write-Host ""
            }

            # Handle log path selection with standardized directory support
            if ($UseStandardizedDirectory) {
                # Use standardized directory system
                $LogPath = Get-StandardizedOutputDirectory -Purpose "Azure Arc Diagnostics" -DefaultName "AzureArcDiagnostics" -Quiet:$Quiet
                if (-not $LogPath) {
                    Write-Error "Failed to obtain standardized output directory"
                    return $false
                }
                if (-not $Quiet) {
                    Write-Host "Using standardized directory for diagnostics: $LogPath"
                }
            }
            elseif (-not $LogPath) {
                if ($Force) {
                    $LogPath = $PWD.Path
                    if (-not $Quiet) {
                        Write-Host "Using current directory for logs: $LogPath"
                    }
                }
                else {
                    Write-Host ""
                    Write-Host "Log Directory Selection"
                    Write-Host "-----------------------"
                    Write-Host "Please specify where to store diagnostic files."
                    Write-Host "Default: Current directory ($($PWD.Path))"
                    Write-Host ""
                    Write-Host "Accepted formats:"
                    Write-Host "  - Relative: .\AzureArcLog, ..\Diagnostics"
                    Write-Host "  - Absolute: C:\AzureArcLog, D:\Temp"
                    Write-Host "  - Quoted: 'C:\Azure Arc Logs', `"C:\Diagnostics`""
                    Write-Host ""
                    
                    do {
                        $userInput = Read-Host "Enter log directory path (press Enter for current directory)"
                        
                        if ([string]::IsNullOrWhiteSpace($userInput)) {
                            $LogPath = $PWD.Path
                            Write-Host "Using current directory: $LogPath"
                            break
                        }
                        else {
                            # Handle quoted paths
                            $cleanPath = $userInput.Trim().Trim('"').Trim("'")
                            
                            # Convert relative paths to absolute
                            if ($cleanPath.StartsWith(".\") -or $cleanPath.StartsWith("..\")) {
                                $LogPath = Join-Path $PWD.Path $cleanPath
                            }
                            else {
                                $LogPath = $cleanPath
                            }
                            
                            # Validate path format
                            try {
                                $LogPath = [System.IO.Path]::GetFullPath($LogPath)
                                Write-Host "Log directory set: $LogPath"
                                break
                            }
                            catch {
                                Write-Host "Invalid path format. Please try again."
                                continue
                            }
                        }
                    } while ($true)
                }
            }
            else {
                # Handle provided LogPath parameter
                $cleanPath = $LogPath.Trim().Trim('"').Trim("'")
                
                if ($cleanPath.StartsWith(".\") -or $cleanPath.StartsWith("..\")) {
                    $LogPath = Join-Path $PWD.Path $cleanPath
                }
                else {
                    $LogPath = $cleanPath
                }
                
                $LogPath = [System.IO.Path]::GetFullPath($LogPath)
            }

            # Create log directory if it doesn't exist
            if (-not (Test-Path $LogPath)) {
                try {
                    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
                    if (-not $Quiet) {
                        Write-Host "Created log directory: $LogPath"
                    }
                }
                catch {
                    Write-Error "Failed to create log directory: $($_.Exception.Message)"
                    return $false
                }
            }

            # Validate write access
            $testFile = Join-Path $LogPath "test_write_access.tmp"
            try {
                "test" | Out-File -FilePath $testFile -Force
                Remove-Item $testFile -Force
            }
            catch {
                Write-Error "Insufficient permissions to write to: $LogPath"
                return $false
            }

            if (-not $Quiet) {
                Write-Host ""
                Write-Host "Starting Azure Arc Diagnostic Collection for $($devicesToDiagnose.Count) device(s)..."
                Write-Host "Output Directory: $LogPath"
                Write-Host ""
            }

            # Process each device
            $overallSuccess = $true
            foreach ($deviceName in $devicesToDiagnose) {
                $isLocalMachine = ($deviceName -eq $env:COMPUTERNAME -or $deviceName -eq "localhost" -or $deviceName -eq ".")
                
                Write-Host " DEVICE: $deviceName" -ForegroundColor Cyan
                Write-Host " $("=" * ($deviceName.Length + 8))" -ForegroundColor Cyan
                Write-Host ""
                
                # Initialize device result
                $deviceResult = @{
                    DeviceName = $deviceName
                    IsLocalMachine = $isLocalMachine
                    DiagnosticResults = @()
                    OverallSuccess = $true
                    Warnings = @()
                    Errors = @()
                    TestDateTime = Get-Date
                    ZipFiles = @()
                }
                
                # Log device section start
                ("=" * 100) | Out-File -FilePath $script:globalLogFile -Append
                "DEVICE: $deviceName" | Out-File -FilePath $script:globalLogFile -Append
                ("=" * 100) | Out-File -FilePath $script:globalLogFile -Append
                "Diagnostic Started: $(Get-Date)" | Out-File -FilePath $script:globalLogFile -Append
                "Local Machine: $isLocalMachine" | Out-File -FilePath $script:globalLogFile -Append
                "" | Out-File -FilePath $script:globalLogFile -Append

                # Check if this is a remote device (not implemented for remote execution yet)
                if (-not $isLocalMachine) {
                    Write-Host "   [WARN] Remote diagnostics not implemented yet for: $deviceName" -ForegroundColor Yellow
                    Write-Host "   This device will be skipped in this version." -ForegroundColor White
                    
                    "WARNING: Remote diagnostics not implemented" | Out-File -FilePath $script:globalLogFile -Append
                    "This device was skipped during diagnostic collection" | Out-File -FilePath $script:globalLogFile -Append
                    "" | Out-File -FilePath $script:globalLogFile -Append
                    
                    $deviceResult.OverallSuccess = $false
                    $deviceResult.Warnings += "Remote diagnostics not implemented yet"
                    $deviceResult.DiagnosticResults += @{
                        Step = 1
                        Name = "Remote Diagnostics"
                        Command = "N/A"
                        Success = $false
                        Duration = 0
                        ExitCode = -1
                        Error = "Remote diagnostics not implemented yet"
                    }
                    
                    $deviceResults[$deviceName] = $deviceResult
                    $overallSuccess = $false
                    continue
                }

                # Define diagnostic commands for local machine
                $diagnosticCommands = @(
                    @{
                        Name = "Agent Status and Configuration"
                        Command = "azcmagent show"
                        Description = "Retrieves comprehensive agent configuration, connection status, and metadata"
                        Step = 1
                    },
                    @{
                        Name = "Connectivity and Health Check"
                        Command = "azcmagent check"
                        Description = "Performs comprehensive connectivity tests and health validation"
                        Step = 2
                    },
                    @{
                        Name = "Complete Log Collection"
                        Command = "azcmagent logs --full"
                        Description = "Generates complete diagnostic log archive with all available data"
                        Step = 3
                    }
                )

                $totalSteps = $diagnosticCommands.Count

                # Log diagnostic commands section
                "DIAGNOSTIC COMMANDS EXECUTION" | Out-File -FilePath $script:globalLogFile -Append
                ("-" * 50) | Out-File -FilePath $script:globalLogFile -Append
                # Execute diagnostic commands for this device
                foreach ($diagnostic in $diagnosticCommands) {
                    Write-Host "   Step $($diagnostic.Step)/$totalSteps`: $($diagnostic.Name)" -ForegroundColor Yellow
                    Write-Progress -Activity "Azure Arc Diagnostics - $deviceName" -Status $diagnostic.Name -PercentComplete (($diagnostic.Step / $totalSteps) * 100)

                    "[$($diagnostic.Step)/$totalSteps] $($diagnostic.Name.ToUpper())" | Out-File -FilePath $script:globalLogFile -Append
                    "Command: $($diagnostic.Command)" | Out-File -FilePath $script:globalLogFile -Append
                    "Description: $($diagnostic.Description)" | Out-File -FilePath $script:globalLogFile -Append
                    "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $script:globalLogFile -Append
                    "------------------------------------------------------------" | Out-File -FilePath $script:globalLogFile -Append

                    try {
                        Write-Host "     Executing: $($diagnostic.Command)" -ForegroundColor White

                        # Check if agent is available before execution
                        if (-not $script:azcmagentAvailable) {
                            throw "Azure Connected Machine Agent (azcmagent) not found in PATH. Please install the agent before running diagnostics."
                        }

                        # Execute command and capture output
                        $startTime = Get-Date
                        
                        if ($diagnostic.Command -eq "azcmagent logs --full") {
                            # Special handling for logs command - it generates files
                            # Create device-specific subdirectory for log archives in same location as global log
                            $deviceLogDir = Join-Path ([System.IO.Path]::GetDirectoryName($script:globalLogFile)) $deviceName
                            if (-not (Test-Path $deviceLogDir)) {
                                New-Item -Path $deviceLogDir -ItemType Directory -Force | Out-Null
                            }
                            
                            # Set environment variable to remove 'unknown' from filename
                            $env:COMPUTERNAME_OVERRIDE = $deviceName
                            $output = & cmd.exe /c "cd /d `"$deviceLogDir`" && set COMPUTERNAME=$deviceName && $($diagnostic.Command) 2>&1"
                            
                            # Post-process to rename any files with 'unknown' in the name
                            $zipFiles = Get-ChildItem -Path $deviceLogDir -Filter "*unknown*.zip" -ErrorAction SilentlyContinue
                            foreach ($zipFile in $zipFiles) {
                                $newName = $zipFile.Name -replace '-unknown', ''
                                try {
                                    Rename-Item -Path $zipFile.FullName -NewName $newName -Force
                                    Write-Host "     Renamed log archive: $newName" -ForegroundColor Green
                                    $deviceResult.ZipFiles += Join-Path $deviceLogDir $newName
                                }
                                catch {
                                    Write-Host "     Could not rename $($zipFile.Name)" -ForegroundColor Yellow
                                    $deviceResult.ZipFiles += $zipFile.FullName
                                }
                            }
                            
                            # Also check for any other ZIP files created
                            $allZipFiles = Get-ChildItem -Path $deviceLogDir -Filter "*.zip" -ErrorAction SilentlyContinue | Where-Object { $_.CreationTime -gt $startTime }
                            foreach ($zipFile in $allZipFiles) {
                                if ($zipFile.FullName -notin $deviceResult.ZipFiles) {
                                    $deviceResult.ZipFiles += $zipFile.FullName
                                }
                            }
                        }
                        else {
                            $output = & cmd.exe /c "$($diagnostic.Command) 2>&1"
                        }
                        
                        $endTime = Get-Date
                        $duration = ($endTime - $startTime).TotalSeconds

                        # Process and log output
                        if ($output) {
                            $outputString = $output -join "`n"
                            "OUTPUT:" | Out-File -FilePath $script:globalLogFile -Append
                            $outputString | Out-File -FilePath $script:globalLogFile -Append
                            
                            # Display summary for user
                            if (-not $Quiet) {
                                $outputLines = $outputString -split "`n"
                                $displayLines = $outputLines | Select-Object -First 5
                                foreach ($line in $displayLines) {
                                    if ($line.Trim()) {
                                        Write-Host "     $line" -ForegroundColor Gray
                                    }
                                }
                                if ($outputLines.Count -gt 5) {
                                    Write-Host "     ... (additional output in log file)" -ForegroundColor Gray
                                }
                            }
                        }
                        else {
                            "OUTPUT: (No output or command completed silently)" | Out-File -FilePath $script:globalLogFile -Append
                        }

                        "" | Out-File -FilePath $script:globalLogFile -Append
                        "EXECUTION DETAILS:" | Out-File -FilePath $script:globalLogFile -Append
                        "Duration: $([math]::Round($duration, 2)) seconds" | Out-File -FilePath $script:globalLogFile -Append
                        "Exit Code: $LASTEXITCODE" | Out-File -FilePath $script:globalLogFile -Append
                        
                        # Determine success/failure
                        $commandSuccess = $LASTEXITCODE -eq 0
                        if ($commandSuccess) {
                            "Status: SUCCESS" | Out-File -FilePath $script:globalLogFile -Append
                            Write-Host "     Completed successfully ($([math]::Round($duration, 2))s)" -ForegroundColor Green
                        }
                        else {
                            "Status: FAILED" | Out-File -FilePath $script:globalLogFile -Append
                            $deviceResult.OverallSuccess = $false
                            $overallSuccess = $false
                            $deviceResult.Errors += "$($diagnostic.Name) failed with exit code $LASTEXITCODE"
                            Write-Host "     Command failed (Exit Code: $LASTEXITCODE)" -ForegroundColor Red
                        }

                        # Store result for summary
                        $deviceResult.DiagnosticResults += @{
                            Step = $diagnostic.Step
                            Name = $diagnostic.Name
                            Command = $diagnostic.Command
                            Success = $commandSuccess
                            Duration = $duration
                            ExitCode = $LASTEXITCODE
                        }
                    }
                    catch {
                        $errorMessage = $_.Exception.Message
                        "ERROR: $errorMessage" | Out-File -FilePath $script:globalLogFile -Append
                        "Status: FAILED" | Out-File -FilePath $script:globalLogFile -Append
                        $deviceResult.OverallSuccess = $false
                        $overallSuccess = $false
                        $deviceResult.Errors += "$($diagnostic.Name) failed: $errorMessage"
                        
                        Write-Host "     Error: $errorMessage" -ForegroundColor Red

                        $deviceResult.DiagnosticResults += @{
                            Step = $diagnostic.Step
                            Name = $diagnostic.Name
                            Command = $diagnostic.Command
                            Success = $false
                            Duration = 0
                            ExitCode = -1
                            Error = $errorMessage
                        }
                    }

                    "" | Out-File -FilePath $script:globalLogFile -Append
                    "------------------------------------------------------------" | Out-File -FilePath $script:globalLogFile -Append
                    "" | Out-File -FilePath $script:globalLogFile -Append

                    Start-Sleep -Milliseconds 500  # Brief pause for readability
                }

                # Generate device summary
                Write-Host ""
                
                $successCount = ($deviceResult.DiagnosticResults | Where-Object { $_.Success }).Count
                
                # Log device summary
                "DEVICE DIAGNOSTIC SUMMARY" | Out-File -FilePath $script:globalLogFile -Append
                ("-" * 50) | Out-File -FilePath $script:globalLogFile -Append
                "Device Status: $successCount/$totalSteps commands completed successfully" | Out-File -FilePath $script:globalLogFile -Append
                "Diagnostic Completed: $(Get-Date)" | Out-File -FilePath $script:globalLogFile -Append
                "" | Out-File -FilePath $script:globalLogFile -Append
                
                if ($deviceResult.Errors.Count -gt 0) {
                    "ERRORS ($($deviceResult.Errors.Count)):" | Out-File -FilePath $script:globalLogFile -Append
                    $deviceResult.Errors | ForEach-Object { "  [FAIL] $_" | Out-File -FilePath $script:globalLogFile -Append }
                    "" | Out-File -FilePath $script:globalLogFile -Append
                }
                
                if ($deviceResult.Warnings.Count -gt 0) {
                    "WARNINGS ($($deviceResult.Warnings.Count)):" | Out-File -FilePath $script:globalLogFile -Append
                    $deviceResult.Warnings | ForEach-Object { "  [WARN] $_" | Out-File -FilePath $script:globalLogFile -Append }
                    "" | Out-File -FilePath $script:globalLogFile -Append
                }

                if ($deviceResult.OverallSuccess) {
                    Write-Host " DEVICE STATUS: DIAGNOSTICS COMPLETED SUCCESSFULLY" -ForegroundColor Green
                    "RESULT: All diagnostic commands completed successfully for $deviceName" | Out-File -FilePath $script:globalLogFile -Append
                } else {
                    Write-Host " DEVICE STATUS: DIAGNOSTICS COMPLETED WITH ISSUES" -ForegroundColor Yellow
                    "RESULT: Some diagnostic commands encountered issues on $deviceName" | Out-File -FilePath $script:globalLogFile -Append
                    $overallRecommendations += "Device '$deviceName' has diagnostic issues that should be reviewed"
                }

                # Store device result
                $deviceResults[$deviceName] = $deviceResult

                # Clear progress for this device
                Write-Progress -Activity "Azure Arc Diagnostics - $deviceName" -Completed

                Write-Host ""
            } # End of device loop
            # Generate final consolidated summary
            Write-Host ""
            Write-Host "" -ForegroundColor Cyan
            Write-Host "                     DIAGNOSTIC COLLECTION SUMMARY                       " -ForegroundColor Cyan
            Write-Host "" -ForegroundColor Cyan
            
            # Calculate summary statistics
            $totalDevices = $deviceResults.Count
            $successfulDevices = @($deviceResults.Values | Where-Object { $_.OverallSuccess }).Count
            $failedDevices = $totalDevices - $successfulDevices
            $totalErrors = ($deviceResults.Values | ForEach-Object { $_.Errors.Count } | Measure-Object -Sum).Sum
            $totalWarnings = ($deviceResults.Values | ForEach-Object { $_.Warnings.Count } | Measure-Object -Sum).Sum
            
            # Log final summary
            ("=" * 100) | Out-File -FilePath $script:globalLogFile -Append
            "FINAL DIAGNOSTIC COLLECTION SUMMARY" | Out-File -FilePath $script:globalLogFile -Append
            ("=" * 100) | Out-File -FilePath $script:globalLogFile -Append
            "Completed: $(Get-Date)" | Out-File -FilePath $script:globalLogFile -Append
            "" | Out-File -FilePath $script:globalLogFile -Append
            "STATISTICS:" | Out-File -FilePath $script:globalLogFile -Append
            "Total Devices: $totalDevices" | Out-File -FilePath $script:globalLogFile -Append
            "Successful: $successfulDevices" | Out-File -FilePath $script:globalLogFile -Append
            "Failed: $failedDevices" | Out-File -FilePath $script:globalLogFile -Append
            "Total Errors: $totalErrors" | Out-File -FilePath $script:globalLogFile -Append
            "Total Warnings: $totalWarnings" | Out-File -FilePath $script:globalLogFile -Append
            "" | Out-File -FilePath $script:globalLogFile -Append
            
            # Display to user
            Write-Host "Total Devices Processed: $totalDevices"
            Write-Host "Successful Devices: $successfulDevices" -ForegroundColor $(if ($successfulDevices -eq $totalDevices) { "Green" } else { "Yellow" })
            Write-Host "Failed Devices: $failedDevices" -ForegroundColor $(if ($failedDevices -eq 0) { "Green" } else { "Red" })
            Write-Host "Total Errors: $totalErrors" -ForegroundColor $(if ($totalErrors -eq 0) { "Green" } else { "Red" })
            Write-Host "Total Warnings: $totalWarnings" -ForegroundColor $(if ($totalWarnings -eq 0) { "Green" } else { "Yellow" })
            Write-Host ""
            
            # Show detailed results per device
            "DEVICE RESULTS:" | Out-File -FilePath $script:globalLogFile -Append
            foreach ($deviceName in $deviceResults.Keys | Sort-Object) {
                $deviceResult = $deviceResults[$deviceName]
                $status = if ($deviceResult.OverallSuccess) { "SUCCESS" } else { "FAILED" }
                $statusColor = if ($deviceResult.OverallSuccess) { "Green" } else { "Red" }
                
                Write-Host "  Device: $deviceName - $status" -ForegroundColor $statusColor
                "  $deviceName - $status" | Out-File -FilePath $script:globalLogFile -Append
                
                if ($deviceResult.DiagnosticResults.Count -gt 0) {
                    $successfulSteps = ($deviceResult.DiagnosticResults | Where-Object { $_.Success }).Count
                    Write-Host "    Diagnostic Steps: $successfulSteps/$($deviceResult.DiagnosticResults.Count) completed successfully"
                    "    Steps: $successfulSteps/$($deviceResult.DiagnosticResults.Count)" | Out-File -FilePath $script:globalLogFile -Append
                    
                    if ($deviceResult.ZipFiles.Count -gt 0) {
                        Write-Host "    Log Archives: $($deviceResult.ZipFiles.Count) ZIP file(s) created"
                        "    ZIP Files: $($deviceResult.ZipFiles.Count)" | Out-File -FilePath $script:globalLogFile -Append
                        foreach ($zipFile in $deviceResult.ZipFiles) {
                            "      - $(Split-Path $zipFile -Leaf)" | Out-File -FilePath $script:globalLogFile -Append
                        }
                    }
                    
                    if ($deviceResult.Errors.Count -gt 0) {
                        "    Errors: $($deviceResult.Errors.Count)" | Out-File -FilePath $script:globalLogFile -Append
                    }
                    
                    if ($deviceResult.Warnings.Count -gt 0) {
                        "    Warnings: $($deviceResult.Warnings.Count)" | Out-File -FilePath $script:globalLogFile -Append
                    }
                }
                Write-Host ""
                "" | Out-File -FilePath $script:globalLogFile -Append
            }
            
            # Show all ZIP files created
            $allZipFiles = @()
            foreach ($deviceResult in $deviceResults.Values) {
                $allZipFiles += $deviceResult.ZipFiles
            }
            
            if ($allZipFiles.Count -gt 0) {
                Write-Host "Log Archives Created:" -ForegroundColor Cyan
                "ALL LOG ARCHIVES:" | Out-File -FilePath $script:globalLogFile -Append
                foreach ($zipFile in $allZipFiles) {
                    Write-Host "  $(Split-Path $zipFile -Leaf)" -ForegroundColor Gray
                    "  $(Split-Path $zipFile -Leaf)" | Out-File -FilePath $script:globalLogFile -Append
                }
                Write-Host ""
                Write-Host "  These ZIP files contain comprehensive diagnostic data for analysis" -ForegroundColor Yellow
                Write-Host "  Share these files with Microsoft Support when opening support cases" -ForegroundColor Yellow
                Write-Host ""
                "" | Out-File -FilePath $script:globalLogFile -Append
                "NOTE: ZIP files contain comprehensive diagnostic data for analysis" | Out-File -FilePath $script:globalLogFile -Append
                "Share these files with Microsoft Support when opening support cases" | Out-File -FilePath $script:globalLogFile -Append
                "" | Out-File -FilePath $script:globalLogFile -Append
            }
            
            # Display final recommendations
            if ($overallRecommendations.Count -gt 0) {
                Write-Host "Recommendations:" -ForegroundColor Cyan
                "RECOMMENDATIONS:" | Out-File -FilePath $script:globalLogFile -Append
                foreach ($recommendation in $overallRecommendations) {
                    Write-Host "  - $recommendation" -ForegroundColor Yellow
                    "  - $recommendation" | Out-File -FilePath $script:globalLogFile -Append
                }
                Write-Host ""
                "" | Out-File -FilePath $script:globalLogFile -Append
            }
            
            # Display output directory
            Write-Host "Output Directory: $([System.IO.Path]::GetDirectoryName($script:globalLogFile))"
            Write-Host "Consolidated Log: $(Split-Path $script:globalLogFile -Leaf)" -ForegroundColor Green
            Write-Host ""
            
            "OUTPUT DIRECTORY: $([System.IO.Path]::GetDirectoryName($script:globalLogFile))" | Out-File -FilePath $script:globalLogFile -Append
            "CONSOLIDATED LOG: $(Split-Path $script:globalLogFile -Leaf)" | Out-File -FilePath $script:globalLogFile -Append
            "" | Out-File -FilePath $script:globalLogFile -Append
            
            # Final status message
            if ($overallSuccess) {
                Write-Host "All device diagnostics completed successfully!" -ForegroundColor Green
                "FINAL RESULT: All device diagnostics completed successfully" | Out-File -FilePath $script:globalLogFile -Append
            } else {
                Write-Host "Some device diagnostics encountered issues. Review the consolidated log for details." -ForegroundColor Yellow
                "FINAL RESULT: Some device diagnostics encountered issues" | Out-File -FilePath $script:globalLogFile -Append
            }
            
            Write-Host "=================================================================="
            
            # Add session footer to log
            ("=" * 100) | Out-File -FilePath $script:globalLogFile -Append
            "DIAGNOSTIC COLLECTION SESSION COMPLETED: $(Get-Date)" | Out-File -FilePath $script:globalLogFile -Append
            "Report generated by ServerProtection PowerShell Module" | Out-File -FilePath $script:globalLogFile -Append
            "Author: Lessi Coulibaly | Organization: Less-IT | Website: https://lessit.net" | Out-File -FilePath $script:globalLogFile -Append
            ("=" * 100) | Out-File -FilePath $script:globalLogFile -Append

            return $overallSuccess
        }
        catch {
            Write-Error "Critical error during diagnostic collection: $($_.Exception.Message)"
            return $false
        }
    }

    end {
        if (-not $Quiet) {
            Write-Host "`nDiagnostic collection completed." -ForegroundColor White
        }
    }
}

