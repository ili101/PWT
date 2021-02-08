# PWT - PowerShell/Pode Web Tools (Beta)
PowerShell website build with [Pode.Web](https://github.com/Badgerati/Pode.Web) with various tools.

You can decide which tools to enable, customize them, add authentication and even add your own tools. 

## Tools
### ExchangeMessageTrackingLogWeb
Web UI for searching Exchange [Get-MessageTrackingLog](https://docs.microsoft.com/en-us/powershell/module/exchange/get-messagetrackinglog?view=exchange-ps). Including filtering, web output display and exporting to Excel `.xlsx` file or CSV.
### Drive
Web drive where you can upload and download files, display text files and more.

## Install and config
1. Git Clone or download zip with the GitHub "Code" button.
2. Copy `Config.Example.ps1` to `Config.ps1`.
3. If not installed install dependent modules:
``` powershell
Install-Module -Name Pode
Install-Module -Name Pode.Web
Install-Module -Name ImportExcel
```
4. Edit `Config.ps1` as needed (Default is Exchange demo mode and unsecured website).
5. Run `Home.ps1` and browse to server URL.

## Customization and more Tools
This project can be used as a framework of other tools. You can write and add more pages for other functions you need.

If you made your own tools and want to share or have ideas for one contact on GitHub. If there is interest maybe we can make a tool collection that you select the tools you want from.

The tool also include an optional SQLite system that allows logins session to persistent server restart and a user configuration page. Can be useful for example for other tools that need to store users data.

[Adding Tools](https://github.com/ili101/ExchangeMessageTrackingLogWeb/blob/master/AddingTools.md)

## Need help?
Open an [Issue](https://github.com/ili101/ExchangeMessageTrackingLogWeb/issues)
or message on [Discussions](https://github.com/ili101/ExchangeMessageTrackingLogWeb/discussions).

## Contributing
If you fund a bug, added functionality or anything else just fork and send pull requests. Thank you!

##  Changelog
[CHANGELOG.md](https://github.com/ili101/ExchangeMessageTrackingLogWeb/blob/master/CHANGELOG.md)

## To do
* Drive subfolders support.