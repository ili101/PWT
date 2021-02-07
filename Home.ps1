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
$ConfigPstPath = @('Config.ps1')
if ($env:PODE_ENVIRONMENT) {
    $ConfigPstPath = , "Config.$($env:PODE_ENVIRONMENT).ps1" + $ConfigPstPath
}
$ConfigPstPath = $ConfigPstPath | ForEach-Object { Join-Path $ScriptRoot $_ } | Where-Object { $_ | Test-Path } | Select-Object -First 1
$ConfigPst = & $ConfigPstPath

# Import Modules.
$ImportParams = if ($ConfigPst['Global']['Debug']) {
    @{ Force = $true }
}
else {
    @{}
}
foreach ($ModulesPath in $ConfigPst['Global']['ModulesPaths']) {
    Import-Module -Name $ModulesPath @ImportParams
}

Start-PodeServer {
    Import-Module -Name (Join-Path (Get-PodeServerPath) '\Components\Core\Pwt.Core.Helper.psm1')
    $Config = Get-PodeConfig
    $ConfigPst = & $ConfigPstPath
    $ConfigPst.GetEnumerator() | ForEach-Object { $Config[$_.Name] = $_.Value }
    'StoragePath', 'DownloadPath' | ForEach-Object { $Config['Global'][$_] = $Config['Global'][$_] | Get-RootedPath }

    New-PodeLoggingMethod -File -Name 'Errors' | Enable-PodeErrorLogging
    New-PodeLoggingMethod -File -Name 'Requests' | Enable-PodeRequestLogging
    if ($Config['Global']['Debug']) {
        Write-Debug "PID: $PID" -Debug
    }

    . $Config['Global']['Endpoint']
    if ($Config['Global']['Login']) {
        . $Config['Global']['Login']
        if ([String]::IsNullOrWhiteSpace($Config['Global']['LoginAuthenticationName'])) {
            throw 'When "Login" configured "LoginAuthenticationName" is required.'
        }
        $Authentication = @{ Authentication = $Config['Global']['LoginAuthenticationName'] }
    }
    else {
        $Authentication = @{}
    }

    $DownloadPath = $Config['Global']['DownloadPath'] | Get-RootedPath
    if (!(Test-Path -Path $DownloadPath)) {
        $null = New-Item -ItemType Directory $DownloadPath
    }
    Add-PodeStaticRoute -Path '/download' -Source $DownloadPath -DownloadOnly @Authentication

    foreach ($Tool in (Get-PodeConfig).Tools.GetEnumerator()) {
        if ($Tool.Value.Enable) {
            . ("\Tools\$($Tool.Name)\Pages.ps1" | Get-RootedPath)
        }
    }

    if ($Config['Global']['LoginUserConfiguration']) {
        . ($Config['Global']['LoginUserConfiguration'] | Get-RootedPath)
    }
}