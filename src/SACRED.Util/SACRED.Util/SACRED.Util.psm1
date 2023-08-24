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

using module SACRED.Store
using module SACRED.Store.Local
using module SACRED.Log
using module SACRED.Log.Local

Enum SACREDStoreType
{
    Local
}

Enum SACREDLoggerType
{
    Local
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

        if($ConnectToAzure)
        {
            Connect-SACREDToAzure -AzureTenantId $AzureTenantId -UseAzureManagedIdentity:$UseAzureManagedIdentity -AzureServicePrincipalClientId $AzureServicePrincipalClientId -AzureServicePrincipalClientSecret $AzureServicePrincipalClientSecret -AzureServicePrincipalClientCertificateThumbprint $AzureServicePrincipalClientCertificateThumbprint
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