VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_KeyboardSaPostupkom"
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
Dim PrviUlaz As Boolean
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

Private Sub DugmeDokumentacija_Click()
On Error GoTo Err_DugmePrikaziSkicu_Click

    Dim stDocName As String
    Dim stLinkCriteria As String
    
    If Nz(BBTehn.IDPostupka, 0) <> 0 Then
        DefinisiPrikaziDokumentaciju BBTehn.IDPostupka, BBTehn.IdentBroj, BBTehn.Operacija
    Else
        MsgBox "Ne postoji definisana operacija za koju želite da definišete dokumentaciju!", vbInformation
    End If
    
Exit_DugmePrikaziSkicu_Click:
    Exit Sub

Err_DugmePrikaziSkicu_Click:
    MsgBox err.Description
    Resume Exit_DugmePrikaziSkicu_Click

End Sub

Private Sub DugmeTest_Click()
On Error GoTo Err_Command180_Click

    MsgBox "IDPostupka: " & BBTehn.IDPostupka & vbCrLf & "IDRadnika: " & BBTehn.IDRadnik & vbCrLf & "IDPredmeta: " & BBTehn.IDPredmet & _
            "KeyBoardDorada: " & KeyboardDorada & vbCrLf & "KeyboardSkart: " & KeyboardSkart & vbCrLf & "KeyboardOperacija: " & KeyboardOperacija
    'MsgBox Me.WindowHeight
Exit_Command180_Click:
    Exit Sub

Err_Command180_Click:
    MsgBox err.Description
    Resume Exit_Command180_Click
End Sub
Private Sub Form_Activate()
  '  MsgBox "Form_Activate"
End Sub
Private Sub Form_GotFocus()
    'Me!UnetaRec = Screen.PreviousControl.Value
   ' MsgBox "Form_GotFocus"
End Sub

Private Function PrimeniUslove()
  ' BBTimerStart
    SetProperlyRecordSource BBCFG.CNNString, Me
  ' Me!LabelTrajanjeUpita.Caption = BBTimerTrajanjeSec("Query=")
End Function

Private Sub Form_Load()
    PrimeniUslove
End Sub

Private Sub Form_Open(Cancel As Integer)
    Dim newLeft As Integer
    If UserUGrupi(CurrentUser(), "Admins") Then
        Me!DugmeTest.Visible = True
    Else
        Me!DugmeTest.Visible = False
    End If
    
    If DaLiPostojeDodatnaOvlascenjaZaRadnika() Then
        'Me!LabelNapomena.Visible = True
        'Me!DugmeNapomena.Visible = True
        Me!tglBox.Visible = True
        Me!tglDorada.Visible = True
        Me!tglSkart.Visible = True
    Else
        'Me!LabelNapomena.Visible = False
        'Me!DugmeNapomena.Visible = False
        Me!tglBox.Visible = False
        Me!tglDorada.Visible = False
        Me!tglSkart.Visible = False
    End If
    ' Modifikovano 21-04-2025   Dodato:
    Me!LabelNapomena.Visible = True
    Me!DugmeNapomena.Visible = True
        
    KeyboardReturn = 0
    KeyboardDorada = False
    KeyboardSkart = False
    KeyboardOperacija = -1
  '  Set StartFrm = Screen.ActiveForm
  '  Set StartCtl = Screen.ActiveControl
    
    'Me!UnetaRec = Screen.PreviousControl
    Me.Caption = Nz(Me!UnetaRec, "")
    selstart = 0
    sellength = 0
    seltext = ""
    PrviUlaz = True
    DoCmd.GoToControl "UnetaRec"
    'MsgBox Me.InputParameters
    'DoCmd.MoveSize , , , 6375
    'DoCmd.MoveSize Me.Right - 2000
          
    ' Postavi željenu vrednost za levu stranu prozora
    newLeft = 100
    
    ' Postavi poziciju forme
    Me.Moveable = True
    Me.Move newLeft, Me.WindowTop, Me.WindowWidth, Me.WindowHeight
    
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
Private Sub ZatvoriFormuIUpisiUnos_NeTREBA()
    Dim UnetaRec
    UnetaRec = Me!UnetaRec
    DoCmd.Close acForm, Me.Name
    'if Screen.ActiveForm.ActiveControl.
    On Error Resume Next
    Screen.ActiveForm.ActiveControl = UnetaRec
End Sub

Private Sub Key_Enter_Click()

    'UpisiUnos
    'If Me!tglDorada = True And Nz(Me!DoradaOperacije, -1) = -1 Then
    '    MsgBox Srpski("Oznacili") & " ste da unosite broj komada dorade, a niste definisali operaciju", vbInformation
    '    DoCmd.GoToControl "DoradaOperacije"
    '    Exit Sub
    'End If
    
    If Me!UnetaRec = "" Then
        KeyboardReturn = 0
        KeyboardDorada = False
        KeyboardSkart = False
        KeyboardOperacija = 0
    Else
        KeyboardReturn = CDbl(Me!UnetaRec)
        KeyboardDorada = Nz(Me!tglDorada, False)
        KeyboardSkart = Nz(Me!tglSkart, False)
        KeyboardOperacija = Nz(Me!DoradaOperacije, 0)
    End If
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
    selstart = Len(Me!UnetaRec)
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

Private Sub tglDorada_AfterUpdate()
    If Me!tglDorada = True Then
        Me!tglSkart = False
        'Me!Label_Operacija.Visible = True
        'Me!DoradaOperacije.Visible = True
        'DoCmd.GoToControl "DoradaOperacije"
    Else
        'Me!DoradaOperacije = Null
        'Me!Label_Operacija.Visible = False
        'Me!DoradaOperacije.Visible = False
    End If
End Sub

Private Sub tglSkart_AfterUpdate()
    If Me!tglSkart = True Then
        Me!tglDorada = False
        'Me!DoradaOperacije = Null
        'Me!Label_Operacija.Visible = False
        'Me!DoradaOperacije.Visible = False
    End If
End Sub

Private Sub UnetaRec_GotFocus()
    Me!UnetaRec = ZameniStr(" ", "_", Nz(Me!UnetaRec))
    Me!UnetaRec.selstart = selstart
    Me!UnetaRec.sellength = sellength
    Me!UnetaRec.seltext = seltext
End Sub
Private Sub UnetaRec_KeyUp(KeyCode As Integer, Shift As Integer)
    If KeyCode = vbKeyReturn And PrviUlaz = False Then
       Rem ZatvoriFormuIUpisiUnos
        Key_Enter_Click
    ElseIf KeyCode = vbKeyEscape Then
        ZatvoriFormu
    Else
        PrviUlaz = False
    End If
End Sub

Private Sub UnetaRec_LostFocus()
    Dim ctl As control
    Set ctl = Me!UnetaRec

   
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
   ' actFrm.SetFocus
   ' actCtl.SetFocus
  If actCtl.ControlType = acTextBox And actCtl.Enabled And Not actCtl.Locked And actFrm.AllowEdits Then
    actCtl.Value = Me!UnetaRec
    Else
    MsgBox "Nije dozvoljen unos!", vbExclamation, "Tehnologija"
   End If
    
End Function
Private Sub DugmeNapomena_Click()
On Error GoTo Err_Command138_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "MemoPromena"
    DoCmd.OpenForm stDocName, , , stLinkCriteria


Exit_Command138_Click:
    Exit Sub

Err_Command138_Click:
    MsgBox err.Description
    Resume Exit_Command138_Click
    
End Sub

