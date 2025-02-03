<#

    Check that there is no account with never-expiring passwords
    - The purpose is to ensure that every account has a password which is compliant with password expiration policies


    Check for short password length in password policy
    - The purpose is to verify if the password policy of the domain enforces users to have at least 8 characters in their password


    Check if all admin passwords are changed on the field
    - The purpose is to ensure that all admins are changing their passwords at least every 3 years 


#>


# Validate that Domain Admins have updated the password.
# --------------------------------------------------
$PasswordAge = 180
$OldAdmPwd = Get-ADGroupMember "Domain Admins" | Get-ADUser -Properties PasswordLastSet | Where-Object {
    $_.PasswordLastSet -lt (Get-Date).adddays(-$PasswordAge) -and $_.Enabled -eq $True
} | Select-Object -Property Name, PasswordLastSet, DistinguishedName | Out-GridView -Title "Please update password on listed users ASAP" -OutputMode Multiple

if ($null -ne $OldAdmPwd) {

#    Disable-ADAccount -Identity $OldAdmPwd.DistinguishedName

}