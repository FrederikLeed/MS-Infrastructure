<%
Response.Write("<!DOCTYPE html>")
Response.Write("<html lang='en'>")
Response.Write("<head>")
Response.Write("<meta charset='UTF-8'>")
Response.Write("<meta name='viewport' content='width=device-width, initial-scale=1.0'>")
Response.Write("<meta http-equiv='X-UA-Compatible' content='ie=edge'>")

function addLeadingZero(value)
  addLeadingZero = value
  if value < 10 then
    addLeadingZero = "0" & value
  end if
end function

Dim today, sYear, sMonth, sDay, folderdate, fs, folder, subfolder, file, item, url
dim subitem, currentDate, foundHtml, maxLookbackDays, i, destinationurl


today = now()
sYear = Year(today)
sMonth = addLeadingZero(Month(today))
sDay = addLeadingZero(Day(today))

set fs = CreateObject("Scripting.FileSystemObject")
set folder = fs.GetFolder(Server.MapPath("./"))

foundHtml = False
maxLookbackDays = 14

For i = 0 To maxLookbackDays
  currentDate = DateAdd("d", -i, Now())
  sYear = Year(currentDate)
  sMonth = addLeadingZero(Month(currentDate))
  sDay = addLeadingZero(Day(currentDate))

  For Each item In folder.SubFolders
    folderdate = Split(item.Name, " - ")
    If folderdate(0) = sDay & "-" & sMonth & "-" & sYear Then
      Set subfolder = fs.GetFolder(Server.MapPath("./" & item.Name & "/"))
      For Each subitem In subfolder.Files
        If LCase(Right(subitem.Name, 5)) = ".html" Then

          destinationurl = "./" & item.Name & "/" & subitem.Name
          Response.Write("<meta HTTP-EQUIV='refresh' content='5;url=" & destinationurl & "'>")
          foundHtml = True
          Exit For
  
        End If
      Next

    End If
    If foundHtml Then Exit For
  Next

  If foundHtml Then Exit For
Next

Response.Write("<title>PingCastle Reports.</title>")
Response.Write("</head>")
Response.Write("<body>")

if destinationurl <> "" Then

  Response.Write("<H3>You wil be redirected to the latest PingCastle report in 5 sec.</H3>")
  Response.Write("Click <a href='" & destinationurl & "'>here</a> to skip the wait.<br>")

  if fs.FileExists(Server.MapPath(".") & "\ad_hc_rules_list.html") Then
    Response.Write("<br><br>")
    Response.Write("<a href='./ad_hc_rules_list.html'>PingCastle Healthcheck rules</a>")
  End If

Else

  Response.Write("<H3>No PingCastle reports available</H3>")

End If

if folder.SubFolders.count > 0 Then
  Response.Write("<br><br>")
  Response.Write("If you need to se a older reports, use the link below to goto the list of older reports.<br>")
  Response.Write("<br>")
  Response.Write("<a href='./list.asp'>List all report dates</a><br>")
  Response.Write("</body>")
  Response.Write("</html>")
End If
%>