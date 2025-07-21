function Test-AzureResourceProviders {
    <#
    .SYNOPSIS
        Tests and optionally registers Azure Resource Providers required for Azure Arc.
    #>
    if (-not $script:azureLoginCompleted -or $script:resourceProvidersChecked) {
        return
    }
    
    # Suppress warnings for resource provider operations
    $OriginalWarningPreference = $WarningPreference
    $WarningPreference = 'SilentlyContinue'
    
    try {
        Write-Step "Checking Azure Resource Provider registrations"
        $providers = @(
            "Microsoft.HybridCompute",
            "Microsoft.GuestConfiguration", 
            "Microsoft.AzureArcData",
            "Microsoft.HybridConnectivity"
        )
        
        $unregisteredProviders = @()
        
        # Show progress while checking providers
        Write-Progress -Activity "Checking Resource Providers" -Status "Initializing..." -PercentComplete 0
        
        for ($i = 0; $i -lt $providers.Count; $i++) {
            $provider = $providers[$i]
            $percentComplete = [math]::Round((($i + 1) / $providers.Count) * 100)
            Write-Progress -Activity "Checking Resource Providers" -Status "Checking $provider... ($($i + 1)/$($providers.Count))" -PercentComplete $percentComplete
            
            try {
                $resourceProvider = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                if ($resourceProvider) {
                    $status = $resourceProvider.RegistrationState
                    if ($status -eq "Registered") {
                        Write-Host "    ✅ $provider : Registered" -ForegroundColor Green
                    } else {
                        Write-Host "    ⚠️  $provider : Not registered" -ForegroundColor Yellow
                        $unregisteredProviders += $provider
                    }
                } else {
                    Write-Host "    ❌ $provider : Provider not found" -ForegroundColor Red
                    $unregisteredProviders += $provider
                }
            } catch {
                Write-Host "    ❌ $provider : Error checking registration - $($_.Exception.Message)" -ForegroundColor Red
                $unregisteredProviders += $provider
            }
        }
        
        Write-Progress -Activity "Checking Resource Providers" -Completed
    
        # Offer to register unregistered providers
        if ($unregisteredProviders.Count -gt 0) {
            Write-Host "`n⚠️  Found $($unregisteredProviders.Count) unregistered resource provider(s)" -ForegroundColor Yellow
            Write-Host "   Unregistered providers: $($unregisteredProviders -join ', ')" -ForegroundColor Gray
            Write-Host "`n💡 These resource providers are required for Azure Arc functionality:" -ForegroundColor Cyan
            Write-Host "   • Microsoft.HybridCompute     - Core Azure Arc agent functionality" -ForegroundColor Gray
            Write-Host "   • Microsoft.GuestConfiguration - Guest configuration policies" -ForegroundColor Gray
            Write-Host "   • Microsoft.AzureArcData      - Azure Arc data services" -ForegroundColor Gray
            Write-Host "   • Microsoft.HybridConnectivity - Hybrid connectivity features" -ForegroundColor Gray
            
            Write-Host "`n🔧 Registration Options:" -ForegroundColor Cyan
            Write-Host "   A - Register ALL unregistered providers automatically" -ForegroundColor Green
            Write-Host "   S - Select specific providers to register" -ForegroundColor Yellow
            Write-Host "   N - Skip registration (you can register manually later)" -ForegroundColor Gray
            
            $registrationAttempted = $false
            
            do {
                $choice = Read-Host "`nWould you like to register resource providers? [A/S/N] (default: A)"
                
                # Use default if user pressed Enter without input
                if ([string]::IsNullOrWhiteSpace($choice)) {
                    $choice = 'A'
                    Write-Host "✅ Using default choice: Register All" -ForegroundColor Green
                }
                switch ($choice.ToUpper()) {
                    'A' {
                        Write-Host "`n🚀 Registering all unregistered providers in parallel..." -ForegroundColor Green
                        $registrationAttempted = $true
                        
                        # Use new parallel registration function
                        $parallelSuccess = Register-AzureResourceProvidersParallel -ProviderNamespaces $unregisteredProviders
                        
                        if ($parallelSuccess) {
                            Write-Host "`n✅ All resource providers registered successfully!" -ForegroundColor Green
                        } else {
                            Write-Host "`n⚠️  Some providers may still be completing registration" -ForegroundColor Yellow
                            Write-Host "   Check Azure portal for final status" -ForegroundColor Gray
                        }
                        break
                    }
                    'S' {
                        Write-Host "`n📋 Select providers to register:" -ForegroundColor Cyan
                        for ($i = 0; $i -lt $unregisteredProviders.Count; $i++) {
                            Write-Host "   $($i + 1). $($unregisteredProviders[$i])" -ForegroundColor Gray
                        }
                        
                        do {
                            $selection = Read-Host "`nEnter provider numbers to register (e.g., 1,3 or 'all' for all) [default: all]"
                            
                            # Use default if user pressed Enter without input
                            if ([string]::IsNullOrWhiteSpace($selection)) {
                                $selection = 'all'
                                Write-Host "✅ Using default choice: all" -ForegroundColor Green
                            }
                            
                            if ($selection.ToLower() -eq 'all') {
                                $selectedProviders = $unregisteredProviders
                                break
                            } else {
                                try {
                                    $indices = $selection.Split(',') | ForEach-Object { [int]$_.Trim() - 1 }
                                    $selectedProviders = @()
                                    foreach ($index in $indices) {
                                        if ($index -ge 0 -and $index -lt $unregisteredProviders.Count) {
                                            $selectedProviders += $unregisteredProviders[$index]
                                        } else {
                                            throw "Invalid selection"
                                        }
                                    }
                                    break
                                } catch {
                                    Write-Host "   Invalid selection. Please try again." -ForegroundColor Red
                                }
                            }
                        } while ($true)
                        
                        Write-Host "`n🔧 Registering selected providers..." -ForegroundColor Green
                        $registrationAttempted = $true
                        
                        $parallelSuccess = Register-AzureResourceProvidersParallel -ProviderNamespaces $selectedProviders
                        
                        if ($parallelSuccess) {
                            Write-Host "`n✅ Selected resource providers registered successfully!" -ForegroundColor Green
                        } else {
                            Write-Host "`n⚠️  Provider registration may still be in progress" -ForegroundColor Yellow
                        }
                        break
                    }
                    'N' {
                        Write-Host "`n⏭️  Skipping resource provider registration" -ForegroundColor Gray
                        Write-Host "   💡 You can register providers manually using:" -ForegroundColor Gray
                        Write-Host "      Register-AzResourceProvider -ProviderNamespace <ProviderName>" -ForegroundColor Gray
                        Write-Host "   📋 Or use the Azure portal: Home > Subscriptions > Resource providers" -ForegroundColor Gray
                        break
                    }
                    default {
                        Write-Host "   Please enter 'A' for all, 'S' for selective, or 'N' to skip." -ForegroundColor Yellow
                    }
                }
            } while ($choice.ToUpper() -notin @('A', 'S', 'N'))
            
            # Re-check registration status after any registration attempts
            if ($registrationAttempted) {
                Write-Host "`n🔍 Re-checking resource provider registration status..." -ForegroundColor Cyan
                $stillUnregistered = @()
                
                # Show progress during re-checking
                Write-Progress -Activity "Re-checking Resource Providers" -Status "Initializing..." -PercentComplete 0
                
                for ($i = 0; $i -lt $providers.Count; $i++) {
                    $provider = $providers[$i]
                    $percentComplete = [math]::Round((($i + 1) / $providers.Count) * 100)
                    Write-Progress -Activity "Re-checking Resource Providers" -Status "Re-checking $provider... ($($i + 1)/$($providers.Count))" -PercentComplete $percentComplete
                    
                    try {
                        $resourceProvider = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                        if ($resourceProvider -and $resourceProvider.RegistrationState -eq "Registered") {
                            Write-Host "    ✅ $provider : Confirmed registered" -ForegroundColor Green
                        } else {
                            Write-Host "    ⚠️  $provider : Still not registered" -ForegroundColor Yellow
                            $stillUnregistered += $provider
                        }
                    } catch {
                        Write-Host "    ❌ $provider : Error re-checking - $($_.Exception.Message)" -ForegroundColor Red
                        $stillUnregistered += $provider
                    }
                }
                
                Write-Progress -Activity "Re-checking Resource Providers" -Completed
                
                # Store the current unregistered providers for later use in status reporting
                $script:unregisteredProviders = $stillUnregistered
                
                # Only mark as checked if all providers are now registered
                if ($stillUnregistered.Count -eq 0) {
                    Write-Host "`n✅ All resource providers are now registered!" -ForegroundColor Green
                    $script:resourceProvidersChecked = $true
                } else {
                    Write-Host "`n⚠️  $($stillUnregistered.Count) resource provider(s) still need attention: $($stillUnregistered -join ', ')" -ForegroundColor Yellow
                    Write-Host "   Resource provider check will remain incomplete until all are registered." -ForegroundColor Gray
                    # Do NOT set $script:resourceProvidersChecked = $true here
                }
            } else {
                # User chose to skip - mark as checked but store unregistered providers for status reporting
                $script:unregisteredProviders = $unregisteredProviders
                Write-Host "`n📝 Resource provider check marked as completed (user chose to skip registration)" -ForegroundColor Gray
                Write-Host "   Note: Unregistered providers may cause issues during Azure Arc onboarding" -ForegroundColor Yellow
                $script:resourceProvidersChecked = $true
            }
            
        } else {
            Write-Host "`n✅ All required resource providers are registered!" -ForegroundColor Green
            $script:unregisteredProviders = @()  # No unregistered providers
            $script:resourceProvidersChecked = $true
        }
    }
    finally {
        # Restore original warning preference
        $WarningPreference = $OriginalWarningPreference
    }
}

function Register-AzureResourceProvidersParallel {
    <#
    .SYNOPSIS
        Registers multiple Azure Resource Providers in parallel.
    
    .PARAMETER ProviderNamespaces
        Array of resource provider namespaces to register.
    #>
    param(
        [string[]]$ProviderNamespaces
    )
    
    Write-Host "    🚀 Initiating parallel registration of $($ProviderNamespaces.Count) resource providers..." -ForegroundColor Cyan
    
    # Start all registrations simultaneously (fire-and-forget approach)
    foreach ($provider in $ProviderNamespaces) {
        try {
            Write-Host "    🔄 Starting registration: $provider" -ForegroundColor Yellow
            Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
        } catch {
            Write-Host "    ⚠️  Failed to start registration for $provider`: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    Write-Host "    ⏱️  All registrations initiated. Monitoring progress (up to 60 seconds)..." -ForegroundColor Cyan
    
    # Monitor progress with optimized polling
    $timeout = 60  # Reduced overall timeout for parallel operations
    $interval = 3   # Very fast polling for parallel monitoring
    $timer = 0
    $completed = @()
    $lastStatusUpdate = 0
    $lastCompletedCount = 0  # Initialize this variable
    
    # Show initial progress bar
    Write-Progress -Activity "Registering Resource Providers" -Status "Initializing registration for $($ProviderNamespaces.Count) providers..." -PercentComplete 0
    
    # Give initial registrations a moment to start
    Start-Sleep -Seconds 2
    $timer += 2
    
    do {
        $timer += $interval
        
        # Check status of all providers
        $stillPending = @()
        foreach ($provider in $ProviderNamespaces) {
            if ($provider -notin $completed) {
                try {
                    $providerStatus = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                    if ($providerStatus.RegistrationState -eq "Registered") {
                        $completed += $provider
                        Write-Host "    ✅ $provider : Registered" -ForegroundColor Green
                    } else {
                        $stillPending += $provider
                    }
                } catch {
                    $stillPending += $provider
                }
            }
        }
        
        # Update progress more frequently for better user experience
        if (($timer - $lastStatusUpdate) -ge 3 -or $completed.Count -ne $lastCompletedCount) {
            $percentComplete = [math]::Round(($completed.Count / $ProviderNamespaces.Count) * 100)
            $remaining = $ProviderNamespaces.Count - $completed.Count
            $statusMessage = if ($completed.Count -eq 0) {
                "Registration in progress... ($timer s elapsed)"
            } else {
                "$($completed.Count)/$($ProviderNamespaces.Count) completed, $remaining pending ($timer s elapsed)"
            }
            Write-Progress -Activity "Registering Resource Providers" -Status $statusMessage -PercentComplete $percentComplete
            $lastStatusUpdate = $timer
            $lastCompletedCount = $completed.Count
        }
        
        # Break if all are completed
        if ($completed.Count -eq $ProviderNamespaces.Count) {
            Write-Progress -Activity "Registering Resource Providers" -Status "All providers registered successfully!" -PercentComplete 100
            Start-Sleep -Seconds 1  # Brief pause to show completion
            break
        }
        
        Start-Sleep -Seconds $interval
        
    } while ($timer -lt $timeout)
    
    Write-Progress -Activity "Registering Resource Providers" -Completed
    
    # Final status report
    $successful = $completed.Count
    $pending = $ProviderNamespaces.Count - $successful
    
    if ($successful -eq $ProviderNamespaces.Count) {
        Write-Host "    ✅ All $successful resource providers registered successfully!" -ForegroundColor Green
        $script:resourceProvidersRegistered = $true
        return $true
    } elseif ($successful -gt 0) {
        Write-Host "    ⚠️  $successful/$($ProviderNamespaces.Count) providers registered, $pending still pending" -ForegroundColor Yellow
        Write-Host "    💡 Remaining registrations will continue in the background" -ForegroundColor Gray
        if ($pending -gt 0) {
            $stillPendingList = $ProviderNamespaces | Where-Object { $_ -notin $completed }
            Write-Host "    📋 Pending: $($stillPendingList -join ', ')" -ForegroundColor Gray
        }
        $script:resourceProvidersRegistered = $true
        return $false
    } else {
        Write-Host "    ❌ No providers completed registration within timeout period" -ForegroundColor Red
        Write-Host "    💡 Registrations may still be in progress. Check Azure portal" -ForegroundColor Gray
        return $false
    }
}

function Invoke-DeviceCheck {
    <#
    .SYNOPSIS
        Performs comprehensive prerequisite checks on a single device.
    
    .PARAMETER DeviceName
        Name of the device to check.
    #>
    param(
        [string]$DeviceName
    )
    
    # First get OS version for header display
    $osVersion = "Unknown OS"
    $session = $null
    try {
        # Test device connectivity first
        $isReachable = Test-DeviceConnectivity -DeviceName $DeviceName
        if ($isReachable) {
            # Establish session if needed for OS version check
            if ($DeviceName -ne $env:COMPUTERNAME -and $DeviceName -ne "localhost") {
                $session = New-PSSession -ComputerName $DeviceName -ErrorAction SilentlyContinue
            }
            $osVersion = Get-DeviceOSVersion -DeviceName $DeviceName -Session $session
            $script:deviceOSVersions[$DeviceName] = $osVersion
        }
    } catch {
        $osVersion = "Unknown OS"
    }
    
    Write-Host "`n🖥️  CHECKING DEVICE: $DeviceName [$osVersion]" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor Yellow
    
    # Add device header to consolidated log
    "" | Out-File -FilePath $script:globalLogFile -Append
    "DEVICE: $DeviceName - Prerequisites Check Started at $(Get-Date)" | Out-File -FilePath $script:globalLogFile -Append
    "-" * 80 | Out-File -FilePath $script:globalLogFile -Append
    
    # Test device connectivity (may have been done above, but ensure proper logging)
    Write-Step "Testing device connectivity" $DeviceName
    if (-not $isReachable) {
        $isReachable = Test-DeviceConnectivity -DeviceName $DeviceName
    }
    
    if (-not $isReachable) {
        Test-Prerequisites $DeviceName "Device Connectivity" "Error" "Device is not reachable"
        Write-Host "    Skipping remaining checks for unreachable device" -ForegroundColor Red
        return
    } else {
        Test-Prerequisites $DeviceName "Device Connectivity" "OK" "Device is reachable"
    }
    
    # Calculate total steps
    $totalSteps = 8  # PowerShell, Az module, Arc agent, Network, Execution policy, MDE service, MDE extension, OS version
    $currentStep = 0
    
    # For remote devices, we'll use Invoke-Command for most checks
    try {
        if ($DeviceName -ne $env:COMPUTERNAME -and $DeviceName -ne "localhost") {
            if (-not $session) {
                Write-Step "Establishing remote session" $DeviceName
                $session = New-PSSession -ComputerName $DeviceName -ErrorAction Stop
                Write-Host "    Remote session established" -ForegroundColor Green
            } else {
                Write-Host "    Using existing remote session" -ForegroundColor Green
            }
        }
        
        # PowerShell version
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Checking PowerShell version" $DeviceName
        try {
            if ($session) {
                $psVersion = Invoke-Command -Session $session -ScriptBlock { $PSVersionTable.PSVersion }
            } else {
                $psVersion = $PSVersionTable.PSVersion
            }
            
            if ($psVersion.Major -lt 5) {
                Test-Prerequisites $DeviceName "PowerShell Version" "Warning" "Version $psVersion. Requires 5.0 or higher."
            } else {
                Test-Prerequisites $DeviceName "PowerShell Version" "OK" "Version $psVersion"
            }
        } catch {
            Test-Prerequisites $DeviceName "PowerShell Version" "Error" $_.Exception.Message
        }
        
        # Az module check (remote devices only)
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        if ($session) {
            Write-Step "Checking Az PowerShell module" $DeviceName
            try {
                $azModule = Invoke-Command -Session $session -ScriptBlock { Get-Module -ListAvailable -Name Az }
                
                if (-not $azModule) {
                    Test-Prerequisites $DeviceName "Az Module" "Warning" "Az module not found on remote device"
                } else {
                    Test-Prerequisites $DeviceName "Az Module" "OK" "Az module is installed on remote device"
                }
            } catch {
                Test-Prerequisites $DeviceName "Az Module" "Error" $_.Exception.Message
            }
        } else {
            Test-Prerequisites $DeviceName "Az Module" "Info" "Checked during Azure login process"
        }
        
        # Azure Arc agent
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Checking Azure Arc agent installation" $DeviceName
        try {
            $arcAgentPath = "C:\Program Files\AzureConnectedMachineAgent"
            if ($session) {
                $arcAgentExists = Invoke-Command -Session $session -ScriptBlock { 
                    param($path) 
                    Test-Path $path 
                } -ArgumentList $arcAgentPath
            } else {
                $arcAgentExists = Test-Path $arcAgentPath
            }
            
            if ($arcAgentExists) {
                Test-Prerequisites $DeviceName "Azure Arc Agent" "OK" "Agent is installed."
            } else {
                Test-Prerequisites $DeviceName "Azure Arc Agent" "Warning" "Agent not found."
            }
        } catch {
            Test-Prerequisites $DeviceName "Azure Arc Agent" "Error" $_.Exception.Message
        }
        
        # Network connectivity
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Testing network connectivity to Azure" $DeviceName
        try {
            if ($session) {
                $networkTest = Invoke-Command -Session $session -ScriptBlock { 
                    Test-NetConnection -ComputerName "management.azure.com" -Port 443 
                }
            } else {
                $networkTest = Test-NetConnection -ComputerName "management.azure.com" -Port 443
            }
            
            if ($networkTest.TcpTestSucceeded) {
                Test-Prerequisites $DeviceName "Network Connectivity" "OK" "Can reach management.azure.com"
            } else {
                Test-Prerequisites $DeviceName "Network Connectivity" "Warning" "Cannot reach management.azure.com"
            }
        } catch {
            Test-Prerequisites $DeviceName "Network Connectivity" "Error" $_.Exception.Message
        }
        
        # Execution policy
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Checking PowerShell execution policy" $DeviceName
        try {
            if ($session) {
                $policy = Invoke-Command -Session $session -ScriptBlock { Get-ExecutionPolicy }
            } else {
                $policy = Get-ExecutionPolicy
            }
            
            if ($policy -eq "RemoteSigned" -or $policy -eq "Unrestricted") {
                Test-Prerequisites $DeviceName "Execution Policy" "OK" $policy
            } else {
                Test-Prerequisites $DeviceName "Execution Policy" "Warning" $policy
            }
        } catch {
            Test-Prerequisites $DeviceName "Execution Policy" "Error" $_.Exception.Message
        }
        
        # MDE service
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Checking Microsoft Defender for Endpoint service" $DeviceName
        try {
            if ($session) {
                $mdeService = Invoke-Command -Session $session -ScriptBlock { 
                    Get-Service -Name "Sense" -ErrorAction SilentlyContinue 
                }
            } else {
                $mdeService = Get-Service -Name "Sense" -ErrorAction SilentlyContinue
            }
            
            if ($mdeService -and $mdeService.Status -eq "Running") {
                Test-Prerequisites $DeviceName "MDE Service" "OK" "Service is running."
            } else {
                Test-Prerequisites $DeviceName "MDE Service" "Warning" "Service not found or not running."
            }
        } catch {
            Test-Prerequisites $DeviceName "MDE Service" "Error" $_.Exception.Message
        }
        
        # MDE extension
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Checking MDE extension installation" $DeviceName
        try {
            $extPath = "C:\Packages\Plugins\Microsoft.Azure.AzureDefenderForServers\MDE.Windows"
            if ($session) {
                $extExists = Invoke-Command -Session $session -ScriptBlock { 
                    param($path) 
                    Test-Path $path 
                } -ArgumentList $extPath
            } else {
                $extExists = Test-Path $extPath
            }
            
            if ($extExists) {
                Test-Prerequisites $DeviceName "MDE Extension" "OK" "Extension is present."
            } else {
                Test-Prerequisites $DeviceName "MDE Extension" "Info" "Extension not found."
            }
        } catch {
            Test-Prerequisites $DeviceName "MDE Extension" "Error" $_.Exception.Message
        }
        
        # OS version
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Checking operating system compatibility" $DeviceName
        try {
            if ($session) {
                $osVersion = Invoke-Command -Session $session -ScriptBlock { 
                    (Get-CimInstance Win32_OperatingSystem).Caption 
                }
            } else {
                $osVersion = (Get-CimInstance Win32_OperatingSystem).Caption
            }
            
            $supported = @(
                "Microsoft Windows 11 Pro",
                "Microsoft Windows 11 Enterprise",
                "Microsoft Windows 10 Pro", 
                "Microsoft Windows 10 Enterprise",
                "Microsoft Windows Server 2025 Standard",
                "Microsoft Windows Server 2025 Datacenter",
                "Microsoft Windows Server 2022 Standard",
                "Microsoft Windows Server 2019 Datacenter",
                "Microsoft Windows Server 2016 Essentials",
                "Microsoft Windows Server 2012 R2 Standard",
                "Microsoft Windows Server 2008 R2 Enterprise"
            )
            
            if ($supported -contains $osVersion) {
                Test-Prerequisites $DeviceName "OS Version" "OK" $osVersion
            } else {
                Test-Prerequisites $DeviceName "OS Version" "Warning" "$osVersion may not be supported."
            }
        } catch {
            Test-Prerequisites $DeviceName "OS Version" "Error" $_.Exception.Message
        }
        
    } finally {
        if ($session) {
            Remove-PSSession $session -ErrorAction SilentlyContinue
            Write-Host "    Remote session closed" -ForegroundColor Gray
        }
    }
    
    # Complete progress for this device
    Write-Progress "Prerequisites Check - $DeviceName" -Completed
}
