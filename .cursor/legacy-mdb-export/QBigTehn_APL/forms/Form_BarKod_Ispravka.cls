VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BarKod_Ispravka"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub Form_Close()
   ' If Not IsNull(Me!Napomena) Or Me!Napomena <> "" Then
   '     Call UpisiNapomenu(Me!IDPostupka, Me!Napomena)
   ' End If
End Sub

Private Sub Form_Open(Cancel As Integer)
'    DoCmd.MoveSize 10, 10
            Me!lblZag.Value = "FORMA ZA ISPRAVKU"
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
Private Sub DugmeUradiStorniranje_Click()
On Error GoTo Err_DugmeUradiStorniranje_Click

    Dim stDocName As String
    If CLng(Me!NapravljenoKomada) < CLng(Nz(Me!StornirajKomada, 0)) Then
        MsgBox "Stornirate broj komada koji nije napravljen!!!"
    Else
        If CLng(Nz(Me!StornirajKomada, 0)) <> 0 Then
            stDocName = "StornirajTehPostupak"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
            DoCmd.Close
        End If
    End If
Exit_DugmeUradiStorniranje_Click:
    Exit Sub

Err_DugmeUradiStorniranje_Click:
    MsgBox err.Description
    Resume Exit_DugmeUradiStorniranje_Click
    
End Sub
