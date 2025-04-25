#### Disable-Stale-Computers.ps1
Find and disable all computers that havnt logged in to Active Directory in 180 days.

#### Disable-Stale-Users.ps1
Find and disable all users that havnt logged in to Active Directory in 180 days.

#### Remove-Stale-Computers.ps1
Removes all computers that have been disabled with the "Disable-Stale-Computers.ps1" after 180 days

#### Remove-Stale-Users.ps1
Removes all users that have been disabled with the "Disable-Stale-Users.ps1" after 180 days

#### Remove-Unused-GPOs.ps1
Find and delete all GPOs that is NOT linked to any OUs or have all settings disabled.
- Please run the GPO Backup/GPO-Export-and-Backup.ps1 prior to executing this.

#### Remove-NestedGroups.ps1
Remote All nested groups from all BuiltIn High Privilige groups

#### Set-AccountNotDelegated.ps1
To ensure all users in BuiltIn High Privilige groups have the "this account is sensitive and cannot be delegated" flag set.

#### Set-ProtectedUsers.ps1
To ensure all users in BuiltIn High Privilige groups is member of the Protected Users group.

#### ValidatePasswords.ps1
To ensure password policy requires atleast 14 chars, and all users in BuiltIn High Privilige groups, have changed password recently.
