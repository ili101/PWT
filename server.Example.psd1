@{
    Server = @{
        # Reload server when files changes, useful for development.
        FileMonitor = @{
            Enable    = $true
            ShowFiles = $true
            Exclude   = @('.git\*', 'Storage\*', 'logs\*')
        }
        Request     = @{
            # Request timeout (seconds), default is 30.
            Timeout  = 600
            # Default limit is 100MB, Pode supports up to `[Int]::MaxValue` (1.99GB), Pode.Kestrel support higher limits.
            BodySize = 1.99GB
        }
    }
}