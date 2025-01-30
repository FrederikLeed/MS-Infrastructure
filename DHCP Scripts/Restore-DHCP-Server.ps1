<#
    .DISCLAIMER

    THE SCRIPT IS PROVIDED AS-IS, WITHOUT WARRANTY OF ANY KIND. USE AT YOUR OWN RISK.

    By running this script, you acknowledge that you have read and understood the disclaimer, and you agree to assume
    all responsibility for any failures, damages, or issues that may arise as a result of executing this script.

    .DESCRIPTION
    Install, Authorize and Restore DHCP Services.    



    .PARAMETER BackupPath 
    Specifies where the backup file is stored.
    This can be a local path or a UNC path
    - The user running the script must have read permissions to the path.
    
    .PARAMETER ScriptPath 
    Specifies where the required scripts will be downloaded to and executed from.
    
    .EXAMPLE
    .\Restore-DHCP-Server.ps1 -BackupPath "\\FileServer\Backup\DHCP" -ScriptPath "C:\LocalScripts"


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


# Download DHCP Scripts
# ------------------------------------------------------------
$GitUrl = "https://raw.githubusercontent.com/SysAdminDk/Powershell/main/DHCP"
$Files = @("Backup-DHCP-Sopes.ps1","Restore-DHCP-Sopes.ps1","Add-DHCP-BackupSchedule.ps1","Install-DHCP-Server.ps1","Add-DHCP-Failover.ps1","Restore-DHCP-Server.ps1")

$Files | Foreach {
    if (!(Test-Path -Path "$ScriptPath\$($_)")) {
        Invoke-WebRequest -Uri "$GitUrl/$($_)" -OutFile "$ScriptPath\$($_)"
    }
}


# Install DHCP server
# ------------------------------------------------------------
Invoke-Expression "$ScriptPath\Install-DHCP-Server.ps1 -ScriptPath `"$ScriptPath`""


# Restore DHCP server
# ------------------------------------------------------------
Invoke-Expression "$ScriptPath\Restore-DHCP-Scopes.ps1 -BackupPath `"$BackupPath`""

