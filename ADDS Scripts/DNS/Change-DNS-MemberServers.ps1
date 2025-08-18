<#

    This script changes DNS servers on all Member servers to the current DNS servers registred on Domain DNS Zone.
    Must run with a user that has permissions to do the change (eg Domain Admin or Server Local Admin)
    
#>


# Get IP of DNS servers, if not ALL domain controllers are to be used, change this to a manual list.
# ------------------------------------------------------------
#$DomainDNS = @("10.10.10.11","10.10.10.12")
$DomainDNS = (Resolve-DnsName (Get-ADDomain).DNSRoot).IPAddress


# Get all servers from Domain, can be limited to search specific OU tree
# ------------------------------------------------------------
$Servers = Get-ADComputer -Filter "OperatingSystem -Like '*Windows Server*' -and Enabled -eq 'True'" # -SearchBase "OU=Servers,OU=Country,DC=Domain,DC=Local"
$Servers = $Servers | Where {$_.DNSHostname -NOTlike "$($env:COMPUTERNAME)*" -and $_.DistinguishedName -Notlike "*Domain Controllers*"}


# Connect and change DNS Address
# ------------------------------------------------------------
Invoke-Command $Servers.DNSHostName -Scriptblock {
        
    $Interface = Get-NetAdapter | Where {$_.Status -eq "up"}
    $CurrentDNS = (Get-DnsClientServerAddress -InterfaceIndex $Interface.InterfaceIndex -AddressFamily IPv4).ServerAddresses -join(", ")

    $RandomDomainDNS = $Using:DomainDNS | Sort-Object {Get-Random}
    Write-Output "$($env:COMPUTERNAME); Change DNS Server(s) {$CurrentDNS} to DNS Server(s) {$($RandomDomainDNS -join(", "))}"

    Set-DnsClientServerAddress -InterfaceIndex $Interface.InterfaceIndex -ServerAddresses $RandomDomainDNS
}
