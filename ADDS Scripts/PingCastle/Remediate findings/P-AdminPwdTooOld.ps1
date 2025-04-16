<#

    List Domain Admins with OLD password.

    - Is is recommended that all the users in Domain Admins and Administrators groups change password reguarly

#>

# Define max password age.
# --------------------------------------------------
$PasswordAge = (Get-Date).AddMonths(-6)


# Find all Domain Admins that have OLD password
# --------------------------------------------------
$OldAdmis = Get-ADGroupMember "Domain Admins" | Get-ADUser -Properties PasswordLastSet | Where-Object {
    $_.PasswordLastSet -lt $PasswordAge -and $_.Enabled -eq $True
}


Write-Output "Please update password on listed users ASAP"
$OldAdmis | Select-Object Name,PasswordLastSet,DistinguishedName
