function Deploy-DefenderForServers {
    <#
    .SYNOPSIS
        Interactive menu system for Azure Arc and Microsoft Defender deployment.

    .DESCRIPTION
        This function provides an interactive menu-driven interface for deploying
        Azure Arc and Microsoft Defender for Servers across enterprise environments.
        The streamlined workflow includes prerequisites testing, complete device deployment,
        and comprehensive diagnostics.

    .EXAMPLE
        Deploy-DefenderForServers
        
        Launches the interactive menu system for Azure Arc deployment.

    .NOTES
        Author: Lessi Coulibaly
        Organization: Less-IT (AI and CyberSecurity)
        Website: https://lessit.net
        Version: 2.0.0
        
        This version features a streamlined 3-option workflow:
        1. Test prerequisites with automatic resource provider registration
        2. Complete Azure Arc deployment (service principal + agent + Group Policy)
        3. Comprehensive diagnostics and troubleshooting
    #>

    [CmdletBinding()]
    param()

    # Function to display module interface
    function Write-ModuleInterface {
        Write-Host ""
        # Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        # Write-Host "║        DEFENDER ENDPOINT DEPLOYMENT MODULE: Azure Arc & MDE Integration        ║" -ForegroundColor Cyan
        # Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "        ██████╗ ███████╗███████╗███████╗███╗   ██╗██████╗ ███████╗██████╗ " -ForegroundColor Cyan
        Write-Host "        ██╔══██╗██╔════╝██╔════╝██╔════╝████╗  ██║██╔══██╗██╔════╝██╔══██╗" -ForegroundColor Cyan
        Write-Host "        ██║  ██║█████╗  █████╗  █████╗  ██╔██╗ ██║██║  ██║█████╗  ██████╔╝" -ForegroundColor Cyan
        Write-Host "        ██║  ██║██╔══╝  ██╔══╝  ██╔══╝  ██║╚██╗██║██║  ██║██╔══╝  ██╔══██╗" -ForegroundColor Cyan
        Write-Host "        ██████╔╝███████╗██║     ███████╗██║ ╚████║██████╔╝███████╗██║  ██║" -ForegroundColor Cyan
        Write-Host "        ╚═════╝ ╚══════╝╚═╝     ╚══════╝╚═╝  ╚═══╝╚═════╝ ╚══════╝╚═╝  ╚═╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "        ███████╗███╗   ██╗██████╗ ██████╗  ██████╗ ██╗███╗   ██╗████████╗" -ForegroundColor Cyan
        Write-Host "        ██╔════╝████╗  ██║██╔══██╗██╔══██╗██╔═══██╗██║████╗  ██║╚══██╔══╝" -ForegroundColor Cyan
        Write-Host "        █████╗  ██╔██╗ ██║██║  ██║██████╔╝██║   ██║██║██╔██╗ ██║   ██║   " -ForegroundColor Cyan
        Write-Host "        ██╔══╝  ██║╚██╗██║██║  ██║██╔═══╝ ██║   ██║██║██║╚██╗██║   ██║   " -ForegroundColor Cyan
        Write-Host "        ███████╗██║ ╚████║██████╔╝██║     ╚██████╔╝██║██║ ╚████║   ██║   " -ForegroundColor Cyan
        Write-Host "        ╚══════╝╚═╝  ╚═══╝╚═════╝ ╚═╝      ╚═════╝ ╚═╝╚═╝  ╚═══╝   ╚═╝   " -ForegroundColor Cyan
        Write-Host ""
        Write-Host "📋 MODULE OVERVIEW:" -ForegroundColor Green
        Write-Host "   Comprehensive PowerShell module for Azure Arc onboarding and Microsoft Defender" -ForegroundColor White
        Write-Host "   for Endpoint integration through enterprise-grade Group Policy deployment." -ForegroundColor White
        Write-Host ""
        Write-Host "🎯 RECOMMENDED WORKFLOW:" -ForegroundColor Cyan
        Write-Host "   • [1]: Start with the validation of your environment and register Azure providers" -ForegroundColor White
        Write-Host "   • [2]: Complete Azure Arc deployment with service principals and Group Policy" -ForegroundColor White
        Write-Host "   • [3]: Perform troubleshooting and diagnostics" -ForegroundColor White
        Write-Host ""
    }

    # Function to display interactive menu
    function Write-InteractiveMenu {
        Write-Host "🚀 AVAILABLE COMMANDS:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   [1] Test Azure Arc Prerequisites" -ForegroundColor Green
        Write-Host "       ├─ Enhanced prerequisites validation" -ForegroundColor Gray
        Write-Host "       ├─ Automatic Azure resource provider registration" -ForegroundColor Gray
        Write-Host "       └─ Network connectivity testing" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [2] Deploy Azure Arc Device" -ForegroundColor Green
        Write-Host "       ├─ Complete deployment including service principal creation" -ForegroundColor Gray
        Write-Host "       ├─ Azure Connected Machine Agent installation" -ForegroundColor Gray
        Write-Host "       └─ Group Policy configuration and deployment" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [3] Run Azure Arc Diagnostics" -ForegroundColor Green
        Write-Host "       ├─ Comprehensive connectivity testing" -ForegroundColor Gray
        Write-Host "       ├─ Agent status validation" -ForegroundColor Gray
        Write-Host "       └─ Log collection and troubleshooting" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [H] Help - Detailed command information" -ForegroundColor Cyan
        Write-Host "   [Q] Quit - Exit the module" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
    }

    # Function to handle user selection
    function Start-UserSelection {
        param (
            [string]$Selection
        )
        
        switch ($Selection.ToUpper()) {
            "1" {
                Clear-Host
                Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
                Write-Host "║                        AZURE ARC PREREQUISITES TESTING                         ║" -ForegroundColor Cyan
                Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "🔍 PREREQUISITES CHECK OVERVIEW:" -ForegroundColor Yellow
                Write-Host "   This enhanced function validates all prerequisites for Azure Arc deployment" -ForegroundColor White
                Write-Host "   and automatically registers required Azure resource providers for a" -ForegroundColor White
                Write-Host "   streamlined experience." -ForegroundColor White
                Write-Host ""
                Write-Host "📋 ACTIONS TO BE PERFORMED:" -ForegroundColor Yellow
                Write-Host "   • Validate PowerShell version and execution policy" -ForegroundColor White
                Write-Host "   • Check Azure PowerShell modules installation" -ForegroundColor White
                Write-Host "   • Test network connectivity to Azure Arc endpoints" -ForegroundColor White
                Write-Host "   • Automatically register Azure resource providers" -ForegroundColor White
                Write-Host "   • Validate system requirements and security settings" -ForegroundColor White
                Write-Host "   • Generate comprehensive readiness report" -ForegroundColor White
                Write-Host ""
                Write-Host "📊 FEATURES:" -ForegroundColor Green
                Write-Host "   • Automatic resource provider registration (no manual step required)" -ForegroundColor White
                Write-Host "   • Enhanced network connectivity testing" -ForegroundColor White
                Write-Host "   • Multi-device support with detailed reporting" -ForegroundColor White
                Write-Host ""
                Write-Host "⚖️  DISCLAIMER & LIABILITY:" -ForegroundColor Magenta
                Write-Host "   • This script is provided 'AS IS' without warranty of any kind" -ForegroundColor White
                Write-Host "   • The author is not liable for any damages, data loss, or other" -ForegroundColor White
                Write-Host "     consequences that may result from running this script" -ForegroundColor White
                Write-Host "   • You assume full responsibility for testing and validating" -ForegroundColor White
                Write-Host "     this script in your environment before production use" -ForegroundColor White
                Write-Host ""
                Write-Host "═════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                $confirm = Read-Host "Do you want to proceed with prerequisites testing? [Y/N] (default: Y)"
                if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.ToUpper() -eq "Y") {
                    Write-Host "`n🔍 Running Test-AzureArcPrerequisite..." -ForegroundColor Green
                    try {
                        Test-AzureArcPrerequisite -Force
                        Write-Host "`n✅ Prerequisites testing completed successfully." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "`n❌ Error during prerequisites testing: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "Please ensure all required modules are installed and try again." -ForegroundColor Yellow
                    }
                    Write-Host "`nPress any key to return to the main menu..." -ForegroundColor Yellow
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                } else {
                    Write-Host "`n❌ Operation cancelled by user." -ForegroundColor Yellow
                }
            }
            "2" {
                Clear-Host
                Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
                Write-Host "║                         AZURE ARC DEVICE DEPLOYMENT                            ║" -ForegroundColor Cyan
                Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "🚀 DEPLOYMENT OVERVIEW:" -ForegroundColor Yellow
                Write-Host "   This comprehensive function automates the entire Azure Arc deployment" -ForegroundColor White
                Write-Host "   process including service principal creation, agent installation, and" -ForegroundColor White
                Write-Host "   Group Policy deployment for enterprise-scale onboarding." -ForegroundColor White
                Write-Host ""
                Write-Host "📋 INTEGRATED FUNCTIONALITY:" -ForegroundColor Yellow
                Write-Host "   • Service Principal Creation - Automatically creates service principals" -ForegroundColor White
                Write-Host "   • Agent Installation - Downloads and optionally installs Azure Connected Machine Agent" -ForegroundColor White
                Write-Host "   • Group Policy Configuration - Creates and deploys Group Policy objects" -ForegroundColor White
                Write-Host "   • File share setup for Group Policy deployment" -ForegroundColor White
                Write-Host "   • OU linking and configuration management" -ForegroundColor White
                Write-Host ""
                Write-Host "📊 STREAMLINED WORKFLOW:" -ForegroundColor Green
                Write-Host "   • All deployment steps combined into one function" -ForegroundColor White
                Write-Host "   • Automatic configuration with interactive prompts" -ForegroundColor White
                Write-Host "   • Enterprise-ready Group Policy deployment" -ForegroundColor White
                Write-Host ""
                Write-Host "⚖️  DISCLAIMER & LIABILITY:" -ForegroundColor Magenta
                Write-Host "   • This script is provided 'AS IS' without warranty of any kind" -ForegroundColor White
                Write-Host "   • The author is not liable for any damages, data loss, or other" -ForegroundColor White
                Write-Host "     consequences that may result from running this script" -ForegroundColor White
                Write-Host "   • You assume full responsibility for testing and validating" -ForegroundColor White
                Write-Host "     this script in your environment before production use" -ForegroundColor White
                Write-Host ""
                Write-Host "═════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                $confirm = Read-Host "Do you want to proceed with complete Azure Arc deployment? [Y/N] (default: Y)"
                if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.ToUpper() -eq "Y") {
                    Write-Host "`n🚀 Running New-AzureArcDevice..." -ForegroundColor Green
                    try {
                        New-AzureArcDevice -Force
                        Write-Host "`n✅ Azure Arc deployment completed successfully." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "`n❌ Error during Azure Arc deployment: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "Please check the error details and try again." -ForegroundColor Yellow
                    }
                    Write-Host "`nPress any key to return to the main menu..." -ForegroundColor Yellow
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                } else {
                    Write-Host "`n❌ Operation cancelled by user." -ForegroundColor Yellow
                }
            }
            "3" {
                Clear-Host
                Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
                Write-Host "║                      AZURE ARC DIAGNOSTICS & TROUBLESHOOTING                   ║" -ForegroundColor Cyan
                Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "🔧 COMPREHENSIVE DIAGNOSTICS OVERVIEW:" -ForegroundColor Yellow
                Write-Host "   This diagnostic function provides comprehensive analysis of your Azure Arc" -ForegroundColor White
                Write-Host "   deployment including connectivity testing, agent status validation," -ForegroundColor White
                Write-Host "   and detailed log collection for troubleshooting." -ForegroundColor White
                Write-Host ""
                Write-Host "📋 DIAGNOSTIC CAPABILITIES:" -ForegroundColor Yellow
                Write-Host "   • Comprehensive connectivity testing to Azure Arc endpoints" -ForegroundColor White
                Write-Host "   • Azure Connected Machine Agent status validation" -ForegroundColor White
                Write-Host "   • Multi-device diagnostic support" -ForegroundColor White
                Write-Host "   • Automated log archiving for support cases" -ForegroundColor White
                Write-Host "   • Detailed health and performance reporting" -ForegroundColor White
                Write-Host "   • Configuration validation and recommendations" -ForegroundColor White
                Write-Host ""
                Write-Host "🎯 TROUBLESHOOTING FEATURES:" -ForegroundColor Green
                Write-Host "   • Automated issue detection and resolution suggestions" -ForegroundColor White
                Write-Host "   • Comprehensive log collection and analysis" -ForegroundColor White
                Write-Host "   • Support-ready diagnostic packages" -ForegroundColor White
                Write-Host ""
                Write-Host "⚖️  DISCLAIMER & LIABILITY:" -ForegroundColor Magenta
                Write-Host "   • This script is provided 'AS IS' without warranty of any kind" -ForegroundColor White
                Write-Host "   • The author is not liable for any damages, data loss, or other" -ForegroundColor White
                Write-Host "     consequences that may result from running this script" -ForegroundColor White
                Write-Host "   • You assume full responsibility for testing and validating" -ForegroundColor White
                Write-Host "     this script in your environment before production use" -ForegroundColor White
                Write-Host ""

                Write-Host "═════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                $confirm = Read-Host "Do you want to proceed with Azure Arc diagnostics? [Y/N] (default: Y)"
                if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.ToUpper() -eq "Y") {
                    Write-Host "`n🔧 Running Get-AzureArcDiagnostics..." -ForegroundColor Green
                    try {
                        Get-AzureArcDiagnostics -SkipPrompt -CollectLogs
                        Write-Host "`n✅ Azure Arc diagnostics completed successfully." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "`n❌ Error during diagnostics: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "Some diagnostic functions may require administrative privileges." -ForegroundColor Yellow
                    }
                    Write-Host "`nPress any key to return to the main menu..." -ForegroundColor Yellow
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                } else {
                    Write-Host "`n❌ Operation cancelled by user." -ForegroundColor Yellow
                }
            }
            "H" {
                $exitHelp = $false
                do {
                    Clear-Host
                    Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
                    Write-Host "║                              DETAILED HELP SYSTEM                              ║" -ForegroundColor Cyan
                    Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "📚 Available commands for detailed help:" -ForegroundColor Yellow
                    Write-Host "[1] Test-AzureArcPrerequisite" -ForegroundColor White
                    Write-Host "[2] New-AzureArcDevice" -ForegroundColor White
                    Write-Host "[3] Get-AzureArcDiagnostics" -ForegroundColor White
                    Write-Host "[Q] Return to main menu" -ForegroundColor White
                    Write-Host ""
                    
                    $helpSelection = Read-Host "Select a command number (1-3) for detailed help or 'Q' to return to main menu"
                    
                    switch ($helpSelection.ToUpper()) {
                        "1" {
                            Clear-Host
                            Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
                            Write-Host "║                         Test-AzureArcPrerequisite Help                         ║" -ForegroundColor Cyan
                            Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                            Write-Host ""
                            Write-Host "SYNOPSIS" -ForegroundColor Yellow
                            Write-Host "    Tests Azure Arc prerequisites and automatically registers resource providers" -ForegroundColor White
                            Write-Host ""
                            Write-Host "SYNTAX" -ForegroundColor Yellow
                            Write-Host "    Test-AzureArcPrerequisite [[-DeviceListPath] <String>] [-Force]" -ForegroundColor White
                            Write-Host "        [-NetworkTestMode <String>] [-IncludeOptionalEndpoints] [-TestTLSVersion]" -ForegroundColor White
                            Write-Host "        [-ShowDetailedNetworkResults] [[-NetworkLogPath] <String>]" -ForegroundColor White
                            Write-Host ""
                            Write-Host "DESCRIPTION" -ForegroundColor Yellow
                            Write-Host "    This enhanced function validates all prerequisites for Azure Arc deployment" -ForegroundColor White
                            Write-Host "    including PowerShell version, Azure modules, execution policy, and network" -ForegroundColor White
                            Write-Host "    connectivity. It also automatically registers required Azure resource providers." -ForegroundColor White
                            Write-Host ""
                            Write-Host "KEY FEATURES" -ForegroundColor Yellow
                            Write-Host "    • Comprehensive prerequisites validation" -ForegroundColor White
                            Write-Host "    • Automatic Azure resource provider registration" -ForegroundColor White
                            Write-Host "    • Network connectivity testing to Azure Arc endpoints" -ForegroundColor White
                            Write-Host "    • Multi-device support with detailed reporting" -ForegroundColor White
                            Write-Host "    • Enhanced security and system requirements validation" -ForegroundColor White
                            Write-Host ""
                            Write-Host "EXAMPLES" -ForegroundColor Yellow
                            Write-Host "    Test-AzureArcPrerequisite" -ForegroundColor Cyan
                            Write-Host "    Test-AzureArcPrerequisite -Force -NetworkTestMode Comprehensive" -ForegroundColor Cyan
                            Write-Host ""
                            Write-Host "Press any key to return to help menu..." -ForegroundColor Yellow
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "2" {
                            Clear-Host
                            Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
                            Write-Host "║                            New-AzureArcDevice Help                             ║" -ForegroundColor Cyan
                            Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                            Write-Host ""
                            Write-Host "SYNOPSIS" -ForegroundColor Yellow
                            Write-Host "    Complete Azure Arc deployment including service principal creation, agent" -ForegroundColor White
                            Write-Host "    installation, and Group Policy deployment" -ForegroundColor White
                            Write-Host ""
                            Write-Host "SYNTAX" -ForegroundColor Yellow
                            Write-Host "    New-AzureArcDevice [[-ResourceGroupName] <String>] [[-Location] <String>]" -ForegroundColor White
                            Write-Host "        [[-SharePath] <String>] [-Force]" -ForegroundColor White
                            Write-Host ""
                            Write-Host "DESCRIPTION" -ForegroundColor Yellow
                            Write-Host "    This comprehensive function automates the complete Azure Arc deployment" -ForegroundColor White
                            Write-Host "    process including service principal creation, agent installation, and" -ForegroundColor White
                            Write-Host "    Group Policy configuration for enterprise-scale onboarding." -ForegroundColor White
                            Write-Host ""
                            Write-Host "INTEGRATED FUNCTIONALITY" -ForegroundColor Yellow
                            Write-Host "    • Service Principal Creation - Automatically creates service principals" -ForegroundColor White
                            Write-Host "    • Agent Installation - Downloads and optionally installs Azure Connected Machine Agent" -ForegroundColor White
                            Write-Host "    • Group Policy Configuration - Creates and deploys Group Policy objects" -ForegroundColor White
                            Write-Host "    • File share setup for Group Policy deployment" -ForegroundColor White
                            Write-Host "    • OU linking and configuration management" -ForegroundColor White
                            Write-Host ""
                            Write-Host "EXAMPLES" -ForegroundColor Yellow
                            Write-Host "    New-AzureArcDevice" -ForegroundColor Cyan
                            Write-Host "    New-AzureArcDevice -ResourceGroupName 'rg-azurearc-prod' -Location 'eastus' -Force" -ForegroundColor Cyan
                            Write-Host ""
                            Write-Host "Press any key to return to help menu..." -ForegroundColor Yellow
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "3" {
                            Clear-Host
                            Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
                            Write-Host "║                          Get-AzureArcDiagnostics Help                          ║" -ForegroundColor Cyan
                            Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                            Write-Host ""
                            Write-Host "SYNOPSIS" -ForegroundColor Yellow
                            Write-Host "    Comprehensive Azure Arc diagnostics and troubleshooting" -ForegroundColor White
                            Write-Host ""
                            Write-Host "SYNTAX" -ForegroundColor Yellow
                            Write-Host "    Get-AzureArcDiagnostics [[-LogPath] <String>] [[-DeviceListPath] <String>]" -ForegroundColor White
                            Write-Host "        [-SkipPrompt] [-CollectLogs] [-CreateArchive]" -ForegroundColor White
                            Write-Host ""
                            Write-Host "DESCRIPTION" -ForegroundColor Yellow
                            Write-Host "    This function provides comprehensive diagnostics for Azure Arc deployments" -ForegroundColor White
                            Write-Host "    including connectivity testing, agent status validation, and log collection." -ForegroundColor White
                            Write-Host ""
                            Write-Host "FEATURES" -ForegroundColor Yellow
                            Write-Host "    • Comprehensive diagnostic data collection" -ForegroundColor White
                            Write-Host "    • Multi-device diagnostic support" -ForegroundColor White
                            Write-Host "    • Automated log archiving for support cases" -ForegroundColor White
                            Write-Host "    • Detailed connectivity and health reporting" -ForegroundColor White
                            Write-Host ""
                            Write-Host "EXAMPLES" -ForegroundColor Yellow
                            Write-Host "    Get-AzureArcDiagnostics" -ForegroundColor Cyan
                            Write-Host "    Get-AzureArcDiagnostics -LogPath 'C:\ArcDiagnostics' -CollectLogs" -ForegroundColor Cyan
                            Write-Host ""
                            Write-Host "Press any key to return to help menu..." -ForegroundColor Yellow
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "Q" {
                            $exitHelp = $true
                        }
                        default {
                            Write-Host "Invalid selection. Please choose 1-3 or Q." -ForegroundColor Red
                        }
                    }
                } while (-not $exitHelp)
            }
            "Q" {
                Write-Host "`n👋 Thank you for using the DefenderEndpointDeployment module!" -ForegroundColor Green
                Write-Host "Exiting...`n" -ForegroundColor Gray
                return
            }
            default {
                Write-Host "`n❌ Invalid selection. Please choose a valid option (1-3, H, or Q)." -ForegroundColor Red
            }
        }
    }

    # Main module loop
    do {
        Clear-Host
        Write-ModuleInterface
        Write-InteractiveMenu
        
        $selection = Read-Host "Please select an option [1-3, H, Q]"
        
        Start-UserSelection -Selection $selection
        
        if ($selection.ToUpper() -eq "Q") {
            break
        }
        
    } while ($true)
}
