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

using module SACRED.Log

Function Connect-SACREDToAzure (
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
        Connects SACRED to Azure.

        .DESCRIPTION
        Connects SACRED to Azure. SACRED can connect to Azure using a managed identity, a service principal with a secret, or a service principal with a certificate.

        .PARAMETER AzureTenantId
        The ID of the Azure tenant to connect to.

        .PARAMETER UseAzureManagedIdentity
        Indicates that SACRED should connect to Azure using a managed identity.

        .PARAMETER AzureServicePrincipalClientId
        The ID of the Azure service principal to connect to Azure with.

        .PARAMETER AzureServicePrincipalClientSecret
        The secret of the Azure service principal to connect to Azure with.

        .PARAMETER AzureServicePrincipalClientCertificateThumbprint
        The thumbprint of the certificate of the Azure service principal to connect to Azure with.

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    if($UseAzureManagedIdentity)
    {
        $global:SACREDLogger.Info("Connecting to Azure using a managed identity.")
        Connect-AzAccount -Identity -WarningAction SilentlyContinue | Out-Null
    }
    elseif($AzureServicePrincipalClientId -ne '')
    {
        if($AzureServicePrincipalClientSecret -ne '')
        {
            $global:SACREDLogger.Info("Connecting to Azure with a secret, using the client ID $AzureServicePrincipalClientId.")
            $secureAzureServicePrincipalClientSecret = ConvertTo-SecureString -String $AzureServicePrincipalClientSecret -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($AzureServicePrincipalClientId, $secureAzureServicePrincipalClientSecret)
            Connect-AzAccount -ServicePrincipal -TenantId $AzureTenantId -Credential $credential -WarningAction SilentlyContinue | Out-Null
        }
        elseif($AzureServicePrincipalClientCertificateThumbprint -ne '')
        {
            $global:SACREDLogger.Info("Connecting to Azure with certificate thumbprint $AzureServicePrincipalClientCertificateThumbprint, using the client ID $AzureServicePrincipalClientId.")
            Connect-AzAccount -CertificateThumbprint $AzureServicePrincipalClientCertificateThumbprint -ApplicationId $AzureServicePrincipalClientId -Tenant $AzureTenantId -ServicePrincipal -WarningAction SilentlyContinue | Out-Null
        }
    }
    else
    {
        $global:SACREDLogger.Info("Connecting to Azure using an interactive logon prompt.")
        Connect-AzAccount -WarningAction SilentlyContinue | Out-Null
        $global:SACREDLogger.Info("Connected to Azure as $((Get-AzContext).Account.Id).")
    }
}

Function Get-SACREDAzureContextForResource (
	[Parameter(Mandatory=$true)] 
    [string] $ResourceName,

    [Parameter(Mandatory=$false)] 
	[string] $ResourceGroupName,
	
	[Parameter(Mandatory=$true)] 
    [string] $ResourceType
)
{
    <#
        .SYNOPSIS
        Gets the Azure context for a resource.

        .DESCRIPTION
        Gets the Azure context for a resource. This function will search all subscriptions for the resource and return the context for the subscription containing the resource.

        .PARAMETER ResourceName
        The name of the resource.

        .PARAMETER ResourceGroupName
        The name of the resource group containing the resource.

        .PARAMETER ResourceType
        The type of the resource.

        .INPUTS
        None

        .OUTPUTS
        None
    #>
    $global:SACREDLogger.Info("Locating correct Azure subscription for resource $ResourceName of type $ResourceType in resource group $ResourceGroupName.")
    $contextConverter =  New-Object -TypeName Microsoft.Azure.Commands.Profile.Models.AzureContextConverter
    $subscriptions = Get-AzSubscription -WarningAction SilentlyContinue
    foreach($subscription in $subscriptions)
	{
        $subscriptionId = $subscription.SubscriptionId
		$tenantId = $subscription.TenantId
        $resourceContext = Set-AzContext -Scope Process -SubscriptionId $subscriptionId -TenantId $tenantId
        $resourceContextContainer =  $contextConverter.ConvertFrom($resourceContext, [Microsoft.Azure.Commands.Common.Authentication.Abstractions.Core.IAzureContextContainer], $null, $true)
        if(($ResourceGroupName -ne $null) -and ($ResourceGroupName -ne ''))
        {
            $desiredResource = Get-AzResource -Name $ResourceName -ResourceGroupName $ResourceGroupName -ResourceType $ResourceType -DefaultProfile $resourceContextContainer -ErrorAction SilentlyContinue
        }
        else 
        {
            $desiredResource = Get-AzResource -Name $ResourceName -ResourceType $ResourceType -DefaultProfile $resourceContextContainer -ErrorAction SilentlyContinue
        }

        if($desiredResource -ne $null)
		{
            $global:SACREDLogger.Info("Found resource $ResourceName in subscription $($resourceContext.Subscription.Name).")
			return $resourceContextContainer
		}
    }

    #If this point has been reached then resource was not found in any subscription
    $errorMessage = "No subscription found containing $ResourceName of type $ResourceType in group $ResourceGroupName"
    $global:SACREDLogger.Error($errorMessage)
	throw [System.Exception] $errorMessage
}