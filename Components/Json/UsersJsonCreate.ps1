# Example of how to create/edit "Users.json".
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

$Users = @(
    @{
        Name = "User 1"
        Username = "u1"
        Email = "u1@example.com"
        Password = Invoke-PodeSHA256Hash -Value 'pass'
        Groups = @(
            'Admin', 'Developer'
        )
    },
    @{
        Name     = "User 2"
        Username = "u2"
        Email    = "u2@example.com"
        Password = Invoke-PodeSHA256Hash -Value 'pass'
        Groups   = @(
            'Developer'
        )
    }
)
$Users | ConvertTo-Json | Out-File -FilePath '.\Storage\Users.json'