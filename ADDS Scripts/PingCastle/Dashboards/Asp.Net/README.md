## PingCastle Dashbords.  
To continue the use of Copilot, I have "converted" the Clasic ASP, to ASP.Net running on same webserver, just in another application.
  
Requires the PingCastle repports to be in seperate folders with dateformat like the "Create-Report.ps1" do that is used by my "Install - PingCastle webservice.ps1" script.
  

### Default.aspx  
Combines the Calender and GraphJs into one page.  
takes a minute to load, the server needs to parse all the xml files.  
  
![Default](https://github.com/SysAdminDk/MS-Infrastructure/blob/20007d25641a6d441cac440eb0287d51932415c7/ADDS%20Scripts/PingCastle/Dashboards/images/Default-example.png)
  
### ListRules.aspx  
Finds ALL xml files in the folder, and list ALL findings, mark the removed with a date.  
takes a minute to load, the server needs to parse all the xml files.  
  
![Rules](https://github.com/SysAdminDk/MS-Infrastructure/blob/20007d25641a6d441cac440eb0287d51932415c7/ADDS%20Scripts/PingCastle/Dashboards/images/Findings-Example.png)
