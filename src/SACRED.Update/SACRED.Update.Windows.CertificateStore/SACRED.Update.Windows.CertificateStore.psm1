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

Function Publish-SACREDWindowsCertificateStoreCertificates (
    [Parameter(Mandatory=$true)]
    [string] $CertificateStoreLocation,

    [Parameter(Mandatory=$true)]
    [string] $CertificateStoreName,

    [Parameter(Mandatory=$true)]
    [PSCustomObject[]] $CertificateMappings,
    
    [Parameter(Mandatory=$true)] 
    [PSCustomObject] $CertificateValues
)
{
    <#
        .SYNOPSIS
        Publishes certificates to a Windows certificate store.

        .DESCRIPTION
        Publishes certificates to a Windows certificate store. The certificate is published and then any previous versions of the certificate are deleted.

        .PARAMETER CertificateStoreLocation
        The location to place the certificate within the store e.g. CurrentUser.

        .PARAMETER CertificateStoreName
        The of the certificate store e.g. My.

        .PARAMETER CertificateMappings
        A PSCustomObject array containing the mappings between the types of certificate stored in CertificateValues, and the values needed to place successfully within the Windows certificate store.

        .PARAMETER CertificateValues
        A PSCustomObject containing the potential certificate values.

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    $global:SACREDLogger.Info("Publishing certificates into the $CertificateStoreLocation\$CertificateStoreName Windows certificate store.")
    foreach($certificateMapping in $CertificateMappings)
    {
        $certificateData = $CertificateValues[$certificateMapping.certificateData]
        $certificatePassword = $CertificateValues[$certificateMapping.password]

        Publish-SACREDWindowsCertificateStoreCertificate -CertificateStoreLocation $CertificateStoreLocation -CertificateStoreName $CertificateStoreName -CertificateData $certificateData -CertificatePassword $certificatePassword
    }
}

Function Publish-SACREDWindowsCertificateStoreCertificate (
    [Parameter(Mandatory=$true)]
    [string] $CertificateStoreLocation,

    [Parameter(Mandatory=$true)]
    [string] $CertificateStoreName,
    
    [Parameter(Mandatory=$true)] 
    [byte[]] $CertificateData,

    [Parameter(Mandatory=$false)]
    [string] $CertificatePassword = ''
)
{
    <#
        .SYNOPSIS
        Publishes a certificate to a Windows certificate store.

        .DESCRIPTION
        Publishes a certificate to a Windows certificate store. The certificate is published and then any previous versions of the certificate are deleted.

        .PARAMETER CertificateStoreLocation
        The location to place the certificate within the store e.g. CurrentUser.

        .PARAMETER CertificateStoreName
        The of the certificate store e.g. My.

        .PARAMETER CertificateData
        The value of the certificate, encoded as a byte array.

        .PARAMETER CertificatePassword
        If needed, the password that protects the certificate.

        .INPUTS
        None

        .OUTPUTS
        None
    #>

    $global:SACREDLogger.Info("Publishing certificate into the $CertificateStoreLocation\$CertificateStoreName Windows certificate store.")
    $secureCertificatePassword = ConvertTo-SecureString -String $CertificatePassword -AsPlainText -Force
    $certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertificateData, $secureCertificatePassword)
    $global:SACREDLogger.Info("Certificate subject is $($certificate.Subject) with a thumbprint of $($certificate.Thumbprint).")
    $certificateStore = New-Object System.Security.Cryptography.X509Certificates.X509Store($CertificateStoreName, $CertificateStoreLocation)
    $certificateStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::'ReadWrite')
    $certificateStore.Add($certificate)

    $global:SACREDLogger.Info("Removing previous versions of the certificate.")
    $certificatesToDelete = ($certificateStore.Certificates | Where-Object {($_.Subject -eq $certificate.Subject) -and ($_.Thumbprint -ne $certificate.Thumbprint)})
    foreach($certificateToDelete in $certificatesToDelete)
    {
        $global:SACREDLogger.Info("Removing certificate with thumbprint $($certificateToDelete.Thumbprint)")
        $certificateStore.Remove($certificateToDelete)
    }
    $certificateStore.Close()
}