VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_UnosPredmetaIspraviKomitenta"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Sub Form_Open(Cancel As Integer)
    DoCmd.GoToControl "UnetiKomitenta"
End Sub


Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click


    DoCmd.Close

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
    
End Sub
Private Sub DugmeSave_Click()
On Error GoTo Err_DugmeSave_Click


    DoCmd.RunCommand acCmdSaveRecord

Exit_DugmeSave_Click:
    Exit Sub

Err_DugmeSave_Click:
    MsgBox err.Description
    Resume Exit_DugmeSave_Click
    
End Sub

Private Sub UnetiKomitenta_AfterUpdate()
    DugmeSave_Click
    DugmeStop_Click
End Sub
