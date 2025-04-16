<#

    The purpose is to check for unusual value in the primarygroupid attribute used to store group membership

    Unless strongly justified, change the primary group id to its default:
        513 or 514 for users,
        516 or 521 for domain controllers,
        514 or 515 for computers.
    
    The primary group can be edited in a friendly manner by editing the account with the "Active Directory Users and Computers" and after selecting the "Member Of" tab, "set primary group".

#>

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
