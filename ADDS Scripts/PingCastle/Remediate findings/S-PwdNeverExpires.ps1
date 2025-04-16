<#

    The purpose is to ensure that every account has a password which is compliant with password expiration policies

    Some accounts have passwords which never expire. Should an attacker compromise one of these accounts, he would be able to maintain long-term access to the Active Directory domain.

    
    Custom step: Ensure Domain Admins must change password, list all regular users.
    
    Note:
    1. For regular users please also ensure they mist change password atleast every year.
    2. Please change any Service Accounts to gMSC where posible.

#>


# Ensure Domain Admins must change password.
# --------------------------------------------------
Get-ADGroupMember "Domain Admins" | Get-ADUser -Properties PasswordNeverExpires | Where-Object {
  $_.PasswordNeverExpires -and $_.objectClass -eq "user" -and $_.Name -ne "Administrator"
} | Set-ADUser -PasswordNeverExpires $false


# List users with PasswordNeverExpires
# --------------------------------------------------
Get-ADUser -Filter * -Properties PasswordLastSet,PasswordNeverExpires | Where-Object {
    $_.PasswordNeverExpires -and $_.objectClass -eq "user"
} | Select-Object -Property Name,PasswordLastSet,DistinguishedName
