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

using module SACRED.Log

Function Publish-SACREDAzureKeyVaultSecrets (
    [Parameter(Mandatory=$true)]
    [string] $KeyVaultName,
    
    [Parameter(Mandatory=$true)]
    [PSCustomObject] $SecretMappings,
    
    [Parameter(Mandatory=$true)] 
    [PSCustomObject] $SecretValues
)
{
    <#
        .SYNOPSIS
        Publishes secrets to an Azure Key Vault.

        .DESCRIPTION
        Publishes secrets to an Azure Key Vault. The secrets are published by creating or updating the secret in the Azure Key Vault.

        .PARAMETER KeyVaultName
        The name of the Azure Key Vault.

        .PARAMETER SecretMappings
        A PSCustomObject containing the mappings between the types of secret stored in SecretValues, and the secret names they are stored against within Azure Key Vault.

        .PARAMETER SecretValues
        A PSCustomObject containing the potential secret values.

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    $global:SACREDLogger.Info("Publishing secrets to Azure Key Vault $KeyVaultName.")
    $SecretMappings.PSObject.Properties | ForEach-Object {
        $secretName = $_.Name
        $secretValue = $SecretValues[$_.Value]
        $secureSecretValue = ConvertTo-SecureString -String $secretValue -AsPlainText -Force
        Publish-SACREDAzureKeyVaultSecret -KeyVaultName $KeyVaultName -SecretName $secretName -SecretValue $secureSecretValue
    }
}

Function Publish-SACREDAzureKeyVaultSecret (
    [Parameter(Mandatory=$true)]
    [string] $KeyVaultName,
    
    [Parameter(Mandatory=$true)]
    [string] $SecretName,
    
    [Parameter(Mandatory=$true)] 
    [Security.SecureString] $SecretValue
)
{
    <#
        .SYNOPSIS
        Publishes a secret to an Azure Key Vault.

        .DESCRIPTION
        Publishes a secret to an Azure Key Vault. The secret is published by creating or updating the secret in the Azure Key Vault. When a secret is updated, the previous version is disabled and expired.

        .PARAMETER KeyVaultName
        The name of the Azure Key Vault.

        .PARAMETER SecretName
        The name of the secret.

        .PARAMETER SecretValue
        The value of the secret.

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    $global:SACREDLogger.Info("Publishing secret $SecretName to Azure Key Vault $KeyVaultName.")
    $resourceContext = Get-SACREDAzureContextForResource -ResourceName $KeyVaultName -ResourceType "Microsoft.KeyVault/vaults"
    $currentSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -DefaultProfile $resourceContext
    $publishedSecret = Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -SecretValue $SecretValue -DefaultProfile $resourceContext

    $currentDateTime = Get-Date
    $expiryTime = $currentDateTime.AddMinutes(30).ToUniversalTime()
    if($currentSecret -ne $null)
    {
        $global:SACREDLogger.Info("Disabling and expiring version $($currentSecret.Version) of secret $SecretName in Azure Key Vault $KeyVaultName.")
        Update-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -Version $currentSecret.Version -Enable $false -Expires $expiryTime -DefaultProfile $resourceContext
    }
}

Function Publish-SACREDAzureKeyVaultCertificates (
    [Parameter(Mandatory=$true)]
    [string] $KeyVaultName,
    
    [Parameter(Mandatory=$true)]
    [PSCustomObject[]] $CertificateMappings,
    
    [Parameter(Mandatory=$true)] 
    [PSCustomObject] $CertificateValues
)
{
    <#
        .SYNOPSIS
        Publishes certificates to an Azure Key Vault.

        .DESCRIPTION
        Publishes certificates to an Azure Key Vault. The certificates are published by creating or updating the certificate in the Azure Key Vault.

        .PARAMETER KeyVaultName
        The name of the Azure Key Vault.

        .PARAMETER CertificateMappings
        A PSCustomObject array containing the mappings between the types of certificate stored in CertificateValues, and the certificate names they are stored against within Azure Key Vault.

        .PARAMETER CertificateValues
        A PSCustomObject containing the potential certificate values.

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    $global:SACREDLogger.Info("Publishing certificates to Azure Key Vault $KeyVaultName.")
    foreach($certificateMapping in $CertificateMappings)
    {
        $certificateName = ''
        $certificateData = ''
        $certificatePassword = ''

        $certificateMapping.PSObject.Properties | ForEach-Object {
            if($_.Name -eq 'password')
            {
                $certificatePassword = $CertificateValues[$_.Value]
            }
            else
            {
                $certificateName = $_.Name
                $certificateData = $CertificateValues[$_.Value]
            }
        }
        Publish-SACREDAzureKeyVaultCertificate -KeyVaultName $KeyVaultName -CertificateName $certificateName -CertificateData $certificateData -CertificatePassword $certificatePassword
    }
}

Function Publish-SACREDAzureKeyVaultCertificate (
    [Parameter(Mandatory=$true)]
    [string] $KeyVaultName,
    
    [Parameter(Mandatory=$true)]
    [string] $CertificateName,
    
    [Parameter(Mandatory=$true)] 
    [byte[]] $CertificateData,

    [Parameter(Mandatory=$false)]
    [string] $CertificatePassword = ''
)
{
    <#
        .SYNOPSIS
        Publishes a certificate to an Azure Key Vault.

        .DESCRIPTION
        Publishes a certificate to an Azure Key Vault. The certificate is published by creating or updating the certificate in the Azure Key Vault. When a certificate is updated, the previous version is disabled.

        .PARAMETER KeyVaultName
        The name of the Azure Key Vault.

        .PARAMETER CertificateName
        The name of the certificate.

        .PARAMETER CertificateData
        The value of the certificate, encoded as a byte array.

        .PARAMETER CertificatePassword
        If needed, the password that protects the certificate.

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    $global:SACREDLogger.Info("Publishing certificate $CertificateName to Azure Key Vault $KeyVaultName.")
    $resourceContext = Get-SACREDAzureContextForResource -ResourceName $KeyVaultName -ResourceType "Microsoft.KeyVault/vaults"
    $currentCertificate = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $CertificateName -DefaultProfile $resourceContext

    $certificateString = [System.Convert]::ToBase64String($CertificateData)
    if($CertificatePassword -eq '')
    {
        Import-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $CertificateName -CertificateString $certificateString -DefaultProfile $resourceContext | Out-Null
    }
    else
    {
        $secureCertificatePassword = ConvertTo-SecureString -String $CertificatePassword -AsPlainText -Force
        Import-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $CertificateName -CertificateString $certificateString -Password $secureCertificatePassword -DefaultProfile $resourceContext | Out-Null
    }

    if($currentCertificate -ne $null)
    {
        $global:SACREDLogger.Info("Disabling version $($currentCertificate.Version) of certificate $CertificateName in Azure Key Vault $KeyVaultName.")
        Update-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $CertificateName -Version $currentCertificate.Version -Enable $false -DefaultProfile $resourceContext
    }
}