#Requires -Modules "ActiveDirectory"
<#
    .DESCRIPTION
     Find and disable Inactive Users

#>

$DisableTimeSpan = 180
$PasswordAge = (Get-Date).AddMonths(-12)


# Usable Date formats.
# "dd-MM-yyyy", "yyyy-MM-dd", "MM-dd-yyyy", "MM/dd/yyyy", "yyyy/MM/dd", "dd/MM/yyyy"
# ------------------------------------------------------------
$DateFormat = $((Get-culture).DateTimeFormat).ShortDatePattern
$CurrentDate = Get-Date -Format $DateFormat
$LastLogon = (Get-Date).Adddays(-$DisableTimeSpan)


Try {
    # Change the Target OU to where you want the User Objects to be, until deleted.
    $TargetOU = Get-ADOrganizationalUnit -Identity "OU=DisabledUsers,OU=UserAccounts,OU=Company Endpoints,$((Get-ADDomain).DistinguishedName)"
}
Catch {
}


$Users = Get-ADUser -Filter { LastLogonTimeStamp -lt $LastLogon -and PasswordLastSet -lt $PasswordAge -and Enabled -eq 'True' } -Properties Description,PasswordLastSet
Foreach ($User in $Users) {
    Write-Verbose "Disable User : $($User.DistinguishedName)"

    Disable-ADAccount -Identity $User.DistinguishedName
    Set-AdUser -Identity $User.DistinguishedName -Description $("[Disabled, $CurrentDate] $($User.Description)") `
        -Replace @{AdminDescription="Location:$(($User.DistinguishedName).Split(",",2)[1])"}
    
    If ($Null -ne $TargetOU) {
        Move-ADObject -Identity $User.DistinguishedName -TargetPath $TargetOU.DistinguishedName
    }
}
