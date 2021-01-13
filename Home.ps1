$Config = .\Config.ps1

foreach ($ModulesPath in $Config['ModulesPaths']) {
    Import-Module -Name $ModulesPath
}

function Connect-Database {
    [CmdletBinding()]
    param ()
    if (!(Get-SqlConnection -ConnectionName SQLite -WarningAction SilentlyContinue)) {
        Open-SQLiteConnection -ConnectionName SQLite -ConnectionString ('Data Source={0};ForeignKeys=True;recursive_triggers=True' -f (Join-Path (Get-PodeServerPath).Replace('\\', '\\\\') '\Storage\Tool.db'))
    }
}

Start-PodeServer {
    . $Config['Endpoint']
    if ($Config['Login']) {
        . $Config['Login']
        if ([String]::IsNullOrWhiteSpace($Config['LoginAuthenticationName'])) {
            throw 'When "Login" configured "LoginAuthenticationName" is required.'
        }
        $Authentication = @{ Authentication = $Config['LoginAuthenticationName'] }
    }
    else {
        $Authentication = @{}
    }
    New-PodeLoggingMethod -File -Name 'Errors' | Enable-PodeErrorLogging
    New-PodeLoggingMethod -File -Name 'Requests' | Enable-PodeRequestLogging
    if ($Config['Debug']) {
        Write-Debug "PID: $PID" -Debug
    }

    if (!(Test-Path -Path $Config['DownloadPath'])) {
        $null = New-Item -ItemType Directory $Config['DownloadPath']
    }
    Add-PodeStaticRoute -Path '/download' -Source $Config['DownloadPath'] -DownloadOnly @Authentication

    Add-PodeWebPage -Name 'Message Tracking' -Icon Activity -Layouts (
        New-PodeWebCard -Name 'Download Section' -Content @(
            New-PodeWebForm -Name 'Search' -Content @(
                New-PodeWebDateTime -Name 'Start' -NoLabels
                New-PodeWebDateTime -Name 'End' -NoLabels
                New-PodeWebTextbox -Name 'Sender' -Type Email
                New-PodeWebTextbox -Name 'Recipients' -Type Email
                New-PodeWebTextbox -Name 'MessageSubject'
            ) -ArgumentList ($Config['Dummy'], $Config['Debug'], $Config['Exchange']) -ScriptBlock {
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
    )
    if ($Config['LoginUserConfiguration']) {
        Add-PodeWebPage -Name 'Config' -Icon settings -ScriptBlock {
            New-PodeWebCard -Name 'Preference' -Content @(
                New-PodeWebForm -Name 'Search' -Content @(
                    # Connect-Database
                    $ConfigTable = Invoke-SqlQuery -ConnectionName SQLite -Query ((Get-Content .\SQL\User\ItemGet.sql | Out-String) -f $WebEvent.Auth.User.Username) -AsDataTable
                    foreach ($Column in ($ConfigTable.Columns | Where-Object 'ColumnName' -NE 'Name')) {
                        # TODO: Add description, options, Type to SQL?
                        switch ($Column.DataType.Name) {
                            'Boolean' {
                                $Params = if ($ConfigTable.Rows[0].($Column.ColumnName)) {
                                    @{ Checked = $true }
                                }
                                else {
                                    @{}
                                }
                                New-PodeWebCheckbox -Name $Column.ColumnName -AsSwitch @Params
                            }
                            'Int32' { New-PodeWebTextbox -Name $Column.ColumnName -Value $ConfigTable.Rows[0].($Column.ColumnName) -Type Number }
                            Default {
                                if ($Column.ColumnName -eq 'Theme') {
                                    New-PodeWebSelect -Name $Column.ColumnName -Options 'Ligth', 'Dark' -SelectedValue $ConfigTable.Rows[0].($Column.ColumnName)
                                }
                                else {
                                    New-PodeWebTextbox -Name $Column.ColumnName -Value $ConfigTable.Rows[0].($Column.ColumnName)
                                }
                            }
                        }
                    }
                ) -ScriptBlock {
                    $ConfigNames = @()
                    $ConfigValues = @()
                    $Configs = @{}
                    foreach ($Config in $WebEvent.Data.GetEnumerator()) {
                        $ConfigNames += '"' + $Config.Name + '"'
                        $ConfigValues += if ($Config.Value -eq 'Choose an option') {
                            'null'
                        }
                        else {
                            # TODO: Pode.Web: New-PodeWebSelect should return $true instead of 'true'?
                            if ($Config.Value -is [String] -and $Config.Value -notin 'true', 'false') {
                                "'" + $Config.Value + "'"
                            }
                            else {
                                $Config.Value
                            }
                        }
                    }
                    # Connect-Database
                    $null = Invoke-SqlUpdate -ConnectionName SQLite -Query ((Get-Content .\SQL\User\ItemSet.sql | Out-String) -f $WebEvent.Auth.User.Username, ($ConfigNames -join ', '), ($ConfigValues -join ', '))
                    $ConfigTable = Invoke-SqlQuery -ConnectionName SQLite -Query ((Get-Content .\SQL\User\ItemGet.sql | Out-String) -f $WebEvent.Auth.User.Username)
                    if ($ConfigTable.Theme -is [DBNull]) {
                        $WebEvent.Auth.User.Remove('Theme')
                    }
                    else {
                        $WebEvent.Auth.User.Theme = $ConfigTable.Theme
                    }
                    # TODO: Pode.Web: Refresh page here.
                }
            )
        }
    }
}