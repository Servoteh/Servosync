Attribute VB_Name = "USLF_Module"
Option Compare Database
Option Explicit

Public USLF As New USLF_Class

Public Function F_USLF_IDDok() As Long
   F_USLF_IDDok = Nz(USLF.IDDok(), -1)
End Function

Public Function F_USLF_TextZaRacun() As String
   F_USLF_TextZaRacun = USLF.TextZaRacun()
End Function
Public Function F_USLF_CheckPIP() As Boolean
  F_USLF_CheckPIP = USLF.CheckPiP
End Function
Public Function F_USLF_CheckDatumPrometaVisible() As Boolean
  F_USLF_CheckDatumPrometaVisible = USLF.CheckDatumPrometaVisible()
End Function
Public Function F_USLF_IDKomitent(Optional IDKomitent) As Long
Dim lnRetVal As Long
    lnRetVal = USLF.IDKomitent()
    F_USLF_IDKomitent = lnRetVal
End Function

Public Function F_USLF_ImaAvans(Optional IDDok) As Boolean
Dim IznosAvansa As Variant
Dim pIDDok As Long
 
If Not IsMissing(IDDok) Then
   pIDDok = CLng(IDDok)
Else
   pIDDok = Nz(USLF.IDDok, -1)
End If
   IznosAvansa = Nz(ADO_Lookup(CNN_CurrentDataBase, "UkIznos", "SELECT SUM(KoristiIznosSaPDV) as UkIznos FROM T_AVR_Usluge WHERE IDDok = " & stR(pIDDok)), 0)
   F_USLF_ImaAvans = (IznosAvansa >= 0.01)
End Function



