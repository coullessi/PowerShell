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
    }
    
    if (-not $script:allResults[$DeviceName]) {
        $script:allResults[$DeviceName] = @()
    }
    $script:allResults[$DeviceName] += $entry
    
    # Write to consolidated log file
    "[$DeviceName]`t$Check`t$Result`t$Details" | Out-File -FilePath $script:globalLogFile -Append
    
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
    
    .OUTPUTS
        Boolean indicating if authentication is successful.
    #>
    Write-Step "Ensuring Azure authentication"
    
    # Suppress warnings globally for Azure operations
    $OriginalWarningPreference = $WarningPreference
    $WarningPreference = 'SilentlyContinue'
    
    try {
        # Check if Az module is available
        $azModule = Get-Module -ListAvailable -Name Az
        if (-not $azModule) {
            Write-Host "    Az module not found. Attempting installation..." -ForegroundColor Yellow
            $installSuccess = Install-AzModule
            if (-not $installSuccess) {
                Write-Host "    ❌ Cannot proceed without Az module" -ForegroundColor Red
                return $false
            }
            # Re-check after installation
            $azModule = Get-Module -ListAvailable -Name Az
        }
        
        Write-Host "    ✅ Az module is available" -ForegroundColor Green
        
        # Import required modules
        try {
            Import-Module Az.Accounts -Force -ErrorAction Stop
            Import-Module Az.Resources -Force -ErrorAction Stop
        }
        catch {
            Write-Host "    ⚠️ Warning: Could not import all Az modules: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Check current Azure context
        try {
            $context = Get-AzContext -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            if ($context) {
                Write-Host "    ✅ Already logged in to Azure as $($context.Account.Id)" -ForegroundColor Green
                Write-Host "    📋 Subscription: $($context.Subscription.Name)" -ForegroundColor Gray
                return $true
            } else {
                Write-Host "    🔑 Not logged in to Azure. Initiating login..." -ForegroundColor Yellow
                
                # Suppress all Azure PowerShell output streams during login
                $originalVerbosePreference = $VerbosePreference
                $originalInformationPreference = $InformationPreference
                $VerbosePreference = 'SilentlyContinue'
                $InformationPreference = 'SilentlyContinue'
                
                try {
                    # Attempt Azure login with all output suppressed
                    $loginResult = Connect-AzAccount -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -InformationAction SilentlyContinue -Verbose:$false
                } finally {
                    # Restore original preferences
                    $VerbosePreference = $originalVerbosePreference
                    $InformationPreference = $originalInformationPreference
                }
                
                if ($loginResult) {
                    $newContext = Get-AzContext -WarningAction SilentlyContinue
                    Write-Host "    ✅ Successfully logged in to Azure as $($newContext.Account.Id)" -ForegroundColor Green
                    Write-Host "    📋 Subscription: $($newContext.Subscription.Name)" -ForegroundColor Gray
                    return $true
                } else {
                    Write-Host "    ❌ Azure login failed" -ForegroundColor Red
                    return $false
                }
            }
        } catch {
            Write-Host "    ❌ Error during Azure authentication: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    finally {
        # Restore original warning preference
        $WarningPreference = $OriginalWarningPreference
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
        - C:\Folder\File.txt (with single quotes)
        - C:\Folder\File.txt (with double quotes)
    
    .PARAMETER Path
        The file path that may contain surrounding quotes.
    
    .RETURNS
        The path with quotes removed.
    
    .EXAMPLE
        Remove-PathQuotes -Path """C:\temp\file.txt"""
        Returns: C:\temp\file.txt
    #>
    param(
        [string]$Path
    )
    
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }
    
    # Remove surrounding quotes (both single and double)
    $trimmedPath = $Path.Trim()
    
    # Check for double quotes
    if ($trimmedPath.StartsWith([char]34) -and $trimmedPath.EndsWith([char]34) -and $trimmedPath.Length -gt 1) {
        $trimmedPath = $trimmedPath.Substring(1, $trimmedPath.Length - 2)
    }
    # Check for single quotes using character comparison
    elseif ($trimmedPath.Length -gt 1 -and $trimmedPath[0] -eq [char]39 -and $trimmedPath[$trimmedPath.Length - 1] -eq [char]39) {
        $trimmedPath = $trimmedPath.Substring(1, $trimmedPath.Length - 2)
    }
    
    return $trimmedPath
}
