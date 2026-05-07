Attribute VB_Name = "PlaniranjeNabavke"
Option Compare Database
Option Explicit

Public Function KreirajDokumentPlaniranjaNabavke(ByVal pIDPredmet As Long, _
                                                ByVal pIDCrtezSklopa As Long, _
                                                ByVal pKolicinaZaIzradu As Double, _
                                                ByVal pSifraRadnika As Long, _
                                                ByRef pIDPlan As Long) As Boolean
    On Error GoTo Err_Handler

    Dim retValOk As Boolean
    Dim Napomena As String
    
    retValOk = True
    
    Napomena = "Prva faza planiranja"
    
    ' --- Osnovne validacije ---
    If pIDPredmet <= 0 Then
        MsgBox "Nije izabran predmet.", vbExclamation
        retValOk = False
        GoTo Exit_Handler
    End If

    If pIDCrtezSklopa <= 0 Then
        MsgBox "Nije izabran sklop za planiranje.", vbExclamation
        retValOk = False
        GoTo Exit_Handler
    End If

    If pKolicinaZaIzradu <= 0 Then
        MsgBox "Kolièina za izradu mora biti veæa od nule.", vbExclamation
        retValOk = False
        GoTo Exit_Handler
    End If

    If pSifraRadnika <= 0 Then
        MsgBox "Nije definisan radnik koji vrši planiranje.", vbExclamation
        retValOk = False
        GoTo Exit_Handler
    End If

    ' --- Preuzimanje rezultata ---
    'retValOk = ADO_ExecSP(CNN_CurrentDataBase, "spPDM_KreirajPlanSaStavkama", pIDPredmet, pIDCrtezSklopa, pKolicinaZaIzradu, pSifraRadnika, Napomena, pIDPlan)
    
    If Not spKreirajPlanSaStavkama(pIDPredmet, pIDCrtezSklopa, pKolicinaZaIzradu, pSifraRadnika, Napomena, pIDPlan) Then
        MsgBox "Dokument planiranja nabavke gotovih delova NIJE kreiran", vbExclamation, "QMegaTeh"
        retValOk = False
        GoTo Exit_Handler
    End If
    
    If pIDPlan <= 0 Then
        MsgBox "Dokument planiranja nije kreiran.", vbCritical
        retValOk = False
        GoTo Exit_Handler
    End If

Exit_Handler:
    On Error Resume Next
    KreirajDokumentPlaniranjaNabavke = retValOk
    Exit Function

Err_Handler:
    MsgBox "Greška pri kreiranju dokumenta planiranja nabavke:" & vbCrLf & err.Description, vbCritical
    retValOk = False
    Resume Exit_Handler
End Function

Public Function spKreirajPlanSaStavkama(IDPredmet As Long, IDCrtezSklopa As Long, _
                                        KolicinaZaIzradu As Double, SifraRadnikaPlaniranja As Long, _
                                        Napomena As String, ByRef IDPlan As Long)
'Kreirano: 22-04-2020
On Error GoTo Err_Point

    Dim pCMD As New ADODB.Command
    Dim retValOk As Boolean
    
    retValOk = True
    DoCmd.Hourglass True
    
    pCMD.ActiveConnection = BBCFG.CNNString
    pCMD.CommandType = adCmdStoredProc
    pCMD.CommandText = "spPDM_KreirajPlanSaStavkama"
    
    pCMD.Parameters.Refresh 'posle ove komande svi parametri su definisani!
    'pCMD.Parameters("@RETURN_VALUE") = CmdRetVal
    pCMD.Parameters("@IDPredmet") = IDPredmet
    pCMD.Parameters("@IDCrtezSklopa") = IDCrtezSklopa
    pCMD.Parameters("@KolicinaZaIzradu") = KolicinaZaIzradu
    pCMD.Parameters("@SifraRadnikaPlaniranja") = SifraRadnikaPlaniranja
    pCMD.Parameters("@Napomena") = Napomena
    pCMD.Parameters("@Korisnik") = CurrentUser()
    
    pCMD.CommandTimeout = 180 '3 minuta !!
    
    pCMD.Execute
    retValOk = (pCMD.ActiveConnection.Errors.Count = 0)
    
    IDPlan = pCMD.Parameters("@IDPlan").Value ' OUTPUT

Exit_Point:
On Error Resume Next

Set pCMD = Nothing
DoCmd.Hourglass False
spKreirajPlanSaStavkama = retValOk
Exit Function

Err_Point:

    BBErrorMSG err, "spKreirajPlanSaStavkama(...)"
    retValOk = False
    Resume Exit_Point

End Function
Public Function UpdatePlaniranjeStavke_SifraArtikla_Zalihe( _
    ByVal pIDPlan As Long) As Boolean

On Error GoTo Err_Handler

    Dim db As DAO.Database
    Dim rsStavke As New ADODB.Recordset

    Dim sqlStavke As String
    Dim sqlArtikal As String

    Dim IDCrtez As Long
    Dim KataloskiBroj As String
    Dim NazivArtikla As String
    Dim retValOk As Boolean
    Dim Zalihe As Double
    Dim Rezervisano As Double
    Dim SlobodneZalihe As Double
    Dim rsArtikal As Long
    Set db = CurrentDb

    ' --- 1. Recordset stavki plana ---
    sqlStavke = _
        "SELECT IDPlanStavka, IDPlan, IDCrtezNabavke, SifraArtikla, Zalihe " & _
        "FROM PDM_PlaniranjeStavke " & _
        "WHERE IDPlan = " & pIDPlan

    Set rsStavke = ADO_GetDRST(CNN_CurrentDataBase, sqlStavke, dbOptimistic, adUseClient, adOpenStatic)
    
    If rsStavke.EOF Then
        UpdatePlaniranjeStavke_SifraArtikla_Zalihe = True
        GoTo Exit_Point
    End If

    rsStavke.MoveFirst

    Do While Not rsStavke.EOF

        IDCrtez = rsStavke!IDCrtezNabavke

        ' --- 2. Uzimamo kataloški broj iz PDMCrtezi ---
        KataloskiBroj = Nz(ADO_Lookup(CNN_CurrentDataBase, "KataloskiBroj", "PDMCrtezi", "IDCrtez=" & IDCrtez), "")

        If Len(KataloskiBroj) > 0 Then

            ' --- 3. Tražimo artikal u EXT_R_Artikli ---
            
            rsArtikal = Nz(DLookup("[Sifra Artikla]", "EXT_R_Artikli", "[Kataloski broj] = '" & Replace(KataloskiBroj, "'", "''") & "'"), 0)
            If rsArtikal <> 0 Then
                NazivArtikla = Nz(DLookup("Naziv", "EXT_R_Artikli", "[Sifra artikla] = " & stR(rsArtikal)), "-")
                retValOk = ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "SifraArtikla", rsArtikal, "IDPlanStavka=" & CStr(rsStavke!IDPlanStavka))
                retValOk = ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "KataloskiBrojStavke", ADO_SQLValue(KataloskiBroj), "IDPlanStavka=" & CStr(rsStavke!IDPlanStavka))
                retValOk = ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "NazivArtiklaStavke", ADO_SQLValue(NazivArtikla), "IDPlanStavka=" & CStr(rsStavke!IDPlanStavka))
                
                Zalihe = Nz(DLookup("PlusMinusKolicina", "BB_StanjeKolicinaNaDan", "[Sifra artikla] = " & stR(rsArtikal)), 0)
                Rezervisano = Nz(DLookup("RezervisanaKolicina", "BB_RezervisaneKolicine", "[Sifra artikla] = " & stR(rsArtikal)), 0)
                SlobodneZalihe = Zalihe - Rezervisano
                If SlobodneZalihe >= 0 Then
                    retValOk = ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "Zalihe", SlobodneZalihe, "IDPlanStavka=" & CStr(rsStavke!IDPlanStavka))
                End If
            End If
        Else
            retValOk = ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "Zalihe", 0, "IDPlanStavka=" & CStr(rsStavke!IDPlanStavka))
        End If

        rsStavke.MoveNext
    Loop

    UpdatePlaniranjeStavke_SifraArtikla_Zalihe = True

Exit_Point:
    On Error Resume Next
    rsStavke.Close
    Set rsStavke = Nothing
    Set db = Nothing
    Exit Function

Err_Handler:
    BBErrorMSG err, "UpdatePlaniranjeStavke_SifraArtikla_Zalihe"
    UpdatePlaniranjeStavke_SifraArtikla_Zalihe = False
    Resume Exit_Point
End Function
Public Function UpisiPotpisAkoJePrazan(ByVal pIDPlan As Long) As Boolean

On Error GoTo Err_Point

    Dim retValOk As Boolean
    Dim stUser As String

    stUser = Replace(CurrentUser(), "'", "''")

    retValOk = ADO_UpdateColumn( _
        CNN_CurrentDataBase, _
        "PDM_Planiranje", _
        "Potpis", _
        "'" & stUser & "'", _
        "IDPlan = " & pIDPlan & " AND (Potpis IS NULL OR Potpis = '')")

    UpisiPotpisAkoJePrazan = retValOk

Exit Function

Err_Point:
    BBErrorMSG err, "UpisiPotpisAkoJePrazan"
    UpisiPotpisAkoJePrazan = False

End Function
Public Function RezervisanjeVecaOdZaliha(ByVal pIDPlan As Long) As Boolean

On Error GoTo Err_Point

Dim rs As DAO.Recordset
Dim sql As String

sql = ""
sql = sql & "SELECT TOP 1 BrojCrteza, Naziv, Rezervisano, Zalihe "
sql = sql & "FROM PDM_PlaniranjeStavke INNER JOIN PDMCrtezi ON PDM_PlaniranjeStavke.IDCrtezNabavke = PDMCrtezi.IDCrtez "
sql = sql & "WHERE IDPlan=" & pIDPlan & " "
sql = sql & "AND Nz(IskljuciNabavku,0)=0 "
sql = sql & "AND Nz(Rezervisano,0) > Nz(Zalihe,0)"

Set rs = CurrentDb.OpenRecordset(sql, dbOpenSnapshot)

If Not rs.EOF Then

    MsgBox "Ne možete rezervisati više nego što ima na zalihama." & vbCrLf & vbCrLf & _
           rs!BrojCrteza & " - " & rs!Naziv & vbCrLf & _
           "Rezervisano: " & rs!Rezervisano & vbCrLf & _
           "Zalihe: " & rs!Zalihe, _
           vbExclamation, "Planiranje nabavke"

    RezervisanjeVecaOdZaliha = True
Else
    RezervisanjeVecaOdZaliha = False
End If

rs.Close
Exit Function

Err_Point:
    MsgBox err.Description
End Function
Public Function KreirajNalogMagacinu(Ulaz As Boolean, DatumDok As Variant, _
                                                VrstaDok As String, IDProdavac As Long, _
                                                IDRadniNalog As Long, Level As Byte, _
                                                IDMagacin As Long, Opis As String, _
                                                IDKomitent As Long, NBrDok As String, _
                                                Rezervisi As Boolean, BrojIzjave As String, _
                                                DatumIzjave As Variant, MemoNapomena As Variant, _
                                                Kurs As Double, IDKontaktOsobe As Long, UsloviPlacanja As String, Fco As String, _
                                                NacinOtpreme As String, Optional IDPredmet As Long = 0) As Long
On Error GoTo GreskaKreirajRobniDok
 

    Dim BigBit As DAO.Database
    Dim TabDok As DAO.Recordset
    Dim NoviIDDok, IDMag As Long
    Dim tmp As Variant
    Dim BrojDokumenta As String
    
    
    Set BigBit = CurrentDb
    Set TabDok = BigBit.OpenRecordset("Profakture", DB_OPEN_DYNASET)
    
    
    TabDok.AddNew                                'Dodaj novi rekord
    TabDok![Ulaz] = Ulaz
    TabDok![Broj naloga] = ObrniDatum(DatumDok)
    TabDok![Vrsta naloga] = VrstaDok
    
    'BrojDokumenta = 1 + NullToZero(DLookup("[CountOfIDDok]", "BrojDokumenataPoVrstama", "[Vrsta dokumenta] = '" & VrstaDok & "'"))
    'BrojDokumenta = DoChLeft(BrojDokumenta, 4, "0")
    'TabDok![Broj dokumenta] = BrojDokumenta
    
    TabDok![Broj dokumenta] = NBrDok
    TabDok![Vrsta dokumenta] = VrstaDok
    TabDok![Sifra komitenta] = IDKomitent 'DLookup("[Sifra]", "Komitenti", "[Vrsta sifre] = 'MATSIF'")
    TabDok![Datum dokumenta] = DatumDok
    TabDok![Datum knjizenja] = DatumDok
    TabDok![Datum valute] = DatumDok
    TabDok![Opis] = Opis
    TabDok![Sifra prodavca] = IDProdavac
    TabDok![IDRadniNalog] = IDRadniNalog
    TabDok![Level] = Level
    TabDok![IDMagacinDOK] = IDMagacin
    TabDok![Rezervisi] = Rezervisi
    TabDok![Broj izjave] = BrojIzjave
    TabDok![Datum izjave] = DatumIzjave
    TabDok![Memo] = MemoNapomena
    TabDok![Kurs] = Kurs
    TabDok![Potpis] = CurrentUser()
    TabDok![IDKontaktOsobe] = IDKontaktOsobe
    TabDok![UsloviPlacanja] = UsloviPlacanja
    TabDok![Fco] = Fco
    TabDok![Nacin otpreme] = NacinOtpreme
    TabDok![IDPredmet] = IDPredmet
    
    NoviIDDok = TabDok![IDDok]
    TabDok.Update                    'Sacuvaj izmene


ExitKreirajRobniDok:
TabDok.Close
Set TabDok = Nothing
BigBit.Close
Set BigBit = Nothing

KreirajNalogMagacinu = NoviIDDok

Exit Function

GreskaKreirajRobniDok:
 MsgBox Error$
 NoviIDDok = 0
 Resume Next

End Function
Public Function DodajStavkeUNalogMagacinu(ByVal NoviIDDok As Long, qdefst As String, ZaIDPlan As Long, Optional ProveraZaliha As Boolean = True) As Boolean
On Error GoTo GreskaDodajStavkeURobniDok

    Dim BigBit As DAO.Database
    Dim TabStav As DAO.Recordset
    Dim QNoviStav As DAO.QueryDef
    Dim NoviStav As DAO.Recordset
    Dim BrojStavki As Integer
    Dim Greska As Boolean
    Dim Poruka As String
    Dim IDMagacinIzDok As Long
    'Dim RetValOk As Boolean
    
    Greska = False
    
    IDMagacinIzDok = DLookup("[IDMagacinDok]", "EXT_T_Robna dokumenta", "IDDok = " & NoviIDDok)
    
    Set BigBit = CurrentDb
    Set TabStav = BigBit.OpenRecordset("EXT_T_Robne stavke", DB_OPEN_DYNASET, dbSeeChanges)
    Set QNoviStav = BigBit.QueryDefs(qdefst)
    QNoviStav.Parameters("[ZaIDPlan]") = ZaIDPlan
    'QNoviStav.Parameters("[ZaDobraKolicina]") = CStr(IIf(ProveraZaliha, "-1", "*"))
    
    Set NoviStav = QNoviStav.OpenRecordset()
    
NoviStav.MoveFirst
BrojStavki = 0
Do Until NoviStav.EOF
   TabStav.AddNew                                'Dodaj novi rekord
   TabStav![IDDok] = NoviIDDok
   TabStav![Sifra artikla] = NoviStav![SifraArtikla]
   TabStav![Kolicina] = NoviStav![Rezervisano]
   TabStav![Nabavna cena - neto] = NoviStav![ProsecnaNC]
   TabStav![Zavisni trosak - sopstveni] = 0
   TabStav![Zavisni trosak - dobavljac] = 0
   TabStav![Kalkulativna VP cena] = NoviStav![ProsecnaVPC]
   TabStav![Kalkulativna MP cena] = Round(NoviStav![ProsecnaVPC] * (1 + NoviStav!PDVStopa / 100), 2)
   TabStav![Stvarna VP cena] = NoviStav![ProsecnaVPC]
   TabStav![Stvarna MP cena] = Round(NoviStav![ProsecnaVPC] * (1 + NoviStav!PDVStopa / 100), 2)
   TabStav![TAKSA] = 0
   TabStav![RabatProc] = 0
   TabStav![KasaProc] = 0
   TabStav![Odlozeno] = 0
   TabStav![Obracunat porez na ulazu - roba] = True
   TabStav![Tarifa - roba - ulaz] = NoviStav![TarifaRoba]
   TabStav![Obracunat porez na usluge] = False
   TabStav![Tarifa - usluge - izlaz] = "0"
   TabStav![Obracunat  porez na robu] = True
   TabStav![Tarifa - roba - Izlaz] = NoviStav![TarifaRoba]
   TabStav![IDMagacin] = IDMagacinIzDok

   TabStav.Update 'Sacuvaj izmene
   BrojStavki = BrojStavki + 1
   NoviStav.MoveNext
Loop
exit_GreskaDodajStavkeURobniDok:

    On Error Resume Next
    NoviStav.Close
    Set NoviStav = Nothing
    TabStav.Close
    Set TabStav = Nothing
    Set QNoviStav = Nothing
    BigBit.Close
    Set BigBit = Nothing
    If Greska Then
      Poruka = "Procedura DodajStavkeUNalogMagacinu se završava sa greškom!" & vbCrLf
    Else
      Poruka = ""
    End If
    Poruka = Poruka & "Broj stavki dodatih u dokument = " & BrojStavki & "."
    ' MsgBox Poruka, vbInformation, "BigBit"
  DodajStavkeUNalogMagacinu = Not Greska
Exit Function

GreskaDodajStavkeURobniDok:
 MsgBox Error$
 Greska = True
 Resume exit_GreskaDodajStavkeURobniDok

End Function


Public Function BBIDProdavacZaCurrentUser() As Long
On Error GoTo Err_Point
    Dim pID As Variant
    
    pID = Nz(DLookup("[Sifra prodavca]", "EXT_Prodavci", "[LogAcc] = '" & CurrentUser & "'"), 0)
    BBIDProdavacZaCurrentUser = pID
    
Exit_Point:
 On Error Resume Next
 BBIDProdavacZaCurrentUser = pID
Exit Function

Err_Point:
    BBErrorMSG err, "BBIDProdavacZaCurrentUser"
    pID = -1
    Resume Exit_Point
End Function

Public Function KreirajZahtevZaNabavkuIzPlana(ByVal IDPlan As Long, ByVal IDPredmet As Long, Optional BrojPlana As String = "") As Boolean
On Error GoTo Err_Point

    Dim db As DAO.Database
    Dim sql As String
    Dim IDZahteva As Long
    Dim Opis As String
    
    Opis = "Broj plana - " & BrojPlana
    Set db = CurrentDb

    ' =====================================
    ' 1. ZAGLAVLJE
    ' =====================================
    sql = ""
    sql = sql & "INSERT INTO EXT_ZahteviZaNabavku ("
    sql = sql & " IDFirma, OJ, OD, Godina, "
    sql = sql & " DatumZahteva, "
    sql = sql & " InicijatorZahteva, "
    sql = sql & " IDPredmetDok, "
    sql = sql & " BrojZahteva, "
    sql = sql & " Opis, "
    sql = sql & " IDStatus, "
    sql = sql & " Napomena, "
    sql = sql & " DatumIVreme "
    sql = sql & ") VALUES ("
    sql = sql & " 0, 0, 0, " & Year(Date) & ", "
    sql = sql & " #" & Format(Date, "yyyy-mm-dd") & "#, "
    sql = sql & " IDRadnikZaCurrentUser(), "
    sql = sql & IDPredmet & ", "
    sql = sql & " '" & OdrediSledeciBrojZahtevaUBB() & "', "
    sql = sql & " '" & Opis & "', "
    sql = sql & " 0, "
    sql = sql & " 'Automatski kreirano iz MRP plana " & IDPlan & "', "
    sql = sql & " Now() "
    sql = sql & ")"

    db.Execute sql, dbFailOnError

    IDZahteva = db.OpenRecordset("SELECT @@IDENTITY")(0)

    ' =====================================
    ' 2. STAVKE (TVOJ ISPRAVLJEN QUERY)
    ' =====================================
    sql = ""
    sql = sql & "INSERT INTO EXT_SpecifikacijaZahtevaNabavke ("
    sql = sql & " IDZahtevaZaNabavku, "
    sql = sql & " [Sifra artikla], "
    sql = sql & " ZahtevanaKolicina, "
    sql = sql & " [Kataloski brojStavke], "
    sql = sql & " OpisStavke, "
    sql = sql & " [Jedinica mereStavke], "
    sql = sql & " [SifraDobavljaca], "
    sql = sql & " DatIVreme, "
    sql = sql & " IDPredmet, "
    sql = sql & " KreirajUpit, "
    sql = sql & " IDPlanStavka "
    sql = sql & ") "

    sql = sql & "SELECT "
    sql = sql & IDZahteva & ", "
    sql = sql & " Nz(SifraArtikla,0), "
    sql = sql & " ZaNabavku, "
    sql = sql & " IIF(Nz(KataloskiBrojStavke,'')='', '-', KataloskiBrojStavke), "
    sql = sql & " IIF(Nz(NazivArtiklaStavke,'')='', '-', NazivArtiklaStavke), "
    sql = sql & " IIF(Nz(JMStavke,'')='', '-', JMStavke), "
    sql = sql & " Nz(DobavljacID,0), "
    sql = sql & " Now(), "
    sql = sql & IDPredmet & ", "
    sql = sql & " True, "
    sql = sql & " IDPlanStavka "
    sql = sql & "FROM PDM_PlaniranjeStavke "
    sql = sql & "WHERE IDPlan = " & IDPlan & " "
    sql = sql & "AND ZaNabavku > 0"

    db.Execute sql, dbFailOnError + dbSeeChanges

    ' =====================================
    ' 3. OZNAÈI KAO REALIZOVANO
    ' =====================================
    'sql = ""
    'sql = sql & "UPDATE PDM_PlaniranjeStavke "
    'sql = sql & "SET ZaNabavku = 0 "
    'sql = sql & "WHERE IDPlan = " & IDPlan

    'db.Execute sql, dbFailOnError

    MsgBox "Zahtev za nabavku je uspešno kreiran.", vbInformation

    KreirajZahtevZaNabavkuIzPlana = True

Exit_Point:
    Set db = Nothing
    Exit Function

Err_Point:
    MsgBox "Greška: " & err.Description, vbCritical
    KreirajZahtevZaNabavkuIzPlana = False
    Resume Exit_Point

End Function
Public Function OdrediSledeciBrojZahtevaUBB(Optional ByVal YearParam As Variant) As String
    On Error GoTo ErrHandler

    Dim db        As DAO.Database
    Dim rst       As DAO.Recordset
    Dim sql       As String
    Dim yearValue As String
    Dim maxNum    As Long
    Dim nextNum   As Long

    ' 1) Godina iz parametra ili tekuca godina
    If IsMissing(YearParam) Or IsNull(YearParam) Then
        yearValue = CStr(Year(Date))
    Else
        yearValue = CStr(YearParam)
    End If

    Set db = CurrentDb

    ' 2) SQL: uzmi najveæi Seq dio (pre slash) za tu godinu
    sql = _
      "SELECT TOP 1 " & _
      "  Val(Left([BrojZahteva], InStr([BrojZahteva],'/')-1)) AS Seq " & _
      "FROM EXT_ZahteviZaNabavku " & _
      "WHERE Right([BrojZahteva],4) = '" & yearValue & "' " & _
      "ORDER BY Val(Left([BrojZahteva], InStr([BrojZahteva],'/')-1)) DESC;"

    Set rst = db.OpenRecordset(sql, dbOpenSnapshot)

    If rst.EOF Then
        maxNum = 0
    Else
        maxNum = Nz(rst!seq, 0)
    End If

    rst.Close
    Set rst = Nothing
    Set db = Nothing

    ' 3) Sledeci broj je max+1, formatiraj na 4 cifre
    nextNum = maxNum + 1
    OdrediSledeciBrojZahtevaUBB = Format(nextNum, "0000") & "/" & yearValue
    Exit Function

ErrHandler:
    MsgBox "Greška u OdrediSledeciBrojZahteva: " & err.Number & " – " & err.Description, vbCritical
    OdrediSledeciBrojZahtevaUBB = ""
End Function


