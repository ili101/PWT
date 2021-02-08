Add-PodeWebPage -Name 'Message Tracking' -Icon Activity -Layouts @(
    New-PodeWebCard -Name 'Search' -Content @(
        New-PodeWebForm -Name 'Search' -Content @(
            New-PodeWebDateTime -Name 'Start' -NoLabels
            New-PodeWebDateTime -Name 'End' -NoLabels
            New-PodeWebTextbox -Name 'Sender' -Type Email
            New-PodeWebTextbox -Name 'Recipients' -Type Email
            New-PodeWebTextbox -Name 'MessageSubject'
        ) -ArgumentList ($Config['Global']['Debug'], $Config['Tools']['ExchangeMessageTrackingLog']['Connection']) -ScriptBlock {
            param (
                $Debug,
                $Connection
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
                foreach ($InputItem in 'Start', 'End') {
                    foreach ($InputType in 'Date', 'Time') {
                        if ($Value = $InputData[($Name = $InputItem + '_' + $InputType)]) {
                            $InputData[$InputItem] = $InputData[$InputItem], $Value -ne $null -join ' '
                            $InputData.Remove($Name)
                        }
                    }
                }

                Import-Module -Name (Join-Path $PSScriptRoot 'Pwt.EMTL.Connector.psm1')
                Connect-Exchange @Connection
                $global:Results = Search-MessageTracking @InputData
                Show-PodeWebToast -Message "Found $($Results.Length) results"
                $Results | Format-Exchange | Out-PodeWebTable -Id 'TableResults'
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
        }
        New-PodeWebLink -Source 'https://docs.microsoft.com/en-us/exchange/mail-flow/transport-logs/message-tracking?view=exchserver-2019#event-types-in-the-message-tracking-log' -Value 'Event types in the message tracking log' -NewTab
        $ResultsTable = New-PodeWebTable -Name 'Results' -Id 'TableResults' -Filter
        $ResultsTable | Add-PodeWebTableButton -Name 'Download Excel' -Icon 'Bar-Chart' -ArgumentList ($Config['Global']['DownloadPath']) -ScriptBlock {
            param (
                $DownloadPath
            )
            $PathLeaf = Join-Path (New-Guid).Guid ('EMTL {0:yyyy-MM-dd HH-mm-ss}.xlsx' -f (Get-Date))
            $WebEvent.Data | ForEach-Object { $_.Timestamp = Get-Date -Date $_.Timestamp }
            Export-Excel -InputObject $WebEvent.Data -WorksheetName 'Log' -TableName 'Log' -AutoSize -Path (Join-Path $DownloadPath $PathLeaf)
            Set-PodeResponseAttachment -Path ('/download', ($PathLeaf.Replace('\', '/')) -join '/')
        }
        $ResultsTable | Add-PodeWebTableButton -Name 'Download Excel Full' -Icon 'file-text' -ArgumentList ($Config['Global']['DownloadPath']) -ScriptBlock {
            param (
                $DownloadPath
            )
            # $WebEvent.Session.Id
            # $WebEvent.Auth.User.Username
            # $WebEvent.Auth.User.Email
            $PathLeaf = Join-Path (New-Guid).Guid ('EMTL {0:yyyy-MM-dd HH-mm-ss}.xlsx' -f (Get-Date))
            Export-Excel -InputObject $global:Results -WorksheetName 'Log' -TableName 'Log' -AutoSize -Path (Join-Path $DownloadPath $PathLeaf)
            Set-PodeResponseAttachment -Path ('/download', ($PathLeaf.Replace('\', '/')) -join '/')
        }
        $ResultsTable
    )
)