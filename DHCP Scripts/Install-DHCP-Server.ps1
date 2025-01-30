<#
    .DISCLAIMER

    THE SCRIPT IS PROVIDED AS-IS, WITHOUT WARRANTY OF ANY KIND. USE AT YOUR OWN RISK.

    By running this script, you acknowledge that you have read and understood the disclaimer, and you agree to assume
    all responsibility for any failures, damages, or issues that may arise as a result of executing this script.

    .DESCRIPTION
    Install and Authorize DHCP Services.


    .PARAMETER ScriptPath 
    Specifies where the DHCP script will be located.
    
    .EXAMPLE
    .\Install-DHCP-Server.ps1 -ScriptPath "C:\TS-Data"

#>
[CmdletBinding()]
Param(
  [Parameter(ValueFromPipelineByPropertyName=$true,Position=0,mandatory=$true)]
  [ValidatePattern("^\w:\\\S+$")]
  [string]$ScriptPath
)


<# ----- #>

# Verify Domain Membership.
# ------------------------------------------------------------
try {
    $DomainName = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
}
Catch {
    Throw "Computer not a member of any domain"
    Break
}


# Restart the script as Admin, if needed.
# ------------------------------------------------------------
$CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
If (!($CurrentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {

    Write-Warning "Not running as Administrator, restarting script"

    $ScriptHost = If ($PSVersionTable.PSVersion.Major -le 5) {'PowerShell'} Else {'PwSh'}
    $ScriptFile = $($MyInvocation.MyCommand.Path)
    $ScriptArguments = ($PSCmdlet.MyInvocation.BoundParameters.GetEnumerator() | ForEach-Object { "-$($_.Key) $($_.Value)" }) -Join(" ")
    
    Start-Process $ScriptHost -ArgumentList " -ExecutionPolicy Bypass -File `"$ScriptFile`" $ScriptArguments" -Verb RunAs

    for($i=0; $i -le 5; $i++) {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 1
    }
    break
}


# Verify the user have Permissions, if not Ask for credentials.
# ------------------------------------------------------------
$CurrentGroups = @()
[System.Security.Principal.WindowsIdentity]::GetCurrent().Groups | ForEach-Object -Process {
    $CurrentGroups += $_.Translate([System.Security.Principal.NTAccount]).Value;
}
If ($CurrentGroups -NotContains "PROD\Domain Admins") {
    $Credentials = $(Get-Credential -Message "BreakGlass Admin Credentials")
}


<# ----- #>


# Install Required Features
# ------------------------------------------------------------
Install-WindowsFeature -name DHCP -IncludeManagementTools


# Verify Script location is on C:\
# ------------------------------------------------------------
if (!(Test-Path -Path $ScriptPath)) {
    New-Item -Path $ScriptPath -ItemType Directory | Out-Null
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


# Authorize new DHCP server
# ------------------------------------------------------------
Try {
    if ($null -eq $Credentials) {
        Add-DHCPServerInDC
    } else {
        Invoke-Command -ScriptBlock {
            Add-DHCPServerInDC
        } -Credential $Credentials
    }
} catch {
    Write-Output $_
}


# Setup Backup Schedule.
# ------------------------------------------------------------
Invoke-Expression "$ScriptPath\Add-BackupSchedule.ps1 -BackupPath `"$BackupPath`""
