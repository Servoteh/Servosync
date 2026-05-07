VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_frmIzborTehnologa"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private mIDRN As Long


Private Sub cmdPotvrdi_Click()
On Error GoTo Err_Handler
    Dim gUserSifraRadnika As Long
    Dim retValOk As Boolean
    'Dim dtRokIzrade As Variant
    
    If Nz(Me.cmbTehnolog, 0) = 0 Then
        MsgBox "Morate izabrati tehnologa.", vbExclamation
        Exit Sub
    End If
    
    ' === proveri rok izrade ===
    'If IsNull(Me.txtRokIzrade) Or Not IsDate(Me.txtRokIzrade) Then
    '    MsgBox "Morate uneti rok izrade.", vbExclamation
    '    Me.txtRokIzrade.SetFocus
    '    Exit Sub
    'End If
    
    'dtRokIzrade = CDate(Me.txtRokIzrade)
    gUserSifraRadnika = IDRadnikZaCurrentUser()
    'Call ADO_ExecSP(CNN_CurrentDataBase, "spPromeniStatusPrimopredaje", mIDRN, 1, Me!cmbTehnolog)
    
    retValOk = ADO_ExecSP(CNN_CurrentDataBase, "spPromeniStatusPrimopredaje", mIDRN, 1, Me!cmbTehnolog, gUserSifraRadnika)
    
    Forms!PregledPrimopredaje.PrimeniUslove
    
    DoCmd.Close acForm, Me.Name
    
    If retValOk Then
        MsgBox "Status primopredaje je uspešno promenjen.", vbInformation
    Else
        MsgBox "Status primopredaje NIJE promenjen.", vbInformation
    End If
    
Exit_Point:
    Exit Sub
Err_Handler:
    MsgBox "Greška: " & err.Description, vbCritical
    Resume Exit_Point

End Sub



' ==========================================
' On Load — preuzima IDRN iz OpenArgs
' ==========================================
Private Sub Form_Load()
    On Error GoTo Err_Point
    
    If Len(Nz(Me.OpenArgs, "")) > 0 Then
        mIDRN = CLng(Me.OpenArgs)
    Else
        MsgBox "Nedostaje IDRN parametar!", vbCritical
        DoCmd.Close acForm, Me.Name
        Exit Sub
    End If

    ' Fokus
    Me.cmbTehnolog.SetFocus

Exit_Point:
    Exit Sub
Err_Point:
    MsgBox "Greška (Form_Load): " & err.Description, vbCritical
    Resume Exit_Point
End Sub


' ==========================================
' Odustani
' ==========================================
Private Sub cmdOdustani_Click()
    DoCmd.Close acForm, Me.Name
End Sub

