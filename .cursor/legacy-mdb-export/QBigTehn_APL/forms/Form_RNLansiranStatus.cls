VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_RNLansiranStatus"
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

Private Sub Form_BeforeUpdate(Cancel As Integer)
    Me!DIVIspravke = Now()
    Me!PotpisIspravka = CurrentUser()
    Me!IDRN = Me!ZaIDRN
End Sub

Private Sub SifraRadnikaUnos_AfterUpdate()
    If Nz(Me!SifraRadnikaUnos, 0) <> 0 Then
        If Nz(Me!SifraRadnikaIspravka, 0) = 0 Then
            Me!SifraRadnikaIspravka = Me!SifraRadnikaUnos
        End If
    End If
End Sub
