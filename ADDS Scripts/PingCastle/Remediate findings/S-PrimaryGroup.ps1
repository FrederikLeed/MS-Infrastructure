# Get Group Domain Users
# ------------------------------------------------------------
$PrimaryUsersGroup = Get-ADGroup "Domain Users" -properties @("primaryGroupToken")
$SkipUsers = Get-AdUser -Identity "Guest" -Properties PrimaryGroup


# Find all users with other primary group
# ------------------------------------------------------------
$Users = Get-ADUser -Filter * -Properties PrimaryGroup | Where-Object {
    $_.DistinguishedName -NotIn $SkipUsers.DistinguishedName -and $_.PrimaryGroup -ne $PrimaryUsersGroup.DistinguishedName
}


# Change primary group to Domain Users.
# ------------------------------------------------------------
foreach ($user in $Users) {
    Get-ADUser -Identity $User.DistinguishedName | Set-ADUser -replace @{primaryGroupID=$PrimaryUsersGroup.primaryGroupToken}
}
