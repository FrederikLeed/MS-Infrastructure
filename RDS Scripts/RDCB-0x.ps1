<#

 Configure Remote Desktop Connection Broker.


 Before you can run this, the Remote Desktop Connection Broker Database servers have to be ready !

#>


# Create RR-DNS for for the RDCB servers.
# ------------------------------------------------------------
$RDCBServers = ($($ServerInfo | Where {$_.Role -eq "RDCB"}).Name | Get-ADComputer -ErrorAction SilentlyContinue)
#$RDCBServers = Get-ADComputer -Filter "Name -like '*RDCB*'" | Sort-Object -Property Name
($RDCBServers).Name | `
 Resolve-DnsName | % {
  Add-DnsServerResourceRecordA -Name "RDCB" -ZoneName $($ENV:UserDNSDomain) -IPv4Address $_.IPAddress -ComputerName $(Get-ADDomain).PDCEmulator
 }


# Create Connection Broker AD Group.
# --
New-ADGroup -Name "RDCB - Servers" -Description "Access to RDDB SQL Database" -GroupScope Global -GroupCategory Security -Path "OU=Groups,OU=Tier1,$TierSearchBase"
Add-ADGroupMember -Identity $(Get-ADGroup -Identity "RDCB - Servers") -Members $RDCBServers



# Get SQL Client




# Select Destination OU
# ------------------------------------------------------------
$TargetPath = (Get-ADOrganizationalUnit -Filter * -SearchBase $TierSearchBase | `
 Where {$_.DistinguishedName -like "OU=*OU=Servers,OU=Tier1,$TierSearchBase"}) | `
  Select-Object Name,DistinguishedName | Out-GridView -Title "Select Destination OU" -OutputMode Single


# Install & Configure 
# ------------------------------------------------------------
$RDCBServers | Foreach {
#Enter-PSSession -ComputerName $RDCBServers[0].DNSHostName

    If ( ($Null -ne $TargetPath) -and ($($_.DistinguishedName) -NotLike "*OU=Servers,OU=Tier1*") ) {
        Move-ADObject -Identity $($_.DistinguishedName) -TargetPath $TargetPath.DistinguishedName
    }


    # Connect to the server.
    # ------------------------------------------------------------
    $Session = New-PSSession -ComputerName "$($_.DNSHostName)"


    # Copy required installers to target server
    # ------------------------------------------------------------
    @(
        "AzureConnectedMachineAgent.msi",
        "VC_redist.x64.exe", # Important
        "msodbcsql-18.msi"   # Important

    ) | Foreach {
        #  Get-ChildItem -Path $TxScriptPath -Filter $_ -Recurse | Copy-Item -Destination "$($ENV:PUBLIC)\downloads\$_" -ToSession $Session -Force
    }


    Invoke-Command -Session $Session -ScriptBlock {

        # Install Azure Arc Agent
        # ------------------------------------------------------------
        if (Test-Path -Path "$($ENV:PUBLIC)\downloads\AzureConnectedMachineAgent.msi") {
            #Start-Process -FilePath "$($ENV:PUBLIC)\downloads\AzureConnectedMachineAgent.msi" -ArgumentList "/quiet /qn /norestart" -wait
        }

        # Install Required Features.
        Install-WindowsFeature -Name RDS-Connection-Broker -IncludeManagementTools

    }
}



# Install RDWEB on both Gateway Servers.
# ------------------------------------------------------------
$RDGWServers = ($($ServerInfo | Where {$_.Role -eq "RDGW"}).Name | Get-ADComputer -ErrorAction SilentlyContinue)
#$RDGWServers = Get-ADComputer -Filter "Name -like '*RDGW*'" | Sort-Object -Property Name
$RDGWServers[0] | Foreach {
 
    $Session = New-PSSession -ComputerName "$($_.DNSHostName)"

    Invoke-Command -Session $Session -ScriptBlock {
        Install-WindowsFeature -Name RDS-Web-Access -IncludeManagementTools

        $Certificate = $(Get-ChildItem Cert:\LocalMachine\My | Where {$_.Subject -like "*.prod.sysadmins.dk" -and $_.Issuer -like "*Encrypt*" } | Sort-Object -Property NotAfter)[-1]
        Export-Certificate -Type CERT -FilePath "$($ENV:PUBLIC)\downloads\rdgw.cer" -Cert "Cert:\LocalMachine\My\$($Certificate.Thumbprint)"

    }

    # Test if this can be used for Remote Desktop !!
    Copy-Item -Path "$($ENV:PUBLIC)\downloads\rdgw.cer" -Destination "$($ENV:PUBLIC)\downloads" -FromSession $Session

}


# Get ALL mangement servers and add as Session Hosts.
# ------------------------------------------------------------
$RDSessionHosts = ($($ServerInfo | Where {$_.Role -eq "MGMT"}).Name | Get-ADComputer -ErrorAction SilentlyContinue) | Where {$_.Name -ne $env:COMPUTERNAME}
$RDSessionHosts = Get-ADComputer -Filter "Name -like '*MGMT*'" | Sort-Object -Property Name
#$RDSessionHosts = $RDSessionHosts | Where {$_.Name -ne $env:COMPUTERNAME}
#$RDSessionHosts = $RDSessionHosts | Where {$_.name -NotLike '*-E*'}
$RDSessionHosts.DNSHostName


# Import required module
# ------------------------------------------------------------
Import-Module remotedesktop -Force
Import-Module RemoteDesktopServices -Force


# Setup New Remote Desktop Session Deployment
# ------------------------------------------------------------
New-RDSessionDeployment -ConnectionBroker $RDCBServers[0].DNSHostName -WebAccessServer $RDGWServers[0].DNSHostName -SessionHost $RDSessionHosts.DNSHostName


# Update Connection string (IF High Avail DB is ready)
# ------------------------------------------------------------
if ((Test-NetConnection -ComputerName RDDB.$ENV:USERDNSDOMAIN -Port 1433 -ErrorAction SilentlyContinue).TcpTestSucceeded)  {
    $DBDriver = "DRIVER={ODBC Driver 18 for SQL Server}"
    $DBServer = "SERVER=RDDB.Prod.SysAdmins.dk"
    $DBName = "DATABASE=RDConnectionBroker"
    $DatabaseConnectionString = "$DBDriver;$DBServer;$DBName;APP=Remote Desktop Services Connection Broker;Trusted_Connection=Yes;Encrypt=optional;TrustServerCertificate=yes"
    Set-RDConnectionBrokerHighAvailability -ConnectionBroker $RDCBServers[0].DNSHostName -DatabaseConnectionString $DatabaseConnectionString -ClientAccessName RDCB.Prod.SysAdmins.Dk
}

# Add session broker.
# ------------------------------------------------------------
Add-RDServer -Server $RDCBServers[1].DNSHostName -Role RDS-CONNECTION-BROKER -ConnectionBroker $RDCBServers[0].DNSHostName

# Add RD License server
# ------------------------------------------------------------
Add-RDServer -Server "RDLI-01.Prod.SysAdmins.Dk" -Role RDS-LICENSING -ConnectionBroker $RDCBServers[0].DNSHostName


# Add Remote Desktop Gateway Servers.
# ------------------------------------------------------------
# 1. Change to Local Policy Store
# 2. Add the GW servers
# 3. Change to MFA policy store..
foreach ($RDGWServer in $RDGWServers) {
    Invoke-Command -ComputerName $RDGWServer.DNSHostName -ScriptBlock {

        Import-Module RemoteDesktopServices
        If ((Get-Item -Path "RDS:\GatewayServer\CentralCAPEnabled").CurrentValue -eq "1") {
            Set-Item -Path "RDS:\GatewayServer\CentralCAPEnabled" -Value 0
        }
    }

    Add-RDServer -Server $RDGWServer.DNSHostName -Role RDS-GATEWAY -ConnectionBroker $RDCBServers[0].DNSHostName -GatewayExternalFqdn "Tx-RDGW.prod.sysadmins.dk"


    Invoke-Command -ComputerName $RDGWServer.DNSHostName -ScriptBlock {

        Import-Module RemoteDesktopServices
        If ((Get-Item -Path "RDS:\GatewayServer\CentralCAPEnabled").CurrentValue -eq "0") {
            Set-Item -Path "RDS:\GatewayServer\CentralCAPEnabled" -Value 1
        }
        Get-ChildItem -Path "RDS:\GatewayServer\RAP" | Where {$_.Name -ne "Remote Desktop Gateway - MFA"} | Foreach {
        
            Remove-Item -Path "RDS:\GatewayServer\RAP\$($_.Name)\UserGroups\Domain Users@PROD" -ErrorAction SilentlyContinue
            New-Item -Path "RDS:\GatewayServer\RAP\$($_.Name)\UserGroups" -Name "Domain ConnectionAccounts@PROD" | Out-Null

        }
    }
}


# Add RD Web access server
# ------------------------------------------------------------
Add-RDServer -Server $RDGWServers[1].DNSHostName -Role RDS-WEB-ACCESS -ConnectionBroker $RDCBServers[0].DNSHostName


# 4. Change Certificate
$PFXPass = ConvertTo-SecureString -String "xHhhrhmTR1aBlNdq3djV6GVTGUJqj2vJEjrhgQlpDXc=" -AsPlainText -Force
##@("RDGateway","RDPublishing","RDRedirector","RDWebAccess") | % {Set-RDCertificate -Role $_ -ConnectionBroker $RDCBServers[0].DNSHostName -ImportPath "C:\TS-Data\TA1hr8Ec6Uuoh99hGuaqQg-main-0855addc747d724a8e96107a6f2e5ff5a045061f-temp.pfx" -Password $PFXPass -force -Verbose }
#Set-RDCertificate -Role RDPublishing -ConnectionBroker $RDCBServers[0].DNSHostName -ImportPath "C:\TS-Data\TA1hr8Ec6Uuoh99hGuaqQg-main-0855addc747d724a8e96107a6f2e5ff5a045061f-temp.pfx" -Password $PFXPass -force
#Set-RDCertificate -Role RDRedirector -ConnectionBroker $RDCBServers[0].DNSHostName -ImportPath "C:\TS-Data\TA1hr8Ec6Uuoh99hGuaqQg-main-0855addc747d724a8e96107a6f2e5ff5a045061f-temp.pfx" -Password $PFXPass -force
Set-RDCertificate -Role RDGateway -ConnectionBroker $RDCBServers[0].DNSHostName -ImportPath "C:\TS-Data\TA1hr8Ec6Uuoh99hGuaqQg-main-0855addc747d724a8e96107a6f2e5ff5a045061f-temp.pfx" -Password $PFXPass -force


# Create collections
# Add DNS ??
$Tier2Servers = $($RDSessionHosts | Where {$_.DNSHostName -like "MGMT-2*"})
New-RDSessionCollection -CollectionName Tier2 -SessionHost $Tier2Servers.DNSHostName -ConnectionBroker $RDCBServers[0].DNSHostName
($Tier2Servers).Name | `
    Resolve-DnsName -Type A | % {
        Add-DnsServerResourceRecordA -Name "T2-MGMT" -ZoneName $($ENV:UserDNSDomain) -IPv4Address $_.IPAddress -ComputerName $(Get-ADDomain).PDCEmulator
    }


$Tier1Servers = $($RDSessionHosts | Where {$_.DNSHostName -like "MGMT-1*"})
New-RDSessionCollection -CollectionName Tier1 -SessionHost $Tier1Servers.DNSHostName -ConnectionBroker $RDCBServers[0].DNSHostName
($Tier1Servers).Name | `
    Resolve-DnsName -Type A | % {
        Add-DnsServerResourceRecordA -Name "T1-MGMT" -ZoneName $($ENV:UserDNSDomain) -IPv4Address $_.IPAddress -ComputerName $(Get-ADDomain).PDCEmulator
    }



$Tier0Servers = $($RDSessionHosts | Where {$_.DNSHostName -like "MGMT-0*"})
New-RDSessionCollection -CollectionName Tier0 -SessionHost $Tier0Servers.DNSHostName -ConnectionBroker $RDCBServers[0].DNSHostName
($Tier0Servers).Name | `
    Resolve-DnsName -Type A | % {
        Add-DnsServerResourceRecordA -Name "T0-MGMT" -ZoneName $($ENV:UserDNSDomain) -IPv4Address $_.IPAddress -ComputerName $(Get-ADDomain).PDCEmulator
    }



# Set who..
Get-RDSessionCollectionConfiguration -ConnectionBroker $RDCBServers[0].DNSHostName -CollectionName Tier2 | fl *
Set-RDSessionCollectionConfiguration -CollectionName Tier2 -UserGroup @("PROD\Domain Tier2 Jumpstation Admins", "PROD\Domain Tier2 Jumpstation remote desktop users") -AuthenticateUsingNLA $false -ConnectionBroker $RDCBServers[0].DNSHostName
Set-RDSessionCollectionConfiguration -CollectionName Tier1 -UserGroup @("PROD\Domain Tier1 Jumpstation Admins", "PROD\Domain Tier1 Jumpstation remote desktop users") -AuthenticateUsingNLA $false -ConnectionBroker $RDCBServers[0].DNSHostName
Set-RDSessionCollectionConfiguration -CollectionName Tier0 -UserGroup @("PROD\Domain Admins") -AuthenticateUsingNLA $false -ConnectionBroker $RDCBServers[0].DNSHostName


# Add Tier0 session host (Only if NOT on that server)
# --
$T0SessionHost = Get-ADComputer -Filter "Name -like 'MGMT-01'" | Where {$_.Name -ne $env:COMPUTERNAME}
if ($null -ne $T0SessionHost) {
    Add-RDServer -Server $T0SessionHost.DNSHostName -Role RDS-RD-SERVER -ConnectionBroker $RDCBServers[0].DNSHostName
    Add-RDSessionHost -CollectionName Tier0 -SessionHost $T0SessionHost.DNSHostName -ConnectionBroker $RDCBServers[0].DNSHostName
}


# Result...
Get-RDServer -ConnectionBroker $RDCBServers[0].DNSHostName | Sort-Object -Property Roles
Get-RDSessionCollection -ConnectionBroker $RDCBServers[0].DNSHostName | Foreach {
    $CollectionData = @()
    $CollectionData += Get-RDSessionCollectionConfiguration -CollectionName $($_.CollectionName) -ConnectionBroker $RDCBServers[0].DNSHostName -UserGroup
#   $CollectionData += Get-RDSessionCollectionConfiguration -CollectionName $($_.CollectionName) -ConnectionBroker $RDCBServers[0].DNSHostName -Connection
    $CollectionData += Get-RDSessionCollectionConfiguration -CollectionName $($_.CollectionName) -ConnectionBroker $RDCBServers[0].DNSHostName -Security

    Write-Host ""
    Write-Host "Remote Desktop Session Collection - $($_.CollectionName)"
    Write-Host "--------------------------------------------------------------------------------"
    Write-Host "UserGroups                   : $($CollectionData.UserGroup)"
    Write-Host "AuthenticateUsingNLA         : $($CollectionData.AuthenticateUsingNLA)"
    Write-Host "--------------------------------------------------------------------------------"

#    $CollectionData | fl
}
