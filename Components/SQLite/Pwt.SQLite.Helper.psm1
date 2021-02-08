function Connect-Sql {
    [CmdletBinding()]
    param ()
    if (!(Get-SqlConnection -ConnectionName SQLite -WarningAction SilentlyContinue)) {
        $StoragePath = (Get-PodeConfig)['Global']['StoragePath']
        Open-SQLiteConnection -ConnectionName SQLite -ConnectionString ('Data Source={0};ForeignKeys=True;recursive_triggers=True' -f (Join-Path $StoragePath.Replace('\\', '\\\\') '\Tool.db'))
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
        $Scalar
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
                $scriptCmd = { & $wrappedCmd @PSBoundParameters }
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
    <#

    .ForwardHelpTargetName Invoke-SqlQuery
    .ForwardHelpCategory Function

    #>
}
function Invoke-SqlCreateTables {
    [CmdletBinding()]
    param ()
    if (!(Invoke-Sql -Scalar -QueryPath '\Components\SQLite\Session\TableGet.sql')) {
        $null = Invoke-Sql -Update -QueryPath '\Components\SQLite\Session\TableCreate.sql'
    }
    if (!(Invoke-Sql -Scalar -QueryPath '\Components\SQLite\User\TableGet.sql')) {
        $null = Invoke-Sql -Update -QueryPath '\Components\SQLite\User\TableCreate.sql'
    }
}
function New-SqlPodeStoreObject {
    [CmdletBinding()]
    param ()
    [PSCustomObject]@{
        Get    = {
            param($sessionId)
            Connect-Sql
            return Invoke-Sql -Scalar -QueryPath '\Components\SQLite\Session\ItemGet.sql' -QueryFormat $sessionId | ConvertFrom-Json -AsHashtable
        }
        Set    = {
            param($sessionId, $data, $expiry)
            Connect-Sql
            $null = Invoke-Sql -Update -QueryPath '\Components\SQLite\Session\ItemSet.sql' -QueryFormat $sessionId, ($data | ConvertTo-Json -Depth 99), $expiry
        }
        Delete = {
            param($sessionId)
            Connect-Sql
            $null = Invoke-Sql -Update -QueryPath '\Components\SQLite\Session\ItemDelete.sql' -QueryFormat $sessionId
        }
    }
}
function New-SqlPodeAuthScriptBlock {
    [CmdletBinding()]
    param ()
    {
        param($User)
        Connect-Sql
        $Config = Invoke-Sql -QueryPath '\Components\SQLite\User\ItemGet.sql' -QueryFormat $User.Username
        if ($Config.Theme) {
            $User.Theme = $Config.Theme
        }
        return @{ User = $User }
    }
}
function Initialize-SqlComponent {
    [CmdletBinding()]
    param (
        # Enable users settings page.
        [Switch]$SettingsPage,
        # Create SQL tables if not exists.
        [Switch]$CreateTables
    )
    $Config = Get-PodeConfig
    if (!$Config.ContainsKey('Components')) {
        $Config['Components'] = @{}
    }
    if (!$Config['Components'].ContainsKey('SQLite')) {
        $Config['Components']['SQLite'] = @{}
    }
    $Config['Components']['SQLite']['Enable'] = $true
    if ($SettingsPage) {
        $Config['Components']['SQLite']['SettingsPage'] = $true
    }
    Connect-Sql
    if ($CreateTables) {
        Invoke-SqlCreateTables
    }
}