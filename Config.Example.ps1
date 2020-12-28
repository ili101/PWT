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

    # Exchange Config.
    Exchange     = @{
        # Fro demo test mode:
        Dummy         = $true

        # For remote connection:
        #ConnectionUri = 'http://exchange.example.com/powershell'
        #Credential    = [System.Management.Automation.PSCredential]::new('ServiceUser', (ConvertTo-SecureString 'Do not save passwords in plain text' -AsPlainText -Force))
    }

    # General.
    Debug        = $true
}