VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_UnosOperacije"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click


    DoCmd.Close

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
    
End Sub
Private Sub DugmeNoviSlog_Click()
On Error GoTo Err_DugmeNoviSlog_Click


    DoCmd.GoToRecord , , acNewRec
    DoCmd.GoToControl "RJGrupaRC"

Exit_DugmeNoviSlog_Click:
    Exit Sub

Err_DugmeNoviSlog_Click:
    MsgBox err.Description
    Resume Exit_DugmeNoviSlog_Click
    
End Sub

Private Sub Form_Open(Cancel As Integer)
    DoCmd.Maximize
End Sub
Private Sub PronadjiPoNazivu_AfterUpdate()
    DoCmd.GoToControl ("RJgrupaRC")
    DoCmd.FindRecord (Me![PronadjiPoNazivu])
    Me![PronadjiPoNazivu] = Null
    DoCmd.GoToControl ("RJgrupaRC")

    
End Sub
Public Function PrimeniUslove()
    Me.Requery
End Function

Private Sub ZaIDRadneJedinice_DblClick(Cancel As Integer)
    Me!ZaIDRadneJedinice = Null
    PrimeniUslove
End Sub
