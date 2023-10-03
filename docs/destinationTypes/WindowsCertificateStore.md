<div align="center">
    <p>
        <a align="center" href="" target="_blank">
            <img width="33%" src="../SACRED.png">
        </a>
    </p>

[![version](https://img.shields.io/powershellgallery/v/SACRED.Update.Windows.CertificateStore)](https://www.powershellgallery.com/packages/SACRED.Update.Windows.CertificateStore)
[![license](https://img.shields.io/github/license/ccdigix/SACRED)](https://opensource.org/license/mit/)
</div>

## Windows Certificate Store

When a rotation job occurs it produces a map containing useful information that can be assigned to various destinations, including the Windows certificate store.

The following JSON job definition snippet updates one or more certificates within a Windows certificate store:

```json
{
    "...": ...,
    "rotationSchedule": "...",
    "update": {
        "windowsCertificateStores": [
            {
                "storeLocation": "LOCATION OF THE WINDOWS CERTIFICATE STORE E.G. CURRENTUSER",
                "storeName": "NAME OF THE WINDOWS CERTIFICATE STORE E.G. MY",
                "certificateMappings":  [
                    {
                        "certificateData": "KEY NAME OF THE CERTIFICATE DATA WITHIN THE ROTATION OUTPUT THAT WE WANT TO STORE",
                        "password": "OPTIONAL KEY NAME OF THE CERTIFICATE PASSWORD WITHIN THE ROTATION OUTPUT"
                    },
                    ...
                ]
            }
        ]
    }
}
```