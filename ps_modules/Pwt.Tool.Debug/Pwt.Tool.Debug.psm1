function Get-PwtPagesDebug {
    [CmdletBinding()]
    param ()
    {
        Add-PodeWebPage -Name Debug -Icon bug-outline -ScriptBlock {
            New-PodeWebAccordion -Mode Collapsed -Bellows @(
                New-PodeWebBellow -Name Config -Content @(
                    $Config = Get-PodeConfig
                    New-PodeWebCodeBlock -Value ($Config.GetType().Name + [Environment]::NewLine + ($Config | ConvertTo-Json -WarningAction SilentlyContinue)) -Language 'Json'
                )
                New-PodeWebBellow -Name WebEvent -Content @(
                    New-PodeWebCodeBlock -Value ($WebEvent.GetType().Name + [Environment]::NewLine + ($WebEvent | Out-String))
                )
                New-PodeWebBellow -Name Auth -Content @(
                    New-PodeWebCodeBlock -Value ($WebEvent.Auth.GetType().Name + [Environment]::NewLine + ($WebEvent.Auth | ConvertTo-Json -WarningAction SilentlyContinue)) -Language 'Json'
                )
                New-PodeWebBellow -Name Tools -Content @(
                    New-PodeWebButton -Name 'Theme' -ScriptBlock {
                        Reset-PodeWebTheme
                    }
                )
            )
        }
    }
}
