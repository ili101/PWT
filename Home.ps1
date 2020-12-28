$Config = .\Config.ps1

foreach ($ModulesPath in $Config['ModulesPaths']) {
    Import-Module -Name $ModulesPath
}

Start-PodeServer {
    . $Config['Endpoint']
    if ($Config['Login']) {
        . $Config['Login']
    }

    $ResultsTable = New-PodeWebTable -Name 'Results' -Id 'TableResults' -Filter
    $DownloadSection = New-PodeWebSection -Name 'Download Section' -Elements @(
        New-PodeWebButton -Name 'Download' -Id 'DownloadResults' -ScriptBlock {
            Lock-PodeObject -Object $WebEvent.Lockable {
                $Results = Get-PodeState -Name 'Results'
            }
            Export-Excel -InputObject $Results['Data'] -WorksheetName 'Log' -TableName 'Log' -AutoSize -Path 'C:\Temp\test.xlsx'
        }
    )

    $Form = New-PodeWebForm -Name 'Search' -ArgumentList ($Config['Dummy'], $Config['Debug'], $Config['Exchange']) -ScriptBlock {
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
            Import-Module -Name .\EXLogLib.psm1
            Connect-Exchange @Exchange
            $Results = Search-MessageTracking @InputData
            Show-PodeWebToast -Message "Found $($Results.Length) results"
            $Results | Format-Exchange | Out-PodeWebTable -Id 'TableResults'
            Lock-PodeObject -Object $WebEvent.Lockable {
                $null = Set-PodeState -Name 'Results' -Value @{ 'Data' = $Results }
            }

            # if ($Debug) {
            #     $Results | Out-PodeWebTextbox -Multiline -Preformat
            # }
        }
        catch {
            if ($Debug) {
                $_ | Get-Error | Out-PodeWebTextbox -Multiline -Preformat
            }
        }
    } -Elements @(
        New-PodeWebTextbox -Name 'Start' -Type Date
        New-PodeWebTextbox -Name 'End' -Type Date
        New-PodeWebTextbox -Name 'Sender' -Type Email
        New-PodeWebTextbox -Name 'Recipients' -Type Email
        New-PodeWebTextbox -Name 'MessageSubject'
    )
    Add-PodeWebPage -Name 'Message Tracking' -Icon Activity -Components $Form, $DownloadSection, $ResultsTable
}