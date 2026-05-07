VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Baze_Firme"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub FirmaZaBaze_DblClick(Cancel As Integer)
    Me!ZaFirmaZaBaze = Me!FirmazaBaze
    PrimeniUslove
End Sub

Private Sub RootDir_DblClick(Cancel As Integer)
 Dim retVal
  retVal = SelectFolder(Nz(Me!RootDir, ""))
  If Not IsNull(retVal) Then
     Me!RootDir = CStr(retVal)
  End If
End Sub
Private Function PrimeniUslove()
    Me.Requery
End Function

Private Sub ZaFirmaZaBaze_AfterUpdate()
    PrimeniUslove
End Sub

Private Sub ZaFirmaZaBaze_DblClick(Cancel As Integer)
    Me!ZaFirmaZaBaze = Null
    PrimeniUslove
End Sub
