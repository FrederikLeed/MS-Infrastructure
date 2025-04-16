# Get Group Domain Computers
# ------------------------------------------------------------
$PrimaryComputersGroup = Get-ADGroup "Domain Computers" -properties @("primaryGroupToken")
$DomainControllers = Get-ADComputer -Filter * -SearchBase (Get-ADDomain).DomainControllersContainer


# Find all users with other primary group
# - Skip Domain Controllers
# ------------------------------------------------------------
$Computers = Get-ADComputer -Filter "Enabled -eq 'True'" -Properties PrimaryGroup | Where-Object {
    $_.DistinguishedName -NotIn $DomainControllers.DistinguishedName -and $_.PrimaryGroup -ne $PrimaryComputersGroup.DistinguishedName
}


# Change primary group to Domain Users.
# ------------------------------------------------------------
foreach ($Computer in $Computers) {
    Get-ADComputer -Identity $Computer.DistinguishedName | Set-ADComputer -replace @{primaryGroupID=$PrimaryComputersGroup.primaryGroupToken}
}
