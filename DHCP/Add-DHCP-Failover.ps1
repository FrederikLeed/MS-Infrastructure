#Requires -RunAsAdministrator
<#
    .DISCLAIMER

    THE SCRIPT IS PROVIDED AS-IS, WITHOUT WARRANTY OF ANY KIND. USE AT YOUR OWN RISK.

    By running this script, you acknowledge that you have read and understood the disclaimer, and you agree to assume
    all responsibility for any failures, damages, or issues that may arise as a result of executing this script.

    .DESCRIPTION
    Install required features for DHCP services and Restore scopes and leases, from latest backup file found on the supplied Path

    .PARAMETER Path 
    Specifies where the backup file will be retrieved.
    This can be a local path or a UNC path.
    
    .EXAMPLE
    .\Add-DHCP-Failover.ps1 -PartnerServer DHCP-01.$($ENV:UserDNSDomain)

#>
[CmdletBinding()]
Param(
  [Parameter(ValueFromPipelineByPropertyName=$true,Position=0,mandatory=$true)]
  [string]$PartnerServer="DHCP-01.$($ENV:UserDNSDomain)"
)


<# -- T o D o -- #>

# Verify the user have Permissions, if not Ask for credentials.
# ------------------------------------------------------------




$Credentials = $(Get-Credential -Message "BreakGlass Admin Credentials")
<# -- T o D o -- #>



# Install Required Features
# ------------------------------------------------------------
Install-WindowsFeature -name DHCP -IncludeManagementTools


# Authorize new DHCP server
# - Please make sure your account have the correct permissions to do this.
# ------------------------------------------------------------
$DomainControllers = ((nslookup -type=SRV _ldap._tcp.dc._msdcs.$($ENV:UserDNSDomain). | Where {$_ -like '*hostname*'}) -split(" ")) | Where {$_ -like "*$($ENV:UserDNSDomain)"}
$DomainController = Get-Random -InputObject $DomainControllers


Try {
    if ($null -eq $Credentials) {
        Invoke-Command -ComputerName $DomainController -ScriptBlock {
            Add-DHCPServerInDC
        }
    } else {
        Invoke-Command -ComputerName $DomainController -ScriptBlock {
            Add-DHCPServerInDC
        } -Credential $Credentials
    }
} catch {
    Write-Output $_
}



# Add to DHCP scope Failower..
# ------------------------------------------------------------
$DHCPSharedSecret = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 35 | ForEach-Object {[char]$_})
$DHCPScopes = Get-DhcpServerv4Scope -ComputerName $PartnerServer
Add-DhcpServerv4Failover -ComputerName $PartnerServer -Name "DHCP-Failover" -PartnerServer "$($env:COMPUTERNAME).$($ENV:UserDNSDomain)" -ScopeId $DHCPScopes.ScopeId -SharedSecret $DHCPSharedSecret -Force


# Restart
# ------------------------------------------------------------
Shutdown -t -t 0
