VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Report_RNPregledPoRJ"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Function PripremiPodatke()
  SetProperlyRecordSource CNN_CurrentDataBase, Me, "ODBC_RNPregledPoRJ"
End Function

Private Sub Report_Open(Cancel As Integer)
    PripremiPodatke
End Sub
