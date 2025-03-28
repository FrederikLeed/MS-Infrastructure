param
(
    $TargetSid,
    $MemberSid,
    $ActionBy,
    $ActionByDomainName
)


# --
# Dateformats (For logging)
# --
$Date = (Get-Date -Format "dd-MM-yyyy hh:mm:ss")
$ScriptStart = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
$EventData = @()


# --
# We need the AD powershell module
# --
Import-Module ActiveDirectory -Force
<#
 $TargetSid = "S-1-5-21-2296055821-4046125481-3868048633-512"
 $TargetSid = "S-1-5-21-2296055821-4046125481-3868048633-519"
 $TargetSid = "S-1-5-21-2296055821-4046125481-3868048633-1116"

 $MemberSid = "S-1-5-21-2296055821-4046125481-3868048633-1604"
 $MemberSid = "S-1-5-21-2296055821-4046125481-3868048633-1603"
 $MemberSid = "S-1-5-21-2296055821-4046125481-3868048633-1602"
#>

# --
# Lookup group from SID
# --
$ADGroup = Get-ADGroup -Identity $TargetSid

# --
# Lookup member from SID
# --
$GroupMember = Get-ADUser -Identity $MemberSid


# --
# Logfile location
# --
if ($PSScriptRoot -eq $Null) {
    $LogFile = $PSScriptRoot + "\Logs\" + $ScriptStart + "_GroupMonitor.csv"
} else {
    $LogFile = "C:\TS-Data\Logs\" + $ScriptStart + "_GroupMonitor.csv"
}
# If more that one sessions is started witin same Millisecond, change filename
#$FileTestCount = ((Get-ChildItem -Path (Split-Path $LogFile -Parent) -Filter $ScriptStart*).FullName).Count
#If ($FileTestCount -ne 0) {
#    $Logfile = $Logfile -replace(".txt"," ($($FileTestCount+1)).txt")
#}
# Write CSV header to file
Add-Content -Path $LogFile -Value "Date;Domain\User;AD Group;Group Member;Action"


# --
# Only do stuff on selected Groups
# --
switch (($TargetSid -split("-"))[-1]) {
    # --
    # Domain Admins = S-1-5-21-2296055821-4046125481-3868048633-512
    # --
    512 {
        # --
        # Verify All other members have TTL
        # Skip Administrator, BreakGlassAdmin and SVC-Syslog
        # -
        $AllowedMembers = "Administrator|BreakGlassAdmin"
        $GroupMembers = (Get-ADGroup $TargetSid -Property member -ShowMemberTimeToLive).Member | Where {$_.Member -NotMatch $AllowedMembers}
        foreach ($Member in $GroupMembers) {
            # If there is no TTL, remove group member
            if ($Member -NotMatch '^<TTL\=[0-9]+>') {
                Remove-ADGroupMember -Identity "Domain Admins" -Members $($Member -replace("^<TTL\=[0-9]+>\,")) -Confirm:$false
                Add-Content -Path $LogFile -Value "$Date;$ActionByDomainName\$ActionBy;$($ADGroup.Name);$($GroupMember.Name);RemoveMember"
            }
        }

        Break
    }

    # --
    # Enterprise Admins = S-1-5-21-2296055821-4046125481-3868048633-519
    # --
    519 {
        # --
        # Verify All members have TTL
        # Skip Administrator
        # -
        $AllowedMembers = "Administrator"
        $GroupMembers = (Get-ADGroup $TargetSid -Property member -ShowMemberTimeToLive).Member | Where {$_.Member -NotMatch $AllowedMembers}
        foreach ($Member in $GroupMembers) {
            # If there is no TTL, remove group member
            if ($Member -NotMatch '^<TTL\=[0-9]+>') {
                Remove-ADGroupMember -Identity "Enterprise Admins" -Members "$($Member -replace("^<TTL\=[0-9]+>\,"))" -Confirm:$false
                Add-Content -Path $LogFile -Value "$Date;$ActionByDomainName\$ActionBy;$($ADGroup.Name);$($GroupMember.Name);RemoveMember"
            }
        }

        Break
    }

    # --
    # T0 - Domain Admin = S-1-5-21-2296055821-4046125481-3868048633-1110
    # --
    1110 {

        # --
        # Default TTL for Domain Admins
        # --
        $ttl = New-TimeSpan -Minutes 5

        # --
        # If New Member matches selected user type
        # Add user to Domain Admins with TTL
        # --
        if ($GroupMember.DistinguishedName -Like "*OU=Tier 0*") {
            Add-ADGroupMember -Identity "Domain Admins" -Members $GroupMember.DistinguishedName -MemberTimeToLive $ttl
            Add-Content -Path $LogFile -Value "$Date;$ActionByDomainName\$ActionBy;$($ADGroup.Name);$($GroupMember.Name);RemoveMember"
        }

        # --
        # Remove user from T0 - Domain Admin (Reset)
        # --
        Remove-ADGroupMember -Identity "T0 - Domain Admin" -Members $GroupMember.DistinguishedName -Confirm:$false
        Add-Content -Path $LogFile -Value "$Date;$ActionByDomainName\$ActionBy;T0 - Domain Admin;$($GroupMember.Name);Cleanup"

        Break
    }

    # --
    # T0 - Enterprise Admin = S-1-5-21-2296055821-4046125481-3868048633-1113
    # --
    1113 {

        # --
        # Default TTL for Enterprise Admins
        # --
        $ttl = New-TimeSpan -Minutes 5

        #$NewGroupMember = Get-Aduser -Identity $($GroupMember.DistinguishedName)
        # --
        # If New Member matches selected user type
        # Add user to Domain Admins with TTL
        # --
        if ($GroupMember.DistinguishedName -Like "*OU=Tier 0*") {
            Add-ADGroupMember -Identity "Domain Admins" -Members $GroupMember.DistinguishedName -MemberTimeToLive $ttl
            Add-Content -Path $LogFile -Value "$Date;$ActionByDomainName\$ActionBy;$($ADGroup.Name);$($GroupMember.Name);AddMember"
        }

        # --
        # Remove user from T0 - Domain Admin (Reset)
        # --
        Remove-ADGroupMember -Identity "T0 - Domain Admin" -Members $GroupMember.DistinguishedName -Confirm:$false
        Add-Content -Path $LogFile -Value "$Date;$ActionByDomainName\$ActionBy;$($ADGroup.Name);$($GroupMember.Name);RemoveMember"

        Break
    }

    # --
    # T0 - Group Management = S-1-5-21-2296055821-4046125481-3868048633-1116
    # --
    1116 {
        # --
        # Ensure only member is "SVC-Syslog"
        # -
        $GroupMembers = (Get-ADGroup $TargetSid -Property member -ShowMemberTimeToLive).Member | Where {$_ -notlike "CN=SVC-Syslog*"}
        foreach ($Member in $GroupMembers) {
            Remove-ADGroupMember -Identity $TargetSid -Members $Member -Confirm:$false
            Add-Content -Path $LogFile -Value "$Date;$ActionByDomainName\$ActionBy;$($ADGroup.Name);$($GroupMember.Name);RemoveMember"
        }

        Break
    }

    # --
    # If not one og the groups we need to manage, just quit.
    # --
    Default {
        exit
    } 
}

#$EventData | Out-File -FilePath $LogFile -Encoding utf8 -Append
$ScriptRunTime = $([DateTimeOffset]::Now.ToUnixTimeMilliseconds()) - $ScriptStart
foreach ($data in $eventdata) {
    Add-Content -Path $LogFile -Value "Runtime:$ScriptRunTime"
}

<#
Get-Variable TargetSid | Remove-Variable
Get-Variable MemberSid | Remove-Variable
Get-Variable ActionBy | Remove-Variable
Get-Variable ActionByDomainName | Remove-Variable
Get-Variable Date | Remove-Variable
Get-Variable ScriptStart | Remove-Variable
Get-Variable EventData | Remove-Variable
Get-Variable ADGroup | Remove-Variable
Get-Variable GroupMember | Remove-Variable
Get-Variable LogFile | Remove-Variable
Get-Variable GroupMembers | Remove-Variable
Get-Variable Member | Remove-Variable
Get-Variable ttl | Remove-Variable
Get-Variable ScriptRunTime | Remove-Variable
#>