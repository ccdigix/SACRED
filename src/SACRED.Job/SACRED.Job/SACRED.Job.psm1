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

using module SACRED.Store
using module SACRED.Log

Function Register-SACREDRotationJobDefinition (
    [Parameter(Mandatory=$false)]
    [string] $RotationJobName = '',

    [Parameter(Mandatory=$true)]
    [string] $RotationJobDefinitionJSON
)
{
    <#
        .SYNOPSIS
        Registers a rotation job definition with SACRED.

        .DESCRIPTION
        Registers a rotation job definition with SACRED. The definition is stored in the SACRED store and can be used to create rotation jobs.

        .PARAMETER RotationJobName
        The name of the rotation job. If not specified, a name will be generated based on the definition.

        .PARAMETER RotationJobDefinitionJSON
        The rotation job definition in JSON format.

        .INPUTS
        None

        .OUTPUTS   
        None
    #>

    try
    {
        $global:SACREDLogger.Info("Registering rotation job with JSON definition $RotationJobDefinitionJSON")
        $rotationJobDefinition = ConvertFrom-Json $RotationJobDefinitionJSON
        $credentialVersionDetails = [SACREDCredentialVersionDetails]::new()
        if($rotationJobDefinition.cosmosDBAccount)
        {
            $global:SACREDLogger.Info("Rotation job is for an Azure Cosmos DB account key.")
            #TODO: validate all required properties are present
            if($rotationJobDefinition.cosmosDBAccount.keyType -eq 'readonly')
            {
                $credentialVersionDetails.credentialVersion = 'primaryReadonly'
            }
            elseif($rotationJobDefinition.cosmosDBAccount.keyType -eq 'readwrite')
            {
                $credentialVersionDetails.credentialVersion = 'primary'
            }
            if($RotationJobName -eq '') { $RotationJobName = Build-SACREDCosmosDBRotationJobName -RotationJobDefinition $rotationJobDefinition } 
        }
        elseif($rotationJobDefinition.entraServicePrincipal)
        {
            if($rotationJobDefinition.entraServicePrincipal.credentialType -eq 'secret')
            {
                $global:SACREDLogger.Info("Rotation job is for an Entra Service Principal secret.")
            }
            elseif($RotationJobDefinition.entraServicePrincipal.credentialType -eq 'selfsignedcertificate')
            {
                $global:SACREDLogger.Info("Rotation job is for an Entra Service Principal self-signed certifcate.")
            }
            if($RotationJobName -eq '') { $RotationJobName = Build-SACREDEntraServicePrincipalRotationJobName -RotationJobDefinition $rotationJobDefinition } 
        }
        elseif($rotationJobDefinition.mock)
        {
            $global:SACREDLogger.Info("Rotation job is for a mock credential.")
            if($RotationJobName -eq '') { $RotationJobName = 'MockCredential' }
        }
        else 
        {
            throw "No supported credential type found in definition."
        }   
        $global:SACREDLogger.Info("Rotation job name will be $RotationJobName.")

        $global:SACREDStore.SetSACREDRotationJobDefinition($RotationJobName, $rotationJobDefinition)
        if($credentialVersionDetails.credentialVersion)
        {
            $existingCredentialVersionDetails = $global:SACREDStore.GetSACREDRotationJobCredentialVersionDetails($RotationJobName)
            if(!$existingCredentialVersionDetails)
            {
                $global:SACREDLogger.Info("Creating new credential version details.")
                $global:SACREDStore.SetSACREDRotationJobCredentialVersionDetails($RotationJobName, $credentialVersionDetails)
            }
            else
            {
                $global:SACREDLogger.Info("Credential version details already exist so skipping update.")
            }
        }
    }
    catch
    {
        Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
        $errorDetails = (Resolve-AzError -Last | Out-String)
        $global:SACREDLogger.Error($errorDetails)
        throw $_
    }
}

Function Unregister-SACREDRotationJobDefinition (
    [Parameter(Mandatory=$false)]
    [string] $RotationJobName = ''
)
{
    <#
        .SYNOPSIS
        Unregisters a rotation job definition from SACRED.

        .DESCRIPTION
        Unregisters a rotation job definition from SACRED. The definition is removed from the SACRED store and any rotation jobs created from it will no longer be able to run.

        .PARAMETER RotationJobName
        The name of the rotation job.

        .INPUTS
        None

        .OUTPUTS   
        None
    #>

    try
    {
        $global:SACREDLogger.Info("Unregistering rotation job $RotationJobName.")
        $global:SACREDStore.RemoveSACREDRotationJobDefinition($RotationJobName)
        $global:SACREDStore.RemoveSACREDRotationJobCredentialVersionDetails($RotationJobName)
    }
    catch
    {
        Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
        $errorDetails = (Resolve-AzError -Last | Out-String)
        $global:SACREDLogger.Error($errorDetails)
        throw $_
    }
}

Function Invoke-SACREDRotationSchedule (
    [Parameter(Mandatory=$true)]
    [string] $RotationScheduleName
)
{
    <#
        .SYNOPSIS
        Runs all rotation jobs within a schedule.

        .DESCRIPTION
        Runs all rotation jobs within a schedule. The jobs are run in sequence one after the other.

        .PARAMETER RotationScheduleName
        The name of the rotation schedule.

        .INPUTS
        None

        .OUTPUTS   
        None
    #>

    $global:SACREDLogger.Info("Running all rotation jobs on the schedule $RotationScheduleName.")
    $rotationJobNames = $global:SACREDStore.GetSACREDScheduledRotationJobNames($RotationScheduleName)
    $global:SACREDLogger.Info("Found rotation jobs $rotationJobNames.")
    $errorMessages = @()
    foreach($rotationJobName in $rotationJobNames)
    {
        try
        {
            Invoke-SACREDRotationJob -RotationJobName $rotationJobName
        }
        catch
        {
            $errorMessages += "$rotationJobName failed with $($_.Exception.Message)"
        }
    }

    if($errorMessages.Count -gt 0)
    {
        $errorMessage = $errorMessages -join "; "
        throw $errorMessage
    }
}

Function Invoke-SACREDRotationJob (
    [Parameter(Mandatory=$true)]
    [string] $RotationJobName
)
{
    <#
        .SYNOPSIS
        Runs a rotation job.

        .DESCRIPTION
        Runs a rotation job.

        .PARAMETER RotationJobName
        The name of the rotation job.

        .INPUTS
        None

        .OUTPUTS   
        None
    #>

    try
    {
        $global:SACREDLogger.Info("Running rotation job $RotationJobName.")
        $rotationJobDefinition = $global:SACREDStore.GetSACREDRotationJobDefinition($RotationJobName)
        if(!$rotationJobDefinition)
        {
            $errorMessage = "No rotation job definition found for rotation job $RotationJobName."
            throw $errorMessage
        }

        #Rotate
        if($rotationJobDefinition.cosmosDBAccount)
        {
            $global:SACREDLogger.Info("Rotation job $RotationJobName is for an Azure Cosmos DB account key.")
            $credentialInfo = Invoke-SACREDCosmosDBKeyRotation -AccountName $rotationJobDefinition.cosmosDBAccount.accountName -AccountResourceGroupName $rotationJobDefinition.cosmosDBAccount.accountResourceGroupName -RotationJobName $RotationJobName
        }
        elseif($rotationJobDefinition.entraServicePrincipal)
        {
            $servicePrincipalDisplayName = $rotationJobDefinition.entraServicePrincipal.displayName
            $credentialValidityInDays = $rotationJobDefinition.entraServicePrincipal.credentialValidityInDays
            $credentialValidityInHours = $rotationJobDefinition.entraServicePrincipal.credentialValidityInHours
            if($rotationJobDefinition.entraServicePrincipal.credentialType -eq 'secret')
            {
                $global:SACREDLogger.Info("Rotation job $RotationJobName is for an Entra Service Principal secret.")

                if($credentialValidityInHours)
                {
                    $credentialInfo = Invoke-SACREDEntraServicePrincipalSecretRotation -ServicePrincipalDisplayName $servicePrincipalDisplayName -SecretValidityInHours $credentialValidityInHours
                }
                elseif($credentialValidityInDays)
                {
                    $credentialInfo = Invoke-SACREDEntraServicePrincipalSecretRotation -ServicePrincipalDisplayName $servicePrincipalDisplayName -SecretValidityInDays $credentialValidityInDays
                }
                else
                {
                    $credentialInfo = Invoke-SACREDEntraServicePrincipalSecretRotation -ServicePrincipalDisplayName $servicePrincipalDisplayName
                }
            }
            elseif($rotationJobDefinition.entraServicePrincipal.credentialType -eq 'selfsignedcertificate')
            {
                $global:SACREDLogger.Info("Rotation job $RotationJobName is for an Entra Service Principal self-signed certificate.")

                if($credentialValidityInHours)
                {
                    $credentialInfo = Invoke-SACREDEntraServicePrincipalSelfSignedCertificateRotation -ServicePrincipalDisplayName $servicePrincipalDisplayName -CertificateValidityInHours $credentialValidityInHours
                }
                elseif($credentialValidityInDays)
                {
                    $credentialInfo = Invoke-SACREDEntraServicePrincipalSelfSignedCertificateRotation -ServicePrincipalDisplayName $servicePrincipalDisplayName -CertificateValidityInDays $credentialValidityInDays
                }
                else
                {
                    $credentialInfo = Invoke-SACREDEntraServicePrincipalSelfSignedCertificateRotation -ServicePrincipalDisplayName $servicePrincipalDisplayName
                }
            }
        }
        elseif($rotationJobDefinition.mock)
        {
            $global:SACREDLogger.Info("Rotation job $RotationJobName is for a mock credential, inputs will therefore be passed straight through as the generated credential info.")
            $credentialInfo = @{}
            foreach($property in $rotationJobDefinition.mock.psobject.properties.name)
            {
                if($property.EndsWith('AsBytes'))
                {
                    $credentialInfo[$property] = [System.Convert]::FromBase64String($rotationJobDefinition.mock.$property)
                }
                else
                {
                    $credentialInfo[$property] = $rotationJobDefinition.mock.$property
                }
            }
        }
        else 
        {
            $errorMessage = 'No supported credential type found in definition.'
            $global:SACREDLogger.Error($errorMessage)
            throw $errorMessage
        }

        #Update
        if($rotationJobDefinition.update.keyVaults)
        {
            foreach($keyVault in $rotationJobDefinition.update.keyVaults)
            {
                $global:SACREDLogger.Info("New credential info needs to go to an Azure Key Vault.")
                $keyVaultName = $keyVault.keyVaultName
                $secretMappings = $keyVault.secretMappings
                $certificateMappings = $keyVault.certificateMappings

                if($secretMappings)
                {
                    Publish-SACREDAzureKeyVaultSecrets -KeyVaultName $keyVaultName -SecretMappings $secretMappings -SecretValues $credentialInfo
                }

                if($certificateMappings)
                {
                    Publish-SACREDAzureKeyVaultCertificates -KeyVaultName $keyVaultName -CertificateMappings $certificateMappings -CertificateValues $credentialInfo
                }
            }
        }
        elseif($rotationJobDefinition.update.windowsCertificateStores)
        {
            foreach($windowsCertificateStore in $rotationJobDefinition.update.windowsCertificateStores)
            {
                $global:SACREDLogger.Info("New credential info needs to go to a Windows certificate store.")
                $storeLocation = $windowsCertificateStore.storeLocation
                $storeName = $windowsCertificateStore.storeName
                $certificateMappings = $windowsCertificateStore.certificateMappings
                Publish-SACREDWindowsCertificateStoreCertificates -CertificateStoreLocation $storeLocation -CertificateStoreName $storeName -CertificateMappings $certificateMappings -CertificateValues $credentialInfo
            }
        }
        elseif($rotationJobDefinition.update.mock)
        {
            $global:SACREDLogger.Info("New credential info needs to go to a mock destination, it will therefore be stored in a global variable within this session.")
            $global:SACREDMockDestination = $credentialInfo
        }

        #Cleanup
        if($rotationJobDefinition.entraServicePrincipal)
        {
            $servicePrincipalDisplayName = $rotationJobDefinition.entraServicePrincipal.displayName
            $mostRecentCredentialsToRetain = $rotationJobDefinition.entraServicePrincipal.mostRecentCredentialsToRetain

            if($rotationJobDefinition.entraServicePrincipal.credentialType -eq 'secret')
            {
                $global:SACREDLogger.Info("Removing older secrets on the Entra Service Principal.")

                if($mostRecentCredentialsToRetain)
                {
                    Remove-SACREDOldEntraServicePrincipalSecrets -ServicePrincipalDisplayName $servicePrincipalDisplayName -MostRecentSecretsToRetain $mostRecentCredentialsToRetain
                }
                else
                {
                    Remove-SACREDOldEntraServicePrincipalSecrets -ServicePrincipalDisplayName $servicePrincipalDisplayName
                }
            }
            elseif($rotationJobDefinition.entraServicePrincipal.credentialType -eq 'selfsignedcertificate')
            {
                $global:SACREDLogger.Info("Removing older certificates on the Entra Service Principal.")

                if($mostRecentCredentialsToRetain)
                {
                    Remove-SACREDOldEntraServicePrincipalSelfSignedCertificates -ServicePrincipalDisplayName $servicePrincipalDisplayName -MostRecentCertificatesToRetain $mostRecentCredentialsToRetain
                }
                else
                {
                    Remove-SACREDOldEntraServicePrincipalSelfSignedCertificates -ServicePrincipalDisplayName $servicePrincipalDisplayName
                }
            }
        }
    }
    catch
    {
        Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
        $errorDetails = (Resolve-AzError -Last | Out-String)
        $global:SACREDLogger.Error($errorDetails)
        throw $_
    }
}