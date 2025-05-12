#Requires -Modules "ActiveDirectory"
<#
    .DESCRIPTION
     Find and disable Inactive Computers

#>

$DisableTimeSpan = ((Get-Date) - (Get-Date).AddMonths(-6)).Days


# Usable Date formats.
# "dd-MM-yyyy", "yyyy-MM-dd", "MM-dd-yyyy", "MM/dd/yyyy", "yyyy/MM/dd", "dd/MM/yyyy"
# ------------------------------------------------------------
$DateFormat = $((Get-culture).DateTimeFormat).ShortDatePattern
$CurrentDate = Get-Date -Format $DateFormat
$LastLogon = (Get-Date).Adddays(-$DisableTimeSpan)


Try {
    # Change the Target OU to where you want the Computer Objects to be, until deleted.
    $TargetOU = Get-ADOrganizationalUnit -Identity "OU=DisabledComputers,OU=UserAccounts,OU=Company Endpoints,$((Get-ADDomain).DistinguishedName)"
}
Catch {
}


$Computers = Get-ADComputer -Filter { LastLogonTimeStamp -lt $LastLogon -and Enabled -eq 'True' }  -Properties Description
Foreach ($Computer in $Computers) {
    Write-Verbose "Disable Computer : $($Computer.DistinguishedName)"

    Disable-ADAccount -Identity $Computer.DistinguishedName
    Set-ADComputer -Identity $Computer.DistinguishedName -Description $("[Disabled, $CurrentDate] $($Computer.Description)")`
        -Replace @{AdminDescription="Location:$(($Computer.DistinguishedName).Split(",",2)[1])"}

    If ($Null -ne $TargetOU) {
        Move-ADObject -Identity $Computer.DistinguishedName -TargetPath $TargetOU.DistinguishedName
    }
}

