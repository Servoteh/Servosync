Attribute VB_Name = "LIB_BOSSON"
Option Compare Database
Option Explicit

Public Function ExportBossonCSV(imetkf As String, ZaDatum As Date) As Boolean
   On Error GoTo errsnimi

    Dim BigBit As DAO.Database
    Dim QBosson As DAO.QueryDef
    Dim RstBosson As DAO.Recordset
    Dim imeteke As String
    Dim tkf As Variant
    Dim cenast As String
    Dim tmpst As String
    Dim sep As String
    Dim UspesnoPoslato As Boolean
    
    
    sep = ","
 
    DoCmd.Hourglass True

    Set BigBit = CurrentDb
    Set QBosson = BigBit.QueryDefs("Bosson_QVPiMP")
    QBosson.Parameters("[ZaDatum]") = ZaDatum
    
    Set RstBosson = QBosson.OpenRecordset()
    RstBosson.Sort = "DocumentID"
   
 
    imeteke = imetkf
    tkf = FreeFile
    Open imeteke For Output As tkf
   If RstBosson.RecordCount > 0 Then
    RstBosson.MoveFirst
   End If
   
   Do Until RstBosson.EOF

   tmpst = ""
   tmpst = tmpst & CStr(RstBosson![DocumentId]) & sep
   tmpst = tmpst & CStr(RstBosson![CustomerID]) & sep
   tmpst = tmpst & CStr(RstBosson![Customer]) & sep
   tmpst = tmpst & CStr(RstBosson![Fix104]) & sep
   tmpst = tmpst & CStr(RstBosson![EmployedID]) & sep
   tmpst = tmpst & CStr(Nz(RstBosson![ProductID], "")) & sep
   'tmpst = tmpst & CStr(RstBosson![Quantity]) & sep
   tmpst = tmpst & Format$(Round(RstBosson![Quantity], 3), "0.00")
   
   Print #tkf, tmpst

   RstBosson.MoveNext
   Loop
   Close tkf
    
    UspesnoPoslato = True
   
reserr:
'On Error Resume Next
   Close tkf

   Set RstBosson = Nothing
   Set QBosson = Nothing
   Set BigBit = Nothing
   DoCmd.Hourglass False
   ExportBossonCSV = UspesnoPoslato
 Exit Function

errsnimi:
 
  'MsgBox Error$ & "    errno: " & Err.Number
  UspesnoPoslato = False
  Resume reserr

End Function

Public Sub TihiExportBosson()
Dim imeteke As String
Dim DATUM As Date
Dim OK As Boolean
DATUM = Date
imeteke = InputBox("BazaZaTip('BOSSON')") ' BazaZaTip("BOSSON") & "\" & ObrniVelikiDatum(Datum) & ".CSV"
    OK = ExportBossonCSV(imeteke, DATUM)
End Sub
