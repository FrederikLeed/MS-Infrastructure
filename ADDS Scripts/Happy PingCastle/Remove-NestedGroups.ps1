<#

    List and remove Groups that are member of Domain Admin
    - To ensure transparency, I recommend NOT to use nested groups in the Builtin groups.

#>

# Set PDC as deault server
# ------------------------------------------------------------
$PSDefaultParameterValues = @{
    "*AD*:Server" = $(Get-ADDomain).PDCEmulator
}


# ------------------------------------------------------------
$PriviligeGroups = @("Administrators", "Domain Admins", "Enterprise Admins", "Schema Admins")


# Remove Nested Groups from High Privilige Groups.
# ------------------------------------------------------------
$AllNedtedGroups = @()
Foreach ($Group in $PriviligeGroups) {
    $GroupInfo = Get-ADGroup -Identity $Group
    $GroupMembers = $(Get-ADGroupMember -Identity $GroupInfo.distinguishedName | Where { $_.objectClass -eq "group" })

    Foreach ($Member in $GroupMembers) {

        If ( ($GroupInfo.Name -eq "Administrators") -and ( ($Member.Name -eq "Domain Admins") -or ($Member.Name -eq "Enterprise Admins") ) ) {
        } else {

            $NestedGroups = New-Object -TypeName psobject
            $NestedGroups | Add-Member -MemberType NoteProperty -Name "GroupName" -Value $GroupInfo.Name
            $NestedGroups | Add-Member -MemberType NoteProperty -Name "GroupNameCN" -Value $GroupInfo.distinguishedName
            $NestedGroups | Add-Member -MemberType NoteProperty -Name "NestedGroupCN" -Value $Member.distinguishedName

            $AllNedtedGroups += $NestedGroups
        }
    }
}

$SelectedGroups = $AllNedtedGroups | Out-GridView -Title "Select the groups to remove" -OutputMode Multiple

if ($null -ne $SelectedGroups) {

    $SelectedGroups | Foreach {
        Remove-ADGroupMember -Identity $_.GroupNameCN -Members $_.NestedGroupCN -Confirm:$false
    }

}
