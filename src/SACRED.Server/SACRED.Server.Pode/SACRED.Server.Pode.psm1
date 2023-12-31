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

        New-PodeAccessScheme -Type Role | Add-PodeAccess -Name 'RoleAccess'

        if((Get-PodeConfig).SACRED.ApiAuthenticationType -eq 'ApiKey')
        {
            New-PodeAuthScheme -ApiKey | Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
                param($key)

                $roles = @()

                Initialize-SACREDPodeServerEnvironment
                
                $rotationJobAuthorApiKey1 = $global:SACREDSecretStore.GetSecret((Get-PodeConfig).SACRED.RotationJobAuthorApiKey1SecretName)
                $rotationJobAuthorApiKey2 = $global:SACREDSecretStore.GetSecret((Get-PodeConfig).SACRED.RotationJobAuthorApiKey2SecretName)
                if(($rotationJobAuthorApiKey1 -eq $key) -or ($rotationJobAuthorApiKey2 -eq $key))
                {
                    $roles += 'RotationJobAuthor'
                }

                $rotationJobExecutorApiKey1 = $global:SACREDSecretStore.GetSecret((Get-PodeConfig).SACRED.RotationJobExecutorApiKey1SecretName)
                $rotationJobExecutorApiKey2 = $global:SACREDSecretStore.GetSecret((Get-PodeConfig).SACRED.RotationJobExecutorApiKey2SecretName)
                if(($rotationJobExecutorApiKey1 -eq $key) -or ($rotationJobExecutorApiKey2 -eq $key))
                {
                    $roles += 'RotationJobExecutor'
                }

                $user = @{
                    User = @{
                        Username = 'APIKeyUser'
                        Roles = $roles
                    }
                }
                return $user
            }
        }
        elseif((Get-PodeConfig).SACRED.ApiAuthenticationType -eq 'EntraServicePrincipalJWT')
        {
            New-PodeAuthScheme -Bearer | Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
                param($token)
    
                $tokenParts = $token.Split('.')
                $header = (ConvertFrom-SACREDBase64UrlString -Base64UrlString $tokenParts[0] | ConvertFrom-Json)
                $body = (ConvertFrom-SACREDBase64UrlString -Base64UrlString $tokenParts[1] | ConvertFrom-Json)
    
                $openIdConfig = Invoke-RestMethod -Method Get -Uri 'https://login.microsoftonline.com/common/.well-known/openid-configuration'
                $jwksConfig = Invoke-RestMethod -Method Get -Uri $openIdConfig.jwks_uri
                $kid = $header.kid
                $signingKey = $jwksConfig.keys | Where-Object {$_.kid -eq $kid}
    
                $cryptoServiceProvider = New-Object System.Security.Cryptography.RSACryptoServiceProvider
                $cryptoServiceProvider.ImportParameters(
                    @{
                        Modulus = (ConvertTo-SACREDBase64ValueBytes -Base64UrlString $signingKey.n)
                        Exponent = (ConvertTo-SACREDBase64ValueBytes -Base64UrlString $signingKey.e)
                    }
                )
                $sha256 = [System.Security.Cryptography.SHA256]::Create()
                $hash = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($tokenParts[0] + '.' + $tokenParts[1]))
                $rsaDeformatter = New-Object System.Security.Cryptography.RSAPKCS1SignatureDeformatter($cryptoServiceProvider)
                $rsaDeformatter.SetHashAlgorithm('SHA256')
                $validSignature = $rsaDeformatter.VerifySignature($hash, (ConvertTo-SACREDBase64ValueBytes -Base64UrlString $tokenParts[2]))
    
                if(!$validSignature)
                {
                    return @{Code = 401; Message = 'Invalid JWT signature.'}
                }
    
                $clientId = (Get-PodeConfig).SACRED.ClientId
                if($body.aud -ne $clientId)
                {
                    return @{Code = 401; Message = "Invalid JWT client ID - $($body.aud)."}
                }
    
                $now = [datetime]::UtcNow
                $unixStart = [datetime]::new(1970, 1, 1, 0, 0, [DateTimeKind]::Utc)
                if(($now -gt $unixStart.AddSeconds($body.exp)) -or ($now -lt $unixStart.AddSeconds($body.nbf)))
                {
                    return @{Code = 401; Message = "Invalid JWT time period."}
                }
    
                $user = @{
                    User = @{
                        Username = $body.appid
                        Roles = $body.roles
                    }
                }
                return $user
            }
        }
        else
        {
            $passThroughAuthScheme = New-PodeAuthScheme -Custom -ScriptBlock {
                return $null
            }
            $passThroughAuthScheme | Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
                $user = @{
                    User = @{
                        Username = 'Anonymous'
                        Roles = @('RotationJobAuthor', 'RotationJobExecutor')
                    }
                }
                return $user
            }
        }

        Add-PodeRouteGroup -Path '/api' -Authentication 'Authenticate' -Role 'RotationJobAuthor' -Access 'RoleAccess' -Routes {
            Add-PodeRoute -Method Post -Path '/rotationjob' -ScriptBlock {
                try
                {
                    Initialize-SACREDPodeServerEnvironment
                    Register-SACREDRotationJobDefinition -RotationJobDefinitionJSON $WebEvent.Request.Body

                    $response = @{
                        'Message' = 'Rotation job definition created successfully.'
                    } | ConvertTo-Json -Depth 5
                    Write-PodeJsonResponse -Value $response -StatusCode 201
                }
                catch
                {
                    $errorJSON = ($_.Exception | Select-Object -Property Message,StackTrace,ErrorRecord | ConvertTo-Json -Depth 5)
                    Write-PodeJsonResponse -Value $errorJSON -StatusCode 500
                }
            }

            Add-PodeRoute -Method Post -Path '/rotationjob/:rotationJobName' -ScriptBlock {
                try
                {
                    Initialize-SACREDPodeServerEnvironment
                    Register-SACREDRotationJobDefinition -RotationJobDefinitionJSON $WebEvent.Request.Body -RotationJobName $WebEvent.Parameters['rotationJobName']
                    $response = @{
                        'Message' = 'Rotation job definition created successfully.'
                    } | ConvertTo-Json -Depth 5
                    Write-PodeJsonResponse -Value $response -StatusCode 201
                }
                catch
                {
                    $errorJSON = ($_.Exception | Select-Object -Property Message,StackTrace,ErrorRecord | ConvertTo-Json -Depth 5)
                    Write-PodeJsonResponse -Value $errorJSON -StatusCode 500
                }
            }

            Add-PodeRoute -Method Delete -Path '/rotationjob/:rotationJobName' -ScriptBlock {
                try
                {
                    Initialize-SACREDPodeServerEnvironment
                    Unregister-SACREDRotationJobDefinition -RotationJobName $WebEvent.Parameters['rotationJobName']
                    $response = @{
                        'Message' = 'Rotation job definition successfully deleted.'
                    } | ConvertTo-Json -Depth 5
                    Write-PodeJsonResponse -Value $response -StatusCode 204
                }
                catch
                {
                    $errorJSON = ($_.Exception | Select-Object -Property Message,StackTrace,ErrorRecord | ConvertTo-Json -Depth 5)
                    Write-PodeJsonResponse -Value $errorJSON -StatusCode 500
                }
            }
        }

        Add-PodeRouteGroup -Path '/api' -Authentication 'Authenticate' -Role 'RotationJobExecutor' -Access 'RoleAccess' -Routes {
            Add-PodeRoute -Method Post -Path '/rotationjob/:rotationJobName/run' -ScriptBlock {
                try
                {
                    Initialize-SACREDPodeServerEnvironment
                    Invoke-SACREDRotationJob -RotationJobName $WebEvent.Parameters['rotationJobName']
                    $response = @{
                        'Message' = 'Rotation job definition executed successfully.'
                    } | ConvertTo-Json -Depth 5
                    Write-PodeJsonResponse -Value $response -StatusCode 200
                }
                catch
                {
                    $errorJSON = ($_.Exception | Select-Object -Property Message,StackTrace,ErrorRecord | ConvertTo-Json -Depth 5)
                    Write-PodeJsonResponse -Value $errorJSON -StatusCode 500
                }
            }
    
            Add-PodeRoute -Method Post -Path '/schedule/:scheduleName/run' -ScriptBlock {
                try
                {
                    Initialize-SACREDPodeServerEnvironment
                    Invoke-SACREDRotationSchedule -RotationScheduleName $WebEvent.Parameters['scheduleName']
                    $response = @{
                        'Message' = 'Rotation job schedule executed successfully.'
                    } | ConvertTo-Json -Depth 5
                    Write-PodeJsonResponse -Value $response -StatusCode 200
                }
                catch
                {
                    $errorJSON = $_.Exception.Message
                    Write-PodeJsonResponse -Value $errorJSON -StatusCode 500
                }
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