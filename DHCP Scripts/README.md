## DHCP Server tools.

Unfortunately, I meet customers where the DHCP service have been installed on one or more of the Domain Controllers  
I have created this collection of scripts that can assist with the migration of the DHCP role away from the Domain Controller(s)

There is still the manual task of updating / changing the IP Helper(s) on network equipment!



### Scripts in this directory.    
#### Install-DHCP-Server.ps1
Install and Authorize DHCP Services on new Windows Server.

#### Restore-DHCP-Sopes.ps1  
Restore DHCP Scopes and Leases from latest XML backup on the UNC path provided.

#### Restore-DHCP-Server.ps1  
Install, Authorize and Restore DHCP Services on new Windows Server.
Execute, Install-DHCP-Server and Restore-DHCP-Scopes.

#### Add-DHCP-BackupSchedule.ps1  
Creates a Scheduled Task that executes the backup script as local system.
This requires Write permissions the UNC path for the DHCP servers AD Account. (DHCP-01$)

#### Backup-DHCP-Sopes.ps1  
Backup DHCP Scopes and Leases to an XML backup on the UNC path provided.

#### Add-DHCP-Failower.ps1  
To add additional DHCP server to the scopes if high availability is required.
I usually don’t recommend this, since managing the DHCP cluster can provide some challenges, and recreating a standalone DHCP server is quite fast.
