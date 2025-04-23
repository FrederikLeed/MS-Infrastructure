#### Install - PingCastle webservice.ps1  
Install and configure Web Service for PingCastle Free  
  
Setup and configure Microsoft IIS with Windows Authentication and authorization.  
Setup Scheduled task to run PingCastleAutoUpdate every Friday at 05:00  
Setup Scheduled task to run PingCastle every night at 06:00  

ToDo.  
Add binding 443  
Add Domain Cert  

To install just run.
PowerShell.exe -executionpolicy bypass -file '.\Install - PingCastle webservice.ps1' -ADGroupName "PingCastle Viewers" -Verbose  
  
  
#### License requirements.
Please note this is created in my spare time, I use PingCastle at work and have an Auditor license.
I recommend purchasing an enterprise license if you want more detailed reports.  

https://pingcastle.com/purchase/
