### Scripts in this directory.  

#### Install - PingCastle webservice.ps1  
Install and configure Web Service for PingCastle Free  
  
Setup and configure Microsoft IIS with Windows Authentication and authorization.  
Setup Scheduled task to run PingCastleAutoUpdate every Friday at 05:00  
Setup Scheduled task to run PingCastle every night at 06:00  
  
To install just run.
PowerShell.exe -executionpolicy bypass -file '.\Install - PingCastle webservice.ps1' -$ADGroupName "PingCastle Viewers" -Verbose

#### FixPrintNightMare.ps1
Create GPO to mitigate the Print Spooler issues, and assign to Domain Controllers OU.

#### Remove-NestedGroups.ps1
Remote All nested groups from all BuiltIn High Privilige groups

#### Set-AccountNotDelegated.ps1
To ensure all users in BuiltIn High Privilige groups have the "this account is sensitive and cannot be delegated" flag set.

#### Set-ProtectedUsers.ps1
To ensure all users in BuiltIn High Privilige groups is member of the Protected Users group.

#### ValidatePasswords.ps1
To ensure password policy requires atleast 14 chars, and all users in BuiltIn High Privilige groups, have changed password recently.

#### Update-MSFT-AuditPolicy.ps1
After importing the MSFT baselines, the auditing needs to be modified, by adding "Audit DPAPI Activity", and "Audit Logoff".



