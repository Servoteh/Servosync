VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Report_Digitron"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub Detail_Format(Cancel As Integer, FormatCount As Integer)
 Me![VredIzraza].DecimalPlaces = Forms![Digitron]![BrojDecimala]
 Me![Total].DecimalPlaces = Forms![Digitron]![BrojDecimala]
End Sub

Private Sub Report_Close()
    BBOpenForm "Digitron"
End Sub

Private Sub ReportFooter_Format(Cancel As Integer, FormatCount As Integer)
 Me![VredIzraza].DecimalPlaces = Forms![Digitron]![BrojDecimala]
 Me![Total].DecimalPlaces = Forms![Digitron]![BrojDecimala]
End Sub
