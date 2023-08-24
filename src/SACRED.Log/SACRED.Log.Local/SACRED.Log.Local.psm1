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

Class SACREDLocalLogger : SACREDLogger
{
    [string] $logFilePath

    SACREDLocalLogger([string] $basePath)
    {
        $logFileName = "$([Math]::Round((Get-Date).ToFileTime()/10000)).txt"
        $this.logFilePath = Join-Path -Path $basePath -ChildPath $logFileName
    }

    [void] Log([string] $message, [SACREDLogLevel] $logLevel)
    {
        $logMessage = "$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss')) $logLevel $message"
        Add-Content -Path $this.logFilePath -Value "$logMessage"

        switch($logLevel)
        {
            'Debug'
            {
                Write-Debug $logMessage
            }
            'Info'
            {
                Write-Host $logMessage
            }
            'Warning'
            {
                Write-Warning $logMessage
            }
            'Error'
            {
                Write-Error $logMessage
            }
            'Fatal'
            {
                Write-Error $logMessage
            }
        }
    }
}