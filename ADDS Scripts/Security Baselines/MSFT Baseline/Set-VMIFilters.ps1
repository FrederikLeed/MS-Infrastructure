<#

    After the WMI filters have been created this adds the filter to the imported MSFT baselines.

    Prequisites.
    Run Import-MSFT-Baselines.ps1 to create the MSFT Baselines
    Run Create-WMIfilters.ps1 to create required WMI filters.


    Note this requires the names of GPOs and WMI filters to match what is in the scripts above..

#>


# OS versions in domain
# ------------------------------------------------------------
$OSVersions = @("2016","2019","2022","2025")


# Assign WMI Filters to MSFT GPOs
# ------------------------------------------------------------
$allWmiFilters = $(New-Object Microsoft.GroupPolicy.GPDomain).SearchWmiFilters($(New-Object Microsoft.GroupPolicy.GPSearchCriteria))


foreach ($OSVersion In $OSVersions) {

    $GPOs = Get-Gpo -All | Where {$_.DisplayName -like "*MSFT*$OSVersion*Member*"}
    if ($Null -ne $GPOs) {
        $GPOs | % {$_.WmiFilter = ($allWmiFilters | Where-Object {$_.Name -like "*$OSVersion*member*"})[0]}
    }

    $GPOs = Get-Gpo -All | Where {$_.DisplayName -like "*MSFT*$OSVersion*Domain Controller*"}
    if ($Null -ne $GPOs) {
        $GPOs | % {$_.WmiFilter = ($allWmiFilters | Where-Object {$_.Name -like "*$OSVersion*DC*"})[0]}
    }

}
