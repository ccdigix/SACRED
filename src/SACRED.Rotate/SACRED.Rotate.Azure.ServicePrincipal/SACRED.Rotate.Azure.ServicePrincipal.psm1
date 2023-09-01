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

Function Invoke-SACREDEntraServicePrincipalSecretRotation (
    [Parameter(Mandatory=$true)]    
    [string] $ServicePrincipalDisplayName,

    [Parameter(Mandatory=$false)]
    [int] $SecretValidityInDays = 365,

    [Parameter(Mandatory=$false)]
    [int] $SecretValidityInHours = 0
)
{
    <#
        .SYNOPSIS
        Rotates an Entra Service Principal secret.

        .DESCRIPTION
        Rotates an Entra Service Principal secret.

        .PARAMETER ServicePrincipalDisplayName
        The name of the Entra Service Principal.

        .PARAMETER SecretValidityInDays
        How long the secret should be valid for, in days.

        .PARAMETER SecretValidityInHours
        How long the secret should be valid for, in hours.

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    Connect-SACREDToMicrosoftGraph

    return Invoke-SACREDEntraServicePrincipalSecretRegeneration -ServicePrincipalDisplayName $ServicePrincipalDisplayName -SecretValidityInDays $SecretValidityInDays -SecretValidityInHours $SecretValidityInHours
}

Function Invoke-SACREDEntraServicePrincipalSecretRegeneration (
    [Parameter(Mandatory=$true)]    
    [string] $ServicePrincipalDisplayName,

    [Parameter(Mandatory=$false)]
    [int] $SecretValidityInDays = 365,

    [Parameter(Mandatory=$false)]
    [int] $SecretValidityInHours = 0
)
{
    <#
        .SYNOPSIS
        Regenerates an Entra Service Principal secret.

        .DESCRIPTION
        Regenerates an Entra Service Principal secret.

        .PARAMETER ServicePrincipalDisplayName
        The name of the Entra Service Principal.

        .PARAMETER SecretValidityInDays
        How long the secret should be valid for, in days.

        .PARAMETER SecretValidityInHours
        How long the secret should be valid for, in hours.

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    $global:SACREDLogger.Info("Regenerating the secret for service principal $ServicePrincipalDisplayName.")
    $servicePrincipal = Get-MgServicePrincipal -Filter "DisplayName  eq '$ServicePrincipalDisplayName'"
    $secretStartDate = Get-Date
    if($SecretValidityInHours -gt 0)
    {
        $secretEndDate = $secretStartDate.AddHours($SecretValidityInHours)
    }
    else
    {
        $secretEndDate = $secretStartDate.AddDays($SecretValidityInDays)
    }
    $global:SACREDLogger.Info("New secret will be valid from $secretStartDate to $secretEndDate.")
    $secretCredential = @{
        'EndDateTime'=$secretEndDate
        'StartDateTime'=$secretStartDate
        'DisplayName'='SACRED generated secret'
    }
    $secret = Add-MgServicePrincipalPassword -ServicePrincipalId $servicePrincipal.Id -PasswordCredential $secretCredential

    $credentialInfo = @{'ServicePrincipalSecret'=$secret.SecretText; 'ServicePrincipalSecretValidFrom'=$secretStartDate; 'ServicePrincipalSecretValidTo'=$secretEndDate}
    return $credentialInfo
}

Function Remove-SACREDOldEntraServicePrincipalSecrets (
    [Parameter(Mandatory=$true)]    
    [string] $ServicePrincipalDisplayName,

    [Parameter(Mandatory=$false)]
    [int] $MostRecentSecretsToRetain = 2
)
{
    <#
        .SYNOPSIS
        Removes any old Entra Service Principal secrets.

        .DESCRIPTION
        Removes any old Entra Service Principal secrets.

        .PARAMETER ServicePrincipalDisplayName
        The name of the Entra Service Principal.

        .PARAMETER MostRecentSecretsToRetain
        How many of the most recent secrets (measured by start time) to retain. 

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    $global:SACREDLogger.Info("Removing every SACRED generated secret bar the $MostRecentSecretsToRetain most recent ones, for service principal $ServicePrincipalDisplayName.")
    $servicePrincipal = Get-MgServicePrincipal -Filter "DisplayName  eq '$ServicePrincipalDisplayName'"
    $existingSecrets = ($servicePrincipal.PasswordCredentials | Sort-Object StartDateTime -Descending)
    if($existingSecrets.Count -gt $MostRecentSecretsToRetain)
    {
        for($i=$MostRecentSecretsToRetain; $i -lt $existingSecrets.Count; $i++)
        {
            $secretToDelete = $existingSecrets[$i]
            $global:SACREDLogger.Info("Deleting secret $($secretToDelete.KeyId) from service principal.")
            Remove-MgServicePrincipalPassword -ServicePrincipalId $servicePrincipal.Id -KeyId $secretToDelete.KeyId
        }
    }
}

Function Invoke-SACREDEntraServicePrincipalSelfSignedCertificateRotation (
    [Parameter(Mandatory=$true)]    
    [string] $ServicePrincipalDisplayName,

    [Parameter(Mandatory=$false)]
    [int] $CertificateValidityInDays = 365,

    [Parameter(Mandatory=$false)]
    [int] $CertificateValidityInHours = 0
)
{
    <#
        .SYNOPSIS
        Rotates an Entra Service Principal certificate.

        .DESCRIPTION
        Rotates an Entra Service Principal certificate. These certificates are self-signed.

        .PARAMETER ServicePrincipalDisplayName
        The name of the Entra Service Principal.

        .PARAMETER CertificateValidityInDays
        How long the certificate should be valid for, in days.

        .PARAMETER CertificateValidityInHours
        How long the certificate should be valid for, in hours.

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    Connect-SACREDToMicrosoftGraph

    return Invoke-SACREDEntraServicePrincipalSelfSignedCertificateRegeneration -ServicePrincipalDisplayName $ServicePrincipalDisplayName -CertificateValidityInDays $CertificateValidityInDays -CertificateValidityInHours $CertificateValidityInHours
}

Function Invoke-SACREDEntraServicePrincipalSelfSignedCertificateRegeneration (
    [Parameter(Mandatory=$true)]    
    [string] $ServicePrincipalDisplayName,

    [Parameter(Mandatory=$false)]
    [int] $CertificateValidityInDays = 365,

    [Parameter(Mandatory=$false)]
    [int] $CertificateValidityInHours = 0
)
{
    <#
        .SYNOPSIS
        Regenerates an Entra Service Principal certificate.

        .DESCRIPTION
        Regenerates an Entra Service Principal certificate. These certificates are self-signed.

        .PARAMETER ServicePrincipalDisplayName
        The name of the Entra Service Principal.

        .PARAMETER CertificateValidityInDays
        How long the certificate should be valid for, in days.

        .PARAMETER CertificateValidityInHours
        How long the certificate should be valid for, in hours.

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    $global:SACREDLogger.Info("Regenerating the self-signed certificate for service principal $ServicePrincipalDisplayName.")
    $certificateStartDate = Get-Date
    if($CertificateValidityInHours -gt 0)
    {
        $certificateEndDate = $certificateStartDate.AddHours($CertificateValidityInHours)
    }
    else
    {
        $certificateEndDate = $certificateStartDate.AddDays($CertificateValidityInDays)
    }
    $global:SACREDLogger.Info("New certificate will be valid from $certificateStartDate to $certificateEndDate.")
    $servicePrincipal = Get-MgServicePrincipal -Filter "DisplayName  eq '$ServicePrincipalDisplayName'"
    $certificate = New-SelfSignedCertificate -Subject "CN=$ServicePrincipalDisplayName" -CertStoreLocation "Cert:\CurrentUser\My" -KeyExportPolicy Exportable -KeySpec Signature -KeyLength 2048 -KeyAlgorithm RSA -HashAlgorithm SHA256 -NotAfter $certificateEndDate

    $publicCertificateData = $certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
    $certificateThumbprint = $certificate.Thumbprint
    $certificateEndDateTime = Get-Date $certificate.NotAfter -Format 'o'
    
    $global:SACREDLogger.Info("New certificate thumbprint is $certificateThumbprint.")
    $keyCredential = @{
        'CustomKeyIdentifier'=[System.Text.Encoding]::UTF8.GetBytes($certificateThumbprint.Substring(0, 32))
        'EndDateTime'=$certificateEndDateTime
        'Key'=$publicCertificateData
        'Type'='AsymmetricX509Cert'
        'Usage'='Verify'
        'DisplayName'="CN=$ServicePrincipalDisplayName"
    }
    $keyCredentials = New-Object System.Collections.ArrayList
    $keyCredentials.Add($keyCredential) | Out-Null
    if($servicePrincipal.KeyCredentials.Count -gt 0)
    {
        foreach($keyCred in $servicePrincipal.KeyCredentials)
        {
            $keyCredentials.Add($keyCred) | Out-Null
        }
    }
    $global:SACREDLogger.Info("Updating key credentials on service principal.")
    Update-MgServicePrincipal -ServicePrincipalId $servicePrincipal.Id -KeyCredentials $keyCredentials

    $privateCertificatePassword = New-Guid
    $securePrivateCertificatePassword = ConvertTo-SecureString -AsPlainText $privateCertificatePassword -Force
    $privateCertificateData = $certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $securePrivateCertificatePassword)

    Remove-Item $certificate.PSPath

    $credentialInfo = @{'ServicePrincipalPublicCertificate'=$publicCertificateData; 'ServicePrincipalPrivateCertificate'=$privateCertificateData; 'ServicePrincipalPrivateCertificatePassword'=$privateCertificatePassword; 'ServicePrincipalCertificateThumbprint'=$certificateThumbprint; 'ServicePrincipalCertificateValidFrom'=$certificateStartDate; 'ServicePrincipalCertificateValidTo'=$certificateEndDate}
    return $credentialInfo
}

Function Remove-SACREDOldEntraServicePrincipalSelfSignedCertificates (
    [Parameter(Mandatory=$true)]    
    [string] $ServicePrincipalDisplayName,

    [Parameter(Mandatory=$false)]
    [int] $MostRecentCertificatesToRetain = 2
)
{
    <#
        .SYNOPSIS
        Removes any old Entra Service Principal certificates.

        .DESCRIPTION
        Removes any old Entra Service Principal certificates.

        .PARAMETER ServicePrincipalDisplayName
        The name of the Entra Service Principal.

        .PARAMETER MostRecentCertificatesToRetain
        How many of the most recent certificates (measured by start time) to retain. 

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    $global:SACREDLogger.Info("Removing every SACRED generated certificate bar the $MostRecentCertificatesToRetain most recent ones, for service principal $ServicePrincipalDisplayName.")
    $servicePrincipal = Get-MgServicePrincipal -Filter "DisplayName  eq '$ServicePrincipalDisplayName'"

    $existingCredentials = $servicePrincipal.KeyCredentials
    $certificateList = New-Object System.Collections.ArrayList
    $keyCredentials = New-Object System.Collections.ArrayList
    foreach($existingCredential in $existingCredentials)
    {
        if($existingCredential.Type -eq "AsymmetricX509Cert") 
        {
            $certificateList.Add($existingCredential) | Out-Null
        }
        $keyCredentials.Add($existingCredential) | Out-Null
    }

    $certificateList = ($certificateList | Sort-Object StartDateTime -Descending)
    if ($certificateList.Count -gt $MostRecentCertificatesToRetain)
    {
        for($i=$MostRecentCertificatesToRetain; $i -lt $certificateList.Count; $i++)
        {
            $credentialToDelete = $certificateList[$i]
            $customKeyIdentifier = $credentialToDelete.CustomKeyIdentifier
            if($customKeyIdentifier)
            {
                $certificateThumbprint = [System.Text.Encoding]::UTF8.GetString($customKeyIdentifier)
            }
            else
            {
                $certificateThumbprint = 'UNKNOWN'
            }

            $global:SACREDLogger.Info("Deleting certificate $($credentialToDelete.KeyId) with thumbprint prefix $certificateThumbprint from service principal.")
            $keyCredentials.Remove($credentialToDelete)
        }

        Update-MgServicePrincipal -ServicePrincipalId $servicePrincipal.Id -KeyCredentials $keyCredentials
    }
}

Function Build-SACREDEntraServicePrincipalRotationJobName (
    [Parameter(Mandatory=$true)]
    [SACREDRotationJobDefinition] $RotationJobDefinition
)
{
    <#
        .SYNOPSIS
        Builds the name of a rotation job for an Entra Service Principal secret/certificate.

        .DESCRIPTION
        Builds the name of a rotation job for an Entra Service Principal secret/certificate.

        .PARAMETER RotationJobDefinition
        The definition of the rotation job.

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    if($RotationJobDefinition.entraServicePrincipal.credentialType -eq 'secret')
    {
        $rotationJobName = "EntraServicePrincipal_$($RotationJobDefinition.entraServicePrincipal.displayName)_Secret"
    }
    elseif($RotationJobDefinition.entraServicePrincipal.credentialType -eq 'selfsignedcertificate')
    {
        $rotationJobName = "EntraServicePrincipal_$($RotationJobDefinition.entraServicePrincipal.displayName)_SelfSignedCertificate"
    }

    return $rotationJobName
}