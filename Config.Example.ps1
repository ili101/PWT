# Rename to "Config.ps1" and fill required information.
@{
    # Initialize.
    #Install-Module -Name Pode
    #Install-Module -Name Pode.Web
    #Install-Module -Name ImportExcel
    ModulesPaths  = @( 'Pode', 'Pode.Web', 'ImportExcel' )

    # URL, Certificate, Theme & Title.
    Endpoint     = {
        # Http
        Add-PodeEndpoint -Address localhost -Protocol Http

        # Https Self Signed
        #Add-PodeEndpoint -Address localhost -Port 443 -Protocol Https -SelfSigned

        # Https Certificate
        #$Certificate = Get-PfxCertificate -FilePath 'MyCert.pfx' -Password 'PfxPass'
        #Add-PodeEndpoint -Address 109.226.1.69 -Port 443 -Protocol Https -X509Certificate $Certificate

        # Theme & Title
        Use-PodeWebTemplates -Title Tools -Theme Dark
    }

    <# Login (Optional uncomment).
    Login        = {
        Enable-PodeSessionMiddleware -Secret 'Cookies jar lid' -Duration (10 * 60) -Extend
        New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'MyDomain' -Groups 'IT'
        Set-PodeWebLoginPage -Authentication 'MyDomain'
    }
    #>
    #<# Login from file with SQLite session.
    Login        = {
        Import-Module -Name SimplySql
        Open-SQLiteConnection -ConnectionName SQLite -ConnectionString ('Data Source={0};ForeignKeys=True;recursive_triggers=True' -f (Join-Path (Get-PodeServerPath).Replace('\\', '\\\\') '\Storage\Tool.db'))
        if (!(Invoke-SqlScalar -ConnectionName SQLite -Query (Get-Content .\SQL\Session\TableGet.sql))) {
            Invoke-SqlUpdate -ConnectionName SQLite -Query (Get-Content .\SQL\Session\TableCreate.sql)
        }
        $Store = [PSCustomObject]@{
            Get    = {
                param($sessionId)
                Open-SQLiteConnection -ConnectionName SQLite -ConnectionString ('Data Source={0};ForeignKeys=True;recursive_triggers=True' -f (Join-Path (Get-PodeServerPath).Replace('\\', '\\\\') '\Storage\Tool.db'))
                return Invoke-SqlScalar -ConnectionName SQLite -Query ((Get-Content .\SQL\Session\ItemGet.sql | Out-String) -f $sessionId) | ConvertFrom-Json -AsHashtable
            }
            Set    = {
                param($sessionId, $data, $expiry)
                Open-SQLiteConnection -ConnectionName SQLite -ConnectionString ('Data Source={0};ForeignKeys=True;recursive_triggers=True' -f (Join-Path (Get-PodeServerPath).Replace('\\', '\\\\') '\Storage\Tool.db'))
                $null = Invoke-SqlUpdate -ConnectionName SQLite -Query ((Get-Content .\SQL\Session\ItemSet.sql | Out-String) -f $sessionId, ($data | ConvertTo-Json -Depth 99), $expiry)
            }
            Delete = {
                param($sessionId)
                Open-SQLiteConnection -ConnectionName SQLite -ConnectionString ('Data Source={0};ForeignKeys=True;recursive_triggers=True' -f (Join-Path (Get-PodeServerPath).Replace('\\', '\\\\') '\Storage\Tool.db'))
                $null = Invoke-SqlUpdate -ConnectionName SQLite -Query ((Get-Content .\SQL\Session\ItemDelete.sql | Out-String) -f $sessionId)
            }
        }

        Enable-PodeSessionMiddleware -Secret 'Cookies jar lid' -Duration (10 * 60) -Extend -Storage $Store
        New-PodeAuthScheme -Form | Add-PodeAuthUserFile -Name 'MyDomain' -FilePath '.\Example\Users.json'
        Set-PodeWebLoginPage -Authentication 'MyDomain'

        if (!(Invoke-SqlScalar -ConnectionName SQLite -Query (Get-Content .\SQL\User\TableGet.sql))) {
            Invoke-SqlUpdate -ConnectionName SQLite -Query (Get-Content .\SQL\User\TableCreate.sql)
        }
    }
    #>

    # Exchange Config.
    Exchange     = @{
        # For demo test mode:
        Dummy         = $true

        # For remote connection:
        #ConnectionUri = 'http://exchange.example.com/powershell'
        #Credential    = [System.Management.Automation.PSCredential]::new('ServiceUser', (ConvertTo-SecureString 'Do not save passwords in plain text' -AsPlainText -Force))

        # For "Exchange Management Shell" mode:
        # Requires "Exchange management tools" installed (PowerShell Core not supported).
        #Tools         = $true
    }

    # General.
    Debug        = $true
    DownloadPath = '.\Storage\Download'
}