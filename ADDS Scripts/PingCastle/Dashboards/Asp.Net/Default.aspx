<%@ Page Language="VB" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Text.RegularExpressions" %>
<%@ Import Namespace="System.Xml" %>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>PingCastle Dashboard</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  <style>
    body { font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f9f9f9; }
    h1 { text-align: center; margin: 5px 0; color: #333; }
    table.calendar { border-collapse: collapse; width: 100%; margin: 5px auto; }
    table.calendar th, table.calendar td { padding: 5px; text-align: center; border: 1px solid #ccc; }
    .today { background-color: #ffffcc; font-weight: bold; }
    .monthname { font-weight: bold; padding: 5px; background: #f0f0f0; text-align: center; }
    .chart-container { margin: 1px auto; max-width: 800px; height: 400px; }
    a { text-decoration: none; color: #000; }
    a:hover { color: #0073e6; }    
    .has-data { background-color: #d4edda; }
  </style>
</head>
<body>
  <!-- Calendar Display -->
  <table align="Center">
    <tr>
      <td colspan=3><h1 style="text-align:center;">PingCastle Report Dashboard</h1></td>
    </tr>
    <tr>
<%
  ' Calendar Setup Variables
  Dim cutoffDate As DateTime = DateAdd(DateInterval.Month, -3, Now) ' Show data for the past 3 months
  Dim today As DateTime = Now
  Dim monthsToShow As Integer = 3

  ' Directory Path for XML Files
  Dim directoryPath As String = Server.MapPath(".")

  ' Get Latest Files by Day
  Dim latestHtmlFiles = GetLatestHtmlFiles(directoryPath, DateAdd(DateInterval.Month, -3, Now))

  ' Generate Calendar for Past 3 Months in Reverse Order
  For monthOffset As Integer = monthsToShow - 1 To 0 Step -1
    Dim currentMonth As DateTime = DateAdd(DateInterval.Month, -monthOffset, today)
    Dim firstDay As DateTime = New DateTime(currentMonth.Year, currentMonth.Month, 1)
    Dim daysInMonth As Integer = DateTime.DaysInMonth(currentMonth.Year, currentMonth.Month)
    Dim weekdayOffset As Integer = firstDay.DayOfWeek ' Offset for first day of the month

    ' Render Month Header
    Response.Write("<td valign='top'>")
    Response.Write("<div class='monthname'>" & MonthName(firstDay.Month) & " " & firstDay.Year & "</div>")
    Response.Write("<table class='calendar'><tr>")
    Response.Write("<th>Sun</th><th>Mon</th><th>Tue</th><th>Wed</th><th>Thu</th><th>Fri</th><th>Sat</th>")
    Response.Write("</tr><tr>")

    ' Render Empty Cells Before First Day
    For emptyCells As Integer = 1 To weekdayOffset
      Response.Write("<td></td>")
    Next

    ' Render Days
    For dayCounter As Integer = 1 To daysInMonth
      Dim cellDate As DateTime = New DateTime(firstDay.Year, firstDay.Month, dayCounter)
      Dim cssClass As String = ""

      ' Highlight Today
      If cellDate.Date = today.Date Then
        cssClass = " class='today'"
      ' Highlight Days with Data
      ElseIf latestHtmlFiles.ContainsKey(cellDate.Date) Then
        cssClass = " class='has-data'"
      End If

      ' Write Day Cell
      Response.Write("<td" & cssClass & ">")
      If latestHtmlFiles.ContainsKey(cellDate.Date) Then
        ' Convert file path to relative URL
        Dim relativePath As String = latestHtmlFiles(cellDate.Date).Replace(Server.MapPath(""), "").Replace("\", "/")
        relativePath = Request.ApplicationPath.TrimEnd("/") & relativePath
        Response.Write("<a href='" & relativePath & "'>" & dayCounter & "</a>")
      Else
        Response.Write(dayCounter.ToString())
      End If
      Response.Write("</td>")

      ' Break Row After Saturday
      If (weekdayOffset + dayCounter) Mod 7 = 0 And dayCounter < daysInMonth Then
        Response.Write("</tr><tr>")
      End If
    Next

    ' Render Empty Cells After Last Day
    Dim remainingCells As Integer = (7 - ((weekdayOffset + daysInMonth) Mod 7)) Mod 7
    For emptyCells As Integer = 1 To remainingCells
      Response.Write("<td></td>")
    Next

    Response.Write("</tr></table></td>")
  Next
%>
    </tr>
    <tr>
      <td colspan=3>
        <div class="chart-container">
          <canvas id="ScoreChart"></canvas>
        </div>
      </td>
    </tr>
    </td></tr>
    <tr><td colspan=3 align=center><br><a href='./ad_hc_rules_list.html'>PingCastle Healthcheck rules</a>&nbsp;&nbsp;|&nbsp;&nbsp;<a href='./ListRules.aspx'>List current findings</a></td></tr>
  </table>
<%

Dim graphData = GetGraphData(Server.MapPath("."), DateAdd(DateInterval.Month, -3, Now))

Dim labels As New List(Of String)()
Dim staleObjectsData As New List(Of Integer)()
Dim privilegedGroupData As New List(Of Integer)()
Dim trustScoreData As New List(Of Integer)()
Dim anomalyScoreData As New List(Of Integer)()
Dim globalScoreData As New List(Of Integer)()

For Each entry As KeyValuePair(Of Date, Integer()) In graphData.OrderBy(Function(kvp) kvp.Key) ' Order by date
    labels.Add(entry.Key.ToString("yyyy-MM-dd"))
    staleObjectsData.Add(entry.Value(0))
    privilegedGroupData.Add(entry.Value(1))
    trustScoreData.Add(entry.Value(2))
    anomalyScoreData.Add(entry.Value(3))
    globalScoreData.Add(entry.Value(4))
Next

Response.Write("<script>")
Dim serializer As New System.Web.Script.Serialization.JavaScriptSerializer()
Response.Write("var labels = " & serializer.Serialize(labels) & ";")
Response.Write("var staleObjectsData = " & serializer.Serialize(staleObjectsData) & ";")
Response.Write("var privilegedGroupData = " & serializer.Serialize(privilegedGroupData) & ";")
Response.Write("var trustScoreData = " & serializer.Serialize(trustScoreData) & ";")
Response.Write("var anomalyScoreData = " & serializer.Serialize(anomalyScoreData) & ";")
Response.Write("var globalScoreData = " & serializer.Serialize(globalScoreData) & ";")
Response.Write("</script>")

%>
  <script runat="server">
Function ProcessFilesByDay(directoryPath As String, cutoffDate As Date, fileType As String, processFile As Action(Of Date, String)) As Dictionary(Of Date, Object)
    Dim resultData As New Dictionary(Of Date, Object)()
    Dim folderRegex As New Regex("^\d{2}-\d{2}-\d{4} - \d{2}-\d{2}$") ' Regex to match folder names

    ' Traverse subfolders
    For Each subfolder In Directory.GetDirectories(directoryPath)
        Dim folderName As String = Path.GetFileName(subfolder)

        ' Check if folder name matches the regex pattern
        If folderRegex.IsMatch(folderName) Then
            Dim folderParts As String() = folderName.Split(New String() {" - "}, StringSplitOptions.None)

            If folderParts.Length = 2 Then
                Dim folderDate As Date
                Dim folderTime As String = folderParts(1)

                ' Parse the folder date and ensure it meets the cutoff
                If Date.TryParseExact(folderParts(0), "dd-MM-yyyy", Nothing, System.Globalization.DateTimeStyles.None, folderDate) AndAlso folderDate >= cutoffDate Then
                    Dim latestFile As String = ""
                    Dim latestTime As String = ""

                    ' Find the latest file of the specified type for the subfolder
                     For Each filePath In Directory.GetFiles(subfolder, "*." & fileType)
                        If latestTime = "" OrElse String.Compare(folderTime, latestTime) > 0 Then
                            latestTime = folderTime

                            latestFile = filePath
                        End If
                    Next

                    ' Process the file if one is found
                    If latestFile <> "" Then
                        processFile(folderDate, latestFile)
                    End If
                End If
            End If
        End If
    Next

    Return resultData
End Function

Function GetLatestHtmlFiles(directoryPath As String, cutoffDate As Date) As Dictionary(Of Date, String)
    Dim latestHtmlFiles As New Dictionary(Of Date, String)()

    ProcessFilesByDay(directoryPath, cutoffDate, "html", Sub(folderDate, filePath)
        latestHtmlFiles(folderDate) = filePath
    End Sub)

    Return latestHtmlFiles
End Function

Function GetGraphData(directoryPath As String, cutoffDate As Date) As Dictionary(Of Date, Integer())
    Dim graphData As New Dictionary(Of Date, Integer())()

    ProcessFilesByDay(directoryPath, cutoffDate, "xml", Sub(folderDate, filePath)
        Dim doc As New XmlDocument()
        doc.Load(filePath)

        Dim staleObjectsScore As Integer = Convert.ToInt32(doc.SelectSingleNode("//HealthcheckData/StaleObjectsScore").InnerText)
        Dim privilegedGroupScore As Integer = Convert.ToInt32(doc.SelectSingleNode("//HealthcheckData/PrivilegiedGroupScore").InnerText)
        Dim trustScore As Integer = Convert.ToInt32(doc.SelectSingleNode("//HealthcheckData/TrustScore").InnerText)
        Dim anomalyScore As Integer = Convert.ToInt32(doc.SelectSingleNode("//HealthcheckData/AnomalyScore").InnerText)
        Dim globalScore As Integer = Convert.ToInt32(doc.SelectSingleNode("//HealthcheckData/GlobalScore").InnerText)

        graphData(folderDate) = {staleObjectsScore, privilegedGroupScore, trustScore, anomalyScore, globalScore}
    End Sub)

    Return graphData
End Function

  </script>

  <script>
    var ctx = document.getElementById('ScoreChart').getContext('2d');
    new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [
                {
                    label: 'Global Objects Score',
                    data: globalScoreData,
                    borderColor: 'rgba(0, 0, 0, 0)',
                    backgroundColor: 'rgba(150, 150, 150, 0.2)',
                    pointRadius: 0,
                    fill: true
                },
                {
                    label: 'Stale Objects Score',
                    data: staleObjectsData,
                    borderColor: 'blue',
                    fill: false
                },
                {
                    label: 'Privileged Group Score',
                    data: privilegedGroupData,
                    borderColor: 'red',
                    fill: false
                },
                {
                    label: 'Trust Score',
                    data: trustScoreData,
                    borderColor: 'yellow',
                    fill: false
                },
                {
                    label: 'Anomaly Score',
                    data: anomalyScoreData,
                    borderColor: 'purple',
                    fill: false
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
               legend: {
                   position: 'bottom' // Moves legend below the graph
               }
            },
            scales: {
                x: {
                    ticks: {
                        callback: function(value, index, ticks) {
                            // Shorten label to dd-MM format
                            var parts = this.getLabelForValue(value).split("-");
                            return parts[0] + "-" + parts[1]; // Format: dd-MM
                        }
                    }
                },
                y: {
                    beginAtZero: true, // Ensure y-axis starts at 0
                    stepSize: 1        // Define step size for better visualization
                }
            }
        }
    });
  </script>


</body>
</html>
