<#
    .SYNOPSIS
    Restore GPO and optional GPO Links.


    .DESCRIPTION
    Find all unique exported GPOs in BackupPath.
    Show PS selection list of unique GPOs.
    Show Versions of selected GPO
    Restore selected gpo version.
    Restore selected GP Links.


    .PARAMETER BackupPath
    Set the folder where the export and reports will be stored.


    .EXAMPLE
    .\GPO-Restore.ps1 -BackupPath "Path to where GPO export is stored" -Verbose

#>

param (
    [parameter(ValueFromPipeline)][string]$BackupPath = "\\prod\shares\IT-Admin\GPO-Backup"
)


# Locate all GPOs in the BackupPath, Sort Unique Name, Select
# ------------------------------------------------------------
Write-Verbose "Listing all GPOs in the selected backup path"
$AllGPOs = Get-ChildItem -Path $BackupPath -Recurse -Filter "{*}"

Write-Verbose "Show selector with unique name list"
$Selected = $AllGPOs | Select-Object -Property @{Label="GPOName"; Expression={$_.Parent}},FullName | Sort-Object -Unique -Property GPOName | Out-GridView -OutputMode Single


# Select Version to restore
# -----------------------------------------------------------
Write-Verbose "If multiple versions show selector."
$Versions = $AllGPOs | Where { $_.fullname -like "*\$($Selected.GPOName)\*"} | Select-Object -Property @{Label="GPOName"; Expression={$_.Parent}}, @{Label="Backup Time"; Expression={$($_.Parent).Parent}}, FullName
if ($Versions.Count -gt 0) {
    $Restore = $Versions | Out-GridView -OutputMode Single
} else {
    $Restore = $Versions
}


# Restore selected GPO
# ------------------------------------------------------------
Write-Verbose "Import Selected"
Import-GPO -TargetName $Restore.GPOName.Name -Path $(Split-Path -Path $Restore.FullName) -BackupId $(Split-Path -Path $Restore.FullName -Leaf) -CreateIfNeeded | Out-Null
$GPOData = Get-GPO -Name $Restore.GPOName.Name


# Apply WMI Filter if exists
# ------------------------------------------------------------
Write-Verbose "Find and Apply WMI filter"
[xml]$GPReport = Get-Content -Path "$($Restore.FullName)\gpreport.xml"

$allWmiFilters = $(New-Object Microsoft.GroupPolicy.GPDomain).SearchWmiFilters($(New-Object Microsoft.GroupPolicy.GPSearchCriteria))
if ($null -ne ($GPOData).WmiFilter) {
    ($GPOData).WmiFilter = ($allWmiFilters | Where-Object {$_.Name -eq "$($GPReport.GPO.FilterName)"})[0]
}


# Apply GP Links
# ------------------------------------------------------------
Write-Verbose "Show GP Links selector"
$CanonicalNames = $GPReport.GPO.LinksTo
$OULinks = (Get-ADOrganizationalUnit -Filter * -Properties CanonicalName | Where {$_.CanonicalName -in $($CanonicalNames.SOMPath)}).DistinguishedName

Foreach ($GPLink in $($OULinks | Out-GridView -OutputMode Multiple)) {
    $OU = Get-ADOrganizationalUnit -Identity $GPLink -Properties CanonicalName
    $GPReportLink = $GPReport.GPO.LinksTo | Where {$_.SOMPath -eq $OU.CanonicalName}
    if ($($GPReportLink.Enabled) -eq "True") { $Enabled = "Yes" } else { $Enabled = "No" }
    if ($($GPReportLink.NoOverride -eq "true")) { $Enforced = "Yes" } else { $Enforced = "No" }
    
    New-GPLink -Name $Restore.GPOName.Name -Target $OU.DistinguishedName -LinkEnabled $Enabled -Enforced $Enforced -ErrorAction SilentlyContinue | Out-Null
}
