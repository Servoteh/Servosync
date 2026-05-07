VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PlanerSingleSubForm"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Function PrimeniUslove()
On Error Resume Next
  Call Me.Parent.PrimeniUslove
End Function

Private Sub CheckUradjeno_AfterUpdate()
    If Me!CheckUradjeno Then
     OznaciDaJeUradjeno
    End If
End Sub

Private Sub DugmeOk_Click()
    OznaciDaJeUradjeno
    Me.Parent.PrimeniUslove
End Sub

Private Sub DugmeSnimiSlog_Click()
    SnimiSlog
End Sub

Private Sub Form_AfterUpdate()
    'Call Me.Parent.PrimeniUslove
    Me.Parent!ZaIDPlaner = Me!ID
    PrimeniUslove
End Sub

Private Sub Form_BeforeUpdate(Cancel As Integer)
    Me!DIVPoslednjaIzmena = Now()
End Sub

Private Sub Form_Current()
    If CurrentUser() = Me!OdKoga Then
       Me.AllowDeletions = True
       Me.AllowEdits = True
    Else
       If UserUGrupi(CurrentUser(), "PowerFulUsers") Then
       Me.AllowDeletions = True
       Me.AllowEdits = True
      Else
       Me.AllowDeletions = False
       Me.AllowEdits = False
      End If
         
    End If
End Sub

Private Sub NoviSlog_Click()
On Error GoTo Err_NoviSlog_Click

    Me.AllowAdditions = True
    Me.AllowEdits = True
    DoCmd.GoToRecord , , acNewRec
    DoCmd.GoToControl "KadaDatum"

Exit_NoviSlog_Click:
    Exit Sub

Err_NoviSlog_Click:
    MsgBox err.Description
    Resume Exit_NoviSlog_Click
    
End Sub

Private Sub ObrisiSlog_Click()
On Error GoTo Err_ObrisiSlog_Click


    DoCmd.DoMenuItem acFormBar, acEditMenu, 8, , acMenuVer70
    DoCmd.DoMenuItem acFormBar, acEditMenu, 6, , acMenuVer70

Exit_ObrisiSlog_Click:
    Exit Sub

Err_ObrisiSlog_Click:
    MsgBox err.Description
    Resume Exit_ObrisiSlog_Click
    
End Sub
Private Function SnimiSlog()
On Error GoTo Err_SnimiSlog


    DoCmd.DoMenuItem acFormBar, acRecordsMenu, acSaveRecord, , acMenuVer70

Exit_SnimiSlog:
    Exit Function

Err_SnimiSlog:
    MsgBox err.Description
    Resume Exit_SnimiSlog
    
End Function
Private Sub OznaciDaJeUradjeno_SLAVISA()
On Error GoTo Err_OznaciDaJeUradjeno

    If IsNumeric(Me!ID) Then
     Me!CheckUradjeno = True
     Me!KadaJeUradjeno = Now()
     Me!KoJeUradio = CurrentUser()
     On Error Resume Next
     SnimiSlog
    End If
   ' DoCmd.Minimize
    
Exit_OznaciDaJeUradjeno:
    Exit Sub

Err_OznaciDaJeUradjeno:
    MsgBox err.Description
    Resume Exit_OznaciDaJeUradjeno
    
End Sub

Private Sub DugmeDuplicate_Click()
On Error GoTo Err_DugmeDuplicate_Click
Dim stInputDate As String

If Not IsNumeric(Me!ID) Then
 Exit Sub
End If
    'stInputDate = Format(Date, "dd-MM-yy")
    'stInputDate = InputBox("Unesite datum u formatu" & vbCrLf & "dd-MM-yy", "Unesite datum", stInputDate)
    'stInputDate = CVDate(stInputDate)
    
    DoCmd.RunCommand acCmdSelectRecord
    DoCmd.RunCommand acCmdCopy
    DoCmd.RunCommand acCmdRecordsGoToNew
    DoCmd.RunCommand acCmdSelectRecord
    DoCmd.RunCommand acCmdPaste
    Me!OdKoga = CurrentUser()
    Me!CheckUradjeno = False
    Me!KadaJeUradjeno = Null
    Me!KoJeUradio = Null
    Me!KadaDatum = Date
    'DoCmd.RunCommand acCmdSave
    DoCmd.GoToControl "KadaDatum"
    
Exit_DugmeDuplicate_Click:
    Exit Sub

Err_DugmeDuplicate_Click:
    MsgBox err.Description
    Resume Exit_DugmeDuplicate_Click
    
End Sub

Private Sub OznaciDaJeUradjeno()
On Error GoTo Err_Point

    Dim stUser As String
    stUser = GetPlanerUser()

    Call ADO_ExecSP( _
        CNN_CurrentDataBase, _
        "spPlanerOznaciProcitano", _
        CLng(Me!ID), _
        stUser _
    )
    
    

Exit_Point:
    Exit Sub

Err_Point:
    BBErrorMSG err, "OznaciDaJeUradjeno"
End Sub

