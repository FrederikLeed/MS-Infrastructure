<#

    Create Override GPO for all imported MSFT baselines, add/remove some settings that I ussaly do.

#>

# Get all MSFT GPOs, and create Override GPO with link enabled Before the Baseline.
# ------------------------------------------------------------
$RefGpos = (Get-GPO -All | Where {$_.DisplayName -like "*MSFT*Member Server"})
foreach ($RefGpo in $RefGpos) {
    try {
        $GPO = Get-GPO -Name "$($RefGpo.DisplayName) [Overrides]"
    }
    Catch {

        $GPO = New-GPO -Name "$($RefGpo.DisplayName) [Overrides]"
        Set-GPRegistryValue -Name $GPO.DisplayName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName "fPromptForPassword" -Value 0 -Type DWord | Out-Null
        (Get-GPO -Name $GPO.DisplayName).GpoStatus = "UserSettingsDisabled"


        # Get all OUs where the Baseline are linked and add the override GPO before
        # ------------------------------------------------------------
        [XML]$GPReport = Get-GPOReport -ReportType Xml -Guid $RefGpo.ID

        foreach ($SOMPath in $GPReport.GPO.LinksTo) {
            $SomPathArray = ($SOMPath.SOMPath -replace("$((Get-ADDomain).DNSRoot)/","")) -split("\/")
            [array]::Reverse($SomPathArray)
            $OUPath = (($SomPathArray | % { $("OU=$($_)")}) -Join(",")) + ",$((Get-ADDomain).DistinguishedName)"

            $LinkNumber = ((Get-GPInheritance -Target $OUPath).GpoLinks | Select-Object -Property Target,DisplayName,Enabled,Enforced,Order | Where {$_.DisplayName -eq $RefGpo.DisplayName}).Order

            New-GPLink -Name $GPO.DisplayName -Target $OUPath -LinkEnabled Yes -Order $($LinkNumber) | Out-Null
        }
    }
}
