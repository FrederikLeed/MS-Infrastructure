<#
    .NOTES
        Name    : Import-MSFT-Baselines.ps1
        Author  : Jan Kristensen (Truesec)

        Version : 1.0
        Date    : 01-08-2022

        Version : 2.0
        Date    : 01-02-2025
        - Updated with new regex to extract the download URLs after the release of Server 2025 Baselines.

        Version : 2.1
        Date    : 20-09-2025
        - Added default import list, based on Server OS versions found in the Domain


    .DESCRIPTION
        Download and import selected security baselines from Microsoft Security Compliance Toolkit

    .PARAMETER DownloadID
        Specifies the ID from Microsoft Download
        - If Download ID have changed please find latest by searching for "Microsoft Security Compliance Toolkit"
        - Curent URL = https://www.microsoft.com/en-us/download/details.aspx?id=55319
                       https://www.microsoft.com/en-us/download/details.aspx?id=55319
        - Curent ID = 55319

    .PARAMETER Path 
        Specifies where the dowloaded files will be saved, extracted and imported from

    .PARAMETER Action
        Specifies which of the actions to preform.
        1. Download - Only download and extract til GPO files, requires internet access.
        2. Install - Only import the GPO files, requires the GPO folders to be avalible in Root of the Path, requires write access to Active Directory.
        3. DownloadAndInstall - Does both of the above actions, requires internet access and write access to Active Directory.

    .PARAMETER Cleanup 
        Specifies whether to remove the files after the script have run.

    .EXAMPLE
        .\Import-MSFT-Baselines.ps1 -DownloadID 55319 -Path "C:\Windows\temp" -Action Download -Cleanup

    .EXAMPLE
        .\Import-MSFT-Baselines.ps1 -DownloadID 55319 -Path "C:\Windows\temp" -Action Install -Cleanup

    .EXAMPLE
        .\Import-MSFT-Baselines.ps1 -DownloadID 55319 -Path "C:\Windows\temp" -Action DownloadAndInstall -Cleanup

    .EXAMPLE
        .\Import-MSFT-Baselines.ps1 -DownloadID 55319 -Path "C:\Windows\temp" -Action AutoInstall -Cleanup

#>
# 
# Request required script options.
# 
param (
    [Parameter(ValueFromPipeline)]
    [string]$DownloadID=55319,

    [Parameter(ValueFromPipeline)]
    $Path="C:\Windows\Temp",

    [Parameter(ValueFromPipeline)]
    [ValidateSet("Download","Install","DownloadAndInstall","AutoInstall")]
    $Action="DownloadAndInstall",

    [Parameter(ValueFromPipeline)]
    [object]$OSVersions=@("2022","2025"),

    [Parameter(ValueFromPipeline)]
    [switch]$Cleanup

)


#
# Create Output folders, if not exists
# ------------------------------------------------------------
if ( (!(Test-Path $Path)) -and ($Action -ne "Install") ) {
    Write-Verbose "Create download directory"
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
}

if ($Action -ne "Install") {
    if (!(Test-Path "$Path\ZIP")) {
        Write-Verbose "Create temp ZIP directory"
        New-Item -Path "$Path\ZIP" -ItemType Directory -Force | Out-Null
    }


    # Download MS Security Baselines
    # ------------------------------------------------------------
    Write-Verbose "Download MSFT security baselines"
    $HTML = Invoke-WebRequest -Uri "https://www.microsoft.com/en-us/download/details.aspx?id=$DownloadID" -UseBasicParsing

    $RegexPattern = '"url":"(https:\/\/download\.microsoft\.com\/[^"]+)"'
    $DownloadLinks = [regex]::Matches($HTML.Content, $RegexPattern)

    Foreach ($URI in $DownloadLinks) {
        $DownloadURI = $URI.Groups[1].Value
        $FileName = $DownloadURI.Split("/")[-1]

        Write-Verbose "Download $FileName"
        Invoke-WebRequest -Uri "$DownloadURI" -OutFile "$Path\ZIP\$FileName"
    }


    # Load Required Assembly "Compression"
    # ------------------------------------------------------------
    Write-Verbose "Extract the Group Policy files"
    [Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') | Out-Null


    # Extract ZIP file
    # ------------------------------------------------------------
    $Files = (Get-ChildItem -Path "$Path\ZIP\*")
    foreach ($File in $Files) {
        $DestinationFolder = $($File.Name -replace(".zip"))
        $ZipFile = [IO.Compression.ZipFile]::OpenRead($File.FullName)

        $ZipFile.Entries | ? { $_.FullName -like "*{*}*" } | ForEach-Object {
            $OutFile = Join-Path $Path $(Join-Path $DestinationFolder "{$(($_.FullName -split("{"))[1])")
            if (!(Test-Path -LiteralPath $(Split-Path $OutFile -Parent))) {
                New-Item -Path $(Split-Path $OutFile -Parent) -ItemType Directory -Force | Out-Null
            }

            if ($_ -notlike "*/") {
                [IO.Compression.ZipFileExtensions]::ExtractToFile($_, $OutFile, $true)
            }
        }
        $ZipFile.Dispose()
    }


    # Remove ZIP files
    # ------------------------------------------------------------
    if ($Cleanup -eq "Yes") {
        Remove-Item -Path "$Path\ZIP" -Recurse -Force
    }
}


# First part done, notify the we are done.
# ------------------------------------------------------------
if ($Action -eq "Download") {
    Write-Output "Copy `"$Path`" content to server with write access to Active Directory for import of the baseline GPOs"
}


if ($Action -ne "Download") {

    # Select Policy to import
    # ------------------------------------------------------------
    Write-Verbose "List all avaliable policy files"
    $GPOList = Get-ChildItem -Path $Path -Recurse -Directory -Filter "{*}"
    if ($GPOList.Length -eq 0) {
        Write-Error "Unable to find Policy to import"
        break
    }
    $GPOMap = @()
    Foreach ($GPO in $GPOList) {
        $GPOMap += New-Object -Type PSObject -Property @{
            'Guid'  = $($GPO.Name)
            'Package' = $($GPO.FullName).Replace("$Path\","").Split("\\")[0]
            'Name' = $(([XML](Get-Content -Path "$($GPO.FullName)\backup.xml")).GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.DisplayName.InnerText) -replace("SCM ","MSFT ")
        }
    }

    if ($Action -eq "AutoInstall") {
        if (-not ($OSVersions)) {
            # Find Server OS Versions in AD
            $OSVersions = Get-ADComputer -Filter "OperatingSystem -like '*Windows Server*'" -Properties OperatingSystem | `
                            Select-Object -ExpandProperty OperatingSystem -Unique | `
                            Where-Object { $_ -match '^(?:\D+)(\d{4})(?:\D+)$' } | `
                            ForEach-Object { [INT]$Matches[1] }
        }

        $Selected = $OSVersions | ForEach-Object {
            $OSVersion = $_ 
            $GPOMap | Select-Object -Property "Name","Guid","Package" | Where {$_.name -like "*$OSVersion*"}
        }


    } else {
        Write-Verbose "Show GPO list, please select which GPOs to import"
        $Selected = $($GPOMap | Select-Object -Property "Name","Guid","Package" | Sort-Object -Descending -Property "Package" | Out-GridView -OutputMode Multiple -Title "Select Group Policy(s) to import")
        if ($Selected.Length -eq 0) {
            Write-Error "Please select which GPOs to import"
            break
        }
    }

    # Import selected GPOs 
    # ------------------------------------------------------------
    Foreach ($GPO in $Selected) {
        $GpoPath = (Get-ChildItem -Path $Path -Recurse | Where {$_.Name -eq $($GPO.Guid)}).Parent
        Write-Output "Import GPO : `"$($GPO.Name)`""
        try {
            Import-GPO -BackupId $GPO.Guid -Path $GpoPath.FullName -TargetName "$($GPO.Name)" -CreateIfNeeded | Out-Null
        } catch {
            Write-Output "Unable to import GPO, please verify that you user have the required permissions"
            Write-Output $GpoPath.FullName
        }
    }

}


# Cleanup
# ------------------------------------------------------------
if ( ($Action -ne "Download") -and ($Cleanup -eq "Yes") ) {
    Write-Verbose "Cleanup policy folders"
    Get-ChildItem -Path $Path -Directory | Remove-Item -Recurse -Force
}
