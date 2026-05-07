Attribute VB_Name = "PDV_Modul"
Option Compare Database
Option Explicit
Public Function Zn(Vred) As Variant
 If IsNumeric(Vred) Then
  If Vred = 0 Then Zn = Null Else Zn = Vred
 Else
  Zn = Vred
 End If
End Function
Public Function F_PDV_VisaStopa(Optional ByVal DATUM As Date, Optional ByVal PDVGrupa As String, Optional ByVal PoreskaStopa As Currency = 20) As Currency
'Modifikovano: 22-03-2023
 Dim retVal As Currency
  If PDVGrupa = "VISA" Then
     retVal = PoreskaStopa
  ElseIf CDate(DATUM) <= CDate(#9/30/2012#) And DATUM <> 0 Then
     retVal = 18
  Else
     retVal = ReadCFGParametar("DefaultPDVVisaStopa", 20)
  End If
  F_PDV_VisaStopa = retVal
End Function
Public Function F_PDV_NizaStopa(Optional ByVal DATUM As Date, Optional ByVal PDVGrupa As String, Optional ByVal PoreskaStopa As Currency = 10) As Currency
'Modifikovano: 22-03-2023
 Dim retVal As Currency
  If PDVGrupa = "NIZA" Then
     retVal = PoreskaStopa
  ElseIf CDate(DATUM) < CDate(#1/1/2014#) And DATUM <> 0 Then
     retVal = 8
  Else
     retVal = ReadCFGParametar("DefaultPDVNizaStopa", 10)
  End If
  F_PDV_NizaStopa = retVal
End Function
Public Function F_PDV_PoljoStopa(Optional ByVal DATUM As Date, Optional ByVal PDVGrupa As String, Optional ByVal PoreskaStopa As Currency = 8) As Currency
'Modifikovano: 22-03-2023
 Dim retVal As Currency
  If PDVGrupa = "POLJO" Then
     retVal = PoreskaStopa
  ElseIf CDate(DATUM) <= CDate(#9/30/2012#) And DATUM <> 0 Then
     retVal = 5
  Else
     retVal = ReadCFGParametar("DefaultPDVPoljoStopa", 8)
  End If
  F_PDV_PoljoStopa = retVal
End Function
Public Function F_PDV_KomitentVanPDV() As Long
    F_PDV_KomitentVanPDV = 2
End Function
Public Function F_PDVGranicaStopa() As Long
    F_PDVGranicaStopa = 11
End Function

Public Function PDVStopaZaTarifu(Tarifa As String) As Currency
 Dim retVal
 
 If BBCFG.SQLDB Then
    retVal = ADO_Lookup(BBCFG.CNNString, "PDVStopa", "PDVZbirneStope", "Tarifa='" & Tarifa & "'")
 Else
    retVal = DLookup("[PDVStopa]", "PDVZbirneStope", "Tarifa='" & Tarifa & "'")
 End If
 
 PDVStopaZaTarifu = CCur(Nz(retVal, 0))
End Function
Public Function PDVTarifaZaStopu(Stopa As Currency) As String
 Dim retVal
 
    retVal = ADO_Lookup(BBCFG.CNNString, "Tarifa", "PDVZbirneStope", "PDVStopa=" & Stopa)
 
 PDVTarifaZaStopu = Nz(retVal, "")
End Function
