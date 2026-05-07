VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_KbdNum"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
'Dim XPos As Long
Dim selstart
Dim sellength
Dim seltext
Dim StartFrm As Form
Dim StartCtl As control

Private Function F_IzvrsiKomandu(komanda As String)
    IzvrsiKomandu (komanda)
End Function
Private Sub IzvrsiKomandu(komanda As String)
Dim brz As Integer
    Select Case komanda
        Case "BS"
            If Len(Me!UnetaRec) > 0 And selstart > 0 Then
                Me!UnetaRec = Left$(Me!UnetaRec, selstart - 1) & Right(Me!UnetaRec, Len(Me!UnetaRec) - selstart)
                'Me!UnetaRec = Left$(Me!UnetaRec, Len(Me!UnetaRec) - 1)
                selstart = selstart - 1
            End If
        Case "DEL"
            If selstart < Len(Me!UnetaRec) Then
                If sellength = 0 Then brz = 1 Else brz = sellength
                Me!UnetaRec.SetFocus
                Me!UnetaRec = Left(Me!UnetaRec, selstart) & Right(Me!UnetaRec, Len(Me!UnetaRec) - (selstart + brz))
            End If
        Case "CLEAR"
            Me!UnetaRec.SetFocus
            Me!UnetaRec = ""
            selstart = 0
        Case "LEFT"
            selstart = selstart - 1
            If selstart < 0 Then selstart = 0
        Case "RIGHT"
            selstart = selstart + 1
            If selstart > Len(Nz(Me!UnetaRec, "")) Then selstart = Len(Nz(Me!UnetaRec, ""))
    End Select
    PostaviFokusNaUnetaRec
    Me.Caption = Nz(Me!UnetaRec, "")
    'actCtl.Value = Me!UnetaRec
    UpisiUnos
End Sub
Private Sub DodajZnak(Znak As String)
    Dim prekey As String
    
    prekey = ""
    
    If Me!Key_SHIFT Then prekey = prekey & "+"
    
    If Me!Key_CTRL Then
        prekey = prekey & "^"
        Me!Key_CTRL = False
        Me!Key_CTRL_2 = False
    End If
    If Me!Key_ALT Then
        prekey = prekey & "%"
        Me!Key_ALT = False
        Me!Key_Alt_2 = False
    End If
      
    If Me!Key_SHIFT Or Key_CapsLock Then
        Znak = UCase(Znak)
        Me!Key_SHIFT = False
        Me!Key_SHIFT_2 = False
    ElseIf Not Me!Key_SHIFT And Not Key_CapsLock Then
        Znak = LCase(Znak)
    End If
    
    If prekey <> "" And prekey <> "+" Then
      On Error Resume Next
        SendKeys prekey & Znak
    Else
        ObrisiSelektovano
        Me!UnetaRec = Left$(Nz(Me!UnetaRec, ""), selstart) & Znak & Right(Nz(Me!UnetaRec, ""), Len(Nz(Me!UnetaRec, "")) - selstart)
       ' XPos = XPos + 1
        selstart = selstart + 1
        PostaviFokusNaUnetaRec
    End If
    Me.Caption = Nz(Me!UnetaRec, "")
    'actCtl.Value = Me!UnetaRec
    UpisiUnos
End Sub
Private Function F_DodajZnak(Znak As String)
    DodajZnak (Znak)
End Function
Private Function F_DodajZnakSHIFT(ZnakSaShiftom As String, ZnakBezShifta As String)
    If Me!Key_SHIFT Then DodajZnak (ZnakSaShiftom) Else DodajZnak (ZnakBezShifta)
End Function
Private Sub ObrisiSelektovano()
    
    If sellength <> 0 Then
        Me!UnetaRec.SetFocus
        Me!UnetaRec = Left(Nz(Me!UnetaRec, ""), selstart) & Right(Nz(Me!UnetaRec, ""), Len(Nz(Me!UnetaRec, "")) - (selstart + sellength))
    End If
    sellength = 0
    
End Sub

Private Sub Command96_Click()
    ZatvoriFormuIUpisiUnos
End Sub
Private Sub Form_Open(Cancel As Integer)
   
    Me!UnetaRec = KbdEditCtl
    Me.Caption = Nz(Me!UnetaRec, "")
    
    selstart = 0
    sellength = Len(Nz(Me!UnetaRec, ""))
    seltext = Me!UnetaRec
    
    DoCmd.GoToControl "UnetaRec"
    
   
    
    'selstart = Len(Me!UnetaRec)
    'PostaviFokusNaUnetaRec
    
   

End Sub


Private Sub Key_Alt_2_AfterUpdate()
    Me!Key_ALT = Me!Key_Alt_2
End Sub

Private Sub Key_ALT_AfterUpdate()
    Me!Key_Alt_2 = Me!Key_ALT
End Sub
Private Sub Key_CTRL_2_AfterUpdate()
    Me!Key_CTRL = Me!Key_CTRL_2
End Sub

Private Sub Key_CTRL_AfterUpdate()
    Me!Key_CTRL_2 = Me!Key_CTRL
End Sub
Private Sub ZatvoriFormuIUpisiUnos()
    Dim UnetaRec
    UnetaRec = Me!UnetaRec
    DoCmd.Close acForm, Me.Name
    'if Screen.ActiveForm.ActiveControl.
    On Error Resume Next
    Screen.ActiveForm.ActiveControl = UnetaRec
End Sub

Private Sub Key_Enter_Click()
    UpisiUnos
    ZatvoriFormu
End Sub

Private Sub Key_ESC_2_Click()
    ZatvoriFormu
End Sub

Private Sub Key_ESC_Click()
    ZatvoriFormu
End Sub

Private Sub Key_EVAL_Click()
On Error Resume Next
    Me!UnetaRec = Eval(Me!UnetaRec)
    'selstart = Len(Me!UnetaRec)
    PostaviFokusNaUnetaRec
End Sub

Private Sub Key_SHIFT_2_AfterUpdate()
    Me!Key_SHIFT = Me!Key_SHIFT_2
End Sub

Private Sub Key_SHIFT_AfterUpdate()
    Me!Key_SHIFT_2 = Me!Key_SHIFT
End Sub

Private Sub Key_Space_Click()
    DodajZnak ("_")
End Sub
Private Sub UnetaRec_GotFocus()
    Me!UnetaRec = ZameniStr(" ", "_", Nz(Me!UnetaRec))
   ' Me!UnetaRec.selstart = selstart
   ' Me!UnetaRec.sellength = sellength
   ' Me!UnetaRec.seltext = seltext
   'selstart = Me!UnetaRec.selstart
   'sellength = Me!UnetaRec.sellength
   'seltext = Me!UnetaRec.seltext
End Sub
Private Sub UnetaRec_LostFocus()
    selstart = Me!UnetaRec.selstart
    sellength = Me!UnetaRec.sellength
    seltext = Me!UnetaRec.seltext
    Me!UnetaRec = ZameniStr("_", " ", Nz(Me!UnetaRec))
End Sub

Public Sub PostaviFokusNaUnetaRec()
    Me!UnetaRec.SetFocus
    Me!UnetaRec.selstart = selstart
    Me!UnetaRec.sellength = 0
End Sub

Public Sub ZatvoriFormu()
    DoCmd.Close acForm, Me.Name
End Sub
Private Function UpisiUnos()
On Error Resume Next
  
  If KbdEditCtl.ControlType = acTextBox And KbdEditCtl.Enabled And Not KbdEditCtl.Locked And KbdEditForm.AllowEdits Then
    KbdEditCtl.Value = Me!UnetaRec
    Else
    MsgBox "Nije dozvoljen unos!", vbExclamation, "QMegaTeh"
   End If
    
End Function
