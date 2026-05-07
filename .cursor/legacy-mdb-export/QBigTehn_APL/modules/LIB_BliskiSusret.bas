Attribute VB_Name = "LIB_BliskiSusret"
Option Compare Database
Option Explicit

'**************************************************************************************
'**************************************************************************************
Public Function F_IDMaticnaSifra() As Long
'Modifikovano: 22-10-21
On Error GoTo Err_Point
Dim IDRetVal
    
    'F_IDMaticnaSifra = Nz(DLookup("[Sifra]", "Komitenti", "[Vrsta sifre] = 'MATSIF'"), 0)
If PostojiTabelaUBazi("Komitenti", CurrentDb) Then
    IDRetVal = ADO_Lookup(CNN_CurrentDataBase, "[Sifra]", "Komitenti", "[PIB] = '" & F_AFPIB() & "'")
    If IsNull(IDRetVal) Then
       IDRetVal = Nz(ADO_Lookup(CNN_CurrentDataBase, "[Sifra]", "Komitenti", "[Vrsta sifre] = 'MATSIF'"), 0)
    End If
Else
    IDRetVal = 0
End If

Exit_Point:
 On Error Resume Next
       F_IDMaticnaSifra = CLng(Nz(IDRetVal, 0))
Exit Function

Err_Point:
 BBErrorMSG err, "F_IDMaticnaSifra"
 IDRetVal = 0
 Resume Exit_Point
End Function
Public Function F_MaticnaSifra() As Long
 F_MaticnaSifra = BBCFG.MaticnaSifra
End Function
Public Function F_SysTabelaRadniFajlovi() As String
'**********************
'Kreirano: 08.01.2019.
'Opis: Naziv tabele koja se koristi kao [Radni fajlovi]
'29-11-2021 Bez uglastih zagrada
F_SysTabelaRadniFajlovi = Nz(ReadParametar("CFG_Sys", "SysTabelaRadniFajlovi"), "T_Radni fajlovi") '29-11-2021 Bez uglastih zagrada
End Function
Public Function F_SysTabelaSemaZaKontiranje() As String
'**********************
'Kreirano: 08.01.2019.
'29-11-2021 Bez uglastih zagrada
F_SysTabelaSemaZaKontiranje = Nz(ReadParametar("CFG_Sys", "SysTabelaSemaZaKontiranje"), "T_Sema za kontiranje") '29-11-2021 Bez uglastih zagrada
End Function
Public Function F_SysTabelaStavkeSemeZaKontiranje() As String
'**********************
'Kreirano: 08.01.2019.
'29-11-2021 Bez uglastih zagrada
F_SysTabelaStavkeSemeZaKontiranje = Nz(ReadParametar("CFG_Sys", "SysTabelaStavkeSemeZaKontiranje"), "T_Stavke seme za kontiranje") '29-11-2021 Bez uglastih zagrada
End Function
Public Function F_SysTabelaUplatniRacuni() As String
'**********************
'Kreirano: 08.01.2019.
'29-11-2021 Bez uglastih zagrada
F_SysTabelaUplatniRacuni = Nz(ReadParametar("CFG_Sys", "SysTabelaUplatniRacuni"), "T_UplatniRacuni") '29-11-2021 Bez uglastih zagrada
End Function
'***********************************************
Public Function F_OdDatuma(Optional ByVal ZaGodinu) As Variant
On Error GoTo Err_Point
'Kreirano: 02.01.2019.
'Modifikovano: 07.10.2019.
'Modifikovano: 24-08-2021,
Dim pGodina As Long

 If IsMissing(ZaGodinu) Then
    pGodina = F_Godina()
 ElseIf IsNumeric(ZaGodinu) Then
    pGodina = CLng(ZaGodinu)
 Else
    pGodina = 2000
 End If
 
F_OdDatuma = CVDate("01-01-" & pGodina)
  
Exit_Point:
 On Error Resume Next
       
Exit Function

Err_Point:
 BBErrorMSG err, "F_OdDatuma"
 Resume Exit_Point
End Function
Public Function F_DoDatuma(Optional ByVal ZaGodinu) As Variant
On Error GoTo Err_Point
'Modifikovano: 07.10.2019.
'Modifikovano: 24-08-2021
Dim pGodina As Long

If IsMissing(ZaGodinu) Then
    pGodina = F_Godina()
ElseIf IsNumeric(ZaGodinu) Then
    pGodina = CLng(ZaGodinu)
 Else
    pGodina = 2099
 End If
 
 If DatePart("yyyy", Date) = pGodina Then
    F_DoDatuma = Date
 Else
    F_DoDatuma = CVDate("31-12-" & pGodina)
 End If
 
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "F_DoDatuma"
 Resume Exit_Point
End Function
Public Function F_AutoBrojDokSufix() As String
'Modifikovano 06-02-2019
'Modifikovano 26-01-2022
On Error GoTo Err_Point
 Dim stRetVal As String
 stRetVal = ""
 If BBCFG.AutoBrojDok = "CountVrstaDok" Then
  'stRetVal = Eval(ReadCFGParametar("AutoBrojDokSufix"))
  stRetVal = ReadCFGParametar("AutoBrojDokSufix", "") '
 End If
Exit_Point:
 On Error Resume Next
 F_AutoBrojDokSufix = stRetVal
Exit Function

Err_Point:
 Resume Exit_Point
End Function
Public Function F_AutoBrojDokPrefix() As String
'Kreirano 06-02-2019
'Modifikovano 26-01-2022
On Error GoTo Err_Point
 Dim stRetVal As String
 stRetVal = ""
 If BBCFG.AutoBrojDok = "CountVrstaDok" Then
  'stRetVal = Eval(ReadCFGParametar("AutoBrojDokPrefix"))
  stRetVal = ReadCFGParametar("AutoBrojDokPrefix", "") '
 End If
Exit_Point:
 On Error Resume Next
 F_AutoBrojDokPrefix = stRetVal
Exit Function

Err_Point:
 Resume Exit_Point
End Function
'***********************************************
Public Function F_AktivnaFirma() As String
'Modifikovano: 07-11-2019
Dim stRetVal As String
    ' 07-11-2019 If Nz(AktivnaFirma, "") = "" Then
     stRetVal = BBCFG.Firma.Naziv & ", " & BBCFG.Firma.MESTO & ", " & BBCFG.Firma.ADRESA & ", " & BBCFG.Firma.Telefon
    ' 07-11-2019 End If
    ' 07-11-2019 F_AktivnaFirma = AktivnaFirma
    F_AktivnaFirma = stRetVal
End Function
Function F_KontoDobavljac() As String
 F_KontoDobavljac = BBCFG.Firma.KontoDobavljac 'RFReadParameter("KontoDobavljac", "4350")
End Function
Function KontoDobavljaca() As String
 KontoDobavljaca = BBCFG.Firma.KontoDobavljac 'RFReadParameter("KontoDobavljac", "4350")
End Function
Function F_KontoKupca() As String
    F_KontoKupca = BBCFG.Firma.KontoKupac
End Function
Function KontoKupca() As String
    KontoKupca = BBCFG.Firma.KontoKupac
End Function
Public Function F_IDAktivneBaze() As Long
On Error GoTo err_Func:

'IDAktivneBaze = F_IDFirma()

exit_Func:
On Error Resume Next

    F_IDAktivneBaze = F_IDFirma()

Exit Function

err_Func:
 MsgBox err.Description, , "QMegaTeh"
 Resume exit_Func
End Function
Public Function F_AFNaziv() As String
 F_AFNaziv = BBCFG.Firma.Naziv
End Function
Public Function F_AFNazivNezvanicno() As String
 F_AFNazivNezvanicno = BBCFG.Firma.NazivNezvanicno
End Function
Public Function F_AFPostBroj() As String
 F_AFPostBroj = BBCFG.Firma.PostBroj
End Function
Public Function F_AFMesto() As String
 F_AFMesto = BBCFG.Firma.MESTO
End Function
Public Function F_AFAdresa() As String
 F_AFAdresa = BBCFG.Firma.ADRESA
End Function
Public Function F_AFOpstina() As String
 F_AFOpstina = BBCFG.Firma.Opstina
End Function
Public Function F_AFPIB() As String
 F_AFPIB = BBCFG.Firma.PIB
End Function
Public Function F_AFTekuciRacun() As String
 F_AFTekuciRacun = BBCFG.Firma.TekuciRacun
End Function
Public Function F_AFTelefon() As String
 F_AFTelefon = BBCFG.Firma.Telefon
End Function
Public Function F_AFFax() As String
 F_AFFax = BBCFG.Firma.Fax
End Function
Public Function F_AFMaticniBroj() As String
 F_AFMaticniBroj = BBCFG.Firma.MaticniBroj
End Function
Public Function F_AFJBKJS() As String
 F_AFJBKJS = BBCFG.Firma.JBKJS
End Function
Public Function F_AFDelatnost() As String
 F_AFDelatnost = BBCFG.Firma.Delatnost
End Function
Public Function F_AFEmail() As String
 F_AFEmail = BBCFG.Firma.Email
End Function
Public Function F_AFSifraDelatnosti() As String
 F_AFSifraDelatnosti = BBCFG.Firma.SifraDelatnosti
End Function
Public Function F_AFWeb() As String
 F_AFWeb = BBCFG.Firma.Web
End Function
Public Function F_AFGLN() As String
 F_AFGLN = BBCFG.Firma.GLN
End Function
Public Function F_AF_Footer_Text() As String
'Kreirano: 20-10-2021
On Error GoTo Err_Point

Dim stRetVal As String

    stRetVal = ""
    stRetVal = stRetVal & IIf(IsNull(F_AFMaticniBroj()), "", "Maticni broj: " & F_AFMaticniBroj())
    stRetVal = stRetVal & "   " & IIf(IsNull(RFReadParameter("Registarski broj")), "", "Registarski broj: " & RFReadParameter("Registarski broj"))
    stRetVal = stRetVal & "   " & IIf(IsNull(F_AFSifraDelatnosti()), "", "Šifra delatnosti: " & F_AFSifraDelatnosti())
    stRetVal = stRetVal & "   " & IIf(IsNull(F_AFPIB()), "", "PIB: " & F_AFPIB())
    stRetVal = stRetVal & "   " & IIf(IsNull(RFReadParameter("PEPDV")), "", "PEPDV: " & RFReadParameter("PEPDV"))
   
Exit_Point:
 On Error Resume Next
 F_AF_Footer_Text = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "F_AF_Footer_Text"
 Resume Exit_Point
End Function
Public Function F_AF_APR_Text() As String
'Kreirano: 20-10-2021
On Error GoTo Err_Point

Exit_Point:
 On Error Resume Next
 F_AF_APR_Text = Nz(RFReadParameter("APRText", F_IDFirma()), "")
Exit Function

Err_Point:
 BBErrorMSG err, "F_AF_Footer_Text"
 Resume Exit_Point
End Function

Public Function F_NivoBaze() As Byte
    F_NivoBaze = BBCFG.NivoBaze
End Function
Public Function F_FP_ImeStampaca() As String
  F_FP_ImeStampaca = Nz(BBCFG.Firma.FP_ImeStampaca, "GALEB01")
End Function
Public Function F_MestoIzdavanjaRacuna() As String
  F_MestoIzdavanjaRacuna = BBCFG.MestoIzdavanjaRacuna()
End Function
Public Function F_DefaultNapomena(Optional Level As Integer = 0) As String
'Modifikovano: 28-01-2022
'Modifikovano: 21-09-2022

On Error GoTo Err_Point
 Dim retValOk As Boolean
 Dim stRetVal As String
 
    If Level < 250 Then
     stRetVal = Nz(BBCFG.Firma.DefaultNapomena, "")
    Else
     stRetVal = Nz(ReadCFGParametar("DefaultNapomenaPROF"), "")
     If stRetVal = "BBCFG.Firma.DefaultNapomena" Then
        stRetVal = Nz(BBCFG.Firma.DefaultNapomena, "")
     End If
    End If
stRetVal = Replace(stRetVal, Chr(34), "'")

Exit_Point:
 On Error Resume Next
       F_DefaultNapomena = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "F_DefaultNapomena"
 retValOk = False
 Resume Exit_Point
End Function
Public Function F_IDNaJezik() As Long
    F_IDNaJezik = BBCFG.IDJezik
End Function
Public Function F_DevValuta() As String
    F_DevValuta = BBCFG.DevValuta()
End Function
Public Function F_KasaCenovnik() As String
    F_KasaCenovnik = BBCFG.Kasa_Cenovnik()
End Function
Public Function F_KasaCenovnikPola() As String
    F_KasaCenovnikPola = BBCFG.Kasa_CenovnikPola()
End Function
Public Function F_KasaVrstaDokumenta() As String
    F_KasaVrstaDokumenta = BBCFG.Kasa_VrstaDokumenta()
End Function
Public Function F_KasaProdavnicaID() As Long
    F_KasaProdavnicaID = BBCFG.Kasa_ProdavnicaID()
End Function
Public Function F_KasaKupacID() As Long
    F_KasaKupacID = BBCFG.Kasa_KupacID()
End Function
Public Function F_KasaID() As Long
    F_KasaID = BBCFG.Kasa_KasaID()
End Function
Public Function F_KasaSmena() As Integer
  F_KasaSmena = BBCFG.Kasa_Smena
End Function
Public Function F_KasaIDProdavac() As Long
  F_KasaIDProdavac = BBCFG.Kasa_IDProdavac
End Function

Public Function F_ProizvodnjaUMP() As Boolean
 F_ProizvodnjaUMP = BBCFG.ProizvodnjaUMP
End Function
Public Function F_FRNazivArtikla(PLU As Long, KatBroj As Variant, NazivArtikla As String) As String
 Dim NNaziv As String
 Dim NZKatBroj As String
 
 NNaziv = ""
 NZKatBroj = Nz(KatBroj, "")
 
  If BBCFG.FPFRPrefixZaNazivArtikla = "KatBroj" Then
   NNaziv = IIf(NZKatBroj = "", NazivArtikla, NZKatBroj & "-" & NazivArtikla)
  ElseIf BBCFG.FPFRPrefixZaNazivArtikla = "PLU" Then
   NNaziv = CStr(PLU) & "-" & NazivArtikla
  ElseIf BBCFG.FPFRPrefixZaNazivArtikla = "NULL" Then
   NNaziv = NazivArtikla
  Else
   NNaziv = CStr(PLU) & "-" & NazivArtikla
  End If
  NNaziv = Left(ZameniNasaSlova(Left(NNaziv, 32)), 32)
  F_FRNazivArtikla = NNaziv
End Function
Public Function F_IFKLNC(NC As Double, KLVP As Double, StvarnaVP As Double) As Double
 Dim RetValNC As Double
 
  If BBCFG.IFKLNC = "NC" Then
   RetValNC = NC
  ElseIf BBCFG.IFKLNC = "KLVP" Then
   RetValNC = KLVP
  ElseIf BBCFG.IFKLNC = "StvarnaVP" Then
   RetValNC = StvarnaVP
  Else
   RetValNC = NC
  End If

  F_IFKLNC = RetValNC
  
End Function
Public Function F_POPDV_BrDec() As Integer
   F_POPDV_BrDec = BBCFG.POPDV_BrDec
End Function
Public Function F_MemorandumHeaderVisible() As Boolean
  F_MemorandumHeaderVisible = BBCFG.MemorandumHeaderVisible()
End Function
Public Function F_UnosNalogaGK_FormName() As String
   F_UnosNalogaGK_FormName = BBCFG.UnosNalogaGK_FormName
End Function
Public Function F_SvaKontaKupaca() As String
    F_SvaKontaKupaca = BBCFG.SvaKontaKupaca()
End Function
Public Function F_DefaultIDMagacin() As Long
    'F_DefaultIDMagacin = CLng(Nz(ReadParametar("CFG_LOKAL", "STDMagacin"), 1))
    F_DefaultIDMagacin = ReadCFGParametar("STDMagacin")
End Function
Public Function F_DefaultIDCM() As Long
    F_DefaultIDCM = ReadCFGParametar("CM_STDMagacin")
End Function
Public Function F_VPCenovnik() As String
'Kreirano: 17-01-2019
 F_VPCenovnik = BBCFG.VPCenovnik()
End Function

Public Function F_ImeFajlaPecIPot() As String
'Kreirano: 22-08-2019
 F_ImeFajlaPecIPot = Nz(ReadParametar("CFG_Global", "ImeFajlaPecIPot"), "")
End Function

Public Function F_BigBitReklama() As String
  F_BigBitReklama = BBCFG.BigBitReklama()
End Function
Public Function F_ZaliheOdDatuma() As Date
'F_ZaliheOdDatuma = CVDate("01-01-" & F_Godina())
F_ZaliheOdDatuma = BBCFG.ZaliheOdDatuma
End Function

Public Function F_ClearCurrentVal(Optional MyForm As Form, Optional DugmePrimeniUslove As control)
'Kreirano: 25-08-2020
   Screen.ActiveControl.Value = Null
   F_TrebaPrimenitiUslove vbRed, MyForm, DugmePrimeniUslove
End Function
Public Function F_TrebaPrimenitiUslove(Optional lColor, Optional MyForm As Form, Optional DugmePrimeniUslove As control) As Boolean
On Error GoTo Err_Point

Dim retVal As Boolean

    If MyForm Is Nothing Then
        Set MyForm = Screen.ActiveForm
    End If
    
    If DugmePrimeniUslove Is Nothing Then
       Set DugmePrimeniUslove = MyForm.Controls("DugmePrimeniUslove")
    End If
    If Not IsMissing(lColor) Then
        DugmePrimeniUslove.ForeColor = lColor
    End If
    
    retVal = (DugmePrimeniUslove.ForeColor = vbRed)
      
Exit_Point:
    On Error Resume Next
  
    F_TrebaPrimenitiUslove = retVal
Exit Function

Err_Point:
  'BBErrorMSG err, "F_TrebaPrimenitiUslove"
  retVal = True
  Resume Exit_Point
End Function

Public Function F_IDMagacinTRPR(Optional IDFirma) As Variant
On Error GoTo Err_Point
Dim retVal As Variant
Dim pIDFirma As Long

If IsMissing(IDFirma) Or IsNull(IDFirma) Then
   pIDFirma = F_IDFirma()
Else
   pIDFirma = CLng(IDFirma)
End If

    retVal = ADO_Lookup(CNN_CurrentDataBase, "[IDMagacin]", "Magacini", "([VrstaMag] like 'TRPR%') AND ([IDFirma]=" & stR(pIDFirma) & ")")

Exit_Point:
 On Error Resume Next
       F_IDMagacinTRPR = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "F_IDMagacinTRPR"
 retVal = Null
 Resume Exit_Point
End Function
Public Function fsPostojiTriger(stImeTrigera) As Boolean
'Kreirano: 17-08-2020
On Error GoTo Err_Point
Dim retVal As Variant
    'retVal = GetValFromUDFS("fsPostojiTriger", stImeTrigera)
    retVal = ADO_GetValFromUDFS(CNN_CurrentDataBase, "fsPostojiTriger", stImeTrigera)
    
Exit_Point:
 On Error Resume Next
 fsPostojiTriger = CBool(Nz(retVal, False))
Exit Function

Err_Point:
 BBErrorMSG err, "fsPostojiTriger(" & stImeTrigera & ")"
 Resume Exit_Point
End Function
Public Function F_SQLAccess_Login_ID() As Long
'Kreirano: 27-10-2023
On Error Resume Next
    F_SQLAccess_Login_ID = BBCFG.SQLAccess_Login_ID
End Function

Public Function F_MaxDanaZaPeriodNaloga() As Long
'Kreirano: 03-04-2024
    F_MaxDanaZaPeriodNaloga = BBCFG.MaxDanaZaPeriodNaloga
End Function

Public Function F_PrebaciKomitenteIzEXTBaze() As Boolean
'Kreirano: 19-06-2024
    F_PrebaciKomitenteIzEXTBaze = BBCFG.PrebaciKomitenteIzEXTBaze
End Function
Public Function F_PrebaciPredmeteIzEXTBaze() As Boolean
'Kreirano: 19-06-2024
    F_PrebaciPredmeteIzEXTBaze = BBCFG.PrebaciPredmeteIzEXTBaze
End Function
Public Function F_StartRibbonName() As String
'Kreirano: 19-12-2024
On Error Resume Next
    F_StartRibbonName = BBCFG.StartRibbonName
End Function

