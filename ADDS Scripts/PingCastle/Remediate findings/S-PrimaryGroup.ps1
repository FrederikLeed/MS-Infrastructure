<#

    The purpose is to check for unusual values in the primarygroupid attribute used to store group memberships

    Unless strongly justified, change the primary group id to its default:
        513 or 514 for users,
        516 or 521 for domain controllers,
        514 or 515 for computers.
    
    The primary group can be edited in a friendly manner by editing the account with the "Active Directory Users and Computers" and after selecting the "Member Of" tab, "set primary group"

#>

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
