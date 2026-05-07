VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Report_rRN_SaSlikamaPodReport"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit


Private Sub PrikaziSliku()
On Error GoTo Err_PrikaziSliku


        Me!Slika.Picture = Nz(Me!LinkSlika, "")

Exit_PrikaziSliku:
    Exit Sub

Err_PrikaziSliku:
    MsgBox err.Description
    Me!Slika.Picture = ""
    Resume Exit_PrikaziSliku
    
End Sub
Private Sub Detail_Format(Cancel As Integer, FormatCount As Integer)
    PrikaziSliku
End Sub
