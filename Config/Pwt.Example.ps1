# Copy to "Config.ps1" and fill required information.
# Support PODE_ENVIRONMENT https://badgerati.github.io/Pode/Tutorials/Configuration/
$Config = @{
    # TODO: Remove "Global"
    Global     = @{
        # Initialize.
        #Install-Module -Name Pode
        #Install-Module -Name Pode.Web
        #Install-Module -Name Pode.Kestrel
        #Install-Module -Name ImportExcel
        ModulesPaths     = @(
            'Pode',
            'Pode.Web',
            'Pode.Kestrel',
            'ImportExcel',
            'SimplySql',
            'EFPosh'
        )

        # Configure parameters for `Start-PodeServer`.
        PodeServerParams = @{
            # Use Pode.Kestrel, see https://github.com/Badgerati/Pode.Kestrel.
            #ListenerType = 'Kestrel'
        }

        # URL, Certificate, Theme & Title.
        Endpoint         = {
            # Http.
            Add-PodeEndpoint -Address localhost -Protocol Http -Name 'Main'

            # Https Self Signed.
            #Add-PodeEndpoint -Address localhost -Port 443 -Protocol Https -SelfSigned -Name 'Main'

            # Https Certificate.
            #$Certificate = Get-PfxCertificate -FilePath 'MyCert.pfx' -Password 'PfxPass'
            #Add-PodeEndpoint -Address 192.168.1.69 -Port 443 -Protocol Https -X509Certificate $Certificate -Name 'Main'

            # Redirect http to https.
            #Add-PodeEndpoint -Address 192.168.1.69 -Port 80 -Protocol Http -Name 'Redirect'
            #Add-PodeRoute -Method * -Path * -EndpointName 'Redirect' -ScriptBlock { Move-PodeResponseUrl -Protocol Https -Port 443 }

            # Theme & Title.
            Use-PodeWebTemplates -Title Tools -Theme Auto -EndpointName 'Main'

            # Set EndpointName for routes.
            # Cusses problems on Pode 2.1.0 https://github.com/Badgerati/Pode/issues/686
            if ((Get-Module -Name Pode).Version -gt '2.1.0') {
                Set-PwtRouteParams -EndpointName 'Main'
            }

            # If using the tool "Drive" and not using any "Login" add a PodeSessionMiddleware.
            # Skipped if "Login" is activated to prevent conflict.

            # Enable-PodeSessionMiddleware -Secret 'Cookies jar lid' -Duration (10 * 60) -Extend
            Enable-PodeSessionMiddleware -Secret 'Cookies jar lid' -Duration (24 * 60 * 60) -Storage (New-SqlPodeStoreObject)
        }

        # Login [ScriptBlock] (Optional uncomment).
        <# With AD:
        Login        = {
            Enable-PodeSessionMiddleware -Secret 'Cookies jar lid' -Duration (10 * 60) -Extend
            New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'MainAuth' -Groups 'IT'
            Set-PodeWebLoginPage -Authentication 'MainAuth'
            Set-PwtRouteParams -Authentication 'MainAuth'
        }
        #>
        <# With json file (Useful for testing):
        Login        = {
            Enable-PodeSessionMiddleware -Secret 'Cookies jar lid' -Duration (10 * 60) -Extend
            New-PodeAuthScheme -Form | Add-PodeAuthUserFile -Name 'MainAuth' -FilePath ('\Components\Json\Example.json' | Get-PwtRootedPath)
            Set-PodeWebLoginPage -Authentication 'MainAuth'
            Set-PwtRouteParams -Authentication 'MainAuth'
        }
        #>
        #<# With EF (SQLite):
        Login            = {
            # EF login:
            New-PodeAuthScheme -Form | Add-PodeAuthEf -Name 'MainAuth'

            # # Json file login + EF user settings:
            # New-PodeAuthScheme -Form | Add-PodeAuthUserFile -Name 'MainAuth' -FilePath ('\Components\Json\Example.json' | Get-PwtRootedPath) -ScriptBlock (New-PwtEfPodeAuthScriptBlock)

            # # AD login + EF user settings:
            # New-PodeAuthScheme -Form | Add-PodeAuthWindowsAd -Name 'MainAuth' -Groups 'IT' -ScriptBlock (New-PwtEfPodeAuthScriptBlock)

            <# AD login + EF login example:
            New-PodeAuthScheme -Form | Add-PodeAuth -Name 'MainAuth'-ArgumentList @{
                PodeAuthWindowsAd = Get-PodeAuthWindowsAd -Groups 'IT' -ScriptBlock (New-PwtEfPodeAuthScriptBlock)
                PodeAuthEf        = Get-PodeAuthEf
            } -ScriptBlock {
                param(
                    [string]$Username,
                    [string]$Password,
                    [hashtable]$PodeAuths
                )
                $ResultsEf = Invoke-PodeScriptBlock -ScriptBlock $PodeAuths.PodeAuthEf.ScriptBlock `
                    -Arguments $Username, $Password, $PodeAuths.PodeAuthEf.Arguments -Splat -Return
                if ($ResultsEf.User) {
                    $ResultsEf
                }
                else {
                    $ResultsWindowsAD = Invoke-PodeScriptBlock -ScriptBlock $PodeAuths.PodeAuthWindowsAd.ScriptBlock `
                        -Arguments $Username, $Password, $PodeAuths.PodeAuthWindowsAd.Arguments -Splat -Return
                    $ResultsWindowsAD
                }
            }
            #>


            Set-PodeWebLoginPage -Authentication 'MainAuth'
            Set-PwtRouteParams -Authentication 'MainAuth'
        }
        #>

        # Force modules reload abd show errors on web.
        Debug            = $true
        # Main storage path.
        StoragePath      = '.\Storage\'
        # Path to temporary downland cache.
        DownloadPath     = '.\Storage\Download'
    }
    Tools      = @(
        'Debug'
        # @{ Name = "MyModule"; Path = '' }
    )
    Components = @(
        # 'Json'
        'Sqlite'
        'Ef'
    )
}
$Config

if ($Config.Components -contains 'Ef') {
    $EFPoshPath = $Config.Global.ModulesPaths -like '*EFPosh*'
    1 | ForEach-Object -ThrottleLimit 1 -Parallel {
        Import-Module $using:EFPoshPath
    }
}
