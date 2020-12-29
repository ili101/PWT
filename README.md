# ExchangeMessageTrackingLogWeb (Beta)
PowerShell website using [Pode.Web](https://github.com/Badgerati/Pode.Web) for searching Exchange [Get-MessageTrackingLog](https://docs.microsoft.com/en-us/powershell/module/exchange/get-messagetrackinglog?view=exchange-ps).

## Install and config
1. Git Clone or download zip with the GitHub "Code" button.
2. Copy `Config.Example.ps1` to `Config.ps1`.
3. If not installed install dependent modules:
``` powershell
Install-Module -Name Pode
Install-Module -Name Pode.Web
Install-Module -Name ImportExcel
```
4. Edit `Config.ps1` as needed (Default is exchange demo mode and unsecured website).
5. Run `Home.ps1` and browse to server URL.

## Need help?
Open an [Issue](https://github.com/ili101/ExchangeMessageTrackingLogWeb/issues)
or message on [Discussions](https://github.com/ili101/ExchangeMessageTrackingLogWeb/discussions).

## Contributing
If you fund a bug, added functionality or anything else just fork and send pull requests. Thank you!

##  Changelog
[CHANGELOG.md](https://github.com/ili101/ExchangeMessageTrackingLogWeb/blob/master/CHANGELOG.md)

## To do
* Excel download button.
* Add time to date filters.
* Exchange local config.