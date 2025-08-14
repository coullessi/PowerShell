function Start-ServerProtection {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    <#
    .SYNOPSIS
        Interactive menu system for Azure Arc and Microsoft Defender deployment.

    .DESCRIPTION
        This function provides an interactive menu-driven interface for deploying
        Azure Arc and Microsoft Defender for Servers across enterprise environments.
        The streamlined workflow includes prerequisites testing, complete device deployment,
        and comprehensive diagnostics.

    .EXAMPLE
        Start-ServerProtection

        Launches the interactive menu system for Azure Arc deployment.

    .NOTES
        Author: Lessi Coulibaly
        Organization: Less-IT (AI and CyberSecurity)
        Website: https://github.com/coullessi/PowerShell
        Version: 1.0.0

        This version features a streamlined 3-option workflow:
        1. Test prerequisites with automatic resource provider registration
        2. Complete Azure Arc deployment (service principal + agent + Group Policy)
        3. Comprehensive diagnostics and troubleshooting
    #>

    [CmdletBinding()]
    param()

    # Module initialization check
    $requiredFunctions = @(
        'Get-AzureArcPrerequisite',
        'New-AzureArcDevice',
        'Get-AzureArcDiagnostic',
        'Set-AzureArcResourcePricing'
    )

    $missingFunctions = @()
    foreach ($function in $requiredFunctions) {
        if (-not (Get-Command $function -ErrorAction SilentlyContinue)) {
            $missingFunctions += $function
        }
    }

    if ($missingFunctions.Count -gt 0) {
        Write-Host ""
        Write-Host " ERROR: Missing required functions"
        Write-Host " The following functions are not available:"
        foreach ($func in $missingFunctions) {
            Write-Host "   - $func"
        }
        Write-Host ""
        Write-Host " SOLUTION:" -ForegroundColor Yellow
        Write-Host "   1. Ensure you are running this from the correct module context"
        Write-Host "   2. Try importing the module: Import-Module ServerProtection -Force"
        Write-Host "   3. Verify the module files are complete and not corrupted"
        Write-Host ""
        return
    }

    # Function to display module interface
    function Write-ModuleInterface {
        Write-Host ""

        # ASCII Art Header - ARC-DFS
        Write-Host ""
        Write-Host "  █████╗ ██████╗  ██████╗      ██████╗ ███████╗███████╗"
        Write-Host " ██╔══██╗██╔══██╗██╔════╝      ██╔══██╗██╔════╝██╔════╝"
        Write-Host " ███████║██████╔╝██║     █████╗██║  ██║█████╗  ███████╗"
        Write-Host " ██╔══██║██╔══██╗██║     ╚════╝██║  ██║██╔══╝  ╚════██║"
        Write-Host " ██║  ██║██║  ██║╚██████╗      ██████╔╝██║     ███████║"
        Write-Host " ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝      ╚═════╝ ╚═╝     ╚══════╝"
        Write-Host ""
        Write-Host " MODULE OVERVIEW:"
        Write-Host "   Comprehensive PowerShell module for Azure Arc onboarding and Microsoft Defender"
        Write-Host "   for Servers integration through enterprise-grade Group Policy deployment."
        Write-Host ""
        Write-Host " DEFENDER FOR SERVERS (DFS) INTEGRATION:"
        Write-Host "   Microsoft Defender for Servers provides advanced threat protection for your"
        Write-Host "   server workloads in Microsoft Defender for Cloud. This module streamlines"
        Write-Host "   the deployment process by automating Azure Arc agent installation and"
        Write-Host "   enabling seamless Defender for Servers protection across your infrastructure."
        Write-Host ""
        Write-Host " KEY BENEFITS:"
        Write-Host "   • Advanced threat detection and behavioral analytics"
        Write-Host "   • Vulnerability assessment and management"
        Write-Host "   • Just-in-time VM access and adaptive application controls"
        Write-Host "   • Security recommendations and compliance monitoring"
        Write-Host "   • Integration with Microsoft Sentinel"
        Write-Host ""
        Write-Host " AVAILABLE COMMANDS:"
        Write-Host "   [1] Test Azure Arc Prerequisites"
        Write-Host "       Enhanced prerequisites validation with automatic Azure resource provider registration"
        Write-Host ""
        Write-Host "   [2] Deploy Azure Arc Device"
        Write-Host "       Complete deployment including service principal creation and Group Policy configuration"
        Write-Host ""
        Write-Host "   [3] Azure Arc Diagnostics"
        Write-Host "       Comprehensive Azure Arc agent diagnostics and troubleshooting reports"
        Write-Host ""
        Write-Host "   [4] Configure Defender Pricing (Post-Deployment)"
        Write-Host "       Resource-level Defender for Servers pricing configuration"
        Write-Host ""
        Write-Host "   [H] Help - Detailed command information"
        Write-Host ""
        Write-Host "   [Q] Quit - Exit the module"
        Write-Host ""
    }

    # Function to handle user selection
    function Start-UserSelection {
        [CmdletBinding()]
        param (
            [string]$Selection
        )

        switch ($Selection.ToUpper()) {
            "1" {
                Clear-Host
                Write-Host ""
                Write-Host " ====================== AZURE ARC PREREQUISITES TESTING ======================= " -ForegroundColor Green
                Write-Host ""
                Write-Host ""
                Write-Host " PREREQUISITES CHECK OVERVIEW:"
                Write-Host "   This enhanced function validates all prerequisites for Azure Arc deployment"
                Write-Host "   and automatically registers required Azure resource providers for a"
                Write-Host "   streamlined experience."
                Write-Host ""
                Write-Host " ACTIONS TO BE PERFORMED:"
                Write-Host "    Validate PowerShell version and execution policy"
                Write-Host "    Check Azure PowerShell modules installation"
                Write-Host "    Test network connectivity to Azure Arc endpoints"
                Write-Host "    Automatically register Azure resource providers"
                Write-Host "    Validate system requirements and security settings"
                Write-Host "    Generate comprehensive readiness report"
                Write-Host ""
                Write-Host " FEATURES:" -ForegroundColor Yellow
                Write-Host "    Automatic resource provider registration (no manual step required)"
                Write-Host "    Enhanced network connectivity testing"
                Write-Host "    Multi-device support with detailed reporting"
                Write-Host ""
                Write-Host "  DISCLAIMER `& LIABILITY:" -ForegroundColor Yellow
                Write-Host "    This script is provided 'AS IS' without warranty of any kind."
                Write-Host "    The author is not liable for any damages, data loss, or other"
                Write-Host "    consequences that may result from running this script."
                Write-Host "    You assume full responsibility for testing and validating"
                Write-Host "    this script in your environment before production use."
                Write-Host ""
                Write-Host ""
                Write-Host ""
                $confirm = Read-Host "Do you want to proceed with prerequisites testing? [Y/N] (default: Y)"
                if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.ToUpper() -eq "Y") {
                    if ($PSCmdlet.ShouldProcess("System", "Run Azure Arc Prerequisites Testing")) {
                        Write-Host "`n Running Get-AzureArcPrerequisite..."
                        try {
                            # Check if the function is available
                            if (-not (Get-Command Get-AzureArcPrerequisite -ErrorAction SilentlyContinue)) {
                                throw "Get-AzureArcPrerequisite function not found. Please ensure the ServerProtection module is properly imported."
                            }

                            Get-AzureArcPrerequisite -Force
                            Write-Host "`n Prerequisites testing completed successfully."
                        }
                        catch {
                            Write-Host "`n Error during prerequisites testing. Please check your setup." -ForegroundColor Red
                            Write-Host "Please ensure the ServerProtection module is properly imported and try again."
                            Write-Host "Try running: Import-Module ServerProtection -Force"
                        }
                    }
                    Write-Host "`nPress any key to return to the main menu..."
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                } else {
                    Write-Host "`n Operation cancelled by user."
                }
            }
            "2" {
                Clear-Host
                Write-Host ""
                Write-Host " ======================== AZURE ARC DEVICE DEPLOYMENT ========================= " -ForegroundColor Green
                Write-Host ""
                Write-Host ""
                Write-Host " DEPLOYMENT OVERVIEW:"
                Write-Host "   This comprehensive function automates the entire Azure Arc deployment"
                Write-Host "   process including service principal creation, agent installation, and"
                Write-Host "   Group Policy deployment for enterprise-scale onboarding."
                Write-Host ""
                Write-Host " INTEGRATED FUNCTIONALITY:" -ForegroundColor Yellow
                Write-Host "    Service Principal Creation - Automatically creates service principals"
                Write-Host "    Agent Installation - Downloads and installs Azure Connected Machine Agent"
                Write-Host "    Group Policy Configuration - Creates and deploys Group Policy objects"
                Write-Host "    File share setup for Group Policy deployment"
                Write-Host "    OU linking and configuration management"
                Write-Host ""
                Write-Host " STREAMLINED WORKFLOW:" -ForegroundColor Yellow
                Write-Host "    All deployment steps combined into one function"
                Write-Host "    Automatic configuration with interactive prompts"
                Write-Host "    Enterprise-ready Group Policy deployment"
                Write-Host ""
                Write-Host "  DISCLAIMER & LIABILITY:" -ForegroundColor Yellow
                Write-Host "  DISCLAIMER `& LIABILITY:" -ForegroundColor Yellow
                Write-Host "    This script is provided 'AS IS' without warranty of any kind."
                Write-Host "    The author is not liable for any damages, data loss, or other"
                Write-Host "    consequences that may result from running this script."
                Write-Host "    You assume full responsibility for testing and validating"
                Write-Host "    this script in your environment before production use."
                Write-Host ""
                Write-Host ""
                $confirm = Read-Host "Do you want to proceed with complete Azure Arc deployment? [Y/N] (default: Y)"
                if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.ToUpper() -eq "Y") {
                    Write-Host "`n Running New-AzureArcDevice..."
                    try {
                        # Check if the function is available
                        if (-not (Get-Command New-AzureArcDevice -ErrorAction SilentlyContinue)) {
                            throw "New-AzureArcDevice function not found. Please ensure the ServerProtection module is properly imported."
                        }

                        New-AzureArcDevice -Force
                        Write-Host "`n Azure Arc deployment completed successfully."
                    }
                    catch {
                        Write-Host "`n Error during Azure Arc deployment. Please check your configuration." -ForegroundColor Red
                        Write-Host "Please check the error details and try again."
                        Write-Host "Try running: Import-Module ServerProtection -Force"
                    }
                    Write-Host "`nPress any key to return to the main menu..."
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                } else {
                    Write-Host "`n Operation cancelled by user."
                }
            }
            "3" {
                Clear-Host
                Write-Host ""
                Write-Host " =================== AZURE ARC DIAGNOSTICS `& TROUBLESHOOTING ================== " -ForegroundColor Green
                Write-Host ""
                Write-Host ""
                Write-Host " AZURE ARC DIAGNOSTICS OVERVIEW:"
                Write-Host "   This comprehensive diagnostic tool performs systematic health checks and"
                Write-Host "   log collection for Azure Arc Connected Machine Agent troubleshooting."
                Write-Host ""
                Write-Host " DIAGNOSTIC OPERATIONS PERFORMED:"
                Write-Host "    Agent Status Analysis - Current configuration and connection state"
                Write-Host "    Connectivity Validation - Network reachability and authentication tests"
                Write-Host "    Complete Log Collection - Comprehensive diagnostic archive generation"
                Write-Host ""
                Write-Host " WORKFLOW `& COMMANDS EXECUTED:"
                Write-Host "   "
                Write-Host "    Command                Description                                         "
                Write-Host "   "
                Write-Host "    azcmagent show         Displays agent configuration and connection status  "
                Write-Host "    azcmagent check        Performs connectivity and health validation tests   "
                Write-Host "    azcmagent logs --full  Generates complete diagnostic log archive           "
                Write-Host "   "
                Write-Host ""
                Write-Host " OUTPUT `& DELIVERABLES:" -ForegroundColor Yellow
                Write-Host "    Detailed diagnostic log with timestamped results and recommendations."
                Write-Host "    Complete ZIP archive containing comprehensive Azure Arc diagnostic data."
                Write-Host "    Professional troubleshooting report suitable for Microsoft Support."
                Write-Host ""
                Write-Host "  DISCLAIMER `& LIABILITY:" -ForegroundColor Yellow
                Write-Host "    This diagnostic tool is provided 'AS IS' without warranty of any kind."
                Write-Host "    Diagnostic logs may contain sensitive system information."
                Write-Host "    Review log contents before sharing with external parties."
                Write-Host "    Store diagnostic files in secure locations with appropriate access controls."
                Write-Host "    The author is not liable for any damages, data loss, or other"
                Write-Host "    consequences that may result from running this script"
                Write-Host "    You assume full responsibility for testing and validating"
                Write-Host "    this script in your environment before production use."

                Write-Host ""
                Write-Host ""
                $confirm = Read-Host "Do you want to proceed with Azure Arc diagnostics collection? [Y/N] (default: Y)"
                Clear-Host
                Write-Host ""
                if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.ToUpper() -eq "Y") {
                    Write-Host "`n Running Get-AzureArcDiagnostic..."
                    try {
                        # Check if the function is available
                        if (-not (Get-Command Get-AzureArcDiagnostic -ErrorAction SilentlyContinue)) {
                            throw "Get-AzureArcDiagnostic function not found. Please ensure the ServerProtection module is properly imported."
                        }

                        $result = Get-AzureArcDiagnostic
                        if ($null -eq $result) {
                            # User quit to main menu - do nothing, just return
                            return
                        } elseif ($result) {
                            Write-Host "`n Azure Arc diagnostics completed successfully."
                            Write-Host " All diagnostic checks passed. Review the log file for detailed results."
                        } else {
                            Write-Host "`n Azure Arc diagnostics completed with issues."
                            Write-Host " Common issues:"
                            Write-Host "   - Azure Arc agent not installed (download from: https://aka.ms/AzureConnectedMachineAgent)"
                            Write-Host "   - Network connectivity problems"
                            Write-Host "   - Insufficient permissions"
                            Write-Host " Check the consolidated log file for detailed error information."
                        }
                    }
                    catch {
                        Write-Host "`n Error during Azure Arc diagnostics. Please check your setup." -ForegroundColor Red
                        Write-Host "Please check the error details and try again."
                        Write-Host "Try running: Import-Module ServerProtection -Force"
                    }

                    # Only show "Press any key" if user didn't quit to main menu
                    if ($null -ne $result) {
                        Write-Host "`nPress any key to return to the main menu..."
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    }
                } else {
                    Write-Host "`n Operation cancelled by user."
                }
            }
            "4" {
                Clear-Host
                Write-Host ""
                Write-Host " ================= DEFENDER FOR SERVERS PRICING CONFIGURATION ================= "
                Write-Host ""
                Write-Host ""
                Write-Host " PRICING CONFIGURATION OVERVIEW:"
                Write-Host "   This post-deployment tool configures Azure Defender for Cloud pricing settings"
                Write-Host "   at the resource level for Virtual Machines, Virtual Machine Scale Sets,"
                Write-Host "   and Azure Arc-enabled machines."
                Write-Host ""
                Write-Host " SUPPORTED OPERATIONS:" -ForegroundColor Yellow
                Write-Host "    READ: View current pricing configuration"
                Write-Host "    FREE: Remove Defender protection (set to Free tier)"
                Write-Host "    STANDARD: Enable Defender for Cloud Plan 1 (P1)"
                Write-Host "    DELETE: Remove resource-level configuration (inherit from parent)"
                Write-Host ""
                Write-Host " TARGETING OPTIONS:" -ForegroundColor Yellow
                Write-Host "    Resource Group Mode: Target all resources within a specific resource group"
                Write-Host "    Tag-based Mode: Target resources with specific tag name and value"
                Write-Host ""
                Write-Host " RESOURCE TYPES SUPPORTED:" -ForegroundColor Yellow
                Write-Host "    Virtual Machines (Microsoft.Compute/virtualMachines)"
                Write-Host "    Virtual Machine Scale Sets (Microsoft.Compute/virtualMachineScaleSets)"
                Write-Host "    Azure Arc-enabled Machines (Microsoft.HybridCompute/machines)"
                Write-Host ""
                Write-Host " FEATURES:" -ForegroundColor Yellow
                Write-Host "    Interactive parameter selection with intelligent defaults"
                Write-Host "    Automatic Azure authentication with token management"
                Write-Host "    Comprehensive success/failure reporting with detailed statistics"
                Write-Host "    Professional table formatting for configuration display"
                Write-Host ""
                Write-Host "  DISCLAIMER `& LIABILITY:" -ForegroundColor Yellow
                Write-Host "    This function is provided 'AS IS' without warranty of any kind"
                Write-Host "    Always test in a non-production environment first"
                Write-Host "    Ensure you understand the implications of changing pricing configurations"
                Write-Host "    The author is not liable for any damages, data loss, or billing"
                Write-Host "     consequences that may result from using this function"
                Write-Host "    You assume full responsibility for validating configurations"
                Write-Host "     and understanding associated costs"
                Write-Host ""
                Write-Host ""
                $confirm = Read-Host "Do you want to proceed with Defender pricing configuration? [Y/N] (default: Y)"
                if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.ToUpper() -eq "Y") {
                    Write-Host "`n Running Set-AzureArcResourcePricing..."
                    try {
                        # Check if the function is available
                        if (-not (Get-Command Set-AzureArcResourcePricing -ErrorAction SilentlyContinue)) {
                            throw "Set-AzureArcResourcePricing function not found. Please ensure the ServerProtection module is properly imported."
                        }

                        Set-AzureArcResourcePricing
                        Write-Host "`n Defender pricing configuration completed successfully."
                    }
                    catch {
                        Write-Host "`n Error during pricing configuration. Please check your Azure setup." -ForegroundColor Red
                        Write-Host "Please check your Azure permissions and network connectivity."
                        Write-Host "Try running: Import-Module ServerProtection -Force"
                    }
                    Write-Host "`nPress any key to return to the main menu..."
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                } else {
                    Write-Host "`n Operation cancelled by user."
                }
            }
            "H" {
                $exitHelp = $false
                do {
                    Clear-Host
                    Write-Host ""
                    Write-Host " ==========================   DETAILED HELP SYSTEM   ========================== "
                    Write-Host ""
                    Write-Host ""
                    Write-Host " Available commands for detailed help:"
                    Write-Host "[1] Get-AzureArcPrerequisite" -ForegroundColor Green
                    Write-Host "[2] New-AzureArcDevice" -ForegroundColor Green
                    Write-Host "[3] Get-AzureArcDiagnostic" -ForegroundColor Green
                    Write-Host "[4] Set-AzureArcResourcePricing" -ForegroundColor Green
                    Write-Host "[Q] Return to main menu" -ForegroundColor Green
                    Write-Host ""

                    $helpSelection = Read-Host "Select a command number (1-4) for detailed help or 'Q' to return to main menu"

                    switch ($helpSelection.ToUpper()) {
                        "1" {
                            Clear-Host
                            Write-Host ""
                            Write-Host "                         Get-AzureArcPrerequisite Help                         "
                            Write-Host ""
                            Write-Host ""
                            Write-Host "SYNOPSIS" -ForegroundColor Yellow
                            Write-Host "    Tests Azure Arc prerequisites and automatically registers resource providers"
                            Write-Host ""
                            Write-Host "SYNTAX" -ForegroundColor Yellow
                            Write-Host "    Get-AzureArcPrerequisite [[-SubscriptionId] <String>] [[-DeviceListPath] <String>] [-Force]"
                            Write-Host "        [-NetworkTestMode <String>] [-IncludeOptionalEndpoints] [-TestTLSVersion]" -ForegroundColor Green
                            Write-Host "        [-ShowDetailedNetworkResults] [[-NetworkLogPath] <String>]"
                            Write-Host ""
                            Write-Host "DESCRIPTION" -ForegroundColor Yellow
                            Write-Host "    This enhanced function validates all prerequisites for Azure Arc deployment"
                            Write-Host "    including PowerShell version, Azure modules, execution policy, and network"
                            Write-Host "    connectivity. It also automatically registers required Azure resource providers."
                            Write-Host ""
                            Write-Host "KEY FEATURES" -ForegroundColor Yellow
                            Write-Host "     Comprehensive prerequisites validation"
                            Write-Host "     Automatic Azure resource provider registration"
                            Write-Host "     Network connectivity testing to Azure Arc endpoints"
                            Write-Host "     Multi-device support with detailed reporting"
                            Write-Host "     Enhanced security and system requirements validation"
                            Write-Host ""
                            Write-Host "EXAMPLES" -ForegroundColor Yellow
                            Write-Host "    Get-AzureArcPrerequisite"
                            Write-Host "    Get-AzureArcPrerequisite -Force -NetworkTestMode Comprehensive"
                            Write-Host ""
                            Write-Host "Press any key to return to help menu..."
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "2" {
                            Clear-Host
                            Write-Host ""
                            Write-Host "                            New-AzureArcDevice Help                             "
                            Write-Host ""
                            Write-Host ""
                            Write-Host "SYNOPSIS" -ForegroundColor Yellow
                            Write-Host "    Complete Azure Arc deployment including service principal creation, agent"
                            Write-Host "    installation, and Group Policy deployment"
                            Write-Host ""
                            Write-Host "SYNTAX" -ForegroundColor Yellow
                            Write-Host "    New-AzureArcDevice [[-ResourceGroupName] <String>] [[-Location] <String>]" -ForegroundColor Green
                            Write-Host "        [[-SharePath] <String>] [-Force]" -ForegroundColor Green
                            Write-Host ""
                            Write-Host "DESCRIPTION" -ForegroundColor Yellow
                            Write-Host "    This comprehensive function automates the complete Azure Arc deployment"
                            Write-Host "    process including service principal creation, agent installation, and"
                            Write-Host "    Group Policy configuration for enterprise-scale onboarding."
                            Write-Host ""
                            Write-Host "INTEGRATED FUNCTIONALITY" -ForegroundColor Yellow
                            Write-Host "     Service Principal Creation - Automatically creates service principals"
                            Write-Host "     Agent Installation - Downloads and optionally installs Azure Connected Machine Agent"
                            Write-Host "     Group Policy Configuration - Creates and deploys Group Policy objects"
                            Write-Host "     File share setup for Group Policy deployment"
                            Write-Host "     OU linking and configuration management"
                            Write-Host ""
                            Write-Host "EXAMPLES" -ForegroundColor Yellow
                            Write-Host "    New-AzureArcDevice"
                            Write-Host "    New-AzureArcDevice -ResourceGroupName 'rg-azurearc-prod' -Location 'eastus' -Force"
                            Write-Host ""
                            Write-Host "Press any key to return to help menu..."
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "3" {
                            Clear-Host
                            Write-Host ""
                            Write-Host "                         Get-AzureArcDiagnostic Help                            "
                            Write-Host ""
                            Write-Host ""
                            Write-Host "SYNOPSIS" -ForegroundColor Yellow
                            Write-Host "    Performs comprehensive Azure Arc agent diagnostics and collects detailed"
                            Write-Host "    logs for troubleshooting and support analysis"
                            Write-Host ""
                            Write-Host "SYNTAX" -ForegroundColor Yellow
                            Write-Host "    Get-AzureArcDiagnostic [[-LogPath] <String>] [-Force] [-Quiet]"
                            Write-Host ""
                            Write-Host "DESCRIPTION" -ForegroundColor Yellow
                            Write-Host "    This comprehensive diagnostic function systematically executes Azure Arc"
                            Write-Host "    agent commands to assess health, configuration, and operational status."
                            Write-Host "    Generates professional diagnostic reports suitable for Microsoft Support."
                            Write-Host ""
                            Write-Host "DIAGNOSTIC WORKFLOW"
                            Write-Host "     azcmagent show - Displays agent configuration and connection status"
                            Write-Host "     azcmagent check - Performs connectivity and health validation tests"
                            Write-Host "     azcmagent logs --full - Generates complete diagnostic log archive"
                            Write-Host ""
                            Write-Host "OUTPUT DELIVERABLES" -ForegroundColor Yellow
                            Write-Host "     Timestamped diagnostic log with detailed results and recommendations"
                            Write-Host "     Complete ZIP archive containing comprehensive Azure Arc diagnostic data"
                            Write-Host "     Professional troubleshooting report with remediation guidance"
                            Write-Host ""
                            Write-Host "EXAMPLES" -ForegroundColor Yellow
                            Write-Host "    Get-AzureArcDiagnostic"
                            Write-Host "    Get-AzureArcDiagnostic -LogPath 'C:\AzureArcDiagnostics' -Force"
                            Write-Host ""
                            Write-Host "Press any key to return to help menu..."
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "4" {
                            Clear-Host
                            Write-Host ""
                            Write-Host "                      Set-AzureArcResourcePricing Help                          "
                            Write-Host ""
                            Write-Host ""
                            Write-Host "SYNOPSIS" -ForegroundColor Yellow
                            Write-Host "    Configure Azure Defender for Cloud pricing at resource level for Virtual"
                            Write-Host "    Machines, Virtual Machine Scale Sets, and Azure Arc-enabled machines"
                            Write-Host ""
                            Write-Host "SYNTAX" -ForegroundColor Yellow
                            Write-Host "    Set-AzureArcResourcePricing [[-SubscriptionId] <String>]" -ForegroundColor Green
                            Write-Host "        [[-ResourceGroupName] <String>] [[-TagName] <String>]" -ForegroundColor Green
                            Write-Host "        [[-TagValue] <String>] [[-Mode] <String>] [[-Action] <String>]" -ForegroundColor Green
                            Write-Host ""
                            Write-Host "DESCRIPTION" -ForegroundColor Yellow
                            Write-Host "    This post-deployment function configures Azure Defender for Cloud pricing"
                            Write-Host "    settings at the resource level. Supports both Resource Group and Tag-based"
                            Write-Host "    resource targeting with comprehensive pricing operations."
                            Write-Host ""
                            Write-Host "SUPPORTED ACTIONS" -ForegroundColor Yellow
                            Write-Host "     READ - View current pricing configuration"
                            Write-Host "     FREE - Remove Defender protection (set to Free tier)"
                            Write-Host "     STANDARD - Enable Defender for Cloud Plan 1 (P1)"
                            Write-Host "     DELETE - Remove resource-level configuration (inherit from parent)"
                            Write-Host ""
                            Write-Host "TARGETING MODES" -ForegroundColor Yellow
                            Write-Host "     RG - Target all resources within a specific Resource Group"
                            Write-Host "     TAG - Target resources with specific tag name and value"
                            Write-Host ""
                            Write-Host "SUPPORTED RESOURCE TYPES"
                            Write-Host "     Virtual Machines (Microsoft.Compute/virtualMachines)"
                            Write-Host "     Virtual Machine Scale Sets (Microsoft.Compute/virtualMachineScaleSets)"
                            Write-Host "     Azure Arc-enabled Machines (Microsoft.HybridCompute/machines)"
                            Write-Host ""
                            Write-Host "EXAMPLES" -ForegroundColor Yellow
                            Write-Host "    Set-AzureArcResourcePricing"
                            Write-Host "    Set-AzureArcResourcePricing -Mode 'RG' -ResourceGroupName 'rg-prod' -Action 'standard'"
                            Write-Host "    Set-AzureArcResourcePricing -Mode 'TAG' -TagName 'Environment' -TagValue 'Production' -Action 'read'"
                            Write-Host ""
                            Write-Host "Press any key to return to help menu..."
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "Q" {
                            $exitHelp = $true
                        }
                        default {
                            Write-Host "Invalid selection. Please choose 1-4 or Q."
                        }
                    }
                } while (-not $exitHelp)
            }
            "Q" {
                Write-Host "`n Thank you for using the ServerProtection module!"
                Write-Host "Exiting...`n"
                return
            }
            default {
                Write-Host "`n Invalid selection. Please choose a valid option (1-3, H, or Q)."
            }
        }
    }

    # Main module loop
    do {
        Clear-Host
        Write-ModuleInterface

        $selection = Read-Host "Please select an option [1-4, H, Q]"

        Start-UserSelection -Selection $selection

        if ($selection.ToUpper() -eq "Q") {
            break
        }

    } while ($true)
}










