VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form__AppRev"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Function PrimeniUslove()
 Me.Requery
 PrikaziAPPRev
End Function
Private Function ClearCurrentVal()
   Screen.ActiveControl.Value = Null
   PrimeniUslove
End Function

Private Sub APP_DblClick(Cancel As Integer)
    Me!ZaAPP = Me!APP
    PrimeniUslove
End Sub

Private Sub DugmeNoviSlog_Click()
    DoCmd.GoToRecord , , acNewRec
    DoCmd.GoToControl "Tema"
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
Private Sub PrikaziAPPRev()
  Me!BBAppRev.Caption = F_APPRev()
End Sub

Private Sub Form_BeforeUpdate(Cancel As Integer)
    If Nz(Me!Opis, "") = "" Then
       Me!Opis = Me!Tema & ":" & vbCrLf & "-"
    End If
End Sub

Private Sub Form_Open(Cancel As Integer)
    PrikaziAPPRev
End Sub

Private Sub ID_DblClick(Cancel As Integer)
    Me!OdID = Me!ID
    Me!DoID = Me!ID
    PrimeniUslove
End Sub

Private Sub Ver_DblClick(Cancel As Integer)
    Me!ZaVer = Me!Ver
    PrimeniUslove
End Sub

Private Sub VerDatum_DblClick(Cancel As Integer)
    Me!OdVerDatum = Me!VerDatum
    Me!DoVerDatum = Me!VerDatum
    PrimeniUslove
End Sub
