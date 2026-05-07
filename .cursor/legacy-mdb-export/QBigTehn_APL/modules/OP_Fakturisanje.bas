Attribute VB_Name = "OP_Fakturisanje"
Option Compare Database
Option Explicit
Public Function OP_KreirajRobniDok(Ulaz As Boolean, DatumDok As Variant, DatumValute As Variant, _
                                                VrstaDok As String, IDProdavac As Long, _
                                                BrojDokumenta As String, _
                                                IDRadniNalog As Long, Level As Byte, _
                                                IDMagacin As Long, Opis As String, IDKomitent As Long, IDMestoIsporuke As Long, _
                                                BrojIzjave As String, DatumIzjave As Variant, MemoNapomena As Variant, Kurs As Double, IDRuta As Long, IDVozac As Long) As Long
On Error GoTo GreskaKreirajRobniDok
 

    Dim BigBit As DAO.Database
    Dim TabDok As DAO.Recordset
    Dim NoviIDDok, IDMag As Long
    Dim tmp As Variant
    
    
    Set BigBit = CurrentDb
    Set TabDok = BigBit.OpenRecordset("Robna dokumenta", DB_OPEN_DYNASET, dbSeeChanges)
    
    
TabDok.AddNew                                'Dodaj novi rekord
TabDok![Ulaz] = Ulaz
TabDok![Broj naloga] = ObrniDatum(DatumDok)
TabDok![Vrsta naloga] = VrstaDok


TabDok![Broj dokumenta] = BrojDokumenta
TabDok![Vrsta dokumenta] = VrstaDok
TabDok![Sifra komitenta] = IDKomitent 'DLookup("[Sifra]", "Komitenti", "[Vrsta sifre] = 'MATSIF'")
TabDok![IDMestoIsporuke] = IDMestoIsporuke
TabDok![Datum dokumenta] = DatumDok
TabDok![Datum knjizenja] = DatumDok
TabDok![Datum valute] = DatumValute
TabDok![Opis] = IIf(Opis = "", Null, Opis)
TabDok![Sifra prodavca] = IDProdavac 'DFirst("[Sifra prodavca]", "Prodavci")
TabDok![IDRadniNalog] = IDRadniNalog
TabDok![Level] = Level
TabDok![IDMagacinDOK] = IDMagacin
TabDok![Broj izjave] = BrojIzjave
TabDok![Datum izjave] = DatumIzjave
TabDok![Memo] = MemoNapomena
TabDok![Kurs] = Kurs
TabDok![IDRuta] = IDRuta
TabDok![IDVozac] = IDVozac

NoviIDDok = TabDok![IDDok]
TabDok.Update                    'Sacuvaj izmene

TabDok.Close
Set TabDok = Nothing
BigBit.Close
Set BigBit = Nothing

OP_KreirajRobniDok = NoviIDDok

ExitKreirajRobniDok:
Exit Function

GreskaKreirajRobniDok:
 MsgBox Error$
 Resume Next

End Function
Sub OP_ProknjiziStavkeURobniDok(ZaVrstuDok, ZaVrstuSifre, OdDatumaOtpreme, DoDatumaOtpreme, ZaVozaca, ZaKupca, ZaMISP, PoCenovniku, CeneSaPDV, GeneralniRabatProc, NoviIDDok, IDMagacin)
On Error GoTo GreskaDodajStavkeURobniDok

    Dim BigBit As DAO.Database
    Dim TabStav As DAO.Recordset
    Dim QNoviStav As DAO.QueryDef
    Dim NoviStav As DAO.Recordset
    'Dim IDMag As Variant 'mora variant!
   
    Set BigBit = CurrentDb
    Set TabStav = BigBit.OpenRecordset("Robne stavke", DB_OPEN_DYNASET, dbSeeChanges)
    
    Set QNoviStav = BigBit.QueryDefs("OP_ArtikliiKomitenti_ZaFakturisanje")
    QNoviStav.Parameters("[Forms]![OP_Fakturisanje]![OdDatumaOtpreme]") = OdDatumaOtpreme
    QNoviStav.Parameters("[Forms]![OP_Fakturisanje]![DoDatumaOtpreme]") = DoDatumaOtpreme
    QNoviStav.Parameters("[Forms]![OP_Fakturisanje]![ZaKupca]") = ZaKupca
    QNoviStav.Parameters("[Forms]![OP_Fakturisanje]![ZaVrstuDok]") = ZaVrstuDok
    QNoviStav.Parameters("[Forms]![OP_Fakturisanje]![ZaVrstuSifre]") = ZaVrstuSifre
    'QNoviStav.Parameters("[Forms]![OP_Fakturisanje]![PoCenovniku]") = PoCenovniku
    'QNoviStav.Parameters("[Forms]![OP_Fakturisanje]![CeneSaPDV]") = CeneSaPDV
    QNoviStav.Parameters("[Forms]![OP_Fakturisanje]![ZaVozaca]") = ZaVozaca
    QNoviStav.Parameters("[Forms]![OP_Fakturisanje]![ZaMISP]") = ZaMISP
  '  QNoviStav.Parameters("[Forms]![OP_Fakturisanje]![GeneralniRabatProc]") = GeneralniRabatProc
    
    Set NoviStav = QNoviStav.OpenRecordset()
    
NoviStav.MoveFirst
Do Until NoviStav.EOF
   TabStav.AddNew                                'Dodaj novi rekord
   TabStav![IDDok] = NoviIDDok
   TabStav![Sifra artikla] = NoviStav![IDArtikal]
   TabStav![Kolicina] = NoviStav![KolicinaZaFakturisanje]
   TabStav![Nabavna cena - neto] = NoviStav![NabavnaCena]
   TabStav![Zavisni trosak - sopstveni] = 0
   TabStav![Zavisni trosak - dobavljac] = 0
   TabStav![Kalkulativna VP cena] = NoviStav![VPCena]
   TabStav![Kalkulativna MP cena] = NoviStav![MPCena]
   TabStav![Stvarna VP cena] = NoviStav![VPCena]
   TabStav![Stvarna MP cena] = NoviStav![MPCena]
   TabStav![TAKSA] = NoviStav![TAKSA]
   TabStav![RabatProc] = NoviStav![RabatProc]
   TabStav![KasaProc] = NoviStav![KasaProc]
   TabStav![Odlozeno] = NoviStav![Odlozeno]
   TabStav![Obracunat porez na ulazu - roba] = False
   TabStav![Tarifa - roba - ulaz] = NoviStav![TarifaPoreza]
   TabStav![Obracunat porez na usluge] = False
   TabStav![Tarifa - usluge - izlaz] = "1"
   TabStav![Obracunat  porez na robu] = True
   TabStav![Tarifa - roba - Izlaz] = NoviStav![TarifaPoreza]
   TabStav![IDMagacin] = IDMagacin
   TabStav![KNGCena] = NoviStav![VPCena]


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

GreskaDodajStavkeURobniDok:
 MsgBox Error$
 Resume Next

End Sub
