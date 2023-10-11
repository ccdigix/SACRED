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

$ErrorActionPreference = 'Stop'

Write-Host 'Creating temporary NuGet repo locally.'
$existingRepo = Get-PSRepository -Name 'SACREDTempRepo' -ErrorAction SilentlyContinue
if($existingRepo)
{
    Unregister-PSRepository -Name 'SACREDTempRepo'
}

$currentLocation = Get-Item .
$tempRepoPath = Join-Path -Path $currentLocation -ChildPath '../target/temprepo'

if(!(Test-Path -Path '../target'))
{
    New-Item -ItemType Directory -Force -Path '../target' | Out-Null
}

if(Test-Path -Path $tempRepoPath)
{
    Remove-Item -Path $tempRepoPath -Force -Recurse
}
New-Item -ItemType Directory -Force -Path $tempRepoPath | Out-Null

Register-PSRepository -Name 'SACREDTempRepo' -SourceLocation $tempRepoPath -PublishLocation $tempRepoPath -InstallationPolicy Trusted

Write-Host 'Unloading any modules already in the session memory.'
Remove-Module SACRED.Job -ErrorAction SilentlyContinue
Remove-Module SACRED.Log -ErrorAction SilentlyContinue
Remove-Module SACRED.Log.Local -ErrorAction SilentlyContinue
Remove-Module SACRED.Rotate.Azure.CosmosDB -ErrorAction SilentlyContinue
Remove-Module SACRED.Rotate.Azure.ServicePrincipal -ErrorAction SilentlyContinue
Remove-Module SACRED.SecretStore -ErrorAction SilentlyContinue
Remove-Module SACRED.SecretStore.EnvironmentVariable -ErrorAction SilentlyContinue
Remove-Module SACRED.Store -ErrorAction SilentlyContinue
Remove-Module SACRED.Store.Local -ErrorAction SilentlyContinue
Remove-Module SACRED.Update.Azure.KeyVault -ErrorAction SilentlyContinue
Remove-Module SACRED.Update.Windows.CertificateStore -ErrorAction SilentlyContinue
Remove-Module SACRED.Util -ErrorAction SilentlyContinue
Remove-Module SACRED.Util.Azure -ErrorAction SilentlyContinue

Remove-Module SACRED -ErrorAction SilentlyContinue

Write-Host 'Uninstalling any existing SACRED modules.'
Uninstall-Module SACRED.Job -AllVersions -Force -ErrorAction SilentlyContinue
Uninstall-Module SACRED.Log -AllVersions -Force -ErrorAction SilentlyContinue
Uninstall-Module SACRED.Log.Local -AllVersions -Force -ErrorAction SilentlyContinue
Uninstall-Module SACRED.Rotate.Azure.CosmosDB -AllVersions -Force -ErrorAction SilentlyContinue
Uninstall-Module SACRED.Rotate.Azure.ServicePrincipal -AllVersions -Force -ErrorAction SilentlyContinue
Uninstall-Module SACRED.SecretStore -AllVersions -Force -ErrorAction SilentlyContinue
Uninstall-Module SACRED.SecretStore.EnvironmentVariable -AllVersions -Force -ErrorAction SilentlyContinue
Uninstall-Module SACRED.Store -AllVersions -Force -ErrorAction SilentlyContinue
Uninstall-Module SACRED.Store.Local -AllVersions -Force -ErrorAction SilentlyContinue
Uninstall-Module SACRED.Update.Azure.KeyVault -AllVersions -Force -ErrorAction SilentlyContinue
Uninstall-Module SACRED.Update.Windows.CertificateStore -AllVersions -Force -ErrorAction SilentlyContinue
Uninstall-Module SACRED.Util -AllVersions -Force -ErrorAction SilentlyContinue
Uninstall-Module SACRED.Util.Azure -AllVersions -Force -ErrorAction SilentlyContinue

Uninstall-Module SACRED -AllVersions -Force -ErrorAction SilentlyContinue

Write-Host 'Publishing SACRED modules to temporary NuGet repo.'
Publish-Module -Name .\SACRED.Job\SACRED.Job\ -Repository SACREDTempRepo
Publish-Module -Name .\SACRED.Log\SACRED.Log\ -Repository SACREDTempRepo
Publish-Module -Name .\SACRED.Log\SACRED.Log.Local\ -Repository SACREDTempRepo
Publish-Module -Name .\SACRED.Rotate\SACRED.Rotate.Azure.CosmosDB\ -Repository SACREDTempRepo
Publish-Module -Name .\SACRED.Rotate\SACRED.Rotate.Azure.ServicePrincipal\ -Repository SACREDTempRepo
Publish-Module -Name .\SACRED.SecretStore\SACRED.SecretStore\ -Repository SACREDTempRepo
Publish-Module -Name .\SACRED.SecretStore\SACRED.SecretStore.EnvironmentVariable\ -Repository SACREDTempRepo
Publish-Module -Name .\SACRED.Store\SACRED.Store\ -Repository SACREDTempRepo
Publish-Module -Name .\SACRED.Store\SACRED.Store.Local\ -Repository SACREDTempRepo
Publish-Module -Name .\SACRED.Update\SACRED.Update.Azure.KeyVault\ -Repository SACREDTempRepo
Publish-Module -Name .\SACRED.Update\SACRED.Update.Windows.CertificateStore\ -Repository SACREDTempRepo
Publish-Module -Name .\SACRED.Util\SACRED.Util\ -Repository SACREDTempRepo
Publish-Module -Name .\SACRED.Util\SACRED.Util.Azure\ -Repository SACREDTempRepo

Write-Host 'Installing SACRED modules from temporary NuGet repo.'
Install-Module SACRED.Job -Scope CurrentUser -Repository SACREDTempRepo -Force
Install-Module SACRED.Log -Scope CurrentUser -Repository SACREDTempRepo -Force
Install-Module SACRED.Log.Local -Scope CurrentUser -Repository SACREDTempRepo -Force
Install-Module SACRED.Rotate.Azure.CosmosDB -Scope CurrentUser -Repository SACREDTempRepo -Force
Install-Module SACRED.Rotate.Azure.ServicePrincipal -Scope CurrentUser -Repository SACREDTempRepo -Force
Install-Module SACRED.SecretStore -Scope CurrentUser -Repository SACREDTempRepo -Force
Install-Module SACRED.SecretStore.EnvironmentVariable -Scope CurrentUser -Repository SACREDTempRepo -Force
Install-Module SACRED.Store -Scope CurrentUser -Repository SACREDTempRepo -Force
Install-Module SACRED.Store.Local -Scope CurrentUser -Repository SACREDTempRepo -Force
Install-Module SACRED.Update.Azure.KeyVault -Scope CurrentUser -Repository SACREDTempRepo -Force
Install-Module SACRED.Update.Windows.CertificateStore -Scope CurrentUser -Repository SACREDTempRepo -Force
Install-Module SACRED.Util -Scope CurrentUser -Repository SACREDTempRepo -Force
Install-Module SACRED.Util.Azure -Scope CurrentUser -Repository SACREDTempRepo -Force

Write-Host 'Publishing top level SACRED module to local NuGet repo.'
Publish-Module -Name .\SACRED\ -Repository SACREDTempRepo

Write-Host 'Installing top level SACRED module from local NuGet repo.'
Install-Module SACRED -Scope CurrentUser -Repository SACREDTempRepo -Force

Write-Host 'Removing temporary NuGet repo.'
Unregister-PSRepository -Name 'SACREDTempRepo'
Remove-Item -Path $tempRepoPath -Force -Recurse

Write-Host 'SACRED successfully built and deployed locally!' -ForegroundColor Green