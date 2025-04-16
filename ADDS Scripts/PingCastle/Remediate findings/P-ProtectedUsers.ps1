<#

    The purpose is to ensure that all privileged accounts are in the Protected User security group

    The Protected User group is a special security group which automatically applies protections to minimize credential exposure


    Custom step: Ignore builtIn Administrator and defined Break Glass Admin

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
