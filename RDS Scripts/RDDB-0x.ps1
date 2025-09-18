<#

    Remote Desktop Session Broker Database Server - SQL Always On.

#>


<#

    Install SQL Always On, for Remote Desktop Session Broker.

#>

# Import TS Tiering modules.
# ------------------------------------------------------------
Import-Module "C:\TS-Data\ADTiering\TSxTieringModule\TSxTieringModule.psm1" -Force -Verbose


# Default TS Tiering base OU
# ------------------------------------------------------------
$TierSearchBase = (Get-ADOrganizationalUnit -Filter "name -eq 'Admin'").DistinguishedName


# Select Destination OU
# ------------------------------------------------------------
$TargetPath = (Get-ADOrganizationalUnit -Filter * -SearchBase $TierSearchBase | `
    Where {$_.DistinguishedName -like "OU=*OU=Servers,OU=Tier1,$TierSearchBase"}) | `
        Select-Object Name,DistinguishedName | Out-GridView -Title "Select Destination OU" -OutputMode Single

<#
if ($null -eq $TargetPath) {
    New-TSxSubOU -Tier T1 -Name "RemoteDesktopDatabaseServers" -Description "Tier1 Remote Desktop Database ervers" -TierOUName "Admin" -CompanyName "NA" -SkipLAPS -Cleanup
    $TargetPath = Get-ADOrganizationalUnit -Identity "OU=RemoteDesktopDatabaseServers,OU=Servers,OU=Tier1,$TierSearchBase"
}
#>


# Get the RDDB servers from AD, we need the objects and path for the script.
# ------------------------------------------------------------
$RDDBServers = Get-ADComputer -Filter "OperatingSystem -like '*Server*' -and Name -like '*RDDB*' -and Enabled -eq 'True'" | Sort-Object -Property Name


# Extract variables from Computer Objects
# ------------------------------------------------------------
$Path = ($RDDBServers[0].DistinguishedName -Split(","))[1..99] -Join(",")
if ($Path -ne $TargetPath.DistinguishedName) {
    $Path = $TargetPath.DistinguishedName
}
$RDDBCluster = "$(($RDDBServers[0].Name)[0..3] -Join(''))"


# Create SQL servers AD Group.
# ------------------------------------------------------------
New-ADGroup -Name "$RDDBCluster - Servers" -Description "RDDB - Group Managed Service account Permissions" -GroupScope Global -GroupCategory Security -Path "OU=Groups,OU=Tier1,$TierSearchBase"
Add-ADGroupMember -Identity $(Get-ADGroup -Identity "$RDDBCluster - Servers") -Members $RDDBServers.SamAccountName


# Remember to reboot the servers after Group Join...
# ------------------------------------------------------------
Invoke-Command -ComputerName $RDDBServers.DNSHostName -ScriptBlock {
    $gpresult = gpresult /r /scope computer
    if (!($gpresult -Match "RDDB - Servers")) {
        Gpupdate /force
        Shutdown -r -t 5
    }
}


# Create Required Cluster objects
# ------------------------------------------------------------
New-ADComputer -Name "$RDDBCluster-CLU" -Path $Path -Enabled $False
$ClusterObject = Get-ADComputer -Identity "$RDDBCluster-CLU"
New-ADComputer -Name "$RDDBCluster-AG" -Path $Path -Enabled $False
$ClusterDBObject = Get-ADComputer -Identity "$RDDBCluster-AG"


# Grant the CLU object permissions on the DB object
# ------------------------------------------------------------
$Acl = Get-Acl "AD:$($ClusterDBObject.DistinguishedName)"
$Ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
    $ClusterObject.SID, "GenericAll", "Allow"
)
$Acl.AddAccessRule($Ace)
Set-Acl -AclObject $Acl -Path $Acl.path

#(Get-Acl "AD:$($ClusterDBObject.DistinguishedName)").access | Where {$_.IdentityReference -like "*$RDDBCluster*"}
#Get-Acl "AD:CN=RDDB,OU=SQL,DC=domain,DC=com" | Format-List
#
#(Get-Acl "AD:$($ClusterObject.DistinguishedName)").access | Where {$_.IdentityReference -like "*$RDDBCluster*"}



# Add SQL GMSA
# ------------------------------------------------------------
New-TSxServiceAccount -FirstName "Service" -LastName "Account $RDDBCluster" -AccountName "gMSA_$RDDBCluster" -UserType gMSA -AccountType T1SVC
Set-ADServiceAccount -Identity "gMSA_$RDDBCluster" -PrincipalsAllowedToRetrieveManagedPassword $(Get-ADGroup -Identity "$RDDBCluster - Servers")
$ServiceAccount = Get-ADServiceAccount -Identity "gMSA_$RDDBCluster" -Properties PrincipalsAllowedToDelegateToAccount,PrincipalsAllowedToRetrieveManagedPassword
$ServiceAccount.PrincipalsAllowedToDelegateToAccount
$ServiceAccount.PrincipalsAllowedToRetrieveManagedPassword


# Allow Service account to create SPN on SELF
# ------------------------------------------------------------
dsacls $(Get-ADServiceAccount "gMSA_$RDDBCluster").DistinguishedName /G "SELF:RPWP;servicePrincipalName" | Out-Null


# Create SPNs
# ------------------------------------------------------------
#$RDDBServers | foreach {
#    
#    setspn -s "MSSQLSvc/$($_.name):1433" "$($ENV:USERDOMAIN)\$($ServiceAccount.SamAccountName)"    
#    setspn -s "MSSQLSvc/$($_.DNSHostName):1433" "$($ENV:USERDOMAIN)\$($ServiceAccount.SamAccountName)"
#    setspn -s "MSSQLSvc/$($_.DNSHostName):5022" "$($ENV:USERDOMAIN)\$($ServiceAccount.SamAccountName)"
#
#}

#setspn -Q MSSQLSvc/RDDB-01.Prod.SysAdmins.Dk:1433
#setspn -Q MSSQLSvc/RDDB-02.Prod.SysAdmins.Dk:1433

#Set-ADAccountControl -Identity gMSA_RDDB$ -TrustedForDelegation $false -TrustedToAuthForDelegation $true

# Download SQL eval install
# $TxScriptPath = "C:\TS-Data"
Invoke-WebRequest -Uri "https://download.microsoft.com/download/4/1/b/41b9a8c3-c2b4-4fcc-a3d5-62feed9e6885/SQL2022-SSEI-Eval.exe?culture=en-us&country=us" -OutFile "$($TxScriptPath)\SQL-Eval-2022.exe"
& "$($TxScriptPath)\SQL-Eval-2022.exe" Action=Download MEDIATYPE=ISO MEDIAPATH="$($TxScriptPath)" QUIET


#Invoke-WebRequest -Uri "https://download.microsoft.com/download/9/b/e/9bee9f00-2ee2-429a-9462-c9bc1ce14c28/SSMS-Setup-ENU.exe" -OutFile "$($TxScriptPath)\SSMS-Setup-ENU.exe"
# Install this on MGMT-11 and MGMT-12 / Perhaps also on MGMT-01 and MGMT-02


# Install & Configure 
# ------------------------------------------------------------
$RDDBServers | Foreach {

    If ( ($Null -ne $TargetPath) -and ($($_.DistinguishedName) -NotLike "*$($TargetPath.DistinguishedName)") ) {
        Move-ADObject -Identity $($_.DistinguishedName) -TargetPath $TargetPath.DistinguishedName
    }


    # Connect to the server.
    # ------------------------------------------------------------
    $Session = New-PSSession -ComputerName "$($_.DNSHostName)"


    # Copy required installers to target server
    # ------------------------------------------------------------
    @(
        "SQLServer2022-x64-ENU.iso"

    ) | Foreach {
        Get-ChildItem -Path $TxScriptPath -Filter $_ -Recurse | Copy-Item -Destination "$($ENV:PUBLIC)\downloads\$_" -ToSession $Session -Force
    }


    # Execute commands.
    # ------------------------------------------------------------
    Invoke-Command -Session $Session -ScriptBlock {

        # Ensure the CDROM, if any dont use the D: Drive
        # ------------------------------------------------------------
        $MediaDrive = Get-WmiObject -Class Win32_volume -Filter "DriveType = '5' and DriveLetter != 'X:'"
        if ($null -ne $MediaDrive) {
            Set-WmiInstance -InputObject $MediaDrive -Arguments @{DriveLetter='X:'} | Out-Null
        }


        # Get any RAW drives, format and assign Drive letter.
        # ------------------------------------------------------------
        $RawDisks = (Get-Disk | Where {$_.PartitionStyle -eq "RAW"}) | Sort-Object -Property Size -Descending
        $RawDisks | Where {$_.PartitionStyle -eq "RAW" -AND $_.Size -ge 50Gb} | Initialize-Disk -PassThru | New-Partition -UseMaximumSize -DriveLetter "D" | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data Disk" -Confirm:$false
        $RawDisks | Where {$_.PartitionStyle -eq "RAW" -AND $_.Size -lt 50Gb} | Initialize-Disk -PassThru | New-Partition -UseMaximumSize -DriveLetter "L" | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Logs Disk" -Confirm:$false


        # Install Required Features.
        Install-WindowsFeature -Name @("Failover-Clustering","NET-Framework-Features") -IncludeManagementTools -Verbose


        # Mount SQL install media
        $ISODrive = Mount-DiskImage -ImagePath "$($ENV:PUBLIC)\Downloads\SQLServer2022-x64-ENU.iso" -StorageType ISO


        # Create Default SQL instalaltion config file
        # ------------------------------------------------------------
        $SQLInstallConfig = @()
        $SQLInstallConfig += "[OPTIONS]"
        $SQLInstallConfig += "ACTION=`"Install`""
        $SQLInstallConfig += "ENU=`"True`""
        $SQLInstallConfig += "PRODUCTCOVEREDBYSA=`"False`""
        $SQLInstallConfig += "SUPPRESSPRIVACYSTATEMENTNOTICE=`"False`""
        $SQLInstallConfig += "QUIET=`"True`""
        $SQLInstallConfig += "QUIETSIMPLE=`"False`""
        $SQLInstallConfig += "UpdateEnabled=`"True`""
        $SQLInstallConfig += "USEMICROSOFTUPDATE=`"True`""
        $SQLInstallConfig += "SUPPRESSPAIDEDITIONNOTICE=`"False`""
        $SQLInstallConfig += "UpdateSource=`"MU`""
        $SQLInstallConfig += "FEATURES=SQLENGINE,REPLICATION"
        $SQLInstallConfig += "HELP=`"False`""
        $SQLInstallConfig += "INDICATEPROGRESS=`"False`""
        $SQLInstallConfig += "INSTANCENAME=`"MSSQLSERVER`""
        $SQLInstallConfig += "INSTALLSHAREDDIR=`"C:\Program Files\Microsoft SQL Server`""
        $SQLInstallConfig += "INSTALLSHAREDWOWDIR=`"C:\Program Files (x86)\Microsoft SQL Server`""
        $SQLInstallConfig += "INSTANCEID=`"MSSQLSERVER`""
        $SQLInstallConfig += "SQLTELSVCSTARTUPTYPE=`"Automatic`""
        $SQLInstallConfig += "SQLTELSVCACCT=`"NT Service\SQLTELEMETRY`""
        $SQLInstallConfig += "INSTANCEDIR=`"C:\Program Files\Microsoft SQL Server`""
        $SQLInstallConfig += "AGTSVCACCOUNT=`"$($ENV:USERDOMAIN)\$($Using:ServiceAccount.SamAccountName)`""
        $SQLInstallConfig += "AGTSVCSTARTUPTYPE=`"Manual`""
        $SQLInstallConfig += "SQLSVCSTARTUPTYPE=`"Automatic`""
        $SQLInstallConfig += "FILESTREAMLEVEL=`"0`""
        $SQLInstallConfig += "SQLMAXDOP=`"4`""
        $SQLInstallConfig += "ENABLERANU=`"False`""
        $SQLInstallConfig += "SQLCOLLATION=`"SQL_Latin1_General_CP1_CI_AS`""
        $SQLInstallConfig += "SQLSVCACCOUNT=`"$($ENV:USERDOMAIN)\$($Using:ServiceAccount.SamAccountName)`""
        $SQLInstallConfig += "SQLSVCINSTANTFILEINIT=`"False`""
        $SQLInstallConfig += "SQLSYSADMINACCOUNTS=`"$($ENV:USERDOMAIN)\Domain Admins`""
        $SQLInstallConfig += "SQLTEMPDBFILECOUNT=`"4`""
        $SQLInstallConfig += "SQLTEMPDBFILESIZE=`"8`""
        $SQLInstallConfig += "SQLTEMPDBFILEGROWTH=`"64`""
        $SQLInstallConfig += "SQLTEMPDBLOGFILESIZE=`"8`""
        $SQLInstallConfig += "SQLTEMPDBLOGFILEGROWTH=`"64`""
        $SQLInstallConfig += "SQLBACKUPDIR=`"D:\Microsoft SQL Server\MSSQL16.MSSQLSERVER\Backup`""
        $SQLInstallConfig += "SQLUSERDBDIR=`"D:\Microsoft SQL Server\MSSQL16.MSSQLSERVER\Data`""
        $SQLInstallConfig += "SQLUSERDBLOGDIR=`"C:\Microsoft SQL Server\MSSQL16.MSSQLSERVER\Logs`""
        $SQLInstallConfig += "ADDCURRENTUSERASSQLADMIN=`"False`""
        $SQLInstallConfig += "TCPENABLED=`"1`""
        $SQLInstallConfig += "NPENABLED=`"0`""
        $SQLInstallConfig += "BROWSERSVCSTARTUPTYPE=`"Disabled`""
        $SQLInstallConfig += "SQLMAXMEMORY=`"8192`""
        $SQLInstallConfig += "SQLMINMEMORY=`"0`""
        $SQLInstallConfig += "IACCEPTSQLSERVERLICENSETERMS=`"True`""

        $SQLInstallConfig | Out-File -FilePath "D:\SqlInstallConfig.ini"


        # Create schedueled task to install the SQL server
        # ------------------------------------------------------------
        $Actions = New-ScheduledTaskAction –Execute "$(($ISODrive | Get-Volume).DriveLetter):\setup.exe" -Argument "/ConfigurationFile=D:\SqlInstallConfig.ini"
        $Trigger = New-ScheduledTaskTrigger -Once -At $((Get-Date).AddDays(1))
        $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
        $Task = New-ScheduledTask -Action $actions -Trigger $trigger -Principal $principal

        Register-ScheduledTask "Install SQL" -InputObject $Task
        Get-ScheduledTask -TaskName "Install SQL" | Start-ScheduledTask


        # Wait for SQL install to be done.
        # ------------------------------------------------------------
        for ($i=0; $i -le 1200; $i++) {
        
            if ((Get-ScheduledTask -TaskName "Install SQL").State -eq "Ready") {
                Unregister-ScheduledTask -TaskName "Install SQL"
            } else {
                Start-Sleep -Seconds 20
            }
        }
        if ((Get-ScheduledTask -TaskName "Install SQL").State -ne "Ready") {
            Write-Warning "SQL Install did not complete within the given timeframe, please verify"
            break
        }
        

        # Open Firewall for 1433 & 5022
        # ------------------------------------------------------------
        if (!(Get-NetFirewallRule -DisplayName "Allow MSSQL on 1433" -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName "Allow MSSQL on 1433" -Direction Inbound -Action Allow -Protocol TCP -LocalPort "1433" | Out-Null
        }

        ## Get-NetFirewallRule -DisplayName "Allow MSSQL on 1433" | Set-NetFirewallRule -RemoteAddress @RDCBServers

        if (!(Get-NetFirewallRule -DisplayName "Allow MSSQL on 5022" -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName "Allow MSSQL on 5022" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5022 | Out-Null
        }

        $RDDBServerIPs = ($Using:RDDBServers | % { Resolve-DnsName -Name $_.DNSHostName -Type A }).IPAddress
        Get-NetFirewallRule -DisplayName "Allow MSSQL on 5022" |  Get-NetFirewallAddressFilter | Set-NetFirewallAddressFilter -RemoteAddress any #$RDDBServerIPs


#        # Test if we have a D:\ Drive where the shares can be created.
#        # ------------------------------------------------------------
#        if ( (!(Get-Partition -DriveLetter $Using:ServerDataDrive -ErrorAction SilentlyContinue)) -And (!($Disk)) ) {
#            Throw "No drive avalible"
#        }
    }
}




# Create Windows Server Failower Cluster
# ------------------------------------------------------------
$CluAddress = "10.36.8.51"
$CluName = "$RDDBCluster-Clu"
if ($Null -eq (Get-Cluster -Domain $ENV:USERDOMAIN | Where {$_.Name -eq "$CluName"})) {
    New-Cluster -Name "$CluName" -Node $RDDBServers[0..1].DNSHostName -StaticAddress $CluAddress
}


Enter-PSSession $RDDBServers[1].DNSHostName


# Create Connection Broker Database, and enable "Always On"
# ------------------------------------------------------------
$DBName = "RDConnectionBroker"
$DbAddress = "10.36.8.52"

Invoke-Command -ComputerName $RDDBServers[0].DNSHostName -ScriptBlock {

    if (!(Get-Module -Name SQLPS)) {
        Import-Module "C:\Program Files (x86)\Microsoft SQL Server\160\Tools\PowerShell\Modules\SQLPS\SQLPS.psd1"
    }

    # Enable SQL Always On.
    if ((get-item  "SQLSERVER:\SQL\$($ENV:ComputerName)\Default").IsHadrEnabled) {
        Disable-SqlAlwaysOn -Path "SQLSERVER:\SQL\$($ENV:ComputerName)\Default" -Force
    }
    if (!((get-item  "SQLSERVER:\SQL\$($ENV:ComputerName)\Default").IsHadrEnabled)) {
        Enable-SqlAlwaysOn -Path "SQLSERVER:\SQL\$($ENV:ComputerName)\Default" -Force
    }


    # Restart SQL Service
    Get-Service -Name MSSQLSERVER | Restart-Service -Force


    # Add Connection Broker Group to SQL
    # ------------------------------------------------------------
    Invoke-Sqlcmd -Query "Create Login [$($ENV:USERDOMAIN)\RDCB - Servers] from Windows"
    Invoke-Sqlcmd -Query "Alter Server role DBCreator add member [$($ENV:USERDOMAIN)\$Using:RDDBCluster - Servers]"

    Invoke-Sqlcmd -Query "Create Login [$($ENV:USERDOMAIN)\Domain Tier1 Admin - DatabaseServers] from Windows"
    Invoke-Sqlcmd -Query "Alter Server role Sysadmin add member [$($ENV:USERDOMAIN)\Domain Tier1 Admin - DatabaseServers]"


    # Verify connection broker Database Name
    # ------------------------------------------------------------
    try {
        Invoke-Sqlcmd -Query "Use $Using:DBName" -ErrorAction Stop
    }
    Catch {
        Invoke-Sqlcmd -Query "CREATE DATABASE [$Using:DBName]"
    }


    Invoke-Sqlcmd -Query "USE [$DBName]; CREATE USER [$($ENV:USERDOMAIN)\$Using:RDDBCluster - Servers] FOR LOGIN [$($ENV:USERDOMAIN)\$Using:RDDBCluster - Servers];"
    Invoke-Sqlcmd -Query "USE [$DBName]; ALTER ROLE [db_owner] ADD MEMBER [$($ENV:USERDOMAIN)\$Using:RDDBCluster - Servers];"
    
    Invoke-Sqlcmd -Query "USE [$DBName]; CREATE USER [$($ENV:USERDOMAIN)\Domain Tier1 Admin - DatabaseServers] FOR LOGIN [$($ENV:USERDOMAIN)\Domain Tier1 Admin - DatabaseServers];"
    Invoke-Sqlcmd -Query "USE [$DBName]; ALTER ROLE [db_owner] ADD MEMBER [$($ENV:USERDOMAIN)\Domain Tier1 Admin - DatabaseServers];"
    
#    Invoke-Sqlcmd -Query "USE [$DBName]; CREATE USER [PROD\RDCB - Servers] FOR LOGIN [PROD\$Using:RDCBServers - Servers];"
#    Invoke-Sqlcmd -Query "USE [$DBName]; ALTER ROLE [db_owner] ADD MEMBER [PROD\$Using:RDDBServers - Servers];"

    Invoke-Sqlcmd -Query "CREATE LOGIN [$($ENV:USERDOMAIN)\gmsa_rddb$] FROM WINDOWS WITH DEFAULT_DATABASE=[master]"

    $BackupDir = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer" | Select-Object BackupDirectory).BackupDirectory
    Invoke-Sqlcmd -Query "BACKUP DATABASE [$DBName] TO DISK = N'$BackupDir\RDConnectionBroker.bak' WITH NOFORMAT, NOINIT,  NAME = N'RDConnectionBroker-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10"

    Invoke-Sqlcmd -Query "CREATE ENDPOINT [Hadr_endpoint] AS TCP (LISTENER_PORT = 5022) FOR DATA_MIRRORING (ROLE = ALL, ENCRYPTION = REQUIRED ALGORITHM AES, AUTHENTICATION = WINDOWS KERBEROS)"
    Invoke-Sqlcmd -Query "ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED"

    Invoke-Sqlcmd -Query "GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [$($ENV:USERDOMAIN)\gmsa_rddb$]"
    Invoke-Sqlcmd -Query "ALTER EVENT SESSION [AlwaysOn_health] ON SERVER WITH (STARTUP_STATE=ON)"
    Invoke-Sqlcmd -Query "ALTER EVENT SESSION [AlwaysOn_health] ON SERVER STATE=START"


    $RDDBServers = $Using:RDDBServers

    $SQLQuery = "USE [Master]; CREATE AVAILABILITY GROUP [RDDB-AG] WITH (AUTOMATED_BACKUP_PREFERENCE = SECONDARY, DB_FAILOVER = ON, DTC_SUPPORT = NONE, "
    $SQLQuery += "REQUIRED_SYNCHRONIZED_SECONDARIES_TO_COMMIT = 0) FOR DATABASE [$($Using:DBName)] "

    $SQLQuery += "REPLICA ON N'$($RDDBServers[0].Name)' WITH (ENDPOINT_URL = N'TCP://$($RDDBServers[0].DNSHostName):5022', FAILOVER_MODE = AUTOMATIC, AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, BACKUP_PRIORITY = 50, SEEDING_MODE = AUTOMATIC, SECONDARY_ROLE(ALLOW_CONNECTIONS = NO)),"

    $SQLQuery += "N'$($RDDBServers[1].Name)' WITH (ENDPOINT_URL = N'TCP://$($RDDBServers[1].DNSHostName):5022', FAILOVER_MODE = AUTOMATIC, AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, BACKUP_PRIORITY = 50, SEEDING_MODE = AUTOMATIC, SECONDARY_ROLE(ALLOW_CONNECTIONS = NO));"
    Invoke-Sqlcmd -Query $SQLQuery

    Invoke-Sqlcmd -Query "USE [Master]; ALTER AVAILABILITY GROUP [RDDB-AG] ADD LISTENER N'RDDB' (WITH IP ((N'$Using:DbAddress', N'255.255.255.0')), PORT=1433);"

}


Invoke-Command -ComputerName $RDDBServers[1].DNSHostName -ScriptBlock {

    if (!(Get-Module -Name SQLPS)) {
        Import-Module "C:\Program Files (x86)\Microsoft SQL Server\160\Tools\PowerShell\Modules\SQLPS\SQLPS.psd1"
    }

    # Enable SQL Always On.
    if ((get-item  "SQLSERVER:\SQL\$($ENV:ComputerName)\Default").IsHadrEnabled) {
        Disable-SqlAlwaysOn -Path "SQLSERVER:\SQL\$($ENV:ComputerName)\Default" -Force
    }
    if (!((get-item  "SQLSERVER:\SQL\$($ENV:ComputerName)\Default").IsHadrEnabled)) {
        Enable-SqlAlwaysOn -Path "SQLSERVER:\SQL\$($ENV:ComputerName)\Default" -Force
    }
    
    # Restart SQL Service
    Get-Service -Name MSSQLSERVER | Restart-Service -Force


    # Add Connection Broker Group to SQL
    # ------------------------------------------------------------
#    Invoke-Sqlcmd -Query "Create Login [PROD\$Using:RDCBServers - Servers] from Windows"
#    Invoke-Sqlcmd -Query "Alter Server role DBCreator add member [PROD\$Using:RDCBServers - Servers]"

    Invoke-Sqlcmd -Query "CREATE LOGIN [PROD\$Using:RDDBServers - Servers] FROM WINDOWS WITH DEFAULT_DATABASE=[master]"

    Invoke-Sqlcmd -Query "CREATE ENDPOINT [Hadr_endpoint] AS TCP (LISTENER_PORT = 5022) FOR DATA_MIRRORING (ROLE = ALL, ENCRYPTION = REQUIRED ALGORITHM AES, AUTHENTICATION = WINDOWS KERBEROS)"
    Invoke-Sqlcmd -Query "ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED"

    Invoke-Sqlcmd -Query "CREATE LOGIN [$($ENV:USERDOMAIN)\gmsa_rddb$] FROM WINDOWS WITH DEFAULT_DATABASE=[master]"

    Invoke-Sqlcmd -Query "GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [$($ENV:USERDOMAIN)\gmsa_rddb$]"
    Invoke-Sqlcmd -Query "ALTER EVENT SESSION [AlwaysOn_health] ON SERVER WITH (STARTUP_STATE=ON)"
    Invoke-Sqlcmd -Query "ALTER EVENT SESSION [AlwaysOn_health] ON SERVER STATE=START"

    Invoke-Sqlcmd -Query "ALTER AVAILABILITY GROUP [RDDB-AG] JOIN;"
    Invoke-Sqlcmd -Query "ALTER AVAILABILITY GROUP [RDDB-AG] GRANT CREATE ANY DATABASE;"

}
