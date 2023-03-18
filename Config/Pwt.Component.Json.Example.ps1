@{
    Users = @(
        @{
            Name     = "User 1"
            Username = "u1"
            Email    = "u1@example.com"
            Password = Invoke-PodeSHA256Hash -Value 'pass'
            Groups   = @(
                'Admin', 'Developer'
            )
            Metadata = @{
                AuthenticationType = 'Json'
            }
        }
        @{
            Name     = "User 2"
            Username = "u2"
            Email    = "u2@example.com"
            Password = Invoke-PodeSHA256Hash -Value 'pass'
            Groups   = @(
                'Developer'
            )
            Metadata = @{
                AuthenticationType = 'Json'
            }
        }
    )
}