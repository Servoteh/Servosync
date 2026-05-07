VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_frmPozicije"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

Private Sub DugmeNoviSlog_Click()
    DoCmd.GoToRecord , , acNewRec
    Me!IDPozicije = Nz(DMax("[IDPozicije]", "tPozicije"), 0) + 1
    DoCmd.GoToControl "Pozicija"
End Sub

Private Sub Form_BeforeUpdate(Cancel As Integer)
    If IsNull(Me!IDPozicije) Or Me!IDPozicije = 0 Then Me!IDPozicije = Nz(DMax("[IDPozicije]", "tPozicije"), 0) + 1
End Sub
Public Function NoviSlog()
    DoCmd.GoToRecord , , acNewRec
    Me!IDPozicije = Nz(DMax("[IDPozicije]", "tPozicije"), 0) + 1
    DoCmd.GoToControl "Pozicija"
End Function
