<#
    ____________   _     _                    _             
    | ___ \  _  \ | |   (_)                  (_)            
    | |_/ / | | | | |    _  ___ ___ _ __  ___ _ _ __   __ _ 
    |    /| | | | | |   | |/ __/ _ \ '_ \/ __| | '_ \ / _` |
    | |\ \| |/ /  | |___| | (_|  __/ | | \__ \ | | | | (_| |
    \_| \_|___/   \_____/_|\___\___|_| |_|___/_|_| |_|\__, |
                                                       __/ |
                                                      |___/ 
#>

<#
    
    Install and Activete Remote Desktop Licensing service.
    - Add License Pack on Remote Desktop

    This asumes the servers are using RDLI in the name
    Terminal Services wil be activated with NetBiosName, and Server Home location (See line 83,84)

#>


# Default TS Tiering base OU
# ------------------------------------------------------------
$TierSearchBase = (Get-ADOrganizationalUnit -Filter "name -eq 'Admin'").DistinguishedName


# Select Destination OU
# ------------------------------------------------------------
$TargetPath = (Get-ADOrganizationalUnit -Filter * -SearchBase $TierSearchBase | `
    Where {$_.DistinguishedName -like "OU=*OU=Servers,OU=Tier1,$TierSearchBase"}) | `
        Select-Object Name,DistinguishedName | Out-GridView -Title "Select Destination OU" -OutputMode Single


# Select Remote Desktop Licensing server
# ------------------------------------------------------------
$ServersQuery = Get-ADComputer -filter "OperatingSystem -like '*Server*' -and Name -like '*RDLI*'"
if ($ServersQuery.count -ge 1) {
    $SelectedServers = $ServersQuery | Select-Object -Property Name,DNSHostName,DistinguishedName | `
        Out-GridView -Title "Select the Tier 0 Jump / Management Servers" -OutputMode Multiple
} else {
    $SelectedServers = $ServersQuery
}


# Install & Configure Remote Desktop Licensing server
# ------------------------------------------------------------
$($SelectedServers).Name | Get-ADComputer -ErrorAction SilentlyContinue | Foreach {

    If ( ($Null -ne $TargetPath) -and ($($_.DistinguishedName) -NotLike "*$($TargetPath.DistinguishedName)*") ) {
        Move-ADObject -Identity $($_.DistinguishedName) -TargetPath $TargetPath.DistinguishedName
    }    


    # Connect to the server.
    # ------------------------------------------------------------
    $Session = New-PSSession -ComputerName "$($_.DNSHostName)"


    # Execute commands.
    # ------------------------------------------------------------
    Invoke-Command -Session $Session -ScriptBlock {


        # Install Remote Desktop Licensing Services
        # ------------------------------------------------------------
        Install-WindowsFeature -Name "RDS-Licensing" -IncludeManagementTools


        # Get user name for Registration
        # ------------------------------------------------------------
        $User = Get-AdUser -Identity $($ENV:USERNAME)
        

        # Activate Licensing server (Please add the CALS after registration)
        # ------------------------------------------------------------
        $wmiClass = ([wmiclass]"\\localhost\root\cimv2:Win32_TSLicenseServer")
        $wmiClass.GetActivationStatus().ActivationStatus

        $wmiTSLicenseObject = Get-WMIObject Win32_TSLicenseServer
        $wmiTSLicenseObject.FirstName="$($User.GivenName)"
        $wmiTSLicenseObject.LastName="$($user.Surname)"
        $wmiTSLicenseObject.Company="$((Get-ADDomain).NetBIOSName)"
        $wmiTSLicenseObject.CountryRegion="$((Get-WinHomeLocation).HomeLocation)"
        $wmiTSLicenseObject.Put()

        $wmiClass.ActivateServerAutomatic()

        $wmiClass.GetActivationStatus().ActivationStatus


        # Reboot to activate all changes.
        # ------------------------------------------------------------
        & shutdown -r -t 10

    }
    

    # Add server to "Terminal Server License Servers"
    # ------------------------------------------------------------
    $RDLicenceServer = $_.Name
    Add-ADGroupMember -Members "$(Get-ADComputer -Identity "$RDLicenceServer")" -Identity $(Get-ADGroup -Identity "Terminal Server License Servers")
    
}


# Create GPO with settings to this RD licensing server
# ------------------------------------------------------------
if ( ($RDLicenceServer) -And (!(Get-GPO -Name "Admin - Set Remote Desktop Licensing server" -ErrorAction SilentlyContinue)) ) {
    $GPO = New-GPO -Name "Admin - Set Remote Desktop Licensing server"
    (Get-GPO -Name $GPO.DisplayName).GpoStatus = "UserSettingsDisabled"

    Set-GPRegistryValue -Name $GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName LicensingMode -Value 4 -Type DWord | Out-Null
    Set-GPRegistryValue -Name $GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName LicenseServers -Value $RDLicenceServer -Type String | Out-Null

    $(Get-ADOrganizationalUnit -Filter "Name -like '*Jump*'") | foreach {
        Get-GPO -Name $GPO.DisplayName | New-GPLink -Target $($_.DistinguishedName) -LinkEnabled Yes | Out-Null
    }
}


# Create GPO to install Remote Desktop Session Host featuers
# ------------------------------------------------------------
if ( ($RDLicenceServer) -And (!(Get-GPO -Name "Admin - Install Remote Desktop Session Host" -ErrorAction SilentlyContinue)) ) {
    $GPO = New-GPO -Name "Admin - Install Remote Desktop Session Host"
    (Get-GPO -Name $GPO.DisplayName).GpoStatus = "UserSettingsDisabled"



    # Create Schedule that runs,
    # Powershell.exe -noprofile -Command "Get-WindowsFeature -Name 'RDS-RD-Server' | Where {$_.InstallState -eq 'Available'} | Install-WindowsFeature -ErrorAction SilentlyContinue"



    $(Get-ADOrganizationalUnit -Filter "Name -like '*Jump*'") | foreach {
        Get-GPO -Name $GPO.DisplayName | New-GPLink -Target $($_.DistinguishedName) -LinkEnabled Yes | Out-Null
    }
}
