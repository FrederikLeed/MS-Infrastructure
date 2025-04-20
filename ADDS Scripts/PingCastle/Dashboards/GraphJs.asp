<%
' Initialize FileSystemObject and variables
Dim fso, folder, subfolder, file, xmlDoc, graphData
Set fso = Server.CreateObject("Scripting.FileSystemObject")
Set folder = fso.GetFolder(Server.MapPath("."))

Dim cutoffDate
cutoffDate = DateAdd("m", -3, Date()) ' Look back 3 months

Set graphData = CreateObject("Scripting.Dictionary") ' Store dates and scores

' Regular Expression to Validate Folder Name
Dim regEx
Set regEx = New RegExp
regEx.Pattern = "^\d{2}-\d{2}-\d{4} - \d{2}-\d{2}$" ' Matches "dd-MM-yyyy - hh-mm"

' Loop through subfolders
For Each subfolder In folder.Subfolders
    If regEx.Test(subfolder.Name) Then ' Validate folder name
        Dim folderDate
        folderDate = CDate(Split(subfolder.Name, " - ")(0)) ' Extract and convert the date part

        If folderDate >= cutoffDate Then ' Check if folder is within 3 months
            For Each file In subfolder.Files
                If LCase(Right(file.Name, 4)) = ".xml" Then ' Process XML files
                    Set xmlDoc = Server.CreateObject("Microsoft.XMLDOM")
                    xmlDoc.Async = False
                    xmlDoc.Load(file.Path)

                    ' Extract required values
                    Dim staleObjectsScore, privilegiedGroupScore, trustScore, anomalyScore
                    staleObjectsScore = xmlDoc.SelectSingleNode("//HealthcheckData/StaleObjectsScore").Text
                    privilegiedGroupScore = xmlDoc.SelectSingleNode("//HealthcheckData/PrivilegiedGroupScore").Text
                    trustScore = xmlDoc.SelectSingleNode("//HealthcheckData/TrustScore").Text
                    anomalyScore = xmlDoc.SelectSingleNode("//HealthcheckData/AnomalyScore").Text

                    ' Store data in dictionary
                    graphData(folderDate) = Array(staleObjectsScore, privilegiedGroupScore, trustScore, anomalyScore)
                End If
            Next
        End If
    End If
Next

' Prepare data for Chart.js
Dim labels, staleObjectsData, privilegiedGroupData, trustData, anomalyData
labels = "" ' Initialize labels (dates)
staleObjectsData = "" ' Initialize data array for Stale Objects Score
privilegiedGroupData = "" ' Initialize data array for Privilegied Group Score
trustData = "" ' Initialize data array for Trust Score
anomalyData = "" ' Initialize data array for Anomaly Score

For Each key In graphData.Keys
    ' Append dates (keys) to labels
    labels = labels & """" & key & ""","
    
    ' Append values to respective datasets
    Dim values
    values = graphData(key)
    staleObjectsData = staleObjectsData & values(0) & ","
    privilegiedGroupData = privilegiedGroupData & values(1) & ","
    trustData = trustData & values(2) & ","
    anomalyData = anomalyData & values(3) & ","
Next

' Remove trailing commas
If Len(labels) > 0 Then
    labels = Left(labels, Len(labels) - 1)
End If

If Len(staleObjectsData) > 0 Then
    staleObjectsData = Left(staleObjectsData, Len(staleObjectsData) - 1)
End If

If Len(privilegiedGroupData) > 0 Then
    privilegiedGroupData = Left(privilegiedGroupData, Len(privilegiedGroupData) - 1)
End If

If Len(trustData) > 0 Then
    trustData = Left(trustData, Len(trustData) - 1)
End If

If Len(anomalyData) > 0 Then
    anomalyData = Left(anomalyData, Len(anomalyData) - 1)
End If

' Build chartData object
Dim chartData
chartData = "{labels: [" & labels & "], datasets: [{label: 'Stale Objects Score', data: [" & staleObjectsData & "], borderColor: 'blue', fill: false}, {label: 'Privilegied Group Score', data: [" & privilegiedGroupData & "], borderColor: 'green', fill: false}, {label: 'Trust Score', data: [" & trustData & "], borderColor: 'yellow', fill: false}, {label: 'Anomaly Score', data: [" & anomalyData & "], borderColor: 'purple', fill: false}]}"

%>

<!DOCTYPE html>
<html>
<head>
    <title>PingCastle Data Visualization</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <h1>PingCastle Data Visualization</h1>

    <!-- Score Chart -->
    <div class="chart-container" style="position: relative; height:400px; width:1400px">
       <canvas id="ScoreChart""></canvas>
    </div>

    <script>
        // Inject server-side data into JavaScript
        var chartData = <%= chartData %>;

        console.log(chartData); // Debugging: Log chartData to ensure correctness

        // Render Score Chart
        var ctx1 = document.getElementById('ScoreChart').getContext('2d');
        new Chart(ctx1, {
            type: 'line',
            data: {
                labels: chartData.labels, // Dates as labels
                datasets: chartData.datasets // Score datasets
            },
            options: {
                responsive: true,
		maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true,
                        stepSize: 1
                    }
                }
            }
        });
    </script>
</body>
</html>
