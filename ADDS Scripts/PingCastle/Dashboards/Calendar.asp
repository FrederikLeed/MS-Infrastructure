<%@ Language=VBScript %>
<%
Function addLeadingZero(val)
  If val < 10 Then
    addLeadingZero = "0" & val
  Else
    addLeadingZero = val
  End If
End Function

Dim fs, folder, subfolder, item, subitem
Dim folderdate, dateParts, reportDates, reportDateKey
Set fs = CreateObject("Scripting.FileSystemObject")
Set folder = fs.GetFolder(Server.MapPath("."))
Set reportDates = Server.CreateObject("Scripting.Dictionary")

For Each item In folder.SubFolders
  folderdate = Split(item.Name, " - ")
  If UBound(folderdate) >= 0 Then
    dateParts = Split(folderdate(0), "-")
    If UBound(dateParts) = 2 Then
      reportDateKey = dateParts(2) & "-" & dateParts(1) & "-" & dateParts(0)
      Set subfolder = fs.GetFolder(Server.MapPath(item.Name))
      For Each subitem In subfolder.Files
        If LCase(Right(subitem.Name, 5)) = ".html" Then
          If Not reportDates.Exists(reportDateKey) Then
            reportDates.Add reportDateKey, item.Name & "/" & subitem.Name
          End If
          Exit For
        End If
      Next
    End If
  End If
Next

Dim latestDateKey, latestHtmlPath
latestDateKey = ""
latestHtmlPath = ""

For Each key In reportDates
  If latestDateKey = "" Or key > latestDateKey Then
    latestDateKey = key
    latestHtmlPath = reportDates(key)
  End If
Next

Response.Write("<!DOCTYPE html>")
Response.Write("<html lang='en'>")
Response.Write("<head>")
Response.Write("<meta charset='UTF-8'>")
Response.Write("<meta name='viewport' content='width=device-width, initial-scale=1.0'>")
Response.Write("<meta http-equiv='X-UA-Compatible' content='ie=edge'>")
Response.Write("<title>PingCastle Reports</title>")
Response.Write("<style>")
Response.Write("table.calendar {border-collapse: collapse; margin: 10px 0; width: 100%;}")
Response.Write("table.calendar th {padding: 10px; background-color: #f0f0f0; text-align: center;}")
Response.Write("table.calendar td {width: 40px; height: 40px; text-align: center; border: 1px solid #ccc; font-size: 16px;}")
Response.Write(".today {background-color: #ffffcc; font-weight: bold;}")
Response.Write(".monthname {font-weight: bold; text-align: center; padding: 5px; background-color: #f0f0f0;}")
Response.Write("a {text-decoration: none; color: #000;}")
Response.Write("a:hover {color: #0073e6;}")
Response.Write(".footer {text-align: center; font-size: 12px; margin-top: 20px; padding: 10px; background-color: #f0f0f0;}")
Response.Write("</style>")
Response.Write("</head>")

Response.Write("<body>")

Response.Write "<table align=center><tr>"

Response.Write "<tr>"

Dim baseDate, i, targetYear, targetMonth
baseDate = Now()

For i = 2 To 0 Step -1
  Dim currentDate, firstDayOfMonth, daysInMonth, weekdayOffset, dayCounter
  currentDate = DateAdd("m", -i, baseDate)
  targetYear = Year(currentDate)
  targetMonth = Month(currentDate)

  firstDayOfMonth = DateSerial(targetYear, targetMonth, 1)
  daysInMonth = Day(DateSerial(targetYear, targetMonth + 1, 0))
  weekdayOffset = Weekday(firstDayOfMonth) - 1 ' Sunday = 1

  Response.Write "<td valign='top' style='width: 33%;'>"
  Response.Write "<div class='monthname'>" & MonthName(targetMonth) & " " & targetYear & "</div>"
  Response.Write "<table class='calendar'>"
  Response.Write "<tr><th>Sun</th><th>Mon</th><th>Tue</th><th>Wed</th><th>Thu</th><th>Fri</th><th>Sat</th></tr><tr>"

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

    If reportDates.Exists(dateKey) Then
      Response.Write "<td" & cssClass & "><b><a href='./" & reportDates(dateKey) & "'>" & dayCounter & "</a></b></td>"
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

  Response.Write "</tr></table>"
  Response.Write "</td>"
Next

Response.Write "</tr>"
Response.Write "<tr><td align=center colspan=3>&nbsp;</a></td></tr>"
Response.Write "<tr><td align=center colspan=3><a href='./ad_hc_rules_list.html'>PingCastle Healthcheck rules</a></td></tr>"
Response.Write "</table>"

Response.Write("</body>")
Response.Write("</html>")
%>
