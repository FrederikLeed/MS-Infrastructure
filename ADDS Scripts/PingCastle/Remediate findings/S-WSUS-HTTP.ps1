<#

    The purpose is to ensure that there is no access of WSUS server via HTTP

    WSUS needs to be configured with HTTPS

    
    ToDo.
    Request PKI cert.


#>

# Find any GPO with WSUS http configuration.
# --------------------------------------------------
$AllGPOs = Get-GPO -All
$FoundInGpo = @()
foreach ($GPO in $AllGPOs) {
    
    $
    if ($null -ne $(Get-GPRegistryValue -Name $GPO.DisplayName -Key "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" -ValueName WUServer -ErrorAction SilentlyContinue)) {
        $FoundInGpo += $GPO.DisplayName
    }

}


Write-Output "The following GPOs contain HTTP wsus configuration"
Write-Output "--------------------------------------------------`n"
$FoundInGpo
Write-Output "`n--------------------------------------------------"
Write-Output "If the policy or setting is nolonger in use, please remove it."


# Always break here
# --------------------------------------------------
break


<#

    Try to remidiate the finding.

    ! Run the steps manually

#>

# Default PKI Search base in AD
# --------------------------------------------------
$SearchBase = "CN=Public Key Services,CN=Services,CN=Configuration,$((Get-ADDomain).DistinguishedName)"


# Test if PKI is installed.
# --------------------------------------------------
$CAPath = Get-ADObject -Identity "CN=Certification Authorities,$SearchBase" -ErrorAction SilentlyContinue
if ($null -ne $CAPath) {
    $CAServers = Get-ChildItem -Path "AD:\$CAPath" | Where {$_.ObjectClass -eq "certificationAuthority"}
}

if ($null -eq $CAServers) {
    Write-Host "No CA/PKI installed, unable to request certificate"
}


# Test if PKI Webserver template exists.
# --------------------------------------------------
$Templates = Get-ADObject -LDAPFilter '(objectClass=pKICertificateTemplate)' -SearchBase "CN=Certificate Templates,$SearchBase" -Properties *displayName, pKIExtendedKeyUsage, 'msPKI-Template-Schema-Version' | Where-Object {
    $_.'msPKI-Template-Schema-Version' -gt 1 -and
    $_.pKIExtendedKeyUsage -eq "1.3.6.1.5.5.7.3.1" -and
    $_.Name -NotIn @("DomainControllerAuthentication","KerberosAuthentication")
} | Select-Object displayName, pKIExtendedKeyUsage


# Encure we can enroll
# --------------------------------------------------
(Get-Acl -Path "AD:\$($Templates[0].DistinguishedName)").Access
# If here is Deny on one of these, SKIP
## a05b8cc2-17bc-4802-a710-e7c15ab866a2 = Certificate-AutoEnrollment
## 0e10c968-78fb-11d2-90d4-00c04f79dc55 = Certificate-Enrollment


if ($Templates.Count -gt 0) {
    $SelectedTemplate = $Templates | Select-Object displayName, pKIExtendedKeyUsage | Out-GridView -Title "Select template to use for WebServer certificate" -OutputMode Single
}

if ($null -eq $SelectedTemplate) {
    Write-Host "Please select or create a WebServer certificate template"
}


# Get the Enrolment service.
# --
$PKIServer = Get-ADObject -LDAPFilter "(objectClass=pKIEnrollmentService)" -SearchBase "CN=Enrollment Services,$SearchBase" -Properties dNSHostName | Select-Object Name, dNSHostName, DistinguishedName
if ($PKIServer.count -gt 0) {
    $PKIServer = $PKIServer | Out-GridView -Title "Select the Issuing server" -OutputMode Single
}




