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
        Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
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
        Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "📋 MODULE OVERVIEW:" -ForegroundColor Green
        Write-Host "   Comprehensive PowerShell module for Azure Arc onboarding and Microsoft Defender" -ForegroundColor White
        Write-Host "   for Endpoint integration through enterprise-grade Group Policy deployment." -ForegroundColor White
        Write-Host ""
        Write-Host "🎯 RECOMMENDED WORKFLOW:" -ForegroundColor Cyan
        Write-Host "   • [1]: Start with the validation of your environment and register Azure providers" -ForegroundColor White
        Write-Host "   • [2]: Complete Azure Arc deployment with service principals and Group Policy" -ForegroundColor White
        Write-Host "   • [3]: Perform comprehensive Azure Arc diagnostics and troubleshooting" -ForegroundColor White
        Write-Host "   • [4]: Configure Defender for Servers pricing at resource level (post-deployment)" -ForegroundColor White
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
        Write-Host "   [3] Azure Arc Diagnostics" -ForegroundColor Green
        Write-Host "       ├─ Comprehensive Azure Arc agent diagnostics" -ForegroundColor Gray
        Write-Host "       ├─ Connectivity testing and health validation" -ForegroundColor Gray
        Write-Host "       └─ Complete log collection and troubleshooting reports" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   [4] Configure Defender Pricing (Post-Deployment)" -ForegroundColor Green
        Write-Host "       ├─ Resource-level Defender for Servers pricing configuration" -ForegroundColor Gray
        Write-Host "       ├─ Support for VMs, VMSS, and Azure Arc machines" -ForegroundColor Gray
        Write-Host "       └─ Resource Group or Tag-based targeting" -ForegroundColor Gray
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
                Write-Host "║ ====================== AZURE ARC PREREQUISITES TESTING ======================= ║" -ForegroundColor Cyan
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
                Write-Host "║ ======================== AZURE ARC DEVICE DEPLOYMENT ========================= ║" -ForegroundColor Cyan
                Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "🚀 DEPLOYMENT OVERVIEW:" -ForegroundColor Yellow
                Write-Host "   This comprehensive function automates the entire Azure Arc deployment" -ForegroundColor White
                Write-Host "   process including service principal creation, agent installation, and" -ForegroundColor White
                Write-Host "   Group Policy deployment for enterprise-scale onboarding." -ForegroundColor White
                Write-Host ""
                Write-Host "📋 INTEGRATED FUNCTIONALITY:" -ForegroundColor Yellow
                Write-Host "   • Service Principal Creation - Automatically creates service principals" -ForegroundColor White
                Write-Host "   • Agent Installation - Downloads and installs Azure Connected Machine Agent" -ForegroundColor White
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
                Write-Host "║ =================== AZURE ARC DIAGNOSTICS & TROUBLESHOOTING ================== ║" -ForegroundColor Cyan
                Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "🔍 AZURE ARC DIAGNOSTICS OVERVIEW:" -ForegroundColor Yellow
                Write-Host "   This comprehensive diagnostic tool performs systematic health checks and" -ForegroundColor White
                Write-Host "   log collection for Azure Arc Connected Machine Agent troubleshooting." -ForegroundColor White
                Write-Host ""
                Write-Host "📋 DIAGNOSTIC OPERATIONS PERFORMED:" -ForegroundColor Yellow
                Write-Host "   • Agent Status Analysis - Current configuration and connection state" -ForegroundColor White
                Write-Host "   • Connectivity Validation - Network reachability and authentication tests" -ForegroundColor White
                Write-Host "   • Complete Log Collection - Comprehensive diagnostic archive generation" -ForegroundColor White
                Write-Host ""
                Write-Host "🎯 WORKFLOW & COMMANDS EXECUTED:" -ForegroundColor Green
                Write-Host "   ┌─────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Gray
                Write-Host "   │ Command               │ Description                                         │" -ForegroundColor Gray
                Write-Host "   ├─────────────────────────────────────────────────────────────────────────────┤" -ForegroundColor Gray
                Write-Host "   │ azcmagent show        │ Displays agent configuration and connection status  │" -ForegroundColor Gray
                Write-Host "   │ azcmagent check       │ Performs connectivity and health validation tests   │" -ForegroundColor Gray
                Write-Host "   │ azcmagent logs --full │ Generates complete diagnostic log archive           │" -ForegroundColor Gray
                Write-Host "   └─────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Gray
                Write-Host ""
                Write-Host "📊 OUTPUT & DELIVERABLES:" -ForegroundColor Green
                Write-Host "   • Detailed diagnostic log with timestamped results and recommendations" -ForegroundColor White
                Write-Host "   • Complete ZIP archive containing comprehensive Azure Arc diagnostic data" -ForegroundColor White
                Write-Host "   • Professional troubleshooting report suitable for Microsoft Support" -ForegroundColor White
                Write-Host ""
                Write-Host "⚖️  DISCLAIMER & LIABILITY:" -ForegroundColor Magenta
                Write-Host "   • This diagnostic tool is provided 'AS IS' without warranty of any kind" -ForegroundColor White
                Write-Host "   • Diagnostic logs may contain sensitive system information" -ForegroundColor White
                Write-Host "   • Review log contents before sharing with external parties" -ForegroundColor White
                Write-Host "   • Store diagnostic files in secure locations with appropriate access controls" -ForegroundColor White
                Write-Host "   • The author is not liable for any damages, data loss, or other" -ForegroundColor White
                Write-Host "     consequences that may result from running this script" -ForegroundColor White
                Write-Host "   • You assume full responsibility for testing and validating" -ForegroundColor White
                Write-Host "     this script in your environment before production use" -ForegroundColor White

                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                $confirm = Read-Host "Do you want to proceed with Azure Arc diagnostics collection? [Y/N] (default: Y)"
                Clear-Host  
                Write-Host ""
                if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.ToUpper() -eq "Y") {
                    Write-Host "`n🚀 Running Get-AzureArcDiagnostic..." -ForegroundColor Green
                    try {
                        $result = Get-AzureArcDiagnostic
                        if ($result) {
                            Write-Host "`n✅ Azure Arc diagnostics completed successfully." -ForegroundColor Green
                        } else {
                            Write-Host "`n⚠️ Azure Arc diagnostics completed with some issues. Check the log file for details." -ForegroundColor Yellow
                        }
                    }
                    catch {
                        Write-Host "`n❌ Error during Azure Arc diagnostics: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "Please check the error details and try again." -ForegroundColor Yellow
                    }
                    Write-Host "`nPress any key to return to the main menu..." -ForegroundColor Yellow
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                } else {
                    Write-Host "`n❌ Operation cancelled by user." -ForegroundColor Yellow
                }
            }
            "4" {
                Clear-Host
                Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
                Write-Host "║ ================= DEFENDER FOR SERVERS PRICING CONFIGURATION ================= ║" -ForegroundColor Cyan
                Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "💰 PRICING CONFIGURATION OVERVIEW:" -ForegroundColor Yellow
                Write-Host "   This post-deployment tool configures Azure Defender for Cloud pricing settings" -ForegroundColor White
                Write-Host "   at the resource level for Virtual Machines, Virtual Machine Scale Sets," -ForegroundColor White
                Write-Host "   and Azure Arc-enabled machines." -ForegroundColor White
                Write-Host ""
                Write-Host "📋 SUPPORTED OPERATIONS:" -ForegroundColor Yellow
                Write-Host "   • READ: View current pricing configuration" -ForegroundColor White
                Write-Host "   • FREE: Remove Defender protection (set to Free tier)" -ForegroundColor White
                Write-Host "   • STANDARD: Enable Defender for Cloud Plan 1 (P1)" -ForegroundColor White
                Write-Host "   • DELETE: Remove resource-level configuration (inherit from parent)" -ForegroundColor White
                Write-Host ""
                Write-Host "🎯 TARGETING OPTIONS:" -ForegroundColor Green
                Write-Host "   • Resource Group Mode: Target all resources within a specific resource group" -ForegroundColor White
                Write-Host "   • Tag-based Mode: Target resources with specific tag name and value" -ForegroundColor White
                Write-Host ""
                Write-Host "🔧 RESOURCE TYPES SUPPORTED:" -ForegroundColor Green
                Write-Host "   • Virtual Machines (Microsoft.Compute/virtualMachines)" -ForegroundColor White
                Write-Host "   • Virtual Machine Scale Sets (Microsoft.Compute/virtualMachineScaleSets)" -ForegroundColor White
                Write-Host "   • Azure Arc-enabled Machines (Microsoft.HybridCompute/machines)" -ForegroundColor White
                Write-Host ""
                Write-Host "📊 FEATURES:" -ForegroundColor Green
                Write-Host "   • Interactive parameter selection with intelligent defaults" -ForegroundColor White
                Write-Host "   • Automatic Azure authentication with token management" -ForegroundColor White
                Write-Host "   • Comprehensive success/failure reporting with detailed statistics" -ForegroundColor White
                Write-Host "   • Professional table formatting for configuration display" -ForegroundColor White
                Write-Host ""
                Write-Host "⚖️  DISCLAIMER & LIABILITY:" -ForegroundColor Magenta
                Write-Host "   • This function is provided 'AS IS' without warranty of any kind" -ForegroundColor White
                Write-Host "   • Always test in a non-production environment first" -ForegroundColor White
                Write-Host "   • Ensure you understand the implications of changing pricing configurations" -ForegroundColor White
                Write-Host "   • The author is not liable for any damages, data loss, or billing" -ForegroundColor White
                Write-Host "     consequences that may result from using this function" -ForegroundColor White
                Write-Host "   • You assume full responsibility for validating configurations" -ForegroundColor White
                Write-Host "     and understanding associated costs" -ForegroundColor White
                Write-Host ""
                Write-Host "═════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                $confirm = Read-Host "Do you want to proceed with Defender pricing configuration? [Y/N] (default: Y)"
                if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.ToUpper() -eq "Y") {
                    Write-Host "`n💰 Running Set-AzureArcResourcePricing..." -ForegroundColor Green
                    try {
                        Set-AzureArcResourcePricing
                        Write-Host "`n✅ Defender pricing configuration completed successfully." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "`n❌ Error during pricing configuration: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "Please check your Azure permissions and network connectivity." -ForegroundColor Yellow
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
                    Write-Host "║ ==========================   DETAILED HELP SYSTEM   ========================== ║" -ForegroundColor Cyan
                    Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "📚 Available commands for detailed help:" -ForegroundColor Yellow
                    Write-Host "[1] Test-AzureArcPrerequisite" -ForegroundColor White
                    Write-Host "[2] New-AzureArcDevice" -ForegroundColor White
                    Write-Host "[3] Get-AzureArcDiagnostic" -ForegroundColor White
                    Write-Host "[4] Set-AzureArcResourcePricing" -ForegroundColor White
                    Write-Host "[Q] Return to main menu" -ForegroundColor White
                    Write-Host ""
                    
                    $helpSelection = Read-Host "Select a command number (1-4) for detailed help or 'Q' to return to main menu"
                    
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
                            Write-Host "    Test-AzureArcPrerequisite [[-SubscriptionId] <String>] [[-DeviceListPath] <String>] [-Force]" -ForegroundColor White
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
                            Write-Host "║                         Get-AzureArcDiagnostic Help                            ║" -ForegroundColor Cyan
                            Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                            Write-Host ""
                            Write-Host "SYNOPSIS" -ForegroundColor Yellow
                            Write-Host "    Performs comprehensive Azure Arc agent diagnostics and collects detailed" -ForegroundColor White
                            Write-Host "    logs for troubleshooting and support analysis" -ForegroundColor White
                            Write-Host ""
                            Write-Host "SYNTAX" -ForegroundColor Yellow
                            Write-Host "    Get-AzureArcDiagnostic [[-LogPath] <String>] [-Force] [-Quiet]" -ForegroundColor White
                            Write-Host ""
                            Write-Host "DESCRIPTION" -ForegroundColor Yellow
                            Write-Host "    This comprehensive diagnostic function systematically executes Azure Arc" -ForegroundColor White
                            Write-Host "    agent commands to assess health, configuration, and operational status." -ForegroundColor White
                            Write-Host "    Generates professional diagnostic reports suitable for Microsoft Support." -ForegroundColor White
                            Write-Host ""
                            Write-Host "DIAGNOSTIC WORKFLOW" -ForegroundColor Yellow
                            Write-Host "    • azcmagent show - Displays agent configuration and connection status" -ForegroundColor White
                            Write-Host "    • azcmagent check - Performs connectivity and health validation tests" -ForegroundColor White
                            Write-Host "    • azcmagent logs --full - Generates complete diagnostic log archive" -ForegroundColor White
                            Write-Host ""
                            Write-Host "OUTPUT DELIVERABLES" -ForegroundColor Yellow
                            Write-Host "    • Timestamped diagnostic log with detailed results and recommendations" -ForegroundColor White
                            Write-Host "    • Complete ZIP archive containing comprehensive Azure Arc diagnostic data" -ForegroundColor White
                            Write-Host "    • Professional troubleshooting report with remediation guidance" -ForegroundColor White
                            Write-Host ""
                            Write-Host "EXAMPLES" -ForegroundColor Yellow
                            Write-Host "    Get-AzureArcDiagnostic" -ForegroundColor Cyan
                            Write-Host "    Get-AzureArcDiagnostic -LogPath 'C:\AzureArcDiagnostics' -Force" -ForegroundColor Cyan
                            Write-Host ""
                            Write-Host "Press any key to return to help menu..." -ForegroundColor Yellow
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "4" {
                            Clear-Host
                            Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
                            Write-Host "║                      Set-AzureArcResourcePricing Help                          ║" -ForegroundColor Cyan
                            Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                            Write-Host ""
                            Write-Host "SYNOPSIS" -ForegroundColor Yellow
                            Write-Host "    Configure Azure Defender for Cloud pricing at resource level for Virtual" -ForegroundColor White
                            Write-Host "    Machines, Virtual Machine Scale Sets, and Azure Arc-enabled machines" -ForegroundColor White
                            Write-Host ""
                            Write-Host "SYNTAX" -ForegroundColor Yellow
                            Write-Host "    Set-AzureArcResourcePricing [[-SubscriptionId] <String>]" -ForegroundColor White
                            Write-Host "        [[-ResourceGroupName] <String>] [[-TagName] <String>]" -ForegroundColor White
                            Write-Host "        [[-TagValue] <String>] [[-Mode] <String>] [[-Action] <String>]" -ForegroundColor White
                            Write-Host ""
                            Write-Host "DESCRIPTION" -ForegroundColor Yellow
                            Write-Host "    This post-deployment function configures Azure Defender for Cloud pricing" -ForegroundColor White
                            Write-Host "    settings at the resource level. Supports both Resource Group and Tag-based" -ForegroundColor White
                            Write-Host "    resource targeting with comprehensive pricing operations." -ForegroundColor White
                            Write-Host ""
                            Write-Host "SUPPORTED ACTIONS" -ForegroundColor Yellow
                            Write-Host "    • READ - View current pricing configuration" -ForegroundColor White
                            Write-Host "    • FREE - Remove Defender protection (set to Free tier)" -ForegroundColor White
                            Write-Host "    • STANDARD - Enable Defender for Cloud Plan 1 (P1)" -ForegroundColor White
                            Write-Host "    • DELETE - Remove resource-level configuration (inherit from parent)" -ForegroundColor White
                            Write-Host ""
                            Write-Host "TARGETING MODES" -ForegroundColor Yellow
                            Write-Host "    • RG - Target all resources within a specific Resource Group" -ForegroundColor White
                            Write-Host "    • TAG - Target resources with specific tag name and value" -ForegroundColor White
                            Write-Host ""
                            Write-Host "SUPPORTED RESOURCE TYPES" -ForegroundColor Yellow
                            Write-Host "    • Virtual Machines (Microsoft.Compute/virtualMachines)" -ForegroundColor White
                            Write-Host "    • Virtual Machine Scale Sets (Microsoft.Compute/virtualMachineScaleSets)" -ForegroundColor White
                            Write-Host "    • Azure Arc-enabled Machines (Microsoft.HybridCompute/machines)" -ForegroundColor White
                            Write-Host ""
                            Write-Host "EXAMPLES" -ForegroundColor Yellow
                            Write-Host "    Set-AzureArcResourcePricing" -ForegroundColor Cyan
                            Write-Host "    Set-AzureArcResourcePricing -Mode 'RG' -ResourceGroupName 'rg-prod' -Action 'standard'" -ForegroundColor Cyan
                            Write-Host "    Set-AzureArcResourcePricing -Mode 'TAG' -TagName 'Environment' -TagValue 'Production' -Action 'read'" -ForegroundColor Cyan
                            Write-Host ""
                            Write-Host "Press any key to return to help menu..." -ForegroundColor Yellow
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "Q" {
                            $exitHelp = $true
                        }
                        default {
                            Write-Host "Invalid selection. Please choose 1-4 or Q." -ForegroundColor Red
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
        
        $selection = Read-Host "Please select an option [1-4, H, Q]"
        
        Start-UserSelection -Selection $selection
        
        if ($selection.ToUpper() -eq "Q") {
            break
        }
        
    } while ($true)
}
