function Register-AzureResourceProviders {
    <#
    .SYNOPSIS
        Registers Azure Resource Providers required for Azure Arc.

    .DESCRIPTION
        This function registers the necessary Azure Resource Providers for Azure Arc functionality.
        It requires an active Azure session and appropriate permissions.

    .PARAMETER ProviderNamespaces
        Array of resource provider namespaces to register. If not specified, defaults to Azure Arc required providers.

    .EXAMPLE
        Register-AzureResourceProviders
        
        Registers all required Azure Arc resource providers.

    .EXAMPLE
        Register-AzureResourceProviders -ProviderNamespaces @("Microsoft.HybridCompute", "Microsoft.GuestConfiguration")
        
        Registers only the specified resource providers.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$ProviderNamespaces = @(
            "Microsoft.HybridCompute",
            "Microsoft.GuestConfiguration",
            "Microsoft.AzureArcData",
            "Microsoft.HybridConnectivity"
        )
    )

    Write-Host "🔧 Azure Resource Provider Registration" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────" -ForegroundColor Cyan

    # Ensure Azure authentication
    $authSuccess = Confirm-AzureAuthentication
    if (-not $authSuccess) {
        Write-Host "❌ Azure authentication required for resource provider registration" -ForegroundColor Red
        return $false
    }

    $results = @()
    
    foreach ($provider in $ProviderNamespaces) {
        Write-Host "🔄 Registering $provider..." -ForegroundColor Yellow
        
        try {
            # Check current status
            $resourceProvider = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop
            $currentStatus = $resourceProvider.RegistrationState
            
            if ($currentStatus -eq "Registered") {
                Write-Host "  ✅ $provider : Already registered" -ForegroundColor Green
                $results += [PSCustomObject]@{
                    Provider = $provider
                    Status = "Already Registered"
                    Success = $true
                }
                continue
            }

            # Register the provider
            Register-AzResourceProvider -ProviderNamespace $provider | Out-Null
            
            # Wait for registration to complete (with timeout)
            $timeout = 300  # 5 minutes
            $timer = 0
            $interval = 10
            
            do {
                Start-Sleep -Seconds $interval
                $timer += $interval
                
                $providerStatus = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction SilentlyContinue
                $status = $providerStatus.RegistrationState
                
                Write-Progress -Activity "Registering $provider" -Status "Status: $status" -PercentComplete (($timer / $timeout) * 100)
                
            } while ($timer -lt $timeout -and $status -ne "Registered")
            
            Write-Progress -Activity "Registering $provider" -Completed
            
            if ($status -eq "Registered") {
                Write-Host "  ✅ $provider : Successfully registered" -ForegroundColor Green
                $results += [PSCustomObject]@{
                    Provider = $provider
                    Status = "Successfully Registered"
                    Success = $true
                }
            } else {
                Write-Host "  ⚠️  $provider : Registration timeout (may complete in background)" -ForegroundColor Yellow
                $results += [PSCustomObject]@{
                    Provider = $provider
                    Status = "Registration Timeout"
                    Success = $false
                }
            }
        }
        catch {
            Write-Host "  ❌ $provider : Registration failed - $($_.Exception.Message)" -ForegroundColor Red
            $results += [PSCustomObject]@{
                Provider = $provider
                Status = "Registration Failed"
                Success = $false
            }
        }
    }

    Write-Host "`n📊 Registration Summary:" -ForegroundColor Cyan
    $results | Format-Table -AutoSize

    $successCount = ($results | Where-Object { $_.Success }).Count
    $totalCount = $results.Count

    if ($successCount -eq $totalCount) {
        Write-Host "✅ All resource providers registered successfully! ($successCount/$totalCount)" -ForegroundColor Green
        return $true
    } else {
        Write-Host "⚠️  Some resource provider registrations incomplete ($successCount/$totalCount)" -ForegroundColor Yellow
        return $false
    }
}
