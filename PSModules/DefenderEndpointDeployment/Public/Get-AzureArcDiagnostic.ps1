function Get-AzureArcDiagnostic {
    <#
    .SYNOPSIS
        Performs comprehensive Azure Arc agent diagnostics and collects detailed logs for troubleshooting.

    .DESCRIPTION
        This function provides comprehensive diagnostic capabilities for Azure Arc Connected Machine Agent
        troubleshooting and analysis. It systematically executes a series of diagnostic commands to assess
        the health, configuration, and operational status of the Azure Arc agent on the local machine.

        The function performs the following diagnostic operati            # Display final summary
            if (-not $Quiet) {
                Write-Host ""
                Write-Host "=================================================================="
                Write-Host "                    DIAGNOSTIC SUMMARY                       "
                Write-Host "=================================================================="
                
                foreach ($result in $diagnosticResults) {
                    $status = if ($result.Success) { "SUCCESS" } else { "FAILED" }
                    Write-Host "  Command: $($result.Command) - Status: $status"ence:

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

    .PARAMETER Force
        When specified, skips interactive prompts and proceeds with diagnostics
        using either the provided LogPath or the current directory as default.

    .PARAMETER Quiet
        When specified, suppresses non-essential output and displays only
        critical information and results.

    .EXAMPLE
        Get-AzureArcDiagnostic
        
        # Interactive mode - prompts user for log directory selection
        # Uses current directory as default suggestion
        # Displays comprehensive progress and status information

    .EXAMPLE
        Get-AzureArcDiagnostic -LogPath "C:\AzureArcDiagnostics"
        
        # Specifies custom directory for diagnostic output
        # Creates directory if it doesn't exist
        # Stores all logs and ZIP files in specified location

    .EXAMPLE
        Get-AzureArcDiagnostic -LogPath ".\Logs" -Force
        
        # Uses relative path for log storage
        # Skips interactive prompts with Force parameter
        # Proceeds directly with diagnostic collection

    .EXAMPLE
        Get-AzureArcDiagnostic -LogPath '"C:\Azure Arc Diagnostics"' -Quiet
        
        # Uses quoted path with spaces
        # Suppresses detailed output with Quiet parameter
        # Displays only essential information

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
        - Windows 10 version 1709 and later
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
        https://lessit.net/projects/DefenderEndpointDeployment
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Directory path for storing diagnostic logs and files")]
        [ValidateNotNullOrEmpty()]
        [string]$LogPath,

        [Parameter(Mandatory = $false, HelpMessage = "Skip interactive prompts")]
        [switch]$Force,

        [Parameter(Mandatory = $false, HelpMessage = "Suppress non-essential output")]
        [switch]$Quiet
    )

    begin {
        # Initialize function
        if (-not $Quiet) {
            Write-Host ""
            Write-Host "Azure Arc Diagnostic Collection Tool"
            Write-Host "====================================="
            Write-Host "Comprehensive Agent Health and Connectivity Analysis"
            Write-Host ""
        }

        # Validate Azure Arc agent availability
        try {
            $azcmagentPath = Get-Command "azcmagent" -ErrorAction Stop
            if (-not $Quiet) {
                Write-Host "Azure Connected Machine Agent found: $($azcmagentPath.Source)"
            }
        }
        catch {
            Write-Error "Azure Connected Machine Agent (azcmagent) not found in PATH. Please ensure Azure Arc agent is installed."
            Write-Error "Download from: https://aka.ms/AzureConnectedMachineAgent"
            return $false
        }

        # Generate timestamp for file naming
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        
        # Initialize success tracking
        $overallSuccess = $true
        $diagnosticResults = @()
    }

    process {
        try {
            # Handle log path selection
            if (-not $LogPath) {
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

            # Initialize log file
            $logFile = Join-Path $LogPath "AzureArc_Diagnostic_$timestamp.log"
            $logContent = @()
            
            # Log header
            $logContent += "AZURE ARC DIAGNOSTIC COLLECTION REPORT"
            $logContent += "======================================="
            $logContent += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            $logContent += "Computer: $env:COMPUTERNAME"
            $logContent += "User: $env:USERNAME"
            $logContent += "PowerShell Version: $($PSVersionTable.PSVersion)"
            $logContent += "---------------------------------------"
            $logContent += ""

            if (-not $Quiet) {
                Write-Host ""
                Write-Host "Starting Azure Arc Diagnostic Collection..."
                Write-Host "Log file: $logFile"
                Write-Host ""
            }

            # Define diagnostic commands
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

            # Execute diagnostic commands
            foreach ($diagnostic in $diagnosticCommands) {
                if (-not $Quiet) {
                    Write-Step -Message "Step $($diagnostic.Step)/$totalSteps`: $($diagnostic.Name)"
                    Write-Progress -Activity "Azure Arc Diagnostics" -Status $diagnostic.Name -PercentComplete (($diagnostic.Step / $totalSteps) * 100)
                }

                $logContent += "[$($diagnostic.Step)/$totalSteps] $($diagnostic.Name.ToUpper())"
                $logContent += "Command: $($diagnostic.Command)"
                $logContent += "Description: $($diagnostic.Description)"
                $logContent += "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                $logContent += "------------------------------------------------------------"

                try {
                    if (-not $Quiet) {
                        Write-Host "   Executing: $($diagnostic.Command)"
                    }

                    # Execute command and capture output
                    $startTime = Get-Date
                    
                    if ($diagnostic.Command -eq "azcmagent logs --full") {
                        # Special handling for logs command - it generates files
                        # Set environment variable to remove 'unknown' from filename
                        $env:COMPUTERNAME_OVERRIDE = $env:COMPUTERNAME
                        $output = & cmd.exe /c "cd /d `"$LogPath`" && set COMPUTERNAME=$env:COMPUTERNAME && $($diagnostic.Command) 2>&1"
                        
                        # Post-process to rename any files with 'unknown' in the name
                        $zipFiles = Get-ChildItem -Path $LogPath -Filter "*unknown*.zip" -ErrorAction SilentlyContinue
                        foreach ($zipFile in $zipFiles) {
                            $newName = $zipFile.Name -replace '-unknown', ''
                            $newPath = Join-Path $LogPath $newName
                            try {
                                Rename-Item -Path $zipFile.FullName -NewName $newName -Force
                                if (-not $Quiet) {
                                    Write-Host "   Renamed log archive: $newName"
                                }
                            }
                            catch {
                                if (-not $Quiet) {
                                    Write-Host "   Could not rename $($zipFile.Name)"
                                }
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
                        $logContent += "OUTPUT:"
                        $logContent += $outputString
                        
                        # Display summary for user
                        if (-not $Quiet) {
                            $outputLines = $outputString -split "`n"
                            $displayLines = $outputLines | Select-Object -First 5
                            foreach ($line in $displayLines) {
                                if ($line.Trim()) {
                                    Write-Host "   $line"
                                }
                            }
                            if ($outputLines.Count -gt 5) {
                                Write-Host "   ... (additional output in log file)"
                            }
                        }
                    }
                    else {
                        $logContent += "OUTPUT: (No output or command completed silently)"
                    }

                    $logContent += ""
                    $logContent += "EXECUTION DETAILS:"
                    $logContent += "Duration: $([math]::Round($duration, 2)) seconds"
                    $logContent += "Exit Code: $LASTEXITCODE"
                    
                    # Determine success/failure
                    $commandSuccess = $LASTEXITCODE -eq 0
                    if ($commandSuccess) {
                        $logContent += "Status: SUCCESS"
                        if (-not $Quiet) {
                            Write-Host "   Completed successfully ($([math]::Round($duration, 2))s)"
                        }
                    }
                    else {
                        $logContent += "Status: FAILED"
                        $overallSuccess = $false
                        if (-not $Quiet) {
                            Write-Host "   Command failed (Exit Code: $LASTEXITCODE)"
                        }
                    }

                    # Store result for summary
                    $diagnosticResults += @{
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
                    $logContent += "ERROR: $errorMessage"
                    $logContent += "Status: FAILED"
                    $overallSuccess = $false
                    
                    if (-not $Quiet) {
                        Write-Host "   Error: $errorMessage"
                    }

                    $diagnosticResults += @{
                        Step = $diagnostic.Step
                        Name = $diagnostic.Name
                        Command = $diagnostic.Command
                        Success = $false
                        Duration = 0
                        ExitCode = -1
                        Error = $errorMessage
                    }
                }

                $logContent += ""
                $logContent += "------------------------------------------------------------"
                $logContent += ""

                if (-not $Quiet) {
                    Start-Sleep -Milliseconds 500  # Brief pause for readability
                }
            }

            # Generate recommendations
            $logContent += "DIAGNOSTIC SUMMARY AND RECOMMENDATIONS"
            $logContent += "======================================"
            $logContent += ""

            $successCount = ($diagnosticResults | Where-Object { $_.Success }).Count
            $logContent += "Overall Status: $successCount/$totalSteps commands completed successfully"
            $logContent += ""

            if ($overallSuccess) {
                $logContent += "RESULT: All diagnostic commands completed successfully"
                $logContent += ""
                $logContent += "RECOMMENDATIONS:"
                $logContent += "- Review the 'azcmagent show' output to verify agent configuration"
                $logContent += "- Check the 'azcmagent check' results for any connectivity warnings"
                $logContent += "- Locate and review the generated ZIP file for detailed diagnostics"
                $logContent += "- If issues persist, contact Microsoft Support with these diagnostic files"
            }
            else {
                $logContent += "RESULT: Some diagnostic commands encountered issues"
                $logContent += ""
                $logContent += "TROUBLESHOOTING RECOMMENDATIONS:"
                
                $failedCommands = $diagnosticResults | Where-Object { -not $_.Success }
                foreach ($failed in $failedCommands) {
                    $logContent += ""
                    $logContent += "FAILED Command: $($failed.Command)"
                    
                    switch ($failed.Command) {
                        "azcmagent show" {
                            $logContent += "   Possible causes:"
                            $logContent += "   - Azure Arc agent not properly installed or registered"
                            $logContent += "   - Agent service not running"
                            $logContent += "   - Insufficient permissions"
                            $logContent += "   Resolution steps:"
                            $logContent += "   - Verify agent installation: Get-Service -Name himds"
                            $logContent += "   - Check agent status: sc query himds"
                            $logContent += "   - Run as administrator if needed"
                        }
                        "azcmagent check" {
                            $logContent += "   Possible causes:"
                            $logContent += "   - Network connectivity issues to Azure endpoints"
                            $logContent += "   - Firewall or proxy blocking connections"
                            $logContent += "   - DNS resolution problems"
                            $logContent += "   - Certificate validation issues"
                            $logContent += "   Resolution steps:"
                            $logContent += "   - Check internet connectivity and DNS resolution"
                            $logContent += "   - Verify firewall allows Azure Arc endpoints"
                            $logContent += "   - Configure proxy settings if required"
                            $logContent += "   - Update system certificates"
                        }
                        "azcmagent logs --full" {
                            $logContent += "   Possible causes:"
                            $logContent += "   - Insufficient disk space for log generation"
                            $logContent += "   - Permission issues writing to target directory"
                            $logContent += "   - Agent service interruption during log collection"
                            $logContent += "   Resolution steps:"
                            $logContent += "   - Ensure sufficient disk space (minimum 100MB)"
                            $logContent += "   - Run with administrator privileges"
                            $logContent += "   - Try alternative directory with write access"
                        }
                    }
                }
                
                $logContent += ""
                $logContent += "GENERAL RECOMMENDATIONS:"
                $logContent += "1. Ensure Azure Connected Machine Agent is properly installed"
                $logContent += "2. Verify network connectivity to Azure endpoints"
                $logContent += "3. Run diagnostics with administrator privileges"
                $logContent += "4. Check Windows Event Logs for additional error details"
                $logContent += "5. Contact Microsoft Support if issues persist"
            }

            $logContent += ""
            $logContent += "ADDITIONAL RESOURCES:"
            $logContent += "- Azure Arc troubleshooting: https://docs.microsoft.com/en-us/azure/azure-arc/servers/troubleshoot-agent-onboard"
            $logContent += "- Agent installation guide: https://docs.microsoft.com/en-us/azure/azure-arc/servers/agent-overview"
            $logContent += "- Network requirements: https://docs.microsoft.com/en-us/azure/azure-arc/servers/network-requirements"
            $logContent += ""
            $logContent += "Report generated by DefenderEndpointDeployment PowerShell Module"
            $logContent += "Author: Lessi Coulibaly | Organization: Less-IT | Website: https://lessit.net"
            $logContent += "================================================================================"

            # Write log file
            try {
                $logContent | Out-File -FilePath $logFile -Encoding UTF8 -Force
                if (-not $Quiet) {
                    Write-Host "`nDiagnostic log saved: $logFile"
                }
            }
            catch {
                Write-Error "Failed to save log file: $($_.Exception.Message)"
                $overallSuccess = $false
            }

            # Clear progress
            Write-Progress -Activity "Azure Arc Diagnostics" -Completed

            # Display final summary
            if (-not $Quiet) {
                Write-Host ""
                Write-Host "┌────────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
                Write-Host "│                    📊 DIAGNOSTIC SUMMARY                       │" -ForegroundColor Cyan
                Write-Host "└────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
                
                foreach ($result in $diagnosticResults) {
                    $status = if ($result.Success) { "SUCCESS" } else { "FAILED" }
                    Write-Host "  $($result.Step). $($result.Name): $status"
                    if ($result.Duration -gt 0) {
                        Write-Host "     Duration: $([math]::Round($result.Duration, 2))s"
                    }
                }
                
                Write-Host ""
                Write-Host "Output Directory: $LogPath"
                Write-Host "Diagnostic Log: $(Split-Path $logFile -Leaf)"
                
                # Check for ZIP files created by azcmagent logs
                $zipFiles = Get-ChildItem -Path $LogPath -Filter "*.zip" | Where-Object { $_.CreationTime -gt (Get-Date).AddMinutes(-10) }
                if ($zipFiles) {
                    Write-Host "🗜️ Log Archives:" -ForegroundColor Cyan
                    foreach ($zip in $zipFiles) {
                        Write-Host "   • $($zip.Name)" -ForegroundColor Gray
                    }
                    Write-Host "   📋 The ZIP file(s) contain comprehensive diagnostic data for further analysis" -ForegroundColor Yellow
                    Write-Host "   🤝 Share these files with Microsoft Support when opening support cases" -ForegroundColor Yellow
                }
                
                if ($overallSuccess) {
                    Write-Host "`nAll diagnostics completed successfully!"
                }
                else {
                    Write-Host "`nSome diagnostics encountered issues. Review the log file for details."
                }
                
                Write-Host "=================================================================="
            }

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
