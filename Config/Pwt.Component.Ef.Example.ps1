# Copy to "Config.ps1" and fill required information.
# Support PODE_ENVIRONMENT https://badgerati.github.io/Pode/Tutorials/Configuration/
@{
    SettingsPage = $true
    AdminPage    = $true
    AdminPageAccessGroups = @('Admins')
    CreateTables = $true
}