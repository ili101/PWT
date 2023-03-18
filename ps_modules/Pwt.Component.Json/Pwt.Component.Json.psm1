function Invoke-PodeSHA256Hash {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Value
    )

    $crypto = [System.Security.Cryptography.SHA256]::Create()
    return [System.Convert]::ToBase64String($crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value)))
}

function Initialize-PwtJson {
    [CmdletBinding()]
    param ()
    {
        $Config = Get-PwtConfig -Module 'Pwt.Component.Json'
        $StoragePath = (Get-PwtConfig -Module 'Pwt.Component.Core')['StoragePath']
        $Config.JsonFilePath = Join-Path $StoragePath '\Users.json'
        $Config.Users | ConvertTo-Json | Out-File -FilePath $Config.JsonFilePath
        $Config.Remove('Users')
    }
}
function Get-PwtJsonFilePath {
    [CmdletBinding()]
    param ()
    (Get-PwtConfig -Module 'Pwt.Component.Json')['JsonFilePath']
}