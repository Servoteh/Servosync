VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BBPravaPristupa"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Function PostaviRowSourceZaImeKontrole()
    Me!ImeKontrole.RowSource = DRST_KontroleNaFormi(Forms(Me!ImeForme)).GetString(, , ";", ";")
End Function
Private Sub ImeKontrole_DblClick(Cancel As Integer)
    'Me!ZaImeKontrole = IIf(Me!ImeKontrole = "[Form]", "Form", Me!ImeKontrole)
    'PrimeniUslove
    PostaviRowSourceZaImeKontrole
End Sub
Private Sub CheckTestPravaPristupa_AfterUpdate()
    BBCFG.TestPravaPristupa = Nz(Me!CheckTestPravaPristupa, False)
End Sub

Private Sub ComboSysOpenForm_AfterUpdate()
    BBCFG.SysOpenForm = Me!ComboSysOpenForm
End Sub

Private Sub DefaultLimitedUser_AfterUpdate()
    Me!DefaultLimitedUser = CStr(Nz(Me!DefaultLimitedUser, BBCFG.DefaultLimitedUser))
    BBCFG.DefaultLimitedUser = Me!DefaultLimitedUser
    Me!DefaultLimitedUser.Requery
    
    Me!ImeUsera.DefaultValue = "'" & BBCFG.DefaultLimitedUser & "'"
    Me!ImeUsera.Requery
    
    Me!ZaImeUsera = Me!DefaultLimitedUser
    PrimeniUslove
End Sub

Private Sub DugmeSetFormEnabled_Click()
    
    Me!ImeKontrole = "[Form]"
    Me!Enabled = True
    
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

Private Sub Form_Open(Cancel As Integer)
    Me!CheckTestPravaPristupa = BBCFG.TestPravaPristupa
    Me!ImeUsera.DefaultValue = "'" & BBCFG.DefaultLimitedUser & "'"
    Me!DefaultLimitedUser = BBCFG.DefaultLimitedUser
    Me!ComboSysOpenForm = BBCFG.SysOpenForm
End Sub

Private Sub ImeForme_DblClick(Cancel As Integer)
    Me!ZaImeForme = Me!ImeForme
    PrimeniUslove
End Sub

Private Sub ImeUsera_DblClick(Cancel As Integer)
     Me!ZaImeUsera = Me!ImeUsera
    PrimeniUslove
End Sub

Private Sub ZaImeForme_AfterUpdate()
    PrimeniUslove
End Sub

Private Sub ZaImeForme_DblClick(Cancel As Integer)
    Me!ZaImeForme = Null
    PrimeniUslove
End Sub

Private Sub ZaImeKontrole_AfterUpdate()
    PrimeniUslove
End Sub

Private Sub ZaImeKontrole_DblClick(Cancel As Integer)
    Me!ZaImeKontrole = Null
    PrimeniUslove
End Sub

Private Sub ZaImeUsera_AfterUpdate()
    PrimeniUslove
End Sub

Private Sub PrimeniUslove()
    Me.Requery
End Sub

Private Sub ZaImeUsera_DblClick(Cancel As Integer)
    Me!ZaImeUsera = Null
    PrimeniUslove
End Sub
