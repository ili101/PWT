# Adding Tools
1. Create folder and file `.\Tools\<ToolName>\<ToolName>Pages.ps1` with the `Add-PodeWebPage` code inside.
2. Put other files you need in the same folder.
3. Add to `Config.Example.ps1` a new section under `Tools` with:
``` powershell
@{
    ...
    Tools = @{
        ...
        ToolName = @{
            # Enable/Disable this tool.
            Enable = $true

            OtherConfigYouNeed = 'Example value'
        }
    }
}
```
3. The page code will be loaded if the tool config Enable is true.
4. To access the config use `$Config['Tools']['ToolName']` or `(Get-PodeConfig)`.
5. Available extra functions:
   * `$RelativePath | Get-PwtRootedPath` if you need to add root to relative path (relative to the `Home.ps1` folder).
   * `Add-PodeStaticRoute @RouteParams` splat `$RouteParams` when adding a Route to set its `EndpointName` and `Authentication` if they where configured by the user.
   * To use the SQLite, use `Connect-Sql` in the beginning of the runspace to establish a confection for the first time then run queries with `Invoke-Sql -QueryPath '\Path\File.sql' -QueryFormat Param`.
   * To generate a file and download it, you can use the `DownloadPath` config and the `/download` route, for example excel:
``` powershell
$DownloadPath = (Get-PodeConfig)['Global']['DownloadPath']
$PathLeaf = Join-Path (New-Guid).Guid ('Data {0:yyyy-MM-dd HH-mm-ss}.xlsx' -f (Get-Date))
Export-Excel -InputObject $Data -TableName 'Data' -AutoSize -Path (Join-Path $DownloadPath $PathLeaf)
Set-PodeResponseAttachment -Path ('/download', ($PathLeaf.Replace('\', '/')) -join '/')
```