# TODO: Support subfolders.
# Initialize.
Import-Module -Name (Join-Path $PSScriptRoot 'Pwt.Drive.Helper.psm1') @ImportParams
$DriveRootPath = $Config['Tools']['Drive']['DriveRootPath'] = $Config['Tools']['Drive']['DriveRootPath'] | Get-PwtRootedPath
if (!(Test-Path -Path $DriveRootPath)) {
    $null = New-Item -ItemType Directory $DriveRootPath
}
Add-PodeStaticRoute -Path '/drive' -Source $DriveRootPath -DownloadOnly @RouteParams

$ExplorerConfirmModal = New-PodeWebModal -Name 'Delete Item' -Id 'DriveDeleteConfirm' -AsForm -Content @(
    New-PodeWebAlert -Type Warning -Id 'DriveDeleteConfirmAlert' -Value '[Placeholder]'
) -ScriptBlock {
    # $DriveWorkingPath = (Get-PodeConfig)['Tools']['Drive']['DriveRootPath']
    $DriveWorkingPath = $WebEvent.Session.Data.DriveWorkingPath

    Remove-Item -Path (Join-Path $DriveWorkingPath $WebEvent.Data.Value) -Recurse
    Hide-PodeWebModal
    Sync-PodeWebTable -Id 'DriveExplorer'
}
$ExplorerMainTable = New-PodeWebTable -Name 'Explorer' -Id 'DriveExplorer' -DataColumn Name -Filter -Sort -Click -Paginate -ScriptBlock {
    # $DriveWorkingPath = (Get-PodeConfig)['Tools']['Drive']['DriveRootPath']
    $DriveWorkingPath = $WebEvent.Session.Data.DriveWorkingPath

    $DownloadButton = New-PodeWebButton -Name 'Download' -Icon 'Download' -IconOnly -ScriptBlock {
        Show-PodeWebToast -Message "Download $($WebEvent.Data.Value)"
        # TODO: Download form subfolder.
        Set-PodeResponseAttachment -Path ('/drive', $WebEvent.Data.Value -join '/')
    }
    $DeleteButton = New-PodeWebButton -Name 'Delete' -Icon 'Delete' -IconOnly -ScriptBlock {
        Show-PodeWebModal -Id 'DriveDeleteConfirm' -DataValue $WebEvent.Data.Value -Actions @(
            # $DriveWorkingPath = (Get-PodeConfig)['Tools']['Drive']['DriveRootPath']
            $DriveWorkingPath = $WebEvent.Session.Data.DriveWorkingPath

            $FileOrFolder = Get-Item -Path (Join-Path $DriveWorkingPath $WebEvent.Data.Value)
            $AlertMassage = if ($FileOrFolder -isnot [System.IO.DirectoryInfo]) {
                "Are you sure you want to delete file `"$($WebEvent.Data.Value)`"?"
            }
            else {
                "Are you sure you want to delete folder `"$($WebEvent.Data.Value)`" and all of it's content!"
            }
            Out-PodeWebText -Id 'DriveDeleteConfirmAlert' -Value $AlertMassage
        )
    }
    $FolderItems = Get-ChildItem -Path $DriveWorkingPath
    foreach ($FolderItem in $FolderItems) {
        [ordered]@{
            Icon          = $FolderItem | Get-Icon
            Name          = $FolderItem.Name
            LastWriteTime = $FolderItem.LastWriteTime.ToString()
            Length        = $FolderItem.Length | Format-FileSize
            Download      = $DownloadButton
            Delete        = $DeleteButton
        }
    }
}
$ExplorerMainTable | Add-PodeWebTableButton -Name 'Home' -Icon 'Home' -ScriptBlock {
    $WebEvent.Session.Data.DriveWorkingPath = (Get-PodeConfig)['Tools']['Drive']['DriveRootPath']
    Sync-PodeWebTable -Id 'DriveExplorer'
}
$ExplorerUploadForm = New-PodeWebForm -Name 'Form' -Content @(
    New-PodeWebFileUpload -Name 'Upload'
) -ScriptBlock {
    # $DriveWorkingPath = (Get-PodeConfig)['Tools']['Drive']['DriveRootPath']
    $DriveWorkingPath = $WebEvent.Session.Data.DriveWorkingPath

    Save-PodeRequestFile -Key Upload -Path $DriveWorkingPath
    Sync-PodeWebTable -Id 'DriveExplorer'
}

$ExplorerCard = New-PodeWebCard -Name 'Explorer' -Content @(
    $ExplorerConfirmModal, $ExplorerUploadForm, $ExplorerMainTable
)

Add-PodeWebPage -Name 'Drive' -Icon Activity -Layouts $ExplorerCard -ScriptBlock {
    if (!($DriveWorkingPath = $WebEvent.Session.Data.DriveWorkingPath)) {
        $DriveWorkingPath = $WebEvent.Session.Data.DriveWorkingPath = (Get-PodeConfig)['Tools']['Drive']['DriveRootPath']
    }
    $FileOrFolderName = $WebEvent.Query['value']
    if ([string]::IsNullOrWhiteSpace($FileOrFolderName)) {
        return
    }

    $FileOrFolder = Get-Item -Path (Join-Path $DriveWorkingPath $FileOrFolderName)
    if ($FileOrFolder -is [System.IO.DirectoryInfo]) {
        $WebEvent.Session.Data.DriveWorkingPath = $FileOrFolder.FullName
    }
    else {
        $FileContent = $FileOrFolder | Get-Content | Out-String
        New-PodeWebCard -Name "$($FileOrFolderName) Content" -Content @(
            New-PodeWebCodeBlock -Value $FileContent -NoHighlight
        )
    }
}