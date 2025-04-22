## PingCastle Dashbords.  
It have been years since I last created any meningfull html or javascript, so this created with all the AI help I can get, ChatGpt and Copilot.
just to have a little fun with the data avalible, feel free to copy and modify.
  
Requires the PingCastle repports to be in seperate folders with dateformat like the "Create-Report.ps1" do that is used by my "Install - PingCastle webservice.ps1" script.
  

### Default.asp  
Combines the Calender and GraphJs into one page.  
takes a minute to load, the server needs to parse all the xml files.  
  
![Default](https://github.com/SysAdminDk/MS-Infrastructure/blob/20007d25641a6d441cac440eb0287d51932415c7/ADDS%20Scripts/PingCastle/Dashboards/images/Default-example.png)
  
### ListRules.asp  
Finds ALL xml files in the folder, and list ALL findings, mark the removed with a date.  
takes a minute to load, the server needs to parse all the xml files.  
  
![Rules](https://github.com/SysAdminDk/MS-Infrastructure/blob/20007d25641a6d441cac440eb0287d51932415c7/ADDS%20Scripts/PingCastle/Dashboards/images/Findings-Example.png)
  
### Calender.asp  
Shows the last 3 monts with links to the html reports.  
  
![Calender](https://github.com/SysAdminDk/MS-Infrastructure/blob/4702c119e1785850ba130b1b2204c95eda43299d/ADDS%20Scripts/PingCastle/Dashboards/images/Calender-example.png)
  
### GraphJS  
Show a graph with the 4 scores, 3 month back.  
takes a minute to load, the server needs to parse all the xml files.  
  
![GraphJS](https://github.com/SysAdminDk/MS-Infrastructure/blob/a3d4f99e9d8621b9d0b9ed2e96a6a77cab0c8ab8/ADDS%20Scripts/PingCastle/Dashboards/images/GraphJS-example.png)
