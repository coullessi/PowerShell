function Clear-ConsoleCompletely {
    <#
    .SYNOPSIS
        Completely clears the console screen and buffer.

    .DESCRIPTION
        This function performs a thorough console clear that removes all previous output,
        including any Azure CLI subscription selection tables or other unwanted output.
    #>
    try {
        # Multiple methods to ensure complete clearing
        Clear-Host

        # Try to clear console buffer (Windows specific)
        if ($IsWindows -or (-not (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue))) {
            try {
                $host.UI.RawUI.CursorPosition = @{X=0; Y=0}
                $host.UI.RawUI.BufferSize = $host.UI.RawUI.WindowSize
            } catch {
                Write-Verbose "Console buffer manipulation not supported on this host: $($_.Exception.Message)"
            }
        }

        # Alternative clear method
        [System.Console]::Clear()
    }
    catch {
        # Fallback to basic clear if advanced methods fail
        Clear-Host
    }
}

function Get-StandardizedOutputDirectory {
    <#
    .SYNOPSIS
        Provides a standardized directory selection system for the ServerProtection module.

    .DESCRIPTION
        This function implements the standardized folder selection menu as requested:
        1. Default folder: AzureArc with timestamp on user desktop (C:\Users\<UserName>\Desktop\AzureArc_YYYYMMDD_HHMMSS)
        2. Custom folder: User-provided path with validation and automatic timestamping for new folders
        3. Quit: Return to main menu (Start-ServerProtection.ps1)

        When creating new directories, timestamps are automatically added to prevent conflicts.
        The function ensures the selected directory exists and creates it if necessary.
        This is the primary folder selection mechanism for ALL scripts in the module.

    .OUTPUTS
        String containing the validated directory path, or $null if user chose to quit.
    #>
    [CmdletBinding()]
    param()

    # Get the default AzureArc folder on desktop with timestamp
    $userName = [Environment]::UserName
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $defaultFolder = Join-Path ([Environment]::GetFolderPath("Desktop")) "AzureArc_$timestamp"

    Clear-Host
    Write-Host ""
    Write-Host " FOLDER SELECTION"
    Write-Host " ================"
    Write-Host ""
    Write-Host " Please select where to store all files:"
    Write-Host ""
    Write-Host "   [1] All file(s) will be stored in: C:\Users\$userName\Desktop\AzureArc_$timestamp"
    Write-Host "       (Default recommended location with timestamp to avoid conflicts)"
    Write-Host ""
    Write-Host "   [2] Custom folder: Provide your own folder location"
    Write-Host "       (Supports various path formats)"
    Write-Host ""
    Write-Host "   [3] Quit the script and return to the main menu located under 'Start-ServerProtection.ps1'"
    Write-Host "       (Returns to the interactive menu system)"
    Write-Host ""

    do {
        $choice = Read-Host " Please enter your choice [1-3]"

        switch ($choice) {
            "1" {
                # Use default folder - exactly as specified in requirements
                if (-not (Test-Path -PathType Container $defaultFolder)) {
                    try {
                        New-Item -ItemType Directory -Path $defaultFolder -Force | Out-Null
                        Write-Host ""
                        Write-Host " [SUCCESS] Created default folder: C:\Users\$userName\Desktop\AzureArc_$timestamp"
                    }
                    catch {
                        Write-Host ""
                        Write-Host " [FAIL] Could not create default folder: $($_.Exception.Message)"
                        Write-Host " Please try a custom folder location."
                        Write-Host ""
                        continue
                    }
                } else {
                    Write-Host ""
                    Write-Host " [SUCCESS] Using existing folder: C:\Users\$userName\Desktop\AzureArc_$timestamp"
                }
                Write-Host ""
                return $defaultFolder
            }

            "2" {
                # Custom folder with specific format validation
                Write-Host ""
                Write-Host " Please provide the full path to your custom folder."
                Write-Host " If the folder doesn't exist, a timestamp will be added to prevent conflicts."
                Write-Host " Supported formats (as specified):"
                Write-Host "   C:\Users\UserName\Desktop\MyAzureArc"
                Write-Host "   'C:\Users\UserName\Desktop\MyAzureArc'"
                Write-Host '   "C:\Users\UserName\Desktop\MyAzureArc"'
                Write-Host ""

                $customPath = Read-Host " Enter custom folder path"

                if ([string]::IsNullOrWhiteSpace($customPath)) {
                    Write-Host " [FAIL] Empty path provided. Please try again."
                    Write-Host ""
                    continue
                }

                # Remove quotes if present - support all specified formats
                $customPath = $customPath.Trim('"', "'")

                # Validate the custom path format and create directory
                try {
                    # Test if path is valid format
                    $resolvedPath = [System.IO.Path]::GetFullPath($customPath)

                    # Check if directory exists
                    if (-not (Test-Path -PathType Container $resolvedPath)) {
                        # Directory doesn't exist - add timestamp to avoid conflicts
                        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                        $parentDir = [System.IO.Path]::GetDirectoryName($resolvedPath)
                        $folderName = [System.IO.Path]::GetFileName($resolvedPath)
                        $timestampedPath = Join-Path $parentDir "${folderName}_$timestamp"

                        New-Item -ItemType Directory -Path $timestampedPath -Force | Out-Null
                        Write-Host " [SUCCESS] Created custom folder with timestamp: $timestampedPath"
                        Write-Host " [INFO] Timestamp added to prevent conflicts with existing folders"
                        $resolvedPath = $timestampedPath
                    } else {
                        Write-Host " [SUCCESS] Using existing folder: $resolvedPath"
                    }

                    # Verify we can write to the directory
                    $testFile = Join-Path $resolvedPath "test_write_permissions.tmp"
                    try {
                        "test" | Out-File -FilePath $testFile -Force
                        Remove-Item -Path $testFile -Force
                        Write-Host " [SUCCESS] Folder is writable"
                    }
                    catch {
                        Write-Host " [FAIL] Cannot write to folder: $($_.Exception.Message)"
                        Write-Host ""
                        continue
                    }

                    Write-Host ""
                    return $resolvedPath
                }
                catch {
                    Write-Host " [FAIL] Invalid folder path: $($_.Exception.Message)"
                    Write-Host " Please provide a valid folder path in one of the supported formats."
                    Write-Host ""
                    continue
                }
            }

            "3" {
                # Quit to main menu - as specified in requirements
                Write-Host ""
                Write-Host " Returning to the main menu located under 'Start-ServerProtection.ps1'..." -ForegroundColor Yellow
                Write-Host ""
                return $null
            }

            default {
                Write-Host " [FAIL] Invalid choice. Please enter 1, 2, or 3." -ForegroundColor Red
                Write-Host ""
            }
        }
    } while ($true)
}

function New-TimestampedFileName {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Creates standardized timestamped filenames for the ServerProtection module.

    .DESCRIPTION
        This function generates consistent filename patterns with timestamps for various
        file types used by the ServerProtection module functions.

    .PARAMETER FileType
        The type of file to create a name for. Valid options:
        - DeviceList: Creates DeviceList-[timestamp].txt
        - OrgUnitList: Creates OrgUnitList-[timestamp].txt
        - DiagnosticLog: Creates AzureArcDiagnostic-[timestamp].log
        - PrerequisiteLog: Creates AzureArcPrerequisite-[timestamp].log
        - DeviceLog: Creates AzureArcDevice-[timestamp].log

    .PARAMETER FolderPath
        The folder path where the file will be created.

    .OUTPUTS
        String containing the full path to the timestamped file.

    .EXAMPLE
        New-TimestampedFileName -FileType "DeviceList" -FolderPath "C:\MyAzureArch"
        Returns: C:\MyAzureArch\DeviceList-20240806_143052.txt
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("DeviceList", "OrgUnitList", "DiagnosticLog", "PrerequisiteLog", "DeviceLog")]
        [string]$FileType,

        [Parameter(Mandatory = $true)]
        [string]$FolderPath
    )

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

    $fileName = switch ($FileType) {
        "DeviceList" { "DeviceList-$timestamp.txt" }
        "OrgUnitList" { "OrgUnitList-$timestamp.txt" }
        "DiagnosticLog" { "AzureArcDiagnostic-$timestamp.log" }
        "PrerequisiteLog" { "AzureArcPrerequisite-$timestamp.log" }
        "DeviceLog" { "AzureArcDevice-$timestamp.log" }
    }

    return Join-Path $FolderPath $fileName
}

function Initialize-StandardizedEnvironment {
    <#
    .SYNOPSIS
        Initializes the standardized environment for ServerProtection module functions.

    .DESCRIPTION
        This function combines folder selection and file path creation for consistent
        initialization across all ServerProtection module functions. It MUST be called
        at the beginning of every public function to ensure the standardized folder
        selection menu is shown and the AzureArc folder is properly configured.

    .PARAMETER ScriptName
        Name of the calling script (for logging purposes).

    .PARAMETER RequiredFileTypes
        Array of file types that will be needed. Valid options:
        - DeviceList, OrgUnitList, DiagnosticLog, PrerequisiteLog, DeviceLog

    .OUTPUTS
        Hashtable containing:
        - FolderPath: The selected/created folder path
        - FilePaths: Hashtable of file type -> full file path mappings
        - Success: Boolean indicating if initialization was successful
        - UserQuit: Boolean indicating if user chose to quit

    .EXAMPLE
        $env = Initialize-StandardizedEnvironment -ScriptName "Get-AzureArcPrerequisite" -RequiredFileTypes @("DeviceList", "PrerequisiteLog")
        if ($env.UserQuit) { return }
        if (-not $env.Success) { Write-Error "Failed to initialize environment" }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptName,

        [Parameter(Mandatory = $false)]
        [ValidateSet("DeviceList", "OrgUnitList", "DiagnosticLog", "PrerequisiteLog", "DeviceLog")]
        [string[]]$RequiredFileTypes = @()
    )

    $result = @{
        FolderPath = $null
        FilePaths = @{}
        Success = $false
        UserQuit = $false
    }

    # Call the standardized folder selection - this is the REQUIRED entry point
    $folderPath = Get-StandardizedOutputDirectory

    if ($null -eq $folderPath) {
        # User chose to quit - return to main menu as specified
        $result.UserQuit = $true
        return $result
    }

    # Create file paths for required file types using the selected folder
    foreach ($fileType in $RequiredFileTypes) {
        $filePath = New-TimestampedFileName -FileType $fileType -FolderPath $folderPath
        $result.FilePaths[$fileType] = $filePath
    }

    $result.FolderPath = $folderPath
    $result.Success = $true

    # Log the successful initialization with specific folder path
    Write-Host ""
    Write-Host " ENVIRONMENT READY" -ForegroundColor Green -BackgroundColor DarkBlue
    Write-Host " =================" -ForegroundColor Green -BackgroundColor DarkBlue
    Write-Host ""
    Write-Host " Working folder: $folderPath" -ForegroundColor White
    if ($RequiredFileTypes.Count -gt 0) {
        Write-Host " Files that will be created:" -ForegroundColor Gray
        foreach ($fileType in $RequiredFileTypes) {
            $fileName = [System.IO.Path]::GetFileName($result.FilePaths[$fileType])
            Write-Host "   - $fileName" -ForegroundColor Gray
        }
    }
    Write-Host ""

    return $result
}

function Write-Step {
    <#
    .SYNOPSIS
        Writes a formatted step message for progress tracking.

    .PARAMETER Message
        The message to display.

    .PARAMETER DeviceName
        Optional device name to include in the message.
    #>
    param(
        [string]$Message,
        [string]$DeviceName = ""
    )

    if ($DeviceName) {
        Write-Host "`n [$DeviceName] $Message..." -ForegroundColor Cyan
    } else {
        Write-Host "`n $Message..." -ForegroundColor Cyan
    }
}

function Write-ProgressStep {
    <#
    .SYNOPSIS
        Writes a progress indicator with step information.

    .PARAMETER Activity
        The activity name for the progress bar.

    .PARAMETER Step
        Current step number.

    .PARAMETER Total
        Total number of steps.
    #>
    param(
        [string]$Activity,
        [int]$Step,
        [int]$Total
    )

    # Guard against division by zero and invalid values
    if ($Total -le 0) {
        Write-Progress -Activity $Activity -Status "Initializing..." -PercentComplete 0
        return
    }

    # Ensure step doesn't exceed total and is not negative
    $adjustedStep = [Math]::Max(0, [Math]::Min($Step, $Total))
    $percent = [math]::Round(($adjustedStep / $Total) * 100)
    Write-Progress -Activity $Activity -Status "Step $adjustedStep of $Total" -PercentComplete $percent
}

function Test-Prerequisite {
    <#
    .SYNOPSIS
        Records and displays prerequisite test results.

    .PARAMETER DeviceName
        Name of the device being tested.

    .PARAMETER Check
        Name of the check being performed.

    .PARAMETER Result
        Result status (OK, Warning, Error, Info).

    .PARAMETER Details
        Additional details about the result.
    #>
    param (
        [string]$DeviceName,
        [string]$Check,
        [string]$Result,
        [string]$Details
    )

    $entry = [PSCustomObject]@{
        Device    = $DeviceName
        Check     = $Check
        Result    = $Result
        Details   = $Details
        Timestamp = Get-Date
    }

    # Initialize device entry as array if it doesn't exist
    if (-not $script:allResults.ContainsKey($DeviceName)) {
        $script:allResults[$DeviceName] = @()
    }

    # Add entry to device array
    $script:allResults[$DeviceName] += $entry

    # Write detailed entry to consolidated log file with timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] [$DeviceName] $Check : $Result - $Details" | Out-File -FilePath $script:globalLogFile -Append

    # Add remediation guidance for errors and warnings
    if ($Result -eq "Error" -or $Result -eq "Warning") {
        $remediation = Get-RemediationGuidance -Check $Check -Result $Result -Details $Details
        if ($remediation) {
            "    REMEDIATION: $remediation" | Out-File -FilePath $script:globalLogFile -Append
        }
    }

    # Provide immediate feedback with color coding
    $color = switch ($Result) {
        "OK" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Info" { "Cyan" }
        default { "White" }
    }
    Write-Host "    [$Result] $Check - $Details" -ForegroundColor $color
}

function Get-RemediationGuidance {
    <#
    .SYNOPSIS
        Provides specific remediation guidance for failed checks.

    .PARAMETER Check
        The name of the failed check.

    .PARAMETER Result
        The result status (Error/Warning).

    .PARAMETER Details
        Additional details about the failure.
    #>
    param(
        [string]$Check,
        [string]$Result,
        [string]$Details
    )

    switch ($Check) {
        "Network Connectivity" {
            return "Configure firewall to allow outbound HTTPS (443) to Azure endpoints. Verify DNS resolution and proxy settings. Check Service Tags: AzureActiveDirectory, AzureResourceManager, AzureArcInfrastructure, Storage."
        }
        "Windows Version" {
            return "Upgrade to supported Windows version: Windows Server 2012 R2 or later. Current version is not compatible with Azure Arc."
        }
        "PowerShell Version" {
            return "Install PowerShell 5.1+ or PowerShell 7+. Download from: https://docs.microsoft.com/powershell/scripting/install/installing-powershell"
        }
        "Azure PowerShell (Az)" {
            return "Install Azure PowerShell module: Install-Module -Name Az -Repository PSGallery -Force -Scope CurrentUser"
        }
        "Windows Services" {
            return "Start required Windows services. Run as administrator: Get-Service | Where-Object {`$_.Name -in @('WinRM','BITS','wuauserv')} | Start-Service"
        }
        "WMI Functionality" {
            return "Rebuild WMI repository: winmgmt /resetrepository &`& winmgmt /salvagerepository. Restart WMI service: Restart-Service Winmgmt"
        }
        "Execution Policy" {
            return "Set PowerShell execution policy: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force"
        }
        "Azure Arc Agent" {
            return "Download and install Azure Connected Machine Agent from: https://aka.ms/AzureConnectedMachineAgent"
        }
        "System Memory" {
            return "Add more RAM to meet minimum 4GB requirement for optimal Azure Arc performance."
        }
        "System Drive Space" {
            return "Free up disk space to meet minimum 2GB requirement. Run disk cleanup: cleanmgr /sagerun:1"
        }
        "Registry Permissions" {
            return "Ensure current user or service account has adequate registry permissions for Azure Arc operations."
        }
        "Certificate Store" {
            return "Update Windows certificate store to include required Azure root certificates. Run Windows Update."
        }
        ".NET Framework" {
            return "Install .NET Framework 4.7.2 or later: https://dotnet.microsoft.com/download/dotnet-framework"
        }
        "Group Policy" {
            return "Review and resolve Group Policy conflicts that may interfere with Azure Arc operations. Check domain policies."
        }
        "Windows Security" {
            return "Enable Windows Security Center and ensure real-time protection is active."
        }
        "Windows Update" {
            return "Configure Windows Update service. Enable automatic updates: Set-Service -Name wuauserv -StartupType Automatic; Start-Service wuauserv"
        }
        default {
            return "Review Azure Arc documentation for specific guidance: https://docs.microsoft.com/azure/azure-arc/"
        }
    }
}

function Test-DeviceConnectivity {
    <#
    .SYNOPSIS
        Tests network connectivity to a device.

    .PARAMETER DeviceName
        Name of the device to test.

    .OUTPUTS
        Boolean indicating if device is reachable.
    #>
    param([string]$DeviceName)

    try {
        $result = Test-Connection -ComputerName $DeviceName -Count 1 -Quiet -ErrorAction SilentlyContinue
        return $result
    } catch {
        return $false
    }
}

function Get-DeviceOSVersion {
    <#
    .SYNOPSIS
        Gets the operating system version of a device.

    .PARAMETER DeviceName
        Name of the device to check.

    .PARAMETER Session
        Optional PowerShell session for remote devices.

    .OUTPUTS
        String containing the OS version.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session = $null
    )

    try {
        if ($Session) {
            $osVersion = Invoke-Command -Session $Session -ScriptBlock {
                (Get-CimInstance Win32_OperatingSystem).Caption
            }
        } else {
            $osVersion = (Get-CimInstance Win32_OperatingSystem).Caption
        }

        # Extract a shorter version for display while preserving key identifiers
        $shortVersion = $osVersion

        # Handle Windows Server versions - preserve "Windows Server"
        if ($osVersion -match "Microsoft Windows Server (\d{4})") {
            $year = $matches[1]
            $shortVersion = "Windows Server $year"
        }
        # Handle other Windows versions - remove Microsoft prefix but keep Windows
        else {
            $shortVersion = $osVersion -replace "Microsoft ", "" -replace " Standard", "" -replace " Datacenter", "" -replace " Enterprise", "" -replace " Pro", "" -replace " Essentials", ""
        }

        return $shortVersion
    } catch {
        return "Unknown OS"
    }
}

function Install-AzModule {
    <#
    .SYNOPSIS
        Installs the Azure PowerShell module.

    .OUTPUTS
        Boolean indicating success or failure.
    #>
    Write-Host "`n Installing Az PowerShell module..." -ForegroundColor Yellow
    try {
        # Check if running as administrator
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

        if ($isAdmin) {
            Install-Module -Name Az -Repository PSGallery -Force -AllowClobber -Scope AllUsers
            Write-Host " Az module installed successfully for all users" -ForegroundColor Green
        } else {
            Install-Module -Name Az -Repository PSGallery -Force -AllowClobber -Scope CurrentUser
            Write-Host " Az module installed successfully for current user" -ForegroundColor Green
        }
        return $true
    } catch {
        Write-Host " Failed to install Az module: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Confirm-AzureAuthentication {
    <#
    .SYNOPSIS
        Confirms Azure authentication is available and valid.

    .DESCRIPTION
        Checks for existing Azure context and prompts for login if needed.
        This function is designed to be called before any Azure operations.

        Note: This function is maintained for backward compatibility.
        New code should use Initialize-AzureAuthenticationAndSubscription instead.

    .OUTPUTS
        Boolean indicating if authentication is successful.
    #>
    Write-Step "Ensuring Azure authentication"

    try {
        # Use the new standardized authentication function
        $authResult = Initialize-AzureAuthenticationAndSubscription
        if ($authResult.Success) {
            Write-Host "     Azure authentication successful" -ForegroundColor Green
            return $true
        } else {
            Write-Host "     Azure authentication failed: $($authResult.Message)" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "     Error during Azure authentication: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Remove-PathQuote {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Removes surrounding quotes from file paths entered by users.

    .DESCRIPTION
        This function removes single or double quotes that users might include
        when entering file paths in the console. It handles paths like:
        - C:\Folder\File.txt
        - "C:\Folder\File.txt" (with double quotes)
        - 'C:\Folder\File.txt' (with single quotes)

    .PARAMETER Path
        The file path that may contain surrounding quotes.

    .RETURNS
        The path with quotes removed.

    .EXAMPLE
        Remove-PathQuote -Path """C:\temp\file.txt"""
        Returns: C:\temp\file.txt
    #>
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    # Remove surrounding quotes (single or double)
    $cleanPath = $Path.Trim()
    if (($cleanPath.StartsWith('"') -and $cleanPath.EndsWith('"')) -or
        ($cleanPath.StartsWith("'") -and $cleanPath.EndsWith("'"))) {
        $cleanPath = $cleanPath.Substring(1, $cleanPath.Length - 2)
    }

    return $cleanPath
}

function Test-ValidPath {
    <#
    .SYNOPSIS
        Validates a file or folder path and ensures it exists or can be created.

    .DESCRIPTION
        This function provides comprehensive path validation including:
        - Path format validation
        - Path existence checking
        - Parent directory validation
        - Permission testing for creation if needed
        - Support for both file and directory paths

    .PARAMETER Path
        The file or directory path to validate.

    .PARAMETER PathType
        Specifies whether the path should be validated as a 'File' or 'Directory'. Default is 'Directory'.

    .PARAMETER CreateIfNotExists
        If specified, creates the directory path if it doesn't exist (applies to directories only).

    .PARAMETER RequireExists
        If specified, the path must already exist. If false, validates that the path can be created.

    .RETURNS
        PSCustomObject with the following properties:
        - IsValid: Boolean indicating if the path is valid
        - FullPath: The resolved full path
        - Exists: Boolean indicating if the path exists
        - Created: Boolean indicating if the path was created during validation
        - Error: String containing any error message
        - CanWrite: Boolean indicating if the location has write permissions

    .EXAMPLE
        $result = Test-ValidPath -Path "C:\MyFolder" -PathType Directory -CreateIfNotExists
        if ($result.IsValid) {
            Write-Host "Using directory: $($result.FullPath)"
        } else {
            Write-Host "Path error: $($result.Error)"
        }

    .EXAMPLE
        $result = Test-ValidPath -Path "C:\MyFile.txt" -PathType File -RequireExists
        if ($result.IsValid -and $result.Exists) {
            Write-Host "File found: $($result.FullPath)"
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [ValidateSet('File', 'Directory')]
        [string]$PathType = 'Directory',

        [Parameter(Mandatory = $false)]
        [switch]$CreateIfNotExists,

        [Parameter(Mandatory = $false)]
        [switch]$RequireExists
    )

    # Initialize result object
    $result = [PSCustomObject]@{
        IsValid = $false
        FullPath = $null
        Exists = $false
        Created = $false
        Error = $null
        CanWrite = $false
    }

    # Validate input path is not null or empty
    if ([string]::IsNullOrWhiteSpace($Path)) {
        $result.Error = "Path cannot be null or empty"
        return $result
    }

    # Clean the path
    $cleanPath = Remove-PathQuote -Path $Path.Trim()

    if ([string]::IsNullOrWhiteSpace($cleanPath)) {
        $result.Error = "Path is empty after cleaning"
        return $result
    }

    try {
        # Convert to absolute path
        if (-not [System.IO.Path]::IsPathRooted($cleanPath)) {
            $cleanPath = Join-Path (Get-Location) $cleanPath
        }

        # Validate path format
        $result.FullPath = [System.IO.Path]::GetFullPath($cleanPath)

        # Check if path exists - convert PathType to PowerShell Test-Path compatible values
        $testPathType = if ($PathType -eq 'Directory') { 'Container' } elseif ($PathType -eq 'File') { 'Leaf' } else { 'Any' }
        $result.Exists = Test-Path $result.FullPath -PathType $testPathType -ErrorAction SilentlyContinue

        # Handle RequireExists condition
        if ($RequireExists -and -not $result.Exists) {
            $result.Error = "$PathType does not exist: $($result.FullPath)"
            return $result
        }

        # For files, validate parent directory
        if ($PathType -eq 'File') {
            $parentDir = Split-Path -Path $result.FullPath -Parent
            if (-not (Test-Path $parentDir -PathType Container)) {
                if ($CreateIfNotExists) {
                    try {
                        New-Item -Path $parentDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
                        $result.Created = $true
                    }
                    catch {
                        $result.Error = "Cannot create parent directory: $($_.Exception.Message)"
                        return $result
                    }
                }
                else {
                    $result.Error = "Parent directory does not exist: $parentDir"
                    return $result
                }
            }

            # Test write permissions in parent directory
            $testFile = Join-Path $parentDir "test_write_$(Get-Random).tmp"
            try {
                "test" | Out-File -FilePath $testFile -Force -ErrorAction Stop
                Remove-Item $testFile -Force -ErrorAction SilentlyContinue
                $result.CanWrite = $true
            }
            catch {
                $result.Error = "Insufficient write permissions in directory: $parentDir"
                return $result
            }
        }
        # For directories
        else {
            if (-not $result.Exists -and $CreateIfNotExists) {
                try {
                    New-Item -Path $result.FullPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
                    $result.Created = $true
                    $result.Exists = $true
                }
                catch {
                    $result.Error = "Cannot create directory: $($_.Exception.Message)"
                    return $result
                }
            }

            # Test write permissions if directory exists
            if ($result.Exists) {
                $testFile = Join-Path $result.FullPath "test_write_$(Get-Random).tmp"
                try {
                    "test" | Out-File -FilePath $testFile -Force -ErrorAction Stop
                    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
                    $result.CanWrite = $true
                }
                catch {
                    $result.Error = "Insufficient write permissions in directory: $($result.FullPath)"
                    return $result
                }
            }
        }

        $result.IsValid = $true
    }
    catch {
        $result.Error = "Invalid path format: $($_.Exception.Message)"
    }

    return $result
}

function Get-ValidatedUserPath {
    <#
    .SYNOPSIS
        Prompts the user for a path and validates it with retry logic.

    .DESCRIPTION
        This function provides an interactive way to get a valid path from the user
        with built-in validation and retry logic. It handles path cleaning, validation,
        and provides clear feedback to the user about path issues.

    .PARAMETER Prompt
        The prompt message to display to the user.

    .PARAMETER PathType
        Specifies whether to validate as 'File' or 'Directory'. Default is 'Directory'.

    .PARAMETER DefaultValue
        A default value to use if the user presses Enter without input.

    .PARAMETER CreateIfNotExists
        If specified, creates the directory path if it doesn't exist.

    .PARAMETER RequireExists
        If specified, the path must already exist.

    .PARAMETER MaxRetries
        Maximum number of retry attempts. Default is 3.

    .RETURNS
        String containing the validated full path, or $null if validation fails after max retries.

    .EXAMPLE
        $logPath = Get-ValidatedUserPath -Prompt "Enter log directory" -PathType Directory -CreateIfNotExists
        if ($logPath) {
            Write-Host "Using directory: $logPath"
        }

    .EXAMPLE
        $deviceFile = Get-ValidatedUserPath -Prompt "Enter device list file" -PathType File -RequireExists
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [Parameter(Mandatory = $false)]
        [ValidateSet('File', 'Directory')]
        [string]$PathType = 'Directory',

        [Parameter(Mandatory = $false)]
        [string]$DefaultValue,

        [Parameter(Mandatory = $false)]
        [switch]$CreateIfNotExists,

        [Parameter(Mandatory = $false)]
        [switch]$RequireExists,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3
    )

    $attempt = 0

    do {
        $attempt++

        # Build the prompt with default value if provided
        $fullPrompt = $Prompt
        if (-not [string]::IsNullOrWhiteSpace($DefaultValue)) {
            $fullPrompt += " [default: $DefaultValue]"
        }

        # Get user input
        $userInput = Read-Host $fullPrompt

        # Use default if no input provided
        if ([string]::IsNullOrWhiteSpace($userInput) -and -not [string]::IsNullOrWhiteSpace($DefaultValue)) {
            $userInput = $DefaultValue
        }

        # Skip validation if still empty
        if ([string]::IsNullOrWhiteSpace($userInput)) {
            Write-Host "   [WARN] No path provided" -ForegroundColor Yellow
            continue
        }

        # Validate the path
        $validation = Test-ValidPath -Path $userInput -PathType $PathType -CreateIfNotExists:$CreateIfNotExists -RequireExists:$RequireExists

        if ($validation.IsValid) {
            if ($validation.Created) {
                Write-Host "   [OK] Created and using $PathType`: $($validation.FullPath)" -ForegroundColor Green
            } elseif ($validation.Exists) {
                Write-Host "   [OK] Using existing $PathType`: $($validation.FullPath)" -ForegroundColor Green
            } else {
                Write-Host "   [OK] Validated $PathType path: $($validation.FullPath)" -ForegroundColor Green
            }
            return $validation.FullPath
        }
        else {
            Write-Host "   [FAIL] $($validation.Error)" -ForegroundColor Red
            if ($attempt -lt $MaxRetries) {
                Write-Host "   Please try again ($attempt/$MaxRetries attempts)" -ForegroundColor Yellow
            }
        }

    } while ($attempt -lt $MaxRetries)

    Write-Host "   [FAIL] Maximum retry attempts reached. Path validation failed." -ForegroundColor Red
    return $null
}

function New-StandardizedOutputFile {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Creates a standardized file path in the module's output directory.

    .DESCRIPTION
        This function creates file paths that follow the module's standardized
        file organization approach. All generated files are placed in the same
        directory as selected by the user for consistency.

    .PARAMETER FileName
        The name of the file to create a path for.

    .PARAMETER Timestamp
        Whether to include a timestamp in the filename. Default is $true.

    .PARAMETER Extension
        The file extension to use if not included in FileName.

    .OUTPUTS
        String containing the full standardized file path.

    .EXAMPLE
        $logFile = New-StandardizedOutputFile -FileName "MyLog" -Extension ".log"
        # Returns: C:\UserSelectedDirectory\MyLog_20250723-090000.log

    .EXAMPLE
        $reportFile = New-StandardizedOutputFile -FileName "Report.txt" -Timestamp:$false
        # Returns: C:\UserSelectedDirectory\Report.txt
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName,

        [Parameter(Mandatory = $false)]
        [bool]$Timestamp = $true,

        [Parameter(Mandatory = $false)]
        [string]$Extension = ""
    )

    $outputDir = Get-StandardizedOutputDirectory

    # Extract name and extension if not provided separately
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $fileExt = [System.IO.Path]::GetExtension($FileName)

    # Use provided extension if original filename doesn't have one
    if ([string]::IsNullOrWhiteSpace($fileExt) -and -not [string]::IsNullOrWhiteSpace($Extension)) {
        $fileExt = $Extension
        if (-not $fileExt.StartsWith(".")) {
            $fileExt = ".$fileExt"
        }
    }

    # Add timestamp if requested
    if ($Timestamp) {
        $timestampString = Get-Date -Format "yyyyMMdd-HHmmss"
        $finalFileName = "$baseName`_$timestampString$fileExt"
    } else {
        $finalFileName = "$baseName$fileExt"
    }

    return Join-Path $outputDir $finalFileName
}

function Initialize-AzureAuthenticationAndSubscription {
    <#
    .SYNOPSIS
        Standardized Azure authentication and subscription selection for the ServerProtection module.

    .DESCRIPTION
        This function provides consistent Azure authentication and subscription selection across all functions
        in the ServerProtection module. It ensures users are authenticated, retrieves all available
        subscriptions, and always prompts for subscription selection to set the appropriate context.

        Even if the user is already logged in and authenticated, this function will present all available
        subscriptions for selection to ensure the user can choose the correct subscription context.

    .PARAMETER SubscriptionId
        Optional. Azure subscription ID to use. If provided, the function will validate and use this subscription.
        If not provided or invalid, user will be prompted to select from available subscriptions.

    .OUTPUTS
        Hashtable containing:
        - Success: Boolean indicating if authentication and subscription selection was successful
        - Context: The Azure context object
        - SubscriptionId: The selected subscription ID
        - SubscriptionName: The selected subscription name
        - Message: Any relevant message or error information

    .EXAMPLE
        $authResult = Initialize-AzureAuthenticationAndSubscription
        if ($authResult.Success) {
            Write-Host "Using subscription: $($authResult.SubscriptionName)"
        }

    .EXAMPLE
        $authResult = Initialize-AzureAuthenticationAndSubscription -SubscriptionId "12345678-1234-1234-1234-123456789012"
        if ($authResult.Success) {
            Write-Host "Using provided subscription: $($authResult.SubscriptionName)"
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$SubscriptionId
    )

    $result = @{
        Success = $false
        Context = $null
        SubscriptionId = $null
        SubscriptionName = $null
        Message = ""
    }

    try {
        # Check if Azure PowerShell module is available
        try {
            $azModule = Get-Module -Name Az.Accounts -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
            if (-not $azModule) {
                $result.Message = "Azure PowerShell module (Az.Accounts) is not installed. Please install it with: Install-Module -Name Az -AllowClobber -Scope CurrentUser"
                Write-Host "`[-`] $($result.Message)" -ForegroundColor Red
                return $result
            }

            # Import the module if not already loaded
            if (-not (Get-Module -Name Az.Accounts)) {
                Import-Module Az.Accounts -Force -WarningAction SilentlyContinue
            }
        }
        catch {
            $result.Message = "Failed to check or load Azure PowerShell module: $($_.Exception.Message)"
            Write-Host "`[-`] $($result.Message)" -ForegroundColor Red
            return $result
        }

        # Configure Azure PowerShell to reduce verbose output while allowing interactive authentication
        $originalWarningPreference = $WarningPreference
        $originalProgressPreference = $ProgressPreference
        $originalInformationPreference = $InformationPreference

        $WarningPreference = 'SilentlyContinue'
        $ProgressPreference = 'SilentlyContinue'
        $InformationPreference = 'SilentlyContinue'

        # Disable Azure PowerShell context auto-save and configure for minimal output
        try {
            Disable-AzContextAutosave -Scope Process -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
            # Set Azure CLI environment variables to minimize output
            $env:AZURE_CORE_NO_COLOR = "true"
            $env:AZURE_CORE_OUTPUT = "none"
        } catch {
            Write-Verbose "Could not set Azure environment variables: $($_.Exception.Message)"
        }

        #region Authentication
        # Check if user is authenticated, if not, authenticate
        $context = $null
        $needsAuthentication = $false
        try {
            $context = Get-AzContext -ErrorAction SilentlyContinue
            if (-not $context -or -not $context.Account) {
                $needsAuthentication = $true
            }
        }
        catch {
            # Context not available, need to authenticate
            $needsAuthentication = $true
        }

        if ($needsAuthentication) {
            try {
                # Completely suppress all console output during authentication
                $originalOut = [Console]::Out
                $originalError = [Console]::Error
                $nullWriter = New-Object System.IO.StringWriter

                try {
                    # Redirect both output and error streams
                    [Console]::SetOut($nullWriter)
                    [Console]::SetError($nullWriter)

                    # Authenticate with maximum suppression flags
                    Connect-AzAccount -Force -SkipContextPopulation -ErrorAction Stop -WarningAction SilentlyContinue -InformationAction SilentlyContinue -ProgressAction SilentlyContinue | Out-Null
                }
                finally {
                    # Always restore console streams
                    [Console]::SetOut($originalOut)
                    [Console]::SetError($originalError)
                    $nullWriter.Dispose()
                }

                # Clear screen completely to remove any residual output
                Clear-ConsoleCompletely

                # Validate authentication
                $context = Get-AzContext -ErrorAction SilentlyContinue
                if (-not $context -or -not $context.Account) {
                    throw "Authentication completed but no valid context available"
                }
            }
            catch {
                try {
                    # Ultimate fallback: Use Start-Job to isolate authentication completely
                    Write-Host "`[*`] Authenticating to Azure (please complete authentication in popup)..." -ForegroundColor Yellow

                    $authJob = Start-Job -ScriptBlock {
                        Import-Module Az.Accounts -Force -WarningAction SilentlyContinue
                        $WarningPreference = 'SilentlyContinue'
                        $ProgressPreference = 'SilentlyContinue'
                        $InformationPreference = 'SilentlyContinue'

                        # Authenticate in isolated job context
                        Connect-AzAccount -Force -SkipContextPopulation -ErrorAction Stop -WarningAction SilentlyContinue
                    } | Out-Null

                    # Wait for authentication job with timeout
                    $timeout = 300 # 5 minutes
                    $authJob | Wait-Job -Timeout $timeout | Out-Null

                    if ($authJob.State -eq 'Completed') {
                        # Clear screen and check context
                        Clear-ConsoleCompletely
                        $context = Get-AzContext -ErrorAction SilentlyContinue
                        if (-not $context -or -not $context.Account) {
                            throw "Job authentication completed but no context available"
                        }
                    } else {
                        $authJob | Stop-Job -ErrorAction SilentlyContinue
                        throw "Authentication job timed out or failed"
                    }

                    # Clean up job
                    $authJob | Remove-Job -Force -ErrorAction SilentlyContinue
                }
                catch {
                    $result.Message = "Failed to authenticate to Azure. Error: $($_.Exception.Message). Please ensure you have proper Azure access and try running 'Connect-AzAccount' manually first."
                    Write-Host "`[-`] $($result.Message)" -ForegroundColor Red
                    return $result
                }
            }
        } else {
            # User was already authenticated - clear screen for consistent experience
            Clear-ConsoleCompletely
        }

        # Validate context but don't show authentication details yet
        if (-not ($context -and $context.Account)) {
            $result.Message = "Authentication completed but no valid context found. Please try running 'Connect-AzAccount' manually."
            Write-Host "`[-`] $($result.Message)" -ForegroundColor Red
            return $result
        }
        #endregion

        #region Subscription Selection
        # Show authentication success and start subscription selection
        Write-Host " Authentication completed successfully!" -ForegroundColor Green
        Write-Host "`[+`] Authenticated as: $($context.Account.Id)" -ForegroundColor Green
        Write-Host "`[*`] Subscription Selection" -ForegroundColor Cyan

        $subs = @()
        try {
            # Get subscriptions and suppress only the potential verbose output, not errors
            Write-Host "`[*`] Retrieving available subscriptions..." -ForegroundColor Yellow

            $subs += Get-AzSubscription -WarningAction SilentlyContinue -ErrorAction Stop

            Write-Host "`[+`] Found $($subs.Count) subscription(s)" -ForegroundColor Green
        }
        catch {
            $result.Message = "Failed to retrieve Azure subscriptions. Please check your authentication and permissions. Error: $($_.Exception.Message)"
            Write-Host "`[-`] $($result.Message)" -ForegroundColor Red

            # Try to get context again to see if authentication is still valid
            try {
                $contextCheck = Get-AzContext -ErrorAction Stop
                if (-not $contextCheck) {
                    Write-Host "`[-`] Azure context is no longer valid. Please restart and authenticate again." -ForegroundColor Red
                }
            }
            catch {
                Write-Host "`[-`] Azure context check failed. Please restart and authenticate again." -ForegroundColor Red
            }
            return $result
        }

        if ($subs.Count -eq 0) {
            $result.Message = "No accessible subscriptions found. Please check your Azure account permissions or contact your Azure administrator."
            Write-Host "`[-`] $($result.Message)" -ForegroundColor Red
            return $result
        }

        # Always display available subscriptions to user for selection
        # Use provided subscription or prompt user
        if ($SubscriptionId) {
            $selectedSub = $subs | Where-Object { $_.Id -eq $SubscriptionId }
            if (-not $selectedSub) {
                Write-Host "`[-`] Subscription ID '$SubscriptionId' not found. Please check and try again." -ForegroundColor Red
                # Fall through to subscription selection prompt
                $SubscriptionId = $null
            } else {
                $subName = $selectedSub.Name
                $subId = $selectedSub.Id
                Write-Host "`[+`] Using provided subscription: $subName" -ForegroundColor Green
            }
        }

        # If no subscription provided or invalid subscription, prompt user to select
        if (-not $SubscriptionId) {
            # Display available subscriptions - show only subscription names (no sensitive info)
            Write-Host ""
            Write-Host "`[*`] Available subscription(s):" -ForegroundColor Green
            for ($i = 0; $i -lt $subs.Count; $i++) {
                Write-Host "[$($i+1)] $($subs[$i].Name)" -ForegroundColor White
            }
            Write-Host ""

            $defaultSub = 1
            do {
                $subRank = Read-Host "Select a subscription (default: $defaultSub)"
                if ([string]::IsNullOrWhiteSpace($subRank)) {
                    $subRank = $defaultSub
                } else {
                    # Try to convert to integer
                    try {
                        $subRank = [int]$subRank
                    } catch {
                        Write-Host "`[-`] Please enter a valid number." -ForegroundColor Yellow
                        $subRank = 0  # Force retry
                        continue
                    }
                }

                if ($subRank -lt 1 -or $subRank -gt $subs.Count) {
                    Write-Host "`[-`] Enter a valid number between 1 and $($subs.Count)" -ForegroundColor Yellow
                }
            } while ($subRank -lt 1 -or $subRank -gt $subs.Count)

            $selectedSub = $subs[$subRank - 1]
            $subName = $selectedSub.Name
            $subId = $selectedSub.Id
        }

        # Set the Azure context to the selected subscription
        Write-Host "`[*`] Setting Azure context to selected subscription..." -ForegroundColor Yellow
        try {
            $setContextResult = Set-AzContext -SubscriptionId $subId -WarningAction SilentlyContinue -ErrorAction Stop

            if ($setContextResult) {
                $context = Get-AzContext -ErrorAction Stop
                Write-Host "`[+`] Successfully set context to subscription: $subName" -ForegroundColor Green
            } else {
                throw "Set-AzContext returned null"
            }
        }
        catch {
            $result.Message = "Failed to set Azure context to subscription '$subName'. Error: $($_.Exception.Message). Please verify you have access to this subscription."
            Write-Host "`[-`] $($result.Message)" -ForegroundColor Red

            # Try to list current context for debugging
            try {
                $currentContext = Get-AzContext -ErrorAction SilentlyContinue
                if ($currentContext) {
                    Write-Host "`[-`] Current context is set to: $($currentContext.Subscription.Name)" -ForegroundColor Yellow
                } else {
                    Write-Host "`[-`] No current Azure context found" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "`[-`] Unable to retrieve current context" -ForegroundColor Yellow
            }
            return $result
        }
        #endregion

        # Populate successful result
        $result.Success = $true
        $result.Context = $context
        $result.SubscriptionId = $subId
        $result.SubscriptionName = $subName
        $result.Message = "Successfully authenticated and set subscription context"

        # Final validation (silent)
        if ($context.Subscription.Id -ne $subId) {
            Write-Host "`[!`] Warning: Context subscription ID doesn't match selected subscription" -ForegroundColor Yellow
        }

        Write-Host ""

        # Restore original preferences
        $WarningPreference = $originalWarningPreference
        $ProgressPreference = $originalProgressPreference
        $InformationPreference = $originalInformationPreference

        # Clean up environment variables
        if ($env:AZURE_CORE_NO_COLOR) { Remove-Item -Path "env:AZURE_CORE_NO_COLOR" -ErrorAction SilentlyContinue }
        if ($env:AZURE_CORE_OUTPUT) { Remove-Item -Path "env:AZURE_CORE_OUTPUT" -ErrorAction SilentlyContinue }

        return $result
    }
    catch {
        # Restore original preferences in case of error
        if ($originalWarningPreference) { $WarningPreference = $originalWarningPreference }
        if ($originalProgressPreference) { $ProgressPreference = $originalProgressPreference }
        if ($originalInformationPreference) { $InformationPreference = $originalInformationPreference }

        # Clean up environment variables in case of error
        if ($env:AZURE_CORE_NO_COLOR) { Remove-Item -Path "env:AZURE_CORE_NO_COLOR" -ErrorAction SilentlyContinue }
        if ($env:AZURE_CORE_OUTPUT) { Remove-Item -Path "env:AZURE_CORE_OUTPUT" -ErrorAction SilentlyContinue }

        $result.Message = "Error during Azure authentication: $($_.Exception.Message)"
        Write-Host "`[-`] $($result.Message)" -ForegroundColor Red
        return $result
    }
}



