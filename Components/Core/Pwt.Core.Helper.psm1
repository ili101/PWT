function Get-RootedPath {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        $Path
    )
    process {
        if ($Path) {
            if (Split-Path $Path -IsAbsolute) {
                $Path
            }
            else {
                Join-Path (Get-PodeServerPath) $Path
            }
        }
    }
}