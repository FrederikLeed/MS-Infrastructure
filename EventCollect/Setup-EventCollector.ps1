<#
     _____                _    ______                               _ _             
    |  ___|              | |   |  ___|                             | (_)            
    | |____   _____ _ __ | |_  | |_ ___  _ ____      ____ _ _ __ __| |_ _ __   __ _ 
    |  __\ \ / / _ \ '_ \| __| |  _/ _ \| '__\ \ /\ / / _` | '__/ _` | | '_ \ / _` |
    | |___\ V /  __/ | | | |_  | || (_) | |   \ V  V / (_| | | | (_| | | | | | (_| |
    \____/ \_/ \___|_| |_|\__| \_| \___/|_|    \_/\_/ \__,_|_|  \__,_|_|_| |_|\__, |
                                                                               __/ |
                                                                              |___/ 
    Todo.
    1. Add the Collector server
    2. ReTest LogForwarder setup.


    "Script" Actions.
    1. Setup Event forwarding
    2. Add GPO
    3. Add EventID to log Collection

#>

# --
# 
# --
#Add-KDSRootKey -EffectiveImmediately


# --
# Set Event Collector server name
# --
$EventCollector = Get-ADComputer -Identity "RPA-01"


# Create eventcollector GPO
# ------------------------------------------------------------
try {
    $GPO = Get-GPO -Name "Admin - Domain Controllers Event Collection Policy"
}
Catch {
    $GPO = New-GPO -Name "Admin - Domain Controllers Event Collection Policy"
}
(Get-GPO -Name $GPO.DisplayName).GpoStatus = "UserSettingsDisabled"


# Update PDC security descriptor from PDC, to allow Network Services access.
# https://learn.microsoft.com/en-gb/troubleshoot/windows-server/group-policy/set-event-log-security-locally-or-via-group-policy
# ------------------------------------------------------------
$ChannelAccess = Invoke-Command -ComputerName $(Get-ADDomain).PDCEmulator -ScriptBlock {
    $log = Get-WinEvent -ListLog "Security"
    Return $log.SecurityDescriptor
}
if ($ChannelAccess -notlike "*(A;;0x1;;;NS)") {
    $ChannelAccess = $ChannelAccess + "(A;;0x1;;;NS)"
}


# Define the Eventcollector Registry settings
# ------------------------------------------------------------
$SubscriptionManager = "Server=http://" + $Identity.DNSHostName + ":5985/wsman/SubscriptionManager/WEC,Refresh=600"


# Create GPO settings.
# ------------------------------------------------------------
Set-GPRegistryValue -Name $GPO.DisplayName -Key "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager" -ValueName "SubscriptionManager" -Type String -Value $SubscriptionManager | Out-Null
Set-GPRegistryValue -Name $GPO.DisplayName -Key "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\EventLog\Security" -ValueName "ChannelAccess" -Type String -Value $ChannelAccess | Out-Null


# Link GPO to Domain controllers
# ------------------------------------------------------------
New-GPLink -Name $GPO.DisplayName -Target $((Get-ADDomain).DomainControllersContainer) -LinkEnabled Yes


# Connect to "syslog" server
# ------------------------------------------------------------
$Session = New-PSSession -ComputerName $EventCollector.DNSHostName


# Setup the event Collector server
# ------------------------------------------------------------
Invoke-Command -Session $Session {

    # Configure Windows Event Collector service
    # ------------------------------------------------------------
    & wecutil qc /q | Out-Null


    # Ensure the Firewall Rules are updated.
    # https://learn.microsoft.com/en-us/troubleshoot/windows-server/admin-development/events-not-forwarded-by-windows-server-collector
    # ------------------------------------------------------------
    & netsh http delete urlacl url=http://+:5985/wsman/ | Out-Null
    & netsh http add urlacl url=http://+:5985/wsman/ sddl="D:(A;;GX;;;S-1-5-80-569256582-2953403351-2909559716-1301513147-412116970)(A;;GX;;;S-1-5-80-4059739203-877974739-1245631912-527174227-2996563517)" | Out-Null
    & netsh http delete urlacl url=https://+:5986/wsman/ | Out-Null
    & netsh http add urlacl url=https://+:5986/wsman/ sddl="D:(A;;GX;;;S-1-5-80-569256582-2953403351-2909559716-1301513147-412116970)(A;;GX;;;S-1-5-80-4059739203-877974739-1245631912-527174227-2996563517)" | Out-Null


    # Create Event Subscription, add more IDs if needed.
    # ------------------------------------------------------------
    # EventID=4728 = A member was added to a security-enabled global group
    # EventID=4729 = A member was removed from a security-enabled global group
    # EventID=5136 = A directory service object was modified
    # ------------------------------------------------------------
    $CollectorName = "Group membership Changes"
    $CollectorPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\EventCollector\Subscriptions"
    New-Item -Path $CollectorPath -Name $CollectorName | Out-Null
    New-ItemProperty -Path "$CollectorPath\$CollectorName" -Name Enabled -PropertyType dword -Value 0 | Out-Null
    New-ItemProperty -Path "$CollectorPath\$CollectorName" -Name Description -PropertyType string -Value "" | Out-Null
    New-ItemProperty -Path "$CollectorPath\$CollectorName" -Name URI -PropertyType string -Value "http://schemas.microsoft.com/wbem/wsman/1/windows/EventLog" | Out-Null
    New-ItemProperty -Path "$CollectorPath\$CollectorName" -Name ConfigurationMode -PropertyType string -Value "MinLatency" | Out-Null
    New-ItemProperty -Path "$CollectorPath\$CollectorName" -Name Query -PropertyType string -Value "<QueryList><Query Id=`"0`"><Select Path=`"Security`">*[System[(EventID=4728 or EventID=4729 or EventID=5136)]]</Select></Query></QueryList>" | Out-Null
    New-ItemProperty -Path "$CollectorPath\$CollectorName" -Name TransportName -PropertyType string -Value "HTTP" | Out-Null
    New-ItemProperty -Path "$CollectorPath\$CollectorName" -Name LogFile -PropertyType string -Value "ForwardedEvents" | Out-Null
    New-ItemProperty -Path "$CollectorPath\$CollectorName" -Name PublisherName -PropertyType string -Value "Microsoft-Windows-EventCollector" | Out-Null
    New-ItemProperty -Path "$CollectorPath\$CollectorName" -Name ReadExistingEvents -PropertyType dword -Value 0 | Out-Null
    New-ItemProperty -Path "$CollectorPath\$CollectorName" -Name SubscriptionType -PropertyType string -Value "SourceInitiated" | Out-Null
    New-ItemProperty -Path "$CollectorPath\$CollectorName" -Name AllowedIssuerCAs -PropertyType string -Value "" | Out-Null
    New-ItemProperty -Path "$CollectorPath\$CollectorName" -Name AllowedSourceDomainComputers -PropertyType string -Value "O:NSG:BAD:P(A;;GA;;;DD)S:" | Out-Null
    New-ItemProperty -Path "$CollectorPath\$CollectorName" -Name LastError -PropertyType dword -Value 0 | Out-Null
    New-ItemProperty -Path "$CollectorPath\$CollectorName" -Name LastFaultMessage -PropertyType string -Value "" | Out-Null
    New-ItemProperty -Path "$CollectorPath\$CollectorName" -Name LastErrorTime -PropertyType string -Value "" | Out-Null

    New-Item -Path "$CollectorPath\$CollectorName" -Name "EventSources" | Out-Null

    Set-ItemProperty -Path"$CollectorPath\$CollectorName" -Name Enabled -Value 1 | Out-Null

    & wecutil rs "$CollectorName"

}


# Update GPOs and restart domain controllers
# ------------------------------------------------------------
$((Get-ADDomain).ReplicaDirectoryServers) | % { Invoke-Command -ComputerName $_ -ScriptBlock {
        Invoke-GPUpdate -Force | Out-Null
        Invoke-GPUpdate -Force | Out-Null
   
        Shutdown -r -t 10
    }

    Start-Sleep -Seconds 300
}
