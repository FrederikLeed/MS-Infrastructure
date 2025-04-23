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

Dim fso, folder, subfolder, file, xmlDoc, graphData, reportDates
Dim regEx, cutoffDate, latestDateKey, latestHtmlPath, folderdate
Dim dateParts, reportDateKey, latestFileToday, latestTimeToday

Set fso = Server.CreateObject("Scripting.FileSystemObject")
Set folder = fso.GetFolder(Server.MapPath("."))

' Only used by GraphJS
cutoffDate = DateAdd("m", -3, Date())

Set graphData = CreateObject("Scripting.Dictionary")
Set reportDates = Server.CreateObject("Scripting.Dictionary")

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
        If LCase(Right(file.Name, 5)) = ".html" Then

          ' Check if it's the latest HTML file for this day
          If Not latestHtmlFiles.Exists(reportDateKey) Then
            ' Initialize the entry if it doesn't exist
            latestHtmlFiles(reportDateKey) = Array(subfolder.Name & "/" & file.Name, fileTime)
          ElseIf fileTime > latestHtmlFiles(reportDateKey)(1) Then
            ' Update the entry if the current file is later
            latestHtmlFiles(reportDateKey) = Array(subfolder.Name & "/" & file.Name, fileTime)
          End If

        ElseIf LCase(Right(file.Name, 4)) = ".xml" Then

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

Dim reportDate
For Each reportDate In latestXmlFiles.Keys
  If CDate(reportDate) >= cutoffDate Then
    ' Load the latest XML file for this day
    Set xmlDoc = Server.CreateObject("Microsoft.XMLDOM")
    xmlDoc.Async = False
    xmlDoc.Load(folder & "\" & latestXmlFiles(reportDate)(0))

    ' Extract graph data
    Dim s1, s2, s3, s4, s5
    s1 = xmlDoc.SelectSingleNode("//HealthcheckData/StaleObjectsScore").Text
    s2 = xmlDoc.SelectSingleNode("//HealthcheckData/PrivilegiedGroupScore").Text
    s3 = xmlDoc.SelectSingleNode("//HealthcheckData/TrustScore").Text
    s4 = xmlDoc.SelectSingleNode("//HealthcheckData/AnomalyScore").Text
    s5 = xmlDoc.SelectSingleNode("//HealthcheckData/GlobalScore").Text

    graphData(CDate(reportDate)) = Array(s1, s2, s3, s4, s5)
  End If
Next

Dim sortedGraphData
Set sortedGraphData = CreateObject("Scripting.Dictionary")

Dim sortedKeys, sortedKey
sortedKeys = Array()
For Each key In graphData.Keys
  ReDim Preserve sortedKeys(UBound(sortedKeys) + 1)
  sortedKeys(UBound(sortedKeys)) = key
Next

' Sort the keys (dates) in ascending order
Dim temp, i, j
For i = LBound(sortedKeys) To UBound(sortedKeys) - 1
  For j = i + 1 To UBound(sortedKeys)
    If sortedKeys(i) > sortedKeys(j) Then
      temp = sortedKeys(i)
      sortedKeys(i) = sortedKeys(j)
      sortedKeys(j) = temp
    End If
  Next
Next

' Create sorted dictionary
For i = LBound(sortedKeys) To UBound(sortedKeys)
  sortedKey = sortedKeys(i)
  sortedGraphData.Add sortedKey, graphData(sortedKey)
Next

Dim labels, staleObjectsData, privilegiedGroupData, trustData, anomalyData, globalData
labels = ""
staleObjectsData = ""
privilegiedGroupData = ""
trustData = ""
anomalyData = ""
globalData = ""

For Each key In sortedGraphData.Keys
  labels = labels & """" & key & ""","
  Dim values
  values = sortedGraphData(key)
  staleObjectsData = staleObjectsData & values(0) & ","
  privilegiedGroupData = privilegiedGroupData & values(1) & ","
  trustData = trustData & values(2) & ","
  anomalyData = anomalyData & values(3) & ","
  globalData = globalData & values(4) & ","
Next

If Len(labels) > 0 Then
  labels = Left(labels, Len(labels) - 1)
  staleObjectsData = Left(staleObjectsData, Len(staleObjectsData) - 1)
  privilegiedGroupData = Left(privilegiedGroupData, Len(privilegiedGroupData) - 1)
  trustData = Left(trustData, Len(trustData) - 1)
  anomalyData = Left(anomalyData, Len(anomalyData) - 1)
  globalData = Left(globalData, Len(globalData) - 1)
End If

Dim chartData
chartData = "{labels: [" & labels & "], datasets: [{label: 'Gloal Score', data: [" & globalData & "], borderColor: 'rgba(0, 0, 0, 0)', backgroundColor: 'rgba(150, 150, 150, 0.2)', pointRadius: 0, fill: true}, {label: 'Stale Objects Score', data: [" & staleObjectsData & "], borderColor: 'blue', fill: false}, {label: 'Privilegied Group Score', data: [" & privilegiedGroupData & "], borderColor: 'red', fill: false}, {label: 'Trust Score', data: [" & trustData & "], borderColor: 'yellow', fill: false}, {label: 'Anomaly Score', data: [" & anomalyData & "], borderColor: 'purple', fill: false}]}"
%>

<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>PingCastle Report Dashboard</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  <style>
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
  </style>
</head>
<body>
  <!-- Calendar Display -->
  <table align=center>
    <tr>
      <td colspan=3><h1 style="text-align:center;">PingCastle Report Dashboard</h1></td>
    </tr>
    <tr>
<%
Dim baseDate
baseDate = Now()

For i = 2 To 0 Step -1
  Dim currentDate, firstDayOfMonth, daysInMonth, weekdayOffset, dayCounter
  currentDate = DateAdd("m", -i, baseDate)
  Dim targetYear, targetMonth
  targetYear = Year(currentDate)
  targetMonth = Month(currentDate)

  firstDayOfMonth = DateSerial(targetYear, targetMonth, 1)
  daysInMonth = Day(DateSerial(targetYear, targetMonth + 1, 0))
  weekdayOffset = Weekday(firstDayOfMonth) - 1

  Response.Write "<td valign='top'><div class='monthname'>" & MonthName(targetMonth) & " " & targetYear & "</div>"
  Response.Write "<table class='calendar'><tr><th>Sun</th><th>Mon</th><th>Tue</th><th>Wed</th><th>Thu</th><th>Fri</th><th>Sat</th></tr><tr>"

  For j = 1 To weekdayOffset
    Response.Write "<td></td>"
  Next

  dayCounter = 1
  Do While dayCounter <= daysInMonth
    If (weekdayOffset + dayCounter - 1) Mod 7 = 0 And dayCounter > 1 Then
      Response.Write "</tr><tr>"
    End If

    Dim dateKey, cssClass
    dateKey = targetYear & "-" & addLeadingZero(targetMonth) & "-" & addLeadingZero(dayCounter)
    cssClass = ""
    If dateKey = Year(baseDate) & "-" & addLeadingZero(Month(baseDate)) & "-" & addLeadingZero(Day(baseDate)) Then
      cssClass = " class='today'"
    End If

    If latestHtmlFiles.Exists(dateKey) Then
      Response.Write "<td" & cssClass & "><a href='./" & latestHtmlFiles(dateKey)(0) & "'><b>" & dayCounter & "</b></a></td>"
    Else
      Response.Write "<td" & cssClass & ">" & dayCounter & "</td>"
    End If

    dayCounter = dayCounter + 1
  Loop

  Dim remaining
  remaining = (7 - ((weekdayOffset + daysInMonth) Mod 7)) Mod 7
  For j = 1 To remaining
    Response.Write "<td></td>"
  Next

  Response.Write "</tr></table></td>"
Next
%>
    </tr>
    <tr>
     <td colspan=3>

  <!-- Line Chart Display -->
  <div class="chart-container">
    <canvas id="ScoreChart"></canvas>
  </div>
  <script>
    var chartData = <%= chartData %>;

  // Initialize Chart.js
  var ctx = document.getElementById('ScoreChart').getContext('2d');
  new Chart(ctx, {
      type: 'line',
      data: chartData,
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
</td></tr>
<tr><td colspan=3 align=center><br><a href='./ad_hc_rules_list.html'>PingCastle Healthcheck rules</a>&nbsp;&nbsp;|&nbsp;&nbsp;<a href='./ListRules.asp'>List current findings</a></td></tr>
</table>
</body>
</html>