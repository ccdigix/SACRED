<div align="center">
    <p>
        <a align="center" href="" target="_blank">
            <img width="20%" src="SACRED.png">
        </a>
    </p>
![version](https://img.shields.io/powershellgallery/v/SACRED)
![license](https://img.shields.io/github/license/ccdigix/SACRED)
</div>

# Contributing

## 🧑‍💻 General

This project is open-source and is licensed as such, specifically by the [MIT License](https://opensource.org/license/mit/). A copy of this can be found within the repo and should be included as a comment at the top of any source file produced. Please add your name to the copyright part of the license header on any file you modify so you can receive rightful acknowledgement. Also don't forget to add your name to the copyright part of the license header on any associated .psd1 file, as well as to the `Author` and `Copyright` attributes within the .psd1.

There's no real code style as such to adhere to when making changes, but you will probably notice patterns that make sense to follow when doing modifications. All function names must follow the [approved PowerShell verbs convention](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands). A header comment should be included within each new function, detailing what it does and the parameters it takes.

Log as much information as you can by making use of the `SACREDLogger` object, accessed as a global variable (`$global:SACREDLogger`).

## 🔑 New credential types

When adding a new credential type that can be rotated to SACRED please consider the following:

- Update the classes within the `SACRED.Store` module so that the new credential type can be parsed when it is included in rotation job definition JSON.
- Create a new module directory for the functionality, somewhere under the SACRED.Rotate directory.
- Name the module directory (and its contained .psm1 and .psd1 files) appropriately so the functionality it provides is well understood.
- Implement a function that generates a default name for a rotation job definition (for example look at `Build-SACREDCosmosDBRotationJobName` in the `SACRED.Rotate.Azure.CosmosDB` module).
- Update the `Register-SACREDRotationJobDefinition` function in the `SACRED.Job` module to use this function.
- For rotation to work efficiently, there should ideally be two valid versions of a credential that exist at one time. The current version being used should be tracked within the SACRED store - it can be retrieved by calling `GetSACREDRotationJobCredentialVersionDetails` and set using `SetSACREDRotationJobCredentialVersionDetails`.
- Implement a function in the new module that regenerates a specific version of the credential and returns it to the caller in a map along with any other useful information associated with the credential (for example look at `Invoke-SACREDCosmosDBKeyRegeneration` in the `SACRED.Rotate.Azure.CosmosDB` module).
- Implement a function that combines the previous two points - it looks up which version of the credential is being used (using `$global:SACREDStore`), regenerates the other version of the credential, and then updates the SACRED store with the new version name of the credential being used (for example look at `Invoke-SACREDCosmosDBKeyRotation` in the `SACRED.Rotate.Azure.CosmosDB` module).
- Update the `Invoke-SACREDRotationJob` function in the `SACRED.Job` module to use this function.

## 🏦 New destination types

When adding a new destination type that can be updated by SACRED please consider the following:

- Update the classes within the `SACRED.Store` module so that the new destination type can be parsed when it is included in rotation job definition JSON.
- Create a new module directory for the functionality, somewhere under the SACRED.Update directory.
- Name the module directory (and its contained .psm1 and .psd1 files) appropriately so the functionality it provides is well understood.
- Implement a function that updates the destination with a specific piece of information generated from a credential type rotation, remembering to delete/invalidate the previous version of the information that was already there (for example look at `Publish-SACREDAzureKeyVaultSecret` in the `SACRED.Update.Azure.KeyVault` module).
- Implement a function that iterates over the mapping from credential type information to destination location, and uses the previous function to update the destination (for example look at `Publish-SACREDAzureKeyVaultSecrets` in the `SACRED.Update.Azure.KeyVault` module).
- Update the `Invoke-SACREDRotationJob` function in the `SACRED.Job` module to use this function.

## 📦 New stores

When adding a new SACRED store type please consider the following:

- Create a new module directory for the functionality, somewhere under the SACRED.Store directory.
- Name the module directory (and its contained .psm1 and .psd1 files) appropriately so the functionality it provides is well understood.
- Create a class that extends `SACREDStore` from the `SACRED.Store` module, overriding all of its methods (for example look at the `SACREDLocalStore` class in the `SACRED.Store.Local` module).
- Update the `SACREDStoreType` enum in the `SACRED.Util` module to offer this new class.
- Update the `Initialize-SACREDEnvironment` function in the `SACRED.Util` module so users can select this new store type when setting up their SACRED environment.

## ✒️ New loggers

When adding a new SACRED logger type please consider the following:

- Create a new module directory for the functionality, somewhere under the SACRED.Log directory.
- Name the module directory (and its contained .psm1 and .psd1 files) appropriately so the functionality it provides is well understood.
- Create a class that extends `SACREDLogger` from the `SACRED.Log` module, overriding the `Log` method (for example look at the `SACREDLocalLogger` class in the `SACRED.Log.Local` module).
- Update the `SACREDLoggerType` enum in the `SACRED.Util` module to offer this new class.
- Update the `Initialize-SACREDEnvironment` function in the `SACRED.Util` module so users can select this new logger type when setting up their SACRED environment.