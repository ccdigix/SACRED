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

Class SACREDPodeLogger : SACREDLogger
{
    [string] $correlationId

    SACREDPodeLogger()
    {
        $this.correlationId = New-Guid
    }

    [void] Log([string] $message, [SACREDLogLevel] $logLevel)
    {
        switch($logLevel)
        {
            'Debug'
            {
                Write-PodeLog -Name 'terminal' -InputObject @('Debug', $message, $this.correlationId)
                Write-PodeLog -Name 'file' -InputObject @('Debug', $message, $this.correlationId)
            }
            'Info'
            {
                Write-PodeLog -Name 'terminal' -InputObject @('Info', $message, $this.correlationId)
                Write-PodeLog -Name 'file' -InputObject @('Info', $message, $this.correlationId)
            }
            'Warning'
            {
                Write-PodeLog -Name 'terminal' -InputObject @('Warning', $message, $this.correlationId)
                Write-PodeLog -Name 'file' -InputObject @('Warning', $message, $this.correlationId)
            }
            'Error'
            {
                Write-PodeLog -Name 'terminal' -InputObject @('Error', $message, $this.correlationId)
                Write-PodeLog -Name 'file' -InputObject @('Error', $message, $this.correlationId)
            }
            'Fatal'
            {
                Write-PodeLog -Name 'terminal' -InputObject @('Fatal', $message, $this.correlationId)
                Write-PodeLog -Name 'file' -InputObject @('Fatal', $message, $this.correlationId)
            }
        }
    }
}