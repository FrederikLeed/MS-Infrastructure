<#

    The purpose is to verify that each delegation is linked to an account which exists

    To reduce the risk, the easiest way is essentially to remove the delegation

#>

# Get the Domain SID
# ------------------------------------------------------------
$DomainSID = (Get-ADDomain).DomainSID.Value


# Get all AD Objects
# ------------------------------------------------------------
$Objects = Get-ADObject -LDAPFilter '(objectClass=*)' -SearchBase (Get-ADDomain).DistinguishedName -SearchScope Subtree -Properties nTSecurityDescriptor


# Check the Objects Acl.
# ------------------------------------------------------------
$UnknownACL = foreach ($Obj in $objects[0..10]) {

    $ace = $(Get-ACL -Path "AD:\$($obj.DistinguishedName)").Access | Where { (!($_.IsInherited)) -and $_.IdentityReference -like "$DomainSID*" }

    if ($null -ne $ace) {
        [PSCustomObject]@{
            DistinguishedName    = $obj.DistinguishedName
            ObjectClass          = $obj.ObjectClass
            UnresolvedSID        = $ace.IdentityReference.Value
            ActiveDirectoryRight = $ace.ActiveDirectoryRights
            AccessControlType    = $ace.AccessControlType
            InheritanceType      = $ace.InheritanceType
        }
    }
}

# List the unknowns.
# ------------------------------------------------------------
$UnknownACL | Format-Table -AutoSize


<#

    Remidate the findings.

    ! Please handle with care, this removes the ACL from Active Directory.

#>
# to ensure this is not just executed.
break


foreach ($Obj in $UnknownACL) {

    $OrgACL = $(Get-ACL -Path "AD:\$($Obj.DistinguishedName)")

    $RuleToRemove = $OrgACL.Access | Where { (!($_.IsInherited)) -and $_.IdentityReference -like "$DomainSID*" }

    $OrgACL.RemoveAccessRule($RuleToRemove)

    Set-Acl -Path "AD:\$($Obj.DistinguishedName)" -AclObject $OrgACL
}
