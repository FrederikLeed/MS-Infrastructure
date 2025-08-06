<#
.SYNOPSIS

.DESCRIPTION
    Simple script with GUI to find Windows and Legacy LAPS password from Active Directory


.NOTES
    FileName: TSxLapsUI.ps1
    Author: Jan kristensen
    Created: 2024-10-18

    Version - 0.5 - 2024-10-18
    Version - 0.7 - 2024-10-20
        - Removed requirement for Microsoft LAPS Powershell module (AdmPWD.PS)
          Changed to ADSI lookup.
        - Add Check for Domain Member
        - Add Windows Laps Unencrypted, no history.
    Version - 0.8 - 2025-06-27
        - Add Phonetic Alphabet view option.

    License Info:
    MIT License
    Copyright (c) 2024 TRUESEC

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.


.EXAMPLE
    TSxLapsUI.ps1

#>

# Ensure script is running on a Domain Member
# ------------------------------------------------------------
if (!(gwmi win32_computersystem).partofdomain) {
    Throw "Running on Workgroup machine, unable to continue"
}

# Phonetic Alphabet array.
# ------------------------------------------------------------
$PhoneticArray = @{'A'=' Alpha ';'B'=' Bravo ';'C'=' Charlie ';'D'=' Delta ';'E'=' Echo ';'F'=' Foxtrot ';'G'=' Golf ';'H'=' Hotel ';'I'=' India ';'J'=' Juliet ';'K'=' Kilo ';'L'=' Lima ';'M'=' Mike ';'N'=' November ';'O'=' Oscar ';'P'=' Papa ';'Q'=' Quebec ';'R'=' Romeo ';'S'=' Sierra ';'T'=' Tango ';'U'=' Uniform ';'V'=' Victory ';'W'=' Whiskey ';'X'=' X-ray ';'Y'=' Yankee ';'Z'=' Zulu ';'0'=' Zero ';'1'=' One ';'2'=' Two ';'3'=' Three ';'4'=' Four ';'5'=' Five ';'6'=' Six ';'7'=' Seven ';'8'=' Eight ';'9'=' Nine '}



# Action on the Search button
# ------------------------------------------------------------
$DoSearch = {
    Write-Debug "$($ComputerName.Text)"

    try {
        $LapsData = Get-LapsADPassword -Identity $($ComputerName.Text) -AsPlainText -ErrorAction SilentlyContinue
    }
    catch {
    }

    # Extract data..
    # ------------------------------------------------------------
    if ($null -ne $LapsData.Password) {

        Write-Debug "Windows LAPS password is : $($LapsData.Password)"
        $LapsPassword.Text = $LapsData.Password

        Write-Debug "Expiration date  : $($LapsData.ExpirationTimestamp)"
        $Expiration.Text = $($LapsData.ExpirationTimestamp.DateTime)    

        if ($LapsData.Source -eq "EncryptedPassword") {

            Write-Debug "PW Source is Windows Laps - EncryptedPassword"
            $global:Source = "Encrypted"
            $HistoryButton.Show()
            $PhoneticButton.Show()

        } else {

            Write-Debug "PW Source - LegacyLapsCleartextPassword or CleartextPassword"
            $global:Source = "Cleartext"
            $HistoryButton.Hide()
            $PhoneticButton.Show()
        }

    } else {
        $LapsPassword.Text = "Host not found"
        $Expiration.Text = ""

        Write-Debug "No LAPS password found"
    }

}

$DoList = {
    # ToDo

    # 
    Add-Type -AssemblyName System.DirectoryServices

    # Get current user
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $samAccountName = $currentUser.Split("\")[-1]

    # Retrieve user's group memberships
    $userSearcher = New-Object DirectoryServices.DirectorySearcher
    $userSearcher.Filter = "(&(objectCategory=User)(samAccountName=$samAccountName))"
    $userSearcher.PropertiesToLoad.Add("memberof") | Out-Null
    $userResult = $userSearcher.FindOne()

    $groups = @()
    foreach ($group in $userResult.Properties["memberof"]) {
        $groups += $group
    }

    # Search for computers where these groups have LAPS read permissions
    $computerSearcher = New-Object DirectoryServices.DirectorySearcher
    $computerSearcher.Filter = "(&(objectCategory=computer))"
    $computerSearcher.PropertiesToLoad.Add("name") | Out-Null

    $results = $computerSearcher.FindAll()
    $accessibleComputers = @()

    if ($groups -match "CN=Domain Admins") {

        $accessibleComputers = $results | % { $_.Properties["name"][0] }

    } else {

        foreach ($result in $results) {
            $computerEntry = [ADSI]"$($result.Path)"
            $acl = $computerEntry.psbase.ObjectSecurity.Access

            foreach ($ace in $acl) {
                foreach ($group in $groups) {
                    if ($ace.IdentityReference -match $group -and `
                        ($ace.ActiveDirectoryRights -match "ReadProperty")) {
                        $accessibleComputers += $result.Properties["name"][0]
                    }
                }
            }
        }

    }

    # Output computers where user has access
    $accessibleComputers


}

$DoExpire = {
    Write-Debug $NewExpiration.Value
    Write-Debug "Source : $Source"

    if ($Source -eq "Encrypted") {
        Write-Debug "Windows Laps PW Change"
        Set-LapsADPasswordExpirationTime -Identity $($ComputerName.Text) -WhenEffective $NewExpiration.Value
    } else {
    
        # Test if Real Legacy.
        $objSearch=[ADSISEARCHER]"(&(objectCategory=computer)(CN= $($ComputerName.Text)))"
        @("ms-Mcs-AdmPwd","ms-Mcs-AdmPwdExpirationTime","description") | foreach { $objSearch.PropertiesToLoad.Add($_) | Out-Null }
        $objComputer = $objSearch.FindOne()

        if ($Null -ne $($objComputer.Properties.'ms-mcs-admpwd')) {
            Write-Debug "Legacy Laps PW Change"

            $ComputerObject = [ADSI]"$($objComputer.Properties.adspath)"
            $ComputerObject.'ms-mcs-admpwdexpirationtime' = "$((Get-Date $($NewExpiration.Value).addYears(-1600)).Ticks)"
            $ComputerObject.SetInfo()

        } else {
            Write-Debug "reset with Windows Laps"
            Set-LapsADPasswordExpirationTime -Identity $($ComputerName.Text) -WhenEffective $NewExpiration.Value
        }
    }
}

$ShowPhonetic = {

    # Phonetic Password window
    # ------------------------------------------------------------
    $Phoneticform = New-Object System.Windows.Forms.Form
    $Phoneticform.Text = 'TS - Phonetic Password Window'
    $Phoneticform.Size = New-Object System.Drawing.Size(566,303)
    $Phoneticform.StartPosition = 'CenterScreen'
    $Phoneticform.FormBorderStyle = 'FixedDialog'
    $Phoneticform.MaximizeBox = $false
    $Phoneticform.MinimizeBox = $false

    ##
    $PhoneticLabel = New-Object System.Windows.Forms.Label
    $PhoneticLabel.Location = New-Object System.Drawing.Point(10,15)
    $PhoneticLabel.Size = New-Object System.Drawing.Size(450,15)
    $PhoneticLabel.Text = 'Phonetic Alphabet Password'
    $Phoneticform.Controls.Add($PhoneticLabel)


    $PhoneticPassword = New-Object System.Windows.Forms.textbox # ListBox
    $PhoneticPassword.Location = New-Object System.Drawing.Point(12,30)
    $PhoneticPassword.Size = New-Object System.Drawing.Size(530,190)
    $PhoneticPassword.Font = (New-Object System.Drawing.Font("Arial", 12))
    $PhoneticPassword.Multiline = $true
    $PhoneticPassword.ReadOnly = $True
    $PhoneticPassword.TabStop = $False
    $Phoneticform.Controls.Add($PhoneticPassword)


    $PhoneticPassword.Text = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" 


    $exitButton = New-Object System.Windows.Forms.Button
    $exitButton.Location = New-Object System.Drawing.Point(470,225)
    $exitButton.Size = New-Object System.Drawing.Size(73,22)
    $exitButton.Text = 'Exit'
    $Phoneticform.CancelButton = $exitButton
    $Phoneticform.Controls.Add($exitButton)

    $Phoneticform.ShowDialog() | Out-Null
}

$SnowHistory = {

    # Password History window
    # ------------------------------------------------------------
    $Historyform = New-Object System.Windows.Forms.Form
    $Historyform.Text = 'TS - Local Administrator Password History'
    $Historyform.Size = New-Object System.Drawing.Size(566,303)
    $Historyform.StartPosition = 'CenterScreen'
    $Historyform.FormBorderStyle = 'FixedDialog'
    $Historyform.MaximizeBox = $false
    $Historyform.MinimizeBox = $false

    $EntryAccountLabel = New-Object System.Windows.Forms.Label
    $EntryAccountLabel.Location = New-Object System.Drawing.Point(10,15)
    $EntryAccountLabel.Size = New-Object System.Drawing.Size(100,15)
    $EntryAccountLabel.Text = 'Account name:'
    $Historyform.Controls.Add($EntryAccountLabel)

    $EntryPasswordLabel = New-Object System.Windows.Forms.Label
    $EntryPasswordLabel.Location = New-Object System.Drawing.Point(152,15)
    $EntryPasswordLabel.Size = New-Object System.Drawing.Size(100,15)
    $EntryPasswordLabel.Text = 'Password:'
    $Historyform.Controls.Add($EntryPasswordLabel)

    $EntryUpdateTimeLabel = New-Object System.Windows.Forms.Label
    $EntryUpdateTimeLabel.Location = New-Object System.Drawing.Point(292,15)
    $EntryUpdateTimeLabel.Size = New-Object System.Drawing.Size(100,15)
    $EntryUpdateTimeLabel.Text = 'Update Time:'
    $Historyform.Controls.Add($EntryUpdateTimeLabel)

    # Get the history data.
    # ------------------------------------------------------------
    $HistoryData = Get-LapsADPassword -Identity $($ComputerName.Text) -IncludeHistory -ErrorAction SilentlyContinue

    if ($($HistoryData.Count) -eq 1) {
        
        $EntryUpdateNoHistory = New-Object System.Windows.Forms.TextBox
        $EntryUpdateNoHistory.Location = New-Object System.Drawing.Point(12,33)
        $EntryUpdateNoHistory.Size = New-Object System.Drawing.Size(100,15)
        $EntryUpdateNoHistory.Text = 'No History'
        $EntryUpdateNoHistory.ReadOnly = $True
        $Historyform.Controls.Add($EntryUpdateNoHistory)

    }

    $Location = 33
    foreach ($Entry in $HistoryData[0..8]) {
        
        $EntryAccount = New-Object System.Windows.Forms.TextBox
        $EntryAccount.Location = New-Object System.Drawing.Point(12,$Location)
        $EntryAccount.Size = New-Object System.Drawing.Size(100,20)
        $EntryAccount.Text = $Entry.Account
        $EntryAccount.ReadOnly = $True
        $Historyform.Controls.Add($EntryAccount)

        $EntryPassword = New-Object System.Windows.Forms.TextBox
        $EntryPassword.Location = New-Object System.Drawing.Point(152,$Location)
        $EntryPassword.Size = New-Object System.Drawing.Size(100,20)
        $EntryPassword.Text = (New-Object PSCredential 0, $Entry.Password).GetNetworkCredential().Password
        $EntryPassword.ReadOnly = $True
        $Historyform.Controls.Add($EntryPassword)

        $EntryUpdateTime = New-Object System.Windows.Forms.TextBox
        $EntryUpdateTime.Location = New-Object System.Drawing.Point(292,$Location)
        $EntryUpdateTime.Size = New-Object System.Drawing.Size(150,20)
        $EntryUpdateTime.Text = $Entry.PasswordUpdateTime.DateTime
        $EntryUpdateTime.ReadOnly = $True
        $Historyform.Controls.Add($EntryUpdateTime)

        $Location = $Location + 27
    }

    $exitButton = New-Object System.Windows.Forms.Button
    $exitButton.Location = New-Object System.Drawing.Point(470,225)
    $exitButton.Size = New-Object System.Drawing.Size(73,22)
    $exitButton.Text = 'Exit'
    $Historyform.CancelButton = $exitButton
    $Historyform.Controls.Add($exitButton)

    $Historyform.ShowDialog() | Out-Null
}


Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


# Query window
# ------------------------------------------------------------
$Queryform = New-Object System.Windows.Forms.Form
$Queryform.Text = 'TS - Local Administrator Password Lookup'
$Queryform.Size = New-Object System.Drawing.Size(566,303)
$Queryform.StartPosition = 'CenterScreen'
$Queryform.FormBorderStyle = 'FixedDialog'
$Queryform.MaximizeBox = $false
$Queryform.MinimizeBox = $false

##
$ComputerLabel = New-Object System.Windows.Forms.Label
$ComputerLabel.Location = New-Object System.Drawing.Point(10,15)
$ComputerLabel.Size = New-Object System.Drawing.Size(450,15)
$ComputerLabel.Text = 'Computer Name:'
$Queryform.Controls.Add($ComputerLabel)

## 
$ComputerName = New-Object System.Windows.Forms.TextBox
$ComputerName.Location = New-Object System.Drawing.Point(12,31)
$ComputerName.Size = New-Object System.Drawing.Size(450,20)

$ComputerName.Add_KeyDown({
    if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        & $DoSearch
    }
})

$Queryform.Controls.Add($ComputerName)

##
$searchButton = New-Object System.Windows.Forms.Button
$searchButton.Location = New-Object System.Drawing.Point(470,30)
$searchButton.Size = New-Object System.Drawing.Size(73,22)
$searchButton.Text = 'Search'
$searchButton.Add_Click($DoSearch)
$Queryform.Controls.Add($searchButton)

##
$listButton = New-Object System.Windows.Forms.Button
$listButton.Location = New-Object System.Drawing.Point(470,60)
$listButton.Size = New-Object System.Drawing.Size(73,22)
$listButton.Text = 'List All'
$listButton.Add_Click($DoList)
#$Queryform.Controls.Add($listButton)

##
$PasswordLabel = New-Object System.Windows.Forms.Label
$PasswordLabel.Location = New-Object System.Drawing.Point(10,65)
$PasswordLabel.Size = New-Object System.Drawing.Size(450,15)
$PasswordLabel.Text = 'Password:'
$Queryform.Controls.Add($PasswordLabel)

##
$LapsPassword = New-Object System.Windows.Forms.TextBox
$LapsPassword.Location = New-Object System.Drawing.Point(12,80)
$LapsPassword.Size = New-Object System.Drawing.Size(450,20)
$LapsPassword.Font = (New-Object System.Drawing.Font("Arial", 12))
$LapsPassword.ReadOnly = $True
$LapsPassword.TabStop = $False
$Queryform.Controls.Add($LapsPassword)

##
$HistoryButton = New-Object System.Windows.Forms.Button
$HistoryButton.Location = New-Object System.Drawing.Point(470,79)
$HistoryButton.Size = New-Object System.Drawing.Size(73,22)
$HistoryButton.Text = 'History'
$HistoryButton.Hide()
$HistoryButton.Add_Click($SnowHistory)
$Queryform.Controls.Add($HistoryButton)


##
$PhoneticButton = New-Object System.Windows.Forms.Button
$PhoneticButton.Location = New-Object System.Drawing.Point(470,105)
$PhoneticButton.Size = New-Object System.Drawing.Size(73,22)
$PhoneticButton.Text = 'Phonetic'
$PhoneticButton.Hide()
$PhoneticButton.Add_Click($ShowPhonetic)
$Queryform.Controls.Add($PhoneticButton)


##
$ExpirationLabel = New-Object System.Windows.Forms.Label
$ExpirationLabel.Location = New-Object System.Drawing.Point(10,120)
$ExpirationLabel.Size = New-Object System.Drawing.Size(450,15)
$ExpirationLabel.Text = 'Password expires:'
$Queryform.Controls.Add($ExpirationLabel)

##
$Expiration = New-Object System.Windows.Forms.TextBox
$Expiration.Location = New-Object System.Drawing.Point(12,135)
$Expiration.Size = New-Object System.Drawing.Size(450,20)
$Expiration.ReadOnly = $True
$Expiration.TabStop = $False
$Queryform.Controls.Add($Expiration)

##
$ExpirationLabel = New-Object System.Windows.Forms.Label
$ExpirationLabel.Location = New-Object System.Drawing.Point(10,175)
$ExpirationLabel.Size = New-Object System.Drawing.Size(450,15)
$ExpirationLabel.Text = 'New expiration time (leave as is for immediate expiration):'
$Queryform.Controls.Add($ExpirationLabel)

##
$NewExpiration = New-Object Windows.Forms.DateTimePicker
$NewExpiration.Format = [windows.forms.datetimepickerFormat]::custom
$NewExpiration.CustomFormat = (Get-culture).DateTimeFormat.FullDateTimePattern
$NewExpiration.Location = New-Object System.Drawing.Point(10, 195)
$NewExpiration.Size = New-Object System.Drawing.Size(450,20)
$Queryform.Controls.Add($NewExpiration)

$setButton = New-Object System.Windows.Forms.Button
$setButton.Location = New-Object System.Drawing.Point(470,194)
$setButton.Size = New-Object System.Drawing.Size(73,22)
$setButton.Text = 'Set'
$setButton.Add_Click($DoExpire)
$Queryform.Controls.Add($setButton)

##
$LapsVersion = New-Object System.Windows.Forms.TextBox
$LapsVersion.Location = New-Object System.Drawing.Point(12,225)
$LapsVersion.Size = New-Object System.Drawing.Size(50,20)
$LapsVersion.ReadOnly = $True
$LapsVersion.BorderStyle = "None"
$LapsVersion.Hide()
$Queryform.Controls.Add($LapsVersion)

$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Location = New-Object System.Drawing.Point(470,225)
$exitButton.Size = New-Object System.Drawing.Size(73,22)
$exitButton.Text = 'Exit'
$Queryform.CancelButton = $exitButton
$Queryform.Controls.Add($exitButton)

$Queryform.ShowDialog() | Out-Null
