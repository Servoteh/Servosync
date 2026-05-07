Attribute VB_Name = "BBKreiranjeDokumenata"
Option Compare Database
Option Explicit
Public Function LastIDENTITY() As Long
Dim rst As DAO.Recordset
With DBEngine(0)(0)
'.Execute "INSERT INTO TABLE1 ([VALUE], IDS) VALUES ('c', 5)"
Set rst = .OpenRecordset("SELECT @@IDENTITY")
End With
'Debug.Print rst.Collect(0)
LastIDENTITY = rst.Collect(0)
' shows 7 the last auto number of the last table updated
Set rst = Nothing
End Function

Public Function KreirajRobniDok(Ulaz As Boolean, DatumDok As Variant, _
                                                VrstaDok As String, IDProdavac As Long, _
                                                IDRadniNalog As Long, Level As Byte, _
                                                IDMagacin As Long, ByVal Opis As String, _
                                                IDKomitent As Long, _
                                                BrojIzjave As String, DatumIzjave As Variant, _
                                                MemoNapomena As Variant, Kurs As Double, _
                                                Optional IDMestoIsporuke As Long = 0, _
                                                Optional DatumValute As Variant = Null, _
                                                Optional IDTrebZaProizvodnju As Long = 0, _
                                                Optional InputBrojDokumenta As String = "", _
                                                Optional DevValuta, _
                                                Optional Fco, _
                                                Optional NacinOtpreme, _
                                                Optional NacinPlacanja, _
                                                Optional IFRobuPrimio, _
                                                Optional IDDokExtBaza, _
                                                Optional IDPredmet As Long = 0 _
                                                ) As Long
'Modifikovano: 09-06-2021

On Error GoTo GreskaKreirajRobniDok
 

    Dim BigBit As DAO.Database
    Dim TabDok As DAO.Recordset
    Dim NoviIDDok, IDMag As Long
    Dim stErrPoruka As String
    Dim BrojDokumenta As String
    
    DatumValute = Nz(DatumValute, DatumDok)
    
    Set BigBit = CurrentDb
    Set TabDok = BigBit.OpenRecordset("T_Robna dokumenta", dbOpenDynaset, dbSeeChanges)
     
    
TabDok.AddNew                                'Dodaj novi rekord
TabDok![Ulaz] = Ulaz
TabDok![Broj naloga] = ObrniDatum(DatumDok)
TabDok![Vrsta naloga] = VrstaDok

'*********************************************
'Dodato: 02.01.2019
'*********************************************
TabDok!Godina = F_Godina()
TabDok!IDFirma = F_IDFirma()
'*********************************************

If InputBrojDokumenta = "" Then
  BrojDokumenta = SledeciBrojDokumenta(VrstaDok)
Else
  BrojDokumenta = InputBrojDokumenta
End If

TabDok![Broj dokumenta] = Left(BrojDokumenta, TabDok![Broj dokumenta].Size)
TabDok![Vrsta dokumenta] = VrstaDok
TabDok![Sifra komitenta] = IDKomitent 'DLookup("[Sifra]", "Komitenti", "[Vrsta sifre] = 'MATSIF'")
TabDok![Datum dokumenta] = DatumDok
TabDok![Datum knjizenja] = DatumDok
If IsMissing(DatumValute) Then
  TabDok![Datum valute] = DatumDok
Else
  TabDok![Datum valute] = DatumValute
End If
TabDok!IDMestoIsporuke = IDMestoIsporuke
TabDok![Opis] = Left(Opis, TabDok![Opis].Size)
TabDok![Sifra prodavca] = IDProdavac 'DFirst("[Sifra prodavca]", "Prodavci")
TabDok![IDRadniNalog] = IDRadniNalog
TabDok![Level] = Level
TabDok![IDMagacinDOK] = IDMagacin
TabDok![Broj izjave] = BrojIzjave
TabDok![Datum izjave] = DatumIzjave
TabDok![Memo] = MemoNapomena
TabDok![Kurs] = Kurs
TabDok![IDPredmet] = CLng(IDPredmet)

If Not IsMissing(DevValuta) Then
    TabDok![DevValuta] = DevValuta
Else
    TabDok![DevValuta] = BBCFG.DevValuta()
End If

TabDok![IDTrebZaProizvodnju] = IDTrebZaProizvodnju

If Not IsMissing(Fco) Then
    TabDok![Fco] = Fco
End If

If Not IsMissing(NacinOtpreme) Then
    TabDok![Nacin otpreme] = NacinOtpreme
End If

If Not IsMissing(NacinPlacanja) Then
    TabDok![Nacin placanja] = NacinPlacanja
End If

'Ovo polje ne postoji u svim bazama!
'Postoji u BleuLine
'If Not IsMissing(IFRobuPrimio) Then
'    TabDok![IFRobuPrimio] = IFRobuPrimio
'End If
If Not IsMissing(IDDokExtBaza) Then
    TabDok![IDDokExtBaza] = IDDokExtBaza
End If

'Modifikovano: 09-06-2021
ProbajDaSacuvas:

On Error Resume Next
TabDok.Update                    'Sacuvaj izmene
If err.Number <> 0 Then
  stErrPoruka = "Ne može da se kreira robni dokument: " & vbCrLf & vbCrLf
  stErrPoruka = stErrPoruka & "[IDFirma] = " & TabDok![IDFirma] & vbCrLf
  stErrPoruka = stErrPoruka & "[Godina] = " & TabDok![Godina] & vbCrLf
  stErrPoruka = stErrPoruka & "[Broj dokumenta] = " & TabDok![Broj dokumenta] & vbCrLf
  stErrPoruka = stErrPoruka & "[Vrsta dokumenta] = " & TabDok![Vrsta dokumenta] & vbCrLf
  stErrPoruka = stErrPoruka & "[Sifra komitenta] = " & TabDok![Sifra komitenta] & vbCrLf
  stErrPoruka = stErrPoruka & "[Level] = " & TabDok![Level] & vbCrLf
  'MsgBox stErrPoruka, vbExclamation, "QBigTeh"
  stErrPoruka = stErrPoruka & vbCrLf
  stErrPoruka = stErrPoruka & "Da li želite da pokušam sa nekim drugim brojem dokumenta?"
  If BBPitanje(stErrPoruka) Then
     BrojDokumenta = InputBox("Broj dokumenta", "QBigTeh", BrojDokumenta)
     If Nz(BrojDokumenta, "") = "" Then
        NoviIDDok = -1
        GoTo ExitKreirajRobniDok
     End If
     TabDok![Broj dokumenta] = Left(BrojDokumenta, TabDok![Broj dokumenta].Size)
     GoTo ProbajDaSacuvas
  Else
   NoviIDDok = -1
  End If
Else
  NoviIDDok = LastIDENTITY()
End If

ExitKreirajRobniDok:
On Error Resume Next
TabDok.Close
Set TabDok = Nothing

BigBit.Close
Set BigBit = Nothing

KreirajRobniDok = NoviIDDok
Exit Function

GreskaKreirajRobniDok:
 NoviIDDok = -1
  MsgBox "Err: " & err.Number & vbCrLf & err.Description, vbCritical, "BigBit (KreirajRobniDok)"
 Resume ExitKreirajRobniDok

End Function
Sub DodajStavkeURobniDok(ByVal NoviIDDok As Long, qdefst As String, ZaIDDok As Long, StvarnaJeKL As Boolean)
On Error GoTo GreskaDodajStavkeURobniDok

    Dim BigBit As DAO.Database
    Dim TabStav As DAO.Recordset
    Dim QNoviStav As DAO.QueryDef
    Dim NoviStav As DAO.Recordset
    'Dim IDMag As Variant 'mora variant!
   
    Set BigBit = CurrentDb
    Set TabStav = BigBit.OpenRecordset("T_Robne stavke", DB_OPEN_DYNASET, dbSeeChanges)
    Set QNoviStav = BigBit.QueryDefs(qdefst)
    QNoviStav.Parameters("[ZaIDDok]") = ZaIDDok
    
    Set NoviStav = QNoviStav.OpenRecordset(dbReadOnly, dbSeeChanges)
    
NoviStav.MoveFirst
Do Until NoviStav.EOF
   TabStav.AddNew                                'Dodaj novi rekord
   TabStav![IDDok] = NoviIDDok
   TabStav![Sifra artikla] = NoviStav![Sifra artikla]
   TabStav![Kolicina] = NoviStav![Kolicina]
   TabStav![Nabavna cena - neto] = NoviStav![Nabavna cena - neto]
   TabStav![Zavisni trosak - sopstveni] = NoviStav![Zavisni trosak - sopstveni]
   TabStav![Zavisni trosak - dobavljac] = NoviStav![Zavisni trosak - dobavljac]
   TabStav![Kalkulativna VP cena] = NoviStav![Kalkulativna VP cena]
   TabStav![Kalkulativna MP cena] = NoviStav![Kalkulativna MP cena]
   If StvarnaJeKL Then
    TabStav![Stvarna VP cena] = NoviStav![Kalkulativna VP cena]
    TabStav![Stvarna MP cena] = NoviStav![Kalkulativna MP cena]
   Else
    TabStav![Stvarna VP cena] = NoviStav![Stvarna VP cena]
    TabStav![Stvarna MP cena] = NoviStav![Stvarna MP cena]
   End If
   TabStav![TAKSA] = NoviStav![TAKSA]
   TabStav![RabatProc] = NoviStav![RabatProc]
   TabStav![KasaProc] = NoviStav![KasaProc]
   TabStav![Odlozeno] = NoviStav![Odlozeno]
   TabStav![Obracunat porez na ulazu - roba] = NoviStav![Obracunat porez na ulazu - roba]
   TabStav![Tarifa - roba - ulaz] = NoviStav![Tarifa - roba - ulaz]
   TabStav![Obracunat porez na usluge] = NoviStav![Obracunat porez na usluge]
   TabStav![Tarifa - usluge - izlaz] = NoviStav![Tarifa - usluge - izlaz]
   TabStav![Obracunat  porez na robu] = NoviStav![Obracunat  porez na robu]
   TabStav![Tarifa - roba - Izlaz] = NoviStav![Tarifa - roba - Izlaz]
   TabStav![IDMagacin] = NoviStav![IDMagacin]
   TabStav![KNGCena] = NoviStav![KNGCena]


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

Public Function KreirajProfakturaDok(Ulaz As Boolean, DatumDok As Variant, _
                                                VrstaDok As String, IDProdavac As Long, _
                                                IDRadniNalog As Long, Level As Byte, _
                                                IDMagacin As Long, Opis As String, _
                                                IDKomitent As Long, NBrDok As String, _
                                                Rezervisi As Boolean, BrojIzjave As String, _
                                                DatumIzjave As Variant, MemoNapomena As Variant, Kurs As Double) As Long
On Error GoTo GreskaKreirajRobniDok
 

    Dim BigBit As DAO.Database
    Dim TabDok As DAO.Recordset
    Dim NoviIDDok, IDMag As Long
    Dim tmp As Variant
    Dim BrojDokumenta As String
    
    
    Set BigBit = CurrentDb
    Set TabDok = BigBit.OpenRecordset("Profakture", DB_OPEN_DYNASET, dbSeeChanges)
    
    
TabDok.AddNew                                'Dodaj novi rekord
TabDok![Ulaz] = Ulaz
TabDok![Broj naloga] = ObrniDatum(DatumDok)
TabDok![Vrsta naloga] = VrstaDok

'*********************************************
'Dodato: 02.01.2019
'*********************************************
TabDok!Godina = F_Godina()
TabDok!IDFirma = F_IDFirma()

'BrojDokumenta = 1 + Nz(DLookup("[CountOfIDDok]", "BrojDokumenataPoVrstama", "[Vrsta dokumenta] = '" & VrstaDok & "'"),0)
'BrojDokumenta = DoChLeft(BrojDokumenta, 4, "0")
'TabDok![Broj dokumenta] = BrojDokumenta

TabDok![Broj dokumenta] = NBrDok
TabDok![Vrsta dokumenta] = VrstaDok
TabDok![Sifra komitenta] = IDKomitent 'DLookup("[Sifra]", "Komitenti", "[Vrsta sifre] = 'MATSIF'")
TabDok![Datum dokumenta] = DatumDok
TabDok![Datum knjizenja] = DatumDok
TabDok![Datum valute] = DatumDok
TabDok![Opis] = Left(Nz(Opis, ""), TabDok![Opis].Size)
TabDok![Sifra prodavca] = IDProdavac 'DFirst("[Sifra prodavca]", "Prodavci")
TabDok![IDRadniNalog] = IDRadniNalog
TabDok![Level] = Level
TabDok![IDMagacinDOK] = IDMagacin
TabDok![Rezervisi] = Rezervisi
TabDok![Broj izjave] = BrojIzjave
TabDok![Datum izjave] = DatumIzjave
TabDok![Memo] = MemoNapomena
TabDok![Kurs] = Kurs
TabDok![DevValuta] = BBCFG.DevValuta

'NoviIDDok = TabDok![IDDok]
TabDok.Update                    'Sacuvaj izmene
 NoviIDDok = LastIDENTITY()
 
TabDok.Close
Set TabDok = Nothing
BigBit.Close
Set BigBit = Nothing

KreirajProfakturaDok = NoviIDDok

ExitKreirajRobniDok:
Exit Function

GreskaKreirajRobniDok:
 MsgBox Error$
 Resume Next

End Function
Sub DodajStavkeUProfakturaStavke(ByVal NoviIDDok As Long, qdefst As String, ZaIDDok As Long)
On Error GoTo GreskaDodajStavkeURobniDok

    Dim BigBit As DAO.Database
    Dim TabStav As DAO.Recordset
    Dim QNoviStav As DAO.QueryDef
    Dim NoviStav As DAO.Recordset
    'Dim IDMag As Variant 'mora variant!
   
    Set BigBit = CurrentDb
    Set TabStav = BigBit.OpenRecordset("Profakture stavke", DB_OPEN_DYNASET, dbSeeChanges)
    Set QNoviStav = BigBit.QueryDefs(qdefst)
    QNoviStav.Parameters("[ZaIDDok]") = ZaIDDok
    
    Set NoviStav = QNoviStav.OpenRecordset(dbOpenDynaset, dbSeeChanges)
    NoviStav.Sort = "IDStavke"
    
NoviStav.MoveFirst
Do Until NoviStav.EOF
   TabStav.AddNew                                'Dodaj novi rekord
   TabStav![IDDok] = NoviIDDok
   TabStav![Sifra artikla] = NoviStav![Sifra artikla]
   TabStav![Kolicina] = NoviStav![Kolicina]
   TabStav![Nabavna cena - neto] = NoviStav![Nabavna cena - neto]
   TabStav![Zavisni trosak - sopstveni] = NoviStav![Zavisni trosak - sopstveni]
   TabStav![Zavisni trosak - dobavljac] = NoviStav![Zavisni trosak - dobavljac]
   TabStav![Kalkulativna VP cena] = NoviStav![Kalkulativna VP cena]
   TabStav![Kalkulativna MP cena] = NoviStav![Kalkulativna MP cena]
   TabStav![Stvarna VP cena] = NoviStav![Stvarna VP cena]
   TabStav![Stvarna MP cena] = NoviStav![Stvarna MP cena]
   TabStav![TAKSA] = NoviStav![TAKSA]
   TabStav![RabatProc] = NoviStav![RabatProc]
   TabStav![KasaProc] = NoviStav![KasaProc]
   TabStav![Odlozeno] = NoviStav![Odlozeno]
   TabStav![Obracunat porez na ulazu - roba] = NoviStav![Obracunat porez na ulazu - roba]
   TabStav![Tarifa - roba - ulaz] = NoviStav![Tarifa - roba - ulaz]
   TabStav![Obracunat porez na usluge] = NoviStav![Obracunat porez na usluge]
   TabStav![Tarifa - usluge - izlaz] = NoviStav![Tarifa - usluge - izlaz]
   TabStav![Obracunat  porez na robu] = NoviStav![Obracunat  porez na robu]
   TabStav![Tarifa - roba - Izlaz] = NoviStav![Tarifa - roba - Izlaz]
   TabStav![IDMagacin] = NoviStav![IDMagacin]
   TabStav![KNGCena] = NoviStav![KNGCena]

   TabStav.Update 'Sacuvaj izmene
   NoviStav.MoveNext
Loop

Exit_Sub:
On Error Resume Next

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
 Resume Exit_Sub

End Sub

Public Function KreirajUslugaDok(DatumDok As Variant, _
                                  VrstaDok As String, IDProdavac As Long, _
                                  IDRadniNalog As Long, Level As Byte, _
                                  IDMagacin As Long, IDKomitent As Long, _
                                  BrojIzjave As String, DatumIzjave As Variant, _
                                  MemoNapomena As Variant, _
                                  Kurs As Double, _
                                  IDDokIF As Long, _
                                  DatumValute As Variant _
                                  ) As Long
'Modifikovano: 22-04-2023
'Modifikovano: 25-12-2023
On Error GoTo GreskaKreirajUslugaDok
 

    Dim BigBit As DAO.Database
    Dim TabDok As DAO.Recordset
    Dim NoviIDDok As Long
    Dim tmp As Variant
    Dim BrojDokumenta As String
    
    
    Set BigBit = CurrentDb
    Set TabDok = BigBit.OpenRecordset("Usluge dokumenta", DB_OPEN_DYNASET, dbSeeChanges)
    
    
TabDok.AddNew                                'Dodaj novi rekord
TabDok![Broj naloga] = ObrniDatum(DatumDok)
TabDok![Vrsta naloga] = VrstaDok

'*********************************************
'Dodato: 02.01.2019
'*********************************************
TabDok!Godina = F_Godina()
TabDok!IDFirma = F_IDFirma()
'*********************************************

'BrojDokumenta = 1 + Nz(DLookup("[CountOfIDDok]", "BrojDokumenataPoVrstama_USLUGE", "[Vrsta dokumenta] = '" & VrstaDok & "'"),0)
'BrojDokumenta = DoChLeft(BrojDokumenta, 4, "0")
 BrojDokumenta = SledeciBrojDokumentaUsluga(VrstaDok, , , , , Level)

TabDok![Broj dokumenta] = BrojDokumenta
TabDok![Vrsta dokumenta] = VrstaDok
TabDok![Sifra komitenta] = IDKomitent 'DLookup("[Sifra]", "Komitenti", "[Vrsta sifre] = 'MATSIF'")
TabDok![Datum dokumenta] = DatumDok
TabDok![Datum knjizenja] = DatumDok
TabDok![Datum valute] = DatumValute '<= 22-04-2023
'TabDok![Opis] = Opis
TabDok![Sifra prodavca] = IDProdavac 'DFirst("[Sifra prodavca]", "Prodavci")
TabDok![IDRadniNalog] = IDRadniNalog
TabDok![Level] = Level
If Level = 250 Then TabDok![TekstZaFakturu] = "Profaktura"
'TabDok![Broj izjave] = BrojIzjave
'TabDok![Datum izjave] = DatumIzjave
If Nz(MemoNapomena, "") <> "" Then TabDok![Napomena] = MemoNapomena

TabDok![IDDokIF] = IDDokIF
TabDok![DevValuta] = BBCFG.DevValuta

TabDok![MestoPrometa] = F_MestoIzdavanjaRacuna()
TabDok![DatumPrometa] = DatumDok

TabDok.Update                    'Sacuvaj izmene

'NoviIDDok = TabDok![IDDok]
NoviIDDok = LastIDENTITY

ExitKreirajUslugaDok:
On Error Resume Next
 TabDok.Close
 Set TabDok = Nothing
 BigBit.Close
 Set BigBit = Nothing

 KreirajUslugaDok = NoviIDDok

Exit Function

GreskaKreirajUslugaDok:
 MsgBox Error$
 NoviIDDok = -1
 Resume ExitKreirajUslugaDok

End Function

Public Function DodajStavkuUUslugaDok(ByVal NoviIDDok As Long, OpisStavke As String, JM As String, ByVal Cena As Double, Kolicina As Double, TarifaPor As String, ObrPDV As Boolean) As Boolean
'Modifikovano: 30-01-2023
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim BigBit As DAO.Database
    Dim TabStav As DAO.Recordset
    
retValOk = True
     
    Set BigBit = CurrentDb
    Set TabStav = BigBit.OpenRecordset("T_Usluge stavke", DB_OPEN_DYNASET, dbSeeChanges)
        
   TabStav.AddNew                                'Dodaj novi rekord
    TabStav![IDDok] = NoviIDDok
    TabStav![Opis] = OpisStavke
    TabStav![Jedinica mere] = JM
    TabStav![Kolicina] = Kolicina
    TabStav![Cena] = Cena
    TabStav![Tarifa usluga] = TarifaPor
    TabStav![Obracunat  porez] = ObrPDV
   
   TabStav.Update 'Sacuvaj izmene

Exit_Point:
 On Error Resume Next
        TabStav.Close
        Set TabStav = Nothing
   
        BigBit.Close
        Set BigBit = Nothing
       
       DodajStavkuUUslugaDok = retValOk

Exit Function

Err_Point:
 BBErrorMSG err, "DodajStavkuUUslugaDok"
 retValOk = False
 Resume Exit_Point

End Function

Public Function KreirajNalogGK(DatumNaloga As Variant, _
                                VrstaNaloga As String, _
                                Level As Byte, _
                                OpisNaloga As Variant) As Long
                                
On Error GoTo GreskaKreirajNalogGK
 

    Dim BigBit As DAO.Database
    Dim TabDok As DAO.Recordset
    Dim NoviIDNalog As Long
    Dim tmp As Variant
    Dim BrojNaloga As String
    
    
    Set BigBit = CurrentDb
    Set TabDok = BigBit.OpenRecordset("Nalozi", DB_OPEN_DYNASET, dbSeeChanges)
    
    
TabDok.AddNew      'Dodaj novi rekord
BrojNaloga = 1 + Nz(DLookup("[CountOfIDNaloga]", "BrojNalogaPoVrstama", "[Vrsta naloga] = '" & VrstaNaloga & "'"), 0)
BrojNaloga = DoChLeft(BrojNaloga, 4, "0")

TabDok![Broj naloga] = BrojNaloga
TabDok![Vrsta naloga] = VrstaNaloga

'*********************************************
'Dodato: 02.01.2019
'*********************************************
TabDok!Godina = F_Godina()
TabDok!IDFirma = F_IDFirma()
'*********************************************

TabDok![Datum naloga] = DatumNaloga
TabDok![Datum knjizenja] = DatumNaloga
TabDok![Opis naloga] = OpisNaloga
TabDok![Level] = Level

NoviIDNalog = TabDok![IDNaloga]
TabDok.Update                    'Sacuvaj izmene

TabDok.Close
Set TabDok = Nothing
BigBit.Close
Set BigBit = Nothing

KreirajNalogGK = NoviIDNalog

ExitKreirajNalogGK:
Exit Function

GreskaKreirajNalogGK:
 MsgBox Error$
 Resume Next

End Function
Public Function KreirajTrebovanjeDok(BrojDokumenta As String, DatumDok As Variant, _
                                      IDKomitent As Long, Kurs As Double, _
                                      Napomena As Variant, Level As Byte, _
                                      IDPredmet As Long, IDTrebVeza As Long, DevValuta As String) As Long
On Error GoTo GreskaKreirajRobniDok
 

    Dim BigBit As DAO.Database
    Dim TabDok As DAO.Recordset
    Dim NoviIDDok
    Dim tmp As Variant
    
    
    Set BigBit = CurrentDb
    Set TabDok = BigBit.OpenRecordset("T_Trebovanja", DB_OPEN_DYNASET, dbSeeChanges)
    
    
TabDok.AddNew                                'Dodaj novi rekord

'*********************************************
'Dodato: 02.01.2019
'*********************************************
TabDok!Godina = F_Godina()
TabDok!IDFirma = F_IDFirma()
'*********************************************

TabDok![Broj trebovanja] = BrojDokumenta
TabDok![Datum trebovanja] = DatumDok
TabDok![Sifra komitenta] = IDKomitent 'DLookup("[Sifra]", "Komitenti", "[Vrsta sifre] = 'MATSIF'")
TabDok![Kurs] = Kurs
TabDok![Level] = Level
TabDok![Napomena] = Napomena
'TabDok![Opis] = Opis
TabDok![DevValuta] = DevValuta
TabDok![IDPredmet] = IDPredmet

TabDok.Update                    'Sacuvaj izmene

'TabDok.MoveLast
'NoviIDDok = TabDok![IDTreb]
 NoviIDDok = DMax("[IDTreb]", "T_Trebovanja")

TabDok.Close
Set TabDok = Nothing
BigBit.Close
Set BigBit = Nothing

KreirajTrebovanjeDok = NoviIDDok

ExitKreirajRobniDok:
Exit Function

GreskaKreirajRobniDok:
 MsgBox Error$
 Resume Next

End Function

Public Sub DodajStavkeUTrebovanje(ByVal NoviIDDok As Long, qdefst As String, ZaIDTreb As Long)
On Error GoTo GreskaDodajStavkeURobniDok

    Dim BigBit As DAO.Database
    Dim TabStav As DAO.Recordset
    Dim QNoviStav As DAO.QueryDef
    Dim NoviStav As DAO.Recordset

   
    Set BigBit = CurrentDb
    Set TabStav = BigBit.OpenRecordset("T_Trebovanja stavke", DB_OPEN_DYNASET, dbSeeChanges)
    Set QNoviStav = BigBit.QueryDefs(qdefst)
    QNoviStav.Parameters("[ZaIDTreb]") = ZaIDTreb
    
    Set NoviStav = QNoviStav.OpenRecordset(RecordsetTypeEnum.dbOpenDynaset, dbSeeChanges)
    
NoviStav.MoveFirst
Do Until NoviStav.EOF
   TabStav.AddNew                                'Dodaj novi rekord
   TabStav![IDTreb] = NoviIDDok
   TabStav![Sifra artikla] = NoviStav![Sifra artikla]
   TabStav![ZaliheKol] = NoviStav![ZaliheKol]
   TabStav![TrebKol] = NoviStav![TrebKol]
   TabStav![IsporucenaKolicina] = NoviStav![IsporucenaKolicina]
   TabStav![Cena] = NoviStav![Cena]
   TabStav![ZaliheKG_Kol] = NoviStav![ZaliheKG_Kol]
   TabStav![UlazKol] = NoviStav![UlazKol]
   TabStav![IzlazKol] = NoviStav![IzlazKol]
   TabStav![Opis] = NoviStav![Opis]
   TabStav![Napomena] = NoviStav![Napomena]
   TabStav![OcekivaniDatumIsporuke] = NoviStav![OcekivaniDatumIsporuke]
   TabStav![DatumIsporuke] = NoviStav![DatumIsporuke]
   
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
Public Function KreirajMPDok(DatumDok As Variant, _
                             VrstaDok As String, IDProdavac As Long, _
                             IDProdavnica As Long, IDKasa As Long, IDKupac As Long, IDRadniNalog As Long, _
                             Level As Byte, Opis As String, Kurs As Double, Optional IDPredmet As Long = 0) As Long
                                               
On Error GoTo GreskaKreirajMPDok
 

    Dim BigBit As DAO.Database
    Dim TabDok As DAO.Recordset
    Dim NoviMPIDDok, IDMag As Long
    Dim tmp As Variant
    Dim BrojDokumenta As String
    
    
    Set BigBit = CurrentDb
    Set TabDok = BigBit.OpenRecordset("MPDokumenta", DB_OPEN_DYNASET, dbSeeChanges)
    
    
TabDok.AddNew                                'Dodaj novi rekord
'*********************************************
'Dodato: 02.01.2019
'*********************************************
TabDok!Godina = F_Godina()
TabDok!IDFirma = F_IDFirma()
'*********************************************
TabDok![IDProdavnica] = IDProdavnica
TabDok![IDKasa] = IDKasa
TabDok![IDKupac] = IDKupac
TabDok![IDRadniNalog] = IDRadniNalog
TabDok![Vrsta dokumenta] = VrstaDok
TabDok![Datum dokumenta] = DatumDok
TabDok![Datum valute] = DatumDok
TabDok![Opis] = Opis
TabDok![Sifra prodavca] = IDProdavac 'DFirst("[Sifra prodavca]", "Prodavci")
TabDok![Opis] = Opis
TabDok![Level] = Level

TabDok![Kurs] = Kurs
NoviMPIDDok = TabDok![IDDok]
BrojDokumenta = IDProdavnica & "/" & NoviMPIDDok
TabDok![Broj dokumenta] = BrojDokumenta
TabDok!IDPredmet = IDPredmet


TabDok.Update                    'Sacuvaj izmene

TabDok.Close
Set TabDok = Nothing
BigBit.Close
Set BigBit = Nothing

KreirajMPDok = NoviMPIDDok

ExitKreirajMPDok:
Exit Function

GreskaKreirajMPDok:
 MsgBox Error$
 Resume Next

End Function
Public Function KreirajPopisDok(DatumDok As Variant, Level As Byte, IDMagacin As Long, _
                                        IDKomitent As Long, Napomena As Variant) As Long
On Error GoTo GreskaKreirajPopisniDok
 

    Dim BigBit As DAO.Database
    Dim TabDok As DAO.Recordset
    Dim NoviIDPopis, IDMag As Long
    Dim tmp As Variant
    Dim BrojDokumenta As String
    
    
    Set BigBit = CurrentDb
    Set TabDok = BigBit.OpenRecordset("Popis zaglavlja", DB_OPEN_DYNASET, dbSeeChanges)
    
    
TabDok.AddNew                                'Dodaj novi rekord

'*********************************************
'Dodato: 02.01.2019
'*********************************************
TabDok!Godina = F_Godina()
TabDok!IDFirma = F_IDFirma()
'*********************************************


TabDok![IDKomitent] = IDKomitent 'DLookup("[Sifra]", "Komitenti", "[Vrsta sifre] = 'MATSIF'")
TabDok![DATUM] = DatumDok
TabDok![Level] = Level
TabDok![IDMagacin] = IDMagacin
TabDok![Napomena] = Napomena

NoviIDPopis = TabDok![IDPopis]
TabDok.Update                    'Sacuvaj izmene

TabDok.Close
Set TabDok = Nothing
BigBit.Close
Set BigBit = Nothing

KreirajPopisDok = NoviIDPopis

ExitKreirajPopisniDok:
Exit Function

GreskaKreirajPopisniDok:
 MsgBox Error$
 Resume Next

End Function
Public Sub DodajStavkeUIFDokSaObracunomKLCena(ByVal NoviIDDok As Long, qdefst As String, ZaIDDok As Long, Optional ProveraZaliha As Boolean = True)
On Error GoTo GreskaDodajStavkeURobniDok

    Dim BigBit As DAO.Database
    Dim TabStav As DAO.Recordset
    Dim QNoviStav As DAO.QueryDef
    Dim NoviStav As DAO.Recordset
    Dim BrojStavki As Integer
    Dim Greska As Boolean
    Dim Poruka As String
    'Dim IDMag As Variant 'mora variant!
    Greska = False
    
    Set BigBit = CurrentDb
    Set TabStav = BigBit.OpenRecordset("T_Robne stavke", DB_OPEN_DYNASET, dbSeeChanges)
    Set QNoviStav = BigBit.QueryDefs(qdefst)
    QNoviStav.Parameters("[ZaIDDok]") = ZaIDDok
    QNoviStav.Parameters("[ZaDobraKolicina]") = CStr(IIf(ProveraZaliha, "-1", "*"))
    
    Set NoviStav = QNoviStav.OpenRecordset()
    
NoviStav.MoveFirst
BrojStavki = 0
Do Until NoviStav.EOF
   TabStav.AddNew                                'Dodaj novi rekord
   TabStav![IDDok] = NoviIDDok
   TabStav![Sifra artikla] = NoviStav![Sifra artikla]
   TabStav![Kolicina] = NoviStav![Kolicina]
   TabStav![Nabavna cena - neto] = NoviStav![ProsecnaNC]
   TabStav![Zavisni trosak - sopstveni] = 0
   TabStav![Zavisni trosak - dobavljac] = 0
   TabStav![Kalkulativna VP cena] = NoviStav![ProsecnaVPC]
   TabStav![Kalkulativna MP cena] = Round(NoviStav![ProsecnaVPC] * (1 + NoviStav!PDVStopa / 100), 2)
   TabStav![Stvarna VP cena] = NoviStav![Stvarna VP cena]
   TabStav![Stvarna MP cena] = NoviStav![Stvarna MP cena]
   TabStav![TAKSA] = NoviStav![TAKSA]
   TabStav![RabatProc] = NoviStav![RabatProc]
   TabStav![KasaProc] = NoviStav![KasaProc]
   TabStav![Odlozeno] = NoviStav![Odlozeno]
   TabStav![Obracunat porez na ulazu - roba] = NoviStav![Obracunat porez na ulazu - roba]
   TabStav![Tarifa - roba - ulaz] = NoviStav![Tarifa - roba - ulaz]
   TabStav![Obracunat porez na usluge] = NoviStav![Obracunat porez na usluge]
   TabStav![Tarifa - usluge - izlaz] = NoviStav![Tarifa - usluge - izlaz]
   TabStav![Obracunat  porez na robu] = NoviStav![Obracunat  porez na robu]
   TabStav![Tarifa - roba - Izlaz] = NoviStav![Tarifa - roba - Izlaz]
   TabStav![IDMagacin] = NoviStav![IDMagacin]

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
      Poruka = "Procedura DodajStavkeUIFDokSaObracunomKLCena se završava sa greškom!" & vbCrLf
    Else
      Poruka = ""
    End If
    Poruka = Poruka & "Broj stavki dodatih u dokument = " & BrojStavki & "."
    ' MsgBox Poruka, vbInformation, "QMegaTeh"
Exit Sub

GreskaDodajStavkeURobniDok:
 MsgBox Error$
 Greska = True
 Resume exit_GreskaDodajStavkeURobniDok

End Sub
'***
Public Function DodajStavkeIzKasaBlokaUIFDokSaObracunomKLCena(ByVal NoviIDDok As Long, qdefst As String, ZaIDDok As Long, ZaIDProdavnica As Long, ZaIDKasa As Long, Optional ProveraZaliha As Boolean = True, Optional ZnakZaKol As Double = 1) As Boolean
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
    
    IDMagacinIzDok = DLookup("[IDMagacinDok]", "T_Robna dokumenta", "IDDok = " & NoviIDDok)
    
    Set BigBit = CurrentDb
    Set TabStav = BigBit.OpenRecordset("T_Robne stavke", DB_OPEN_DYNASET, dbSeeChanges)
    Set QNoviStav = BigBit.QueryDefs(qdefst)
    QNoviStav.Parameters("[ZaIDDok]") = ZaIDDok
    QNoviStav.Parameters("[ZaIDProdavnica]") = ZaIDProdavnica
    QNoviStav.Parameters("[ZaIDKasa]") = ZaIDKasa
    QNoviStav.Parameters("[ZaDobraKolicina]") = CStr(IIf(ProveraZaliha, "-1", "*"))
    
    Set NoviStav = QNoviStav.OpenRecordset()
    
NoviStav.MoveFirst
BrojStavki = 0
Do Until NoviStav.EOF
   TabStav.AddNew                                'Dodaj novi rekord
   TabStav![IDDok] = NoviIDDok
   TabStav![Sifra artikla] = NoviStav![Sifra artikla]
   TabStav![Kolicina] = ZnakZaKol * NoviStav![Kolicina]
   TabStav![Nabavna cena - neto] = NoviStav![ProsecnaNC]
   TabStav![Zavisni trosak - sopstveni] = 0
   TabStav![Zavisni trosak - dobavljac] = 0
   TabStav![Kalkulativna VP cena] = NoviStav![ProsecnaVPC]
   TabStav![Kalkulativna MP cena] = Round(NoviStav![ProsecnaVPC] * (1 + NoviStav!PDVStopa / 100), 2)
   TabStav![Stvarna VP cena] = Round(NoviStav![StvarnaMPCena] * (1 - NoviStav![RabatProc] / 100), 2) / (1 + NoviStav!PDVStopa / 100)
   TabStav![Stvarna MP cena] = Round(NoviStav![StvarnaMPCena] * (1 - NoviStav![RabatProc] / 100), 2)
   TabStav![TAKSA] = 0
   TabStav![RabatProc] = NoviStav![RabatProc]
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
      Poruka = "Procedura DodajStavkeIzKasaBlokaUIFDokSaObracunomKLCena se završava sa greškom!" & vbCrLf
    Else
      Poruka = ""
    End If
    Poruka = Poruka & "Broj stavki dodatih u dokument = " & BrojStavki & "."
    ' MsgBox Poruka, vbInformation, "QMegaTeh"
  DodajStavkeIzKasaBlokaUIFDokSaObracunomKLCena = Not Greska
Exit Function

GreskaDodajStavkeURobniDok:
 MsgBox Error$
 Greska = True
 Resume exit_GreskaDodajStavkeURobniDok

End Function
'***
'***
Public Function DodajStavkeIzTrebovanjaUIFDokSaObracunomKLCena(ByVal NoviIDDok As Long, qdefst As String, ZaIDDok As Long, ProveraZaliha As Boolean, PoCenovniku As String, CeneSaPDV As Boolean) As Boolean
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
    
    IDMagacinIzDok = DLookup("[IDMagacinDok]", "T_Robna dokumenta", "IDDok = " & NoviIDDok)
    
    Set BigBit = CurrentDb
    Set TabStav = BigBit.OpenRecordset("T_Robne stavke", dbOpenDynaset, dbSeeChanges)
    Set QNoviStav = BigBit.QueryDefs(qdefst)
    QNoviStav.Parameters("[ZaIDDok]") = ZaIDDok
    QNoviStav.Parameters("[PoCenovniku]") = PoCenovniku
    'QNoviStav.Parameters("[CeneSaPDV]") = CeneSaPDV
    QNoviStav.Parameters("[ZaDobraKolicina]") = CStr(IIf(ProveraZaliha, "-1", "*"))
    
    Set NoviStav = QNoviStav.OpenRecordset() 'dbOpenDynaset, dbSeeChanges)
    
NoviStav.MoveFirst
BrojStavki = 0
Do Until NoviStav.EOF
   TabStav.AddNew                                'Dodaj novi rekord
   TabStav![IDDok] = NoviIDDok
   TabStav![Sifra artikla] = NoviStav![Sifra artikla]
   TabStav![Kolicina] = NoviStav![Kolicina]
   TabStav![Nabavna cena - neto] = NoviStav![ProsecnaNC]
   TabStav![Zavisni trosak - sopstveni] = 0
   TabStav![Zavisni trosak - dobavljac] = 0
   TabStav![Kalkulativna VP cena] = NoviStav![ProsecnaVPC]
   TabStav![Kalkulativna MP cena] = Round(NoviStav![ProsecnaVPC] * (1 + NoviStav!PDVStopa / 100), 2)
   
   If CeneSaPDV Then
    TabStav![Stvarna VP cena] = NoviStav![CenaIzCenovnika] / (1 + NoviStav!PDVStopa / 100)
    TabStav![Stvarna MP cena] = Round(NoviStav![CenaIzCenovnika], 2)
   Else
    TabStav![Stvarna VP cena] = NoviStav![CenaIzCenovnika]
    TabStav![Stvarna MP cena] = Round(NoviStav![CenaIzCenovnika] * (1 + NoviStav!PDVStopa / 100), 2)
   End If
   
   TabStav![TAKSA] = 0
   TabStav![RabatProc] = NoviStav![RabatProc]
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
      Poruka = "Procedura DodajStavkeIzKasaBlokaUIFDokSaObracunomKLCena se završava sa greškom!" & vbCrLf
    Else
      Poruka = ""
    End If
    Poruka = Poruka & "Broj stavki dodatih u dokument = " & BrojStavki & "."
    ' MsgBox Poruka, vbInformation, "QMegaTeh"
  DodajStavkeIzTrebovanjaUIFDokSaObracunomKLCena = Not Greska
Exit Function

GreskaDodajStavkeURobniDok:
 MsgBox Error$
 Greska = True
 Resume exit_GreskaDodajStavkeURobniDok

End Function
'***
Public Function KreirajRadniNalog(BrojRadnogNaloga As String, Pozicija As String, DatumOtvaranja As Date, IDInvestitor As Long, Napomena As Variant, Optional NazivProizvoda) As Long
On Error GoTo GreskaKreirajRadniNalog
 

    Dim BigBit As DAO.Database
    Dim TabDok As DAO.Recordset
    Dim NoviIDRadniNalog As Long
    Dim tmp As Variant
    Dim BrojDokumenta As String
    
    
    Set BigBit = CurrentDb
    Set TabDok = BigBit.OpenRecordset("RadniNalozi", DB_OPEN_DYNASET, dbSeeChanges)
    
    
TabDok.AddNew                                'Dodaj novi rekord

'*********************************************
'Dodato: 02.01.2019
'*********************************************
' NE POSTOJI POLJE TabDok!Godina = F_Godina()
TabDok!IDFirma = F_IDFirma()
'*********************************************

TabDok![BrojRadnogNaloga] = BrojRadnogNaloga
TabDok![Pozicija] = Pozicija
TabDok![DatumOtvaranja] = DatumOtvaranja
TabDok![IDInvestitor] = IDInvestitor
If Not IsMissing(NazivProizvoda) Then
    TabDok![NazivProizvoda] = Left(CStr(Nz(NazivProizvoda, "")), TabDok![NazivProizvoda].Size)
End If
TabDok![Memo] = Napomena

'NoviIDRadniNalog = TabDok![IDRadniNalog]
TabDok.Update                    'Sacuvaj izmene

NoviIDRadniNalog = LastIDENTITY()

exit_KreirajRadniNalog:
On Error Resume Next

TabDok.Close
Set TabDok = Nothing
BigBit.Close
Set BigBit = Nothing

KreirajRadniNalog = NoviIDRadniNalog

Exit Function

GreskaKreirajRadniNalog:
 BBErrorMSG err, "KreirajRadniNalog"
 NoviIDRadniNalog = -1
 Resume exit_KreirajRadniNalog

End Function

'******************************************************************
'Prepisuje stavke iz T_Robne stavke za IDDok u T_Usluge stavke
'******************************************************************
Public Sub PrepisiStavkeIzRobeUUsluge(ByVal IDRobniDok As Long, IDUslugaDok As Long)
On Error GoTo err_Sub

  
    Dim rs As DAO.Recordset
    Dim stSQL As String
  
stSQL = "SELECT [T_Robne stavke].*, R_Artikli.Naziv AS NazivArtikla, R_Artikli.[Jedinica mere] FROM R_Artikli INNER JOIN [T_Robne stavke] ON R_Artikli.[Sifra artikla] = [T_Robne stavke].[Sifra artikla]"
stSQL = stSQL & " WHERE ((([T_Robne stavke].IDDok)=" & stR([IDRobniDok]) & ")) ORDER BY [T_Robne stavke].IDStavke;"
    
Set rs = CurrentDb.OpenRecordset(stSQL) ', , , dbReadOnly)

rs.MoveFirst
While Not rs.EOF
   DodajStavkuUUslugaDok IDUslugaDok, Nz(rs!OpisStavke, rs!NazivArtikla), rs![Jedinica mere], rs![Stvarna VP cena], rs!Kolicina, rs![Tarifa - roba - Izlaz], rs![Obracunat  porez na robu]
   rs.MoveNext
Wend
Exit_Sub:

    rs.Close
    Set rs = Nothing
    
Exit Sub

err_Sub:

 BBErrorMSG err, "PrepisiStavkeIzRobeUUsluge"
 Resume Next

End Sub

Public Function DobraStavkaZaImport_Komentar(ByVal IDArtikal, ByVal Kolicina, ByVal VPCena) As String
Dim stRetVal As String

stRetVal = ""
  If Not IsNumeric(IDArtikal) Then
   stRetVal = "Ne postoji artikal"
  ElseIf DCount("*", "R_Artikli", "[Sifra artikla] = " & CLng(IDArtikal)) < 1 Then
   stRetVal = "Ne postoji artikal"
  ElseIf Not IsNumeric(Kolicina) Then
   stRetVal = stRetVal & "Nije dobra kolièina"
  ElseIf Not IsNumeric(VPCena) Then
   stRetVal = stRetVal & "Nije dobra VPCena"
  ElseIf VPCena < 0 Then
   stRetVal = stRetVal & "Nije dobra VPCena"
  Else
   stRetVal = "Ok"
  End If
  DobraStavkaZaImport_Komentar = stRetVal
End Function
Public Function ProknjiziRobnuStavkuPROF(IDDok As Long, IDArtikal As Long, Kolicina As Currency, VPCena As Currency, IDMagacin As Long, Optional ByVal TarifaRoba) As Boolean
'? ProknjiziRobnuStavku(149084,1,1.123,150.00,1)
On Error GoTo err_Func
  Dim retValOk As Boolean
  Dim rst_RobneStavke As DAO.Recordset
  Dim PDVStopa As Currency
  
  retValOk = True
  Set rst_RobneStavke = CurrentDb.OpenRecordset("T_Robne stavke", , dbAppendOnly)
  If IsMissing(TarifaRoba) Then
   TarifaRoba = DLookup("[Tarifa robe]", "R_Artikli", "[Sifra artikla] = " & IDArtikal)
  End If
  PDVStopa = DLookup("[PDVStopa]", "PDVZbirneStope", "[Tarifa] = '" & TarifaRoba & "'")
  
  rst_RobneStavke.AddNew
  rst_RobneStavke!IDDok = IDDok
  rst_RobneStavke![Sifra artikla] = IDArtikal
  rst_RobneStavke![Kolicina] = Kolicina
  rst_RobneStavke![Stvarna VP cena] = VPCena
  rst_RobneStavke![Stvarna MP cena] = Round(VPCena * (1 + PDVStopa / 100), 2)
  rst_RobneStavke![IDMagacin] = IDMagacin
  rst_RobneStavke![Obracunat porez na usluge] = False
  rst_RobneStavke![Tarifa - usluge - izlaz] = "0"
  rst_RobneStavke![Obracunat  porez na robu] = True
  rst_RobneStavke![Tarifa - roba - Izlaz] = TarifaRoba
  
  rst_RobneStavke.Update

exit_Func:
  
  ProknjiziRobnuStavkuPROF = retValOk

On Error Resume Next
rst_RobneStavke.Close
Set rst_RobneStavke = Nothing

Exit Function

err_Func:
  BBErrorMSG err, "BBKreiranjeDokumenata.ProknjiziRobnuStavkuPROF"
  retValOk = False
  Resume exit_Func:
End Function

Public Function VredPoRedu(RbVred As Integer, ByVal Vred1, ByVal Vred2, ByVal Vred3) As Variant
 Dim retVal As Variant
 
 If RbVred = 1 Then
  retVal = Vred1
 ElseIf RbVred = 2 Then
  retVal = Vred2
 ElseIf RbVred = 3 Then
  retVal = Vred3
 Else
  retVal = 0
 End If
 VredPoRedu = retVal
End Function
'********************
'IMPORTED 22-03-2018
'Public Sub DodajStavkeUIFDokSaObracunomKLCena(ByVal NoviIDDok As Long, QDefSt As String, ZaIDDok As Long, Optional ProveraZaliha As Boolean = True)
Public Sub EXTINT_DodajStavkeUIFDokSaObracunomKLCena(ByVal UlazniDok As Boolean, ByVal TRobneStavke As String, ByVal NoviIDDok As Long, qdefst As String, ZaIDDok As Long, ZaliheOdLevel As Byte, ZaliheDoLevel As Byte, _
                                              Optional ProveraZaliha As Boolean = True, Optional KolUMinus As Boolean = False, _
                                              Optional CeneIzCenovnika As Boolean = False, Optional CenovnikVrstaDok As String = "MP1", _
                                              Optional CenovnikSaPDV As Boolean = True, Optional KolKoef As Currency = 1, _
                                              Optional SacuvajRabat As Boolean = True, _
                                              Optional ObracunajUlazniPDV As Boolean = True)
On Error GoTo GreskaDodajStavkeURobniDok

    Dim BigBit As DAO.Database
    Dim TabStav As DAO.Recordset
    Dim QNoviStav As DAO.QueryDef
    Dim NoviStav As DAO.Recordset
    Dim BrojStavki As Integer
    Dim Greska As Boolean
    Dim Poruka As String
    Dim BrojProknjizenihStavki As Long
    Dim BrojStavkiZaKnjizenje As Long
    Dim BrojStavkiNaPolaznomDokumentu As Long
    Dim DobraKolicina As Boolean
    
    'Dim IDMag As Variant 'mora variant!
    
    BrojStavkiNaPolaznomDokumentu = Nz(DCount("*", "T_Robne stavke", "[IDDok] = " & NoviIDDok), 0)
    
    Greska = False
    
    Set BigBit = CurrentDb
    Set TabStav = BigBit.OpenRecordset("T_Robne stavke", DB_OPEN_DYNASET, dbSeeChanges) 'Tabela U koju se knjizi
    Set QNoviStav = BigBit.QueryDefs(qdefst)
    QNoviStav.Parameters("[ZaIDDok]") = ZaIDDok
    'QNoviStav.Parameters("[ZaDobraKolicina]") = CStr(IIf(ProveraZaliha, "-1", "*"))
    QNoviStav.Parameters("[ZaliheOdLevel]") = ZaliheOdLevel
    QNoviStav.Parameters("[ZaliheDoLevel]") = ZaliheDoLevel
    QNoviStav.Parameters("[CenovnikVrstaDok]") = CenovnikVrstaDok
    
    Set NoviStav = QNoviStav.OpenRecordset()
    NoviStav.Sort = "IDStavke"
    NoviStav.Requery
    
NoviStav.MoveFirst
BrojStavki = 0
Do Until NoviStav.EOF
   'DobraKolicina: CStr(CInt(([ZalihaKolicineZaMagacin]-[Kolicina])>=-0.001))
   
   If ProveraZaliha Then
    If UlazniDok Then
     DobraKolicina = ((NoviStav!ZalihaKolicineZaMagacin + KolKoef * NoviStav!Kolicina) >= -0.001)
    Else
     DobraKolicina = ((NoviStav!ZalihaKolicineZaMagacin - KolKoef * NoviStav!Kolicina) >= -0.001)
    End If
   Else
    DobraKolicina = True
   End If
 If DobraKolicina Then
   TabStav.AddNew                                'Dodaj novi rekord
     
   TabStav![IDDok] = NoviIDDok
   TabStav![Sifra artikla] = NoviStav![Sifra artikla]
   TabStav![Kolicina] = KolKoef * NoviStav!Kolicina
   
   
    If Abs(NoviStav![ProsecnaNC]) < 0.0001 Then
        TabStav![Nabavna cena - neto] = NoviStav![PoslednjaKLNC]
    Else
        TabStav![Nabavna cena - neto] = NoviStav![ProsecnaNC]
    End If
   
    TabStav![Zavisni trosak - sopstveni] = 0
    TabStav![Zavisni trosak - dobavljac] = 0
   
    If Abs(NoviStav![ProsecnaVPC]) < 0.0001 Then
        TabStav![Kalkulativna VP cena] = NoviStav![PoslednjaKLVPC]
    Else
        TabStav![Kalkulativna VP cena] = NoviStav![ProsecnaVPC]
    End If
   
    TabStav![Kalkulativna MP cena] = Round(TabStav![Kalkulativna VP cena] * (1 + NoviStav!PDVStopa / 100#), 2)
   
    If CeneIzCenovnika Then
            If CenovnikSaPDV Then
                TabStav![Stvarna VP cena] = NoviStav![CenaIzCenovnika] / (1 + NoviStav!PDVStopa / 100#)
                TabStav![Stvarna MP cena] = NoviStav![CenaIzCenovnika]
            Else
                TabStav![Stvarna VP cena] = NoviStav![CenaIzCenovnika]
                TabStav![Stvarna MP cena] = Round(NoviStav![CenaIzCenovnika] * (1 + NoviStav!PDVStopa / 100#), 2)
            End If
        
        If SacuvajRabat Then
            TabStav![Stvarna VP cena] = TabStav![Stvarna VP cena] * (1# - (NoviStav![RabatProc] / 100)) * (1# - (NoviStav![KasaProc] / 100))
            TabStav![Stvarna MP cena] = Round(TabStav![Stvarna MP cena] * (1# - (NoviStav![RabatProc] / 100)) * (1# - (NoviStav![KasaProc] / 100)), 2)
            TabStav![RabatProc] = NoviStav![RabatProc]
            TabStav![KasaProc] = NoviStav![KasaProc]
        Else
            TabStav![RabatProc] = 0
            TabStav![KasaProc] = 0
        End If
    Else
        If NoviStav![Ulaz] Then
            TabStav![Stvarna VP cena] = TabStav![Kalkulativna VP cena]
            TabStav![Stvarna MP cena] = TabStav![Kalkulativna MP cena]
            TabStav![RabatProc] = 0
            TabStav![KasaProc] = 0
        Else
            If SacuvajRabat Then
                TabStav![Stvarna VP cena] = NoviStav![Stvarna VP cena]
                TabStav![Stvarna MP cena] = NoviStav![Stvarna MP cena]
                TabStav![RabatProc] = NoviStav![RabatProc]
                TabStav![KasaProc] = NoviStav![KasaProc]
            Else
                TabStav![Stvarna VP cena] = (NoviStav![Stvarna VP cena] / (1# - (NoviStav![KasaProc] / 100))) / (1# - (NoviStav![RabatProc] / 100))
                TabStav![Stvarna MP cena] = (NoviStav![Stvarna MP cena] / (1# - (NoviStav![KasaProc] / 100))) / (1# - (NoviStav![RabatProc] / 100))
                TabStav![RabatProc] = 0
                TabStav![KasaProc] = 0
            End If
        End If
    
    End If
   
   TabStav![TAKSA] = NoviStav![TAKSA]
     
   TabStav![Odlozeno] = NoviStav![Odlozeno]
   TabStav![Obracunat porez na ulazu - roba] = ObracunajUlazniPDV 'NoviStav![Obracunat porez na ulazu - roba]
   TabStav![Tarifa - roba - ulaz] = NoviStav![Tarifa - roba - ulaz]
   TabStav![Obracunat porez na usluge] = NoviStav![Obracunat porez na usluge]
   TabStav![Tarifa - usluge - izlaz] = NoviStav![Tarifa - usluge - izlaz]
   TabStav![Obracunat  porez na robu] = NoviStav![Obracunat  porez na robu]
   TabStav![Tarifa - roba - Izlaz] = NoviStav![Tarifa - roba - Izlaz]
   TabStav![IDMagacin] = NoviStav![IDMagacin]
   'TabStav!OpisStavke = NoviStav!OpisStavke
   TabStav!OpisStavke = NoviStav!NazivArtikla

   TabStav.Update 'Sacuvaj izmene
   BrojStavki = BrojStavki + 1
 End If 'DobraKolicina
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
      Poruka = "Procedura DodajStavkeUIFDokSaObracunomKLCena se završava sa greškom!" & vbCrLf
    Else
      Poruka = ""
    End If
    Poruka = Poruka & "Broj stavki dodatih u dokument = " & BrojStavki & "."
    ' MsgBox Poruka, vbInformation, "QMegaTeh"
'********************************************************************
' Uporedjivanje broja proknjizenih stavki
'********************************************************************
On Error Resume Next
BrojProknjizenihStavki = Nz(DCount("*", "T_Robne stavke", "[IDDok] = " & NoviIDDok), 0) - BrojStavkiNaPolaznomDokumentu
BrojStavkiZaKnjizenje = Nz(DCount("*", TRobneStavke, "[IDDok] = " & ZaIDDok), 0)
If BrojProknjizenihStavki <> BrojStavkiZaKnjizenje Then
    Poruka = "Broj proknjiženih stavki u izlazni dokument nije dobar!" & vbCrLf
    Poruka = Poruka & "Ostalo je neproknjiženih stavki: " & BrojStavkiZaKnjizenje - BrojProknjizenihStavki
    MsgBox Poruka, vbCritical, "QMegaTeh"
End If
'********************************************************************
Exit Sub

GreskaDodajStavkeURobniDok:
 MsgBox Error$
 Greska = True
 Resume exit_GreskaDodajStavkeURobniDok

End Sub
Public Sub OtvoriDijalogZaKreiranjeDok(ExtInt As String, IDDok As Long)
On Error GoTo Err_OtvoriDijalogZaKreiranjeDok

    Dim stDocName As String
    Dim stLinkCriteria As String
    Dim frm As Form

    stDocName = "KreirajDokIzDok"
  
    DoCmd.OpenForm stDocName, , , stLinkCriteria
    Forms(stDocName)!ComboImportIz = ExtInt
    Forms(stDocName)!IzIDDok = IDDok
    Forms(stDocName)!IzIDDok.Locked = True
    Forms(stDocName).ImportIz = ExtInt
    'Call Forms(stDocName).ScenKALK
    Call Forms(stDocName).ScenPROF
  ' !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    Call Forms(stDocName).PodesiFormu   'Poziva PUBLIC Sub/Func iz forme stDocName
    'Forms(stDocName).Requery
    
Exit_OtvoriDijalogZaKreiranjeDok:
    Exit Sub

Err_OtvoriDijalogZaKreiranjeDok:
    BBErrorMSG err, "OtvoriDijalogZaKreiranjeDok"
    Resume Exit_OtvoriDijalogZaKreiranjeDok
    
End Sub
Public Sub EXTINT_DodajStavkeUUFDok(ByVal UlazniDok As Boolean, ByVal TRobneStavke As String, ByVal NoviIDDok As Long, qdefst As String, ZaIDDok As Long, ZaliheOdLevel As Byte, ZaliheDoLevel As Byte, _
                                              Optional ProveraZaliha As Boolean = True, Optional KolUMinus As Boolean = False, _
                                              Optional CeneIzCenovnika As Boolean = False, Optional CenovnikVrstaDok As String = "MP1", _
                                              Optional CenovnikSaPDV As Boolean = True, Optional KolKoef As Currency = 1, _
                                              Optional SacuvajRabat As Boolean = True, _
                                              Optional ObracunajUlazniPDV As Boolean = True)
On Error GoTo GreskaDodajStavkeURobniDok

    Dim BigBit As DAO.Database
    Dim TabStav As DAO.Recordset
    Dim QNoviStav As DAO.QueryDef
    Dim NoviStav As DAO.Recordset
    Dim BrojStavki As Integer
    Dim Greska As Boolean
    Dim Poruka As String
    Dim BrojProknjizenihStavki As Long
    Dim BrojStavkiZaKnjizenje As Long
    Dim BrojStavkiNaPolaznomDokumentu As Long
    Dim DobraKolicina As Boolean
    
    'Dim IDMag As Variant 'mora variant!
    
    BrojStavkiNaPolaznomDokumentu = Nz(DCount("*", "T_Robne stavke", "[IDDok] = " & NoviIDDok), 0)
    
    Greska = False
    
    Set BigBit = CurrentDb
    Set TabStav = BigBit.OpenRecordset("T_Robne stavke", DB_OPEN_DYNASET) 'Tabela U koju se knjizi
    Set QNoviStav = BigBit.QueryDefs(qdefst)
    QNoviStav.Parameters("[ZaIDDok]") = ZaIDDok
    'QNoviStav.Parameters("[ZaDobraKolicina]") = CStr(IIf(ProveraZaliha, "-1", "*"))
    QNoviStav.Parameters("[ZaliheOdLevel]") = ZaliheOdLevel
    QNoviStav.Parameters("[ZaliheDoLevel]") = ZaliheDoLevel
    QNoviStav.Parameters("[CenovnikVrstaDok]") = CenovnikVrstaDok
    
    Set NoviStav = QNoviStav.OpenRecordset()
    NoviStav.Sort = "IDStavke"
    NoviStav.Requery
    
NoviStav.MoveFirst
BrojStavki = 0
Do Until NoviStav.EOF
   'DobraKolicina: CStr(CInt(([ZalihaKolicineZaMagacin]-[Kolicina])>=-0.001))
   
   If ProveraZaliha Then
    If UlazniDok Then
     DobraKolicina = ((NoviStav!ZalihaKolicineZaMagacin + KolKoef * NoviStav!Kolicina) >= -0.001)
    Else
     DobraKolicina = ((NoviStav!ZalihaKolicineZaMagacin - KolKoef * NoviStav!Kolicina) >= -0.001)
    End If
   Else
    DobraKolicina = True
   End If
 If DobraKolicina Then
   TabStav.AddNew                                'Dodaj novi rekord
     
   TabStav![IDDok] = NoviIDDok
   TabStav![Sifra artikla] = NoviStav![Sifra artikla]
   TabStav![Kolicina] = KolKoef * NoviStav!Kolicina
      
    If NoviStav!Ulaz Then
        TabStav![Nabavna cena - neto] = NoviStav![Nabavna cena - neto]
        TabStav![Zavisni trosak - sopstveni] = NoviStav![Zavisni trosak - sopstveni]
        TabStav![Zavisni trosak - dobavljac] = NoviStav![Zavisni trosak - dobavljac]
        TabStav![Kalkulativna VP cena] = NoviStav![Kalkulativna VP cena]
        TabStav![Kalkulativna MP cena] = Round(NoviStav![Kalkulativna VP cena] * (1 + NoviStav!PDVStopa / 100#), 2)
        TabStav!RabatProc = NoviStav![RabatProc]
        TabStav![KasaProc] = NoviStav![KasaProc]
    Else
        TabStav![Nabavna cena - neto] = NoviStav![Stvarna VP cena]
        TabStav![Zavisni trosak - sopstveni] = 0
        TabStav![Zavisni trosak - dobavljac] = 0
        If CeneIzCenovnika Then
            If CenovnikSaPDV Then
                TabStav![Kalkulativna VP cena] = NoviStav![CenaIzCenovnika] / (1 + NoviStav!PDVStopa / 100#)
                TabStav![Kalkulativna MP cena] = NoviStav![CenaIzCenovnika]
            Else
                TabStav![Kalkulativna VP cena] = NoviStav![CenaIzCenovnika]
                TabStav![Kalkulativna MP cena] = Round(NoviStav![CenaIzCenovnika] * (1 + NoviStav!PDVStopa / 100#), 2)
            End If
        Else
            TabStav![Kalkulativna VP cena] = 10000# * NoviStav![Stvarna VP cena] / ((100# - NoviStav![RabatProc]) * (100# - NoviStav![KasaProc]))
            TabStav![Kalkulativna MP cena] = Round(TabStav![Kalkulativna VP cena] * (1 + NoviStav!PDVStopa / 100#), 2)
            TabStav!RabatProc = NoviStav![RabatProc]
            TabStav![KasaProc] = NoviStav![KasaProc]
        End If
        
    End If
   
   TabStav![TAKSA] = NoviStav![TAKSA]
     
   TabStav![Odlozeno] = NoviStav![Odlozeno]
   TabStav![Obracunat porez na ulazu - roba] = ObracunajUlazniPDV ' NoviStav![Obracunat porez na ulazu - roba]
   TabStav![Tarifa - roba - ulaz] = NoviStav![Tarifa - roba - ulaz]
   TabStav![Obracunat porez na usluge] = NoviStav![Obracunat porez na usluge]
   TabStav![Tarifa - usluge - izlaz] = NoviStav![Tarifa - usluge - izlaz]
   TabStav![Obracunat  porez na robu] = NoviStav![Obracunat  porez na robu]
   TabStav![Tarifa - roba - Izlaz] = NoviStav![Tarifa - roba - Izlaz]
   TabStav![IDMagacin] = NoviStav![IDMagacin]
   'TabStav!OpisStavke = NoviStav!OpisStavke
   TabStav!OpisStavke = NoviStav!NazivArtikla

   TabStav.Update 'Sacuvaj izmene
   BrojStavki = BrojStavki + 1
 End If 'DobraKolicina
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
      Poruka = "Procedura DodajStavkeUUFDok se završava sa greškom!" & vbCrLf
    Else
      Poruka = ""
    End If
    Poruka = Poruka & "Broj stavki dodatih u dokument = " & BrojStavki & "."
    ' MsgBox Poruka, vbInformation, "QMegaTeh"
'********************************************************************
' Uporedjivanje broja proknjizenih stavki
'********************************************************************
On Error Resume Next
BrojProknjizenihStavki = Nz(DCount("*", "T_Robne stavke", "[IDDok] = " & NoviIDDok), 0) - BrojStavkiNaPolaznomDokumentu
BrojStavkiZaKnjizenje = Nz(DCount("*", TRobneStavke, "[IDDok] = " & ZaIDDok), 0)
If BrojProknjizenihStavki <> BrojStavkiZaKnjizenje Then
    Poruka = "Broj proknjiženih stavki u ulazni dokument nije dobar!" & vbCrLf
    Poruka = Poruka & "Ostalo je neproknjiženih stavki: " & BrojStavkiZaKnjizenje - BrojProknjizenihStavki
    MsgBox Poruka, vbCritical, "QMegaTeh"
End If
'********************************************************************
Exit Sub

GreskaDodajStavkeURobniDok:
 MsgBox Error$
 Greska = True
 Resume exit_GreskaDodajStavkeURobniDok

End Sub

Public Function KreirajIliPronadjiPredmet(BrojPredmeta As String, Opis As String, DatumOtvaranja As Date, IDKomitent As Long, ByVal Status As String, Optional ByVal Napomena As String = "-") As Long
'26-10-2018
'Kreira novi predmet ako može, a ako ne može zbog indexa "BrojPredmeta"
'onda vraæa ID postojeæeg
'a ako ne postoji vraæa -1
On Error GoTo Err_Point
 

    Dim BigBit As DAO.Database
    Dim TabDok As DAO.Recordset
    Dim noviIDPredmet As Long
    Dim tmp As Variant
    Dim BrojDokumenta As String
    
    
    Set BigBit = CurrentDb
    Set TabDok = BigBit.OpenRecordset("Predmeti", DB_OPEN_DYNASET, dbSeeChanges)
    
 TabDok.FindFirst "[BrojPredmeta] = '" & BrojPredmeta & "'"
 If Not TabDok.NoMatch Then
     noviIDPredmet = TabDok!IDPredmet
     GoTo Exit_Point
 End If
    
TabDok.AddNew                                'Dodaj novi rekord
TabDok![BrojPredmeta] = Left(BrojPredmeta, TabDok.Fields("BrojPredmeta").Size)
TabDok![Opis] = Left(BrojPredmeta, TabDok.Fields("Opis").Size)
TabDok![DatumOtvaranja] = DatumOtvaranja
TabDok![IDKomitent] = IDKomitent
If Nz(Status) = "" Then
 Status = "UNKNOWN"
End If
TabDok!Status = Left(Status, TabDok.Fields("Status").Size)
If Nz(Napomena) = "" Then
 Napomena = "-"
End If
TabDok![Memo] = Napomena
TabDok.Update                    'Sacuvaj izmene

'NoviIDPredmet = TabDok![IDPredmet]
noviIDPredmet = LastIDENTITY

Exit_Point:
On Error Resume Next

TabDok.Close
Set TabDok = Nothing
BigBit.Close
Set BigBit = Nothing

KreirajIliPronadjiPredmet = noviIDPredmet

Exit Function
pronadjiPredmet:
   TabDok.FindFirst "[BrojPredmeta] = '" & BrojPredmeta & "'"
   If TabDok.NoMatch Then
    noviIDPredmet = -1
   Else
    noviIDPredmet = TabDok!IDPredmet
   End If
GoTo Exit_Point:

Err_Point:
 If err.Number = 3022 Then
  Resume pronadjiPredmet:
 Else
  BBErrorMSG err, "KreirajIliPronadjiPredmet"
  noviIDPredmet = -1
 End If
 Resume Exit_Point
End Function

Public Function DodajStavkuUPopis(IDPopis As Long, IDArtikal As Long, KolKng As Currency, KolPop As Currency, Cena As Currency, Optional IDMagacin, Optional ByVal TarifaRoba) As Boolean
'**********************
'Date: 13-06-2019
'**********************
On Error GoTo err_Func
  Dim retValOk As Boolean
  Dim rstStavke As DAO.Recordset
  Dim PDVStopa As Currency
  
  retValOk = True
  Set rstStavke = CurrentDb.OpenRecordset("T_Popis stavke", , dbAppendOnly)
  If IsMissing(TarifaRoba) Then
   TarifaRoba = DLookup("[Tarifa robe]", "R_Artikli", "[Sifra artikla] = " & IDArtikal)
  End If
  If IsMissing(IDMagacin) Then
   IDMagacin = DFirst("[IDMagacin]", "Magacini")
  End If
  'PDVStopa = DLookup("[PDVStopa]", "PDVZbirneStope", "[Tarifa] = '" & TarifaRoba & "'")
  
  rstStavke.AddNew
  rstStavke!IDPopis = IDPopis
  rstStavke![IDArtikal] = IDArtikal
  rstStavke![KolKng] = KolKng
  rstStavke![KolPop] = KolPop
  rstStavke![Cena] = Cena
  rstStavke![IDMagacin] = IDMagacin
  rstStavke![Tarifa] = TarifaRoba
  
  rstStavke.Update

exit_Func:
  
  DodajStavkuUPopis = retValOk

On Error Resume Next
rstStavke.Close
Set rstStavke = Nothing

Exit Function

err_Func:
  BBErrorMSG err, "BBKreiranjeDokumenata.DodajStavkuUPopis"
  retValOk = False
  Resume exit_Func:
End Function
Public Function spUradiMMP( _
    IDFirma As Long, Godina As Long, OJ As Long, OD As Long, _
    IDDok_OsnovniDokument As Long, KoefKol As Double, IDMagacin_PLUS As Long, BrojDokumenata As Long, ObracunNabCene As Integer, _
    ProveraZaliha As Boolean, ZaliheOdDatuma As Variant, ZaliheDoDatuma As Variant, ZaliheOdLevel As Byte, ZaliheDoLevel As Byte, _
    VrstaDok_PLUS As String, BrojDok_PLUS As String, DatumDok_PLUS As Date, Leveldok_PLUS As Byte, IDKomitent_PLUS As Long, Opis_PLUS As String, _
    VrstaDok_MINUS As String, BrojDok_MINUS As String, DatumDok_MINUS As Date, LevelDok_MINUS As Byte, IDKomitent_MINUS As Long, Opis_MINUS As String _
                ) As Boolean
'Kreirano: 20-08-2020
On Error GoTo Err_Point
'    @IDFirma int ,
'    @Godina int = Null,
'    @OJ int = 0,
'    @OD int = 0,
'
'    @IDDok_OsnovniDokument int,
'    @KoefKol float = 1,
'    @IDMagacin_PLUS int,
'
'    @BrojDokumenata int, -- =1 -  kroz isti dokument i MINUS i PLUS
'                         -- =2 -  poseban dokument za MINUS, a poseban za PLUS
'
'    @ObracunNabCene int,  -- =1 -  nabavna cena iz Osnovnog dokumenta
'                          -- =2 -  Proseène nabavne cene (u magacinu povraæaja - MINUS)
'    @ProveraZaliha bit,
'    @ZaliheOdDatuma date = null,
'    @ZaliheDoDatuma date = null,
'    @ZaliheOdLevel smallint = 0,
'    @ZaliheDoLevel smallint = 0,
'
'    @VrstaDok_PLUS nvarchar(20),
'    @BrojDok_PLUS nvarchar(20),
'    @DatumDok_PLUS date,
'    @LevelDok_PLUS smallint = 0,
'    @IDKomitent_PLUS int,
'    @Opis_PLUS nvarchar(30),
'
'    @VrstaDok_MINUS nvarchar(20),
'    @BrojDok_MINUS nvarchar(20),
'    @DatumDok_MINUS date,
'    @LevelDok_MINUS smallint = 0,
'    @IDKomitent_MINUS int,
'    @Opis_MINUS nvarchar(30)
Dim retValOk As Boolean

    retValOk = ADO_ExecSP(BBCFG.CNNString, "spUradiMMP", IDFirma, Godina, OJ, OD, _
    IDDok_OsnovniDokument, KoefKol, IDMagacin_PLUS, BrojDokumenata, ObracunNabCene, _
    SQLFormatBoolean(ProveraZaliha), SQLFormatDatuma(ZaliheOdDatuma, False), SQLFormatDatuma(ZaliheDoDatuma, False), ZaliheOdLevel, ZaliheDoLevel, _
    VrstaDok_PLUS, BrojDok_PLUS, SQLFormatDatuma(DatumDok_PLUS, False), Leveldok_PLUS, IDKomitent_PLUS, Opis_PLUS, _
    VrstaDok_MINUS, BrojDok_MINUS, SQLFormatDatuma(DatumDok_MINUS, False), LevelDok_MINUS, IDKomitent_MINUS, Opis_MINUS)
    
Exit_Point:
 On Error Resume Next
 spUradiMMP = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "spUradiMMP"
 Resume Exit_Point
End Function
Public Function spKreirajRobniDokIzProfakture(ByVal IDFirma As Long, ByVal Godina As Variant, ByVal Level As Byte, ByVal IzIDDok As Long, _
                                              ByVal PromeniDatume As Boolean, _
                                              ByVal NoviDatumDokumenta As Date, _
                                              ByVal NoviBrojDokumenta As String, _
                                              ByVal NovaVrstaDokumenta As String, _
                                              ByVal NoviDatumValute As Date, _
                                              ByRef NoviIDDok) As Boolean
'Kreirano: 17-01-2022
'Modifikovano: 23-06-2022
'    ,@PromeniDatume bit = 0
'    ,@NoviDatumDokumenta datetime
'    ,@NoviBrojDokumenta nvarchar(20)
'    ,@NovaVrstaDokumenta nvarchar(10)

On Error GoTo Err_Point

Dim pCMD As New ADODB.Command
Dim retValOk As Boolean

retValOk = True
DoCmd.Hourglass True

pCMD.ActiveConnection = CNN_CurrentDataBase
pCMD.CommandType = adCmdStoredProc
pCMD.CommandText = "spKreirajRobniDokIzProfakture"

pCMD.Parameters.Refresh 'posle ove komande svi parametri su definisani!
'pCMD.Parameters("@RETURN_VALUE") = CmdRetVal
pCMD.Parameters("@IDFirma") = IDFirma
pCMD.Parameters("@Godina") = Godina
pCMD.Parameters("@Level") = Level

pCMD.Parameters("@PromeniDatume") = PromeniDatume
pCMD.Parameters("@NoviDatumDokumenta") = NoviDatumDokumenta
pCMD.Parameters("@NoviBrojDokumenta") = NoviBrojDokumenta
pCMD.Parameters("@NovaVrstaDokumenta") = NovaVrstaDokumenta
pCMD.Parameters("@NoviDatumValute") = NoviDatumValute

pCMD.Parameters("@IzIDDok") = IzIDDok

'pCMD.Parameters("@NoviIDDok") = NoviIDDok ' OUTPUT

pCMD.CommandTimeout = 30 '180 = 3 minuta !!

pCMD.Execute
retValOk = (pCMD.ActiveConnection.Errors.Count = 0)

If retValOk Then
    NoviIDDok = Nz(pCMD.Parameters("@NoviIDDok").Value, -1) ' OUTPUT
Else
    NoviIDDok = -1
End If

Exit_Point:
On Error Resume Next

pCMD.ActiveConnection.Close
Set pCMD = Nothing

DoCmd.Hourglass False
    spKreirajRobniDokIzProfakture = retValOk
Exit Function

Err_Point:

    BBErrorMSG err, "spKreirajRobniDokIzProfakture(...)"
    retValOk = False
    Resume Exit_Point
    
End Function


Public Function spKreirajMPDokIStavkeIzVPDok(ByVal VP_IDDok As Long, _
                                             ByRef MP_IDDok As Long, ByRef MP_IDProdavnica As Long, ByRef MP_IDKasa As Long) As Boolean
        ' @IDFirma int
        ',@Godina int
        ',@VP_IDDok int
        ',@MP_IDDok int OUTPUT
        ',@MP_IDProdavnica int OUTPUT
        ',@MP_IDKasa int OUTPUT
        
'Kreirano: 23-04-2022
On Error GoTo Err_Point

Dim pCMD As New ADODB.Command
Dim retValOk As Boolean

retValOk = True
DoCmd.Hourglass True

pCMD.ActiveConnection = CNN_CurrentDataBase
pCMD.CommandType = adCmdStoredProc
pCMD.CommandText = "spKreirajMPDokIStavkeIzVPDok"

pCMD.Parameters.Refresh 'posle ove komande svi parametri su definisani!
'pCMD.Parameters("@RETURN_VALUE") = CmdRetVal
pCMD.Parameters("@IDFirma") = F_IDFirma()
pCMD.Parameters("@Godina") = Null
pCMD.Parameters("@VP_IDDok") = VP_IDDok
'pCMD.Parameters("@MP_IDDok") = MP_IDDok ' OUTPUT
pCMD.Parameters("@MP_IDProdavnica") = MP_IDDok ' OUTPUT
pCMD.Parameters("@MP_IDKasa") = MP_IDKasa ' OUTPUT

pCMD.CommandTimeout = 30 '180 = 3 minuta !!

pCMD.Execute
retValOk = (pCMD.ActiveConnection.Errors.Count = 0)

If retValOk Then
    MP_IDDok = Nz(pCMD.Parameters("@MP_IDDok").Value, -1) ' OUTPUT
    MP_IDProdavnica = Nz(pCMD.Parameters("@MP_IDProdavnica").Value, -1) ' OUTPUT
    MP_IDKasa = Nz(pCMD.Parameters("@MP_IDKasa").Value, -1) ' OUTPUT
Else
    MP_IDDok = -1
End If

Exit_Point:
On Error Resume Next

pCMD.ActiveConnection.Close
Set pCMD = Nothing

DoCmd.Hourglass False
    spKreirajMPDokIStavkeIzVPDok = retValOk
Exit Function

Err_Point:

    BBErrorMSG err, "spKreirajMPDokIStavkeIzVPDok(...)"
    retValOk = False
    Resume Exit_Point
    
End Function
Public Function spPrepisiStavke_RobniDok(ByVal IzIDDok As Long, ByVal UIDDok As Long, Optional KoefKol As Double = 1) As Boolean
'Kreirano 25-01-2023

On Error GoTo Err_Point

Dim pCMD As New ADODB.Command
Dim retValOk As Boolean

retValOk = True
DoCmd.Hourglass True

pCMD.ActiveConnection = CNN_CurrentDataBase
pCMD.CommandType = adCmdStoredProc
pCMD.CommandText = "spPrepisiStavke_RobniDok"

pCMD.Parameters.Refresh 'posle ove komande svi parametri su definisani!
'pCMD.Parameters("@RETURN_VALUE") = CmdRetVal
pCMD.Parameters("@IzIDDok") = IzIDDok
pCMD.Parameters("@UIDDok") = UIDDok
pCMD.Parameters("@KoefKol") = KoefKol

pCMD.CommandTimeout = 30 '180 = 3 minuta !!

pCMD.Execute
retValOk = (pCMD.ActiveConnection.Errors.Count = 0)

Exit_Point:
On Error Resume Next

pCMD.ActiveConnection.Close
Set pCMD = Nothing

DoCmd.Hourglass False
    spPrepisiStavke_RobniDok = retValOk
Exit Function

Err_Point:

    BBErrorMSG err, "spPrepisiStavke_RobniDok(...)"
    retValOk = False
    Resume Exit_Point
    
End Function
Public Function spPrepisiStavke_UslugeDok(ByVal IzIDDok As Long, ByVal UIDDok As Long, Optional KoefKol As Double = 1) As Boolean
'Kreirano 26-01-2023

On Error GoTo Err_Point

Dim pCMD As New ADODB.Command
Dim retValOk As Boolean

retValOk = True
DoCmd.Hourglass True

pCMD.ActiveConnection = CNN_CurrentDataBase
pCMD.CommandType = adCmdStoredProc
pCMD.CommandText = "spPrepisiStavke_UslugeDok"

pCMD.Parameters.Refresh 'posle ove komande svi parametri su definisani!
'pCMD.Parameters("@RETURN_VALUE") = CmdRetVal
pCMD.Parameters("@IzIDDok") = IzIDDok
pCMD.Parameters("@UIDDok") = UIDDok
pCMD.Parameters("@KoefKol") = KoefKol

pCMD.CommandTimeout = 30 '180 = 3 minuta !!

pCMD.Execute
retValOk = (pCMD.ActiveConnection.Errors.Count = 0)

Exit_Point:
On Error Resume Next

pCMD.ActiveConnection.Close
Set pCMD = Nothing

DoCmd.Hourglass False
    spPrepisiStavke_UslugeDok = retValOk
Exit Function

Err_Point:

    BBErrorMSG err, "spPrepisiStavke_UslugeDok(...)"
    retValOk = False
    Resume Exit_Point
    
End Function

Public Function KreirajUslugaDokPoUgovoru(VrstaUgovora As String, IDKomitent As Long, pDatumDok As Date, pVrstaDok As String _
                                            , pOdlozeno As Integer, pKurs As Double, pPeriod As String _
                                            , pLevel As Byte _
                                            , Optional pRound As Integer = 2) As Boolean
On Error GoTo Err_Point

Dim retValOk As Boolean
Dim NoviIDDok As Variant
Dim IDProdavac As Long
Dim stOpisStavke As String
Dim IDMagacin As Long
Dim DatumValute As Date

Dim stSQL As String
Dim rstStavkeUgovora As ADODB.Recordset

Dim vCena As Currency
Dim stNapomena As String
retValOk = True

IDProdavac = F_IDProdavacZaKomitenta(IDKomitent)
IDMagacin = Nz(ReadCFGParametar("STDMagacin"), 1)
DatumValute = DateAdd("d", pOdlozeno, pDatumDok)


stSQL = "SELECT * FROM Komitenti_Ugovori WHERE (VrstaUgovora = '" & VrstaUgovora & "') AND (Aktivan=1) AND (IDKomitent=" & CStr(IDKomitent) & ") ORDER BY ID ASC"
Set rstStavkeUgovora = ADO_GetRST(CNN_CurrentDataBase, stSQL, dbOptimistic, , adOpenForwardOnly)
stNapomena = F_DefaultNapomena()

If False Then
    If Nz(rstStavkeUgovora!Napomena, "") <> "" Then
        stNapomena = stNapomena & vbCrLf & rstStavkeUgovora!Napomena
    End If
End If

NoviIDDok = KreirajUslugaDok(pDatumDok, pVrstaDok, IDProdavac, 0, pLevel, IDMagacin, IDKomitent, F_MestoIzdavanjaRacuna(), pDatumDok, stNapomena, pKurs, 0, DatumValute)
If NoviIDDok > 0 Then
    
    While Not rstStavkeUgovora.EOF
        stOpisStavke = rstStavkeUgovora!OpisStavke
        stOpisStavke = Replace(stOpisStavke, "@Period", pPeriod)
        If pRound = 0 Then
            vCena = Fix(rstStavkeUgovora!Cena * pKurs)
        Else
            vCena = Round(rstStavkeUgovora!Cena * pKurs, pRound)
        End If
    
        retValOk = retValOk And DodajStavkuUUslugaDok(NoviIDDok, stOpisStavke, rstStavkeUgovora!JedinicaMere, vCena, rstStavkeUgovora!Kolicina, "3", True)
        rstStavkeUgovora.MoveNext
    Wend
Else
    retValOk = False
End If
Exit_Point:
 On Error Resume Next
       rstStavkeUgovora.Close
       Set rstStavkeUgovora = Nothing
       KreirajUslugaDokPoUgovoru = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "KreirajUslugaDokPoUgovoru"
 retValOk = False
 Resume Exit_Point
End Function
Public Function KreirajSveUslugeDok_Ugovori(VrstaUgovora As String, pPeriod As String, pDatum As Date, pVrstaDok As String, pKurs As Double, pOdlozeno As Integer, pLevel As Byte, Optional pRound As Integer = 2) As Boolean
'31-01-2023 ? KreirajSveUslugeDok_Ugovori("Mesec","od 01.01.2023. do 31.01.2023.","31-01-2023","UGOVOR",117.3742,10,0)
'04-05-2023 ? KreirajSveUslugeDok_Ugovori("Mesec","od 01.04.2023. do 30.04.2023.","30-04-2023","UGOVOR",117.2719,10,0)
'Kreirano: 30-01-2023

On Error GoTo Err_Point
Dim retValOk As Boolean
Dim rstUgovori As ADODB.Recordset
Dim stSQL As String
Dim stOpisStavke As String
Dim vCena As Currency

retValOk = True
stSQL = "SELECT IDKomitent FROM Komitenti_Ugovori WHERE (VrstaUgovora = '" & VrstaUgovora & "') AND (Aktivan=1) GROUP BY IDKomitent ORDER BY IDKomitent ASC"
Set rstUgovori = ADO_GetRST(CNN_CurrentDataBase, stSQL, dbOptimistic, , adOpenForwardOnly)

While Not rstUgovori.EOF
    
    retValOk = KreirajUslugaDokPoUgovoru(VrstaUgovora, rstUgovori!IDKomitent, pDatum, pVrstaDok, pOdlozeno, pKurs, pPeriod, pLevel, pRound)
    rstUgovori.MoveNext

Wend

Exit_Point:
 On Error Resume Next
       rstUgovori.Close
       Set rstUgovori = Nothing
       KreirajSveUslugeDok_Ugovori = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "KreirajSveUslugeDok_Ugovori"
 retValOk = False
 Resume Exit_Point

End Function

Public Function spPromeniIDDok_Robno(ByVal StariIDDok As Long, PrebaciUVrstuDok As String, BrojZnakovaBrojDok As Integer, ObrisiPrebaciNaProfStariDok As Integer, ByRef NoviIDDok As Variant) As Boolean
'Kreirano: 23-03-2023
'     @StariIDDok AS int
'    ,@PrebaciUVrstuDok as nvarchar(MAX)
'    ,@BrojZnakovaBrojDok as smallint = 20
'    ,@BrojZnakovaVrsteDok as smallint = 10
'    ,@ObrisiPrebaciNaProfStariDok as smallint = 1 -- 1 - obrisi stari, 0 - prebaci na prof
'    ,@NoviIDDok as int OUT
    
On Error GoTo Err_Point

Dim pCMD As New ADODB.Command
Dim retValOk As Boolean

retValOk = True
DoCmd.Hourglass True

pCMD.ActiveConnection = CNN_CurrentDataBase
pCMD.CommandType = adCmdStoredProc
pCMD.CommandText = "spPromeniIDDok_Robno"

pCMD.Parameters.Refresh 'posle ove komande svi parametri su definisani!
'pCMD.Parameters("@RETURN_VALUE") = CmdRetVal
pCMD.Parameters("@StariIDDok") = StariIDDok
pCMD.Parameters("@PrebaciUVrstuDok") = PrebaciUVrstuDok
pCMD.Parameters("@BrojZnakovaBrojDok") = BrojZnakovaBrojDok
pCMD.Parameters("@ObrisiPrebaciNaProfStariDok") = ObrisiPrebaciNaProfStariDok
'pCMD.Parameters("@NoviIDDok") = NoviIDDok ' OUTPUT

pCMD.CommandTimeout = 60 '180 = 3 minuta !!

pCMD.Execute
retValOk = (pCMD.ActiveConnection.Errors.Count = 0)

If retValOk Then
    NoviIDDok = Nz(pCMD.Parameters("@NoviIDDok").Value, -1) ' OUTPUT
Else
    NoviIDDok = -1
End If

Exit_Point:
On Error Resume Next

pCMD.ActiveConnection.Close
Set pCMD = Nothing

DoCmd.Hourglass False
    spPromeniIDDok_Robno = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "spPromeniIDDok_Robno"
 retValOk = False
 Resume Exit_Point

End Function

Public Function spNapraviKopijuUSLDok(IDDok As Long, KoefKol As Double, NoviBrojDokumenta As Variant _
                                    , NovaVrstaDok As Variant, NoviBrojNaloga As Variant, NovaVrstaNaloga As Variant _
                                    , NoviIDFirma As Variant, NovaGodina As Variant _
                                    , NoviDatumDokumenta As Variant, NoviDatumValute As Variant _
                                    , NoviLevel As Variant _
                                    , NoviDDok As Long) As Boolean

'Kreirano: 19-05-2023
'     @IDDok int
'    ,@KoefKol float = 1
'    ,@NoviBrojDokumenta nvarchar(20)
'    ,@NoviIDFirma int
'    ,@NovaGodina int
'    ,@NoviDatumDokumenta date
'    ,@NoviDatumValute date
'    ,@NoviIDDok int OUT
    
    
On Error GoTo Err_Point

Dim pCMD As New ADODB.Command
Dim retValOk As Boolean

retValOk = True
DoCmd.Hourglass True

pCMD.ActiveConnection = CNN_CurrentDataBase
pCMD.CommandType = adCmdStoredProc
pCMD.CommandText = "spNapraviKopijuUSLDok"

pCMD.Parameters.Refresh 'posle ove komande svi parametri su definisani!
'pCMD.Parameters("@RETURN_VALUE") = CmdRetVal
pCMD.Parameters("@IDDok") = IDDok
pCMD.Parameters("@KoefKol") = KoefKol
pCMD.Parameters("@NoviBrojDokumenta") = NoviBrojDokumenta
pCMD.Parameters("@NovaVrstaDok") = NovaVrstaDok
pCMD.Parameters("@NoviBrojNaloga") = NoviBrojNaloga
pCMD.Parameters("@NovaVrstaNaloga") = NovaVrstaNaloga
pCMD.Parameters("@NoviIDFirma") = NoviIDFirma
pCMD.Parameters("@NovaGodina") = NovaGodina
pCMD.Parameters("@NoviDatumDokumenta") = SQLFormatDatuma(NoviDatumDokumenta, False)
pCMD.Parameters("@NoviDatumValute") = SQLFormatDatuma(NoviDatumValute, False)
pCMD.Parameters("@NoviLevel") = NoviLevel
'pCMD.Parameters("@NoviIDDok") = NoviIDDok ' OUTPUT

pCMD.CommandTimeout = 60 '180 = 3 minuta !!

pCMD.Execute
retValOk = (pCMD.ActiveConnection.Errors.Count = 0)

If retValOk Then
    NoviDDok = Nz(pCMD.Parameters("@NoviIDDok").Value, -1) ' OUTPUT
Else
    NoviDDok = -1
End If

Exit_Point:
On Error Resume Next

pCMD.ActiveConnection.Close
Set pCMD = Nothing

DoCmd.Hourglass False
    spNapraviKopijuUSLDok = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "spNapraviKopijuUSLDok"
 retValOk = False
 Resume Exit_Point

End Function
