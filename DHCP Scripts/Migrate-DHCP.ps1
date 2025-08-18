<#

    Prior to running this, IP Helpers on all VLans must be updated to point to both the OLD and the NEW DHCP servers

#>



# Define the staying DHCP server in the domain.
# ------------------------------------------------------------
$LastDHCPServer = "DHCP-01.$($env:USERDNSDOMAIN)"


# Make sure the DHCP server is ready.
# ------------------------------------------------------------
#Install-WindowsFeature -Name DHCP -IncludeManagementTools -ComputerName $LastDHCPServer

$DHCPServerInfo = Resolve-DnsName -Name $LastDHCPServer -Type A -ErrorAction SilentlyContinue
Add-DhcpServerInDC -DnsName $($DHCPServerInfo.Name) -IPAddress $($DHCPServerInfo.IPAddress)


# Get all DHCP servers from AD
# ------------------------------------------------------------
$DHCPServers = Get-DhcpServerInDC


# Remove all DEAD servers from Active Directory
# ------------------------------------------------------------
$ResolveDHCPServers = @()
foreach ($DHCPServer in $DHCPServers) {

    if (!(Resolve-DnsName -Name $DHCPServer.DnsName -Type A -ErrorAction SilentlyContinue)) {
        # Remove-DhcpServerInDC -DnsName $DHCPServer.DnsName -IPAddress $DHCPServer.IPAddress -Confirm:$False
        Write-Host "Remove-DhcpServerInDC -DnsName $($DHCPServer.DnsName) -IPAddress $($DHCPServer.IPAddress) -Confirm:$False"
    } else {
        $ResolveDHCPServers += $DHCPServer
    }
}


# Move all scopes to $LastDHCPServer
# ------------------------------------------------------------
$ExportDHCPServers = $ResolveDHCPServers | Where {$_.DnsName -ne "$LastDHCPServer"}
foreach ($DHCPServer in $ExportDHCPServers) {

    $Scopes = Get-DhcpServerv4Scope -ComputerName $DHCPServer.DnsName
    Foreach ($Scope in $Scopes) {

        # Export scope with leases to XML
        # ------------------------------------------------------------
#        Export-DhcpServer -ComputerName $($DHCPServer.DnsName) -ScopeId $($Scope.ScopeID) -File "$($env:TEMP)\$($Scope.ScopeID).xml" -Leases
        Write-Output "Export-DhcpServer -ComputerName $($DHCPServer.DnsName) -ScopeId $($Scope.ScopeID) -File `"$($env:TEMP)\$($Scope.ScopeID).xml`" -Leases"


        # Import scope with leases from XML
        # ------------------------------------------------------------
#        Import-DhcpServer -ComputerName "$LastDHCPServer.zealandpharm.net" -File "$env:TEMP\$($Scope.ScopeID).xml"
        Write-Output "Import-DhcpServer -ComputerName `"$LastDHCPServer.$($env:USERDNSDOMAIN)`" -File `"$env:TEMP\$($Scope.ScopeID).xml`""


        # Disable Scope
        # ------------------------------------------------------------
#        Get-DhcpServerv4Scope -ComputerName $($DHCPServer.DnsName) -ScopeId $($Scope.ScopeID) | Set-DhcpServerv4Scope -State InActive
        Write-Output "Get-DhcpServerv4Scope -ComputerName $($DHCPServer.DnsName) -ScopeId $($Scope.ScopeID) | Set-DhcpServerv4Scope -State InActive"


        # Remove XML file
        # ------------------------------------------------------------
#        Remove-Item -Path "$($env:TEMP)\$($Scope.ScopeID).xml"
        Write-Output "Remove-Item -Path `"$($env:TEMP)\$($Scope.ScopeID).xml`""
    }


    # Remove server from Active Directory
    # ------------------------------------------------------------
#    Remove-DhcpServerInDC -DnsName $($DHCPServer.DnsName) -IPAddress $($DHCPServer.IPAddress) -Confirm:$False
    Write-Output "Remove-DhcpServerInDC -DnsName $($DHCPServer.DnsName) -IPAddress $($DHCPServer.IPAddress) -Confirm:$False"
}



<#

    OLD Dhcp servers must now be removed from IP Helpers on all VLans

#>
