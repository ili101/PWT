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
    if ($Config['Debug']) {
        Write-Debug "PID: $PID" -Debug
    }

    if (!(Test-Path -Path $Config['DownloadPath'])) {
        $null = New-Item -ItemType Directory $Config['DownloadPath']
    }
    Add-PodeStaticRoute -Path '/download' -Source $Config['DownloadPath'] -DownloadOnly

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
                foreach ($InputItem in 'Start', 'End') {
                    foreach ($InputType in 'Date', 'Time') {
                        if ($Value = $InputData[($Name = $InputItem + '_' + $InputType)]) {
                            $InputData[$InputItem] = $InputData[$InputItem], $Value -ne $null -join ' '
                            $InputData.Remove($Name)
                        }
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
            New-PodeWebDateTime -Name 'Start' -NoLabels
            New-PodeWebDateTime -Name 'End' -NoLabels
            New-PodeWebTextbox -Name 'Sender' -Type Email
            New-PodeWebTextbox -Name 'Recipients' -Type Email
            New-PodeWebTextbox -Name 'MessageSubject'
        )
        New-PodeWebLink -Source 'https://docs.microsoft.com/en-us/exchange/mail-flow/transport-logs/message-tracking?view=exchserver-2019#event-types-in-the-message-tracking-log' -Value 'Event types in the message tracking log' -NewTab
        $ResultsTable = New-PodeWebTable -Name 'Results' -Id 'TableResults' -Filter
        $ResultsTable | Add-PodeWebTableButton -Name 'DownloadExcel' -Icon 'Bar-Chart' -ArgumentList ($Config['DownloadPath']) -ScriptBlock {
            param (
                $DownloadPath
            )
            # $WebEvent.Session.Id
            # $WebEvent.Auth.User.Username
            # $WebEvent.Auth.User.Email
            $PathRoot = if ([System.IO.Path]::IsPathRooted($DownloadPath)) {
                $DownloadPath
            }
            else {
                Join-Path (Get-PodeServerPath) $DownloadPath
            }
            $PathLeaf = Join-Path (New-Guid).Guid ('EMTL {0:yyyy-MM-dd hh-mm-ss}.xlsx' -f (Get-Date))
            Export-Excel -InputObject $global:Results -WorksheetName 'Log' -TableName 'Log' -AutoSize -Path (Join-Path $PathRoot $PathLeaf)
            Set-PodeResponseAttachment -Path ('/download', ($PathLeaf.Replace('\', '/')) -join '/')
        }
        $ResultsTable
    )
    Add-PodeWebPage -Name 'Message Tracking' -Icon Activity -Layouts $DownloadSection
}