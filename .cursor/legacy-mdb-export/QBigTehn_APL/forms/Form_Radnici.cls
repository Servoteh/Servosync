VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Radnici"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub DugmeNoviSlog_Click()
On Error GoTo Err_DugmeNoviSlog_Click


    DoCmd.GoToRecord , , acNewRec
    DoCmd.GoToControl "ImeMajstora"

Exit_DugmeNoviSlog_Click:
    Exit Sub

Err_DugmeNoviSlog_Click:
    MsgBox err.Description
    Resume Exit_DugmeNoviSlog_Click
    
End Sub

Private Sub DugmePrebaciUClipboard_Click()
    SetClipboard Me!IDKartice
End Sub

Private Sub Form_Current()
On Error Resume Next
    Forms![RadniciPoMasinama]![PristupMasinama].Form.Requery
    Forms![RadniciPoMasinama]![PristupMasinama].Form![SifraRadnika].Requery
End Sub

Private Sub Form_Open(Cancel As Integer)
    If UserUGrupi(CurrentUser(), "Admins") Then
        Me!DugmePrebaciUClipboard.Visible = True
    Else
        Me!DugmePrebaciUClipboard.Visible = False
    End If

End Sub

Private Sub Password_DblClick(Cancel As Integer)
   If Me!Password.InputMask = "" Then
        Me!Password.InputMask = "Password"
    Else
        Me!Password.InputMask = ""
    End If
End Sub

Private Sub PronadjiPoNazivu_AfterUpdate()
    DoCmd.GoToControl ("SifraRadnika")
    DoCmd.FindRecord (Me![PronadjiPoNazivu])
    Me![PronadjiPoNazivu] = Null
    DoCmd.GoToControl ("ImeIPrezime")
End Sub
