# Copy to "Config.ps1" and fill required information.
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

    # Login (Optional uncomment).
    <# With AD:
    Login        = {
        Enable-PodeSessionMiddleware -Secret 'Cookies jar lid' -Duration (10 * 60) -Extend
        New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'MainAuth' -Groups 'IT'
        Set-PodeWebLoginPage -Authentication 'MainAuth'
    }
    #>
    <# Json file:
    Login        = {
        Enable-PodeSessionMiddleware -Secret 'Cookies jar lid' -Duration (10 * 60) -Extend -Storage $Store
        New-PodeAuthScheme -Form | Add-PodeAuthUserFile -Name 'MainAuth' -FilePath '.\Example\Users.json'
        Set-PodeWebLoginPage -Authentication 'MainAuth'
    }
    #>
    #<# Login from file with SQLite session:
    Login        = {
        Import-Module -Name SimplySql
        Connect-Database
        if (!(Invoke-SqlScalar -ConnectionName SQLite -Query (Get-Content .\SQL\Session\TableGet.sql))) {
            Invoke-SqlUpdate -ConnectionName SQLite -Query (Get-Content .\SQL\Session\TableCreate.sql)
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

        # TODO: -Extend not implemented in Pode?
        Enable-PodeSessionMiddleware -Secret 'Cookies jar lid' -Duration (24 * 60 * 60) -Storage $Store
        New-PodeAuthScheme -Form | Add-PodeAuthUserFile -Name 'MainAuth' -FilePath '.\Example\Users.json'
        Set-PodeWebLoginPage -Authentication 'MainAuth'

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