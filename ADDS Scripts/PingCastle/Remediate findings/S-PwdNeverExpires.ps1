<#

    List Domain Admins with password Never Expires

    - Is is recommended that all the users in Domain Admins and Administrators groups change password reguarly

#>

$DomainAdmins = Get-ADGroupMember "Domain Admins" | Get-ADUser -Properties PasswordNeverExpires | Where-Object {
  $_.PasswordNeverExpires -and $_.objectClass -eq "user" -and $_.Name -ne "Administrator"
}


foreach ($User in $DomainAdmins) {
    $User.DistinguishedName | Set-ADUser -PasswordNeverExpires $false
}
