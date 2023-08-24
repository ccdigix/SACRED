<div align="center">
    <p>
        <a align="center" href="" target="_blank">
            <img width="20%" src="../SACRED.png">
        </a>
    </p>
![version](https://img.shields.io/powershellgallery/v/SACRED.Update.Azure.KeyVault)
![license](https://img.shields.io/github/license/ccdigix/SACRED)
</div>

## Azure Key Vault

When a rotation job occurs it produces a map containing useful information that can be assigned to various destinations, including Azure Key Vault.

### Secrets

The following JSON job definition snippet updates one or more secrets within an Azure Key Vault:

```json
{
    "...": ...,
    "rotationSchedule": "...",
    "update": {
        "keyVaults": [
            {
                "keyVaultName":  "NAME OF THE KEY VAULT",
                "secretMappings":  {
                    "KEY NAME OF THE ROTATION OUTPUT TO STORE":  "NAME OF THE KEY VAULT SECRET TO STORE THE INFO IN",
                    "ANOTHER KEY NAME OF THE ROTATION OUTPUT TO STORE":  "NAME OF ANOTHER KEY VAULT SECRET TO STORE THE INFO IN",
                    ...
                }
            }
        ]
    }
}
```

### Certificates

The following JSON job definition snippet updates one or more certificates within an Azure Key Vault:

```json
{
    "...": ...,
    "rotationSchedule": "...",
    "update": {
        "keyVaults": [
            {
                "keyVaultName":  "NAME OF THE KEY VAULT",
                "certificateMappings":  {
                    "KEY NAME OF A CERTIFICATE WITHIN THE ROTATION OUTPUT THAT WE WANT TO STORE":  "NAME OF THE KEY VAULT CERTIFICATE TO STORE IT IN",
                    "ANOTHER KEY NAME OF A CERTIFICATE WITHIN THE ROTATION OUTPUT THAT WE WANT TO STORE":  "NAME OF ANOTHER KEY VAULT CERTIFICATE TO STORE IT IN",
                    ...
                }
            }
        ]
    }
}
```