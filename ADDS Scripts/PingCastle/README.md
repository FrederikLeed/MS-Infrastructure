### Disclaimer Regarding PingCastle Usage
    
PingCastle's free "Basic Edition" is intended for personal use or auditing your own systems.
Commercial use, including generating reports for third parties, requires an appropriate license.
For more details, refer to PingCastle's Terms and Conditions.

    
User Responsibility:
Users of these scripts are responsible for ensuring compliance with PingCastle's licensing terms.
If you intend to use PingCastle for commercial purposes or require advanced features,
you must obtain the necessary license directly from PingCastle.

    
No Warranty:
These scripts are provided as-is, without any warranty or guarantee of compliance with
PingCastle's licensing terms. Use them at your own discretion.


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
