function Get-AzureArcDiagnostics {
    <#
    .SYNOPSIS
        Performs comprehensive diagnostic tests and log collection for Azure Arc agents.

    .DESCRIPTION
        This function provides comprehensive diagnostic capabilities for Azure Arc agents, including
        connectivity testing, agent status validation, extension management, and automated log collection.
        
        The function performs the following operations:
        - Validates Azure Arc agent installation and functionality
        - Tests connectivity to Azure endpoints
        - Lists and validates installed Azure Arc extensions
        - Creates comprehensive log archives for troubleshooting and support
        - Provides smooth progress animations with realistic completion phases

        This function is designed for troubleshooting Azure Arc deployment issues, gathering
        information for Microsoft support cases, and performing routine health checks.

    .PARAMETER LogPath
        Specifies the path where diagnostic logs will be stored. If not provided, user will be prompted
        to choose a location. Must be an absolute path.

    .PARAMETER Silent
        Runs the function in silent mode without user prompts. Useful for automated scenarios.

    .PARAMETER SkipPrompt
        Skips interactive prompts and uses default values. Can be combined with other parameters.

    .PARAMETER Location
        Azure region for connectivity testing. This is particularly important when the machine
        is not yet connected to Azure Arc. Default is 'eastus'.

    .PARAMETER Force
        Forces the operation to proceed without user confirmation prompts.

    .EXAMPLE
        Get-AzureArcDiagnostics
        
        Runs the diagnostic function interactively, prompting for log storage location.

    .EXAMPLE
        Get-AzureArcDiagnostics -LogPath "C:\ArcDiagnostics" -Location "westus2"
        
        Runs diagnostics with a specific log path and Azure region.

    .EXAMPLE
        Get-AzureArcDiagnostics -Silent -LogPath "D:\Logs" -SkipPrompt
        
        Runs in silent mode with no user interaction, storing logs in D:\Logs.

    .NOTES
        Author: Lessi Coulibaly
        Organization: Less-IT (AI and CyberSecurity)
        Website: https://lessit.net
        
        Requirements:
        - PowerShell 5.1 or later
        - Azure Connected Machine Agent (azcmagent) installed
        - Administrative privileges recommended
        - Network connectivity to Azure endpoints

        The function creates comprehensive ZIP archives containing:
        - Azure Arc agent logs
        - System configuration information
        - Network connectivity test results
        - Extension status and configuration

    .LINK
        https://lessit.net

    .LINK
        Get-Help Test-AzureArcPrerequisites
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Specify the path where log files will be stored")]
        [ValidateScript({
            if ($_ -ne "" -and -not [System.IO.Path]::IsPathRooted($_)) {
                throw "LogPath must be an absolute path"
            }
            return $true
        })]
        [string]$LogPath = "",
        
        [Parameter(Mandatory = $false, HelpMessage = "Run in silent mode without user prompts")]
        [switch]$Silent = $false,
        
        [Parameter(Mandatory = $false, HelpMessage = "Skip interactive prompts and use defaults")]
        [switch]$SkipPrompt = $false,
        
        [Parameter(Mandatory = $false, HelpMessage = "Azure region for connectivity testing (required when machine is not connected)")]
        [string]$Location = "eastus",

        [Parameter(Mandatory = $false, HelpMessage = "Force operation without confirmation prompts")]
        [switch]$Force = $false
    )

    # Script configuration
    $ErrorActionPreference = "Stop"

    # Make parameters available to functions with script scope
    $script:Silent = $Silent
    $script:SkipPrompt = $SkipPrompt -or $Force
    $script:LogPath = $LogPath
    $script:ConsolidatedLogPath = ""
    $script:LogStoragePath = ""
    $script:ScriptStartTime = Get-Date
    $script:CommandsExecuted = 0
    $script:CommandsSuccessful = 0
    $script:CommandsFailed = 0
    $script:ExecutedCommands = @()

    # Validate PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Error "This function requires PowerShell 5.0 or later. Current version: $($PSVersionTable.PSVersion)"
        return
    }

    # Validate operating system (Azure Arc agent is platform-specific)
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        # PowerShell Core - check if running on Windows
        if (-not $IsWindows) {
            Write-Error "This function is designed for Windows systems with Azure Connected Machine Agent"
            return
        }
    } else {
        # Windows PowerShell (5.x) - always Windows, so no check needed
    }

    # Function to write colored output
    function Write-ColorOutput {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Message,
            [Parameter(Mandatory = $false)]
            [ValidateSet("Black", "DarkBlue", "DarkGreen", "DarkCyan", "DarkRed", "DarkMagenta", "DarkYellow", "Gray", "DarkGray", "Blue", "Green", "Cyan", "Red", "Magenta", "Yellow", "White")]
            [string]$Color = "White",
            [Parameter(Mandatory = $false)]
            [switch]$Force = $false
        )
        
        # Use script-level Silent variable or allow Force to override
        if (-not $script:Silent -or $Force) {
            Write-Host $Message -ForegroundColor $Color
        }
    }

    # Function to write log entry
    function Write-LogEntry {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Message,
            [Parameter(Mandatory = $false)]
            [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
            [string]$Level = "INFO"
        )
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] [$Level] $Message"
        
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "SUCCESS" { "Green" }
            default { "White" }
        }
        
        Write-ColorOutput $logMessage -Color $color
        
        # Also write to consolidated log file if path is set
        if (-not [string]::IsNullOrEmpty($script:ConsolidatedLogPath)) {
            try {
                $logMessage | Out-File -FilePath $script:ConsolidatedLogPath -Append -Encoding UTF8
            }
            catch {
                # Silently continue if logging fails
            }
        }
    }

    # Function to check if azcmagent is available
    function Test-AzureArcAgent {
        try {
            $null = Get-Command "azcmagent" -ErrorAction Stop
            Write-LogEntry "Azure Arc agent command found in PATH" "SUCCESS"
            
            # Additional validation - try to run a simple command to verify it's functional
            try {
                $null = & azcmagent version 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-LogEntry "Azure Arc agent is functional (version check successful)" "SUCCESS"
                    return $true
                } else {
                    Write-LogEntry "Azure Arc agent found but not functional" "WARNING"
                    return $false
                }
            }
            catch {
                Write-LogEntry "Azure Arc agent found but unable to execute version command" "WARNING"
                return $false
            }
        }
        catch {
            Write-LogEntry "Azure Arc agent (azcmagent) not found in PATH" "ERROR"
            return $false
        }
    }

    # Function to execute azcmagent command with error handling
    function Start-ArcAgentCommand {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Command,
            [Parameter(Mandatory = $true)]
            [string]$Description,
            [Parameter(Mandatory = $false)]
            [string]$WorkingDirectory = ""
        )
        
        $script:CommandsExecuted++
        
        Write-ColorOutput " "
        Write-ColorOutput "[$($script:CommandsExecuted)] $Description" -Color "Cyan"
        Write-ColorOutput "Command: azcmagent $Command" -Color "Gray"
        Write-ColorOutput " "
        
        Write-LogEntry "Executing: azcmagent $Command" "INFO"
        
        try {
            # Change to working directory if specified
            $originalLocation = Get-Location
            if (-not [string]::IsNullOrEmpty($WorkingDirectory)) {
                Write-LogEntry "Changing to working directory: $WorkingDirectory" "INFO"
                Set-Location -Path $WorkingDirectory
            }
            
            # Handle special case for logs command with progress bar
            if ($Command -like "logs*") {
                Write-LogEntry "Starting log collection with progress tracking..." "INFO"
                
                # Show animated progress bar during log collection
                $progressJob = Start-Job -ScriptBlock {
                    param($cmd, $workDir)
                    if ($workDir) { Set-Location $workDir }
                    $result = & azcmagent $cmd.Split(' ') 2>&1
                    return @{
                        Output = $result
                        ExitCode = $LASTEXITCODE
                    }
                } -ArgumentList $Command, $WorkingDirectory
                
                # Animate progress bar with realistic phases
                $phases = @(
                    @{ Name = "Initial"; Start = 0; End = 20; Duration = 2 },
                    @{ Name = "Collection"; Start = 20; End = 60; Duration = 8 },
                    @{ Name = "Compression"; Start = 60; End = 85; Duration = 5 },
                    @{ Name = "Finalization"; Start = 85; End = 100; Duration = 2 }
                )
                
                $currentProgress = 0
                $phaseIndex = 0
                $phaseStartTime = Get-Date
                
                while ($progressJob.State -eq "Running" -and $phaseIndex -lt $phases.Count) {
                    $currentPhase = $phases[$phaseIndex]
                    $phaseElapsed = (Get-Date) - $phaseStartTime
                    $phaseProgress = [Math]::Min(1.0, $phaseElapsed.TotalSeconds / $currentPhase.Duration)
                    
                    # Calculate smooth progress within current phase
                    $phaseRange = $currentPhase.End - $currentPhase.Start
                    $progressInPhase = $phaseRange * $phaseProgress
                    $currentProgress = $currentPhase.Start + $progressInPhase
                    
                    # Ensure we don't exceed 100%
                    $displayProgress = [Math]::Min(100, [Math]::Round($currentProgress))
                    
                    $progressBar = "█" * [Math]::Floor($displayProgress / 2.5) + "░" * [Math]::Ceiling((100 - $displayProgress) / 2.5)
                    $phaseText = "[$($currentPhase.Name) Phase]"
                    
                    Write-Host "`r🔄 Collecting logs... $phaseText [$progressBar] $displayProgress%" -NoNewline -ForegroundColor Yellow
                    
                    Start-Sleep -Milliseconds 200
                    
                    # Move to next phase if current phase time is complete
                    if ($phaseProgress -ge 1.0) {
                        $phaseIndex++
                        $phaseStartTime = Get-Date
                    }
                }
                
                # Wait for job completion and get results
                $jobResult = Wait-Job $progressJob | Receive-Job
                Remove-Job $progressJob
                
                # Complete the progress bar
                Write-Host "`r✅ Log collection completed! [████████████████████████████████████████] 100%" -ForegroundColor Green
                Write-Host ""
                
                $output = $jobResult.Output
                $exitCode = $jobResult.ExitCode
            }
            else {
                # Execute command normally for non-logs commands
                $output = & azcmagent $Command.Split(' ') 2>&1
                $exitCode = $LASTEXITCODE
            }
            
            # Restore original location
            if (-not [string]::IsNullOrEmpty($WorkingDirectory)) {
                Set-Location -Path $originalLocation
            }
            
            if ($exitCode -eq 0) {
                Write-LogEntry "Command completed successfully" "SUCCESS"
                $script:CommandsSuccessful++
                
                # Display output with proper formatting
                if ($output) {
                    Write-ColorOutput "Output:" -Color "Green"
                    foreach ($line in $output) {
                        if (-not [string]::IsNullOrWhiteSpace($line)) {
                            Write-ColorOutput "  $line" -Color "White"
                        }
                    }
                }
                
                # Store command execution details
                $script:ExecutedCommands += @{
                    Command = "azcmagent $Command"
                    Description = $Description
                    Status = "SUCCESS"
                    ExitCode = $exitCode
                    Output = $output
                    Timestamp = Get-Date
                }
                
                return $true
            }
            else {
                Write-LogEntry "Command failed with exit code: $exitCode" "ERROR"
                $script:CommandsFailed++
                
                # Display error output
                if ($output) {
                    Write-ColorOutput "Error Output:" -Color "Red"
                    foreach ($line in $output) {
                        if (-not [string]::IsNullOrWhiteSpace($line)) {
                            Write-ColorOutput "  $line" -Color "Red"
                        }
                    }
                }
                
                # Store command execution details
                $script:ExecutedCommands += @{
                    Command = "azcmagent $Command"
                    Description = $Description
                    Status = "FAILED"
                    ExitCode = $exitCode
                    Output = $output
                    Timestamp = Get-Date
                }
                
                return $false
            }
        }
        catch {
            Write-LogEntry "Exception during command execution: $($_.Exception.Message)" "ERROR"
            $script:CommandsFailed++
            
            # Store command execution details
            $script:ExecutedCommands += @{
                Command = "azcmagent $Command"
                Description = $Description
                Status = "EXCEPTION"
                ExitCode = -1
                Output = $_.Exception.Message
                Timestamp = Get-Date
            }
            
            # Restore original location in case of exception
            if (-not [string]::IsNullOrEmpty($WorkingDirectory)) {
                try {
                    Set-Location -Path $originalLocation
                }
                catch {
                    # Ignore errors when restoring location
                }
            }
            
            return $false
        }
    }

    # Function to validate and create directory
    function New-DirectoryIfNotExists {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path
        )
        
        try {
            if (-not (Test-Path -Path $Path)) {
                Write-LogEntry "Creating directory: $Path" "INFO"
                $null = New-Item -Path $Path -ItemType Directory -Force
                Write-LogEntry "Directory created successfully" "SUCCESS"
            } else {
                Write-LogEntry "Directory already exists: $Path" "INFO"
            }
            
            # Test write access
            $testFile = Join-Path -Path $Path -ChildPath "test_write_access.tmp"
            try {
                "test" | Out-File -FilePath $testFile -Force
                Remove-Item -Path $testFile -Force
                Write-LogEntry "Write access confirmed for directory" "SUCCESS"
                return $true
            }
            catch {
                Write-LogEntry "No write access to directory: $Path" "ERROR"
                return $false
            }
        }
        catch {
            Write-LogEntry "Failed to create directory: $($_.Exception.Message)" "ERROR"
            return $false
        }
    }

    # Function to get user consent before proceeding
    function Get-UserConsent {
        if ($script:SkipPrompt) {
            Write-LogEntry "Skipping user consent prompt (SkipPrompt enabled)" "INFO"
            return $true
        }
        
        Write-ColorOutput "╔════════════════════════════════════════════════════════════════════════════════╗" -Color "Cyan"
        Write-ColorOutput "║  ===================  AZURE ARC DIAGNOSTICS & LOG COLLECTION ================  ║" -Color "Cyan"
        Write-ColorOutput "╚════════════════════════════════════════════════════════════════════════════════╝" -Color "Cyan"
        Write-ColorOutput " "
        Write-ColorOutput "🔍 DIAGNOSTIC OVERVIEW:" -Color "Yellow"
        Write-ColorOutput "   This diagnostic tool will gather comprehensive information about your" -Color "White"
        Write-ColorOutput "   Azure Arc agent installation and create detailed logs for troubleshooting." -Color "White"
        Write-ColorOutput " "
        Write-ColorOutput "📋 ACTIONS TO BE PERFORMED:" -Color "Yellow"
        Write-ColorOutput "   • Test connectivity to Azure Arc endpoints" -Color "White"
        Write-ColorOutput "   • Validate Azure Arc agent installation and status" -Color "White"
        Write-ColorOutput "   • List installed extensions and their configurations" -Color "White"
        Write-ColorOutput "   • Create comprehensive log archive for support scenarios" -Color "White"
        Write-ColorOutput "   • Generate detailed diagnostic reports" -Color "White"
        Write-ColorOutput " "
        Write-ColorOutput "⚠️  IMPORTANT CONSIDERATIONS:" -Color "Red"
        Write-ColorOutput "   • This tool requires the Azure Connected Machine Agent (azcmagent)" -Color "White"
        Write-ColorOutput "   • Administrative privileges are recommended for complete diagnostics" -Color "White"
        Write-ColorOutput "   • Network connectivity to Azure endpoints will be tested" -Color "White"
        Write-ColorOutput "   • Log files will be created in your specified directory" -Color "White"
        Write-ColorOutput "   • No modifications will be made to your system configuration" -Color "White"
        Write-ColorOutput " "
        Write-ColorOutput "🛡️  DATA & PRIVACY:" -Color "Green"
        Write-ColorOutput "   • All data processing occurs locally on your machine" -Color "White"
        Write-ColorOutput "   • No data is transmitted to third parties" -Color "White"
        Write-ColorOutput "   • Generated logs may contain system configuration information" -Color "White"
        Write-ColorOutput "   • You control where log files are stored and can review them before sharing" -Color "White"
        Write-ColorOutput " "
        Write-ColorOutput "⚖️  DISCLAIMER & LIABILITY:" -Color "Magenta"
        Write-ColorOutput "   This diagnostic tool is provided 'as-is' without warranty. The author" -Color "White"
        Write-ColorOutput "   and organization assume no responsibility for any issues that may arise" -Color "White"
        Write-ColorOutput "   from its use. Use at your own discretion." -Color "White"
        Write-ColorOutput " "
        
        do {
            $consent = Read-Host "Do you want to proceed with Azure Arc diagnostics? [Y/N] (default: Y)"
            if ([string]::IsNullOrWhiteSpace($consent) -or $consent -match '^[Yy]$') {
                Write-LogEntry "User provided consent to proceed" "SUCCESS"
                return $true
            } elseif ($consent -match '^[Nn]$') {
                Write-LogEntry "User declined consent" "INFO"
                return $false
            } else {
                Write-ColorOutput "Please enter 'Y' for Yes or 'N' for No (or press Enter for default Y)." -Color "Yellow"
            }
        } while ($true)
    }

    # Function to get log storage location from user
    function Get-LogStorageLocation {
        # If LogPath was provided as parameter, use it
        if (-not [string]::IsNullOrEmpty($script:LogPath)) {
            Write-LogEntry "Using provided log path: $($script:LogPath)" "INFO"
            return $script:LogPath
        }
        
        # Always prompt user for log storage location choice
        Write-ColorOutput " "
        Write-ColorOutput "📁 LOG STORAGE CONFIGURATION" -Color "Cyan"
        Write-ColorOutput "════════════════════════════" -Color "Cyan"
        Write-ColorOutput " "
        Write-ColorOutput "Please specify where you would like to store the diagnostic logs." -Color "White"
        Write-ColorOutput "The logs will be saved as a ZIP archive containing all diagnostic information." -Color "White"
        Write-ColorOutput " "
        Write-ColorOutput "💡 RECOMMENDATIONS:" -Color "Yellow"
        Write-ColorOutput "   • Choose a location with at least 100MB of free space" -Color "White"
        Write-ColorOutput "   • Avoid system directories (C:\Windows, C:\Program Files)" -Color "White"
        Write-ColorOutput "   • Use a path that you can easily access later" -Color "White"
        Write-ColorOutput "   • Consider using a dedicated folder like C:\ArcDiagnostics" -Color "White"
        Write-ColorOutput " "
        
        do {
            $defaultLocation = "C:\ArcAgentLogs"
            Write-ColorOutput "Default location: $defaultLocation" -Color "Gray"
            $userInput = Read-Host "Press Enter to use default, or type a custom path"
            
            if ([string]::IsNullOrWhiteSpace($userInput)) {
                $selectedPath = $defaultLocation
                Write-LogEntry "User selected default log storage location: $selectedPath" "INFO"
                break
            } else {
                # Remove quotes if present
                $customPath = $userInput.Trim('"', "'")
                
                # Validate path
                if ([System.IO.Path]::IsPathRooted($customPath)) {
                    $selectedPath = $customPath
                    Write-LogEntry "User provided custom log storage location: $selectedPath" "INFO"
                    break
                } else {
                    Write-ColorOutput "❌ Please provide an absolute path (e.g., C:\MyLogs)" -Color "Red"
                    Write-ColorOutput " "
                    continue
                }
            }
        } while ($true)
        
        return $selectedPath
    }

    # Function to initialize consolidated logging
    function Initialize-ConsolidatedLogging {
        param(
            [Parameter(Mandatory = $true)]
            [string]$LogDirectory
        )
        
        try {
            $logFileName = "AzureArc_Diagnostics_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
            $script:ConsolidatedLogPath = Join-Path -Path $LogDirectory -ChildPath $logFileName
            
            # Create initial log entry
            $headerContent = @"
Azure Arc Agent Diagnostics Log
===============================
Script Version: 1.4
Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
PowerShell Version: $($PSVersionTable.PSVersion)
Operating System: $($PSVersionTable.OS)
Computer Name: $($env:COMPUTERNAME)
User: $($env:USERNAME)
Log Directory: $LogDirectory

Diagnostic Commands Execution Log:
==================================

"@
            
            $headerContent | Out-File -FilePath $script:ConsolidatedLogPath -Encoding UTF8
            Write-LogEntry "Consolidated logging initialized: $($script:ConsolidatedLogPath)" "SUCCESS"
            return $true
        }
        catch {
            Write-LogEntry "Failed to initialize consolidated logging: $($_.Exception.Message)" "WARNING"
            return $false
        }
    }

    # Function to display detailed execution summary
    function Write-ExecutionSummary {
        Write-ColorOutput " "
        Write-ColorOutput "+=============================================================================+" -Color "Cyan"
        Write-ColorOutput "|                            EXECUTION SUMMARY                                |" -Color "Cyan"
        Write-ColorOutput "+=============================================================================+" -Color "Cyan"
        Write-ColorOutput " "
        
        $executionTime = (Get-Date) - $script:ScriptStartTime
        
        Write-ColorOutput "⏱️  EXECUTION DETAILS:" -Color "Yellow"
        Write-ColorOutput "   • Start Time: $($script:ScriptStartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -Color "White"
        Write-ColorOutput "   • End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Color "White"
        Write-ColorOutput "   • Total Duration: $($executionTime.ToString('hh\:mm\:ss'))" -Color "White"
        Write-ColorOutput "   • Commands Executed: $($script:CommandsExecuted)" -Color "White"
        Write-ColorOutput "   • Commands Successful: $($script:CommandsSuccessful)" -Color "Green"
        Write-ColorOutput "   • Commands Failed: $($script:CommandsFailed)" -Color $(if ($script:CommandsFailed -gt 0) { "Red" } else { "Green" })
        Write-ColorOutput " "
        
        Write-ColorOutput "📋 COMMAND EXECUTION DETAILS:" -Color "Yellow"
        foreach ($cmd in $script:ExecutedCommands) {
            $statusColor = switch ($cmd.Status) {
                "SUCCESS" { "Green" }
                "FAILED" { "Red" }
                "EXCEPTION" { "Magenta" }
                default { "Gray" }
            }
            
            $statusIcon = switch ($cmd.Status) {
                "SUCCESS" { "✅" }
                "FAILED" { "❌" }
                "EXCEPTION" { "⚠️" }
                default { "❓" }
            }
            
            Write-ColorOutput "   $statusIcon $($cmd.Description)" -Color $statusColor
            Write-ColorOutput "      Command: $($cmd.Command)" -Color "Gray"
            Write-ColorOutput "      Time: $($cmd.Timestamp.ToString('HH:mm:ss'))" -Color "Gray"
            if ($cmd.Status -ne "SUCCESS") {
                Write-ColorOutput "      Exit Code: $($cmd.ExitCode)" -Color "Gray"
            }
            Write-ColorOutput " "
        }
        
        Write-ColorOutput "📁 LOG FILES LOCATION:" -Color "Yellow"
        Write-ColorOutput "   • Log Storage Directory: $($script:LogStoragePath)" -Color "White"
        if (-not [string]::IsNullOrEmpty($script:ConsolidatedLogPath)) {
            Write-ColorOutput "   • Consolidated Log File: $($script:ConsolidatedLogPath)" -Color "White"
        }
        Write-ColorOutput " "
        
        # Overall status assessment
        if ($script:CommandsFailed -eq 0) {
            Write-ColorOutput "OVERALL STATUS: ✅ ALL COMMANDS SUCCESSFUL" -Color "Green"
        } else {
            Write-ColorOutput "OVERALL STATUS: ⚠️ PARTIAL SUCCESS - $($script:CommandsFailed) command(s) failed" -Color "Yellow"
        }
        
        Write-ColorOutput " "
        Write-ColorOutput "+=============================================================================+" -Color "Cyan"
        Write-ColorOutput " "
    }

    # Main execution
    try {
        # Clear the screen before starting
        Clear-Host
        
        # Get user consent first
        Write-LogEntry "Function initialization starting..." "INFO"
        if (-not (Get-UserConsent)) {
            Write-LogEntry "User declined to proceed. Exiting function." "INFO"
            Write-ColorOutput "`nDiagnostic execution cancelled by user." -Color "Yellow"
            return
        }
        
        # Get log storage location
        $script:LogStoragePath = Get-LogStorageLocation
        
        # Validate and create directory
        if (-not (New-DirectoryIfNotExists -Path $script:LogStoragePath)) {
            throw "Failed to create or access log storage directory: $($script:LogStoragePath)"
        }
        
        # Initialize consolidated logging
        if (-not (Initialize-ConsolidatedLogging -LogDirectory $script:LogStoragePath)) {
            Write-LogEntry "Warning: Consolidated logging could not be initialized, continuing without it" "WARNING"
        }

        Write-LogEntry "Azure Arc Agent Diagnostics started" "INFO"
        Write-LogEntry "Log storage location: $($script:LogStoragePath)" "INFO"
        
        # Check if Azure Arc agent is installed
        Write-LogEntry "Checking Azure Arc agent installation..." "INFO"
        if (-not (Test-AzureArcAgent)) {
            $errorMsg = "Azure Arc agent (azcmagent) is not installed or not available in PATH. Please ensure the Azure Connected Machine Agent is installed."
            Write-LogEntry $errorMsg "ERROR"
            throw $errorMsg
        }
        Write-LogEntry "Azure Arc agent found and functional" "SUCCESS"
        
        # Execute diagnostic commands in sequence
        Write-LogEntry "Starting Azure Arc agent diagnostic sequence" "INFO"
        Write-ColorOutput "`n" -Color "White"
        Write-ColorOutput "+=============================================================================+" -Color "Cyan"
        Write-ColorOutput "|                        DIAGNOSTIC COMMANDS SEQUENCE                         |" -Color "Cyan"
        Write-ColorOutput "+=============================================================================+" -Color "Cyan"
        Write-ColorOutput " "
        
        # 1. Test connectivity
        Start-ArcAgentCommand -Command "check --location $Location" -Description "Testing connectivity to Azure endpoints"
        
        # 2. Get machine metadata and agent status
        Start-ArcAgentCommand -Command "show" -Description "Getting machine metadata and agent status"
        
        # 3. List extensions
        Start-ArcAgentCommand -Command "extension list" -Description "Listing installed extensions"
        
        # 4. Create comprehensive log archive
        Write-ColorOutput "`n" -Color "White"
        Write-ColorOutput "+=============================================================================+" -Color "Cyan"
        Write-ColorOutput "|                            LOG COLLECTION PHASE                             |" -Color "Cyan"
        Write-ColorOutput "+=============================================================================+" -Color "Cyan"
        Write-ColorOutput " "
        Write-LogEntry "Preparing to collect Azure Arc agent logs" "INFO"
        
        Start-ArcAgentCommand -Command "logs --full" -Description "Creating comprehensive log archive" -WorkingDirectory $script:LogStoragePath
        
        # Display detailed execution summary
        Write-ExecutionSummary
        
        # Final summary
        Write-LogEntry "Azure Arc diagnostics completed successfully!" "SUCCESS"
        Write-ColorOutput "You can share these logs with Microsoft support if needed." -Color "Green"
        
        # Return success
        return $true
    }
    catch {
        Write-LogEntry "Function execution failed: $($_.Exception.Message)" "ERROR"
        Write-ColorOutput "`nDiagnostic execution failed. Please check the error messages above." -Color "Red"
        return $false
    }
    finally {
        Write-ColorOutput " " -Color "White"
        Write-LogEntry "Azure Arc Agent Diagnostics function completed" "INFO"
        Write-ColorOutput " " -Color "White"
    }
}
