VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_LokacijaSvihNapravljenihDelovaPoRN"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub XPoz_BeforeUpdate(Cancel As Integer)
    If Not IsNumeric(Me!XPoz) Then
        MsgBox "Police su numerisane!"
        DoCmd.RunCommand acCmdUndo
        Cancel = True
    End If
End Sub

Private Sub YPoz_BeforeUpdate(Cancel As Integer)
    If Not IsNumeric(Me!YPoz) Then
        MsgBox "Police su numerisane!"
        DoCmd.RunCommand acCmdUndo
        Cancel = True
    End If
End Sub

Private Sub ZPoz_BeforeUpdate(Cancel As Integer)
    If Not IsNumeric(Me!ZPoz) Then
        MsgBox "Police su numerisane!"
        DoCmd.RunCommand acCmdUndo
        Cancel = True
    End If
End Sub

Private Sub Form_Current()
    If Me.Parent!DugmePripremiPrenos.Visible = False Then
       Me.Parent.PostaviParametreZaPrenos
    End If
    If Me.Parent!DugmePripremiTrebovanje.Visible = False Then
       Me.Parent.PostaviParametreZaTrebovanje
    End If
End Sub

Private Sub Form_Open(Cancel As Integer)
    DoCmd.MoveSize , , 7820
End Sub

Private Sub IDPozicijaOpis_Enter()
        Me.IDPozicijaOpis.ControlTipText = Me!IDPozicijaOpis.Column(0)
End Sub
