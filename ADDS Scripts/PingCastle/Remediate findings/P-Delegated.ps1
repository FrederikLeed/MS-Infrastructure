<#

    The purpose is to ensure that all Administrator Accounts have the configuration flag "this account is sensitive and cannot be delegated"

    To correct the situation, you should make sure that all your Administrator Accounts have the check-box "This account is sensitive and cannot be delegated"
    active or add your Administrator Accounts to the built-in group "Protected Users"

#>

# We need to skip the BuildIn Administrator
# --------------------------------------------------
$BuiltInAdmin = Get-ADUser -Identity "Administrator"


# Get All Domain Admin users, and select all that will get the "This account is sensitive and cannot be delegated" flag set.
# --------------------------------------------------
$DomainAdmins = Get-ADGroupMember "Domain Admins" | Get-ADUser -Properties AccountNotDelegated | Where-Object {
    $_.SID -ne $BuiltInAdmin.SID -and
    -not $_.AccountNotDelegated -and
    $_.objectClass -eq "user"
}


# Add "This account is sensitive and cannot be delegated" to the selected users
# --------------------------------------------------
foreach ($User in $DomainAdmins | Select-Object Name, UserPrincipalName, DistinguishedName | Out-GridView -Title "Select all the accounts to add the `"This account is sensitive and cannot be delegated`"" -OutputMode Multiple) {
    $SelectedAdmins.DistinguishedName | Set-ADUser -AccountNotDelegated $true
}
