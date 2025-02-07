<#

    Check that there is no account with never-expiring passwords
    - The purpose is to ensure that every account has a password which is compliant with password expiration policies


    Check if all admin passwords are changed on the field
    - The purpose is to ensure that all admins are changing their passwords at least every 3 years 


    Check for short password length in password policy
    - The purpose is to verify if the password policy of the domain enforces users to have at least 8 characters in their password

#>

# Set PDC as deault server
# ------------------------------------------------------------
$PSDefaultParameterValues = @{
    "*AD*:Server" = $(Get-ADDomain).PDCEmulator
}


# ------------------------------------------------------------
$DomainAdmins = Get-ADGroupMember "Domain Admins"
$PriviligeGroups = @("Administrators", "Domain Admins", "Enterprise Admins", "Schema Admins")


# Validate that Domain Admins have updated the password.
# --------------------------------------------------
$PasswordAge = 180
$DomainAdmins.DistinguishedName | Get-ADUser -Properties PasswordLastSet | Where-Object {
    $_.PasswordLastSet -lt (Get-Date).adddays(-$PasswordAge) -and $_.Enabled -eq $True
} | Select-Object -Property Name, PasswordLastSet, DistinguishedName | Out-GridView -Title "Please update password on listed users ASAP" -OutputMode None



# Make sure members of Domain Admin must change password
# --------------------------------------------------
$SelectedUsers = $DomainAdmins.DistinguishedName | Get-ADUser -Properties PasswordNeverExpires | Where-Object {
    $_.PasswordNeverExpires -and $_.objectClass -eq "user" -and $_.Name -ne "Administrator"
} | Select-Object Name, UserPrincipalName, DistinguishedName | Out-GridView -Title "Select the admins that are NOT used as service accounts" -OutputMode Multiple


if ($Null -ne $SelectedUsers) {

    $DomainAdmins.DistinguishedName | Set-ADUser -PasswordNeverExpires $false

}


# Update Default Domain Password Policy
$PasswordLength = 14
if ((Get-ADDefaultDomainPasswordPolicy -Identity $(Get-ADDomain).DNSRoot).MinPasswordLength -lt $PasswordLength) {
    Set-ADDefaultDomainPasswordPolicy -MinPasswordLength $PasswordLength -Identity $DomainInfo.DNSRoot
}
