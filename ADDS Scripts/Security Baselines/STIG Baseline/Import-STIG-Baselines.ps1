<#
    .NOTES
        Name    : Import-STIG-Baselines.ps1
        Author  : Jan Kristensen (Truesec)

        Version : 1.0
        Date    : 01-02-2025


    .DESCRIPTION
        Download and import selected security baselines from DOD (STIG)


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
        .\Import-STIG-Baselines.ps1 -Path "C:\Windows\temp" -Action Download -Cleanup

    .EXAMPLE
        .\Import-STIG-Baselines.ps1 -Path "C:\Windows\temp" -Action Install -Cleanup

    .EXAMPLE
        .\Import-STIG-Baselines.ps1 -Path "C:\Windows\temp" -Action DownloadAndInstall -Cleanup

#>
# 
# Request required script options.
#
param (
    [Parameter(ValueFromPipeline)]
    $Path=$PSScriptRoot,

    [parameter(ValueFromPipeline)]
    [switch]$Cleanup
)


#
# Create Output folders, if not exists
#
if (!(Test-Path $Path)) {
    Write-Verbose "Create download directory"
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
}


if ($Action -ne "Install") {
    if (!(Test-Path "$Path\ZIP")) {
        Write-Verbose "Create temp ZIP directory"
        New-Item -Path "$Path\ZIP" -ItemType Directory -Force | Out-Null
    }


    #
    # Download Security Baselines
    #
    Write-Verbose "Download STIG security baselines"
    $HTML = Invoke-WebRequest -Uri "https://public.cyber.mil/stigs/gpo/" -UseBasicParsing
    $DownloadLinks = ($HTML.Links | Where {$_ -like "*STIG_GPO*"}).href

    Foreach ($URI in $DownloadLinks) {
        $DownloadURI = $URI
        $FileName = $DownloadURI.Split("/")[-1]

        Write-Verbose "Download $FileName"
        Invoke-WebRequest -Uri "$DownloadURI" -OutFile "$Path\ZIP\$FileName"
    }

    #
    # Extract GPO baselines
    #
    Write-Verbose "Extract the Group Policy files"
    [Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') | Out-Null

    # Get ZIP files to extract
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


    #
    # Remove ZIP files
    #
    if ($Cleanup -eq "Yes") {
        Remove-Item -Path "$Path\ZIP" -Recurse -Force
    }
}

#
# First part done, notify the we are done.
#
if ($Action -eq "Download") {
    Write-Output "Copy `"$Path`" content to server with write access to Active Directory for import of the baseline GPOs"
}


if ($Action -ne "Download") {
    #
    # Select Policy to import
    #
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
    Write-Verbose "Show GPO list, please select which GPOs to import"
    $Selected = $($GPOMap | Select-Object -Property "Name","Guid","Package" | Sort-Object -Descending -Property "Package" | Out-GridView -OutputMode Multiple -Title "Select Group Policy(s) to import")
    if ($Selected.Length -eq 0) {
        Write-Error "Please select which GPOs to import"
        break
    }


    #
    # Import selected GPOs 
    #
    Foreach ($GPO in $Selected) {
        $GpoPath = (Get-ChildItem -Path $Path -Recurse | Where {$_.Name -eq $($GPO.Guid)}).Parent
        Write-Verbose "Import GPO : `"$($GPO.Name)`""
        try {
            Import-GPO -BackupId $GPO.Guid -Path $GpoPath.FullName -TargetName "$($GPO.Name)" -CreateIfNeeded | Out-Null
        } catch {
            Write-Output "Unable to import GPO, please verify that you user have the required permissions"
            Write-Output $_
        }
    }

}


#
# Cleanup
#
if ( ($Action -ne "Download") -and ($Cleanup -eq "Yes") ) {
    Write-Verbose "Cleanup policy folders"
    Get-ChildItem -Path $Path -Directory | Remove-Item -Recurse -Force
}



