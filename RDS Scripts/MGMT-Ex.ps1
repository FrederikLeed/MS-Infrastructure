<#
    ___  ___                                                  _     _____                              
    |  \/  |                                                 | |   /  ___|                             
    | .  . | __ _ _ __   __ _  __ _  ___ _ __ ___   ___ _ __ | |_  \ `--.  ___ _ ____   _____ _ __ ___ 
    | |\/| |/ _` | '_ \ / _` |/ _` |/ _ \ '_ ` _ \ / _ \ '_ \| __|  `--. \/ _ \ '__\ \ / / _ \ '__/ __|
    | |  | | (_| | | | | (_| | (_| |  __/ | | | | |  __/ | | | |_  /\__/ /  __/ |   \ V /  __/ |  \__ \
    \_|  |_/\__,_|_| |_|\__,_|\__, |\___|_| |_| |_|\___|_| |_|\__| \____/ \___|_|    \_/ \___|_|  |___/
                               __/ |                                                                   
                              |___/                                                                    
#>

<#

    Install & Configure Tier Endpoint Management Servers

    This asumes the servers are using MGMT in the name, if not please update the query in line 37.

#>

# Location of install files required for Management Servers
# - All files are Downloaded with requirement script !
# ------------------------------------------------------------
$TxScriptPath = "C:\TS-Data\Download"


# Select OU for Tier0 Jump servers.
# ------------------------------------------------------------
$TargetPath = Get-ADOrganizationalUnit -Filter "name -like '*jump*'" | Where { $_.DistinguishedName -like '*tierendpoints*' }
if ($TargetPath.count -ge 1) {
    $TargetSelection = $TargetPath | Select-Object DistinguishedName | Out-GridView -Title "Select the Tier Endpoint JumpStations OU" -OutputMode Single
    $TargetPath = Get-ADOrganizationalUnit -Identity $TargetSelection.DistinguishedName
}


# Select management servers for Tier Endpoint
# ------------------------------------------------------------
$ServersQuery = Get-ADComputer -filter "OperatingSystem -like '*Server*' -and Name -like '*MGMT*'"
if ($ServersQuery.count -ge 1) {
    $SelectedServers = $ServersQuery | Select-Object -Property Name,DNSHostName,DistinguishedName | `
        Out-GridView -Title "Select the Tier Endpoint Jump / Management Servers" -OutputMode Multiple
} else {
    $SelectedServers = $ServersQuery
}


# Install & Configure Tier Endpoint management server(s)
# ------------------------------------------------------------
$($SelectedServers).Name | Get-ADComputer -ErrorAction SilentlyContinue | Foreach {

    If ( ($Null -ne $TargetPath) -and ($($_.DistinguishedName) -NotLike "*$($TargetPath.DistinguishedName)") ) {
        Move-ADObject -Identity $($_.DistinguishedName) -TargetPath $TargetPath.DistinguishedName
    }


    # Connect to the server.
    # ------------------------------------------------------------
    $Session = New-PSSession -ComputerName "$($_.DNSHostName)"


    # Execute commands.
    # ------------------------------------------------------------
    Invoke-Command -Session $Session -ScriptBlock {


        # Install RSAT tools (Will be moved to GPO install)
        # ------------------------------------------------------------
        $ToolsToInstall = @(
	        "RSAT-*",
            "GPMC"
	        )
        Get-WindowsFeature -Name $ToolsToInstall | Where {$_.InstallState -eq "Available"} | Install-WindowsFeature -Verbose -ErrorAction SilentlyContinue
        

        # Force a GPO update
        # ------------------------------------------------------------
        & Gpupdate /force
        & Gpupdate /force


        # Reboot to activate all changes.
        # ------------------------------------------------------------
        & shutdown -r -t 10
    }
}
