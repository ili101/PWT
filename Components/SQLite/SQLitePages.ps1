if ($Config['Components']['SQLite']['SettingsPage']) {
    Add-PodeWebPage -Name 'Settings' -Icon settings -ScriptBlock {
        New-PodeWebForm -Name 'Account' -AsCard -Content @(
            $ConfigTable = Invoke-Sql -QueryPath '\Components\SQLite\User\ItemGet.sql' -QueryFormat $WebEvent.Auth.User.Username -AsDataTable
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
                            New-PodeWebSelect -Name $Column.ColumnName -Options 'Auto', 'Light', 'Dark' -SelectedValue $ConfigTable.Rows[0].($Column.ColumnName) -ChooseOptionValue 'Default'
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
            foreach ($Config in $WebEvent.Data.GetEnumerator()) {
                $ConfigNames += '"' + $Config.Name + '"'
                $ConfigValues += if ($Config.Value -eq 'Default') {
                    'null'
                }
                else {
                    if ($Config.Value -is [String] -and $Config.Value -notin 'true', 'false') {
                        "'" + $Config.Value + "'"
                    }
                    else {
                        $Config.Value
                    }
                }
            }
            $null = Invoke-Sql -Update -QueryPath '\Components\SQLite\User\ItemSet.sql' -QueryFormat $WebEvent.Auth.User.Username, ($ConfigNames -join ', '), ($ConfigValues -join ', ')
            $ConfigTable = Invoke-Sql -QueryPath '\Components\SQLite\User\ItemGet.sql' -QueryFormat $WebEvent.Auth.User.Username
            if ($ConfigTable.Theme -is [DBNull]) {
                $WebEvent.Auth.User.Remove('Theme')
            }
            else {
                $WebEvent.Auth.User.Theme = $ConfigTable.Theme
            }
            Reset-PodeWebPage
        }
    }
}