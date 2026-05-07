Attribute VB_Name = "ImportIzBB_Module"
Option Compare Database
Option Explicit
Public Function DodajNoveKomitenteIzBigBita() As Boolean
On Error GoTo Err_Point
    Dim SQL_SELECT_IzTabele As String
    Dim retValOk As Boolean
    
    retValOk = True
    
    SQL_SELECT_IzTabele = ""
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " SELECT EXT_Komitenti.Sifra, EXT_Komitenti.Naziv, EXT_Komitenti.Poslovnica, EXT_Komitenti.Mesto,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_Komitenti.Adresa, EXT_Komitenti.[Postanski broj], EXT_Komitenti.[Ziro racun_1],"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_Komitenti.[Ziro racun_2], EXT_Komitenti.[Ziro racun_3], EXT_Komitenti.Telefon,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_Komitenti.Fax, EXT_Komitenti.Kontakt, EXT_Komitenti.Napomena, EXT_Komitenti.Drzava,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_Komitenti.Region, EXT_Komitenti.[Vrsta sifre], EXT_Komitenti.Email, EXT_Komitenti.Mobilni,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_Komitenti.[Datum rodjenja], EXT_Komitenti.[Web adresa], 0 AS [Sifra prodavca], EXT_Komitenti.RabatKomitenta, EXT_Komitenti.ZastKodKupca,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " IIf(Nz([EXT_Komitenti].[PIB],"""")="""",""XX_"" & [EXT_Komitenti].[Sifra],[EXT_Komitenti].[PIB]) AS PIB, EXT_Komitenti.PDVStatus"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " FROM EXT_Komitenti LEFT JOIN Komitenti ON EXT_Komitenti.Sifra = Komitenti.Sifra"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " WHERE (((Komitenti.Sifra) Is Null));"


    retValOk = ExportujTabeluUSQL("EXT_Komitenti", "Komitenti", Trim(Nz(SQL_SELECT_IzTabele, ""))) ', Trim(Nz(Me!SQLTexImport, "")), Trim(Nz(Me!SQLTextPostImport, "")), False, Me!IdentityOnOff = "On")
       
Exit_Point:
 On Error Resume Next
 DodajNoveKomitenteIzBigBita = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "DodajNoveKomitenteIzBigBita"
    retValOk = False
    Resume Exit_Point
End Function
Public Function DodajNovePredmeteIzBigBita() As Boolean
On Error GoTo Err_Point
    Dim SQL_SELECT_IzTabele As String
    Dim retValOk As Boolean
    
    retValOk = True
    
    SQL_SELECT_IzTabele = ""
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " SELECT EXT_Predmeti.IDPredmet, EXT_Predmeti.BrojPredmeta, EXT_Predmeti.Opis, EXT_Predmeti.DatumOtvaranja,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_Predmeti.IDProdavac , EXT_Predmeti.IDKomitent, EXT_Predmeti.NextAction, EXT_Predmeti.DatumZakljucenja, EXT_Predmeti.Memo,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_Predmeti.Status , EXT_Predmeti.NasaRef, EXT_Predmeti.NasKontakt1, EXT_Predmeti.NasKontakt2, EXT_Predmeti.NasTel1,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_Predmeti.NasTel2 , EXT_Predmeti.VasaRef, EXT_Predmeti.VasKontakt1, EXT_Predmeti.VasKontakt2, EXT_Predmeti.VasTel1,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_Predmeti.VasTel2 , EXT_Predmeti.NabavnaVrednost, EXT_Predmeti.Carina, EXT_Predmeti.Spedicija, EXT_Predmeti.Prevoz,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_Predmeti.Ostalo , EXT_Predmeti.InoDobavljac, EXT_Predmeti.RJ, EXT_Predmeti.DevValuta, EXT_Predmeti.Kurs, EXT_Predmeti.NazivPredmeta,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_Predmeti.BrojUgovora , EXT_Predmeti.DatumUgovora, EXT_Predmeti.BrojNarudzbenice, EXT_Predmeti.DatumNarudzbenice"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " FROM EXT_Predmeti LEFT JOIN Predmeti ON EXT_Predmeti.IDPredmet = Predmeti.IDPredmet"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " WHERE (((Predmeti.IDPredmet) Is Null));"
    
    retValOk = ExportujTabeluUSQL("EXT_Predmeti", "Predmeti", Trim(Nz(SQL_SELECT_IzTabele, "")))  ', Trim(Nz(Me!SQLTexImport, "")), Trim(Nz(Me!SQLTextPostImport, "")), False, Me!IdentityOnOff = "On")
       
Exit_Point:
 On Error Resume Next
 DodajNovePredmeteIzBigBita = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "DodajNovePredmeteIzBigBita"
    retValOk = False
    Resume Exit_Point
End Function
Public Function DodajNoveProdavceIzBigBita() As Boolean
On Error GoTo Err_Point
    Dim SQL_SELECT_IzTabele As String
    Dim retValOk As Boolean
    
    retValOk = True
    
    SQL_SELECT_IzTabele = ""
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " SELECT EXT_Prodavci.[Sifra prodavca], EXT_Prodavci.Prodavac, EXT_Prodavci.Region,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_Prodavci.ProcenatZaObracun, EXT_Prodavci.DeljivoUGrupi, EXT_Prodavci.ImeProdavca,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_Prodavci.BrLkProdavca, EXT_Prodavci.LogAcc,"
    'SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_Prodavci.[Sifra prodavca] as Password, EXT_Prodavci.Aktivan,"
    'SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_Prodavci.[Password], EXT_Prodavci.Aktivan,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " IIf(IsNull(EXT_Prodavci.[Password]), EXT_Prodavci.[Sifra prodavca], [EXT_Prodavci].[Password]) As Password, EXT_Prodavci.Aktivan,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_Prodavci.NefiskalniRN, EXT_Prodavci.Storniranje, EXT_Prodavci.PotpisSlika,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_Prodavci.OznakaTima, EXT_Prodavci.Telefon, EXT_Prodavci.Email"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " FROM EXT_Prodavci LEFT JOIN Prodavci ON EXT_Prodavci.[Sifra prodavca] = Prodavci.[Sifra prodavca]"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " WHERE (((Prodavci.[Sifra prodavca]) Is Null));"

    retValOk = ExportujTabeluUSQL("EXT_Prodavci", "Prodavci", Trim(Nz(SQL_SELECT_IzTabele, ""))) ', Trim(Nz(Me!SQLTexImport, "")), Trim(Nz(Me!SQLTextPostImport, "")), False, Me!IdentityOnOff = "On")
       
Exit_Point:
 On Error Resume Next
 DodajNoveProdavceIzBigBita = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "DodajNoveProdavceIzBigBita"
    retValOk = False
    Resume Exit_Point
End Function

Public Function DodajNoveArtikleIzBigBita() As Boolean
On Error GoTo Err_Point
    Dim SQL_SELECT_IzTabele As String
    Dim retValOk As Boolean
    
    retValOk = True
    
    SQL_SELECT_IzTabele = ""
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " SELECT EXT_R_Artikli.[Sifra artikla] AS [BBSifra artikla], EXT_R_Artikli.[Kataloski broj], EXT_R_Artikli.BarKod,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_R_Artikli.PLU, EXT_R_Artikli.ExtSifra, EXT_R_Artikli.Naziv, EXT_R_Artikli.[Jedinica mere],"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_R_Artikli.Pakovanje, EXT_R_Artikli.InoJm, EXT_R_Artikli.Kutija, EXT_R_Artikli.[Transportno pakovanje],"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_R_Artikli.Poreklo, EXT_R_Artikli.Grupa, EXT_R_Artikli.Podgrupa, EXT_R_Artikli.[Tarifa robe],"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_R_Artikli.[Tarifa usluga], EXT_R_Artikli.[Uvek porez na robu], EXT_R_Artikli.[Uvek porez na usluge],"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_R_Artikli.[VP cena], EXT_R_Artikli.[MP cena], EXT_R_Artikli.NabDevCena, EXT_R_Artikli.ProdDevCena,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_R_Artikli.[Minimalna kolicina], EXT_R_Artikli.ArtTaksa, EXT_R_Artikli.Odlozeno,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_R_Artikli.[Neoporezivi deo], EXT_R_Artikli.MaxRabatProc, EXT_R_Artikli.Memo, EXT_R_Artikli.KngSifra, EXT_R_Artikli.ArtAkciza,"
    
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_R_Artikli.KngSifra_2 , EXT_R_Artikli.ZavTrosProiz, EXT_R_Artikli.CarStopa, EXT_R_Artikli.IDRaster,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_R_Artikli.CarTarifa, EXT_R_Artikli.ZemljaPorekla, EXT_R_Artikli.Polica, EXT_R_Artikli.INONaziv, EXT_R_Artikli.SifDob,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_R_Artikli.WebOpis, EXT_R_Artikli.OpisArtikla, EXT_R_Artikli.Tezina, EXT_R_Artikli.PDFLink, EXT_R_Artikli.ZaBrisanje,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_R_Artikli.Aktivan, EXT_R_Artikli.CenaZaUpisUCen, EXT_R_Artikli.IDMestoIzdavanja, EXT_R_Artikli.Proizvodjac, EXT_R_Artikli.HPS,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_R_Artikli.PotpisArt, EXT_R_Artikli.DatumIVremeArt, EXT_R_Artikli.KolUPak, EXT_R_Artikli.KLRucProc, EXT_R_Artikli.OsnJM,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_R_Artikli.SlikaSimbolaLink, EXT_R_Artikli.MPKaloProc, EXT_R_Artikli.WordLokacija, EXT_R_Artikli.VPKaloProc, EXT_R_Artikli.NeVodiZalihe,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_R_Artikli.TezinaKg, EXT_R_Artikli.Zapremina, EXT_R_Artikli.Povrsina, EXT_R_Artikli.RSort, EXT_R_Artikli.AkcijskiRabat, EXT_R_Artikli.Napomena2,"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " EXT_R_Artikli.IDKvalitetArtikla, EXT_R_Artikli.Debljina"
    
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " FROM EXT_R_Artikli LEFT JOIN R_Artikli ON EXT_R_Artikli.[Sifra artikla] = R_Artikli.[BBSifra artikla]"
    SQL_SELECT_IzTabele = SQL_SELECT_IzTabele & " WHERE (((R_Artikli.[BBSifra artikla]) Is Null));"


    retValOk = ExportujTabeluUSQLBezIdentityKolone("EXT_R_Artikli", "R_Artikli", Trim(Nz(SQL_SELECT_IzTabele, "")))
       
Exit_Point:
 On Error Resume Next
 DodajNoveArtikleIzBigBita = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "DodajNoveArtikleIzBigBita"
    retValOk = False
    Resume Exit_Point
End Function
