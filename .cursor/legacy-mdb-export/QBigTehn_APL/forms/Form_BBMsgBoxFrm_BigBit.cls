VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BBMsgBoxFrm_BigBit"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub DugmeDa_Click()
    BBMsgBoxRetVal = vbYes
    DoCmd.Close
End Sub

Private Sub DugmeOk_Click()
    BBMsgBoxRetVal = vbOK
    DoCmd.Close
End Sub

Private Sub DugmeNe_Click()
    BBMsgBoxRetVal = vbNo
    DoCmd.Close
End Sub

Private Sub DugmePonisti_Click()
    BBMsgBoxRetVal = vbCancel
    DoCmd.Close
End Sub

Private Sub Form_Open(Cancel As Integer)
        Rem Me.Caption = BBCFG.AppName
        Me.Caption = "QMegaTeh"
        BBMsgBoxRetVal = -1
        DoCmd.GoToControl "Dugme"
End Sub

Private Sub Form_Timer()
    Me!VremeTrajanja = Me!VremeTrajanja - 1
    Me!VremeTrajanja.Visible = True
    'Me!Vreme.Requery
    If Me!VremeTrajanja < 0 Then
        DoCmd.Close acForm, Me.Name
    Else
        Me.Repaint
    End If
End Sub
