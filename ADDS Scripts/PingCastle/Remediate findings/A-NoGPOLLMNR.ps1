<#

    Adding GPO to disable NetBios, LLMNR, mDNS on all member servers.

    Disable Netbios in all DHCP Scopes.


    ! Note this can break single label resolution !

#>

# Find all DHCP servers published in AD.
# --
$DHCPServers = Get-DHCPServerInDC
$DHCPServers | % { Get-DhcpServerv4Scope -ComputerName $_.DNSName }




# Add GPO to Disable LLMNR & NetBios
# --
$GPO = New-GPO -Name "Disable LLMNR & Netbios"



