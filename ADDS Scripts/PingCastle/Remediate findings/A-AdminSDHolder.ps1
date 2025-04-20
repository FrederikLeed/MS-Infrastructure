<#

    The purpose is to ensure that there are no rogue admin accounts in the Active Directory

    These accounts should be reviewed, especially in regards with their past activities and have the admincount attribute removed

#>


# Find all Users with AdminCount = 1, clear only on regular users
# --------------------------------------------------
$ProtectedGroups = Get-ADGroup -Filter "AdminCount -eq 1"
$AdminCountUsers = Get-ADUser -Filter "AdminCount -eq 1" -Properties Memberof | Where {$_.Name -ne "krbtgt"}

foreach ($User in $AdminCountUsers) {
    if (!($User.MemberOf | Where {$_ -In $ProtectedGroups.DistinguishedName}).count -ge 1) {
        Write-Output "Clear AdminCount on $($User.DistinguishedName)"
        Set-ADUser -Identity $User.DistinguishedName -clear AdminCount
    }
}
