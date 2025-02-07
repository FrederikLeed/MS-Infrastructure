### Scripts in this directory.  

#### Install - PingCastle webservice.ps1  
Install and configure Web Service for PingCastle Free  
  
Setup and configure Microsoft IIS with Windows Authentication and authorization.  
Setup Scheduled task to run PingCastleAutoUpdate every Friday at 05:00  
Setup Scheduled task to run PingCastle every night at 06:00  
  
To install just run.
PowerShell.exe -executionpolicy bypass -file '.\Install - PingCastle webservice.ps1' -$ADGroupName "PingCastle Viewers" -Verbose
