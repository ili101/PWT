# Copy to "Config.ps1" and fill required information.
# Support PODE_ENVIRONMENT https://badgerati.github.io/Pode/Tutorials/Configuration/
@{
    Global = @{
        # Initialize.
        #Install-Module -Name Pode
        #Install-Module -Name Pode.Web
        #Install-Module -Name ImportExcel
        ModulesPaths            = @('Pode', 'Pode.Web', 'ImportExcel')

        # URL, Certificate, Theme & Title.
        Endpoint                = {
            # Http.
            Add-PodeEndpoint -Address localhost -Protocol Http

            # Https Self Signed.
            #Add-PodeEndpoint -Address localhost -Port 443 -Protocol Https -SelfSigned

            # Https Certificate.
            #$Certificate = Get-PfxCertificate -FilePath 'MyCert.pfx' -Password 'PfxPass'
            #Add-PodeEndpoint -Address 192.168.1.69 -Port 443 -Protocol Https -X509Certificate $Certificate -Name 'Main'

            # Redirect http to https.
            #Add-PodeEndpoint -Address 192.168.1.69 -Port 80 -Protocol Http -Name 'Redirect'
            #Add-PodeRoute -Method * -Path * -EndpointName 'Redirect' -ScriptBlock { Move-PodeResponseUrl -Protocol Https -Port 443 }

            # Theme & Title
            Use-PodeWebTemplates -Title Tools -Theme Auto
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
            New-PodeAuthScheme -Form | Add-PodeAuthUserFile -Name 'MainAuth' -FilePath (Join-Path (Get-PodeServerPath) '\Components\Json\Example.json')
            Set-PodeWebLoginPage -Authentication 'MainAuth'
        }
        LoginAuthenticationName = 'MainAuth'
        #>
        <# Login from Json file with SQLite persistent session and user configuration page:
        # You can edit this to use AD + SQLite for example. If needed I can add an SQLite only example that stores the users in it.
        Login                   = {
            Import-Module -Name SimplySql
            Import-Module -Name (Join-Path (Get-PodeServerPath) '\Components\SQLite\Pwt.SQLite.Helper.psm1')
            Connect-Sql
            Invoke-SqlCreateTables
            Enable-PodeSessionMiddleware -Secret 'Cookies jar lid' -Duration (24 * 60 * 60) -Storage (New-SqlPodeStoreObject)
            New-PodeAuthScheme -Form | Add-PodeAuthUserFile -Name 'MainAuth' -FilePath (Join-Path (Get-PodeServerPath) '\Components\Json\Example.json') -ScriptBlock (New-SqlPodeAuthScriptBlock)
            Set-PodeWebLoginPage -Authentication 'MainAuth'
        }
        LoginAuthenticationName = 'MainAuth'
        # Enable the SQLite user configuration page:
        LoginUserConfiguration  = '.\Components\SQLite\SettingsPage.ps1'
        #>

        # General.
        Debug                   = $true
        StoragePath             = '.\Storage\'
        DownloadPath            = '.\Storage\Download'
    }
    Tools  = @{
        ExchangeMessageTrackingLog = @{
            # Enable this tool
            Enable = $true

            Connection = @{
                # For demo test mode:
                Dummy = $true

                # For remote connection:
                #ConnectionUri = 'http://exchange.example.com/powershell'
                #Credential    = [System.Management.Automation.PSCredential]::new('ServiceUser', (ConvertTo-SecureString 'Do not save passwords in plain text' -AsPlainText -Force))

                # For "Exchange Management Shell" mode:
                # Requires "Exchange management tools" installed (PowerShell Core not supported).
                #Tools         = $true
            }
        }
        Drive = @{
            # Enable this tool
            Enable = $false

            DriveRootPath = '.\Storage\Drive'
        }
    }
}