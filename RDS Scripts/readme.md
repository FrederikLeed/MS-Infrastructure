## Setup Remote Desktop Session host farm(s)
### The example scripts in this folder, will setup an Remote Access option for accesing On-Premis servers, can be used for internal and externals, just remember the security implications.

#### Most of the scripts have the assumption that you KNOW what you are doing, and some still have the hardcoded domain and ip information from my LAB.

All servers needs to be created and joined to the Active Directory, that process is not part of this..

Servers required, for all.  
RDLI-01 - Remote Desktop Licenseing server  
  
Servers required, in Tier 0  
MGMT-01 - Management / Jump server Tier0  
MGMT-02 - Management / Jump server Tier0  
  
Servers required, in Tier 1  
RDDB-01 - SQL Server - Always on Cluster node  
RDDB-02 - SQL Server - Always on Cluster node  
RDCB-01 - Remote Desktop Connection broker  
RDCB-02 - Remote Desktop Connection broker  
RDGW-01 - Remote Desktop Gateway and Entra Private Network Connector  
RDGW-02 - Remote Desktop Gateway and Entra Private Network Connector  
MGMT-11 - Management / Jump server Tier1  
MGMT-12 - Management / Jump server Tier1  
MGMT-L1 - Management / Jump server Tier1 Limited  
MGMT-L1 - Management / Jump server Tier1 Limited  
  
If Tier2 is needed.
MGMT-21 - Management / Jump server Tier2  
MGMT-22 - Management / Jump server Tier2  

Servers required, in Tier Endpoint (Service Desk)
MGMT-91 - Management / Jump server TierE  
MGMT-92 - Management / Jump server TierE  

Please use with causion, have been tested on server 2022 and 2025.
