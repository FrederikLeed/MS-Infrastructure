<#
    ____________   _____       _                           
    | ___ \  _  \ |  __ \     | |                          
    | |_/ / | | | | |  \/ __ _| |_ _____      ____ _ _   _ 
    |    /| | | | | | __ / _` | __/ _ \ \ /\ / / _` | | | |
    | |\ \| |/ /  | |_\ \ (_| | ||  __/\ V  V / (_| | |_| |
    \_| \_|___/    \____/\__,_|\__\___| \_/\_/ \__,_|\__, |
                                                      __/ |
                                                     |___/ 
    Todo
    1. CA Request / LetsEncrypt Install

    
    "Script" Actions
    1. Install RDGW
    2. Configure CAP
    3. Add RRDNS

#>


<#

    This region is used to Install & Configure RDGW Servers

#>


# Import TS Tiering modules.
# ------------------------------------------------------------
Import-Module "C:\TS-Data\ADTiering\TSxTieringModule\TSxTieringModule.psm1" -Force -Verbose


# Default TS Tiering base OU
# ------------------------------------------------------------
$TierSearchBase = (Get-ADOrganizationalUnit -Filter "name -eq 'Admin'").DistinguishedName


# Select Tier0 Destination OU (Will create if missing)
# ------------------------------------------------------------
$T0TargetPath = (Get-ADOrganizationalUnit -Filter * -SearchBase $TierSearchBase | `
    Where {$_.DistinguishedName -like "OU=*OU=Servers,OU=Tier0,$TierSearchBase"}) | `
        Select-Object Name,DistinguishedName | Out-GridView -Title "Select Destination OU" -OutputMode Single

if ($null -eq $T0TargetPath) {
    New-TSxSubOU -Tier T0 -Name "RemoteDesktopBackendServer" -Description "Tier0 RemoteDesktopBackendServers" -TierOUName "Admin" -CompanyName "NA" -SkipLAPS -Cleanup
    $T0TargetPath = Get-ADOrganizationalUnit -Identity "OU=RemoteDesktopBackendServers,OU=Servers,OU=Tier0,$TierSearchBase"
}


# Select Tier1 Destination OU (Will create if missing)
# ------------------------------------------------------------
$T1TargetPath = (Get-ADOrganizationalUnit -Filter * -SearchBase $TierSearchBase | `
    Where {$_.DistinguishedName -like "OU=*OU=Servers,OU=Tier1,$TierSearchBase"}) | `
        Select-Object Name,DistinguishedName | Out-GridView -Title "Select Destination OU" -OutputMode Single

if ($null -eq $T1TargetPath) {
    New-TSxSubOU -Tier T1 -Name "RemoteDesktopBackendServers" -Description "Tier1 RemoteDesktopBackendServers" -TierOUName "Admin" -CompanyName "NA" -SkipLAPS -Cleanup
    $T1TargetPath = Get-ADOrganizationalUnit -Identity "OU=RemoteDesktopBackendServers,OU=Servers,OU=Tier1,$TierSearchBase"
}


# Select Tier 0 Remote Desktop Gateway Servers
# ------------------------------------------------------------
$ServersQuery = Get-ADComputer -filter "OperatingSystem -like '*Server*' -and Name -like '*RDGW*'"
if ($ServersQuery.count -ge 1) {
    $T0RDGWServers = $ServersQuery | Select-Object -Property Name,DNSHostName,DistinguishedName | `
        Out-GridView -Title "Select the Tier 0 - Remote Desktop Gateway Servers" -OutputMode Multiple
} else {
    $T0RDGWServers = $ServersQuery
}


# Select Tier 1 Remote Desktop Gateway Servers
# ------------------------------------------------------------
if ($ServersQuery.count -ge 1) {
    $T1RDGWServers = $ServersQuery | Select-Object -Property Name,DNSHostName,DistinguishedName | `
        Out-GridView -Title "Select the Tier 1 - Remote Desktop Gateway Servers" -OutputMode Multiple
} else {
    $T1RDGWServers = $ServersQuery
}


# Make the Array to easy install all servers at once.
# ------------------------------------------------------------
$RDGWServers = @(    
    $T0RDGWServers | Foreach {
        [PSCustomObject]@{ Name = $($_.name);  TargetPath = $T0TargetPath.DistinguishedName }
    }

    $T1RDGWServers | Foreach {
        [PSCustomObject]@{ Name = $($_.name);  TargetPath = $T1TargetPath.DistinguishedName }
    }
)


# Install and activate required featuers.
# ------------------------------------------------------------
$RDGWServers | Foreach {

    $ServerInfo = Get-ADComputer -Identity $_.name -ErrorAction SilentlyContinue

    If ( ($Null -ne $ServerInfo) -and ($($ServerInfo.DistinguishedName) -NotLike "*$($_.TargetPath)") ) {
        Move-ADObject -Identity $($ServerInfo.DistinguishedName) -TargetPath $_.TargetPath
    }


    # Connect to the server.
    # ------------------------------------------------------------
    $Session = New-PSSession -ComputerName "$($ServerInfo.DNSHostName)"


    # Execute commands.
    # ------------------------------------------------------------
    Invoke-Command -Session $Session -ScriptBlock {


        # Install Remote Desktop Gateway Services
        # ------------------------------------------------------------
        Install-WindowsFeature -Name "RDS-Gateway" -IncludeManagementTools


        # Load module
        # ------------------------------------------------------------
        Import-Module RemoteDesktopServices


        # Create Resource Authorization Policy
        # ------------------------------------------------------------
        if (!(Test-Path -Path "RDS:\GatewayServer\RAP\Remote Desktop Gateway")) {
            New-Item -Path "RDS:\GatewayServer\RAP" -Name "Remote Desktop Gateway" -UserGroups "Domain ConnectionAccounts@$($ENV:UserDomain)" -ComputerGroupType 2 | Out-Null
        }


        # Fix the Warning (RequireMsgAuth and/or limitProxyState configuration is in Disable mode)
        # ------------------------------------------------------------
        netsh nps set limitproxystate all = "enable"
        netsh nps set requiremsgauth all = "enable"


        # Reboot to activate all the changes.
        # ------------------------------------------------------------
        & shutdown -r -t 10

    }
}


# Setup RRDNS
# ------------------------------------------------------------
$T0RDGWServers | Foreach {
    $IpAddress = Resolve-DnsName -Name $_.DNSHostName -Type A
    Add-DnsServerResourceRecordA -Name "RDGWT0" -IPv4Address $IpAddress.IPAddress -ZoneName $($ENV:USERDNSDOMAIN) -ComputerName $((Get-ADDomain).PDCEmulator) -ErrorAction SilentlyContinue
}


$T1RDGWServers | Foreach {
    $IpAddress = Resolve-DnsName -Name $_.DNSHostName -Type A
    Add-DnsServerResourceRecordA -Name "RDGWT1" -IPv4Address $IpAddress.IPAddress -ZoneName $($ENV:USERDNSDOMAIN) -ComputerName $((Get-ADDomain).PDCEmulator) -ErrorAction SilentlyContinue
}


<#
# Verify DNS records.
Resolve-DnsName -Name "RDGWT0.$($ENV:USERDNSDOMAIN)"
Resolve-DnsName -Name "RDGWT1.$($ENV:USERDNSDOMAIN)"
#>


# Request the Certificate
# ------------------------------------------------------------
Write-Warning "Make the Wildcard Certificate request, and install on RDGWs"
