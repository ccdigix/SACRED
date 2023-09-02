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
> This destination type is designed to be solely used when testing SACRED.

When a rotation job occurs it produces a map containing useful information that can be assigned to various destinations; this type stores this map in a global variable called `$global:SACREDMockDestination`.

The following JSON job definition snippet updates this global variable:

```json
{
    "...": ...,
    "rotationSchedule": "...",
    "update": {
        "mock": {}
    }
}
```