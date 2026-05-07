Attribute VB_Name = "RN_RadSaDatumima"
Option Compare Database
Option Explicit
Public Function MojDanUNedelji(DATUM As Variant) As String
On Error Resume Next
Dim rbrdan
Dim retVal As String
    rbrdan = Weekday(DATUM)
  Select Case rbrdan
    Case 1: retVal = "Nedelja"
    Case 2: retVal = "Ponedeljak"
    Case 3: retVal = "Utorak"
    Case 4: retVal = "Sreda"
    Case 5: retVal = "Cetvrtak"
    Case 6: retVal = "Petak"
    Case 7: retVal = "Subota"
    Case Else
        retVal = "-"
  End Select
  MojDanUNedelji = retVal
End Function
Public Function DatumUIntervalu(DATUM, OdDatuma, DoDatuma) As Boolean
    Dim retVal As Boolean
    Dim D_OdDatuma As Date
    Dim D_DoDatuma As Date
    Dim D_Datum As Date
    
    
    D_OdDatuma = CDate(Nz(OdDatuma, #1/1/1901#))
    D_DoDatuma = CDate(Nz(DoDatuma, #12/31/2099#))
    D_Datum = CDate(DATUM)
    retVal = (D_OdDatuma <= D_Datum) And (D_Datum <= D_DoDatuma)
    
    DatumUIntervalu = retVal
End Function
Public Function DatIVremeUIntervalu(DatumIVreme, OdDatuma, OdVremena, DoDatuma, DoVremena) As Boolean
    Dim retVal As Boolean
    Dim D_OdDatIVrem As Date
    Dim D_DoDatIVrem As Date
    Dim D_DatIVrem As Date
    
    
    D_OdDatIVrem = CDate(Nz(OdDatuma, #1/1/1901#) + Nz(OdVremena, #12:00:00 AM#))
    D_DoDatIVrem = CDate(Nz(DoDatuma, #12/31/2099#) + Nz(DoVremena, #11:59:59 PM#))
    D_DatIVrem = CDate(DatumIVreme)
    retVal = (D_OdDatIVrem <= D_DatIVrem) And (D_DatIVrem <= D_DoDatIVrem)
    'Between IIf(IsNull([Forms]![AP]![OdVremena]),CDate(#01-01-91#+#0:00:00#),CDate([Forms]![AP]![Od datuma]+[Forms]![AP]![Odvremena])) And IIf(IsNull([Forms]![AP]![DoVremena]),CDate(#31-12-2099#+#0:00:00#),CDate([Forms]![AP].[Do datuma]+[Forms]![AP]![DoVremena]))
      
    DatIVremeUIntervalu = retVal
End Function
Public Function VremeUIntervalu(Vreme, OdVremena, DoVremena) As Boolean
    Dim retVal As Boolean
    Dim D_Vrem As Date
    Dim D_OdVrem As Date
    Dim D_DoVrem As Date
    
    
    D_OdVrem = CDate(Nz(OdVremena, #12:00:00 AM#))
    D_DoVrem = CDate(Nz(DoVremena, #11:59:59 PM#))
    D_Vrem = CDate(Vreme)
    retVal = (D_OdVrem <= D_Vrem) And (D_Vrem <= D_DoVrem)
      
    VremeUIntervalu = retVal
End Function
Public Function DatumDoDatuma(DATUM, DoDatuma, Optional UljucenaGranica As Boolean = True) As Boolean
    Dim retVal As Boolean
    Dim D_DoDatuma As Date
    Dim D_Datum As Date
    
    D_DoDatuma = CDate(Nz(DoDatuma, #12/31/2099#))
    D_Datum = CDate(DATUM)
    If UljucenaGranica Then
        retVal = (D_Datum <= D_DoDatuma)
    Else
        retVal = (D_Datum < D_DoDatuma)
    End If
    
    DatumDoDatuma = retVal
End Function
Public Function VremeDoVremena(Vreme, DoVremena, Optional UljucenaGranica As Boolean = True) As Boolean
    Dim retVal As Boolean
    Dim D_Vrem As Date
    Dim D_DoVrem As Date
    
    D_DoVrem = CDate(Nz(DoVremena, #11:59:59 PM#))
    D_Vrem = CDate(Vreme)
    
    If UljucenaGranica Then
        retVal = (D_Vrem <= D_DoVrem)
    Else
        retVal = (D_Vrem < D_DoVrem)
    End If
    
    VremeDoVremena = retVal
End Function
Public Function DatIVremeDoDatIVreme(DatumIVreme, DoDatuma, DoVremena, Optional UljucenaGranica As Boolean = True) As Boolean
    Dim retVal As Boolean
    Dim D_OdDatIVrem As Date
    Dim D_DoDatIVrem As Date
    Dim D_DatIVrem As Date
    
    D_DoDatIVrem = CDate(Nz(DoDatuma, #12/31/2099#) + Nz(DoVremena, #11:59:59 PM#))
    D_DatIVrem = CDate(DatumIVreme)
    If UljucenaGranica Then
        retVal = (D_DatIVrem <= D_DoDatIVrem)
    Else
        retVal = (D_DatIVrem < D_DoDatIVrem)
    End If
      
    DatIVremeDoDatIVreme = retVal
End Function
Public Function BrojDanaUSekundama(Sekunde As Long) As Long
    Dim retVal As Long
    retVal = Sekunde \ 86400
    BrojDanaUSekundama = retVal
End Function
Public Function BrojSatiUSekundama(Sekunde As Long) As Long
    Dim retVal As Long
    Dim dani As Long
    dani = BrojDanaUSekundama(Sekunde)
    retVal = (Sekunde - dani * 86400) \ 3600
    BrojSatiUSekundama = retVal
End Function
Public Function BrojMinutaUSekundama(Sekunde As Long) As Long
    Dim retVal As Long
    Dim dani As Long
    Dim Sati As Long
    dani = BrojDanaUSekundama(Sekunde)
    Sati = BrojSatiUSekundama(Sekunde)
    retVal = (Sekunde - (dani * 86400 + Sati * 3600)) \ 60
    BrojMinutaUSekundama = retVal
End Function

Public Function BrojSekundiUIntervalu(PocetakIntervala As Variant, ZavrsetakIntervala As Variant) As Long
    Dim retVal As Long
    If Not IsNull(PocetakIntervala) And Not IsNull(ZavrsetakIntervala) Then
        retVal = DateDiff("s", PocetakIntervala, ZavrsetakIntervala)
    Else
        retVal = 0
    End If
    BrojSekundiUIntervalu = retVal
End Function
Public Function ServotehDatIVreme(DatumIVreme As Variant) As Variant
    Dim retVal As Date
    If Not IsNull(DatumIVreme) Then
        retVal = DatumIVreme
        ServotehDatIVreme = Left(CDate(retVal), 9) & DoChLeft(CStr(DatePart("h", retVal)), 2, "0") & ":" & DoChLeft(CStr(DatePart("m", retVal)), 2, "0")
    Else
        ServotehDatIVreme = Null
    End If
End Function
Public Function ServotehDatIVremeDeo1(DatumIVreme As Variant) As Variant
    Dim retVal As Date
    If Not IsNull(DatumIVreme) Then
        retVal = DatumIVreme
        ServotehDatIVremeDeo1 = Left(CDate(retVal), 9) ' & DoChLeft(CStr(DatePart("h", retVal)), 2, "0") & ":" & DoChLeft(CStr(DatePart("m", retVal)), 2, "0")
    Else
        ServotehDatIVremeDeo1 = Null
    End If
End Function
Public Function ServotehDatIVremeDeo2(DatumIVreme As Variant) As Variant
    Dim retVal As Date
    If Not IsNull(DatumIVreme) Then
        retVal = DatumIVreme
        ServotehDatIVremeDeo2 = DoChLeft(CStr(DatePart("h", retVal)), 2, "0")  '& ":" & DoChLeft(CStr(DatePart("m", retVal)), 2, "0")
    Else
        ServotehDatIVremeDeo2 = Null
    End If
End Function
Public Function ServotehDatIVremeDeo3(DatumIVreme As Variant) As Variant
    Dim retVal As Date
    If Not IsNull(DatumIVreme) Then
        retVal = DatumIVreme
        ServotehDatIVremeDeo3 = DoChLeft(CStr(DatePart("m", retVal)), 2, "0")
    Else
        ServotehDatIVremeDeo3 = Null
    End If
End Function
