VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "ODBC_Synch_Class"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private pCNN As New ADODB.Connection
Private pCMD As New ADODB.Command
Private pRstSynchRequest As ADODB.Recordset
Private pRstSyncProcLines As ADODB.Recordset

Private pIDProc As Long
'Private pProcName As String
Private pHasRequest As Boolean
Private pLogText As String
Private pLogFileName As String
Private pShuttleFileName As String
Private pSyncFormName As String 'na ovoj formi se nalaze i parametri...
Private pMessageFromMaster As String

Private pMakeNewSHUTTLEBeforeSync As Boolean

Private pErrNumber As Long
Private pErrDescription As String
Private pCNNString As String

Private Sub SetMyError(err As ErrObject)
 pErrNumber = err.Number
 If BBCFG.SysSuspendSynch Then
  pErrDescription = "Synch Suspended"
 Else
  pErrDescription = err.Description
 End If
End Sub

Public Function MakeNewSHUTTLE() As Boolean
 On Error GoTo Err_MakeNewSHUTTLE
 Dim retValOk As Boolean
 
    
    If Nz(pShuttleFileName, "") <> "" Then
     retValOk = BBCreateDatabase(pShuttleFileName, True)
    Else
     retValOk = False
    End If
    
Exit_MakeNewSHUTTLE:
MakeNewSHUTTLE = retValOk
    Exit Function

Err_MakeNewSHUTTLE:
    MsgBox err.Description
    retValOk = False
    Resume Exit_MakeNewSHUTTLE
End Function
Private Function FillRstSynchRequest() As Boolean
On Error GoTo Err_Point
 Dim retValOk As Boolean

 pCMD.ActiveConnection.CursorLocation = adUseClient
 pCMD.CommandType = adCmdStoredProc
 pCMD.CommandText = "spSynchRequestGetRST"
 pCMD.Parameters.Refresh
 pCMD.Parameters("@ClientID").Value = BigBit_UID
 
 Set pRstSynchRequest = pCMD.Execute
 pHasRequest = (pRstSynchRequest.RecordCount > 0)
 
Exit_Point:
 On Error Resume Next
 FillRstSynchRequest = (pErrNumber = 0)
Exit Function

Err_Point:
  'BBErrorMSG err
  SetMyError err
  retValOk = False
  Resume Exit_Point:
End Function
Public Function CheckRequest() As Boolean
On Error GoTo Err_Point

 Dim trebaSynch As Boolean
 Dim retValOk As Boolean
 
 retValOk = True
 
 If Not OpenConnection Then
    retValOk = False
    CheckRequest = False
    Exit Function
 End If
 
 FillRstSynchRequest
 
 If pHasRequest Then
    pMessageFromMaster = pRstSynchRequest!MessageToClient
 Else
    pMessageFromMaster = ""
 End If
Exit_Point:
On Error Resume Next
    pHasRequest = (pRstSynchRequest.RecordCount > 0)
    'CheckRequest = pHasRequest
    CheckRequest = retValOk
Exit Function
Err_Point:
  'MsgBox "ErrNo: " & Err.Number & vbCrLf & Err.Description
  SetMyError err
  retValOk = False
  Resume Exit_Point:
End Function
Public Property Get HasRequest() As String
   HasRequest = pHasRequest
End Property
Public Property Get IDProc() As Long
   IDProc = pIDProc
End Property
Private Function FillRstProcLines()
 pCMD.ActiveConnection.CursorLocation = adUseClient
 pCMD.CommandType = adCmdStoredProc
 pCMD.CommandText = "spSynchProcLinesGetRST"
 pCMD.Parameters.Refresh
 pCMD.Parameters("@IDProc").Value = pIDProc
 Set pRstSyncProcLines = pCMD.Execute
End Function
Public Property Let IDProc(ByVal vNewValue As Long)
  pIDProc = vNewValue
  FillRstProcLines
  'pProcName = DLookup("ProcName", "ODBC_Synch_Proc", "IDProc=" & pIDProc)
End Property
Private Function RunSyncQuery(SQLText, QueryID, QueryName, ByRef Komentar) As Boolean
'Modifikovano: 12-08-2021
On Error GoTo Err_RunSyncQuery
    Const BrZnLn = 120
    Dim stSQLText As String
    Dim StartTime As Variant, endTime As Variant
    Dim recaff As Long
    Dim retValOk As Boolean
    
    retValOk = True
    
    stSQLText = SQLText

    '12-08-2021'Komentar = Komentar & String(BrZnLn, "-")
    '12-08-2021'Komentar = Komentar & vbCrLf & Now() & " Pokreæem upit IDQuery= " & QueryID & " " & QueryName & vbCrLf
    DoCmd.Hourglass True
    
    StartTime = Timer
      
    If BBQueryTool.ExecuteSQLActionQuery(stSQLText, recaff) Then
       'Komentar = Komentar & "RecordsAffected= " & recaff
       '12-08-2021
       Komentar = Komentar & ADO_Komentar
       retValOk = True
      Else
       Komentar = Komentar & "ERROR!"
       retValOk = False
      End If
    endTime = Timer
    
    DoCmd.Hourglass False
   
   
Exit_RunSyncQuery:
 On Error Resume Next
    '12-08-2021 Komentar = Komentar & vbCrLf & Now() & " Završen upit IDQuery= " & QueryID & " " & QueryName & " Trajanje= " & Format(EndTime - StartTime, "###0.00000") & " sec."
    '12-08-2021 Komentar = Komentar & vbCrLf & String(BrZnLn, "-") & vbCrLf

    DoCmd.Hourglass False
    DoCmd.SetWarnings True
    RunSyncQuery = retValOk
 Exit Function

Err_RunSyncQuery:
    'MsgBox Err.Description
    BBErrorMSG err, "RunSyncQuery(QueryID= " & QueryID & ", QueryName= " & QueryName
     DoCmd.SetWarnings True
     retValOk = False
    Resume Exit_RunSyncQuery
    
End Function

Public Function ExecuteProc(Optional nIDProc As Long, Optional WithRespond As Boolean = False, Optional WithLog As Boolean = False) As Boolean
On Error GoTo Err_Point:
 Dim pPoruka As String
 Dim retValOk As Boolean
 Dim OK As Boolean

  OK = True
  retValOk = True
  If Not IsMissing(nIDProc) Then
     Me.IDProc = nIDProc
  End If
 
  pRstSyncProcLines.MoveFirst
  While Not pRstSyncProcLines.EOF
     OK = RunSyncQuery(pRstSyncProcLines!SQLText, pRstSyncProcLines!IDQuery, pRstSyncProcLines!QueryName, pLogText)
     retValOk = OK And retValOk
     If Not OK Then
      pPoruka = "Došlo je do greške prilikom izvršavanja upita [" & pRstSyncProcLines!QueryName & "]."
      pPoruka = pPoruka & vbCrLf & vbCrLf & "Da li nastavljate proces sinhronizacije?"
      If BBPitanje(pPoruka) = False Then
       GoTo Exit_Point
      End If
     End If
     pRstSyncProcLines.MoveNext
  Wend
  If WithRespond Then
    Me.SaveRespond 0, "IDProc= " & CStr(nIDProc)
  End If
  If WithLog Then
     SaveStringToFile pLogFileName, pLogText
  End If
Exit_Point:
On Error Resume Next
 ExecuteProc = retValOk
 Exit Function
 
Err_Point:
 BBErrorMSG err, "ODBC_Synch_Class.ExecuteProc(..)"
 retValOk = False
 Resume Exit_Point
End Function
Public Function Synchronize() As Boolean
On Error GoTo Err_Point
Dim ZatvoriSyncFormOnExit As Boolean
Dim tmpTimerInterval As Long
Dim tmpCloseBezPitanja As Boolean
Dim retValOk As Boolean
Dim OK As Boolean

 'pErr.Clear
 retValOk = True
 OK = True
 
 If Not IsLoaded(pSyncFormName) Then
  DoCmd.OpenForm pSyncFormName, AcFormView.acNormal, , , , AcWindowMode.acHidden
  ZatvoriSyncFormOnExit = True
 Else
  ZatvoriSyncFormOnExit = False
 End If
 
 tmpTimerInterval = Forms(pSyncFormName).TimerInterval
 Forms(pSyncFormName).TimerInterval = 0
 
 tmpCloseBezPitanja = Forms(pSyncFormName).CloseBezPitanja
 Forms(pSyncFormName).CloseBezPitanja = True
 Forms(pSyncFormName)!Label_NextCheck.Caption = "START: Poziv iz koda"
 
 'FillRstSynchRequest
 CheckRequest
 If pHasRequest Then
    pRstSynchRequest.MoveFirst
    While Not pRstSynchRequest.EOF
      OK = ExecuteProc(pRstSynchRequest!IDProcForExecution)
      retValOk = OK And retValOk
      SaveRespond pRstSynchRequest!IDRequest
      pRstSynchRequest.MoveNext
    Wend
    SaveStringToFile pLogFileName, pLogText
 End If
Exit_Point:
On Error Resume Next
 'Synchronize = (pErrNumber = 0)
 Synchronize = retValOk
 If ZatvoriSyncFormOnExit Then
  DoCmd.Close acForm, pSyncFormName, acSaveNo
 Else 'vrati kako je bilo
  Forms(pSyncFormName).TimerInterval = tmpTimerInterval
  Forms(pSyncFormName).CloseBezPitanja = tmpCloseBezPitanja
  Forms(pSyncFormName)!Label_NextCheck.Caption = "END: Poziv iz koda"
 End If
 
Exit Function

Err_Point:
 SetMyError err
 retValOk = False
 Resume Exit_Point
End Function

Public Function SaveRespond(IDRequest As Long, Optional MsgText As String) As Boolean
On Error GoTo Err_Point
 
 Dim retValOk
 
 retValOk = True
 'pCmd.ActiveConnection = "DRIVER=SQL Server;SERVER=(local);Trusted_Connection=Yes;APP=Microsoft Office 2010;DATABASE=VuleMarket"
 'pCmd.ActiveConnection.CursorLocation = adUseClient
 pCMD.CommandType = adCmdStoredProc
 pCMD.CommandText = "spSyncRespondSave"
 pCMD.Parameters.Refresh
 pCMD.Parameters("@IDRequest").Value = IDRequest
 pCMD.Parameters("@ClientID").Value = Left(BigBit_UID, 250)
 pCMD.Parameters("@ClientMSG").Value = IIf(IsMissing(MsgText), Left(pLogText, 4000), Left(MsgText, 4000))
 pCMD.Parameters("@Status").Value = "Err=" & pErrNumber
 pCMD.Parameters("@HasError").Value = (pErrNumber <> 0)
 
 pCMD.Execute
 
Exit_Point:
On Error Resume Next
    SaveRespond = retValOk
Exit Function
Err_Point:
  MsgBox "ErrNo: " & err.Number & vbCrLf & err.Description
  retValOk = False
  SetMyError err
  Resume Exit_Point:
End Function
Public Function OpenConnection() As Boolean
On Error GoTo Err_Point

 pErrNumber = 0
 pErrDescription = ""
 
 If pCNN.State = adStateOpen Then
    OpenConnection = True
    pCMD.ActiveConnection = pCNN
    Exit Function
 End If
  
DoCmd.Hourglass True

  pCNN.ConnectionString = Me.CNNString
  pCNN.CursorLocation = adUseClient
  'pCNN.ConnectionTimeout = 15
  '**********************************************************************
  If Not BBCFG.SysSuspendSynch Then
  On Error Resume Next
   pCNN.Open Me.CNNString ', "QBigBit", "QbigBit.9496"
  End If
DoCmd.Hourglass False

 If pCNN.State = adStateOpen Then
 Set pCMD.ActiveConnection = pCNN
 Else
    BBCFG.SysSuspendSynch = True
    'MsgBox "Ne postoji veza sa MasterDB!", vbCritical, "QMegaTeh"
    pErrNumber = vbObjectError + 515
    pErrDescription = "Disconected MasterDB"
    'err.Raise pErrNumber, "ODBC_Synch_Class_Initialize", "Ne postoji veza sa MasterDB!"
 End If
Err_Point:
 DoCmd.Hourglass False
 SetMyError err
 err.Clear
 OpenConnection = (pCNN.State = adStateOpen) '(pErrNumber = 0) and
End Function
Public Property Get CNNString() As String
  CNNString = pCNNString
End Property
Public Property Let CNNString(ByVal vNewValue As String)
  pCNNString = vNewValue
End Property
Private Sub Class_Initialize()
On Error GoTo Err_Point

 Dim retValOk As Boolean
 pErrNumber = 0
 pErrDescription = ""
 
 pShuttleFileName = BBCFG.SHUTTLE_FileName()
 pSyncFormName = "ODBC_Synch"
 'pMakeNewSHUTTLEBeforeSync = False '!!!!!
 pLogText = ""
 pLogFileName = BBCFG.ODBC_Synch_LogFileName
    
    'Me.CNNString = "DRIVER=SQL Server;SERVER=(local);Trusted_Connection=Yes;APP=Microsoft Office 2010;DATABASE=VuleMarket"
    'Me.CNNString = Replace(CurrentDb.TableDefs("Master_Cenovnik").Connect, "ODBC;", "")
    'Me.CNNString = Replace(Nz(BazaZaTip("MasterDB"), ""), "ODBC;", "")
    'Me.CNNString = "DRIVER=SQL Server;SERVER=(local);UID=QBigBit;Password=QbigBit.9496;APP=Microsoft Office 2010;DATABASE=VuleMarket"
    Me.CNNString = Replace(BazaZaTip("Synch"), "ODBC;", "")
'Me.CheckRequest
Exit_Point:
 On Error Resume Next
Exit Sub
Err_Point:
  'MsgBox "ErrNo: " & Err.Number & vbCrLf & Err.Description
  SetMyError err
  retValOk = False
  Resume Exit_Point:
End Sub

Private Sub Class_Terminate()
'On Error Resume Next
 If pCNN.State = adStateOpen Then
   pCNN.Close
 End If
' If pCmd.ActiveConnection.State = adStateOpen Then
'  pCmd.ActiveConnection.Close
' End If
 Set pCNN = Nothing
 Set pCMD = Nothing
End Sub

Public Property Get LogText() As Variant
  LogText = pLogText
End Property
Public Property Get MessageFromMaster() As String
  MessageFromMaster = pMessageFromMaster
End Property

Public Property Get ErrNumber() As Variant
  ErrNumber = pErrNumber
End Property

Public Property Let ErrNumber(ByVal vNewValue As Variant)
  pErrNumber = vNewValue
End Property

Public Property Get ErrDescription() As String
  ErrDescription = pErrDescription
End Property

Public Property Let ErrDescription(ByVal vNewValue As String)
  pErrDescription = vNewValue
End Property

Public Property Get State() As Variant
  State = pCNN.State
End Property

