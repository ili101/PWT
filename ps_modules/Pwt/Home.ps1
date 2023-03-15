{
    $PwtCorePath = (Get-Module 'Pwt.Component.Core').ModuleBase
    Import-PodeModule -Name $PwtCorePath
    Invoke-PwtConfig -Module 'Pwt.Component.Core' -Save
    . (. 'Initialize-PwtCore')

    # Set Config.
    $ConfigPwt = Invoke-PwtConfig -Module 'Pwt' -PassThru -Save
    'Tools', 'Components' | Where-Object { $null -eq $ConfigPwt[$_] } | ForEach-Object { $ConfigPwt[$_] = @{} }
    $ImportParams = $ConfigPwt['ImportParams'] = if ($ConfigPwt['Debug']) {
        @{ Force = $true }
    }
    else {
        @{}
    }

    # Logging.
    New-PodeLoggingMethod -File -Name 'Errors' | Enable-PodeErrorLogging
    New-PodeLoggingMethod -File -Name 'Requests' | Enable-PodeRequestLogging
    if ($ConfigPwt['Debug']) {
        Write-Debug "PID: $PID" -Debug
    }

    # $PackagePath = Join-Path $ScriptRoot '\Components\*\package.json'
    # if (Test-Path $PackagePath) {
    #     $Package = Resolve-Path -Path $PackagePath | ForEach-Object { $_ | Get-Content | ConvertFrom-Json -AsHashtable }
    # }
    # else {
    #     throw 'package.json file not found'
    # }

    # $Modules = [System.Collections.Generic.HashSet[String]]@($Package.modules.Keys)
    # $Modules.ExceptWith([String[]]@('Pode', 'Kestrel'))

    # # Import Modules.
    # foreach ($Module in $Modules) {
    #     Import-PodeModule @Module
    # }

    # $Components = @{}
    # $Package | ForEach-Object { $Components[$_.name] = $_.components ?? @() }
    # Get-TopologicalSort $Components
    # foreach ($Component in $ConfigPwt.Components.GetEnumerator()) {
    #     if ($Component.Value.Enable) {
    #         . ("\Components\$($Component.Name)\$($Component.Name)Pages.ps1" | Get-PwtRootedPath)
    #     }
    # }

    foreach ($Component in $ConfigPwt.Components) {
        Import-PodeModule -Name "Pwt.Component.$Component"
        Invoke-PwtConfig -Module "Pwt.Component.$Component" -Save
    }
    # Load Tools and Components.
    foreach ($Tool in $ConfigPwt.Tools) {
        Import-PodeModule -Name "Pwt.Tool.$Tool"
        Invoke-PwtConfig -Module "Pwt.Tool.$Tool" -Save
    }
    foreach ($Module in $ConfigPwt.Components + $ConfigPwt.Tools) {
        if (Get-Command "Initialize-Pwt$Module" -ErrorAction SilentlyContinue) {
            . (. "Initialize-Pwt$Module")
        }
    }

    # Load Endpoint and Login.
    . $ConfigPwt['Endpoint']
    if ($ConfigPwt['Login']) {
        . $ConfigPwt['Login']
        if ([String]::IsNullOrWhiteSpace((Get-PwtConfig -Module 'Pwt.Component.Core')['RouteParams']['Authentication'])) {
            throw 'When "Login" configured "Set-PwtRouteParams -Authentication [String]" is required.'
        }
    }

    # Load Tools and Components.
    foreach ($Module in 'Core', $ConfigPwt.Components, $ConfigPwt.Tools | Join-Array) {
        . (. "Get-PwtPages$Module")
    }
}