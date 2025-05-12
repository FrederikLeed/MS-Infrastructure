<#
    .SYNOPSIS
    Backup all GPO's that have changed since last time this script have run (Using the same BackupFolder)


    .DESCRIPTION
    Exports and document the GPO's in Active Directory, write an CSV file with information about where each GPO are linked, and saves a HTML GPO report of each.
    - If there are any files in the SCRIPTS folder in the GPO, they will be copied to the backup folder.


    .PARAMETER BackupPath
    Set the folder where the export and reports will be stored.


    .EXAMPLE
    .\GPO-Export-and-Backup.ps1 -BackupPath "Path to where GPO export is stored" -Verbose

#>

param (
    [parameter(ValueFromPipeline)][string]$BackupPath = $PSScriptRoot,
    [parameter(ValueFromPipeline)][string]$Delimiter = (Get-Culture).TextInfo.ListSeparator,
    [switch]$AutoCorrect
)


# Try to get the latest export date.
# ------------------------------------------------------------
Write-Verbose "Find latest GPO backup in $BackupPath"
try {
    $LatestExportTime = $(Get-Date -Date ((Get-ChildItem -Path $BackupPath | Sort-Object CreationTime -Descending | Select-Object -First 1).LastWriteTime) -Format "yyyy-MM-dd HH:mm")
}
Catch {
    $LatestExportTime = "01-01-1970 00:00"
}


# Import modules
# ------------------------------------------------------------
Write-Verbose "Import Required modules"
Import-Module ActiveDirectory


# Get Domain Info
# ------------------------------------------------------------
Write-Verbose "Get Domain info and find/makeup SysVol Path"
$Domain = Get-ADDomain
$SysVolFolder = "\\" + $($Domain.DNSRoot) + "\sysvol\" + $($Domain.DNSRoot) + "\Policies\"


# Backup changed Group Policies
# ------------------------------------------------------------
Write-Verbose "Get GPO's changed since $LatestExportTime"
$GPOs = Get-GPO -All | Where { $_.ModificationTime -gt $LatestExportTime }


# Create backup folder if there are any changes.
# ------------------------------------------------------------
$FileDate = (Get-Date -Format "yyyy-MM-dd HH.mm")
$GpoFilePath = $($BackupPath + "\" + $FileDate)
If ( (!(Test-Path -Path $GpoFilePath)) -AND ($GPOs.Count -gt 0) ) {
    New-Item -Path $GpoFilePath -ItemType Directory | Out-Null
}


$OutReport = @()
$ErrorReport = @()
Foreach ($GPO in $GPOs) {
    Write-Verbose "Export $($GPO.DisplayName)"


    # Verify GPO Displayname can be used as Folder Name
    # ------------------------------------------------------------
    if ($($GPO.DisplayName) -match '[<>:"/\\|?*\x00-\x1F]|\s$|^\s|\.$') {
        $ErrorReport += "`"$($GPO.DisplayName)`" have leading, traling spaces or invalid chars in the displayname"


        # Sanitize GPO Name
        # ------------------------------------------------------------
        $GPODisplayName = $GPO.DisplayName -replace '[<>:"/\\|?*\x00-\x1F]', '_'
        $GPODisplayName = $GPODisplayName.TrimEnd(' ', '.')


        # Autocorrect GPO DisplayName
        # ------------------------------------------------------------
        if ($AutoCorrect) {
            $OriginalName = $GPO.DisplayName
            $GPO.DisplayName = $GPO.DisplayName -replace '[<>:"/\\|?*\x00-\x1F]', '_'
            $GPO.DisplayName = $GPO.DisplayName.Trim()

            Write-Verbose "Auto-corrected GPO name: '$OriginalName' => '$($GPO.DisplayName)'"
        }

    } else {
        $GPODisplayName = $GPO.DisplayName
    }


    if (!(Test-Path -Path "$GpoFilePath\$GPODisplayName")) {
        New-Item -Path "$GpoFilePath\$GPODisplayName" -ItemType Directory | Out-Null
    }
    Backup-GPO -Guid $GPO.ID -Path "$GpoFilePath\$GPODisplayName" | Out-Null

    $UserPolicyFiles = Get-ChildItem -Path $($SysVolFolder + "{" + $($GPO.ID) + "}\User\Scripts") -File -Recurse
    if ($UserPolicyFiles.Count -ne 0) {
        Write-Verbose "Copy scripts from $GPODisplayName User"
        New-Item -Path "$GpoFilePath\$GPODisplayName\UserFiles" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
        Copy-Item -Path $($SysVolFolder + "{" + $($GPO.ID) + "}\User\Scripts") -Destination $($GpoFilePath + "\" + $GPODisplayName + "\UserFiles") -Recurse | Out-Null
    }

    $ComputerPolicyFiles = Get-ChildItem -Path $($SysVolFolder + "{" + $($GPO.ID) + "}\Machine\Scripts") -File -Recurse
    if ($ComputerPolicyFiles.Count -ne 0) {
        Write-Verbose "Copy scripts from $GPODisplayName Machine"
        New-Item -Path "$GpoFilePath\$GPODisplayName\MachineFiles" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
        Copy-Item -Path $($SysVolFolder + "{" + $($GPO.ID) + "}\Machine\Scripts") -Destination $($GpoFilePath + "\" + $GPODisplayName + "\MachineFiles") -Recurse | Out-Null
    }

    Write-Verbose "Create GPO HTML report"
    [XML]$GPReport = Get-GPOReport -ReportType Xml -Guid $GPO.ID
    Get-GPOReport -ReportType Html -Guid $GPO.ID -Path $($GpoFilePath + "\" + $GPODisplayName + "\" + $($GPO.DisplayName) + ".html")

    Write-Verbose "Document the OU's where the Policy is linked"
    if (($GPReport.GPO.LinksTo).Count -eq 0) {
        $OutReport += [PSCustomObject]@{
        "Name" = $GPReport.GPO.Name
        "Link" = ""
        "Link Enabled" = ""
        "ComputerEnabled" = $GPReport.GPO.Computer.Enabled
        "UserEnabled" = $GPReport.GPO.User.Enabled
        "WmiFilter" = $GPO.WmiFilter
        "GpoApply" = (Get-GPPermissions -Guid $GPO.ID -All | Where {$_.Permission -eq "GpoApply"}).Trustee.Name
        "SDDL" = $($GPReport.GPO.SecurityDescriptor.SDDL.'#text')
        }
    } else {

        foreach ($i in $GPReport.GPO.LinksTo) {
            $OutReport += [PSCustomObject]@{
            "Name" = $GPReport.GPO.Name
            "Link" = $i.SOMPath
            "Link Enabled" = $i.Enabled
            "ComputerEnabled" = $GPReport.GPO.Computer.Enabled
            "UserEnabled" = $GPReport.GPO.User.Enabled
            "WmiFilter" = $GPO.WmiFilter
            "GpoApply" = (Get-GPPermissions -Guid $GPO.ID -All | Where {$_.Permission -eq "GpoApply"}).Trustee.Name
            "SDDL" = $($GPReport.GPO.SecurityDescriptor.SDDL.'#text')
            }
        }

    }

}

if ($OutReport.count -ge 1) {
    $OutReport | Export-Csv -Path "$(Split-Path -Path $GpoFilePath -Parent)\$FileDate-GPO-Link-Report.csv" -NoTypeInformation -Delimiter $Delimiter -Encoding UTF8
}
if ($ErrorReport.count -ge 1) {
    $ErrorReport | Out-File -FilePath "$(Split-Path -Path $GpoFilePath -Parent)\$FileDate-Error-Report.log"
}
