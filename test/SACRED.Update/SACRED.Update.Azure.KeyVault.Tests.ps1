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

Describe 'SACRED.Update.Azure.KeyVault' {
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
    }

    It 'Updates an Azure Key Vault secret' {
        $rotationJobDefinitionJSON = '
        {
            "mock": {
                "name": "someName",
                "age": "45"
            },
            "rotationSchedule": "never",
            "update": {
                "keyVaults": [
                    {
                        "keyVaultName": "@@KEYVAULT_NAME@@",
                        "secretMappings": {
                            "testSecret1": "name",
                            "testSecret2": "age"
                        }
                    }
                ]
            }
        }
        '

        $rotationJobDefinitionJSON = Merge-SACREDTokensIntoRotationJobDefinition -RotationJobDefinitionJSON $rotationJobDefinitionJSON -TokenFilePath $TokenFilePath

        Register-SACREDRotationJobDefinition -RotationJobDefinitionJSON $rotationJobDefinitionJSON

        #Rotate the mock secret
        $rotationJobName = "MockCredential"
        Invoke-SACREDRotationJob -RotationJobName $rotationJobName

        #Check the Key Vault was updated correctly
        $rotationJobDefinition = ConvertFrom-Json $rotationJobDefinitionJSON
        $testSecret1 = Get-AzKeyVaultSecret -VaultName $rotationJobDefinition.update.keyVaults[0].keyVaultName -Name 'testSecret1' -AsPlainText
        $testSecret1 | Should -Be $rotationJobDefinition.mock.name
        $testSecret2 = Get-AzKeyVaultSecret -VaultName $rotationJobDefinition.update.keyVaults[0].keyVaultName -Name 'testSecret2' -AsPlainText
        $testSecret2 | Should -Be $rotationJobDefinition.mock.age
    }

    It 'Updates an Azure Key Vault certificate' {
        $rotationJobDefinitionJSON = '
        {
            "mock": {
                "certificateStringAsBytes": "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",
                "certificatePassword": "password",
                "certificateThumbprint": "5E1842C3B5A1F3FED74584B18CE4511E32C1DF69"
            },
            "rotationSchedule": "never",
            "update": {
                "keyVaults": [
                    {
                        "keyVaultName": "@@KEYVAULT_NAME@@",
                        "certificateMappings": [
                            {
                                "testCertificate": "certificateStringAsBytes",
                                "password": "certificatePassword"
                            }
                        ]
                    }
                ]
            }
        }
        '

        $rotationJobDefinitionJSON = Merge-SACREDTokensIntoRotationJobDefinition -RotationJobDefinitionJSON $rotationJobDefinitionJSON -TokenFilePath $TokenFilePath

        Register-SACREDRotationJobDefinition -RotationJobDefinitionJSON $rotationJobDefinitionJSON

        #Rotate the mock secret
        $rotationJobName = "MockCredential"
        Invoke-SACREDRotationJob -RotationJobName $rotationJobName

        #Check the Key Vault was updated correctly
        $rotationJobDefinition = ConvertFrom-Json $rotationJobDefinitionJSON
        $testCertificate = Get-AzKeyVaultCertificate -VaultName $rotationJobDefinition.update.keyVaults[0].keyVaultName -Name 'testCertificate'
        $testCertificate.Thumbprint | Should -Be $rotationJobDefinition.mock.certificateThumbprint
    }
}