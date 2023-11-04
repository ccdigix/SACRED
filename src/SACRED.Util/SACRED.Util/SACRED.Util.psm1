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

using module SACRED.SecretStore
using module SACRED.SecretStore.EnvironmentVariable
using module SACRED.SecretStore.PodeConfigFile
using module SACRED.Store
using module SACRED.Store.Local
using module SACRED.Log
using module SACRED.Log.Local
using module SACRED.Log.Pode

Enum SACREDSecretStoreType
{
    EnvironmentVariable
    PodeConfigFile
}

Enum SACREDStoreType
{
    Local
}

Enum SACREDLoggerType
{
    Local
    Pode
}

Function Initialize-SACREDEnvironment (
    [Parameter(Mandatory=$false)]
    [SACREDStoreType] $StoreType = [SACREDStoreType]::Local,

    [Parameter(Mandatory=$false)]
    [string] $LocalStoreBasePath = '',

    [Parameter(Mandatory=$false)]
    [SACREDLoggerType] $LoggerType = [SACREDLoggerType]::Local,

    [Parameter(Mandatory=$false)]
    [string] $LocalLoggerBasePath = '',

    [Parameter(Mandatory=$false)]
    [SACREDSecretStoreType] $SecretStoreType = [SACREDSecretStoreType]::EnvironmentVariable,

    [Parameter(Mandatory=$false)]
    [switch] $ConnectToAzure,

    [Parameter(Mandatory=$false)]
    [string] $AzureTenantId = '',

    [Parameter(Mandatory=$false)]
    [switch] $UseAzureManagedIdentity,

    [Parameter(Mandatory=$false)]
    [string] $AzureServicePrincipalClientId = '',

    [Parameter(Mandatory=$false)]
    [string] $AzureServicePrincipalClientSecret = '',

    [Parameter(Mandatory=$false)]
    [string] $AzureServicePrincipalClientCertificateThumbprint = ''
)
{
    <#
        .SYNOPSIS
        Initializes the SACRED environment.

        .DESCRIPTION
        Initializes the SACRED environment. This function should be called at the start of any SACRED script.

        .PARAMETER StoreType
        The type of store to use. The default is Local.

        .PARAMETER LocalStoreBasePath
        The base path to use for the local store. This parameter is only used if StoreType is Local.

        .PARAMETER LoggerType
        The type of logger to use. The default is Local.

        .PARAMETER LocalLoggerBasePath
        The base path to use for the local logger to store logs. This parameter is only used if LoggerType is Local.

        .PARAMETER SecretStoreType
        The type of secret store to use. The default is EnvironmentVariable.

        .PARAMETER ConnectToAzure
        Indicates whether to connect to Azure. The default is false.

        .PARAMETER AzureTenantId
        The Azure tenant ID to use when connecting to Azure.

        .PARAMETER UseAzureManagedIdentity
        Indicates whether to use a managed identity when connecting to Azure.

        .PARAMETER AzureServicePrincipalClientId
        The Azure service principal client ID to use when connecting to Azure.

        .PARAMETER AzureServicePrincipalClientSecret
        The Azure service principal client secret to use when connecting to Azure.

        .PARAMETER AzureServicePrincipalClientCertificateThumbprint
        The Azure service principal client certificate thumbprint to use when connecting to Azure.

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    $ErrorActionPreference = 'Stop'
    try
    {
        switch($LoggerType)
        {
            'Local'
            {
                if($LocalLoggerBasePath -eq '') { throw "The LocalLoggerBasePath parameter must be specified if logger type is Local." }
                [SACREDLogger] $global:SACREDLogger = [SACREDLocalLogger]::new($LocalLoggerBasePath)
            }
            'Pode'
            {
                [SACREDLogger] $global:SACREDLogger = [SACREDPodeLogger]::new()
            }
        }

        if($ConnectToAzure)
        {
            Connect-SACREDToAzure -AzureTenantId $AzureTenantId -UseAzureManagedIdentity:$UseAzureManagedIdentity -AzureServicePrincipalClientId $AzureServicePrincipalClientId -AzureServicePrincipalClientSecret $AzureServicePrincipalClientSecret -AzureServicePrincipalClientCertificateThumbprint $AzureServicePrincipalClientCertificateThumbprint
        }

        switch($SecretStoreType)
        {
            'EnvironmentVariable'
            {
                $global:SACREDLogger.Info("Using a store that retrieves secrets from environment variables.")
                [SACREDSecretStore] $global:SACREDSecretStore = [SACREDEnvironmentVariableSecretStore]::new()
            }
            'PodeConfigFile'
            {
                $global:SACREDLogger.Info("Using a store that retrieves secrets from the Pode server config file.")
                [SACREDSecretStore] $global:SACREDSecretStore = [SACREDPodeConfigFileSecretStore]::new()
            }
        }

        switch($StoreType)
        {
            'Local'
            {
                if($LocalStoreBasePath -eq '') { throw "The LocalStoreBasePath parameter must be specified if store type is Local." }
                $global:SACREDLogger.Info("Using a local store with the base path $LocalStoreBasePath.")
                [SACREDStore] $global:SACREDStore = [SACREDLocalStore]::new($LocalStoreBasePath)
            }
        }
    }
    catch
    {
        Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
        $errorDetails = (Resolve-AzError -Last | Out-String)
        $global:SACREDLogger.Error($errorDetails)
        throw $_
    }
}

Function ConvertTo-SACREDBase64ValueBytes (
    [Parameter(Mandatory=$true)]    
    [string] $Base64UrlString
) 
{
    <#
        .SYNOPSIS
        Converts a Base64Url encoded string into regular Base64 bytes.

        .DESCRIPTION
        Converts a Base64Url encoded string into regular Base64 bytes.

        .PARAMETER Base64UrlString
        The Base64Url string to convert.

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    $Base64UrlString = ($Base64UrlString -ireplace '-', '+')
    $Base64UrlString = ($Base64UrlString -ireplace '_', '/')

    switch ($Base64UrlString.Length % 4) 
    {
        1 {
            #$Value = $Value.Substring(0, $Value.Length - 1)
            $Base64UrlString += '==='
        }

        2 {
            $Base64UrlString += '=='
        }

        3 {
            $Base64UrlString += '='
        }
    }

    try 
    {
        $base64Bytes = [System.Convert]::FromBase64String($Base64UrlString)
        return $base64Bytes
    }
    catch 
    {
        throw 'Invalid Base64 encoded value.'
    }
}

Function ConvertFrom-SACREDBase64UrlString (
    [Parameter(Mandatory=$true)]    
    [string] $Base64UrlString
)
{
    <#
        .SYNOPSIS
        Converts a Base64Url encoded string into a regular Base64 string.

        .DESCRIPTION
        Converts a Base64Url encoded string into a regular Base64 string.

        .PARAMETER Base64UrlString
        The Base64Url string to convert.

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    try 
    {
        $base64Bytes = ConvertTo-SACREDBase64ValueBytes -Base64UrlString $Base64UrlString
        $base64String = [System.Text.Encoding]::UTF8.GetString($base64Bytes)
        return $base64String
    }
    catch 
    {
        throw 'Invalid Base64 encoded value.'
    }
}