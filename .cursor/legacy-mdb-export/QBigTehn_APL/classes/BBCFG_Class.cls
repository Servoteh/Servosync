VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "BBCFG_Class"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

' *** Ovo je bilo *****
'Const C_LockColor = 13879747 '11838362        '#A7B2C9 = '10000000         '8421504
'Const C_UnLockColor = 14869218 ' &HE2E2E2       '14869218=#E2E2E2=RGB(226,226,226) '12632256
Const C_LockColor = 13879747 '11838362        '#A7B2C9 = '10000000         '8421504
Const C_UnLockColor = 14869218 ' &HE2E2E2       '14869218=#E2E2E2=RGB(226,226,226) '12632256
  
Private pCNNString As String
Private pAPLUserName As String
Private pAppName  As String
'Private pGodina As Long ' prebaceno u LIB_CFGRW.Godina
Private pIDMestoUnosa As Long
Private pBrojDecimala As Byte
Private pFirma As TypeFirma

Private pBBAktGodina As Long             'as long GODINA
Private pBBAktOJ     As Long             'as long ORGANIZACIONA JEDINICA
Private pBBAktOD     As Long             'as long ODELJENJE

Private pBBUnlockAktGodina As Boolean
Private pBBUnlockAktOJ     As Boolean
Private pBBUnlockAktOD     As Boolean
Private pLogoFontSize     As Integer
Private pTextFakturisao As String
Private pDevValuta As String
Private pKnjigaKEPU As String

Private pDefaultPDVVisaStopa As Currency
Private pDefaultPDVNizaStopa As Currency

Private pKasa_Cenovnik As String
Private pKasa_CenovnikPola As String
Private pKasa_VrstaDokumenta As String
Private pKasa_ProdavnicaID As Long
Private pKasa_KasaID As Long
Private pKasa_KupacID As Long
Private pKasa_ProveraZaliha As Boolean
Private pKasa_RadniNalog As String
Private pKasa_NumKbd As Boolean

Private pKasa_TabStopKolicina As Boolean
Private pKasa_TabStopRabatProc As Boolean

Private pKasa_ZakljucajPosleNaplate As Boolean
Private pKasa_NeManjaKolicina As Boolean
Private pKasa_NeMenjajArtikal As Boolean
Private pKasa_Cena_Locked As Boolean

Private pKasa_DozvoljenRabatStavke As Boolean
Private pKasa_DozvoljenRabatRN As Boolean
Private pKasa_PrenesiRabatKomitentaNaStavku As Boolean

Private pKasa_IDProdavac As Long
Private pKasa_Smena As Byte
Private pKasa_PWD As String
Private pKasa_AutoLogin As Boolean

Private pGALEBFP550 As Boolean
Private pACS As Boolean
Private pKonobarAPL As String
Private pMestoIzdavanjaRacuna As String
Private pKafe_IDMestoIzdavanjaRobe As Long

Private pRPT_MemorandumHeader As String
Private pRPT_MemorandumFooter As String

Private pNivoBaze As Byte
Private pDonjiNivoBaze As Byte
Private pProizvodnjaUMP As Boolean
Private pBizerbaExportFileName As String
Private pDefaultDirNovaBaza As String
Private pDefaultLimitedUser As String
'Private pProveraZaliha As Boolean
Private pProveraZalihaNaDatumDokumenta As Boolean
Private pColorLock As Long
Private pColorUnLock As Long
Private pNoExplorer As Boolean
Private pKatBrojField As String
Private pKatBrojLabel As String

Private pVPCenovnik As String
Private pVPRabatPoArtiklima As Boolean

Private pKasa_ProdajaPoKatBroju As Boolean
Private pRFReadParameterSilent As Boolean
Private pFPFRPrefixZaNazivArtikla As String
Private pIFKLNC As String
Private pPrikazZalihaMag As Boolean
Private pProveraZalihaMag As Boolean
Private pDefaultTabUnosArtikala As String
Private pIF_Podforma_TabStopOpisStavke As Boolean
Private pImeFormeRN As String
Private pUFAutoUpisiBrDokUOpis As Boolean
'**********************************************
Private pDirImport As String
Private pDirExport As String
'Private pSHUTTLE_FileName As String
'**********************************************
Private pODBC_Synch_LogFileName As String
Private pODBC_Synch_FormName As String
Private pODBC_Synch_AutoStart As Boolean
Private pODBC_Synch_TimerInterval As Long
Private pODBC_Synch_SvakiMPDok As Boolean
Private pODBC_Synch_MPDok_OnCloseKasa As Boolean
Private pODBC_Synch_MPDok_OnCloseKasa_AskUser As Boolean
'**********************************************

Private pDeklaracije As Boolean
Private pCarinskiMagacin As Boolean

Private pAutoBrojDok As String
Private pBrojZnakovaZaBrDok As Byte
Private pUserPassword As String

Private pPoslednjaKLPoMag As Boolean
'*****************************************
Private pBB_TMP_FileName As String          '= adhCurrentDBPath() & "BB_TMP.mdb"
Private pBB_CFG_Lokal_FileName As String    '= adhCurrentDBPath() & "BB_CFG_Lokal.mdb"
    
Private pForsirajLink_BB_CFG_Lokal As Boolean
Private pForsirajLink_BB_TMP As Boolean
 
'*****************************************
Private pSysRazvojAPL As Boolean
Private pSysOpenForm As Long
Private pSysOpenReport As Long
Private pSysPravaPristupaPodesiFormu As Boolean
Private pSysProveraZakljucavanja As Boolean
'Private pSysAppEchoStari As Boolean
Private pSysAppEchoUvekTrue As Boolean
Private pCheckEcho As Boolean
Private pEchoStatusBarText As String
Private pSysConnectionTimeOut As Integer
Private pSysTabStopPodesiFormu As Boolean
Private pSysVodiDnevnik As Boolean
Private pSysSuspendOpenSynchForm As Boolean 'ne treba GET i LET
Private pSysSuspendSynch As Boolean
Private pSysDisabledSynch As Boolean
Private pSysSynchAllMPDokType As Integer
Private pSysSynchAllMPDokWhere As String
Private pSysCFG_TabStop_TableName As String

'*****************************************
Private pCheckLink_ODBC_Synch_Request As Boolean
Private pCheckLink_CFG_Sys As Boolean
Private pCheckLink_RadniFajlovi As Boolean
Private pCheckLink_CFG_Global As Boolean
Private pCheckLink_CFG_Lokal As Boolean
Private pCheckLink_Prodavci As Boolean

Private pTestPravaPristupa As Boolean
Private pIntroIsOpen As Boolean
Private pUFKLStampaOkreni As Boolean


Private pUnosNalogaGK_FormName As String
Private pMaticnaSifra As Long

Private pPOPDV_BrDec As Byte
Private pPOPDV_PrikaziTotale As Boolean

Private pMemorandumHeaderVisible As Boolean

Private pSvaKontaKupaca As String
Private pIDJezik As Long
Private pSysBigBitReklama As String
Private pZaliheOdDatuma As Variant
Private pIF_ProdavacIzKomitenta As Boolean
Private pIF_AutoSaveZagDok As Boolean
'Modifikovano: 21-01-2020
Private pObracunCenaPoMagacinu As Boolean

'Modifikovano: 27-10-2023
Private pSQLAccess_Login_ID As Long
'Modifikovano: 03-04-2024
Private pMaxDanaZaPeriodNaloga As Long
'Modifikovano: 19-06-2024
Private pPrebaciKomitenteIzEXTBaze As Boolean
Private pPrebaciPredmeteIzEXTBaze As Boolean

'Modifikovan: 20-07-2025
Private pStartRibbonName As String
Private pVremeIsporukeDana As Integer
Public Property Get PrebaciPredmeteIzEXTBaze() As Boolean
   PrebaciPredmeteIzEXTBaze = pPrebaciPredmeteIzEXTBaze
End Property
Public Property Let PrebaciPredmeteIzEXTBaze(ByVal vNewValue As Boolean)
   pPrebaciPredmeteIzEXTBaze = vNewValue
End Property

Public Property Get PrebaciKomitenteIzEXTBaze() As Boolean
   PrebaciKomitenteIzEXTBaze = pPrebaciKomitenteIzEXTBaze
End Property
Public Property Let PrebaciKomitenteIzEXTBaze(ByVal vNewValue As Boolean)
   pPrebaciKomitenteIzEXTBaze = vNewValue
End Property
Public Property Get MaxDanaZaPeriodNaloga() As Long
   MaxDanaZaPeriodNaloga = pMaxDanaZaPeriodNaloga
End Property
Public Property Let MaxDanaZaPeriodNaloga(ByVal vNewValue As Long)
   pMaxDanaZaPeriodNaloga = vNewValue
End Property
Public Property Get SQLAccess_Login_ID() As Long
    SQLAccess_Login_ID = pSQLAccess_Login_ID
End Property

Public Property Let SQLAccess_Login_ID(ByVal vNewValue As Long)
On Error Resume Next
    pSQLAccess_Login_ID = CLng(Nz(vNewValue, 0))
End Property

Public Property Get NovaAPL_BigBit() As String
Dim stRetVal As String

stRetVal = ReadCFGParametar("NovaAPL_BigBit", "")
NovaAPL_BigBit = stRetVal

End Property

Public Property Get ObracunCenaPoMagacinu() As Boolean
   ObracunCenaPoMagacinu = pObracunCenaPoMagacinu
End Property
Public Property Let ObracunCenaPoMagacinu(ByVal vNewValue As Boolean)
   pObracunCenaPoMagacinu = vNewValue
End Property
'*******************************************
Public Property Get IF_AutoSaveZagDok() As Boolean
   IF_AutoSaveZagDok = pIF_AutoSaveZagDok
End Property

Public Property Let IF_AutoSaveZagDok(ByVal vNewValue As Boolean)
   pIF_AutoSaveZagDok = vNewValue
End Property
Public Property Let BigBitReklama(vNewValue As String)
 pSysBigBitReklama = vNewValue
End Property
Public Property Get BigBitReklama() As String
 BigBitReklama = pSysBigBitReklama
End Property
Public Property Let IDJezik(newIDJezik As Long)
     pIDJezik = newIDJezik
End Property
Public Property Get IDJezik() As Long
    IDJezik = pIDJezik
End Property
Public Property Get SvaKontaKupaca() As String
    SvaKontaKupaca = pSvaKontaKupaca
End Property
Public Property Get POPDV_PrikaziTotale() As Boolean
    POPDV_PrikaziTotale = pPOPDV_PrikaziTotale
End Property
Public Property Let POPDV_PrikaziTotale(vNewValue As Boolean)
    pPOPDV_PrikaziTotale = vNewValue
End Property
Public Property Get MemorandumHeaderVisible() As Boolean
    MemorandumHeaderVisible = pMemorandumHeaderVisible
End Property
Public Property Let MemorandumHeaderVisible(vNewValue As Boolean)
    pMemorandumHeaderVisible = vNewValue
End Property

Public Property Get POPDV_BrDec() As Byte
  POPDV_BrDec = pPOPDV_BrDec
End Property
Public Property Let POPDV_BrDec(newValue As Byte)
  pPOPDV_BrDec = newValue
End Property

Public Property Get VPRabatPoArtiklima() As Boolean
  VPRabatPoArtiklima = pVPRabatPoArtiklima
End Property
Public Property Let VPRabatPoArtiklima(newValue As Boolean)
  pVPRabatPoArtiklima = newValue
End Property
Public Property Get MaticnaSifra() As Long
 MaticnaSifra = pMaticnaSifra
End Property
Public Property Let MaticnaSifra(newValue As Long)
 pMaticnaSifra = newValue
End Property

Public Property Let UnosNalogaGK_FormName(newValue As String)
 pUnosNalogaGK_FormName = newValue
End Property

Public Property Get UnosNalogaGK_FormName() As String
 UnosNalogaGK_FormName = pUnosNalogaGK_FormName
End Property

Public Property Get UFKLStampaOkreni() As Boolean
   UFKLStampaOkreni = pUFKLStampaOkreni
End Property
Public Property Let UFKLStampaOkreni(newValue As Boolean)
   pUFKLStampaOkreni = newValue
End Property
Private Property Let IntroMsg(newValue As String)
 If pIntroIsOpen Then
  Forms!Intro!OpisPoslaKojiSeRadi = newValue
 End If
End Property
Public Property Get IntroIsOpen() As Boolean
   IntroIsOpen = pIntroIsOpen
End Property
Public Property Let IntroIsOpen(newValue As Boolean)
   pIntroIsOpen = newValue
End Property
'*****************************************
Public Sub SetAppEcho(setVal As Boolean, Optional strStatusBarText As String = "")

pEchoStatusBarText = "BBCFG: " & strStatusBarText
If pSysAppEchoUvekTrue Then
   pEchoStatusBarText = pEchoStatusBarText & "=True"
   pCheckEcho = True
Else
   If setVal Then
      pEchoStatusBarText = pEchoStatusBarText & "=True"
      DoCmd.Hourglass False
   Else
      pEchoStatusBarText = pEchoStatusBarText & "=False"
      DoCmd.Hourglass True
   End If
  
   pCheckEcho = setVal
   Application.Echo setVal, pEchoStatusBarText
End If
End Sub
Public Property Get CheckEcho() As Boolean
 CheckEcho = pCheckEcho
End Property
Public Property Get EchoStatusBarText() As String
 EchoStatusBarText = pEchoStatusBarText
End Property
'*****************************************
Public Property Get SQLDB() As Boolean
 'SQLDB = (pAppName = "BigTehn_T")
 SQLDB = True
End Property
Public Property Get DBUserName() As String
'14-01-2021
Dim stRetVal As String
 'stRetVal = GetParFromCnnString("UID", BazaZaTabelu("R_Tarife"))
 stRetVal = GetParFromCnnString("UID", CNN_CurrentDataBase())
 If Nz(stRetVal, "") = "" Then
    stRetVal = pAPLUserName
 End If
 DBUserName = stRetVal
End Property
Public Property Get TestPravaPristupa() As Boolean
   TestPravaPristupa = pTestPravaPristupa
End Property
Public Property Let TestPravaPristupa(newValue As Boolean)
   pTestPravaPristupa = newValue
End Property
Public Property Get SysRazvojAPL() As Boolean
   SysRazvojAPL = (pSysRazvojAPL And (CurrentUser = "Negovan"))
End Property
Public Property Let SysRazvojAPL(newValue As Boolean)
   pSysRazvojAPL = newValue
End Property
'Private Function CnnStringAsArray() As String()
'  CnnStringAsArray = Split(pCNNString, ";")
'End Function
Public Function CnnStringBezPWD() As String
On Error GoTo Err_Point

 Dim stRetVal As String
 Dim stArray() As String
 Dim lb As Integer
 Dim ub As Integer
 Dim i As Integer
 
 stRetVal = ""
 'stArray = CnnStringAsArray() 'Split(pCNNString, ";")()
 stArray = Split(pCNNString, ";") 'Dodeljivanje jednog niza drugom; Assign One Array to Another Array
 lb = LBound(stArray) 'LBound(Split(pCNNString, ";"))
 ub = UBound(stArray) 'UBound(Split(pCNNString, ";"))
 For i = lb To ub
  ' If Not (Split(pCNNString, ";")(i) Like "UID*") And Not (Split(pCNNString, ";")(i) Like "PWD*") Then
   If Not (stArray(i) Like "UID*") And Not (stArray(i) Like "PWD*") Then
   'stRetVal = stRetVal & Split(pCNNString, ";")(i) & ";"
   stRetVal = stRetVal & stArray(i) & ";"
   End If
 Next i

Exit_Point:
On Error Resume Next
 CnnStringBezPWD = stRetVal
Exit Function
Err_Point:
 stRetVal = "error"
 Resume Exit_Point

End Function
Public Property Get CNNString() As String
    CNNString = Replace(pCNNString, "ODBC;", "")
End Property
Public Property Let CNNString(NCnnString As String)
     pCNNString = NCnnString
     'Refresh linked table!
End Property
Public Property Get AppName() As String
    AppName = pAppName
End Property
Public Property Get ProizvodnjaUMP() As Boolean
    ProizvodnjaUMP = pProizvodnjaUMP
End Property
Public Property Let ProizvodnjaUMP(vNewValue As Boolean)
    pProizvodnjaUMP = vNewValue
End Property
Public Property Get APLUserName() As String
    APLUserName = pAPLUserName
End Property
Public Property Let IDFirma(nIDFirma As Long)
'Modifikovano: 22-10-2021
     'If DCount("*", "Radni fajlovi", "IDBaze = " & nIDFirma) = 1 Then
     If ADO_Lookup(CNN_CurrentDataBase, "[BrojSlogova]", "SELECT Count(*) as BrojSlogova FROM [Radni fajlovi] WHERE IDBaze = " & stR(nIDFirma)) = 1 Then
      pFirma.IDFirma = nIDFirma
      LIB_CFGRW.IDFirma = nIDFirma
      SetFirmaPod nIDFirma
      InitializeFromRadniFajlovi nIDFirma
      pMaticnaSifra = F_IDMaticnaSifra()
     Else
      'Ne postoji firma sa zadatim ID
      MsgBox "Ne postoji firma ID=" & nIDFirma & vbCrLf & vbCrLf & "Aktivna firma nece biti promenjena.", vbExclamation, "QMegaTeh"
     End If
End Property
Public Property Get IDFirma() As Long
    IDFirma = LIB_CFGRW.IDFirma
End Property
Public Property Get NazivFirme() As String
    NazivFirme = pFirma.Naziv
End Property
Public Property Get NazivFirmeNezvanicno() As String
    NazivFirmeNezvanicno = pFirma.NazivNezvanicno
End Property
Public Property Let NazivFirmeNezvanicno(vNnewValue As String)
    pFirma.NazivNezvanicno = vNnewValue
End Property
Public Property Let Godina(nGodina As Long)
     'pGodina = nGodina
     LIB_CFGRW.Godina = nGodina
End Property
Public Property Get Godina() As Long
    'Godina = pGodina
    Godina = LIB_CFGRW.Godina
End Property
Public Property Get IDMestoUnosa() As Long
    IDMestoUnosa = pIDMestoUnosa
End Property
Public Property Get LogoFontSize() As Integer
    LogoFontSize = pLogoFontSize
End Property
Public Property Get TextFakturisao() As String
    TextFakturisao = pTextFakturisao
End Property
Public Property Get DevValuta() As String
    DevValuta = pDevValuta
End Property
Public Property Get KnjigaKEPU() As String
    KnjigaKEPU = pKnjigaKEPU
End Property
Public Property Get DefaultPDVVisaStopa() As Currency
    DefaultPDVVisaStopa = pDefaultPDVVisaStopa
End Property
Public Property Get DefaultPDVNizaStopa() As Currency
    DefaultPDVNizaStopa = pDefaultPDVNizaStopa
End Property
Public Property Get Kasa_Cenovnik() As String
    Kasa_Cenovnik = pKasa_Cenovnik
End Property
Public Property Let Kasa_Cenovnik(vNewCenovnik As String)
    pKasa_Cenovnik = vNewCenovnik
End Property
Public Property Get Kasa_CenovnikPola() As String
    Kasa_CenovnikPola = pKasa_CenovnikPola
End Property
Public Property Let Kasa_CenovnikPola(vNewCenovnikPola As String)
    pKasa_CenovnikPola = vNewCenovnikPola
End Property
Public Property Get Kasa_VrstaDokumenta() As String
   Kasa_VrstaDokumenta = pKasa_VrstaDokumenta
End Property
Public Property Get Kasa_ProdavnicaID() As Long
    Kasa_ProdavnicaID = pKasa_ProdavnicaID
End Property
Public Property Get Kasa_KasaID() As Long
    Kasa_KasaID = pKasa_KasaID
End Property
Public Property Get Kasa_KupacID() As Long
    Kasa_KupacID = pKasa_KupacID
End Property
Public Property Get Kasa_ProveraZaliha() As Boolean
    Kasa_ProveraZaliha = pKasa_ProveraZaliha
End Property
Public Property Get Kasa_RadniNalog() As Long
    Kasa_RadniNalog = pKasa_RadniNalog
End Property
Public Property Get Kasa_NumKbd() As Boolean
    Kasa_NumKbd = pKasa_NumKbd
End Property
Public Property Get Kasa_TabStopKolicina() As Boolean
    Kasa_TabStopKolicina = pKasa_TabStopKolicina
End Property
Public Property Get Kasa_DozvoljenRabatStavke() As Boolean
    Kasa_DozvoljenRabatStavke = pKasa_DozvoljenRabatStavke
End Property
Public Property Get Kasa_DozvoljenRabatRN() As Boolean
    Kasa_DozvoljenRabatRN = pKasa_DozvoljenRabatRN
End Property
Public Property Get Kasa_TabStopRabatProc() As Boolean
    Kasa_TabStopRabatProc = pKasa_TabStopRabatProc And pKasa_DozvoljenRabatStavke
End Property
Public Property Get Kasa_PrenesiRabatKomitentaNaStavku() As Boolean
    Kasa_PrenesiRabatKomitentaNaStavku = pKasa_PrenesiRabatKomitentaNaStavku
End Property
Public Property Get Kasa_ZakljucajPosleNaplate() As Boolean
    Kasa_ZakljucajPosleNaplate = pKasa_ZakljucajPosleNaplate
End Property
Public Property Get Kasa_NeManjaKolicina() As Boolean
    Kasa_NeManjaKolicina = pKasa_NeManjaKolicina
End Property
Public Property Get Kasa_NeMenjajArtikal() As Boolean
    Kasa_NeMenjajArtikal = pKasa_NeMenjajArtikal
End Property
Public Property Get Kasa_Cena_Locked() As Boolean
    Kasa_Cena_Locked = pKasa_Cena_Locked
End Property
Public Property Get GALEBFP550() As Boolean
    GALEBFP550 = pGALEBFP550
End Property
Public Property Get ACS() As Boolean
    ACS = pACS
End Property
Public Property Get KonobarAPL() As String
    KonobarAPL = pKonobarAPL
End Property
Public Property Get MestoIzdavanjaRacuna() As String
    MestoIzdavanjaRacuna = pMestoIzdavanjaRacuna
End Property
Public Property Get Kafe_IDMestoIzdavanjaRobe() As Long
    Kafe_IDMestoIzdavanjaRobe = pKafe_IDMestoIzdavanjaRobe
End Property
Public Property Get UserPassword() As String
    UserPassword = pUserPassword
End Property
Public Property Let UserPassword(NewVal As String)
     pUserPassword = CStr(NewVal)
End Property
Public Property Get Firma() As TypeFirma
    Firma = pFirma
End Property
Public Property Get RPT_MemorandumHeader() As String
    RPT_MemorandumHeader = pRPT_MemorandumHeader
End Property
Public Property Get RPT_MemorandumFooter() As String
    RPT_MemorandumFooter = pRPT_MemorandumFooter
End Property
Public Property Get NivoBaze() As Byte
    NivoBaze = pNivoBaze
End Property
Public Property Let NivoBaze(nNivoBaze As Byte)
    pNivoBaze = nNivoBaze
End Property
Public Property Get BizerbaExportFileName() As String
    BizerbaExportFileName = pBizerbaExportFileName
End Property
Public Property Let BizerbaExportFileName(nFileName As String)
    pBizerbaExportFileName = nFileName
End Property
Public Property Get Kasa_PWD() As String
    Kasa_PWD = pKasa_PWD
End Property
Public Property Let Kasa_PWD(strPassword As String)
'Modifikovano 14-01-2021
   
   pKasa_PWD = strPassword
   pKasa_IDProdavac = Nz(ADO_Lookup(CNN_CurrentDataBase, "[Sifra prodavca]", "Prodavci", "[Password] = '" & pKasa_PWD & "'"), -1)
   
End Property
Public Property Get Kasa_IDProdavac() As Long
    Kasa_IDProdavac = pKasa_IDProdavac
End Property
Public Property Let Kasa_IDProdavac(nIDProdavac As Long)
    pKasa_IDProdavac = nIDProdavac
End Property
Public Property Get Kasa_Smena() As Byte
    Kasa_Smena = pKasa_Smena
End Property
Public Property Let Kasa_Smena(nSmena As Byte)
    pKasa_Smena = nSmena
End Property
Public Property Get Kasa_AutoLogin() As Boolean
    Kasa_AutoLogin = pKasa_AutoLogin
End Property
Public Property Get DefaultDirNovaBaza() As String
    DefaultDirNovaBaza = pDefaultDirNovaBaza
End Property
Public Property Let DefaultDirNovaBaza(strNewDir As String)
    pDefaultDirNovaBaza = strNewDir
End Property
Public Property Get DirExport() As String
    DirExport = pDirExport
End Property
Public Property Let DirExport(strNewDir As String)
    pDirExport = strNewDir
End Property
Public Property Let DirImport(strNewDir As String)
    pDirImport = strNewDir
End Property
Public Property Get DirImport() As String
    DirImport = pDirImport
End Property
Public Property Get SHUTTLE_FileName() As String
'Modifikovano: 14-01-2021
    'SHUTTLE_FileName = BazaZaTip("SHUTTLE")
    SHUTTLE_FileName = GetParFromCnnString("Data Source=", CNN_SHUTTLE)

End Property
'******************************************************************
Public Property Get ODBC_Synch_FormName() As String
    ODBC_Synch_FormName = pODBC_Synch_FormName
End Property
Public Property Let ODBC_Synch_FormName(vNewValue As String)
    pODBC_Synch_FormName = vNewValue
End Property
Public Property Get ODBC_Synch_LogFileName() As String
    ODBC_Synch_LogFileName = pODBC_Synch_LogFileName
End Property
Public Property Let ODBC_Synch_LogFileName(vNewValue As String)
    pODBC_Synch_LogFileName = vNewValue
End Property
Public Property Get ODBC_Synch_AutoStart() As Boolean
    ODBC_Synch_AutoStart = pODBC_Synch_AutoStart
End Property
Public Property Let ODBC_Synch_AutoStart(vNewValue As Boolean)
    pODBC_Synch_AutoStart = vNewValue
End Property
Public Property Get ODBC_Synch_TimerInterval() As Long
    ODBC_Synch_TimerInterval = pODBC_Synch_TimerInterval
End Property
Public Property Let ODBC_Synch_TimerInterval(vNewValue As Long)
    pODBC_Synch_TimerInterval = vNewValue
End Property
Public Property Get ODBC_Synch_SvakiMPDok() As Boolean
    ODBC_Synch_SvakiMPDok = pODBC_Synch_SvakiMPDok
End Property
Public Property Let ODBC_Synch_SvakiMPDok(vNewValue As Boolean)
    pODBC_Synch_SvakiMPDok = vNewValue
End Property
Public Property Get ODBC_Synch_MPDok_OnCloseKasa() As Boolean
    ODBC_Synch_MPDok_OnCloseKasa = pODBC_Synch_MPDok_OnCloseKasa
End Property
Public Property Let ODBC_Synch_MPDok_OnCloseKasa(vNewValue As Boolean)
    pODBC_Synch_MPDok_OnCloseKasa = vNewValue
End Property
Public Property Get ODBC_Synch_MPDok_OnCloseKasa_AskUser() As Boolean
    ODBC_Synch_MPDok_OnCloseKasa_AskUser = pODBC_Synch_MPDok_OnCloseKasa_AskUser
End Property
Public Property Let ODBC_Synch_MPDok_OnCloseKasa_AskUser(vNewValue As Boolean)
    pODBC_Synch_MPDok_OnCloseKasa_AskUser = vNewValue
End Property
Public Property Get DefaultLimitedUser() As String
    DefaultLimitedUser = pDefaultLimitedUser
End Property
Public Property Let DefaultLimitedUser(strUserName As String)
    pDefaultLimitedUser = strUserName
End Property
Public Property Get ProveraZalihaNaDatumDokumenta() As Boolean
    ProveraZalihaNaDatumDokumenta = pProveraZalihaNaDatumDokumenta
End Property
Public Property Let ProveraZalihaNaDatumDokumenta(vNewVal As Boolean)
    pProveraZalihaNaDatumDokumenta = vNewVal
End Property
Public Property Get ColorLock() As Long
    ColorLock = pColorLock
End Property
Public Property Let ColorLock(nColor As Long)
    pColorLock = nColor
End Property
Public Property Get ColorUnLock() As Long
    ColorUnLock = pColorUnLock
End Property
Public Property Let ColorUnLock(nColor As Long)
    pColorUnLock = nColor
End Property
Public Property Get NoExplorer() As Boolean
  NoExplorer = pNoExplorer
End Property
Public Property Let NoExplorer(vNewVal As Boolean)
  pNoExplorer = vNewVal
End Property
Public Property Get KatBrojField() As String
    KatBrojField = pKatBrojField
End Property
Public Property Let KatBrojField(vNewVal As String)
    pKatBrojField = vNewVal
End Property
Public Property Get KatBrojLabel() As String
    KatBrojLabel = pKatBrojLabel
End Property
Public Property Let KatBrojLabel(vNewVal As String)
    pKatBrojLabel = vNewVal
End Property
Public Property Get VPCenovnik() As String
    VPCenovnik = pVPCenovnik
End Property
Public Property Let VPCenovnik(vNewVal As String)
    pVPCenovnik = vNewVal
End Property
Public Property Get Kasa_ProdajaPoKatBroju() As Boolean
 Kasa_ProdajaPoKatBroju = pKasa_ProdajaPoKatBroju
End Property
Public Property Let Kasa_ProdajaPoKatBroju(ByVal vNewValue As Boolean)
 pKasa_ProdajaPoKatBroju = vNewValue
End Property
Public Property Get FPFRPrefixZaNazivArtikla() As String
    FPFRPrefixZaNazivArtikla = pFPFRPrefixZaNazivArtikla
End Property
Public Property Get IFKLNC() As String
    IFKLNC = pIFKLNC
End Property
Public Property Get PrikazZalihaMag() As Boolean
 PrikazZalihaMag = pPrikazZalihaMag
End Property
Public Property Let PrikazZalihaMag(vNewValue As Boolean)
 pPrikazZalihaMag = vNewValue
End Property
Public Property Get ProveraZalihaMag() As Boolean
 ProveraZalihaMag = pProveraZalihaMag
End Property
Public Property Let ProveraZalihaMag(vNewValue As Boolean)
 pProveraZalihaMag = vNewValue
End Property
Public Property Get DefaultTabUnosArtikala() As String
    DefaultTabUnosArtikala = pDefaultTabUnosArtikala
End Property
Public Property Get IF_Podforma_TabStopOpisStavke() As Boolean
 IF_Podforma_TabStopOpisStavke = pIF_Podforma_TabStopOpisStavke
End Property
Public Property Let IF_Podforma_TabStopOpisStavke(ByVal vNewValue As Boolean)
 pIF_Podforma_TabStopOpisStavke = vNewValue
End Property
Public Property Get ImeFormeRN() As String
    ImeFormeRN = pImeFormeRN
End Property
Public Property Get UFAutoUpisiBrDokUOpis() As Boolean
 UFAutoUpisiBrDokUOpis = pUFAutoUpisiBrDokUOpis
End Property
Public Property Let UFAutoUpisiBrDokUOpis(ByVal vNewValue As Boolean)
 pUFAutoUpisiBrDokUOpis = vNewValue
End Property
Public Property Get Deklaracije() As Boolean
 Deklaracije = pDeklaracije
End Property
Public Property Let Deklaracije(ByVal vNewValue As Boolean)
 pDeklaracije = vNewValue
 If pDeklaracije Then 'ako je False nema potrebe da radi F_CheckLink
  pDeklaracije = pDeklaracije And ADO_PostojiTabelaUBazi(CNN_CurrentDataBase(), "R_Artikli_Deklaracije")
 End If
End Property

Public Property Get CarinskiMagacin() As Boolean
 CarinskiMagacin = pCarinskiMagacin
End Property
Public Property Let CarinskiMagacin(ByVal vNewValue As Boolean)
 pCarinskiMagacin = vNewValue
   If pCarinskiMagacin Then 'ako je False nema potrebe da radi F_CheckLink
     pCarinskiMagacin = pCarinskiMagacin And ADO_PostojiTabelaUBazi(CNN_CurrentDataBase(), "T_CMDok_Ulaz")
     pCarinskiMagacin = pCarinskiMagacin And ADO_PostojiTabelaUBazi(CNN_CurrentDataBase(), "T_CMStavke_Ulaz")
     pCarinskiMagacin = pCarinskiMagacin And ADO_PostojiTabelaUBazi(CNN_CurrentDataBase(), "T_CMDok_Izlaz")
     pCarinskiMagacin = pCarinskiMagacin And ADO_PostojiTabelaUBazi(CNN_CurrentDataBase(), "T_CMStavke_Izlaz")
     pCarinskiMagacin = pCarinskiMagacin And ADO_PostojiTabelaUBazi(CNN_CurrentDataBase(), "CarinskeTarife")
   End If
End Property


Public Property Get AutoBrojDok() As String
   AutoBrojDok = pAutoBrojDok
End Property

Public Property Let AutoBrojDok(ByVal vNewValue As String)
  pAutoBrojDok = vNewValue
End Property

Public Property Get BrojZnakovaZaBrDok() As Byte
  BrojZnakovaZaBrDok = pBrojZnakovaZaBrDok
End Property

Public Property Let BrojZnakovaZaBrDok(ByVal vNewValue As Byte)
 pBrojZnakovaZaBrDok = vNewValue
End Property

Public Property Get PoslednjaKLPoMag() As Boolean
  PoslednjaKLPoMag = pPoslednjaKLPoMag
End Property
Public Property Let PoslednjaKLPoMag(ByVal vNewValue As Boolean)
 pPoslednjaKLPoMag = vNewValue
End Property
Public Property Get ForsirajLink_BB_CFG_Lokal() As Boolean
  ForsirajLink_BB_CFG_Lokal = pForsirajLink_BB_CFG_Lokal
End Property


Public Property Get ForsirajLink_BB_TMP() As Boolean
  ForsirajLink_BB_TMP = pForsirajLink_BB_TMP
End Property
Public Property Get BB_TMP_FileName() As String
  BB_TMP_FileName = pBB_TMP_FileName
End Property

'******************************
' Sys
'******************************
Public Property Get SysOpenForm() As Long
  SysOpenForm = pSysOpenForm
End Property
Public Property Let SysOpenForm(ByVal vNewValue As Long)
 pSysOpenForm = vNewValue
End Property
Public Property Get SysOpenReport() As Long
  SysOpenReport = pSysOpenReport
End Property

Public Property Let SysOpenReport(ByVal vNewValue As Long)
 pSysOpenReport = vNewValue
End Property
Public Property Get SysPravaPristupaPodesiFormu() As Boolean
  SysPravaPristupaPodesiFormu = pSysPravaPristupaPodesiFormu
End Property

Public Property Let SysPravaPristupaPodesiFormu(ByVal vNewValue As Boolean)
 pSysPravaPristupaPodesiFormu = vNewValue
End Property
Public Property Get SysProveraZakljucavanja() As Boolean
  SysProveraZakljucavanja = pSysProveraZakljucavanja
End Property
Public Property Let SysProveraZakljucavanja(ByVal vNewValue As Boolean)
 pSysProveraZakljucavanja = vNewValue
End Property
Public Property Let SysAppEchoUvekTrue(ByVal vNewValue As Boolean)
 pSysAppEchoUvekTrue = vNewValue
End Property
Public Property Get SysAppEchoUvekTrue() As Boolean
  SysAppEchoUvekTrue = pSysAppEchoUvekTrue
End Property

Public Property Let SysTabStopPodesiFormu(ByVal vNewValue As Boolean)
 pSysTabStopPodesiFormu = vNewValue
End Property
Public Property Get SysTabStopPodesiFormu() As Boolean
  SysTabStopPodesiFormu = pSysTabStopPodesiFormu
End Property
Public Property Let SysVodiDnevnik(ByVal vNewValue As Boolean)
 pSysVodiDnevnik = vNewValue
End Property
Public Property Get SysVodiDnevnik() As Boolean
  SysVodiDnevnik = pSysVodiDnevnik
End Property

Public Property Let SysSynchAllMPDokType(ByVal vNewValue As Integer)
 pSysSynchAllMPDokType = vNewValue
End Property
Public Property Get SysSynchAllMPDokType() As Integer
  SysSynchAllMPDokType = pSysSynchAllMPDokType
End Property

Public Property Let SysSynchAllMPDokWhere(ByVal vNewValue As String)
 pSysSynchAllMPDokWhere = vNewValue
End Property
Public Property Get SysSynchAllMPDokWhere() As String
  SysSynchAllMPDokWhere = pSysSynchAllMPDokWhere
End Property
Public Property Get SysCFG_TabStop_TableName() As String
  SysCFG_TabStop_TableName = pSysCFG_TabStop_TableName
End Property
Public Property Let SysCFG_TabStop_TableName(vNewValue As String)
  pSysCFG_TabStop_TableName = vNewValue
End Property
Public Property Get SysConnectionTimeOut() As Integer
    SysConnectionTimeOut = pSysConnectionTimeOut
End Property
Public Property Get SysSuspendSynch() As Boolean
    SysSuspendSynch = pSysSuspendSynch
End Property
Public Property Let SysSuspendSynch(newValue As Boolean)
   pSysSuspendSynch = newValue
End Property

Public Property Get SysDisabledSynch() As Boolean
    SysDisabledSynch = pSysDisabledSynch
End Property
Public Property Let SysDisabledSynch(newValue As Boolean)
   pSysDisabledSynch = newValue
End Property

'Modifikovano: 23-01-2023
Public Property Get Firma_TekuciRacun() As String
    Firma_TekuciRacun = BBCFG.Firma.TekuciRacun
End Property
Public Property Let Firma_TekuciRacun(newValue As String)
   pFirma.TekuciRacun = newValue
End Property

'********************do ovde Modifikovano: 23-01-2023

' Modifikovano: 20-07-2025
Public Property Get StartRibbonName() As String
    StartRibbonName = pStartRibbonName
End Property
'********************do ovde Modifikovano: 20-07-2025

Public Sub SetFirmaPod(Optional ByVal ZaIDAktivneBaze As Long = -1)
On Error GoTo err_Sub
'********************************************
'Modifikovano: 24-10-2019
'Modifikovano: 13-01-2020
'Modifikovano: 02-11-2020
'Modifikovano: 09-02-2021
'Modifikovano: 19-10-2021
'Modifikovano: 11-04-2023
'Modifikovano: 21-11-2023
'********************************************
 Dim rst As ADODB.Recordset
    
    If pCheckLink_RadniFajlovi And (ZaIDAktivneBaze = -1) Then
          'ZaIDAktivneBaze = Nz(DLookup("IDBaze", "Radni fajlovi", "[Naziv baze] = '" & CNNString & "'"), 0)
          ZaIDAktivneBaze = Nz(ADO_Lookup(CNN_CurrentDataBase, "IDBaze", "Radni fajlovi", "[Naziv baze] = '" & CNNString & "'"), 0)
    ElseIf (ZaIDAktivneBaze = -1) Then
          ZaIDAktivneBaze = 0
    End If
   
   
    If pCheckLink_CFG_Global Then 'SysCheckLink("CFG_Global") Then
       pRFReadParameterSilent = Nz(ReadParametar("CFG_Global", "RFReadParameterSilent"), False)
    Else
       pRFReadParameterSilent = False
    End If
    
    If Nz(ReadParametar("CFG_Sys", "SysTipKorisnika"), 0) = 1 Then 'Agencija, radni fajlovi su u CFG
        pFirma.IDFirma = 0
    Else
        pFirma.IDFirma = IDFirma
    End If
    '***********************************************************
    'iz tabele "Radni fajlovi"
    '***********************************************************
    If pCheckLink_RadniFajlovi Then 'SysCheckLink("Radni fajlovi") Then
        
        '19-10-2021
        Set rst = ADO_GetRST(CNN_CurrentDataBase, "SELECT * FROM [Radni fajlovi] WHERE [IDBaze]=" & stR(pFirma.IDFirma), dbOptimistic, adUseClient, adOpenStatic)
        'rst.FindFirst ("[IDBaze] = " & pFirma.IDFirma) '09-02-2021 F_IDFirma()) 'F_IDAktivneBaze())
    
        pFirma.Naziv = Nz(rst![Firma], "") 'Nz(RFReadParameter("Firma", ZaIDAktivneBaze, pRFReadParameterSilent), "")
        
        '21-11-2023
        On Error Resume Next
            pFirma.NazivNezvanicno = Nz(rst![NazivFirmeNezvanicno], "")
            If pFirma.NazivNezvanicno = "" Then
               pFirma.NazivNezvanicno = pFirma.Naziv
            End If
        On Error GoTo err_Sub
        
        pFirma.MESTO = Nz(rst![MESTO], "") 'Nz(DLookup("[Mesto]", "Radni fajlovi", "[IDBaze] = " & ZaIDAktivneBaze), "")
        pFirma.ADRESA = Nz(rst![ADRESA], "") 'Nz(DLookup("[Adresa]", "Radni fajlovi", "[IDBaze] = " & ZaIDAktivneBaze), "")
        pFirma.TekuciRacun = Nz(rst![Ziro racun], "") 'Nz(DLookup("[Ziro racun]", "Radni fajlovi", "[IDBaze] = " & ZaIDAktivneBaze), "")
        pFirma.PIB = Nz(rst![PIB], "") 'Nz(DLookup("[PIB]", "Radni fajlovi", "[IDBaze] = " & ZaIDAktivneBaze), "")
        pFirma.Telefon = Nz(rst![Telefon], "") 'Nz(DLookup("[Telefon]", "Radni fajlovi", "[IDBaze] = " & ZaIDAktivneBaze), "")
        pFirma.Fax = Nz(rst![Fax], "") 'Nz(DLookup("[Fax]", "Radni fajlovi", "[IDBaze] = " & ZaIDAktivneBaze), "")
        pFirma.MaticniBroj = Nz(rst![Maticni broj], "") 'Nz(DLookup("[Maticni broj]", "Radni fajlovi", "[IDBaze] = " & ZaIDAktivneBaze), "")
        
        '11-04-2023
        On Error Resume Next
            pFirma.JBKJS = Nz(rst![JBKJS], "")
        On Error GoTo err_Sub
        
        pFirma.SifraDelatnosti = Nz(rst![Sifra delatnosti], "") 'Nz(DLookup("[Sifra delatnosti]", "Radni fajlovi", "[IDBaze] = " & ZaIDAktivneBaze), "")
        pFirma.Delatnost = Nz(rst![Delatnost], "") 'Nz(DLookup("[Delatnost]", "Radni fajlovi", "[IDBaze] = " & ZaIDAktivneBaze), "")
        pFirma.Email = Nz(rst![e-mail], "") 'Nz(DLookup("[e-mail]", "Radni fajlovi", "[IDBaze] = " & ZaIDAktivneBaze), "")
        pFirma.Web = Nz(rst![WebAdresa], "") 'Nz(RFReadParameter("WebAdresa", ZaIDAktivneBaze, True), "")
        pFirma.Opstina = Nz(rst![Opstina], "") 'Nz(RFReadParameter("Opstina", ZaIDAktivneBaze, pRFReadParameterSilent), "")
        '*******************************************************************************************
        'Modifikovano: 13-01-2020
        '--------------------------------------------------------------------------------------------
        pFirma.BrDecUlKl = Nz(rst!BrDecUlKl, 4)
        pFirma.BrDecIzKl = Nz(rst!BrDecIzKl, 2)
        pFirma.KursDeli = Nz(rst!KursDeli, False)
        'ProveraZalihaMag = rst![ProveraZalihaMag]
        pFirma.AutoPodelaPrihoda = Nz(rst!AutoPodelaPrihoda, False)
        pFirma.FakturnaJeVPZaUlKl = Nz(rst!FakturnaJeVPZaUlKl, False)
        pFirma.KepuPoNabavnojCeni = Nz(rst!KepuPoNabavnojCeni, True)
        pFirma.TrgovackaPoKursu = Nz(rst![TrgovackaPoKursu], False)
        pFirma.KepuPoKursu = Nz(rst![KepuPoKursu], False)
        pFirma.KEPUPoKNGCeni = Nz(rst![KEPUPoKNGCeni], False)
        pFirma.GKPoKursu = Nz(rst![GKPoKursu], False)
        pFirma.KontoKupac = Nz(rst![KontoKupac], "2040")
        pFirma.KontoDobavljac = Nz(rst![KontoDobavljac], "4350")
        pFirma.KnjiziRazlikeNaTK = Nz(rst![KnjiziRazlikeNaTK], True)
        pFirma.KnjiziRazlikeNaKEPU = Nz(rst![KnjiziRazlikeNaKEPU], True)
        pFirma.KnjiziRazlikeNaMPKEPU = Nz(rst![KnjiziRazlikeNaMPKEPU], True)
        pFirma.GKPoKursuObrnuto = Nz(rst![GKPoKursuObrnuto], False)
        pFirma.ProveraPorukaInterval = Nz(rst![ProveraPorukaInterval], 0)
        pFirma.DekodirajBarKod = Nz(rst![DekodirajBarKod], False)
        'Galeb = rst![Galeb]
        pFirma.Raster = False 'rst![Raster]
        pFirma.ServerZaGaleb = False 'rst![ServerZaGaleb]
        pFirma.KlijentZaGaleb = False 'rst![KlijentZaGaleb]
        pFirma.FP_ImeStampaca = Nz(rst![FP_ImeStampaca], "")
        'MestoIzdavanjaRacuna = rst![MestoIzdavanjaRacuna]
        pFirma.DefaultNapomena = Nz(rst![Napomena], "Napomena o poreskom oslobodjenju: NEMA") 'Nz(RFReadParameter("Napomena"), "Napomena o poreskom oslobodjenju: NEMA")
    Else
        pFirma.Naziv = ""
        pFirma.NazivNezvanicno = ""
        pFirma.MESTO = ""
        pFirma.ADRESA = ""
        pFirma.TekuciRacun = ""
        pFirma.PIB = ""
        pFirma.Telefon = ""
        pFirma.Fax = ""
        pFirma.MaticniBroj = ""
        pFirma.JBKJS = ""
        pFirma.SifraDelatnosti = ""
        pFirma.Delatnost = ""
        pFirma.Email = ""
        pFirma.Web = ""
        pFirma.Opstina = ""
        '*******************************************************************************************
        'Modifikovano: 13-01-2020
        '--------------------------------------------------------------------------------------------
        pFirma.BrDecUlKl = 4
        pFirma.BrDecIzKl = 2
        pFirma.KursDeli = False
        'ProveraZalihaMag = rst![ProveraZalihaMag")
        pFirma.AutoPodelaPrihoda = False
        pFirma.FakturnaJeVPZaUlKl = False
        pFirma.KepuPoNabavnojCeni = True
        pFirma.TrgovackaPoKursu = False
        pFirma.KepuPoKursu = False
        pFirma.KEPUPoKNGCeni = False
        pFirma.GKPoKursu = False
        pFirma.KontoKupac = "2040"
        pFirma.KontoDobavljac = "4350"
        pFirma.KnjiziRazlikeNaTK = True
        pFirma.KnjiziRazlikeNaKEPU = True
        pFirma.KnjiziRazlikeNaMPKEPU = True
        pFirma.GKPoKursuObrnuto = False
        pFirma.ProveraPorukaInterval = 0
        pFirma.DekodirajBarKod = False
        'Galeb = rst![Galeb")
        pFirma.Raster = False
        pFirma.ServerZaGaleb = False
        pFirma.KlijentZaGaleb = False
        pFirma.FP_ImeStampaca = ""
        'MestoIzdavanjaRacuna = rst![MestoIzdavanjaRacuna")
        pFirma.DefaultNapomena = "Napomena o poreskom oslobodjenju: NEMA"
    End If
    
    '***********************************************************
    'iz tabele "CFG_Global"
    '***********************************************************
    If pCheckLink_CFG_Global Then 'SysCheckLink("CFG_Global") Then
        pFirma.Drzava = Nz(ReadParametar("CFG_Global", "Drzava"), "Srbija")
        pFirma.PostBroj = Nz(ReadParametar("CFG_Global", "PostBroj"), "")
        pFirma.GLN = Nz(ReadParametar("CFG_Global", "EDI_GLN_Sender"), "")
    Else
        pFirma.Drzava = ""
        pFirma.PostBroj = ""
        pFirma.GLN = ""
    End If
    
Exit_Sub:
On Error Resume Next
    If pCheckLink_RadniFajlovi Then
        rst.Close
        Set rst = Nothing
    End If
Exit Sub

err_Sub:
   BBErrorMSG err, "Class:BBCFG, sub:SetFirmaPod"
   Resume Next
End Sub

'**********************************************************************************
' INICIJALIZACIJA SYS
'**********************************************************************************
Private Sub InitializeFromCFG_Sys()
 'Dim pTmp
 
 
 If Not pCheckLink_CFG_Sys Then ' SysCheckLink("CFG_Sys", 5, True) Then
    MsgBox "Tabela [CFG_Sys] nije dostupna.", vbExclamation, "QMegaTeh"
    Exit Sub
 End If
 
   '********************************************************
   'Ukinuto 13-01-2020 i preneto u sub PostaviGodinu
   'odredjivanje godine
   'pTmp = ReadParametar("CFG_Sys", "SysDefaultGodina")
   'If Not IsNull(pTmp) And IsNumeric(pTmp) Then
   '   pGodina = CLng(pTmp)
   'Else
   '   pGodina = DatePart("yyyy", Date)
   'End If
   '********************************************************
   
   pSysSuspendSynch = Nz(ReadParametar("CFG_Sys", "SysSuspendSynch"), False)
   pSysSuspendSynch = pSysSuspendSynch And pCheckLink_ODBC_Synch_Request
   
   pSysDisabledSynch = Nz(ReadParametar("CFG_Sys", "SysDisabledSynch"), False)
   
   pSysRazvojAPL = Nz(ReadParametar("CFG_Sys", "SysRazvojAPL"), False)
   pSysOpenForm = Nz(ReadParametar("CFG_Sys", "SysOpenForm"), 0)
   pSysOpenReport = Nz(ReadParametar("CFG_Sys", "SysOpenReport"), 0)
   pSysPravaPristupaPodesiFormu = Nz(ReadParametar("CFG_Sys", "SysPravaPristupaPodesiFormu"), True)
   pSysProveraZakljucavanja = Nz(ReadParametar("CFG_Sys", "SysProveraZakljucavanja"), True)
   
   pSysAppEchoUvekTrue = Nz(ReadParametar("CFG_Sys", "SysAppEchoUvekTrue"), True)
   pCheckEcho = True
   
   pSysConnectionTimeOut = CInt(Nz(ReadParametar("CFG_Sys", "SysConnectionTimeOut"), 15))
    
   ' START 28-08-18
   pSysTabStopPodesiFormu = CBool(Nz(ReadParametar("CFG_Sys", "SysTabStopPodesiFormu"), True))
   pSysCFG_TabStop_TableName = CStr(Nz(ReadParametar("CFG_Sys", "SysCFG_TabStop_TableName"), "CFG_TabStop"))
   
   If Not ADO_PostojiTabelaUBazi(CNN_CFG_Lokal(), pSysCFG_TabStop_TableName) Then
       pSysCFG_TabStop_TableName = "APL_CFG_TabStop"
   End If
   
   '14-01-2021 izbaceno
   'If Not PostojiTabelaUBazi(pSysCFG_TabStop_TableName, CurrentDb) Then
   '   pSysTabStopPodesiFormu = False
   'End If
   
   ' END 28-08-18
   pSysVodiDnevnik = CBool(Nz(ReadParametar("CFG_Sys", "SysVodiDnevnik"), False))
   pSysSuspendOpenSynchForm = CBool(Nz(ReadParametar("CFG_Sys", "SysSuspendOpenSynchForm"), False))
    
   pSysSynchAllMPDokType = CBool(Nz(ReadParametar("CFG_Sys", "SysSynchAllMPDokType"), 0))
   pSysSynchAllMPDokWhere = CStr(Nz(ReadParametar("CFG_Sys", "SysSynchAllMPDokWhere"), ""))
   
End Sub
Private Sub InitializeFromAPL()
'*********************************************************************************
'parametri koji ne zavise od linkovanih tabela tj. od toga da li su linkovi "zdravi"
'*********************************************************************************
    
    pAPLUserName = CurrentUser()
    'pGodina = DatePart("yyyy", Date) 'prebaceno u CFG_Sys
    
    
    pNoExplorer = False 'Mora još da se radi za True
    pKasa_Smena = 1
    
    If ADO_PostojiTabelaUBazi(CNN_CurrentDataBase(), "_Rev") Then
        If GetParFromCnnString("DRIVER=", CNN_CurrentDataBase()) Like "SQL*" Then
            pCNNString = "ODBC;" & CNN_CurrentDataBase() 'CurrentDb.TableDefs("R_Tarife").Connect
            pAppName = "QMegaTeh"
        Else 'Access baza
            pCNNString = CNN_CurrentDataBase()
            If Nz(ReadParametar("CFG_Sys", "SysTipKorisnika"), 0) = 1 Then
             pAppName = "A-QMegaTeh"
            Else
             pAppName = "QMegaTeh"
            End If
        End If
    Else
       pCNNString = "Disconeted!"
       pAppName = "QMegaTeh!"
    End If
    
   pTestPravaPristupa = False
   
   If ADO_PostojiTabelaUBazi(CNN_CurrentDataBase(), "BBDefUser") Then
    pNivoBaze = Nz(ADO_Lookup(CNN_CurrentDataBase(), "[Level]", "BBDefUser", "[UserName] = '" & CurrentUser() & "'"), 0)
   Else
    pNivoBaze = 0
   End If
End Sub
Public Sub InitializeFromRadniFajlovi(lintIDFirma As Long)
    
   'pVPCenovnik = RFReadParameter("VPCenovnik")
   If pCheckLink_RadniFajlovi Then 'SysCheckLink("Radni fajlovi") Then
    pVPCenovnik = Nz(RFReadParameter("VPCenovnik", lintIDFirma, True), "")
    pProveraZalihaMag = Nz(RFReadParameter("ProveraZalihaMag", lintIDFirma, True), True)
   Else
    pVPCenovnik = ""
    pProveraZalihaMag = True
    MsgBox "Tabela [Radni fajlovi] nije dostupna.", vbExclamation, "QMegaTeh"
   End If
End Sub
Private Sub InitializeFromCFG_GLOBAL()
On Error GoTo Err_Point
 'Dim Ok As Boolean
    
    pBB_TMP_FileName = CurrentProject.Path & "\BB_TMP.mdb"
    pBB_CFG_Lokal_FileName = CurrentProject.Path & "\BB_CFG_Lokal.mdb"
    
    If Not pCheckLink_CFG_Global Then ' SysCheckLink("CFG_GLOBAL") Then
     Exit Sub
     MsgBox "Tabela [CFG_GLOBAL] nije dostupna.", vbExclamation, "QMegaTeh"
    End If
            
    '14-01-2021 IZBACENO!!
    'ForsirajLink_BB_CFG_Lokal = Nz(ReadParametar("CFG_GLOBAL", "ForsirajLink_BB_CFG_Lokal"), True)
    'ForsirajLink_BB_TMP = Nz(ReadParametar("CFG_GLOBAL", "ForsirajLink_BB_TMP"), True)
    
    
    pLogoFontSize = CInt(Nz(ReadParametar("CFG_Global", "LogoFontSize"), 28))
    pTextFakturisao = CStr(Nz(ReadParametar("CFG_Global", "TextFakturisao"), "Fakturisao"))
    pDevValuta = CStr(Nz(ReadParametar("CFG_Global", "DefaultDevValuta"), "RSD"))
    pKnjigaKEPU = CStr(Nz(ReadParametar("CFG_Global", "KnjigaKEPU"), "KEPU_SRB"))
    pDefaultPDVVisaStopa = CCur(Nz(ReadParametar("CFG_Global", "DefaultPDVVisaStopa"), 20))
    pDefaultPDVNizaStopa = CCur(Nz(ReadParametar("CFG_Global", "DefaultPDVNizaStopa"), 10))
    
    'pProveraZaliha = RFReadParameter("ProveraZalihaMag")
    pProveraZalihaNaDatumDokumenta = CBool(Nz(ReadParametar("CFG_Global", "ProveraZalihaNaDatumDokumenta"), False))
    
    pRPT_MemorandumHeader = Nz(ReadParametar("CFG_Global", "RPT.Memorandum_Header"), "Memorandum_Header_STD")
    pRPT_MemorandumFooter = Nz(ReadParametar("CFG_Global", "RPT.Memorandum_Footer"), "Memorandum_Footer_STD")
    
    pProizvodnjaUMP = CBool(Nz(ReadParametar("CFG_Global", "ProizvodnjaUMP"), False))
    
    pFPFRPrefixZaNazivArtikla = Nz(ReadParametar("CFG_Global", "FP.FR.PrefixZaNazivArtikla"), "PLU")
    pIFKLNC = Nz(ReadParametar("CFG_Global", "IFKLNC"), "NC")
    
    pPrikazZalihaMag = Nz(ReadParametar("CFG_Global", "PrikazZalihaMag"), True)
    
   
 
    pImeFormeRN = Nz(ReadParametar("CFG_Global", "ImeFormeRN"), "ObracunRadnogNaloga")
    pUFAutoUpisiBrDokUOpis = Nz(ReadParametar("CFG_Global", "UFAutoUpisiBrDokUOpis"), False)
   
    
    pAutoBrojDok = Nz(ReadParametar("CFG_Global", "AutoBrojDok"), "MaxVrstaDok")
    pBrojZnakovaZaBrDok = Nz(ReadParametar("CFG_Global", "BrojZnakovaZaBrDok"), 5)
   
    pPoslednjaKLPoMag = Nz(ReadParametar("CFG_Global", "PoslednjaKLPoMag"), True)
   
    '******************************************************************************
    ' za Deklaracije nije dovoljan samo parametar u CFG_Global
    ' mora da postoji i link ka tabeli R_Artikli_Deklaracije
    pDeklaracije = Nz(ReadParametar("CFG_Global", "Deklaracije"), False)
    If pDeklaracije Then 'ako je False nema potrebe da radi F_CheckLink
      pDeklaracije = pDeklaracije And ADO_PostojiTabelaUBazi(CNN_CurrentDataBase(), "R_Artikli_Deklaracije")
    End If
    '******************************************************************************
   
    '******************************************************************************
    ' za CarinskiMagacin nije dovoljan samo parametar u CFG_Global
    ' mora da postoji i link ka tabelama za CarinskiMagacin
    pCarinskiMagacin = Nz(ReadParametar("CFG_Global", "CarinskiMagacin"), False)
    
    If pCarinskiMagacin Then 'ako je False nema potrebe da radi F_CheckLink
     pCarinskiMagacin = pCarinskiMagacin And ADO_PostojiTabelaUBazi(CNN_CurrentDataBase(), "T_CMDok_Ulaz")
     pCarinskiMagacin = pCarinskiMagacin And ADO_PostojiTabelaUBazi(CNN_CurrentDataBase(), "T_CMStavke_Ulaz")
     pCarinskiMagacin = pCarinskiMagacin And ADO_PostojiTabelaUBazi(CNN_CurrentDataBase(), "T_CMDok_Izlaz")
     pCarinskiMagacin = pCarinskiMagacin And ADO_PostojiTabelaUBazi(CNN_CurrentDataBase(), "T_CMStavke_Izlaz")
     pCarinskiMagacin = pCarinskiMagacin And ADO_PostojiTabelaUBazi(CNN_CurrentDataBase(), "CarinskeTarife")
   End If
    '******************************************************************************
    
    'Koristi se iz Radnih fajlova
    'pVPCenovnik = Nz(ReadParametar("CFG_Global", "VPCenovnik"), pVPCenovnik)
    '
    pVPRabatPoArtiklima = Nz(ReadParametar("CFG_Global", "VPRabatPoArtiklima"), False)
    pUFKLStampaOkreni = Nz(ReadParametar("CFG_Global", "UFKLStampaOkreni"), False)
    
    'pMaticnaSifra = Nz(DLookup("[Sifra]", "Komitenti", "[Vrsta sifre] = 'MATSIF'"), 0)
    '08-03-2021
    'pMaticnaSifra = Nz(ADO_Lookup(CNN_CurrentDataBase(), "[Sifra]", "Komitenti", "[Vrsta sifre] = 'MATSIF'"), 0)
    pMaticnaSifra = F_IDMaticnaSifra()
    
    pUnosNalogaGK_FormName = Nz(ReadParametar("CFG_Global", "UnosNalogaGK_FormName"), "GKNalog")
    pPOPDV_BrDec = Nz(ReadParametar("CFG_Global", "POPDV_BrDec"), 0)
    
    pSvaKontaKupaca = CStr(Nz(ReadParametar("CFG_Global", "SvaKontaKupaca"), "204*"))
    pSysBigBitReklama = CStr(Nz(ReadParametar("CFG_Global", "BigBitReklama"), ""))
    
    pZaliheOdDatuma = CStr(Nz(ReadParametar("CFG_Global", "ZaliheOdDatuma"), "ZaGodinu"))
    
    pIF_ProdavacIzKomitenta = ReadCFGParametar("IF.ProdavacIzKomitenta", True)
    pIF_AutoSaveZagDok = ReadCFGParametar("FORM.IF.AutoSaveZagDok", True)
    
    pObracunCenaPoMagacinu = ReadCFGParametar("ObracunCenaPoMagacinu", True)
    
    'Modifikovano 03-04-2024
    pMaxDanaZaPeriodNaloga = Nz(ReadParametar("CFG_Global", "MaxDanaZaPeriodNaloga"), 0)
    
    'Modifikovano 19-06-2024 PrebaciKomitenteIzEXTBaze i PrebaciPredmeteIzEXTBaze
    pPrebaciKomitenteIzEXTBaze = Nz(ReadParametar("CFG_Global", "PrebaciKomitenteIzEXTBaze"), False)
    pPrebaciPredmeteIzEXTBaze = Nz(ReadParametar("CFG_Global", "PrebaciPredmeteIzEXTBaze"), False)
    
    pVremeIsporukeDana = Nz(ReadParametar("CFG_Global", "VremeIsporukeDana"), 0)
    
Exit_Point:
Exit Sub

Err_Point:

 MsgBox err.Number & vbCrLf & err.Description & vbCrLf & "Sub: InitializeFromCFG_GLOBAL", vbInformation, "QMegaTeh"
 Resume Next
End Sub
Private Sub InitializeFromCFG_LOKAL()
On Error GoTo Err_Point

    If Not pCheckLink_CFG_Lokal Then  'SysCheckLink("CFG_LOKAL") Then
      MsgBox "Tabela [CFG_LOKAL] nije dostupna.", vbExclamation, "QMegaTeh"
      Exit Sub
    End If

    pIDJezik = ReadParametar("CFG_Lokal", "IDNaJezik") 'CLng(Nz(ReadParametar("CFG_LOKAL", "IDNaJezik"), 0))
    
    pColorLock = CLng(Nz(ReadParametar("CFG_LOKAL", "ColorLock"), C_LockColor))
    pColorUnLock = CLng(Nz(ReadParametar("CFG_LOKAL", "ColorUnLock"), C_UnLockColor))
   
    pKasa_Cenovnik = CStr(Nz(ReadParametar("CFG_Lokal", "Kasa_Cenovnik"), "MP1"))
    pKasa_CenovnikPola = CStr(Nz(ReadParametar("CFG_Lokal", "Kasa_CenovnikPola"), "MP1P"))
    pKasa_VrstaDokumenta = CStr(Nz(ReadParametar("CFG_Lokal", "Kasa_VrstaDokumenta"), "MP1"))
    pKasa_ProdavnicaID = CLng(Nz(ReadParametar("CFG_Lokal", "Kasa_ProdavnicaID"), 0))
    pKasa_KasaID = CLng(Nz(ReadParametar("CFG_Lokal", "Kasa_KasaID"), 0))
    pKasa_KupacID = CLng(Nz(ReadParametar("CFG_Lokal", "Kasa_KupacID"), 0))
    pKasa_ProveraZaliha = CBool(Nz(ReadParametar("CFG_Lokal", "Kasa_ProveraZaliha"), False))
    pKasa_RadniNalog = CLng(Nz(ReadParametar("CFG_Lokal", "Kasa_RadniNalog"), 0))
    pKasa_NumKbd = CBool(Nz(ReadParametar("CFG_Lokal", "Kasa_NumKbd"), False))
    pKasa_ZakljucajPosleNaplate = Nz(ReadParametar("CFG_Lokal", "Kasa_ZakljucajPosleNaplate"), True)
    pKasa_NeManjaKolicina = Nz(ReadParametar("CFG_Lokal", "Kasa_NeManjaKolicina"), True)
    pKasa_NeMenjajArtikal = Nz(ReadParametar("CFG_Lokal", "Kasa_NeMenjajArtikal"), True)
    pKasa_TabStopKolicina = Nz(ReadParametar("CFG_Lokal", "Kasa_TabStopKolicina"), False)
        
    pKasa_DozvoljenRabatStavke = Nz(ReadParametar("CFG_Lokal", "Kasa_DozvoljenRabatStavke"), False)
    pKasa_DozvoljenRabatRN = Nz(ReadParametar("CFG_Lokal", "Kasa_DozvoljenRabatRN"), False)
    pKasa_PrenesiRabatKomitentaNaStavku = Nz(ReadParametar("CFG_Lokal", "Kasa_PrenesiRabatKomitentaNaStavku"), False)
    
    pKasa_TabStopRabatProc = Nz(ReadParametar("CFG_Lokal", "Kasa_TabStopRabatProc"), False)
    pKasa_Cena_Locked = Nz(ReadParametar("CFG_Lokal", "Kasa_Cena_Locked"), True)
    
    pGALEBFP550 = CBool(Nz(ReadParametar("CFG_Lokal", "GALEBFP550"), False))
    pACS = CBool(Nz(ReadParametar("CFG_Lokal", "ACS"), False))
    pKonobarAPL = Nz(ReadParametar("CFG_Lokal", "KonobarAPL"), "PrvaMaskaKonobar")
    pMestoIzdavanjaRacuna = Nz(ReadParametar("CFG_Lokal", "MestoIzdavanjaRacuna"), "Beograd")
    pKafe_IDMestoIzdavanjaRobe = CLng(Nz(ReadParametar("CFG_Lokal", "Kafe_IDMestoIzdavanjaRobe"), -1))
    
    pBizerbaExportFileName = Nz(ReadParametar("CFG_Lokal", "BizerbaExportFileName"), "C:\SHARES\AcBaze\EXPORT\BIZERBA\PLST.TXT")
    
    'pDefaultDirNovaBaza = Nz(ReadParametar("CFG_Lokal", "BBDefaultDirNovaBaza"), WorkDir)
    pDefaultDirNovaBaza = Nz(ReadCFGParametar("BBDefaultDirNovaBaza"), CurrentProject.Path)
    
    'pDefaultLimitedUser = Nz(ReadParametar("CFG_Global", "DefaultLimitedUser"), "")
    'If pDefaultLimitedUser = "" Then
    ' pDefaultLimitedUser = Nz(ReadParametar("CFG_Lokal", "DefaultLimitedUser"), "RDPUser")
    'End If
    pDefaultLimitedUser = Nz(ReadCFGParametar("DefaultLimitedUser"), "RDPUser")
    
    pKatBrojField = Nz(ReadParametar("CFG_Lokal", "RPT.IF.KatBroj.Field"), "Kataloski broj")
    pKatBrojLabel = Nz(ReadParametar("CFG_Lokal", "RPT.IF.KatBroj.Label"), "Kat. br.")
 
    pKasa_ProdajaPoKatBroju = CBool(Nz(ReadParametar("CFG_Lokal", "Kasa_ProdajaPoKatBroju"), False))
    
    pDefaultTabUnosArtikala = Nz(ReadParametar("CFG_Lokal", "DefaultTabUnosArtikala"), "Cene")
    pIF_Podforma_TabStopOpisStavke = Nz(ReadParametar("CFG_Lokal", "IF.Podforma.TabStopOpisStavke"), False)
   
    pKasa_AutoLogin = Nz(ReadParametar("CFG_Lokal", "Kasa_AutoLogin"), False)
    
    '**************
    If pKasa_AutoLogin Then
        pKasa_PWD = Nz(ReadParametar("CFG_Lokal", "PWDKasir"), "")
        If ADO_PostojiTabelaUBazi(CNN_CurrentDataBase(), "Prodavci") Then
            On Error Resume Next
            pKasa_IDProdavac = Nz(ADO_Lookup(CNN_CurrentDataBase, "[Sifra prodavca]", "Prodavci", "[Password] = '" & pKasa_PWD & "'"), -1)
            On Error GoTo Err_Point
        Else
            pKasa_IDProdavac = -1
        End If
    Else
      pKasa_PWD = ">>UNKNOWN<<"
      pKasa_IDProdavac = -1
    End If
    
    'If pKasa_IDProdavac = -1 Then
    '    pKasa_IDProdavac = Nz(ADO_Lookup(CNN_CurrentDataBase, "[Sifra prodavca]", "Prodavci", "[Prodavac] = '" & CurrentUser & "'"), 0)
    'End If
    pKasa_IDProdavac = 0
    
    pDirImport = Nz(ReadParametar("CFG_Lokal", "DIR_Import"), "")
    pDirExport = Nz(ReadParametar("CFG_Lokal", "DIR_Export"), "")
    'pSHUTTLE_FileName = Nz(ReadParametar("CFG_Lokal", "SHUTTLE_FileName"), "")
    
    pODBC_Synch_LogFileName = Nz(ReadParametar("CFG_Lokal", "ODBC_Synch_LogFileName"), "")
    pODBC_Synch_FormName = Nz(ReadParametar("CFG_Lokal", "ODBC_Synch_FormName"), "ODBC_Synch")
    pODBC_Synch_TimerInterval = Nz(ReadParametar("CFG_Lokal", "ODBC_Synch_TimerInterval"), 0)
    pODBC_Synch_AutoStart = Nz(ReadParametar("CFG_Lokal", "ODBC_Synch_AutoStart"), False)
    pODBC_Synch_SvakiMPDok = Nz(ReadParametar("CFG_Lokal", "ODBC_Synch_SvakiMPDok"), False)
    pODBC_Synch_MPDok_OnCloseKasa = Nz(ReadParametar("CFG_Lokal", "ODBC_Synch_MPDok_OnCloseKasa"), False)
    pODBC_Synch_MPDok_OnCloseKasa_AskUser = Nz(ReadParametar("CFG_Lokal", "ODBC_Synch_MPDok_OnCloseKasa_AskUser"), True)
    
    pMemorandumHeaderVisible = Nz(ReadParametar("CFG_Lokal", "MemorandumHeaderVisible"), True)
    'pPOPDV_PrikaziTotale = Nz(ReadParametar("CFG_Lokal", "POPDV_PrikaziTotale"), True)
    pPOPDV_PrikaziTotale = Nz(ReadCFGParametar("POPDV_PrikaziTotale"), False)
    
    'MODIFIKOVANO: 20-07-2025
    pStartRibbonName = Nz(ReadParametar("CFG_Lokal", "StartRibbonName"), "")
    
Exit_Point:
Exit Sub

Err_Point:

 MsgBox err.Number & vbCrLf & err.Description & vbCrLf & "Sub: InitializeFromCFG_LOKAL", vbInformation, "QMegaTeh"
 Resume Next
 
End Sub
Private Sub PostaviGodinuIzCFG()
'Kreirano: 13-01-2020
'Podrazumeva se da su tabele CFG_Sys i CFG_Lokal dostupne!
'*****************************************************
On Error GoTo Err_Point
   Dim pTmpGodina
   Dim stCFGTabela As String
   Dim lintGodina As Long
   
    
   stCFGTabela = Nz(ReadParametar("CFG_Sys", "SysDefaultGodina_IzTabele"), "CFG_Sys")
   If stCFGTabela = "CFG_Sys" Then
      pTmpGodina = ReadParametar("CFG_Sys", "SysDefaultGodina")
   Else
      pTmpGodina = ReadParametar(stCFGTabela, "DefaultGodina")
   End If
   If Not IsNull(pTmpGodina) And IsNumeric(pTmpGodina) Then
           lintGodina = CLng(pTmpGodina)
    Else
           lintGodina = Year(Date)
    End If
   
Exit_Point:
On Error Resume Next
   Godina = lintGodina
   
Exit Sub

Err_Point:
   BBErrorMSG err, "Class:BBCFG, sub:PostaviGodinuIzCFG"
   lintGodina = Year(Date)
   Resume Exit_Point
End Sub
Private Sub PostaviFirmuIzCFG()
'Kreirano: 13-01-2020
'Podrazumeva se da su tabele CFG_Sys i CFG_Lokal dostupne!
'*****************************************************
On Error GoTo Err_Point
   Dim pTmpIDFirma
   Dim stCFGTabela As String
   Dim lintIDFirma As Long
   
    
   stCFGTabela = Nz(ReadParametar("CFG_Sys", "SysDefaultIDFirma_IzTabele"), "CFG_Sys")
   If stCFGTabela = "CFG_Sys" Then
      pTmpIDFirma = ReadParametar("CFG_Sys", "SysDefaultIDFirma")
   Else
      pTmpIDFirma = ReadParametar(stCFGTabela, "DefaultIDFirma")
   End If
   If Not IsNull(pTmpIDFirma) And IsNumeric(pTmpIDFirma) Then
           lintIDFirma = CLng(pTmpIDFirma)
    Else
           lintIDFirma = 0
    End If
   
Exit_Point:
On Error Resume Next
   
   IDFirma = lintIDFirma '(Ovde se postavljaju i parametri iz radnih fajlova)
   
Exit Sub

Err_Point:
   BBErrorMSG err, "Class:BBCFG, sub:PostaviFirmuIzCFG"
   lintIDFirma = 0
   Resume Exit_Point
End Sub
Private Sub InitializeFirmaIGodina()
'Kreitano: 13-01-2020
'Podrazumeva se da su tabele CFG_Sys i CFG_Lokal dostupne!
'*****************************************************
On Error GoTo Err_Point
   
   PostaviGodinuIzCFG
   PostaviFirmuIzCFG
   
Exit_Point:
On Error Resume Next

Exit Sub

Err_Point:
   BBErrorMSG err, "Class:BBCFG, sub:InitializeFirmaIGodina"
   Resume Exit_Point
End Sub

Public Property Get ZaliheOdDatuma() As Variant
Dim retVal As Date
  If IsDate(pZaliheOdDatuma) Then
    retVal = CVDate(pZaliheOdDatuma)
  Else
     'retVal = CVDate("01-01-" & pGodina)
     retVal = DateSerial(LIB_CFGRW.Godina, 1, 1)
  End If
  ZaliheOdDatuma = retVal
End Property

Public Property Let ZaliheOdDatuma(ByVal vNewValue As Variant)
  pZaliheOdDatuma = vNewValue
End Property

Public Property Get IF_ProdavacIzKomitenta() As Boolean
   IF_ProdavacIzKomitenta = pIF_ProdavacIzKomitenta
End Property

Public Property Let IF_ProdavacIzKomitenta(ByVal vNewValue As Boolean)
   pIF_ProdavacIzKomitenta = vNewValue
End Property
Private Function SourceTableNameZaTabelu(imeTabele As String) As String
Dim IDBaze
Dim stRetVal As String
 stRetVal = Nz(ADO_Lookup(CNN_FIT(), "[SourceTableName]", "BazeITabele", "[Name]= '" & imeTabele & "'"), "")
 SourceTableNameZaTabelu = stRetVal
End Function
Private Sub HideNavPane(bVisible As Boolean)
'Datum: 31-08-18
    On Error GoTo Error_Handler
Exit Sub

    If Not SysCmd(acSysCmdRuntime) Then  '= False Then 'ako nije RunTime
        If bVisible Then
            '            DoCmd.SelectObject acTable, , True
            DoCmd.SelectObject acModule, , True
            DoCmd.RunCommand acCmdWindowUnhide
        Else
            '           DoCmd.SelectObject acTable, , True
            '           DoCmd.SelectObject acTable, "_Rev", True
            '           DoCmd.NavigateTo ("acNavigationCategoryObjectType")
                        
            DoCmd.SelectObject acModule, , True
            DoCmd.RunCommand acCmdWindowHide
        End If
    End If
 
Error_Handler_Exit:
    On Error Resume Next
    Exit Sub
 
Error_Handler:
    MsgBox "The following error has occured" & vbCrLf & vbCrLf & _
           "Error Number: " & err.Number & vbCrLf & _
           "Error Source: HideNavPane" & vbCrLf & _
           "Error Description: " & err.Description _
           , vbOKOnly + vbCritical, "An Error has Occured!"
    Resume Error_Handler_Exit
End Sub
Public Property Get VremeIsporukeDana() As Integer
   VremeIsporukeDana = pVremeIsporukeDana
End Property

Public Property Let VremeIsporukeDana(ByVal vNewValue As Integer)
   pVremeIsporukeDana = vNewValue
End Property

Private Sub Class_Initialize()
'****************************************************
'Modifikovano: 05-04-2020
'Opis: dodat "refres" linka za ES_Synch_DB SQL bazu
'Modifikovano: 08-03-2021
'****************************************************
Dim retValOk As Boolean

 DoCmd.Hourglass True
 IntroComment "Class_Initialize"
 
   'If Not PostojiTabelaUBazi("_T_Rev", CurrentDb) Then 'insistitamo(ne znam zasto)??? da postoji DAO link _T_Rev
   ' retValOk = ForsirajNoviLinkZaTabelu("_T_Rev", SourceTableNameZaTabelu("_T_Rev"), "ODBC;" & CNN_CurrentDataBase())
   'End If
If PostojiTabelaUBazi("_T_Rev", CurrentDb) Then

   If CurrentDb.TableDefs("_T_Rev").Connect Like "*ODBC*" Then
    'retValOk = ForsirajNoviLinkZaTabelu("_T_Rev", SourceTableNameZaTabelu("_T_Rev"), BazaZaTabelu("_T_Rev"))
    retValOk = ForsirajNoviLinkZaTabelu("_T_Rev", SourceTableNameZaTabelu("_T_Rev"), "ODBC;" & CNN_CurrentDataBase())
    HideNavPane False
    If Not retValOk Then
     If CurrentUser <> "Negovan" Then
      DoCmd.Quit
     Else
      If Not BBPitanje("Ne može da se uradi refresh linka za tabelu [_T_Rev]" & vbCrLf & "Da li nastavljate izvršavanje programa?") Then
        Exit Sub
      End If
     End If
    End If
   End If
End If

   '****************************************************
   '05-04-2020
   'RefresAllLinkedDB() ovo bi trebalo napraviti za slucaj da ima vise SQL baza!!
   'sada cemo ovako:
   If PostojiTabelaUBazi("es_order", CurrentDb) Then
      retValOk = ForsirajNoviLinkZaTabelu("es_order", SourceTableNameZaTabelu("es_order"), "ODBC;" & CNN_ESDB)
   End If
   '****************************************************
   
    If PostojiTabelaUBazi("ODBC_Synch_Request", CurrentDb) Then
     pCheckLink_ODBC_Synch_Request = ForsirajNoviLinkZaTabelu("ODBC_Synch_Request", SourceTableNameZaTabelu("ODBC_Synch_Request"), "ODBC;" & CNN_MasterDB)
    Else
     pCheckLink_ODBC_Synch_Request = False
    End If
    
    pCheckLink_CFG_Sys = True 'SysCheckLink("CFG_Sys")
    pCheckLink_RadniFajlovi = True 'SysCheckLink("Radni fajlovi", , , True) 'Proveri da li postoji tabela [Radni fajlovi]
    
    If Not pCheckLink_RadniFajlovi Then 'Ako ne postoji tabela, proveri da li postoji UPIT [Radni fajlovi]
      pCheckLink_RadniFajlovi = PostojiQuery("Radni fajlovi")
    End If
    
    
    If pCheckLink_RadniFajlovi Then
     If ADO_Lookup(CNN_CurrentDataBase(), "BrojSlogova", "SELECT COUNT(*) as BrojSlogova FROM [Radni fajlovi]") = 0 Then
        pCheckLink_RadniFajlovi = False
     End If
    End If
    
    pCheckLink_CFG_Global = ADO_PostojiTabelaUBazi(CNN_CurrentDataBase(), "CFG_Global")
    pCheckLink_Prodavci = ADO_PostojiTabelaUBazi(CNN_CurrentDataBase(), "Prodavci")
    
    IntroComment "InitializeFromCFG_Sys"
    InitializeFromCFG_Sys
    
    IntroComment "InitializeFromAPL"
    InitializeFromAPL
    
    IntroComment "InitializeFromCFG_GLOBAL"
    InitializeFromCFG_GLOBAL
     pCheckLink_CFG_Lokal = ADO_PostojiTabelaUBazi(CNN_CFG_Lokal(), "CFG_Lokal")
     
    IntroComment "InitializeFromCFG_LOKAL"
    InitializeFromCFG_LOKAL
    
    IntroComment "InitializeFirmaIGodina"
    InitializeFirmaIGodina
    'Ne treba jer se poziva indirektno kod dodele IDFirma = ...pIDFirma InitializeFromRadniFajlovi Me.IDFirma
    
 DoCmd.Hourglass False
   'BBCFG_Initialized = True
   
   
   
'***************************************************************************************************
  'otvori ODBC_Synch formu
  '14-01-2021 izbaceno
  'If Not SysDisabledSynch Then
  ' If Me.ODBC_Synch_AutoStart _
  '    And PostojiForma(Me.ODBC_Synch_FormName) _
  '    And (Not pSysSuspendOpenSynchForm) Then
  '  DoCmd.OpenForm Me.ODBC_Synch_FormName
  ' End If
  'End If
'***************************************************************************************************
  
End Sub
'***************************************************************************************************
'14-01-2021 izbaceno
'***************************************************************************************************
'Public Property Let ForsirajLink_BB_CFG_Lokal(ByVal vNewValue As Boolean)
'Modifikovano: 14-12-2020

 
 'If Not Nz(ReadParametar("CFG_Sys", "SysSuspendForsirajLink_BB_CFG_Lokal"), False) Then
 '  If vNewValue = True Then
 '     pForsirajLink_BB_CFG_Lokal = ForsirajNoveLinkoveZaTipBaze("LOKAL_CFG", pBB_CFG_Lokal_FileName)
 '     'Ovde uskladjujemo CNN_CFG_Lokal sa linkovima
 '     If pForsirajLink_BB_CFG_Lokal Then 'ako je forsiranje proslo TRUE
 '        CNN_CFG_Lokal = CreateAccess_CNNString(pBB_CFG_Lokal_FileName)
 '        Call BBCreateProperty("CNN_CFG_Lokal", , CNN_CFG_Lokal) 'kreira ga ili mu menja vrednost
 '     End If
 '  End If
 ' End If

 'End Property
'*****************************************************************************************************
'Public Property Let ForsirajLink_BB_TMP(ByVal vNewValue As Boolean)
' pForsirajLink_BB_TMP = vNewValue
' If Not Nz(ReadParametar("CFG_Sys", "SysSuspendForsirajLink_BB_TMP"), False) Then
'  If vNewValue Then
'     pForsirajLink_BB_TMP = ForsirajNoveLinkoveZaTipBaze("TMP", pBB_TMP_FileName)
'     'Ovde uskladjujemo CNN_CFG_Lokal sa linkovima
'     If pForsirajLink_BB_TMP Then 'ako je forsiranje proslo TRUE
'        CNN_TempDB = CreateAccess_CNNString(pBB_TMP_FileName)
'        Call BBCreateProperty("CNN_TempDB", , CNN_TempDB) 'kreira ga ili mu menja vrednost
'     End If
'
'     IntroMsg = "Kreiranje novih linkova za BB_TMP"
'  End If
' End If
'End Property
'***************************************************************************************************

