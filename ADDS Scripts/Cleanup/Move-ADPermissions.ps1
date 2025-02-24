<#

    To assist in secureing Domain root and Domain Controllers OU, this script can Copy or Move ACLs to where they are needed.

#>

# Get DistinguishedName of required Containers
# ------------------------------------------------------------
$OrganizationalUnits  = @()
$OrganizationalUnits += (Get-ADDomain).DistinguishedName
$OrganizationalUnits += (Get-ADDomain).DomainControllersContainer

$OrganizationalUnit = $OrganizationalUnits | Out-GridView -Title "Select OU where to MOVE acl from" -OutputMode Single


# Select the ACL to move
# ------------------------------------------------------------
$CurrentACL = Get-Acl "AD:\$OrganizationalUnit"
$SelectedACL = ($CurrentACL.Access) | Where {$_.IsInherited -eq 0} | Select-Object IdentityReference -Unique | Out-GridView -Title "Select the IdentityReference to be moved" -OutputMode Multiple
$ACL2Move = $CurrentACL.Access | Where {$_.IdentityReference -in $SelectedACL.IdentityReference}


# Select Target OU
# ------------------------------------------------------------
$TargetOU = Get-ADOrganizationalUnit -Filter * -SearchBase $(Get-ADDomain).DistinguishedName -SearchScope OneLevel | Select-Object Name,DistinguishedName | Out-GridView -Title "Select the Destination OU" -OutputMode Multiple


# Apply the selected ACLs
# ------------------------------------------------------------
$TargetOU | % {
    $OU = $($_.DistinguishedName)
    $OUACL = Get-ACL -Path "AD:\$OU"

    $ACL2Move | % {
        $OUACL.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule $_.IdentityReference, $_.ActiveDirectoryRights, $_.AccessControlType, $_.ObjectType, $_.InheritanceType, $_.InheritedObjectType))
    }

    #$OUACL.Access | Where {$_.IdentityReference -in $ACL2Move.IdentityReference}
    Set-Acl -Path "AD:\$OU" -AclObject $OUACL
}


# Remove from "Source OU"
# ------------------------------------------------------------
$Cleanup = [System.Windows.MessageBox]::Show('Remove selected ACLs','Cleanup','YesNo','Question')
if ($Cleanup -eq "Yes") {

    $ACL2Move | % {
        $CurrentACL.RemoveAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule $_.IdentityReference, $_.ActiveDirectoryRights, $_.AccessControlType, $_.ObjectType, $_.InheritanceType, $_.InheritedObjectType))
    }

    Set-Acl -Path "AD:\$OrganizationalUnit" -AclObject $CurrentACL
}
