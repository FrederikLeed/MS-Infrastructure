<#
     _                _       _                         ___                         _____                              
    | |              | |     | |                       |_  |                       /  ___|                             
    | |     ___   ___| | ____| | _____      ___ __       | |_   _ _ __ ___  _ __   \ `--.  ___ _ ____   _____ _ __ ___ 
    | |    / _ \ / __| |/ / _` |/ _ \ \ /\ / / '_ \      | | | | | '_ ` _ \| '_ \   `--. \/ _ \ '__\ \ / / _ \ '__/ __|
    | |___| (_) | (__|   < (_| | (_) \ V  V /| | | | /\__/ / |_| | | | | | | |_) | /\__/ /  __/ |   \ V /  __/ |  \__ \
    \_____/\___/ \___|_|\_\__,_|\___/ \_/\_/ |_| |_| \____/ \__,_|_| |_| |_| .__/  \____/ \___|_|    \_/ \___|_|  |___/
                                                                           | |                                         
                                                                           |_|                                         

    Ensure firewall are enabled on all JumpServers and limited to only allow RDP from the Remote Desktop Gateway server(s)

#>


<#

    Create Jumpstations group

#>
$TierOUName = "Admin"
$MGMTServerGroup = "Domain Tier - Management Servers"
$TierSearchBase = (Get-ADOrganizationalUnit -Filter "Name -like '*$TierOUName*'" -SearchScope OneLevel).DistinguishedName
$TierZeroPath = ((Get-ADOrganizationalUnit -Filter * -SearchBase $TierSearchBase | Where {$_.DistinguishedName -like "*Groups*Tier0*"})[0]).DistinguishedName

Try {
    $GroupName = Get-AdGroup -Identity $MGMTServerGroup
}
catch {
    New-ADGroup -Name $MGMTServerGroup -Description "Remote Desktop Gateway Network Recources group" -GroupScope Global -GroupCategory Security -Path $TierZeroPath
}

# Add all JumpStations to the Group.
Add-ADGroupMember -Identity $MGMTServerGroup -Members $(Get-ADComputer -Filter * | where {$_.DistinguishedName -like "*JumpStations*"})


<#

    Update RDGW CAP

#>
Invoke-Command -ComputerName $((Get-ADComputer -Filter "Name -like '*RDGW*'").DNSHostName) -ScriptBlock {

    Import-Module RemoteDesktopServices

    if (Test-Path -Path "RDS:\GatewayServer\RAP\Remote Desktop Gateway - MFA") {
        Remove-Item -Path "RDS:\GatewayServer\RAP\Remote Desktop Gateway - MFA" -Recurse -Force
    }

    New-Item -Path "RDS:\GatewayServer\RAP" -Name "Remote Desktop Gateway - MFA" -UserGroups "Domain ConnectionAccounts@$($ENV:UserDomain)" -ComputerGroupType 1 -ComputerGroup "$Using:MGMTServerGroup@$($ENV:UserDomain)" | Out-Null
}



<#
    Update firewall GPO policy on JumpStations

#>
$GPO = Get-GPO -Name "Admin - Enable Remote Desktop w NLA Disabled"

# Get IP Addresse of Remote Desktop Gateway Servers.
$IPAddresses = (($((Get-ADComputer -Filter "Name -like '*RDGW*'").DNSHostName) | Resolve-DnsName) | % { "|RA4=" + $_.IPAddress } ) -Join("")

$Value = "v2.31|Action=Allow|Active=TRUE|Dir=In|Protocol=17|LPort=3389" + $IPAddresses + "|App=%SystemRoot%\system32\svchost.exe|Svc=termservice|Name=@FirewallAPI.dll,-28776|Desc=@FirewallAPI.dll,-28777|EmbedCtxt=@FirewallAPI.dll,-28752|"
Set-GPRegistryValue -Name $GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\FirewallRules" -ValueName "RemoteDesktop-UserMode-In-UDP" -Value $Value -Type String | Out-Null

$Value = "v2.31|Action=Allow|Active=TRUE|Dir=In|Protocol=6|LPort=3389" + $IPAddresses + "|App=%SystemRoot%\system32\svchost.exe|Svc=termservice|Name=@FirewallAPI.dll,-28775|Desc=@FirewallAPI.dll,-28756|EmbedCtxt=@FirewallAPI.dll,-28752|"
Set-GPRegistryValue -Name $GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\FirewallRules" -ValueName "RemoteDesktop-UserMode-In-TCP" -Value $Value -Type String | Out-Null

Set-GPRegistryValue -Name $GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\FirewallRules" -ValueName "RemoteDesktop-Shadow-In-TCP" -Value "v2.31|Action=Allow|Active=FALSE|Dir=In|Protocol=6|App=%SystemRoot%\system32\RdpSa.exe|Name=@FirewallAPI.dll,-28778|Desc=@FirewallAPI.dll,-28779|EmbedCtxt=@FirewallAPI.dll,-28752|Edge=TRUE|Defer=App|" -Type String | Out-Null
