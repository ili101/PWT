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
$ConfigDynamicPath = @('config.ps1')
if ($env:PODE_ENVIRONMENT) {
    $ConfigDynamicPath = , "config.$($env:PODE_ENVIRONMENT).ps1" + $ConfigDynamicPath
}
$ConfigDynamicPath = $ConfigDynamicPath | ForEach-Object { Join-Path $ScriptRoot $_ } | Where-Object { $_ | Test-Path } | Select-Object -First 1
$ConfigDynamic = & $ConfigDynamicPath

# Import Modules.
$Modules = @(@{ 'Path' = Join-Path $ScriptRoot '\Components\Core\Pwt.Core.Helper.psm1'}) + $ConfigDynamic['Global']['ModulesPaths']
foreach ($Module in $Modules) {
    Import-PodeModule @Module
}

# Get `Start-PodeServer` params.
$PodeServerParams = if ($ConfigDynamic.Global.PodeServerParams) {
    $ConfigDynamic.Global.PodeServerParams
}
else {
    @{}
}

Start-PodeServer @PodeServerParams -RootPath $ScriptRoot -FilePath (Join-Path $ScriptRoot '\Components\Core\Home.ps1')