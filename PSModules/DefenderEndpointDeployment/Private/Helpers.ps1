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
        Write-Host "`n🔍 [$DeviceName] $Message..." -ForegroundColor Cyan
    } else {
        Write-Host "`n🔍 $Message..." -ForegroundColor Cyan
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

function Test-Prerequisites {
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
            return "Upgrade to supported Windows version: Windows 10 1709+, Windows 11, or Windows Server 2012 R2+. Current version is not compatible with Azure Arc."
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
            return "Rebuild WMI repository: winmgmt /resetrepository && winmgmt /salvagerepository. Restart WMI service: Restart-Service Winmgmt"
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
        # Handle Windows 11 client versions - preserve "Windows 11"
        elseif ($osVersion -match "Microsoft Windows 11") {
            $shortVersion = "Windows 11"
        }
        # Handle Windows 10 client versions - preserve "Windows 10"
        elseif ($osVersion -match "Microsoft Windows 10") {
            $shortVersion = "Windows 10"
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
    Write-Host "`n🔽 Installing Az PowerShell module..." -ForegroundColor Yellow
    try {
        # Check if running as administrator
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        
        if ($isAdmin) {
            Install-Module -Name Az -Repository PSGallery -Force -AllowClobber -Scope AllUsers
            Write-Host "✅ Az module installed successfully for all users" -ForegroundColor Green
        } else {
            Install-Module -Name Az -Repository PSGallery -Force -AllowClobber -Scope CurrentUser
            Write-Host "✅ Az module installed successfully for current user" -ForegroundColor Green
        }
        return $true
    } catch {
        Write-Host "❌ Failed to install Az module: $($_.Exception.Message)" -ForegroundColor Red
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
            Write-Host "    ✅ Azure authentication successful" -ForegroundColor Green
            return $true
        } else {
            Write-Host "    ❌ Azure authentication failed: $($authResult.Message)" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "    ❌ Error during Azure authentication: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Remove-PathQuotes {
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
        Remove-PathQuotes -Path """C:\temp\file.txt"""
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

function Get-StandardizedOutputDirectory {
    <#
    .SYNOPSIS
        Gets the standardized output directory used across all module functions.
    
    .DESCRIPTION
        This function provides a consistent way to determine where all generated files
        should be stored. It uses the global log file directory if available, 
        otherwise falls back to the current directory.
        
        This ensures all files generated by any function in the module are stored
        in the same location as selected by the user.
    
    .OUTPUTS
        String containing the standardized output directory path.
    
    .EXAMPLE
        $outputDir = Get-StandardizedOutputDirectory
        $myFile = Join-Path $outputDir "MyGeneratedFile.txt"
    #>
    
    # Check if we have a global log file path established
    if ($script:globalLogFile -and -not [string]::IsNullOrWhiteSpace($script:globalLogFile)) {
        $logDirectory = Split-Path -Path $script:globalLogFile -Parent
        if ($logDirectory -and (Test-Path $logDirectory -PathType Container)) {
            return $logDirectory
        }
    }
    
    # Fallback to current directory
    return "."
}

function New-StandardizedOutputFile {
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
        Standardized Azure authentication and subscription selection for the DefenderEndpointDeployment module.
    
    .DESCRIPTION
        This function provides consistent Azure authentication and subscription selection across all functions
        in the DefenderEndpointDeployment module. It ensures users are authenticated, retrieves all available
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
                Write-Host "[-] $($result.Message)" -ForegroundColor Red
                return $result
            }
            
            # Import the module if not already loaded
            if (-not (Get-Module -Name Az.Accounts)) {
                Import-Module Az.Accounts -Force -WarningAction SilentlyContinue
            }
        }
        catch {
            $result.Message = "Failed to check or load Azure PowerShell module: $($_.Exception.Message)"
            Write-Host "[-] $($result.Message)" -ForegroundColor Red
            return $result
        }

        # Configure Azure PowerShell to reduce verbose output while allowing interactive authentication
        $originalWarningPreference = $WarningPreference
        $WarningPreference = 'SilentlyContinue'
        
        # Disable Azure PowerShell context auto-save to reduce noise
        try {
            Disable-AzContextAutosave -Scope Process -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
        } catch {
            # Ignore if the command fails
        }

        #region Authentication
        Write-Host "[*] Azure Authentication & Setup" -ForegroundColor Cyan

        # Check if user is authenticated, if not, authenticate
        $context = $null
        try {
            $context = Get-AzContext -ErrorAction SilentlyContinue
        }
        catch {
            # Context not available, need to authenticate
            $context = $null
        }
        
        if (-not $context -or -not $context.Account) {
            Write-Host "[*] No Azure authentication found. Authenticating..." -ForegroundColor Yellow
            Write-Host "Please complete authentication in your browser..." -ForegroundColor Cyan
            
            try {
                # Use direct Connect-AzAccount instead of jobs for better reliability
                $authResult = Connect-AzAccount -ErrorAction Stop -WarningAction SilentlyContinue
                
                if ($authResult) {
                    # Clear the screen to remove any sensitive information
                    Start-Sleep -Milliseconds 500
                    Clear-Host
                    
                    Write-Host "🚀 Azure Arc & MDE Prerequisites Checker..." -ForegroundColor Cyan
                    Write-Host "✅ Authentication completed successfully!" -ForegroundColor Green
                    
                    $context = Get-AzContext
                } else {
                    throw "Authentication failed - no context returned"
                }
            }
            catch {
                Write-Host "[-] Authentication failed. Please try again..." -ForegroundColor Red
                Write-Host "[-] Error: $($_.Exception.Message)" -ForegroundColor Red
                
                try {
                    # Second attempt with device code authentication
                    Write-Host "[*] Attempting device code authentication..." -ForegroundColor Yellow
                    $authResult = Connect-AzAccount -UseDeviceAuthentication -ErrorAction Stop -WarningAction SilentlyContinue
                    
                    if ($authResult) {
                        Start-Sleep -Milliseconds 500
                        Clear-Host
                        
                        Write-Host "🚀 Azure Arc & MDE Prerequisites Checker..." -ForegroundColor Cyan
                        Write-Host "✅ Authentication completed successfully!" -ForegroundColor Green
                        
                        $context = Get-AzContext
                    } else {
                        throw "Device code authentication failed"
                    }
                }
                catch {
                    $result.Message = "Failed to authenticate to Azure. Error: $($_.Exception.Message). Please ensure you have proper Azure access and try running 'Connect-AzAccount' manually first."
                    Write-Host "[-] $($result.Message)" -ForegroundColor Red
                    return $result
                }
            }
        }
        
        if ($context -and $context.Account) {
            Write-Host "[+] Authenticated as: $($context.Account.Id)" -ForegroundColor Green
        } else {
            $result.Message = "Authentication completed but no valid context found. Please try running 'Connect-AzAccount' manually."
            Write-Host "[-] $($result.Message)" -ForegroundColor Red
            return $result
        }
        #endregion

        #region Subscription Selection
        Write-Host "[*] Subscription Selection" -ForegroundColor Cyan

        $subs = @()
        try {
            # Get subscriptions with better error handling
            Write-Host "[*] Retrieving available subscriptions..." -ForegroundColor Yellow
            $subs += Get-AzSubscription -WarningAction SilentlyContinue -ErrorAction Stop
            Write-Host "[+] Found $($subs.Count) subscription(s)" -ForegroundColor Green
        }
        catch {
            $result.Message = "Failed to retrieve Azure subscriptions. Please check your authentication and permissions. Error: $($_.Exception.Message)"
            Write-Host "[-] $($result.Message)" -ForegroundColor Red
            
            # Try to get context again to see if authentication is still valid
            try {
                $contextCheck = Get-AzContext -ErrorAction Stop
                if (-not $contextCheck) {
                    Write-Host "[-] Azure context is no longer valid. Please restart and authenticate again." -ForegroundColor Red
                }
            }
            catch {
                Write-Host "[-] Azure context check failed. Please restart and authenticate again." -ForegroundColor Red
            }
            return $result
        }
        
        if ($subs.Count -eq 0) {
            $result.Message = "No accessible subscriptions found. Please check your Azure account permissions or contact your Azure administrator."
            Write-Host "[-] $($result.Message)" -ForegroundColor Red
            return $result
        }

        # Always display available subscriptions to user for selection
        # Use provided subscription or prompt user
        if ($SubscriptionId) {
            $selectedSub = $subs | Where-Object { $_.Id -eq $SubscriptionId }
            if (-not $selectedSub) {
                Write-Host "[-] Subscription ID '$SubscriptionId' not found. Please check and try again." -ForegroundColor Red
                # Fall through to subscription selection prompt
                $SubscriptionId = $null
            } else {
                $subName = $selectedSub.Name
                $subId = $selectedSub.Id
                Write-Host "[+] Using provided subscription: $subName" -ForegroundColor Green
            }
        }
        
        # If no subscription provided or invalid subscription, prompt user to select
        if (-not $SubscriptionId) {
            # Display available subscriptions - show only subscription names (no sensitive info)
            Write-Host ""
            Write-Host "[*] Available subscription(s):" -ForegroundColor Green
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
                        Write-Host "[-] Please enter a valid number." -ForegroundColor Yellow
                        $subRank = 0  # Force retry
                        continue
                    }
                }
                
                if ($subRank -lt 1 -or $subRank -gt $subs.Count) {
                    Write-Host "[-] Enter a valid number between 1 and $($subs.Count)" -ForegroundColor Yellow
                }
            } while ($subRank -lt 1 -or $subRank -gt $subs.Count)

            $selectedSub = $subs[$subRank - 1]
            $subName = $selectedSub.Name
            $subId = $selectedSub.Id
        }

        # Set the Azure context to the selected subscription
        Write-Host "[*] Setting Azure context to selected subscription..." -ForegroundColor Yellow
        try {
            $setContextResult = Set-AzContext -SubscriptionId $subId -WarningAction SilentlyContinue -ErrorAction Stop
            if ($setContextResult) {
                $context = Get-AzContext -ErrorAction Stop
                Write-Host "[+] Successfully set context to subscription: $subName" -ForegroundColor Green
            } else {
                throw "Set-AzContext returned null"
            }
        }
        catch {
            $result.Message = "Failed to set Azure context to subscription '$subName'. Error: $($_.Exception.Message). Please verify you have access to this subscription."
            Write-Host "[-] $($result.Message)" -ForegroundColor Red
            
            # Try to list current context for debugging
            try {
                $currentContext = Get-AzContext -ErrorAction SilentlyContinue
                if ($currentContext) {
                    Write-Host "[-] Current context is set to: $($currentContext.Subscription.Name)" -ForegroundColor Yellow
                } else {
                    Write-Host "[-] No current Azure context found" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "[-] Unable to retrieve current context" -ForegroundColor Yellow
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
        
        # Final validation
        if ($context.Subscription.Id -eq $subId) {
            Write-Host "[+] ✅ Azure authentication and subscription setup completed successfully!" -ForegroundColor Green
            Write-Host "[+] Current subscription: $($context.Subscription.Name)" -ForegroundColor Green
            Write-Host "[+] Account: $($context.Account.Id)" -ForegroundColor Green
        } else {
            Write-Host "[!] Warning: Context subscription ID doesn't match selected subscription" -ForegroundColor Yellow
        }
        
        Write-Host ""

        # Restore original preferences
        $WarningPreference = $originalWarningPreference

        return $result
    }
    catch {
        # Restore original preferences in case of error
        if ($originalWarningPreference) { $WarningPreference = $originalWarningPreference }
        
        $result.Message = "Error during Azure authentication: $($_.Exception.Message)"
        Write-Host "[-] $($result.Message)" -ForegroundColor Red
        return $result
    }
}
