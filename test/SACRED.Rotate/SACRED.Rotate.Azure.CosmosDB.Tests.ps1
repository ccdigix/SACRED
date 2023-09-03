param 
(
    [Parameter(Mandatory=$true)]
    [string] $tokenFilePath
)

Describe 'SACRED.Rotate.Azure.CosmosDB' {

    BeforeAll {
        Initialize-SACREDEnvironment -LocalStoreBasePath $TestDrive -LocalLoggerBasePath $TestDrive -ConnectToAzure
    }

    It 'Rotates an Azure Cosmos DB account key' {
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
        $tokenValues = ConvertFrom-StringData (Get-Content $tokenFilePath -Raw)
        foreach($tokenValue in $tokenValues.GetEnumerator())
        {
            $rotationJobDefinitionJSON = $rotationJobDefinitionJSON.Replace($tokenValue.Name, $tokenValue.Value)
        }

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
    }
}