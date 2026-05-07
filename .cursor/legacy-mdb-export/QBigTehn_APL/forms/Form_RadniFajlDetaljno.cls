VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_RadniFajlDetaljno"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Function MemorandumPreview()
On Error GoTo Err_Point

    On Error Resume Next
    DoCmd.RunCommand acCmdSaveRecord

On Error GoTo Err_Point
    DoCmd.OpenReport "Memorandum", acViewPreview

Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "MemorandumPreview"
 Resume Exit_Point
End Function

Private Sub DugmeMemorandumHeaderPreview_Click()
    Call MemorandumPreview
End Sub

Private Sub DugmePrepisiUplatneRacuneIzCFG_Click()
On Error GoTo Err_DugmePrepisiUplatneRacuneIzCFG_Click

    Dim stDocName As String

    stDocName = "UplatniRacuni_PrepisiIzCFG"
    DoCmd.OpenQuery stDocName, acNormal, acEdit

Exit_DugmePrepisiUplatneRacuneIzCFG_Clic:
    Exit Sub

Err_DugmePrepisiUplatneRacuneIzCFG_Click:
    MsgBox err.Description
    Resume Exit_DugmePrepisiUplatneRacuneIzCFG_Clic
    
End Sub

Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click


    DoCmd.Close

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
    
End Sub

Private Sub ER_ApiKey_DblClick(Cancel As Integer)
 If UserUGrupi(CurrentUser(), "PowerfulUsers") Then
    If Me!ER_ApiKey.InputMask = "password" Then
        Me!ER_ApiKey.InputMask = ""
        Me!ER_ApiKey.Locked = False
    Else
        Me!ER_ApiKey.InputMask = "password"
        Me!ER_ApiKey.Locked = True
    End If
 End If
End Sub

Private Sub Form_Close()
    'PostaviGlobalneParametre
    BBCFG.SetFirmaPod Me.IDBaze
End Sub
Private Sub DugmeCFGRW_Click()
On Error GoTo Err_DugmeCFGRW_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    'stDocName = "CFGReadWrite"
    'BBOpenForm stDocName, , , stLinkCriteria
    
    OtvoriFormuCFGReadWrite

Exit_DugmeCFGRW_Click:
    Exit Sub

Err_DugmeCFGRW_Click:
    MsgBox err.Description
    Resume Exit_DugmeCFGRW_Click
    
End Sub
Private Sub Form_Open(Cancel As Integer)
On Error Resume Next
    Me!BazaZaRF = Replace(CurrentDb.TableDefs("Radni fajlovi").Connect, ";DATABASE=", "")
    If BazaZaTabelu("Radni fajlovi") = BazaZaTip("BigBit_T") Then
    'radni fajlovi su unutar baze
     Me!DugmeKreirajUplatniRacunID0.Visible = True
     Me!DugmePrepisiUplatneRacuneIzCFG.Visible = True
    ElseIf CurrentUser = "Negovan" Then
     Me!DugmeKreirajUplatniRacunID0.Visible = True
     Me!DugmePrepisiUplatneRacuneIzCFG.Visible = True
    Else
     Me!DugmeKreirajUplatniRacunID0.Visible = False
     Me!DugmePrepisiUplatneRacuneIzCFG.Visible = False
    End If
    If UserUGrupi(CurrentUser, "PowerfulUsers") Then
       Me!ProveraZalihaMag.Enabled = True
    Else
       Me!ProveraZalihaMag.Enabled = False
    End If
End Sub

Private Sub NazivFirmeNezvanicno_AfterUpdate()
    BBCFG.NazivFirmeNezvanicno = Me!NazivFirmeNezvanicno
End Sub

Private Sub ProveraZalihaMag_AfterUpdate()
'Modifikovano: 11-08-2020
On Error GoTo Err_Point

Dim stSQLCmdENABLETrigger As String
Dim stSQLCmdDISABLETrigger As String

stSQLCmdENABLETrigger = ""
stSQLCmdDISABLETrigger = ""
DoCmd.RunCommand acCmdSaveRecord

    BBCFG.ProveraZalihaMag = Me!ProveraZalihaMag
    
    If Not BBCFG.SQLDB Then
       Exit Sub
    Else
       If fsPostojiTriger("trg_RobneStavke_Delete") Then
        stSQLCmdENABLETrigger = stSQLCmdENABLETrigger & "ENABLE TRIGGER [dbo].[trg_RobneStavke_Delete] ON  [dbo].[T_Robne stavke];" & vbCrLf
        stSQLCmdDISABLETrigger = stSQLCmdDISABLETrigger & "DISABLE TRIGGER [dbo].[trg_RobneStavke_Delete] ON  [dbo].[T_Robne stavke];" & vbCrLf
       End If
       If fsPostojiTriger("trg_RobneStavke_Insert") Then
        stSQLCmdENABLETrigger = stSQLCmdENABLETrigger & "ENABLE TRIGGER [dbo].[trg_RobneStavke_Insert] ON  [dbo].[T_Robne stavke];" & vbCrLf
        stSQLCmdDISABLETrigger = stSQLCmdDISABLETrigger & "DISABLE TRIGGER [dbo].[trg_RobneStavke_Insert] ON  [dbo].[T_Robne stavke];" & vbCrLf
       End If
       If fsPostojiTriger("trg_RobneStavke_Update") Then
        stSQLCmdENABLETrigger = stSQLCmdENABLETrigger & "ENABLE TRIGGER [dbo].[trg_RobneStavke_Update] ON  [dbo].[T_Robne stavke];" & vbCrLf
        stSQLCmdDISABLETrigger = stSQLCmdDISABLETrigger & "DISABLE TRIGGER [dbo].[trg_RobneStavke_Update] ON  [dbo].[T_Robne stavke];" & vbCrLf
       End If
       If fsPostojiTriger("trg_RobnaDokumenta_Delete") Then
        stSQLCmdENABLETrigger = stSQLCmdENABLETrigger & "ENABLE TRIGGER [dbo].[trg_RobnaDokumenta_Delete] ON  [dbo].[T_Robna dokumenta];" & vbCrLf
        stSQLCmdDISABLETrigger = stSQLCmdDISABLETrigger & "DISABLE TRIGGER [dbo].[trg_RobnaDokumenta_Delete] ON  [dbo].[T_Robna dokumenta];" & vbCrLf
       End If
    End If

If ReadCFGParametar("ProveraZalihaPrekoTrigera") Then
      If BBCFG.ProveraZalihaMag Then
        If stSQLCmdENABLETrigger <> "" Then
            ADO_ExecSQL BBCFG.CNNString, stSQLCmdENABLETrigger
        End If
      Else
        If stSQLCmdDISABLETrigger <> "" Then
            ADO_ExecSQL BBCFG.CNNString, stSQLCmdDISABLETrigger
        End If
      End If
Else
      If stSQLCmdDISABLETrigger <> "" Then
            ADO_ExecSQL BBCFG.CNNString, stSQLCmdDISABLETrigger
      End If
End If

Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "ProveraZalihaMag_AfterUpdate"
 Resume Exit_Point
End Sub
Private Sub DugmeKreirajUplatniRacunID0_Click()
On Error GoTo Err_DugmeKreirajUplatniRacunID0_Click

    Dim stDocName As String

    stDocName = "KreirajUplatniRacunID0"
    DoCmd.OpenQuery stDocName, acNormal, acEdit

Exit_DugmeKreirajUplatniRacunID0_Click:
    Exit Sub

Err_DugmeKreirajUplatniRacunID0_Click:
    MsgBox err.Description
    Resume Exit_DugmeKreirajUplatniRacunID0_Click
    
End Sub

Private Sub RPT_Memorandum_Footer_GotFocus()
    On Error Resume Next
    Me!RPT_Memorandum_Footer.RowSource = ListaSvihReporta("Memorandum_Footer?*")

End Sub

Private Sub RPT_Memorandum_Header_GotFocus()
On Error Resume Next
    Me!RPT_Memorandum_Header.RowSource = ListaSvihReporta("Memorandum_Header?*")
End Sub
