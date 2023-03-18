function Initialize-PwtEf {
    [CmdletBinding()]
    param (
        # # Enable users settings page.
        # [Switch]$SettingsPage,
        # # Enable admin settings page.
        # [Switch]$AdminPage,
        # # Create SQL tables if not exists.
        # [Switch]$CreateTables
    )
    {
        $Config = Get-PwtConfig -Module 'Pwt.Component.Ef'

        # $BaseReferencedAssemblies = [IO.Directory]::GetFiles([IO.Path]::Combine($PSHOME, 'ref'), '*.dll', [IO.SearchOption]::TopDirectoryOnly)
        Add-Type -Path (Join-Path $PSScriptRoot 'Classes.cs')

        $Tables = @(
            (New-EFPoshEntityDefinition -Type 'Pwt.Ef.User' -PrimaryKey 'Username' -TableName 'User'),
            (New-EFPoshEntityDefinition -Type 'Pwt.Ef.Group' -PrimaryKey 'GroupName' -TableName 'Group')
        )

        $StoragePath = (Get-PwtConfig -Module 'Pwt.Component.Core')['StoragePath']
        $ConnectionString = ('Data Source={0}' -f (Join-Path $StoragePath.Replace('\\', '\\\\') '\Ef.db'))

        $Config['EfParams'] = @{
            ConnectionString = $ConnectionString
            DBType           = 'SQLite'
            Entities         = $Tables
        }
        if ($Config.ContainsKey('CreateTables')) {
            $Config['EfParams']['EnsureCreated'] = $Config['CreateTables']
        }

        $EfParams = $Config['EfParams']
        $Context = New-EFPoshContext @EfParams

        # MAYBE: Use `[Microsoft.AspNetCore.Identity.UserManager[Pwt.Ef.User]]`.
        Add-Type -Path (Join-Path ((Get-Module Pode.Kestrel).Path | Split-Path) 'Libs' 'Microsoft.Extensions.Identity.Core.dll')
    }
}
function Get-HashPassword {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Password
    )
    # $PasswordHasherOptions = [Microsoft.AspNetCore.Identity.PasswordHasherOptions]::new()
    # $RuntimeMethodInfo = [Microsoft.Extensions.Options.Options].GetMethod('Create').MakeGenericMethod([Microsoft.AspNetCore.Identity.PasswordHasherOptions])
    # $OptionsWrapper = $RuntimeMethodInfo.Invoke($null, ($PasswordHasherOptions))
    $PasswordHasher = [Microsoft.AspNetCore.Identity.PasswordHasher[String]]::new()
    $PasswordHasher.HashPassword($null, $Password)
}
function Test-HashPassword {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$HashedPassword,
        [Parameter(Mandatory)]
        [string]$Password
    )
    $PasswordHasher = [Microsoft.AspNetCore.Identity.PasswordHasher[String]]::new()
    $PasswordHasher.VerifyHashedPassword($null, $HashedPassword, $Password)
}

function Get-PwtEf_Snippet {
    [CmdletBinding(DefaultParameterSetName = 'New')]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('User', 'Group')]
        [String]$Table,
        [Parameter(Mandatory)]
        [ValidateSet('Get', 'Set', 'Delete')]
        [String]$Action,
        [Parameter(Mandatory)]
        [ValidateSet('New', 'Existing')]
        [String]$Variant,
        [Parameter(Mandatory, ParameterSetName = 'Existing')]
        [string]$Username,
        [switch]$PassThru,
        [switch]$Restricted
    )
    if ($Action -eq 'Get') {
        if ($Variant -eq 'Existing') {
            . Connect-PwtEfSql -ScriptBlock {
                $ConfigTable = Search-EFPosh -Entity User -Expression { $_.Username -eq $Username } -Include 'Groups'
            }
        }
        elseif ($Variant -eq 'New') {
            $ConfigTable = ([Type]"Pwt.Ef.$Table")::new()
        }
        $Filter = if ($Table -eq 'User') {
            $_Filter = 'Username', 'Password', 'Name', 'Theme', 'Email'
            if ($Restricted) {
                $_Filter
            }
            else {
                $_Filter + 'Groups'
            }
        }
        else {
            'GroupName'
        }
        foreach ($Column in ($ConfigTable.PsObject.Properties | Where-Object 'Name' -In $Filter)) {
            $Params = @{}
            $Disabled = $Table -eq 'User' -and $Variant -eq 'Existing' -and $Column.Name -in 'Username'
            switch ($Column.TypeNameOfValue) {
                'System.Boolean' {
                    if ($Column.Value) {
                        $Params.Checked = $true
                    }
                    if ($Disabled) {
                        $Params.Disabled = $true
                    }
                    New-PodeWebCheckbox -Name $Column.Name -AsSwitch @Params
                }
                'System.Int32' {
                    if ($Disabled) {
                        $Params.ReadOnly = $true
                    }
                    New-PodeWebTextbox -Name $Column.Name -Value $Column.Value -Type Number @Params
                }
                'System.String' {
                    $Params.Value = $Column.Value
                    switch -Wildcard ($Column.Name) {
                        "*Password*" {
                            $Params.Type = 'Password'
                            $Params.Remove('Value')
                            if ($Variant -eq 'Existing') {
                                New-PodeWebCheckbox -Name 'ChangePassword' -DisplayName 'Change password' -AsSwitch
                            }
                        }
                        "*Email*" { $Params.Type = 'Email' }
                    }
                    if ($Disabled) {
                        $Params.ReadOnly = $true
                    }
                    New-PodeWebTextbox -Name $Column.Name @Params
                }
                Default {
                    if (([Type]$_).BaseType.Name -eq 'Enum') {
                        New-PodeWebSelect -Name $Column.Name -Options ([Enum]::GetValues([type]$_)) -SelectedValue $Column.Value
                    }
                    elseif (([Type]$_).Name -like 'List*') {
                        $SubType = ([Type]$_).GenericTypeArguments[0]
                        . Connect-PwtEfSql -ScriptBlock {
                            $ObjectsList = Search-EFPosh -Entity $SubType.Name
                        }
                        $KeyName = ${ObjectsList}?[0].PsObject.Properties | Select-Object -First 1 -ExpandProperty Name
                        New-PodeWebSelect -Name $Column.Name -Options ($ObjectsList.$KeyName) -Multiple -SelectedValue $Column.Value.$KeyName
                    }
                }
            }
        }
    }
    elseif ($Action -eq 'Set') {
        # {
        try {
            if ($Variant -eq 'Existing') {
                . Connect-PwtEfSql -ScriptBlock {
                    $User = Search-EFPosh -Entity User -Expression { $_.Username -eq $WebEvent.Data.Username } -Include 'Groups'
                    'Name', 'Theme', 'Email' | ForEach-Object {
                        $User.$_ = $WebEvent.Data.$_
                    }
                    if ($WebEvent.Data.ChangePassword) {
                        $User.Password = Get-HashPassword -Password $WebEvent.Data.Password
                    }
                    # Wait-Debugger
                    if (!$Restricted) {
                        $GroupsArray = $WebEvent.Data.Groups -split ','
                        $Group = Search-EFPosh -Entity Group -Expression { $GroupsArray -contains $_.GroupName }
                        $User.Groups = $Group
                    }
                }
            }
            elseif ($Variant -eq 'New') {
                # Wait-Debugger
                Connect-PwtEfSql -ScriptBlock {
                    if ($Table -eq 'User') {
                        $GroupsArray = $WebEvent.Data.Groups -split ','
                        $Group = Search-EFPosh -Entity Group -Expression { $GroupsArray -contains $_.GroupName }
                        $WebEvent.Data.Groups = $Group
                    }
                    $User = $WebEvent.Data -as ([Type]"Pwt.Ef.$Table")
                    if ($Table -eq 'User') {
                        $User.Password = Get-HashPassword -Password $User.Password
                        $User.AuthenticationType = 'Sqlite'
                        [MailAddress]$User.Email | Out-Null
                    }
                    Add-EFPoshEntity -Entity $User
                }
            }
            if ($PassThru) {
                $User
            }
        }
        catch {
            $_ | Get-ErrorMessage | ForEach-Object {
                Show-PodeWebToast -Message $_ -Duration ([int]::MaxValue) -Title 'Error'
            }
        }
    }
}
function Get-PwtPagesEf {
    [CmdletBinding()]
    param ()
    {
        $Config = Get-PwtConfig -Module 'Pwt.Component.Ef'
        if ($Config['SettingsPage']) {
            Add-PodeWebPage -Name 'Settings' -Icon cog-outline -ScriptBlock {
                New-PodeWebForm -Name 'Account' -AsCard -Content @(
                    Get-PwtEf_Snippet -Table 'User' -Action 'Get' -Variant 'Existing' -Username $WebEvent.Auth.User.Username -Restricted

                ) -ScriptBlock {
                    if ($WebEvent.Data.Username -ne $WebEvent.Auth.User.Username) {
                        throw 'You can only edit your own account.'
                    }
                    $User = Get-PwtEf_Snippet -Table 'User' -Action 'Set' -Variant 'Existing' -PassThru -Restricted

                    'Username', 'Name', 'Email', 'AuthenticationType' | ForEach-Object {
                        $WebEvent.Auth.User.$_ = $User.$_
                    }
                    if ($User.Groups) {
                        $WebEvent.Auth.User.Groups = $User.Groups.GroupName
                    }
                    if ($User.Theme) {
                        $WebEvent.Auth.User.Theme = $User.Theme.ToString()
                    }
                    else {
                        $WebEvent.Auth.User.Remove('Theme')
                    }
                    Reset-PodeWebTheme
                }
            }
        }
        if ($Config['AdminPage']) {
            $WebPageParams = @{}
            if ($null -ne $Config['AdminPageAccessGroups']) {
                $WebPageParams.AccessGroups = $Config['AdminPageAccessGroups']
            }
            Add-PodeWebPage @WebPageParams -Group 'Admin' -Name 'Users' -Icon 'account-details-outline' -ScriptBlock {
                $Username = $WebEvent.Query['value']
                if ([string]::IsNullOrWhiteSpace($Username)) {
                    # Main table page.
                    $Table = New-PodeWebTable -Name 'Explorer' -Id 'AdminUsers' -DataColumn 'Username' -Filter -Sort -Click -Paginate -ScriptBlock {
                        Connect-PwtEfSql -ScriptBlock {
                            Search-EFPosh -Entity 'User' -Include 'Groups' | Select-Object @(
                                'Username'
                                'Name'
                                'Theme'
                                'Email'
                                'AuthenticationType'
                                @{ Name = 'Groups'; Expression = { $_.Groups.GroupName -join ', ' } }
                                @{ Name = 'Delete'; Expression = {
                                        New-PodeWebButton -Name 'Delete' -Icon 'delete' -ScriptBlock {
                                            Connect-PwtEfSql -ScriptBlock {
                                                Remove-EFPoshEntity -Entity (Search-EFPosh -Entity 'User' -Expression { $_.Username -eq $WebEvent.Data.Value })
                                            }
                                            Sync-PodeWebTable -Id 'AdminUsers'
                                        }
                                    }
                                }
                            )
                        }
                    }
                    $Table | Add-PodeWebTableButton -Name 'Add' -Icon 'account-plus-outline' -ScriptBlock {
                        Show-PodeWebModal -Name 'Add'
                    }
                    $Table
                    # User add page.
                    New-PodeWebModal -Name 'Add' -AsForm -Content @(
                        Get-PwtEf_Snippet -Table 'User' -Action 'Get' -Variant 'New'
                    ) -ArgumentList '' -ScriptBlock {
                        Get-PwtEf_Snippet -Table 'User' -Action 'Set' -Variant 'New'
                        Sync-PodeWebTable -Id 'AdminUsers'
                        Hide-PodeWebModal
                    }
                }
                else {
                    # User edit page.
                    New-PodeWebForm -Name 'Account' -AsCard -Content @(
                        Get-PwtEf_Snippet -Table 'User' -Action 'Get' -Variant 'Existing' -Username $Username
                    ) -ScriptBlock {
                        Get-PwtEf_Snippet -Table 'User' -Action 'Set' -Variant 'Existing'
                        # WORKAROUND: Move-PodeWebUrl not accepting `Move-PodeWebUrl -Url ''`.
                        Move-PodeWebUrl -Url '?'
                        # TODO: Reset user session.
                    }
                }
            }
            Add-PodeWebPage @WebPageParams -Group 'Admin' -Name 'Groups' -Icon 'account-group-outline' -ScriptBlock {
                $Table = New-PodeWebTable -Name 'Explorer' -Id 'AdminGroups' -DataColumn 'GroupName' -Filter -Sort -Paginate -ScriptBlock {
                    Connect-PwtEfSql -ScriptBlock {
                        Search-EFPosh -Entity 'Group' -Include 'Users' | Select-Object @(
                            'GroupName'
                            @{ Name = 'Users'; Expression = { $_.Users.Username -join ', ' } }
                            @{ Name = 'Delete'; Expression = {
                                    New-PodeWebButton -Name 'Delete' -Icon 'delete' -ScriptBlock {
                                        Connect-PwtEfSql -ScriptBlock {
                                            Remove-EFPoshEntity -Entity (Search-EFPosh -Entity 'Group' -Expression { $_.GroupName -eq $WebEvent.Data.Value })
                                        }
                                        Sync-PodeWebTable -Id 'AdminGroups'
                                    }
                                }
                            }
                        )
                    }
                }
                $Table | Add-PodeWebTableButton -Name 'Add' -Icon 'account-plus-outline' -ScriptBlock {
                    Show-PodeWebModal -Name 'Add'
                }
                $Table
                New-PodeWebModal -Name 'Add' -AsForm -Content @(
                    Get-PwtEf_Snippet -Table 'Group' -Action 'Get' -Variant 'New'
                ) -ScriptBlock {
                    Get-PwtEf_Snippet -Table 'Group' -Action 'Set' -Variant 'New'
                    Sync-PodeWebTable -Id 'AdminGroups'
                    Hide-PodeWebModal
                }
            }
        }
    }
}

function Connect-PwtEfSql {
    [CmdletBinding()]
    param (
        [scriptblock]
        $ScriptBlock
    )
    $EfParams = (Get-PwtConfig -Module 'Pwt.Component.Ef')['EfParams']
    $Context = New-EFPoshContext @EfParams
    if ($ScriptBlock) {
        try {
            . $ScriptBlock
        }
        finally {
            Save-EFPoshChanges
            # try {
            #     Save-EFPoshChanges
            # }
            # catch {
            #     $Context.DBContext.ChangeTracker.Clear()
            # }
        }
    }
}
function Disconnect-Sql {
    [CmdletBinding()]
    param ()
    if ((Get-SqlConnection -ConnectionName SQLite -WarningAction SilentlyContinue)) {
        $ConnectionString = (Get-PwtConfig -Module 'Pwt.Component.Ef')['ConnectionString']
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

function New-PwtEfPodeAuthScriptBlock {
    [CmdletBinding()]
    param ()
    {
        param($UserPode)
        if (!$UserPode.AuthenticationType -and $UserPode.Metadata.AuthenticationType) {
            $UserPode.AuthenticationType = $UserPode.Metadata.AuthenticationType
        }
        . Connect-PwtEfSql -ScriptBlock {
            $UserEf = Search-EFPosh -Entity User -Expression { $_.Username -eq $UserPode.Username } -Include 'Groups'
        }
        if (!$UserEf) {
            $UserEf = [Pwt.Ef.User]::new()#$UserPode
            'Username', 'Name', 'Email', 'AuthenticationType' | ForEach-Object {
                $UserEf.$_ = $UserPode.$_
            }
            Connect-PwtEfSql -ScriptBlock {
                Add-EFPoshEntity -Entity $UserEf
            }
            return @{ User = $UserEf | Convert-EfUserToPodeUser }
        }
        elseif ($UserEf.Count -eq 1) {
            if ($UserEf.AuthenticationType -ne $UserPode.AuthenticationType) {
                return @{ Message = 'User with the same username already exists' }
            }
            else {
                return @{ User = $UserEf | Convert-EfUserToPodeUser }
            }
        }
        else {
            return @{ Message = 'Multiple user with the same username already exists' }
        }
    }
}
function Get-PodeAuthEfMethod {
    [CmdletBinding()]
    param()
    {
        param(
            # [Parameter(Mandatory)]
            [string]$Username,
            # [Parameter(Mandatory)]
            [string]$Password
        )
        . Connect-PwtEfSql -ScriptBlock {
            $User = Search-EFPosh -Entity User -Expression { $_.Username -eq $Username } -Include 'Groups'
        }
        if ($User.Count -ne 1 -or $User.AuthenticationType -ne 'Sqlite' -or !(Test-HashPassword -HashedPassword $User.Password -Password $Password)) {
            return @{ Message = 'Invalid username or password' }
        }

        $UserPode = $User | Convert-EfUserToPodeUser
        return @{ User = $UserPode }
    }
}

function Get-PodeAuthEf {
    [CmdletBinding()]
    param ()
    @{
        ScriptBlock = (Get-PodeAuthEfMethod)
        Arguments   = @{}
    }
}


function Add-PodeAuthEf {
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

            $PSBoundParameters['ScriptBlock'] = Get-PodeAuthEfMethod

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
function Convert-EfUserToPodeUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Pwt.Ef.User]
        $User
    )
    $UserPode = @{}
    'Username', 'Name', 'Email', 'AuthenticationType' | ForEach-Object {
        $UserPode.$_ = $User.$_
    }
    if ($User.Groups) {
        $UserPode.Groups = $User.Groups.GroupName
    }
    if ($User.Theme) {
        $UserPode.Theme = $User.Theme.ToString()
    }
    $UserPode
}