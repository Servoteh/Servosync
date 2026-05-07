VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PrimopredajaUnosStavkiPDM"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit


Private Sub Dugme_Nova_Stavka_Click()
On Error Resume Next
    ProveriZakljucavanje
    DoCmd.GoToRecord , , acNewRec
    DoCmd.GoToControl "ComboRJgrupaRC"
End Sub

Private Sub Form_Current()
    ProveriZakljucavanje
    Me!PozicijaPDM.Requery
End Sub

Private Sub ProveriZakljucavanje()
'Application.Echo False
    Dim userReadOnly As Boolean
    userReadOnly = IsReadOnlyUser()
    If Nz(Forms![Primopredaja].Zakljucano, False) Then

        Me.Detail0.BackColor = BBCFG.ColorLock
        Me.FormFooter2.BackColor = BBCFG.ColorLock
        
        Me.AllowEdits = False
        Me.AllowDeletions = False
        Me.AllowAdditions = False
    ElseIf userReadOnly Then
        Me.AllowEdits = False
        Me.AllowAdditions = False
        Me.AllowDeletions = False
        
    Else
        Me.Detail0.BackColor = BBCFG.ColorUnLock
        Me.FormFooter2.BackColor = BBCFG.ColorUnLock
        Me.AllowEdits = True
        Me.AllowDeletions = True
        Me.AllowAdditions = True
        
    End If
  'Application.Echo True
End Sub

Private Sub Form_Open(Cancel As Integer)
Dim OK As Boolean
    
    OK = (DCount("*", "tPDM", "[IDRN] = " & Nz(Forms!Primopredaja!IDRN, -1)) > 0)
    If OK Then
        DoCmd.GoToControl "ComboRJgrupaRC"
    End If
End Sub


Private Sub PozicijaPDM_AfterUpdate()
    If Me!PozicijaPDM.Column(3) = Forms!Primopredaja!BrojCrteza Then
        Me!NazivP = Me!PozicijaPDM.Column(1)
        Me!BrojCrtezaP = Me!PozicijaPDM.Column(2)
    Else
        MsgBox "Ovaj " & Srpski("montazni") & " deo nije definisan kao radni nalog!", vbInformation, "Proverite"
    End If
End Sub
