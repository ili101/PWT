# put where you want to stop:
Wait-Debugger

# If Debug enabled, PID will be printed on start.
# or use `Get-Process -Name pwsh`
Enter-PSHostProcess -Id (Read-Host -Prompt PID)

# Go to the waiting runspace:
Get-Runspace | where-Object { $_.Debugger.InBreakpoint -eq 'InBreakpoint' } | Debug-Runspace
