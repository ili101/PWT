$ErrorActionPreference = 'Stop'

function Connect-Exchange {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Dummy')]
        [Switch]$Dummy,
        [Parameter(Mandatory, ParameterSetName = 'Remote')]
        [String]$ConnectionUri,
        [Parameter(Mandatory, ParameterSetName = 'Remote')]
        [PSCredential]$Credential
    )
    if ($Script:ExchangePSSession.State -eq 'Opened' -or $Script:Dummy) {
        Return
    }
    if ($Dummy) {
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
    else {
        $Script:Dummy = $null
        $Script:ExchangePSSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $ConnectionUri -Credential $Credential
        $Script:ExchangePSModuleInfo = Import-PSSession -Session $Script:ExchangePSSession
        $Script:TransportServices = Get-TransportService
    }
}
function Disconnect-Exchange {
    [CmdletBinding()]
    param ()
    if (!$Dummy) {
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
    if ($Dummy) {
        $Dummy
    }
    else {
        $TransportServices | ForEach-Object {
            Get-MessageTrackingLog @PSBoundParameters -Server $_.Name
        }
    }
}