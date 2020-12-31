$Config = .\Config.ps1

foreach ($ModulesPath in $Config['ModulesPaths']) {
    Import-Module -Name $ModulesPath
}

Start-PodeServer {
    . $Config['Endpoint']
    if ($Config['Login']) {
        . $Config['Login']
    }
    
    New-PodeLoggingMethod -File -Name 'Errors' | Enable-PodeErrorLogging -Levels @('Error', 'Warning', 'Informational', 'Verbose', 'Debug')
    New-PodeLoggingMethod -File -Name 'Requests' | Enable-PodeRequestLogging

    $DownloadSection = New-PodeWebCard -Name 'Download Section' -Content @(
        New-PodeWebForm -Name 'Search' -ArgumentList ($Config['Dummy'], $Config['Debug'], $Config['Exchange']) -ScriptBlock {
            param (
                $Dummy,
                $Debug,
                $Exchange
            )
            $ErrorActionPreference = 'Stop'
            try {
                function Format-Exchange {
                    [CmdletBinding()]
                    param (
                        [Parameter(ValueFromPipeline)]
                        $InputObject
                    )
                    process {
                        $InputObject | Select-Object -Property @{N = 'Timestamp' ; E = { $_.Timestamp.ToString() } }, 'EventId', 'Source', 'Sender', 'Recipients', 'MessageSubject'
                    }
                }
                # Clear Parameters.
                $InputData = @{}
                foreach ($Param in $WebEvent.Data.GetEnumerator()) {
                    if (![string]::IsNullOrWhiteSpace($Param.Value)) {
                        $InputData[$Param.Key] = $Param.Value
                    }
                }
                Import-Module -Name (Join-Path $PSScriptRoot 'EXLogLib.psm1')
                Connect-Exchange @Exchange
                $global:Results = Search-MessageTracking @InputData
                Show-PodeWebToast -Message "Found $($Results.Length) results"
                $Results | Format-Exchange | Out-PodeWebTable -Id 'TableResults'

                # if ($Debug) {
                #     $Results | Out-PodeWebTextbox -Multiline -Preformat
                # }
            }
            catch {
                if ($Debug) {
                    $ErrorMsg = if ($PSVersionTable.PSVersion.Major -gt 5) {
                        $_ | Get-Error
                    }
                    else {
                        $_
                    }
                    $ErrorMsg | Out-PodeWebTextbox -Multiline -Preformat
                }
            }
        } -Content @(
            New-PodeWebTextbox -Name 'Start' -Type Date
            New-PodeWebTextbox -Name 'End' -Type Date
            New-PodeWebTextbox -Name 'Sender' -Type Email
            New-PodeWebTextbox -Name 'Recipients' -Type Email
            New-PodeWebTextbox -Name 'MessageSubject'
        )
        New-PodeWebButton -Name 'Download' -Id 'DownloadResults' -Icon 'Download' -ScriptBlock {
            Write-Warning 'Button run'
            Export-Excel -InputObject $global:Results -WorksheetName 'Log' -TableName 'Log' -AutoSize -Path 'C:\Temp\test.xlsx'
        }
        New-PodeWebLink -Source 'https://docs.microsoft.com/en-us/exchange/mail-flow/transport-logs/message-tracking?view=exchserver-2019#event-types-in-the-message-tracking-log' -Value 'Event types in the message tracking log' -NewTab
        New-PodeWebTable -Name 'Results' -Id 'TableResults' -Filter
    )
    Add-PodeWebPage -Name 'Message Tracking' -Icon Activity -Layouts $DownloadSection
}