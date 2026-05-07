Attribute VB_Name = "ADO_DiconectedRecordset"
Option Compare Database
Option Explicit

Public bDirty As Boolean

Public Function DRST_KontroleNaFormi_Create() As ADODB.Recordset
On Error GoTo Err_Point

  Set DRST_KontroleNaFormi_Create = New ADODB.Recordset
  
  With DRST_KontroleNaFormi_Create
  Set .ActiveConnection = Nothing
  .CursorLocation = adUseClient
  .LockType = adLockBatchOptimistic
  With .Fields
  '.Append "ImeForme", adBSTR, 64
  .Append "ImeKontrole", adBSTR, 64
  '.Append "TipKontrole", adBSTR, 64
  '.Append "TabStop", adBoolean, 1
  End With
  .Open
  '.AddNew Array("ImeForme", "ImeKontrole", "TipKontrole", "TabStop"), Array("'1'", "'1'", "'1'")
  '.Save strFilename, adPersistADTG
  '.Close
  End With
  
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "DRST_KontroleNaFormi_Create"
 Resume Exit_Point
End Function
Public Function DRST_KontroleNaFormi_Open(Optional strFilename As String = "") As ADODB.Recordset
On Error GoTo Err_Point

  If Dir(strFilename) = "" Then
    Set DRST_KontroleNaFormi_Open = DRST_KontroleNaFormi_Create()
  Else
    Set DRST_KontroleNaFormi_Open = New ADODB.Recordset
    DRST_KontroleNaFormi_Open.Open strFilename
  End If
 
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "DRST_KontroleNaFormi_Open"
 Resume Exit_Point
End Function
Public Function DRST_KontroleNaFormi(aktForma As Form) As ADODB.Recordset
On Error GoTo Err_Point
    
    Dim ctl As control
    'Dim aktForma As Form
    
    'DoCmd.OpenForm "TEST", acDesign
    'Set aktForma = Forms("TEST")
    
    Set DRST_KontroleNaFormi = DRST_KontroleNaFormi_Create

    For Each ctl In aktForma.Controls
          'DRST_KontroleNaFormi.AddNew Array("ImeForme", "ImeKontrole", "TipKontrole"), Array(aktForma.Name, ctl.Name, ctl.ControlType)
          DRST_KontroleNaFormi.AddNew Array("ImeKontrole"), Array(ctl.Name)
          DRST_KontroleNaFormi.Update
         'On Error Resume Next
          'TabKontrole!TabOrder = ctl.TabOrder
          'aktForma.Section("Detail").SetTabOrder
          'TabKontrole!TabStop = ctl.TabStop
          'TabKontrole.Update
    Next
Exit_Point:
On Error Resume Next
    DRST_KontroleNaFormi.MoveFirst
Exit Function

Err_Point:
   BBErrorMSG err, "DRST_KontroleNaFormi"
 Resume Exit_Point
End Function
'***********************************************************************************************
Public Function ADO_GetDRST(ByVal CNNString As String, ByVal SQLText As String, _
                                             Optional ByVal pLockType As LockTypeEnum = adLockOptimistic, _
                                             Optional ByVal pCursorLocation As CursorLocationEnum = adUseClient, _
                                             Optional ByVal pCursorType As CursorTypeEnum = adOpenKeyset, _
                                             Optional ByVal OnErrShowDetails As Boolean = True, _
                                             Optional ByVal CommandTimeout As Integer = 180, _
                                             Optional ByVal pSort As String = "" _
                          ) As ADODB.Recordset
On Error GoTo Err_Point

   Set ADO_GetDRST = ADO_GetRST(ByVal CNNString, SQLText, pLockType, pCursorLocation, pCursorType, OnErrShowDetails, CommandTimeout, pSort)
   ADO_GetDRST.ActiveConnection = Nothing

   
On Error GoTo Err_Point

Exit_Point:
 On Error Resume Next

Exit Function

Err_Point:
 BBErrorMSG err, "ADO_GetDRST"
 Resume Exit_Point
End Function
Public Function DRST_UseriNaBazi_Create() As ADODB.Recordset
On Error GoTo Err_Point

  Dim rs As ADODB.Recordset
  Set rs = New ADODB.Recordset

  With rs
    .CursorLocation = adUseClient
    .CursorType = adOpenStatic
    .LockType = adLockBatchOptimistic

    With .Fields
      .Append "ImeUsera", adVarWChar, 64
    End With

    ' VAŽNO: ne diraj ActiveConnection uopšte
    .Open
  End With

  Set DRST_UseriNaBazi_Create = rs
  Exit Function

Err_Point:
  BBErrorMSG err, "DRST_UseriNaBazi_Create"
  Set DRST_UseriNaBazi_Create = Nothing
End Function

Public Function DRST_UseriNaBazi_Open(Optional strFilename As String = "") As ADODB.Recordset
On Error GoTo Err_Point

  Dim rs As ADODB.Recordset

  If Len(strFilename) = 0 Or Dir(strFilename) = "" Then
    Set DRST_UseriNaBazi_Open = DRST_UseriNaBazi_Create()
  Else
    Set rs = New ADODB.Recordset
    rs.CursorLocation = adUseClient
    rs.Open strFilename  ' radi ako si ranije .Save u ADTG
    Set DRST_UseriNaBazi_Open = rs
  End If

  Exit Function

Err_Point:
  BBErrorMSG err, "DRST_UseriNaBazi_Open"
  Set DRST_UseriNaBazi_Open = Nothing
End Function

Public Function DRST_UseriNaBazi() As ADODB.Recordset
On Error GoTo Err_Point

    Dim rs As ADODB.Recordset
    Dim wsp As DAO.Workspace
    Dim usr As DAO.User

    Set rs = DRST_UseriNaBazi_Open()
    If rs Is Nothing Then GoTo Exit_Point
    If rs.State = adStateClosed Then GoTo Exit_Point

    Set wsp = DBEngine.Workspaces(0)

    For Each usr In wsp.Users
        rs.AddNew
        rs!ImeUsera = usr.Name
        rs.Update
    Next usr

    If rs.RecordCount > 0 Then rs.MoveFirst
    Set DRST_UseriNaBazi = rs
    Exit Function

Exit_Point:
    Set DRST_UseriNaBazi = rs
    Exit Function

Err_Point:
   BBErrorMSG err, "DRST_UseriNaBazi"
   Set DRST_UseriNaBazi = Nothing
End Function

