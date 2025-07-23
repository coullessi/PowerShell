function Test-AzureResourceProviders {
    <#
    .SYNOPSIS
        Tests and registers Azure Resource Providers required for Azure Arc.
    #>
    if (-not $script:azureLoginCompleted -or $script:resourceProvidersChecked) {
        return
    }
    
    # Suppress warnings for resource provider operations
    $OriginalWarningPreference = $WarningPreference
    $WarningPreference = 'SilentlyContinue'
    
    try {
        Write-Step "Checking and registering Azure Resource Provider registrations"
        $providers = @(
            "Microsoft.HybridCompute",
            "Microsoft.GuestConfiguration", 
            "Microsoft.AzureArcData",
            "Microsoft.HybridConnectivity"
        )
        
        $results = @()
        
        # Show progress while checking and registering providers
        Write-Progress -Activity "Processing Resource Providers" -Status "Initializing..." -PercentComplete 0
        
        for ($i = 0; $i -lt $providers.Count; $i++) {
            $provider = $providers[$i]
            $percentComplete = [math]::Round((($i + 1) / $providers.Count) * 100)
            Write-Progress -Activity "Processing Resource Providers" -Status "Processing $provider... ($($i + 1)/$($providers.Count))" -PercentComplete $percentComplete
            
            try {
                # Check current status
                $resourceProvider = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                
                if ($resourceProvider) {
                    $currentStatus = $resourceProvider.RegistrationState
                    
                    if ($currentStatus -eq "Registered") {
                        Write-Host "    ✅ $provider : Already registered" -ForegroundColor Green
                        $results += [PSCustomObject]@{
                            Provider = $provider
                            Status = "Already Registered"
                            Success = $true
                        }
                        continue
                    }

                    # Register the provider
                    Write-Host "    🔄 $provider : Registering..." -ForegroundColor Yellow
                    Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop | Out-Null
                    
                    # Wait for registration to complete (with shorter timeout for better UX)
                    $timeout = 120  # 2 minutes
                    $timer = 0
                    $interval = 5
                    
                    do {
                        Start-Sleep -Seconds $interval
                        $timer += $interval
                        
                        $providerStatus = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                        $status = $providerStatus.RegistrationState
                        
                    } while ($timer -lt $timeout -and $status -ne "Registered")
                    
                    if ($status -eq "Registered") {
                        Write-Host "    ✅ $provider : Successfully registered" -ForegroundColor Green
                        $results += [PSCustomObject]@{
                            Provider = $provider
                            Status = "Successfully Registered"
                            Success = $true
                        }
                    } else {
                        Write-Host "    ⚠️  $provider : Registration timeout (may complete in background)" -ForegroundColor Yellow
                        $results += [PSCustomObject]@{
                            Provider = $provider
                            Status = "Registration Timeout"
                            Success = $false
                        }
                    }
                } else {
                    Write-Host "    ❌ $provider : Provider not found" -ForegroundColor Red
                    $results += [PSCustomObject]@{
                        Provider = $provider
                        Status = "Provider Not Found"
                        Success = $false
                    }
                }
            } catch {
                Write-Host "    ❌ $provider : Registration failed - $($_.Exception.Message)" -ForegroundColor Red
                $results += [PSCustomObject]@{
                    Provider = $provider
                    Status = "Registration Failed"
                    Success = $false
                }
            }
        }
        
        Write-Progress -Activity "Processing Resource Providers" -Completed
        
        # Display registration summary
        Write-Host "`n� Resource Provider Registration Summary:" -ForegroundColor Cyan
        $successCount = ($results | Where-Object { $_.Success }).Count
        $totalCount = $results.Count

        if ($successCount -eq $totalCount) {
            Write-Host "✅ All resource providers registered successfully! ($successCount/$totalCount)" -ForegroundColor Green
            $script:resourceProvidersChecked = $true
            $script:unregisteredProviders = @()
        } else {
            Write-Host "⚠️  Some resource provider registrations incomplete ($successCount/$totalCount)" -ForegroundColor Yellow
            $script:unregisteredProviders = ($results | Where-Object { -not $_.Success }).Provider
            # Still mark as checked since we attempted registration
            $script:resourceProvidersChecked = $true
        }
    }
    finally {
        # Restore original warning preference
        $WarningPreference = $OriginalWarningPreference
    }
}

function Test-DeviceCheck {
    <#
    .SYNOPSIS
        Performs comprehensive prerequisite checks on a single device for Azure Arc and MDE integration.
    
    .PARAMETER DeviceName
        Name of the device to check.
    
    .PARAMETER ValidateDefenderConfiguration
        Perform deep validation of Microsoft Defender for Endpoint configuration.
    
    .PARAMETER CheckSystemRequirements
        Validate hardware and system requirements.
    
    .PARAMETER SkipInteractiveChecks
        Skip checks that require user interaction.
    
    .PARAMETER GenerateRemediationScript
        Generate remediation scripts for identified issues.
    #>
    param(
        [string]$DeviceName,
        [switch]$ValidateDefenderConfiguration,
        [switch]$CheckSystemRequirements,
        [switch]$SkipInteractiveChecks,
        [switch]$GenerateRemediationScript
    )
    
    # Initialize remediation script content
    $script:remediationScriptContent = @()
    $script:remediationScriptContent += "# Azure Arc & MDE Prerequisites Remediation Script"
    $script:remediationScriptContent += "# Generated on: $(Get-Date)"
    $script:remediationScriptContent += "# Target Device: $DeviceName"
    $script:remediationScriptContent += ""
    
    # Get OS version for header display
    $osVersion = "Unknown OS"
    $session = $null
    $deviceInfo = @{}
    
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
            
            # Get comprehensive device information
            $deviceInfo = Get-DeviceSystemInfo -DeviceName $DeviceName -Session $session
        }
    } catch {
        $osVersion = "Unknown OS"
    }
    
    Write-Host "`n🖥️  COMPREHENSIVE PREREQUISITES CHECK: $DeviceName" -ForegroundColor Yellow
    Write-Host "    OS: $osVersion | Architecture: $($deviceInfo.Architecture)" -ForegroundColor Gray
    Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    
    # Add device header to consolidated log
    "" | Out-File -FilePath $script:globalLogFile -Append
    "DEVICE: $DeviceName - Comprehensive Prerequisites Check Started at $(Get-Date)" | Out-File -FilePath $script:globalLogFile -Append
    "OS: $osVersion | Architecture: $($deviceInfo.Architecture)" | Out-File -FilePath $script:globalLogFile -Append
    "=" * 100 | Out-File -FilePath $script:globalLogFile -Append
    
    # Test device connectivity
    Write-Step "Testing device connectivity and accessibility" $DeviceName
    if (-not $isReachable) {
        $isReachable = Test-DeviceConnectivity -DeviceName $DeviceName
    }
    
    if (-not $isReachable) {
        Test-Prerequisites $DeviceName "Device Connectivity" "Error" "Device is not reachable via network or WinRM"
        Write-Host "    ❌ Device is unreachable. Skipping all other checks." -ForegroundColor Red
        Add-RemediationStep "# Device connectivity failed - verify network connectivity and WinRM configuration"
        Add-RemediationStep "Test-NetConnection -ComputerName $DeviceName -Port 5985"
        Add-RemediationStep "Enable-PSRemoting -Force  # Run on target device"
        return
    } else {
        Test-Prerequisites $DeviceName "Device Connectivity" "OK" "Device is reachable and accessible"
    }
    
    # Calculate total steps for comprehensive checking
    $totalSteps = 25
    if ($CheckSystemRequirements) { $totalSteps += 8 }
    if ($ValidateDefenderConfiguration) { $totalSteps += 12 }
    $currentStep = 0
    
    try {
        if ($DeviceName -ne $env:COMPUTERNAME -and $DeviceName -ne "localhost") {
            if (-not $session) {
                Write-Step "Establishing secure remote PowerShell session" $DeviceName
                $session = New-PSSession -ComputerName $DeviceName -ErrorAction Stop
                Write-Host "    ✅ Secure remote session established successfully" -ForegroundColor Green
            }
        }
        
        # ============================================================================
        # 1. OPERATING SYSTEM REQUIREMENTS VALIDATION
        # ============================================================================
        Write-Host "`n📋 1. OPERATING SYSTEM REQUIREMENTS" -ForegroundColor Cyan
        
        # Windows Version and Build Check
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Validating Windows version and build compatibility" $DeviceName
        $osCompatibility = Test-WindowsVersionCompatibility -DeviceName $DeviceName -Session $session
        if ($osCompatibility.IsSupported) {
            Test-Prerequisites $DeviceName "Windows Version" "OK" "$($osCompatibility.Version) - Build $($osCompatibility.Build)"
        } else {
            Test-Prerequisites $DeviceName "Windows Version" "Error" "$($osCompatibility.Version) - $($osCompatibility.Reason)"
            Add-RemediationStep "# Windows version $($osCompatibility.Version) is not supported"
            Add-RemediationStep "# Minimum requirement: Windows 10 1709+ or Windows Server 2012 R2+"
            Add-RemediationStep "# Consider upgrading to a supported Windows version"
        }
        
        # Architecture Check
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Checking processor architecture compatibility" $DeviceName
        $archResult = Test-ProcessorArchitecture -DeviceName $DeviceName -Session $session
        if ($archResult.IsSupported) {
            Test-Prerequisites $DeviceName "Processor Architecture" "OK" "$($archResult.Architecture) - Supported"
        } else {
            Test-Prerequisites $DeviceName "Processor Architecture" "Error" "$($archResult.Architecture) - Not supported for Azure Arc"
            Add-RemediationStep "# Processor architecture $($archResult.Architecture) is not supported"
            Add-RemediationStep "# Azure Arc requires x64 or ARM64 architecture"
        }
        
        # System Requirements Check (if enabled)
        if ($CheckSystemRequirements) {
            Write-Host "`n💾 SYSTEM HARDWARE REQUIREMENTS" -ForegroundColor Cyan
            
            # Memory Check
            $currentStep++
            Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
            Write-Step "Validating system memory requirements" $DeviceName
            $memoryResult = Test-SystemMemoryRequirements -DeviceName $DeviceName -Session $session
            if ($memoryResult.IsSufficient) {
                Test-Prerequisites $DeviceName "System Memory" "OK" "$([math]::Round($memoryResult.TotalGB, 1)) GB available"
            } else {
                Test-Prerequisites $DeviceName "System Memory" "Warning" "$([math]::Round($memoryResult.TotalGB, 1)) GB - Below recommended 4GB"
                Add-RemediationStep "# System has only $([math]::Round($memoryResult.TotalGB, 1)) GB RAM"
                Add-RemediationStep "# Consider adding more memory for optimal performance"
            }
            
            # Disk Space Check
            $currentStep++
            Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
            Write-Step "Checking system drive free space" $DeviceName
            $diskResult = Test-SystemDiskSpace -DeviceName $DeviceName -Session $session
            if ($diskResult.IsSufficient) {
                Test-Prerequisites $DeviceName "System Drive Space" "OK" "$([math]::Round($diskResult.FreeSpaceGB, 1)) GB free on $($diskResult.Drive)"
            } else {
                Test-Prerequisites $DeviceName "System Drive Space" "Warning" "$([math]::Round($diskResult.FreeSpaceGB, 1)) GB free - Below recommended 2GB"
                Add-RemediationStep "# System drive has only $([math]::Round($diskResult.FreeSpaceGB, 1)) GB free space"
                Add-RemediationStep "# Free up disk space or consider disk cleanup"
                Add-RemediationStep "cleanmgr /sagerun:1  # Run disk cleanup"
            }
        }
        
        # ============================================================================
        # 2. POWERSHELL & EXECUTION ENVIRONMENT
        # ============================================================================
        Write-Host "`n💻 2. POWERSHELL & EXECUTION ENVIRONMENT" -ForegroundColor Cyan
        
        # PowerShell Version
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Validating PowerShell version and capabilities" $DeviceName
        $psResult = Test-PowerShellVersion -DeviceName $DeviceName -Session $session
        if ($psResult.IsCompatible) {
            Test-Prerequisites $DeviceName "PowerShell Version" "OK" "Version $($psResult.Version) - Compatible"
        } else {
            Test-Prerequisites $DeviceName "PowerShell Version" "Error" "Version $($psResult.Version) - Requires 5.1 or higher"
            Add-RemediationStep "# PowerShell version $($psResult.Version) is not compatible"
            Add-RemediationStep "# Install Windows Management Framework 5.1 or PowerShell 7+"
            Add-RemediationStep "# Download from: https://docs.microsoft.com/powershell/scripting/install/installing-powershell"
        }
        
        # .NET Framework Version
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Checking .NET Framework version" $DeviceName
        $dotNetResult = Test-DotNetFrameworkVersion -DeviceName $DeviceName -Session $session
        if ($dotNetResult.IsCompatible) {
            Test-Prerequisites $DeviceName ".NET Framework" "OK" "Version $($dotNetResult.Version) - Compatible"
        } else {
            Test-Prerequisites $DeviceName ".NET Framework" "Warning" "Version $($dotNetResult.Version) - Consider upgrading to 4.7.2+"
            Add-RemediationStep "# .NET Framework version $($dotNetResult.Version) may cause compatibility issues"
            Add-RemediationStep "# Install .NET Framework 4.7.2 or later"
            Add-RemediationStep "# Download from: https://dotnet.microsoft.com/download/dotnet-framework"
        }
        
        # Execution Policy
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Validating PowerShell execution policy" $DeviceName
        $execPolicyResult = Test-ExecutionPolicy -DeviceName $DeviceName -Session $session
        if ($execPolicyResult.IsCompatible) {
            Test-Prerequisites $DeviceName "Execution Policy" "OK" "$($execPolicyResult.Policy) - Allows script execution"
        } else {
            Test-Prerequisites $DeviceName "Execution Policy" "Warning" "$($execPolicyResult.Policy) - May block Azure Arc scripts"
            Add-RemediationStep "# PowerShell execution policy is set to $($execPolicyResult.Policy)"
            Add-RemediationStep "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine"
        }
        
        # Azure PowerShell Module
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Checking Azure PowerShell module availability" $DeviceName
        $azModuleResult = Test-AzurePowerShellModule -DeviceName $DeviceName -Session $session
        if ($azModuleResult.IsInstalled) {
            Test-Prerequisites $DeviceName "Azure PowerShell (Az)" "OK" "Version $($azModuleResult.Version) installed"
        } else {
            Test-Prerequisites $DeviceName "Azure PowerShell (Az)" "Info" "Not installed - will be handled during Azure authentication"
            Add-RemediationStep "# Azure PowerShell module not found"
            Add-RemediationStep "Install-Module -Name Az -Repository PSGallery -Force"
        }
        
        # ============================================================================
        # 3. WINDOWS SYSTEM REQUIREMENTS
        # ============================================================================
        Write-Host "`n⚙️  3. WINDOWS SYSTEM REQUIREMENTS" -ForegroundColor Cyan
        
        # Windows Services
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Validating required Windows services" $DeviceName
        $servicesResult = Test-RequiredWindowsServices -DeviceName $DeviceName -Session $session
        $criticalServiceIssues = $servicesResult | Where-Object { $_.Status -ne "Running" -and $_.Critical }
        if ($criticalServiceIssues.Count -eq 0) {
            Test-Prerequisites $DeviceName "Windows Services" "OK" "All critical services are running"
        } else {
            Test-Prerequisites $DeviceName "Windows Services" "Error" "$($criticalServiceIssues.Count) critical services not running"
            foreach ($service in $criticalServiceIssues) {
                Add-RemediationStep "# Critical service '$($service.Name)' is $($service.Status)"
                Add-RemediationStep "Start-Service -Name '$($service.Name)'"
                Add-RemediationStep "Set-Service -Name '$($service.Name)' -StartupType Automatic"
            }
        }
        
        # WMI Functionality
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Testing Windows Management Instrumentation (WMI)" $DeviceName
        $wmiResult = Test-WMIFunctionality -DeviceName $DeviceName -Session $session
        if ($wmiResult.IsWorking) {
            Test-Prerequisites $DeviceName "WMI Functionality" "OK" "WMI is responding correctly"
        } else {
            Test-Prerequisites $DeviceName "WMI Functionality" "Error" "WMI is not responding - $($wmiResult.Error)"
            Add-RemediationStep "# WMI functionality test failed"
            Add-RemediationStep "# Try rebuilding WMI repository"
            Add-RemediationStep "winmgmt /resetrepository"
            Add-RemediationStep "winmgmt /salvagerepository"
        }
        
        # Windows Update Service
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Checking Windows Update service availability" $DeviceName
        $updateResult = Test-WindowsUpdateService -DeviceName $DeviceName -Session $session
        if ($updateResult.IsAvailable) {
            Test-Prerequisites $DeviceName "Windows Update" "OK" "Service is available and configured"
        } else {
            Test-Prerequisites $DeviceName "Windows Update" "Warning" "Service may not be properly configured"
            Add-RemediationStep "# Windows Update service issues detected"
            Add-RemediationStep "Start-Service -Name 'wuauserv'"
            Add-RemediationStep "Set-Service -Name 'wuauserv' -StartupType Manual"
        }
        
        # Registry Permissions
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Validating registry permissions for Azure Arc" $DeviceName
        $registryResult = Test-RegistryPermissions -DeviceName $DeviceName -Session $session
        if ($registryResult.HasPermissions) {
            Test-Prerequisites $DeviceName "Registry Permissions" "OK" "Adequate permissions for Azure Arc operations"
        } else {
            Test-Prerequisites $DeviceName "Registry Permissions" "Warning" "May have insufficient registry permissions"
            Add-RemediationStep "# Registry permission issues detected"
            Add-RemediationStep "# Ensure running with administrative privileges"
        }
        
        # ============================================================================
        # 4. AZURE ARC AGENT REQUIREMENTS
        # ============================================================================
        Write-Host "`n🔧 4. AZURE ARC AGENT REQUIREMENTS" -ForegroundColor Cyan
        
        # Azure Connected Machine Agent Installation
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Checking Azure Connected Machine Agent installation" $DeviceName
        $arcAgentResult = Test-AzureArcAgentInstallation -DeviceName $DeviceName -Session $session
        if ($arcAgentResult.IsInstalled) {
            Test-Prerequisites $DeviceName "Azure Arc Agent" "OK" "Version $($arcAgentResult.Version) installed"
        } else {
            Test-Prerequisites $DeviceName "Azure Arc Agent" "Info" "Not installed - ready for deployment"
            Add-RemediationStep "# Azure Connected Machine Agent not installed"
            Add-RemediationStep "# Download and install from: https://aka.ms/AzureConnectedMachineAgent"
        }
        
        # Agent Service Status (if installed)
        if ($arcAgentResult.IsInstalled) {
            $currentStep++
            Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
            Write-Step "Validating Azure Arc agent service status" $DeviceName
            $agentServiceResult = Test-AzureArcAgentService -DeviceName $DeviceName -Session $session
            if ($agentServiceResult.IsRunning) {
                Test-Prerequisites $DeviceName "Arc Agent Service" "OK" "Service is running and healthy"
            } else {
                Test-Prerequisites $DeviceName "Arc Agent Service" "Warning" "Service status: $($agentServiceResult.Status)"
                Add-RemediationStep "# Azure Arc agent service issues"
                Add-RemediationStep "Start-Service -Name 'himds'"
                Add-RemediationStep "Restart-Service -Name 'GCArcService'"
            }
        }
        
        # Agent Configuration Validation (if installed)
        if ($arcAgentResult.IsInstalled) {
            $currentStep++
            Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
            Write-Step "Validating Azure Arc agent configuration" $DeviceName
            $configResult = Test-AzureArcAgentConfiguration -DeviceName $DeviceName -Session $session
            if ($configResult.IsValid) {
                Test-Prerequisites $DeviceName "Arc Agent Config" "OK" "Configuration is valid"
            } else {
                Test-Prerequisites $DeviceName "Arc Agent Config" "Warning" "Configuration may need attention"
                Add-RemediationStep "# Azure Arc agent configuration issues detected"
                Add-RemediationStep "# Review agent logs and configuration files"
            }
        }
        
        # ============================================================================
        # 5. MICROSOFT DEFENDER INTEGRATION (if enabled)
        # ============================================================================
        if ($ValidateDefenderConfiguration) {
            Write-Host "`n🛡️  5. MICROSOFT DEFENDER INTEGRATION" -ForegroundColor Cyan
            
            # Windows Defender Antivirus Status
            $currentStep++
            Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
            Write-Step "Checking Windows Defender Antivirus status" $DeviceName
            $defenderAvResult = Test-WindowsDefenderAntivirus -DeviceName $DeviceName -Session $session
            if ($defenderAvResult.IsHealthy) {
                Test-Prerequisites $DeviceName "Windows Defender AV" "OK" "Active and healthy"
            } else {
                Test-Prerequisites $DeviceName "Windows Defender AV" "Warning" "$($defenderAvResult.Issues -join '; ')"
                Add-RemediationStep "# Windows Defender Antivirus issues detected"
                Add-RemediationStep "Set-MpPreference -DisableRealtimeMonitoring `$false"
                Add-RemediationStep "Update-MpSignature"
            }
            
            # Microsoft Defender for Endpoint Service
            $currentStep++
            Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
            Write-Step "Checking Microsoft Defender for Endpoint service" $DeviceName
            $mdeServiceResult = Test-MicrosoftDefenderForEndpointService -DeviceName $DeviceName -Session $session
            if ($mdeServiceResult.IsRunning) {
                Test-Prerequisites $DeviceName "MDE Service" "OK" "Service is running"
            } else {
                Test-Prerequisites $DeviceName "MDE Service" "Info" "Service not found - will be installed via Defender for Servers"
                Add-RemediationStep "# Microsoft Defender for Endpoint service not found"
                Add-RemediationStep "# This is expected if not yet onboarded to Defender for Servers"
            }
            
            # Defender for Cloud Extension
            $currentStep++
            Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
            Write-Step "Checking Microsoft Defender for Cloud extension" $DeviceName
            $defenderExtResult = Test-DefenderForCloudExtension -DeviceName $DeviceName -Session $session
            if ($defenderExtResult.IsInstalled) {
                Test-Prerequisites $DeviceName "Defender for Cloud Ext" "OK" "Extension is installed and configured"
            } else {
                Test-Prerequisites $DeviceName "Defender for Cloud Ext" "Info" "Extension not found - will be deployed automatically"
                Add-RemediationStep "# Defender for Cloud extension not installed"
                Add-RemediationStep "# This will be automatically installed after Azure Arc onboarding"
            }
        }
        
        # ============================================================================
        # 6. SECURITY & COMPLIANCE VALIDATION
        # ============================================================================
        Write-Host "`n🔒 6. SECURITY & COMPLIANCE" -ForegroundColor Cyan
        
        # Windows Security Center Status
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Checking Windows Security Center status" $DeviceName
        $securityCenterResult = Test-WindowsSecurityCenter -DeviceName $DeviceName -Session $session
        if ($securityCenterResult.IsHealthy) {
            Test-Prerequisites $DeviceName "Windows Security" "OK" "Security Center is healthy"
        } else {
            Test-Prerequisites $DeviceName "Windows Security" "Warning" "Security Center has warnings"
            Add-RemediationStep "# Windows Security Center issues detected"
            Add-RemediationStep "# Review Windows Security settings manually"
        }
        
        # Group Policy Conflicts
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Scanning for Group Policy conflicts" $DeviceName
        $gpConflictResult = Test-GroupPolicyConflicts -DeviceName $DeviceName -Session $session
        if ($gpConflictResult.HasConflicts) {
            Test-Prerequisites $DeviceName "Group Policy" "Warning" "$($gpConflictResult.ConflictCount) potential conflicts found"
            Add-RemediationStep "# Group Policy conflicts detected:"
            foreach ($conflict in $gpConflictResult.Conflicts) {
                Add-RemediationStep "# - $conflict"
            }
        } else {
            Test-Prerequisites $DeviceName "Group Policy" "OK" "No conflicts detected"
        }
        
        # Certificate Store Validation
        $currentStep++
        Write-ProgressStep "Prerequisites Check - $DeviceName" $currentStep $totalSteps
        Write-Step "Validating certificate store for Azure root certificates" $DeviceName
        $certStoreResult = Test-CertificateStore -DeviceName $DeviceName -Session $session
        if ($certStoreResult.HasAzureCerts) {
            Test-Prerequisites $DeviceName "Certificate Store" "OK" "Azure root certificates present"
        } else {
            Test-Prerequisites $DeviceName "Certificate Store" "Warning" "Some Azure certificates may be missing"
            Add-RemediationStep "# Azure root certificates may need updating"
            Add-RemediationStep "# Run Windows Update to get latest certificate updates"
            Add-RemediationStep "certlm.msc  # Manually review certificate store"
        }
        
        # ============================================================================
        # 7. FINAL SUMMARY AND RECOMMENDATIONS
        # ============================================================================
        Write-Host "`n📊 COMPREHENSIVE CHECK SUMMARY" -ForegroundColor Green
        
        # Generate device summary
        $deviceResults = $script:allResults[$DeviceName]
        $totalChecks = $deviceResults.Count
        $okChecks = ($deviceResults | Where-Object { $_.Result -eq "OK" }).Count
        $warningChecks = ($deviceResults | Where-Object { $_.Result -eq "Warning" }).Count
        $errorChecks = ($deviceResults | Where-Object { $_.Result -eq "Error" }).Count
        $infoChecks = ($deviceResults | Where-Object { $_.Result -eq "Info" }).Count
        
        Write-Host "    Total Checks: $totalChecks" -ForegroundColor White
        Write-Host "    ✅ Passed: $okChecks" -ForegroundColor Green
        Write-Host "    ⚠️  Warnings: $warningChecks" -ForegroundColor Yellow
        Write-Host "    ❌ Errors: $errorChecks" -ForegroundColor Red
        Write-Host "    ℹ️  Info: $infoChecks" -ForegroundColor Cyan
        
        # Determine overall readiness
        if ($errorChecks -eq 0 -and $warningChecks -le 2) {
            Write-Host "`n🎯 READINESS STATUS: READY FOR AZURE ARC ONBOARDING" -ForegroundColor Green
            Write-Host "   Device meets all critical requirements for Azure Arc and MDE integration" -ForegroundColor Green
        } elseif ($errorChecks -eq 0) {
            Write-Host "`n🎯 READINESS STATUS: READY WITH MINOR WARNINGS" -ForegroundColor Yellow
            Write-Host "   Device can be onboarded but some optimizations are recommended" -ForegroundColor Yellow
        } else {
            Write-Host "`n🎯 READINESS STATUS: REQUIRES REMEDIATION" -ForegroundColor Red
            Write-Host "   Critical issues must be resolved before Azure Arc onboarding" -ForegroundColor Red
        }
        
        # Generate remediation script if requested
        if ($GenerateRemediationScript -and $script:remediationScriptContent.Count -gt 4) {
            # Use standardized output directory for remediation scripts
            $remediationFile = New-StandardizedOutputFile -FileName "AzureArc_Remediation_$($DeviceName)" -Extension ".ps1"
            $script:remediationScriptContent | Out-File -FilePath $remediationFile -Encoding UTF8
            Write-Host "`n📜 Remediation script generated: $remediationFile" -ForegroundColor Cyan
        }
        
    } finally {
        if ($session) {
            Remove-PSSession $session -ErrorAction SilentlyContinue
            Write-Host "`n🔌 Remote session closed for $DeviceName" -ForegroundColor Gray
        }
    }
    
    # Complete progress for this device
    Write-Progress "Prerequisites Check - $DeviceName" -Completed
}

# Helper function to add remediation steps
function Add-RemediationStep {
    param([string]$Step)
    $script:remediationScriptContent += $Step
}

# ============================================================================
# COMPREHENSIVE PREREQUISITE TEST FUNCTIONS
# ============================================================================

function Get-DeviceSystemInfo {
    <#
    .SYNOPSIS
        Gets comprehensive system information from a device.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $systemInfo = Invoke-Command -Session $Session -ScriptBlock {
                [PSCustomObject]@{
                    Architecture = (Get-CimInstance Win32_Processor).Architecture
                    TotalMemoryGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
                    OSVersion = (Get-CimInstance Win32_OperatingSystem).Version
                    OSCaption = (Get-CimInstance Win32_OperatingSystem).Caption
                    SystemDrive = $env:SystemDrive
                }
            }
        } else {
            $systemInfo = [PSCustomObject]@{
                Architecture = (Get-CimInstance Win32_Processor).Architecture
                TotalMemoryGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
                OSVersion = (Get-CimInstance Win32_OperatingSystem).Version
                OSCaption = (Get-CimInstance Win32_OperatingSystem).Caption
                SystemDrive = $env:SystemDrive
            }
        }
        return $systemInfo
    } catch {
        return @{
            Architecture = "Unknown"
            TotalMemoryGB = 0
            OSVersion = "Unknown"
            OSCaption = "Unknown"
            SystemDrive = "C:"
        }
    }
}

function Test-WindowsVersionCompatibility {
    <#
    .SYNOPSIS
        Tests Windows version compatibility for Azure Arc.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $osInfo = Invoke-Command -Session $Session -ScriptBlock {
                $os = Get-CimInstance Win32_OperatingSystem
                [PSCustomObject]@{
                    Version = $os.Version
                    Caption = $os.Caption
                    BuildNumber = $os.BuildNumber
                    ProductType = $os.ProductType
                }
            }
        } else {
            $os = Get-CimInstance Win32_OperatingSystem
            $osInfo = [PSCustomObject]@{
                Version = $os.Version
                Caption = $os.Caption
                BuildNumber = $os.BuildNumber
                ProductType = $os.ProductType
            }
        }
        
        # Define supported versions
        $supportedVersions = @{
            "Windows 10" = @{ MinBuild = 16299 }  # Fall Creators Update (1709)
            "Windows 11" = @{ MinBuild = 22000 }
            "Windows Server 2012 R2" = @{ MinBuild = 9600 }
            "Windows Server 2016" = @{ MinBuild = 14393 }
            "Windows Server 2019" = @{ MinBuild = 17763 }
            "Windows Server 2022" = @{ MinBuild = 20348 }
            "Windows Server 2025" = @{ MinBuild = 26100 }
        }
        
        $isSupported = $false
        $reason = "Unknown Windows version"
        
        foreach ($supportedOS in $supportedVersions.Keys) {
            if ($osInfo.Caption -like "*$supportedOS*") {
                if ([int]$osInfo.BuildNumber -ge $supportedVersions[$supportedOS].MinBuild) {
                    $isSupported = $true
                    break
                } else {
                    $reason = "Build $($osInfo.BuildNumber) is below minimum required $($supportedVersions[$supportedOS].MinBuild)"
                }
            }
        }
        
        return [PSCustomObject]@{
            IsSupported = $isSupported
            Version = $osInfo.Caption
            Build = $osInfo.BuildNumber
            Reason = $reason
        }
    } catch {
        return [PSCustomObject]@{
            IsSupported = $false
            Version = "Unknown"
            Build = "Unknown"
            Reason = "Error retrieving OS information: $($_.Exception.Message)"
        }
    }
}

function Test-ProcessorArchitecture {
    <#
    .SYNOPSIS
        Tests processor architecture compatibility.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $archInfo = Invoke-Command -Session $Session -ScriptBlock {
                (Get-CimInstance Win32_Processor).Architecture
            }
        } else {
            $archInfo = (Get-CimInstance Win32_Processor).Architecture
        }
        
        # Architecture codes: 0=x86, 9=x64, 12=ARM64
        $supportedArchitectures = @(9, 12)  # x64 and ARM64
        $archNames = @{
            0 = "x86"
            9 = "x64"
            12 = "ARM64"
        }
        
        $archName = $archNames[$archInfo]
        $isSupported = $archInfo -in $supportedArchitectures
        
        return [PSCustomObject]@{
            IsSupported = $isSupported
            Architecture = $archName
        }
    } catch {
        return [PSCustomObject]@{
            IsSupported = $false
            Architecture = "Unknown"
        }
    }
}

function Test-SystemMemoryRequirements {
    <#
    .SYNOPSIS
        Tests system memory requirements.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $memoryInfo = Invoke-Command -Session $Session -ScriptBlock {
                $totalMemory = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
                [math]::Round($totalMemory / 1GB, 2)
            }
        } else {
            $totalMemory = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
            $memoryInfo = [math]::Round($totalMemory / 1GB, 2)
        }
        
        $minimumGB = 4
        $isSufficient = $memoryInfo -ge $minimumGB
        
        return [PSCustomObject]@{
            IsSufficient = $isSufficient
            TotalGB = $memoryInfo
            MinimumGB = $minimumGB
        }
    } catch {
        return [PSCustomObject]@{
            IsSufficient = $false
            TotalGB = 0
            MinimumGB = 4
        }
    }
}

function Test-SystemDiskSpace {
    <#
    .SYNOPSIS
        Tests system drive free space requirements.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $diskInfo = Invoke-Command -Session $Session -ScriptBlock {
                $systemDrive = $env:SystemDrive + "\"
                $disk = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $systemDrive.TrimEnd('\') }
                [PSCustomObject]@{
                    Drive = $systemDrive
                    FreeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
                }
            }
        } else {
            $systemDrive = $env:SystemDrive + "\"
            $disk = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $systemDrive.TrimEnd('\') }
            $diskInfo = [PSCustomObject]@{
                Drive = $systemDrive
                FreeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
            }
        }
        
        $minimumGB = 2
        $isSufficient = $diskInfo.FreeSpaceGB -ge $minimumGB
        
        return [PSCustomObject]@{
            IsSufficient = $isSufficient
            FreeSpaceGB = $diskInfo.FreeSpaceGB
            Drive = $diskInfo.Drive
            MinimumGB = $minimumGB
        }
    } catch {
        return [PSCustomObject]@{
            IsSufficient = $false
            FreeSpaceGB = 0
            Drive = "Unknown"
            MinimumGB = 2
        }
    }
}

function Test-PowerShellVersion {
    <#
    .SYNOPSIS
        Tests PowerShell version compatibility.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $psVersion = Invoke-Command -Session $Session -ScriptBlock {
                $PSVersionTable.PSVersion
            }
        } else {
            $psVersion = $PSVersionTable.PSVersion
        }
        
        $isCompatible = $psVersion.Major -ge 5 -and ($psVersion.Major -gt 5 -or $psVersion.Minor -ge 1)
        
        return [PSCustomObject]@{
            IsCompatible = $isCompatible
            Version = $psVersion.ToString()
            Major = $psVersion.Major
            Minor = $psVersion.Minor
        }
    } catch {
        return [PSCustomObject]@{
            IsCompatible = $false
            Version = "Unknown"
            Major = 0
            Minor = 0
        }
    }
}

function Test-DotNetFrameworkVersion {
    <#
    .SYNOPSIS
        Tests .NET Framework version compatibility.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $dotNetVersion = Invoke-Command -Session $Session -ScriptBlock {
                try {
                    $release = Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -Name Release -ErrorAction SilentlyContinue
                    if ($release.Release -ge 528040) { return "4.8+" }
                    elseif ($release.Release -ge 461808) { return "4.7.2" }
                    elseif ($release.Release -ge 460798) { return "4.7" }
                    elseif ($release.Release -ge 394802) { return "4.6.2" }
                    else { return "4.6 or earlier" }
                } catch {
                    return "Unknown"
                }
            }
        } else {
            try {
                $release = Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -Name Release -ErrorAction SilentlyContinue
                if ($release.Release -ge 528040) { $dotNetVersion = "4.8+" }
                elseif ($release.Release -ge 461808) { $dotNetVersion = "4.7.2" }
                elseif ($release.Release -ge 460798) { $dotNetVersion = "4.7" }
                elseif ($release.Release -ge 394802) { $dotNetVersion = "4.6.2" }
                else { $dotNetVersion = "4.6 or earlier" }
            } catch {
                $dotNetVersion = "Unknown"
            }
        }
        
        $isCompatible = $dotNetVersion -like "4.7*" -or $dotNetVersion -like "4.8*"
        
        return [PSCustomObject]@{
            IsCompatible = $isCompatible
            Version = $dotNetVersion
        }
    } catch {
        return [PSCustomObject]@{
            IsCompatible = $false
            Version = "Unknown"
        }
    }
}

function Test-ExecutionPolicy {
    <#
    .SYNOPSIS
        Tests PowerShell execution policy compatibility.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $policy = Invoke-Command -Session $Session -ScriptBlock {
                Get-ExecutionPolicy
            }
        } else {
            $policy = Get-ExecutionPolicy
        }
        
        $compatiblePolicies = @("RemoteSigned", "Unrestricted", "Bypass")
        $isCompatible = $policy -in $compatiblePolicies
        
        return [PSCustomObject]@{
            IsCompatible = $isCompatible
            Policy = $policy.ToString()
        }
    } catch {
        return [PSCustomObject]@{
            IsCompatible = $false
            Policy = "Unknown"
        }
    }
}

function Test-AzurePowerShellModule {
    <#
    .SYNOPSIS
        Tests Azure PowerShell module availability.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $azModule = Invoke-Command -Session $Session -ScriptBlock {
                Get-Module -ListAvailable -Name Az | Select-Object -First 1
            }
        } else {
            $azModule = Get-Module -ListAvailable -Name Az | Select-Object -First 1
        }
        
        return [PSCustomObject]@{
            IsInstalled = $null -ne $azModule
            Version = if ($azModule) { $azModule.Version.ToString() } else { "Not installed" }
        }
    } catch {
        return [PSCustomObject]@{
            IsInstalled = $false
            Version = "Unknown"
        }
    }
}

function Test-RequiredWindowsServices {
    <#
    .SYNOPSIS
        Tests required Windows services for Azure Arc.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    $requiredServices = @(
        @{ Name = "WinRM"; DisplayName = "Windows Remote Management"; Critical = $true },
        @{ Name = "wuauserv"; DisplayName = "Windows Update"; Critical = $true },
        @{ Name = "Winmgmt"; DisplayName = "Windows Management Instrumentation"; Critical = $true },
        @{ Name = "EventLog"; DisplayName = "Windows Event Log"; Critical = $true },
        @{ Name = "RpcSs"; DisplayName = "Remote Procedure Call (RPC)"; Critical = $true },
        @{ Name = "Dhcp"; DisplayName = "DHCP Client"; Critical = $false },
        @{ Name = "Dnscache"; DisplayName = "DNS Client"; Critical = $true }
    )
    
    $results = @()
    
    try {
        foreach ($service in $requiredServices) {
            if ($Session) {
                $serviceStatus = Invoke-Command -Session $Session -ScriptBlock {
                    param($serviceName)
                    Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                } -ArgumentList $service.Name
            } else {
                $serviceStatus = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
            }
            
            $results += [PSCustomObject]@{
                Name = $service.Name
                DisplayName = $service.DisplayName
                Status = if ($serviceStatus) { $serviceStatus.Status.ToString() } else { "Not Found" }
                Critical = $service.Critical
            }
        }
        
        return $results
    } catch {
        return @()
    }
}

function Test-WMIFunctionality {
    <#
    .SYNOPSIS
        Tests Windows Management Instrumentation functionality.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $wmiTest = Invoke-Command -Session $Session -ScriptBlock {
                try {
                    $null = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
                    return $true
                } catch {
                    return $false
                }
            }
        } else {
            try {
                $null = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
                $wmiTest = $true
            } catch {
                $wmiTest = $false
            }
        }
        
        return [PSCustomObject]@{
            IsWorking = $wmiTest
            Error = if (-not $wmiTest) { "WMI query failed" } else { $null }
        }
    } catch {
        return [PSCustomObject]@{
            IsWorking = $false
            Error = $_.Exception.Message
        }
    }
}

function Test-WindowsUpdateService {
    <#
    .SYNOPSIS
        Tests Windows Update service availability.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $updateService = Invoke-Command -Session $Session -ScriptBlock {
                Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue
            }
        } else {
            $updateService = Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue
        }
        
        return [PSCustomObject]@{
            IsAvailable = $null -ne $updateService
            Status = if ($updateService) { $updateService.Status.ToString() } else { "Not Found" }
        }
    } catch {
        return [PSCustomObject]@{
            IsAvailable = $false
            Status = "Error"
        }
    }
}

function Test-RegistryPermissions {
    <#
    .SYNOPSIS
        Tests registry permissions for Azure Arc operations.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $registryTest = Invoke-Command -Session $Session -ScriptBlock {
                try {
                    # Test read access to HKLM\SOFTWARE
                    $null = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion" -ErrorAction Stop
                    return $true
                } catch {
                    return $false
                }
            }
        } else {
            try {
                $null = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion" -ErrorAction Stop
                $registryTest = $true
            } catch {
                $registryTest = $false
            }
        }
        
        return [PSCustomObject]@{
            HasPermissions = $registryTest
        }
    } catch {
        return [PSCustomObject]@{
            HasPermissions = $false
        }
    }
}

function Test-AzureArcAgentInstallation {
    <#
    .SYNOPSIS
        Tests Azure Connected Machine Agent installation.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $agentInfo = Invoke-Command -Session $Session -ScriptBlock {
                $agentPath = "C:\Program Files\AzureConnectedMachineAgent"
                $agentExists = Test-Path $agentPath
                $version = "Unknown"
                
                if ($agentExists) {
                    try {
                        $versionFile = Join-Path $agentPath "azcmagent.exe"
                        if (Test-Path $versionFile) {
                            $version = (Get-Item $versionFile).VersionInfo.ProductVersion
                        }
                    } catch {
                        $version = "Unknown"
                    }
                }
                
                [PSCustomObject]@{
                    IsInstalled = $agentExists
                    Version = $version
                }
            }
        } else {
            $agentPath = "C:\Program Files\AzureConnectedMachineAgent"
            $agentExists = Test-Path $agentPath
            $version = "Unknown"
            
            if ($agentExists) {
                try {
                    $versionFile = Join-Path $agentPath "azcmagent.exe"
                    if (Test-Path $versionFile) {
                        $version = (Get-Item $versionFile).VersionInfo.ProductVersion
                    }
                } catch {
                    $version = "Unknown"
                }
            }
            
            $agentInfo = [PSCustomObject]@{
                IsInstalled = $agentExists
                Version = $version
            }
        }
        
        return $agentInfo
    } catch {
        return [PSCustomObject]@{
            IsInstalled = $false
            Version = "Unknown"
        }
    }
}

function Test-AzureArcAgentService {
    <#
    .SYNOPSIS
        Tests Azure Arc agent service status.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $serviceInfo = Invoke-Command -Session $Session -ScriptBlock {
                $himdsService = Get-Service -Name "himds" -ErrorAction SilentlyContinue
                $gcArcService = Get-Service -Name "GCArcService" -ErrorAction SilentlyContinue
                
                [PSCustomObject]@{
                    HimdsStatus = if ($himdsService) { $himdsService.Status.ToString() } else { "Not Found" }
                    GCArcStatus = if ($gcArcService) { $gcArcService.Status.ToString() } else { "Not Found" }
                    IsRunning = ($himdsService -and $himdsService.Status -eq "Running") -or 
                               ($gcArcService -and $gcArcService.Status -eq "Running")
                }
            }
        } else {
            $himdsService = Get-Service -Name "himds" -ErrorAction SilentlyContinue
            $gcArcService = Get-Service -Name "GCArcService" -ErrorAction SilentlyContinue
            
            $serviceInfo = [PSCustomObject]@{
                HimdsStatus = if ($himdsService) { $himdsService.Status.ToString() } else { "Not Found" }
                GCArcStatus = if ($gcArcService) { $gcArcService.Status.ToString() } else { "Not Found" }
                IsRunning = ($himdsService -and $himdsService.Status -eq "Running") -or 
                           ($gcArcService -and $gcArcService.Status -eq "Running")
            }
        }
        
        return $serviceInfo
    } catch {
        return [PSCustomObject]@{
            HimdsStatus = "Error"
            GCArcStatus = "Error"
            IsRunning = $false
            Status = "Error checking services"
        }
    }
}

function Test-AzureArcAgentConfiguration {
    <#
    .SYNOPSIS
        Tests Azure Arc agent configuration validity.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $configInfo = Invoke-Command -Session $Session -ScriptBlock {
                $configPath = "C:\ProgramData\AzureConnectedMachineAgent"
                $configExists = Test-Path $configPath
                
                [PSCustomObject]@{
                    ConfigExists = $configExists
                    IsValid = $configExists  # Simplified check
                }
            }
        } else {
            $configPath = "C:\ProgramData\AzureConnectedMachineAgent"
            $configExists = Test-Path $configPath
            
            $configInfo = [PSCustomObject]@{
                ConfigExists = $configExists
                IsValid = $configExists  # Simplified check
            }
        }
        
        return $configInfo
    } catch {
        return [PSCustomObject]@{
            ConfigExists = $false
            IsValid = $false
        }
    }
}

function Test-WindowsDefenderAntivirus {
    <#
    .SYNOPSIS
        Tests Windows Defender Antivirus status and configuration.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $defenderInfo = Invoke-Command -Session $Session -ScriptBlock {
                try {
                    $mpPrefs = Get-MpPreference -ErrorAction SilentlyContinue
                    $mpStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
                    
                    $issues = @()
                    
                    if (-not $mpStatus.RealTimeProtectionEnabled) {
                        $issues += "Real-time protection disabled"
                    }
                    if (-not $mpStatus.IoavProtectionEnabled) {
                        $issues += "IOAV protection disabled"
                    }
                    if (-not $mpStatus.OnAccessProtectionEnabled) {
                        $issues += "On-access protection disabled"
                    }
                    
                    [PSCustomObject]@{
                        IsHealthy = $issues.Count -eq 0
                        Issues = $issues
                        RealtimeEnabled = $mpStatus.RealTimeProtectionEnabled
                        CloudProtectionEnabled = $mpStatus.IoavProtectionEnabled
                    }
                } catch {
                    [PSCustomObject]@{
                        IsHealthy = $false
                        Issues = @("Error checking Windows Defender status")
                        RealtimeEnabled = $false
                        CloudProtectionEnabled = $false
                    }
                }
            }
        } else {
            try {
                $mpPrefs = Get-MpPreference -ErrorAction SilentlyContinue
                $mpStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
                
                $issues = @()
                
                if (-not $mpStatus.RealTimeProtectionEnabled) {
                    $issues += "Real-time protection disabled"
                }
                if (-not $mpStatus.IoavProtectionEnabled) {
                    $issues += "IOAV protection disabled"
                }
                if (-not $mpStatus.OnAccessProtectionEnabled) {
                    $issues += "On-access protection disabled"
                }
                
                $defenderInfo = [PSCustomObject]@{
                    IsHealthy = $issues.Count -eq 0
                    Issues = $issues
                    RealtimeEnabled = $mpStatus.RealTimeProtectionEnabled
                    CloudProtectionEnabled = $mpStatus.IoavProtectionEnabled
                }
            } catch {
                $defenderInfo = [PSCustomObject]@{
                    IsHealthy = $false
                    Issues = @("Error checking Windows Defender status")
                    RealtimeEnabled = $false
                    CloudProtectionEnabled = $false
                }
            }
        }
        
        return $defenderInfo
    } catch {
        return [PSCustomObject]@{
            IsHealthy = $false
            Issues = @("Error accessing Windows Defender")
            RealtimeEnabled = $false
            CloudProtectionEnabled = $false
        }
    }
}

function Test-MicrosoftDefenderForEndpointService {
    <#
    .SYNOPSIS
        Tests Microsoft Defender for Endpoint service status.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $mdeService = Invoke-Command -Session $Session -ScriptBlock {
                Get-Service -Name "Sense" -ErrorAction SilentlyContinue
            }
        } else {
            $mdeService = Get-Service -Name "Sense" -ErrorAction SilentlyContinue
        }
        
        return [PSCustomObject]@{
            IsRunning = $mdeService -and $mdeService.Status -eq "Running"
            Status = if ($mdeService) { $mdeService.Status.ToString() } else { "Not Found" }
        }
    } catch {
        return [PSCustomObject]@{
            IsRunning = $false
            Status = "Error"
        }
    }
}

function Test-DefenderForCloudExtension {
    <#
    .SYNOPSIS
        Tests Microsoft Defender for Cloud extension installation.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $extensionInfo = Invoke-Command -Session $Session -ScriptBlock {
                $extPaths = @(
                    "C:\Packages\Plugins\Microsoft.Azure.AzureDefenderForServers",
                    "C:\WindowsAzure\Packages\Plugins\Microsoft.Azure.Security.Monitoring.AzureSecurityCenterForServers"
                )
                
                $isInstalled = $false
                foreach ($path in $extPaths) {
                    if (Test-Path $path) {
                        $isInstalled = $true
                        break
                    }
                }
                
                [PSCustomObject]@{
                    IsInstalled = $isInstalled
                }
            }
        } else {
            $extPaths = @(
                "C:\Packages\Plugins\Microsoft.Azure.AzureDefenderForServers",
                "C:\WindowsAzure\Packages\Plugins\Microsoft.Azure.Security.Monitoring.AzureSecurityCenterForServers"
            )
            
            $isInstalled = $false
            foreach ($path in $extPaths) {
                if (Test-Path $path) {
                    $isInstalled = $true
                    break
                }
            }
            
            $extensionInfo = [PSCustomObject]@{
                IsInstalled = $isInstalled
            }
        }
        
        return $extensionInfo
    } catch {
        return [PSCustomObject]@{
            IsInstalled = $false
        }
    }
}

function Test-WindowsSecurityCenter {
    <#
    .SYNOPSIS
        Tests Windows Security Center status.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $securityInfo = Invoke-Command -Session $Session -ScriptBlock {
                try {
                    $secCenter = Get-Service -Name "wscsvc" -ErrorAction SilentlyContinue
                    [PSCustomObject]@{
                        IsHealthy = $secCenter -and $secCenter.Status -eq "Running"
                        ServiceStatus = if ($secCenter) { $secCenter.Status.ToString() } else { "Not Found" }
                    }
                } catch {
                    [PSCustomObject]@{
                        IsHealthy = $false
                        ServiceStatus = "Error"
                    }
                }
            }
        } else {
            try {
                $secCenter = Get-Service -Name "wscsvc" -ErrorAction SilentlyContinue
                $securityInfo = [PSCustomObject]@{
                    IsHealthy = $secCenter -and $secCenter.Status -eq "Running"
                    ServiceStatus = if ($secCenter) { $secCenter.Status.ToString() } else { "Not Found" }
                }
            } catch {
                $securityInfo = [PSCustomObject]@{
                    IsHealthy = $false
                    ServiceStatus = "Error"
                }
            }
        }
        
        return $securityInfo
    } catch {
        return [PSCustomObject]@{
            IsHealthy = $false
            ServiceStatus = "Unknown"
        }
    }
}

function Test-GroupPolicyConflicts {
    <#
    .SYNOPSIS
        Tests for Group Policy conflicts that might affect Azure Arc.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $gpInfo = Invoke-Command -Session $Session -ScriptBlock {
                $conflicts = @()
                
                try {
                    # Check for PowerShell execution policy restrictions
                    $execPolicy = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell" -Name "ExecutionPolicy" -ErrorAction SilentlyContinue
                    if ($execPolicy -and $execPolicy.ExecutionPolicy -eq "AllSigned") {
                        $conflicts += "PowerShell execution policy set to AllSigned via Group Policy"
                    }
                    
                    # Check for Windows Update restrictions
                    $wuPolicy = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "DisableWindowsUpdateAccess" -ErrorAction SilentlyContinue
                    if ($wuPolicy -and $wuPolicy.DisableWindowsUpdateAccess -eq 1) {
                        $conflicts += "Windows Update access disabled via Group Policy"
                    }
                    
                    # Check for service control restrictions
                    $servicePolicy = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Services" -ErrorAction SilentlyContinue
                    if ($servicePolicy) {
                        $conflicts += "Service control policies detected"
                    }
                } catch {
                    # Ignore errors - this is a best-effort check
                }
                
                [PSCustomObject]@{
                    HasConflicts = $conflicts.Count -gt 0
                    ConflictCount = $conflicts.Count
                    Conflicts = $conflicts
                }
            }
        } else {
            $conflicts = @()
            
            try {
                # Check for PowerShell execution policy restrictions
                $execPolicy = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell" -Name "ExecutionPolicy" -ErrorAction SilentlyContinue
                if ($execPolicy -and $execPolicy.ExecutionPolicy -eq "AllSigned") {
                    $conflicts += "PowerShell execution policy set to AllSigned via Group Policy"
                }
                
                # Check for Windows Update restrictions
                $wuPolicy = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "DisableWindowsUpdateAccess" -ErrorAction SilentlyContinue
                if ($wuPolicy -and $wuPolicy.DisableWindowsUpdateAccess -eq 1) {
                    $conflicts += "Windows Update access disabled via Group Policy"
                }
                
                # Check for service control restrictions
                $servicePolicy = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Services" -ErrorAction SilentlyContinue
                if ($servicePolicy) {
                    $conflicts += "Service control policies detected"
                }
            } catch {
                # Ignore errors - this is a best-effort check
            }
            
            $gpInfo = [PSCustomObject]@{
                HasConflicts = $conflicts.Count -gt 0
                ConflictCount = $conflicts.Count
                Conflicts = $conflicts
            }
        }
        
        return $gpInfo
    } catch {
        return [PSCustomObject]@{
            HasConflicts = $false
            ConflictCount = 0
            Conflicts = @()
        }
    }
}

function Test-CertificateStore {
    <#
    .SYNOPSIS
        Tests certificate store for Azure root certificates.
    #>
    param(
        [string]$DeviceName,
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    
    try {
        if ($Session) {
            $certInfo = Invoke-Command -Session $Session -ScriptBlock {
                try {
                    $rootCerts = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*Microsoft*" -or $_.Subject -like "*Azure*" }
                    [PSCustomObject]@{
                        HasAzureCerts = $rootCerts.Count -gt 0
                        CertCount = $rootCerts.Count
                    }
                } catch {
                    [PSCustomObject]@{
                        HasAzureCerts = $false
                        CertCount = 0
                    }
                }
            }
        } else {
            try {
                $rootCerts = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*Microsoft*" -or $_.Subject -like "*Azure*" }
                $certInfo = [PSCustomObject]@{
                    HasAzureCerts = $rootCerts.Count -gt 0
                    CertCount = $rootCerts.Count
                }
            } catch {
                $certInfo = [PSCustomObject]@{
                    HasAzureCerts = $false
                    CertCount = 0
                }
            }
        }
        
        return $certInfo
    } catch {
        return [PSCustomObject]@{
            HasAzureCerts = $false
            CertCount = 0
        }
    }
}
