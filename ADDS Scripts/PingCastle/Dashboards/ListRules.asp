<%@ Language=VBScript %>
<%
' --- BEGIN: Shared Setup ---
Function addLeadingZero(val)
  If val < 10 Then
    addLeadingZero = "0" & val
  Else
    addLeadingZero = val
  End If
End Function

Dim fso, folder, subfolder, file, xmlDocToday, xmlDocYesterday, riskRulesToday, riskRulesYesterday, combinedResults
Set fso = Server.CreateObject("Scripting.FileSystemObject")
Set folder = fso.GetFolder(Server.MapPath("."))

Set riskRulesToday = CreateObject("Scripting.Dictionary")
Set riskRulesYesterday = CreateObject("Scripting.Dictionary")
Set combinedResults = CreateObject("Scripting.Dictionary")

Dim regEx
Set regEx = New RegExp
regEx.Pattern = "^\d{2}-\d{2}-\d{4} - \d{2}-\d{2}$"

latestDateKey = ""
latestHtmlPath = ""
latestFileToday = ""
latestTimeToday = ""

Dim latestHtmlFiles, latestXmlFiles, fileTime
Set latestHtmlFiles = CreateObject("Scripting.Dictionary")
Set latestXmlFiles = CreateObject("Scripting.Dictionary")

' Identify the latest HTML and XML files for each day
For Each subfolder In folder.SubFolders
  If regEx.Test(subfolder.Name) Then
    folderdate = Split(subfolder.Name, " - ")
    dateParts = Split(folderdate(0), "-")
    If UBound(dateParts) = 2 Then
      reportDateKey = dateParts(2) & "-" & dateParts(1) & "-" & dateParts(0)
      fileTime = folderdate(1)

      For Each file In subfolder.Files
        If LCase(Right(file.Name, 4)) = ".xml" Then

          ' Check if it's the latest XML file for this day
          If Not latestXmlFiles.Exists(reportDateKey) Then
            ' Initialize the entry if it doesn't exist
            latestXmlFiles(reportDateKey) = Array(subfolder.Name & "/" & file.Name, fileTime)
          ElseIf fileTime > latestXmlFiles(reportDateKey)(1) Then
            ' Update the entry if the current file is later
            latestXmlFiles(reportDateKey) = Array(subfolder.Name & "/" & file.Name, fileTime)
          End If

        End If
      Next
    End If
  End If
Next

' Aggregate all findings across XML files
Dim reportDatesProcessed, allFindings
Set reportDatesProcessed = CreateObject("Scripting.Dictionary")
Set allFindings = CreateObject("Scripting.Dictionary")

For Each reportDate In latestXmlFiles.Keys
  Set xmlDoc = Server.CreateObject("Microsoft.XMLDOM")
  xmlDoc.Async = False
  xmlDoc.Load(folder & "/" & latestXmlFiles(reportDate)(0))

  Dim healthCheckNode, riskRule
  Set healthCheckNode = xmlDoc.SelectNodes("//HealthcheckData/RiskRules/HealthcheckRiskRule")

  ' Process findings in the current file
  For Each riskRule In healthCheckNode
    Dim riskId, points, category, model, rationale
    riskId = riskRule.SelectSingleNode("./RiskId").Text
    points = riskRule.SelectSingleNode("./Points").Text
    category = riskRule.SelectSingleNode("./Category").Text
    model = riskRule.SelectSingleNode("./Model").Text
    rationale = riskRule.SelectSingleNode("./Rationale").Text

    If Not allFindings.Exists(riskId) Then
      ' If the finding is new, set its added date
      allFindings(riskId) = Array(points, category, model, rationale, reportDate, "")
    Else
      ' If the finding exists, ensure "removed date" is cleared
      Dim existingFinding
      existingFinding = allFindings(riskId)
      existingFinding(5) = "" ' Clear removed date (still active)
      allFindings(riskId) = existingFinding
    End If
  Next

  ' Mark findings as removed if they are not present in the current file
  Dim existingRiskId, isPresent
  For Each existingRiskId In allFindings.Keys
      isPresent = False
      For Each riskRule In healthCheckNode
          If riskRule.SelectSingleNode("./RiskId").Text = existingRiskId Then
              isPresent = True
              Exit For
          End If
      Next
  
      Dim findingData
      findingData = allFindings(existingRiskId)
      If Not isPresent And findingData(5) = "" Then
          findingData(5) = reportDate ' Set removed date
          allFindings(existingRiskId) = findingData
      End If
  Next
Next

Dim sortedFindings, ruleData
sortedFindings = Array()

' Populate the array with all findings
For Each riskId In allFindings.Keys
  ruleData = allFindings(riskId)
  ReDim Preserve sortedFindings(UBound(sortedFindings) + 1)
  sortedFindings(UBound(sortedFindings)) = Array(riskId, ruleData(0), ruleData(1), ruleData(2), ruleData(3), ruleData(4), ruleData(5))
Next

' Sort the array by Category (element index 2)
Dim i, j, temp
For i = LBound(sortedFindings) To UBound(sortedFindings) - 1
  For j = i + 1 To UBound(sortedFindings)
    If sortedFindings(i)(2) > sortedFindings(j)(2) Then
      temp = sortedFindings(i)
      sortedFindings(i) = sortedFindings(j)
      sortedFindings(j) = temp
    End If
  Next
Next
%>

<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>RiskRules Comparison</title>
  <style>
    table { border-collapse: collapse; width: 100%; }
    table th, table td { padding: 6px; text-align: left; border: 1px solid #ccc; }
    .added { background-color: #f8d7da; } /* Green for added rules */
    .removed { background-color: #d4edda; } /* Red for removed rules */
    .unchanged { background-color: #ffffff; } /* No styling for unchanged rules */
  </style>
</head>
<body>
  <h1 style="text-align:center;">RiskRules Comparison</h1>

<table align="center">
  <tr>
    <th>Points</th>
    <th>Category</th>
    <th>Model</th>
    <th>RiskId</th>
    <th>Rationale</th>
    <th>Date Added</th>
    <th>Date Removed</th>
  </tr>
<%
Dim rowClass, dateAdded, dateRemoved
For i = LBound(sortedFindings) To UBound(sortedFindings)
  ruleData = sortedFindings(i)
  dateAdded = ruleData(5)
  dateRemoved = ruleData(6)

  ' Determine the row class for coloring
  If dateRemoved = "" Then
    rowClass = "added"
  ElseIf dateAdded <> "" And dateRemoved <> "" Then
    rowClass = "removed"
  Else
    rowClass = ""
  End If

  Response.Write "<tr class='" & LCase(rowClass) & "'>"
  Response.Write "<td>" & ruleData(1) & "</td>" ' Points
  Response.Write "<td>" & ruleData(2) & "</td>" ' Category
  Response.Write "<td>" & ruleData(3) & "</td>" ' Model
  Response.Write "<td>" & ruleData(0) & "</td>" ' RiskId
  Response.Write "<td>" & ruleData(4) & "</td>" ' Rationale
  Response.Write "<td>" & dateAdded & "</td>"   ' Date Added
  Response.Write "<td>" & dateRemoved & "</td>" ' Date Removed
  Response.Write "</tr>"
Next
%>
</table>


</body>
</html>
