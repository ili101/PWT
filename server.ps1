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

$PsModulesPath = Resolve-Path (Join-Path $ScriptRoot 'ps_modules')
if ($env:PSModulePath -notlike "*$PsModulesPath*") {
    $env:PSModulePath = $PsModulesPath.Path + ($IsWindows ? ';' : ':') + $env:PSModulePath
}
Import-Module -Name 'Pwt' -Force

# Import-Module -Name '.\Components\Pwt.Core' -Force
Start-Pwt -ScriptRoot $ScriptRoot