<#

    LDAP Script to lookup OU where the account have permissions to Join the domain.

    Join the computer / server to the selected OU

#>


# Restart the script as Admin, if needed.
# ------------------------------------------------------------
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
If (!($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {

    Write-Output ""
    Write-Warning "Restarting script as Administrator"
    Write-Output ""

    $PSHost = If ($PSVersionTable.PSVersion.Major -le 5) {'PowerShell'} Else {'PwSh'}
    Start-Process -Verb RunAs $PSHost (" -File `"$PSCommandPath`" " + ($MyInvocation.Line -split '\.ps1[\s\''\"]\s*', 2)[-1])

    Start-Sleep -Seconds 5
    break

}


# Check existing domain member.
# ------------------------------------------------------------
if ((gwmi win32_computersystem).partofdomain) {
    Write-Output ""
    Write-Warning "Server is already part of a domain, if you want to change that, please remove the server from the current domain and rerun this script"
    Write-Output ""
    break
}


# Get the Domain Name
# ------------------------------------------------------------
Write-Output ""
Write-Output "Please enter the domain name you whish to join"
$strDomainName = Read-Host -Prompt "Domain Name (FQDN)"


# Get Domain Join Credentials
# ------------------------------------------------------------
Write-Output ""
Write-Output "Please enter credentials with permissions to do Domain Join"
$Credentials = Get-Credential -Message "Domain Join Credentials"


# Try to resolve domain name.
# ------------------------------------------------------------
try {
    $DomainToJoin = (((nslookup $strDomainName | Where {$_ -like '*Name:*'}) -Split(" "))[-1]).tolower() | Out-Null
}
Catch {

}


# Get hostname
# ------------------------------------------------------------
Write-Output ""
Write-Output "If the name of this server need to change please enter the new name, or enter for no change"
$ServerName = Read-Host -Prompt "Enter new Server Name: `"$($env:COMPUTERNAME)`""


<#

    Main Script

#>


# DNS Name to distinguishedName
# ------------------------------------------------------------
$RootDSE = (($DomainToJoin -split("\.")) | Foreach { "DC=$($_)" }) -Join(",")


# Lookup Domain controller in DNS
# ------------------------------------------------------------
Write-Output ""
Write-Output "------------------------------------------------------------"
Write-Output "Find primary server in DNS, used by the LDAP connection"
$Servers = ((nslookup -type=SRV _ldap._tcp.dc._msdcs.$DomainToJoin. | Where {$_ -like '*hostname*'}) -split(" ")) | Where {$_ -like "*$DomainToJoin*"}
$DomainServer = Get-Random -InputObject $Servers


# Connect to the Domain Controller, with supplied credentials.
# ------------------------------------------------------------
Write-Output "Make LDAP connection to $DomainServer with supplied credentials"
$objDomain = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$DomainServer/$RootDSE", $($Credentials.UserName), $($Credentials.GetNetworkCredential().password))


# Setup the AD Searcher.
# ------------------------------------------------------------
$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
$objSearcher.SearchScope = "Subtree"
$objSearcher.SearchRoot = $objDomain


# Only get selected properties.
# ------------------------------------------------------------
@("name", "samaccountname", "distinguishedName", "memberof", "objectsid") | `
foreach { $objSearcher.PropertiesToLoad.Add($_) | Out-Null }


# Search filter for enter user, need group membership.
# ------------------------------------------------------------
$objSearcher.Filter = "(samaccountname=$struserName)"


# Extract required values from object.
# ------------------------------------------------------------
Write-Output "Query AD (LDAP) for the supplied users group membership"

$UserData = $objSearcher.FindOne() | `
    Select-Object @{n='DistinguishedName'; e={$_.Properties.distinguishedname}}, `
                  @{n='ObjectSid'; e={[System.Security.Principal.SecurityIdentifier]::new($_.Properties.objectsid[0], 0).value}}, `
                  @{n='Tier'; e={([REGEX]"\bTier[^,]+").match($_.Properties.distinguishedname).Value}}, `
                  @{n='memberof'; e={$_.Properties.memberof}}


if ($UserData.memberof.count -eq 0) {
    Write-Output ""
    Write-Error "Unable to find any Group membership"
    Start-Sleep -Seconds 120
    break
}


# Extract Domain SID from UserSid
# ------------------------------------------------------------
$DomainSid = (Select-String -Pattern ".*(?=-)" -InputObject $UserData.ObjectSid).Matches.Value


# Get Groups SID
# ------------------------------------------------------------
Write-Output "Query AD (LDAP) for group(s) information"
$GroupSids = @()

foreach ($Group in $UserData.memberof) {
    $objSearcher.Filter = "(distinguishedName=$Group)"
    $GroupSids += $objSearcher.FindOne() | `
        Select-Object @{n='samaccountname'; e={"$($objDomain.name)\$($_.Properties.samaccountname)"}}, `
                      @{n='objectsid'; e={[System.Security.Principal.SecurityIdentifier]::new($_.Properties.objectsid[0], 0).value}}
}


# Change filter to Organizational Units
# ------------------------------------------------------------
$objSearcher.Filter = "(objectCategory=organizationalUnit)"


# Construct the OU list, from permissions.
# ------------------------------------------------------------
Write-Output "Get all the OUs where the users group membership gives Domain Join rights"
$OrganizationalUnits = @()


# If Domain Admin, show all Server OUs
# ------------------------------------------------------------
if ($("$DomainSid-512") -in $GroupSids) {

    $OrganizationalUnits += ($objSearcher.FindAll() | Where {$_.Properties.distinguishedname -like "*OU=*OU=Servers,OU=Tier*"})

} else {

    # If Tier 1 or Tier 2 admin show OUs where supplied user have Computer Create rights
    $objSearcher.FindAll() | Foreach {

        $objOUACL = New-Object System.DirectoryServices.DirectoryEntry($_.Path, $($Credentials.UserName), $($Credentials.GetNetworkCredential().password))
        
        $Permissions = $objOUACL.PsBase.ObjectSecurity.Access | `
            Where { ( $_.IdentityReference -in $GroupSids.objectsid -OR $_.IdentityReference -in $GroupSids.samaccountname ) `
                    -AND $_.ObjectType -eq "bf967a86-0de6-11d0-a285-00aa003049e2" `
                    -AND $_.ActiveDirectoryRights -like "*CreateChild*"}

        if ($NULL -ne $Permissions.ActiveDirectoryRights) {
            $OrganizationalUnits += $_ #$objOUACL.distinguishedName
        }
    }
}


if ($OrganizationalUnits.Count -eq 0) {
    Write-Output ""
    Write-Error "Unable to find any Organizational Unit where $($Credentials.UserName) have Create Computer permissions"
    Start-Sleep -Seconds 120
    break
}


# Show Powershell gridview to select destination OU
# ------------------------------------------------------------
$DestinationOU = $OrganizationalUnits | Select-Object -Property @{n='Name'; e={$_.Properties.name}}, @{n='DistinguishedName'; e={$_.Properties.distinguishedname}} | Out-GridView -Title "Please select the destination OU" -OutputMode Single


# Show confirmation prompt..
# ------------------------------------------------------------
Write-Output ""
Write-Output "Domain join parameters."
Write-Output "------------------------------------------------------------"
if ($ServerName) {
    Write-Output "Servername : $ServerName"
} else {
    Write-Output "Servername : $($env:COMPUTERNAME)"
}
Write-Output "Domain Name : $DomainToJoin"
Write-Output "Destination OU : $($DestinationOU.DistinguishedName)"
Write-Output ""


while($true) {
    $readHostValue = Read-Host -Prompt "Is the parameters correct Yes or No"
    switch -Regex ($readHostValue) {
        "^Y(es)?$" {
            # Add the server to Domain in the selected OU
            # ------------------------------------------------------------
            Write-Output ""
            Write-Output "Add local computer to $DomainToJoin"
            if ($ServerName) {

                Rename-Computer -NewName $ServerName -Restart:$False
                Start-Sleep -Seconds 5
                Add-Computer -DomainName $DomainToJoin -force –Options JoinWithNewName,accountcreate -OUPath $($DestinationOU.DistinguishedName) -Restart -Credential $Credentials

            } else {

                Add-Computer -DomainName $DomainToJoin -OUPath $($DestinationOU.DistinguishedName) -Credential $Credentials -Restart

            }
            return
        }
        "^N(o)?$" {
            return
        }
        Default {
            "Invalid input"
        }
    }
}
