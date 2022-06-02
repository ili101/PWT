Add-PodeWebPage -Name Processes -Icon Activity -ScriptBlock {
    $Config = Get-PodeConfig
    New-PodeWebHero -Title 'Welcome!' -Message ($Config['Tools'] | convertto-json )
}