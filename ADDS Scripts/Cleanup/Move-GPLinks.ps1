<#

    To assist in secureing Domain root and Domain Controllers OU, this script can Copy or Move ACLs to where they are needed.

#>

# Get DistinguishedName of required Containers
# ------------------------------------------------------------
$OrganizationalUnits  = @()
$OrganizationalUnits += (Get-ADDomain).DistinguishedName
$OrganizationalUnits += (Get-ADDomain).DomainControllersContainer


# Select OU from where the GPO link must be removed.
# ------------------------------------------------------------
$OrganizationalUnit = $OrganizationalUnits | Out-GridView -Title "Select OU where to MOVE GPO links from" -OutputMode Single


# Select the GPO to move
# ------------------------------------------------------------
$GPOLinks = (Get-GPInheritance -Target $OrganizationalUnit).GpoLinks
$SelectedGPOs = $GPOLinks | Select-Object DisplayName -Unique | Out-GridView -Title "Select the GPO to be moved" -OutputMode Multiple


# Select Target OU
# ------------------------------------------------------------
$TargetOU = Get-ADOrganizationalUnit -Filter * -SearchBase $(Get-ADDomain).DistinguishedName -SearchScope Subtree | Select-Object Name,DistinguishedName | Out-GridView -Title "Select the Destination OU" -OutputMode Multiple
$TargetOU = Get-ADDomain | Select-Object Name,DistinguishedName


# Apply the selected GPLinks
# ------------------------------------------------------------
$TargetOU | % {
    $OU = $($_.DistinguishedName)

    $SelectedGPOs | % {
        New-GPLink -Target $OU -Name $_.DisplayName | Out-Null
    }
}


# Remove from "Source OU"
# ------------------------------------------------------------
$Cleanup = [System.Windows.MessageBox]::Show('Remove selected GPO Links','Cleanup','YesNo','Question')
if ($Cleanup -eq "Yes") {

    $SelectedGPOs | % {
        Remove-GPLink -Target $OrganizationalUnit -Name $_.DisplayName | Out-Null
    }
}
