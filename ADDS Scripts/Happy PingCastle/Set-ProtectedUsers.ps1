<#
    
    Finding : At least one administrator account can be delegated
    - The purpose is to ensure that all Administrator Accounts have the configuration flag "this account is sensitive and cannot be delegated"

#>

# Find all members of Domain Admins and ensures that the flag is set.
# --------------------------------------------------
$PriviligeGroups = ("Administrators", "Domain Admins", "Enterprise Admins", "Schema Admins", "DnsAdmins", "Group Policy Creator Owners")
$AdminUsers = $PriviligeGroups | Foreach { Get-ADGroupMember $($_) } | Where { $_.ObjectClass -Eq "User" } | Select-Object -Unique
$AdminUsers = $AdminUsers | Get-ADUser -Properties AccountNotDelegated | Where-Object { -not $_.AccountNotDelegated }

$SelectedUsers = $AdminUsers | Select-Object Name, UserPrincipalName, DistinguishedName | `
    Out-GridView -Title "Select the admins that isnt uses as service accounts" -OutputMode Multiple

if ($SelectedUsers) {

    $AdminUsers.DistinguishedName | Set-ADUser -AccountNotDelegated $true

}
