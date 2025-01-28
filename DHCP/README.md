Since I meet many customers where the DHCP service have been installed on one or more of the Domain Controllers, I have created this collection of scripts that can assist with the migration of the DHCP role away from the Domain Controller(s)

There will still be required some work on the network to update / change the IP Helper(s) to allow for the DHCP service to move, this will be a manual task...


Scripts in this directory.
Setup-Dhcp-Server.ps1
Can be used to install and configure a standalone DHCP server, the script will also import the latest backup, and authorize the DHCP server in Active Directory.

Backup-Dhcp-Server.ps1
Backup DHCP Scopes and Leases to an XML backup on the UNC path provided.

Restore-Dhcp-Server.ps1
Restore DHCP Scopes and Leases from lastest XML backup on the UNC path provided.


Add-BackupSchedule.ps1
Creates a Scheduled Task that executes the backup script as local system.
This requires Write permissions the UNC path for the DHCP servers AD Account. (DHCP-01$)
