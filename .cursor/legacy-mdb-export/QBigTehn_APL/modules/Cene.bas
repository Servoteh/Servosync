Attribute VB_Name = "Cene"
Option Compare Database   'Use database order for string comparisons
Option Explicit

Public Function CenaIzCenovnika(ByVal ZaVrstuDokumenta As String, ByVal ZaSifruArtikla As Long) As Variant
On Error GoTo Err_Point
'Modifikovano: 30-01-2021

 Dim tmpst As String
 Dim Cena As Variant
 
 tmpst = " [Vrsta dokumenta] = '" & ZaVrstuDokumenta & "'"
 tmpst = tmpst & " And [Sifra artikla] = " & ZaSifruArtikla

 'Cena = DFirst("[Cena]", "Cenovnik", tmpst)
 Cena = ADO_Lookup(BBCFG.CNNString, "[Cena]", "Cenovnik", tmpst)

Exit_Point:
 On Error Resume Next
 CenaIzCenovnika = Cena
Exit Function

Err_Point:
 BBErrorMSG err, "CenaIzCenovnika"
 Cena = Null
 Resume Exit_Point
End Function
Public Function ZakljucanaCenaUCenovniku(ByVal IDArtikal As Long, ByVal CenovnikVrstaDok As String) As Boolean
On Error GoTo Err_Point
'Kreirano: 09-11-2022

  Dim retVal As Boolean
 
 retVal = ADO_GetValFromUDFS(CNN_CurrentDataBase, "fsZakljucanaCenaUCenovniku", IDArtikal, CenovnikVrstaDok)

Exit_Point:
 On Error Resume Next
 ZakljucanaCenaUCenovniku = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "ZakljucanaCenaUCenovniku"
 retVal = False
 Resume Exit_Point
End Function
Public Function KNGCenaZaKNGArtikal(ZaKNGSifruArtikla As String) As Variant

 Dim tmpst As String
 
 tmpst = "[KNGSifra] = '" & ZaKNGSifruArtikla & "'"

 KNGCenaZaKNGArtikal = DFirst("[Cena]", "KNG_Artikli", tmpst)

End Function
Public Function CenovnikZaKomitenta(IDKomitent) As String

 Dim retVal As String
 Dim stWhere As String
 
 If IsNumeric(IDKomitent) Then
    stWhere = "[Sifra] = " & CStr(CLng(IDKomitent))
    retVal = Nz(DLookup("[Cenovnik]", "Komitenti", stWhere), "")
 Else
    'retVal = BBCFG.VPCenovnik()
    retVal = ""
 End If

 CenovnikZaKomitenta = retVal
End Function
Public Function VPCenaOdCeneIzCenovnika(Cena As Double, Cenovnik As String, PDVStopa As Currency) As Double
 Dim retVal As Double
 
 If Cenovnik Like "MP*" Then
  retVal = Cena / (1 + (PDVStopa / 100))
 Else
  retVal = Cena
 End If
 VPCenaOdCeneIzCenovnika = retVal
End Function
Public Function MPCenaOdCeneIzCenovnika(Cena As Double, Cenovnik As String, PDVStopa As Currency) As Double
 Dim retVal As Double
 
 If Cenovnik Like "MP*" Then
  retVal = Cena
 Else
  retVal = Cena * (1 + (PDVStopa / 100))
 End If
 MPCenaOdCeneIzCenovnika = retVal
End Function
Public Function SracunajMPCenu(NC, ZTD, ZTS, RUCProc, PDVStopa, Optional BrDec As Integer = 2) As Currency
On Error GoTo err_Func

  Dim nzNC As Double
  Dim nzZTD As Double
  Dim nzZTS As Double
  Dim nzRUCProc As Double
  Dim nzPDVStopa As Double
  Dim nzBrDec As Integer
  Dim retVal As Double
  
  nzNC = Nz(NC, 0)
  nzZTD = Nz(ZTD, 0)
  nzZTS = Nz(ZTS, 0)
  nzRUCProc = Nz(RUCProc, 0)
  nzPDVStopa = Nz(PDVStopa, 0)
  
  If (BrDec < 0) Or (BrDec > 4) Then
   nzBrDec = 2
 Else
   nzBrDec = BrDec
 End If
 
  retVal = Round(((nzNC + nzZTD + nzZTS) * (1 + nzRUCProc / 100)) * (1 + nzPDVStopa / 100), nzBrDec)
exit_Func:
 On Error Resume Next
 SracunajMPCenu = CCur(retVal)
Exit Function
err_Func:
 'MsgBox Err.Description, , "QMegaTeh"
 BBErrorMSG err, "SracunajMPCenu"
 Resume exit_Func
End Function
Public Function UpisiCenuArtiklaUCenovnik(IDArtikal As Long, CenovnikVrstaDok As String, NovaCena As Currency, Optional DodajArtikalAkoNePostoji As Boolean = True) As Boolean
On Error GoTo Err_Point
   Dim retValOk As Boolean
   Dim rst As DAO.Recordset
   Dim SQLText As String
   
  'BBTimerStart
   retValOk = True
   SQLText = "SELECT Cenovnik.*"
   SQLText = SQLText & " FROM Cenovnik"
   SQLText = SQLText & " WHERE (((Cenovnik.[Sifra artikla])=" & IDArtikal & " ) "
   SQLText = SQLText & " AND ((Cenovnik.[Vrsta dokumenta])= '" & CenovnikVrstaDok & "'))"

   Set rst = CurrentDb.OpenRecordset(SQLText, dbOpenDynaset, dbSeeChanges)
   If Not rst.EOF Then 'postoji artikal u cenovniku
      rst.Edit
       rst!Cena = NovaCena
      rst.Update
   Else 'ne postoji artikal u cenovniku
    If DodajArtikalAkoNePostoji Then
      rst.AddNew
       rst![Sifra artikla] = IDArtikal
       rst![Vrsta dokumenta] = CenovnikVrstaDok
       rst![Cena] = NovaCena
       rst![Tarifa] = DLookup("[Tarifa robe]", "R_Artikli", "[Sifra artikla]=" & IDArtikal)
       rst!Prn = True
      rst.Update
    Else
      retValOk = False
    End If
   End If
   
Exit_Point:
 On Error Resume Next
   rst.Close
   Set rst = Nothing
   UpisiCenuArtiklaUCenovnik = retValOk
'Echo True, "Save: " & BBTimerTrajanjeSec
Exit Function
Err_Point:
   BBErrorMSG err, "UpisiCenuArtiklaUCenovnik"
   err.Clear
   retValOk = False
   Resume Exit_Point
End Function
Public Function OdrediCenuZaKasaBlok_OLD(CenovnikVrstaDok As String, _
                                    ZaIDArtikal As Long, _
                                    KupacRabat As Currency, _
                                    ByRef RetValMPCena As Currency, _
                                    ByRef RetValKLMPCena As Currency, _
                                    ByRef RetValTarifaRobe As String, _
                                    ByRef RetValTaksa As Currency _
                                    ) As Currency
 On Error GoTo Err_Point

    Dim rstCene As DAO.Recordset
    Dim stSQL As String
    Dim Cena1 As Currency
    Dim Cena2 As Currency
    
    
    stSQL = ""
    stSQL = stSQL & "SELECT Cena,Taksa,ZakCen ,Round([Cena]*(1-[PopustProc]/100),2) AS Popust1Cena, R_Poreklo.PopustProc, R_Artikli.[Tarifa robe] as TarifaRobeIzArtikla, Round([Cena]*" & (1 - KupacRabat / 100) & " ,2) AS Popust2Cena "
    stSQL = stSQL & "FROM R_Poreklo INNER JOIN (Cenovnik INNER JOIN R_Artikli ON Cenovnik.[Sifra artikla] = R_Artikli.[Sifra artikla]) ON R_Poreklo.Poreklo = R_Artikli.Poreklo"
    stSQL = stSQL & " WHERE (Cenovnik.[Vrsta dokumenta]= '" & CenovnikVrstaDok & "')"
    stSQL = stSQL & " AND (Cenovnik.[Sifra artikla]= " & ZaIDArtikal & ")"
    
    'Debug.Print stSQL
    
    Set rstCene = CurrentDb.OpenRecordset(stSQL, dbOpenSnapshot, dbReadOnly)
    
    If rstCene.EOF And rstCene.BOF Then
        MsgBox "Trazeni artikal nije u cenovniku!", vbExclamation, "QMegaTeh"
        RetValTarifaRobe = Nz(DLookup("[Tarifa robe]", "R_Artikli", "[Sifra artikla] = " & ZaIDArtikal), "3") 'rstCene!TarifaRobeIzArtikla
        RetValKLMPCena = 0
        RetValMPCena = 0
        RetValTaksa = 0
    Else
        If rstCene![ZakCen] Then
           RetValKLMPCena = Round(Nz(rstCene![Cena], 0), 2)
           RetValMPCena = Round(Nz(rstCene![Cena], 0), 2)
        Else
           Cena1 = CCur(Round(Nz(rstCene![Popust1Cena], 0), 2))
           Cena2 = CCur(Round(Nz(rstCene![Popust2Cena], 0), 2))
           RetValKLMPCena = Round(Nz(rstCene![Cena], 0), 2)
           RetValMPCena = IIf(Cena1 < Cena2, Cena1, Cena2)
        End If
        RetValTaksa = rstCene![TAKSA]
        RetValTarifaRobe = rstCene!TarifaRobeIzArtikla
    End If
  
Exit_Point:
  On Error Resume Next
  rstCene.Close
  Set rstCene = Nothing
  
  OdrediCenuZaKasaBlok_OLD = RetValMPCena
 Exit Function
Err_Point:
 BBErrorMSG err, "OdrediCenuZaKasaBlok_OLD"
 Resume Exit_Point
End Function
Public Function OdrediCenuZaKasaBlok(CenovnikVrstaDok As String, ZaIDArtikal As Long, KupacRabat As Currency, _
                                        ByRef RetValMPCena As Currency, _
                                        ByRef RetValKLMPCena As Currency, _
                                        ByRef RetValTarifaRobe As String, _
                                        ByRef RetValTaksa As Currency, _
                                        ByRef PU_GTIN As Variant, _
                                        ByRef PU_Labels As String, _
                                        ByRef PU_Name As String _
                                        ) As Currency
'Modifikovano: 17-03-2022
'Modifikovano: 03-04-2022 (kataloski broj)
'Insertovano: 04-04-2022 iz BigBit e-Kasa

 On Error GoTo Err_Point

    Dim rstCene As ADODB.Recordset
    Dim stSQL As String
    Dim Cena1 As Currency
    Dim Cena2 As Currency
    Dim stKatBroj As String
    
    
    
    stSQL = ""
    stSQL = stSQL & "SELECT Cena, Taksa, ZakCen, Round([Cena]*(1-[PopustProc]/100),2) AS Popust1Cena"
    stSQL = stSQL & "       ,R_Poreklo.PopustProc, R_Artikli.[Tarifa robe] as TarifaRobeIzArtikla"
    stSQL = stSQL & "       ,Round([Cena]*" & (1 - KupacRabat / 100) & " ,2) AS Popust2Cena "
    stSQL = stSQL & "       ,R_Tarife.PU_Labels "
    stSQL = stSQL & "       ,R_Artikli.[Kataloski broj],R_Artikli.[Barkod], R_Artikli.Naziv, R_Artikli.[Jedinica mere] "
    stSQL = stSQL & " FROM             R_Tarife "
    stSQL = stSQL & "       INNER JOIN R_Poreklo"
    stSQL = stSQL & "       INNER JOIN R_Artikli ON R_Poreklo.Poreklo = R_Artikli.Poreklo ON R_Tarife.Tarifa = R_Artikli.[Tarifa robe]"
    stSQL = stSQL & "       LEFT OUTER JOIN (SELECT [Sifra artikla],Cena,Taksa,ZakCen "
    stSQL = stSQL & "                        FROM Cenovnik "
    stSQL = stSQL & "                        WHERE (Cenovnik.[Vrsta dokumenta]='" & CenovnikVrstaDok & "') "
    stSQL = stSQL & "                        ) as Cen ON R_Artikli.[Sifra artikla] = Cen.[Sifra artikla] "
    stSQL = stSQL & " WHERE (R_Artikli.[Sifra artikla]= " & stR(ZaIDArtikal) & ")"
    
    'Debug.Print stSQL
    
    'Set rstCene = CurrentDb.OpenRecordset(stSQL, dbOpenSnapshot, dbReadOnly)
    Set rstCene = ADO_GetRST(CNN_CurrentDataBase, stSQL)
    
    If (rstCene.EOF And rstCene.BOF) Or Nz(rstCene!Cena, 0) = 0 Then
        MsgBox "Trazeni artikal nema cenu u cenovniku!", vbExclamation, "QMegaTeh"
        'RetValTarifaRobe = Nz(ADO_Lookup(CNN_CurrentDataBase, "[Tarifa robe]", "R_Artikli", "[Sifra artikla] = " & Str(ZaIDArtikal)), "3")
        RetValKLMPCena = 0
        RetValMPCena = 0
        'RetValTaksa = 0
        'PU_Labels = Nz(ADO_Lookup(CNN_CurrentDataBase, "[PU_Labels]", "R_Tarife", "[Tarifa] = '" & RetValTarifaRobe & "'"), "")
        'PU_Name = ""
        'PU_GTIN = ""
    Else
        If Nz(rstCene![ZakCen], True) Then
           RetValKLMPCena = Round(Nz(rstCene![Cena], 0), 2)
           RetValMPCena = Round(Nz(rstCene![Cena], 0), 2)
        Else
           Cena1 = CCur(Round(Nz(rstCene![Popust1Cena], 0), 2))
           Cena2 = CCur(Round(Nz(rstCene![Popust2Cena], 0), 2))
           RetValKLMPCena = Round(Nz(rstCene![Cena], 0), 2)
           RetValMPCena = IIf(Cena1 < Cena2, Cena1, Cena2)
        End If
    End If
        
        RetValTaksa = 0
        RetValTarifaRobe = rstCene!TarifaRobeIzArtikla
        PU_Labels = Nz(rstCene!PU_Labels, "")
        
        'Kataloski broj
        stKatBroj = Trim(Nz(rstCene![Kataloski broj], ""))
        If stKatBroj = "-" Then
            stKatBroj = ""
        End If
        'PU_Name = IIf(Nz(rstCene![Kataloski broj], "") = "", "", "[" & rstCene![Kataloski broj] & "] ") + rstCene!Naziv
        PU_Name = IIf(Nz(stKatBroj, "") = "", "", "[" & stKatBroj & "] ") + rstCene!Naziv
        
        PU_Name = PU_Name & IIf(Nz(rstCene![Jedinica mere], "") = "", "", " /" & rstCene![Jedinica mere]) '& "/")
        PU_GTIN = IIf(Len(LTrim(RTrim(Left(LTrim(RTrim(Nz(rstCene!BarKod, ""))), 14)))) >= 8, Replace(LTrim(RTrim(Left(LTrim(RTrim(Nz(rstCene!BarKod, ""))), 14))), Chr(9), ""), Null)
    
  
Exit_Point:
  On Error Resume Next
  rstCene.Close
  Set rstCene = Nothing
  
  OdrediCenuZaKasaBlok = RetValMPCena
 Exit Function
Err_Point:
 BBErrorMSG err, "OdrediCenuZaKasaBlok"
 Resume Exit_Point
End Function
Public Function TEST_CenaIzCenovnikaZaKasaBlok(ZaIDArtikal As Long)
 Dim CenovnikVrstaDok As String
 'Dim ZaIDArtikal As Long
 Dim ZaIDKomitent As Long
 Dim RetValMPCena As Currency
 Dim RetValKLMPCena As Currency
 Dim RetValTarifaRobe As String
 Dim RetValTaksa As Currency
 Dim KupacRabat As Currency
 
 CenovnikVrstaDok = "MP1"
 'ZaIDArtikal = 7
 ZaIDKomitent = 4465
 KupacRabat = 20
 Call OdrediCenuZaKasaBlok_OLD(CenovnikVrstaDok, ZaIDArtikal, KupacRabat, RetValMPCena, RetValKLMPCena, RetValTarifaRobe, RetValTaksa)
 Debug.Print "RetValKLMPCena=" & RetValKLMPCena
 Debug.Print "RetValMPCena=" & RetValMPCena
 Debug.Print "RetValTarifaRobe=" & RetValTarifaRobe
End Function
Public Function PromeniIzlazneCeneUDokumentu_SQL(IDDok As Long, UzmiCeneIzCenovnika As Boolean, CenovnikVrstaDok As String, CenovnikSaPDV As Boolean, _
                                             UpisiNoviRabat As Boolean, NoviRabatProc As Double, _
                                             UpisiNoviExRabat As Boolean, NoviExRabatProc As Double, _
                                             IDFirma As Long, Godina As Long, FakturnaJeNetoVP As Boolean) As Boolean

On Error GoTo Err_Point
 Dim retValOk As Boolean

If DLookup("Zakljucano", "T_Robna dokumenta", "[IDDok] = " & IDDok) Then
     retValOk = False
     PromeniIzlazneCeneUDokumentu_SQL = retValOk
     MsgBox "Dokument je zakljucan!", vbCritical, "QMegaTeh"
    Exit Function
   End If

retValOk = ADO_ExecSP(BBCFG.CNNString, "spIF_PromeniVPCeneUDok", IDFirma, Godina, IDDok, _
                    UzmiCeneIzCenovnika, CenovnikVrstaDok, CenovnikSaPDV, _
                    UpisiNoviRabat, NoviRabatProc, _
                    UpisiNoviExRabat, NoviExRabatProc, _
                    FakturnaJeNetoVP)
 'spIF_PromeniVPCeneUDok(
 '   @IDFirma int,
 '   @Godina int,
 '   @IDDok int,
 '   @UzmiCeneIzCenovnika bit = 0,
 '   @CenovnikVrstaDok nvarchar(10)= Null,
 '   @CenovnikSaPDV bit,
 '   @UpisiNoviRabat bit = 0,
 '   @NoviRabatProc float ,
 '   @UpisiNoviExRabat bit = 0,
 '   @NoviExRabatProc bit )
Exit_Point:
 On Error Resume Next
 PromeniIzlazneCeneUDokumentu_SQL = retValOk
Exit Function

Err_Point:
 retValOk = False
 BBErrorMSG err, "PromeniIzlazneCeneUDokumentu_SQL"
End Function
'
'*************************************************************************************************
'Modifikovano: 05-12-2019     - dodat ExRabat
Public Function PromeniIzlazneCeneUDokumentu(IDDok As Long, UzmiCeneIzCenovnika As Boolean, CenovnikVrstaDok As String, CenovnikSaPDV As Boolean, _
                                             UpisiNoviRabat As Boolean, NoviRabatProc As Double, _
                                             UpisiNoviExRabat As Boolean, NoviExRabatProc As Double) As Boolean
On Error GoTo Err_Point
   Dim retValOk As Boolean
   Dim BigBit As DAO.Database
   Dim rstStavke As DAO.Recordset
   Dim SQLText As String
   Dim CenaIzCenovnika As Variant '!!! mora
   Dim NovaVPCenaZaUpis As Currency
   Dim NovaMPCenaZaUpis As Currency
   Dim NoviRabatProcZaUpis As Currency
   Dim NoviExRabatProcZaUpis As Currency
   Dim PDVStopa As Currency
   
   If DLookup("Zakljucano", "T_Robna dokumenta", "[IDDok] = " & IDDok) Then
     retValOk = False
     PromeniIzlazneCeneUDokumentu = retValOk
     MsgBox "Dokument je zakljucan!", vbCritical, "QMegaTeh"
    Exit Function
   End If
   
   SQLText = "SELECT [T_Robne stavke].* FROM [T_Robne stavke] WHERE [IDDok] = " & IDDok
   retValOk = True
   Set BigBit = CurrentDb
   Set rstStavke = BigBit.OpenRecordset(SQLText, dbOpenDynaset, dbSeeChanges)
   
   While Not rstStavke.EOF
    
    rstStavke.Edit
    NovaVPCenaZaUpis = rstStavke![Stvarna VP cena]
    NovaMPCenaZaUpis = rstStavke![Stvarna MP cena]
    NoviRabatProcZaUpis = rstStavke![RabatProc]
    NoviExRabatProcZaUpis = rstStavke![KasaProc]
    
    If UzmiCeneIzCenovnika Then
       CenaIzCenovnika = Cene.CenaIzCenovnika(CenovnikVrstaDok, rstStavke![Sifra artikla])
       If IsNumeric(CenaIzCenovnika) Then
          If CenaIzCenovnika > 0 Then
             PDVStopa = PDVStopaZaTarifu(rstStavke![Tarifa - roba - Izlaz])
             NovaVPCenaZaUpis = IIf(CenovnikSaPDV, CenaIzCenovnika / (1 + (PDVStopa / 100)), CenaIzCenovnika)
             'zadržavamo stari rabat i kasu
             NovaVPCenaZaUpis = (NovaVPCenaZaUpis * (1 - (rstStavke![RabatProc] / 100))) * (1 - (rstStavke![KasaProc] / 100))
             NovaMPCenaZaUpis = Round(NovaVPCenaZaUpis * (1 + PDVStopa / 100), 2)
          End If
       End If
    End If
    If UpisiNoviRabat Or UpisiNoviExRabat Then
       'skini stari rabat i kasu tj. ExRabat
       NovaVPCenaZaUpis = (NovaVPCenaZaUpis / (1 - (rstStavke![KasaProc] / 100))) / (1 - (rstStavke![RabatProc] / 100))
       'primeni novi
       NovaVPCenaZaUpis = (NovaVPCenaZaUpis * (1 - (NoviRabatProc / 100))) * (1 - (NoviExRabatProc / 100))
       NovaMPCenaZaUpis = Round(NovaVPCenaZaUpis * (1 + PDVStopa / 100), 2)
       NoviRabatProcZaUpis = NoviRabatProc
       NoviExRabatProcZaUpis = NoviExRabatProc
    End If
    
    
    rstStavke![Stvarna VP cena] = NovaVPCenaZaUpis
    rstStavke![Stvarna MP cena] = NovaMPCenaZaUpis
    rstStavke![RabatProc] = NoviRabatProcZaUpis
    rstStavke![KasaProc] = NoviExRabatProcZaUpis
    rstStavke.Update
    
    'Debug.Print rstStavke!IDStavke
    rstStavke.MoveNext
   Wend
   
Exit_Point:
 On Error Resume Next
 BigBit.Close
 Set BigBit = Nothing
 rstStavke.Close
 Set rstStavke = Nothing
 PromeniIzlazneCeneUDokumentu = retValOk
Exit Function

Err_Point:
 retValOk = False
 BBErrorMSG err, "PromeniIzlazneCeneUDokumentu"
End Function
Public Function ProsNCZaArt(IDArtikal As Long, OdDatuma As Date, DoDatuma As Date, Optional IDMagacin = Null _
                            , Optional OdLevel As Byte = 0, Optional DoLevel As Byte = 0, Optional IDFirma = Null, Optional Godina = Null) As Currency

'Modifikovano:06-03-2020
                              
If BBCFG.SQLDB Then
 'ProsNCZaArt = SQL_ProsNCZaArt(IDArtikal, OdDatuma, DoDatuma, IDMagacin, OdLevel, DoLevel, IDFirma, Godina)
 ProsNCZaArt = fsVPProsNC(IDArtikal, IDFirma, Godina, OdLevel, DoLevel, IDMagacin, OdDatuma, DoDatuma, Null)
Else
 ProsNCZaArt = Acc_ProsNCZaArt(IDArtikal, OdDatuma, DoDatuma, IDMagacin, OdLevel, DoLevel, IDFirma, Godina)
End If
End Function

Public Function SQL_ProsNCZaArt(IDArtikal As Long, OdDatuma As Date, DoDatuma As Date, Optional IDMagacin = Null _
                            , Optional OdLevel As Byte = 0, Optional DoLevel As Byte = 0, Optional IDFirma = Null, Optional Godina = Null) As Currency
'Created: 22-09-2019
On Error GoTo Err_Point

    Dim stSQL As String
    Dim rst As ADODB.Recordset
    Dim retValProsNC As Currency
    
    'ftProsecneCene(
                    '@IDFirma int,
                    '@Godina int ,
                    '@OdLevel int = 0,
                    '@DoLevel int = 0,
                    '@ZaIDMagacin int,
                    '@DoDatuma Date,
                    '@ZaIDArtikal int
    ')
    
    stSQL = TextSelectQForUDFT("[ftProsecneCene]", IDFirma, Godina, OdLevel, DoLevel, IDMagacin, SQLFormatDatuma(DoDatuma), IDArtikal)
    Set rst = ADO_GetRST(BBCFG.CNNString, stSQL) 'ADO_GetRST(BBCFG.CNNString,stSQL)
    If rst.EOF And rst.BOF Then
     'ne postoje stavke u recordsetu
     retValProsNC = 0
     GoTo Exit_Point
    End If
    
    rst.Find ("[IDArt] = " & IDArtikal)
    If rst.EOF Then
       retValProsNC = 0
    Else
       retValProsNC = rst!ProsNC
    End If
        
Exit_Point:
   On Error Resume Next
   rst.Close
   Set rst = Nothing
   
   SQL_ProsNCZaArt = retValProsNC
Exit Function
Err_Point:
   BBErrorMSG err, "SQL_ProsNCZaArt"
   retValProsNC = 0
   Resume Exit_Point
End Function
Public Function Acc_ProsNCZaArt(IDArtikal As Long, OdDatuma As Date, DoDatuma As Date, Optional IDMagacin = Null _
                            , Optional OdLevel As Byte = 0, Optional DoLevel As Byte = 0, Optional IDFirma = Null, Optional Godina = Null) As Currency
'Created: 28-11-2018
On Error GoTo Err_Point

    Dim stDocName As String
    Dim qDef As DAO.QueryDef
    Dim rst As DAO.Recordset
    Dim retValProsNC As Currency

    
        stDocName = "QProsNC"
        Set qDef = CurrentDb.QueryDefs(stDocName)
        qDef.Parameters("[ZaIDArtikal]") = IDArtikal
        qDef.Parameters("[OdDatuma]") = OdDatuma
        qDef.Parameters("[DoDatuma]") = DoDatuma
        qDef.Parameters("[ZaIDMagacin]") = IDMagacin
        qDef.Parameters("[OdLevel]") = OdLevel
        qDef.Parameters("[DoLevel]") = DoLevel
        qDef.Parameters("[ZaIDFirma]") = IDFirma
        qDef.Parameters("[ZaGodinu]") = Godina
        
        Set rst = qDef.OpenRecordset()
        
        rst.FindFirst ("[Sifra artikla] = " & IDArtikal)
        If rst.NoMatch Then
            retValProsNC = 0
        Else
            retValProsNC = rst!ProsNCZaliha
        End If
        
Exit_Point:
   On Error Resume Next
   rst.Close
   Set rst = Nothing
   Set qDef = Nothing
   
   Acc_ProsNCZaArt = retValProsNC
Exit Function
Err_Point:
   BBErrorMSG err, "Acc_ProsNCZaArt"
   retValProsNC = 0
   Resume Exit_Point
End Function
Public Function BSM_PoslednjiDatRabat(IDKomitent As Long, IDArtikal As Long) As Double
On Error GoTo Err_Point
 Dim stSQLTG As String
 Dim stSQLPG As String
 Dim IDStavkeTG As Variant
 Dim IDStavkePG As Variant
 Dim retValRabat As Double
 Dim qdfTMP As DAO.QueryDef
 Dim rstTMP As DAO.Recordset
  
 stSQLTG = "SELECT Max([T_Robne stavke].IDStavke) AS MaxOfIDStavke"
 stSQLTG = stSQLTG & " FROM [T_Robna dokumenta] INNER JOIN [T_Robne stavke] ON [T_Robna dokumenta].IDDok = [T_Robne stavke].IDDok"
 stSQLTG = stSQLTG & " WHERE ([T_Robna dokumenta].Ulaz=False)"
 stSQLTG = stSQLTG & " AND ([T_Robna dokumenta].[Sifra komitenta]=" & IDKomitent & ")"
 stSQLTG = stSQLTG & " AND ([T_Robne stavke].[Sifra artikla]= " & IDArtikal & ")"
 stSQLTG = stSQLTG & " AND ([T_Robne stavke].Kolicina>0) "
 stSQLTG = stSQLTG & " AND ([T_Robna dokumenta].Level<=" & F_NivoBaze() & ")"
 stSQLTG = stSQLTG & " AND ([T_Robna dokumenta].IDFirma=" & F_IDFirma() & ")"
 
 Set qdfTMP = CurrentDb.CreateQueryDef("", stSQLTG)
 Set rstTMP = qdfTMP.OpenRecordset()
 rstTMP.MoveFirst
 IDStavkeTG = rstTMP!MaxOfIDStavke ' IDStavkeTG = DLookup("[MaxOfIDStavke]", stSQLTG)

 If Not IsNull(IDStavkeTG) Then
    retValRabat = DLookup("[RabatProc]", "T_Robne stavke", "[IDStavke] = " & IDStavkeTG)
 ElseIf PostojiTabelaUBazi("T_Robne stavke1", CurrentDb) Then
    stSQLPG = "SELECT Max([T_Robne stavke1].IDStavke) AS MaxOfIDStavke"
    stSQLPG = stSQLPG & " FROM [T_Robna dokumenta1] INNER JOIN [T_Robne stavke1] ON [T_Robna dokumenta1].IDDok = [T_Robne stavke1].IDDok"
    stSQLPG = stSQLPG & " WHERE ([T_Robna dokumenta1].Ulaz=False)"
    stSQLPG = stSQLPG & " AND ([T_Robna dokumenta1].[Sifra komitenta]=" & IDKomitent & ")"
    stSQLPG = stSQLPG & " AND ([T_Robne stavke1].[Sifra artikla]= " & IDArtikal & ")"
    stSQLPG = stSQLPG & " AND ([T_Robne stavke1].Kolicina>0) "
    stSQLPG = stSQLPG & " AND ([T_Robna dokumenta1].Level<=" & F_NivoBaze() & ")"
    stSQLPG = stSQLPG & " AND ([T_Robna dokumenta1].IDFirma=" & F_IDFirma() & ")"
 
    Set qdfTMP = CurrentDb.CreateQueryDef("", stSQLPG)
    Set rstTMP = qdfTMP.OpenRecordset()
    rstTMP.MoveFirst
    IDStavkePG = rstTMP!MaxOfIDStavke 'IDStavkePG = DLookup("[MaxOfIDStavke]", stSQLPG)
    If Not IsNull(IDStavkePG) Then
       retValRabat = DLookup("[RabatProc]", "T_Robne stavke1", "[IDStavke] = " & IDStavkePG)
    Else
       retValRabat = 0
    End If
 Else
  retValRabat = 0
 End If
Exit_Point:
  On Error Resume Next
  BSM_PoslednjiDatRabat = retValRabat
  Set qdfTMP = Nothing
  rstTMP.Close
  Set rstTMP = Nothing
  
Exit Function
Err_Point:
  BBErrorMSG err, "BSM_PoslednjiDatRabat"
  retValRabat = 0
  Resume Exit_Point
End Function
Public Function PoslednjaNCZaArt(IDArtikal As Long, OdDatuma As Date, DoDatuma As Date, Optional IDMagacin = Null _
                            , Optional OdLevel As Byte = 0, Optional DoLevel As Byte = 0, Optional IDFirma = Null, Optional Godina = Null) As Currency
' ? PoslednjaNCZaArt(16029,"01-01-19","31-12-19")
'Kreirano: 28-08-2019
 Dim stDocName As String
    Dim qDef As DAO.QueryDef
    Dim rst As DAO.Recordset
    Dim retValPoslednjaNC As Currency

    
        stDocName = "QPoslednjeCene"
        Set qDef = CurrentDb.QueryDefs(stDocName)
        qDef.Parameters("[ZaArtikal]") = IDArtikal
        qDef.Parameters("[OdDatuma]") = OdDatuma
        qDef.Parameters("[DoDatuma]") = DoDatuma
        qDef.Parameters("[ZaIDMagacin]") = IDMagacin
        qDef.Parameters("[OdLevel]") = OdLevel
        qDef.Parameters("[DoLevel]") = DoLevel
        qDef.Parameters("[ZaIDFirma]") = IDFirma
        qDef.Parameters("[ZaGodinu]") = Godina
        
        Set rst = qDef.OpenRecordset(dbOpenSnapshot, dbSeeChanges)

        If Not rst.BOF Then 'ima slogova i treba ga popuniti
          rst.MoveLast 'popuni recordset
          rst.FindFirst ("[Sifra artikla] = " & IDArtikal)
          If rst.NoMatch Then
            retValPoslednjaNC = 0
          Else
            retValPoslednjaNC = rst!PoslednjaNCBruto
          End If
        Else
          retValPoslednjaNC = 0
        End If
        
        
Exit_Point:
   On Error Resume Next
   rst.Close
   Set rst = Nothing
   Set qDef = Nothing
      
   PoslednjaNCZaArt = retValPoslednjaNC
Exit Function
Err_Point:
   BBErrorMSG err, "PoslednjaNCZaArt"
   retValPoslednjaNC = 0
   Resume Exit_Point
End Function

Public Function RabatIExRabatKomitentaZaArtikal_Access(ByVal IDKomitent As Long, ByVal IDArtikal As Long, ByVal NaDan As Date, Optional ByRef RetVal_RabatProc As Double, Optional ByRef RetVal_ExtraRabatProc As Double) As Double
'? RabatIExRabatKomitentaZaArtikal(4465,2928,date())
'Kreirano: 07-09-2019
On Error GoTo Err_Point
Dim retValR As Double
Dim retValExR As Double
Dim GrupaArtikla As String
Dim PodgrupaArtikla As String
Dim GeneralniRabat As Double
Dim RabatGrupa As Variant
Dim RabatPodgrupa As Variant
Dim RabatArtikal As Variant
Dim MaxRabatProc As Double
Dim OdDatuma As Variant
Dim DoDatuma As Variant

retValExR = 0
MaxRabatProc = Nz(DLookup("[MaxRabatProc]", "R_Artikli", "[Sifra artikla]=" & CStr(IDArtikal)), 100)
RabatArtikal = DLookup("[RabatProc]", "RabatiPoArt", "Sifra=" & CStr(IDKomitent) & " AND [IDArtikal]=" & CStr(IDArtikal))
If Not IsNull(RabatArtikal) Then
 OdDatuma = CVDate(Nz(DLookup("[OdDatuma]", "RabatiPoArt", "Sifra=" & CStr(IDKomitent) & " AND [IDArtikal]=" & CStr(IDArtikal)), "01-01-1901"))
 DoDatuma = CVDate(Nz(DLookup("[DoDatuma]", "RabatiPoArt", "Sifra=" & CStr(IDKomitent) & " AND [IDArtikal]=" & CStr(IDArtikal)), "31-12-2099"))
 If (OdDatuma <= NaDan) And (NaDan <= DoDatuma) Then
    retValR = CDbl(RabatArtikal)
    retValExR = Nz(DLookup("[ExtraRabatProc]", "RabatiPoArt", "Sifra=" & CStr(IDKomitent) & " AND [IDArtikal]=" & CStr(IDArtikal)), 0)
    GoTo Exit_Point
 End If
End If

PodgrupaArtikla = DLookup("[Podgrupa]", "R_Artikli", "[Sifra artikla]=" & CStr(IDArtikal))
RabatPodgrupa = DLookup("[RabatProc]", "RabatiPodgrupa", "Sifra=" & CStr(IDKomitent) & " AND [IDPodgrupa]='" & PodgrupaArtikla & "'")
If Not IsNull(RabatPodgrupa) Then
 retValR = CDbl(RabatPodgrupa)
 retValExR = Nz(DLookup("[ExtraRabatProc]", "RabatiPodgrupa", "Sifra=" & CStr(IDKomitent) & " AND [IDPodgrupa]='" & PodgrupaArtikla & "'"), 0)
 GoTo Exit_Point
End If

GrupaArtikla = DLookup("[Grupa]", "R_Artikli", "[Sifra artikla]=" & CStr(IDArtikal))
RabatGrupa = DLookup("[RabatProc]", "Rabati", "Sifra=" & CStr(IDKomitent) & " AND [IDGrupa]='" & GrupaArtikla & "'")
If Not IsNull(RabatGrupa) Then
 retValR = CDbl(RabatGrupa)
 retValExR = Nz(DLookup("[ExtraRabatProc]", "Rabati", "Sifra=" & CStr(IDKomitent) & " AND [IDGrupa]='" & GrupaArtikla & "'"), 0)
 GoTo Exit_Point
End If

GeneralniRabat = Nz(DLookup("[RabatKomitenta]", "Komitenti", "[Sifra]=" & CStr(IDKomitent)), 0)
retValR = CDbl(GeneralniRabat)

Exit_Point:
On Error Resume Next
If (retValR * (1 + retValExR / 100)) > MaxRabatProc Then
   retValR = MaxRabatProc
   retValExR = 0
End If
If retValR >= 100 Then
 retValR = 99.99
End If
If retValExR >= 100 Then
 retValExR = 99.99
End If
RetVal_RabatProc = retValR
RabatIExRabatKomitentaZaArtikal_Access = retValR
Exit Function

Err_Point:
    BBErrorMSG err, "RabatIExRabatKomitentaZaArtikal(IDKomitent=" & IDKomitent & ", IDArtikal=" & IDArtikal & ", NaDan=" & NaDan & ")"
    Resume Exit_Point:
End Function
Public Function spRabatIExRabatKomitentaZaArtikal(ByVal IDKomitent As Long, ByVal IDArtikal As Long, ByVal NaDan As Date, ByRef RetVal_RabatProc As Double, ByRef RetVal_ExtraRabatProc As Double, Optional ByRef RetVal_IzTabele) As Boolean
'Kreirano: 22-04-2020
On Error GoTo Err_Point

Dim pCMD As New ADODB.Command
Dim retValOk As Boolean

retValOk = True
DoCmd.Hourglass True

pCMD.ActiveConnection = BBCFG.CNNString
pCMD.CommandType = adCmdStoredProc
pCMD.CommandText = "spRabatIExRabatKomitentaZaArtikal"

pCMD.Parameters.Refresh 'posle ove komande svi parametri su definisani!
'pCMD.Parameters("@RETURN_VALUE") = CmdRetVal
pCMD.Parameters("@IDFirma") = F_IDFirma()
pCMD.Parameters("@Godina") = F_Godina()
pCMD.Parameters("@IDKomitent") = IDKomitent
pCMD.Parameters("@IDArtikal") = IDArtikal
pCMD.Parameters("@NaDan") = SQLFormatDatuma(NaDan, False)
pCMD.Parameters("@RabatIzPoslednjeProdaje") = 0
'pCMD.Parameters("@RetVal_RabatProc") = RetVal_RabatProc ' OUTPUT
'pCMD.Parameters("@RetVal_ExtraRabatProc") = RetVal_ExtraRabatProc 'OUTPUT
'pCMD.Parameters("@RetVal_IzTabele") = RetVal_IzTabele'OUTPUT

pCMD.CommandTimeout = 180 '3 minuta !!

pCMD.Execute
retValOk = (pCMD.ActiveConnection.Errors.Count = 0)
RetVal_RabatProc = pCMD.Parameters("@RetVal_RabatProc").Value ' OUTPUT
RetVal_ExtraRabatProc = pCMD.Parameters("@RetVal_ExtraRabatProc").Value 'OUTPUT
RetVal_IzTabele = pCMD.Parameters("@RetVal_IzTabele").Value 'OUTPUT

Exit_Point:
On Error Resume Next

Set pCMD = Nothing
DoCmd.Hourglass False
spRabatIExRabatKomitentaZaArtikal = retValOk
Exit Function

Err_Point:

    BBErrorMSG err, "spRabatIExRabatKomitentaZaArtikal(...)"
    retValOk = False
    Resume Exit_Point

End Function
Public Function RabatIExRabatKomitentaZaArtikal(ByVal IDKomitent As Long, ByVal IDArtikal As Long, ByVal NaDan As Date, Optional ByRef RetVal_RabatProc As Double, Optional ByRef RetVal_ExtraRabatProc As Double, Optional ByRef RetVal_IzTabele) As Double
   If BBCFG.SQLDB Then
     Call spRabatIExRabatKomitentaZaArtikal(IDKomitent, IDArtikal, NaDan, RetVal_RabatProc, RetVal_ExtraRabatProc, RetVal_IzTabele)
     RabatIExRabatKomitentaZaArtikal = RetVal_RabatProc
   Else
     RabatIExRabatKomitentaZaArtikal = RabatIExRabatKomitentaZaArtikal_Access(IDKomitent, IDArtikal, NaDan, RetVal_RabatProc, RetVal_ExtraRabatProc)
   End If
End Function
Public Function fsVPProsNC(IDArtikal As Long, Optional IDFirma = Null, Optional Godina = Null, Optional OdLevel = Null, Optional DoLevel = Null, Optional IDMagacin = Null, Optional OdDatuma = Null, Optional DoDatuma = Null, Optional OsimIDStavke = Null) As Currency
'Kreirano: 06-03-2020
Dim retVal As Variant
    retVal = ADO_GetValFromUDFS(CNN_CurrentDataBase, "fsVPProsNC", IDFirma, Godina, OdLevel, DoLevel, IDMagacin, SQLFormatDatuma(OdDatuma, False), SQLFormatDatuma(DoDatuma, False), IDArtikal, OsimIDStavke)
    fsVPProsNC = CCur(Nz(retVal, 0))
End Function
Public Function fsVPCenaKostanjaGP(IDArtikal As Long, Optional IDFirma = Null, Optional Godina = Null, Optional OdLevel = Null, Optional DoLevel = Null, Optional IDMagacin = Null, Optional OdDatuma = Null, Optional DoDatuma = Null) As Currency
'Kreirano: 12-03-2020
Dim retVal As Variant
    retVal = ADO_GetValFromUDFS(CNN_CurrentDataBase, "fsVPCenaKostanjaGP", IDFirma, Godina, OdLevel, DoLevel, IDMagacin, SQLFormatDatuma(OdDatuma, False), SQLFormatDatuma(DoDatuma, False), IDArtikal)
    fsVPCenaKostanjaGP = CCur(Nz(retVal, 0))
End Function

Public Function ProsCenaKostanjaGP(IDArtikal As Long, IDFirma As Long, Godina As Variant, OdLevel As Byte, DoLevel As Byte, IDMagacinTRPR As Variant, SirovineOdDatuma As Variant, SirovineDoDatuma As Variant) As Currency
'Kreirano: 13-03-2020
On Error GoTo Err_Point
Dim NabCena As Currency

    If BBCFG.SQLDB Then
       NabCena = fsVPCenaKostanjaGP(IDArtikal, IDFirma, Godina, OdLevel, DoLevel, IDMagacinTRPR, SirovineOdDatuma, SirovineDoDatuma)
    Else
       'Ovo ne radi dobro u ovom modulu jer su parametri iz forme [Ulazna faktura]
       NabCena = Nz(DLookup("[NabCenaGotProiz]", "ULGP_CenaKostanjaGP", "[ZaSifruArtikla] = " & IDArtikal), 0)
       
    End If
        
    NabCena = Nz(NabCena, 0)

Exit_Point:
 On Error Resume Next
 ProsCenaKostanjaGP = NabCena
Exit Function

Err_Point:
 BBErrorMSG err, "ProsCenaKostanjaGP"
 Resume Exit_Point
End Function

Public Function CenaKostanjaGPZaIDDok(IDArtikal As Long, IDDok As Long, Optional PlanskiCenovnik, Optional IDMagacinTRPR) As Currency
'Kreirano: 12-03-2020
'OBRATI PAŽNJU NA
'CenaKostanjaGotovogProizvoda u modulu Proizvodnja

On Error GoTo Err_Point
    Dim NabCena
    Dim OdDatuma As Date 'za sracunavanje zaliha, Pros NC itd
    Dim DatumDokumenta As Date
    Dim stWhereIDDok As String
    Dim OdLevel As Byte
    Dim DoLevel As Byte
    Dim IDFirma As Long
    Dim Godina As Variant
    Dim pIDMagacinTRPR As Variant
    Dim pPlanskiCenovnik As String

If IsMissing(PlanskiCenovnik) Then
   pPlanskiCenovnik = ""
Else
   pPlanskiCenovnik = CStr(PlanskiCenovnik)
End If

If Nz(pPlanskiCenovnik, "") <> "" Then
        NabCena = Nz(CenaIzCenovnika(CStr(Nz(pPlanskiCenovnik, "")), IDArtikal), 0)
        NabCena = Nz(NabCena, 0)
    Else
        
        stWhereIDDok = "[IDDOk]=" & IDDok
        If IsMissing(IDMagacinTRPR) Then
           pIDMagacinTRPR = DLookup("IDMagacin", "Magacini", "VrstaMag='TRPR'") 'moze da bude i NULL
        Else
           pIDMagacinTRPR = CLng(IDMagacinTRPR)
        End If
        DatumDokumenta = DLookup("[Datum dokumenta]", "T_Robna dokumenta", stWhereIDDok)
        OdDatuma = CVDate("01-01-" & DatePart("yyyy", DatumDokumenta))
        If Format(BBCFG.ZaliheOdDatuma, "yyyyMMdd") <= Format(OdDatuma, "yyyyMMdd") Then
           OdDatuma = BBCFG.ZaliheOdDatuma
           Godina = Null
        Else
           Godina = DLookup("[Godina]", "T_Robna dokumenta", stWhereIDDok)
        End If
        OdLevel = 0
        DoLevel = DLookup("[Level]", "T_Robna dokumenta", stWhereIDDok)
        IDFirma = DLookup("[IDFirma]", "T_Robna dokumenta", stWhereIDDok)
        
        NabCena = ProsCenaKostanjaGP(IDArtikal, IDFirma, Godina, OdLevel, DoLevel, pIDMagacinTRPR, OdDatuma, DatumDokumenta)
        NabCena = Nz(NabCena, 0)
    End If
Exit_Point:
 On Error Resume Next
 CenaKostanjaGPZaIDDok = NabCena
Exit Function

Err_Point:
 BBErrorMSG err, "CenaKostanjaGPZaIDDok"
 Resume Exit_Point
End Function
Public Function PostojiKLZaArtikal(IDArtikal As Variant, Optional IDMagacin As Variant = Null, Optional DoDatuma As Variant = Null) As Boolean
'Kreirano: 30-01-2021
On Error GoTo Err_Point
    Dim retVal As Boolean
    Dim stSQL As String
    Dim Brojslogova As Variant
    
    stSQL = TextSelectQForUDFT("ftPoslednjiIDStavkeZaKL", F_IDFirma(), Null, 0, F_NivoBaze(), IDMagacin, SQLFormatDatuma(DoDatuma, True), IDArtikal)
    
    Brojslogova = ADO_Lookup(BBCFG.CNNString, "BrojSlogova", "SELECT COUNT(*) as BrojSlogova FROM (" & stSQL & ") as r ")
    retVal = (Nz(Brojslogova, 0) > 0)
    
Exit_Point:
 On Error Resume Next
 PostojiKLZaArtikal = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "PostojiKLZaArtikal"
 retVal = False
 Resume Exit_Point
End Function
Public Function F_FakturnaCena(ByVal NetoCena As Variant, ByVal RabatProc As Variant, ByVal ExRabatProc As Variant, Optional ByVal Kurs = 1, Optional ByVal BrojDecimala) As Double
'Kreirano: 05-02-2022

On Error GoTo Err_Point
    Dim retVal_FakturnaCena As Double
    Dim pNetoCena As Double
    Dim pRabatProc As Double
    Dim pExRabatProc As Double
    Dim pKurs As Double
    Dim pBrojDecimala As Byte

pNetoCena = CDbl(Nz(NetoCena, 0#))
    retVal_FakturnaCena = pNetoCena
pRabatProc = CDbl(Nz(RabatProc, 0#))
pExRabatProc = CDbl(Nz(ExRabatProc, 0#))
pKurs = CDbl(Nz(Kurs, 1#))

retVal_FakturnaCena = pKurs * ((10000# * pNetoCena) / ((100# - pRabatProc) * (100# - pExRabatProc)))

If Not IsMissing(BrojDecimala) Then
    pBrojDecimala = CInt(Nz(BrojDecimala, 10))
    retVal_FakturnaCena = Round(retVal_FakturnaCena, pBrojDecimala)
End If

Exit_Point:
 On Error Resume Next
       F_FakturnaCena = retVal_FakturnaCena
Exit Function

Err_Point:
 BBErrorMSG err, "F_FakturnaCena"
 Resume Exit_Point
End Function
