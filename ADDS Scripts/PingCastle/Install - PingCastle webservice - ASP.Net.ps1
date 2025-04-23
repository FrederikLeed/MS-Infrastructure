#RunAs Administrator
<#
    This script Installs IIS with the required features to support Windows authentication and authorization

    Create a Scheduled task that run the PingCastleAutoUpdate every Friday at 05:00
    Create a Scheduled task that run the PingCastle every day at 06:00

    Create two .aspx files in the created IIS Application directory to show the calender view and list findings.

#>


# --------------------------------------------------
# Active Directory Group - Allowed access to the web site
# - The Group have to be created in Active Directory
# --------------------------------------------------
param (
    [cmdletbinding()]
    [Parameter(ValueFromPipeline)]
    [string[]]$ADGroupName = "PingCastle Report Readers"
)


# --------------------------------------------------------------------------------
# Read registry keys for Windows version
# --------------------------------------------------------------------------------
$WindowsVersion = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion" | Select-Object ProductName, InstallationType, CurrentBuild, UBR


# --------------------------------------------------------------------------------
# Windows Feature list.
# --------------------------------------------------------------------------------
Switch ($WindowsVersion) {

    { (($_.ProductName) -Match("Windows Server 20(16|19|22|25)")) -And ($_.InstallationType -eq "Server") } {

        $ToolsToInstall = @(
            "Web-Server",
            "Web-WebServer",
            "Web-Common-Http",
            "Web-Default-Doc",
            "Web-Dir-Browsing",
            "Web-Http-Errors",
            "Web-Static-Content",
            "Web-Http-Redirect",
            "Web-Health",
            "Web-Http-Logging",
            "Web-Performance",
            "Web-Stat-Compression",
            "Web-Security",
            "Web-Filtering",
            "Web-Url-Auth",
            "Web-Windows-Auth",
            "Web-App-Dev",
            "Web-ASP",
            "Web-Net-Ext45",
            "Web-Asp-Net45",
            "Web-ISAPI-Ext",
            "Web-ISAPI-Filter",
            "NET-Framework-45-ASPNET",
            "Web-Mgmt-Tools",
            "Web-Mgmt-Console"
	        )
        Write-Verbose "Installing required Windows Features"
        Install-WindowsFeature -Name $ToolsToInstall -IncludeManagementTools
    }

    { (($_.ProductName) -Match("Windows 10")) -AND ($_.InstallationType -eq "Client") } {

        # Need to verify this is the correct list !
        $ToolsToInstall = @(
            "IIS-WebServerRole",
            "IIS-WebServer",
            "IIS-CommonHttpFeatures",
            "IIS-HttpErrors",
            "IIS-HttpRedirect",
            "IIS-Security",
            "IIS-HealthAndDiagnostics",
            "IIS-ApplicationDevelopment",
            "IIS-RequestFiltering",
            "IIS-HttpLogging",
            "IIS-Performance",
            "IIS-WebServerManagementTools",
            "IIS-URLAuthorization",
            "IIS-DefaultDocument",
            "IIS-DirectoryBrowsing",
            "IIS-ISAPIExtensions",
            "IIS-ISAPIFilter",
            "IIS-ASPNET",
            "IIS-ASPNET45",
            "IIS-WindowsAuthentication",
            "IIS-ManagementConsole",
            "IIS-ASP",
            "IIS-HttpCompressionStatic",
            "IIS-StaticContent"
	        )
        Write-Verbose "Installing required Windows Features"
        Enable-WindowsOptionalFeature -Online -FeatureName $ToolsToInstall
    }    
}


# --------------------------------------------------
# Create Folder structure
# --------------------------------------------------
Write-Verbose "Create Folders"
$BasePath = "$($ENV:SystemDrive)\InetPub\PingCastle"
If (!(Test-Path -Path $BasePath)) {
    Write-Verbose "Create Folders, $BasePath"
    New-Item -Path $BasePath -Itemtype Directory
}


# --------------------------------------------------
# Download PingCastle
# --------------------------------------------------
Write-Verbose "Download PingCastle"
$DownloadPath = "$($ENV:USERPROFILE)\Downloads"

# Get latest version download link and name
$LatestRelease = (Invoke-WebRequest -Uri "https://api.github.com/repos/vletoux/pingcastle/releases" -UseBasicParsing | ConvertFrom-Json)[0]
$Uri = $LatestRelease.assets.browser_download_url
$OutFile = $LatestRelease.assets.name

if (!(Test-Path -Path "$DownloadPath\$OutFile")) {
    Write-Verbose "Resolved latest stable version, $($LatestRelease.Name)"
    Invoke-WebRequest -Uri $Uri -OutFile "$DownloadPath\$OutFile" -UseBasicParsing
}


# --------------------------------------------------
# Extract PingCastle.
# --------------------------------------------------
$AppPath = "$($ENV:ProgramFiles)\PingCastle"
if (!(Test-Path -Path $AppPath)) {
    Write-Verbose "Create Folders, $AppPath"
    New-Item -Path $AppPath -ItemType Directory
}
if (!(Test-Path -Path "$AppPath\PingCastle.exe")) {
    Write-Verbose "Extract PingCastle to $AppPath"

    if (Test-Path -Path "$DownloadPath\$OutFile") {
        Expand-Archive -Path "$DownloadPath\$OutFile" -DestinationPath "$AppPath" -Force
    }

    # Dump all PingCaste rules, for refrence.
    if (Test-Path -Path "$AppPath\PingCastle.exe") {
        Write-Verbose "Create refrence HTML with all PingCastle rules"
        Start-Process -FilePath "$($ENV:ProgramFiles)\PingCastle\PingCastle.exe" -ArgumentList "--rules" -NoNewWindow -WorkingDirectory "$BasePath" -Wait
    }
}


# --------------------------------------------------
# Create Scheduled Task - PingCastle Auto Update
# --------------------------------------------------
Write-Verbose "Create PingCastle Auto Update Task"
$Scheduletrigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Friday -At "05:00"
$ScheduleSettings = New-ScheduledTaskSettingsSet
$ScheduleAction = New-ScheduledTaskAction -Execute "$($ENV:ProgramFiles)\PingCastle\PingCastleAutoUpdater.exe"
$SchedulePrincipal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Limited
$ScheduledTask = New-ScheduledTask -Action $ScheduleAction -Trigger $Scheduletrigger -Settings $ScheduleSettings -Principal $SchedulePrincipal
Register-ScheduledTask -TaskName "Run PingCastle Auto Update" -InputObject $ScheduledTask


# --------------------------------------------------
# Write "Create-Report.ps1"
# --------------------------------------------------
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SysAdminDk/MS-Infrastructure/refs/heads/main/ADDS%20Scripts/PingCastle/Scripts/Create-Report.ps1" -OutFile "$($ENV:ProgramFiles)\PingCastle\Create-Report.ps1" -UseBasicParsing


# --------------------------------------------------
# Create Scheduled Task
# --------------------------------------------------
Write-Verbose "Create PingCastle Scheduled Task"
$PowershellPath = "$(($ENV:PATH) -split(";") | Where {$_ -like '*Powershell*'})Powershell.exe"

$Scheduletrigger = New-ScheduledTaskTrigger -Daily -At "06:00"
$ScheduleSettings = New-ScheduledTaskSettingsSet
$ScheduleAction = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$($ENV:ProgramFiles)\PingCastle\Create-Report.ps1"
$SchedulePrincipal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Limited
$ScheduledTask = New-ScheduledTask -Action $ScheduleAction -Trigger $Scheduletrigger -Settings $ScheduleSettings -Principal $SchedulePrincipal
Register-ScheduledTask -TaskName "Run PingCastle - Daily" -InputObject $ScheduledTask


# --------------------------------------------------
# Create Web Application
# --------------------------------------------------
Write-Verbose "Create PingCastle IIS Application"
$DefaultSite = Get-IISSite
$DefaultAppPool = Get-IISAppPool
$Roles = "$($ENV:USERDOMAIN)\$ADGroupName"

$PingCastleWeb = New-WebApplication -Name "PingCastle" -Site $DefaultSite.name -PhysicalPath "$BasePath" -ApplicationPool $DefaultAppPool.Name

# Diasble Anonymous
Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication/anonymousAuthentication" -Name "enabled" -Value "false" -PSPath "IIS:\" -Location "$($DefaultSite.name)/$($PingCastleWeb.Name)"

# Enable Windows Authentication
Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication/windowsAuthentication" -Name "enabled" -Value "true" -PSPath "IIS:\" -Location "$($DefaultSite.name)/$($PingCastleWeb.Name)"

# Remove Default Authorization
$RemoveElement = @{
    users='*'
    roles=''
    verbs=''
}
Remove-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST/Default Web Site/PingCastle" -Filter 'system.webServer/security/authorization' -name '.' -AtElement $RemoveElement

# Add Group Authorization rule
$AddElement = @{
    accessType='Allow'
    roles=$Roles
}
Add-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST/Default Web Site/PingCastle" -Filter 'system.webServer/security/authorization' -name '.' -value 


# --------------------------------------------------
# Add the ASPNetHandler
# --------------------------------------------------
$HandlerSettings = @{
    name = "ASPNetHandler"
    path = "*.aspx"
    verb = "*"
    type = "System.Web.UI.PageHandlerFactory"
    modules = "ManagedPipelineHandler"
    resourceType = "Unspecified"
}
Add-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST/Default Web Site/PingCastle" -Filter 'system.webServer/handlers' -name '.' -value $HandlerSettings


# --------------------------------------------------
# Create Default.aspx
# --------------------------------------------------
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SysAdminDk/MS-Infrastructure/refs/heads/main/ADDS%20Scripts/PingCastle/Dashboards/Asp.Net/Default.aspx" -OutFile "$BasePath\Default.aspx" -UseBasicParsing


# --------------------------------------------------
# Create List.aspx
# --------------------------------------------------
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SysAdminDk/MS-Infrastructure/refs/heads/main/ADDS%20Scripts/PingCastle/Dashboards/Asp.Net/ListRules.aspx" -OutFile "$BasePath\ListRules.aspx" -UseBasicParsing
