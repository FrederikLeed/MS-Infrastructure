<#

    Create GPO to disable Print Spooler on servers.
    - Will link to Domain Controllers !

#>

# Set PDC as deault server
# ------------------------------------------------------------
$PSDefaultParameterValues = @{
    "*AD*:Server" = $(Get-ADDomain).PDCEmulator
}


# Create GPO to mitigate the print spooler issue, and assign to Domain Controllers
# - The same policy can be assigned to any server that is NOT used as a print server
# ------------------------------------------------------------
$TargetGPOname = "Admin - Disable Print Spooler"
if (!(Get-GPO -Name $TargetGPOname -ErrorAction SilentlyContinue)) {

    New-GPO -Name $TargetGPOname -Server $DefaultServer | Out-Null

    Set-GPRegistryValue -Name $TargetGPOname -Key "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint" -ValueName "Restricted" -Value 1 -Type DWord | Out-Null
    Set-GPRegistryValue -Name $TargetGPOname -Key "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint" -ValueName "TrustedServers" -Value 0 -Type DWord | Out-Null
    Set-GPRegistryValue -Name $TargetGPOname -Key "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint" -ValueName "ServerList" -Value "" -Type String | Out-Null
    Set-GPRegistryValue -Name $TargetGPOname -Key "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint" -ValueName "InForest" -Value 0 -Type DWord | Out-Null
    Set-GPRegistryValue -Name $TargetGPOname -Key "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint" -ValueName "NoWarningNoElevationOnInstall" -Value 0 -Type DWord | Out-Null
    Set-GPRegistryValue -Name $TargetGPOname -Key "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint" -ValueName "UpdatePromptSettings" -Value 0 -Type DWord | Out-Null

    Set-GPRegistryValue -Name $TargetGPOname -Key "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\Printers" -ValueName "RegisterSpoolerRemoteRpcEndPoint" -Value 2 -Type DWord | Out-Null

    Get-GPO -Name $TargetGPOname | New-GPLink -Target $(Get-ADDomain).DomainControllersContainer | Out-Null
    (Get-GPO -Name $TargetGPOname).GpoStatus = "UserSettingsDisabled"
}
