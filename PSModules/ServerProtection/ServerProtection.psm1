#Requires -Version 5.1

<#
.SYNOPSIS
    ServerProtection PowerShell Module

.DESCRIPTION
    This module provides comprehensive tools for server protection through Azure Arc device
    deployment and Microsoft Defender for Servers (DFS) management. Microsoft Defender for
    Servers is a cloud-native security solution that provides advanced threat protection,
    vulnerability assessment, and security monitoring for server workloads in Microsoft
    Defender for Cloud. It includes functions for prerequisites checking, Azure Arc
    deployment, and seamless integration with Defender for Servers across multiple devices,
    enabling advanced threat detection, behavioral analytics, and security recommendations.

.AUTHOR
    Lessi Coulibaly

.ORGANIZATION
    Less-IT (AI and CyberSecurity)

.WEBSITE
    https://lessit.net

.VERSION
    1.0.0
#>

# Get the path to the module
$ModulePath = $PSScriptRoot

# Import private functions
Get-ChildItem -Path "$ModulePath\Private\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        . $_.FullName
        Write-Verbose "Imported private function: $($_.BaseName)"
    }
    catch {
        Write-Error "Failed to import private function $($_.BaseName): $($_.Exception.Message)"
    }
}

# Import public functions
Get-ChildItem -Path "$ModulePath\Public\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        . $_.FullName
        Write-Verbose "Imported public function: $($_.BaseName)"
    }
    catch {
        Write-Error "Failed to import public function $($_.BaseName): $($_.Exception.Message)"
    }
}

# Export public functions
$PublicFunctions = Get-ChildItem -Path "$ModulePath\Public\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    $_.BaseName
}

if ($PublicFunctions) {
    Export-ModuleMember -Function $PublicFunctions
}

# Module initialization
Write-Verbose "ServerProtection module loaded successfully"
Write-Verbose "Author: Lessi Coulibaly | Organization: Less-IT | Website: https://lessit.net"
