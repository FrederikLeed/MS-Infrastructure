#Requires -RunAsAdministrator
<#
    ______                      _         _____             _             _ _               
    |  _  \                    (_)       /  __ \           | |           | | |              
    | | | |___  _ __ ___   __ _ _ _ __   | /  \/ ___  _ __ | |_ _ __ ___ | | | ___ _ __ ___ 
    | | | / _ \| '_ ` _ \ / _` | | '_ \  | |    / _ \| '_ \| __| '__/ _ \| | |/ _ \ '__/ __|
    | |/ / (_) | | | | | | (_| | | | | | | \__/\ (_) | | | | |_| | | (_) | | |  __/ |  \__ \
    |___/ \___/|_| |_| |_|\__,_|_|_| |_|  \____/\___/|_| |_|\__|_|  \___/|_|_|\___|_|  |___/


    .DISCLAIMER

    THE SCRIPT IS PROVIDED AS-IS, WITHOUT WARRANTY OF ANY KIND. USE AT YOUR OWN RISK.

    By running this script, you acknowledge that you have read and understood the disclaimer, and you agree to assume
    all responsibility for any failures, damages, or issues that may arise as a result of executing this script.

    .DESCRIPTION
    "Script" Actions.
    1. Promote domain controller(s)
    2. Move NTDS database to D:\
    3. Configure Windows Backup on PDC
    4. Move FMSO
    5. 

    .PARAMETER Servers
    
    
    .EXAMPLE
    .\ADD-DomainController.ps1 -Server 

#>

[CmdletBinding()]
Param(
  [Parameter(ValueFromPipelineByPropertyName=$true,Position=0,mandatory=$true)]
  [string]$Servers
)



#region ADDS
<#

    Get the list of new Domain Controllers and install Active Directory Domain Services on them.

#>


# Install & Configure Domain Controllers.
# ------------------------------------------------------------
$($ServerInfo | Where {$_.Role -eq "DC"}).Name | Get-ADComputer -ErrorAction SilentlyContinue | Foreach {
    $ServerName = $_.Name
    $ServerDNSHostName = $_.DNSHostName

    # Ensure the selected server isnt already a Domain Controller
    # ------------------------------------------------------------
    Try {
        $null = Get-ADDomainController -Identity $ServerName
        Write-Output "$ServerName, The server is already Domain Controller"
    }
    Catch {
        Write-Host "Install Active Directory on $ServerName"


        # Connect to the server.
        # ------------------------------------------------------------
        $Session = New-PSSession -ComputerName $ServerDNSHostName


        # Copy required installers to target server
        # ------------------------------------------------------------
        $FilesToCopy = @(
            "AzureConnectedMachineAgent.msi",
            "AzureADPasswordProtectionDCAgentSetup.msi"
        )

        $FilesToCopy | Foreach {
            Get-ChildItem -Path $TxScriptPath -Filter $_ -Recurse | Copy-Item -Destination "$($ENV:PUBLIC)\downloads\$_" -ToSession $Session -Force
        }


        # Execute commands.
        # ------------------------------------------------------------
        Invoke-Command -Session $Session -ScriptBlock {


            # Install Azure Arc Agent
            # ------------------------------------------------------------
            if (Test-Path -Path "$($ENV:PUBLIC)\downloads\AzureConnectedMachineAgent.msi") {
                Start-Process -FilePath "$($ENV:PUBLIC)\downloads\AzureConnectedMachineAgent.msi" -ArgumentList "/quiet /qn /norestart" -wait
            }


            # Install ADDS
            # ------------------------------------------------------------
            Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools


            # Gennerate Safe Mode Password.
            # ------------------------------------------------------------
            $SecurePassword = ConvertTo-SecureString -string $Using:SafeModeAdminPw -AsPlainText -Force


            # Promote domain controller
            # ------------------------------------------------------------
            Install-ADDSDomainController -DomainName $ENV:USERDNSDOMAIN -SafeModeAdministratorPassword $SecurePassword -NoRebootOnCompletion -Confirm:$false -Credential $Using:Credentials


            # Create Central PolicyStore
            # ------------------------------------------------------------
            if (!(Test-Path "\\$($ENV:UserDNSDomain)\SYSVOL\$($ENV:UserDNSDomain)\Policies\PolicyDefinitions")) {
                Copy-Item -Path "$($ENV:SystemRoot)\PolicyDefinitions" -Destination "\\$($ENV:UserDNSDomain)\SYSVOL\$($ENV:UserDNSDomain)\Policies" -Recurse -Force
            }


            # Microsoft Entra Password Protection
            # ------------------------------------------------------------
            if (Test-Path -Path "$($ENV:PUBLIC)\downloads\AzureADPasswordProtectionDCAgentSetup.msi") {
                Start-Process -FilePath "$($ENV:PUBLIC)\downloads\AzureADPasswordProtectionDCAgentSetup.msi" -ArgumentList "/quiet /qn /norestart"
            }


            # Cleanup files.
            # ------------------------------------------------------------
            do {
                Start-Sleep -Seconds 5
            } While ($(Get-Process).name -contains "msiexec")

            Get-ChildItem -Path "$($ENV:PUBLIC)\downloads" -Recurse | Remove-Item


            # Reboot
            # ------------------------------------------------------------
            & Shutdown -r -t 10

        }

        # Cleanup Session
        # ------------------------------------------------------------
        Get-PSSession $Session.Id | Remove-PSSession
    }
}

    #region fmso
    <#

        Move FMSO to new server (Select the one you want to have the FSMO)

    #>
    Write-Output "Current Operation Masters"
    Write-Output "------------------------------"
    $OperationMasterRoles = Get-ADDomainController -Filter * -Credential $Credentials | Select-Object Name, OperationMasterRoles | Where-Object {$_.OperationMasterRoles}
    $OperationMasterRoles.OperationMasterRoles | % { Write-Output "$($OperationMasterRoles.Name) = $($_)" }

    $NewFMSO = Get-ADComputer -Filter "OperatingSystem -like '*2022*'" -SearchBase $((Get-ADDOmain).DomainControllersContainer) -Properties OperatingSystem | Out-GridView -Title "Select the Domain Controller to have all FMSO roles" -OutputMode Single
    if ($NewFMSO) {
        Move-ADDirectoryServerOperationMasterRole -Identity $NewFMSO.Name -OperationMasterRole DomainNamingMaster, InfrastructureMaster, PDCEmulator, RIDMaster, SchemaMaster -Confirm:$False -Force

        Start-Sleep -Seconds 30

        Write-Output "New Operation Masters"
        Write-Output "------------------------------"
        $OperationMasterRoles = Get-ADDomainController -Filter * | Select-Object Name, OperationMasterRoles | Where-Object {$_.OperationMasterRoles}
        $OperationMasterRoles.OperationMasterRoles | % { Write-Output "$($OperationMasterRoles.Name) = $($_)" }
    }
    #endregion

    #region Domain SystemState Backup
    <#

        Configure System State backup of PDC

    #>
    Invoke-Command -ComputerName "$((Get-ADDomain).PDCEmulator)" -ScriptBlock {
#    Enter-PSSession -ComputerName "$((Get-ADDomain).PDCEmulator)"

        # Ensure Windows Server Backup is installed
        # ------------------------------------------------------------
        if (!(Get-Command Start-WBBackup -ErrorAction SilentlyContinue)) {
            Install-WindowsFeature -Name Windows-Server-Backup -IncludeManagementTools
        }


        # Setup Scheduled backup
        # ------------------------------------------------------------
        $Disk = Get-WBDisk | Where { $_.TotalSpace -gt (Get-Partition | Where {$_.DriveLetter -eq "C"} | Get-Disk).Size }
        if ($Disk.count -gt 1) {
            throw "Multiple disks found, please ensure there is only one"
            break
        }
        $DiskInfo = Get-Disk -Number $Disk.DiskNumber

        if ($DiskInfo.OperationalStatus -ne "Online") {
            Get-Disk -Number $Drives.DiskNumber | Set-Disk -IsOffline:$False
            $DiskInfo | Initialize-Disk
            $DiskInfo | Clear-Disk
        }

        if ($null -ne $Disk) {
                
            if (!(Get-WBPolicy)) {
                & wbadmin enable backup -addtarget:"{$($Disk.DiskId.Guid)}" -Schedule:22:00 -allCritical -quiet
            } else {
                Write-Warning "Backup already configured, please check configuration."
                Get-WBPolicy
            }

        } else {
            Write-Warning "No AD Backup configured"
        }

#    Exit-PSSession
    }
    #endregion

    #region Move NDIS path
    <#

        Optional, but recommended.
        Move NTDS.DIT to another drive, eg. D:\ (Ensure the disk is large enouph to hold the database and logfiles)

    #>

    #(Get-ADDomain).ReplicaDirectoryServers | Foreach {
    $($ServerInfo | Where {$_.Role -eq "DC"}).Name | Get-ADComputer -ErrorAction SilentlyContinue | Foreach {

        Invoke-Command -ComputerName "$($_.DNSHostName)" -ScriptBlock {
#    Enter-PSSession -ComputerName "$((Get-ADDomain).PDCEmulator)"

            $CurrentPath = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" -Name "DSA Working Directory")."DSA Working Directory"
            If ($CurrentPath -like "*Windows*") {

                # If any MEDIA on D, Move the drive letter
                $MediaDrive = Get-WmiObject -Class Win32_volume -Filter "DriveType = '5' and DriveLetter != 'X:'"
                if ($null -ne $MediaDrive) {
                    Set-WmiInstance -InputObject $MediaDrive -Arguments @{DriveLetter='X:'} | Out-Null
                }

                # Prep the drive.
#                $Disk = Get-Disk | Where {$_.PartitionStyle -eq "RAW" -AND $_.Size -gt 5Gb -AND $_.Size -lt 15Gb} | Initialize-Disk -PassThru | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "NTDS Disk" -Confirm:$false
                $Disk = Get-Disk | Where {$_.PartitionStyle -eq "RAW"} | Initialize-Disk -PassThru | New-Partition -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "NTDS Disk" -Confirm:$false
                if ($Disk.count -gt 1) {
                    throw "Multiple disks found, please ensure there is only one"
                    break
                }
                if ($null -eq $Disk) {
                    Write-Warning "No disk suitable for NTDS"
                    break
                }

                # Create Folder
                if (!(Test-Path -Path "$($Disk.DriveLetter):\NTDS")) {
                    New-Item -Path "$($Disk.DriveLetter):\NTDS\" -ItemType Directory | Out-Null
                }

                # Stop AD
                Get-Service -Name NTDS | Stop-Service -Force

                $Commands = @()
                $Commands += "activate instance ntds"
                $Commands += "files"
                $Commands += "move db to $($Disk.DriveLetter):\NTDS"
                $Commands += "move logs to $($Disk.DriveLetter):\NTDS"
                $Commands += "quit"
                $Commands += "quit"

                & ntdsutil $commands

                # Start AD
                Get-Service -Name NTDS | Start-Service

                Start-Sleep -Seconds 30
            }
#        Exit-PSSession
        }
    }
    #endregion

    #region Change DNS
    <#

        OPTIONAL : Change Member server DNS (If Required / Run Multiple times)

    #>
    if (Test-Path -Path "$TxScriptPath\Scripts\Change-DNS-MemberServers.ps1") {

        # Open DNS change script.
        # ------------------------------------------------------------
        ISE "$TxScriptPath\Scripts\Change-DNS-MemberServers.ps1"
    }
    #endregion

    #region DHCP DNS
    <#

        OPTIONAL : Change DHCP DNS (If Required / Run Multiple times)

    #>
    if (Test-Path -Path "$TxScriptPath\Scripts\Change-DHCP-DNS.ps1") {

        # Open DHCP-DNS change script.
        # ------------------------------------------------------------
        ISE "$TxScriptPath\Scripts\Change-DHCP-DNS.ps1"
    }
    #endregion

#endregion
