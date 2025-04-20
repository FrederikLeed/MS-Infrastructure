The script in this folder is embedded in the "Install - PingCastle webservice.ps1"  

Encoding done.
$Bytes = [System.Text.Encoding]::UTF8.GetBytes($CreateReportPs1)
$EncodedText =[Convert]::ToBase64String($Bytes)
$EncodedText

Copied the output to "Install - PingCastle webservice.ps1"
  
Same encoding have been done with the "simple" Default.asp and List.asp  
