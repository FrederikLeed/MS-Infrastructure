<#
    
    Finding : At least one administrator account can be delegated
    - The purpose is to ensure that all Administrator Accounts have the configuration flag "this account is sensitive and cannot be delegated"

#>

# Set PDC as deault server
# ------------------------------------------------------------
$PSDefaultParameterValues = @{
    "*AD*:Server" = $(Get-ADDomain).PDCEmulator
}


# Find all members of Domain Admins and ensures that the flag is set.
# --------------------------------------------------
$PriviligeGroups = @("Administrators", "Domain Admins", "Enterprise Admins", "Schema Admins", "DnsAdmins", "Group Policy Creator Owners")

$AdminUsers = $PriviligeGroups | Get-ADGroupMember -Recursive | Select-Object -Unique | Get-ADUser
$AdminUsers = $AdminUsers | Get-ADUser -Properties AccountNotDelegated | Where-Object { -not $_.AccountNotDelegated }

$SelectedUsers = $AdminUsers | Select-Object Name, SamAccountName, UserPrincipalName, DistinguishedName | `
    Out-GridView -Title "Select the admins that are NOT used as service accounts" -OutputMode Multiple

if ($Null -ne $SelectedUsers) {

    $SelectedUsers.DistinguishedName | Set-ADUser -AccountNotDelegated $true

}
