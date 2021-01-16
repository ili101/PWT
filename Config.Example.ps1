# Copy to "Config.ps1" and fill required information.
@{
    # Initialize.
    #Install-Module -Name Pode
    #Install-Module -Name Pode.Web
    #Install-Module -Name ImportExcel
    ModulesPaths            = @( 'Pode', 'Pode.Web', 'ImportExcel' )

    # URL, Certificate, Theme & Title.
    Endpoint                = {
        # Http
        Add-PodeEndpoint -Address localhost -Protocol Http

        # Https Self Signed
        #Add-PodeEndpoint -Address localhost -Port 443 -Protocol Https -SelfSigned

        # Https Certificate
        #$Certificate = Get-PfxCertificate -FilePath 'MyCert.pfx' -Password 'PfxPass'
        #Add-PodeEndpoint -Address 109.226.1.69 -Port 443 -Protocol Https -X509Certificate $Certificate

        # Theme & Title
        # TODO: Pode.Web: -Theme Auto?
        Use-PodeWebTemplates -Title Tools -Theme Dark
    }

    # Login [ScriptBlock] (Optional uncomment). If used LoginAuthenticationName [String] is required with the Authentication name.
    <# With AD:
    Login                   = {
        Enable-PodeSessionMiddleware -Secret 'Cookies jar lid' -Duration (10 * 60) -Extend
        New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'MainAuth' -Groups 'IT'
        Set-PodeWebLoginPage -Authentication 'MainAuth'
    }
    LoginAuthenticationName = 'MainAuth'
    #>
    <# Json file (Useful for testing):
    Login                   = {
        Enable-PodeSessionMiddleware -Secret 'Cookies jar lid' -Duration (10 * 60) -Extend
        New-PodeAuthScheme -Form | Add-PodeAuthUserFile -Name 'MainAuth' -FilePath '.\Example\Users.json'
        Set-PodeWebLoginPage -Authentication 'MainAuth'
    }
    LoginAuthenticationName = 'MainAuth'
    #>
    <# Login from Json file with SQLite persistent session and user configuration page:
    # You can edit this to use AD + SQLite for example. If needed I can add an SQLite only example that stores the users in it.
    Login                   = {
        Import-Module -Name SimplySql
        Connect-Database
        if (!(Invoke-SqlScalar -ConnectionName SQLite -Query (Get-Content .\SQL\Session\TableGet.sql))) {
            $null = Invoke-SqlUpdate -ConnectionName SQLite -Query (Get-Content .\SQL\Session\TableCreate.sql)
        }
        $Store = [PSCustomObject]@{
            Get    = {
                param($sessionId)
                Connect-Database
                return Invoke-SqlScalar -ConnectionName SQLite -Query ((Get-Content .\SQL\Session\ItemGet.sql | Out-String) -f $sessionId) | ConvertFrom-Json -AsHashtable
            }
            Set    = {
                param($sessionId, $data, $expiry)
                Connect-Database
                $null = Invoke-SqlUpdate -ConnectionName SQLite -Query ((Get-Content .\SQL\Session\ItemSet.sql | Out-String) -f $sessionId, ($data | ConvertTo-Json -Depth 99), $expiry)
            }
            Delete = {
                param($sessionId)
                Connect-Database
                $null = Invoke-SqlUpdate -ConnectionName SQLite -Query ((Get-Content .\SQL\Session\ItemDelete.sql | Out-String) -f $sessionId)
            }
        }

        Enable-PodeSessionMiddleware -Secret 'Cookies jar lid' -Duration (24 * 60 * 60) -Storage $Store
        New-PodeAuthScheme -Form | Add-PodeAuthUserFile -Name 'MainAuth' -FilePath '.\Example\Users.json' -ScriptBlock {
            param($User)
            Connect-Database
            $Config = Invoke-SqlQuery -ConnectionName SQLite -Query ((Get-Content .\SQL\User\ItemGet.sql | Out-String) -f $User.Username)
            if ($Config.Theme) {
                $User.Theme = $Config.Theme
            }
            return @{ User = $User }
        }
        Set-PodeWebLoginPage -Authentication 'MainAuth'

        if (!(Invoke-SqlScalar -ConnectionName SQLite -Query (Get-Content .\SQL\User\TableGet.sql))) {
            $null = Invoke-SqlUpdate -ConnectionName SQLite -Query (Get-Content .\SQL\User\TableCreate.sql)
        }
    }
    LoginAuthenticationName = 'MainAuth'
    # Enable the SQLite user configuration page:
    LoginUserConfiguration  = $true
    #>

    # Exchange Config.
    Exchange                = @{
        # For demo test mode:
        Dummy = $true

        # For remote connection:
        #ConnectionUri = 'http://exchange.example.com/powershell'
        #Credential    = [System.Management.Automation.PSCredential]::new('ServiceUser', (ConvertTo-SecureString 'Do not save passwords in plain text' -AsPlainText -Force))

        # For "Exchange Management Shell" mode:
        # Requires "Exchange management tools" installed (PowerShell Core not supported).
        #Tools         = $true
    }

    # General.
    Debug                   = $true
    DownloadPath            = '.\Storage\Download'
}