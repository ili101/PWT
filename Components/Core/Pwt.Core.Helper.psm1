function Get-PwtRootedPath {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [string]$Path,
        [string]$Root = (Get-PodeServerPath)
    )
    process {
        if (![String]::IsNullOrWhiteSpace($Path)) {
            # `Split-Path -IsAbsolute` don't work on UNC.
            # `[System.IO.Path]::IsPathFullyQualified()` don't work on PSDrive.
            # `[System.IO.Path]::IsPathRooted()` don't work on "\Foo".
            $RootedPath = if ((Split-Path $Path -IsAbsolute) -or $Path.StartsWith('\\')) {
                $Path
            }
            else {
                Join-Path $Root $Path
            }
            # Normalize path:
            # `[System.IO.Path]::GetFullPath()` don't work on Drive.
            # `$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath()` converts Drives to full path, Drives must exist, doesn't normalize UNC.
            # `Resolve-Path` path must exist.
            # `Convert-Path` path must exist, converts Drives to full path.
            [System.IO.Path]::GetFullPath($RootedPath)
        }
    }
}
function Set-PwtRouteParams {
    [CmdletBinding()]
    param (
        [String]$EndpointName,
        [String]$Authentication
    )
    $Config = Get-PodeConfig
    if (!$Config['Global'].ContainsKey('RouteParams')) {
        $Config['Global']['RouteParams'] = @{}
    }
    if (!$Config['Global'].ContainsKey('AttachmentParams')) {
        $Config['Global']['AttachmentParams'] = @{}
    }
    if ($EndpointName) {
        $Config['Global']['AttachmentParams']['EndpointName'] = $Config['Global']['RouteParams']['EndpointName'] = $EndpointName
    }
    if ($Authentication) {
        $Config['Global']['RouteParams']['Authentication'] = $Authentication
    }
}