#Requires -Modules "ActiveDirectory"
<#
    .DESCRIPTION
     Find and disable Inactive Computers

#>

$DeleteTimeSpan = 180


# Usable Date formats.
# "dd-MM-yyyy", "yyyy-MM-dd", "MM-dd-yyyy", "MM/dd/yyyy", "yyyy/MM/dd", "dd/MM/yyyy"
# ------------------------------------------------------------
$DateFormat = $((Get-culture).DateTimeFormat).ShortDatePattern
$CurrentDate = Get-Date -Format $DateFormat


Try {
    # Change the OU to where the Disabled Computer Objects are located.
    $SearchBase = Get-ADOrganizationalUnit -Identity "OU=DisabledComputers,OU=UserAccounts,OU=Company Endpoints,$((Get-ADDomain).DistinguishedName)"
}
Catch {
}


$Computers = Get-ADComputer -Filter { Enabled -eq 'False' } -Properties Description -SearchBase $SearchBase.DistinguishedName
Foreach ($Computer in $Computers) {

$Computer = Get-ADComputer -Identity $Computers.DistinguishedName -Properties Description

    # Get the Disabled Date from Description
    # ------------------------------------------------------------
    $($Computer.Description) -match "\[(?:Disabled),\s*([\d\-\/]+)\]"
    $DisableDate = Get-Date $($matches[1]) -Format $DateFormat


    # Calculate the timespan
    # ------------------------------------------------------------
    $TimeSpan = New-TimeSpan -Start $DisableDate -End $CurrentDate
    if ($TimeSpan.Days -gt $DeleteTimeSpan) {
        Write-Verbose "Remove Computer : $($Computer.DistinguishedName)"

        # Update Description
        # ------------------------------------------------------------
        Set-AdComputer -Identity $Computer.DistinguishedName -Description $("[Deleted, $CurrentDate] $($Computer.Description)")


        # Delete the Computer.
        # ------------------------------------------------------------
        Remove-ADComputer -Identity $Computer.DistinguishedName -Confirm:$False

    }
}
