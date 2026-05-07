Attribute VB_Name = "Sys"
Option Compare Database
Option Explicit
'******************************************************
'Funkcije iz ovog modula ne zavise od linkovanih tabela
'ali mogu da utièu na linkove
'
'sve mora da radi ultra brzo
'ne sme da zavisi od toga da li je Access ili ODBC
'******************************************************
'*********************************************************************
'08-08-2021
Private Declare PtrSafe Function InternetGetConnectedState Lib "wininet.dll" _
(ByRef dwflags As Long, ByVal dwReserved As Long) As Long

Public Function GetInternetConnectedState() As Boolean
  GetInternetConnectedState = InternetGetConnectedState(0&, 0&)
End Function
'08-08-2021
'*********************************************************************
Public Function GetIPAdress()
Dim myWMI As Object
Dim myobj As Object
Dim itm

Set myWMI = GetObject("winmgmts:\\.\root\cimv2")
Set myobj = myWMI.ExecQuery("Select * from Win32_NetworkAdapterConfiguration Where IPEnabled = True")
For Each itm In myobj
  GetIPAdress = itm.IPAddress(0)
  Exit Function
Next
End Function

Public Function F_SysConnectionTimeOut() As Integer
Dim RetValInt As Integer
 RetValInt = Nz(ReadParametar("CFG_Sys", "SysConnectionTimeOut"), 15)
 F_SysConnectionTimeOut = RetValInt
End Function
Public Function TestConnection(ByVal CNNString, ConnectionTimeout) As Boolean
On Error GoTo err_Func
'Provider=Microsoft.Access.OLEDB.10.0;Persist Security Info=True;Data Source=P50\SQLEXPRESS;Integrated Security=SSPI;Initial Catalog=VuleMarket;Data Provider=SQLOLEDB
'ODBC;DRIVER=SQL Server;SERVER=P50\SQLEXPRESS;Trusted_Connection=Yes;APP=Microsoft Office 2010;DATABASE=VuleMarket
'Provider=Microsoft.Access.OLEDB.10.0;Persist Security Info=True;Data Source=(local);Integrated Security=SSPI;Initial Catalog=VuleMarket;Data Provider=SQLOLEDB
    Dim retValOk As Boolean
    Dim cnn As New ADODB.Connection
    
    If IsMissing(CNNString) Then ' Or IsEmpty(CnnString) Or IsNull(CnnString) Or Nz(CnnString, "") = "" Then
     'CnnString = "Provider=Microsoft.Access.OLEDB.10.0;Persist Security Info=True;Data Source=(local);Integrated Security=SSPI;Initial Catalog=VuleMarket;Data Provider=SQLOLEDB"
     'CnnString = "Provider=Microsoft.Access.OLEDB.10.0;Persist Security Info=True;Data Source=P50\SQLEXPRESS;Integrated Security=SSPI;Initial Catalog=VuleMarket;Data Provider=SQLOLEDB"
     ' CnnString = "Provider=Microsoft.Access.OLEDB.10.0;Persist Security Info=True;Data Source=(local);Integrated Security=SSPI;Initial Catalog=master;Data Provider=SQLOLEDB"
     'CnnString = "ODBC;DRIVER=SQL Server;SERVER=P50\SQLEXPRESS;Trusted_Connection=Yes;APP=Microsoft Office 2010;DATABASE=master"
     'CnnString = "Driver={SQL Server Native Client 10.0};Server=myServerAddress;Database=myDataBase;Trusted_Connection=yes;"
     'CnnString = "DRIVER={SQL Server};SERVER=P50\SQLEXPRESS;Trusted_Connection=Yes;APP=Microsoft Office 2010;DATABASE=master"
     CNNString = "DRIVER=SQL Server;SERVER=TOSHIBA\SQLEXPRESS;Trusted_Connection=Yes;APP=Microsoft Office 2010;DATABASE=master"
    End If
    
    cnn.ConnectionString = CNNString
    cnn.ConnectionTimeout = ConnectionTimeout 'Potroši što manje vremena
    'On Error Resume Next
    'cnn.Provider = "Microsoft.Access.OLEDB.10.0" ', MSDASQL
    'cnn.Properties("Data Provider").Value = "SQLOLEDB"
    
    cnn.Open
    If cnn.State = adStateOpen Then
     'PrikazisvePropZaObj cnn
     retValOk = True
     cnn.Close
    Else
     retValOk = False
    End If
 err.Clear
 
 Set cnn = Nothing
 TestConnection = retValOk
Exit Function
err_Func:
 Rem Debug.Print "err="; Err.Number, Err.Description; ""
 err.Clear
 retValOk = False
 Resume Next
End Function
'*********************************************
Private Function PrikazisvePropZaCnn(cnn As ADODB.Connection)
 Dim i As Integer
 Debug.Print cnn.ConnectionString
 For i = 0 To cnn.Properties.Count() - 1
  Debug.Print cnn.Properties(i).Name; "="; cnn.Properties(i).Value
 Next i
End Function

Private Sub RefreshLinkOutput(dbsTemp As DAO.Database, imeTabele As String)

   Dim rstRemote As DAO.Recordset
   Dim intCount As Integer

   ' Open linked table.
   Set rstRemote = _
      dbsTemp.OpenRecordset(imeTabele)

   intCount = 0

   ' Enumerate Recordset object, but stop at 50 records.
   With rstRemote
      Do While Not .EOF And intCount < 50
         Debug.Print , .Fields(0), .Fields(1)
         intCount = intCount + 1
         .MoveNext
      Loop
      If Not .EOF Then Debug.Print , "[more records]"
      .Close
   End With
 rstRemote.Close
 Set rstRemote = Nothing
End Sub


