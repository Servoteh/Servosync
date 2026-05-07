VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_frmDefParametriUnos"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit

Private Sub PrimeniUslove()
On Error GoTo Err_PrimeniUslove

    If Me!TabIzbor = 0 Then
        FrameProdaja_AfterUpdate
    Else
        Me!Podforma.SourceObject = "ReklamniPanel"
        Me!Podforma.Requery
    End If
Exit_PrimeniUslove:
    Exit Sub

Err_PrimeniUslove:
    MsgBox Error$
    Resume Exit_PrimeniUslove
    
End Sub


Private Sub Dugme_Stop_Click()
On Error GoTo Err_Dugme_stop_Click


    DoCmd.Close

Exit_Dugme_stop_Click:
    Exit Sub

Err_Dugme_stop_Click:
    MsgBox Error$
    Resume Exit_Dugme_stop_Click
    
End Sub


Private Sub Form_Open(Cancel As Integer)
'On Error Resume Next

DoCmd.Maximize

End Sub
Private Sub FrameProdaja_AfterUpdate()
    If Me!FrameProdaja = 1 Then
        Me!Podforma.SourceObject = "frmGrupe"
    ElseIf Me!FrameProdaja = 2 Then
        Me!Podforma.SourceObject = "frmPozicije"
    ElseIf Me!FrameProdaja = 3 Then
        'Me!Podforma.SourceObject = "frmRedovi"
    Else
        Me!Podforma.SourceObject = "ReklamniPanel"
    End If
End Sub


Private Sub TabIzbor_Change()
'    If Me!TabIzbor = 0 Then
'        FrameProdaja_AfterUpdate
'    ElseIf Me!TabIzbor = 1 Then
'        FrameIzvestaji_AfterUpdate
'    ElseIf Me!TabIzbor = 2 Then
'        FrameSPEC_AfterUpdate
'    Else
    
'    End If
End Sub
