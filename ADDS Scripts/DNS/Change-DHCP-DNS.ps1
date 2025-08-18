<#

    This script changes DNS servers on all DHCP scopes to the current DNS servers registred on Domain DNS Zone.
    Must run with a user that has permissions to do the change (eg Domain Admin)

#>


# Define DNS servers for all DHCP scopes, if not ALL domain controllers are to be used, change this to a manual list.
# ------------------------------------------------------------
#$DomainDNS = @("10.10.10.11","10.10.10.12")
$DomainDNS = (Resolve-DnsName (Get-ADDomain).DNSRoot).IPAddress


# Get all DHCP servers from AD
# ------------------------------------------------------------
$DHCPServers = Get-DhcpServerInDC


# Resolve DHCP hosts
# ------------------------------------------------------------
$ResolveDHCPServers = @()
foreach ($DHCPServer in $DHCPServers) {
    if (Resolve-DnsName -Name $DHCPServer.DnsName -DnsOnly -ErrorAction SilentlyContinue) {
        $ResolveDHCPServers += $DHCPServer
    }
}


# Connecto to DHCP and change DNS server on all scopes.
# ------------------------------------------------------------
foreach ($DHCPServer in $ResolveDHCPServers) {

    $DHCPScopes = Get-DhcpServerv4Scope -ComputerName $DHCPServer.DnsName | Out-GridView -Title "Select scopes to change" -OutputMode Multiple
    Foreach ($Scope in $DHCPScopes) {
        $CurrentDNS = (Get-DhcpServerv4OptionValue -ComputerName $DHCPServer.DnsName -ScopeId $Scope.ScopeID -OptionId 6 | Select-Object Value).Value -join(", ")
        Write-Output "Change DHCP [$($Scope.Name)] Scope, current DNS {$CurrentDNS} to new DNS {$($DomainDNS -join(", "))}"

        Set-DhcpServerv4OptionValue -ComputerName $DHCPServer.DnsName -ScopeId $Scope.ScopeID -DnsServer $DomainDNS
    }
}
