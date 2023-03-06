function Initialize-PwtSqlite {
    [CmdletBinding()]
    param (
        # Enable users settings page.
        [Switch]$SettingsPage,
        # Enable admin settings page.
        [Switch]$AdminPage,
        # Create SQL tables if not exists.
        [Switch]$CreateTables
    )
    {
        $Config = Get-PwtConfig -Module 'Pwt.Component.Sqlite'
        # if (!$Config.ContainsKey('Components')) {
        #     $Config['Components'] = @{}
        # }
        # if (!$Config['Components'].ContainsKey('SQLite')) {
        #     $Config['Components']['SQLite'] = @{}
        # }
        # $Config['Components']['SQLite']['Enable'] = $true
        # if ($SettingsPage) {
        #     $Config['Components']['SQLite']['SettingsPage'] = $true
        # }
        # if ($AdminPage) {
        #     $Config['Components']['SQLite']['AdminPage'] = $true
        # }
        $StoragePath = (Get-PodeConfig)['Global']['StoragePath']
        $Config['ConnectionString'] = ('Data Source={0};ForeignKeys=True;recursive_triggers=True' -f (Join-Path $StoragePath.Replace('\\', '\\\\') '\Tool.db'))
        Connect-Sql -ScriptBlock {
            if ($Config['CreateTables']) {
                Invoke-SqlCreateTables
            }
        }
    }
}
function Get-PwtSqlite_Snippet {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('UserGet', 'UserSet')]
        [String]$Name,
        [Parameter(Mandatory)]
        [ValidateSet('New', 'Existing')]
        [String]$Variant
    )
    if ($Name -eq 'UserGet') {
        if ($Variant -eq 'Existing') {
            $ConfigTable = Invoke-Sql -QueryPath (Join-Path $PSScriptRoot 'User\ItemGet.sql') -QueryFormat $WebEvent.Auth.User.Username -AsDataTable -Connect
            # $ConfigTable.Rows[0].Username
        }
        elseif ($Variant -eq 'New') {
            $ConfigTable = Invoke-Sql -QueryPath (Join-Path $PSScriptRoot 'User\StructureGet.sql') -AsDataTable -Connect
        }
        foreach ($Column in ($ConfigTable.Columns | Where-Object 'ColumnName' -In ('Username', 'Password', 'Name', 'Theme', 'Email'))) {
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
                        New-PodeWebSelect -Name $Column.ColumnName -Options 'Default', 'Auto', 'Light', 'Dark', 'Terminal' -SelectedValue $ConfigTable.Rows[0].($Column.ColumnName)
                    }
                    else {
                        New-PodeWebTextbox -Name $Column.ColumnName -Value $ConfigTable.Rows[0].($Column.ColumnName)
                    }
                }
            }
        }
    }
    elseif ($Name -eq 'UserSet') {
        {
            $ConfigNames = @('"AuthenticationType"')
            $ConfigValues = @("'Sqlite'")
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
            # Wait-Debugger
            Connect-Sql -ScriptBlock {
                $null = Invoke-Sql -Update -QueryPath '/PsF/Scripts/PWT/ps_modules/Pwt.Component.Sqlite/User/ItemInsert.sql' -QueryFormat ($ConfigNames -join ', '), ($ConfigValues -join ', ')
                # $ConfigTable = Invoke-Sql -QueryPath (Join-Path $PSScriptRoot 'User\ItemGet.sql') -QueryFormat $WebEvent.Auth.User.Username
            }
            # if ($ConfigTable.Theme -is [DBNull]) {
            #     $WebEvent.Auth.User.Remove('Theme')
            # }
            # else {
            #     $WebEvent.Auth.User.Theme = $ConfigTable.Theme
            # }
            # Reset-PodeWebTheme

        }
    }
}
function Get-PwtPagesSqlite {
    [CmdletBinding()]
    param ()
    {
        $Config = Get-PwtConfig -Module 'Pwt.Component.Sqlite'
        if ($Config['SettingsPage']) {
            Add-PodeWebPage -Name 'Settings' -Icon cog-outline -ScriptBlock {
                New-PodeWebForm -Name 'Account' -AsCard -Content @(
                    # Wait-Debugger
                    Get-PwtSqlite_Snippet -Name 'UserGet' -Variant 'Existing'
                    # $ConfigTable = Invoke-Sql -QueryPath (Join-Path $PSScriptRoot 'User\ItemGet.sql') -QueryFormat $WebEvent.Auth.User.Username -AsDataTable -Connect
                    # foreach ($Column in ($ConfigTable.Columns | Where-Object 'ColumnName' -In ('Username', 'Password', 'Theme', 'Email'))) {
                    #     # TODO: Add description, options, Type to SQL?
                    #     switch ($Column.DataType.Name) {
                    #         'Boolean' {
                    #             $Params = if ($ConfigTable.Rows[0].($Column.ColumnName)) {
                    #                 @{ Checked = $true }
                    #             }
                    #             else {
                    #                 @{}
                    #             }
                    #             New-PodeWebCheckbox -Name $Column.ColumnName -AsSwitch @Params
                    #         }
                    #         'Int32' { New-PodeWebTextbox -Name $Column.ColumnName -Value $ConfigTable.Rows[0].($Column.ColumnName) -Type Number }
                    #         Default {
                    #             if ($Column.ColumnName -eq 'Theme') {
                    #                 New-PodeWebSelect -Name $Column.ColumnName -Options 'Default', 'Auto', 'Light', 'Dark', 'Terminal' -SelectedValue $ConfigTable.Rows[0].($Column.ColumnName)
                    #             }
                    #             else {
                    #                 New-PodeWebTextbox -Name $Column.ColumnName -Value $ConfigTable.Rows[0].($Column.ColumnName)
                    #             }
                    #         }
                    #     }
                    # }
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
                    Connect-Sql -ScriptBlock {
                        $null = Invoke-Sql -Update -QueryPath (Join-Path $PSScriptRoot 'User\ItemSet.sql') -QueryFormat $WebEvent.Auth.User.Username, ($ConfigNames -join ', '), ($ConfigValues -join ', ')
                        $ConfigTable = Invoke-Sql -QueryPath (Join-Path $PSScriptRoot 'User\ItemGet.sql') -QueryFormat $WebEvent.Auth.User.Username
                    }
                    if ($ConfigTable.Theme -is [DBNull]) {
                        $WebEvent.Auth.User.Remove('Theme')
                    }
                    else {
                        $WebEvent.Auth.User.Theme = $ConfigTable.Theme
                    }
                    Reset-PodeWebTheme
                }
            }
        }
        if ($Config['AdminPage']) {
            Add-PodeWebPage -Group 'Admin' -Name 'Users' -Icon account-details-outline -ScriptBlock {
                $Table = New-PodeWebTable -Name 'Explorer' -Id 'AdminUsers' -DataColumn Name -Filter -Sort -Click -Paginate -ScriptBlock {
                    $Users = Invoke-Sql -QueryPath (Join-Path $PSScriptRoot 'User\ItemList.sql') -Stream -Connect
                    # wait-debugger
                    $Users
                }
                $Table | Add-PodeWebTableButton -Name 'Add' -Icon 'account-plus-outline' -ScriptBlock {
                    Show-PodeWebModal -Name 'Add'
                }
                $Table
                New-PodeWebModal -Name 'Add' -AsForm -Content @(
                    Get-PwtSqlite_Snippet -Name 'UserGet' -Variant 'New'
                ) -ScriptBlock {
                    # Wait-Debugger
                    . (Get-PwtSqlite_Snippet -Name 'UserSet' -Variant 'New')
                    Sync-PodeWebTable -Id 'AdminUsers'
                    Hide-PodeWebModal
                }
            }
        }
    }
}

function Connect-Sql {
    [CmdletBinding()]
    param (
        [scriptblock]
        $ScriptBlock
    )
    if (!(Get-SqlConnection -ConnectionName SQLite -WarningAction SilentlyContinue)) {
        $ConnectionString = (Get-PwtConfig -Module 'Pwt.Component.Sqlite')['ConnectionString']
        Open-SQLiteConnection -ConnectionName SQLite -ConnectionString $ConnectionString
        if ($ScriptBlock) {
            try {
                . $ScriptBlock
            }
            finally {
                Disconnect-Sql
            }
        }
    }
}
function Disconnect-Sql {
    [CmdletBinding()]
    param ()
    if ((Get-SqlConnection -ConnectionName SQLite -WarningAction SilentlyContinue)) {
        $ConnectionString = (Get-PwtConfig -Module 'Pwt.Component.Sqlite')['ConnectionString']
        Close-SqlConnection -ConnectionName SQLite
    }
}
function Invoke-Sql {
    <#
        .SYNOPSIS
        Invoke-SqlQuery preset.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Query', SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType('Data.DataTable[]')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Query')]
        [AllowEmptyString()]
        [string[]]
        ${Query},

        [Parameter(Position = 1)]
        [hashtable]
        ${Parameters},

        [int]
        ${CommandTimeout},

        [Alias('cn')]
        [ValidateNotNullOrEmpty()]
        ${ConnectionName},

        [switch]
        ${Stream},

        [switch]
        ${AsDataTable},

        [switch]
        ${ProviderTypes},

        # Sets $Query to content of a file.
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'QueryPath')]
        [string]
        $QueryPath,

        # Sets "Format Operator" like `$Query -f $QueryFormat` ($Query string need to have {N} in it).
        $QueryFormat,

        # Run Invoke-SqlUpdate instead of Invoke-SqlQuery.
        [switch]
        $Update,

        # Run Invoke-SqlScalar instead of Invoke-SqlQuery.
        [switch]
        $Scalar,

        [switch]
        $Connect
    )

    begin {
        try {
            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer)) {
                $PSBoundParameters['OutBuffer'] = 1
            }

            # QueryPath
            if ($QueryPath) {
                $PSBoundParameters['Query'] = Get-Content -Path ($QueryPath | Get-PwtRootedPath)
            }
            $null = $PSBoundParameters.Remove('QueryPath')

            # QueryFormat
            if ($QueryFormat) {
                $PSBoundParameters['Query'] = ($PSBoundParameters['Query'] | Out-String) -f $QueryFormat
            }
            $null = $PSBoundParameters.Remove('QueryFormat')

            if (!$PSBoundParameters.ContainsKey('ConnectionName')) {
                $PSBoundParameters['ConnectionName'] = 'SQLite'
            }

            $null = $PSBoundParameters.Remove('WhatIf')
            $null = $PSBoundParameters.Remove('Confirm')
            $null = $PSBoundParameters.Remove('Update')
            $null = $PSBoundParameters.Remove('Scalar')
            $null = $PSBoundParameters.Remove('Connect')
            if ($Connect) {
                Connect-Sql
            }
            if (!$PSCmdlet.ShouldProcess(($PSBoundParameters | Out-String))) {
                $scriptCmd = { & Out-String -InputObject $PSBoundParameters['Query'] }
            }
            else {
                if ($Update) {
                    $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Invoke-SqlUpdate', [System.Management.Automation.CommandTypes]::Function)
                }
                elseif ($Scalar) {
                    $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Invoke-SqlScalar', [System.Management.Automation.CommandTypes]::Function)
                }
                else {
                    $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Invoke-SqlQuery', [System.Management.Automation.CommandTypes]::Function)
                }
                $scriptCmd = { & $wrappedCmd @PSBoundParameters -WarningAction 'Stop' }
            }

            $steppablePipeline = $scriptCmd.GetSteppablePipeline()
            $steppablePipeline.Begin($PSCmdlet)
        }
        catch {
            throw
        }
    }

    process {
        try {
            $steppablePipeline.Process($_)
        }
        catch {
            throw
        }
    }

    end {
        try {
            $steppablePipeline.End()
        }
        catch {
            throw
        }
    }
    clean {
        if ($Connect) {
            Disconnect-Sql
        }
    }
    <#

    .ForwardHelpTargetName Invoke-SqlQuery
    .ForwardHelpCategory Function

    #>
}
function Invoke-SqlCreateTables {
    [CmdletBinding()]
    param ()
    if (!(Invoke-Sql -Scalar -QueryPath (Join-Path $PSScriptRoot 'Session\TableGet.sql'))) {
        $null = Invoke-Sql -Update -QueryPath (Join-Path $PSScriptRoot 'Session\TableCreate.sql')
    }
    if (!(Invoke-Sql -Scalar -QueryPath (Join-Path $PSScriptRoot 'User\TableGet.sql'))) {
        $null = Invoke-Sql -Update -QueryPath (Join-Path $PSScriptRoot 'User\TableCreate.sql')
    }
    if (!(Invoke-Sql -Scalar -QueryPath (Join-Path $PSScriptRoot 'Group\TableGet.sql'))) {
        $null = Invoke-Sql -Update -QueryPath (Join-Path $PSScriptRoot 'Group\TableCreate.sql')
    }
    if (!(Invoke-Sql -Scalar -QueryPath (Join-Path $PSScriptRoot 'UserGroup\TableGet.sql'))) {
        $null = Invoke-Sql -Update -QueryPath (Join-Path $PSScriptRoot 'UserGroup\TableCreate.sql')
    }
}
function New-SqlPodeStoreObject {
    [CmdletBinding()]
    param ()
    [PSCustomObject]@{
        Get    = {
            param($sessionId)
            return Invoke-Sql -Scalar -QueryPath (Join-Path $PSScriptRoot 'Session\ItemGet.sql') -QueryFormat $sessionId -Connect | ConvertFrom-Json -AsHashtable
        }
        Set    = {
            param($sessionId, $data, $expiry)
            $null = Invoke-Sql -Update -QueryPath (Join-Path $PSScriptRoot 'Session\ItemSet.sql') -QueryFormat $sessionId, ($data | ConvertTo-Json -Depth 99), $expiry -Connect
        }
        Delete = {
            param($sessionId)
            $null = Invoke-Sql -Update -QueryPath (Join-Path $PSScriptRoot 'Session\ItemDelete.sql') -QueryFormat $sessionId -Connect
        }
    }
}
function New-SqlPodeAuthScriptBlock {
    [CmdletBinding()]
    param ()
    {
        param($User)
        # Wait-Debugger
        # $WebEvent.Auth.User
        $Config = Invoke-Sql -QueryPath (Join-Path $PSScriptRoot 'User\ItemGet.sql') -QueryFormat $User.Username -Connect
        if ($Config.Theme) {
            $User.Theme = $Config.Theme
        }
        return @{ User = $User }
        # param($user)


        # return @{ Message = "n $user" }
    }
}
function Add-PodeAuthSqlite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        ${Name},

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true)]
        [hashtable]
        ${Scheme},

        # [Parameter(Mandatory = $true, Position = 2)]
        # [ValidateScript({
        #         if (Test-PodeIsEmpty $_) {
        #             throw "A non-empty ScriptBlock is required for the authentication method"
        #         }

        #         return $true
        #     })]
        # [scriptblock]
        # ${ScriptBlock},

        [Parameter(Position = 3)]
        [System.Object[]]
        ${ArgumentList},

        [Parameter(Position = 4)]
        [string]
        ${FailureUrl},

        [Parameter(Position = 5)]
        [string]
        ${FailureMessage},

        [Parameter(Position = 6)]
        [string]
        ${SuccessUrl},

        [switch]
        ${Sessionless},

        [switch]
        ${SuccessUseOrigin}
    )

    begin {
        try {
            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer)) {
                $PSBoundParameters['OutBuffer'] = 1
            }

            $PSBoundParameters['ScriptBlock'] = {
                param(
                    # [Parameter(Mandatory)]
                    [string]$Username,
                    # [Parameter(Mandatory)]
                    [string]$Password
                )
                $Config = Invoke-Sql -QueryPath (Join-Path $PSScriptRoot 'User\ItemGet.sql') -QueryFormat $Username -Connect
                if ($Config.Count -eq 1 -and $Config.Password -eq $Password) {
                    $User = @{
                        Username           = $Config.Username
                        Name               = $Config.Name
                        Email              = $Config.Email
                        Groups             = $Config.Groups
                        AuthenticationType = 'Sqlite'
                    }
                    if ($Config.Theme) {
                        $User.Theme = $Config.Theme
                    }
                    return @{ User = $User }
                }
                else {
                    return @{ Message = 'Invalid username or password' }
                }
            }

            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Add-PodeAuth', [System.Management.Automation.CommandTypes]::Function)
            $scriptCmd = { & $wrappedCmd @PSBoundParameters }

            $steppablePipeline = $scriptCmd.GetSteppablePipeline()
            $steppablePipeline.Begin($PSCmdlet)
        }
        catch {
            throw
        }
    }

    process {
        try {
            $steppablePipeline.Process($_)
        }
        catch {
            throw
        }
    }

    end {
        try {
            $steppablePipeline.End()
        }
        catch {
            throw
        }
    }

    clean {
        if ($null -ne $steppablePipeline) {
            $steppablePipeline.Clean()
        }
    }
    <#
    .ForwardHelpTargetName Add-PodeAuth
    .ForwardHelpCategory Function
    #>
}
