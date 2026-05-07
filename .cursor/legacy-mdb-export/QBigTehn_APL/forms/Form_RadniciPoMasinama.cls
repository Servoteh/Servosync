VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_RadniciPoMasinama"
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

Private Sub Form_Open(Cancel As Integer)
    DoCmd.Maximize
End Sub
Private Sub ZaIDRadneJedinice_DblClick(Cancel As Integer)
    Me!ZaIDRadneJedinice = Null
    UradiRefresh
End Sub

Public Function UradiRefresh()
    Me!Radnici.Requery
    Me!PristupMasinama.Requery
    Me![PristupMasinama].Form![IDMasineSifra].Requery
    'Me![PristupMasinama].Form![IDMasine].Requery
End Function
