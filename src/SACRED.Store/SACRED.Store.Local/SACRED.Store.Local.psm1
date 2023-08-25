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

Class SACREDLocalStore : SACREDStore
{
    [string] $basePath
    [string] $credentialVersionDetailsBasePath
    [string] $rotationJobDefinitionsBasePath

    SACREDLocalStore([string] $basePath)
    {
        $this.basePath = $basePath
        $this.credentialVersionDetailsBasePath = Join-Path -Path $this.basePath -ChildPath "credentialVersions"
        if (!(Test-Path -Path $this.credentialVersionDetailsBasePath))
        {
            [system.io.directory]::CreateDirectory($this.credentialVersionDetailsBasePath)
        }
        $this.rotationJobDefinitionsBasePath = Join-Path -Path $this.basePath -ChildPath "rotationJobDefinitions"
        if (!(Test-Path -Path $this.rotationJobDefinitionsBasePath))
        {
            [system.io.directory]::CreateDirectory($this.rotationJobDefinitionsBasePath)
        }
    }

    [SACREDCredentialVersionDetails] GetSACREDRotationJobCredentialVersionDetails([string] $rotationJobName)
    {
        $global:SACREDLogger.Info("Retrieving credential version details for rotation job $rotationJobName.")
        $credentialVersionDetailsPath = Join-Path -Path $this.credentialVersionDetailsBasePath -ChildPath "$rotationJobName.json"
        if (Test-Path -Path $credentialVersionDetailsPath)
        {
            $credentialVersionDetails = Get-Content -Path $credentialVersionDetailsPath -Raw | ConvertFrom-Json
            return $credentialVersionDetails
        }
        else
        {
            $global:SACREDLogger.Warning("No credential version details found for rotation job $rotationJobName.")
            return $null
        }
    }

    [void] SetSACREDRotationJobCredentialVersionDetails([string] $rotationJobName, [SACREDCredentialVersionDetails] $credentialVersionDetails)
    {
        $global:SACREDLogger.Info("Updating credential version details for rotation job $rotationJobName.")
        $credentialVersionDetailsPath = Join-Path -Path $this.credentialVersionDetailsBasePath -ChildPath "$rotationJobName.json"
        $credentialVersionDetails | ConvertTo-Json | Set-Content -Path $credentialVersionDetailsPath
    }

    [void] RemoveSACREDRotationJobCredentialVersionDetails([string] $rotationJobName)
    {
        $global:SACREDLogger.Info("Removing credential version details for rotation job $rotationJobName.")
        $credentialVersionDetailsPath = Join-Path -Path $this.credentialVersionDetailsBasePath -ChildPath "$rotationJobName.json"
        if (Test-Path -Path $credentialVersionDetailsPath)
        {
            $global:SACREDLogger.Info("Deleting credential version details at $credentialVersionDetailsPath.")
            Remove-Item -Path $credentialVersionDetailsPath -Force
        }
        else
        {
            $global:SACREDLogger.Warning("No credential version details found for rotation job $rotationJobName.")
        }
    }

    [SACREDRotationJobDefinition] GetSACREDRotationJobDefinition([string] $rotationJobName)
    {
        $global:SACREDLogger.Info("Retrieving rotation job definition for rotation job $rotationJobName.")
        $rotationJobDefinitionPath = Get-ChildItem -Path $this.rotationJobDefinitionsBasePath -Include "$rotationJobName.json" -File -Recurse -ErrorAction SilentlyContinue
        if ($rotationJobDefinitionPath -ne $null)
        {
            $rotationJobDefinition = Get-Content -Path $rotationJobDefinitionPath -Raw | ConvertFrom-Json
            return $rotationJobDefinition
        }
        else
        {
            $global:SACREDLogger.Warning("No rotation job definition found for rotation job $rotationJobName.")
            return $null
        }
    }

    [void] SetSACREDRotationJobDefinition([string] $rotationJobName, [SACREDRotationJobDefinition] $rotationJobDefinition)
    {
        $global:SACREDLogger.Info("Updating rotation job definition for rotation job $rotationJobName.")
        $rotationScheduleName = $rotationJobDefinition.rotationSchedule
        $rotationJobDefinitionParentPath = Join-Path -Path $this.rotationJobDefinitionsBasePath -ChildPath "$rotationScheduleName"
        if (!(Test-Path -Path $rotationJobDefinitionParentPath))
        {
            [system.io.directory]::CreateDirectory($rotationJobDefinitionParentPath)
        }
        $rotationJobDefinitionPath = Join-Path -Path $rotationJobDefinitionParentPath -ChildPath "$rotationJobName.json"
        $global:SACREDLogger.Info("Saving rotation job definition to $rotationJobDefinitionPath.")
        $rotationJobDefinition | ConvertTo-Json -Depth 10 | Set-Content -Path $rotationJobDefinitionPath
    }

    [void] RemoveSACREDRotationJobDefinition([string] $rotationJobName)
    {
        $global:SACREDLogger.Info("Removing rotation job definition for rotation job $rotationJobName.")
        $rotationJobDefinitionPath = Get-ChildItem -Path $this.rotationJobDefinitionsBasePath -Include "$rotationJobName.json" -File -Recurse -ErrorAction SilentlyContinue
        if ($rotationJobDefinitionPath -ne $null)
        {
            $global:SACREDLogger.Info("Deleting rotation job definition at $rotationJobDefinitionPath.")
            Remove-Item -Path $rotationJobDefinitionPath -Force
        }
        else
        {
            $global:SACREDLogger.Warning("No rotation job definition found for rotation job $rotationJobName.")
        }
    }

    [string[]] GetSACREDScheduledRotationJobNames([string] $rotationScheduleName)
    {
        $global:SACREDLogger.Info("Retrieving rotation job names for rotation schedule $rotationScheduleName.")
        $rotationJobDefinitionParentPath = Join-Path -Path $this.rotationJobDefinitionsBasePath -ChildPath "$rotationScheduleName"
        if (Test-Path -Path $rotationJobDefinitionParentPath)
        {
            $rotationJobDefinitionPaths = Get-ChildItem -Path $rotationJobDefinitionParentPath -Include "*.json" -File -Recurse -ErrorAction SilentlyContinue
            $rotationJobNames = @()
            foreach ($rotationJobDefinitionPath in $rotationJobDefinitionPaths)
            {
                $rotationJobNames += $rotationJobDefinitionPath.Name.Replace('.json', '')
            }
            $global:SACREDLogger.Info("Found $($rotationJobNames.Count) rotation jobs for rotation schedule $rotationScheduleName.")
            return $rotationJobNames
        }
        else
        {
            $global:SACREDLogger.Warning("No rotation jobs found for rotation schedule $rotationScheduleName.")
            return $null
        }
    }
}