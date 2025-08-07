function Write-ConsolidatedResults {
    <#
    .SYNOPSIS
        Displays consolidated results for all devices checked.

    .PARAMETE                      Write-Host "  WARNINGS (Recommended to Address):"
                    foreach ($warning in $warnings) {
                        Write-Host "    $($warning.Check): $($warning.Details)"               Write-Host "  WARNINGS (Recommended to Address):"
                    foreach ($warning in $warnings) {
                        Write-Host "    $($warning.Check): $($warning.Details)"evices
        Array of device names that were checked.

    .PARAMETER AzureLoginSuccess
        Boolean indicating if Azure login was successful.
    #>
    param(
        [string[]]$Devices,
        [bool]$AzureLoginSuccess
    )

    Write-Host "`n`n CONSOLIDATED RESULTS - ALL DEVICES"
    Write-Host ""

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

        Write-Host " OVERALL SUMMARY"
        Write-Host ""
        Write-Host "Devices Checked:`t$($Devices.Count)"
        Write-Host "Total Checks:`t`t$totalChecks"
        Write-Host " OK:`t`t`t$okCount"
        Write-Host "  Warnings:`t`t$warningCount"
        Write-Host " Errors:`t`t$errorCount"
        Write-Host "  Info:`t`t$infoCount"
        Write-Host "Azure Login:`t`t$(if ($AzureLoginSuccess) { ' Success' } else { ' Failed' })"
        Write-Host "Resource Providers:`t$(if ($script:resourceProvidersChecked) { ' Checked' } else { ' Skipped' })"
        Write-Host ""

        # Device-specific summaries
        Write-Host "`n Per-Device Summary:"
        foreach ($deviceName in $script:allResults.Keys | Sort-Object) {
            $deviceResults = $script:allResults[$deviceName]
            $deviceOK = ($deviceResults | Where-Object { $_.Result -eq "OK" }).Count
            $deviceWarnings = ($deviceResults | Where-Object { $_.Result -eq "Warning" }).Count
            $deviceErrors = ($deviceResults | Where-Object { $_.Result -eq "Error" }).Count
            $deviceInfo = ($deviceResults | Where-Object { $_.Result -eq "Info" }).Count

            $osVersion = if ($script:deviceOSVersions[$deviceName]) { $script:deviceOSVersions[$deviceName] } else { "Unknown OS" }
            $status = if ($deviceErrors -gt 0) { " Errors" } elseif ($deviceWarnings -gt 0) { " Warnings" } else { " Ready" }

            Write-Host "   $deviceName [$osVersion]: $status (OK: $deviceOK, Warnings: $deviceWarnings, Errors: $deviceErrors, Info: $deviceInfo)"
        }

        # Detailed Issues per Device
        Write-Host "`n`n DETAILED ISSUES TO ADDRESS PER DEVICE"
        Write-Host ""

        $hasAnyIssues = $false
        foreach ($deviceName in $script:allResults.Keys | Sort-Object) {
            $deviceResults = $script:allResults[$deviceName]
            $deviceErrors = $deviceResults | Where-Object { $_.Result -eq "Error" }
            $deviceWarnings = $deviceResults | Where-Object { $_.Result -eq "Warning" }

            if ($deviceErrors.Count -gt 0 -or $deviceWarnings.Count -gt 0) {
                $hasAnyIssues = $true
                $osVersion = if ($script:deviceOSVersions[$deviceName]) { $script:deviceOSVersions[$deviceName] } else { "Unknown OS" }
                Write-Host "`n  DEVICE: $deviceName [$osVersion]"
                Write-Host ""

                # Display Errors first
                if ($deviceErrors.Count -gt 0) {
                    Write-Host " CRITICAL ERRORS (Must Fix):"
                    foreach ($deviceError in $deviceErrors) {
                        Write-Host "    $($deviceError.Check): $($deviceError.Details)"

                        # Provide specific remediation guidance
                        switch ($deviceError.Check) {
                            "Device Connectivity" {
                                Write-Host "      Action Required:"
                                Write-Host "        - Verify device is powered on and network accessible"
                                Write-Host "        - Enable WinRM: winrm quickconfig"
                                Write-Host "        - Check Windows Firewall settings for remote management"
                            }
                            "PowerShell Version" {
                                Write-Host "      Action Required:"
                                Write-Host "        - Download and install PowerShell 5.1 or later"
                                Write-Host "        - Or install PowerShell 7: https://github.com/PowerShell/PowerShell/releases"
                            }
                            "Az Module" {
                                Write-Host "      Action Required:"
                                Write-Host "        - Install Azure PowerShell: Install-Module -Name Az -Scope CurrentUser"
                                Write-Host "        - Or as admin: Install-Module -Name Az -Scope AllUsers"
                            }
                            "Azure Arc Agent" {
                                Write-Host "      Action Required:"
                                Write-Host "        - Download agent from Azure portal - Azure Arc - Servers"
                                Write-Host "        - Install: msiexec /i AzureConnectedMachineAgent.msi /quiet"
                            }
                            "Network Connectivity" {
                                Write-Host "      Action Required:"
                                Write-Host "        - Check internet connectivity and DNS resolution"
                                Write-Host "        - Verify firewall allows HTTPS (443) to *.azure.com"
                                Write-Host "        - Configure proxy if required"
                            }
                            "Execution Policy" {
                                Write-Host "      Action Required:"
                                Write-Host "        - Set policy: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"
                                Write-Host "        - Or as admin: Set-ExecutionPolicy RemoteSigned"
                            }
                            "MDE Service" {
                                Write-Host "      Action Required:"
                                Write-Host "        - Install Microsoft Defender for Endpoint from Microsoft 365 Defender portal"
                                Write-Host "        - Start service: Start-Service -Name Sense"
                            }
                            "MDE Extension" {
                                Write-Host "      Action Required:"
                                Write-Host "        - Install via Azure portal or PowerShell after Arc onboarding"
                                Write-Host "        - Ensure Microsoft Defender for Cloud is enabled"
                            }
                            "OS Version" {
                                Write-Host "      Action Required:"
                                Write-Host "        - Verify OS version is supported by Azure Arc"
                                Write-Host "        - Consider OS upgrade if version is not supported"
                            }
                            default {
                                Write-Host "      Action Required:"
                                Write-Host "        - Review error details and consult Azure Arc documentation"
                                Write-Host "        - Check Azure Arc troubleshooting guide"
                            }
                        }
                    }
                    Write-Host ""
                }

                # Display Warnings
                if ($deviceWarnings.Count -gt 0) {
                    Write-Host "  WARNINGS (Recommended to Address):" -ForegroundColor Yellow
                    foreach ($warning in $deviceWarnings) {
                        Write-Host "    $($warning.Check): $($warning.Details)" -ForegroundColor Yellow

                        # Provide specific recommendations
                        switch ($warning.Check) {
                            "PowerShell Version" {
                                Write-Host "      Recommendation:"
                                Write-Host "        - Consider upgrading to PowerShell 7.x for enhanced Azure features"
                                Write-Host "        - PowerShell 7 offers better cross-platform support"
                            }
                            "Az Module" {
                                Write-Host "      Recommendation:"
                                Write-Host "        - Install Az module on device for local Azure operations"
                                Write-Host "        - Enables local Azure CLI and PowerShell commands"
                            }
                            "Azure Arc Agent" {
                                Write-Host "      Recommendation:"
                                Write-Host "        - Install Azure Connected Machine agent before Arc onboarding"
                                Write-Host "        - Agent required for Azure Arc-enabled servers functionality"
                            }
                            "Network Connectivity" {
                                Write-Host "      Recommendation:"
                                Write-Host "        - Test connectivity: Test-NetConnection management.azure.com -Port 443"
                                Write-Host "        - Ensure stable internet connection for Azure services"
                            }
                            "Execution Policy" {
                                Write-Host "      Recommendation:"
                                Write-Host "        - Current policy may limit script execution capabilities"
                                Write-Host "        - Consider setting to RemoteSigned for Azure operations"
                            }
                            "MDE Service" {
                                Write-Host "      Recommendation:"
                                Write-Host "        - Install MDE for enhanced security monitoring"
                                Write-Host "        - Integrates with Azure Defender for Cloud"
                            }
                            "MDE Extension" {
                                Write-Host "      Recommendation:"
                                Write-Host "        - Extension will be available after Arc onboarding"
                                Write-Host "        - Provides automated MDE deployment capabilities"
                            }
                            "OS Version" {
                                Write-Host "      Recommendation:"
                                Write-Host "        - Verify compatibility with latest Azure Arc features"
                                Write-Host "        - Check Azure Arc supported operating systems documentation"
                            }
                            default {
                                Write-Host "      Recommendation:"
                                Write-Host "        - Review warning for potential optimization opportunities"
                                Write-Host "        - Consider addressing for optimal Azure Arc experience"
                            }
                        }
                    }
                    Write-Host ""
                }

                # Show action priority for this device
                if ($deviceErrors.Count -gt 0) {
                    Write-Host " Priority for $deviceName`: Fix $($deviceErrors.Count) critical error(s) before proceeding"
                } elseif ($deviceWarnings.Count -gt 0) {
                    Write-Host " Priority for $deviceName`: Address $($deviceWarnings.Count) warning(s) for optimal setup"
                }
            } else {
                # Device has no issues
                $osVersion = if ($script:deviceOSVersions[$deviceName]) { $script:deviceOSVersions[$deviceName] } else { "Unknown OS" }
                Write-Host "`n`n  DEVICE: $deviceName [$osVersion]"
                Write-Host ""
                Write-Host " No issues found - Ready for Azure Arc onboarding!"
            }
        }

        if (-not $hasAnyIssues) {
            Write-Host "`n EXCELLENT! No warnings or errors found across all devices!"
            Write-Host "All systems are fully ready for Azure Arc onboarding and MDE integration."
        }

        # Cross-Device Priority Summary
        if ($hasAnyIssues) {
            Write-Host "`n`n CROSS-DEVICE PRIORITY SUMMARY"
            Write-Host ""

            # Critical errors summary
            $criticalErrors = $consolidatedResults | Where-Object { $_.Result -eq "Error" }
            if ($criticalErrors.Count -gt 0) {
                Write-Host "`n CRITICAL ISSUES (Must Fix Before Arc Onboarding):" -ForegroundColor Red
                $errorGroups = $criticalErrors | Group-Object -Property Check | Sort-Object Name
                foreach ($group in $errorGroups) {
                    $affectedDevices = ($group.Group | Select-Object -Property Device -Unique).Device -join ", "
                    Write-Host "    $($group.Name)" -ForegroundColor Red
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
                Write-Host "  HIGH PRIORITY RECOMMENDATIONS:" -ForegroundColor Yellow
                $warningGroups = $highPriorityWarnings | Group-Object -Property Check | Sort-Object Name
                foreach ($group in $warningGroups) {
                    $affectedDevices = ($group.Group | Select-Object -Property Device -Unique).Device -join ", "
                    Write-Host "    $($group.Name)" -ForegroundColor Yellow
                    Write-Host "     Affected devices: $affectedDevices" -ForegroundColor Gray
                    Write-Host "     Impact: May affect Azure Arc functionality or performance" -ForegroundColor Gray
                    Write-Host ""
                }
            }

            # Azure configuration status
            Write-Host " AZURE CONFIGURATION STATUS:" -ForegroundColor Cyan
            if ($AzureLoginSuccess) {
                Write-Host "    Azure Authentication: Successfully completed" -ForegroundColor Green
            } else {
                Write-Host "    Azure Authentication: Failed - required for resource provider checks" -ForegroundColor Red
            }

            if ($script:resourceProvidersChecked) {
                if ($script:unregisteredProviders.Count -eq 0) {
                    Write-Host "    Resource Providers: All required providers are registered" -ForegroundColor Green
                    if ($script:resourceProvidersRegistered) {
                        Write-Host "    Resource Provider Registration: New providers were registered during this session" -ForegroundColor Blue
                    }
                } else {
                    Write-Host "     Resource Providers: $($script:unregisteredProviders.Count) provider(s) still need registration" -ForegroundColor Yellow
                    Write-Host "      Unregistered: $($script:unregisteredProviders -join ', ')" -ForegroundColor Gray
                    if ($script:resourceProvidersRegistered) {
                        Write-Host "    Some providers were registered this session, but registration incomplete" -ForegroundColor Yellow
                    }
                }
            } else {
                if ($AzureLoginSuccess) {
                    Write-Host "     Resource Providers: Check incomplete - some providers may not be registered" -ForegroundColor Yellow
                } else {
                    Write-Host "     Resource Providers: Not checked - Azure login required" -ForegroundColor Yellow
                }
            }

            # Next steps recommendation
            Write-Host "`n RECOMMENDED NEXT STEPS:" -ForegroundColor Magenta
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

        Write-Host "`n Consolidated log saved as: $($script:globalLogFile)" -ForegroundColor Gray

        # Final status determination
        # Use the stored unregistered providers information instead of re-checking
        $allProvidersRegistered = ($AzureLoginSuccess -and $script:unregisteredProviders.Count -eq 0)

        if ($errorCount -eq 0 -and $warningCount -eq 0 -and $AzureLoginSuccess -and $script:resourceProvidersChecked -and $allProvidersRegistered) {
            Write-Host "`n ALL SYSTEMS GO! All prerequisites passed for all devices!" -ForegroundColor Green
            Write-Host "   Systems are fully ready for Azure Arc and MDE integration." -ForegroundColor Green
        } elseif ($errorCount -eq 0 -and $AzureLoginSuccess -and $allProvidersRegistered) {
            Write-Host "`n  READY WITH MINOR ITEMS: Prerequisites check completed with warnings only." -ForegroundColor Yellow
            Write-Host "   You can proceed with Azure Arc onboarding, but addressing warnings is recommended." -ForegroundColor Yellow
        } elseif ($errorCount -eq 0 -and $AzureLoginSuccess -and -not $allProvidersRegistered) {
            Write-Host "`n  PARTIALLY READY: Device checks passed but resource provider registration incomplete." -ForegroundColor Yellow
            Write-Host "   Please register all required Azure resource providers before Arc onboarding." -ForegroundColor Yellow
            if ($script:unregisteredProviders.Count -gt 0) {
                Write-Host "   Missing providers: $($script:unregisteredProviders -join ", ")" -ForegroundColor Gray
            }
        } else {
            Write-Host "`n NOT READY: Prerequisites check completed with critical errors." -ForegroundColor Red
            Write-Host "   Please resolve all critical errors before proceeding with Azure Arc onboarding." -ForegroundColor Red
        }
    } else {
        Write-Host " No results collected. Please check device connectivity and permissions." -ForegroundColor Red
    }

    Write-Host
    Write-Host "" -ForegroundColor Cyan
    Write-Host "END: Multi-Device Azure Arc and MDC/MDE Prerequisites Checks" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan
}



