{
    $PwtCorePath = (Get-Module 'Pwt.Component.Core').ModuleBase
    Import-PodeModule -Name $PwtCorePath

    # Set Config.
    $ConfigPode = Get-PodeConfig
    $ConfigPode['Configs'] = @{}
    $ConfigPode['Configs']['Pwt'] = $ConfigPwt = Invoke-PwtConfig -PassThru -Module 'Pwt'
    'StoragePath', 'DownloadPath' | ForEach-Object { $ConfigPwt[$_] = $ConfigPwt[$_] | Get-PwtRootedPath }
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
        $ConfigPode['Configs']["Pwt.Component.$Component"] = Invoke-PwtConfig -PassThru -Module "Pwt.Component.$Component"
    }
    # Load Tools and Components.
    foreach ($Tool in $ConfigPwt.Tools) {
        Import-PodeModule -Name "Pwt.Tool.$Tool"
        $ConfigPode['Configs']["Pwt.Tool.$Tool"] = Invoke-PwtConfig -PassThru -Module "Pwt.Tool.$Tool"
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
        if ([String]::IsNullOrWhiteSpace($ConfigPwt['RouteParams']['Authentication'])) {
            throw 'When "Login" configured "Set-PwtRouteParams -Authentication [String]" is required.'
        }
    }
    Set-PwtRouteParams
    $RouteParams = $ConfigPwt['RouteParams']

    # Set Download Route.
    $DownloadPath = $ConfigPwt['DownloadPath']
    if (!(Test-Path -Path $DownloadPath)) {
        $null = New-Item -ItemType Directory $DownloadPath
    }
    Add-PodeStaticRoute -Path '/download' -Source $DownloadPath -DownloadOnly @RouteParams

    # # Load Tools and Components.
    # foreach ($Tool in $ConfigPwt.Tools.GetEnumerator()) {
    #     if ($Tool.Value.Enable) {
    #         . ("\Tools\$($Tool.Name)\$($Tool.Name)Pages.ps1" | Get-PwtRootedPath)
    #     }
    # }

    # Load Tools and Components.
    foreach ($Module in $ConfigPwt.Components + $ConfigPwt.Tools) {
        . (. "Get-PwtPages$Module")
    }
}