<#

    The purpose is to check if NTLMv1 or LM can be used by DC

    NTLMv1 is an old protocol which is known to be vulnerable to cryptographic attacks.
    It is typically used when a hacker sniffs the network and tries to retrieve NTLM hashes which can then be used to impersonate users.


    Custom Steps:

        1. Enable Auditing on NTLMv1

        2. Update Default Domain Policy and Default Domain Controller policy to "Send NTLMv2 response only. Refuse LM & NTLM"



#>


# Encoded ZIP file.
# ------------------------------------------------------------
$NTLMZIP = "Encoded string = Zip File"


# Extract GPOs
#------------------------------------------------------------
if (!(Test-Path -Path "$TxScriptPath\Scripts\NTLM.zip")) {
    Throw "Missing NTLM.zip, please copy it to $TxScriptPath\Scripts\Download"
    break
} else {
    Expand-Archive -Path "$TxScriptPath\Scripts\NTLM.zip" -DestinationPath "$TxScriptPath\Scripts\NTLM" -Force
}


# List the extracted GPOs
# ------------------------------------------------------------
$GPOList = Get-ChildItem -Path "$TxScriptPath\Scripts\NTLM" -Recurse -Directory -Filter "{*}"


# Import the Audit and Enforce GPO, and link them to Domain Root.
# - Enforce is NOT enabled !
# ------------------------------------------------------------
Foreach ($GPO in $GPOList) {
        $GPOGuid = $($GPO.Name)
        $GPOName = $([XML](Get-Content -Path "$($GPO.FullName)\backup.xml")).GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.DisplayName.InnerText

    if (!(Get-GPO -Name $GPOName -ErrorAction SilentlyContinue)) {
        Import-GPO -Path $(Split-Path -Path $($GPO.FullName) -Parent) -BackupId $(Split-Path -Path $($GPO.FullName) -Leaf) -CreateIfNeeded -TargetName $GPOName | Out-Null
        if ($GPOName -like "*NTLM Audit*") {
            $LinkEnabled = "Yes"
        } else {
            $LinkEnabled = "No"
        }
        Get-GPO -Name $GPOName | New-GPLink -Target (Get-ADDomain).DistinguishedName -Server $(Get-ADDomain).PDCEmulator -LinkEnabled $LinkEnabled | Out-Null
    }
}
