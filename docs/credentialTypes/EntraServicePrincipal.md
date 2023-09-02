<div align="center">
    <p>
        <a align="center" href="" target="_blank">
            <img width="33%" src="../SACRED.png">
        </a>
    </p>

[![version](https://img.shields.io/powershellgallery/v/SACRED.Rotate.Azure.ServicePrincipal)](https://www.powershellgallery.com/packages/SACRED.Rotate.Azure.ServicePrincipal)
[![license](https://img.shields.io/github/license/ccdigix/SACRED)](https://opensource.org/license/mit/)
</div>

## Entra (Azure Active Directory) Service Principal

### Secrets

The following JSON job definition snippet rotates the secret of an Entra Service Principal:

```json
{
    "entraServicePrincipal": {
        "displayName": "NAME OF THE SERVICE PRINCIPAL",
        "credentialType": "secret",
        "credentialValidityInDays": "HOW MANY DAYS THE SECRET IS VALID FOR (DEFAULTS TO 365 IF NOT SET)",
        "mostRecentCredentialsToRetain": "HOW MANY OF THE MOST RECENT SECRETS TO KEEP ACTIVE ON EACH ROTATION (DEFAULTS TO 2 IF NOT SET)"
    },
    "rotationSchedule": "...",
    "update": {
        ...
    }
}
```

> [!NOTE]
> The validity length of the secret can alternatively be specified in hours by replacing `credentialValidityInDays` with `credentialValidityInHours`. Also the start time of a secret is used to measure how recent it is.

### Self-signed certificates

The following JSON job definition snippet rotates the self-signed certificate of an Entra Service Principal:

```json
{
    "entraServicePrincipal": {
        "displayName": "NAME OF THE SERVICE PRINCIPAL",
        "credentialType": "selfsignedcertificate",
        "credentialValidityInDays": "HOW MANY DAYS THE CERTIFICATE IS VALID FOR (DEFAULTS TO 365 IF NOT SET)",
        "mostRecentCredentialsToRetain": "HOW MANY OF THE MOST RECENT CERTIFICATES TO KEEP ACTIVE ON EACH ROTATION (DEFAULTS TO 2 IF NOT SET)"
    },
    "rotationSchedule": "...",
    "update": {
        ...
    }
}
```

> [!NOTE]
> The validity length of the certificate can alternatively be specified in hours by replacing `credentialValidityInDays` with `credentialValidityInHours`. Also the start time of a certificate is used to measure how recent it is.

### Outputs

When a rotation job occurs it produces a map containing useful information that can be assigned to various destinations. This rotation type outputs:

#### Secrets

| Key Name | Description |
| ------------- | ------------- |
| ServicePrincipalSecret | The newly generated Entra Service Principal secret. |
| ServicePrincipalSecretValidFrom | When the newly generated secret is valid from. |
| ServicePrincipalSecretValidTo | When the newly generated secret is valid to. |

#### Self-signed certificates

| Key Name | Description |
| ------------- | ------------- |
| ServicePrincipalPublicCertificate | The public part (.cer) of the newly generated Entra Service Principal self-signed certificate. |
| ServicePrincipalPrivateCertificate | The private part (.pfx) of the newly generated Entra Service Principal self-signed certificate. |
| ServicePrincipalPrivateCertificatePassword | The randomly generated password needed to access the private part of the newly generated Entra Service Principal self-signed certificate. |
| ServicePrincipalCertificateThumbprint | The thumbprint of the newly generated Entra Service Principal self-signed certificate. |
| ServicePrincipalCertificateValidFrom | When the newly generated self-signed certificate is valid from. |
| ServicePrincipalCertificateValidTo | When the newly generated self-signed certificate is valid to. |