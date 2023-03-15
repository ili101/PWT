function Invoke-PwtConfig {
    [CmdletBinding()]
    param (
        [string]$Module,
        [switch]$PassThru,
        [switch]$Save,
        [string]$ScriptRoot = (Get-PodeServerPath)
    )
    # Load Config.
    $ConfigDynamicPath = @("$Module.ps1")
    if ($env:PODE_ENVIRONMENT) {
        $ConfigDynamicPath = , "$Module.$($env:PODE_ENVIRONMENT).ps1" + $ConfigDynamicPath
    }
    $ConfigDynamicPath = $ConfigDynamicPath | ForEach-Object { Join-Path $ScriptRoot 'Config' $_ } | Where-Object { $_ | Test-Path } | Select-Object -First 1
    if ($ConfigDynamicPath) {
        $Config = & $ConfigDynamicPath
    }
    else {
        $Config = @{}
    }
    if ($Save) {
        $ConfigPode = Get-PodeConfig
        if (!$ConfigPode.ContainsKey('Configs')) {
            $ConfigPode['Configs'] = @{}
        }
        $ConfigPode['Configs'][$Module] = $Config
    }
    if ($PassThru) {
        return $Config
    }
}
function Get-PwtConfig {
    [CmdletBinding()]
    param (
        [string]$Module
    )
    $Config = Get-PodeConfig
    return $Config['Configs'][$Module]
}
function Initialize-PwtCore {
    [CmdletBinding()]
    param ()
    {
        $ConfigPwtCore = Get-PwtConfig -Module 'Pwt.Component.Core'
        'StoragePath', 'DownloadPath' | ForEach-Object { $ConfigPwtCore[$_] = $ConfigPwtCore[$_] | Get-PwtRootedPath }
        if (!$ConfigPwtCore.ContainsKey('RouteParams')) {
            $ConfigPwtCore['RouteParams'] = @{}
        }
        if (!$ConfigPwtCore.ContainsKey('AttachmentParams')) {
            $ConfigPwtCore['AttachmentParams'] = @{}
        }
    }
}
function Get-PwtPagesCore {
    [CmdletBinding()]
    param ()
    {
        $Config = Get-PwtConfig -Module 'Pwt.Component.Core'
        $RouteParams = $Config['RouteParams']

        # Set Download Route.
        $DownloadPath = $Config['DownloadPath']
        if (!(Test-Path -Path $DownloadPath)) {
            $null = New-Item -ItemType Directory $DownloadPath
        }
        Add-PodeStaticRoute -Path '/download' -Source $DownloadPath -DownloadOnly @RouteParams
    }
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
    $Config = Get-PwtConfig -Module 'Pwt.Component.Core'
    if ($EndpointName) {
        $Config['AttachmentParams']['EndpointName'] = $Config['RouteParams']['EndpointName'] = $EndpointName
    }
    if ($Authentication) {
        $Config['RouteParams']['Authentication'] = $Authentication
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

function Get-ErrorMessage {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $ErrorRecord
    )

    $Exception = $ErrorRecord.Exception
    $Messages = while ($Exception.Message) {
        $Exception.Message
        $Exception = $Exception.InnerException
    }
    $Messages
}

function Get-PodeAuthWindowsAd {
    [CmdletBinding(DefaultParameterSetName = 'Groups')]
    param (
        # [Parameter(Mandatory = $true)]
        # [string]
        # $Name,

        # [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        # [hashtable]
        # $Scheme,

        [Parameter()]
        [Alias('Server')]
        [string]
        $Fqdn,

        [Parameter()]
        [string]
        $Domain,

        [Parameter()]
        [string]
        $SearchBase,

        [Parameter(ParameterSetName = 'Groups')]
        [string[]]
        $Groups,

        [Parameter()]
        [string[]]
        $Users,

        # [Parameter()]
        # [string]
        # $FailureUrl,

        # [Parameter()]
        # [string]
        # $FailureMessage,

        # [Parameter()]
        # [string]
        # $SuccessUrl,

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        # [switch]
        # $Sessionless,

        [Parameter(ParameterSetName = 'NoGroups')]
        [switch]
        $NoGroups,

        [Parameter(ParameterSetName = 'Groups')]
        [switch]
        $DirectGroups,

        [switch]
        $OpenLDAP,

        [switch]
        $ADModule,

        # [switch]
        # $SuccessUseOrigin,

        [switch]
        $KeepCredential
    )
    . (Get-Module Pode) {
        $args[0].GetEnumerator() | ForEach-Object {
            Set-Variable -Name $_.Key -Value $_.Value
        }

        # ensure the name doesn't already exist
        # if (Test-PodeAuth -Name $Name) {
        #     throw "Windows AD Authentication method already defined: $($Name)"
        # }

        # # ensure the Scheme contains a scriptblock
        # if (Test-PodeIsEmpty $Scheme.ScriptBlock) {
        #     throw "The supplied Scheme for the '$($Name)' Windows AD authentication validator requires a valid ScriptBlock"
        # }

        # # if we're using sessions, ensure sessions have been setup
        # if (!$Sessionless -and !(Test-PodeSessionsConfigured)) {
        #     throw 'Sessions are required to use session persistent authentication'
        # }

        # if AD module set, ensure we're on windows and the module is available, then import/export it
        if ($ADModule) {
            Import-PodeAuthADModule
        }
        # set server name if not passed
        if ([string]::IsNullOrWhiteSpace($Fqdn)) {
            $Fqdn = Get-PodeAuthDomainName

            if ([string]::IsNullOrWhiteSpace($Fqdn)) {
                throw 'No domain server name has been supplied for Windows AD authentication'
            }
        }

        # set the domain if not passed
        if ([string]::IsNullOrWhiteSpace($Domain)) {
            $Domain = ($Fqdn -split '\.')[0]
        }

        # if we have a scriptblock, deal with using vars
        if ($null -ne $ScriptBlock) {
            $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
        }

        # add Windows AD auth method to server
        @{
            ScriptBlock = (Get-PodeAuthWindowsADMethod)
            Arguments   = @{
                Server         = $Fqdn
                Domain         = $Domain
                SearchBase     = $SearchBase
                Users          = $Users
                Groups         = $Groups
                NoGroups       = $NoGroups
                DirectGroups   = $DirectGroups
                KeepCredential = $KeepCredential
                Provider       = (Get-PodeAuthADProvider -OpenLDAP:$OpenLDAP -ADModule:$ADModule)
                ScriptBlock    = @{
                    Script         = $ScriptBlock
                    UsingVariables = $usingVars
                }
            }
        }
    } $PSBoundParameters
}
function Join-Array {
    <#
    .SYNOPSIS
        Joins an array of arrays.
    .DESCRIPTION
        Filters out nulls on the first level unless -IncludeNull is specified.
        Dose not join nested arrays.
        Using `-InputObject` should behave the same as if pipeline was used https://github.com/PowerShell/PowerShell/issues/4242.
    .OUTPUTS
        If multiple items to be returned, output will be an array.
        If one item to be returned, output will be the object itself.
        If nothing to be returned, noting will be returned (Powershell will return `[System.Management.Automation.Internal.AutomationNull]::Value`),
        which is the same as `$null` but will not be pipelined (see null example).
    .EXAMPLE
        $Foo = $null
        $Bar = 'zzz'
        $Baz = @(1, 2, $null)
        $Foo, $Bar, $Baz | Join-Array | ConvertTo-Json -Compress
        # Output: ["zzz",1,2,null]
    .EXAMPLE
        $null | Join-Array | ForEach-Object { ConvertTo-Json $_ -Compress }
        # No output, because the pipeline is empty.

        # Without `Join-Array`:
        $null | ForEach-Object { ConvertTo-Json $_ -Compress }
        # Output: null
    #>
    [CmdletBinding()]
    param (
        # The arrays to join.
        [Parameter(ValueFromPipeline)]
        $InputObject,
        # Do not filter out nulls on the first level.
        [switch]$IncludeNull
    )
    process {
        if ($MyInvocation.ExpectingInput) {
            if ($IncludeNull -or $null -ne $InputObject) {
                $InputObject
            }
        }
        else {
            foreach ( $SubObject in @($InputObject) ) {
                if ($IncludeNull -or $null -ne $SubObject) {
                    $SubObject
                }
            }
        }
    }
}
