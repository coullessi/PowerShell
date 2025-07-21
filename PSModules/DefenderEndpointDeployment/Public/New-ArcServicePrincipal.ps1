function New-ArcServicePrincipal {
    <#
    .SYNOPSIS
        Creates a service principal for Azure Arc onboarding.

    .DESCRIPTION
        This function creates an Azure AD service principal with the necessary permissions 
        for Azure Arc device onboarding. It generates a client secret and assigns appropriate roles.

    .PARAMETER DisplayName
        Display name for the service principal. Defaults to "Azure Arc Onboarding Account".

    .PARAMETER ResourceGroupName
        Name of the resource group to scope the service principal permissions to.

    .PARAMETER SubscriptionId
        Azure subscription ID. If not provided, uses current context subscription.

    .PARAMETER ExpirationDays
        Number of days until the service principal secret expires. Default is 30 days.

    .EXAMPLE
        New-ArcServicePrincipal -ResourceGroupName "rg-azurearc-prod"
        
        Creates a service principal scoped to the specified resource group.

    .EXAMPLE
        New-ArcServicePrincipal -DisplayName "Arc-SP-Prod" -ExpirationDays 90
        
        Creates a service principal with custom name and 90-day expiration.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DisplayName = "Azure Arc Deployment Account - DefenderEndpointDeployment",
        
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory = $false)]
        [int]$ExpirationDays = 30
    )

    Write-Host "🔐 Creating Azure Arc Service Principal" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────" -ForegroundColor Cyan

    # Ensure Azure authentication
    $authSuccess = Confirm-AzureAuthentication
    if (-not $authSuccess) {
        Write-Host "❌ Azure authentication required for service principal creation" -ForegroundColor Red
        return $null
    }

    try {
        # Get current context if subscription not provided
        if ([string]::IsNullOrWhiteSpace($SubscriptionId)) {
            $context = Get-AzContext
            $SubscriptionId = $context.Subscription.Id
        }

        $expirationDate = (Get-Date).AddDays($ExpirationDays)
        $scope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"
        
        Write-Host "📋 Service Principal Configuration:" -ForegroundColor Yellow
        Write-Host "  Display Name: $DisplayName" -ForegroundColor Gray
        Write-Host "  Scope: $scope" -ForegroundColor Gray
        Write-Host "  Expiration: $($expirationDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray

        # Create the service principal
        Write-Host "`n🔄 Creating service principal..." -ForegroundColor Yellow
        $servicePrincipal = New-AzADServicePrincipal -DisplayName $DisplayName -Role "Azure Connected Machine Onboarding" -Scope $scope -EndDate $expirationDate

        if ($servicePrincipal) {
            Write-Host "✅ Service principal created successfully!" -ForegroundColor Green
            
            $result = [PSCustomObject]@{
                ApplicationId = $servicePrincipal.AppId
                ObjectId = $servicePrincipal.Id
                DisplayName = $servicePrincipal.DisplayName
                Secret = $servicePrincipal.PasswordCredentials.SecretText
                ExpirationDate = $expirationDate
                TenantId = (Get-AzContext).Tenant.Id
                SubscriptionId = $SubscriptionId
                ResourceGroup = $ResourceGroupName
                Scope = $scope
            }
            
            Write-Host "`n📊 Service Principal Details:" -ForegroundColor Cyan
            Write-Host "  Application ID: $($result.ApplicationId)" -ForegroundColor Green
            Write-Host "  Object ID: $($result.ObjectId)" -ForegroundColor Gray
            Write-Host "  Tenant ID: $($result.TenantId)" -ForegroundColor Gray
            Write-Host "  Secret: [HIDDEN FOR SECURITY]" -ForegroundColor Yellow
            Write-Host "  Expires: $($result.ExpirationDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
            
            Write-Host "`n⚠️  IMPORTANT SECURITY NOTES:" -ForegroundColor Red
            Write-Host "  • Store the client secret securely - it cannot be retrieved again" -ForegroundColor Yellow
            Write-Host "  • The secret expires on $($result.ExpirationDate.ToString('yyyy-MM-dd'))" -ForegroundColor Yellow
            Write-Host "  • Limit access to these credentials to authorized personnel only" -ForegroundColor Yellow

            return $result
        } else {
            Write-Host "❌ Failed to create service principal" -ForegroundColor Red
            return $null
        }
    }
    catch {
        Write-Host "❌ Error creating service principal: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}
