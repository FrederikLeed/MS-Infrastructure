#Requires -Modules "ActiveDirectory"
<#
    .DESCRIPTION
     Find and remove disabled Users

#>

$DeleteTimeSpan = 180


# Usable Date formats.
# "dd-MM-yyyy", "yyyy-MM-dd", "MM-dd-yyyy", "MM/dd/yyyy", "yyyy/MM/dd", "dd/MM/yyyy"
# ------------------------------------------------------------
$DateFormat = $((Get-culture).DateTimeFormat).ShortDatePattern
$CurrentDate = Get-Date -Format $DateFormat


Try {
    # Change the OU to where the Disabled User Objects are located.
    $SearchBase = Get-ADOrganizationalUnit -Identity "OU=DisabledUsers,OU=UserAccounts,OU=Company Endpoints,$((Get-ADDomain).DistinguishedName)"
}
Catch {
}


$Users = Get-ADUser -Filter { Enabled -eq 'False' } -Properties Description,MemberOf -SearchBase $SearchBase.DistinguishedName
Foreach ($User in $Users) {

    # Get the Disabled Date from Description
    # ------------------------------------------------------------
    $($User.Description) -match "\[(?:Disabled),\s*([\d\-\/]+)\]"
    $DisableDate = Get-Date $($matches[1]) -Format $DateFormat


    # Calculate the timespan
    # ------------------------------------------------------------
    $TimeSpan = New-TimeSpan -Start $DisableDate -End $CurrentDate
    if ($TimeSpan.Days -gt $DeleteTimeSpan) {
        Write-Verbose "Remove User : $($User.Name)"

        # Update Description
        # ------------------------------------------------------------
        Set-AdUser -Identity $User.DistinguishedName -Description $("[Deleted, $CurrentDate] $($User.Description)")


        # Cleanup Group Membership, prior to removal.
        # ------------------------------------------------------------
        $($User.MemberOf) | Foreach {
            Remove-ADGroupMember -Identity $_ -Members $User.DistinguishedName -Confirm:$False
        }

        # Delete the user.
        # ------------------------------------------------------------
        Remove-ADUser -Identity $User.DistinguishedName -Confirm:$False

    }
}
