<%@ Page Language="VB" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Text.RegularExpressions" %>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Sorted HTML File List</title>
  <style>
    table {
      border-collapse: collapse;
      width: 800px;
    }
    table th, table td {
      padding: 8px;
      border: 1px solid #ccc;
      text-align: left;
    }
  </style>
</head>
<body>
  <table align="center">
    <thead>
      <tr>
	<td colspan=2><h1>Sorted HTML Files by Folder Date and Time</h1></td>
      </tr>
      <tr>
        <th width="20%">Scan time</th>
        <th width="80%">PingCastle Report</th>
      </tr>
    </thead>
    <tbody>
<%
    ' Path to the directory containing folders with XML and HTML files
    Dim rootFolderPath As String = Server.MapPath(".")
    Dim folderRegex As New Regex("^\d{2}-\d{2}-\d{4} - \d{2}-\d{2}$") ' Regex to match folders with "dd-MM-yyyy - HH-mm" format

    Dim sortedFolders As New SortedList(Of DateTime, String)()

    ' Step 1: Traverse the folders
    For Each subfolder As String In Directory.GetDirectories(rootFolderPath)
        Dim folderName As String = Path.GetFileName(subfolder)

        Dim dateMatch As Match = folderRegex.Match(folderName)
        If dateMatch.Success Then
            Dim dateTimeParts As String() = dateMatch.Value.Split(" - ")
            Dim folderDateTime As DateTime
        
            If dateTimeParts.Length = 3 Then
                ' Folder has both date and time
                If DateTime.TryParseExact(dateTimeParts(0) & " " & dateTimeParts(2), "dd-MM-yyyy HH-mm", Nothing, System.Globalization.DateTimeStyles.None, folderDateTime) Then
                    sortedFolders(folderDateTime) = subfolder
                Else
                    Response.Write("Failed to parse date-time for folder: " & folderName & "<br>")
                End If
            ElseIf dateTimeParts.Length = 1 Then
                ' Folder has only the date
                If DateTime.TryParseExact(dateTimeParts(0), "dd-MM-yyyy", Nothing, System.Globalization.DateTimeStyles.None, folderDateTime) Then
                    sortedFolders(folderDateTime) = subfolder
                Else
                    Response.Write("Failed to parse date for folder: " & folderName & "<br>")
                End If
            Else
                Response.Write("Unexpected folder name format: " & folderName & "<br>")
            End If
        End If
    Next

    ' Step 2: Sort folders and generate the table
    For Each folderDateTime As DateTime In sortedFolders.Keys
        Dim folderPath As String = sortedFolders(folderDateTime)

        ' Find the HTML file in the folder
        Dim htmlFilePath As String = Directory.GetFiles(folderPath, "*.html").FirstOrDefault()

        If Not String.IsNullOrEmpty(htmlFilePath) Then
            Dim htmlFileName As String = Path.GetFileName(htmlFilePath)

            ' Write a table row with the converted date-time and a link to the HTML file
            Response.Write("<tr>")
            Response.Write("<td>" & folderDateTime.ToString("dd/MM/yyyy HH:mm") & "</td>")
            Response.Write("<td><a href='" & htmlFilePath.Replace(Server.MapPath(""), ".") & "'>" & htmlFileName & "</a></td>")
            Response.Write("</tr>")
        End If
    Next
%>
    </tbody>
  </table>
</body>
</html>
