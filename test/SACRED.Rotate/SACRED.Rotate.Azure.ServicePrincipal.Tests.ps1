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

param 
(
    [Parameter(Mandatory=$true)]
    [string] $TokenFilePath
)

Describe 'SACRED.Rotate.Azure.ServicePrincipal' {

    BeforeAll {
        if(!$global:EnvironmentInitialized)
        {
            Initialize-SACREDEnvironment -LocalStoreBasePath $TestDrive -LocalLoggerBasePath $TestDrive -ConnectToAzure
            $global:EnvironmentInitialized = $true
        }
        else
        {
            Initialize-SACREDEnvironment -LocalStoreBasePath $TestDrive -LocalLoggerBasePath $TestDrive
        }
        Connect-SACREDToMicrosoftGraph
    }

    It 'Rotates an Entra Service Principal secret that is valid for x hours' {
        $rotationJobDefinitionJSON = '
        {
            "entraServicePrincipal": {
                "displayName": "@@SERVICEPRINCIPAL_DISPLAY_NAME@@",
                "credentialType": "secret",
                "credentialValidityInHours": 5,
                "mostRecentCredentialsToRetain": 2
            },
            "rotationSchedule": "never",
            "update": {
                "mock": {}
            }
        }
        '

        $rotationJobDefinitionJSON = Merge-SACREDTokensIntoRotationJobDefinition -RotationJobDefinitionJSON $rotationJobDefinitionJSON -TokenFilePath $TokenFilePath

        Register-SACREDRotationJobDefinition -RotationJobDefinitionJSON $rotationJobDefinitionJSON

        #Add two secrets manually
        $rotationJobDefinition = ConvertFrom-Json $rotationJobDefinitionJSON
        $servicePrincipal = Get-MgServicePrincipal -Filter "DisplayName  eq '$($rotationJobDefinition.entraServicePrincipal.displayName)'"
        $secretKeyIds = @()
        for($i = 0; $i -lt 2; $i++)
        {
            $secretStartDate = Get-Date
            $secretEndDate = $secretStartDate.AddHours($rotationJobDefinition.entraServicePrincipal.credentialValidityInHours)
            $secretCredential = @{
                'EndDateTime'=$secretEndDate
                'StartDateTime'=$secretStartDate
                'DisplayName'='SACRED generated secret'
            }
            $secret = Add-MgServicePrincipalPassword -ServicePrincipalId $servicePrincipal.Id -PasswordCredential $secretCredential
            $secretKeyIds += $secret.KeyId
        }

        #Rotate the secret
        $rotationJobName = "EntraServicePrincipal_$($rotationJobDefinition.entraServicePrincipal.displayName)_Secret"
        Invoke-SACREDRotationJob -RotationJobName $rotationJobName
        Start-Sleep -Seconds 30

        #Check there are only two secrets, including the new one
        $servicePrincipal = Get-MgServicePrincipal -Filter "DisplayName  eq '$($rotationJobDefinition.entraServicePrincipal.displayName)'"
        $secrets = ($servicePrincipal.PasswordCredentials | Sort-Object StartDateTime -Descending)
        $secrets.Count | Should -Be 2
        $secrets[1].KeyId | Should -Be $secretKeyIds[1]

        #Check what SACRED thinks is the new secret is what it actually is
        $secretKeyId = $global:SACREDMockDestination['ServicePrincipalSecretKeyId']
        $secretKeyId | Should -Be $secrets[0].KeyId

        #Check expiry time of new secret is between 4 and 5 hours
        $now = (Get-Date).ToUniversalTime()
        $expiryLowerBound = $now.AddHours(4)
        $expiryUpperBound = $now.AddHours(5)
        $secrets[0].EndDateTime | Should -BeGreaterThan $expiryLowerBound
        $secrets[0].EndDateTime | Should -BeLessThan $expiryUpperBound
    }

    It 'Rotates an Entra Service Principal secret that is valid for x days' {
        $rotationJobDefinitionJSON = '
        {
            "entraServicePrincipal": {
                "displayName": "@@SERVICEPRINCIPAL_DISPLAY_NAME@@",
                "credentialType": "secret",
                "credentialValidityInDays": 10,
                "mostRecentCredentialsToRetain": 2
            },
            "rotationSchedule": "never",
            "update": {
                "mock": {}
            }
        }
        '

        $rotationJobDefinitionJSON = Merge-SACREDTokensIntoRotationJobDefinition -RotationJobDefinitionJSON $rotationJobDefinitionJSON -TokenFilePath $TokenFilePath

        Register-SACREDRotationJobDefinition -RotationJobDefinitionJSON $rotationJobDefinitionJSON

        #Add two secrets manually
        $rotationJobDefinition = ConvertFrom-Json $rotationJobDefinitionJSON
        $servicePrincipal = Get-MgServicePrincipal -Filter "DisplayName eq '$($rotationJobDefinition.entraServicePrincipal.displayName)'"
        $secretKeyIds = @()
        for($i = 0; $i -lt 2; $i++)
        {
            $secretStartDate = Get-Date
            $secretEndDate = $secretStartDate.AddDays($rotationJobDefinition.entraServicePrincipal.credentialValidityInDays)
            $secretCredential = @{
                'EndDateTime'=$secretEndDate
                'StartDateTime'=$secretStartDate
                'DisplayName'='SACRED generated secret'
            }
            $secret = Add-MgServicePrincipalPassword -ServicePrincipalId $servicePrincipal.Id -PasswordCredential $secretCredential
            $secretKeyIds += $secret.KeyId
        }

        #Rotate the secret
        $rotationJobName = "EntraServicePrincipal_$($rotationJobDefinition.entraServicePrincipal.displayName)_Secret"
        Invoke-SACREDRotationJob -RotationJobName $rotationJobName
        Start-Sleep -Seconds 30

        #Check there are only two secrets, including the new one
        $servicePrincipal = Get-MgServicePrincipal -Filter "DisplayName eq '$($rotationJobDefinition.entraServicePrincipal.displayName)'"
        $secrets = ($servicePrincipal.PasswordCredentials | Sort-Object StartDateTime -Descending)
        $secrets.Count | Should -Be 2
        $secrets[1].KeyId | Should -Be $secretKeyIds[1]

        #Check what SACRED thinks is the new secret is what it actually is
        $secretKeyId = $global:SACREDMockDestination['ServicePrincipalSecretKeyId']
        $secretKeyId | Should -Be $secrets[0].KeyId

        #Check expiry date of new secret is between 9 and 10 days
        $now = (Get-Date).ToUniversalTime()
        $expiryLowerBound = $now.AddDays(9)
        $expiryUpperBound = $now.AddDays(10)
        $secrets[0].EndDateTime | Should -BeGreaterThan $expiryLowerBound
        $secrets[0].EndDateTime | Should -BeLessThan $expiryUpperBound
    }

    It 'Rotates an Entra Service Principal self-signed certificate that is valid for x hours' {
        $rotationJobDefinitionJSON = '
        {
            "entraServicePrincipal": {
                "displayName": "@@SERVICEPRINCIPAL_DISPLAY_NAME@@",
                "credentialType": "selfsignedcertificate",
                "credentialValidityInHours": 5,
                "mostRecentCredentialsToRetain": 2
            },
            "rotationSchedule": "never",
            "update": {
                "mock": {}
            }
        }
        '

        $rotationJobDefinitionJSON = Merge-SACREDTokensIntoRotationJobDefinition -RotationJobDefinitionJSON $rotationJobDefinitionJSON -TokenFilePath $TokenFilePath

        Register-SACREDRotationJobDefinition -RotationJobDefinitionJSON $rotationJobDefinitionJSON

        #Add two certificates manually
        $rotationJobDefinition = ConvertFrom-Json $rotationJobDefinitionJSON
        $servicePrincipal = Get-MgServicePrincipal -Filter "DisplayName  eq '$($rotationJobDefinition.entraServicePrincipal.displayName)'"
        $certificateThumbprints = @()
        $keyCredentials = New-Object System.Collections.ArrayList
        for($i = 0; $i -lt 2; $i++)
        {
            $certificateStartDate = Get-Date
            $certificateEndDate = $certificateStartDate.AddHours($rotationJobDefinition.entraServicePrincipal.credentialValidityInHours)
            $certificate = New-SelfSignedCertificate -Subject "CN=$($rotationJobDefinition.entraServicePrincipal.displayName)" -CertStoreLocation "Cert:\CurrentUser\My" -KeyExportPolicy Exportable -KeySpec Signature -KeyLength 2048 -KeyAlgorithm RSA -HashAlgorithm SHA256 -NotAfter $certificateEndDate
            $publicCertificateData = $certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
            $certificateThumbprint = $certificate.Thumbprint
            $certificateEndDateTime = Get-Date $certificate.NotAfter -Format 'o'
            $keyCredential = @{
                'CustomKeyIdentifier'=[System.Text.Encoding]::UTF8.GetBytes($certificateThumbprint.Substring(0, 32))
                'EndDateTime'=$certificateEndDateTime
                'Key'=$publicCertificateData
                'Type'='AsymmetricX509Cert'
                'Usage'='Verify'
                'DisplayName'="CN=$($rotationJobDefinition.entraServicePrincipal.displayName)"
            }
            $keyCredentials.Add($keyCredential) | Out-Null
            $certificateThumbprints += $certificateThumbprint
            Remove-Item $certificate.PSPath
        }
        Update-MgServicePrincipal -ServicePrincipalId $servicePrincipal.Id -KeyCredentials $keyCredentials

        #Rotate the certificate
        $rotationJobName = "EntraServicePrincipal_$($rotationJobDefinition.entraServicePrincipal.displayName)_SelfSignedCertificate"
        Invoke-SACREDRotationJob -RotationJobName $rotationJobName
        Start-Sleep -Seconds 30

        #Check there are only two certificates, including the new one
        $servicePrincipal = Get-MgServicePrincipal -Filter "DisplayName  eq '$($rotationJobDefinition.entraServicePrincipal.displayName)'"
        $certificates = $servicePrincipal.KeyCredentials
        $certificates.Count | Should -Be 2
        $oldCertificateThumbprint = [System.Text.Encoding]::UTF8.GetString($certificates[1].CustomKeyIdentifier)
        $certificateThumbprints[1] | Should -BeLike "$oldCertificateThumbprint*"

        #Check what SACRED thinks is the new certificate is what it actually is
        $certificateThumbprint = $global:SACREDMockDestination['ServicePrincipalCertificateThumbprint']
        $newCertificateThumbprint = [System.Text.Encoding]::UTF8.GetString($certificates[0].CustomKeyIdentifier)
        $certificateThumbprint | Should -BeLike "$newCertificateThumbprint*"

        #Check expiry time of new certificate is between 4 and 5 hours
        $now = (Get-Date).ToUniversalTime()
        $expiryLowerBound = $now.AddHours(4)
        $expiryUpperBound = $now.AddHours(5)
        $certificates[0].EndDateTime | Should -BeGreaterThan $expiryLowerBound
        $certificates[0].EndDateTime | Should -BeLessThan $expiryUpperBound
    }

    It 'Rotates an Entra Service Principal self-signed certificate that is valid for x days' {
        $rotationJobDefinitionJSON = '
        {
            "entraServicePrincipal": {
                "displayName": "@@SERVICEPRINCIPAL_DISPLAY_NAME@@",
                "credentialType": "selfsignedcertificate",
                "credentialValidityInDays": 10,
                "mostRecentCredentialsToRetain": 2
            },
            "rotationSchedule": "never",
            "update": {
                "mock": {}
            }
        }
        '

        $rotationJobDefinitionJSON = Merge-SACREDTokensIntoRotationJobDefinition -RotationJobDefinitionJSON $rotationJobDefinitionJSON -TokenFilePath $TokenFilePath

        Register-SACREDRotationJobDefinition -RotationJobDefinitionJSON $rotationJobDefinitionJSON

        #Add two certificates manually
        $rotationJobDefinition = ConvertFrom-Json $rotationJobDefinitionJSON
        $servicePrincipal = Get-MgServicePrincipal -Filter "DisplayName  eq '$($rotationJobDefinition.entraServicePrincipal.displayName)'"
        $certificateThumbprints = @()
        $keyCredentials = New-Object System.Collections.ArrayList
        for($i = 0; $i -lt 2; $i++)
        {
            $certificateStartDate = Get-Date
            $certificateEndDate = $certificateStartDate.AddDays($rotationJobDefinition.entraServicePrincipal.credentialValidityInDays)
            $certificate = New-SelfSignedCertificate -Subject "CN=$($rotationJobDefinition.entraServicePrincipal.displayName)" -CertStoreLocation "Cert:\CurrentUser\My" -KeyExportPolicy Exportable -KeySpec Signature -KeyLength 2048 -KeyAlgorithm RSA -HashAlgorithm SHA256 -NotAfter $certificateEndDate
            $publicCertificateData = $certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
            $certificateThumbprint = $certificate.Thumbprint
            $certificateEndDateTime = Get-Date $certificate.NotAfter -Format 'o'
            $keyCredential = @{
                'CustomKeyIdentifier'=[System.Text.Encoding]::UTF8.GetBytes($certificateThumbprint.Substring(0, 32))
                'EndDateTime'=$certificateEndDateTime
                'Key'=$publicCertificateData
                'Type'='AsymmetricX509Cert'
                'Usage'='Verify'
                'DisplayName'="CN=$($rotationJobDefinition.entraServicePrincipal.displayName)"
            }
            $keyCredentials.Add($keyCredential) | Out-Null
            $certificateThumbprints += $certificateThumbprint
            Remove-Item $certificate.PSPath
        }
        Update-MgServicePrincipal -ServicePrincipalId $servicePrincipal.Id -KeyCredentials $keyCredentials

        #Rotate the certificate
        $rotationJobName = "EntraServicePrincipal_$($rotationJobDefinition.entraServicePrincipal.displayName)_SelfSignedCertificate"
        Invoke-SACREDRotationJob -RotationJobName $rotationJobName
        Start-Sleep -Seconds 30

        #Check there are only two certificates, including the new one
        $servicePrincipal = Get-MgServicePrincipal -Filter "DisplayName  eq '$($rotationJobDefinition.entraServicePrincipal.displayName)'"
        $certificates = $servicePrincipal.KeyCredentials
        $certificates.Count | Should -Be 2
        $oldCertificateThumbprint = [System.Text.Encoding]::UTF8.GetString($certificates[1].CustomKeyIdentifier)
        $certificateThumbprints[1] | Should -BeLike "$oldCertificateThumbprint*"

        #Check what SACRED thinks is the new certificate is what it actually is
        $certificateThumbprint = $global:SACREDMockDestination['ServicePrincipalCertificateThumbprint']
        $newCertificateThumbprint = [System.Text.Encoding]::UTF8.GetString($certificates[0].CustomKeyIdentifier)
        $certificateThumbprint | Should -BeLike "$newCertificateThumbprint*"

        #Check expiry time of new certificate is between 9 and 10 days
        $now = (Get-Date).ToUniversalTime()
        $expiryLowerBound = $now.AddDays(9)
        $expiryUpperBound = $now.AddDays(10)
        $certificates[0].EndDateTime | Should -BeGreaterThan $expiryLowerBound
        $certificates[0].EndDateTime | Should -BeLessThan $expiryUpperBound
    }
}