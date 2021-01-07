$ErrorActionPreference = 'Stop'

function Connect-Exchange {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Dummy')]
        [Switch]$Dummy,
        [Parameter(Mandatory, ParameterSetName = 'Remote')]
        [String]$ConnectionUri,
        [Parameter(Mandatory, ParameterSetName = 'Remote')]
        [PSCredential]$Credential,
        [Parameter(Mandatory, ParameterSetName = 'Tools')]
        [Switch]$Tools
    )
    if ($Script:ExchangePSSession.State -eq 'Opened' -or $Script:Dummy -or $Script:Tools) {
        Return
    }
    if ($Dummy) {
        Write-Warning 'Dummy Exchange connect.'
        $Script:Dummy = @(
            [PSCustomObject]@{
                Timestamp      = Get-Date
                EventId        = 'DELIVER'
                Source         = 'STOREDRIVER'
                Sender         = 'me@example.com'
                Recipients     = 'you@example.com'
                MessageSubject = 'Nerd stuff'
            },
            [PSCustomObject]@{
                Timestamp      = Get-Date
                EventId        = 'DELIVER'
                Source         = 'STOREDRIVER'
                Sender         = 'me@example.com'
                Recipients     = 'you@example.com'
                MessageSubject = 'Nerd stuff 2'
            }
        )
    }
    elseif ($Tools) {
        Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn
        $Script:TransportServices = Get-TransportService
        $Script:Tools = $true
    }
    else {
        if ($Script:ExchangePSSession.State -eq 'Broken') {
            Remove-PSSession -Session $Script:ExchangePSSession
            $Script:ExchangePSSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $ConnectionUri -Credential $Credential
            & $Script:ExchangePSModuleInfo Set-PSImplicitRemotingSession -PSSession $Script:ExchangePSSession -createdByModule $True
        }
        else {
            $Script:Dummy = $null
            $Script:ExchangePSSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $ConnectionUri -Credential $Credential
            $Script:ExchangePSModuleInfo = Import-PSSession -Session $Script:ExchangePSSession
            $Script:TransportServices = Get-TransportService
        }
    }
}
function Disconnect-Exchange {
    [CmdletBinding()]
    param ()
    if (!$Script:Dummy -and !$Script:Tools) {
        $Script:ExchangePSSession | Remove-PSSession
    }
}

function Search-MessageTracking {
    [CmdletBinding()]
    param (
        [DateTime]$Start,
        [DateTime]$End,
        [String]$Sender,
        [String]$Recipients,
        [String]$MessageSubject

    )
    if ($Script:Dummy) {
        $Script:Dummy
        Write-Warning ('Dummy filter for:' + ($PSBoundParameters | Out-String))
    }
    else {
        $TransportServices | ForEach-Object {
            Get-MessageTrackingLog @PSBoundParameters -Server $_.Name
        }
    }
}