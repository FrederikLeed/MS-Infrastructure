<#
    
    Update Imported Baselines.

#>

# List existing all MSFT Baselines.
# ------------------------------------------------------------
$GPOs = Get-GPO -all | Where {$_.DisplayName -Like "*MSFT*"}


# Execute the Import-MSFT-Baselines script to DOWNLOAD all the baselines.
# ------------------------------------------------------------
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SysAdminDk/MS-Infrastructure/refs/heads/main/ADDS%20Scripts/Security%20Baselines/MSFT%20Baseline/Import-MSFT-Baselines.ps1" -OutFile "$($env:TEMP)\Import-MSFT-Baselines.ps1"
& "$($env:TEMP)\Import-MSFT-Baselines.ps1" -DownloadID 55319 -Path $($env:TEMP) -Action Download -Cleanup


# Verify that we have the required files.
# ------------------------------------------------------------
$GPOList = Get-ChildItem -Path $($env:TEMP) -Recurse -Directory -Filter "{*}"
if ($GPOList.Length -eq 0) {
    Write-Error "Unable to find Policy to import"
    break
}

# Find and import existing baselines.
# ------------------------------------------------------------
Foreach ($GPO in $GPOList) {
    $ImportGPO = New-Object -Type PSObject -Property @{
        'Guid'  = $($GPO.Name)
        'Name' = $(([XML](Get-Content -Path "$($GPO.FullName)\backup.xml")).GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.DisplayName.InnerText) -replace("SCM ","MSFT ")
    }
    
    if ($ImportGPO.Name -in $GPOs.DisplayName) {
        Write-Host "Import $($ImportGPO.name)"
        
        $GPOPath = Split-Path $($GPO.FullName) -Parent
        Import-GPO -BackupId $($ImportGPO.guid) -Path $GPOPath -TargetName "$($ImportGPO.name)" -CreateIfNeeded | Out-Null

    }
}
