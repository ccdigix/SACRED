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

param 
(
    [Parameter(Mandatory=$true)]
    [string] $TokenFilePath
)

Describe 'SACRED.Rotate.Azure.CosmosDB' {

    BeforeAll {
        Initialize-SACREDEnvironment -LocalStoreBasePath $TestDrive -LocalLoggerBasePath $TestDrive -ConnectToAzure
    }

    It 'Rotates an Azure Cosmos DB read-only account key' {
        $rotationJobDefinitionJSON = '
        {
            "cosmosDBAccount": {
                "accountName": "@@COSMOSDB_ACCOUNT_NAME@@",
                "accountResourceGroupName":  "@@COSMOSDB_ACCOUNT_RESOURCE_GROUP_NAME@@",
                "keyType": "readonly"
            },
            "rotationSchedule":  "never",
            "update": {
                "mock": {}
            }
        }
        '
        $rotationJobDefinitionJSON = Merge-SACREDTokensIntoRotationJobDefinition -RotationJobDefinitionJSON $rotationJobDefinitionJSON -TokenFilePath $TokenFilePath

        Register-SACREDRotationJobDefinition -RotationJobDefinitionJSON $rotationJobDefinitionJSON

        #Get the existing key that we are about to rotate, which is not the one SACRED currently thinks is active
        $rotationJobDefinition = ConvertFrom-Json $rotationJobDefinitionJSON
        $accountName = $rotationJobDefinition.cosmosDBAccount.accountName
        $accountResourceGroupName = $rotationJobDefinition.cosmosDBAccount.accountResourceGroupName
        $rotationJobName = "AzureCosmosDB_$accountResourceGroupName`_$accountName`_ReadOnly"
        $credentialVersionDetails = $global:SACREDStore.GetSACREDRotationJobCredentialVersionDetails($rotationJobName)
        $existingAccountKeyType = $credentialVersionDetails.credentialVersion
        $resourceContext = Get-SACREDAzureContextForResource -ResourceName $accountName -ResourceGroupName $accountResourceGroupName -ResourceType 'Microsoft.DocumentDB/databaseAccounts'
        $existingAccountKeys = Get-AzCosmosDBAccountKey -ResourceGroupName $accountResourceGroupName -Name $accountName -Type 'ReadOnlyKeys' -DefaultProfile $resourceContext
        $existingAccountKey = ($existingAccountKeys.GetEnumerator() | Where-Object { $_.Name -notlike "*$existingAccountKeyType*" }).Value

        #Rotate the key
        Invoke-SACREDRotationJob -RotationJobName $rotationJobName

        #Get the name of the version of the key SACRED currently thinks is active
        $credentialVersionDetails = $global:SACREDStore.GetSACREDRotationJobCredentialVersionDetails($rotationJobName)
        $currentAccountKeyType = $credentialVersionDetails.credentialVersion

        #Check this version is the opposite of what it was at the start
        if($existingAccountKeyType -eq 'primaryReadonly')
        {
            $currentAccountKeyType | Should -Be 'secondaryReadonly'
        }
        else
        {
            $currentAccountKeyType | Should -Be 'primaryReadonly'
        }

        #Check the key is not the same as it was at the start
        $currentAccountKeys = Get-AzCosmosDBAccountKey -ResourceGroupName $accountResourceGroupName -Name $accountName -Type 'ReadOnlyKeys' -DefaultProfile $resourceContext
        $currentAccountKey = ($currentAccountKeys.GetEnumerator() | Where-Object { $_.Name -like "*$currentAccountKeyType*" }).Value
        $currentAccountKey | Should -Not -Be $existingAccountKey

        #Check what SACRED thinks is the new key is what it actually is
        $sacredAccountKey = $global:SACREDMockDestination['CosmosDBAccountKey']
        $sacredAccountKey | Should -Be $currentAccountKey

        #Check what SACRED thinks is the new connection string is what it actually is
        $currentAccountKeyConnectionStrings = Get-AzCosmosDBAccountKey -ResourceGroupName $accountResourceGroupName -Name $accountName -Type 'ConnectionStrings' -DefaultProfile $resourceContext
        $currentAccountKeyConnectionString = ($currentAccountKeyConnectionStrings.GetEnumerator() | Where-Object { $_.Value -like "*$sacredAccountKey*" }).Value
        $sacredAccountKeyConnectionString = $global:SACREDMockDestination['CosmosDBConnectionString']
        $sacredAccountKeyConnectionString | Should -Be $currentAccountKeyConnectionString
    }

    It 'Rotates an Azure Cosmos DB read-write account key' {
        $rotationJobDefinitionJSON = '
        {
            "cosmosDBAccount": {
                "accountName": "@@COSMOSDB_ACCOUNT_NAME@@",
                "accountResourceGroupName":  "@@COSMOSDB_ACCOUNT_RESOURCE_GROUP_NAME@@",
                "keyType": "readwrite"
            },
            "rotationSchedule":  "never",
            "update": {
                "mock": {}
            }
        }
        '
        $rotationJobDefinitionJSON = Merge-SACREDTokensIntoRotationJobDefinition -RotationJobDefinitionJSON $rotationJobDefinitionJSON -TokenFilePath $TokenFilePath

        Register-SACREDRotationJobDefinition -RotationJobDefinitionJSON $rotationJobDefinitionJSON

        #Get the existing key that we are about to rotate, which is not the one SACRED currently thinks is active
        $rotationJobDefinition = ConvertFrom-Json $rotationJobDefinitionJSON
        $accountName = $rotationJobDefinition.cosmosDBAccount.accountName
        $accountResourceGroupName = $rotationJobDefinition.cosmosDBAccount.accountResourceGroupName
        $rotationJobName = "AzureCosmosDB_$accountResourceGroupName`_$accountName`_ReadWrite"
        $credentialVersionDetails = $global:SACREDStore.GetSACREDRotationJobCredentialVersionDetails($rotationJobName)
        $existingAccountKeyType = $credentialVersionDetails.credentialVersion
        $resourceContext = Get-SACREDAzureContextForResource -ResourceName $accountName -ResourceGroupName $accountResourceGroupName -ResourceType 'Microsoft.DocumentDB/databaseAccounts'
        $existingAccountKeys = Get-AzCosmosDBAccountKey -ResourceGroupName $accountResourceGroupName -Name $accountName -Type 'Keys' -DefaultProfile $resourceContext
        $existingAccountKey = ($existingAccountKeys.GetEnumerator() | Where-Object { $_.Name -notlike "*$existingAccountKeyType*" }).Value

        #Rotate the key
        Invoke-SACREDRotationJob -RotationJobName $rotationJobName

        #Get the name of the version of the key SACRED currently thinks is active
        $credentialVersionDetails = $global:SACREDStore.GetSACREDRotationJobCredentialVersionDetails($rotationJobName)
        $currentAccountKeyType = $credentialVersionDetails.credentialVersion

        #Check this version is the opposite of what it was at the start
        if($existingAccountKeyType -eq 'primary')
        {
            $currentAccountKeyType | Should -Be 'secondary'
        }
        else
        {
            $currentAccountKeyType | Should -Be 'primary'
        }

        #Check the key is not the same as it was at the start
        $currentAccountKeys = Get-AzCosmosDBAccountKey -ResourceGroupName $accountResourceGroupName -Name $accountName -Type 'Keys' -DefaultProfile $resourceContext
        $currentAccountKey = ($currentAccountKeys.GetEnumerator() | Where-Object { ($_.Name -like "*$currentAccountKeyType*") -and ($_.Name -notlike "*readonly*") }).Value
        $currentAccountKey | Should -Not -Be $existingAccountKey

        #Check what SACRED thinks is the new key is what it actually is
        $sacredAccountKey = $global:SACREDMockDestination['CosmosDBAccountKey']
        $sacredAccountKey | Should -Be $currentAccountKey

        #Check what SACRED thinks is the new connection string is what it actually is
        $currentAccountKeyConnectionStrings = Get-AzCosmosDBAccountKey -ResourceGroupName $accountResourceGroupName -Name $accountName -Type 'ConnectionStrings' -DefaultProfile $resourceContext
        $currentAccountKeyConnectionString = ($currentAccountKeyConnectionStrings.GetEnumerator() | Where-Object { $_.Value -like "*$sacredAccountKey*" }).Value
        $sacredAccountKeyConnectionString = $global:SACREDMockDestination['CosmosDBConnectionString']
        $sacredAccountKeyConnectionString | Should -Be $currentAccountKeyConnectionString
    }
}