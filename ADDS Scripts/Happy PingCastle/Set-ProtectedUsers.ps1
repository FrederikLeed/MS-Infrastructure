<#
    
    Finding : Check if all privileged accounts are in "Protected Users"
    - Disables NTLM authentication
    - Reduces Kerberos ticket lifetime
    - Mandates strong encryption algorithms, such as AES
    - Prevents password caching on workstations
    - Prevents any type of Kerberos delegation

#>

# Find all members of Domain Admins and .....
# --------------------------------------------------
$PriviligeGroups = @("Administrators", "Domain Admins", "Enterprise Admins", "Schema Admins")
$ProtectedUsersGroup = (Get-ADGroup -Filter { Name -eq "Protected Users" }).DistinguishedName

$SelectedUsers = $PriviligeGroups | Get-ADGroupMember -Recursive | Get-ADUser -Properties MemberOf | Select-Object -Unique | `
    Where-Object { $_.Name -notIn $BreakGlassAccountNames -and $_.objectClass -eq "user" -and $_.MemberOf -notcontains $ProtectedUsersGroup } | `
        Select-Object Name, UserPrincipalName, DistinguishedName | Out-GridView -Title "Select the admins that are NOT used as service accounts" -OutputMode Multiple

if ($Null -ne $SelectedUsers) {

    Add-ADGroupMember -Identity "Protected Users" -Members $SelectedUsers.DistinguishedName

}
