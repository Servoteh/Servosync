-- =====================================================
-- Query: 000_ProveraSkartova
-- =====================================================
SELECT Predmeti.BrojPredmeta, Komitenti.Naziv, tRN.IdentBroj, tRN.NazivDela, tRN.DatumUnosa, tRN.BrojCrteza, tRN.Revizija, tRN.Varijanta, tRN.Komada AS [Potrebno komada], Query3.Komada AS [Provereno komada], StatusKvaliteta([Query3].[IDVrstaKvaliteta]) AS StatusKontrole, StatusKvaliteta([tRN].[IDVrstaKvaliteta]) AS StatusTehnologa
FROM (Komitenti INNER JOIN (Query3 INNER JOIN tRN ON Query3.IDRN = tRN.IDRN) ON Komitenti.Sifra = tRN.BBIDKomitent) INNER JOIN Predmeti ON Query3.IDPredmet = Predmeti.IDPredmet
WHERE ((([query3].[idvrstaKvaliteta]<>[tRN].[idVrstaKvaliteta])=True) AND (([trn].[komada]-[query3].[komada]=0)=True))
ORDER BY tRN.DatumUnosa DESC;


-- =====================================================
-- Query: B_ZaliheArtPoMag
-- =====================================================
PARAMETERS [Forms]![B_ZaliheArtPoMag]![VPOdLevel] Value, [Forms]![B_ZaliheArtPoMag]![VPDoLevel] Value, [Forms]![B_ZaliheArtPoMag]![Na dan] Value, [Forms]![B_ZaliheArtPoMag]![OdDatuma] Value;
SELECT DISTINCTROW [EXT_T_Robne stavke].IDMagacin AS IDObjekat, EXT_Magacini.Magacin AS NazivObjekta, [EXT_T_Robne stavke].[Sifra artikla] AS IDArtikal, Round(Sum(IIf([Ulaz],[Kolicina],-[Kolicina])),4) AS StanjeKol
FROM EXT_Magacini INNER JOIN ([EXT_T_Robna dokumenta] INNER JOIN [EXT_T_Robne stavke] ON [EXT_T_Robna dokumenta].IDDok = [EXT_T_Robne stavke].IDDok) ON EXT_Magacini.IDMagacin = [EXT_T_Robne stavke].IDMagacin
WHERE ((([EXT_T_Robna dokumenta].[Datum dokumenta]) Between [Forms]![B_ZaliheArtPoMag]![OdDatuma] And [Forms]![B_ZaliheArtPoMag]![Na dan]) AND (([EXT_T_Robna dokumenta].[Vrsta dokumenta])<>"KODJ") AND (([EXT_T_Robna dokumenta].Level) Between [Forms]![B_ZaliheArtPoMag]![VPOdLevel] And [Forms]![B_ZaliheArtPoMag]![VPDoLevel]))
GROUP BY [EXT_T_Robne stavke].IDMagacin, EXT_Magacini.Magacin, [EXT_T_Robne stavke].[Sifra artikla]
HAVING (((Round(Sum(IIf([Ulaz],[Kolicina],-[Kolicina])),4))<>0));


-- =====================================================
-- Query: B_ZaliheArtPoMagIProd
-- =====================================================
SELECT B_ZaliheArtPoMag.IDObjekat, B_ZaliheArtPoMag.NazivObjekta, B_ZaliheArtPoMag.IDArtikal, EXT_R_Artikli.[Kataloski broj], EXT_R_Artikli.BarKod, EXT_R_Artikli.PLU, EXT_R_Artikli.ExtSifra, EXT_R_Artikli.Naziv, EXT_R_Artikli.[Jedinica mere], B_ZaliheArtPoMag.StanjeKol, Round(Nz([RezervisanaKolicina],0),2) AS RezKol
FROM (EXT_R_Artikli INNER JOIN B_ZaliheArtPoMag ON EXT_R_Artikli.[Sifra artikla] = B_ZaliheArtPoMag.IDArtikal) LEFT JOIN LL_RezervisaneKolicine ON EXT_R_Artikli.[Sifra artikla] = LL_RezervisaneKolicine.[Sifra artikla];


-- =====================================================
-- Query: B_ZaliheArtPoMagIProd_CT
-- =====================================================
TRANSFORM Sum(B_ZaliheArtPoMagIProd_ZaCT.StanjeKol) AS SumOfStanjeKol
SELECT B_ZaliheArtPoMagIProd_ZaCT.Grupa, B_ZaliheArtPoMagIProd_ZaCT.IDArtikal, B_ZaliheArtPoMagIProd_ZaCT.[Kataloski broj], B_ZaliheArtPoMagIProd_ZaCT.Naziv, Sum(B_ZaliheArtPoMagIProd_ZaCT.StanjeKol) AS Ukupno
FROM B_ZaliheArtPoMagIProd_ZaCT
GROUP BY B_ZaliheArtPoMagIProd_ZaCT.Grupa, B_ZaliheArtPoMagIProd_ZaCT.IDArtikal, B_ZaliheArtPoMagIProd_ZaCT.[Kataloski broj], B_ZaliheArtPoMagIProd_ZaCT.Naziv
ORDER BY B_ZaliheArtPoMagIProd_ZaCT.Grupa, B_ZaliheArtPoMagIProd_ZaCT.[Kataloski broj]
PIVOT B_ZaliheArtPoMagIProd_ZaCT.NazivObjekta;


-- =====================================================
-- Query: B_ZaliheArtPoMagIProd_ZaCT
-- =====================================================
PARAMETERS [Forms]![B_ZaliheArtPoMag]![ZaGrupu] Value;
SELECT EXT_R_Artikli.Grupa AS IDGrupa, EXT_R_Grupa.Opis AS Grupa, B_ZaliheArtPoMag.IDObjekat, B_ZaliheArtPoMag.NazivObjekta, B_ZaliheArtPoMag.IDArtikal, EXT_R_Artikli.[Kataloski broj], EXT_R_Artikli.BarKod, EXT_R_Artikli.PLU, EXT_R_Artikli.ExtSifra, EXT_R_Artikli.Naziv, EXT_R_Artikli.[Jedinica mere], B_ZaliheArtPoMag.StanjeKol
FROM EXT_R_Grupa INNER JOIN (B_ZaliheArtPoMag INNER JOIN EXT_R_Artikli ON B_ZaliheArtPoMag.IDArtikal = EXT_R_Artikli.[Sifra artikla]) ON EXT_R_Grupa.Grupa = EXT_R_Artikli.Grupa
WHERE (((EXT_R_Artikli.Grupa) Like Nz([Forms]![B_ZaliheArtPoMag]![ZaGrupu],"*")) AND ((Round([StanjeKol],4))<>0));


-- =====================================================
-- Query: BarKodUnos_PostojiSTART
-- =====================================================
SELECT tTehPostupak.IDPostupka, tTehPostupak.SifraRadnika, tTehPostupak.IDPredmet, tTehPostupak.IdentBroj, tTehPostupak.Varijanta, tTehPostupak.PrnTimer, tTehPostupak.DatumIVremeUnosa, tTehPostupak.Operacija, tTehPostupak.RJgrupaRC, tTehPostupak.Toznaka, tTehPostupak.Komada, tTehPostupak.Potpis, tTehPostupak.SimbolRadnik, tTehPostupak.SimbolPostupak, tTehPostupak.SimbolOperacija, tTehPostupak.DatumIVremeZavrsetka, tTehPostupak.ZavrsenPostupak, tTehPostupak.Napomena, tRN.DatumUnosa, tRN.RokIzrade, tRN.BrojCrteza, tRN.NazivDela, Komitenti.Naziv
FROM Komitenti INNER JOIN (tRN INNER JOIN tTehPostupak ON (tRN.Varijanta = tTehPostupak.Varijanta) AND (tRN.IdentBroj = tTehPostupak.IdentBroj) AND (tRN.IDPredmet = tTehPostupak.IDPredmet)) ON Komitenti.Sifra = tRN.BBIDKomitent
WHERE (((tTehPostupak.SifraRadnika)=[Forms]![Barkod_Unos]![SifraRadnika]) AND ((tTehPostupak.ZavrsenPostupak)=False));


-- =====================================================
-- Query: BarKodUnos_PotrebniParametri
-- =====================================================
SELECT tTehPostupak.*
FROM tTehPostupak
WHERE (((tTehPostupak.IDPostupka)=[ZaIDPostupka]));


-- =====================================================
-- Query: BarKodUnos_ProveraKomada
-- =====================================================
SELECT Sum(tTehPostupak.Komada) AS UkupnoNapravljeno
FROM tTehPostupak
WHERE (((tTehPostupak.ZavrsenPostupak)=True) AND ((tTehPostupak.IDPredmet)=[ZaIDPredmet]) AND ((tTehPostupak.IdentBroj)=[ZaIdentBroj]) AND ((tTehPostupak.Varijanta)=[ZaVarijanta]) AND ((tTehPostupak.Operacija)=[ZaOperacija]));


-- =====================================================
-- Query: BarKodUnos_ProveraOperacijaZaRadnika
-- =====================================================
SELECT BarKodUnos_ProveraOperacijaZaRadnika_1K.IDRN, Count(BarKodUnos_ProveraOperacijaZaRadnika_1K.IDStavkeRN) AS BrojOperacija
FROM BarKodUnos_ProveraOperacijaZaRadnika_1K
GROUP BY BarKodUnos_ProveraOperacijaZaRadnika_1K.IDRN;


-- =====================================================
-- Query: BarKodUnos_ProveraOperacijaZaRadnika_1K
-- =====================================================
SELECT tRN.IDRN, tStavkeRN.IDStavkeRN
FROM tPristupMasini INNER JOIN (tRN INNER JOIN tStavkeRN ON tRN.IDRN = tStavkeRN.IDRN) ON tPristupMasini.RJgrupaRC = tStavkeRN.RJgrupaRC
WHERE (((tRN.IDPredmet)=[Forms]![Barkod_Unos]![IDPredmet]) AND ((tRN.IdentBroj)=[Forms]![Barkod_Unos]![IdentBroj]) AND ((tRN.Varijanta)=[Forms]![Barkod_Unos]![Varijanta]))
GROUP BY tRN.IDRN, tStavkeRN.IDStavkeRN, tPristupMasini.SifraRadnika
HAVING (((tPristupMasini.SifraRadnika)=[Forms]![Barkod_Unos]![SifraRadnika]));


-- =====================================================
-- Query: BarKodUnos_UnosOperacije
-- =====================================================
SELECT tStavkeRN.Operacija, tStavkeRN.RJgrupaRC
FROM tRN INNER JOIN (tPristupMasini INNER JOIN tStavkeRN ON tPristupMasini.RJgrupaRC = tStavkeRN.RJgrupaRC) ON tRN.IDRN = tStavkeRN.IDRN
WHERE (((tRN.IDPredmet)=[Forms]![Barkod_Unos]![IDPredmet]) AND ((tRN.IdentBroj)=[Forms]![Barkod_Unos]![IdentBroj]) AND ((tRN.Varijanta)=[Forms]![Barkod_Unos]![Varijanta]) AND ((tPristupMasini.SifraRadnika)=[Forms]![Barkod_Unos]![SifraRadnika]))
GROUP BY tStavkeRN.Operacija, tStavkeRN.RJgrupaRC;


-- =====================================================
-- Query: BarKodUnos_ZaIDPostupka
-- =====================================================
SELECT tTehPostupak.IDPostupka, tTehPostupak.SifraRadnika, tTehPostupak.IDPredmet, tTehPostupak.IdentBroj, tTehPostupak.Varijanta, tTehPostupak.PrnTimer, tTehPostupak.DatumIVremeUnosa, tTehPostupak.Operacija, tTehPostupak.RJgrupaRC, tTehPostupak.Toznaka, tTehPostupak.Komada, tTehPostupak.Potpis, tTehPostupak.SimbolRadnik, tTehPostupak.SimbolPostupak, tTehPostupak.SimbolOperacija, tTehPostupak.DatumIVremeZavrsetka, tTehPostupak.ZavrsenPostupak, tTehPostupak.Napomena, tRN.DatumUnosa, tRN.RokIzrade, tRN.BrojCrteza, tRN.NazivDela, Komitenti.Naziv
FROM Komitenti INNER JOIN (tRN INNER JOIN tTehPostupak ON (tRN.Varijanta = tTehPostupak.Varijanta) AND (tRN.IdentBroj = tTehPostupak.IdentBroj) AND (tRN.IDPredmet = tTehPostupak.IDPredmet)) ON Komitenti.Sifra = tRN.BBIDKomitent
WHERE (((tTehPostupak.IDPostupka)=[ZaIDPostupka]) AND ((tTehPostupak.ZavrsenPostupak)=False));


-- =====================================================
-- Query: BarKodUnos_ZatvoriPostupak
-- =====================================================
SELECT tTehPostupak.*
FROM tTehPostupak
WHERE (((tTehPostupak.IDPostupka)=[ZaIDPostupka]));


-- =====================================================
-- Query: Baze
-- =====================================================
SELECT BazeIFirme.IDBaze, BazeIFirme.TipBaze, BazeIFirme.Baza, BazeIFirme.ForsirajNoviLink, BazeIFirme.UserName, BazeIFirme.Password
FROM BazeIFirme
WHERE (((BazeIFirme.FirmaZaBaze)=F_FirmaZaBaze()));


-- =====================================================
-- Query: Baze_CheckLink_PonistiUTabelama
-- =====================================================
UPDATE BazeITabele SET BazeITabele.CheckLink = Null, BazeITabele.CurrentSourceDataBase = Null;


-- =====================================================
-- Query: BAZE_NapraviBazeZaNovuFirmu
-- =====================================================
INSERT INTO BazeIFirme ( FirmaZaBaze, IDBaze, TipBaze, Baza, ForsirajNoviLink )
SELECT [Forms]![Baze]![ComboFirmaZaBaze] AS Expr1, BazeIFirme.IDBaze, BazeIFirme.TipBaze, Replace([Baza],RootDirZaFirmu([Forms]![Baze]![ModelFirme]),RootDirZaFirmu([Forms]![Baze]![ComboFirmaZaBaze])) AS Expr2, BazeIFirme.ForsirajNoviLink
FROM BazeIFirme
WHERE (((BazeIFirme.FirmaZaBaze)=[Forms]![Baze]![ModelFirme]));


-- =====================================================
-- Query: Baze_NeispravniLinkoviZaFirmu
-- =====================================================
SELECT BazeIFirme.IDBaze, BazeIFirme.TipBaze, BazeITabele.Name, BazeITabele.SourceTableName, BazeIFirme.Baza AS TrebaDaBudeBaza, F_GetConnectionString([Name]) AS ASadaJe, InStr(";DATABASE=" & [Baza],F_GetConnectionString([Name])) AS DobarLink
FROM BazeIFirme INNER JOIN BazeITabele ON BazeIFirme.IDBaze = BazeITabele.IDBaze
WHERE (((InStr(";DATABASE=" & [Baza],F_GetConnectionString([Name])))=False) AND ((BazeIFirme.FirmaZaBaze)=[Forms]![Baze]![ComboFirmaZaBaze]));


-- =====================================================
-- Query: BAZE_PronadjiIZameni
-- =====================================================
UPDATE Baze_UpitZaFormu SET Baze_UpitZaFormu.Baza = ZameniSTR([Forms]![Baze]![Pronadji],[Forms]![Baze]![Zameni],[Baza])
WHERE (((Baze_UpitZaFormu.Baza) Like "*" & [Forms]![Baze]![Pronadji] & "*"));


-- =====================================================
-- Query: Baze_ProveraLinkova
-- =====================================================
SELECT BazeIFirme.IDBaze, BazeIFirme.TipBaze, BazeITabele.Name, BazeITabele.SourceTableName, BazeIFirme.Baza AS TrebaDaBudeBaza, BazeITabele.CurrentSourceDataBase AS ASadaJe, InStr(";DATABASE=" & [Baza],[CurrentSourceDataBase])>0 AS DobarLink
FROM BazeIFirme INNER JOIN BazeITabele ON BazeIFirme.IDBaze = BazeITabele.IDBaze
WHERE (((BazeIFirme.FirmaZaBaze)=[Forms]![Baze]![ComboFirmaZaBaze]));


-- =====================================================
-- Query: Baze_TEST
-- =====================================================
SELECT BazeIFirme.IDBaze, BazeIFirme.TipBaze, BazeIFirme.Baza, BazeIFirme.ForsirajNoviLink, BazeIFirme.UserName, BazeIFirme.Password
FROM BazeIFirme
WHERE (((BazeIFirme.FirmaZaBaze)=F_FirmaZaBaze()));


-- =====================================================
-- Query: Baze_Tipovi_APL_ExportUFIT
-- =====================================================
INSERT INTO Baze_Tipovi ( IDBaze, TipBaze )
SELECT Baze_Tipovi_APL.IDBaze, Baze_Tipovi_APL.TipBaze
FROM Baze_Tipovi_APL LEFT JOIN Baze_Tipovi ON Baze_Tipovi_APL.TipBaze = Baze_Tipovi.TipBaze
WHERE (((Baze_Tipovi.TipBaze) Is Null));


-- =====================================================
-- Query: Baze_Tipovi_APL_ImportIzFIT
-- =====================================================
INSERT INTO Baze_Tipovi_APL ( IDBaze, TipBaze )
SELECT Baze_Tipovi.IDBaze, Baze_Tipovi.TipBaze
FROM Baze_Tipovi_APL RIGHT JOIN Baze_Tipovi ON Baze_Tipovi_APL.TipBaze = Baze_Tipovi.TipBaze
WHERE (((Baze_Tipovi_APL.TipBaze) Is Null));


-- =====================================================
-- Query: Baze_UpitZaFormu
-- =====================================================
SELECT BazeIFirme.*, FileExists([Baza]) AS PostojiFajl, DirExists([Baza]) AS PostojiDir, CLng(DCount("*","BazeITabele","[IDBaze] = " & [IDBaze])) AS UkupnoT, CLng(DCount("*","Baze_ProveraLinkova","[IDBaze] = " & [IDBaze] & "And [DobarLink] = True")) AS IspravnoT, CLng(DCount("*","Baze_ProveraLinkova","[IDBaze] = " & [IDBaze] & "And [DobarLink] = False")) AS NeispravnoT
FROM BazeIFirme
WHERE (((BazeIFirme.FirmaZaBaze)=[Forms]![Baze]![ComboFirmaZaBaze]) AND ((ZadovoljenUslovZaBoolVal([ForsirajNoviLink],[Forms]![Baze]![ZaForsirajNoviLink]))=True))
ORDER BY BazeIFirme.IDBaze;


-- =====================================================
-- Query: BazeITabele_APL_ExportUFIT
-- =====================================================
INSERT INTO BazeITabele ( ID, IDBaze, SysFitLevel, Name, SourceTableName, SourceType, CheckLink, CurrentSourceDataBase, RedBrojZaBrisanje, CheckModDel, WhereUslov )
SELECT BazeITabele_APL.ID, BazeITabele_APL.IDBaze, BazeITabele_APL.SysFitLevel, BazeITabele_APL.Name, BazeITabele_APL.SourceTableName, BazeITabele_APL.SourceType, BazeITabele_APL.CheckLink, BazeITabele_APL.CurrentSourceDataBase, BazeITabele_APL.RedBrojZaBrisanje, BazeITabele_APL.CheckModDel, BazeITabele_APL.WhereUslov
FROM BazeITabele_APL LEFT JOIN BazeITabele ON (BazeITabele_APL.SourceTableName = BazeITabele.SourceTableName) AND (BazeITabele_APL.Name = BazeITabele.Name)
WHERE (((BazeITabele.ID) Is Null));


-- =====================================================
-- Query: BazeITabele_APL_ImportIzFIT
-- =====================================================
INSERT INTO BazeITabele_APL ( ID, IDBaze, SysFitLevel, Name, SourceTableName, SourceType, CheckLink, CurrentSourceDataBase, RedBrojZaBrisanje, CheckModDel, WhereUslov )
SELECT BazeITabele.ID, BazeITabele.IDBaze, BazeITabele.SysFitLevel, BazeITabele.Name, BazeITabele.SourceTableName, BazeITabele.SourceType, BazeITabele.CheckLink, BazeITabele.CurrentSourceDataBase, BazeITabele.RedBrojZaBrisanje, BazeITabele.CheckModDel, BazeITabele.WhereUslov
FROM BazeITabele_APL RIGHT JOIN BazeITabele ON (BazeITabele_APL.SourceTableName = BazeITabele.SourceTableName) AND (BazeITabele_APL.Name = BazeITabele.Name)
WHERE (((BazeITabele_APL.ID) Is Null));


-- =====================================================
-- Query: BazeITabele_KopirajUNovu
-- =====================================================
INSERT INTO BazeITabele ( ID, IDBaze, Name, SourceTableName )
SELECT [ID]+110000 AS Expr2, 110 AS Expr1, "-" & [Name] AS Expr3, BazeITabele.SourceTableName
FROM BazeITabele
WHERE (((BazeITabele.IDBaze)=4));


-- =====================================================
-- Query: BazeITabele_PrepisiIzBazeUBazu
-- =====================================================
INSERT INTO BazeITabele ( ID, IDBaze, Name, SourceTableName, CheckLink, CurrentSourceDataBase )
SELECT [ID]+[BazniIndex] AS Expr4, [UIDBazu] AS Expr1, [PrefixName] & [Name] AS Expr2, [PrefixSourceTableName] & [SourceTableName] AS Expr3, BazeITabele.CheckLink, BazeITabele.CurrentSourceDataBase
FROM BazeITabele
WHERE (((BazeITabele.IDBaze)=[IzIDBaze]));


-- =====================================================
-- Query: BazeITabele_SveLinkovaneTabele_ExportUFIT
-- =====================================================
INSERT INTO BazeITabele ( IDBaze, ID, Name, SourceTableName, CurrentSourceDataBase, CheckLink )
SELECT SveLinkovaneTabele.IDBaze, SveLinkovaneTabele.ID_ZaUpis, SveLinkovaneTabele.Name, SveLinkovaneTabele.SourceTableName, SveLinkovaneTabele.Database, SveLinkovaneTabele.Status
FROM SveLinkovaneTabele;


-- =====================================================
-- Query: BazeITabele_UpdateName
-- =====================================================
UPDATE BazeITabele SET BazeITabele.Name = [DodajPrefix] & [Name]
WHERE (((BazeITabele.IDBaze)=[ZaIDBaze]));


-- =====================================================
-- Query: BazeITabele_UpdateSourceTableName
-- =====================================================
UPDATE BazeITabele SET BazeITabele.SourceTableName = [DodajPrefix] & [SourceTableName]
WHERE (((BazeITabele.IDBaze)=[ZaIDBaze]));


-- =====================================================
-- Query: BazeITabele_UpisiNovuSQLBazu
-- =====================================================
UPDATE Baze_UpitZaFormu AS tbl SET tbl.Baza = "ODBC;" & [Forms]![Baze]![CNNString]
WHERE (((tbl.IDBaze)=-2 Or (tbl.IDBaze)=0 Or (tbl.IDBaze)=4 Or (tbl.IDBaze)=5 Or (tbl.IDBaze)=28 Or (tbl.IDBaze)=31 Or (tbl.IDBaze)=500 Or (tbl.IDBaze)=45 Or (tbl.IDBaze)=35));


-- =====================================================
-- Query: BB_CeneZaliha
-- =====================================================
SELECT BB_CeneZaliha1K.[Sifra artikla] AS IDArtikal, BB_CeneZaliha1K.ProsecnaVPC, BB_CeneZaliha1K.ProsecnaNC, Nz([Kalkulativna VP cena],0) AS PoslednjaKLVPC, Nz([EXT_T_Robne stavke]![Nabavna cena - neto]+[EXT_T_Robne stavke]![Zavisni trosak - sopstveni]+[EXT_T_Robne stavke]![Zavisni trosak - dobavljac],0) AS PoslednjaKLNC, Not IsNull([IDStavke]) AS ImaPoslednjuKL, BB_CeneZaliha1K.ZalihaKolicine
FROM BB_CeneZaliha1K LEFT JOIN [EXT_T_Robne stavke] ON BB_CeneZaliha1K.MaxOfIDStavke = [EXT_T_Robne stavke].IDStavke;


-- =====================================================
-- Query: BB_CeneZaliha1K
-- =====================================================
SELECT DISTINCTROW [EXT_T_Robne stavke].[Sifra artikla], Sum(IIf([Ulaz],[Kolicina]*[Kalkulativna VP cena],-[Kolicina]*[Kalkulativna VP cena])) AS ZalihaVPVrednosti, Sum(IIf([Ulaz],[Kolicina]*([EXT_T_Robne stavke]![Nabavna cena - neto]+[EXT_T_Robne stavke]![Zavisni trosak - sopstveni]+[EXT_T_Robne stavke]![Zavisni trosak - dobavljac]),-[Kolicina]*[EXT_T_Robne stavke]![Nabavna cena - neto])) AS ZalihaNabVrednosti, Sum(IIf([Ulaz],[Kolicina],-[Kolicina])) AS ZalihaKolicine, Round(IIf([Zalihakolicine]<>0,[ZalihaVPVrednosti]/[ZalihaKolicine],0),2) AS ProsecnaVPC, Round(IIf([Zalihakolicine]<>0,[ZalihaNabVrednosti]/[ZalihaKolicine],0),2) AS ProsecnaNC, Max(IIf([Ulaz] And [Kolicina]>0,[IDStavke],0)) AS MaxOfIDStavke
FROM [EXT_T_Robna dokumenta] INNER JOIN [EXT_T_Robne stavke] ON [EXT_T_Robna dokumenta].IDDok = [EXT_T_Robne stavke].IDDok
WHERE ((([EXT_T_Robna dokumenta].[Vrsta dokumenta])<>"KODJ") AND (([EXT_T_Robna dokumenta].Level)=0))
GROUP BY [EXT_T_Robne stavke].[Sifra artikla];


-- =====================================================
-- Query: BB_RezervisaneKolicine
-- =====================================================
SELECT [EXT_T_Robne stavke].[Sifra artikla], Sum([EXT_T_Robne stavke].Kolicina) AS RezervisanaKolicina
FROM [EXT_T_Robna dokumenta] INNER JOIN [EXT_T_Robne stavke] ON [EXT_T_Robna dokumenta].IDDok = [EXT_T_Robne stavke].IDDok
WHERE ((([EXT_T_Robna dokumenta].Ulaz)=No) AND (([EXT_T_Robna dokumenta].Rezervisi)=True) AND (([EXT_T_Robna dokumenta].Level)=250))
GROUP BY [EXT_T_Robne stavke].[Sifra artikla];


-- =====================================================
-- Query: BB_StanjeKolicinaNaDan
-- =====================================================
SELECT DISTINCTROW [EXT_T_Robne stavke].[Sifra artikla], Sum(IIf([Ulaz],[Kolicina],-[Kolicina])) AS PlusMinusKolicina
FROM [EXT_T_Robna dokumenta] INNER JOIN [EXT_T_Robne stavke] ON [EXT_T_Robna dokumenta].IDDok = [EXT_T_Robne stavke].IDDok
WHERE ((([EXT_T_Robna dokumenta].[Datum dokumenta])<=Date()) AND (([EXT_T_Robna dokumenta].[Vrsta dokumenta])<>"KODJ") AND (([EXT_T_Robna dokumenta].Level)=0))
GROUP BY [EXT_T_Robne stavke].[Sifra artikla];


-- =====================================================
-- Query: BrojProfakturaPoVrstama
-- =====================================================
SELECT Count(Profakture.IDDok) AS CountOfIDDok, Profakture.[Vrsta dokumenta]
FROM Profakture
GROUP BY Profakture.[Vrsta dokumenta];


-- =====================================================
-- Query: CFG_Apl_Parametri_DEF_ExportU_CFG_Global
-- =====================================================
INSERT INTO CFG_Global ( Parametar, Vrednost, Tip, Opis )
SELECT CFG_Apl_Parametri_DEF_PoUslovu.Parametar, CFG_Apl_Parametri_DEF_PoUslovu.Vrednost, CFG_Apl_Parametri_DEF_PoUslovu.Tip, CFG_Apl_Parametri_DEF_PoUslovu.Opis
FROM CFG_Apl_Parametri_DEF_PoUslovu
WHERE (((ParametarPostojiUTabeli("CFG_Global",[Parametar]))=False));


-- =====================================================
-- Query: CFG_Apl_Parametri_DEF_ExportU_CFG_Lokal
-- =====================================================
INSERT INTO CFG_Lokal ( Parametar, Vrednost, Tip, Opis )
SELECT CFG_Apl_Parametri_DEF_PoUslovu.Parametar, CFG_Apl_Parametri_DEF_PoUslovu.Vrednost, CFG_Apl_Parametri_DEF_PoUslovu.Tip, CFG_Apl_Parametri_DEF_PoUslovu.Opis
FROM CFG_Apl_Parametri_DEF_PoUslovu
WHERE (((ParametarPostojiUTabeli("CFG_Lokal",[Parametar]))=False));


-- =====================================================
-- Query: CFG_Apl_Parametri_DEF_PoUslovu
-- =====================================================
SELECT CFG_Apl_Parametri_DEF.*, ParametarUKategoriji([CFG_Apl_Parametri_DEF].[Parametar],[Forms]![CFGReadWrite]![ZaKatPar]) AS ParUKat, ParametarPostojiUTabeli("CFG_Lokal",[Parametar],True,[Forms]![CFGReadWrite]![ZaIDFirma]) AS ImaLokal, ParametarPostojiUTabeli("CFG_Global",[Parametar],True,[Forms]![CFGReadWrite]![ZaIDFirma]) AS ImaGlobal
FROM CFG_Apl_Parametri_DEF
WHERE (((ParametarUKategoriji([CFG_Apl_Parametri_DEF].[Parametar],[Forms]![CFGReadWrite]![ZaKatPar]))=True) AND ((CFG_Apl_Parametri_DEF.Parametar) Like "*" & Nz([Forms]![CFGReadWrite]![ZaParametar],"*") & "*") AND ((CStr(Nz([CFG_Apl_Parametri_DEF].[Vrednost],"<<Null>>"))) Like "*" & CStr(Nz([Forms]![CFGReadWrite]![ZaVrednostParametra],"*")) & "*") AND ((CStr(Nz([CFG_Apl_Parametri_DEF].[Opis],"<<Null>>"))) Like "*" & CStr(Nz([Forms]![CFGReadWrite]![ZaOpis],"*")) & "*") AND ((ZadovoljenUslovZaBoolVal([CFG_Apl_Parametri_DEF].[GlobalPar],[forms]![CFGReadWrite]![ZaDefGlobal]))=True) AND ((ZadovoljenUslovZaBoolVal([CFG_Apl_Parametri_DEF].[LokalPar],[forms]![CFGReadWrite]![ZaDefLokal]))=True))
ORDER BY CFG_Apl_Parametri_DEF.Parametar;


-- =====================================================
-- Query: CFG_DozvoljeneVrednosti
-- =====================================================
SELECT CFG_Apl_Parametri_DozvoljeneVrednosti.*, ParametarUKategoriji([CFG_Apl_Parametri_DozvoljeneVrednosti].[Parametar],[Forms]![CFGReadWrite]![ZaKatPar]) AS ParUKat, CFG_Apl_Parametri_DEF.Tip, CFG_Apl_Parametri_DEF.Opis
FROM CFG_Apl_Parametri_DEF INNER JOIN CFG_Apl_Parametri_DozvoljeneVrednosti ON CFG_Apl_Parametri_DEF.Parametar = CFG_Apl_Parametri_DozvoljeneVrednosti.Parametar
WHERE (((ParametarUKategoriji([CFG_Apl_Parametri_DozvoljeneVrednosti].[Parametar],[Forms]![CFGReadWrite]![ZaKatPar]))=True) AND ((CFG_Apl_Parametri_DozvoljeneVrednosti.Parametar) Like "*" & Nz([Forms]![CFGReadWrite]![ZaParametar],"*") & "*") AND ((ZadovoljenUslovZaBoolVal([CFG_Apl_Parametri_DEF].[GlobalPar],[Forms]![CFGReadWrite]![ZaDefGlobal]))=True) AND ((ZadovoljenUslovZaBoolVal([CFG_Apl_Parametri_DEF].[LokalPar],[Forms]![CFGReadWrite]![ZaDefLokal]))=True) AND ((CStr(Nz([CFG_Apl_Parametri_DozvoljeneVrednosti].[Vrednost],"<<Null>>"))) Like "*" & CStr(Nz([Forms]![CFGReadWrite]![ZaVrednostParametra],"*")) & "*"))
ORDER BY CFG_Apl_Parametri_DozvoljeneVrednosti.Parametar, CFG_Apl_Parametri_DEF.Parametar, DoChLeft(Left(Nz([CFG_Apl_Parametri_DozvoljeneVrednosti].[Vrednost],"<<Null>>"),100),100,"0");


-- =====================================================
-- Query: CFG_DozvoljeneVrednosti_FULL
-- =====================================================
SELECT CFG_Apl_Parametri_DozvoljeneVrednosti.*, ParametarUKategoriji([CFG_Apl_Parametri_DozvoljeneVrednosti].[Parametar],[Forms]![CFGReadWrite]![ZaKatPar]) AS ParUKat, CFG_Apl_Parametri_DEF.Tip, CFG_Apl_Parametri_DEF.Opis
FROM CFG_Apl_Parametri_DEF INNER JOIN CFG_Apl_Parametri_DozvoljeneVrednosti ON CFG_Apl_Parametri_DEF.Parametar = CFG_Apl_Parametri_DozvoljeneVrednosti.Parametar
WHERE (((ParametarUKategoriji([CFG_Apl_Parametri_DozvoljeneVrednosti].[Parametar],[Forms]![CFGReadWrite]![ZaKatPar]))=True) AND ((CFG_Apl_Parametri_DozvoljeneVrednosti.Parametar) Like "*" & Nz([Forms]![CFGReadWrite]![ZaParametar],"*") & "*") AND ((ZadovoljenUslovZaBoolVal(ParametarPostojiUTabeli("CFG_Lokal",[CFG_Apl_Parametri_DEF]![Parametar],True,[Forms]![CFGReadWrite]![ZaIDFirma]),[Forms]![CFGReadWrite]![ZaImaLokal]))=True) AND ((ZadovoljenUslovZaBoolVal(ParametarPostojiUTabeli("CFG_Global",[CFG_Apl_Parametri_DEF]![Parametar],True,[Forms]![CFGReadWrite]![ZaIDFirma]),[Forms]![CFGReadWrite]![ZaImaGlobal]))=True) AND ((ZadovoljenUslovZaBoolVal([CFG_Apl_Parametri_DEF].[GlobalPar],[Forms]![CFGReadWrite]![ZaDefGlobal]))=True) AND ((ZadovoljenUslovZaBoolVal([CFG_Apl_Parametri_DEF].[LokalPar],[Forms]![CFGReadWrite]![ZaDefLokal]))=True) AND ((CStr(Nz([CFG_Apl_Parametri_DozvoljeneVrednosti].[Vrednost],"<<Null>>"))) Like "*" & CStr(Nz([Forms]![CFGReadWrite]![ZaVrednostParametra],"*")) & "*"))
ORDER BY CFG_Apl_Parametri_DozvoljeneVrednosti.Parametar, CFG_Apl_Parametri_DEF.Parametar, DoChLeft(Left(Nz([CFG_Apl_Parametri_DozvoljeneVrednosti].[Vrednost],"<<Null>>"),100),100,"0");


-- =====================================================
-- Query: CFG_Global_ImportUAPL_DEF
-- =====================================================
INSERT INTO CFG_Apl_Parametri_DEF ( Parametar, Vrednost, Tip, Opis, GlobalPar )
SELECT CFG_Global.Parametar, CFG_Global.Vrednost, CFG_Global.Tip, CFG_Global.Opis, True AS Expr1
FROM CFG_Global LEFT JOIN CFG_Apl_Parametri_DEF ON CFG_Global.Parametar = CFG_Apl_Parametri_DEF.Parametar
WHERE (((CFG_Global.Parametar) Like "*" & Nz([Forms]![CFGReadWrite]![ZaParametar],"*") & "*") AND ((CFG_Apl_Parametri_DEF.Parametar) Is Null) AND ((CStr(Nz([CFG_Global].[Vrednost],"<<NULL>>"))) Like "*" & CStr(Nz([Forms]![CFGReadWrite]![ZaVrednostParametra],"*")) & "*"));


-- =====================================================
-- Query: CFG_Global_ImportUAPL_DozvoljeneVrednosti
-- =====================================================
INSERT INTO CFG_Apl_Parametri_DozvoljeneVrednosti ( Parametar, Vrednost )
SELECT CFG_Global.Parametar, CFG_Global.Vrednost
FROM CFG_Global LEFT JOIN CFG_Apl_Parametri_DozvoljeneVrednosti ON (left(CFG_Global.Vrednost,64) = left(CFG_Apl_Parametri_DozvoljeneVrednosti.Vrednost,64)) AND (CFG_Global.Parametar = CFG_Apl_Parametri_DozvoljeneVrednosti.Parametar)
WHERE (((CFG_Apl_Parametri_DozvoljeneVrednosti.Parametar) Is Null)) OR (((CFG_Apl_Parametri_DozvoljeneVrednosti.Vrednost) Is Null));


-- =====================================================
-- Query: CFG_Lokal_ImportUAPL_DEF
-- =====================================================
INSERT INTO CFG_Apl_Parametri_DEF ( Parametar, Vrednost, Tip, Opis, GlobalPar )
SELECT CFG_Lokal.Parametar, CFG_Lokal.Vrednost, CFG_Lokal.Tip, CFG_Lokal.Opis, True AS Expr1
FROM CFG_Lokal LEFT JOIN CFG_Apl_Parametri_DEF ON CFG_Lokal.Parametar = CFG_Apl_Parametri_DEF.Parametar
WHERE (((CFG_Lokal.Parametar) Like "*" & Nz([Forms]![CFGReadWrite]![ZaParametar],"*") & "*") AND ((CFG_Apl_Parametri_DEF.Parametar) Is Null) AND ((CStr(Nz([CFG_Lokal].[Vrednost],"<<NULL>>"))) Like "*" & CStr(Nz([Forms]![CFGReadWrite]![ZaVrednostParametra],"*")) & "*"));


-- =====================================================
-- Query: CFG_Lokal_ImportUAPL_DozvoljeneVrednosti
-- =====================================================
INSERT INTO CFG_Apl_Parametri_DozvoljeneVrednosti ( Parametar, Vrednost )
SELECT CFG_Lokal.Parametar, CFG_Lokal.Vrednost
FROM CFG_Lokal LEFT JOIN CFG_Apl_Parametri_DozvoljeneVrednosti ON (CFG_Lokal.Parametar = CFG_Apl_Parametri_DozvoljeneVrednosti.Parametar) AND (left(CFG_Lokal.Vrednost,64) = left(CFG_Apl_Parametri_DozvoljeneVrednosti.Vrednost,64))
WHERE (((CFG_Apl_Parametri_DozvoljeneVrednosti.Parametar) Is Null)) OR (((CFG_Apl_Parametri_DozvoljeneVrednosti.Vrednost) Is Null));


-- =====================================================
-- Query: Copy Of PDM_GlavniDokument_TEST
-- =====================================================
SELECT h.DocID AS Glavni_DocID, h.Attr_Revision AS Glavni_Revision, r.DocID AS Referenca_DocID, r.Attr_Revision AS Referenca_Revision, r.Attr_Reference_Count
FROM PDM_Document AS h LEFT JOIN PDM_Document AS r ON h.DocID = r.ParentDocID
WHERE ((Not (r.DocID) Is Null))
ORDER BY h.DocID, r.DocID;


-- =====================================================
-- Query: DetaljanPregledPostupkaPoRN
-- =====================================================
SELECT tRN.*, IIf(IsNull([PrvaNezavrsenaOperacijasaRJPoRN].[IDRN]),"Završeno",[PrvaNezavrsenaOperacijasaRJPoRN].[OperacijaDoKojeSeStiglo]) AS OperacijaDoKojeSeStiglo_, IIf(IsNull([PrvaNezavrsenaOperacijasaRJPoRN].[IDRN]),"Završeno",[PrvaNezavrsenaOperacijasaRJPoRN].[RJDoKojeSeStiglo]) AS RJDoKojeSeStiglo_, IIf(IsNull([PrvaNezavrsenaOperacijasaRJPoRN].[IDRN]),"Završeno",[PrvaNezavrsenaOperacijasaRJPoRN].[NazivGrupeRC]) AS NazivGrupeRC_, SviKrajPostupciSaBrojemKomada.Razlika AS BrojKomadaZaZavrsnuKontrolu, SviPostupciSaUtrosenimVremenom.UtrosenoVreme, SviPostupciSaUtrosenimVremenom.NormiranoVreme, Predmeti.BrojPredmeta, Komitenti.Naziv
FROM ((((Komitenti INNER JOIN tRN ON Komitenti.Sifra = tRN.BBIDKomitent) INNER JOIN Predmeti ON tRN.IDPredmet = Predmeti.IDPredmet) LEFT JOIN PrvaNezavrsenaOperacijasaRJPoRN ON tRN.IDRN = PrvaNezavrsenaOperacijasaRJPoRN.IDRN) INNER JOIN SviKrajPostupciSaBrojemKomada ON tRN.IDRN = SviKrajPostupciSaBrojemKomada.IDRN) INNER JOIN SviPostupciSaUtrosenimVremenom ON tRN.IDRN = SviPostupciSaUtrosenimVremenom.IDRN
WHERE (((CStr([tRN].[IdentBroj])) Like CStr(Nz([Forms]![RNPregledZag]![ZaIdentBroj],"*"))) AND ((CStr([tRN].[IDPredmet])) Like CStr(Nz([Forms]![RNPregledZag]![ZaPredmet],"*"))) AND ((CStr([tRn].[Varijanta])) Like CStr(Nz([Forms]![RNPregledZag]![ZaVarijanta],"*"))) AND ((CStr([BBIDKomitent])) Like CStr(Nz([Forms]![RNPregledZag]![ZaKomitenta],"*"))) AND ((tRN.DatumUnosa) Between IIf(IsNull([Forms]![RNPregledZag]![OdDatumaNaloga]),#1/1/1991#,[Forms]![RNPregledZag]![OdDatumaNaloga]) And IIf(IsNull([Forms]![RNPregledZag]![DoDatumaNaloga]),#12/31/2099#,[Forms]![RNPregledZag]![DoDatumaNaloga])) AND ((tRN.BBDatumOtvaranja) Between IIf(IsNull([Forms]![RNPregledZag]![OdDatumaPredmeta]),#1/1/1991#,[Forms]![RNPregledZag]![OdDatumaPredmeta]) And IIf(IsNull([Forms]![RNPregledZag]![DoDatumaPredmeta]),#12/31/2099#,[Forms]![RNPregledZag]![DoDatumaPredmeta])) AND ((IIf([Razlika]=0,True,False)) Like CStr(Nz([Forms]![RNPregledZag]![ZavrsenNalog],"*"))))
ORDER BY Predmeti.BrojPredmeta, tRN.IdentBroj;


-- =====================================================
-- Query: DetaljanPregledPostupkaPoRNIRadnicima
-- =====================================================
SELECT tRN.*, SviPostupciSaUtrosenimVremenomPoRadniku.SifraRadnika, tRadnici.Radnik, SviPostupciSaUtrosenimVremenomPoRadniku.Razlika AS BrojKomadaZaZavrsnuKontrolu, SviPostupciSaUtrosenimVremenomPoRadniku.UtrosenoVreme, SviPostupciSaUtrosenimVremenomPoRadniku.NormiranoVreme, Predmeti.BrojPredmeta, Komitenti.Naziv, tRadnici.ImeIPrezime
FROM (((Komitenti INNER JOIN tRN ON Komitenti.Sifra = tRN.BBIDKomitent) INNER JOIN Predmeti ON tRN.IDPredmet = Predmeti.IDPredmet) INNER JOIN SviPostupciSaUtrosenimVremenomPoRadniku ON tRN.IDRN = SviPostupciSaUtrosenimVremenomPoRadniku.IDRN) INNER JOIN tRadnici ON SviPostupciSaUtrosenimVremenomPoRadniku.SifraRadnika = tRadnici.SifraRadnika
WHERE (((SviPostupciSaUtrosenimVremenomPoRadniku.SifraRadnika)=[Forms]![RNPregledZag]![ZaRadnika]) AND ((CStr([tRN].[IdentBroj])) Like CStr(Nz([Forms]![RNPregledZag]![ZaIdentBroj],"*"))) AND ((CStr([tRN].[IDPredmet])) Like CStr(Nz([Forms]![RNPregledZag]![ZaPredmet],"*"))) AND ((CStr([tRn].[Varijanta])) Like CStr(Nz([Forms]![RNPregledZag]![ZaVarijanta],"*"))) AND ((CStr([BBIDKomitent])) Like CStr(Nz([Forms]![RNPregledZag]![ZaKomitenta],"*"))) AND ((tRN.DatumUnosa) Between IIf(IsNull([Forms]![RNPregledZag]![OdDatumaNaloga]),#1/1/1991#,[Forms]![RNPregledZag]![OdDatumaNaloga]) And IIf(IsNull([Forms]![RNPregledZag]![DoDatumaNaloga]),#12/31/2099#,[Forms]![RNPregledZag]![DoDatumaNaloga])) AND ((tRN.BBDatumOtvaranja) Between IIf(IsNull([Forms]![RNPregledZag]![OdDatumaPredmeta]),#1/1/1991#,[Forms]![RNPregledZag]![OdDatumaPredmeta]) And IIf(IsNull([Forms]![RNPregledZag]![DoDatumaPredmeta]),#12/31/2099#,[Forms]![RNPregledZag]![DoDatumaPredmeta])))
ORDER BY Predmeti.BrojPredmeta, tRN.IdentBroj;


-- =====================================================
-- Query: DetaljanPregledPostupkaPoRNIRadniku
-- =====================================================
SELECT tRN.*, SviPostupciSaBrojemKomadaPoRadniku.Operacija, SviPostupciSaUtrosenimVremenomPoRadniku.RJgrupaRC, tOperacije.NazivGrupeRC, SviPostupciSaBrojemKomadaPoRadniku.Razlika AS BrojKomadaZaZavrsnuKontrolu, SviPostupciSaUtrosenimVremenomPoRadniku.UtrosenoVreme, SviPostupciSaUtrosenimVremenomPoRadniku.NormiranoVreme, Predmeti.BrojPredmeta, Komitenti.Naziv, IIf([PreostaloVreme_]=0,0,[PreostaloVreme_]+[VremePripreme]) AS PreostaloVreme
FROM tOperacije INNER JOIN ((((Komitenti INNER JOIN tRN ON Komitenti.Sifra = tRN.BBIDKomitent) INNER JOIN Predmeti ON tRN.IDPredmet = Predmeti.IDPredmet) INNER JOIN SviPostupciSaUtrosenimVremenomPoRadniku ON tRN.IDRN = SviPostupciSaUtrosenimVremenomPoRadniku.IDRN) INNER JOIN SviPostupciSaBrojemKomadaPoRadniku ON (SviPostupciSaUtrosenimVremenomPoRadniku.Operacija = SviPostupciSaBrojemKomadaPoRadniku.Operacija) AND (SviPostupciSaUtrosenimVremenomPoRadniku.RJgrupaRC = SviPostupciSaBrojemKomadaPoRadniku.RJgrupaRC) AND (tRN.IDRN = SviPostupciSaBrojemKomadaPoRadniku.IDRN)) ON tOperacije.RJgrupaRC = SviPostupciSaBrojemKomadaPoRadniku.RJgrupaRC
WHERE (((CStr([tRN].[IdentBroj])) Like CStr(Nz([Forms]![RNPregledZag]![ZaIdentBroj],"*"))) AND ((CStr([tRN].[IDPredmet])) Like CStr(Nz([Forms]![RNPregledZag]![ZaPredmet],"*"))) AND ((CStr([tRn].[Varijanta])) Like CStr(Nz([Forms]![RNPregledZag]![ZaVarijanta],"*"))) AND ((CStr([BBIDKomitent])) Like CStr(Nz([Forms]![RNPregledZag]![ZaKomitenta],"*"))) AND ((tRN.DatumUnosa) Between IIf(IsNull([Forms]![RNPregledZag]![OdDatumaNaloga]),#1/1/1991#,[Forms]![RNPregledZag]![OdDatumaNaloga]) And IIf(IsNull([Forms]![RNPregledZag]![DoDatumaNaloga]),#12/31/2099#,[Forms]![RNPregledZag]![DoDatumaNaloga])) AND ((tRN.BBDatumOtvaranja) Between IIf(IsNull([Forms]![RNPregledZag]![OdDatumaPredmeta]),#1/1/1991#,[Forms]![RNPregledZag]![OdDatumaPredmeta]) And IIf(IsNull([Forms]![RNPregledZag]![DoDatumaPredmeta]),#12/31/2099#,[Forms]![RNPregledZag]![DoDatumaPredmeta])) AND ((IIf([PreostaloVreme_]=0,True,False)) Like CStr(Nz([Forms]![RNPregledZag]![ZavrsenNalog],"*"))))
ORDER BY SviPostupciSaBrojemKomadaPoRadniku.Operacija, Predmeti.BrojPredmeta, tRN.IdentBroj;


-- =====================================================
-- Query: DetaljanPregledPostupkaPoRNIRJ
-- =====================================================
SELECT tRN.*, SviPostupciSaBrojemKomada.Operacija, SviPostupciSaUtrosenimVremenomPoRJ.RJgrupaRC, tOperacije.NazivGrupeRC, SviPostupciSaBrojemKomada.Razlika AS BrojKomadaZaZavrsnuKontrolu, SviPostupciSaUtrosenimVremenomPoRJ.UtrosenoVreme, SviPostupciSaUtrosenimVremenomPoRJ.NormiranoVreme, Predmeti.BrojPredmeta, Komitenti.Naziv, IIf([PreostaloVreme_]=0,0,[PreostaloVreme_]+[VremePripreme]) AS PreostaloVreme
FROM ((((Komitenti INNER JOIN tRN ON Komitenti.Sifra = tRN.BBIDKomitent) INNER JOIN Predmeti ON tRN.IDPredmet = Predmeti.IDPredmet) INNER JOIN SviPostupciSaBrojemKomada ON tRN.IDRN = SviPostupciSaBrojemKomada.IDRN) INNER JOIN SviPostupciSaUtrosenimVremenomPoRJ ON (SviPostupciSaUtrosenimVremenomPoRJ.Operacija = SviPostupciSaBrojemKomada.Operacija) AND (SviPostupciSaBrojemKomada.RJgrupaRC = SviPostupciSaUtrosenimVremenomPoRJ.RJgrupaRC) AND (tRN.IDRN = SviPostupciSaUtrosenimVremenomPoRJ.IDRN)) INNER JOIN tOperacije ON SviPostupciSaBrojemKomada.RJgrupaRC = tOperacije.RJgrupaRC
WHERE (((CStr([tRN].[IdentBroj])) Like CStr(Nz([Forms]![RNPregledZag]![ZaIdentBroj],"*"))) AND ((CStr([tRN].[IDPredmet])) Like CStr(Nz([Forms]![RNPregledZag]![ZaPredmet],"*"))) AND ((CStr([tRn].[Varijanta])) Like CStr(Nz([Forms]![RNPregledZag]![ZaVarijanta],"*"))) AND ((CStr([BBIDKomitent])) Like CStr(Nz([Forms]![RNPregledZag]![ZaKomitenta],"*"))) AND ((tRN.DatumUnosa) Between IIf(IsNull([Forms]![RNPregledZag]![OdDatumaNaloga]),#1/1/1991#,[Forms]![RNPregledZag]![OdDatumaNaloga]) And IIf(IsNull([Forms]![RNPregledZag]![DoDatumaNaloga]),#12/31/2099#,[Forms]![RNPregledZag]![DoDatumaNaloga])) AND ((tRN.BBDatumOtvaranja) Between IIf(IsNull([Forms]![RNPregledZag]![OdDatumaPredmeta]),#1/1/1991#,[Forms]![RNPregledZag]![OdDatumaPredmeta]) And IIf(IsNull([Forms]![RNPregledZag]![DoDatumaPredmeta]),#12/31/2099#,[Forms]![RNPregledZag]![DoDatumaPredmeta])) AND ((IIf([PreostaloVreme_]=0,True,False)) Like CStr(Nz([Forms]![RNPregledZag]![ZavrsenNalog],"*"))))
ORDER BY Predmeti.BrojPredmeta, tRN.IdentBroj, SviPostupciSaBrojemKomada.Operacija;


-- =====================================================
-- Query: DetaljnoStavkeRN
-- =====================================================
SELECT tRN.IDRN, tRN.IDPredmet, tRN.IdentBroj, tRN.Varijanta, tStavkeRN.Operacija, tStavkeRN.RJgrupaRC, tRN.Komada, [Tpz]+([Tk]*[Komada]) AS UkupnoVreme, tStavkeRN.Tk AS VremePoKomadu, tStavkeRN.Tpz AS VremePripreme
FROM tRN INNER JOIN tStavkeRN ON tRN.IDRN = tStavkeRN.IDRN;


-- =====================================================
-- Query: ftPregledPotrebnihTopLevelKomponentiZaCrtez
-- =====================================================
SELECT * FROM ftPregledPotrebnihKomponentiZaCrtezIKolicinu( 11578, 1, 1)

-- =====================================================
-- Query: IzabranitTehPostupak
-- =====================================================
SELECT tTehPostupak.*
FROM tTehPostupak
WHERE (((DatumUIntervalu(Nz([DatumIVremeUnosa],#1/1/1991#),[Forms]![PregledPoPostupcima]![OdDatumaPostupka],[Forms]![PregledPoPostupcima]![DoDatumaPostupka]))=True) AND ((DatumUIntervalu(Nz([DatumIVremeZavrsetka],#12/31/2099#),[Forms]![PregledPoPostupcima]![OdDatumaPostupkaKraj],[Forms]![PregledPoPostupcima]![DoDatumaPostupkaKraj]))=True) AND ((CStr(Nz([tTehPostupak].[SifraRadnika],-1))) Like CStr(Nz([Forms]![PregledPoPostupcima]![ZaRadnika],"*"))));


-- =====================================================
-- Query: IzborRadnikaZaDaljiRad
-- =====================================================
SELECT tTehPostupak.SifraRadnika, tRadnici.Radnik, tRadnici.ImeIPrezime
FROM tVrsteRadnika INNER JOIN (tRadnici INNER JOIN tTehPostupak ON tRadnici.SifraRadnika = tTehPostupak.SifraRadnika) ON tVrsteRadnika.IDVrsteRadnika = tRadnici.IDVrsteRadnika
WHERE (((tTehPostupak.ZavrsenPostupak)=False) AND ((tVrsteRadnika.DodatnaOvlasenja)=True))
GROUP BY tTehPostupak.SifraRadnika, tRadnici.Radnik, tRadnici.ImeIPrezime;


-- =====================================================
-- Query: Lager Lista
-- =====================================================
SELECT [Lager Lista_1Korak].*
FROM [Lager Lista_1Korak]
ORDER BY [Lager Lista_1Korak].Naziv;


-- =====================================================
-- Query: Lager Lista_1Korak
-- =====================================================
SELECT DISTINCTROW EXT_R_Artikli.[Sifra artikla], Round([PlusMinusKolicina],3) AS Kolicina, EXT_R_Artikli.Naziv, EXT_R_Artikli.Grupa, EXT_R_Artikli.[Tarifa robe], EXT_R_Artikli.Poreklo, EXT_R_Artikli.[Jedinica mere], EXT_R_Artikli.[Kataloski broj], EXT_R_Artikli.BarKod, EXT_R_Artikli.[Transportno pakovanje], EXT_R_Artikli.Kutija, EXT_R_Artikli.[VP cena] AS VPCIzArtikala, EXT_R_Artikli.KngSifra, EXT_R_Artikli.ProdDevCena, Round(Nz([RezervisanaKolicina],0),3) AS RezKol, Nz([Kolicina],0)-Nz([RezKol],0) AS SlobodnaKol, EXT_R_Artikli.Polica
FROM EXT_R_Tarife INNER JOIN ((([Stanje kolicina na dan] INNER JOIN EXT_R_Artikli ON [Stanje kolicina na dan].[Sifra artikla] = EXT_R_Artikli.[Sifra artikla]) LEFT JOIN LL_RezervisaneKolicine ON EXT_R_Artikli.[Sifra artikla] = LL_RezervisaneKolicine.[Sifra artikla]) INNER JOIN tR_Grupa ON EXT_R_Artikli.Grupa = tR_Grupa.Grupa) ON EXT_R_Tarife.Tarifa = EXT_R_Artikli.[Tarifa robe]
WHERE (((EXT_R_Artikli.Podgrupa) Like IIf(IsNull([Forms]![Lager lista]![ZaPodgrupu]),"*",[Forms]![Lager lista]![ZaPodgrupu])) AND ((IIf(Nz([RezervisanaKolicina],0)=0,True,False))<=IIf([Forms]![Lager lista]![NulaRezervisi]=True,True,False)) AND ((EXT_R_Artikli.IDKvalitetArtikla) Like IIf(IsNull([Forms]![Lager lista]![ZaKvalitet]),"*",[Forms]![Lager lista]![ZaKvalitet])) AND ((EXT_R_Artikli.IDRaster) Like IIf(IsNull([Forms]![Lager lista]![ZaDimenziju]),"*",[Forms]![Lager lista]![ZaDimenziju])))
GROUP BY EXT_R_Artikli.[Sifra artikla], Round([PlusMinusKolicina],3), EXT_R_Artikli.Naziv, EXT_R_Artikli.Grupa, EXT_R_Artikli.[Tarifa robe], EXT_R_Artikli.Poreklo, EXT_R_Artikli.[Jedinica mere], EXT_R_Artikli.[Kataloski broj], EXT_R_Artikli.BarKod, EXT_R_Artikli.[Transportno pakovanje], EXT_R_Artikli.Kutija, EXT_R_Artikli.[VP cena], EXT_R_Artikli.KngSifra, EXT_R_Artikli.ProdDevCena, Round(Nz([RezervisanaKolicina],0),3), EXT_R_Artikli.Polica
HAVING (((Round([PlusMinusKolicina],3))<>IIf(IIf(IsNull([Forms]![Lager lista]![NulaKolicine]),True,[Forms]![Lager lista]![NulaKolicine]),0.000001,0)) AND ((EXT_R_Artikli.Grupa) Like IIf(IsNull([Forms]![Lager lista]![ZaGrupu]),"*",[Forms]![Lager lista]![ZaGrupu])) AND ((EXT_R_Artikli.[Tarifa robe]) Like IIf(IsNull([Forms]![Lager lista]![ZaTarifu]),"*",[Forms]![Lager lista]![ZaTarifu])) AND ((EXT_R_Artikli.Poreklo) Like IIf(IsNull([Forms]![Lager lista]![ZaPoreklo]),"*",[Forms]![Lager lista]![ZaPoreklo])) AND ((EXT_R_Artikli.[Kataloski broj]) Like IIf(IsNull([Forms]![Lager lista]![ZaKatBroj]),'*',[Forms]![Lager lista]![ZaKatBroj])))
ORDER BY EXT_R_Artikli.Grupa, EXT_R_Artikli.[Kataloski broj], EXT_R_Artikli.Naziv;


-- =====================================================
-- Query: LL_RezervisaneKolicine
-- =====================================================
SELECT [Profakture stavke].[Sifra artikla], Sum([Profakture stavke].Kolicina) AS RezervisanaKolicina
FROM Profakture INNER JOIN [Profakture stavke] ON Profakture.IDDok = [Profakture stavke].IDDok
WHERE (((Profakture.Ulaz)=No) AND ((Profakture.Rezervisi)=True))
GROUP BY [Profakture stavke].[Sifra artikla];


-- =====================================================
-- Query: Nabavka_UpisiDobavljacaUStavke
-- =====================================================
UPDATE EXT_SpecifikacijaZahtevaNabavke SET EXT_SpecifikacijaZahtevaNabavke.SifraDobavljaca = CLng([Forms]![UnosZahtevaZaNabavku]![Dobavljac])
WHERE (((EXT_SpecifikacijaZahtevaNabavke.IDZahtevaZaNabavku)=[Forms]![UnosZahtevaZaNabavku]![IDZahtevaZaNabavku]));


-- =====================================================
-- Query: NajveciBrojPredmeta
-- =====================================================
SELECT Max(CLng(Eval([BrojPredmeta]))) AS NajveciBroj
FROM Predmeti
WHERE (((IsNumeric([BrojPredmeta]))=True));


-- =====================================================
-- Query: NalepniceZaStampu
-- =====================================================
SELECT tmp_Nalepnice.*
FROM tmp_Nalepnice;


-- =====================================================
-- Query: NETREBA_PregledPredmeta
-- =====================================================
SELECT T_Predmeti.*
FROM T_Predmeti
WHERE (((Nz([ORGAN],"")) Like Nz([forms]![Pisarnica_PregledPredmeta]![ZaORGAN],"*")) AND ((Nz([KLASIF],"")) Like Nz([forms]![Pisarnica_PregledPredmeta]![ZaKLASIF],"*")) AND ((Nz([PODBROJ],"")) Like Nz([forms]![Pisarnica_PregledPredmeta]![ZaPODBROJ],"*")) AND ((Nz([BROJ],"")) Like Nz([forms]![Pisarnica_PregledPredmeta]![ZaBROJ],"*")) AND ((Nz([GOD],"")) Like Nz([forms]![Pisarnica_PregledPredmeta]![ZaGOD],"*")) AND ((Nz([STRANKA],"")) Like "*" & Nz([forms]![Pisarnica_PregledPredmeta]![ZaSTRANKA],"*") & "*") AND ((T_Predmeti.DATUMP) Between [forms]![Pisarnica_PregledPredmeta]![OdDATUMP] And [forms]![Pisarnica_PregledPredmeta]![DoDATUMP]));


-- =====================================================
-- Query: NeZavrseniPostupciPoRN
-- =====================================================
SELECT SviKrajPostupciSaBrojemKomada.IDRN AS IDNezavrsenogRN, Sum(SviKrajPostupciSaBrojemKomada.Razlika) AS BrojPreostalihKomadaZaKontrolu
FROM SviKrajPostupciSaBrojemKomada
GROUP BY SviKrajPostupciSaBrojemKomada.IDRN
HAVING (((Sum(SviKrajPostupciSaBrojemKomada.Razlika))<>0));


-- =====================================================
-- Query: NeZavrseniPredmeti
-- =====================================================
SELECT NeZavrseniPostupciPoRN.IDPredmet AS IDNezavrsenogPredmeta, Sum(NeZavrseniPostupciPoRN.Razlika) AS SumOfRazlika
FROM NeZavrseniPostupciPoRN
GROUP BY NeZavrseniPostupciPoRN.IDPredmet
HAVING (((Sum(NeZavrseniPostupciPoRN.Razlika))<>0));


-- =====================================================
-- Query: NeZavrseniPredmeti_1K
-- =====================================================
SELECT DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IDPredmet, DetaljnoStavkeRN.IdentBroj, DetaljnoStavkeRN.Varijanta, DetaljnoStavkeRN.Operacija, DetaljnoStavkeRN.RJgrupaRC, [Komada]-Nz([NapravljenBrojKomada],0) AS Razlika
FROM (DetaljnoStavkeRN LEFT JOIN tTehPostupak_NapravljenoKomada ON (DetaljnoStavkeRN.RJgrupaRC = tTehPostupak_NapravljenoKomada.RJgrupaRC) AND (DetaljnoStavkeRN.Operacija = tTehPostupak_NapravljenoKomada.Operacija) AND (DetaljnoStavkeRN.Varijanta = tTehPostupak_NapravljenoKomada.Varijanta) AND (DetaljnoStavkeRN.IdentBroj = tTehPostupak_NapravljenoKomada.IdentBroj) AND (DetaljnoStavkeRN.IDPredmet = tTehPostupak_NapravljenoKomada.IDPredmet)) INNER JOIN tOperacije ON DetaljnoStavkeRN.RJgrupaRC = tOperacije.RJgrupaRC
WHERE (((tOperacije.ZnacajneOperacijeZaZavrsen)=True))
GROUP BY DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IDPredmet, DetaljnoStavkeRN.IdentBroj, DetaljnoStavkeRN.Varijanta, DetaljnoStavkeRN.Operacija, DetaljnoStavkeRN.RJgrupaRC, [Komada]-Nz([NapravljenBrojKomada],0)
HAVING (((DetaljnoStavkeRN.IDRN)<>0))
ORDER BY DetaljnoStavkeRN.IDRN;


-- =====================================================
-- Query: Obrisi_tPDM
-- =====================================================
DELETE tPDM.*, tPDM.IDRN
FROM tPDM
WHERE (((tPDM.IDRN)=[Forms]![PregledPoPredmetima]![IDRN]));


-- =====================================================
-- Query: Obrisi_tPLP
-- =====================================================
DELETE tPLP.*, tPLP.IDRN
FROM tPLP
WHERE (((tPLP.IDRN)=[Forms]![PregledPoPredmetima]![IDRN]));


-- =====================================================
-- Query: Obrisi_tPND
-- =====================================================
DELETE tPND.*, tPND.IDRN
FROM tPND
WHERE (((tPND.IDRN)=[Forms]![PregledPoPredmetima]![IDRN]));


-- =====================================================
-- Query: Obrisi_tRN
-- =====================================================
DELETE tRN.*, tRN.IDRN
FROM tRN
WHERE (((tRN.IDRN)=[Forms]![PregledPoPredmetima]![IDRN]));


-- =====================================================
-- Query: Obrisi_tStavkeRN
-- =====================================================
DELETE tStavkeRN.*, tStavkeRN.IDRN
FROM tStavkeRN
WHERE (((tStavkeRN.IDRN)=[Forms]![PregledPoPredmetima]![IDRN]));


-- =====================================================
-- Query: Obrisi_tTehPostupakZaIDPostupka
-- =====================================================
DELETE tTehPostupak.*, tTehPostupak.IDPostupka
FROM tTehPostupak
WHERE (((tTehPostupak.IDPostupka)=[Forms]![PregledPoPostupcima]![Podforma].[Form]![IDPostupka]));


-- =====================================================
-- Query: ODBC_ftBOMKolicine
-- =====================================================
SELECT * FROM ftBOMKolicine( 1827, 1)

-- =====================================================
-- Query: ODBC_ftBOMNabavniDelovi
-- =====================================================
SELECT * FROM ftBOMNabavniDelovi( 12665,0)

-- =====================================================
-- Query: ODBC_ftDnevneAkcijeSaLosimUnosom
-- =====================================================
SELECT * FROM ftDnevneAkcijeSaLosimUnosom( '2025-06-10', '2025-06-10', '07:00:00', '23:00:00', 2)


ORDER BY Radnik

-- =====================================================
-- Query: ODBC_ftKarticaLokacijaDela
-- =====================================================
SELECT * FROM ftKarticaLokacijaDela( 9639, N'..', Null, Null, Null)

ORDER BY BrojPredmeta DESC, BrojNaloga DESC

-- =====================================================
-- Query: ODBC_ftListaProblematicnihRN_Detaljno
-- =====================================================
SELECT * FROM ftListaProblematicnihRN_Detaljno( Null, Null, Null, Null, Null, Null, Null, Null, Null)

-- =====================================================
-- Query: ODBC_ftMRP_PregledPoDobavljacu
-- =====================================================
SELECT * FROM ftMRP_PregledPoDobavljacu( Null, Null, Forms![MRP_Pregled]![ZaProjekat], Null, Forms![MRP_Pregled]![ZaArtikalNaziv], 1)

-- =====================================================
-- Query: ODBC_ftPDMPodPodPODSklopReference
-- =====================================================
SELECT * FROM ftPDMSklopReference( 0)

-- =====================================================
-- Query: ODBC_ftPDMPodPodSklopReference
-- =====================================================
SELECT * FROM ftPDMSklopReference( 4934)

-- =====================================================
-- Query: ODBC_ftPDMPodSklopReference
-- =====================================================
SELECT * FROM ftPDMSklopReference( 12660)

-- =====================================================
-- Query: ODBC_ftPDMSklop
-- =====================================================
SELECT * FROM ftPDMSklop( 12666, 0)

-- =====================================================
-- Query: ODBC_ftPDMSklopConectorPregled
-- =====================================================
SELECT * FROM ftPDMSklopConectorPregled( N'Forms![PDMCrteziPregled]![OdDesignDate]', N'Forms![PDMCrteziPregled]![DoDesignDate]', N'Forms![PDMCrteziPregled]![ZaDesignBy]', N'Forms![PDMCrteziPregled]![OdApprovedDate]', N'Forms![PDMCrteziPregled]![DoApprovedDate]', N'Forms![PDMCrteziPregled]![ZaApprovedBy]', N'Forms![PDMCrteziPregled]![ZaBrojCrteza]', N'Forms![PDMCrteziPregled]![ZaNazivCrteza]', N'Forms![PDMCrteziPregled]![ZaWhereUsed]', N'Forms![PDMCrteziPregled]![ZaNazivProjekta]')

-- =====================================================
-- Query: ODBC_ftPDMSklopReference
-- =====================================================
SELECT * FROM ftPDMSklopReference( 12666)

ORDER BY BrojCrteza

-- =====================================================
-- Query: ODBC_ftPostupciRadnikaKojeTrebaZavrsiti
-- =====================================================
SELECT * FROM ftPostupciRadnikaKojeTrebaZavrsiti( -1)

-- =====================================================
-- Query: ODBC_ftPregledDelovaPoLokacijama
-- =====================================================
SELECT * FROM ftPregledDelovaPoLokacijama( Null, Null, Null, N'9151/5', Null, Null, Null, Null, Null, Null, Null, Null)

ORDER BY  BrojPredmeta DESC, IdentBroj DESC

-- =====================================================
-- Query: ODBC_ftPregledKriticnihPostupaka
-- =====================================================
SELECT *
FROM ftPregledKriticnihPostupaka()
ORDER BY Kriticnost DESC, IDRN DESC, Operacija;

-- =====================================================
-- Query: ODBC_ftPregledNacrtaPrimopredaje
-- =====================================================
SELECT * FROM ftPregledNacrtaPrimopredaje( 0, Null, 0, Null, Null, Null, Null, Null)
ORDER BY IDNacrtPrim, sort;

-- =====================================================
-- Query: ODBC_ftPregledNalogaZaKreiranjeNovogProjekta
-- =====================================================
SELECT * FROM ftPregledNalogaZaKreiranjeNovogProjekta( Null)

ORDER BY DatumUnosa, IdentBroj

-- =====================================================
-- Query: ODBC_ftPregledPostupakaSaDokumentacijom
-- =====================================================
SELECT * FROM ftPregledPostupakaSaDokumentacijom( Null, Null, Null, Null, Null, Null, Null, Null)

-- =====================================================
-- Query: ODBC_ftPregledPoSvimZapocetimPostupcima
-- =====================================================
SELECT * FROM ftPregledPoSvimZapocetimPostupcima( Null, Null, Null, Null, Null, Null, Null, Null, Null, Null, Null, Null)


ORDER BY BrojPredmeta DESC, Operacija

-- =====================================================
-- Query: ODBC_ftPregledPotrebnihKomponentiZaCrtezIKolicinu
-- =====================================================
SELECT * FROM ftPregledPotrebnihKomponentiZaCrtezIKolicinu( 11187, 1, 1)

-- =====================================================
-- Query: ODBC_ftPregledRadnikaCijePostupkeTrebaZavrsiti
-- =====================================================
SELECT * FROM ftPregledRadnikaCijePostupkeTrebaZavrsiti( -1)

-- =====================================================
-- Query: ODBC_ftPregledRazlikaRNvsTP
-- =====================================================
SELECT * FROM ftPregledRazlikaRNvsTP( Null, Null, Null, Null, Null, Null, Null, Null, Null, Null)

-- =====================================================
-- Query: ODBC_ftPregledRNZaPrimopredaju
-- =====================================================
SELECT * FROM ftPregledRNZaPrimopredaju( Null, 0, Null, Null, Null, Null, Null, Null)

-- =====================================================
-- Query: ODBC_ftPregledStavkeRN
-- =====================================================
SELECT * FROM ftPregledStavkeRN( 44701, 1)

-- =====================================================
-- Query: ODBC_ftPregledTopLevelPodsklopovaZaCrtez
-- =====================================================
SELECT * FROM ftPregledTopLevelPodsklopovaZaCrtez( 12665, 1, 1)

-- =====================================================
-- Query: ODBC_ftStatistikaAktivnostiPivot
-- =====================================================
SELECT * FROM ftStatistikaAktivnostiPivot( '2026-04-03', '2026-04-03', '07:00:00', '23:59:59', Null, 2)

ORDER BY StatusUnosa, Radnik

-- =====================================================
-- Query: ODBC_ftWhereUsed
-- =====================================================
SELECT * FROM ftWhereUsed( 12666, 0)

-- =====================================================
-- Query: ODBC_IF
-- =====================================================
SELECT * FROM ftPDMSklop( 109)

-- =====================================================
-- Query: ODBC_Kartica TehPostupka - Podforma
-- =====================================================
SELECT * FROM ftKarticaTehnoloskogPostupkaStavke( 29387, Null, Null, Null, Null)

ORDER BY Operacija, RJgrupaRC, DatumIVremeUnosa

-- =====================================================
-- Query: ODBC_KeyboardSaPostupkom
-- =====================================================
SELECT * FROM ftPostupciRadnikaKojeTrebaZavrsiti( 118)

-- =====================================================
-- Query: ODBC_MRP_PregledPoDobavljacu
-- =====================================================
EXECUTE spMRP_Pregled @OdDatuma=Null, @DoDatuma=Null, @ZaPredmet=Null, @ZaDobavljaca=Null, @ZaSifruArtikla=Null, @ZaNazivArtikla=Null, @PrikaziSve=1, @ZaToggle=N'PoDobavljacu'

-- =====================================================
-- Query: ODBC_PDMCrteziPregled
-- =====================================================
SELECT * FROM ftPDMSklopConectorPregled( Null, Null, Null, Null, Null, Null, N'1135029', Null, Null, Null, Null, 0, Null, Null, Null)

ORDER BY DIVUnosa DESC

-- =====================================================
-- Query: ODBC_PregledOperacijaPoPrioritetima
-- =====================================================
SELECT * FROM ftPregledOperacijaPoPrioritetima( '1900-01-01', '2999-12-31', '1900-01-01', '2999-12-31', Null, Null, Null, Null, Null, Null, Null, Null, Null, Null, Null, Null, Null, Null)

ORDER BY Prioritet

-- =====================================================
-- Query: ODBC_PregledPoPostupcima_Zbir
-- =====================================================
SELECT * FROM ftPregledPoPostupcima( '2025-12-22', Null, Null, Null, Null, Null, Null, Null, Null, Null, Null, Null, Null)
ORDER BY DatumUnosa

-- =====================================================
-- Query: ODBC_PregledPoPredmetima
-- =====================================================
SELECT * FROM ftPregledRNPoPredmetima( '1900-01-01', '2999-12-31', '1900-01-01', '2999-12-31', Null, Null, Null, Null, Null, Null, Null, Null, Null, Null, Null, Null, Null, Null, 3)
ORDER BY  DatumUnosa DESC, IdentBroj DESC;

-- =====================================================
-- Query: ODBC_PregledStavkePrimopredajaRN
-- =====================================================
SELECT * FROM ftPregledStavkeRN( 44189, 35)

-- =====================================================
-- Query: ODBC_RN
-- =====================================================
SELECT * FROM ftRNUnos(38709)

-- =====================================================
-- Query: ODBC_RN_Primopredaja
-- =====================================================
SELECT * FROM ftRNUnos( 44189)

-- =====================================================
-- Query: ODBC_RNPregled
-- =====================================================
EXECUTE spDetaljanPregledPostupakaPoRN @OdDatumaNaloga='2025-07-26', @DoDatumaNaloga=Null, @OdDatumaPredmeta=Null, @DoDatumaPredmeta=Null, @ZaIdentBroj=Null, @ZaPredmet=Null, @ZaKomitenta=Null, @ZavrsenNalog=Null, @ZaBrojCrteza=Null, @ZaVezaSa=Null

-- =====================================================
-- Query: ODBC_RNPregledPoRadniku
-- =====================================================
EXECUTE spDetaljanPregledPostupakaPoRNiRadniku @OdDatumaNaloga='2025-11-28', @DoDatumaNaloga='2999-12-31', @OdDatumaPredmeta='1900-01-01', @DoDatumaPredmeta='2999-12-31', @ZaIdentBroj=Null, @ZaPredmet=9833, @ZaKomitenta=Null, @ZavrsenNalog=Null, @ZaRadnika=94, @ZaBrojCrteza=Null

-- =====================================================
-- Query: ODBC_RNPregledPoRJ
-- =====================================================
EXECUTE spDetaljanPregledPostupakaPoRNiRJ @OdDatumaNaloga='2025-12-12', @DoDatumaNaloga='2999-12-31', @OdDatumaPredmeta='1900-01-01', @DoDatumaPredmeta='2999-12-31', @ZaIdentBroj=Null, @ZaPredmet=Null, @ZaKomitenta=Null, @ZavrsenNalog=0, @ZaRJgrupaRC=N'2.1', @ZaBrojCrteza=Null

-- =====================================================
-- Query: ODBC_spBarKodStatusForm
-- =====================================================
EXECUTE spBarKodStatusForm @ZaIDPostupka=95641, @ZaIDPredmet=9470, @ZaIdentBroj=N'9000/297', @ZaVarijanta=0, @ZaOperaciju=10

-- =====================================================
-- Query: ODBC_spMRP_PregledDetalji
-- =====================================================
EXECUTE spMRP_Pregled @OdDatuma=Null, @DoDatuma=Null, @ZaPredmet=Null, @ZaDobavljaca=Null, @ZaSifruArtikla=Null, @ZaNazivArtikla=Null, @ZaBrojCrteza=Null, @FilterObradjeni=0, @ZaToggle=N'Detalji'

-- =====================================================
-- Query: ODBC_spMRP_PregledDetaljiSvihMRPPotreba
-- =====================================================
EXECUTE spMRP_Pregled @OdDatuma=Null, @DoDatuma=Null, @ZaPredmet=Null, @ZaDobavljaca=Null, @ZaSifruArtikla=Null, @ZaNazivArtikla=Null, @ZaBrojCrteza=Null, @FilterObradjeni=Null, @ZaToggle=N'Detalji'

-- =====================================================
-- Query: ODBC_spMRP_PregledPoArtiklu
-- =====================================================
EXECUTE spMRP_Pregled @OdDatuma=Null, @DoDatuma=Null, @ZaPredmet=10215, @ZaDobavljaca=Null, @ZaSifruArtikla=Null, @ZaNazivArtikla=Null, @ZaBrojCrteza=Null, @ZaToggle=N'PoArtiklu'

-- =====================================================
-- Query: ODBC_spMRP_PregledPoArtikluSamoNabavku
-- =====================================================
EXECUTE spMRP_Pregled @OdDatuma=Null, @DoDatuma=Null, @ZaPredmet=Null, @ZaDobavljaca=Null, @ZaSifruArtikla=Null, @ZaNazivArtikla=Null, @ZaBrojCrteza=Null, @ZaToggle=N'PoArtiklu_SamoZaNabavku'

-- =====================================================
-- Query: ODBC_spMRP_PregledPoDobavljacu
-- =====================================================
EXECUTE spMRP_Pregled @OdDatuma=Null, @DoDatuma=Null, @ZaPredmet=10215, @ZaDobavljaca=Null, @ZaSifruArtikla=Null, @ZaNazivArtikla=Null, @ZaBrojCrteza=N'1132045', @ZaToggle=N'PoDobavljacu'

-- =====================================================
-- Query: ODBC_spMRP_PregledRezervisano
-- =====================================================
EXECUTE spMRP_Pregled @OdDatuma=Null, @DoDatuma=Null, @ZaPredmet=Null, @ZaDobavljaca=Null, @ZaSifruArtikla=Null, @ZaNazivArtikla=Null, @ZaBrojCrteza=Null, @ZaToggle=N'Rezervisano'

-- =====================================================
-- Query: ODBC_spPDMXMLImportLog
-- =====================================================
EXECUTE spPDMXMLImportLog @OdDatuma=Null, @DoDatuma=Null, @OdVremena=DEFAULT, @DoVremena=DEFAULT, @CheckUspesno=Null, @CheckKriticno=Null, @ZaStatusPoruka=Null

-- =====================================================
-- Query: ODBC_spPregledNalogaZaKreiranjeNovogProjekta
-- =====================================================
EXECUTE spPregledNalogaZaKreiranjeNovogProjekta 9466

-- =====================================================
-- Query: ODBC_spPregledRNPoPredmetima
-- =====================================================
EXECUTE spPregledRNPoPredmetima @OdDatumaNaloga='1900-01-01', @DoDatumaNaloga='2999-12-31', @OdDatumaPredmeta='1900-01-01', @DoDatumaPredmeta='2999-12-31', @ZaIdentBroj=N'9151/5', @ZaPredmet=Null, @ZaKomitenta=Null, @LansiranRN=Null, @ZaBrCrteza=Null, @ZaNazivDela=Null, @ZaMaterijal=Null, @ZaDimMaterijala=Null, @SaglasanRN=Null, @ZaVezaSa=Null, @ZaIDVrstaKvaliteta=Null, @StatusRN=Null, @ZaVarijanta=Null, @ZaRevizija=Null, @ZaStatusPrimopredaje=3, @PageNumber=1, @PageSize=200

-- =====================================================
-- Query: ODBC_spPregledZapocetihTehnoloskihPostupaka
-- =====================================================
EXECUTE spPregledZapocetihTehnoloskihPostupaka @OdDatumaPostupka=Null, @DoDatumaPostupka=Null, @OdVremenaPostupka=Null, @DoVremenaPostupka=Null, @OdDatumaPostupkaKraj=Null, @DoDatumaPostupkaKraj=Null, @OdVremenaPostupkaKraj=Null, @DoVremenaPostupkaKraj=Null, @ZaRadnika=Null, @ZaIdentBroj=Null, @ZaPredmet=Null, @ZaKomitenta=Null, @ZaRJgrupaRC=Null, @ZavrsenPostupak=Null, @ZaKvalitetDela=Null, @ZaBrojCrteza=Null, @CheckDiV=1, @CheckZapocetiPostupci=0, @ZaVarijanta=Null

-- =====================================================
-- Query: ODBC_spRNPregled
-- =====================================================
EXECUTE spRNPregledUStatusuProizvodnje @TipPregleda=N'RN', @OdDatumaNaloga='2025-12-22', @DoDatumaNaloga='2999-12-31', @OdDatumaPredmeta='1900-01-01', @DoDatumaPredmeta='2999-12-31', @ZaIdentBroj=Null, @ZaPredmet=Null, @ZaKomitenta=Null, @ZavrsenNalog=Null, @ZaBrojCrteza=Null, @ZaRJgrupaRC=Null, @ZaRadnika=Null, @PoslePoslednje=0

-- =====================================================
-- Query: ODBC_spStatusSklopovaPivot
-- =====================================================
EXECUTE spStatusSklopovaPivot @OdDatumaNaloga='2025-10-01', @DoDatumaNaloga=Null, @ZaIdentBroj=Null, @ZaPredmet=Null, @ZaKomitenta=Null, @ZavrsenNalog=Null, @BrojCrteza=Null, @ZaReviziju=Null, @ZaVarijantu=Null, @VezaSaBrojemCrteza=Null, @Rekurzivno=0

-- =====================================================
-- Query: ODBC_spStatusSklopovaPoOperacijama
-- =====================================================
EXECUTE spStatusSklopovaPoOperacijama @OdDatumaNaloga='2025-10-01', @DoDatumaNaloga='2999-12-31', @ZaIdentBroj=Null, @ZaPredmet=Null, @ZaKomitenta=Null, @ZaStatus=Null, @BrojCrteza=Null, @ZaReviziju=Null, @ZaVarijantu=Null, @VezaSaBrojemCrteza=Null, @Rekurzivno=0, @ZaIDPrimopredaje=Null, @ZaOffset=0, @ZaPageSize=20

-- =====================================================
-- Query: PDM_Document_OBRISI
-- =====================================================
DELETE PDM_Document.*
FROM PDM_Document;


-- =====================================================
-- Query: PDM_GlavniDokument_TEST
-- =====================================================
SELECT h.DocID AS Glavni_DocID, h.Attr_Naziv AS Glavni_Naziv, h.Attr_Name AS Glavni_FileName, h.TransactionDate AS Datum, r.DocID AS Referenca_DocID, r.Attr_Naziv AS Referenca_Naziv, r.Attr_Name AS Referenca_FileName, r.Attr_Weight AS Referenca_Težina
FROM PDM_Document AS h LEFT JOIN PDM_Document AS r ON h.DocID = r.ParentDocID
WHERE ((Not (r.DocID) Is Null))
ORDER BY h.DocID, r.DocID;


-- =====================================================
-- Query: PDM_ReferenceDokumenta_TEST
-- =====================================================
SELECT r.DocID, r.Attr_Naziv, r.Attr_Name, r.Attr_Weight
FROM PDM_document AS r
ORDER BY r.DocID;


-- =====================================================
-- Query: PDVZbirneStope
-- =====================================================
SELECT EXT_R_Tarife.Tarifa, [EXT_R_Tarife]![Osnovna stopa]+[EXT_R_Tarife]![Zeleznica stopa]+[EXT_R_Tarife]![Gradska stopa]+[EXT_R_Tarife]![Ratna stopa]+[EXT_R_Tarife]![Posebna stopa] AS PDVStopa, EXT_R_Tarife.PDVGrupa
FROM EXT_R_Tarife;


-- =====================================================
-- Query: PG_Prepisi_tPDM
-- =====================================================
INSERT INTO tPDM ( IDRN, PozicijaPDM, OperacijaPDM, RJgrupaRC, NazivP, BrojCrtezaP, Komada, DIVUnosa, DIVIspravke, SifraRadnika )
SELECT CLng([Forms]![UnosRN]![IDRN]) AS Expr1, tPDM1.PozicijaPDM, tPDM1.OperacijaPDM, tPDM1.RJgrupaRC, tPDM1.NazivP, tPDM1.BrojCrtezaP, tPDM1.Komada, Now() AS Expr2, Now() AS Expr3, IDRadnikZaCurrentUser() AS Expr4
FROM tPDM1
WHERE (((tPDM1.IDRN)=[Forms]![PG_IzborNalogaZaPrepisivanje]![ComboIDRN]));


-- =====================================================
-- Query: PG_Prepisi_tPLP
-- =====================================================
INSERT INTO tPLP ( IDRN, PozicijaPLP, RJgrupaRC, Materijal, DimenzijaMaterijala, JM, TezinaJed, Komada, BrojPozicije, DIVUnosa, DIVIspravke, SifraRadnika )
SELECT CLng([Forms]![UnosRN]![IDRN]) AS Expr1, tPLP1.PozicijaPLP, tPLP1.RJgrupaRC, tPLP1.Materijal, tPLP1.DimenzijaMaterijala, tPLP1.JM, tPLP1.TezinaJed, tPLP1.Komada, tPLP1.BrojPozicije, Now() AS Expr2, Now() AS Expr3, IDRadnikZaCurrentUser() AS Expr4
FROM tPLP1
WHERE (((tPLP1.IDRN)=[Forms]![PG_IzborNalogaZaPrepisivanje]![ComboIDRN]));


-- =====================================================
-- Query: PG_Prepisi_tPND
-- =====================================================
INSERT INTO tPND ( IDRN, PozicijaPND, OperacijaPND, RJgrupaRC, NazivDela, Komada, Napomena, DIVUnosa, DIVIspravke, SifraRadnika )
SELECT CLng([Forms]![UnosRN]![IDRN]) AS Expr1, tPND1.PozicijaPND, tPND1.OperacijaPND, tPND1.RJgrupaRC, tPND1.NazivDela, tPND1.Komada, tPND1.Napomena, tPND1.DIVUnosa, tPND1.DIVIspravke, IDRadnikZaCurrentUser() AS Expr2
FROM tPND1
WHERE (((tPND1.IDRN)=[Forms]![PG_IzborNalogaZaPrepisivanje]![ComboIDRN]));


-- =====================================================
-- Query: PG_Prepisi_tStavkeRN
-- =====================================================
INSERT INTO tStavkeRN ( IDRN, Operacija, RJgrupaRC, OpisRada, AlatPribor, Tpz, Tk, TezinaTO, SifraRadnika, DIVUnosa, DIVIspravke )
SELECT CLng([Forms]![UnosRN]![IDRN]) AS Expr1, tStavkeRN1.Operacija, tStavkeRN1.RJgrupaRC, tStavkeRN1.OpisRada, tStavkeRN1.AlatPribor, tStavkeRN1.Tpz, tStavkeRN1.Tk, tStavkeRN1.TezinaTO, IDRadnikZaCurrentUser() AS Expr4, Now() AS Expr2, Now() AS Expr3
FROM tStavkeRN1
WHERE (((tStavkeRN1.IDRN)=[Forms]![PG_IzborNalogaZaPrepisivanje]![ComboIDRN]));


-- =====================================================
-- Query: PlanerPrikaz
-- =====================================================
SELECT T_Planer.*
FROM T_Planer
WHERE (((T_Planer.KadaDatum) Between Nz([Forms]![PlanerPopUp]![OdDatuma],Date()) And Nz([Forms]![PlanerPopUp]![DoDatuma],Date())) AND ((Format([KadaVreme],"Short Time"))>=Format([Forms]![PlanerPopUp]![OdVremena],"Short Time") And (Format([KadaVreme],"Short Time"))<=Format([Forms]![PlanerPopUp]![DoVremena],"Short Time")) AND ((ZadovoljenUslovZaBoolVal([CheckUradjeno],[Forms]![PlanerPopUp]![ZaCheckUradjeno]))=True) AND ((T_Planer.OdKoga) Like Nz([Forms]![PlanerPopUp]![ZaOdKoga],"*")) AND ((T_Planer.ZaKoga) Like Nz([Forms]![PlanerPopUp]![ZaZaKoga],"*")) AND ((T_Planer.Subject) Like "*" & Nz([Forms]![PlanerPopUp]![ZaSubjekt],"*") & "*") AND ((Nz([KoJeUradio],"-")) Like Nz([Forms]![PlanerPopUp]![ZaKoJeUradio],"*")))
ORDER BY T_Planer.KadaDatum, Format([KadaVreme],"Short Time");


-- =====================================================
-- Query: PlaniranjeStavkeZaKnjizenjeNALMA
-- =====================================================
SELECT PDM_PlaniranjeStavke.*, EXT_R_Artikli.[Tarifa robe] AS TarifaRoba, BB_CeneZaliha.ProsecnaVPC, BB_CeneZaliha.ProsecnaNC, BB_CeneZaliha.PoslednjaKLVPC, BB_CeneZaliha.PoslednjaKLNC, BB_CeneZaliha.ImaPoslednjuKL, PDVZbirneStope.PDVStopa
FROM PDVZbirneStope INNER JOIN (EXT_R_Artikli INNER JOIN (PDM_PlaniranjeStavke INNER JOIN BB_CeneZaliha ON PDM_PlaniranjeStavke.[SifraArtikla] = BB_CeneZaliha.IDArtikal) ON EXT_R_Artikli.[Sifra artikla] = PDM_PlaniranjeStavke.SifraArtikla) ON PDVZbirneStope.Tarifa = EXT_R_Artikli.[Tarifa robe]
WHERE (((PDM_PlaniranjeStavke.IDPlan)=[ZaIDPlan]) AND ((PDM_PlaniranjeStavke.Rezervisano)>0));


-- =====================================================
-- Query: PopuniTablicu_TMP_Nalepnice
-- =====================================================
INSERT INTO tmp_Nalepnice ( IDRN, IdentBroj, IDPostupka, BarKod, Komitent, NazivPredmeta, BrojCrteza, NazivDela, Materijal, Kolicina, UkupnaKolicina, DatumUnosa )
SELECT tLokacijeDelova.IDRN, tRN.IdentBroj, 0 AS IDPostupka, [trn].[IDPredmet] & ":" & [trn].[IdentBroj] & ":" & [trn].[Varijanta] AS Expr2, Komitenti.Naziv, tRN.BBNazivPredmeta, tRN.BrojCrteza, tRN.NazivDela, tRN.Materijal, tLokacijeDelova.Kolicina, CLng([Forms]![LokacijaNapravljenihDelovaZag]![KolicinaIskontrolisanihDelova]) AS Kolicina, tLokacijeDelova.Datum
FROM tVrsteKvalitetaDelova INNER JOIN (Komitenti INNER JOIN (tRN INNER JOIN tLokacijeDelova ON tRN.IDRN = tLokacijeDelova.IDRN) ON Komitenti.Sifra = tRN.BBIDKomitent) ON tVrsteKvalitetaDelova.IDVrstaKvaliteta = tLokacijeDelova.IDVrstaKvaliteta
WHERE (((tRN.BrojCrteza)=[Forms]![LokacijaNapravljenihDelovaZag]![BrojCrteza]) AND ((CStr([tLokacijeDelova].[IDVrstaKvaliteta])) Like Nz([Forms]![LokacijaNapravljenihDelovaZag]![IDVrstaKvaliteta],"*")) AND ((tRN.IdentBroj) Like Nz([Forms]![LokacijaNapravljenihDelovaZag]![IdentBroj],"*")) AND ((CStr([tLokacijeDelova].[IDpredmet])) Like Nz([Forms]![LokacijaNapravljenihDelovaZag]![IDPredmet],"*")));


-- =====================================================
-- Query: PostojeStavkeZahtevaNabavke
-- =====================================================
SELECT EXT_SpecifikacijaZahtevaNabavke.IDZahtevaZaNabavku
FROM EXT_SpecifikacijaZahtevaNabavke
WHERE (((EXT_SpecifikacijaZahtevaNabavke.SifraDobavljaca) Like Nz([Forms]![ZahteviZaNabavku]![ZaDobavljaca],"*")))
GROUP BY EXT_SpecifikacijaZahtevaNabavke.IDZahtevaZaNabavku;


-- =====================================================
-- Query: PostupciLoseEvidentirani
-- =====================================================
SELECT tTehPostupak.IDPostupka, Day([DatumIVremeUnosa])+Month([DatumIVremeUnosa]) AS Expr1
FROM tTehPostupak
WHERE (((Day([DatumIVremeUnosa])+Month([DatumIVremeUnosa]))<>Day([DatumIVremeZavrsetka])+Month([DatumIVremeZavrsetka]))) OR (((tTehPostupak.DatumIVremeZavrsetka) Is Null));


-- =====================================================
-- Query: Pregled komitenata
-- =====================================================
SELECT DISTINCTROW Komitenti.Naziv, Komitenti.Mesto, Komitenti.Adresa, Komitenti.[Ziro racun_1], Komitenti.Telefon, Komitenti.Fax, Komitenti.Kontakt, Komitenti.Region, Komitenti.Sifra, Komitenti.[Vrsta sifre], Komitenti.[Datum rodjenja], Komitenti.RabatKomitenta, Komitenti.Region, Komitenti.[Postanski broj], CStr([PDVStatus]) Like IIf(IsNull(Forms![Pregled komitenata]!ZaPDVStatus) Or Forms![Pregled komitenata]!ZaPDVStatus=3,"*",CStr(Forms![Pregled komitenata]!ZaPDVStatus)) AS Expr1, Komitenti.Mobilni, Komitenti.PIB, Komitenti.ZastKodKupca
FROM Komitenti
WHERE (((Komitenti.Naziv) Like IIf(IsNull([Forms]![Pregled komitenata]![ZaNaziv]),'*',"*" & [Forms]![Pregled komitenata]![ZaNaziv] & "*")) AND ((Komitenti.[Vrsta sifre]) Like IIf(IsNull([Forms]![Pregled komitenata]![ZaVrstuSifre]),'*',[Forms]![Pregled komitenata]![ZaVrstuSifre])) AND ((Komitenti.RabatKomitenta) Like IIf(IsNull([Forms]![Pregled komitenata]![ZaRabat]),'*',[Forms]![Pregled komitenata]![ZaRabat])) AND ((Komitenti.Region) Like IIf(IsNull([Forms]![Pregled komitenata]![ZaRegion]),'*',[Forms]![Pregled komitenata]![ZaRegion])) AND ((CStr([PDVStatus]) Like IIf(IsNull([Forms]![Pregled komitenata]![ZaPDVStatus]) Or [Forms]![Pregled komitenata]![ZaPDVStatus]=3,"*",CStr([Forms]![Pregled komitenata]![ZaPDVStatus])))=True) AND ((Nz([Mesto],"@#$")) Like IIf(IsNull([Forms]![Pregled komitenata]![ZaMesto]),'*',[Forms]![Pregled komitenata]![ZaMesto])) AND ((CStr(Nz([Sifra prodavca],"@#$"))) Like CStr(IIf(IsNull([Forms]![Pregled komitenata]![ZaProdavca]),'*',[Forms]![Pregled komitenata]![ZaProdavca]))) AND ((CStr(Nz([PIB],"$#%^"))) Like CStr(IIf(IsNull([Forms]![Pregled komitenata]![ZaPIB]),'*',[Forms]![Pregled komitenata]![ZaPIB]))))
ORDER BY Komitenti.Naziv;


-- =====================================================
-- Query: Pregled komitenata - filter
-- =====================================================
SELECT *
FROM Komitenti
WHERE (((Komitenti.Naziv) Like "*" & Forms![Uslov za pronadji komitenta]![Rec za trazenje] & "*"));


-- =====================================================
-- Query: Pregled komitenata - filter1
-- =====================================================
SELECT *
FROM Komitenti
WHERE (((Komitenti.Naziv) Like "*" & Forms![Uslov za pronadji komitenta]![Rec za trazenje] & "*"));


-- =====================================================
-- Query: PregledPoPostupcima
-- =====================================================
SELECT tRN.IDRN, tRN.IDPredmet, tRN.DatumUnosa, tRN.BBNazivPredmeta, tRN.BBDatumOtvaranja, Predmeti.BrojPredmeta, Komitenti.Naziv, tRN.IdentBroj, tRN.Varijanta, DetaljnoStavkeRN.Operacija, DetaljnoStavkeRN.RJgrupaRC, IIf([DetaljnoStavkeRN].[IDRN]=0,0,[DetaljnoStavkeRN].[Komada]) AS PotrebnoKomada, Nz([IzabranitTehPostupak].[Komada],0) AS NapravljenoKomada, Nz([PotrebnoKomada],0)-Nz([NapravljenoKomada],0) AS Razlika, Nz(Round(DateDiff("s",[DatumIVremeUnosa],[DatumIVremeZavrsetka])/3600,4),0) AS VremeProvedenoURadu, Nz(Round(DateDiff("n",[DatumIVremeUnosa],[DatumIVremeZavrsetka]),4),0) AS VremeProvedenoURaduMin, Nz(DateDiff("s",[DatumIVremeUnosa],[DatumIVremeZavrsetka]),0) AS VremeUSekundama, BrojSatiUSekundama(BrojSekundiUIntervalu([DatumIVremeUnosa],[DatumIVremeZavrsetka])) AS Sati, BrojMinutaUSekundama(BrojSekundiUIntervalu([DatumIVremeUnosa],[DatumIVremeZavrsetka])) AS Minuti, Nz(ServotehDatIVreme([DatumIVremeUnosa]),#1/1/1991#) AS DatumIVremeUnosaPostupka, Nz(ServotehDatIVreme([DatumIVremeZavrsetka]),#12/31/2099#) AS DatumIVremeZavrsetkaPostupka, Round(DateDiff("d",[DatumUnosa],IIf(IsNull([DatumIVremeZavrsetka]),Date(),[DatumIVremeZavrsetka]),4)) AS BrojDanaOdOtvaranjaNaloga, Round(DateDiff("d",[RokIzrade],IIf([Razlika]<=0,[DatumIVremeZavrsetka],Date())),4) AS KasnjenjeDana, Nz([IDPostupka],0) AS IDTehPostupka, tRN.RokIzrade, Round(DateDiff("d",[BBDatumOtvaranja],[DatumUnosa],4)) AS BrojDanaOdOtvaranjaPredmeta, IzabranitTehPostupak.Napomena
FROM (((Komitenti INNER JOIN tRN ON Komitenti.Sifra = tRN.BBIDKomitent) INNER JOIN Predmeti ON tRN.IDPredmet = Predmeti.IDPredmet) INNER JOIN DetaljnoStavkeRN ON tRN.IDRN = DetaljnoStavkeRN.IDRN) LEFT JOIN IzabranitTehPostupak ON (DetaljnoStavkeRN.RJgrupaRC = IzabranitTehPostupak.RJgrupaRC) AND (DetaljnoStavkeRN.Operacija = IzabranitTehPostupak.Operacija) AND (DetaljnoStavkeRN.Varijanta = IzabranitTehPostupak.Varijanta) AND (DetaljnoStavkeRN.IdentBroj = IzabranitTehPostupak.IdentBroj) AND (DetaljnoStavkeRN.IDPredmet = IzabranitTehPostupak.IDPredmet)
WHERE (((tRN.DatumUnosa) Between IIf(IsNull([Forms]![PregledPoPostupcima]![OdDatumaNaloga]),#1/1/1991#,[Forms]![PregledPoPostupcima]![OdDatumaNaloga]) And IIf(IsNull([Forms]![PregledPoPostupcima]![DoDatumaNaloga]),#12/31/2099#,[Forms]![PregledPoPostupcima]![DoDatumaNaloga])) AND ((tRN.BBDatumOtvaranja) Between IIf(IsNull([Forms]![PregledPoPostupcima]![OdDatumaPredmeta]),#1/1/1991#,[Forms]![PregledPoPostupcima]![OdDatumaPredmeta]) And IIf(IsNull([Forms]![PregledPoPostupcima]![DoDatumaPredmeta]),#12/31/2099#,[Forms]![PregledPoPostupcima]![DoDatumaPredmeta])) AND ((Nz(ServotehDatIVreme([DatumIVremeUnosa]),#1/1/1991#)) Between IIf(IsNull([Forms]![PregledPoPostupcima]![OdDatumaPostupka]),#1/1/1991#,[Forms]![PregledPoPostupcima]![OdDatumaPostupka]) And IIf(IsNull([Forms]![PregledPoPostupcima]![DoDatumaPostupka]),#12/31/2099#,[Forms]![PregledPoPostupcima]![DoDatumaPostupka])) AND ((Nz(ServotehDatIVreme([DatumIVremeZavrsetka]),#12/31/2099#)) Between IIf(IsNull([Forms]![PregledPoPostupcima]![OdDatumaPostupkaKraj]),#1/1/1991#,[Forms]![PregledPoPostupcima]![OdDatumaPostupkaKraj]) And IIf(IsNull([Forms]![PregledPoPostupcima]![DoDatumaPostupkaKraj]),#12/31/2099#,[Forms]![PregledPoPostupcima]![DoDatumaPostupkaKraj])) AND ((tRN.RokIzrade) Between IIf(IsNull([Forms]![PregledPoPostupcima]![OdDatumaRoka]),#1/1/1991#,[Forms]![PregledPoPostupcima]![OdDatumaRoka]) And IIf(IsNull([Forms]![PregledPoPostupcima]![DoDatumaRoka]),#12/31/2099#,[Forms]![PregledPoPostupcima]![DoDatumaRoka])) AND ((CStr([DetaljnoStavkeRN].[IdentBroj])) Like CStr(Nz([Forms]![PregledPoPostupcima]![ZaIdentBroj],"*"))) AND ((CStr([tRN].[IDPredmet])) Like CStr(Nz([Forms]![PregledPoPostupcima]![ZaPredmet],"*"))) AND ((CStr([DetaljnoStavkeRN].[Varijanta])) Like CStr(Nz([Forms]![PregledPoPostupcima]![ZaVarijanta],"*"))) AND ((CStr([BBIDKomitent])) Like CStr(Nz([Forms]![PregledPoPostupcima]![ZaKomitenta],"*"))) AND ((CStr([DetaljnoStavkeRN].[RJgrupaRC])) Like CStr(Nz([Forms]![PregledPoPostupcima]![ZaRJgrupaRC],"*"))))
ORDER BY tRN.DatumUnosa DESC;


-- =====================================================
-- Query: PregledPoPostupcimaLoseEvidentirani
-- =====================================================
SELECT tTehPostupak.IDPostupka, tRN.IDRN, tRN.IDPredmet, tRN.DatumUnosa, tRN.BBNazivPredmeta, tRN.BBDatumOtvaranja, Predmeti.BrojPredmeta, Komitenti.Naziv, tRadnici.ImeIPrezime, tRN.RokIzrade, tRN.IdentBroj, tRN.Varijanta, DetaljnoStavkeRN.Operacija, DetaljnoStavkeRN.RJgrupaRC, tTehPostupak.DatumIVremeUnosa, tTehPostupak.DatumIVremeZavrsetka
FROM tRadnici INNER JOIN ((((Komitenti INNER JOIN tRN ON Komitenti.Sifra = tRN.BBIDKomitent) INNER JOIN Predmeti ON tRN.IDPredmet = Predmeti.IDPredmet) INNER JOIN DetaljnoStavkeRN ON tRN.IDRN = DetaljnoStavkeRN.IDRN) INNER JOIN (tTehPostupak INNER JOIN PostupciLoseEvidentirani ON tTehPostupak.IDPostupka = PostupciLoseEvidentirani.IDPostupka) ON (DetaljnoStavkeRN.RJgrupaRC = tTehPostupak.RJgrupaRC) AND (DetaljnoStavkeRN.Operacija = tTehPostupak.Operacija) AND (DetaljnoStavkeRN.Varijanta = tTehPostupak.Varijanta) AND (DetaljnoStavkeRN.IdentBroj = tTehPostupak.IdentBroj) AND (DetaljnoStavkeRN.IDPredmet = tTehPostupak.IDPredmet)) ON tRadnici.SifraRadnika = tTehPostupak.SifraRadnika
WHERE (((tRN.DatumUnosa) Between IIf(IsNull([Forms]![PregledPoPostupcima]![OdDatumaNaloga]),#1/1/1991#,[Forms]![PregledPoPostupcima]![OdDatumaNaloga]) And IIf(IsNull([Forms]![PregledPoPostupcima]![DoDatumaNaloga]),#12/31/2099#,[Forms]![PregledPoPostupcima]![DoDatumaNaloga])) AND ((tRN.BBDatumOtvaranja) Between IIf(IsNull([Forms]![PregledPoPostupcima]![OdDatumaPredmeta]),#1/1/1991#,[Forms]![PregledPoPostupcima]![OdDatumaPredmeta]) And IIf(IsNull([Forms]![PregledPoPostupcima]![DoDatumaPredmeta]),#12/31/2099#,[Forms]![PregledPoPostupcima]![DoDatumaPredmeta])) AND ((CStr(Nz([tTehPostupak].[SifraRadnika],"*"))) Like CStr(Nz([Forms]![PregledPoPostupcima]![ZaRadnika],"*"))) AND ((CStr([DetaljnoStavkeRN].[IdentBroj])) Like CStr(Nz([Forms]![PregledPoPostupcima]![ZaIdentBroj],"*"))) AND ((CStr([tRN].[IDPredmet])) Like CStr(Nz([Forms]![PregledPoPostupcima]![ZaPredmet],"*"))) AND ((CStr([DetaljnoStavkeRN].[Varijanta])) Like CStr(Nz([Forms]![PregledPoPostupcima]![ZaVarijanta],"*"))) AND ((CStr([BBIDKomitent])) Like CStr(Nz([Forms]![PregledPoPostupcima]![ZaKomitenta],"*"))) AND ((CStr([tTehPostupak].[RJgrupaRC])) Like CStr(Nz([Forms]![PregledPoPostupcima]![ZaRJgrupaRC],"*"))))
ORDER BY tRN.DatumUnosa DESC;


-- =====================================================
-- Query: PregledPoPostupcimaZbirno
-- =====================================================
SELECT tRN.IDRN, tRN.IDPredmet, tRN.DatumUnosa, tRN.BBNazivPredmeta, tRN.BBDatumOtvaranja, Predmeti.BrojPredmeta, Komitenti.Naziv, tRN.RokIzrade, tRN.IdentBroj, tRN.Varijanta, DetaljnoStavkeRN.Operacija, DetaljnoStavkeRN.RJgrupaRC, IIf([DetaljnoStavkeRN].[IDRN]=0,0,[DetaljnoStavkeRN].[Komada]) AS PotrebnoKomada, Nz([NapravljenBrojKomada],0) AS NapravljenoKomada, Nz([PotrebnoKomada],0)-Nz([NapravljenBrojKomada],0) AS Razlika, PregledPoPostupcimaZbirnoTehPostupak.VremeProvedenoURadu, PregledPoPostupcimaZbirnoTehPostupak.VremeProvedenoURaduMin, PregledPoPostupcimaZbirnoTehPostupak.VremeUSekundama, BrojDanaUSekundama(Nz([VremeUSekundama],0)) AS Dani, BrojSatiUSekundama(Nz([VremeUSekundama],0)) AS Sati, BrojMinutaUSekundama(Nz([VremeUSekundama],0)) AS Minuti, PregledPoPostupcimaZbirnoTehPostupak.MinOfDatumIVremeUnosa AS DatumIVremeUnosa, PregledPoPostupcimaZbirnoTehPostupak.MaxOfDatumIVremeZavrsetka AS DatumIVremeZavrsetka, Round(DateDiff("d",[DatumUnosa],IIf(IsNull([MaxOfDatumIVremeZavrsetka]),Date(),[MaxOfDatumIVremeZavrsetka]),4)) AS BrojDanaOdOtvaranjaNaloga, Round(DateDiff("d",[RokIzrade],IIf([Razlika]<=0,[MaxOfDatumIVremeZavrsetka],Date())),4) AS KasnjenjeDana, Round(DateDiff("d",[BBDatumOtvaranja],[DatumUnosa],4)) AS BrojDanaOdOtvaranjaPredmeta, IIf([DetaljnoStavkeRN].[IDRN]=0,Round([VremeUSekundama]/3600,2),[DetaljnoStavkeRN].[UkupnoVreme]) AS UkVreme, IIf([DetaljnoStavkeRN].[IDRN]=0,Round([VremeUSekundama]/3600,2),Nz([VremePripreme],0)+(Nz([NapravljenBrojKomada],0)*Nz([VremePoKomadu],0))) AS NormiranoVreme
FROM (((Komitenti INNER JOIN tRN ON Komitenti.Sifra = tRN.BBIDKomitent) INNER JOIN Predmeti ON tRN.IDPredmet = Predmeti.IDPredmet) INNER JOIN DetaljnoStavkeRN ON tRN.IDRN = DetaljnoStavkeRN.IDRN) LEFT JOIN PregledPoPostupcimaZbirnoTehPostupak ON (DetaljnoStavkeRN.RJgrupaRC = PregledPoPostupcimaZbirnoTehPostupak.RJgrupaRC) AND (DetaljnoStavkeRN.Operacija = PregledPoPostupcimaZbirnoTehPostupak.Operacija) AND (DetaljnoStavkeRN.Varijanta = PregledPoPostupcimaZbirnoTehPostupak.Varijanta) AND (DetaljnoStavkeRN.IdentBroj = PregledPoPostupcimaZbirnoTehPostupak.IdentBroj) AND (DetaljnoStavkeRN.IDPredmet = PregledPoPostupcimaZbirnoTehPostupak.IDPredmet)
WHERE (((tRN.DatumUnosa) Between IIf(IsNull([Forms]![PregledPoPostupcima]![OdDatumaNaloga]),#1/1/1991#,[Forms]![PregledPoPostupcima]![OdDatumaNaloga]) And IIf(IsNull([Forms]![PregledPoPostupcima]![DoDatumaNaloga]),#12/31/2099#,[Forms]![PregledPoPostupcima]![DoDatumaNaloga])) AND ((tRN.BBDatumOtvaranja) Between IIf(IsNull([Forms]![PregledPoPostupcima]![OdDatumaPredmeta]),#1/1/1991#,[Forms]![PregledPoPostupcima]![OdDatumaPredmeta]) And IIf(IsNull([Forms]![PregledPoPostupcima]![DoDatumaPredmeta]),#12/31/2099#,[Forms]![PregledPoPostupcima]![DoDatumaPredmeta])) AND ((tRN.RokIzrade) Between IIf(IsNull([Forms]![PregledPoPostupcima]![OdDatumaRoka]),#1/1/1991#,[Forms]![PregledPoPostupcima]![OdDatumaRoka]) And IIf(IsNull([Forms]![PregledPoPostupcima]![DoDatumaRoka]),#12/31/2099#,[Forms]![PregledPoPostupcima]![DoDatumaRoka])) AND ((CStr([DetaljnoStavkeRN].[IdentBroj])) Like CStr(Nz([Forms]![PregledPoPostupcima]![ZaIdentBroj],"*"))) AND ((CStr([tRN].[IDPredmet])) Like CStr(Nz([Forms]![PregledPoPostupcima]![ZaPredmet],"*"))) AND ((CStr([DetaljnoStavkeRN].[Varijanta])) Like CStr(Nz([Forms]![PregledPoPostupcima]![ZaVarijanta],"*"))) AND ((CStr([BBIDKomitent])) Like CStr(Nz([Forms]![PregledPoPostupcima]![ZaKomitenta],"*"))) AND ((CStr([DetaljnoStavkeRN].[RJgrupaRC])) Like CStr(Nz([Forms]![PregledPoPostupcima]![ZaRJgrupaRC],"*"))) AND ((CStr(IIf([DetaljnoStavkeRN].[IDRN]=0,-1,IIf(IsNull([NapravljenBrojKomada]),False,True)))) Like CStr(Nz([Forms]![PregledPoPostupcima]![ZavrsenPosao],"*"))))
ORDER BY tRN.DatumUnosa DESC;


-- =====================================================
-- Query: PregledPoPostupcimaZbirnoTehPostupak
-- =====================================================
SELECT tTehPostupak.IDPredmet, tTehPostupak.IdentBroj, tTehPostupak.Varijanta, tTehPostupak.Operacija, tTehPostupak.RJgrupaRC, tTehPostupak.SifraRadnika, Min(tTehPostupak.DatumIVremeUnosa) AS MinOfDatumIVremeUnosa, Max(tTehPostupak.DatumIVremeZavrsetka) AS MaxOfDatumIVremeZavrsetka, Sum(tTehPostupak.Komada) AS NapravljenBrojKomada, Sum(Round(DateDiff("s",[DatumIVremeUnosa],[DatumIVremeZavrsetka])/3600,4)) AS VremeProvedenoURadu, Sum(Round(DateDiff("n",[DatumIVremeUnosa],[DatumIVremeZavrsetka]),4)) AS VremeProvedenoURaduMin, Sum(DateDiff("s",[DatumIVremeUnosa],[DatumIVremeZavrsetka])) AS VremeUSekundama
FROM tTehPostupak
WHERE (((Nz(ServotehDatIVreme([DatumIVremeUnosa]),#1/1/1991#)) Between IIf(IsNull([Forms]![PregledPoPostupcima]![OdDatumaPostupka]),#1/1/1991#,[Forms]![PregledPoPostupcima]![OdDatumaPostupka]) And IIf(IsNull([Forms]![PregledPoPostupcima]![DoDatumaPostupka]),#12/31/2099#,[Forms]![PregledPoPostupcima]![DoDatumaPostupka])) AND ((Nz(ServotehDatIVreme([DatumIVremeZavrsetka]),#12/31/2099#)) Between IIf(IsNull([Forms]![PregledPoPostupcima]![OdDatumaPostupkaKraj]),#1/1/1991#,[Forms]![PregledPoPostupcima]![OdDatumaPostupkaKraj]) And IIf(IsNull([Forms]![PregledPoPostupcima]![DoDatumaPostupkaKraj]),#12/31/2099#,[Forms]![PregledPoPostupcima]![DoDatumaPostupkaKraj])) AND ((CStr(Nz([SifraRadnika],"*"))) Like CStr(Nz([Forms]![PregledPoPostupcima]![ZaRadnika],"*"))))
GROUP BY tTehPostupak.IDPredmet, tTehPostupak.IdentBroj, tTehPostupak.Varijanta, tTehPostupak.Operacija, tTehPostupak.RJgrupaRC, tTehPostupak.SifraRadnika;


-- =====================================================
-- Query: PregledPoPostupcimaZbirnoTehPostupak_TMP
-- =====================================================
SELECT tTehPostupak.IDPredmet, tTehPostupak.IdentBroj, tTehPostupak.Varijanta, tTehPostupak.Operacija, tTehPostupak.RJgrupaRC, tTehPostupak.SifraRadnika, tTehPostupak.DatumIVremeUnosa, tTehPostupak.DatumIVremeZavrsetka, tTehPostupak.Komada AS NapravljenBrojKomada, Round(DateDiff("s",[DatumIVremeUnosa],[DatumIVremeZavrsetka])/3600,4) AS VremeProvedenoURadu, Round(DateDiff("n",[DatumIVremeUnosa],[DatumIVremeZavrsetka]),4) AS VremeProvedenoURaduMin, DateDiff("s",[DatumIVremeUnosa],[DatumIVremeZavrsetka]) AS VremeUSekundama, BrojDanaUSekundama(BrojSekundiUIntervalu([DatumIVremeUnosa],[DatumIVremeZavrsetka])) AS Dani, BrojSatiUSekundama(BrojSekundiUIntervalu([DatumIVremeUnosa],[DatumIVremeZavrsetka])) AS Sati, BrojMinutaUSekundama(BrojSekundiUIntervalu([DatumIVremeUnosa],[DatumIVremeZavrsetka])) AS Minuti
FROM tTehPostupak
WHERE (((CStr(Nz([SifraRadnika],"*"))) Like CStr(Nz([Forms]![PregledPoPostupcima]![ZaRadnika],"*"))) AND ((DatumUIntervalu(Nz([DatumIVremeUnosa],#1/1/1991#),[Forms]![PregledPoPostupcima]![OdDatumaPostupka],[Forms]![PregledPoPostupcima]![DoDatumaPostupka]))=True) AND ((DatumUIntervalu(Nz([DatumIVremeZavrsetka],#12/31/2099#),[Forms]![PregledPoPostupcima]![OdDatumaPostupkaKraj],[Forms]![PregledPoPostupcima]![DoDatumaPostupkaKraj]))=True));


-- =====================================================
-- Query: PregledPostupka
-- =====================================================
SELECT tTehPostupak.IDPostupka, tTehPostupak.IDPredmet, Predmeti.BrojPredmeta, tRN.BBDatumOtvaranja, Komitenti.Naziv, tTehPostupak.IdentBroj, tTehPostupak.Varijanta, tRN.DatumUnosa, tRadnici.Radnik, tTehPostupak.DatumIVremeUnosa, tTehPostupak.Operacija, tTehPostupak.RJgrupaRC, tTehPostupak.Toznaka, tTehPostupak.Komada, tTehPostupak.Napomena
FROM tRadnici INNER JOIN (((Komitenti INNER JOIN tRN ON Komitenti.Sifra=tRN.BBIDKomitent) INNER JOIN tTehPostupak ON (tRN.Varijanta=tTehPostupak.Varijanta) AND (tRN.IdentBroj=tTehPostupak.IdentBroj) AND (tRN.IDPredmet=tTehPostupak.IDPredmet)) INNER JOIN Predmeti ON tTehPostupak.IDPredmet=Predmeti.IDPredmet) ON tRadnici.SifraRadnika=tTehPostupak.SifraRadnika;


-- =====================================================
-- Query: Prepisi_tPDM
-- =====================================================
INSERT INTO tPDM ( IDRN, PozicijaPDM, OperacijaPDM, RJgrupaRC, NazivP, BrojCrtezaP, Komada, DIVUnosa, DIVIspravke, SifraRadnika )
SELECT CLng([Forms]![UnosRN]![IDRN]) AS Expr1, tPDM.PozicijaPDM, tPDM.OperacijaPDM, tPDM.RJgrupaRC, tPDM.NazivP, tPDM.BrojCrtezaP, tPDM.Komada, Now() AS Expr2, Now() AS Expr3, IDRadnikZaCurrentUser() AS Expr4
FROM tPDM
WHERE (((tPDM.IDRN)=[Forms]![IzborNalogaZaPrepisivanje]![ComboIDRN]));


-- =====================================================
-- Query: Prepisi_tPLP
-- =====================================================
INSERT INTO tPLP ( IDRN, PozicijaPLP, RJgrupaRC, Materijal, DimenzijaMaterijala, JM, TezinaJed, Komada, BrojPozicije, DIVUnosa, DIVIspravke, SifraRadnika )
SELECT CLng([Forms]![UnosRN]![IDRN]) AS Expr1, tPLP.PozicijaPLP, tPLP.RJgrupaRC, tPLP.Materijal, tPLP.DimenzijaMaterijala, tPLP.JM, tPLP.TezinaJed, tPLP.Komada, tPLP.BrojPozicije, Now() AS Expr2, Now() AS Expr3, IDRadnikZaCurrentUser() AS Expr4
FROM tPLP
WHERE (((tPLP.IDRN)=[Forms]![IzborNalogaZaPrepisivanje]![ComboIDRN]));


-- =====================================================
-- Query: Prepisi_tPND
-- =====================================================
INSERT INTO tPND ( IDRN, PozicijaPND, OperacijaPND, RJgrupaRC, NazivDela, Komada, Napomena, DIVUnosa, DIVIspravke, SifraRadnika )
SELECT CLng([Forms]![UnosRN]![IDRN]) AS Expr1, tPND.PozicijaPND, tPND.OperacijaPND, tPND.RJgrupaRC, tPND.NazivDela, tPND.Komada, tPND.Napomena, tPND.DIVUnosa, tPND.DIVIspravke, IDRadnikZaCurrentUser() AS Expr2
FROM tPND
WHERE (((tPND.IDRN)=[Forms]![IzborNalogaZaPrepisivanje]![ComboIDRN]));


-- =====================================================
-- Query: Prepisi_tStavkeRN
-- =====================================================
INSERT INTO tStavkeRN ( IDRN, Operacija, RJgrupaRC, OpisRada, AlatPribor, Tpz, Tk, TezinaTO, SifraRadnika, DIVUnosa, DIVIspravke )
SELECT CLng([Forms]![UnosRN]![IDRN]) AS Expr1, tStavkeRN.Operacija, tStavkeRN.RJgrupaRC, tStavkeRN.OpisRada, tStavkeRN.AlatPribor, tStavkeRN.Tpz, tStavkeRN.Tk, tStavkeRN.TezinaTO, IDRadnikZaCurrentUser() AS Expr4, Now() AS Expr2, Now() AS Expr3
FROM tStavkeRN
WHERE (((tStavkeRN.IDRN)=[Forms]![IzborNalogaZaPrepisivanje]![ComboIDRN]));


-- =====================================================
-- Query: Profakture
-- =====================================================
SELECT [EXT_T_Robna dokumenta].*
FROM [EXT_T_Robna dokumenta]
WHERE ((([EXT_T_Robna dokumenta].Level)>=250));


-- =====================================================
-- Query: Profakture stavke
-- =====================================================
SELECT [EXT_T_Robne stavke].*
FROM Profakture INNER JOIN [EXT_T_Robne stavke] ON Profakture.IDDok = [EXT_T_Robne stavke].IDDok;


-- =====================================================
-- Query: ProknjiziStavkeSpecifikacijaZahtevaNabavke
-- =====================================================
INSERT INTO EXT_SpecifikacijaZahtevaNabavke ( IDZahtevaZaNabavku, [Sifra artikla], ZahtevanaKolicina, [Kataloski brojStavke], OpisStavke, [Jedinica mereStavke], SifraDobavljaca, Proizvodjaca, Napomena, DatIVreme, IDPredmet, KreirajUpit )
SELECT CLng([Forms]![UnosZahtevaZaNabavku]![IDZahtevaZaNabavku]) AS Expr3, EXT_SpecifikacijaZahtevaNabavke.[Sifra artikla], EXT_SpecifikacijaZahtevaNabavke.ZahtevanaKolicina, EXT_SpecifikacijaZahtevaNabavke.[Kataloski brojStavke], EXT_SpecifikacijaZahtevaNabavke.OpisStavke, EXT_SpecifikacijaZahtevaNabavke.[Jedinica mereStavke], EXT_SpecifikacijaZahtevaNabavke.SifraDobavljaca, EXT_SpecifikacijaZahtevaNabavke.Proizvodjaca, EXT_SpecifikacijaZahtevaNabavke.Napomena, Now() AS Expr1, CLng([Forms]![UnosZahtevaZaNabavku]![IDPredmetDok]) AS Expr2, EXT_SpecifikacijaZahtevaNabavke.KreirajUpit
FROM EXT_SpecifikacijaZahtevaNabavke
WHERE (((EXT_SpecifikacijaZahtevaNabavke.IDZahtevaZaNabavku)=[Forms]![IzborSpecifikacijeNabavkeZaPrepisivanje]![ComboIDSpecifikacije]));


-- =====================================================
-- Query: ProveraPreKopiranja
-- =====================================================
SELECT tRN.IDRN
FROM (((tRN LEFT JOIN tPDM ON tRN.IDRN = tPDM.IDRN) LEFT JOIN tPLP ON tRN.IDRN = tPLP.IDRN) LEFT JOIN tPND ON tRN.IDRN = tPND.IDRN) LEFT JOIN tStavkeRN ON tRN.IDRN = tStavkeRN.IDRN
WHERE (((Nz([IDStavkePDM],0)+Nz([IDStavkePLP],0)+Nz([IDStavkePND],0)+Nz([IDStavkeRN],0))=0))
GROUP BY tRN.IDRN
HAVING (((tRN.IDRN)=F_RN_IDRN()));


-- =====================================================
-- Query: PrvaNezavrsenaOperacijaPoRN
-- =====================================================
SELECT SveOperacijeSaBrojemNezavrsenihKomada.IDRN, SveOperacijeSaBrojemNezavrsenihKomada.IDPredmet, SveOperacijeSaBrojemNezavrsenihKomada.IdentBroj, Min(SveOperacijeSaBrojemNezavrsenihKomada.Operacija) AS OperacijaDoKojeSeStiglo
FROM SveOperacijeSaBrojemNezavrsenihKomada
GROUP BY SveOperacijeSaBrojemNezavrsenihKomada.IDRN, SveOperacijeSaBrojemNezavrsenihKomada.IDPredmet, SveOperacijeSaBrojemNezavrsenihKomada.IdentBroj;


-- =====================================================
-- Query: PrvaNezavrsenaOperacijasaRJPoRN
-- =====================================================
SELECT PrvaNezavrsenaOperacijaPoRN.IDRN, PrvaNezavrsenaOperacijaPoRN.OperacijaDoKojeSeStiglo, tStavkeRN.RJgrupaRC AS RJDoKojeSeStiglo, tOperacije.NazivGrupeRC
FROM tOperacije INNER JOIN (PrvaNezavrsenaOperacijaPoRN INNER JOIN tStavkeRN ON (PrvaNezavrsenaOperacijaPoRN.OperacijaDoKojeSeStiglo = tStavkeRN.Operacija) AND (PrvaNezavrsenaOperacijaPoRN.IDRN = tStavkeRN.IDRN)) ON tOperacije.RJgrupaRC = tStavkeRN.RJgrupaRC;


-- =====================================================
-- Query: Q_BBPravaPristupa
-- =====================================================
SELECT BBPravaPristupa.*
FROM BBPravaPristupa
WHERE (((BBPravaPristupa.ImeUsera) Like [ZaUsera]) AND ((BBPravaPristupa.ImeForme)=[ZaFormu]));


-- =====================================================
-- Query: Q_OdlukePredProvere
-- =====================================================
SELECT viewOdlukePredProvera.IDNacrtStavka, viewOdlukePredProvera.BrojCrteza, viewOdlukePredProvera.Naziv, viewOdlukePredProvera.Revizija, viewOdlukePredProvera.KolicinaZaIzradu, viewOdlukePredProvera.PrethodnoPredateKolicine, viewOdlukePredProvera.PredProveraDuplikat, viewOdlukePredProvera.PredProveraIDNacrtPrim, viewOdlukePredProvera.PredProveraIDRN, viewOdlukePredProvera.IskljuciPrimopredaju, viewOdlukePredProvera.OdlukaAkcija, viewOdlukePredProvera.Napomena, viewOdlukePredProvera.NeedsDecision, viewOdlukePredProvera.SuggestedAction
FROM viewOdlukePredProvera
WHERE (((viewOdlukePredProvera.IDNacrtPrim)=[Forms]![NacrtPrimopredaje]![IDNacrtPrim]) AND ((viewOdlukePredProvera.NeedsDecision)=True));


-- =====================================================
-- Query: Q_PlanSporneStavke
-- =====================================================
SELECT *
FROM viewPlaniranjeOdlukePredProvera
WHERE (((viewPlaniranjeOdlukePredProvera.[IDPlan])=[Forms]![PlaniranjeNabavke]![IDPlan]));


-- =====================================================
-- Query: Q_tmp_NaloziZaKreiranjeNovogProjekta
-- =====================================================
SELECT tmp_NaloziZaKreiranjeNovogProjekta.*
FROM tmp_NaloziZaKreiranjeNovogProjekta
WHERE (((CStr([Kreirati])) Like Nz([Forms]![KreirajNoveNalogeZaIDPredmet]![CheckKreirati],"*")) AND ((tmp_NaloziZaKreiranjeNovogProjekta.NazivDela) Like "*" & Nz([Forms]![KreirajNoveNalogeZaIDPredmet]![ZaNazivDela],"*") & "*") AND ((tmp_NaloziZaKreiranjeNovogProjekta.IdentBroj) Like "*" & Nz([Forms]![KreirajNoveNalogeZaIDPredmet]![ZaIdentBroj],"*") & "*") AND ((tmp_NaloziZaKreiranjeNovogProjekta.BrojCrteza) Like "*" & Nz([Forms]![KreirajNoveNalogeZaIDPredmet]![ZaBrojCrteza],"*") & "*") AND ((tmp_NaloziZaKreiranjeNovogProjekta.Materijal) Like "*" & Nz([Forms]![KreirajNoveNalogeZaIDPredmet]![ZaMaterijal],"*") & "*") AND ((tmp_NaloziZaKreiranjeNovogProjekta.DimenzijaMaterijala) Like "*" & Nz([Forms]![KreirajNoveNalogeZaIDPredmet]![ZaDimenzijaMaterijala],"*") & "*"));


-- =====================================================
-- Query: QDigitron
-- =====================================================
SELECT Digitron.*, VrednostIzrazaZaDigitron([Izraz],[BrojDecimala]) AS VredIzraza
FROM ZagDigitron INNER JOIN Digitron ON ZagDigitron.IdZagDig=Digitron.IDZagDig;


-- =====================================================
-- Query: qMRP_PregledDetaljno
-- =====================================================
SELECT D.*, Nz(L.PlusMinusKolicina,0) AS Lager, Nz([R].[RezervisanaKolicina],0) AS Rezervisano, Nz(L.PlusMinusKolicina,0)-Nz(R.RezervisanaKolicina,0) AS Slobodno, EXT_R_Artikli.Naziv
FROM ((viewMRP_PregledDetaljno AS D LEFT JOIN BB_StanjeKolicinaNaDan AS L ON D.SifraArtikla = L.[Sifra artikla]) LEFT JOIN BB_RezervisaneKolicine AS R ON D.SifraArtikla = R.[Sifra artikla]) LEFT JOIN EXT_R_Artikli ON D.SifraArtikla = EXT_R_Artikli.[Sifra artikla];


-- =====================================================
-- Query: qMRP_PregledSaZalihama
-- =====================================================
SELECT M.*, Predmeti.BrojPredmeta, Nz(L.PlusMinusKolicina,0) AS Lager, Nz([R].[RezervisanaKolicina],0) AS Rezervisano, Nz(L.PlusMinusKolicina,0)-Nz(R.RezervisanaKolicina,0) AS Slobodno, IIf(M.UkupnoPotrebno-(Nz(L.PlusMinusKolicina,0)-Nz(R.RezervisanaKolicina,0))>0,M.UkupnoPotrebno-(Nz(L.PlusMinusKolicina,0)-Nz(R.RezervisanaKolicina,0)),0) AS ZaNabavku, EXT_R_Artikli.Naziv
FROM (((viewMRP_PregledPoArtiklu AS M LEFT JOIN BB_StanjeKolicinaNaDan AS L ON M.SifraArtikla = L.[Sifra artikla]) LEFT JOIN BB_RezervisaneKolicine AS R ON M.SifraArtikla = R.[Sifra artikla]) INNER JOIN Predmeti ON M.IDPredmet = Predmeti.IDPredmet) LEFT JOIN EXT_R_Artikli ON M.SifraArtikla = EXT_R_Artikli.[Sifra artikla];


-- =====================================================
-- Query: qPT_StatusSklopovaPivot
-- =====================================================
EXEC dbo.spStatusSklopovaPivot 
     @OdDatumaNaloga='1900-01-01',
     @DoDatumaNaloga='2999-12-31',
     @ZaIdentBroj=NULL,
     @ZaPredmet=NULL,
     @ZaKomitenta=NULL,
     @ZavrsenNalog=NULL,
     @BrojCrteza=NULL,
     @ZaReviziju=NULL,
     @ZaVarijantu=NULL,
     @VezaSaBrojemCrteza=NULL,
     @Rekurzivno=0


-- =====================================================
-- Query: qry_TMP_MRP_Stanje
-- =====================================================
SELECT M.SifraArtikla, Nz([L].[PlusMinusKolicina],0) AS Zalihe, Nz([R].[RezervisanaKolicina],0) AS Rezervisane, EXT_R_Artikli.[Kataloski broj], EXT_R_Artikli.Naziv, EXT_R_Artikli.[Jedinica mere]
FROM (((SELECT DISTINCT SifraArtikla FROM MRP_PotrebeStavke)  AS M LEFT JOIN BB_StanjeKolicinaNaDan AS L ON M.SifraArtikla = L.[Sifra artikla]) LEFT JOIN BB_RezervisaneKolicine AS R ON M.SifraArtikla = R.[Sifra artikla]) INNER JOIN EXT_R_Artikli ON M.SifraArtikla = EXT_R_Artikli.[Sifra artikla]
ORDER BY M.SifraArtikla;


-- =====================================================
-- Query: qry_TMP_MRP_StanjeZaIDPotreba
-- =====================================================
SELECT M.SifraArtikla, Nz([L].[PlusMinusKolicina],0) AS Zalihe, Nz([R].[RezervisanaKolicina],0) AS Rezervisane, EXT_R_Artikli.[Kataloski broj], EXT_R_Artikli.Naziv, EXT_R_Artikli.[Jedinica mere]
FROM (((SELECT DISTINCT SifraArtikla FROM MRP_PotrebeStavke WHERE IDPotreba = [TempVars]![ZaIDPotreba])  AS M LEFT JOIN BB_StanjeKolicinaNaDan AS L ON M.SifraArtikla = L.[Sifra artikla]) LEFT JOIN BB_RezervisaneKolicine AS R ON M.SifraArtikla = R.[Sifra artikla]) INNER JOIN EXT_R_Artikli ON M.SifraArtikla = EXT_R_Artikli.[Sifra artikla]
ORDER BY M.SifraArtikla;


-- =====================================================
-- Query: qry_TMP_MRP_StanjeZaIDPotreba_X
-- =====================================================
SELECT M.SifraArtikla, Nz([L].[PlusMinusKolicina],0) AS Zalihe, Nz([R].[RezervisanaKolicina],0) AS Rezervisane, EXT_R_Artikli.[Kataloski broj], EXT_R_Artikli.Naziv, EXT_R_Artikli.[Jedinica mere]
FROM (((SELECT DISTINCT SifraArtikla FROM MRP_PotrebeStavke WHERE IDPotreba = [ZaIDPotreba])  AS M LEFT JOIN BB_StanjeKolicinaNaDan AS L ON M.SifraArtikla = L.[Sifra artikla]) LEFT JOIN BB_RezervisaneKolicine AS R ON M.SifraArtikla = R.[Sifra artikla]) INNER JOIN EXT_R_Artikli ON M.SifraArtikla = EXT_R_Artikli.[Sifra artikla]
ORDER BY M.SifraArtikla;


-- =====================================================
-- Query: QryPregledGotovihDelovaZaCrtez
-- =====================================================
SELECT [EXT_T_Trebovanja stavke].*, tmp_PDM_KataloskiBrojevi.IDCrtez, tmp_PDM_KataloskiBrojevi.BrojCrteza, EXT_R_Artikli.[Kataloski broj], EXT_R_Artikli.Naziv, EXT_R_Artikli.[Jedinica mere], EXT_T_Trebovanja.[Sifra komitenta], EXT_Komitenti.Naziv AS DObavljac, Round(Nz([PlusMinusKolicina],0),3) AS Kolicina, Round(Nz([RezervisanaKolicina],0),3) AS RezKol, Nz([PlusMinusKolicina],0)-Nz([RezKol],0) AS SlobodnaKol
FROM (EXT_Komitenti INNER JOIN EXT_T_Trebovanja ON EXT_Komitenti.Sifra = EXT_T_Trebovanja.[Sifra komitenta]) INNER JOIN (((tmp_PDM_KataloskiBrojevi INNER JOIN (EXT_R_Artikli INNER JOIN [EXT_T_Trebovanja stavke] ON EXT_R_Artikli.[Sifra artikla] = [EXT_T_Trebovanja stavke].[Sifra artikla]) ON tmp_PDM_KataloskiBrojevi.SifraArtikla = EXT_R_Artikli.[Sifra artikla]) LEFT JOIN BB_RezervisaneKolicine ON EXT_R_Artikli.[Sifra artikla] = BB_RezervisaneKolicine.[Sifra artikla]) LEFT JOIN BB_StanjeKolicinaNaDan ON EXT_R_Artikli.[Sifra artikla] = BB_StanjeKolicinaNaDan.[Sifra artikla]) ON EXT_T_Trebovanja.IDTreb = [EXT_T_Trebovanja stavke].IDTreb
ORDER BY [EXT_T_Trebovanja stavke].IDStavke;


-- =====================================================
-- Query: qryStatusPlaniranja
-- =====================================================
SELECT p.IDPlan, p.IDPlanStavka, p.SifraArtikla, p.PotrebnoUkupno, p.Rezervisano, p.ZaNabavku, nm.Kolicina AS MagacinRezervisano, sn.ZahtevanaKolicina AS NabavkaNarucena
FROM (PDM_PlaniranjeStavke AS p LEFT JOIN [Profakture stavke] AS nm ON p.IDPlanStavka = nm.IDPlanStavka) LEFT JOIN EXT_SpecifikacijaZahtevaNabavke AS sn ON p.IDPlanStavka = sn.IDPlanStavka;


-- =====================================================
-- Query: Query1
-- =====================================================
SELECT tRN.IdentBroj, Count(tRN.IDRN) AS CountOfIDRN
FROM tRN
GROUP BY tRN.IdentBroj
HAVING (((tRN.IdentBroj)="7701/164-1") AND ((Count(tRN.IDRN))>1))
ORDER BY tRN.IdentBroj;


-- =====================================================
-- Query: Query2
-- =====================================================
SELECT tStavkeRN.IDRN, tStavkeRN.Operacija, Count(tStavkeRN.IDStavkeRN) AS CountOfIDStavkeRN
FROM tRN INNER JOIN tStavkeRN ON tRN.IDRN = tStavkeRN.IDRN
WHERE (((tRN.DatumUnosa)>#1/1/2024#))
GROUP BY tStavkeRN.IDRN, tStavkeRN.Operacija
ORDER BY Count(tStavkeRN.IDStavkeRN) DESC;


-- =====================================================
-- Query: Query3
-- =====================================================
SELECT tTehPostupak.*
FROM tOperacije INNER JOIN tTehPostupak ON tOperacije.RJgrupaRC = tTehPostupak.RJgrupaRC
WHERE (((tOperacije.ZnacajneOperacijeZaZavrsen)=True));


-- =====================================================
-- Query: Query4
-- =====================================================
SELECT tRN.NazivDela, Count(tRN.IDRN) AS CountOfIDRN
FROM tRN
GROUP BY tRN.NazivDela
ORDER BY Count(tRN.IDRN) DESC;


-- =====================================================
-- Query: Query5
-- =====================================================
SELECT PDMCrtezi.IDCrtez, PDMCrtezi.BrojCrteza, PDMCrtezi.Revizija, PDMCrtezi.KataloskiBroj, PDMCrtezi.Naziv
FROM PDMCrtezi
WHERE (((PDMCrtezi.Nabavka)=False));


-- =====================================================
-- Query: Query6
-- =====================================================
UPDATE tmp_OdlukePredProvera SET tmp_OdlukePredProvera.OdlukaAkcija = 1
WHERE ((([IDNacrtPrim])=71));


-- =====================================================
-- Query: Query7
-- =====================================================
UPDATE PDM_PlaniranjeStavke AS s INNER JOIN tmp_PlanSporneStavke AS d ON s.IDPlanStavka = d.IDPlanStavka SET s.IskljuciNabavku = True, s.OdlukaAkcija = 1, s.Rezervisano = 0, s.ZaNabavku = 0
WHERE (((s.IDPlan)=6) AND ((Nz([d].[OdlukaAkcija],0))=1));


-- =====================================================
-- Query: Query8
-- =====================================================
SELECT PDMCrtezi.BrojCrteza, PDMCrtezi.DIVUnosa
FROM EXT_R_Artikli INNER JOIN PDMCrtezi ON EXT_R_Artikli.[Kataloski broj] = PDMCrtezi.KataloskiBroj
ORDER BY PDMCrtezi.DIVUnosa DESC;


-- =====================================================
-- Query: Query9
-- =====================================================
SELECT PDMCrtezi.BrojCrteza, PDMCrtezi_1.BrojCrteza, PDMCrtezi_1.RN
FROM PDMCrtezi AS PDMCrtezi_1 INNER JOIN (KomponentePDMCrteza INNER JOIN (EXT_R_Artikli INNER JOIN PDMCrtezi ON EXT_R_Artikli.[Kataloski broj] = PDMCrtezi.KataloskiBroj) ON KomponentePDMCrteza.TrebaIDCrtez = PDMCrtezi.IDCrtez) ON PDMCrtezi_1.IDCrtez = KomponentePDMCrteza.ZaIDCrtez
WHERE (((PDMCrtezi.Nabavka)=True))
GROUP BY PDMCrtezi.BrojCrteza, PDMCrtezi_1.BrojCrteza, PDMCrtezi_1.RN
HAVING (((PDMCrtezi_1.RN)<>"0001"))
ORDER BY PDMCrtezi_1.BrojCrteza;


-- =====================================================
-- Query: RazlikeIzmedju_tRN_tTehPostupak
-- =====================================================
SELECT tTehPostupak.IDPostupka, tRN.IDRN, Predmeti_1.BrojPredmeta AS TP_BrojPredmet, tTehPostupak.IdentBroj AS TP_IdentBroj, tTehPostupak.Varijanta AS TP_Varijanta, tTehPostupak.PrnTimer AS TP_PrnTimer, Predmeti.BrojPredmeta, tRN.IdentBroj, tRN.Varijanta, tRN.PrnTimer, [tTehPostupak].[IDPredmet]<>[tRN].[IDPredmet] AS IDPredmetRazlika, [tTehPostupak].[IdentBroj]<>[tRN].[IdentBroj] AS IdentBrojRazlika, [tTehPostupak].[Varijanta]<>[tRN].[Varijanta] AS VarijantaRazlika, [tTehPostupak].[PrnTimer]<>[tRN].[PrnTimer] AS PrnTimerRazlika
FROM Predmeti AS Predmeti_1 INNER JOIN (Predmeti INNER JOIN (tTehPostupak INNER JOIN tRN ON tTehPostupak.IDRN = tRN.IDRN) ON Predmeti.IDPredmet = tRN.IDPredmet) ON Predmeti_1.IDPredmet = tTehPostupak.IDPredmet
WHERE ((([tTehPostupak].[IDPredmet]<>[tRN].[IDPredmet])=True)) OR ((([tTehPostupak].[IdentBroj]<>[tRN].[IdentBroj])=True)) OR ((([tTehPostupak].[Varijanta]<>[tRN].[Varijanta])=True)) OR ((([tTehPostupak].[PrnTimer]<>[tRN].[PrnTimer])=True))
ORDER BY Predmeti_1.BrojPredmeta, tTehPostupak.IdentBroj, tTehPostupak.Varijanta, tTehPostupak.PrnTimer;


-- =====================================================
-- Query: RNPregledPostupci
-- =====================================================
SELECT tRN.IDPredmet, tRN.IdentBroj, tRN.Varijanta, tStavkeRN_PotrebnoVreme.Operacija, tStavkeRN_PotrebnoVreme.RJgrupaRC, tStavkeRN_PotrebnoVreme.UkupnoVreme, tRN.Komada AS PotrebnoKomada, Nz([UtrosenoVremeURadu],0)/3600 AS VremeUtroseno, Nz([SumOfKomada],0) AS NapravljenoKomada, RNPregledPostupci_1K.ImeIPrezime, CDbl([tStavkeRN_PotrebnoVreme].[Komada]-Nz([SumOfKomada],0)) AS PreostaloKomada
FROM tRN INNER JOIN (RNPregledPostupci_1K RIGHT JOIN tStavkeRN_PotrebnoVreme ON (RNPregledPostupci_1K.Operacija = tStavkeRN_PotrebnoVreme.Operacija) AND (RNPregledPostupci_1K.Varijanta = tStavkeRN_PotrebnoVreme.Varijanta) AND (RNPregledPostupci_1K.IdentBroj = tStavkeRN_PotrebnoVreme.IdentBroj) AND (RNPregledPostupci_1K.IDPredmet = tStavkeRN_PotrebnoVreme.IDPredmet)) ON (tRN.IDPredmet = tStavkeRN_PotrebnoVreme.IDPredmet) AND (tRN.IdentBroj = tStavkeRN_PotrebnoVreme.IdentBroj) AND (tRN.Varijanta = tStavkeRN_PotrebnoVreme.Varijanta)
WHERE (((IIf(CDbl([tStavkeRN_PotrebnoVreme].[Komada]-Nz([SumOfKomada],0))=0,True,False)) Like CStr(Nz([Forms]![RNPregledZag]![RNPregledPostupciPodforma].[Form]![CheckZavrseno],"*"))))
ORDER BY tStavkeRN_PotrebnoVreme.Operacija;


-- =====================================================
-- Query: RNPregledPostupci_1K
-- =====================================================
SELECT tTehPostupak.IDPredmet, tTehPostupak.IdentBroj, tTehPostupak.Varijanta, tTehPostupak.Operacija, tTehPostupak.RJgrupaRC, tTehPostupak.SifraRadnika, tRadnici.Radnik, tRadnici.ImeIPrezime, Sum(tTehPostupak.Komada) AS SumOfKomada, Sum(DateDiff("s",[DatumIVremeUnosa],[DatumIVremeZavrsetka])) AS UtrosenoVremeURadu
FROM tRadnici INNER JOIN tTehPostupak ON tRadnici.SifraRadnika = tTehPostupak.SifraRadnika
GROUP BY tTehPostupak.IDPredmet, tTehPostupak.IdentBroj, tTehPostupak.Varijanta, tTehPostupak.Operacija, tTehPostupak.RJgrupaRC, tTehPostupak.SifraRadnika, tRadnici.Radnik, tRadnici.ImeIPrezime;


-- =====================================================
-- Query: Robna dokumenta
-- =====================================================
SELECT [EXT_T_Robna dokumenta].*
FROM [EXT_T_Robna dokumenta]
WHERE ((([EXT_T_Robna dokumenta].Level)<=F_NivoBaze()));


-- =====================================================
-- Query: Robne stavke
-- =====================================================
SELECT [EXT_T_Robne stavke].*
FROM [Robna dokumenta] INNER JOIN [EXT_T_Robne stavke] ON [Robna dokumenta].IDDok = [EXT_T_Robne stavke].IDDok;


-- =====================================================
-- Query: Sortirana tTehPostupak
-- =====================================================
SELECT tTehPostupak.*
FROM tTehPostupak
ORDER BY tTehPostupak.IDPostupka DESC;


-- =====================================================
-- Query: Stanje kolicina na dan
-- =====================================================
SELECT DISTINCTROW [Robne stavke].[Sifra artikla], Sum(IIf([Ulaz],[Kolicina],-[Kolicina])) AS PlusMinusKolicina
FROM [Robna dokumenta] INNER JOIN [Robne stavke] ON [Robna dokumenta].IDDok = [Robne stavke].IDDok
WHERE ((([Robna dokumenta].[Datum dokumenta])<=[Forms]![Lager lista]![Na dan]) AND (([Robna dokumenta].[Vrsta dokumenta])<>"KODJ") AND (([Robne stavke].IDMagacin) Like IIf(IsNull([Forms]![Lager lista]![ZaMagacin]),"*",[Forms]![Lager lista]![ZaMagacin])) AND (([Robna dokumenta].Level) Between [Forms]![Lager lista]![OdLevel] And [Forms]![Lager lista]![DoLevel]))
GROUP BY [Robne stavke].[Sifra artikla];


-- =====================================================
-- Query: StornirajTehPostupak
-- =====================================================
INSERT INTO tTehPostupak ( SifraRadnika, IDPredmet, IdentBroj, Varijanta, PrnTimer, DatumIVremeUnosa, Operacija, RJgrupaRC, Toznaka, Komada, Potpis, SimbolRadnik, SimbolPostupak, SimbolOperacija, DatumIVremeZavrsetka, ZavrsenPostupak, Napomena )
SELECT tTehPostupak.SifraRadnika, tTehPostupak.IDPredmet, tTehPostupak.IdentBroj, tTehPostupak.Varijanta, F_Timer() AS Expr3, Now() AS Expr2, tTehPostupak.Operacija, tTehPostupak.RJgrupaRC, tTehPostupak.Toznaka, CLng([Forms]![BarKod_Ispravka]![StornirajKomada])*(-1) AS Expr1, tTehPostupak.Potpis, tTehPostupak.SimbolRadnik, tTehPostupak.SimbolPostupak, tTehPostupak.SimbolOperacija, Now() AS Expr4, True AS Expr5, "STORNIRAN POSTUPAK" AS Expr6
FROM tTehPostupak
WHERE (((tTehPostupak.IDPostupka)=[Forms]![BarKod_Ispravka]![IDPostupka]));


-- =====================================================
-- Query: SveOperacijeSaBrojemNezavrsenihKomada
-- =====================================================
SELECT DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IDPredmet, DetaljnoStavkeRN.IdentBroj, DetaljnoStavkeRN.Varijanta, DetaljnoStavkeRN.Operacija, DetaljnoStavkeRN.RJgrupaRC, [Komada]-Nz([NapravljenBrojKomada],0) AS Razlika
FROM ((DetaljnoStavkeRN LEFT JOIN tTehPostupak_NapravljenoKomada ON (DetaljnoStavkeRN.RJgrupaRC = tTehPostupak_NapravljenoKomada.RJgrupaRC) AND (DetaljnoStavkeRN.Operacija = tTehPostupak_NapravljenoKomada.Operacija) AND (DetaljnoStavkeRN.Varijanta = tTehPostupak_NapravljenoKomada.Varijanta) AND (DetaljnoStavkeRN.IdentBroj = tTehPostupak_NapravljenoKomada.IdentBroj) AND (DetaljnoStavkeRN.IDPredmet = tTehPostupak_NapravljenoKomada.IDPredmet)) INNER JOIN tOperacije ON DetaljnoStavkeRN.RJgrupaRC = tOperacije.RJgrupaRC) LEFT JOIN SviZavrseniNalozi ON DetaljnoStavkeRN.IDRN = SviZavrseniNalozi.IDRN
WHERE (((SviZavrseniNalozi.IDRN) Is Null))
GROUP BY DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IDPredmet, DetaljnoStavkeRN.IdentBroj, DetaljnoStavkeRN.Varijanta, DetaljnoStavkeRN.Operacija, DetaljnoStavkeRN.RJgrupaRC, [Komada]-Nz([NapravljenBrojKomada],0)
HAVING (((DetaljnoStavkeRN.IDRN)<>0) AND (([Komada]-Nz([NapravljenBrojKomada],0))<>0))
ORDER BY DetaljnoStavkeRN.IDRN;


-- =====================================================
-- Query: SveOperacijeSaBrojemNezavrsenihKomada_1K
-- =====================================================
SELECT DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IDPredmet, DetaljnoStavkeRN.IdentBroj, DetaljnoStavkeRN.Varijanta, DetaljnoStavkeRN.Operacija, DetaljnoStavkeRN.RJgrupaRC, [Komada]-Nz([NapravljenBrojKomada],0) AS Razlika, tOperacije.ZnacajneOperacijeZaZavrsen
FROM (DetaljnoStavkeRN LEFT JOIN tTehPostupak_NapravljenoKomada ON (DetaljnoStavkeRN.RJgrupaRC = tTehPostupak_NapravljenoKomada.RJgrupaRC) AND (DetaljnoStavkeRN.Operacija = tTehPostupak_NapravljenoKomada.Operacija) AND (DetaljnoStavkeRN.Varijanta = tTehPostupak_NapravljenoKomada.Varijanta) AND (DetaljnoStavkeRN.IdentBroj = tTehPostupak_NapravljenoKomada.IdentBroj) AND (DetaljnoStavkeRN.IDPredmet = tTehPostupak_NapravljenoKomada.IDPredmet)) INNER JOIN tOperacije ON DetaljnoStavkeRN.RJgrupaRC = tOperacije.RJgrupaRC
GROUP BY DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IDPredmet, DetaljnoStavkeRN.IdentBroj, DetaljnoStavkeRN.Varijanta, DetaljnoStavkeRN.Operacija, DetaljnoStavkeRN.RJgrupaRC, [Komada]-Nz([NapravljenBrojKomada],0), tOperacije.ZnacajneOperacijeZaZavrsen
HAVING (((DetaljnoStavkeRN.IDRN)<>0))
ORDER BY DetaljnoStavkeRN.IDRN;


-- =====================================================
-- Query: SviKrajPostupciSaBrojemKomada
-- =====================================================
SELECT DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IDPredmet, DetaljnoStavkeRN.IdentBroj, DetaljnoStavkeRN.Varijanta, Max(DetaljnoStavkeRN.Operacija) AS OperacijaKaoKrajProizvodnje, DetaljnoStavkeRN.RJgrupaRC, [Komada]-Nz([NapravljenBrojKomada],0) AS Razlika
FROM (DetaljnoStavkeRN LEFT JOIN tTehPostupak_NapravljenoKomada ON (DetaljnoStavkeRN.RJgrupaRC = tTehPostupak_NapravljenoKomada.RJgrupaRC) AND (DetaljnoStavkeRN.Operacija = tTehPostupak_NapravljenoKomada.Operacija) AND (DetaljnoStavkeRN.Varijanta = tTehPostupak_NapravljenoKomada.Varijanta) AND (DetaljnoStavkeRN.IdentBroj = tTehPostupak_NapravljenoKomada.IdentBroj) AND (DetaljnoStavkeRN.IDPredmet = tTehPostupak_NapravljenoKomada.IDPredmet)) INNER JOIN tOperacije ON DetaljnoStavkeRN.RJgrupaRC = tOperacije.RJgrupaRC
WHERE (((tOperacije.ZnacajneOperacijeZaZavrsen)=True))
GROUP BY DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IDPredmet, DetaljnoStavkeRN.IdentBroj, DetaljnoStavkeRN.Varijanta, DetaljnoStavkeRN.RJgrupaRC, [Komada]-Nz([NapravljenBrojKomada],0)
HAVING (((DetaljnoStavkeRN.IDRN)<>0))
ORDER BY DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IdentBroj;


-- =====================================================
-- Query: SviPostupciSaBrojemKomada
-- =====================================================
SELECT DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IDPredmet, DetaljnoStavkeRN.IdentBroj, DetaljnoStavkeRN.Varijanta, DetaljnoStavkeRN.Operacija, DetaljnoStavkeRN.RJgrupaRC, [Komada]-Nz([NapravljenBrojKomada],0) AS Razlika, DetaljnoStavkeRN.UkupnoVreme AS NormiranoVreme, Sum(([Komada]-Nz([NapravljenBrojKomada],0))*[VremePoKomadu]) AS PreostaloVreme_, DetaljnoStavkeRN.VremePripreme
FROM (DetaljnoStavkeRN LEFT JOIN tTehPostupak_NapravljenoKomada ON (DetaljnoStavkeRN.RJgrupaRC = tTehPostupak_NapravljenoKomada.RJgrupaRC) AND (DetaljnoStavkeRN.Operacija = tTehPostupak_NapravljenoKomada.Operacija) AND (DetaljnoStavkeRN.Varijanta = tTehPostupak_NapravljenoKomada.Varijanta) AND (DetaljnoStavkeRN.IdentBroj = tTehPostupak_NapravljenoKomada.IdentBroj) AND (DetaljnoStavkeRN.IDPredmet = tTehPostupak_NapravljenoKomada.IDPredmet)) INNER JOIN tOperacije ON DetaljnoStavkeRN.RJgrupaRC = tOperacije.RJgrupaRC
WHERE (((DetaljnoStavkeRN.RJgrupaRC) Like CStr(Nz([Forms]![RNPregledZag]![ZaRJgrupaRC],"-"))))
GROUP BY DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IDPredmet, DetaljnoStavkeRN.IdentBroj, DetaljnoStavkeRN.Varijanta, DetaljnoStavkeRN.Operacija, DetaljnoStavkeRN.RJgrupaRC, [Komada]-Nz([NapravljenBrojKomada],0), DetaljnoStavkeRN.UkupnoVreme, DetaljnoStavkeRN.VremePripreme
HAVING (((DetaljnoStavkeRN.IDRN)<>0))
ORDER BY DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IdentBroj, DetaljnoStavkeRN.Operacija;


-- =====================================================
-- Query: SviPostupciSaBrojemKomadaPoRadniku
-- =====================================================
SELECT DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IDPredmet, DetaljnoStavkeRN.IdentBroj, DetaljnoStavkeRN.Varijanta, DetaljnoStavkeRN.Operacija, DetaljnoStavkeRN.RJgrupaRC, tTehPostupak_NapravljenoKomada.SifraRadnika, [Komada]-Nz([NapravljenBrojKomada],0) AS Razlika, DetaljnoStavkeRN.UkupnoVreme AS NormiranoVreme, Sum(([Komada]-Nz([NapravljenBrojKomada],0))*[VremePoKomadu]) AS PreostaloVreme_, DetaljnoStavkeRN.VremePripreme
FROM (DetaljnoStavkeRN LEFT JOIN tTehPostupak_NapravljenoKomada ON (DetaljnoStavkeRN.RJgrupaRC = tTehPostupak_NapravljenoKomada.RJgrupaRC) AND (DetaljnoStavkeRN.Operacija = tTehPostupak_NapravljenoKomada.Operacija) AND (DetaljnoStavkeRN.Varijanta = tTehPostupak_NapravljenoKomada.Varijanta) AND (DetaljnoStavkeRN.IdentBroj = tTehPostupak_NapravljenoKomada.IdentBroj) AND (DetaljnoStavkeRN.IDPredmet = tTehPostupak_NapravljenoKomada.IDPredmet)) INNER JOIN tOperacije ON DetaljnoStavkeRN.RJgrupaRC = tOperacije.RJgrupaRC
WHERE (((CStr(Nz([SifraRadnika],0))) Like CStr(Nz([Forms]![RNPregledZag]![ZaRadnika],"-"))))
GROUP BY DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IDPredmet, DetaljnoStavkeRN.IdentBroj, DetaljnoStavkeRN.Varijanta, DetaljnoStavkeRN.Operacija, DetaljnoStavkeRN.RJgrupaRC, tTehPostupak_NapravljenoKomada.SifraRadnika, [Komada]-Nz([NapravljenBrojKomada],0), DetaljnoStavkeRN.UkupnoVreme, DetaljnoStavkeRN.VremePripreme
HAVING (((DetaljnoStavkeRN.IDRN)<>0))
ORDER BY DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IdentBroj, DetaljnoStavkeRN.Operacija;


-- =====================================================
-- Query: SviPostupciSaUtrosenimVremenom
-- =====================================================
SELECT DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IDPredmet, Sum(Nz([VremeProvedenoURadu],0)) AS UtrosenoVreme, Sum(DetaljnoStavkeRN.UkupnoVreme) AS NormiranoVreme
FROM DetaljnoStavkeRN LEFT JOIN tTehPostupak_NapravljenoKomada ON (DetaljnoStavkeRN.RJgrupaRC = tTehPostupak_NapravljenoKomada.RJgrupaRC) AND (DetaljnoStavkeRN.Operacija = tTehPostupak_NapravljenoKomada.Operacija) AND (DetaljnoStavkeRN.Varijanta = tTehPostupak_NapravljenoKomada.Varijanta) AND (DetaljnoStavkeRN.IdentBroj = tTehPostupak_NapravljenoKomada.IdentBroj) AND (DetaljnoStavkeRN.IDPredmet = tTehPostupak_NapravljenoKomada.IDPredmet)
GROUP BY DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IDPredmet
HAVING (((DetaljnoStavkeRN.IDRN)<>0))
ORDER BY DetaljnoStavkeRN.IDRN;


-- =====================================================
-- Query: SviPostupciSaUtrosenimVremenomPoRadniku
-- =====================================================
SELECT DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IDPredmet, DetaljnoStavkeRN.Operacija, DetaljnoStavkeRN.RJgrupaRC, tTehPostupak_NapravljenoKomada.SifraRadnika, Sum(Nz([VremeProvedenoURadu],0)) AS UtrosenoVreme, Sum(DetaljnoStavkeRN.UkupnoVreme) AS NormiranoVreme, Sum([Komada]-Nz([NapravljenBrojKomada],0)) AS Razlika, Sum(([Komada]-Nz([NapravljenBrojKomada],0))*[VremePoKomadu]) AS PreostaloVreme
FROM DetaljnoStavkeRN INNER JOIN tTehPostupak_NapravljenoKomada ON (DetaljnoStavkeRN.RJgrupaRC = tTehPostupak_NapravljenoKomada.RJgrupaRC) AND (DetaljnoStavkeRN.Operacija = tTehPostupak_NapravljenoKomada.Operacija) AND (DetaljnoStavkeRN.Varijanta = tTehPostupak_NapravljenoKomada.Varijanta) AND (DetaljnoStavkeRN.IdentBroj = tTehPostupak_NapravljenoKomada.IdentBroj) AND (DetaljnoStavkeRN.IDPredmet = tTehPostupak_NapravljenoKomada.IDPredmet)
GROUP BY DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IDPredmet, DetaljnoStavkeRN.Operacija, DetaljnoStavkeRN.RJgrupaRC, tTehPostupak_NapravljenoKomada.SifraRadnika
HAVING (((DetaljnoStavkeRN.IDRN)<>0))
ORDER BY DetaljnoStavkeRN.IDRN;


-- =====================================================
-- Query: SviPostupciSaUtrosenimVremenomPoRJ
-- =====================================================
SELECT DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IDPredmet, DetaljnoStavkeRN.Operacija, DetaljnoStavkeRN.RJgrupaRC, Sum(Nz([VremeProvedenoURadu],0)) AS UtrosenoVreme, Sum(DetaljnoStavkeRN.UkupnoVreme) AS NormiranoVreme
FROM DetaljnoStavkeRN LEFT JOIN tTehPostupak_NapravljenoKomada ON (DetaljnoStavkeRN.RJgrupaRC = tTehPostupak_NapravljenoKomada.RJgrupaRC) AND (DetaljnoStavkeRN.Operacija = tTehPostupak_NapravljenoKomada.Operacija) AND (DetaljnoStavkeRN.Varijanta = tTehPostupak_NapravljenoKomada.Varijanta) AND (DetaljnoStavkeRN.IdentBroj = tTehPostupak_NapravljenoKomada.IdentBroj) AND (DetaljnoStavkeRN.IDPredmet = tTehPostupak_NapravljenoKomada.IDPredmet)
GROUP BY DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IDPredmet, DetaljnoStavkeRN.Operacija, DetaljnoStavkeRN.RJgrupaRC
HAVING (((DetaljnoStavkeRN.IDRN)<>0))
ORDER BY DetaljnoStavkeRN.IDRN;


-- =====================================================
-- Query: SviZavrseniNalozi
-- =====================================================
SELECT SviZavrseniNalozi_1K.IDRN, SviZavrseniNalozi_1K.IDPredmet, SviZavrseniNalozi_1K.IdentBroj, SviZavrseniNalozi_1K.Varijanta, SviZavrseniNalozi_1K.Operacija, SviZavrseniNalozi_1K.RJgrupaRC, SviZavrseniNalozi_1K.Razlika, SviZavrseniNalozi_1K.ZnacajneOperacijeZaZavrsen
FROM SviZavrseniNalozi_1K
WHERE ((([Razlika]=0 And [ZnacajneOperacijeZaZavrsen]=True)=True))
ORDER BY SviZavrseniNalozi_1K.IDPredmet, SviZavrseniNalozi_1K.IdentBroj, SviZavrseniNalozi_1K.Operacija;


-- =====================================================
-- Query: SviZavrseniNalozi_1K
-- =====================================================
SELECT DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IDPredmet, DetaljnoStavkeRN.IdentBroj, DetaljnoStavkeRN.Varijanta, DetaljnoStavkeRN.Operacija, DetaljnoStavkeRN.RJgrupaRC, [Komada]-Nz([NapravljenBrojKomada],0) AS Razlika, tOperacije.ZnacajneOperacijeZaZavrsen
FROM (DetaljnoStavkeRN LEFT JOIN tTehPostupak_NapravljenoKomada ON (DetaljnoStavkeRN.RJgrupaRC = tTehPostupak_NapravljenoKomada.RJgrupaRC) AND (DetaljnoStavkeRN.Operacija = tTehPostupak_NapravljenoKomada.Operacija) AND (DetaljnoStavkeRN.Varijanta = tTehPostupak_NapravljenoKomada.Varijanta) AND (DetaljnoStavkeRN.IdentBroj = tTehPostupak_NapravljenoKomada.IdentBroj) AND (DetaljnoStavkeRN.IDPredmet = tTehPostupak_NapravljenoKomada.IDPredmet)) INNER JOIN tOperacije ON DetaljnoStavkeRN.RJgrupaRC = tOperacije.RJgrupaRC
GROUP BY DetaljnoStavkeRN.IDRN, DetaljnoStavkeRN.IDPredmet, DetaljnoStavkeRN.IdentBroj, DetaljnoStavkeRN.Varijanta, DetaljnoStavkeRN.Operacija, DetaljnoStavkeRN.RJgrupaRC, [Komada]-Nz([NapravljenBrojKomada],0), tOperacije.ZnacajneOperacijeZaZavrsen
HAVING (((DetaljnoStavkeRN.IDRN)<>0))
ORDER BY DetaljnoStavkeRN.IDRN;


-- =====================================================
-- Query: Tehnolog
-- =====================================================
SELECT tRadnici.SifraRadnika, tRadnici.ImeIPrezime
FROM tRadnici
WHERE (((tRadnici.IDVrsteRadnika)=1));


-- =====================================================
-- Query: tPDM_IDRN
-- =====================================================
SELECT Max(tPDM.IDStavkePDM) AS IDStavke_tPDM, tPDM.IDRN
FROM tPDM
GROUP BY tPDM.IDRN;


-- =====================================================
-- Query: tPLP_IDRN
-- =====================================================
SELECT Max(tPLP.IDStavkePLP) AS IDStavke_tPLP, tPLP.IDRN
FROM tPLP
GROUP BY tPLP.IDRN;


-- =====================================================
-- Query: tPND_IDRN
-- =====================================================
SELECT Max(tPND.IDStavkePND) AS IDStavke_tPND, tPND.IDRN
FROM tPND
GROUP BY tPND.IDRN;


-- =====================================================
-- Query: tStavkeRN_BrOperacija
-- =====================================================
SELECT tOperacije.IDRadneJedinice AS ID
FROM tOperacije INNER JOIN tStavkeRN ON tOperacije.RJgrupaRC = tStavkeRN.RJgrupaRC
WHERE (((tStavkeRN.IDRN)=[Forms]![UnosRN]![IDRN]))
GROUP BY tOperacije.IDRadneJedinice
HAVING (((Count(tOperacije.IDRadneJedinice))>1))
ORDER BY tOperacije.IDRadneJedinice;


-- =====================================================
-- Query: tStavkeRN_PotrebnoVreme
-- =====================================================
SELECT tRN.IDPredmet, tRN.IdentBroj, tRN.Varijanta, tStavkeRN.Operacija, tStavkeRN.RJgrupaRC, tRN.Komada, [Tpz]+([Tk]*[Komada]) AS UkupnoVreme
FROM tRN INNER JOIN tStavkeRN ON tRN.IDRN = tStavkeRN.IDRN
WHERE (((CStr([tRN].[IDPredmet])) Like CStr(Nz([Forms]![RNPregledZag]![RNPregledPodforma].[Form]![IDPredmet],"*"))) AND ((CStr([tRN].[IdentBroj])) Like CStr(Nz([Forms]![RNPregledZag]![RNPregledPodforma].[Form]![IdentBroj],"*"))) AND ((CStr([tRN].[Varijanta])) Like CStr(Nz([Forms]![RNPregledZag]![RNPregledPodforma].[Form]![Varijanta],"*"))))
GROUP BY tRN.IDPredmet, tRN.IdentBroj, tRN.Varijanta, tStavkeRN.Operacija, tStavkeRN.RJgrupaRC, tRN.Komada, [Tpz]+([Tk]*[Komada]);


-- =====================================================
-- Query: tTehPostupak_NapravljenoKomada
-- =====================================================
SELECT tTehPostupak.IDPredmet, tTehPostupak.IdentBroj, tTehPostupak.Varijanta, tTehPostupak.Operacija, tTehPostupak.RJgrupaRC, tTehPostupak.SifraRadnika, Min(tTehPostupak.DatumIVremeUnosa) AS MinOfDatumIVremeUnosa, Max(tTehPostupak.DatumIVremeZavrsetka) AS MaxOfDatumIVremeZavrsetka, Sum(tTehPostupak.Komada) AS NapravljenBrojKomada, Sum(Round(DateDiff("s",[DatumIVremeUnosa],[DatumIVremeZavrsetka])/3600,4)) AS VremeProvedenoURadu, Sum(Round(DateDiff("n",[DatumIVremeUnosa],[DatumIVremeZavrsetka]),4)) AS VremeProvedenoURaduMin, Sum(DateDiff("s",[DatumIVremeUnosa],[DatumIVremeZavrsetka])) AS VremeUSekundama, Sum(BrojSatiUSekundama(BrojSekundiUIntervalu([DatumIVremeUnosa],[DatumIVremeZavrsetka]))) AS Sati, Sum(BrojMinutaUSekundama(BrojSekundiUIntervalu([DatumIVremeUnosa],[DatumIVremeZavrsetka]))) AS Minuti
FROM tTehPostupak
GROUP BY tTehPostupak.IDPredmet, tTehPostupak.IdentBroj, tTehPostupak.Varijanta, tTehPostupak.Operacija, tTehPostupak.RJgrupaRC, tTehPostupak.SifraRadnika;


-- =====================================================
-- Query: tTehPostupak_Q
-- =====================================================
SELECT tTehPostupak.IDPredmet, tTehPostupak.IdentBroj, tTehPostupak.Varijanta
FROM tTehPostupak
GROUP BY tTehPostupak.IDPredmet, tTehPostupak.IdentBroj, tTehPostupak.Varijanta;


-- =====================================================
-- Query: UnosStatusaDokumenta
-- =====================================================
SELECT T_StatusDokumenata.*, [T_Robna dokumenta].[Broj dokumenta] AS Expr1, [T_Robna dokumenta].[Vrsta dokumenta] AS Expr2, [T_Robna dokumenta].[Datum dokumenta] AS Expr3, [T_Robna dokumenta].IDDok AS DokIDDok, Komitenti.Naziv AS Expr4, Komitenti.Poslovnica AS Expr5, Komitenti.Mesto AS Expr6
FROM T_StatusDokumenata, [T_Robna dokumenta], Komitenti;


-- =====================================================
-- Query: UnosStavkiSerijeStatusa
-- =====================================================
SELECT DISTINCTROW tTehPostupakStavke.IDPostupka, tTehPostupak.IDPredmet, tTehPostupak.IdentBroj, tTehPostupak.Varijanta, tTehPostupakStavke.Operacija, tTehPostupakStavke.RJgrupaRC, tTehPostupakStavke.Toznaka, tTehPostupakStavke.Komada
FROM tTehPostupak INNER JOIN tTehPostupakStavke ON tTehPostupak.IDPostupka=tTehPostupakStavke.IDPostupka;


-- =====================================================
-- Query: ZahteviZaNabavkuPregled
-- =====================================================
SELECT EXT_ZahteviZaNabavku.*, EXT_Prodavci.Prodavac AS InicijatorZahtevaIme, Prodavci_1.Prodavac AS OdgovornoLice
FROM ((EXT_ZahteviZaNabavku INNER JOIN EXT_Prodavci ON EXT_ZahteviZaNabavku.InicijatorZahteva = EXT_Prodavci.[Sifra prodavca]) INNER JOIN EXT_Prodavci AS Prodavci_1 ON EXT_ZahteviZaNabavku.IDProdavac = Prodavci_1.[Sifra prodavca]) INNER JOIN PostojeStavkeZahtevaNabavke ON EXT_ZahteviZaNabavku.IDZahtevaZaNabavku = PostojeStavkeZahtevaNabavke.IDZahtevaZaNabavku
WHERE (((EXT_ZahteviZaNabavku.BrojZahteva) Like Nz([Forms]![ZahteviZaNabavku]![ZaBrojZahteva],"*")) AND ((EXT_ZahteviZaNabavku.DatumZahteva) Between IIf(IsNull([Forms]![ZahteviZaNabavku]![Od Datuma]),#1/1/1991#,[Forms]![ZahteviZaNabavku]![Od Datuma]) And IIf(IsNull([Forms]![ZahteviZaNabavku]![Do datuma]),#12/31/2099#,[Forms]![ZahteviZaNabavku]![Do datuma])) AND ((CStr(Nz([EXT_ZahteviZaNabavku].[IDProdavac],0))) Like Nz([Forms]![ZahteviZaNabavku]![ZaProdavca],"*")) AND ((CStr(Nz([IDStatus],"<<NULL>>"))) Like Nz([Forms]![ZahteviZaNabavku]![ZaStatus],"*")) AND ((CStr(Nz([InicijatorZahteva],0))) Like Nz([Forms]![ZahteviZaNabavku]![ZaInicijatoraZahteva],"*")) AND ((EXT_ZahteviZaNabavku.IDPredmetDok) Like Nz([Forms]![ZahteviZaNabavku]![ZaBrojPredmeta],"*")))
ORDER BY EXT_ZahteviZaNabavku.Godina DESC , EXT_ZahteviZaNabavku.BrojZahteva DESC , EXT_ZahteviZaNabavku.DatumZahteva DESC;


