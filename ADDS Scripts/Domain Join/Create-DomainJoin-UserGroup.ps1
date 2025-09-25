<# 

    Create Domain Join User and Delegate permissions.

#>

Import-Module "C:\<path>\ADTiering\TSxTieringModule\TSxTieringModule.psm1" -Force

$ADDistinguishedName = (Get-ADDomain).DistinguishedName


$JoinUserName = "Domain Join" -split(" ")
$JoinUserAccount = "AD-Comp-Join"
$JoinGroup = "Domain Join Users"
$JoinOU = "OU=ComputerQuarantine,$ADDistinguishedName"



New-TSxServiceAccount -FirstName $JoinUserName[0] -LastName $JoinUserName[1] -AccountName $JoinUserAccount -UserType User -AccountType T1SVC
New-TSxADGroup -Name $JoinGroup -Path "OU=Groups,OU=Tier1,OU=Admin,$ADDistinguishedName" -GroupCategory Security -GroupScope Global -Description "Members can domain join to $JoinOU" | Out-Null
Add-ADGroupMember -Identity $JoinGroup -Members $JoinUserAccount

Set-TSxOUPermission -OrganizationalUnitDN "OU=ComputerQuarantine,$ADDistinguishedName" -GroupName $JoinGroup -ObjectType ComputersCreate
& redircmp.exe "OU=ComputerQuarantine,$ADDistinguishedName"
