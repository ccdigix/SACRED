<div align="center">
    <p>
        <a align="center" href="" target="_blank">
            <img width="33%" src="../SACRED.png">
        </a>
    </p>

[![version](https://img.shields.io/powershellgallery/v/SACRED.Job)](https://www.powershellgallery.com/packages/SACRED.Job)
[![license](https://img.shields.io/github/license/ccdigix/SACRED)](https://opensource.org/license/mit/)
</div>

## Mock

> [!IMPORTANT]
> This credential type is designed to be solely used when testing SACRED.

The following JSON job definition snippet does not rotate anything; it simply passes through whatver its input is as the generated credential info.

```json
{
    "mock": {
        "CREDENTIAL INFO KEY 1": "CREDENTIAL INFO VALUE 1",
        "CREDENTIAL INFO KEY 2": "CREDENTIAL INFO VALUE 2",
        ...
    },
    "rotationSchedule": "...",
    "update": {
        ...
    }
}
```

### Outputs

When a rotation job occurs it produces a map containing useful information that can be assigned to various destinations. This rotation type simply creates this map as a copy of the inputs it receives.