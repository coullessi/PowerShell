function Write-ConsolidatedResults {
    <#
    .SYNOPSIS
        Displays consolidated results for all devices checked.
    
    .PARAMETER Devices
        Array of device names that were checked.
    
    .PARAMETER AzureLoginSuccess
        Boolean indicating if Azure login was successful.
    #>
    param(
        [string[]]$Devices,
        [bool]$AzureLoginSuccess
    )

    Write-Host "`n`n📊 CONSOLIDATED RESULTS - ALL DEVICES" -ForegroundColor Cyan
    Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan

    $consolidatedResults = @()
    foreach ($deviceName in $script:allResults.Keys) {
        $consolidatedResults += $script:allResults[$deviceName]
    }

    if ($consolidatedResults.Count -gt 0) {
        $consolidatedResults | Format-Table -Property Device, Check, Result, Details -AutoSize
        
        # Overall summary
        $totalChecks = $consolidatedResults.Count
        $okCount = ($consolidatedResults | Where-Object { $_.Result -eq "OK" }).Count
        $warningCount = ($consolidatedResults | Where-Object { $_.Result -eq "Warning" }).Count
        $errorCount = ($consolidatedResults | Where-Object { $_.Result -eq "Error" }).Count
        $infoCount = ($consolidatedResults | Where-Object { $_.Result -eq "Info" }).Count
        
        Write-Host "📋 OVERALL SUMMARY" -ForegroundColor Cyan
        Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
        Write-Host "Devices Checked:`t$($Devices.Count)" -ForegroundColor White
        Write-Host "Total Checks:`t`t$totalChecks" -ForegroundColor White
        Write-Host "✅ OK:`t`t`t$okCount" -ForegroundColor Green
        Write-Host "⚠️  Warnings:`t`t$warningCount" -ForegroundColor Yellow
        Write-Host "❌ Errors:`t`t$errorCount" -ForegroundColor Red
        Write-Host "ℹ️  Info:`t`t$infoCount" -ForegroundColor Blue
        Write-Host "Azure Login:`t`t$(if ($AzureLoginSuccess) { '✅ Success' } else { '❌ Failed' })" -ForegroundColor $(if ($AzureLoginSuccess) { 'Green' } else { 'Red' })
        Write-Host "Resource Providers:`t$(if ($script:resourceProvidersChecked) { '✅ Checked' } else { '⚠️ Skipped' })" -ForegroundColor $(if ($script:resourceProvidersChecked) { 'Green' } else { 'Yellow' })
        Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor Cyan
        
        # Device-specific summaries
        Write-Host "`n📊 Per-Device Summary:" -ForegroundColor Cyan
        foreach ($deviceName in $script:allResults.Keys | Sort-Object) {
            $deviceResults = $script:allResults[$deviceName]
            $deviceOK = ($deviceResults | Where-Object { $_.Result -eq "OK" }).Count
            $deviceWarnings = ($deviceResults | Where-Object { $_.Result -eq "Warning" }).Count
            $deviceErrors = ($deviceResults | Where-Object { $_.Result -eq "Error" }).Count
            $deviceInfo = ($deviceResults | Where-Object { $_.Result -eq "Info" }).Count
            
            $osVersion = if ($script:deviceOSVersions[$deviceName]) { $script:deviceOSVersions[$deviceName] } else { "Unknown OS" }
            $status = if ($deviceErrors -gt 0) { "❌ Errors" } elseif ($deviceWarnings -gt 0) { "⚠️ Warnings" } else { "✅ Ready" }
            
            Write-Host "  • $deviceName [$osVersion]: $status (OK: $deviceOK, Warnings: $deviceWarnings, Errors: $deviceErrors, Info: $deviceInfo)" -ForegroundColor Gray
        }
        
        # Detailed Issues per Device
        Write-Host "`n`n🔍 DETAILED ISSUES TO ADDRESS PER DEVICE" -ForegroundColor Yellow
        Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor Yellow
        
        $hasAnyIssues = $false
        foreach ($deviceName in $script:allResults.Keys | Sort-Object) {
            $deviceResults = $script:allResults[$deviceName]
            $deviceErrors = $deviceResults | Where-Object { $_.Result -eq "Error" }
            $deviceWarnings = $deviceResults | Where-Object { $_.Result -eq "Warning" }
            
            if ($deviceErrors.Count -gt 0 -or $deviceWarnings.Count -gt 0) {
                $hasAnyIssues = $true
                $osVersion = if ($script:deviceOSVersions[$deviceName]) { $script:deviceOSVersions[$deviceName] } else { "Unknown OS" }
                Write-Host "`n🖥️  DEVICE: $deviceName [$osVersion]" -ForegroundColor Yellow
                Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor Yellow
                
                # Display Errors first
                if ($deviceErrors.Count -gt 0) {
                    Write-Host "❌ CRITICAL ERRORS (Must Fix):" -ForegroundColor Red
                    foreach ($deviceError in $deviceErrors) {
                        Write-Host "   • $($deviceError.Check): $($deviceError.Details)" -ForegroundColor Red
                        
                        # Provide specific remediation guidance
                        switch ($deviceError.Check) {
                            "Device Connectivity" {
                                Write-Host "     💡 Action Required:" -ForegroundColor DarkGray
                                Write-Host "        - Verify device is powered on and network accessible" -ForegroundColor Gray
                                Write-Host "        - Enable WinRM: winrm quickconfig" -ForegroundColor Gray
                                Write-Host "        - Check Windows Firewall settings for remote management" -ForegroundColor Gray
                            }
                            "PowerShell Version" {
                                Write-Host "     💡 Action Required:" -ForegroundColor DarkGray
                                Write-Host "        - Download and install PowerShell 5.1 or later" -ForegroundColor Gray
                                Write-Host "        - Or install PowerShell 7: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Gray
                            }
                            "Az Module" {
                                Write-Host "     💡 Action Required:" -ForegroundColor DarkGray
                                Write-Host "        - Install Azure PowerShell: Install-Module -Name Az -Scope CurrentUser" -ForegroundColor Gray
                                Write-Host "        - Or as admin: Install-Module -Name Az -Scope AllUsers" -ForegroundColor Gray
                            }
                            "Azure Arc Agent" {
                                Write-Host "     💡 Action Required:" -ForegroundColor DarkGray
                                Write-Host "        - Download agent from Azure portal > Azure Arc > Servers" -ForegroundColor Gray
                                Write-Host "        - Install: msiexec /i AzureConnectedMachineAgent.msi /quiet" -ForegroundColor Gray
                            }
                            "Network Connectivity" {
                                Write-Host "     💡 Action Required:" -ForegroundColor DarkGray
                                Write-Host "        - Check internet connectivity and DNS resolution" -ForegroundColor Gray
                                Write-Host "        - Verify firewall allows HTTPS (443) to *.azure.com" -ForegroundColor Gray
                                Write-Host "        - Configure proxy if required" -ForegroundColor Gray
                            }
                            "Execution Policy" {
                                Write-Host "     💡 Action Required:" -ForegroundColor DarkGray
                                Write-Host "        - Set policy: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Gray
                                Write-Host "        - Or as admin: Set-ExecutionPolicy RemoteSigned" -ForegroundColor Gray
                            }
                            "MDE Service" {
                                Write-Host "     💡 Action Required:" -ForegroundColor DarkGray
                                Write-Host "        - Install Microsoft Defender for Endpoint from Microsoft 365 Defender portal" -ForegroundColor Gray
                                Write-Host "        - Start service: Start-Service -Name Sense" -ForegroundColor Gray
                            }
                            "MDE Extension" {
                                Write-Host "     💡 Action Required:" -ForegroundColor DarkGray
                                Write-Host "        - Install via Azure portal or PowerShell after Arc onboarding" -ForegroundColor Gray
                                Write-Host "        - Ensure Microsoft Defender for Cloud is enabled" -ForegroundColor Gray
                            }
                            "OS Version" {
                                Write-Host "     💡 Action Required:" -ForegroundColor DarkGray
                                Write-Host "        - Verify OS version is supported by Azure Arc" -ForegroundColor Gray
                                Write-Host "        - Consider OS upgrade if version is not supported" -ForegroundColor Gray
                            }
                            default {
                                Write-Host "     💡 Action Required:" -ForegroundColor DarkGray
                                Write-Host "        - Review error details and consult Azure Arc documentation" -ForegroundColor Gray
                                Write-Host "        - Check Azure Arc troubleshooting guide" -ForegroundColor Gray
                            }
                        }
                    }
                    Write-Host ""
                }
                
                # Display Warnings
                if ($deviceWarnings.Count -gt 0) {
                    Write-Host "⚠️  WARNINGS (Recommended to Address):" -ForegroundColor Yellow
                    foreach ($warning in $deviceWarnings) {
                        Write-Host "   • $($warning.Check): $($warning.Details)" -ForegroundColor Yellow
                        
                        # Provide specific recommendations
                        switch ($warning.Check) {
                            "PowerShell Version" {
                                Write-Host "     💡 Recommendation:" -ForegroundColor DarkGray
                                Write-Host "        - Consider upgrading to PowerShell 7.x for enhanced Azure features" -ForegroundColor Gray
                                Write-Host "        - PowerShell 7 offers better cross-platform support" -ForegroundColor Gray
                            }
                            "Az Module" {
                                Write-Host "     💡 Recommendation:" -ForegroundColor DarkGray
                                Write-Host "        - Install Az module on device for local Azure operations" -ForegroundColor Gray
                                Write-Host "        - Enables local Azure CLI and PowerShell commands" -ForegroundColor Gray
                            }
                            "Azure Arc Agent" {
                                Write-Host "     💡 Recommendation:" -ForegroundColor DarkGray
                                Write-Host "        - Install Azure Connected Machine agent before Arc onboarding" -ForegroundColor Gray
                                Write-Host "        - Agent required for Azure Arc-enabled servers functionality" -ForegroundColor Gray
                            }
                            "Network Connectivity" {
                                Write-Host "     💡 Recommendation:" -ForegroundColor DarkGray
                                Write-Host "        - Test connectivity: Test-NetConnection management.azure.com -Port 443" -ForegroundColor Gray
                                Write-Host "        - Ensure stable internet connection for Azure services" -ForegroundColor Gray
                            }
                            "Execution Policy" {
                                Write-Host "     💡 Recommendation:" -ForegroundColor DarkGray
                                Write-Host "        - Current policy may limit script execution capabilities" -ForegroundColor Gray
                                Write-Host "        - Consider setting to RemoteSigned for Azure operations" -ForegroundColor Gray
                            }
                            "MDE Service" {
                                Write-Host "     💡 Recommendation:" -ForegroundColor DarkGray
                                Write-Host "        - Install MDE for enhanced security monitoring" -ForegroundColor Gray
                                Write-Host "        - Integrates with Azure Defender for Cloud" -ForegroundColor Gray
                            }
                            "MDE Extension" {
                                Write-Host "     💡 Recommendation:" -ForegroundColor DarkGray
                                Write-Host "        - Extension will be available after Arc onboarding" -ForegroundColor Gray
                                Write-Host "        - Provides automated MDE deployment capabilities" -ForegroundColor Gray
                            }
                            "OS Version" {
                                Write-Host "     💡 Recommendation:" -ForegroundColor DarkGray
                                Write-Host "        - Verify compatibility with latest Azure Arc features" -ForegroundColor Gray
                                Write-Host "        - Check Azure Arc supported operating systems documentation" -ForegroundColor Gray
                            }
                            default {
                                Write-Host "     💡 Recommendation:" -ForegroundColor DarkGray
                                Write-Host "        - Review warning for potential optimization opportunities" -ForegroundColor Gray
                                Write-Host "        - Consider addressing for optimal Azure Arc experience" -ForegroundColor Gray
                            }
                        }
                    }
                    Write-Host ""
                }
                
                # Show action priority for this device
                if ($deviceErrors.Count -gt 0) {
                    Write-Host "🎯 Priority for $deviceName`: Fix $($deviceErrors.Count) critical error(s) before proceeding" -ForegroundColor Red
                } elseif ($deviceWarnings.Count -gt 0) {
                    Write-Host "🎯 Priority for $deviceName`: Address $($deviceWarnings.Count) warning(s) for optimal setup" -ForegroundColor Yellow
                }
            } else {
                # Device has no issues
                $osVersion = if ($script:deviceOSVersions[$deviceName]) { $script:deviceOSVersions[$deviceName] } else { "Unknown OS" }
                Write-Host "`n`n🖥️  DEVICE: $deviceName [$osVersion]" -ForegroundColor Green
                Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor Green
                Write-Host "✅ No issues found - Ready for Azure Arc onboarding!" -ForegroundColor Green
            }
        }
        
        if (-not $hasAnyIssues) {
            Write-Host "`n🎉 EXCELLENT! No warnings or errors found across all devices!" -ForegroundColor Green
            Write-Host "All systems are fully ready for Azure Arc onboarding and MDE integration." -ForegroundColor Green
        }
        
        # Cross-Device Priority Summary
        if ($hasAnyIssues) {
            Write-Host "`n`n📋 CROSS-DEVICE PRIORITY SUMMARY" -ForegroundColor Magenta
            Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor Magenta
            
            # Critical errors summary
            $criticalErrors = $consolidatedResults | Where-Object { $_.Result -eq "Error" }
            if ($criticalErrors.Count -gt 0) {
                Write-Host "`n🔥 CRITICAL ISSUES (Must Fix Before Arc Onboarding):" -ForegroundColor Red
                $errorGroups = $criticalErrors | Group-Object -Property Check | Sort-Object Name
                foreach ($group in $errorGroups) {
                    $affectedDevices = ($group.Group | Select-Object -Property Device -Unique).Device -join ", "
                    Write-Host "   • $($group.Name)" -ForegroundColor Red
                    Write-Host "     Affected devices: $affectedDevices" -ForegroundColor Gray
                    Write-Host "     Impact: Blocks Azure Arc onboarding process" -ForegroundColor Gray
                    Write-Host ""
                }
            }
            
            # High priority warnings
            $highPriorityWarnings = $consolidatedResults | Where-Object { 
                $_.Result -eq "Warning" -and 
                ($_.Check -eq "Azure Arc Agent" -or $_.Check -eq "Network Connectivity" -or $_.Check -eq "PowerShell Version")
            }
            if ($highPriorityWarnings.Count -gt 0) {
                Write-Host "⚠️  HIGH PRIORITY RECOMMENDATIONS:" -ForegroundColor Yellow
                $warningGroups = $highPriorityWarnings | Group-Object -Property Check | Sort-Object Name
                foreach ($group in $warningGroups) {
                    $affectedDevices = ($group.Group | Select-Object -Property Device -Unique).Device -join ", "
                    Write-Host "   • $($group.Name)" -ForegroundColor Yellow
                    Write-Host "     Affected devices: $affectedDevices" -ForegroundColor Gray
                    Write-Host "     Impact: May affect Azure Arc functionality or performance" -ForegroundColor Gray
                    Write-Host ""
                }
            }
            
            # Azure configuration status
            Write-Host "🔧 AZURE CONFIGURATION STATUS:" -ForegroundColor Cyan
            if ($AzureLoginSuccess) {
                Write-Host "   ✅ Azure Authentication: Successfully completed" -ForegroundColor Green
            } else {
                Write-Host "   ❌ Azure Authentication: Failed - required for resource provider checks" -ForegroundColor Red
            }
            
            if ($script:resourceProvidersChecked) {
                if ($script:unregisteredProviders.Count -eq 0) {
                    Write-Host "   ✅ Resource Providers: All required providers are registered" -ForegroundColor Green
                    if ($script:resourceProvidersRegistered) {
                        Write-Host "   🔧 Resource Provider Registration: New providers were registered during this session" -ForegroundColor Blue
                    }
                } else {
                    Write-Host "   ⚠️  Resource Providers: $($script:unregisteredProviders.Count) provider(s) still need registration" -ForegroundColor Yellow
                    Write-Host "      Unregistered: $($script:unregisteredProviders -join ', ')" -ForegroundColor Gray
                    if ($script:resourceProvidersRegistered) {
                        Write-Host "   🔧 Some providers were registered this session, but registration incomplete" -ForegroundColor Yellow
                    }
                }
            } else {
                if ($AzureLoginSuccess) {
                    Write-Host "   ⚠️  Resource Providers: Check incomplete - some providers may not be registered" -ForegroundColor Yellow
                } else {
                    Write-Host "   ⚠️  Resource Providers: Not checked - Azure login required" -ForegroundColor Yellow
                }
            }
            
            # Next steps recommendation
            Write-Host "`n🎯 RECOMMENDED NEXT STEPS:" -ForegroundColor Magenta
            Write-Host "`t1. Address all critical errors first (red items above)" -ForegroundColor White
            Write-Host "`t2. Resolve high-priority warnings for optimal experience" -ForegroundColor White
            Write-Host "`t3. Ensure Azure authentication is completed" -ForegroundColor White
            if ($script:resourceProvidersRegistered) {
                Write-Host "`t4. Resource providers registered - ready for Arc onboarding" -ForegroundColor White
            } else {
                Write-Host "`t4. Verify Azure resource providers are registered (script can assist)" -ForegroundColor White
            }
            Write-Host "`t5. Re-run this script to validate fixes" -ForegroundColor White
            Write-Host "`t6. Proceed with Azure Arc onboarding process" -ForegroundColor White
        }
        
        Write-Host "`n📁 Consolidated log saved as: $($script:globalLogFile)" -ForegroundColor Gray
        
        # Final status determination
        # Use the stored unregistered providers information instead of re-checking
        $allProvidersRegistered = ($AzureLoginSuccess -and $script:unregisteredProviders.Count -eq 0)
        
        if ($errorCount -eq 0 -and $warningCount -eq 0 -and $AzureLoginSuccess -and $script:resourceProvidersChecked -and $allProvidersRegistered) {
            Write-Host "`n🚀 ALL SYSTEMS GO! All prerequisites passed for all devices!" -ForegroundColor Green
            Write-Host "   Systems are fully ready for Azure Arc and MDE integration." -ForegroundColor Green
        } elseif ($errorCount -eq 0 -and $AzureLoginSuccess -and $allProvidersRegistered) {
            Write-Host "`n⚠️  READY WITH MINOR ITEMS: Prerequisites check completed with warnings only." -ForegroundColor Yellow
            Write-Host "   You can proceed with Azure Arc onboarding, but addressing warnings is recommended." -ForegroundColor Yellow
        } elseif ($errorCount -eq 0 -and $AzureLoginSuccess -and -not $allProvidersRegistered) {
            Write-Host "`n⚠️  PARTIALLY READY: Device checks passed but resource provider registration incomplete." -ForegroundColor Yellow
            Write-Host "   Please register all required Azure resource providers before Arc onboarding." -ForegroundColor Yellow
            if ($script:unregisteredProviders.Count -gt 0) {
                Write-Host "   Missing providers: $($script:unregisteredProviders -join ', ')" -ForegroundColor Gray
            }
        } else {
            Write-Host "`n❌ NOT READY: Prerequisites check completed with critical errors." -ForegroundColor Red
            Write-Host "   Please resolve all critical errors before proceeding with Azure Arc onboarding." -ForegroundColor Red
        }
    } else {
        Write-Host "❌ No results collected. Please check device connectivity and permissions." -ForegroundColor Red
    }

    Write-Host
    Write-Host "────────────────────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "END: Multi-Device Azure Arc and MDC/MDE Prerequisites Checks" -ForegroundColor Cyan
    Write-Host "────────────────────────────────────────────────────────────" -ForegroundColor Cyan
}
