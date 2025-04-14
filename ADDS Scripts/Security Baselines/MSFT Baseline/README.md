### Scripts in this directory.  

#### Import-MSFT-Baselines.ps1
Download and import selected Microsoft Security Baselines.


#### Set-VMIFilters.ps1
Add WMI filters to each of the imported Baselines.


#### Create-Overrides.ps1
Create Override GPO foreach of the imported GPOs.  
Add/remove some settings that I ussaly do


#### Update-MSFT-AuditPolicy.ps1
To satisfy PingCastle, the MSFT Baseline DC auditing needs to be modified.  
Include Success on "Audit DPAPI Activity", and "Audit Logoff".
