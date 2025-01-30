<#
    .DISCLAIMER

    THE SCRIPT IS PROVIDED AS-IS, WITHOUT WARRANTY OF ANY KIND. USE AT YOUR OWN RISK.

    By running this script, you acknowledge that you have read and understood the disclaimer, and you agree to assume
    all responsibility for any failures, damages, or issues that may arise as a result of executing this script.

    .DESCRIPTION
    


    .PARAMETER PartnerServer 
    Specifies the "Master" DHCP server, where DHCP Services and Scopes already exists.

    
    .EXAMPLE
    .\Add-DHCP-Failover.ps1 -PartnerServer DHCP-01.$($ENV:UserDNSDomain)

#>
[CmdletBinding()]
Param(
  [Parameter(ValueFromPipelineByPropertyName=$true,Position=0,mandatory=$true)]
  [string]$PartnerServer
)


<# ----- #>

# Verify Domain Membership.
# ------------------------------------------------------------
try {
    $DomainName = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
}
Catch {
    Throw "Computer not a member of any domain"
    Break
}


# Restart the script as Admin, if needed.
# ------------------------------------------------------------
$CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
If (!($CurrentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {

    Write-Warning "Not running as Administrator, restarting script"

    $ScriptHost = If ($PSVersionTable.PSVersion.Major -le 5) {'PowerShell'} Else {'PwSh'}
    $ScriptFile = $($MyInvocation.MyCommand.Path)
    $ScriptArguments = ($PSCmdlet.MyInvocation.BoundParameters.GetEnumerator() | ForEach-Object { "-$($_.Key) $($_.Value)" }) -Join(" ")
    
    Start-Process $ScriptHost -ArgumentList " -ExecutionPolicy Bypass -File `"$ScriptFile`" $ScriptArguments" -Verb RunAs

    for($i=0; $i -le 5; $i++) {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 1
    }
    break
}


# Verify the user have Permissions, if not Ask for credentials.
# ------------------------------------------------------------
$CurrentGroups = @()
[System.Security.Principal.WindowsIdentity]::GetCurrent().Groups | ForEach-Object -Process {
    $CurrentGroups += $_.Translate([System.Security.Principal.NTAccount]).Value;
}
If ($CurrentGroups -NotContains "PROD\Domain Admins") {
    $Credentials = $(Get-Credential -Message "BreakGlass Admin Credentials")
}


<# ----- #>


# Authorize new DHCP server
# ------------------------------------------------------------
Try {
    if ($null -eq $Credentials) {
        Add-DHCPServerInDC
    } else {
        Invoke-Command -ScriptBlock {
            Add-DHCPServerInDC
        } -Credential $Credentials
    }
} catch {
    Write-Output $_
}


# Add to DHCP scope Failower..
# ------------------------------------------------------------
$DHCPSharedSecret = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 35 | ForEach-Object {[char]$_})
$DHCPScopes = Get-DhcpServerv4Scope -ComputerName $PartnerServer
Add-DhcpServerv4Failover -ComputerName $PartnerServer -Name "DHCP-Failover" -PartnerServer "$($env:COMPUTERNAME).$($ENV:UserDNSDomain)" -ScopeId $DHCPScopes.ScopeId -SharedSecret $DHCPSharedSecret -Force
