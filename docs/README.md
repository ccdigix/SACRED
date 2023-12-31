<div align="center">
    <p>
        <a align="center" href="" target="_blank">
            <img width="50%" src="SACRED.png">
        </a>
    </p>

[![version](https://img.shields.io/powershellgallery/v/SACRED)](https://www.powershellgallery.com/packages/SACRED)
[![license](https://img.shields.io/github/license/ccdigix/SACRED)](https://opensource.org/license/mit/)
</div>

## 👋 Hello!

The Securely Automated Credentials product (SACRED) generates and rotates a wide range of different credential types, with the option of updating the applications that use them. It comes with a fully functional [web server](podeServer/Index.md) that exposes SACRED functionality over RESTful APIs.

All SACRED assets are open-source and distributed under the [MIT License](https://opensource.org/license/mit/).

## 🔧 Installation

### From the PowerShell Gallery

To install the latest version of the SACRED PowerShell modules, open up a prompt or terminal and execute the following:

```powershell
Install-Module SACRED
```

> [!NOTE]
> To install the modules for the current user only use `Install-Module SACRED -Scope CurrentUser` instead.

### From the source code

To install the SACRED PowerShell modules directly from the source code first clone a version of the SACRED repo by executing...

```bash
git clone https://github.com/ccdigix/SACRED.git
```

...and then from within the `src` directory of the repo run the `LocalSACREDBuildAndDeploy.ps1` script.

### Dependencies

If making use of Azure functionality within SACRED, there is an assumption that the [Az](https://learn.microsoft.com/en-us/powershell/azure/new-azureps-module-az) PowerShell modules are already installed. If interacting with Entra (formerly known as Azure Active Directory) then you will also need the [Microsoft Graph](https://learn.microsoft.com/en-us/powershell/microsoftgraph/get-started?view=graph-powershell-1.0) modules. To run the SACRED Pode Server then you need to make sure [Pode](https://badgerati.github.io/Pode/Getting-Started/Installation/) is installed. If you plan on running the tests within SACRED (maybe for development purposes) then you will require the [Pester](https://pester.dev/) framework modules.

## 🤔 How does it work?

### Initialization

Before using SACRED setup its environment by using the `Initialize-SACREDEnvironment` function, which can take many parameters depending on the situation.

| To... | Then... |
| ------------- | ------------- |
| ...use the local file system SACRED store implementation | ...pass in 'Local' to the `-StoreType` parameter, along with the base path of the store to the `-LocalStoreBasePath` parameter (see [here](#store)) |
| ...use the local file system SACRED logger implementation  | ...pass in 'Local' to the `-LoggerType` parameter, along with the parent directory of the logs to the `-LocalLoggerBasePath` parameter (see [here](#logs)) |
| ...use the SACRED secret store implementation that searches environment variables | ...pass in 'EnvironmentVariable' to the `-SecretStoreType` parameter (see [here](#secret-store)) |
| ...connect to Azure with an interactive login | ...pass in the `-ConnectToAzure` switch parameter along with the tenant ID in the `-AzureTenantId` parameter |
| ...connect to Azure with a managed identity | ...pass in the `-ConnectToAzure` and `-UseAzureManagedIdentity` switch parameters |
| ...connect to Azure with a service principal and its secret | ...pass in the `-ConnectToAzure` switch parameter along with the tenant ID in the `-AzureTenantId` parameter, as well as the service principal's client ID and secret in the `-AzureServicePrincipalClientId` / `-AzureServicePrincipalClientSecret` parameters respectively |
| ...connect to Azure with a service principal and its certificate | ...pass in the `-ConnectToAzure` switch parameter along with the tenant ID in the `-AzureTenantId` parameter, as well as the service principal's client ID and certificate thumbprint in the `-AzureServicePrincipalClientId` / `-AzureServicePrincipalClientCertificateThumbprint` parameters respectively |

> [!NOTE]
> All of the selected parameters must be passed into a single call to `Initialize-SACREDEnvironment`. For example to use the local implementations of the SACRED store and logger, as well as connecting to Azure interactively, execute `Initialize-SACREDEnvironment -StoreType Local -LocalStoreBasePath 'SomeLocalPath' -LoggerType Local -LocalLoggerBasePath 'AnotherLocalPath' -ConnectToAzure -AzureTenantId 'MyAzureTenantID'`.

### Rotation jobs

SACRED operates with the concept of rotation jobs. A rotation job definition is written in JSON and specifies:

1. The details of the credential to rotate.
1. The name of a schedule to link the rotation job to. More info [here](#schedules).
1. The details of the destination(s) to update with the newly rotated credential.

This corresponds to a JSON layout akin to:

```json
{
    "ResourceCredentialToRotate": {
        Details To Identify The Resource
    },
    "rotationSchedule": "RotationScheduleName",
    "update": {
        "ResourceType1ToUpdateWithCredential": [
            {
                Details To Identify First Instance Of Resource Type 1
            },
            {
                Details To Identify Last Instance Of Resource Type 1
            }
        ],
        "ResourceTypeNToUpdateWithCredential": [
            {
                Details To Identify First Instance Of Resource Type N
            },
            {
                Details To Identify Last Instance Of Resource Type N
            }
        ]
    }
}
```

For example the definition JSON to rotate an Azure Cosmos DB account key on a weekly schedule, whilst updating an Azure Key Vault with the new key would be:

```json
{
    "cosmosDBAccount": {
        "accountName": "mycosmosdb",
        "accountResourceGroupName": "mycosmosdbresourcegroup",
        "keyType": "readonly"
    },
    "rotationSchedule": "weekly",
    "update": {
        "keyVaults": [
            {
                "keyVaultName": "mykeyvault",
                "secretMappings":  {
                    "secretnametoholdkey": "CosmosDBAccountKey",
                    "secretnametoholdconnectionstring": "CosmosDBConnectionString"
                }
            }
        ]
    }
}
```

The above example shows a subtle feature of a SACRED rotation job - that a rotation may not just generate a new credential but also additional information that may be of use (such as the Cosmos DB's new connection string). The destinations to be updated then pick out the items that they want to use (such as the Key Vault storing both the 'CosmosDBAccountKey' and 'CosmosDBConnectionString' in secrets). A full list of [credential](credentialTypes/Index.md) and [destination](destinationTypes/Index.md) types are maintained, and examples of what is possible can be found by browsing through the test cases in the code repo (found within the sub-directories under the `test` directory).

To register a rotation job with SACRED a string containing the JSON definition must be sent to the `Register-SACREDRotationJobDefinition` function alongside an optional name for the job:

```powershell
Register-SACREDRotationJobDefinition -RotationJobDefinitionJSON $variableContainingJSONString -RotationJobName 'ReallyGoodJobName'
```
> [!NOTE]
> If no job name is provided a suitable one will be auto-generated.

Conversely, to delete a rotation job definition execute:

```powershell
Unregister-SACREDRotationJobDefinition -RotationJobName 'ReallyGoodJobName'
```

To run the rotation job execute:

```powershell
Invoke-SACREDRotationJob -RotationJobName 'ReallyGoodJobName'
```

To run all of the rotation jobs within a particular schedule execute:

```powershell
Invoke-SACREDRotationSchedule -RotationScheduleName 'SomeScheduleName'
```

### Store

SACRED makes use of an internal store to keep track of rotation job definitions, their schedules, and additional information such as which version of a credential key is currently being used. The type of store used is controlled by the `-StoreType` parameter in the `Initialize-SACREDEnvironment` function, and by default the 'Local' store implementation is utilised. This simply uses the local file system as the store, keeping all files under the directory specified by the `-LocalStoreBasePath` parameter.

### Logs

SACRED provides full logging of everything it does, including warnings and errors. The type of logger used is controlled by the `-LoggerType` parameter in the `Initialize-SACREDEnvironment` function, and by default the 'Local' logger implementation is utilised. This logs all messages to the console, in addition to a file under the directory specified by the `-LocalLoggerBasePath` parameter.

### Secret Store

Sometimes SACRED will encounter the need to login or authorise to systems that need their credential rotated or that need updating with a new version of a credential. SACRED uses the concept of a 'secret store' to hold sensitive information required for these authorisations, with the type of secret store controlled by the `-SecretStoreType` parameter in the `Initialize-SACREDEnvironment` function. By default the 'EnvironmentVariable' store implementation is used, which searches through the session's environment variables for the value of the specified secret.

### Schedules

> [!IMPORTANT]
> The core SACRED modules do not provide a scheduler to orchestrate rotation job executions, however the [SACRED Pode Server](podeServer/Index.md) does.

Whilst SACRED does not include a scheduler, it instead manages which job definitions are linked to which schedules and provides a means for an external tool to call `Invoke-SACREDRotationSchedule` to execute them. Therefore the name of the schedules can be anything that makes sense to the user.

The [SACRED Pode Server](podeServer/Index.md) provides a mechanism to implement schedules with a Cron syntax via its `server.psd1` configuration file.

Another example would be to use the built-in Windows task scheduler. To trigger a 9am 'daily' SACRED schedule (logging into Azure with a managed identity) you could execute:

```powershell
$initCommand = "Initialize-SACREDEnvironment -StoreType Local -LocalStoreBasePath 'SomeLocalPath' -LoggerType Local -LocalLoggerBasePath 'AnotherLocalPath' -ConnectToAzure -AzureTenantId 'MyAzureTenantID' -UseAzureManagedIdentity"

$runScheduleCommand = "Invoke-SACREDRotationSchedule -RotationScheduleName 'daily'"

$command = "powershell.exe"
$arguments = "-Command ""$initCommand; $runScheduleCommand"""

$action = New-ScheduledTaskAction -Execute $command -Argument $arguments
$trigger = New-ScheduledTaskTrigger -Daily -At '9:00 AM'
$principal = New-ScheduledTaskPrincipal -UserId 'DOMAIN\someuser'
$task = New-ScheduledTask -Action $action -Principal $principal -Trigger $trigger
Register-ScheduledTask 'DailySACREDSchedule' -InputObject $task
```

More information about configuring the Windows task scheduler can be found [here](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtask).

## 🤗 Contributing

Everyone is welcome to contribute to and improve SACRED, in fact we actively encourage it. Please read our [contribution guidelines](CONTRIBUTING.md) to find out how best to modify the codebase and help us with the current wishlist of [enhancements](https://github.com/ccdigix/SACRED/labels/enhancement). We look forward to receiving your pull request!