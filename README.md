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

## Customization and more Tools
This project can be used as a template of other tools. You can write and add more pages for other functions you need.

If you made other tools or have ideas for one contact on GitHub. If there is interest maybe we will make a tool collection that you select the tools you want from?

The tool also include an optional SQLite system that allows logins session to persistent server restart and a user configuration page. Can be useful example for other tools that need to save users data.

## Need help?
Open an [Issue](https://github.com/ili101/ExchangeMessageTrackingLogWeb/issues)
or message on [Discussions](https://github.com/ili101/ExchangeMessageTrackingLogWeb/discussions).

## Contributing
If you fund a bug, added functionality or anything else just fork and send pull requests. Thank you!

##  Changelog
[CHANGELOG.md](https://github.com/ili101/ExchangeMessageTrackingLogWeb/blob/master/CHANGELOG.md)

## To do
* Excel download button.