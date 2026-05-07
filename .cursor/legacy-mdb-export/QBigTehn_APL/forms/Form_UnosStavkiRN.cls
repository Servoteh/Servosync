VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_UnosStavkiRN"
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
    DoCmd.GoToControl "Operacija"
End Sub

Private Sub DugmePrebaciUClipboard_Click()
    SetClipboard Me!txtBarKod
End Sub

Private Sub Form_BeforeUpdate(Cancel As Integer)
    If Me!ComboRJgrupaRC.Column(2) = False Then
        Me!Prioritet = 255
    End If
End Sub

Private Sub Form_Current()
    ProveriZakljucavanje
End Sub

Private Sub ProveriZakljucavanje()
'Application.Echo False
    Dim userReadOnly As Boolean
    userReadOnly = IsReadOnlyUser()
    
    If Nz(Forms![UnosRN].Zakljucano, False) Then

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
Private Sub DugmePrikaziSkicu_Click()
On Error GoTo Err_DugmePrikaziSkicu_Click

    Dim stDocName As String
    Dim stLinkCriteria As String
    
    'stDocName = "StavkeRNSlike"
    'DoCmd.OpenForm stDocName, , , stLinkCriteria
    If Nz(Me!IDStavkeRN, 0) <> 0 Then
        DefinisiPrikaziSkicu Me!IDRN, Me.Parent!IdentBroj, Me!Operacija
    Else
        MsgBox "Ne postoji definisana operacija za koju želite da definišete skicu!", vbInformation
    End If
    
Exit_DugmePrikaziSkicu_Click:
    Exit Sub

Err_DugmePrikaziSkicu_Click:
    MsgBox err.Description
    Resume Exit_DugmePrikaziSkicu_Click
    
End Sub

Private Sub Form_Open(Cancel As Integer)
    PrikaziObjekteZaMene
End Sub

Private Sub txtBarKod_DblClick(Cancel As Integer)
    SetClipboard Me!txtBarKod
End Sub

Public Sub PrikaziObjekteZaMene()
    If UserUGrupi(CurrentUser(), "Admins") Then
        Me!LblBarKod.Visible = True
        Me!txtBarKod.Visible = True
        Me!DugmePrebaciUClipboard.Visible = True
    Else
        Me!LblBarKod.Visible = False
        Me!txtBarKod.Visible = False
        Me!DugmePrebaciUClipboard.Visible = False
    End If
End Sub
