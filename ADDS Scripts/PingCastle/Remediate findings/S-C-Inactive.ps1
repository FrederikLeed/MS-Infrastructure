<#

    The purpose is to ensure that there are as few inactive computers as possible within the domain.

    * To mitigate the risk, you should monitor the number of inactive accounts and reduce it as much as possible
    
#>


# Get cleanup script.
# --------------------------------------------------
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SysAdminDk/MS-Infrastructure/refs/heads/main/ADDS%20Scripts/Cleanup/Disable-Stale-Computers.ps1" -OutFile "$($env:USERPROFILE)\Downloads\Disable-Stale-Computers.ps1"


# If you want, change the DisableTimeSpan
# --------------------------------------------------
ISE "$($env:USERPROFILE)\Downloads\Disable-Stale-Computers.ps1"

# Execute.
# --------------------------------------------------
& "$($env:USERPROFILE)\Downloads\Disable-Stale-Computers.ps1"
