{
    # Set Config.
    $Config = Get-PodeConfig
    $ConfigDynamic = & $ConfigDynamicPath
    $ConfigDynamic.GetEnumerator() | ForEach-Object { $Config[$_.Name] = $_.Value }
    'StoragePath', 'DownloadPath' | ForEach-Object { $Config['Global'][$_] = $Config['Global'][$_] | Get-PwtRootedPath }
    'Tools', 'Components' | Where-Object { $null -eq $Config[$_] } | ForEach-Object { $Config[$_] = @{} }
    $ImportParams = $Config['Global']['ImportParams'] = if ($Config['Global']['Debug']) {
        @{ Force = $true }
    }
    else {
        @{}
    }

    # Logging.
    New-PodeLoggingMethod -File -Name 'Errors' | Enable-PodeErrorLogging
    New-PodeLoggingMethod -File -Name 'Requests' | Enable-PodeRequestLogging
    if ($Config['Global']['Debug']) {
        Write-Debug "PID: $PID" -Debug
    }

    # Load Endpoint and Login.
    . $Config['Global']['Endpoint']
    if ($Config['Global']['Login']) {
        . $Config['Global']['Login']
        if ([String]::IsNullOrWhiteSpace($Config['Global']['RouteParams']['Authentication'])) {
            throw 'When "Login" configured "Set-PwtRouteParams -Authentication [String]" is required.'
        }
    }
    Set-PwtRouteParams
    $RouteParams = $Config['Global']['RouteParams']

    # Set Download Route.
    $DownloadPath = $Config['Global']['DownloadPath']
    if (!(Test-Path -Path $DownloadPath)) {
        $null = New-Item -ItemType Directory $DownloadPath
    }
    Add-PodeStaticRoute -Path '/download' -Source $DownloadPath -DownloadOnly @RouteParams

    # Load Tools and Components.
    foreach ($Tool in $Config.Tools.GetEnumerator()) {
        if ($Tool.Value.Enable) {
            . ("\Tools\$($Tool.Name)\$($Tool.Name)Pages.ps1" | Get-PwtRootedPath)
        }
    }
    foreach ($Component in $Config.Components.GetEnumerator()) {
        if ($Component.Value.Enable) {
            . ("\Components\$($Component.Name)\$($Component.Name)Pages.ps1" | Get-PwtRootedPath)
        }
    }
}