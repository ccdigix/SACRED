<#
Copyright (c) 2023 Chris Clohosy

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>

Function Initialize-SACREDPodeServerEnvironment (
)
{
    <#
        .SYNOPSIS
        Initializes the SACRED environment within the Pode server.

        .DESCRIPTION
        Initializes the SACRED environment within the Pode server. Configuration values are retrieved from the Pode server config file.

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    Initialize-SACREDEnvironment -StoreType (Get-PodeConfig).SACRED.StoreType -LocalStoreBasePath (Get-PodeConfig).SACRED.LocalStoreBasePath -LoggerType (Get-PodeConfig).SACRED.LoggerType -LocalLoggerBasePath (Get-PodeConfig).SACRED.LocalLoggerBasePath -SecretStoreType (Get-PodeConfig).SACRED.SecretStoreType -ConnectToAzure:((Get-PodeConfig).SACRED.ConnectToAzure) -AzureTenantId (Get-PodeConfig).SACRED.AzureTenantId -UseAzureManagedIdentity:((Get-PodeConfig).SACRED.UseAzureManagedIdentity) -AzureServicePrincipalClientId (Get-PodeConfig).SACRED.AzureServicePrincipalClientId -AzureServicePrincipalClientSecret (Get-PodeConfig).SACRED.AzureServicePrincipalClientSecret -AzureServicePrincipalClientCertificateThumbprint (Get-PodeConfig).SACRED.AzureServicePrincipalClientCertificateThumbprint
}

Function Start-SACREDPodeServer (
    [Parameter(Mandatory=$false)]
    [int] $ServerThreads = 3
)
{
    <#
        .SYNOPSIS
        Starts the SACRED environment within a Pode server.

        .DESCRIPTION
        Starts the SACRED environment within a Pode server. Configuration values are retrieved from the Pode server config file.

        .PARAMETER ServerThreads
        The number of threads assigned to the server. Defaults to 3.

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    Start-PodeServer -Threads $ServerThreads -RootPath (Get-Location).Path -ScriptBlock {
        New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
        if((Get-PodeConfig).SACRED.LoggerType -eq 'Pode')
        {
            New-PodeLoggingMethod -File -Name 'sacred' -Path (Get-PodeConfig).SACRED.PodeLoggerBasePath -MaxDays (Get-PodeConfig).SACRED.PodeLoggerMaxDaysRetention | Add-PodeLogger -Name 'file' -ArgumentList $($logLevel, $message, $correlationId) -ScriptBlock {
                param($logLevel, $message, $correlationId)
                $logMessage = "$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss')) $correlationId $logLevel $message"
                return $logMessage
            }
            New-PodeLoggingMethod -Terminal | Add-PodeLogger -Name 'terminal' -ArgumentList $($logLevel, $message, $correlationId) -ScriptBlock {
                param($logLevel, $message, $correlationId)
                $logMessage = "$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss')) $correlationId $logLevel $message"
                return $logMessage
            }
        }

        if((Get-PodeConfig).Protocol -eq 'Https')
        {
            if((Get-PodeConfig).SelfSigned)
            {
                Add-PodeEndpoint -Address (Get-PodeConfig).Address -Port (Get-PodeConfig).Port -Protocol (Get-PodeConfig).Protocol -SelfSigned
            }
            elseif((Get-PodeConfig).CertificateThumbprint)
            {
                Add-PodeEndpoint -Address (Get-PodeConfig).Address -Port (Get-PodeConfig).Port -Protocol (Get-PodeConfig).Protocol -CertificateThumbprint (Get-PodeConfig).CertificateThumbprint -CertificateStoreName (Get-PodeConfig).CertificateStoreName -CertificateStoreLocation (Get-PodeConfig).CertificateStoreLocation
            }
            elseif((Get-PodeConfig).Certificate)
            {
                Add-PodeEndpoint -Address (Get-PodeConfig).Address -Port (Get-PodeConfig).Port -Protocol (Get-PodeConfig).Protocol -Certificate (Get-PodeConfig).Certificate -CertificateThumbprint (Get-PodeConfig).CertificateThumbprint
            }
        }
        else
        {
            Add-PodeEndpoint -Address (Get-PodeConfig).Address -Port (Get-PodeConfig).Port -Protocol (Get-PodeConfig).Protocol
        }

        Add-PodeRoute -Method Post -Path '/api/rotationjob' -ScriptBlock {
            try
            {
                Initialize-SACREDPodeServerEnvironment
                Register-SACREDRotationJobDefinition -RotationJobDefinitionJSON $WebEvent.Request.Body
                Write-PodeTextResponse -Value 'Rotation job definition created successfully' -StatusCode 201
            }
            catch
            {
                $errorDetails = ($_.Exception | Format-List -Force | Out-String)
                Write-PodeTextResponse -Value "Failed to register the rotation job definition, error message included: $errorDetails" -StatusCode 500
            }
        }

        Add-PodeRoute -Method Post -Path '/api/rotationjob/:rotationJobName' -ScriptBlock {
            try
            {
                Initialize-SACREDPodeServerEnvironment
                Register-SACREDRotationJobDefinition -RotationJobDefinitionJSON $WebEvent.Request.Body -RotationJobName $WebEvent.Parameters['rotationJobName']
                Write-PodeTextResponse -Value 'Rotation job definition created successfully' -StatusCode 201
            }
            catch
            {
                $errorDetails = ($_.Exception | Format-List -Force | Out-String)
                Write-PodeTextResponse -Value "Failed to register the rotation job definition, error message included: $errorDetails" -StatusCode 500
            }
        }

        Add-PodeRoute -Method Delete -Path '/api/rotationjob/:rotationJobName' -ScriptBlock {
            try
            {
                Initialize-SACREDPodeServerEnvironment
                Unregister-SACREDRotationJobDefinition -RotationJobName $WebEvent.Parameters['rotationJobName']
                Write-PodeTextResponse -Value 'Rotation job definition successfully deleted' -StatusCode 204
            }
            catch
            {
                $errorDetails = ($_.Exception | Format-List -Force | Out-String)
                Write-PodeTextResponse -Value "Failed to delete the rotation job definition, error message included: $errorDetails" -StatusCode 500
            }
        }

        Add-PodeRoute -Method Post -Path '/api/rotationjob/:rotationJobName/run' -ScriptBlock {
            try
            {
                Initialize-SACREDPodeServerEnvironment
                Invoke-SACREDRotationJob -RotationJobName $WebEvent.Parameters['rotationJobName']
                Write-PodeTextResponse -Value 'Rotation job definition executed successfully' -StatusCode 200
            }
            catch
            {
                $errorDetails = ($_.Exception | Format-List -Force | Out-String)
                Write-PodeTextResponse -Value "Failed to execute the rotation job definition, error message included: $errorDetails" -StatusCode 500
            }
        }

        Add-PodeRoute -Method Post -Path '/api/schedule/:scheduleName/run' -ScriptBlock {
            try
            {
                Initialize-SACREDPodeServerEnvironment
                Invoke-SACREDRotationSchedule -RotationScheduleName $WebEvent.Parameters['scheduleName']
                Write-PodeTextResponse -Value 'Rotation job schedule executed successfully' -StatusCode 200
            }
            catch
            {
                $errorDetails = ($_.Exception | Format-List -Force | Out-String)
                Write-PodeTextResponse -Value "Failed to execute the rotation job schedule, error message included: $errorDetails" -StatusCode 500
            }
        }

        $schedules = (Get-PodeConfig).SACRED.Schedules
        foreach($schedule in $schedules)
        {
            Add-PodeSchedule -Name $schedule.Name -Cron $schedule.CronSchedule -ArgumentList @{ ScheduleName = $schedule.Name } -ScriptBlock {
                param($ScheduleName)
                Initialize-SACREDPodeServerEnvironment
                Invoke-SACREDRotationSchedule -RotationScheduleName $ScheduleName
            }
        }
    }
}