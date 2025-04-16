<#

    Find all accounts that have DES enabled

    - If password havnt changed for 12 month, disable the account!

#>

# Define max password age.
# --------------------------------------------------
$PasswordAge = (Get-Date).AddMonths(-12)

# Find all Objects that have DES enabled.
# --------------------------------------------------
$DesEnabledObjects = Get-ADObject -Filter {UserAccountControl -band 0x200000 -or msDs-supportedEncryptionTypes -band 3} -Properties Name,pwdLastSet,whenCreated


# Disable ALL that have password older than defined Password age.
# --------------------------------------------------
$DesEnabledObjects | Where-Object { ([datetime]::FromFileTimeUtc($_.pwdLastSet)) -lt $PasswordAge } | Disable-ADAccount


# List the accounts where you need to take action.
# --------------------------------------------------
$DesEnabledObjects | Where-Object { ([datetime]::FromFileTimeUtc($_.pwdLastSet)) -lt $PasswordAge } | Select-Object Name,@{L="PasswordLastSet"; E={[datetime]::FromFileTimeUtc($_.pwdLastSet)}},DistinguishedName
