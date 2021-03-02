# Set ScriptRoot.
$ScriptRoot = if ($PSScriptRoot) {
    $PSScriptRoot
}
elseif ($Host.Name -eq 'Visual Studio Code Host') {
    (Split-Path $psEditor.GetEditorContext().CurrentFile.Path)
}
else {
    '.\'
}

# Load Config.
$ConfigDynamicPath = @('Config.ps1')
if ($env:PODE_ENVIRONMENT) {
    $ConfigDynamicPath = , "Config.$($env:PODE_ENVIRONMENT).ps1" + $ConfigDynamicPath
}
$ConfigDynamicPath = $ConfigDynamicPath | ForEach-Object { Join-Path $ScriptRoot $_ } | Where-Object { $_ | Test-Path } | Select-Object -First 1
$ConfigDynamic = & $ConfigDynamicPath

# Import Modules.
$ImportParams = if ($ConfigDynamic['Global']['Debug']) {
    @{ Force = $true }
}
else {
    @{}
}
$ModulesPaths = @(Join-Path $ScriptRoot '\Components\Core\Pwt.Core.Helper.psm1') + $ConfigDynamic['Global']['ModulesPaths']
foreach ($ModulesPath in $ModulesPaths) {
    Import-Module -Name $ModulesPath @ImportParams
}

# Get `Start-PodeServer` params.
$PodeServerParams = if ($ConfigDynamic.Global.PodeServerParams) {
    $ConfigDynamic.Global.PodeServerParams
}
else {
    @{}
}

Start-PodeServer @PodeServerParams -ScriptBlock {
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