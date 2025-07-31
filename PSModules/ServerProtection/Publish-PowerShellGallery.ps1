# PowerShell Gallery Publishing Script
# This script helps prepare and publish the ServerProtection module to PowerShell Gallery

param(
    [Parameter(Mandatory = $false)]
    [string]$NuGetApiKey,
    
    [Parameter(Mandatory = $false)]
    [switch]$TestOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

# Module information
$ModuleName = "ServerProtection"
$ModulePath = $PSScriptRoot

Write-Host "PowerShell Gallery Publishing Script for $ModuleName" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# Check if module manifest exists
$ManifestPath = Join-Path $ModulePath "$ModuleName.psd1"
if (-not (Test-Path $ManifestPath)) {
    Write-Error "Module manifest not found at: $ManifestPath"
    exit 1
}

# Import and test the module
Write-Host "Testing module import..." -ForegroundColor Yellow
try {
    Import-Module $ManifestPath -Force
    $Module = Get-Module $ModuleName
    Write-Host "✓ Module imported successfully" -ForegroundColor Green
    Write-Host "  Version: $($Module.Version)" -ForegroundColor Gray
    Write-Host "  Functions: $($Module.ExportedFunctions.Count)" -ForegroundColor Gray
}
catch {
    Write-Error "Failed to import module: $_"
    exit 1
}

# Run PSScriptAnalyzer if available
Write-Host "`nRunning PSScriptAnalyzer..." -ForegroundColor Yellow
try {
    if (Get-Module -ListAvailable -Name PSScriptAnalyzer) {
        $AnalyzerResults = Invoke-ScriptAnalyzer -Path $ModulePath -Recurse
        if ($AnalyzerResults) {
            Write-Warning "PSScriptAnalyzer found issues:"
            $AnalyzerResults | Format-Table -AutoSize
            
            $Errors = $AnalyzerResults | Where-Object Severity -eq 'Error'
            if ($Errors) {
                Write-Error "Found $($Errors.Count) error(s). Please fix before publishing."
                exit 1
            }
        } else {
            Write-Host "✓ No PSScriptAnalyzer issues found" -ForegroundColor Green
        }
    } else {
        Write-Warning "PSScriptAnalyzer not installed. Install with: Install-Module PSScriptAnalyzer"
    }
}
catch {
    Write-Warning "PSScriptAnalyzer check failed: $_"
}

# Test module functions
Write-Host "`nTesting module functions..." -ForegroundColor Yellow
$ExpectedFunctions = @(
    'Start-ServerProtection',
    'Get-AzureArcPrerequisite', 
    'New-AzureArcDevice',
    'Get-AzureArcDiagnostic',
    'Set-AzureArcResourcePricing'
)

foreach ($Function in $ExpectedFunctions) {
    if (Get-Command $Function -ErrorAction SilentlyContinue) {
        Write-Host "✓ $Function" -ForegroundColor Green
    } else {
        Write-Error "✗ $Function not found"
        exit 1
    }
}

# Check for required files
Write-Host "`nChecking required files..." -ForegroundColor Yellow
$RequiredFiles = @(
    'README.md',
    'LICENSE',
    'CHANGELOG.md'
)

foreach ($File in $RequiredFiles) {
    $FilePath = Join-Path $ModulePath $File
    if (Test-Path $FilePath) {
        Write-Host "✓ $File" -ForegroundColor Green
    } else {
        Write-Warning "✗ $File not found (recommended for PowerShell Gallery)"
    }
}

if ($TestOnly) {
    Write-Host "`nTest completed successfully! Module is ready for publishing." -ForegroundColor Green
    exit 0
}

# Check PowerShell Gallery prerequisites
Write-Host "`nChecking PowerShell Gallery prerequisites..." -ForegroundColor Yellow

# Check if PowerShellGet is available
if (-not (Get-Module -ListAvailable -Name PowerShellGet)) {
    Write-Error "PowerShellGet module not found. Install with: Install-Module PowerShellGet -Force"
    exit 1
}

# Check if logged into PowerShell Gallery
try {
    $ApiKeyTest = Test-ScriptFileInfo -Path (Join-Path $env:TEMP "test.ps1") -ErrorAction SilentlyContinue
    Write-Host "✓ PowerShellGet is available" -ForegroundColor Green
}
catch {
    Write-Host "✓ PowerShellGet is available" -ForegroundColor Green
}

# Prepare for publishing
if (-not $WhatIf) {
    if (-not $NuGetApiKey) {
        Write-Host "`nTo publish to PowerShell Gallery, you need a NuGet API key." -ForegroundColor Yellow
        Write-Host "1. Go to https://www.powershellgallery.com/" -ForegroundColor White
        Write-Host "2. Sign in with your Microsoft account" -ForegroundColor White
        Write-Host "3. Go to 'API Keys' and create a new key" -ForegroundColor White
        Write-Host "4. Run this script again with -NuGetApiKey parameter" -ForegroundColor White
        Write-Host ""
        Write-Host "Example: .\Publish-PowerShellGallery.ps1 -NuGetApiKey 'your-api-key-here'" -ForegroundColor Gray
        exit 0
    }

    # Final confirmation
    Write-Host "`nReady to publish $ModuleName v$($Module.Version) to PowerShell Gallery!" -ForegroundColor Green
    $Confirmation = Read-Host "Do you want to proceed? (Y/N)"
    
    if ($Confirmation -notmatch '^[Yy]') {
        Write-Host "Publishing cancelled." -ForegroundColor Yellow
        exit 0
    }

    # Publish to PowerShell Gallery
    Write-Host "`nPublishing to PowerShell Gallery..." -ForegroundColor Yellow
    try {
        Publish-Module -Path $ModulePath -NuGetApiKey $NuGetApiKey -Verbose
        Write-Host "✓ Successfully published to PowerShell Gallery!" -ForegroundColor Green
        Write-Host "Module will be available at: https://www.powershellgallery.com/packages/$ModuleName" -ForegroundColor Cyan
    }
    catch {
        Write-Error "Failed to publish: $_"
        exit 1
    }
} else {
    Write-Host "`n[WHAT-IF] Would publish $ModuleName v$($Module.Version) to PowerShell Gallery" -ForegroundColor Cyan
}

Write-Host "`nPublishing process completed!" -ForegroundColor Green
