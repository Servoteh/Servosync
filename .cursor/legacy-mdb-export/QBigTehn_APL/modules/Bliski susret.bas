Attribute VB_Name = "Bliski susret"
Option Compare Database
Option Explicit


Public Const POSTUJFAKTCENU = True 'Kod VP zbog rabata ...
Public Const POSTUJRAZUCENI = False   'Kod UF za FRIGO je TRUE inace je FALSE
   
  ' #If CDbl(SysCmd(acSysCmdAccessVer)) < 14 Then
    Public Const acExportAllTableAndFieldProperties = 32
    Public Const acSpreadsheetTypeExcel12Xml = 10
    Public Const acFormatPDF = "PDF Format (*.pdf)"
    Public Const acFormatXPS = "XPS Format (*.xps)"
    Public Const acFormatXLSX = "Microsoft Excel Workbook (*.xlsx)"
  ' #End If


Public MyAnswer As Long


'Ukinuto: 27-10-2021 Public IDAktivneBaze As Long
Public AktivnaFirma As String
            
Public BBAktOJ     As Long             'as long ORGANIZACIONA JEDINICA
Public BBAktOD     As Long             'as long ODELJENJE

Public BBUnlockAktGodina As Boolean
Public BBUnlockAktOJ     As Boolean
Public BBUnlockAktOD     As Boolean

Public BBCFG_Initialized As Boolean
Public DefaultPIP 'Kreirano: 19-01-2019
Public BBStart_LogText As String 'Kreirano: 18-01-2021

Private pUzmiCeneIzCenovnika As Variant

Public FinalStartFormName As String  'Dodato: 10-01-2022
Global KeyboardReturn As Double
Global KeyboardDorada As Boolean
Global KeyboardSkart As Boolean
Global KeyboardOperacija As Long
Public KorisnikAplikacije As Long
Public Property Get UzmiCeneIzCenovnika() As Boolean
     If IsEmpty(pUzmiCeneIzCenovnika) Then
        pUzmiCeneIzCenovnika = True
     End If
     UzmiCeneIzCenovnika = CBool(pUzmiCeneIzCenovnika)
End Property
Public Property Get Specijal() As String
    Specijal = RFReadParameter("SPECIJAL")
End Property

Public Property Let UzmiCeneIzCenovnika(vNewValue As Boolean)
    pUzmiCeneIzCenovnika = vNewValue
End Property
Public Property Get ImeFakture() As String
    ImeFakture = "Faktura - " + Specijal
End Property
Public Property Get ImeProfakture() As String
    ImeProfakture = "Profaktura - " + Specijal
End Property
Public Property Get ImeFaktureUsluga() As String
'Modifikovano: 15-01-2023
    'ImeFaktureUsluga = "USLUGA Faktura - " + Specijal
    ImeFaktureUsluga = ReadCFGParametar("RPT.FakturaUsluga")
End Property
Public Property Get ImeFaktureUslugaBezKol() As String
'Modifikovano: 15-01-2023
  'ImeFaktureUslugaBezKol = "UslugaFakturaBezKol - " + Specijal
  ImeFaktureUslugaBezKol = ReadCFGParametar("RPT.FakturaUslugaBezKol")
  If ImeFaktureUslugaBezKol = ImeFaktureUsluga Then
        ImeFaktureUslugaBezKol = "USLUGA Faktura - DEFAULT"
  End If
End Property

Public Property Get ImeKalkulacije() As String
    ImeKalkulacije = "Kalkulacija - " + Specijal
End Property
Public Property Get ImeOtpremnice() As String
'Modifikovano: 26-09-2022
    'ImeOtpremnice = "Otpremnica - " + Specijal
    ImeOtpremnice = ReadCFGParametar("RPT.IF.Otpremnica")
End Property
Public Property Get ImeIzlazneKalkulacije() As String
    ImeIzlazneKalkulacije = "Kalkulacija izlazne fakture - " + Specijal
End Property
Public Property Get ImeIzjave() As String
     ImeIzjave = "Porudzbenica i izjava - " + Specijal
End Property
Public Property Get ImeTrebovanja() As String
 ImeTrebovanja = "Trebovanje - " + Specijal
End Property
Public Property Get KompletFaktura() As Integer
    KompletFaktura = 1
End Property
Public Property Get KompletOtpremnica() As Integer
    KompletOtpremnica = 1
End Property
Public Property Get KompletIzjava() As Integer
    KompletIzjava = 0
End Property

Public Function Postavi_CFG_T_Tabele(Optional RadniFajlovi As Boolean = True, Optional UplatniRacuni As Boolean = True _
                                    , Optional SemeZaKOntiranje As Boolean = True, Optional StavkeSemeZaKontiranje As Boolean = True) As Boolean
'*************************************************
'Kreirano: 12.01.2019.
'Modifikovano: 11-02-2019
'Modifikovano: 26-10-2019 dodati parametri
'Opis: redefiniše upite na osnovu definicaija tabela u CFG_Sys
' "Radni fajlovi"
' "Uplatni racuni"
' "Sema za kontiranje"
' "Stavke seme za kontiranje"
' Ovu funkciju bi trebalo pozvati samo iz forme CFG_Sys kada se menjaju parametri SysTabela...
'26-10-19 Treba je pozvati sa svih mesta gde se forsiraju linkovi ka novoj bazi (kod agencija Forms![IzborRadnogFajla].PoveziSeSaNovomBazom)
'*************************************************

On Error GoTo Err_Point

   Dim st_SysTabelaRadniFajlovi As String
   Dim st_SysTabelaUplatniRacuni As String
   Dim st_SysTabelaSemaZaKontiranje As String
   Dim st_SysTabelaStavkeSemeZaKontiranje As String
   
   Dim retValOk As Boolean
   
    
    '**********************************************************************************************************************
    ' OVDE SE REŠAVA UPITIMA
    '**********************************************************************************************************************
    '   CurrentDb.QueryDefs("Radni fajlovi").SQL = "SELECT * FROM [" & F_SysTabelaRadniFajlovi() & "];"
    '   CurrentDb.QueryDefs("UplatniRacuni").SQL = "SELECT * FROM [" & F_SysTabelaUplatniRacuni() & "];"
    '   CurrentDb.QueryDefs("Sema za kontiranje").SQL = "SELECT * FROM [" & F_SysTabelaSemaZaKontiranje() & "];"
    '   CurrentDb.QueryDefs("Stavke seme za kontiranje").SQL = "SELECT * FROM [" & F_SysTabelaStavkeSemeZaKontiranje() & "];"
    '**********************************************************************************************************************
    
    retValOk = True
    If RadniFajlovi Then
        retValOk = retValOk And ForsirajNoviLinkZaTabelu("Radni fajlovi", SourceTableNameZaTabelu(F_SysTabelaRadniFajlovi()), BazaZaTabelu(F_SysTabelaRadniFajlovi()))
    End If
    If UplatniRacuni Then
        retValOk = retValOk And ForsirajNoviLinkZaTabelu("UplatniRacuni", SourceTableNameZaTabelu(F_SysTabelaUplatniRacuni()), BazaZaTabelu(F_SysTabelaUplatniRacuni()))
    End If
    If SemeZaKOntiranje Then
        retValOk = retValOk And ForsirajNoviLinkZaTabelu("Sema za kontiranje", SourceTableNameZaTabelu(F_SysTabelaSemaZaKontiranje()), BazaZaTabelu(F_SysTabelaSemaZaKontiranje()))
    End If
    If StavkeSemeZaKontiranje Then
        retValOk = retValOk And ForsirajNoviLinkZaTabelu("Stavke seme za kontiranje", SourceTableNameZaTabelu(F_SysTabelaStavkeSemeZaKontiranje()), BazaZaTabelu(F_SysTabelaStavkeSemeZaKontiranje()))
    End If
    
Exit_Point:
    On Error Resume Next
    Postavi_CFG_T_Tabele = retValOk
    Exit Function

Err_Point:
    MsgBox err.Description
    retValOk = False
    Resume Exit_Point
    
End Function

Public Function F_BBAktOJ() As Long
    F_BBAktOJ = BBAktOJ
End Function
Public Function F_BBAktOD() As Long
    F_BBAktOD = BBAktOD
End Function
Public Function F_BBUnlockAktGodina() As Boolean
    F_BBUnlockAktGodina = BBUnlockAktGodina
End Function
Public Function F_BBUnlockAktOJ() As Boolean
    F_BBUnlockAktOJ = BBUnlockAktOJ
End Function
Public Function F_BBUnlockAktOD() As Boolean
    F_BBUnlockAktOD = BBUnlockAktOD
End Function
Public Function F_UFKLStampaOkreni() As Boolean
    F_UFKLStampaOkreni = BBCFG.UFKLStampaOkreni
End Function
Private Function DefaultStart_NeKoristiSeOd_27102021()
    DoCmd.SetWarnings True
End Function

Private Function F_Specijal_NeKoristiSeOd_27102021() As String
    F_Specijal_NeKoristiSeOd_27102021 = Specijal
End Function

Private Sub InicNizObjZaImportovanje_NeKoristiSeOd_27102021()
Dim Glupost As Variant
     Glupost = InicSPECIJAL_NeKoristiSeOd_27102021()
End Sub

Private Function InicSPECIJAL_NeKoristiSeOd_27102021()

 '27-10-2021 Specijal = DLookup("[SPECIJAL]", "Radni fajlovi", "[Naziv baze] = '" & VezaSaBazom() & "'")

 If Not IsNull(Specijal) Then
    '27-10-2021 IDAktivneBaze = DLookup("[IDBaze]", "Radni fajlovi", "[Naziv baze] = '" & VezaSaBazom() & "'")
 Else
    '27-10-2021 Specijal = "DEFAULT"
 End If
 
 '27-10-2021 ImeFakture = "Faktura - " + Specijal
 '27-10-2021 ImeProfakture = "Profaktura - " + Specijal
 '27-10-2021 ImeKalkulacije = "Kalkulacija - " + Specijal
 '27-10-2021 ImeOtpremnice = "Otpremnica - " + Specijal
 '27-10-2021 ImeIzlazneKalkulacije = "Kalkulacija izlazne fakture - " + Specijal
 '27-10-2021 ImeIzjave = "Porudzbenica i izjava - " + Specijal
 '27-10-2021 ImeFaktureUsluga = "USLUGA Faktura - " + Specijal
 '27-10-2021 ImeFaktureUslugaBezKol = "UslugaFakturaBezKol - " + Specijal
 '27-10-2021 ImeTrebovanja = "Trebovanje - " + Specijal

 '27-10-2021 KompletFaktura = 0
 '27-10-2021 KompletOtpremnica = 0
 '27-10-2021 KompletIzjava = 0
 '27-10-2021 UzmiCeneIzCenovnika = True
 
 '27-10-2021 KompletFaktura = 1
 '27-10-2021 KompletOtpremnica = 1
End Function

Function KreirajNovuBazu(OldDbName, NewDbName As String) As Boolean
On Error GoTo Err_kreirajNovuBazu

    Dim strdir As String
    Dim varRet As Boolean
    Dim answ As Long
    
    strdir = Left(NewDbName, InStrRev(NewDbName, "\") - 1)
    MkDir strdir
    If FileExists(NewDbName) Then
            'answ = MsgBox("Fajl " & NewDbName & " vec postoji." & vbCr & _
                    "Ukoliko nastavite sa kreiranjem nove baze ova baza ce biti unistena!" & Chr(13) & _
                    "Da nastavim proces kreiranja baze?", vbExclamation + vbYesNo)
            'If answ <> vbYes Then
            '    varRet = False
            '    GoTo exit_KreirajNovuBazu
            'End If
            MsgBox "Baza " & NewDbName & " vec postoji." & vbCr & _
                    "Nova baza ne moze biti kreirana preko postojece!" _
                    , vbCritical + vbOKOnly
            GoTo exit_KreirajNovuBazu
    End If
    FileCopy OldDbName, NewDbName
    varRet = True

exit_KreirajNovuBazu:

If Not varRet Then
    MsgBox "Nova baza nije kreirana!", vbCritical + vbOKOnly
Else
    MsgBox "Nova baza " & NewDbName & " je uspesno kreirana", vbOKOnly
End If
    KreirajNovuBazu = varRet
Exit Function

Err_kreirajNovuBazu:

    Select Case err.Number
        Case 76
        MsgBox "Ne moze da se kreira folder " & strdir, vbCritical + vbOKOnly
        Case 75
            answ = MsgBox("Folder " & strdir & " vec postoji." & Chr(13) & _
                    "Da nastavim proces kreiranja baze?", vbExclamation + vbYesNo)
            If answ = vbYes Then Resume Next
        Case 53
        MsgBox "Ne postoji fajl iz kog se kreira nova baza: " & OldDbName, vbCritical + vbOKOnly
        Case Else
            MsgBox "ErrNo: " & err.Number & "  " & err.Description
    End Select
    
    varRet = False
    Resume exit_KreirajNovuBazu
    
End Function

Public Function PostojiReport(Name As String) As Boolean
Dim dbs As DAO.Database, ctr As DAO.Container, doc As DAO.Document
Dim postoji As Boolean

    ' Return reference to current database.
    Set dbs = CurrentDb
    ' Return referenct to Reports container.
    Set ctr = dbs.Containers!Reports
    ' Enumerate through Documents collection of Forms container.
    
    postoji = False
    For Each doc In ctr.Documents
        ' Print Document object name and value of LastUpdated property.
       ' Debug.Print doc.name; "      "; doc.LastUpdated
       postoji = postoji Or (doc.Name = Name)
    Next doc
    
    PostojiReport = postoji
    dbs.Close
    Set dbs = Nothing
    Set ctr = Nothing
    Set doc = Nothing
    

End Function
Public Function PostojiForma(Name As String) As Boolean
Dim dbs As DAO.Database, ctr As DAO.Container, doc As DAO.Document
Dim postoji As Boolean

    ' Return reference to current database.
    Set dbs = CurrentDb
    ' Return referenct to Reports container.
    Set ctr = dbs.Containers!Forms
    ' Enumerate through Documents collection of Forms container.
    
    postoji = False
    For Each doc In ctr.Documents
        ' Print Document object name and value of LastUpdated property.
       ' Debug.Print doc.name; "      "; doc.LastUpdated
       postoji = postoji Or (doc.Name = Name)
    Next doc
    
    PostojiForma = postoji
    dbs.Close
    Set dbs = Nothing
    Set ctr = Nothing
    Set doc = Nothing
    

End Function
Public Function IDProdavacZaCurrentUser_BigBit(Optional UserName As String = "", Optional AppendNew) As Long
'*****************************************************************************************
'Kreirano: 27-10-2019
'ako se ne unese UserName onda je = CurrentUser()
'ako se ne unese AppendNew onda je = CBool(ReadCFGParametar("DodajProdavcaZaCurrentUser", False))
'ako UserName nije unet u tabelu prodavci u kolonu PRODAVCI ili IMEPRODAVCA onda ga ova funkcija dodaje
'i vraca njegov ID tj. [Sifra prodavca]
'*****************************************************************************************
On Error GoTo Err_Point
Dim rstProdavci As DAO.Recordset
Dim pstUserName  As String
Dim pboolAppendNew As Boolean
Dim retValIDProdavac As Long

 If Nz(UserName, "") = "" Then
  pstUserName = CurrentUser()
 Else
  pstUserName = UserName
 End If

 Set rstProdavci = CurrentDb.OpenRecordset("Prodavci", RecordsetTypeEnum.dbOpenSnapshot, dbSeeChanges)
 rstProdavci.FindFirst "[Prodavac] = '" & pstUserName & "' Or [ImeProdavca] = '" & pstUserName & "'"
 
 If rstProdavci.NoMatch Then 'Ne postoji i treba ga dodati
    If IsMissing(AppendNew) Then
      pboolAppendNew = CBool(ReadCFGParametar("DodajProdavcaZaCurrentUser", False))
    Else
      pboolAppendNew = CBool(AppendNew)
    End If
    
    If pboolAppendNew Then
        'prvo zatvori rstProdavci jer je dbOpenSnapshot
        rstProdavci.Close
        Set rstProdavci = Nothing
        'pa otvori ponovo sa parametrom dbOpenDynaset
        Set rstProdavci = CurrentDb.OpenRecordset("Prodavci", RecordsetTypeEnum.dbOpenDynaset, dbSeeChanges)
        
        rstProdavci.AddNew
        rstProdavci!Prodavac = Left(pstUserName, rstProdavci.Fields("Prodavac").Size)
        rstProdavci!ImeProdavca = Left(pstUserName, rstProdavci.Fields("ImeProdavca").Size)
        rstProdavci!Password = Left(pstUserName, rstProdavci.Fields("Password").Size)
        If Not IsAutoNumber("Prodavci", "Sifra prodavca") Then
           rstProdavci![Sifra prodavca] = SledeciAutoID("Sifra prodavca", "Prodavci")
        End If
        rstProdavci.Update
        If Not IsAutoNumber("Prodavci", "Sifra prodavca") Then
           retValIDProdavac = rstProdavci![Sifra prodavca]
        Else
            retValIDProdavac = LastIDENTITY
        End If
    Else
        retValIDProdavac = 0
    End If
 Else
   retValIDProdavac = rstProdavci![Sifra prodavca]
 End If


Exit_Point:
On Error Resume Next
 rstProdavci.Close
 Set rstProdavci = Nothing
 IDProdavacZaCurrentUser_BigBit = retValIDProdavac
Exit Function

Err_Point:
 BBErrorMSG err, "IDProdavacZaCurrentUser_BigBit"
 Resume Exit_Point
End Function

Public Function WorkDir() As String
    Dim Path As String
    Path = VezaSaBazom()
    Path = Left$(Path, LastPosInStr(Path, "\"))
    WorkDir = Path
End Function

Public Function LastPosInStr(ustr, trazistr As String) As Long
Dim nPos, nLastPos As Long

nPos = 0
nLastPos = 0

    Do
        nPos = InStr(nPos + 1, ustr, trazistr)
        If nPos > 0 Then nLastPos = nPos
        
    Loop While nPos <> 0
    LastPosInStr = nLastPos
    
End Function

Public Function PostaviGlobalneParametre()
On Error GoTo err_RFReadParameter
    
    If F_CheckLink("BBDefUser") Then
     BBAktOJ = CLng(Nz(DLookup("[DefaultOJ]", "BBDefUser", "[UserName] = '" & CurrentUser() & "'"), 0))
     BBAktOD = CLng(Nz(DLookup("[DefaultOD]", "BBDefUser", "[UserName] = '" & CurrentUser() & "'"), 0))
    
     BBUnlockAktGodina = CBool(Nz(DLookup("[UnlockGodina]", "BBDefUser", "[UserName] = '" & CurrentUser() & "'"), False))
     BBUnlockAktOJ = CBool(Nz(DLookup("[UnlockOJ]", "BBDefUser", "[UserName] = '" & CurrentUser() & "'"), False))
     BBUnlockAktOD = CBool(Nz(DLookup("[UnlockOD]", "BBDefUser", "[UserName] = '" & CurrentUser() & "'"), False))
    Else
     BBAktOJ = 0
     BBAktOD = 0
    
     BBUnlockAktGodina = False
     BBUnlockAktOJ = False
     BBUnlockAktOD = False
    End If
    
    '13-01-2020 Prebaceno u BBCFG.Firma...  PostaviGlobalneParametreIzRadnogFajla
   
     
exit_RFReadParameter:

On Error Resume Next
 
Exit Function

err_RFReadParameter:
    MsgBox "Error: " & err.Number & " " & err.Description
    Resume Next 'exit_RFReadParameter
End Function

Public Function F_BrDecUlKl() As Integer
  F_BrDecUlKl = Nz(BBCFG.Firma.BrDecUlKl, 2)
End Function

Public Function F_BrDecIzKl() As Integer
  F_BrDecIzKl = Nz(BBCFG.Firma.BrDecIzKl, 2)
End Function
Public Function F_KursDeli() As Boolean
  F_KursDeli = BBCFG.Firma.KursDeli
End Function
Public Function F_ProveraZalihaMag() As Boolean
  F_ProveraZalihaMag = BBCFG.ProveraZalihaMag()
  '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!1
  'PROVERI OVO
  '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!1
End Function
Public Function F_ObracunCenaPoMagacinu() As Boolean
'Kreirano: 11-06-2020
  F_ObracunCenaPoMagacinu = BBCFG.ObracunCenaPoMagacinu()
End Function
Public Function F_AutoPodelaPrihoda() As Boolean
    F_AutoPodelaPrihoda = BBCFG.Firma.AutoPodelaPrihoda
End Function
Public Function F_FakturnaJeVPZaUlKl() As Boolean
    F_FakturnaJeVPZaUlKl = BBCFG.Firma.FakturnaJeVPZaUlKl
End Function
Public Function F_KepuPoNabavnojCeni() As Boolean
    F_KepuPoNabavnojCeni = BBCFG.Firma.KepuPoNabavnojCeni
End Function
Public Function F_KepuPoKNGCeni() As Boolean
    F_KepuPoKNGCeni = BBCFG.Firma.KEPUPoKNGCeni
End Function
Public Function F_TrgovackaPoKursu() As Boolean
    F_TrgovackaPoKursu = BBCFG.Firma.TrgovackaPoKursu
End Function
Public Function F_KepuPoKursu() As Boolean
  F_KepuPoKursu = BBCFG.Firma.KepuPoKursu
End Function
Public Function F_GKPoKursu() As Boolean
  F_GKPoKursu = BBCFG.Firma.GKPoKursu
End Function
Public Function F_GKPoKursuObrnuto() As Boolean
  F_GKPoKursuObrnuto = BBCFG.Firma.GKPoKursuObrnuto
End Function

Public Function F_KnjiziRazlikeNaTK() As Boolean
  F_KnjiziRazlikeNaTK = BBCFG.Firma.KnjiziRazlikeNaTK
End Function
Public Function F_KnjiziRazlikeNaKEPU() As Boolean
    F_KnjiziRazlikeNaKEPU = BBCFG.Firma.KnjiziRazlikeNaKEPU
End Function
Public Function F_KnjiziRazlikeNaMPKEPU() As Boolean
  F_KnjiziRazlikeNaMPKEPU = BBCFG.Firma.KnjiziRazlikeNaMPKEPU
End Function
Public Function F_ProveraPorukaInterval() As Long
  F_ProveraPorukaInterval = Nz(BBCFG.Firma.ProveraPorukaInterval, 0) * 1000
End Function
Public Function F_DekodirajBarKod() As Boolean
    F_DekodirajBarKod = BBCFG.Firma.DekodirajBarKod
End Function
Public Function F_Galeb() As Boolean
 F_Galeb = BBCFG.GALEBFP550
End Function
Public Function F_Raster() As Boolean
 F_Raster = BBCFG.Firma.Raster
End Function
Public Function F_ServerZaGaleb() As Boolean
  F_ServerZaGaleb = BBCFG.Firma.ServerZaGaleb
End Function
Public Function F_KlijentZaGaleb() As Boolean
  F_KlijentZaGaleb = BBCFG.Firma.KlijentZaGaleb
End Function
Public Function F_SaljiBosson() As Boolean
  F_SaljiBosson = False 'BBCFG.Firma.SaljiBosson
End Function
Public Function BigBit_UID() As String
Dim retVal As String
 'retval = DLookup("[Naziv Baze]", "Radni fajlovi", "[IDBaze] = " & F_IDAktivneBaze())
 retVal = "ComputerName=" & Environ("ComputerName")
 retVal = retVal & ";IP=" & GetIPAdress()
 retVal = retVal & ";HDSN=" & BBReadRealHDSN()
 retVal = retVal & ";APL=" & CurrentProject.FullName
 'retval = retval & CurrentDb.TableDefs("Cenovnik").Connect
 retVal = retVal & ";CNNString={" & BBCFG.CNNString & "}"
 BigBit_UID = retVal
End Function
Public Function F_DefaultDirNovaBaza()
    F_DefaultDirNovaBaza = BBCFG.DefaultDirNovaBaza
End Function
Public Function F_AutoKatBroj() As Boolean
 F_AutoKatBroj = CBool(Nz(ReadParametar("CFG_Global", "AutoKatBroj"), False))
End Function
Public Function F_ReportNameIF() As String
 'F_ReportNameIF = CStr(Nz(ReadParametar("CFG_Lokal", "RPT.IF"), "Faktura - DEFAULT"))
 F_ReportNameIF = Nz(ReadCFGParametar("RPT.IF", "Faktura - DEFAULT"), "Faktura - DEFAULT")
End Function
Public Function F_ReportNamePROF() As String
 F_ReportNamePROF = Nz(ReadCFGParametar("RPT.PROF", F_ReportNameIF()), "Faktura - DEFAULT")
End Function
Public Function F_UIVrsteDokLimit() As String
On Error GoTo err_Func
Dim UIVrsteDokLimit As String

  UIVrsteDokLimit = Nz(ReadParametar("CFG_Global", "UIVrsteDokLimit"), "UI_*")

exit_Func:
 
 F_UIVrsteDokLimit = UIVrsteDokLimit

Exit Function

err_Func:
 MsgBox "Greška na funkciji F_UIVrsteDokLimit()" & vbCrLf & "Err.Number: " & err.Number & vbCrLf & "Err.Description: " & err.Description
 UIVrsteDokLimit = "UI_*"
 Resume exit_Func
End Function
Public Function MesecRecima(M As Byte) As String
Dim mes As String
Select Case M
          Case 1
          mes = "Januar"
          Case 2
          mes = "Februar"
          Case 3
          mes = "Mart"
          Case 4
          mes = "Aril"
          Case 5
          mes = "Maj"
          Case 6
          mes = "Jun"
          Case 7
          mes = "Jul"
          Case 8
          mes = "Avgust"
          Case 9
          mes = "Septembar"
          Case 10
          mes = "Oktobar"
          Case 11
          mes = "Novembar"
          Case 12
          mes = "Decembar"
                 
    End Select
MesecRecima = Prevedi(mes)

End Function


Public Function F_CheckBBFIT(Optional stBBFit As String = "", Optional ForceNew As Boolean = False) As Boolean
'Modifikovano: 13-12-2020
'Uskladjuje se CNN_FIT sa stvarnim linkom i memorise se kao property

On Error GoTo Err_Point

Dim NovaBaza As String
Dim ImeNoveBaze As String
Dim DobarLink As Boolean
Dim retVal As Boolean
Dim txtSQLUpdate As String
 
 If IsMissing(stBBFit) Or Nz(stBBFit) = "" Then
  NovaBaza = ";DATABASE=" & CurrentDBPath & F_SysBB_FIT() ' "BB_FIT.mdb"
 Else
  NovaBaza = stBBFit
 End If
 
 DobarLink = True
 retVal = True
 
 'DobarLink = DobarLink And SysCheckLink("Baze_Tipovi", 1, False)
 'DobarLink = DobarLink And F_CheckLink("BazeIFirme")
 'DobarLink = DobarLink And F_CheckLink("BazeITabele")
 'DobarLink = DobarLink And F_CheckLink("Baze_CnnString")
 'DobarLink = DobarLink And F_CheckLink("Baze_Firme")
 
 If SysCheckLink("Baze_Tipovi", 1, False) Then
  If SysCheckLink("BazeIFirme", 1, False) Then
   If SysCheckLink("BazeITabele", 1, False) Then
    If SysCheckLink("Baze_CnnString", 1, False) Then
     If SysCheckLink("Baze_Firme", 1, False) Then
        DobarLink = True
     Else
        DobarLink = False
     End If
    Else
       DobarLink = False
    End If
   Else
      DobarLink = False
   End If
  Else
     DobarLink = False
  End If
 Else
    DobarLink = False
 End If
 
 If DobarLink Then
   DobarLink = (FileNameFromPath(CurrentDb.TableDefs("BazeITabele").Connect) = F_SysBB_FIT())
 End If
 
 If Not DobarLink Then
   ImeNoveBaze = Replace(NovaBaza, ";DATABASE=", "")
  If Not FileExists(ImeNoveBaze) Then
    MsgBox F_SysBB_FIT() & " nije dobar!", vbExclamation, "QMegaTeh"
    ImeNoveBaze = OpenFile(ImeNoveBaze)
    If Nz(ImeNoveBaze, "") = "" Then
         retVal = False
        GoTo Exit_Point
    Else
        NovaBaza = ";DATABASE=" & ImeNoveBaze
    End If
  Else
    If CurrentUser = "Negovan" Then
      MsgBox "Bice promenjeni linkovi za FIT." & vbCrLf & "Novi link: " & ImeNoveBaze, vbInformation, "QMegaTeh"
    End If
  End If
 End If
 
 If Not DobarLink Or ForceNew Then
  retVal = retVal And ForsirajNoviLinkZaTabelu("Baze_Tipovi", "Baze_Tipovi", NovaBaza)
  retVal = retVal And ForsirajNoviLinkZaTabelu("BazeIFirme", "BazeIFirme", NovaBaza)
  retVal = retVal And ForsirajNoviLinkZaTabelu("BazeITabele", "BazeITabele", NovaBaza)
  retVal = retVal And ForsirajNoviLinkZaTabelu("Baze_CnnString", "Baze_CnnString", NovaBaza)
  retVal = retVal And ForsirajNoviLinkZaTabelu("Baze_Firme", "Firme", NovaBaza)
   '***********************************************************************************************************
   'Uskladjuje se CNN_FIT sa stvarnim linkom i memorise se kao property
        If retVal Then
          CNN_FIT = CreateAccess_CNNString(ImeNoveBaze) '!!!!! treba koristiti promenljivu ImeNoveBaze jer ona ne sadrži ";DATABASE="
          retVal = BBCreateProperty("CNN_FIT", , CNN_FIT) 'kreira ga ili mu menja vrednost
        Else
         retVal = False
        End If
   '***********************************************************************************************************
 End If
 
 If Not retVal Then
   GoTo Exit_Point
 End If
 
 If Not PostojiPoljeUTabeli("SysFitLevel", CurrentDb.TableDefs("BazeITabele")) Then
  If BBPitanje("Ne postoji polje [SysFitLevel] u tabeli [BazeITabele]." & vbCrLf & "Da li želite da ga kreiram?") Then
   retVal = KreirajPoljeUTabeli(ImeFajlaZaTabelu("BazeITabele"), "BazeITabele", "SysFitLevel", dbInteger, 2, 0)
   If retVal Then
     txtSQLUpdate = "UPDATE [" & "BazeITabele" & "] SET [" & "BazeITabele" & "].[" & "SysFitLevel" & "] = 0;"
      CurrentDb.Execute txtSQLUpdate
   End If
  Else
   retVal = False
  End If
 End If

Exit_Point:
 On Error Resume Next
  F_CheckBBFIT = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "F_CheckBBFIT"
 Resume Exit_Point
End Function

Public Function OtvoriFormuBaze()
On Error GoTo Err_Point
Dim stMsg As String
  
If Not UserUGrupi(CurrentUser(), "PowerfulUsers") Then
    GoTo Exit_Point
End If

  'If F_CheckBBFIT(, True) Then 'do 12-08-18
  If F_CheckBBFIT() Then
   DoCmd.OpenForm "Baze"
  Else
   MsgBox "Ne možete otvoriti formu Baze", vbCritical, "QMegaTeh"
  End If
  
Exit_Point:
Exit Function
Err_Point:
If err.Number = 2501 Then
 MsgBox "Nemate pravo da otvorite formu [Baze]", vbExclamation, "QMegaTeh"
Else
 BBErrorMSG err, "OtvoriFormuBaze"
End If
Resume Exit_Point
End Function
Public Function BBOpenSysForm(stSysFormName As String, Optional SaPitanjem As Boolean = False)
On Error Resume Next

Dim stImeForme As String
    
stImeForme = stSysFormName
If CurrentUser <> "Negovan" Then
    BBOpenForm stImeForme
    Exit Function
End If
If SaPitanjem Then
 stImeForme = InputBox("Koju formu otvaraš?", "QMegaTeh", stImeForme)
End If
If Nz(stImeForme, "") <> "" Then
   DoCmd.OpenForm stImeForme
End If
End Function
Public Sub UnosDozvoljenihCenovnika()
 DoCmd.OpenTable "CEN_DozvoljeniCenovnici", acViewNormal
End Sub
Public Function DozvoljenCenovnik(VrstaDokZaCen As String) As Boolean
 DozvoljenCenovnik = (VrstaDokZaCen = Nz(DLookup("CenVrstaDok", "CEN_DozvoljeniCenovnici", "[CenVrstaDok] = '" & VrstaDokZaCen & "'"), "<<NULL>>"))
End Function
Public Function NZOdDatuma(Optional OdDatuma) As Variant
Const DefaultOdDatuma = "01-01-1901"
Dim retVal
   If IsMissing(OdDatuma) Then
      retVal = DefaultOdDatuma
   ElseIf IsNull(OdDatuma) Then
      retVal = DefaultOdDatuma
   ElseIf Trim(CStr(OdDatuma)) = "" Then
      retVal = DefaultOdDatuma
   Else
      retVal = OdDatuma
   End If
   NZOdDatuma = CVDate(retVal)
End Function
Public Function NZDoDatuma(Optional DoDatuma) As Variant
Const DefaultDoDatuma = "01-01-2991"
Dim retVal
   If IsMissing(DoDatuma) Then
      retVal = DefaultDoDatuma
   ElseIf IsNull(DoDatuma) Then
      retVal = DefaultDoDatuma
   ElseIf Trim(CStr(DoDatuma)) = "" Then
      retVal = DefaultDoDatuma
   Else
      retVal = DoDatuma
   End If
   NZDoDatuma = CVDate(retVal)
End Function
Public Function F_DefaultPIP() As Boolean
'Kreirano: 19-01-2019
 If IsEmpty(DefaultPIP) Then
  DefaultPIP = CBool(Nz(ReadParametar("CFG_Global", "DefaultPIP"), False))
 End If
 F_DefaultPIP = DefaultPIP
End Function
Public Function F_KomitentiVrstaDokIF(IDKomitent As Long, Optional DefaultVal As String = "") As String
'Kreirano: 18-08-2019
On Error GoTo Err_Point
Dim VrstaDokIF
 If PostojiPoljeUTabeli("VrstaDokIF", CurrentDb.TableDefs("Komitenti")) Then
  VrstaDokIF = DLookup("VrstaDokIF", "Komitenti", "Sifra = " & IDKomitent)
 Else
  VrstaDokIF = DefaultVal
 End If
 
Exit_Point:
 On Error Resume Next
 F_KomitentiVrstaDokIF = Nz(VrstaDokIF, DefaultVal)
 Exit Function
 
Err_Point:
 Resume Exit_Point
End Function
Public Function VrstaDokumentaUticeNaZalihe(ByVal stVrstaDok As Variant) As Boolean
'Kreirano: 08-09-2019
On Error GoTo Err_Point
Dim retVal As Boolean
 
 stVrstaDok = CStr(Nz(stVrstaDok, "<<Null>>"))
 If stVrstaDok = "KODJ" Then
    retVal = False
 Else
    retVal = Nz(DLookup("[UticeNaZalihe]", "R_Vrste dokumenata", "[Vrsta dokumenta]='" & stVrstaDok & "'"), True)
 End If
 
Exit_Point:
 On Error Resume Next
 VrstaDokumentaUticeNaZalihe = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "VrstaDokumentaUticeNaZalihe"
 retVal = True
 Resume Exit_Point
End Function

Public Function OtvoriFormuVezanaDokumenta(IDDok As Long) As Boolean
'Kreirano: 08-10-2019
On Error GoTo Err_Point
Dim stImeForme As String
Dim retValOk As Boolean
 
 retValOk = True
 stImeForme = "VezanaDokumenta"
 BBOpenForm stImeForme
 Forms(stImeForme)!ZaIDDok = IDDok
 Forms(stImeForme)!IDDokIzRobnog.DefaultValue = IDDok
 Forms(stImeForme).PrimeniUslove
Exit_Point:
 On Error Resume Next
 OtvoriFormuVezanaDokumenta = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "OtvoriFormuVezanaDokumenta"
 retValOk = False
 Resume Exit_Point
End Function
Public Function F_CSV_ColSep()
  F_CSV_ColSep = ReadCFGParametar("CSV_ColSep", ",")
End Function
Public Function F_APPRev(Optional stAPP As String = "QBigTehn", Optional TableName, Optional OnlyRev As Boolean = False) As String
'Modifikovano: 05-02-2020
On Error GoTo Err_Point
Dim stRetVal
Dim VerDatum 'As Date
Dim Ver As String
Dim IDRev As Long
Dim stWhere As String
Dim pstTableName As String

If IsMissing(TableName) Then
    If stAPP Like "DB*" Then
       pstTableName = "_T_Rev"
    Else
       pstTableName = "_APPRev"
    End If
Else
    pstTableName = CStr(Nz(TableName, "_APPRev"))
End If



VerDatum = DMax("[VerDatum]", pstTableName, "APP='" & stAPP & "'")
If Not IsDate(VerDatum) Then
  stRetVal = "-"
  GoTo Exit_Point
End If

stWhere = "(Format([VerDatum],""dd-MM-yy"")='" & Format(CVDate(VerDatum), "dd-MM-yy") & "')"    'UH!
stWhere = stWhere & " AND (" & Chr(34) & "APP='" & stAPP & "'" & Chr(34) & ")"                  'UH UH!

IDRev = DMax("[ID]", pstTableName, stWhere)
Ver = DLookup("Ver", pstTableName, "[ID]=" & IDRev)

If OnlyRev Then
  stRetVal = Ver
Else
  stRetVal = "Ver: " & Ver & vbCrLf & Format(VerDatum, "dd.MM.yyyy.")
End If
Exit_Point:
 On Error Resume Next
 F_APPRev = stRetVal
Exit Function

Err_Point:
  BBErrorMSG err, "F_APPRev"
  Resume Exit_Point
End Function

Public Function F_CheckPrintVoziloNaReportuRN() As Boolean
  F_CheckPrintVoziloNaReportuRN = ReadCFGParametar("CheckPrintVoziloNaReportuRN", True)
End Function
Public Function F_RPT_Memorandum_Header(Optional IDFirma) As String
Dim ZaIDFirma As Long
    If IsMissing(IDFirma) Then
       ZaIDFirma = F_IDFirma()
    Else
        ZaIDFirma = IDFirma
    End If
    F_RPT_Memorandum_Header = Nz(RFReadParameter("RPT_Memorandum_Header", ZaIDFirma, False), "Memorandum_Header_STD")
End Function
Public Function F_RPT_Memorandum_Footer(Optional IDFirma) As String
Dim ZaIDFirma As Long
    If IsMissing(IDFirma) Then
       ZaIDFirma = F_IDFirma()
    Else
        ZaIDFirma = IDFirma
    End If
    F_RPT_Memorandum_Footer = Nz(RFReadParameter("RPT_Memorandum_Footer", ZaIDFirma, False), "Memorandum_Footer_STD")
End Function
Public Function F_IOSText() As String
On Error GoTo Err_Point
Dim stRetVal As String

stRetVal = ReadCFGParametar("IOSText")


Exit_Point:
 On Error Resume Next
      F_IOSText = stRetVal
Exit Function

Err_Point:

 BBErrorMSG err, "F_IOSText"
 Resume Exit_Point
End Function
Public Function UnosVrednostiZaKombo(Optional ZaKolonu, Optional NovaVrednost) As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean

Dim stZaKolonu As String

Dim stCaller As String
stCaller = Screen.ActiveForm.Name

If IsMissing(ZaKolonu) Then
   stZaKolonu = Screen.ActiveControl.ControlSource
Else
   stZaKolonu = CStr(ZaKolonu)
End If

BBOpenForm "VrednostiZaKombo", , , , , , stCaller

If IsLoaded("VrednostiZaKombo") Then
   Forms("VrednostiZaKombo")!ZaKolonu = stZaKolonu
   Forms("VrednostiZaKombo").PrimeniUslove
   DoCmd.GoToRecord , , acNewRec
   If Not IsMissing(NovaVrednost) Then
    Forms("VrednostiZaKombo")!Vrednost = CStr(NovaVrednost)
   End If
End If

Exit_Point:
 On Error Resume Next
       UnosVrednostiZaKombo = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "UnosVrednostiZaKombo"
 retValOk = False
 Resume Exit_Point
End Function
Public Function F_GKSK_VeceOdDatuma() As Date
    F_GKSK_VeceOdDatuma = CVDate(ReadCFGParametar("GKSK_VeceOdDatuma", "01-01-2001"))
End Function
Public Function F_FR_BrZn() As Integer
    F_FR_BrZn = 40
End Function
Public Function F_FR_PrnLin(Labela As Variant, Vrednost As Variant, BrojZnakova As Integer, Optional bCirLabela As Boolean = False, Optional bCirVrednost) As String
On Error GoTo Err_Point
    
    Dim stRetVal As String
    Dim stRetValUk As String
    Dim retValOk As Boolean
    Dim brSp As Integer
    Dim i As Integer
    Dim brLinija As Integer
    
    Dim stLabela As String
    Dim stVrednost As String
    Dim nBrojZnakova As Integer
    Dim vNumVred As Variant
    
    
    stRetVal = Trim(CStr(Nz(Vrednost, "")))
    
    If Len(stRetVal) = 0 Then
        stRetVal = ""
        GoTo Exit_Point
    ElseIf (stRetVal = "0") Then
        stRetVal = ""
        GoTo Exit_Point
    ElseIf (stRetVal = "0,00") Or (stRetVal = "0,0") Or (stRetVal = "0,") Or (stRetVal = ",0") Then
        stRetVal = ""
        GoTo Exit_Point
    ElseIf (stRetVal = "0.00") Or (stRetVal = "0.0") Or (stRetVal = "0.") Or (stRetVal = ".0") Then
        stRetVal = ""
        GoTo Exit_Point
    ElseIf stRetVal = "<Null>" Then
        stRetVal = ""
    End If
    
    'ElseIf IsNumeric(Trim(CStr(Nz(Vrednost, "")))) Then
    '       On Error Resume Next
    '          vNumVred = Eval(Trim(CStr(Nz(Vrednost, ""))))
    '          If err.Number <> 0 Then
    '
    '          End If
    '       On Error GoTo err_Point
    '
    '       If Eval(Trim(CStr(Nz(Vrednost, "")))) = 0 Then
    '         stRetVal = ""
    '         GoTo exit_Point
    '       End If
    'End If
    
    nBrojZnakova = CInt(Nz(BrojZnakova, 0))
    
    
    stLabela = CStr(Nz(Labela, ""))
    stLabela = IIf(bCirLabela, Lat2Cir(stLabela), Cyr2Lat(stLabela))
    stVrednost = CStr(Nz(Vrednost, ""))
    If stVrednost = "<Null>" Then
       stVrednost = ""
    End If
    
    If IsMissing(bCirVrednost) Then
       stVrednost = IIf(bCirLabela, Lat2Cir(stVrednost), Cyr2Lat(stVrednost))
    Else
       stVrednost = IIf(CBool(bCirVrednost), Lat2Cir(stVrednost), Cyr2Lat(stVrednost))
    End If
    
    retValOk = True
   
    If nBrojZnakova <= 0 Then
       nBrojZnakova = (Len(stLabela) + Len(stVrednost))
    End If
    
    brSp = nBrojZnakova - (Len(stLabela) + Len(stVrednost))
    
    If brSp >= 0 Then
        stRetVal = stLabela & String(brSp, " ") & stVrednost
    Else
        brSp = Len(stLabela) + Len(stVrednost)
        brLinija = brSp \ nBrojZnakova + CInt(IIf(brSp Mod nBrojZnakova > 0, 1, 0))
        stRetValUk = stLabela & stVrednost
        stRetVal = ""
        For i = 1 To brLinija
            stRetVal = stRetVal & Left(stRetValUk, nBrojZnakova)
            If Len(stRetValUk) - nBrojZnakova > 0 Then
                stRetValUk = Right(stRetValUk, Len(stRetValUk) - nBrojZnakova)
            End If
            
            If Len(stRetValUk) > 0 Then
               If i < brLinija Then
                 stRetVal = stRetVal & vbCrLf
               End If
            End If
        Next i
    End If
    
Exit_Point:
 On Error Resume Next
       F_FR_PrnLin = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "F_FR_PrnLin"
 retValOk = False
 stRetVal = ""
 Resume Exit_Point
End Function
Public Function KasaErrMsg(stMsg As String)
    'MsgBox Srpski(stMSG), vbExclamation, BBKasaName
    MsgBox Srpski(stMsg), vbExclamation, "QBigTeh"
End Function
Public Function F_FR_Din(Iznos, Optional BrojDecimala As Byte = 2) As String
'? F_FR_Din(2545455.445,2),round(2545455.445,2),Format(2545455.445, "############,##0.00")

    Dim stRetVal As String
    Dim ZIznos
    Dim DecSepChar As String
    
    ZIznos = Round(Iznos, BrojDecimala)
    ZIznos = Round(Iznos + 0.000001, BrojDecimala)
    
    stRetVal = Format(ZIznos, "############,##0.00")
    DecSepChar = Left(Right(stRetVal, 3), 1)
    If DecSepChar = "." Then
        stRetVal = Replace(stRetVal, ",", "!")
        stRetVal = Replace(stRetVal, ".", ",")
        stRetVal = Replace(stRetVal, "!", ".")
    End If
    
    F_FR_Din = stRetVal
End Function
Public Function F_LL_SortNaReportu() As String
  F_LL_SortNaReportu = Nz(ReadCFGParametar("LL_SortNaReportu", "Kataloski broj"), "Kataloski broj")
End Function
Public Function F_DTM_IOSListaKonta() As String
'Kreirano: 04-11-2023
    F_DTM_IOSListaKonta = ReadCFGParametar("DTM_IOSListaKonta")
End Function

