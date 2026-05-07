VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Grupe artikala"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons

Private Sub DugmeNova_grupa_Click()
On Error GoTo Err_DugmeNova_grupa_Click


    DoCmd.GoToRecord , , A_NEWREC
    DoCmd.GoToControl "Grupa"

Exit_DugmeNova_grupa_Click:
    Exit Sub

Err_DugmeNova_grupa_Click:
    MsgBox Error$
    Resume Exit_DugmeNova_grupa_Click
    
End Sub

Private Sub Grupa_AfterUpdate()
    Me!Opis = Me!Grupa.Column(1)
End Sub
Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click


    If Me.Dirty Then Me.Dirty = False
    DoCmd.Close

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
    
End Sub
