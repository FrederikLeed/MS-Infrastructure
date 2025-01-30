#Requires -RunAsAdministrator
<#
    .DISCLAIMER

    THE SCRIPT IS PROVIDED AS-IS, WITHOUT WARRANTY OF ANY KIND. USE AT YOUR OWN RISK.

    By running this script, you acknowledge that you have read and understood the disclaimer, and you agree to assume
    all responsibility for any failures, damages, or issues that may arise as a result of executing this script.
    
    .DESCRIPTION
    Configure scheduled job to execute the Backup-Dhcp-Server script.

    .PARAMETER BackupPath 
    Specifies where the backup file will be created.
    This can be a local path or a UNC path
    - The user running the script must have write permissions to the path.
    - The DHCP Server account in AD needs write permissions to the path.
    
    .PARAMETER ScriptPath 
    Specifies where the required scripts will be downloaded to and executed from.

    .EXAMPLE
    .\Add-BackupSchedule.ps1 -BackupPath "\\FileServer\Backup\DHCP" -ScriptPath "C:\LocalScripts"

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



# Verify Script location
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


# Download DHCP Scripts
# ------------------------------------------------------------
$GitUrl = "https://raw.githubusercontent.com/SysAdminDk/Powershell/main/DHCP"
$Files = @("Backup-DHCP-Sopes.ps1","Restore-DHCP-Sopes.ps1","Add-DHCP-BackupSchedule.ps1","Install-DHCP-Server.ps1","Add-DHCP-Failover.ps1","Restore-DHCP-Server.ps1")

$Files | Foreach {
    if (!(Test-Path -Path "$ScriptPath\$($_)")) {
        Invoke-WebRequest -Uri "$GitUrl/$($_)" -OutFile "$ScriptPath\$($_)"
    }
}


# Create Backup Schedule
# ------------------------------------------------------------
$Scheduletrigger = New-ScheduledTaskTrigger -Daily -At "23:00"
$ScheduleSettings = New-ScheduledTaskSettingsSet -Compatibility Win8
$ScheduleAction = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath\Backup-DHCP-Sopes.ps1`" -BackupPath $BackupPath"
$SchedulePrincipal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Limited
$ScheduledTask = New-ScheduledTask -Action $ScheduleAction -Trigger $Scheduletrigger -Settings $ScheduleSettings -Principal $SchedulePrincipal
Register-ScheduledTask -TaskName "Backup DHCP service - Daily" -InputObject $ScheduledTask
