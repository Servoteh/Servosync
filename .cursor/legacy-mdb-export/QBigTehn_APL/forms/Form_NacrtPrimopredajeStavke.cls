VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_NacrtPrimopredajeStavke"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub Form_Current()
    ProveriZakljucavanje
End Sub

Private Sub Form_Open(Cancel As Integer)
'    PrimeniUslove
End Sub

Private Sub Form_Unload(Cancel As Integer)
'    CloseConnectionOnCurrentForm Me
End Sub
Private Sub ProveriZakljucavanje()
'Application.Echo False
    If Nz(Forms![NacrtPrimopredaje].Zakljucano, False) Then
        
        Me.Detail.BackColor = BBCFG.ColorLock
        Me.FormFooter.BackColor = BBCFG.ColorLock
        Me.FormHeader.BackColor = BBCFG.ColorLock
        
        Me.AllowEdits = False
        Me.AllowDeletions = False
        Me.AllowAdditions = False
    Else
        Me.Detail.BackColor = BBCFG.ColorUnLock
        Me.FormFooter.BackColor = BBCFG.ColorUnLock
        Me.FormHeader.BackColor = BBCFG.ColorUnLock
        
        Me.AllowEdits = True
        Me.AllowDeletions = True
        Me.AllowAdditions = True
        
    End If
  'Application.Echo True
End Sub


