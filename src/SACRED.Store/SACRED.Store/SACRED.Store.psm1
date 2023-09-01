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

Class SACREDStore
{
    [SACREDCredentialVersionDetails] GetSACREDRotationJobCredentialVersionDetails([string] $rotationJobName)
    {
        return $null
    }

    [void] SetSACREDRotationJobCredentialVersionDetails([string] $rotationJobName, [SACREDCredentialVersionDetails] $credentialVersionDetails)
    {
    }

    [void] RemoveSACREDRotationJobCredentialVersionDetails([string] $rotationJobName)
    {
    }

    [SACREDRotationJobDefinition] GetSACREDRotationJobDefinition([string] $rotationJobName)
    {
        return $null
    }

    [void] SetSACREDRotationJobDefinition([string] $rotationJobName, [SACREDRotationJobDefinition] $rotationJobDefinition)
    {
    }

    [void] RemoveSACREDRotationJobDefinition([string] $rotationJobName)
    {
    }

    [string[]] GetSACREDScheduledRotationJobNames([string] $rotationScheduleName)
    {
        return $null
    }
}

Class SACREDCredentialVersionDetails
{
    [string] $credentialVersion
}

Class SACREDRotationJobDefinition
{
    [string] $rotationSchedule
    [SACREDCosmosDBAccountDefinition] $cosmosDBAccount
    [SACREDEntraServicePrincipalDefinition] $entraServicePrincipal
    [SACREDUpdateDefinition] $update
}

Class SACREDCosmosDBAccountDefinition
{
    [string] $accountName
    [string] $accountResourceGroupName
    [string] $keyType
}

Class SACREDEntraServicePrincipalDefinition
{
    [string] $displayName
    [string] $credentialType
    [int] $credentialValidityInDays
    [int] $credentialValidityInHours 
    [int] $mostRecentCredentialsToRetain
}

Class SACREDUpdateDefinition
{
    [SACREDKeyVaultDefinition[]] $keyVaults
}

Class SACREDKeyVaultDefinition
{
    [string] $keyVaultName
    [PSCustomObject] $secretMappings
    [PSCustomObject[]] $certificateMappings
}