function Deploy-DefenderForServers {
    <#
    .SYNOPSIS
    Interactive module for Azure Arc and Microsoft Defender for Servers deployment.
    
    .DESCRIPTION
    This function provides an interactive interface for deploying and managing Azure Arc devices
    and Microsoft Defender for Servers across multiple systems in an enterprise environment.
    #>
    [CmdletBinding()]
    param()

    # Check if required functions are available
    $requiredFunctions = @(
        'Test-AzureArcPrerequisites',
        'Test-AzureConnectivity',
        'Test-AzureArcNetworkRequirements',
        'Register-AzureResourceProviders',
        'New-ArcServicePrincipal',
        'Install-AzureConnectedMachineAgent',
        'Deploy-ArcGroupPolicy',
        'New-AzureArcDevice',
        'Test-AzureArcDiagnostics'
    )

    $missingFunctions = @()
    foreach ($func in $requiredFunctions) {
        if (-not (Get-Command $func -ErrorAction SilentlyContinue)) {
            $missingFunctions += $func
        }
    }

    if ($missingFunctions.Count -gt 0) {
        Write-Warning "The following required functions are not available:"
        $missingFunctions | ForEach-Object { Write-Warning "  - $_" }
        Write-Warning "Please ensure the DefenderEndpointDeployment module is properly imported."
        Write-Host "`nTry running: Import-Module DefenderEndpointDeployment -Force" -ForegroundColor Yellow
        return
    }

    # Function to display the module interface
    function Show-ModuleInterface {
        Clear-Host
        
        # ASCII Art Header
        $asciiArt = @"
                ██████╗ ███████╗███████╗███████╗███╗   ██╗██████╗ ███████╗██████╗ 
                ██╔══██╗██╔════╝██╔════╝██╔════╝████╗  ██║██╔══██╗██╔════╝██╔══██╗
                ██║  ██║█████╗  █████╗  █████╗  ██╔██╗ ██║██║  ██║█████╗  ██████╔╝
                ██║  ██║██╔══╝  ██╔══╝  ██╔══╝  ██║╚██╗██║██║  ██║██╔══╝  ██╔══██╗
                ██████╔╝███████╗██║     ███████╗██║ ╚████║██████╔╝███████╗██║  ██║
                ╚═════╝ ╚══════╝╚═╝     ╚══════╝╚═╝  ╚═══╝╚═════╝ ╚══════╝╚═╝  ╚═╝
                                                                                    
                ███████╗███╗   ██╗██████╗ ██████╗  ██████╗ ██╗███╗   ██╗████████╗
                ██╔════╝████╗  ██║██╔══██╗██╔══██╗██╔═══██╗██║████╗  ██║╚══██╔══╝
                █████╗  ██╔██╗ ██║██║  ██║██████╔╝██║   ██║██║██╔██╗ ██║   ██║   
                ██╔══╝  ██║╚██╗██║██║  ██║██╔═══╝ ██║   ██║██║██║╚██╗██║   ██║   
                ███████╗██║ ╚████║██████╔╝██║     ╚██████╔╝██║██║ ╚████║   ██║   
                ╚══════╝╚═╝  ╚═══╝╚═════╝ ╚═╝      ╚═════╝ ╚═╝╚═╝  ╚═══╝   ╚═╝   
"@

        Write-Host $asciiArt -ForegroundColor Cyan
        # Write-Host ""

        # Complete Microsoft Defender for Servers Description
        # Write-Host "┌─────────────────────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Blue
        # Write-Host " 👨‍💻 AUTHOR: Lessi Coulibaly" -ForegroundColor Gray
        # Write-Host " 🏢 ORGANIZATION: Less-IT (AI and CyberSecurity)" -ForegroundColor Gray
        # Write-Host " 🌐 WEBSITE: https://lessit.net" -ForegroundColor Gray
        # Write-Host "└─────────────────────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Blue
        Write-Host ""
        Write-Host "📖 MODULE DESCRIPTION:" -ForegroundColor Green
        Write-Host "   This PowerShell module provides comprehensive tools for Azure Arc device deployment and" -ForegroundColor White
        Write-Host "   Microsoft Defender for Endpoint management. It enables enterprise-scale onboarding of devices" -ForegroundColor White
        Write-Host "   using Group Policy, automated prerequisites checking, and seamless integration with Azure Arc" -ForegroundColor White
        Write-Host "   and Microsoft Defender for Endpoint across multiple devices." -ForegroundColor White
        Write-Host ""
    }

    # Function to display the interactive menu
    function Show-InteractiveMenu {
        Write-Host "🛠️  AVAILABLE COMMANDS:" -ForegroundColor Yellow
        Write-Host "┌─────────────────────────────────────────┬─────────────────────────────────────────────────────┐"
        Write-Host "│ [1] Test-AzureArcPrerequisites          │ Validates Azure authentication and prerequisites    │"
        Write-Host "├─────────────────────────────────────────┼─────────────────────────────────────────────────────┤"
        Write-Host "│ [2] Test-AzureConnectivity              │ Tests connectivity to Azure endpoints               │"
        Write-Host "├─────────────────────────────────────────┼─────────────────────────────────────────────────────┤"
        Write-Host "│ [3] Test-AzureArcNetworkRequirements    │ Tests network requirements for Azure Arc            │"
        Write-Host "├─────────────────────────────────────────┼─────────────────────────────────────────────────────┤"
        Write-Host "│ [4] Register-AzureResourceProviders     │ Registers required Azure resource providers         │"
        Write-Host "├─────────────────────────────────────────┼─────────────────────────────────────────────────────┤"
        Write-Host "│ [5] New-ArcServicePrincipal             │ Creates service principals for Azure Arc            │"
        Write-Host "├─────────────────────────────────────────┼─────────────────────────────────────────────────────┤"
        Write-Host "│ [6] Install-AzureConnectedMachineAgent  │ Installs Azure Connected Machine Agent              │"
        Write-Host "├─────────────────────────────────────────┼─────────────────────────────────────────────────────┤"
        Write-Host "│ [7] Deploy-ArcGroupPolicy               │ Deploys Group Policy for Azure Arc deployment       │"
        Write-Host "├─────────────────────────────────────────┼─────────────────────────────────────────────────────┤"
        Write-Host "│ [8] New-AzureArcDevice                  │ Creates and configures Azure Arc-enabled devices    │"
        Write-Host "├─────────────────────────────────────────┼─────────────────────────────────────────────────────┤"
        Write-Host "│ [9] Test-AzureArcDiagnostics            │ Runs comprehensive Azure Arc diagnostics            │"
        Write-Host "├─────────────────────────────────────────┼─────────────────────────────────────────────────────┤"
        Write-Host "│ [H] Help for specific command           │ Get detailed help for any command                   │"
        Write-Host "├─────────────────────────────────────────┼─────────────────────────────────────────────────────┤"
        Write-Host "│ [Q] Quit                                │ Exit the module                                     │"
        Write-Host "└─────────────────────────────────────────┴─────────────────────────────────────────────────────┘"
        Write-Host ""
        Write-Host "💡 GETTING STARTED:" -ForegroundColor Magenta
        Write-Host "   • Start with option [1] to validate your environment" -ForegroundColor White
        Write-Host "   • Use option [8] for complete Azure Arc deployment" -ForegroundColor White
        Write-Host "   • Use option [9] for troubleshooting and diagnostics" -ForegroundColor White
        Write-Host "   • Type 'H' for detailed help on any command" -ForegroundColor White
        Write-Host ""
    }

    # Function to handle user selection
    function Invoke-UserSelection {
        param (
            [string]$Selection
        )
        
        switch ($Selection.ToUpper()) {
            "1" {
                Clear-Host
                Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
                Write-Host "║  ==================  AZURE ARC PREREQUISITES CHECKER ==================      ║" -ForegroundColor Cyan
                Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "🔍 SCRIPT OVERVIEW:" -ForegroundColor Yellow
                Write-Host "   This script will validate your Azure authentication status and check all" -ForegroundColor White
                Write-Host "   prerequisites required for Azure Arc deployment, including PowerShell" -ForegroundColor White
                Write-Host "   modules and permissions." -ForegroundColor White
                Write-Host ""
                Write-Host "📋 ACTIONS TO BE PERFORMED:" -ForegroundColor Yellow
                Write-Host "   • Check PowerShell version compatibility" -ForegroundColor White
                Write-Host "   • Validate Azure PowerShell modules availability" -ForegroundColor White
                Write-Host "   • Test Azure Arc Connected Machine Agent status" -ForegroundColor White
                Write-Host "   • Authenticate to Azure (browser-based login)" -ForegroundColor White
                Write-Host "   • Check Azure resource provider registrations" -ForegroundColor White
                Write-Host "   • Generate detailed prerequisite reports" -ForegroundColor White
                Write-Host ""
                Write-Host "⚠️  IMPORTANT CONSIDERATIONS:" -ForegroundColor Red
                Write-Host "   • Azure authentication will be required (browser-based login)" -ForegroundColor White
                Write-Host "   • Script may install Azure PowerShell module if missing" -ForegroundColor White
                Write-Host "   • Administrative privileges recommended for complete checks" -ForegroundColor White
                Write-Host "   • No modifications will be made to your system configuration" -ForegroundColor White
                Write-Host ""
                Write-Host "🛡️  DATA & PRIVACY:" -ForegroundColor Green
                Write-Host "   • All data processing occurs locally on your machine" -ForegroundColor White
                Write-Host "   • No data is transmitted to third parties" -ForegroundColor White
                Write-Host "   • Azure credentials are handled by official Microsoft modules" -ForegroundColor White
                Write-Host ""
                Write-Host "⚖️  DISCLAIMER & LIABILITY:" -ForegroundColor Magenta
                Write-Host "   • This script is provided 'AS IS' without warranty of any kind" -ForegroundColor White
                Write-Host "   • The author is not liable for any damages, data loss, or other" -ForegroundColor White
                Write-Host "     consequences that may result from running this script" -ForegroundColor White
                Write-Host "   • You assume full responsibility for testing and validating" -ForegroundColor White
                Write-Host "     this script in your environment before production use" -ForegroundColor White
                Write-Host ""
                Write-Host "═════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                $confirm = Read-Host "Do you consent to proceed with prerequisites check? [Y/N] (default: Y)"
                if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.ToUpper() -eq "Y") {
                    Write-Host "`n🔍 Running Test-AzureArcPrerequisites..." -ForegroundColor Green
                    try {
                        Test-AzureArcPrerequisites -Force
                        Write-Host "`n✅ Test-AzureArcPrerequisites completed successfully." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "`n❌ Error executing Test-AzureArcPrerequisites: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "Please ensure the module is properly imported and all dependencies are available." -ForegroundColor Yellow
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
                Write-Host "║  ==================  AZURE CONNECTIVITY TESTER ==================            ║" -ForegroundColor Cyan
                Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "🔍 SCRIPT OVERVIEW:" -ForegroundColor Yellow
                Write-Host "   This script will test network connectivity to required Azure endpoints" -ForegroundColor White
                Write-Host "   and verify that your system can communicate with Azure Arc services." -ForegroundColor White
                Write-Host ""
                Write-Host "📋 ACTIONS TO BE PERFORMED:" -ForegroundColor Yellow
                Write-Host "   • Test connectivity to Azure management endpoints" -ForegroundColor White
                Write-Host "   • Verify DNS resolution for Azure services" -ForegroundColor White
                Write-Host "   • Check network ports and protocols" -ForegroundColor White
                Write-Host "   • Validate firewall and proxy configurations" -ForegroundColor White
                Write-Host "   • Generate connectivity diagnostic reports" -ForegroundColor White
                Write-Host ""
                Write-Host "⚠️  IMPORTANT CONSIDERATIONS:" -ForegroundColor Red
                Write-Host "   • Network connectivity tests will be performed" -ForegroundColor White
                Write-Host "   • Internet access is required for Azure endpoints" -ForegroundColor White
                Write-Host "   • Firewall and proxy settings may affect results" -ForegroundColor White
                Write-Host "   • No modifications will be made to network configuration" -ForegroundColor White
                Write-Host ""
                Write-Host "🛡️  DATA & PRIVACY:" -ForegroundColor Green
                Write-Host "   • All connectivity tests occur from your local machine" -ForegroundColor White
                Write-Host "   • No sensitive data is transmitted during tests" -ForegroundColor White
                Write-Host "   • Test results are processed locally" -ForegroundColor White
                Write-Host ""
                Write-Host "⚖️  DISCLAIMER & LIABILITY:" -ForegroundColor Magenta
                Write-Host "   • This script is provided 'AS IS' without warranty of any kind" -ForegroundColor White
                Write-Host "   • The author is not liable for any network connectivity issues" -ForegroundColor White
                Write-Host "   • Use at your own discretion in your network environment" -ForegroundColor White
                Write-Host ""
                Write-Host "═════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                $confirm = Read-Host "Do you consent to proceed with connectivity testing? [Y/N] (default: Y)"
                if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.ToUpper() -eq "Y") {
                    Write-Host "`n🌐 Running Test-AzureConnectivity..." -ForegroundColor Green
                    try {
                        Test-AzureConnectivity
                        Write-Host "`n✅ Test-AzureConnectivity completed successfully." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "`n❌ Error executing Test-AzureConnectivity: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "Please ensure the module is properly imported and all dependencies are available." -ForegroundColor Yellow
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
                Write-Host "║  ==================  AZURE ARC NETWORK REQUIREMENTS ==================       ║" -ForegroundColor Cyan
                Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "🔍 SCRIPT OVERVIEW:" -ForegroundColor Yellow
                Write-Host "   This script will test specific network requirements for Azure Arc" -ForegroundColor White
                Write-Host "   including required endpoints, ports, and protocols for successful" -ForegroundColor White
                Write-Host "   connectivity and operation." -ForegroundColor White
                Write-Host ""
                Write-Host "📋 ACTIONS TO BE PERFORMED:" -ForegroundColor Yellow
                Write-Host "   • Test Azure Arc specific endpoints connectivity" -ForegroundColor White
                Write-Host "   • Verify required TCP/UDP ports accessibility" -ForegroundColor White
                Write-Host "   • Check TLS/SSL certificate validation" -ForegroundColor White
                Write-Host "   • Validate proxy and firewall configurations" -ForegroundColor White
                Write-Host "   • Test Microsoft services dependencies" -ForegroundColor White
                Write-Host "   • Generate network requirements compliance report" -ForegroundColor White
                Write-Host ""
                Write-Host "⚠️  IMPORTANT CONSIDERATIONS:" -ForegroundColor Red
                Write-Host "   • Comprehensive network testing will be performed" -ForegroundColor White
                Write-Host "   • Multiple Azure Arc endpoints will be tested" -ForegroundColor White
                Write-Host "   • Internet connectivity is required" -ForegroundColor White
                Write-Host "   • Corporate firewall/proxy may affect results" -ForegroundColor White
                Write-Host ""
                Write-Host "🛡️  DATA & PRIVACY:" -ForegroundColor Green
                Write-Host "   • Network tests are performed locally from your machine" -ForegroundColor White
                Write-Host "   • No sensitive information is transmitted" -ForegroundColor White
                Write-Host "   • Test results are processed and stored locally" -ForegroundColor White
                Write-Host ""
                Write-Host "⚖️  DISCLAIMER & LIABILITY:" -ForegroundColor Magenta
                Write-Host "   • This script is provided 'AS IS' without warranty of any kind" -ForegroundColor White
                Write-Host "   • Network requirements may change based on Azure updates" -ForegroundColor White
                Write-Host "   • Consult official Microsoft documentation for latest requirements" -ForegroundColor White
                Write-Host ""
                Write-Host "═════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                $confirm = Read-Host "Do you consent to proceed with network requirements testing? [Y/N] (default: Y)"
                if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.ToUpper() -eq "Y") {
                    Write-Host "`n🌐 Running Test-AzureArcNetworkRequirements..." -ForegroundColor Green
                    try {
                        Test-AzureArcNetworkRequirements
                        Write-Host "`n✅ Test-AzureArcNetworkRequirements completed successfully." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "`n❌ Error executing Test-AzureArcNetworkRequirements: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "Please ensure the module is properly imported and all dependencies are available." -ForegroundColor Yellow
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
                Write-Host "║  ==================  AZURE RESOURCE PROVIDERS REGISTRATION ==================  ║" -ForegroundColor Cyan
                Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "� SCRIPT OVERVIEW:" -ForegroundColor Yellow
                Write-Host "   This script will register the required Azure resource providers" -ForegroundColor White
                Write-Host "   in your subscription that are necessary for Azure Arc functionality" -ForegroundColor White
                Write-Host "   and Microsoft Defender integration." -ForegroundColor White
                Write-Host ""
                Write-Host "📋 ACTIONS TO BE PERFORMED:" -ForegroundColor Yellow
                Write-Host "   • Check current Azure resource provider registration status" -ForegroundColor White
                Write-Host "   • Register Microsoft.HybridCompute provider" -ForegroundColor White
                Write-Host "   • Register Microsoft.GuestConfiguration provider" -ForegroundColor White
                Write-Host "   • Register Microsoft.Security provider (for Defender)" -ForegroundColor White
                Write-Host "   • Validate registration completion and status" -ForegroundColor White
                Write-Host "   • Generate registration status report" -ForegroundColor White
                Write-Host ""
                Write-Host "⚠️  IMPORTANT CONSIDERATIONS:" -ForegroundColor Red
                Write-Host "   • Azure authentication will be required" -ForegroundColor White
                Write-Host "   • Contributor or Owner permissions needed on subscription" -ForegroundColor White
                Write-Host "   • Resource provider registration may take several minutes" -ForegroundColor White
                Write-Host "   • Changes will be made to your Azure subscription" -ForegroundColor White
                Write-Host ""
                Write-Host "🛡️  DATA & PRIVACY:" -ForegroundColor Green
                Write-Host "   • Authentication handled by official Microsoft Azure modules" -ForegroundColor White
                Write-Host "   • Only resource provider registrations are modified" -ForegroundColor White
                Write-Host "   • No user data or configurations are accessed" -ForegroundColor White
                Write-Host ""
                Write-Host "⚖️  DISCLAIMER & LIABILITY:" -ForegroundColor Magenta
                Write-Host "   • This script is provided 'AS IS' without warranty of any kind" -ForegroundColor White
                Write-Host "   • Ensure you have appropriate permissions before proceeding" -ForegroundColor White
                Write-Host "   • Resource provider changes affect your Azure subscription" -ForegroundColor White
                Write-Host ""
                Write-Host "═════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                $confirm = Read-Host "Do you consent to proceed with resource provider registration? [Y/N] (default: Y)"
                if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.ToUpper() -eq "Y") {
                    Write-Host "`n📋 Running Register-AzureResourceProviders..." -ForegroundColor Green
                    try {
                        Register-AzureResourceProviders
                        Write-Host "`n✅ Register-AzureResourceProviders completed successfully." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "`n❌ Error executing Register-AzureResourceProviders: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "Please ensure the module is properly imported and all dependencies are available." -ForegroundColor Yellow
                    }
                    Write-Host "`nPress any key to return to the main menu..." -ForegroundColor Yellow
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                } else {
                    Write-Host "`n❌ Operation cancelled by user." -ForegroundColor Yellow
                }
            }
            "5" {
                Clear-Host
                Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
                Write-Host "║   ==================  AZURE ARC SERVICE PRINCIPAL CREATOR ==================   ║" -ForegroundColor Cyan
                Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "� SCRIPT OVERVIEW:" -ForegroundColor Yellow
                Write-Host "   This script will create a new service principal in Azure Active Directory" -ForegroundColor White
                Write-Host "   with the necessary permissions for Azure Arc device onboarding and" -ForegroundColor White
                Write-Host "   automated deployment scenarios." -ForegroundColor White
                Write-Host ""
                Write-Host "📋 ACTIONS TO BE PERFORMED:" -ForegroundColor Yellow
                Write-Host "   • Create new Azure AD application registration" -ForegroundColor White
                Write-Host "   • Generate service principal with secure credentials" -ForegroundColor White
                Write-Host "   • Assign Azure Connected Machine Onboarding role" -ForegroundColor White
                Write-Host "   • Configure appropriate resource group permissions" -ForegroundColor White
                Write-Host "   • Generate service principal credentials for deployment" -ForegroundColor White
                Write-Host "   • Provide configuration details for future use" -ForegroundColor White
                Write-Host ""
                Write-Host "⚠️  IMPORTANT CONSIDERATIONS:" -ForegroundColor Red
                Write-Host "   • Azure AD administrative permissions required" -ForegroundColor White
                Write-Host "   • Service principal will have Azure resource permissions" -ForegroundColor White
                Write-Host "   • Generated credentials must be stored securely" -ForegroundColor White
                Write-Host "   • Changes will be made to your Azure AD tenant" -ForegroundColor White
                Write-Host ""
                Write-Host "🛡️  DATA & PRIVACY:" -ForegroundColor Green
                Write-Host "   • Service principal credentials are generated securely" -ForegroundColor White
                Write-Host "   • No personal data is collected or stored" -ForegroundColor White
                Write-Host "   • You control the service principal lifecycle" -ForegroundColor White
                Write-Host ""
                Write-Host "⚖️  DISCLAIMER & LIABILITY:" -ForegroundColor Magenta
                Write-Host "   • This script is provided 'AS IS' without warranty of any kind" -ForegroundColor White
                Write-Host "   • You are responsible for securing service principal credentials" -ForegroundColor White
                Write-Host "   • Follow your organization's security policies for service accounts" -ForegroundColor White
                Write-Host ""
                Write-Host "═════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                $confirm = Read-Host "Do you consent to proceed with service principal creation? [Y/N] (default: Y)"
                if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.ToUpper() -eq "Y") {
                    Write-Host "`n🔐 Running New-ArcServicePrincipal..." -ForegroundColor Green
                    try {
                        New-ArcServicePrincipal
                        Write-Host "`n✅ New-ArcServicePrincipal completed successfully." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "`n❌ Error executing New-ArcServicePrincipal: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "Please ensure the module is properly imported and all dependencies are available." -ForegroundColor Yellow
                    }
                    Write-Host "`nPress any key to return to the main menu..." -ForegroundColor Yellow
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                } else {
                    Write-Host "`n❌ Operation cancelled by user." -ForegroundColor Yellow
                }
            }
            "6" {
                Clear-Host
                Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
                Write-Host "║  ==================  AZURE CONNECTED MACHINE AGENT INSTALLER ================  ║" -ForegroundColor Cyan
                Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "🔍 SCRIPT OVERVIEW:" -ForegroundColor Yellow
                Write-Host "   This script will download and install the Azure Connected Machine Agent" -ForegroundColor White
                Write-Host "   on the current system, which is required for Azure Arc connectivity" -ForegroundColor White
                Write-Host "   and hybrid cloud management." -ForegroundColor White
                Write-Host ""
                Write-Host "📋 ACTIONS TO BE PERFORMED:" -ForegroundColor Yellow
                Write-Host "   • Download latest Azure Connected Machine Agent installer" -ForegroundColor White
                Write-Host "   • Verify installer authenticity and digital signatures" -ForegroundColor White
                Write-Host "   • Install agent with appropriate configurations" -ForegroundColor White
                Write-Host "   • Configure agent for Azure Arc connectivity" -ForegroundColor White
                Write-Host "   • Validate installation and service status" -ForegroundColor White
                Write-Host "   • Generate installation status report" -ForegroundColor White
                Write-Host ""
                Write-Host "⚠️  IMPORTANT CONSIDERATIONS:" -ForegroundColor Red
                Write-Host "   • Administrative privileges are required for installation" -ForegroundColor White
                Write-Host "   • Internet connectivity needed to download installer" -ForegroundColor White
                Write-Host "   • System will install Microsoft software components" -ForegroundColor White
                Write-Host "   • Windows services will be created and started" -ForegroundColor White
                Write-Host ""
                Write-Host "🛡️  DATA & PRIVACY:" -ForegroundColor Green
                Write-Host "   • Installer downloaded from official Microsoft sources" -ForegroundColor White
                Write-Host "   • Agent communicates only with Microsoft Azure services" -ForegroundColor White
                Write-Host "   • No personal data is collected during installation" -ForegroundColor White
                Write-Host ""
                Write-Host "⚖️  DISCLAIMER & LIABILITY:" -ForegroundColor Magenta
                Write-Host "   • This script is provided 'AS IS' without warranty of any kind" -ForegroundColor White
                Write-Host "   • Ensure you have appropriate permissions for software installation" -ForegroundColor White
                Write-Host "   • Test in non-production environment before deployment" -ForegroundColor White
                Write-Host ""
                Write-Host "═════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                $confirm = Read-Host "Do you consent to proceed with agent installation? [Y/N] (default: Y)"
                if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.ToUpper() -eq "Y") {
                    Write-Host "`n💾 Running Install-AzureConnectedMachineAgent..." -ForegroundColor Green
                    try {
                        Install-AzureConnectedMachineAgent
                        Write-Host "`n✅ Install-AzureConnectedMachineAgent completed successfully." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "`n❌ Error executing Install-AzureConnectedMachineAgent: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "Please ensure the module is properly imported and all dependencies are available." -ForegroundColor Yellow
                    }
                    Write-Host "`nPress any key to return to the main menu..." -ForegroundColor Yellow
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                } else {
                    Write-Host "`n❌ Operation cancelled by user." -ForegroundColor Yellow
                }
            }
            "7" {
                Clear-Host
                Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
                Write-Host "║    ==================  AZURE ARC GROUP POLICY DEPLOYMENT  ==================   ║" -ForegroundColor Cyan
                Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "🔍 SCRIPT OVERVIEW:" -ForegroundColor Yellow
                Write-Host "   This script will create and deploy Group Policy objects for automated" -ForegroundColor White
                Write-Host "   Azure Arc agent deployment across domain-joined machines in your" -ForegroundColor White
                Write-Host "   enterprise environment." -ForegroundColor White
                Write-Host ""
                Write-Host "📋 ACTIONS TO BE PERFORMED:" -ForegroundColor Yellow
                Write-Host "   • Create Group Policy Object (GPO) for Azure Arc deployment" -ForegroundColor White
                Write-Host "   • Configure startup scripts for agent installation" -ForegroundColor White
                Write-Host "   • Set registry keys for Azure Arc configuration" -ForegroundColor White
                Write-Host "   • Link GPO to specified Organizational Units (OUs)" -ForegroundColor White
                Write-Host "   • Configure automatic service principal authentication" -ForegroundColor White
                Write-Host "   • Generate deployment status reports" -ForegroundColor White
                Write-Host ""
                Write-Host "⚠️  IMPORTANT CONSIDERATIONS:" -ForegroundColor Red
                Write-Host "   • Domain Administrator privileges required" -ForegroundColor White
                Write-Host "   • Group Policy changes will affect domain-joined machines" -ForegroundColor White
                Write-Host "   • Service principal credentials must be available" -ForegroundColor White
                Write-Host "   • Changes will be deployed to Active Directory" -ForegroundColor White
                Write-Host ""
                Write-Host "🛡️  DATA & PRIVACY:" -ForegroundColor Green
                Write-Host "   • Group Policy configurations stored in Active Directory" -ForegroundColor White
                Write-Host "   • Service principal credentials handled securely" -ForegroundColor White
                Write-Host "   • No personal user data is collected" -ForegroundColor White
                Write-Host ""
                Write-Host "⚖️  DISCLAIMER & LIABILITY:" -ForegroundColor Magenta
                Write-Host "   • This script is provided 'AS IS' without warranty of any kind" -ForegroundColor White
                Write-Host "   • Test Group Policy changes in non-production environment first" -ForegroundColor White
                Write-Host "   • Follow your organization's change management procedures" -ForegroundColor White
                Write-Host ""
                Write-Host "═════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                $confirm = Read-Host "Do you consent to proceed with Group Policy deployment? [Y/N] (default: Y)"
                if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.ToUpper() -eq "Y") {
                    Write-Host "`n📄 Running Deploy-ArcGroupPolicy..." -ForegroundColor Green
                    try {
                        Deploy-ArcGroupPolicy
                        Write-Host "`n✅ Deploy-ArcGroupPolicy completed successfully." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "`n❌ Error executing Deploy-ArcGroupPolicy: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "Please ensure the module is properly imported and all dependencies are available." -ForegroundColor Yellow
                    }
                    Write-Host "`nPress any key to return to the main menu..." -ForegroundColor Yellow
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                } else {
                    Write-Host "`n❌ Operation cancelled by user." -ForegroundColor Yellow
                }
            }
            "8" {
                Clear-Host
                Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
                Write-Host "║  ======================  AZURE ARC DEVICE ONBOARDING  ======================   ║" -ForegroundColor Cyan
                Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "🔍 SCRIPT OVERVIEW:" -ForegroundColor Yellow
                Write-Host "   This script will perform a complete Azure Arc device onboarding process," -ForegroundColor White
                Write-Host "   including agent installation, device registration, and policy configuration" -ForegroundColor White
                Write-Host "   for comprehensive hybrid cloud management." -ForegroundColor White
                Write-Host ""
                Write-Host "📋 ACTIONS TO BE PERFORMED:" -ForegroundColor Yellow
                Write-Host "   • Install Azure Connected Machine Agent if not present" -ForegroundColor White
                Write-Host "   • Register device with Azure Arc service" -ForegroundColor White
                Write-Host "   • Configure device identity and authentication" -ForegroundColor White
                Write-Host "   • Apply Azure policies and compliance settings" -ForegroundColor White
                Write-Host "   • Enable monitoring and management capabilities" -ForegroundColor White
                Write-Host "   • Validate successful onboarding and connectivity" -ForegroundColor White
                Write-Host ""
                Write-Host "⚠️  IMPORTANT CONSIDERATIONS:" -ForegroundColor Red
                Write-Host "   • Administrative privileges required on local machine" -ForegroundColor White
                Write-Host "   • Azure authentication and subscription access needed" -ForegroundColor White
                Write-Host "   • Device will be registered in your Azure subscription" -ForegroundColor White
                Write-Host "   • Azure policies may be automatically applied" -ForegroundColor White
                Write-Host ""
                Write-Host "🛡️  DATA & PRIVACY:" -ForegroundColor Green
                Write-Host "   • Device metadata will be sent to Azure for management" -ForegroundColor White
                Write-Host "   • Communication secured with TLS/SSL encryption" -ForegroundColor White
                Write-Host "   • Data handled according to Microsoft privacy policies" -ForegroundColor White
                Write-Host ""
                Write-Host "⚖️  DISCLAIMER & LIABILITY:" -ForegroundColor Magenta
                Write-Host "   • This script is provided 'AS IS' without warranty of any kind" -ForegroundColor White
                Write-Host "   • Device will be managed by Azure Arc after onboarding" -ForegroundColor White
                Write-Host "   • Ensure compliance with your organization's policies" -ForegroundColor White
                Write-Host ""
                Write-Host "═════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                $confirm = Read-Host "Do you consent to proceed with Azure Arc device onboarding? [Y/N] (default: Y)"
                if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.ToUpper() -eq "Y") {
                    Write-Host "`n🚀 Running New-AzureArcDevice..." -ForegroundColor Green
                    try {
                        New-AzureArcDevice -Force
                        Write-Host "`n✅ New-AzureArcDevice completed successfully." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "`n❌ Error executing New-AzureArcDevice: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "Please ensure the module is properly imported and all dependencies are available." -ForegroundColor Yellow
                    }
                    Write-Host "`nPress any key to return to the main menu..." -ForegroundColor Yellow
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                } else {
                    Write-Host "`n❌ Operation cancelled by user." -ForegroundColor Yellow
                }
            }
            "9" {
                Clear-Host
                Write-Host "╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
                Write-Host "║  ===================  AZURE ARC DIAGNOSTICS & LOG COLLECTION ================  ║" -ForegroundColor Cyan
                Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "🔍 SCRIPT OVERVIEW:" -ForegroundColor Yellow
                Write-Host "   This script will run comprehensive Azure Arc diagnostics and collect logs" -ForegroundColor White
                Write-Host "   to help troubleshoot connectivity and configuration issues. Perfect for" -ForegroundColor White
                Write-Host "   support scenarios and system health analysis." -ForegroundColor White
                Write-Host ""
                Write-Host "📋 ACTIONS TO BE PERFORMED:" -ForegroundColor Yellow
                Write-Host "   • Test connectivity to Azure Arc endpoints" -ForegroundColor White
                Write-Host "   • Validate Azure Arc agent installation and status" -ForegroundColor White
                Write-Host "   • Collect comprehensive system and agent logs" -ForegroundColor White
                Write-Host "   • List installed extensions and their configurations" -ForegroundColor White
                Write-Host "   • Create detailed diagnostic reports" -ForegroundColor White
                Write-Host "   • Generate ZIP archives for Microsoft support" -ForegroundColor White
                Write-Host ""
                Write-Host "⚠️  IMPORTANT CONSIDERATIONS:" -ForegroundColor Red
                Write-Host "   • Azure Connected Machine Agent (azcmagent) must be installed" -ForegroundColor White
                Write-Host "   • Administrative privileges recommended for complete diagnostics" -ForegroundColor White
                Write-Host "   • Network connectivity to Azure endpoints will be tested" -ForegroundColor White
                Write-Host "   • Log files will be created in your specified directory" -ForegroundColor White
                Write-Host ""
                Write-Host "🛡️  DATA & PRIVACY:" -ForegroundColor Green
                Write-Host "   • All data processing occurs locally on your machine" -ForegroundColor White
                Write-Host "   • No data is transmitted to third parties" -ForegroundColor White
                Write-Host "   • Generated logs may contain system configuration information" -ForegroundColor White
                Write-Host "   • You control where log files are stored and can review before sharing" -ForegroundColor White
                Write-Host ""
                Write-Host "⚖️  DISCLAIMER & LIABILITY:" -ForegroundColor Magenta
                Write-Host "   • This script is provided 'AS IS' without warranty of any kind" -ForegroundColor White
                Write-Host "   • Review generated logs before sharing with support" -ForegroundColor White
                Write-Host "   • No modifications will be made to your system configuration" -ForegroundColor White
                Write-Host ""
                Write-Host "═════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                $confirm = Read-Host "Do you consent to proceed with Azure Arc diagnostics? [Y/N] (default: Y)"
                if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.ToUpper() -eq "Y") {
                    Write-Host "`n🔍 Running Test-AzureArcDiagnostics..." -ForegroundColor Green
                    try {
                        Test-AzureArcDiagnostics -SkipPrompt
                        Write-Host "`n✅ Test-AzureArcDiagnostics completed successfully." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "`n❌ Error executing Test-AzureArcDiagnostics: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "Please ensure the module is properly imported and all dependencies are available." -ForegroundColor Yellow
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
                    Write-Host "`nAvailable commands for detailed help:" -ForegroundColor Yellow
                    Write-Host "[1] Test-AzureArcPrerequisites" -ForegroundColor White
                    Write-Host "[2] Test-AzureConnectivity" -ForegroundColor White
                    Write-Host "[3] Test-AzureArcNetworkRequirements" -ForegroundColor White
                    Write-Host "[4] Register-AzureResourceProviders" -ForegroundColor White
                    Write-Host "[5] New-ArcServicePrincipal" -ForegroundColor White
                    Write-Host "[6] Install-AzureConnectedMachineAgent" -ForegroundColor White
                    Write-Host "[7] Deploy-ArcGroupPolicy" -ForegroundColor White
                    Write-Host "[8] New-AzureArcDevice" -ForegroundColor White
                    Write-Host "[9] Test-AzureArcDiagnostics" -ForegroundColor White
                    Write-Host "[Q] Return to main menu" -ForegroundColor White
                    Write-Host ""
                    
                    $helpSelection = Read-Host "Select a command number (1-9) for detailed help or 'Q' to return to main menu"
                    
                    switch ($helpSelection.ToUpper()) {
                        "1" {
                            Write-Host "`n📖 Displaying detailed help for Test-AzureArcPrerequisites..." -ForegroundColor Green
                            Write-Host ""
                            Write-Host "SYNOPSIS" -ForegroundColor Yellow
                            Write-Host "    Checks prerequisites for Azure Arc onboarding and Microsoft Defender for Endpoint integration." -ForegroundColor White
                            Write-Host ""
                            Write-Host "DESCRIPTION" -ForegroundColor Yellow
                            Write-Host "    This function performs comprehensive prerequisites validation for Azure Arc onboarding" -ForegroundColor White
                            Write-Host "    and Microsoft Defender for Endpoint integration across multiple devices." -ForegroundColor White
                            Write-Host ""
                            Write-Host "SYNTAX" -ForegroundColor Yellow
                            Write-Host "    Test-AzureArcPrerequisites [[-DeviceListPath] <String>] [-Force]" -ForegroundColor White
                            Write-Host ""
                            Write-Host "PARAMETERS" -ForegroundColor Yellow
                            Write-Host "    -DeviceListPath <String>" -ForegroundColor White
                            Write-Host "        Path to a file containing device names (one per line)." -ForegroundColor Gray
                            Write-Host ""
                            Write-Host "    -Force [<SwitchParameter>]" -ForegroundColor White
                            Write-Host "        Skip user consent prompts and proceed with checks." -ForegroundColor Gray
                            Write-Host ""
                            Write-Host "EXAMPLES" -ForegroundColor Yellow
                            Write-Host "    Example 1: Interactive prerequisites check" -ForegroundColor White
                            Write-Host "    Test-AzureArcPrerequisites" -ForegroundColor Gray
                            Write-Host ""
                            Write-Host "    Example 2: Check specific devices" -ForegroundColor White
                            Write-Host "    Test-AzureArcPrerequisites -DeviceListPath 'C:\devices.txt'" -ForegroundColor Gray
                            Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "2" {
                            Write-Host "`n📖 Displaying detailed help for Test-AzureConnectivity..." -ForegroundColor Green
                            Write-Host ""
                            Write-Host "SYNOPSIS" -ForegroundColor Yellow
                            Write-Host "    Tests network connectivity to required Azure endpoints." -ForegroundColor White
                            Write-Host ""
                            Write-Host "DESCRIPTION" -ForegroundColor Yellow
                            Write-Host "    This function tests connectivity to Azure management endpoints and validates" -ForegroundColor White
                            Write-Host "    that your system can communicate with Azure Arc services." -ForegroundColor White
                            Write-Host ""
                            Write-Host "SYNTAX" -ForegroundColor Yellow
                            Write-Host "    Test-AzureConnectivity [[-ComputerName] <String>]" -ForegroundColor White
                            Write-Host ""
                            Write-Host "PARAMETERS" -ForegroundColor Yellow
                            Write-Host "    -ComputerName <String>" -ForegroundColor White
                            Write-Host "        Name of the computer to test connectivity from (default: localhost)." -ForegroundColor Gray
                            Write-Host ""
                            Write-Host "EXAMPLES" -ForegroundColor Yellow
                            Write-Host "    Example 1: Test local connectivity" -ForegroundColor White
                            Write-Host "    Test-AzureConnectivity" -ForegroundColor Gray
                            Write-Host ""
                            Write-Host "    Example 2: Test remote computer connectivity" -ForegroundColor White
                            Write-Host "    Test-AzureConnectivity -ComputerName 'SERVER01'" -ForegroundColor Gray
                            Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "3" {
                            Write-Host "`n📖 Displaying detailed help for Test-AzureArcNetworkRequirements..." -ForegroundColor Green
                            Write-Host ""
                            Write-Host "SYNOPSIS" -ForegroundColor Yellow
                            Write-Host "    Tests specific network requirements for Azure Arc connectivity." -ForegroundColor White
                            Write-Host ""
                            Write-Host "DESCRIPTION" -ForegroundColor Yellow
                            Write-Host "    This function validates network requirements for Azure Arc including" -ForegroundColor White
                            Write-Host "    required endpoints, ports, and protocols for successful operation." -ForegroundColor White
                            Write-Host ""
                            Write-Host "SYNTAX" -ForegroundColor Yellow
                            Write-Host "    Test-AzureArcNetworkRequirements [[-ComputerName] <String>] [[-Timeout] <Int32>] [[-LogPath] <String>]" -ForegroundColor White
                            Write-Host ""
                            Write-Host "PARAMETERS" -ForegroundColor Yellow
                            Write-Host "    -ComputerName <String>" -ForegroundColor White
                            Write-Host "        Name of the computer to test (default: localhost)." -ForegroundColor Gray
                            Write-Host ""
                            Write-Host "    -Timeout <Int32>" -ForegroundColor White
                            Write-Host "        Timeout in seconds for connectivity tests (default: 30)." -ForegroundColor Gray
                            Write-Host ""
                            Write-Host "EXAMPLES" -ForegroundColor Yellow
                            Write-Host "    Example 1: Test local network requirements" -ForegroundColor White
                            Write-Host "    Test-AzureArcNetworkRequirements" -ForegroundColor Gray
                            Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "4" {
                            Write-Host "`n📖 Displaying detailed help for Register-AzureResourceProviders..." -ForegroundColor Green
                            Write-Host ""
                            Write-Host "SYNOPSIS" -ForegroundColor Yellow
                            Write-Host "    Registers required Azure resource providers for Azure Arc functionality." -ForegroundColor White
                            Write-Host ""
                            Write-Host "DESCRIPTION" -ForegroundColor Yellow
                            Write-Host "    This function registers the required Azure resource providers in your" -ForegroundColor White
                            Write-Host "    subscription that are necessary for Azure Arc and Microsoft Defender integration." -ForegroundColor White
                            Write-Host ""
                            Write-Host "SYNTAX" -ForegroundColor Yellow
                            Write-Host "    Register-AzureResourceProviders [[-ProviderNamespaces] <String[]>]" -ForegroundColor White
                            Write-Host ""
                            Write-Host "PARAMETERS" -ForegroundColor Yellow
                            Write-Host "    -ProviderNamespaces <String[]>" -ForegroundColor White
                            Write-Host "        Array of resource provider namespaces to register." -ForegroundColor Gray
                            Write-Host ""
                            Write-Host "EXAMPLES" -ForegroundColor Yellow
                            Write-Host "    Example 1: Register default providers" -ForegroundColor White
                            Write-Host "    Register-AzureResourceProviders" -ForegroundColor Gray
                            Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "5" {
                            Write-Host "`n📖 Displaying detailed help for New-ArcServicePrincipal..." -ForegroundColor Green
                            Write-Host ""
                            Write-Host "SYNOPSIS" -ForegroundColor Yellow
                            Write-Host "    Creates a new service principal for Azure Arc device onboarding." -ForegroundColor White
                            Write-Host ""
                            Write-Host "DESCRIPTION" -ForegroundColor Yellow
                            Write-Host "    This function creates a new service principal in Azure Active Directory" -ForegroundColor White
                            Write-Host "    with the necessary permissions for Azure Arc device onboarding." -ForegroundColor White
                            Write-Host ""
                            Write-Host "SYNTAX" -ForegroundColor Yellow
                            Write-Host "    New-ArcServicePrincipal [parameters]" -ForegroundColor White
                            Write-Host ""
                            Write-Host "EXAMPLES" -ForegroundColor Yellow
                            Write-Host "    Example 1: Create service principal interactively" -ForegroundColor White
                            Write-Host "    New-ArcServicePrincipal" -ForegroundColor Gray
                            Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "6" {
                            Write-Host "`n📖 Displaying detailed help for Install-AzureConnectedMachineAgent..." -ForegroundColor Green
                            Write-Host ""
                            Write-Host "SYNOPSIS" -ForegroundColor Yellow
                            Write-Host "    Downloads and installs the Azure Connected Machine Agent." -ForegroundColor White
                            Write-Host ""
                            Write-Host "DESCRIPTION" -ForegroundColor Yellow
                            Write-Host "    This function downloads and installs the Azure Connected Machine Agent" -ForegroundColor White
                            Write-Host "    on the current system, which is required for Azure Arc connectivity." -ForegroundColor White
                            Write-Host ""
                            Write-Host "SYNTAX" -ForegroundColor Yellow
                            Write-Host "    Install-AzureConnectedMachineAgent [parameters]" -ForegroundColor White
                            Write-Host ""
                            Write-Host "EXAMPLES" -ForegroundColor Yellow
                            Write-Host "    Example 1: Install agent with default settings" -ForegroundColor White
                            Write-Host "    Install-AzureConnectedMachineAgent" -ForegroundColor Gray
                            Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "7" {
                            Write-Host "`n📖 Displaying detailed help for Deploy-ArcGroupPolicy..." -ForegroundColor Green
                            Write-Host ""
                            Write-Host "SYNOPSIS" -ForegroundColor Yellow
                            Write-Host "    Creates and deploys Group Policy objects for automated Azure Arc deployment." -ForegroundColor White
                            Write-Host ""
                            Write-Host "DESCRIPTION" -ForegroundColor Yellow
                            Write-Host "    This function creates and deploys Group Policy objects for automated" -ForegroundColor White
                            Write-Host "    Azure Arc agent deployment across domain-joined machines." -ForegroundColor White
                            Write-Host ""
                            Write-Host "SYNTAX" -ForegroundColor Yellow
                            Write-Host "    Deploy-ArcGroupPolicy [parameters]" -ForegroundColor White
                            Write-Host ""
                            Write-Host "EXAMPLES" -ForegroundColor Yellow
                            Write-Host "    Example 1: Deploy Group Policy interactively" -ForegroundColor White
                            Write-Host "    Deploy-ArcGroupPolicy" -ForegroundColor Gray
                            Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "8" {
                            Write-Host "`n📖 Displaying detailed help for New-AzureArcDevice..." -ForegroundColor Green
                            Write-Host ""
                            Write-Host "SYNOPSIS" -ForegroundColor Yellow
                            Write-Host "    Performs complete Azure Arc device onboarding process." -ForegroundColor White
                            Write-Host ""
                            Write-Host "DESCRIPTION" -ForegroundColor Yellow
                            Write-Host "    This function performs a complete Azure Arc device onboarding process," -ForegroundColor White
                            Write-Host "    including agent installation, device registration, and policy configuration." -ForegroundColor White
                            Write-Host ""
                            Write-Host "SYNTAX" -ForegroundColor Yellow
                            Write-Host "    New-AzureArcDevice [[-ResourceGroupName] <String>] [[-Location] <String>] [[-SharePath] <String>] [-Force]" -ForegroundColor White
                            Write-Host ""
                            Write-Host "PARAMETERS" -ForegroundColor Yellow
                            Write-Host "    -ResourceGroupName <String>" -ForegroundColor White
                            Write-Host "        Name of the Azure resource group." -ForegroundColor Gray
                            Write-Host ""
                            Write-Host "    -Force [<SwitchParameter>]" -ForegroundColor White
                            Write-Host "        Skip user consent prompts and proceed with deployment." -ForegroundColor Gray
                            Write-Host ""
                            Write-Host "EXAMPLES" -ForegroundColor Yellow
                            Write-Host "    Example 1: Interactive device onboarding" -ForegroundColor White
                            Write-Host "    New-AzureArcDevice" -ForegroundColor Gray
                            Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "9" {
                            Write-Host "`n📖 Displaying detailed help for Test-AzureArcDiagnostics..." -ForegroundColor Green
                            Write-Host ""
                            Write-Host "SYNOPSIS" -ForegroundColor Yellow
                            Write-Host "    Runs comprehensive Azure Arc diagnostics and collects system information." -ForegroundColor White
                            Write-Host ""
                            Write-Host "DESCRIPTION" -ForegroundColor Yellow
                            Write-Host "    This function performs detailed diagnostics on Azure Arc connectivity and" -ForegroundColor White
                            Write-Host "    configuration. It collects logs, system information, and connectivity data" -ForegroundColor White
                            Write-Host "    to help troubleshoot Azure Arc deployment and operation issues." -ForegroundColor White
                            Write-Host ""
                            Write-Host "SYNTAX" -ForegroundColor Yellow
                            Write-Host "    Test-AzureArcDiagnostics [[-LogPath] <String>] [[-Location] <String>] [-Silent] [-SkipPrompt] [-Force]" -ForegroundColor White
                            Write-Host ""
                            Write-Host "PARAMETERS" -ForegroundColor Yellow
                            Write-Host "    -LogPath <String>" -ForegroundColor White
                            Write-Host "        Specifies the path where diagnostic logs will be saved." -ForegroundColor Gray
                            Write-Host ""
                            Write-Host "    -Location <String>" -ForegroundColor White
                            Write-Host "        Specifies the Azure region for diagnostics." -ForegroundColor Gray
                            Write-Host ""
                            Write-Host "    -Silent [<SwitchParameter>]" -ForegroundColor White
                            Write-Host "        Runs diagnostics without user interaction." -ForegroundColor Gray
                            Write-Host ""
                            Write-Host "EXAMPLES" -ForegroundColor Yellow
                            Write-Host "    Example 1: Run basic diagnostics" -ForegroundColor White
                            Write-Host "    Test-AzureArcDiagnostics" -ForegroundColor Gray
                            Write-Host "    Runs comprehensive Azure Arc diagnostics with default settings." -ForegroundColor Gray
                            Write-Host ""
                            Write-Host "    Example 2: Run diagnostics with custom settings" -ForegroundColor White
                            Write-Host "    Test-AzureArcDiagnostics -LogPath 'C:\ArcDiagnostics' -Location 'westus2' -Silent" -ForegroundColor Gray
                            Write-Host "    Runs silently with specified log path and Azure region." -ForegroundColor Gray
                            Write-Host ""
                            Write-Host "NOTES" -ForegroundColor Yellow
                            Write-Host "    - Requires Azure Connected Machine Agent (azcmagent) installed" -ForegroundColor White
                            Write-Host "    - Administrative privileges recommended for complete diagnostics" -ForegroundColor White
                            Write-Host "    - Creates comprehensive ZIP archives for Microsoft support" -ForegroundColor White
                            Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
                            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                        "Q" {
                            # Return to main menu (break out of help loop)
                            $exitHelp = $true
                        }
                        default {
                            Write-Host "`n❌ Invalid selection. Please choose a valid option (1-9 or Q)." -ForegroundColor Red
                        }
                    }
                } while ($helpSelection.ToUpper() -ne "Q" -and -not $exitHelp)
            }
            "Q" {
                Write-Host "`n👋 Thank you for using Microsoft Defender for Servers deployment module!`n" -ForegroundColor Green
                return $false
            }
            default {
                Write-Host "`n❌ Invalid selection. Please choose a valid option (1-9, H, or Q)." -ForegroundColor Red
            }
        }
        
        if ($Selection.ToUpper() -ne "Q") {
            return $true
        }
        
        return $false
    }

    # Main execution loop
    do {
        Show-ModuleInterface
        Show-InteractiveMenu
        
        $selection = Read-Host "Please select an option [1-9, H, Q]"
        $continue = Invoke-UserSelection -Selection $selection
        
    } while ($continue)
}
