$Config = .\Config.ps1
Import-Module -Name ($Config['ModulesPaths'] | Where-Object { (Split-Path -Path $_ -Leaf) -in 'Pode', 'Pode.psd1' })

# https://github.com/Badgerati/Pode/blob/3f7fd9f68d5fc8707b34db825538c7cc930cd0d5/examples/web-route-protocols.ps1
Start-PodeServer {
    # listen on 80 (set your listening address).
    Add-PodeEndpoint -Address 192.168.0.1 -Port 80 -Protocol Http

    # Redirect http to https.
    Add-PodeRoute -Method * -Path * -ScriptBlock {
        Move-PodeResponseUrl -Protocol Https -Port 443
    }
}