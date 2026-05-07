Attribute VB_Name = "Proizvodnja"
Option Compare Database   'Use database order for string comparisons
Option Explicit
Private Function OdrediMagacinSirovina() As Long
Dim tmp As Variant

tmp = Nz(Forms![ArtikliKojihNemaNaZalihamaZaProizvodnju]![ZaMagacin], 0)

If tmp <= 0 Then 'Ako nije zadat magacin na formi onda ...
     'Ako ima samo jedan magacin TRPR onda uzmi njega inace pitaj korisnika
 If Nz(DCount("[IDMagacin]", "Magacini", "[VrstaMag] = 'TRPR'"), 0) = 1 Then
     tmp = DLookup("[IDMagacin]", "Magacini", "[VrstaMag] = 'TRPR'")
     tmp = Nz(tmp, 0)
 Else
     tmp = 0
 End If
End If

    If tmp = 0 Then
        tmp = DFirst("[IDMagacin]", "Magacini")
        tmp = Nz(InputBox("Iz kog magacina trebujete sirovine?", , tmp), 0)
        If tmp = 0 Then tmp = DFirst("[IDMagacin]", "Magacini")
    End If
OdrediMagacinSirovina = tmp

End Function
Public Function DodajDokZaProizvodnju() As Long

On Error GoTo GreskaDodajDokZaProizvodnju

    Dim BigBit As DAO.Database
    Dim TabDok As DAO.Recordset
    Dim NoviIDDok, IDMag As Long
    Dim tmp As Variant
    Dim VrstaDokINaloga As String
    Dim stSufix As String
    
    Set BigBit = CurrentDb
    Set TabDok = BigBit.OpenRecordset("T_Robna dokumenta", DB_OPEN_DYNASET, dbSeeChanges)
    
VrstaDokINaloga = Nz(Forms![ArtikliKojihNemaNaZalihamaZaProizvodnju]![TrebovanjeVrstaDok], "TRPR") '"TRPR"
stSufix = "/" & Right(CStr(F_Godina()), 2)

TabDok.AddNew                                'Dodaj novi rekord
TabDok![Ulaz] = False
TabDok![IDFirma] = F_IDFirma()
TabDok![Godina] = F_Godina()
TabDok![Broj naloga] = ObrniDatum(Forms![Ulazna faktura]![Datum dokumenta])   ' "TREB. ZA PROIZ."
TabDok![Vrsta naloga] = VrstaDokINaloga

'TabDok![Broj dokumenta] = "T-" & Forms![Ulazna faktura]![Broj dokumenta]
TabDok![Broj dokumenta] = SledeciBrojDokumenta(VrstaDokINaloga, "T-", stSufix, "CountVrstaDok")

TabDok![Vrsta dokumenta] = VrstaDokINaloga
TabDok![Sifra komitenta] = BBCFG.MaticnaSifra 'DLookup("[Sifra]", "Komitenti", "[Vrsta sifre] = 'MATSIF'")
TabDok![Datum dokumenta] = Forms![Ulazna faktura]![Datum knjizenja]
TabDok![Datum knjizenja] = Forms![Ulazna faktura]![Datum valute]
TabDok![Datum valute] = Forms![Ulazna faktura]![Datum dokumenta]

TabDok![Datum izjave] = Forms![Ulazna faktura]![Datum dokumenta]
TabDok![Broj izjave] = BBCFG.MestoIzdavanjaRacuna

TabDok![Opis] = "Treb. za proiz. uz ID=" & Forms![Ulazna faktura]![IDDok]
TabDok![Sifra prodavca] = DFirst("[Sifra prodavca]", "Prodavci")
TabDok![IDRadniNalog] = Forms![Ulazna faktura]![IDRadniNalog]
TabDok![Level] = Forms![Ulazna faktura]![Level]
TabDok!DevValuta = BBCFG.DevValuta

IDMag = OdrediMagacinSirovina()

TabDok![IDMagacinDOK] = IDMag
'NoviIDDok = TabDok![IDDok]
TabDok.Update                    'Sacuvaj izmene
NoviIDDok = LastIDENTITY()

DodajStavkeUDokZaProizvodnju NoviIDDok, IDMag


ExitDodajDokZaProizvodnju:
 On Error Resume Next
 TabDok.Close
 Set TabDok = Nothing
 BigBit.Close
 Set BigBit = Nothing
 
DodajDokZaProizvodnju = NoviIDDok
Exit Function

GreskaDodajDokZaProizvodnju:
 NoviIDDok = -1
 BBErrorMSG err, "DodajDokZaProizvodnju"
 Resume ExitDodajDokZaProizvodnju

End Function

Public Sub DodajStavkeUDokZaProizvodnju(ByVal NoviIDDok As Long, ByVal IDMag As Long)
On Error GoTo GreskaDodajStavkeUDokZaProizvodnju

    Dim BigBit As DAO.Database
    Dim TabStav As DAO.Recordset
    Dim QNoviStav As DAO.QueryDef
    Dim NoviStav As DAO.Recordset
    'Dim IDMag As Variant 'mora variant!
   
    Set BigBit = CurrentDb
    Set TabStav = BigBit.OpenRecordset("T_Robne stavke", DB_OPEN_DYNASET, dbSeeChanges)
    Set QNoviStav = BigBit.QueryDefs("TrebArtikliZaProizvodnju")
    QNoviStav.Parameters("Forms![Ulazna faktura]![IDDok]") = Forms![Ulazna faktura]![IDDok]
    QNoviStav.Parameters("Forms![Ulazna faktura]![Level]") = Forms![Ulazna faktura]![Level]
    QNoviStav.Parameters("Forms![Ulazna faktura]![Datum dokumenta]") = Forms![Ulazna faktura]![Datum dokumenta]
    'QNoviStav.Parameters("[ZaMagacin]") = IDMag
    QNoviStav.Parameters("Forms![ArtikliKojihNemaNaZalihamaZaProizvodnju]![ZaMagacin]") = IDMag
    
    Set NoviStav = QNoviStav.OpenRecordset()
    
    'Uzima se iz dokumenta
    'IDMag = DLookup("[IDMagacin]", "Magacini", "[VrstaMag] = 'TRPR'")
    'IDMag = Nz(IDMag, 0)
    'If IDMag = 0 Then
    '    IDMag = DFirst("[IDMagacin]", "Magacini")
    '    IDMag = Nz(InputBox("Iz kog magacina trebujete sirovine?", , IDMag), 0)
    '    If IDMag = 0 Then IDMag = DFirst("[IDMagacin]", "Magacini")
    'End If

NoviStav.MoveFirst
Do Until NoviStav.EOF
   TabStav.AddNew                                'Dodaj novi rekord
   TabStav![IDDok] = NoviIDDok
   TabStav![Sifra artikla] = NoviStav![TrebSifraArtikla]
   TabStav![Kolicina] = NoviStav![TrebKolicina]
   TabStav![Nabavna cena - neto] = NoviStav![ProsNabCena]
                                                                'TabStav![Zavisni trosak - sopstveni] = NoviStav![ZavTrosProiz] / 100# * NoviStav![ProsNabCena]
   TabStav![Kalkulativna VP cena] = NoviStav![ProsNabCena]      'TabStav![Kalkulativna VP cena] = NoviStav![ProsKalkVPCena] 'Za diskusiju!
   TabStav![Stvarna VP cena] = NoviStav![ProsNabCena]           'TabStav![stvarna VP cena] = NoviStav![TrebCena]
   TabStav![Obracunat porez na ulazu - roba] = False
   TabStav![Tarifa - roba - ulaz] = NoviStav![Tarifa robe]
   TabStav![Obracunat porez na usluge] = False
   TabStav![Tarifa - usluge - izlaz] = NoviStav![Tarifa usluga]
   TabStav![Obracunat  porez na robu] = False
   TabStav![Tarifa - roba - Izlaz] = NoviStav![Tarifa robe]
   TabStav![IDMagacin] = IDMag
   
   TabStav.Update 'Sacuvaj izmene
   NoviStav.MoveNext
Loop

    NoviStav.Close
    Set NoviStav = Nothing
    TabStav.Close
    Set TabStav = Nothing
    Set QNoviStav = Nothing
    BigBit.Close
    Set BigBit = Nothing
    
    
    
Exit Sub

GreskaDodajStavkeUDokZaProizvodnju:
 MsgBox Error$
 Resume Next

End Sub

Public Function CenaKostanjaGotovogProizvoda(ZaIDArtikal As Long, Optional NaDan As Variant, Optional ZaLevel As Byte, Optional ZaMagacinSirovina = Null) As Double
'Izmena 25-01-2019

On Error GoTo Err_Point
 Const QNameCenaKostanjaGP = "PRZ_CenaKostanjaGP"
 Dim rstDefCenaKostanjaGP As DAO.QueryDef
 Dim rstCenaKostanjaGP As DAO.Recordset
 Dim retVal As Double
 Dim lokalNaDan As Variant
 Dim lokalZaLevel As Byte
 
 If IsMissing(NaDan) Then
    lokalNaDan = Date
 Else
    lokalNaDan = CVDate(Nz(NaDan, Date))
 End If
 
 If IsMissing(ZaLevel) Then
    lokalZaLevel = 0
 Else
    lokalZaLevel = Nz(ZaLevel, 0)
 End If
 
 Set rstDefCenaKostanjaGP = CurrentDb.QueryDefs(QNameCenaKostanjaGP)
 rstDefCenaKostanjaGP.Parameters("ZaIDArtikal") = ZaIDArtikal
 rstDefCenaKostanjaGP.Parameters("ZaLevel") = lokalZaLevel
 rstDefCenaKostanjaGP.Parameters("NaDan") = CVDate(lokalNaDan)
 rstDefCenaKostanjaGP.Parameters("ZaMagacinSirovina") = ZaMagacinSirovina 'Izmena 25-01-2019 na upitu
                                                                          ' Ovaj parametar sada napada Magacini.IDMagacin
                                                                          ' Dok je bio na T_Robne stavke.IDMagacin upit se izvrsavao jako sporo
 
 Set rstCenaKostanjaGP = rstDefCenaKostanjaGP.OpenRecordset(RecordsetTypeEnum.dbOpenDynaset, RecordsetOptionEnum.dbReadOnly) ', LockTypeEnum.dbOptimistic)
 rstCenaKostanjaGP.FindFirst "ZaSifruArtikla=" & ZaIDArtikal
 If rstCenaKostanjaGP.NoMatch Then
    retVal = 0
 Else
    retVal = Nz(rstCenaKostanjaGP("NabCenaGotProiz"), 0)
 End If
Exit_Point:
On Error Resume Next
 rstCenaKostanjaGP.Close
 Set rstCenaKostanjaGP = Nothing
 Set rstDefCenaKostanjaGP = Nothing
 
 CenaKostanjaGotovogProizvoda = retVal
Exit Function

Err_Point:
BBErrorMSG err, "CenaKostanjaGotovogProizvoda"
retVal = 0
Resume Exit_Point
End Function


