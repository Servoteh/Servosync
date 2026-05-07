Attribute VB_Name = "_TEST1"
Option Compare Database
Option Explicit
Private Function CNN_SetTest()
'Const stDBName = "QBigBit"
Const stDBName = "Expro"

   CNN_CurrentDataBase = "DRIVER=SQL Server;SERVER=P50\SQLEXPRESS;Trusted_Connection=Yes;APP=QBigBit;DATABASE=" & stDBName
   CNN_CFG_Lokal = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=C:\SHARES\AcBaze\QBigBit\BB_CFG_Lokal.mdb;Persist Security Info=False"
   CNN_CFG_Global = "DRIVER=SQL Server;SERVER=P50\SQLEXPRESS;Trusted_Connection=Yes;APP=QBigBit;DATABASE=" & stDBName
   CNN_MasterDB = "DRIVER=SQL Server;SERVER=P50\SQLEXPRESS;Trusted_Connection=Yes;APP=QBigBit;DATABASE=" & stDBName
   CNN_SHUTTLE = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=C:\SHARES\AcBaze\QBigBit\SHUTTLE\Shuttle.mdb;Persist Security Info=False"
   CNN_ESDB = "DRIVER=SQL Server;SERVER=P50\SQLEXPRESS;Trusted_Connection=Yes;APP=QBigBit;DATABASE=ES_Synch_DB"
   CNN_TempDB = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=C:\SHARES\AcBaze\QBigBit\BB_TMP.mdb;Persist Security Info=True"
   CNN_FIT = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=C:\SHARES\AcBaze\QBigBit\BB_FIT.mdb;Persist Security Info=False"
   CNN_CFG_Sys = "DRIVER=SQL Server;SERVER=P50\SQLEXPRESS;Trusted_Connection=Yes;APP=QBigBit;DATABASE=" & stDBName
   
End Function
Public Function PrikaziPropZaQName(Name As String)
On Error GoTo Err_Point

Dim i As Integer
Dim qDef As DAO.QueryDef

Set qDef = CurrentDb.QueryDefs(Name)

    For i = 0 To qDef.Properties.Count
        Debug.Print i;
        Debug.Print qDef.Properties(i).Name & "= ";
        Debug.Print qDef.Properties(i).Value
     Next i
Exit_Point:
On Error Resume Next

Exit Function

Err_Point:
 Debug.Print "err.Number=" & err.Number & " " & err.Description
 Resume Next
End Function

Public Function Test()
On Error GoTo Err_Point
 Dim i As Integer
 Dim qDef As DAO.QueryDef
 Dim qdefODBC As QueryDef
 Dim qdefACC As QueryDef
 
 'Debug.Print "CurrentDb.QueryDefs.Count="; CurrentDb.QueryDefs.Count
 'Debug.Print "CurrentProject.AllForms.Count="; CurrentProject.AllForms.Count
 Set qdefODBC = CurrentDb.QueryDefs("ODBC_CFG_Global")
 Set qdefACC = CurrentDb.QueryDefs("Acc_CFG_Sys")
 
 For Each qDef In CurrentDb.QueryDefs
  If qDef.Name = "ODBC_CFG_Global" Then
     PrikaziPropZaQName (qDef.Name)
  End If
 Next
Exit_Point:
On Error Resume Next

Exit Function

Err_Point:
 Debug.Print "err.Number=" & err.Number & " " & err.Description
 Resume Next
End Function

Public Function TEST_PopraviSveBBQueryDefZaUDF()
On Error GoTo Err_Point
Dim rstQueryDef As DAO.Recordset
Dim stSQL As String

Set rstQueryDef = CurrentDb.OpenRecordset("SELECT * FROM BBQueryDef WHERE ProcType='UDF'", dbOpenDynaset)
While Not rstQueryDef.EOF
    stSQL = PopraviBBQueryDefZaUDF(rstQueryDef!QueryName)
    Debug.Print "            " & rstQueryDef!QueryName
    Debug.Print stSQL
    
 rstQueryDef.MoveNext
Wend

Exit_Point:
 On Error Resume Next
 
 rstQueryDef.Close
 Set rstQueryDef = Nothing
 
Exit Function

Err_Point:
 BBErrorMSG err, ""
 Resume Exit_Point
End Function
Public Sub TEST_ConvertstringToArrayLines(stString As String)
 Dim originalString As String
 Dim i As Integer
 Dim myArray() As String

'originalString = "hi there" & vbCrLf & "Pera tera kera"
    myArray = ConvertstringToArrayLines(stString)
 For i = LBound(myArray) To UBound(myArray)
    Debug.Print i, myArray(i)
 Next i
End Sub

Public Function OpenFormForTest(Optional stImeForme As String = "CFGReadWrite")
 
    CNN_SetTest
    DoCmd.OpenForm stImeForme

End Function
