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
    .\Setup-Dhcp-Server.ps1 -BackupPath "\\FileServer\Backup\DHCP" -ScriptPath "C:\LocalScripts"

#>

[CmdletBinding()]
Param(
  [Parameter(ValueFromPipelineByPropertyName=$true,Position=0,mandatory=$true)]
  [ValidatePattern("^\\\\\S+$")]
  [string]$BackupPath,
  [Parameter(ValueFromPipelineByPropertyName=$true,Position=0,mandatory=$true)]
  [ValidatePattern("^\w:\\\S+$")]
  [string]$ScriptPath
)


# Need to be able to execute the Restore script
# ------------------------------------------------------------
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force


# Verify Script location is on C:\
# ------------------------------------------------------------
if (!(Test-Path -Path $ScriptPath)) {
    New-Item -Path $ScriptPath -ItemType Directory | Out-Null
}


# Verify Backup location
# ------------------------------------------------------------
if (!(Test-Path -Path $BackupPath)) {
    Throw "Backup Path not found"
} else {
    $AllowedPermissions = @("FullControl","Modify","Write")

    $ACL = Get-ACL -Path $BackupPath
    $ACLAccess = $ACL.Access | Where { $_.IdentityReference -eq "$($ENV:UserDomain)\$($env:COMPUTERNAME)$" }
    if ($AllowedPermissions -NotContains $(($ACLAccess.FileSystemRights -split(","))[0])) {
        Throw "Missing permissions on Network Share"
    }
}


<# -- T o D o -- #>
# Verify the user have Permissions, if not Ask for credentials.
# ------------------------------------------------------------
if ($UserDomain.ToLower() -eq $($env:COMPUTERNAME).ToLower()) {
    Throw "Running as Local User, unable to add DHCP server to the domain"
}

#$CurrentUser = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name).ToLower()
#$UserDomain = $($ENV:USERDOMAIN).ToLower()

$CurrentGroups = @()
[System.Security.Principal.WindowsIdentity]::GetCurrent().Groups | ForEach-Object -Process {
    $CurrentGroups += $_.Translate([System.Security.Principal.NTAccount]).Value;
}
if ($CurrentGroups -NotContains "PROD\Domain Admins") {
    Throw "Missing Domain Permissions, unable to add DHCP server to the domain"
}

if ($WeHavePermissions -ne "") {
    $Credentials = Get-Credential -Message "Enter Domain Admin Credentials"
}

<# -- T o D o -- #>


# Install Required Features
# ------------------------------------------------------------
Install-WindowsFeature -name DHCP -IncludeManagementTools


# Download DHCP Scripts
# ------------------------------------------------------------
$GitUrl = "https://raw.githubusercontent.com/SysAdminDk/Powershell/main/DHCP"
if (!(Test-Path -Path "$ScriptPath\Backup-Dhcp-Server.ps1")) {
    Invoke-WebRequest -Uri "$GitUrl/Backup-Dhcp-Server.ps1" -OutFile "$ScriptPath\Backup-Dhcp-Server.ps1"
}
if (!(Test-Path -Path "$ScriptPath\Restore-Dhcp-Server.ps1")) {
    Invoke-WebRequest -Uri "$GitUrl/Restore-Dhcp-Server.ps1" -OutFile "$ScriptPath\Restore-Dhcp-Server.ps1"
}
if (!(Test-Path -Path "$ScriptPath\Add-BackupSchedule.ps1")) {
    Invoke-WebRequest -Uri "$GitUrl/Add-BackupSchedule.ps1" -OutFile "$ScriptPath\Add-BackupSchedule.ps1"
}


# Restore DHCP server
# ------------------------------------------------------------
Invoke-Expression "$ScriptPath\Restore-Dhcp-Server.ps1 -BackupPath `"$BackupPath`""


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


# Setup Backup Schedule.
# ------------------------------------------------------------
Invoke-Expression "$ScriptPath\Add-BackupSchedule.ps1 -BackupPath `"$BackupPath`""


# Restart
# ------------------------------------------------------------
Shutdown -t -t 0
