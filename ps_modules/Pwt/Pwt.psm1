function Start-Pwt {
    param (
        [string]$ScriptRoot
    )
    $script:ConfigDynamic = Invoke-PwtConfig -Module 'Pwt' -PassThru -ScriptRoot $ScriptRoot
    # $script:PwtCorePath = (Join-Path $PSScriptRoot 'Pwt.Component.Core')

    # $PackagePath = Join-Path $ScriptRoot '\Components\Core\package.json'
    # if (Test-Path $PackagePath) {
    #     $Package = (Get-Content $PackagePath | ConvertFrom-Json)
    # }
    # else {
    #     throw 'package.json file not found'
    # }

    # $Modules = $Package.modules | Where-Object { $_ -ne 'Pode' }
    # Import-PodeModule -Name Pode

    # # Import Modules.
    # foreach ($Module in $Modules) {
    #     Import-PodeModule @Module
    # }

    # Import Modules.
    $ImportParams = if ($ConfigDynamic['Global']['Debug']) {
        @{ Force = $true }
    }
    else {
        @{}
    }
    # $ModulesPaths = @(Join-Path $ScriptRoot '\Components\Core\Pwt.Core.Helper.psm1') + $ConfigDynamic['Global']['ModulesPaths']
    $ModulesPaths = $ConfigDynamic['Global']['ModulesPaths']
    Import-Module -Name $ModulesPaths @ImportParams -Global

    # Get `Start-PodeServer` params.
    $PodeServerParams = if ($ConfigDynamic.Global.PodeServerParams) {
        $ConfigDynamic.Global.PodeServerParams
    }
    else {
        @{}
    }
    if ($ConfigDynamic.Global.PodeServerParams.ListenerType -eq 'Kestrel') {
        Import-Module -Name Pode.Kestrel
    }

    Start-PodeServer @PodeServerParams -RootPath $ScriptRoot -FilePath (Join-Path $PSScriptRoot 'Home.ps1')
}
