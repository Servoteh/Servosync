VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_frmGrupe"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database

Private Sub DugmeNoviSlog_Click()
    DoCmd.GoToRecord , , acNewRec
    Me!IDObjekta = Nz(DMax("[IDObjekta]", "tObjekti"), 0) + 1
    DoCmd.GoToControl "Objekat"
End Sub

Private Sub Form_BeforeUpdate(Cancel As Integer)
    If IsNull(Me!IDObjekta) Or Me!IDObjekta = 0 Then Me!IDObjekta = Nz(DMax("[IDObjekta]", "tObjekti"), 0) + 1
End Sub
