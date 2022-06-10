function Start-Pwt {
    param (
        [string]$ScriptRoot
    )
    # Load Config.
    $ConfigDynamicPath = @('config.ps1')
    if ($env:PODE_ENVIRONMENT) {
        $ConfigDynamicPath = , "config.$($env:PODE_ENVIRONMENT).ps1" + $ConfigDynamicPath
    }
    $ConfigDynamicPath = $ConfigDynamicPath | ForEach-Object { Join-Path $ScriptRoot $_ } | Where-Object { $_ | Test-Path } | Select-Object -First 1
    $ConfigDynamic = & $ConfigDynamicPath

    # $PackagePath = Join-Path $ScriptRoot '\Components\Core\package.json'
    # if (Test-Path $PackagePath) {
    #     $Package = (Get-Content $PackagePath | ConvertFrom-Json)
    # }
    # else {
    #     throw 'package.json file not found'
    # }

    # $Modules = $Package.modules | Where-Object { $_ -ne 'Pode' }
    Import-PodeModule -Name Pode

    # # Import Modules.
    # foreach ($Module in $Modules) {
    #     Import-PodeModule @Module
    # }

    # Get `Start-PodeServer` params.
    $PodeServerParams = if ($ConfigDynamic.Global.PodeServerParams) {
        $ConfigDynamic.Global.PodeServerParams
    }
    else {
        @{}
    }
    if ($ConfigDynamic.Global.PodeServerParams.ListenerType -eq 'Kestrel') {
        Import-PodeModule -Name Pode.Kestrel
    }

    Start-PodeServer @PodeServerParams -RootPath $ScriptRoot -FilePath (Join-Path $ScriptRoot '\Components\Pwt\Home.ps1')
}


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
            if ($RootedPath -match '^(?!\\)+.{2,}:') {
                # If path root is drive replace with "C:", normalize and replace back.
                $RootedPath = $RootedPath.Replace($Matches[0], 'C:')
                [System.IO.Path]::GetFullPath($RootedPath).Replace('C:', $Matches[0])
            }
            else {
                [System.IO.Path]::GetFullPath($RootedPath)
            }
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


# Idea from http://stackoverflow.com/questions/7468707/deep-copy-a-dictionary-hashtable-in-powershell
function Get-ClonedObject {
    param($DeepCopyObject)
    $memStream = New-Object IO.MemoryStream
    $formatter = New-Object Runtime.Serialization.Formatters.Binary.BinaryFormatter
    $formatter.Serialize($memStream, $DeepCopyObject)
    $memStream.Position = 0
    $formatter.Deserialize($memStream)
}

# Thanks to http://stackoverflow.com/questions/8982782/does-anyone-have-a-dependency-graph-and-topological-sorting-code-snippet-for-pow
# Input is a hashtable of @{ID = @(Depended,On,IDs);...}
function Get-TopologicalSort {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [hashtable] $edgeList
    )

    # Make sure we can use HashSet
    Add-Type -AssemblyName System.Core

    # Clone it so as to not alter original
    $currentEdgeList = [hashtable] (Get-ClonedObject $edgeList)

    # algorithm from http://en.wikipedia.org/wiki/Topological_sorting#Algorithms
    $topologicallySortedElements = New-Object System.Collections.ArrayList
    $setOfAllNodesWithNoIncomingEdges = New-Object System.Collections.Queue

    $fasterEdgeList = @{}

    # Keep track of all nodes in case they put it in as an edge destination but not source
    $allNodes = New-Object -TypeName System.Collections.Generic.HashSet[object] -ArgumentList (, [object[]] $currentEdgeList.Keys)

    foreach ($currentNode in $currentEdgeList.Keys) {
        $currentDestinationNodes = [array] $currentEdgeList[$currentNode]
        if ($currentDestinationNodes.Length -eq 0) {
            $setOfAllNodesWithNoIncomingEdges.Enqueue($currentNode)
        }

        foreach ($currentDestinationNode in $currentDestinationNodes) {
            if (!$allNodes.Contains($currentDestinationNode)) {
                [void] $allNodes.Add($currentDestinationNode)
            }
        }

        # Take this time to convert them to a HashSet for faster operation
        $currentDestinationNodes = New-Object -TypeName System.Collections.Generic.HashSet[object] -ArgumentList (, [object[]] $currentDestinationNodes )
        [void] $fasterEdgeList.Add($currentNode, $currentDestinationNodes)
    }

    # Now let's reconcile by adding empty dependencies for source nodes they didn't tell us about
    foreach ($currentNode in $allNodes) {
        if (!$currentEdgeList.ContainsKey($currentNode)) {
            [void] $currentEdgeList.Add($currentNode, (New-Object -TypeName System.Collections.Generic.HashSet[object]))
            $setOfAllNodesWithNoIncomingEdges.Enqueue($currentNode)
        }
    }

    $currentEdgeList = $fasterEdgeList

    while ($setOfAllNodesWithNoIncomingEdges.Count -gt 0) {
        $currentNode = $setOfAllNodesWithNoIncomingEdges.Dequeue()
        [void] $currentEdgeList.Remove($currentNode)
        [void] $topologicallySortedElements.Add($currentNode)

        foreach ($currentEdgeSourceNode in $currentEdgeList.Keys) {
            $currentNodeDestinations = $currentEdgeList[$currentEdgeSourceNode]
            if ($currentNodeDestinations.Contains($currentNode)) {
                [void] $currentNodeDestinations.Remove($currentNode)

                if ($currentNodeDestinations.Count -eq 0) {
                    [void] $setOfAllNodesWithNoIncomingEdges.Enqueue($currentEdgeSourceNode)
                }
            }
        }
    }

    if ($currentEdgeList.Count -gt 0) {
        throw "Graph has at least one cycle!"
    }

    return $topologicallySortedElements
}