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
using module SACRED.Log

Function Invoke-SACREDCosmosDBKeyRotation (
    [Parameter(Mandatory=$true)]
    [string] $AccountName,

    [Parameter(Mandatory=$true)]
    [string] $AccountResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string] $RotationJobName
)
{
    <#
        .SYNOPSIS
        Rotates an Azure Cosmos DB account key.

        .DESCRIPTION
        Rotates an Azure Cosmos DB account key. The key is rotated by regenerating the version of the key currently not being used.

        .PARAMETER AccountName
        The name of the Azure Cosmos DB account.

        .PARAMETER AccountResourceGroupName
        The name of the resource group containing the Azure Cosmos DB account.

        .PARAMETER RotationJobName
        The name of the rotation job.

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    $global:SACREDLogger.Info("Rotating Azure Cosmos DB account key for account $AccountName in resource group $AccountResourceGroupName.")
    $credentialVersionDetails = $global:SACREDStore.GetSACREDRotationJobCredentialVersionDetails($RotationJobName)
    $currentAccountKeyType = $credentialVersionDetails.credentialVersion
    switch($currentAccountKeyType)
    {
        'primary' 
        {
            $newAccountKeyType = 'secondary'
        }
        'secondary' 
        {
            $newAccountKeyType = 'primary' 
        }
        'primaryReadonly'
        {
            $newAccountKeyType = 'secondaryReadonly'
        }
        'secondaryReadonly'
        {
            $newAccountKeyType = 'primaryReadonly'
        }
        default 
        {
            $errorMessage = "Unknown account key type: $currentAccountKeyType"
            $global:SACREDLogger.Error($errorMessage)
            throw $errorMessage 
        }
    }
    $global:SACREDLogger.Info("Key to be regenerated and used is the $newAccountKeyType version.")

    $newCredentials = Invoke-SACREDCosmosDBKeyRegeneration -accountName $AccountName -accountResourceGroupName $AccountResourceGroupName -accountKeyType $newAccountKeyType
    $credentialVersionDetails.credentialVersion = $newAccountKeyType
    $global:SACREDStore.SetSACREDRotationJobCredentialVersionDetails($RotationJobName, $credentialVersionDetails)

    return $newCredentials
}


Function Invoke-SACREDCosmosDBKeyRegeneration (
    [Parameter(Mandatory=$true)]
    [string] $AccountName,

    [Parameter(Mandatory=$true)]
    [string] $AccountResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string] $AccountKeyType
)
{
    <#
        .SYNOPSIS
        Regenerates an Azure Cosmos DB account key.

        .DESCRIPTION
        Regenerates an Azure Cosmos DB account key.

        .PARAMETER AccountName
        The name of the Azure Cosmos DB account.

        .PARAMETER AccountResourceGroupName
        The name of the resource group containing the Azure Cosmos DB account.

        .PARAMETER AccountKeyType
        The type of key to regenerate. Valid values are 'primary', 'secondary', 'primaryReadonly', and 'secondaryReadonly'.

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    $global:SACREDLogger.Info("Regenerating the $AccountKeyType key on Azure Cosmos DB account $AccountName within the $AccountResourceGroupName resource group.")
    $resourceContext = Get-SACREDAzureContextForResource -ResourceName $AccountName -ResourceGroupName $AccountResourceGroupName -ResourceType 'Microsoft.DocumentDB/databaseAccounts'
    $newAccountKey = New-AzCosmosDBAccountKey -ResourceGroupName $AccountResourceGroupName -Name $AccountName -KeyKind $AccountKeyType -DefaultProfile $resourceContext
    $accountKeyConnectionStrings = Get-AzCosmosDBAccountKey -ResourceGroupName $AccountResourceGroupName -Name $AccountName -Type 'ConnectionStrings' -DefaultProfile $resourceContext
    $newAccountKeyConnectionString = ($accountKeyConnectionStrings.GetEnumerator() | Where-Object { $_.Value -like "*$newAccountKey*" }).Value

    $newCredentials = @{'CosmosDBAccountKey'=$newAccountKey; 'CosmosDBConnectionString'=$newAccountKeyConnectionString}
    return $newCredentials
}

Function Build-SACREDCosmosDBRotationJobName (
    [Parameter(Mandatory=$true)]
    [SACREDRotationJobDefinition] $RotationJobDefinition
)
{
    <#
        .SYNOPSIS
        Builds the name of a rotation job for an Azure Cosmos DB key.

        .DESCRIPTION
        Builds the name of a rotation job for an Azure Cosmos DB key.

        .PARAMETER RotationJobDefinition
        The definition of the rotation job.

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    if($RotationJobDefinition.cosmosDBAccount.keyType -eq 'readonly')
    {
        $rotationJobName = "AzureCosmosDB_$($RotationJobDefinition.cosmosDBAccount.accountResourceGroupName)_$($RotationJobDefinition.cosmosDBAccount.accountName)_ReadOnly"
    }
    elseif($RotationJobDefinition.cosmosDBAccount.keyType -eq 'readwrite')
    {
        $rotationJobName = "AzureCosmosDB_$($RotationJobDefinition.cosmosDBAccount.accountResourceGroupName)_$($RotationJobDefinition.cosmosDBAccount.accountName)_ReadWrite"
    }

    return $rotationJobName
}