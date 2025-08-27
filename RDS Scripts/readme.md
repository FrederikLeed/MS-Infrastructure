## Setup Remote Desktop Session host farm(s)
### The example scripts in this folder, will setup an Remote Access option for accesing On-Premis servers, can be used for internal and externals, just remember the security implications.

#### Most of the scripts have the assumption that you KNOW what you are doing, and some still have the hardcoded domain and ip information from my LAB.

All servers needs to be created and joined to the Active Directory, that process is not part of this..

Servers required, for all.  
RDLI-01 - Remote Desktop Licenseing server  
  
Servers required, only for Tier 0  
RDGW-001 - Remote Desktop Gateway and Entra Private Network Connector  
RDGW-001 - Remote Desktop Gateway and Entra Private Network Connector  
MGMT-001 - Management / Jump server Tier0  
MGMT-002 - Management / Jump server Tier0  
  
Servers required, only for Tier 1  
RDDB-011 - SQL Server - Always on Cluster  
RDDB-012 - SQL Server - Always on Cluster  
RDCB-011 - Remote Desktop Connection broker  
RDCB-011 - Remote Desktop Connection broker  
RDGW-011 - Remote Desktop Gateway and Entra Private Network Connector  
RDGW-011 - Remote Desktop Gateway and Entra Private Network Connector  
MGMT-011 - Management / Jump server Tier1  
MGMT-012 - Management / Jump server Tier1  
MGMT-11L - Management / Jump server Tier1 Limited  
MGMT-11L - Management / Jump server Tier1 Limited  
  
If Tier2 is needed, a copy of Tier1 will be required, do NOT share across tiers.

Please use with causion, have been tested on server 2022 and 2025.
