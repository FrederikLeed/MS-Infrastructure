<#
    .DISCLAIMER

    THE SCRIPT IS PROVIDED AS-IS, WITHOUT WARRANTY OF ANY KIND. USE AT YOUR OWN RISK.

    By running this script, you acknowledge that you have read and understood the disclaimer, and you agree to assume
    all responsibility for any failures, damages, or issues that may arise as a result of executing this script.
    
    .DESCRIPTION
    Configure scheduled job to execute the Backup-Dhcp-Server script.

    .PARAMETER Path 
    Specifies where the backup file will be created.
    This can be a local path or a UNC path, but the user running the script must have write permissions to the path.
    
    .EXAMPLE
    .\Add-BackupSchedule.ps1 -BackupPath "\\FileServer\Backup\DHCP" -ScriptPath "C:\LocalScripts"

#>

[CmdletBinding()]
Param(
  [Parameter(ValueFromPipelineByPropertyName=$true,Position=0)][string]$BackupPath,
  [Parameter(ValueFromPipelineByPropertyName=$true,Position=0)][string]$ScriptPath

)


# Verify Script location
# ------------------------------------------------------------
if ($null -eq $ScriptPath) {
    Throw "Missing Script path"
} else {
    if (!(Test-Path -Path $ScriptPath)) {
        New-Item -Path $ScriptPath -ItemType Directory | Out-Null
    }
}


# Verify Backup location
# ------------------------------------------------------------
if ($null -eq $BackupPath) {
    Throw "Missing backup path"
} else {
    if (!(Test-Path -Path $BackupPath)) {
        Throw "Backup Path not found"
    }
}


# Create Backup Script
# ------------------------------------------------------------
$GitUrl = "https://raw.githubusercontent.com/SysAdminDk/Powershell/main/DHCP"
if (!(Test-Path -Path "$ScriptPath\Backup-Dhcp-Server.ps1")) {
    Invoke-WebRequest -Uri "$GitUrl/Backup-Dhcp-Server.ps1" -OutFile "$ScriptPath\Backup-Dhcp-Server.ps1"
}
if (!(Test-Path -Path "$ScriptPath\Restore-Dhcp-Server.ps1")) {
    Invoke-WebRequest -Uri "$GitUrl/Restore-Dhcp-Server.ps1" -OutFile "$ScriptPath\Restore-Dhcp-Server.ps1"
}
#if (!(Test-Path -Path "$ScriptPath\Setup-Dhcp-Server.ps1")) {
#    Invoke-WebRequest -Uri "$GitUrl/Setup-Dhcp-Server.ps1" -OutFile "$ScriptPath\Setup-Dhcp-Server.ps1"
#}


# Create Backup Schedule
# ------------------------------------------------------------
$Scheduletrigger = New-ScheduledTaskTrigger -Daily -At "23:00"
$ScheduleSettings = New-ScheduledTaskSettingsSet -Compatibility Win8
$ScheduleAction = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath\Backup-Dhcp-Server.ps1`" -path $BackupPath"
$SchedulePrincipal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Limited
$ScheduledTask = New-ScheduledTask -Action $ScheduleAction -Trigger $Scheduletrigger -Settings $ScheduleSettings -Principal $SchedulePrincipal
Register-ScheduledTask -TaskName "Backup DHCP service - Daily" -InputObject $ScheduledTask
