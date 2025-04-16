<#

    The purpose is to ensure that there are as few inactive accounts as possible within the domain. Stale user accounts are a significant security issue,
    as former employees and external attackers could use those accounts to attack the organization.

    * To mitigate the risk, you should monitor the number of inactive accounts and reduce it as much as possible
    
#>


# Get cleanup script.
# --------------------------------------------------
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SysAdminDk/MS-Infrastructure/refs/heads/main/ADDS%20Scripts/Cleanup/Disable-Stale-Users.ps1" -OutFile "$($env:USERPROFILE)\Downloads\Disable-Stale-Users.ps1"


# If you want, change the DisableTimeSpan
# --------------------------------------------------
ISE "$($env:USERPROFILE)\Downloads\Disable-Stale-Users.ps1"

# Execute.
# --------------------------------------------------
& "$($env:USERPROFILE)\Downloads\Disable-Stale-Users.ps1"
