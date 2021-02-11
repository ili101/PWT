function Get-PwtRootedPath {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        $Path,
        $Root = (Get-PodeServerPath)
    )
    process {
        if ($Path) {
            $RootedPath = if (Split-Path $Path -IsAbsolute) {
                $Path
            }
            else {
                Join-Path $Root $Path
            }
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
    if ($EndpointName) {
        $Config['Global']['RouteParams']['EndpointName'] = $EndpointName
    }
    if ($Authentication) {
        $Config['Global']['RouteParams']['Authentication'] = $Authentication
    }
}