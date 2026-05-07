Attribute VB_Name = "GKS"
Option Compare Database
Option Explicit

'Kreirano: 09-04-19

Public Function GKS_KolonaZaPeriod(BrojDana) As String
On Error Resume Next
 Dim stRetVal As String
 
 If Not IsNumeric(BrojDana) Then
   stRetVal = "Neispravan parametar BrojDana"
 Else
  stRetVal = Nz(DLookup("[NazivKolone]", "GKS_T_Periodi", BrojDana & " Between [OdDana] AND [DoDana]"), "NEPOZNAT PERIOD")
 End If
  GKS_KolonaZaPeriod = stRetVal
End Function
