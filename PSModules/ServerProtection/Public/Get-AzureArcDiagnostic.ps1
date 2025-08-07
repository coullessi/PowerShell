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
        - Remote diagnostics support via PowerShell remoting
        - Multi-device processing from device list files
        - Automatic credential handling for remote machines
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

    .PARAMETER Credential
        Specifies credentials for remote device access when running diagnostics
        on devices listed in DeviceListPath. Required for remote diagnostics
        on devices that are not the local machine. If not specified, current
        user credentials will be used for remote connections.

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

    .EXAMPLE
        $cred = Get-Credential -Message "Enter credentials for remote devices"
        Get-AzureArcDiagnostic -DeviceListPath "C:\RemoteServers.txt" -Credential $cred

        # Runs diagnostics on remote devices listed in the file
        # Uses specified credentials for PowerShell remoting to remote machines
        # Collects diagnostic data from remote Azure Arc agents
        # Copies log archives back to local machine

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
        - Azure Connected Machine Agent installed and accessible on target machines
        - Network connectivity to Azure Arc endpoints
        - Sufficient disk space for log file generation (minimum 100MB recommended)

        REMOTE DIAGNOSTICS REQUIREMENTS:
        - PowerShell remoting enabled on target machines (Enable-PSRemoting -Force)
        - Network connectivity to remote machines via WinRM (ports 5985/5986)
        - Administrative credentials for remote machines (if different from current user)
        - Azure Arc agent installed on each remote machine

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
        https://github.com/coullessi/PowerShell
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

        [Parameter(Mandatory = $false, HelpMessage = "Credentials for remote device access (required for remote diagnostics)")]
        [PSCredential]$Credential
    )

    begin {
        # Function to build the proper azcmagent command with full path if needed
        function Get-AzcmagentCommand {
            param([string]$Command)

            if ($script:azcmagentPath -and $script:azcmagentPath -like "*\*") {
                # We have a full path, replace 'azcmagent' with the full path
                return $Command -replace '^azcmagent', "`"$script:azcmagentPath`""
            }
            else {
                # Agent is in PATH or we're using the command as-is
                return $Command
            }
        }

        # Initialize script-level variables
        $script:allResults = @{}
        $script:deviceResults = @{}
        $script:skipCleanup = $false

        # MANDATORY: Initialize standardized environment at the very beginning
        # This ensures the folder selection menu is ALWAYS shown and AzureArc folder is configured
        $environment = Initialize-StandardizedEnvironment -ScriptName "Get-AzureArcDiagnostic" -RequiredFileTypes @("DeviceList", "DiagnosticLog")

        # Check if user chose to quit (return to main menu)
        if ($environment.UserQuit) {
            $script:skipCleanup = $true
            return $null
        }

        # Check if initialization failed
        if (-not $environment.Success) {
            Write-Host "Failed to initialize environment. Exiting..."
            return
        }

        # Set up paths from standardized environment
        $workingFolder = $environment.FolderPath
        $script:deviceListFile = $environment.FilePaths["DeviceList"]
        $script:globalLogFile = $environment.FilePaths["DiagnosticLog"]

        # Override LogPath parameter with standardized directory (always use the selected folder)
        $LogPath = $workingFolder

        # Check if Azure Arc agent is available (but don't fail immediately - wait until actual diagnostic execution)
        $script:azcmagentAvailable = $false
        $script:azcmagentPath = $null

        # First try to find azcmagent in PATH
        try {
            $azcmagentCommand = Get-Command "azcmagent" -ErrorAction Stop
            $script:azcmagentAvailable = $true
            $script:azcmagentPath = $azcmagentCommand.Source
            if (-not $Quiet) {
                Write-Host "Azure Connected Machine Agent found in PATH: $($azcmagentCommand.Source)"
            }
        }
        catch {
            # If not in PATH, check the default installation location
            $defaultAzcmagentPath = "${env:ProgramFiles}\AzureConnectedMachineAgent\azcmagent.exe"
            if (Test-Path $defaultAzcmagentPath) {
                $script:azcmagentAvailable = $true
                $script:azcmagentPath = $defaultAzcmagentPath
                # Agent found in default location - no need to inform user of internal details
            }
            else {
                # Agent not found anywhere
                if (-not $Quiet) {
                    Write-Host "Azure Connected Machine Agent (azcmagent) not found in PATH or default location"
                    Write-Host "Note: Agent installation will be required for diagnostic execution"
                }
            }
        }
    }

    process {
        # Simple menu system for device selection
        if (-not $Force -and [string]::IsNullOrWhiteSpace($DeviceListPath)) {
            Clear-Host
            Write-Host ""
            Write-Host " AZURE ARC DIAGNOSTIC COLLECTION"
            Write-Host " ================================"
            Write-Host ""
            Write-Host " Please select an option:"
            Write-Host ""
            Write-Host "   1. Run diagnostics on localhost only"
            Write-Host "   2. Run diagnostics for a list of devices"
            Write-Host "   3. Quit and return to main menu"
            Write-Host ""

            $validChoice = $false
            do {
                $choice = Read-Host "   Enter your choice (1-3)"

                switch ($choice) {
                    "1" {
                        # Use localhost only
                        if (-not $Quiet) {
                            Write-Host "   Selected: Localhost diagnostics"
                        }
                        $DeviceListPath = $null
                        $validChoice = $true
                    }
                    "2" {
                        # Get device list file or create default if using standardized environment
                        if ($script:deviceListFile -and (-not $DeviceListPath)) {
                            # Create default device list file in standardized location
                            $defaultDeviceContent = @"
# Azure Arc Device List for Diagnostics
# Enter one device name per line
# Lines starting with # are comments and will be ignored
#
# Examples:
# SERVER01
# SERVER02
# $env:COMPUTERNAME
#
# Add your device names below:
$env:COMPUTERNAME
"@
                            try {
                                $defaultDeviceContent | Out-File -FilePath $script:deviceListFile -Encoding UTF8
                                Write-Host "   [OK] Created default device list: $([System.IO.Path]::GetFileName($script:deviceListFile))"

                                Write-Host ""
                                Write-Host "   Opening device list in Notepad for editing..."
                                Write-Host "   Edit your device names and save the file."
                                Write-Host "   Close Notepad when done to continue."
                                Write-Host ""

                                try {
                                    $notepadProcess = Start-Process -FilePath "notepad.exe" -ArgumentList $script:deviceListFile -PassThru
                                    $notepadProcess.WaitForExit()
                                    Write-Host "   [OK] Device list editing completed"
                                } catch {
                                    Write-Host "   [WARN] Could not open Notepad: $($_.Exception.Message)"
                                    Read-Host "   Press Enter after editing the device list file manually"
                                }

                                $DeviceListPath = $script:deviceListFile
                                $validChoice = $true
                            } catch {
                                Write-Host "   [FAIL] Could not create device list file: $($_.Exception.Message)"
                                Write-Host "   Using localhost only..."
                                $DeviceListPath = $null
                                $validChoice = $true
                            }
                        } else {
                            # Manual device list file selection
                            Write-Host ""
                            Write-Host "   Supported formats:"
                            Write-Host "   - C:\MyAzureArc\Devices.txt"
                            Write-Host "   - 'C:\MyAzureArc\Devices.txt'"
                            Write-Host "   - `"C:\MyAzureArc\Devices.txt`""
                            Write-Host ""

                            $deviceFileInput = Read-Host "   Enter device list file path"

                            if ([string]::IsNullOrWhiteSpace($deviceFileInput)) {
                                Write-Host "   [WARN] No file path provided. Using localhost only..."
                                $DeviceListPath = $null
                                $validChoice = $true
                            } else {
                                # Clean and validate the path
                                $cleanPath = Remove-PathQuote -Path $deviceFileInput.Trim()
                                $pathValidation = Test-ValidPath -Path $cleanPath -PathType File -RequireExists

                                if (-not $pathValidation.IsValid) {
                                    Write-Host "   [WARN] Invalid file path: $($pathValidation.Error)"
                                    Write-Host "   Using localhost only..."
                                    $DeviceListPath = $null
                                    $validChoice = $true
                                } elseif (-not $pathValidation.Exists) {
                                    Write-Host "   [WARN] File not found: $($pathValidation.FullPath)"
                                    Write-Host "   Using localhost only..."
                                    $DeviceListPath = $null
                                    $validChoice = $true
                                } else {
                                    $DeviceListPath = $pathValidation.FullPath
                                    Write-Host "   [OK] Device list file found: $DeviceListPath"
                                    $validChoice = $true
                                }
                            }
                        }
                    }
                    "3" {
                        # Quit to main menu
                        $script:skipCleanup = $true
                        return $null
                    }
                    default {
                        Write-Host "   [WARN] Invalid choice. Please enter 1, 2, or 3."
                        $validChoice = $false
                    }
                }
            } while (-not $validChoice)
        } elseif (-not [string]::IsNullOrWhiteSpace($DeviceListPath)) {
            # DeviceListPath was provided as parameter - validate it
            $pathValidation = Test-ValidPath -Path $DeviceListPath -PathType File -RequireExists

            if (-not $pathValidation.IsValid -or -not $pathValidation.Exists) {
                Write-Host "[WARN] Invalid or missing device list file. Using localhost only..."
                $DeviceListPath = $null
            } else {
                $DeviceListPath = $pathValidation.FullPath
                if (-not $Quiet) {
                    Write-Host "Using device list file: $DeviceListPath"
                }
            }
        }

        try {
            Clear-Host
            Write-Host ""
            Write-Host " AZURE ARC DIAGNOSTIC COLLECTION" -ForegroundColor Green
            Write-Host " Comprehensive Agent Health and Connectivity Analysis" -ForegroundColor Gray
            Write-Host ""

            # Log session start
            ("=" * 100) | Out-File -FilePath $script:globalLogFile
            "AZURE ARC DIAGNOSTIC COLLECTION SESSION" | Out-File -FilePath $script:globalLogFile -Append
            ("=" * 100) | Out-File -FilePath $script:globalLogFile -Append
            "Started: $(Get-Date)" | Out-File -FilePath $script:globalLogFile -Append
            "Parameters: Force=$Force, Quiet=$Quiet" | Out-File -FilePath $script:globalLogFile -Append
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
                Write-Host " LOADING DEVICE LIST"
                Write-Host ""
                Write-Host "   Reading device list from: $DeviceListPath"

                try {
                    $deviceListContent = Get-Content $DeviceListPath -ErrorAction Stop
                    $devicesToDiagnose = $deviceListContent | Where-Object {
                        $_.Trim() -ne "" -and -not $_.Trim().StartsWith("#")
                    } | ForEach-Object { $_.Trim() }

                    if ($devicesToDiagnose.Count -eq 0) {
                        Write-Host "   [WARN] No valid device names found in device list"
                        Write-Host "   Using localhost only..."
                        $devicesToDiagnose = @($env:COMPUTERNAME)
                    } else {
                        if (-not $Quiet) {
                            Write-Host "   [OK] Found $($devicesToDiagnose.Count) device(s) to diagnose"
                            $devicesToDiagnose | ForEach-Object { Write-Host "     - $_" }
                        }
                    }

                } catch {
                    Write-Host "   [FAIL] Failed to read device list: $($_.Exception.Message)"
                    Write-Host "   Using localhost only..."
                    $devicesToDiagnose = @($env:COMPUTERNAME)
                }
            } else {
                # No device list - use localhost only
                $devicesToDiagnose = @($env:COMPUTERNAME)
                if (-not $Quiet) {
                    Write-Host " USING LOCALHOST ONLY"
                    Write-Host ""
                    Write-Host "   Device: $env:COMPUTERNAME"
                }
            }

            Write-Host ""
            Write-Host " RUNNING DIAGNOSTICS ON $($devicesToDiagnose.Count) DEVICE(S)"
            Write-Host ""

            # Validate Azure Arc agent is available before proceeding with diagnostics
            if (-not $script:azcmagentAvailable) {
                Write-Host ""
                Write-Host " AZURE ARC AGENT REQUIRED"
                Write-Host ""
                Write-Host "   The Azure Connected Machine Agent (azcmagent) is required for diagnostic collection."
                Write-Host "   Please install the agent before running diagnostics."
                Write-Host ""
                Write-Host "   Download from: https://aka.ms/AzureConnectedMachineAgent"
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
                        Write-Host "   Diagnostic collection cancelled by user."
                        return $false
                    }
                    Write-Host "   Proceeding with diagnostic collection (expect failures)..."
                } else {
                    Write-Host "   Force mode: Proceeding with diagnostic collection (expect failures)..."
                }
                Write-Host ""
            }

            # LogPath is already set from standardized environment or legacy mode
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

                Write-Host " DEVICE: $deviceName"
                Write-Host " $("=" * ($deviceName.Length + 8))"
                Write-Host ""

                # Clean up any existing device directory from previous runs to prevent accumulation
                # This ensures each diagnostic run starts fresh and doesn't accumulate old files
                $deviceLogDir = Join-Path ([System.IO.Path]::GetDirectoryName($script:globalLogFile)) $deviceName
                if (Test-Path $deviceLogDir) {
                    try {
                        Remove-Item -Path $deviceLogDir -Recurse -Force -ErrorAction SilentlyContinue
                        if (-not $Quiet) {
                            Write-Host "   Cleaned up previous diagnostic files for $deviceName"
                        }
                    } catch {
                        # Ignore cleanup errors - they're not critical
                    }
                }

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

                # Test remote connectivity for remote devices
                if (-not $isLocalMachine) {
                    Write-Host "   Testing remote connectivity to: $deviceName"

                    # Test if remote device is reachable
                    try {
                        $pingResult = Test-Connection -ComputerName $deviceName -Count 1 -Quiet -ErrorAction Stop
                        if (-not $pingResult) {
                            throw "Ping test failed"
                        }
                        Write-Host "   [OK] Remote device is reachable"
                        "Remote Connectivity: Device is reachable via ping" | Out-File -FilePath $script:globalLogFile -Append
                    } catch {
                        Write-Host "   [WARN] Remote device not reachable: $($_.Exception.Message)"
                        "WARNING: Remote device not reachable - $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
                        $deviceResult.Warnings += "Remote device not reachable: $($_.Exception.Message)"
                    }

                    # Test PowerShell remoting
                    try {
                        $testSessionParams = @{
                            ComputerName = $deviceName
                            ErrorAction = "Stop"
                        }
                        if ($Credential) {
                            $testSessionParams.Credential = $Credential
                        }

                        $testSession = New-PSSession @testSessionParams
                        Remove-PSSession $testSession -ErrorAction SilentlyContinue
                        Write-Host "   [OK] PowerShell remoting is available"
                        "Remote Connectivity: PowerShell remoting is available" | Out-File -FilePath $script:globalLogFile -Append
                    } catch {
                        Write-Host "   [FAIL] PowerShell remoting not available: $($_.Exception.Message)"
                        Write-Host "   This device will be skipped. Enable PowerShell remoting on the target device."

                        "ERROR: PowerShell remoting not available - $($_.Exception.Message)" | Out-File -FilePath $script:globalLogFile -Append
                        "This device was skipped due to remoting issues" | Out-File -FilePath $script:globalLogFile -Append
                        "RESOLUTION: Enable PowerShell remoting on target device using: Enable-PSRemoting -Force" | Out-File -FilePath $script:globalLogFile -Append
                        "" | Out-File -FilePath $script:globalLogFile -Append

                        $deviceResult.OverallSuccess = $false
                        $deviceResult.Errors += "PowerShell remoting not available: $($_.Exception.Message)"
                        $deviceResult.DiagnosticResults += @{
                            Step = 1
                            Name = "Remote Connectivity Test"
                            Command = "Test-WSMan"
                            Success = $false
                            Duration = 0
                            ExitCode = -1
                            Error = "PowerShell remoting not available: $($_.Exception.Message)"
                        }

                        $deviceResults[$deviceName] = $deviceResult
                        $overallSuccess = $false
                        continue
                    }
                }

                # Define diagnostic commands for both local and remote machines
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
                    Write-Host "   Step $($diagnostic.Step)/$totalSteps`: $($diagnostic.Name)"
                    Write-Progress -Activity "Azure Arc Diagnostics - $deviceName" -Status $diagnostic.Name -PercentComplete (($diagnostic.Step / $totalSteps) * 100)

                    "[$($diagnostic.Step)/$totalSteps] $($diagnostic.Name.ToUpper())" | Out-File -FilePath $script:globalLogFile -Append
                    "Command: $($diagnostic.Command)" | Out-File -FilePath $script:globalLogFile -Append
                    "Description: $($diagnostic.Description)" | Out-File -FilePath $script:globalLogFile -Append
                    "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $script:globalLogFile -Append
                    "------------------------------------------------------------" | Out-File -FilePath $script:globalLogFile -Append

                    try {
                        # Build the proper command with full path if needed
                        $actualCommand = Get-AzcmagentCommand -Command $diagnostic.Command
                        Write-Host "     Executing: $actualCommand"

                        # Execute command and capture output
                        $startTime = Get-Date

                        if ($isLocalMachine) {
                            # Local execution
                            # Check if agent is available before execution
                            if (-not $script:azcmagentAvailable) {
                                throw "Azure Connected Machine Agent (azcmagent) not found in PATH or default location. Please install the agent before running diagnostics."
                            }

                            if ($diagnostic.Command -eq "azcmagent logs --full") {
                                # Special handling for logs command - it generates files
                                # Create device-specific subdirectory for log archives in same location as global log
                                $deviceLogDir = Join-Path ([System.IO.Path]::GetDirectoryName($script:globalLogFile)) $deviceName
                                if (-not (Test-Path $deviceLogDir)) {
                                    New-Item -Path $deviceLogDir -ItemType Directory -Force | Out-Null
                                } else {
                                    # Clean up any existing ZIP files from previous runs to avoid accumulation
                                    $existingZipFiles = Get-ChildItem -Path $deviceLogDir -Filter "*.zip" -ErrorAction SilentlyContinue
                                    if ($existingZipFiles.Count -gt 0) {
                                        Write-Host "     Cleaning up $($existingZipFiles.Count) existing log file(s) from previous runs..."
                                        $existingZipFiles | Remove-Item -Force -ErrorAction SilentlyContinue
                                    }
                                }

                                # Set environment variable to remove 'unknown' from filename
                                $env:COMPUTERNAME_OVERRIDE = $deviceName

                                # Use Start-Process to have better control over process completion
                                $processInfo = New-Object System.Diagnostics.ProcessStartInfo
                                $processInfo.FileName = "cmd.exe"
                                $processInfo.Arguments = "/c `"cd /d `"$deviceLogDir`" && set COMPUTERNAME=$deviceName && $actualCommand`""
                                $processInfo.UseShellExecute = $false
                                $processInfo.RedirectStandardOutput = $true
                                $processInfo.RedirectStandardError = $true
                                $processInfo.CreateNoWindow = $true

                                $process = New-Object System.Diagnostics.Process
                                $process.StartInfo = $processInfo
                                $process.Start() | Out-Null

                                # Read output asynchronously
                                $output = $process.StandardOutput.ReadToEnd()
                                $errorOutput = $process.StandardError.ReadToEnd()

                                # Wait for the process to completely finish
                                $process.WaitForExit()

                                # Combine output and error streams
                                if ($errorOutput) {
                                    $output = if ($output) { "$output`n$errorOutput" } else { $errorOutput }
                                }

                                $process.Dispose()

                                # Wait for any background file operations to complete
                                Write-Host "     Waiting for log collection to complete..."
                                Start-Sleep -Seconds 3

                                # Wait for any file system operations to settle
                                $maxWaitTime = 30
                                $waitInterval = 1
                                $elapsedTime = 0

                                do {
                                    Start-Sleep -Seconds $waitInterval
                                    $elapsedTime += $waitInterval

                                    # Check if there are any active file operations
                                    $activeProcesses = Get-Process -Name "azcmagent*" -ErrorAction SilentlyContinue
                                    if (-not $activeProcesses) {
                                        break
                                    }
                                } while ($elapsedTime -lt $maxWaitTime)

                                if (-not $Quiet) {
                                    Write-Host "     Log collection stabilized after $elapsedTime seconds"
                                }

                                # Post-process to rename any files with 'unknown' in the name
                                $zipFiles = Get-ChildItem -Path $deviceLogDir -Filter "*unknown*.zip" -ErrorAction SilentlyContinue
                                foreach ($zipFile in $zipFiles) {
                                    $newName = $zipFile.Name -replace '-unknown', ''
                                    try {
                                        Rename-Item -Path $zipFile.FullName -NewName $newName -Force
                                        Write-Host "     Renamed log archive: $newName"
                                        $deviceResult.ZipFiles += Join-Path $deviceLogDir $newName
                                    }
                                    catch {
                                        Write-Host "     Could not rename $($zipFile.Name)"
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
                                # Use Start-Process for better control over process completion
                                $processInfo = New-Object System.Diagnostics.ProcessStartInfo
                                $processInfo.FileName = "cmd.exe"
                                $processInfo.Arguments = "/c `"$actualCommand`""
                                $processInfo.UseShellExecute = $false
                                $processInfo.RedirectStandardOutput = $true
                                $processInfo.RedirectStandardError = $true
                                $processInfo.CreateNoWindow = $true

                                $process = New-Object System.Diagnostics.Process
                                $process.StartInfo = $processInfo
                                $process.Start() | Out-Null

                                # Read output asynchronously
                                $output = $process.StandardOutput.ReadToEnd()
                                $errorOutput = $process.StandardError.ReadToEnd()

                                # Wait for the process to completely finish
                                $process.WaitForExit()

                                # Combine output and error streams
                                if ($errorOutput) {
                                    $output = if ($output) { "$output`n$errorOutput" } else { $errorOutput }
                                }

                                $process.Dispose()
                            }
                        } else {
                            # Remote execution using PowerShell remoting
                            Write-Host "     Executing remotely on: $deviceName"

                            $remoteScriptBlock = {
                                param($Command, $DeviceName, $IsLogsCommand)

                                $result = @{
                                    Output = ""
                                    ErrorOutput = ""
                                    ExitCode = 0
                                    ZipFiles = @()
                                }

                                try {
                                    # Check if azcmagent is available on remote machine
                                    try {
                                        Get-Command "azcmagent" -ErrorAction Stop | Out-Null
                                    } catch {
                                        $defaultPath = "${env:ProgramFiles}\AzureConnectedMachineAgent\azcmagent.exe"
                                        if (Test-Path $defaultPath) {
                                            $Command = $Command -replace '^azcmagent', "`"$defaultPath`""
                                        } else {
                                            throw "Azure Connected Machine Agent (azcmagent) not found on remote machine"
                                        }
                                    }

                                    if ($IsLogsCommand) {
                                        # For logs command, create a temp directory and execute there
                                        $tempDir = Join-Path $env:TEMP "AzureArcDiagnostics_$DeviceName"
                                        if (-not (Test-Path $tempDir)) {
                                            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
                                        } else {
                                            # Clean up any existing ZIP files from previous runs
                                            $existingZipFiles = Get-ChildItem -Path $tempDir -Filter "*.zip" -ErrorAction SilentlyContinue
                                            if ($existingZipFiles.Count -gt 0) {
                                                $existingZipFiles | Remove-Item -Force -ErrorAction SilentlyContinue
                                            }
                                        }

                                        # Change to temp directory and execute command
                                        Push-Location $tempDir
                                        try {
                                            $processResult = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $Command -Wait -NoNewWindow -PassThru -RedirectStandardOutput "$tempDir\output.txt" -RedirectStandardError "$tempDir\error.txt"
                                            $result.ExitCode = $processResult.ExitCode

                                            # Wait for log collection to complete and files to be written
                                            Start-Sleep -Seconds 3

                                            if (Test-Path "$tempDir\output.txt") {
                                                $result.Output = Get-Content "$tempDir\output.txt" -Raw
                                            }
                                            if (Test-Path "$tempDir\error.txt") {
                                                $result.ErrorOutput = Get-Content "$tempDir\error.txt" -Raw
                                            }

                                            # Wait for any background file operations to complete
                                            $maxWaitTime = 15
                                            $waitInterval = 1
                                            $elapsedTime = 0

                                            do {
                                                Start-Sleep -Seconds $waitInterval
                                                $elapsedTime += $waitInterval

                                                # Check for ZIP files
                                                $zipFiles = Get-ChildItem -Path $tempDir -Filter "*.zip" -ErrorAction SilentlyContinue
                                                if ($zipFiles.Count -gt 0) {
                                                    break
                                                }
                                            } while ($elapsedTime -lt $maxWaitTime)

                                            # Find any ZIP files created (final check)
                                            $zipFiles = Get-ChildItem -Path $tempDir -Filter "*.zip" -ErrorAction SilentlyContinue
                                            foreach ($zipFile in $zipFiles) {
                                                $result.ZipFiles += $zipFile.FullName
                                            }
                                        } finally {
                                            Pop-Location
                                        }
                                    } else {
                                        # For regular commands, execute directly
                                        $processResult = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $Command -Wait -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\azcmagent_output.txt" -RedirectStandardError "$env:TEMP\azcmagent_error.txt"
                                        $result.ExitCode = $processResult.ExitCode

                                        if (Test-Path "$env:TEMP\azcmagent_output.txt") {
                                            $result.Output = Get-Content "$env:TEMP\azcmagent_output.txt" -Raw
                                            Remove-Item "$env:TEMP\azcmagent_output.txt" -Force -ErrorAction SilentlyContinue
                                        }
                                        if (Test-Path "$env:TEMP\azcmagent_error.txt") {
                                            $result.ErrorOutput = Get-Content "$env:TEMP\azcmagent_error.txt" -Raw
                                            Remove-Item "$env:TEMP\azcmagent_error.txt" -Force -ErrorAction SilentlyContinue
                                        }
                                    }
                                } catch {
                                    $result.Output = ""
                                    $result.ErrorOutput = $_.Exception.Message
                                    $result.ExitCode = -1
                                }

                                return $result
                            }

                            $isLogsCommand = $diagnostic.Command -eq "azcmagent logs --full"
                            $invokeParams = @{
                                ComputerName = $deviceName
                                ScriptBlock = $remoteScriptBlock
                                ArgumentList = $actualCommand, $deviceName, $isLogsCommand
                                ErrorAction = "Stop"
                            }
                            if ($Credential) {
                                $invokeParams.Credential = $Credential
                            }

                            if ($isLogsCommand) {
                                Write-Host "     Executing remote log collection (this may take a while)..."
                            }

                            $remoteResult = Invoke-Command @invokeParams

                            $output = $remoteResult.Output
                            if ($remoteResult.ErrorOutput) {
                                $output = if ($output) { "$output`n$($remoteResult.ErrorOutput)" } else { $remoteResult.ErrorOutput }
                            }

                            # Set the exit code from remote execution
                            $global:LASTEXITCODE = $remoteResult.ExitCode

                            # Log remote execution details
                            if ($isLogsCommand) {
                                "Remote log execution completed with exit code: $($remoteResult.ExitCode)" | Out-File -FilePath $script:globalLogFile -Append
                                "ZIP files found on remote: $($remoteResult.ZipFiles.Count)" | Out-File -FilePath $script:globalLogFile -Append
                                if ($remoteResult.ZipFiles.Count -gt 0) {
                                    $remoteResult.ZipFiles | ForEach-Object { "  Remote ZIP: $_" | Out-File -FilePath $script:globalLogFile -Append }
                                }
                            }

                            # Handle ZIP files from remote logs command
                            if ($isLogsCommand -and $remoteResult.ZipFiles.Count -gt 0) {
                                Write-Host "     Copying log archives from remote device..."
                                $deviceLogDir = Join-Path ([System.IO.Path]::GetDirectoryName($script:globalLogFile)) $deviceName
                                if (-not (Test-Path $deviceLogDir)) {
                                    New-Item -Path $deviceLogDir -ItemType Directory -Force | Out-Null
                                }

                                # Copy ZIP files from remote machine using PowerShell remoting
                                $copyScriptBlock = {
                                    param($ZipFilePaths)
                                    $results = @()
                                    foreach ($zipPath in $ZipFilePaths) {
                                        if (Test-Path $zipPath) {
                                            try {
                                                $content = [System.IO.File]::ReadAllBytes($zipPath)
                                                $results += @{
                                                    FileName = Split-Path $zipPath -Leaf
                                                    Content = $content
                                                    Success = $true
                                                }
                                            } catch {
                                                $results += @{
                                                    FileName = Split-Path $zipPath -Leaf
                                                    Content = $null
                                                    Success = $false
                                                    Error = $_.Exception.Message
                                                }
                                            }
                                        } else {
                                            $results += @{
                                                FileName = Split-Path $zipPath -Leaf
                                                Content = $null
                                                Success = $false
                                                Error = "File not found: $zipPath"
                                            }
                                        }
                                    }
                                    return $results
                                }

                                try {
                                    $copyParams = @{
                                        ComputerName = $deviceName
                                        ScriptBlock = $copyScriptBlock
                                        ArgumentList = @(,$remoteResult.ZipFiles)
                                        ErrorAction = "Stop"
                                    }
                                    if ($Credential) {
                                        $copyParams.Credential = $Credential
                                    }

                                    $copyResults = Invoke-Command @copyParams

                                    foreach ($copyResult in $copyResults) {
                                        if ($copyResult.Success -and $copyResult.Content) {
                                            try {
                                                $localZipPath = Join-Path $deviceLogDir $copyResult.FileName
                                                [System.IO.File]::WriteAllBytes($localZipPath, $copyResult.Content)
                                                $deviceResult.ZipFiles += $localZipPath
                                                Write-Host "     Copied log archive: $($copyResult.FileName)"
                                            } catch {
                                                Write-Host "     Could not write $($copyResult.FileName): $($_.Exception.Message)"
                                                $deviceResult.ZipFiles += "Remote: $($copyResult.FileName) (Copy failed: $($_.Exception.Message))"
                                            }
                                        } else {
                                            Write-Host "     Could not copy $($copyResult.FileName): $($copyResult.Error)"
                                            $deviceResult.ZipFiles += "Remote: $($copyResult.FileName) (Copy failed: $($copyResult.Error))"
                                        }
                                    }
                                } catch {
                                    Write-Host "     Remote file copy failed: $($_.Exception.Message)"
                                    # Fallback: try UNC path method for backward compatibility
                                    foreach ($remoteZipFile in $remoteResult.ZipFiles) {
                                        try {
                                            $remoteZipPath = "\\$deviceName\" + $remoteZipFile.Replace(":", "$")
                                            $localZipName = Split-Path $remoteZipFile -Leaf
                                            $localZipPath = Join-Path $deviceLogDir $localZipName

                                            Copy-Item -Path $remoteZipPath -Destination $localZipPath -Force
                                            $deviceResult.ZipFiles += $localZipPath
                                            Write-Host "     Copied log archive via UNC: $localZipName"
                                        } catch {
                                            Write-Host "     Could not copy $remoteZipFile via UNC: $($_.Exception.Message)"
                                            # Add the remote path to the results anyway for reference
                                            $deviceResult.ZipFiles += "Remote: $(Split-Path $remoteZipFile -Leaf) (Available on $deviceName)"
                                        }
                                    }
                                }
                            }
                        }

                        $endTime = Get-Date
                        $duration = ($endTime - $startTime).TotalSeconds

                        # Process and log output
                        if ($output) {
                            $outputString = if ($output -is [array]) { $output -join "`n" } else { $output }
                            "OUTPUT:" | Out-File -FilePath $script:globalLogFile -Append
                            $outputString | Out-File -FilePath $script:globalLogFile -Append

                            # Display summary for user
                            if (-not $Quiet) {
                                $outputLines = $outputString -split "`n"
                                $displayLines = $outputLines | Select-Object -First 5
                                foreach ($line in $displayLines) {
                                    if ($line.Trim()) {
                                        Write-Host "     $line"
                                    }
                                }
                                if ($outputLines.Count -gt 5) {
                                    Write-Host "     ... (additional output in log file)"
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
                            Write-Host "     Completed successfully ($([math]::Round($duration, 2))s)"
                        }
                        else {
                            "Status: FAILED" | Out-File -FilePath $script:globalLogFile -Append
                            $deviceResult.OverallSuccess = $false
                            $overallSuccess = $false
                            $deviceResult.Errors += "$($diagnostic.Name) failed with exit code $LASTEXITCODE"
                            Write-Host "     Command failed (Exit Code: $LASTEXITCODE)"
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

                        Write-Host "     Error: $errorMessage"

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
                    Write-Host " DEVICE STATUS: DIAGNOSTICS COMPLETED SUCCESSFULLY"
                    "RESULT: All diagnostic commands completed successfully for $deviceName" | Out-File -FilePath $script:globalLogFile -Append
                } else {
                    Write-Host " DEVICE STATUS: DIAGNOSTICS COMPLETED WITH ISSUES"
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
            Write-Host ""
            Write-Host "                     DIAGNOSTIC COLLECTION SUMMARY                       "
            Write-Host ""

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
            Write-Host "Successful Devices: $successfulDevices"
            Write-Host "Failed Devices: $failedDevices"
            Write-Host "Total Errors: $totalErrors"
            Write-Host "Total Warnings: $totalWarnings"
            Write-Host ""

            # Show detailed results per device
            "DEVICE RESULTS:" | Out-File -FilePath $script:globalLogFile -Append
            foreach ($deviceName in $deviceResults.Keys | Sort-Object) {
                $deviceResult = $deviceResults[$deviceName]
                $status = if ($deviceResult.OverallSuccess) { "SUCCESS" } else { "FAILED" }

                Write-Host "  Device: $deviceName - $status"
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
                Write-Host "Log Archives Created:"
                "ALL LOG ARCHIVES:" | Out-File -FilePath $script:globalLogFile -Append

                $localZipFiles = $allZipFiles | Where-Object { -not $_.StartsWith("Remote:") }
                $remoteZipFiles = $allZipFiles | Where-Object { $_.StartsWith("Remote:") }

                # Show local (copied) ZIP files
                if ($localZipFiles.Count -gt 0) {
                    Write-Host "  Local Archives (copied to output directory):"
                    "  LOCAL ARCHIVES (copied to output directory):" | Out-File -FilePath $script:globalLogFile -Append
                    foreach ($zipFile in $localZipFiles) {
                        $fileName = Split-Path $zipFile -Leaf
                        Write-Host "    $fileName"
                        "    $fileName" | Out-File -FilePath $script:globalLogFile -Append
                    }
                }

                # Show remote ZIP files that couldn't be copied
                if ($remoteZipFiles.Count -gt 0) {
                    Write-Host "  Remote Archives (unable to copy):"
                    "  REMOTE ARCHIVES (unable to copy):" | Out-File -FilePath $script:globalLogFile -Append
                    foreach ($zipFile in $remoteZipFiles) {
                        $displayName = $zipFile -replace "^Remote: ", ""
                        Write-Host "    $displayName"
                        "    $displayName" | Out-File -FilePath $script:globalLogFile -Append
                    }
                    Write-Host "    Note: These files remain on their respective remote devices"
                    "    Note: These files remain on their respective remote devices" | Out-File -FilePath $script:globalLogFile -Append
                }

                Write-Host ""
                Write-Host "  These ZIP files contain comprehensive diagnostic data for analysis"
                Write-Host "  Share these files with Microsoft Support when opening support cases"
                Write-Host ""
                "" | Out-File -FilePath $script:globalLogFile -Append
                "NOTE: ZIP files contain comprehensive diagnostic data for analysis" | Out-File -FilePath $script:globalLogFile -Append
                "Share these files with Microsoft Support when opening support cases" | Out-File -FilePath $script:globalLogFile -Append
                "" | Out-File -FilePath $script:globalLogFile -Append
            }

            # Display final recommendations
            if ($overallRecommendations.Count -gt 0) {
                Write-Host "Recommendations:"
                "RECOMMENDATIONS:" | Out-File -FilePath $script:globalLogFile -Append
                foreach ($recommendation in $overallRecommendations) {
                    Write-Host "  - $recommendation"
                    "  - $recommendation" | Out-File -FilePath $script:globalLogFile -Append
                }
                Write-Host ""
                "" | Out-File -FilePath $script:globalLogFile -Append
            }

            # Display output directory
            Write-Host "Output Directory: $([System.IO.Path]::GetDirectoryName($script:globalLogFile))"
            Write-Host "Consolidated Log: $(Split-Path $script:globalLogFile -Leaf)"
            Write-Host ""

            "OUTPUT DIRECTORY: $([System.IO.Path]::GetDirectoryName($script:globalLogFile))" | Out-File -FilePath $script:globalLogFile -Append
            "CONSOLIDATED LOG: $(Split-Path $script:globalLogFile -Leaf)" | Out-File -FilePath $script:globalLogFile -Append
            "" | Out-File -FilePath $script:globalLogFile -Append

            # Final status message
            if ($overallSuccess) {
                Write-Host "All device diagnostics completed successfully!"
                "FINAL RESULT: All device diagnostics completed successfully" | Out-File -FilePath $script:globalLogFile -Append
            } else {
                Write-Host "Some device diagnostics encountered issues. Review the consolidated log for details."
                "FINAL RESULT: Some device diagnostics encountered issues" | Out-File -FilePath $script:globalLogFile -Append
            }

            Write-Host "=================================================================="

            # Add session footer to log
            ("=" * 100) | Out-File -FilePath $script:globalLogFile -Append
            "DIAGNOSTIC COLLECTION SESSION COMPLETED: $(Get-Date)" | Out-File -FilePath $script:globalLogFile -Append
            "Report generated by ServerProtection PowerShell Module" | Out-File -FilePath $script:globalLogFile -Append
            "Author: Lessi Coulibaly | Organization: Less-IT | Website: https://github.com/coullessi/PowerShell" | Out-File -FilePath $script:globalLogFile -Append
            ("=" * 100) | Out-File -FilePath $script:globalLogFile -Append

            return $overallSuccess
        }
        catch {
            Write-Error "Critical error during diagnostic collection: $($_.Exception.Message)"
            return $false
        }
    }

    end {
        # Skip cleanup if user chose to quit to main menu
        if ($script:skipCleanup) {
            return
        }

        # Clean up any lingering processes and ensure all background operations are complete
        try {
            if (-not $Quiet) {
                Write-Host "`nFinalizing diagnostic collection..."
            }

            # Wait for any remaining file operations to complete
            Start-Sleep -Milliseconds 2000

            # Check for any lingering azcmagent processes that might still be writing files
            $maxCleanupWait = 10 # Maximum wait time for cleanup
            $cleanupWait = 0

            do {
                $azcmagentProcesses = Get-Process -Name "azcmagent" -ErrorAction SilentlyContinue
                if (-not $azcmagentProcesses) {
                    break
                }

                Start-Sleep -Seconds 1
                $cleanupWait++

                if ($cleanupWait -ge $maxCleanupWait) {
                    # Force terminate any remaining processes
                    $azcmagentProcesses | ForEach-Object {
                        try {
                            $_.Kill()
                            if (-not $Quiet) {
                                Write-Host "Force-terminated lingering azcmagent process (PID: $($_.Id))"
                            }
                        }
                        catch {
                            # Ignore errors when killing processes
                        }
                    }
                    break
                }
            } while ($azcmagentProcesses)

            # Final wait to ensure all file operations are flushed
            Start-Sleep -Milliseconds 1000

        }
        catch {
            # Ignore cleanup errors
        }

        if (-not $Quiet) {
            Write-Host "`nDiagnostic collection completed."
        }
    }
}



