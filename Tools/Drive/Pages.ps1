$DriveRootPath = $Config['Tools']['Drive']['RootPath'] = $Config['Tools']['Drive']['RootPath'] | Get-RootedPath
if (!(Test-Path -Path $DriveRootPath)) {
    $null = New-Item -ItemType Directory $DriveRootPath
}
Add-PodeStaticRoute -Path '/drive' -Source $DriveRootPath -DownloadOnly @Authentication

$Modal = New-PodeWebModal -Name 'Delete Item' -Id 'DriveDeleteConfirm' -AsForm -Content @(
    New-PodeWebAlert -Type Warning -Id 'DriveDeleteConfirmAlert' -Value '[Alert]'
) -ScriptBlock {
    $Config = (Get-PodeConfig)['Tools']['Drive']
    Remove-Item -Path (Join-Path $Config['RootPath'] $WebEvent.Data.Value)
    Hide-PodeWebModal
    Sync-PodeWebTable -Id 'DriveExplorer'
}

$Table = New-PodeWebTable -Name 'Explorer' -Id 'DriveExplorer' -DataColumn Name -Filter -Sort -Click -Paginate -ArgumentList $DriveRootPath -ScriptBlock {
    param (
        $RootPath
    )
    Import-Module -Name (Join-Path $PSScriptRoot 'Functions.psm1')

    $DownloadBtn = New-PodeWebButton -Name 'Download' -Icon 'Download' -IconOnly -ScriptBlock {
        Show-PodeWebToast -Message "Download $($WebEvent.Data.Value)"
        Set-PodeResponseAttachment -Path ('/drive', $WebEvent.Data.Value -join '/')
    }
    $DeleteBtn = New-PodeWebButton -Name 'Delete' -Icon 'Delete' -IconOnly -ScriptBlock {
        Show-PodeWebModal -Id 'DriveDeleteConfirm' -DataValue $WebEvent.Data.Value -Actions @(
            $Config = (Get-PodeConfig)['Tools']['Drive']
            $FileOrFolder = Get-Item -Path (Join-Path $Config['RootPath'] $WebEvent.Data.Value)
            $AlertMassage = if ($FileOrFolder -isnot [System.IO.DirectoryInfo]) {
                "Are you sure you want to delete file $($WebEvent.Data.Value)?"
            }
            else {
                "Are you sure you want to delete folder $($WebEvent.Data.Value) and all of it's content!"
            }
            Out-PodeWebText -Id 'DriveDeleteConfirmAlert' -Value $AlertMassage
        )
    }
    $FolderItems = Get-ChildItem -Path $RootPath | Select-Object -Property 'Name', 'LastWriteTime', 'Length'
    foreach ($FolderItem in $FolderItems) {
        [ordered]@{
            Name          = $FolderItem.Name
            LastWriteTime = $FolderItem.LastWriteTime.ToString()
            Length        = $FolderItem.Length | Format-FileSize
            Download      = $DownloadBtn
            Delete        = $DeleteBtn
        }
    }
}

$Form = New-PodeWebForm -Name 'Form' -Content @(
    New-PodeWebFileUpload -Name 'Upload'
) -ScriptBlock {
    $Config = (Get-PodeConfig)['Tools']['Drive']
    Save-PodeRequestFile -Key Upload -Path $Config['RootPath']
    Sync-PodeWebTable -Id 'DriveExplorer'
}

$Card = New-PodeWebCard -Name 'Explorer' -Content @(
    $Modal, $Form, $Table
)

Add-PodeWebPage -Name 'Drive' -Icon Activity -Layouts $Card -ScriptBlock {
    $Config = (Get-PodeConfig)['Tools']['Drive']
    $FileName = $WebEvent.Query['value']
    if ([string]::IsNullOrWhiteSpace($FileName)) {
        return
    }

    $FileContent = Get-Content -Path (Join-Path $Config['RootPath'] $FileName) | Out-String

    New-PodeWebCard -Name "$($FileName) Content" -Content @(
        New-PodeWebCodeBlock -Value $FileContent -NoHighlight
    )
}