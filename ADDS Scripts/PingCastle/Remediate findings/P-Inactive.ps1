<#

    The purpose is to ensure that all admins are changing their passwords at least every year

    This rule ensure that passwords of administrator are well managed.

#>

# Define max password age.
# --------------------------------------------------
$DisableTimeSpan = 180
$PasswordAge = (Get-Date).AddMonths(-6)


# Find all Domain Admins that have OLD password
# --------------------------------------------------

Get-ADUser -Filter { LastLogonTimeStamp -lt $LastLogon -and PasswordLastSet -lt $PasswordAge -and Enabled -eq 'True' } -Properties Description,PasswordLastSet

$OldAdmis = Get-ADGroupMember "Domain Admins" | Get-ADUser -Properties PasswordLastSet | Where-Object {
    $_.LastLogonTimeStamp -lt $LastLogon -and $_.PasswordLastSet -lt $PasswordAge -and $_.Enabled -eq $True
}


Write-Output "Please update password on listed users ASAP"
$OldAdmis | Select-Object Name,PasswordLastSet,DistinguishedName
