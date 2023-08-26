<div align="center">
    <p>
        <a align="center" href="" target="_blank">
            <img width="33%" src="../SACRED.png">
        </a>
    </p>

[![version](https://img.shields.io/powershellgallery/v/SACRED.Rotate.Azure.CosmosDB)](https://www.powershellgallery.com/packages/SACRED.Rotate.Azure.CosmosDB)
[![license](https://img.shields.io/github/license/ccdigix/SACRED)](https://opensource.org/license/mit/)
</div>

## Azure Cosmos DB

### Read-only account keys

The following JSON job definition snippet rotates the read-only account keys of an Azure Cosmos DB:

```json
{
    "cosmosDBAccount": {
        "accountName": "NAME OF THE COSMOS DB ACCOUNT",
        "accountResourceGroupName": "RESOURCE GROUP THAT CONTAINS THE COSMOS DB ACCOUNT",
        "keyType": "readonly"
    },
    "rotationSchedule": "...",
    "update": {
        ...
    }
}
```

### Read-write account keys

The following JSON job definition snippet rotates the read-write account keys of an Azure Cosmos DB:

```json
{
    "cosmosDBAccount": {
        "accountName": "NAME OF THE COSMOS DB ACCOUNT",
        "accountResourceGroupName": "RESOURCE GROUP THAT CONTAINS THE COSMOS DB ACCOUNT",
        "keyType": "readwrite"
    },
    "rotationSchedule": "...",
    "update": {
        ...
    }
}
```

### Outputs

When a rotation job occurs it produces a map containing useful information that can be assigned to various destinations. This rotation type outputs:

| Key Name | Description |
| ------------- | ------------- |
| CosmosDBAccountKey | The newly generated Cosmos DB account key. |
| CosmosDBConnectionString | The connection string for the Cosmos DB account, containing the newly generated account key. |