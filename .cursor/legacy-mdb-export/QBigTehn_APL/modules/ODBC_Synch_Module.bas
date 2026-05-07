Attribute VB_Name = "ODBC_Synch_Module"
Option Compare Database
Option Explicit
'*****************************************************************
'*    OVO JE PRAVO!
'*****************************************************************
Public Function F_SynchMPDok(IDDok As Long, IDProdavnica As Long, IDKasa As Long) As Boolean
 Dim SynchMPDokIC As New ODBC_Synch_MPDok_Class
 If Not BBCFG.SysDisabledSynch Then 'provera da li je sys zabranio
    F_SynchMPDok = SynchMPDokIC.SynchronizeMPDok(IDDok, IDProdavnica, IDKasa)
 Else
    F_SynchMPDok = False
 End If
End Function
'*****************************************************************
Public Function F_SynchAllMPDok(Optional ByVal stWhereInput As String, Optional ByRef Ukupno As Long, Optional ByRef Uspesno As Long, Optional ByRef Neuspesno As Long) As Boolean
On Error GoTo Err_Point
  
  Dim BigBitDB As DAO.Database
  Dim rstMPDok As DAO.Recordset
  Dim stWhere As String
  
  Dim OK As Boolean
  Dim retValOk As Boolean
  
  Uspesno = 0
  Neuspesno = 0
  Ukupno = 0
  retValOk = True
  
  If BBCFG.SysDisabledSynch Then
     F_SynchAllMPDok = False
     MsgBox "Sinhronizacija onemoguæena" & vbCrLf & vbCrLf & "Parametar [SysDisabledSynch] = True", vbExclamation, "QMegaTeh"
     Exit Function
  End If
  
  If IsMissing(stWhereInput) Or Nz(stWhereInput) = "" Then
     stWhere = stWhereInput
  Else
     stWhere = stWhereInput
  End If
  
  stWhere = Replace(stWhere, "WHERE", "")
  If stWhere <> "" Then
   stWhere = " WHERE " & stWhere
  End If
  
  Set BigBitDB = CurrentDb
  Set rstMPDok = BigBitDB.OpenRecordset("SELECT * FROM T_MPDokumenta " & stWhere, dbOpenDynaset, dbReadOnly + dbSeeChanges)
  
  While Not rstMPDok.EOF
   OK = F_SynchMPDok(rstMPDok!IDDok, rstMPDok!IDProdavnica, rstMPDok!IDKasa)
   Ukupno = Ukupno + 1
    If OK Then
       Uspesno = Uspesno + 1
    Else
       Neuspesno = Neuspesno + 1
    End If
    
   retValOk = retValOk And OK
   rstMPDok.MoveNext
  Wend
  If IsLoaded("ODBC_Synch_PorukaOSinhronizaciji") Then
   DoCmd.Close acForm, "ODBC_Synch_PorukaOSinhronizaciji"
  End If
  
  If retValOk Then
   If Ukupno = 0 Then
    MsgBox "Nemate dokumenta za sinhronizaciju." & vbCrLf & vbCrLf & "za uslov: " & stWhere, vbInformation, "QMegaTeh"
   Else
    MsgBox "Sinhronizacija uspešno završena za " & Ukupno & " dokumenata." & vbCrLf & vbCrLf & "za uslov: " & stWhere, vbInformation, "QMegaTeh"
   End If
  Else
    MsgBox "Sinhronizacija nije uspešno završena za " & Neuspesno & " dokumenata od ukupno " & Ukupno & vbCrLf & vbCrLf & "za uslov: " & stWhere, vbExclamation, "QMegaTeh"
  End If
  
Exit_Point:
On Error Resume Next

   BigBitDB.Close
   Set BigBitDB = Nothing
   rstMPDok.Close
   Set rstMPDok = Nothing
   
   F_SynchAllMPDok = retValOk
  Exit Function
  
Err_Point:
  BBErrorMSG err, "F_SynchAllMPDok"
  retValOk = False
  Resume Exit_Point:
End Function

Private Function Test1Synch()
 Dim ODBCSync As New ODBC_Synch_Class
 Dim OK As Boolean

 OK = ODBCSync.CheckRequest
 If ODBCSync.HasRequest Then
  OK = OK And ODBCSync.Synchronize
  'Debug.Print ODBCSync.LogText
 End If
 Test1Synch = OK
End Function
Private Function test2Synch()
  Dim ODBCSync As New ODBC_Synch_Class
  test2Synch = ODBCSync.Synchronize
End Function
Private Function test3Synch()
  Dim ODBCSync As New ODBC_Synch_Class
  test3Synch = ODBCSync.CheckRequest
End Function
Private Function Test_FillRstSynchRequest() As Boolean
On Error GoTo Err_Point
 Dim retValOk As Boolean
 Dim pCMD As New ADODB.Command
 Dim CNNString As String
 Dim pRstSynchRequest As New ADODB.Recordset
 Dim pHasRequest As Boolean
 Dim pErrNumber As Long
 
 CNNString = Nz(BazaZaTip("MasterDB"), "")
 CNNString = "ODBC;Description=QBigBit;DRIVER=SQL Server;SERVER=(local);Trusted_Connection=Yes;APP=Microsoft Office 2010;DATABASE=QBigBit;Regional=Yes"
 CNNString = "DRIVER=SQL Server;SERVER=(local);APP=Microsoft Office 2010;DATABASE=QBigBit;Regional=Yes"
 CNNString = "ODBC;DRIVER=SQL Server;SERVER=(local);UID=QBigBit;Password=QbigBit.9496;APP=Microsoft Office 2010;DATABASE=VuleMarket"
 CNNString = "DRIVER=SQL Server;SERVER=(local);UID=QBigBit;Password=QbigBit.9496;APP=Microsoft Office 2010;DATABASE=VuleMarket"
 
 pCMD.ActiveConnection = CNNString ', "QBigBit", "QbigBit.9496"
 pCMD.ActiveConnection.CursorLocation = adUseClient
 pCMD.CommandType = adCmdStoredProc
 pCMD.CommandText = "spSynchRequestGetRST"
 pCMD.Parameters.Refresh
 pCMD.Parameters("@ClientID").Value = BigBit_UID
 
 Set pRstSynchRequest = pCMD.Execute
 pHasRequest = (pRstSynchRequest.RecordCount > 0)
 
Exit_Point:
 On Error Resume Next
 Test_FillRstSynchRequest = (pErrNumber = 0)
Exit Function

Err_Point:
  BBErrorMSG err
  'SetMyError err
  pErrNumber = err.Number
  retValOk = False
  Resume Exit_Point:
End Function
