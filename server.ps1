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

Import-Module -Name '.\Components\Pwt.Core' -Force
Start-Pwt -ScriptRoot $ScriptRoot