# --------------------------------------------------
# List and remove Groups that are member of Domain Admin
#
# - To ensure transparency, dont use nested groups in the Builtin groups.
#
# --------------------------------------------------
$ClearGroups = Get-ADGroupMember -Identity "Domain Admins" | Where-Object {
    $_.objectClass -eq "group"
} | Select-Object -Property Name,DistinguishedName | Out-GridView -Title "Remove selected groups from Domain Admins" -OutputMode Multiple

if ($ClearGroups) {

    Remove-ADGroupMember -Identity "Domain Admins" -Members $ClearGroups.DistinguishedName -Confirm:$false

}
