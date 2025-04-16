<#

    Make all Domain Admins member of protected users (Skip Break Glass Administrator)

    If there are any accounts used as Service Accounts in the Domain Admins group, please remove and delegate the required permissions.

#>

# Define YOUR breakglass accounts that will be skipped.
# --------------------------------------------------
$BreakGlassAccountNames = ""#@("Administrator","AdminBreakGlass")


# Get the Sensitive groups
# --------------------------------------------------
$PrivilegedGroupNames = @("Domain Admins", "Enterprise Admins", "Schema Admins", "Administrators")
$ProtectedUsersGroup = (Get-ADGroup -Filter { Name -eq "Protected Users" }).DistinguishedName


# Get all group members
#--------------------------------------------------
$DomainAdmins = $PrivilegedGroupNames | Get-ADGroupMember -Recursive | Get-ADUser -Properties MemberOf | Select-Object -Unique | `
Where-Object { $_.Name -notIn $BreakGlassAccountNames -and $_.objectClass -eq "user" -and $_.MemberOf -notcontains $ProtectedUsersGroup }


# Add selected users to Protected Users group.
# --------------------------------------------------
Foreach ($User in $DomainAdmins | Select-Object Name, UserPrincipalName, DistinguishedName | Out-GridView -Title "Select all the accounts to add to `"Protected Users`"" -OutputMode Multiple) {
    Add-ADGroupMember -Identity "Protected Users" -Members $User.DistinguishedName
}
