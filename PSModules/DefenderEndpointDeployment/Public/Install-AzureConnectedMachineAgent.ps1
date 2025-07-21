function Install-AzureConnectedMachineAgent {
    <#
    .SYNOPSIS
        Downloads and installs the Azure Connected Machine Agent on local or remote machines.

    .DESCRIPTION
        This function downloads and installs the Azure Connected Machine Agent, which is required 
        for Azure Arc-enabled servers. It can install on the local machine or remote machines.

    .PARAMETER ComputerName
        Name of the computer to install the agent on. Defaults to localhost.

    .PARAMETER Force
        Forces installation even if agent is already installed.

    .EXAMPLE
        Install-AzureConnectedMachineAgent
        
        Installs the agent on the local machine.

    .EXAMPLE
        Install-AzureConnectedMachineAgent -ComputerName "SERVER01" -Force
        
        Forces installation of the agent on SERVER01.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ComputerName = "localhost",
        
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    Write-Host "🔽 Azure Connected Machine Agent Installation" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────" -ForegroundColor Cyan

    # Check if agent is already installed (if not forcing)
    if (-not $Force) {
        $agentPath = "C:\Program Files\AzureConnectedMachineAgent"
        $isInstalled = if ($ComputerName -eq "localhost" -or $ComputerName -eq $env:COMPUTERNAME) {
            Test-Path $agentPath
        } else {
            Invoke-Command -ComputerName $ComputerName -ScriptBlock { 
                param($path) 
                Test-Path $path 
            } -ArgumentList $agentPath -ErrorAction SilentlyContinue
        }

        if ($isInstalled) {
            Write-Host "✅ Azure Connected Machine Agent is already installed on $ComputerName" -ForegroundColor Green
            return $true
        }
    }

    try {
        # Download the agent
        $downloadUrl = "https://aka.ms/AzureConnectedMachineAgent"
        $installerPath = "$env:TEMP\AzureConnectedMachineAgent.msi"
        
        Write-Host "📥 Downloading Azure Connected Machine Agent..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath
        Write-Host "✅ Download completed" -ForegroundColor Green

        # Install the agent
        if ($ComputerName -eq "localhost" -or $ComputerName -eq $env:COMPUTERNAME) {
            Write-Host "🔧 Installing agent on local machine..." -ForegroundColor Yellow
            $installResult = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $installerPath, "/quiet", "/norestart" -Wait -PassThru
        } else {
            Write-Host "🔧 Installing agent on $ComputerName..." -ForegroundColor Yellow
            
            # Copy installer to remote machine
            $remotePath = "\\$ComputerName\C$\Temp\AzureConnectedMachineAgent.msi"
            Copy-Item $installerPath $remotePath -Force
            
            # Install remotely
            $installResult = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                param($msiPath)
                Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $msiPath, "/quiet", "/norestart" -Wait -PassThru
            } -ArgumentList "C:\Temp\AzureConnectedMachineAgent.msi"
        }

        if ($installResult.ExitCode -eq 0) {
            Write-Host "✅ Azure Connected Machine Agent installed successfully on $ComputerName" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ Installation failed with exit code: $($installResult.ExitCode)" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ Failed to install Azure Connected Machine Agent: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    finally {
        # Clean up installer
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }
    }
}
