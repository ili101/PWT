@{
    Server = @{
        FileMonitor = @{
            Enable    = $true
            ShowFiles = $true
            Exclude   = @('.git\*', 'Storage\*', 'logs\*')
        }
    }
}