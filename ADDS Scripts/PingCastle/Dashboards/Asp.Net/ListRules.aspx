<%@ Page Language="VB" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Xml" %>
<%@ Import Namespace="System.Text.RegularExpressions" %>
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
      <th Width="75px">Added</th>
      <th Width="75px">Removed</th>
    </tr>
    <asp:Literal ID="TableRows" runat="server" />
  </table>

  <script runat="server">
    Protected Sub Page_Load(sender As Object, e As EventArgs)
        ' Variables
        Dim folderPath As String = Server.MapPath(".")
        Dim latestXmlFiles As New Dictionary(Of String, String)()
        Dim allFindings As New Dictionary(Of String, Object())
        Dim folderRegex As New Regex("^\d{2}-\d{2}-\d{4} - \d{2}-\d{2}$")

        ' Traverse subfolders and gather the latest XML files
        For Each subfolder As String In Directory.GetDirectories(folderPath)
            Dim folderName As String = Path.GetFileName(subfolder)

            ' Validate folder name with regex
            If folderRegex.IsMatch(folderName) Then
                Dim folderParts As String() = folderName.Split(" - ")
                Dim latestFile As String = ""
                Dim latestTime As String = folderParts(1)

                ' Find the latest XML file
                For Each filePath As String In Directory.GetFiles(subfolder, "*.xml")
                    If latestFile = "" OrElse String.Compare(latestTime, Path.GetFileNameWithoutExtension(filePath)) > 0 Then
                        latestFile = filePath
                    End If
                Next

                If latestFile <> "" Then
                    latestXmlFiles(folderParts(0)) = latestFile
                End If
            End If
        Next

        ' Process findings
        For Each reportDate As String In latestXmlFiles.Keys
            Dim xmlDoc As New XmlDocument()
            xmlDoc.Load(latestXmlFiles(reportDate))
            Dim riskRules = xmlDoc.SelectNodes("//HealthcheckData/RiskRules/HealthcheckRiskRule")

            ' Parse findings
            For Each riskRule As XmlNode In riskRules
                Dim riskId = riskRule.SelectSingleNode("RiskId").InnerText
                Dim points = riskRule.SelectSingleNode("Points").InnerText
                Dim category = riskRule.SelectSingleNode("Category").InnerText
                Dim model = riskRule.SelectSingleNode("Model").InnerText
                Dim rationale = riskRule.SelectSingleNode("Rationale").InnerText

                ' Add or update the finding
                If Not allFindings.ContainsKey(riskId) Then
                    allFindings(riskId) = {points, category, model, rationale, reportDate, ""}
                Else
                    Dim existingFinding = allFindings(riskId)
                    existingFinding(5) = "" ' Clear removed date
                    allFindings(riskId) = existingFinding
                End If
            Next

            ' Mark findings as removed if not present in the current file
            For Each key As String In allFindings.Keys.ToList()
                If Not riskRules.Cast(Of XmlNode)().Any(Function(r) r.SelectSingleNode("RiskId").InnerText = key) Then
                    Dim findingData = allFindings(key)
                    If findingData(5) = "" Then
                        findingData(5) = reportDate ' Set removed date
                        allFindings(key) = findingData
                    End If
                End If
            Next
        Next

        ' Sort findings by category
        Dim sortedFindings = allFindings.OrderBy(Function(f) f.Value(1)).ToList()

        ' Build HTML table rows
        Dim html As String = ""
        For Each finding In sortedFindings
            Dim riskId = finding.Key
            Dim data = finding.Value
            Dim points = data(0)
            Dim category = data(1)
            Dim model = data(2)
            Dim rationale = data(3)
            Dim dateAdded = data(4)
            Dim dateRemoved = data(5)

            ' Determine row class
            Dim rowClass As String = If(dateRemoved = "", "added", If(dateAdded <> "" And dateRemoved <> "", "removed", "unchanged"))

            ' Add row to HTML
            html &= "<tr class='" & rowClass.ToLower() & "'>"
            html &= "<td>" & points & "</td>"
            html &= "<td>" & category & "</td>"
            html &= "<td>" & model & "</td>"
            html &= "<td>" & riskId & "</td>"
            html &= "<td>" & rationale & "</td>"
            html &= "<td>" & dateAdded & "</td>"
            html &= "<td>" & dateRemoved & "</td>"
            html &= "</tr>"
        Next

        TableRows.Text = html
    End Sub
  </script>
</body>
</html>
