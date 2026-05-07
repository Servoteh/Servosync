Attribute VB_Name = "BBTehn_Module"
Option Compare Database
Option Explicit

Public BBTehn As New BBTehn_Class
Public IzabraniRadnik As Long
Public IzabraniPostupak As Long
Public Function F_BBTehn_IDPostupka() As Long
   F_BBTehn_IDPostupka = Nz(BBTehn.IDPostupka(), -1)
End Function
Public Function F_BBTehn_IDPredmet() As Long
   F_BBTehn_IDPredmet = Nz(BBTehn.IDPredmet(), -1)
End Function
Public Function F_BBTehn_IDRadnik() As Long
    F_BBTehn_IDRadnik = Nz(BBTehn.IDRadnik(), -1)
End Function

Public Function F_VremeTrajanja_BarKodStatus() As Long
    F_VremeTrajanja_BarKodStatus = 5
End Function
Public Function F_BBTehn_IdentBroj() As String
   F_BBTehn_IdentBroj = Nz(BBTehn.IdentBroj(), -1)
End Function
Public Function F_BBTehn_Varijanta() As Long
   F_BBTehn_Varijanta = Nz(BBTehn.Varijanta(), -1)
End Function
Public Function F_BBTehn_Operacija() As Long
   F_BBTehn_Operacija = Nz(BBTehn.Operacija(), -1)
End Function
Public Function SpremiPodatkeZaOtvaranjeFormeBarKod_Unos(ByVal pSifraRadnika As Long, ByVal bZavrsiNalogDrugogRadnika As Boolean, ByVal bDozvoliMultitasking As Boolean) As Boolean ' stFormName As String, stControlName As String,
On Error GoTo Err_Point
    
    Dim retValOk As Boolean
    Dim pNoviRadnikSifra As Long
    Dim pNoviIDPostupka As Long
    Dim retVal As Integer
    Dim pitanje As String
    Dim stSQL As String
    Dim BrojZapocetihPostupakaRadnika As Integer
    Dim stDocName As String
    Dim RadnikuJeDozvoljenMultiTasking As Boolean
    
    retValOk = True
    stDocName = "ReklamniPanel_Login"
    RadnikuJeDozvoljenMultiTasking = Nz(ADO_Lookup(CNN_CurrentDataBase, "MultiNalog", "tRadnici", "SifraRadnika=" & pSifraRadnika), False)
    
    Set BBTehn = Nothing
    BBTehn.IDRadnik = pSifraRadnika
    BBTehn.IDLogovanogRadnika = pSifraRadnika
    BBTehn.ZavrsiNalogDrugogRadnika = bZavrsiNalogDrugogRadnika
    BBTehn.DozvoliMultitasking = bDozvoliMultitasking
    
    '1- POCETAK PRVOG USLOVA ////////// - Form!ReklamniPanel_Login!ZavrsiNalogDrugogRadnika=True
    If bZavrsiNalogDrugogRadnika Then
        If DaLiPostojeDodatnaOvlascenjaZaRadnika(pSifraRadnika) Then
            retVal = BrojStavkiOtvorenihPostupakaZaRadnikeSaDodatnimOvlascenjima(pSifraRadnika)
            If retVal > 0 Then
                pNoviRadnikSifra = Nz(IzaberiRadnika, -1)
                pNoviIDPostupka = Nz(IzabraniPostupak, -1)
                If pNoviRadnikSifra = -1 Then
                    MsgBox "Proces je prekinut", vbInformation, "QBigTehn"
                    retValOk = False
                    Forms(stDocName)!ZavrsiNalogDrugogRadnika = False
                    Forms(stDocName).ZavrsiNalogDrugogRadnikaAfterUpdate
                Else
                    BBTehn.IDRadnik = pNoviRadnikSifra
                    BBTehn.IDPostupka = pNoviIDPostupka
                End If
            Else
                MsgBox "Ne postoji " & Srpski("zapoceti") & " postupak drugog kontrolora koga treba zatvoriti!", vbInformation, "QBigTehn"
                retValOk = False
                Forms(stDocName)!ZavrsiNalogDrugogRadnika = False
                Forms(stDocName).ZavrsiNalogDrugogRadnikaAfterUpdate
            End If
        Else
            MsgBox "Nemate " & Srpski("ovlascenja") & " da zatvorite tehnološki postupak drugog radnika!", vbInformation, "QBigTehn"
            retValOk = False
            Forms(stDocName)!ZavrsiNalogDrugogRadnika = False
            Forms(stDocName).ZavrsiNalogDrugogRadnikaAfterUpdate
        End If
    '1- KRAJ PRVOG USLOVA ////////// - Form!ReklamniPanel_Login!ZavrsiNalogDrugogRadnika=True

    '2- POCETAK DRUGOG USLOVA ////////// - Form!ReklamniPanel_Login!OtvoriNoviNalogBezuslovno=True
    ElseIf bDozvoliMultitasking Then
        If Not RadnikuJeDozvoljenMultiTasking Then
            retValOk = False
            MsgBox "Nemate prava da otvarate novi tehnološki postupak" & vbCrLf & "ako NISTE ZATVORILI zapoèeti tehnološki postupak!"
            BBTehn.IDPostupka = -1
            Forms(stDocName)!OtvoriNoviNalogBezuslovno = False
            Forms(stDocName).OtvoriNoviNalogBezuslovnoAfterUpdate
        End If
    '2- KRAJ DRUGOG USLOVA ////////// - Form!ReklamniPanel_Login!OtvoriNoviNalogBezuslovno=True
    
    '3- POCETAK - BEZ USLOVA ////////// -    'Form!ReklamniPanel_Login!ZavrsiNalogDrugogRadnika=False AND Form!ReklamniPanel_Login!OtvoriNoviNalogBezuslovno=False
    Else
        ' AKO NE POSTOJE USLOVI TREBA RAZRADITI
        retValOk = retValOk And DefinisiIDPostupkaZaRadnika(BBTehn)
    End If
    '3- KRAJ - BEZ USLOVA ////////// -    'Form!ReklamniPanel_Login!ZavrsiNalogDrugogRadnika=False AND Form!ReklamniPanel_Login!OtvoriNoviNalogBezuslovno=False

Exit_Point:
On Error Resume Next

    SpremiPodatkeZaOtvaranjeFormeBarKod_Unos = retValOk
    
Exit Function

Err_Point:
    BBErrorMSG err, "SpremiPodatkeZaOtvaranjeFormeBarKod_Unos"
    retValOk = False
    Resume Exit_Point
End Function

Public Function OtvoriFormuBarKod_Unos() As Boolean 'ByRef bTehn As BBTehn_Class
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stTextZaRacun As Variant
retValOk = True
    
    If IsLoaded("Barkod_Unos") Then
        MsgBox "Morate zatvoriti prethodni prozor za unos.", vbExclamation, "QBigTehn"
        retValOk = False
        Exit Function
    End If
    
    DoCmd.Hourglass True
    DoCmd.Close acForm, "ReklamniPanel_Login"
    DoCmd.OpenForm "Barkod_Unos"
 
    If Not IsLoaded("Barkod_Unos") Then
        MsgBox "Ne može da se otvori forma [Barkod_Unos]", vbExclamation, "QBigTeh"
        retValOk = False
        Exit Function
    End If
    
    Forms!Barkod_Unos.PrimeniUslove

Exit_Point:
On Error Resume Next

    DoCmd.Hourglass False
    OtvoriFormuBarKod_Unos = retValOk
    
Exit Function

Err_Point:
    BBErrorMSG err, "OtvoriFormuBarKod_Unos"
    retValOk = False
    Resume Exit_Point
End Function


Public Function OtvoriFormuZaLogovanje() As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stTextZaRacun As Variant
retValOk = True

    If IsLoaded("ReklamniPanel_Login") Then
        'MsgBox "Morate zatvoriti prethodni prozor za unos.", vbExclamation, "QBigTehn"
        DoCmd.Close "ReklamniPanel_Login"
        
        DoCmd.Hourglass True
        DoCmd.OpenForm "ReklamniPanel_Login"
    End If
    
    If Not IsLoaded("ReklamniPanel_Login") Then
        MsgBox "Ne može da se otvori forma za logovanje", vbExclamation, "QBigTeh"
        retValOk = False
        Exit Function
     End If
    
    
Exit_Point:
On Error Resume Next

    DoCmd.Hourglass False
    OtvoriFormuZaLogovanje = retValOk
    
Exit Function

Err_Point:
    BBErrorMSG err, "OtvoriFormuZaLogovanje"
    retValOk = False
    Resume Exit_Point
End Function
Public Function F_BBTehn_ImePrezimeRadnika() As String
    F_BBTehn_ImePrezimeRadnika = Nz(ADO_Lookup(CNN_CurrentDataBase, "ImeIPrezime", "tRadnici", "SifraRadnika=" & F_BBTehn_IDRadnik()), "--------------")
End Function
Public Function F_BBTehn_ZavrsiNalogDrugogRadnika() As Boolean
    F_BBTehn_ZavrsiNalogDrugogRadnika = Nz(BBTehn.ZavrsiNalogDrugogRadnika, False)
End Function
Public Function F_BBTehn_DozvoliMultitasking() As Boolean
    F_BBTehn_DozvoliMultitasking = Nz(BBTehn.DozvoliMultitasking, False)
End Function
Public Function PostupakZaRadnikaJeUToku(ByRef bTehn As BBTehn_Class, ByRef BrojStavki As Integer) As Boolean
On Error GoTo Err_Point
    Dim stSQL As String
    Dim retValOk As Boolean
    Dim IDPostupka As Long
    
    retValOk = True
    stSQL = ""
    stSQL = stSQL & " SELECT COUNT(*) AS BrojStavki FROM tTehPostupak AS tp"
    stSQL = stSQL & " WHERE (tp.SifraRadnika = " & bTehn.IDRadnik & ")"
    stSQL = stSQL & "       AND (tp.ZavrsenPostupak = " & SQLFormatBoolean(False) & ")"
    BrojStavki = Nz(ADO_Lookup(CNN_CurrentDataBase, "BrojStavki", stSQL), 0)
    If BrojStavki = 0 Then
        bTehn.IDPostupka = -1
        retValOk = False
    ElseIf Nz(ADO_Lookup(CNN_CurrentDataBase, "BrojStavki", stSQL), 0) = 1 Then
        stSQL = ""
        stSQL = stSQL & " SELECT tp.IDPostupka FROM tTehPostupak as tp "
        stSQL = stSQL & " WHERE     (tp.SifraRadnika = " & bTehn.IDRadnik & ")"
        stSQL = stSQL & "       AND (tp.ZavrsenPostupak = " & SQLFormatBoolean(False) & ")"
        
        IDPostupka = Nz(ADO_Lookup(CNN_CurrentDataBase, "IDPostupka", stSQL), 0)
        bTehn.IDPostupka = IDPostupka
    End If
    
Exit_Point:
 On Error Resume Next
 PostupakZaRadnikaJeUToku = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "PostupakZaRadnikaJeUToku"
    retValOk = False
    Resume Exit_Point
End Function


Public Function DaLiPostojeNezavrseniNalozi() As Boolean
On Error GoTo Err_Point
    Dim stSQL As String
    Dim retValOk As Boolean
    Dim Sifra As Long
    
    retValOk = True
    
    stSQL = stSQL & " SELECT Count(*) as BrojStavki" 'tTehPostupak.SifraRadnika"
    stSQL = stSQL & " FROM tVrsteRadnika INNER JOIN (tRadnici INNER JOIN tTehPostupak ON tRadnici.SifraRadnika = tTehPostupak.SifraRadnika) ON tVrsteRadnika.IDVrsteRadnika = tRadnici.IDVrsteRadnika"
    stSQL = stSQL & " Where (((tTehPostupak.ZavrsenPostupak) = " & SQLFormatBoolean(False) & " ) And ((tVrsteRadnika.DodatnaOvlasenja) =  " & SQLFormatBoolean(True) & " ))"
    stSQL = stSQL & " GROUP BY tTehPostupak.SifraRadnika"

    SetClipboard stSQL
    
    Sifra = Nz(ADO_Lookup(CNN_CurrentDataBase, "BrojStavki", stSQL), 0)
    
    If Sifra = 0 Then
        MsgBox "Ne postoji " & Srpski("zapoèeti") & " postupak drugog radnika koga treba zatvoriti!", vbInformation, "QBigTehn"
        retValOk = False
    End If
    
Exit_Point:
 On Error Resume Next
 DaLiPostojeNezavrseniNalozi = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "DaLiPostojeNezavrseniNalozi"
    retValOk = False
    Resume Exit_Point

End Function
Public Function F_BBTehn_ImePrezimeLogovanogRadnika() As String
    F_BBTehn_ImePrezimeLogovanogRadnika = Nz(ADO_Lookup(CNN_CurrentDataBase, "ImeIPrezime", "tRadnici", "SifraRadnika=" & F_BBTehn_IDLogovanogRadnika()), "--------------")
End Function
Public Function F_BBTehn_IDLogovanogRadnika() As Long
    F_BBTehn_IDLogovanogRadnika = Nz(BBTehn.IDLogovanogRadnika(), -1)
End Function

Public Function OtvoriFormuZaUnosKolicineNapravljenihDelova(ByRef bTehn As BBTehn_Class, ByRef pDorada As Boolean, ByRef pSkart As Boolean, ByRef pDoradaOperacije As Long) As Long
On Error GoTo Err_OtvoriFormuZaUnosKolicineNapravljenihDelova
    Dim retValOk As Boolean
    Dim stDocName As String
    Dim stLinkCriteria As String
    Dim ind As Boolean
    Dim answer As Variant
    
    stDocName = "KeyboardSaPostupkom"
    ind = True
    While ind
        'OpenKeyboardNumeric
        retValOk = OtvoriKeyboardNumericSaOpisom(stDocName)
        'Definiši podatje potrebne za klasu
        bTehn.IDPredmet = Forms(stDocName)!IDPredmet
        bTehn.IdentBroj = Forms(stDocName)!IdentBroj
        bTehn.Varijanta = Forms(stDocName)!Varijanta
        bTehn.Operacija = Forms(stDocName)!Operacija
        bTehn.RJgrupaRC = Forms(stDocName)!RJgrupaRC
       
        'While IsLoaded("KeyboardNumeric")
        While IsLoaded(stDocName)
            DoEvents
        Wend
       
        ind = False
       
    Wend
    OtvoriFormuZaUnosKolicineNapravljenihDelova = KeyboardReturn
    pDorada = KeyboardDorada
    pSkart = KeyboardSkart
    pDoradaOperacije = KeyboardOperacija
    
Exit_OtvoriFormuZaUnosKolicineNapravljenihDelova:
    Exit Function

Err_OtvoriFormuZaUnosKolicineNapravljenihDelova:
    MsgBox err.Description
    Resume Exit_OtvoriFormuZaUnosKolicineNapravljenihDelova
End Function
Public Function OznaciDaJeZavrsenPostupak(ByVal IDPostupka As Long, ByVal Komada As Long, ByVal nIDPredmet As Long, ByVal stIdentBroj As String, ByVal nVarijanta As Long, _
                                ByVal nSifraRadnika As Long, ByVal nOperacija As Long, ByVal stRJgrupaRC As String, ByVal bBezPostupka As Boolean, _
                                Optional pDorada As Boolean = False, Optional pSkart As Boolean = False, Optional pDoradaOperacije As Long = 0) As Boolean
On Error GoTo Err_Point
    Dim stSQL As String
    Dim retValOk As Boolean
    Dim DaLiJeUnetBrojKomadaDobar As Boolean
    Dim PotrebnoKomada As Long
    Dim ZaIDRN As Long
    Dim KreiraniIDRN As Long
    Dim Napomena As String
    ' Modifikovano: 11-05-2025
    ' dodata promenljiva KoristiPrioritet a promenljivoj ZaIDRN odmah dodeljujem vrednost
    ' jer mi treba da update kolone prioritet u tabeli tStavkeRN
    Dim KoristiPrioritet As Boolean
    KoristiPrioritet = Nz(ADO_Lookup(CNN_CurrentDataBase, "KoristiPrioritet", "tOperacije", "RJgrupaRC ='" & stRJgrupaRC & "'"), False)
    ZaIDRN = Nz(ADO_Lookup(CNN_CurrentDataBase, "IDRN", "tTehPostupak", "[IDPostupka] = " & IDPostupka), 0)
    
    retValOk = True
    stSQL = ""
    stSQL = stSQL & " SELECT COUNT(*) AS BrojStavki FROM tTehPostupak AS tp"
    stSQL = stSQL & " WHERE (tp.IDPostupka = " & IDPostupka & ")"
   
    If Nz(ADO_Lookup(CNN_CurrentDataBase, "BrojStavki", stSQL), 0) = 0 Then
        retValOk = False
        GoTo Exit_Point
    End If
    
    DaLiJeUnetBrojKomadaDobar = ProveriKolicine(nIDPredmet, stIdentBroj, nVarijanta, nOperacija, Komada)
    If DaLiJeUnetBrojKomadaDobar Then
            
        Call ADO_UpdateColumn(CNN_CurrentDataBase, "tTehPostupak", "Komada", Komada, "IDPostupka=" & stR(IDPostupka)) ' rst("Komada") = Komada
        Call ADO_UpdateColumn(CNN_CurrentDataBase, "tTehPostupak", "DatumIVremeZavrsetka", SQLFormatDatumIVreme(Now()), "IDPostupka=" & stR(IDPostupka)) 'rst("DatumIVremeZavrsetka") = Now()
        Call ADO_UpdateColumn(CNN_CurrentDataBase, "tTehPostupak", "ZavrsenPostupak", 1, "IDPostupka=" & stR(IDPostupka)) 'rst("ZavrsenPostupak") = True
        ' Modifikovano: 11-05-2025
        ' Radim update kolone prioritet
        Call ADO_UpdateColumn(CNN_CurrentDataBase, "tStavkeRN", "Prioritet", 255, "IDRN = " & stR(ZaIDRN) & " AND [Operacija] = " & stR(nOperacija))
        If pDorada Or pSkart Then
            Call ADO_UpdateColumn(CNN_CurrentDataBase, "tTehPostupak", "IDVrstaKvaliteta", IIf(pDorada, 1, 2), "IDPostupka=" & stR(IDPostupka)) 'rst("ZavrsenPostupak") = True
        End If
        
        PotrebnoKomada = PotrebneKolicineZaRN(nIDPredmet, stIdentBroj, nVarijanta)
        
        PrikaziFormuZaBarKodStatus nOperacija, bBezPostupka, Komada, PotrebnoKomada
        While IsLoaded("BarKod_Status")
            DoEvents
        Wend
        
        retValOk = True
        '*** Razrada DORADE ILI SKARTA
        If pDorada Or pSkart Then
            '*** Dodajem sve nezyvrsene operacije do kraja sa kolicinom koliko je bilo delova za doradu ili u skartu
            retValOk = DefinisiOperacijeIBrojKomadaDoradeIliSkarta(IDPostupka, Komada, nIDPredmet, stIdentBroj, nVarijanta, nSifraRadnika, nOperacija, stRJgrupaRC, bBezPostupka, pDorada, pSkart, pDoradaOperacije)
            
            '*** Kreiram novi nalog DORADE ILI SKARTA sa kolicinom koliko je bilo delova za doradu ili u skartu
            Napomena = Nz(ADO_Lookup(CNN_CurrentDataBase, "Napomena", "tTehPostupak", "[IDPostupka] = " & IDPostupka), "")
            Napomena = Left(Napomena, Len(Napomena))
            ' 11-05-2025 PREBACIO SAM GORE OVAJ RED ISPOD, TREBA MI ZA UPDATE PRIORITET-a
            'ZaIDRN = Nz(ADO_Lookup(CNN_CurrentDataBase, "IDRN", "tTehPostupak", "[IDPostupka] = " & IDPostupka), 0)
            KreiraniIDRN = KreirajNalogDoradeIliSkarta(ZaIDRN, Komada, IIf(pDorada, 1, 2), Napomena)
            
            '*** Kreiram novu poruku da obavestim tehnologe da stampaju novi nalog DORADE ILI SKARTA sa kolicinom koliko je bilo delova za doradu ili u skartu
            If KreiraniIDRN <> -1 Then
                retValOk = KreirajPorukuZbogDoradeIliSkarta(Nz(ADO_Lookup(CNN_CurrentDataBase, "IdentBroj", "tRN", "[IDRN] = " & KreiraniIDRN), ""), _
                            Komada, nSifraRadnika, pDorada, pSkart, "TEHNOLOG")
            End If
        End If
    Else
        BBMsgBox "GREŠKA!!!", "PROVERITE BROJ KOMADA", "Definisali ste broj napravljenih komada koji prelazi potreban broj!!!", 5, vbYes, 16, 14, 125
        ZaIDPostupkaDeletettTehPostupak IDPostupka
        retValOk = False
    End If
   
    'If retValOk Then
    '        DoCmd.Close acForm, "BarKod_Unos"
    '        DoCmd.OpenForm "ReklamniPanel_Login"
    '    Else
    '        BBMsgBox "GREŠKA!!!", "PROVERITE BROJ KOMADA", "Definisali ste broj napravljenih komada koji prelazi potreban broj!!!", 5, vbYes, 16, 14, 125
    '        'DoCmd.Close
    '        DoCmd.Close acForm, "BarKod_Unos"
    '        DoCmd.OpenForm "ReklamniPanel_Login"
    '    End If
        
Exit_Point:
 On Error Resume Next
    OznaciDaJeZavrsenPostupak = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "OznaciDaJeZavrsenPostupak"
    retValOk = False
    Resume Exit_Point

End Function

Public Function ProveriKolicine(ByVal nIDPredmet As Long, ByVal stIdentBroj As String, ByVal nVarijanta As Long, ByVal nOperacija As Long, _
                                ByVal nTrenutnoKomada As Long, Optional ByRef bStatusZavrsen As Boolean = False) As Boolean
On Error GoTo Err_Point
    
    Dim stSQL As String
    Dim NapravljenoKomada As Long
    Dim PotrebnoNapravitiKomada As Long
    Dim retValOk As Boolean
                
    stSQL = ""
    stSQL = stSQL & " SELECT Sum(tTehPostupak.Komada) AS UkupnoNapravljeno"
    stSQL = stSQL & " FROM tTehPostupak"
    stSQL = stSQL & " WHERE (((tTehPostupak.ZavrsenPostupak)=" & SQLFormatBoolean(True) & ") AND ((tTehPostupak.IDPredmet)=" & nIDPredmet & ") AND ((tTehPostupak.IdentBroj)='" & stIdentBroj & "') AND ((tTehPostupak.Varijanta)=" & nVarijanta & ") AND ((tTehPostupak.Operacija)=" & nOperacija & "))"
    
    
    NapravljenoKomada = Nz(ADO_Lookup(CNN_CurrentDataBase, "UkupnoNapravljeno", stSQL), 0) 'Nz(rstPotrebanBroj!UkupnoNapravljeno)
    
    PotrebnoNapravitiKomada = PotrebneKolicineZaRN(nIDPredmet, stIdentBroj, nVarijanta) 'Nz(ADO_Lookup(CNN_CurrentDataBase, "PotrebnoKomada", stSQL), 0) 'Nz(rstPotrebanBroj!PotrebnoKomada, 0)
    
    If NapravljenoKomada = PotrebnoNapravitiKomada Then
        bStatusZavrsen = True
    End If
    
    If NapravljenoKomada + nTrenutnoKomada <= PotrebnoNapravitiKomada Then
        retValOk = True
    Else
        retValOk = False
    End If
    
    ProveriKolicine = retValOk
    
Exit_Point:
    Exit Function

Err_Point:
    MsgBox err.Description
    retValOk = False
    Resume Exit_Point
End Function
Private Sub DugmeNovaSerija()
On Error GoTo Err_DugmeNovaSerija_Click


    DoCmd.GoToRecord , , acNewRec
    DoCmd.GoToControl "ProcitajBarKod"

Exit_DugmeNovaSerija_Click:
    Exit Sub

Err_DugmeNovaSerija_Click:
    MsgBox err.Description
    Resume Exit_DugmeNovaSerija_Click
    
End Sub
Public Function DesifrujBarKod_TEST(BarKod As String, IDPredmet As Long, IdentBroj As String, Varijanta As Variant, Operacija As Integer) As Boolean
Dim retVal As Boolean
Dim pozdvt As Integer
Dim Separator As String
Dim Unos As Integer
    
    Unos = BrojSeparatoraUBarKodu(BarKod, ":")
    Select Case Unos
    Case 0
        
    Case 3
    Case 4
    End Select
    DesifrujBarKod_TEST = retVal
            
End Function

Public Function FTestF() As Boolean
Dim bc As String
Dim polje As String
Dim Vred As Integer
Dim ID As Long
  bc = "2340:001/1:0:7.3:TO-KALJ"
  
    DesifrujBarKod_TEST bc, ID, bc, polje, Vred
    Debug.Print "PredmetID = " & ID
    Debug.Print "IdentBroj = " & bc
    Debug.Print "Varijanta = " & polje
    FTestF = True
End Function
Public Function BrojSeparatoraUBarKodu(ByVal BarKod As String, ByVal stringSeparator As String) As Integer
    Dim pom As String
    Dim DuzPom, i, Pos As Integer
    Dim ind As Boolean
    
    pom = BarKod
    DuzPom = Len(pom)
    i = 0
    ind = True
    While DuzPom <> 0 And ind
        Pos = InStr(1, pom, stringSeparator, vbTextCompare)
        If Pos <> 0 Then
            i = i + 1
        Else
            ind = False
        End If
        pom = Mid(pom, Pos + 1)
        DuzPom = Len(pom)
    Wend
    BrojSeparatoraUBarKodu = i
End Function
Public Function MoguciDupliUnos_NeTREBA(stBarKod As String) As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim BrSt As Integer
    Dim IDVrsteRadnika As Long
    Dim ovlascenNaDupliUnos As Boolean
       
    If InStr(1, Nz(stBarKod, ""), ":", vbTextCompare) = 0 Then
        'IDRadnik = Nz(DLookup("SifraRadnika", "tRadnici", "IDKartice='" & stBarKod & "'"), 0)
        BBTehn.IDRadnik = Nz(DLookup("SifraRadnika", "tRadnici", "IDKartice='" & stBarKod & "'"), 0)
        IDVrsteRadnika = Nz(DLookup("IDVrsteRadnika", "tRadnici", "SifraRadnika=" & BBTehn.IDRadnik), 0)
    End If
       
    ovlascenNaDupliUnos = Nz(DLookup("MultiNalog", "tRadnici", "SifraRadnika=" & F_BBTehn_IDRadnik()), False)
    
    retValOk = ovlascenNaDupliUnos And PostupakZaRadnikaJeUToku(BBTehn, BrSt)
    
Exit_Point:
 On Error Resume Next
 MoguciDupliUnos_NeTREBA = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "MoguciDupliUnos_NeTREBA"
    retValOk = False
    Resume Exit_Point

End Function


Public Function IzaberiRadnika() As Long
On Error GoTo Err_Point

        DoCmd.OpenForm "IzborRadnikaZaDaljiRadZag", acNormal, , , , acDialog
        'DoCmd.OpenForm "IzborRadnikaZaDaljiRad", acNormal, , , , acDialog
        While IsLoaded("IzborRadnikaZaDaljiRadZag")
            DoEvents
        Wend
        
        '' Prvo zatvorite trenutnu formu
        'DoCmd.Close acForm, "NazivTrenutneForme"

        '' Zatim otvorite ciljanu formu
        'DoCmd.OpenForm "NazivZeljeneForme", acNormal
        
        IzaberiRadnika = IzabraniRadnik
        
        ' Na kraju postavite fokus na ciljanu formu
        Forms("ReklamniPanel_Login").SetFocus
       
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
    BBErrorMSG err, "IzaberiRadnika"
    Resume Exit_Point
End Function
Public Function PrikaziFormuZaIspravkuUnosa(Optional pIDTehPostupka As Long = -1) As Boolean
On Error GoTo Err_Point

    Dim stDocName As String
    Dim stLinkCriteria As String
    Dim IDTehPostupka As Long
    Dim retValOk As Boolean
    
    retValOk = True
    
    stDocName = "BarKod_Ispravka"
    If pIDTehPostupka = -1 Then
        IDTehPostupka = F_BBTehn_IDPostupka()
    Else
        IDTehPostupka = pIDTehPostupka
    End If
    
    If IDTehPostupka <> -1 Then
        stLinkCriteria = "[IDPostupka]=" & IDTehPostupka
        DoCmd.OpenForm stDocName, , , stLinkCriteria
    Else
        MsgBox "Nema unosa postupka po ovom nalogu!!!"
        retValOk = False
    End If
    
Exit_Point:

    PrikaziFormuZaIspravkuUnosa = retValOk
    Exit Function

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
End Function

Public Function IzaberiPostupak() As Long
On Error GoTo Err_Point

    DoCmd.OpenForm "IzborPostupakaZaDaljiRadZag", acNormal, , , , acDialog
    While IsLoaded("IzborPostupakaZaDaljiRadZag")
         DoEvents
    Wend
    
    IzaberiPostupak = IzabraniPostupak
    Forms("ReklamniPanel_Login").SetFocus
    
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
    BBErrorMSG err, "IzaberiRadnika"
    Resume Exit_Point
End Function

Public Sub Sacekaj(n As Long)
    Dim StartTime As Variant
    StartTime = Timer
    n = (n * 1000) / 500
    While Timer < StartTime + n
    Wend
End Sub
Public Function DaLiPostojiOtvoreniPostupakZaRadnika(pSifraRadnika As Long) As Boolean
On Error GoTo Err_Point
    Dim stSQL As String
    Dim retValOk As Boolean
    
    retValOk = True
    stSQL = ""
    stSQL = stSQL & " SELECT COUNT(*) AS BrojStavki FROM tTehPostupak AS tp"
    stSQL = stSQL & " WHERE (tp.SifraRadnika = " & pSifraRadnika & ")"
    stSQL = stSQL & "       AND (tp.ZavrsenPostupak = " & SQLFormatBoolean(False) & ")"
    If Nz(ADO_Lookup(CNN_CurrentDataBase, "BrojStavki", stSQL), 0) = 0 Then
        retValOk = False
    End If
    
Exit_Point:
 On Error Resume Next
 DaLiPostojiOtvoreniPostupakZaRadnika = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "DaLiPostojiOtvoreniPostupakZaRadnika"
    retValOk = False
    Resume Exit_Point
End Function
Public Function DefinisiIDPostupkaZaRadnika(ByRef bTehn As BBTehn_Class) As Boolean
On Error GoTo Err_Point
    Dim stSQL_BrSt As String
    Dim stSQL As String
    Dim retValOk As Boolean
    Dim IDPostupka As Long
    Dim BrojStavki As Integer
    
    retValOk = True
    stSQL_BrSt = ""
    stSQL_BrSt = stSQL_BrSt & " SELECT COUNT(*) AS BrojStavki FROM tTehPostupak AS tp"
    stSQL_BrSt = stSQL_BrSt & " WHERE (tp.SifraRadnika = " & bTehn.IDRadnik & ")"
    stSQL_BrSt = stSQL_BrSt & "       AND (tp.ZavrsenPostupak = " & SQLFormatBoolean(False) & ")"
    stSQL_BrSt = stSQL_BrSt & "       AND (tp.IDVrstaKvaliteta = " & 0 & ")"
    
    BrojStavki = Nz(ADO_Lookup(CNN_CurrentDataBase, "BrojStavki", stSQL_BrSt), 0)
    
    stSQL = ""
    stSQL = stSQL & " SELECT tp.IDPostupka FROM tTehPostupak as tp "
    stSQL = stSQL & " WHERE     (tp.SifraRadnika = " & bTehn.IDRadnik & ")"
    stSQL = stSQL & "       AND (tp.ZavrsenPostupak = " & SQLFormatBoolean(False) & ")"
    stSQL = stSQL & "       AND (tp.IDVrstaKvaliteta = " & 0 & ")"
    
    If BrojStavki = 0 Then
        bTehn.IDPostupka = -1
    ElseIf BrojStavki = 1 Then
        IDPostupka = Nz(ADO_Lookup(CNN_CurrentDataBase, "IDPostupka", stSQL), 0)
        bTehn.IDPostupka = IDPostupka
    Else
        IDPostupka = Nz(IzaberiPostupak, -1)
        If IDPostupka = -1 Then
            retValOk = False
        End If
        bTehn.IDPostupka = IDPostupka
    End If
   
Exit_Point:
 On Error Resume Next
 DefinisiIDPostupkaZaRadnika = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "DefinisiIDPostupkaZaRadnika"
    retValOk = False
    Resume Exit_Point
End Function
Public Function BrojStavkiOtvorenihPostupakaZaRadnikeSaDodatnimOvlascenjima(ByVal pSifraRadnika As Long) As Integer
On Error GoTo Err_Point
    Dim stSQL As String
    Dim retValOk As Boolean
    Dim BrojStavki As Integer
    
    retValOk = True
    stSQL = ""
    stSQL = stSQL & " SELECT Count (*) AS BrojStavki"
    stSQL = stSQL & " FROM tRN  INNER JOIN"
    stSQL = stSQL & " tVrsteRadnika INNER JOIN"
    stSQL = stSQL & " tRadnici INNER JOIN"
    stSQL = stSQL & " tTehPostupak ON tRadnici.SifraRadnika = tTehPostupak.SifraRadnika ON tVrsteRadnika.IDVrsteRadnika = tRadnici.IDVrsteRadnika ON tRN.IdentBroj = tTehPostupak.IdentBroj"
    stSQL = stSQL & " Where (tTehPostupak.ZavrsenPostupak = " & SQLFormatBoolean(False) & ")"
    stSQL = stSQL & " AND (tVrsteRadnika.DodatnaOvlascenja = " & SQLFormatBoolean(True) & ")"
    stSQL = stSQL & " AND (tTehPostupak.[SifraRadnika] <> " & pSifraRadnika & ")"
         
    BrojStavki = Nz(ADO_Lookup(CNN_CurrentDataBase, "BrojStavki", stSQL), 0)
    
Exit_Point:
 On Error Resume Next
 BrojStavkiOtvorenihPostupakaZaRadnikeSaDodatnimOvlascenjima = BrojStavki
Exit Function

Err_Point:
    BBErrorMSG err, "BrojStavkiOtvorenihPostupakaZaRadnikeSaDodatnimOvlascenjima"
    retValOk = False
    BrojStavki = 0
    Resume Exit_Point
End Function
Public Function DesifrujBarKodIzBarKod_Unosa(ByRef bTehn As BBTehn_Class, ByVal pSifraRadnika As Long, ByVal sProcitaniBarKod As String) As Boolean
On Error GoTo Err_Point
    Dim BrojDvotacke As Integer
    Dim BarKod As String
    Dim retValOk As Boolean
    Dim NoviUnos As Boolean
    Dim MozeOperacija As Boolean
    
    


Exit_Point:
    On Error Resume Next
Exit Function

Err_Point:
    BBErrorMSG err, "NastaviUnosomPoStarom"
    Resume Exit_Point

End Function
Public Function BrojOperacijaZaRadnikaUProcitanomRN(nIDPredmet As Long, stIdentBroj As String, nVarijanta As Long, nSifraRadnika As Long) As Integer
On Error GoTo Err_Point
   Dim stSQL As String
    Dim retValOk As Boolean
    Dim BrojOperacija As Integer
    
    retValOk = True
    stSQL = ""
    stSQL = stSQL & " SELECT OpURN.IDRN, Count(OpURN.IDStavkeRN) AS BrojOperacija"
    stSQL = stSQL & " FROM (SELECT tRN.IDRN, tStavkeRN.IDStavkeRN"
    stSQL = stSQL & "       FROM  tPristupMasini INNER JOIN"
    stSQL = stSQL & "       (tRN INNER JOIN tStavkeRN ON tRN.IDRN = tStavkeRN.IDRN) ON tPristupMasini.RJgrupaRC = tStavkeRN.RJgrupaRC"
    stSQL = stSQL & "       WHERE       (tRN.IDPredmet=" & nIDPredmet & ")"
    stSQL = stSQL & "       AND (tRN.IdentBroj='" & stIdentBroj & "')"
    stSQL = stSQL & "       AND (tRN.Varijanta=" & nVarijanta & ")"
    stSQL = stSQL & "       GROUP BY    tRN.IDRN, tStavkeRN.IDStavkeRN, tPristupMasini.SifraRadnika"
    stSQL = stSQL & "       HAVING (tPristupMasini.SifraRadnika=" & nSifraRadnika & ")) as OpURN"
    stSQL = stSQL & " GROUP BY OpURN.IDRN"
    
    BrojOperacija = Nz(ADO_Lookup(CNN_CurrentDataBase, "BrojOperacija", stSQL), 0)
    
Exit_Point:
 On Error Resume Next
 BrojOperacijaZaRadnikaUProcitanomRN = BrojOperacija
Exit Function

Err_Point:
    BBErrorMSG err, "BrojOperacijaZaRadnikaUProcitanomRN"
    BrojOperacija = -1
    Resume Exit_Point
End Function
Public Function ProcitajOperacijuZaRadnikaUProcitanomRN(ByVal nIDPredmet As Long, ByVal stIdentBroj As String, ByVal nVarijanta As Long, _
                                ByVal nSifraRadnika As Long, ByRef pOperacija As Long, ByRef stRJgrupaRC As String) As Boolean
On Error GoTo Err_Point
   Dim stSQL As String
    Dim retValOk As Boolean
    Dim Operacija As String
    
    retValOk = True
    stSQL = ""
    stSQL = stSQL & " SELECT tStavkeRN.Operacija, tStavkeRN.RJgrupaRC"
    stSQL = stSQL & " FROM tRN INNER JOIN"
    stSQL = stSQL & " (tPristupMasini INNER JOIN tStavkeRN ON tPristupMasini.RJgrupaRC = tStavkeRN.RJgrupaRC) ON tRN.IDRN = tStavkeRN.IDRN"
    stSQL = stSQL & " WHERE (tRN.IDPredmet=" & nIDPredmet & ")"
    stSQL = stSQL & " AND (tRN.IdentBroj='" & stIdentBroj & "')"
    stSQL = stSQL & " AND (tRN.Varijanta=" & nVarijanta & ")"
    stSQL = stSQL & " AND (tPristupMasini.SifraRadnika=" & nSifraRadnika & ")"
    stSQL = stSQL & " GROUP BY tStavkeRN.Operacija, tStavkeRN.RJgrupaRC"
    
    pOperacija = Nz(ADO_Lookup(CNN_CurrentDataBase, "Operacija", stSQL), 0)
    stRJgrupaRC = Nz(ADO_Lookup(CNN_CurrentDataBase, "RJgrupaRC", stSQL), "")
    
Exit_Point:
 On Error Resume Next
 ProcitajOperacijuZaRadnikaUProcitanomRN = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "ProcitajOperacijuZaRadnikaUProcitanomRN"
    retValOk = False
    Resume Exit_Point
End Function
Public Function PotrebneKolicineZaRN(ByVal pIDPredmet As Long, ByVal stIdentBroj As String, ByVal pVarijanta As Long) As Long
On Error GoTo Err_Point
    
    Dim stSQL As String
    Dim PotrebnoNapravitiKomada As Long
    Dim retValOk As Boolean
    
    stSQL = ""
    stSQL = stSQL & " SELECT tRN.Komada AS PotrebnoKomada"
    stSQL = stSQL & " FROM tRN"
    stSQL = stSQL & " WHERE (tRN.IDPredmet=" & pIDPredmet & ")"
    stSQL = stSQL & " AND (tRN.IdentBroj ='" & stIdentBroj & "')"
    stSQL = stSQL & " AND (tRN.Varijanta = " & pVarijanta & ")"

    PotrebnoNapravitiKomada = Nz(ADO_Lookup(CNN_CurrentDataBase, "PotrebnoKomada", stSQL), 0)
       
Exit_Point:
    On Error Resume Next
    PotrebneKolicineZaRN = PotrebnoNapravitiKomada
Exit Function

Err_Point:
    BBErrorMSG err, "PotrebneKolicineZaRN"
    PotrebnoNapravitiKomada = 0
    Resume Exit_Point
End Function

Public Function ZaIDRNDeletetPDM(ByVal ZaIDRN As Long) As Boolean
On Error GoTo Err_DugmeDeleteStavke_Click
    Dim stSQL As String
    Dim retValOk As Boolean
    
    retValOk = True
    
    stSQL = "DELETE FROM [tPDM] WHERE ([tPDM].IDRN = " & CStr(ZaIDRN) & ");"
    DoCmd.SetWarnings False
    Call ADO_ExecSQL(CNN_CurrentDataBase, stSQL, , 60)
     
Exit_DugmeDeleteStavke_Click:
     DoCmd.SetWarnings True
     ZaIDRNDeletetPDM = retValOk
    Exit Function

Err_DugmeDeleteStavke_Click:
    MsgBox err.Description
    retValOk = False
    Resume Exit_DugmeDeleteStavke_Click
    
End Function
Public Function ZaIDRNDeletetPLP(ByVal ZaIDRN As Long) As Boolean
On Error GoTo Err_DugmeDeleteStavke_Click
    Dim stSQL As String
    Dim retValOk As Boolean
    
    retValOk = True
    
    stSQL = "DELETE FROM [tPLP] WHERE ([tPLP].IDRN = " & CStr(ZaIDRN) & ");"
    DoCmd.SetWarnings False
    Call ADO_ExecSQL(CNN_CurrentDataBase, stSQL, , 60)
     
Exit_DugmeDeleteStavke_Click:
     DoCmd.SetWarnings True
     ZaIDRNDeletetPLP = retValOk
    Exit Function

Err_DugmeDeleteStavke_Click:
    MsgBox err.Description
    retValOk = False
    Resume Exit_DugmeDeleteStavke_Click
    
End Function

Public Function ZaIDRNDeletetPND(ByVal ZaIDRN As Long) As Boolean 'tStavkeRN
On Error GoTo Err_DugmeDeleteStavke_Click
    Dim stSQL As String
    Dim retValOk As Boolean
    
    retValOk = True

    stSQL = "DELETE FROM [tPND] WHERE ([tPND].IDRN = " & CStr(ZaIDRN) & ");"
    DoCmd.SetWarnings False
    Call ADO_ExecSQL(CNN_CurrentDataBase, stSQL, , 60)
     
Exit_DugmeDeleteStavke_Click:
     DoCmd.SetWarnings True
     ZaIDRNDeletetPND = retValOk
    Exit Function

Err_DugmeDeleteStavke_Click:
    MsgBox err.Description
    retValOk = False
    Resume Exit_DugmeDeleteStavke_Click
    
End Function

Public Function ZaIDRNDeletetStavkeRN(ByVal ZaIDRN As Long) As Boolean
On Error GoTo Err_DugmeDeleteStavke_Click
    Dim stSQL As String
    Dim retValOk As Boolean
    
    retValOk = True

    stSQL = "DELETE FROM [tStavkeRN] WHERE ([tStavkeRN].IDRN = " & CStr(ZaIDRN) & ");"
    DoCmd.SetWarnings False
    Call ADO_ExecSQL(CNN_CurrentDataBase, stSQL, , 60)
     
Exit_DugmeDeleteStavke_Click:
     DoCmd.SetWarnings True
     ZaIDRNDeletetStavkeRN = retValOk
    Exit Function

Err_DugmeDeleteStavke_Click:
    MsgBox err.Description
    retValOk = False
    Resume Exit_DugmeDeleteStavke_Click
    
End Function
Public Function ZaIDRNDeletetRN(ByVal ZaIDRN As Long) As Boolean
On Error GoTo Err_DugmeDeleteStavke_Click
    Dim stSQL As String
    Dim retValOk As Boolean
    
    retValOk = True

    stSQL = "DELETE FROM [tRN] WHERE ([tRN].IDRN = " & CStr(ZaIDRN) & ");"
    DoCmd.SetWarnings False
    Call ADO_ExecSQL(CNN_CurrentDataBase, stSQL, , 60)
     
Exit_DugmeDeleteStavke_Click:
     DoCmd.SetWarnings True
     ZaIDRNDeletetRN = retValOk
    Exit Function

Err_DugmeDeleteStavke_Click:
    MsgBox err.Description
    retValOk = False
    Resume Exit_DugmeDeleteStavke_Click
    
End Function

Public Function PrikaziFormuZaBarKodStatus(ByVal Operacija As Long, ByVal BezPostupka As Boolean, ByVal BrojZavrsenihKomada As Long, ByVal PotrebnoKomada As Long) As Boolean
    On Error GoTo Err_Point

    Dim stDocName As String
    Dim stLinkCriteria As String
    Dim retValOk As Boolean
    
    retValOk = True
    
    stDocName = "BarKod_Status"
    DoCmd.OpenForm stDocName, , , stLinkCriteria
    
    If UserUGrupi(CurrentUser(), "Admins") Then
        Forms!BarKod_Status!DugmeTest.Visible = True
    Else
        Forms!BarKod_Status!DugmeTest.Visible = False
    End If
    
    If Nz(BrojZavrsenihKomada, 0) = 0 Then
        If Nz(BezPostupka, False) = False Then
            Forms!BarKod_Status!lblZag.Value = Srpski("ZAPOCELI") & " STE:"
        Else
            Forms!BarKod_Status!lblZag.Value = Srpski("ZAPOCELI") & " STE I ZAVRŠILI:"
        End If
    Else
        Forms!BarKod_Status!lblZag.Value = "ZAVRŠILI STE:"
    End If
    If PotrebnoKomada > 999 Then Forms!BarKod_Status!txtPotrebnoKomada.FontSize = 14
    
Exit_Point:

    PrikaziFormuZaBarKodStatus = retValOk
    Exit Function

Err_Point:
    MsgBox err.Description
    retValOk = False
    Resume Exit_Point
    
End Function
Public Function ZaIDPostupkaDeletettTehPostupak(ByVal ZaIDPostupka As Long) As Boolean
On Error GoTo Err_DugmeDeleteStavke_Click
    Dim stSQL As String
    Dim retValOk As Boolean
    
    retValOk = True
    
    stSQL = "DELETE FROM [tTehPostupak] WHERE ((([tTehPostupak].IDPostupka)=" & CStr(ZaIDPostupka) & "));"
    DoCmd.SetWarnings False
    Call ADO_ExecSQL(CNN_CurrentDataBase, stSQL, , 60)
     
Exit_DugmeDeleteStavke_Click:
     DoCmd.SetWarnings True
     ZaIDPostupkaDeletettTehPostupak = retValOk
    Exit Function

Err_DugmeDeleteStavke_Click:
    MsgBox err.Description
    retValOk = False
    Resume Exit_DugmeDeleteStavke_Click
    
End Function

Public Function ProcitajIDRNIUpisiUtTehPostupak(nIDPostupka As Long, nIDPredmet As Integer, stIdentBroj As String, nVarijanta As Integer) As Long
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim stSQL As String
    Dim IDRN As Long
    Dim stSQLWhere As String
    
    retValOk = True
    stSQL = ""
   
    stSQLWhere = ""
    stSQLWhere = stSQLWhere & "([IDPredmet]=" & stR(nIDPredmet) & ")"
    stSQLWhere = stSQLWhere & " AND ([IdentBroj]='" & stIdentBroj & "')"
    stSQLWhere = stSQLWhere & " AND ([Varijanta]=" & stR(nVarijanta) & ")"
    
    IDRN = Nz(ADO_Lookup(CNN_CurrentDataBase, "IDRN", "tRN", stSQLWhere), 0)
    
    'If IDRN <> 0 Then
    stSQLWhere = ""
    stSQLWhere = stSQLWhere & "([IDPostupka]=" & stR(nIDPostupka) & ")"
    Call ADO_UpdateColumn(CNN_CurrentDataBase, "tTehPostupak", "IDRN", IDRN, stSQLWhere)
    'End If
    
Exit_Point:
 On Error Resume Next
 ProcitajIDRNIUpisiUtTehPostupak = IDRN
Exit Function

Err_Point:
    BBErrorMSG err, "ProcitajIDRNIUpisiUtTehPostupak"
    retValOk = False
    Resume Exit_Point
End Function
Public Function OtvoriFormuZaLokacijuDelova(ByVal IDPredmet As Long, ByVal BrojZavrsenihDelova As Integer, ByVal Dorada As Boolean, ByVal Skart As Boolean, _
                                           ByVal SifraRadnika As Long, ByVal pIDRN As Long, Optional podFormName As String, Optional ProveraUnosaKolicina As Boolean = False) As Boolean
On Error GoTo Err_Point

Dim IDVrstaKvaliteta As Long
Dim stLinkCriteria As String
Dim retValOk As Boolean
Dim IdentBroj As String
Dim BrojCrteza As String
'Dim BBNazivPredmeta As String
Dim NazivDela As String
Dim SifraKomitenta As Long
Dim NazivKomitenta As String
Dim Radnik As String

    retValOk = True

    If IsLoaded("LokacijaNapravljenihDelovaZag") Then
        MsgBox "Morate zatvoriti prethodni dijalog za lokaciju delova.", vbExclamation, "QBigTehn"
        retValOk = False
        Exit Function
    End If
        
    If Dorada Then
        IDVrstaKvaliteta = 1
    ElseIf Skart Then
        IDVrstaKvaliteta = 2
    Else
        IDVrstaKvaliteta = 0
    End If
        
    IdentBroj = Nz(ADO_Lookup(CNN_CurrentDataBase, "IdentBroj", "tRN", "[IDRN] = " & pIDRN), "")
    BrojCrteza = Nz(ADO_Lookup(CNN_CurrentDataBase, "BrojCrteza", "tRN", "[IDRN] = " & pIDRN), "")
    NazivDela = Nz(ADO_Lookup(CNN_CurrentDataBase, "NazivDela", "tRN", "[IDRN] = " & pIDRN), "")
    SifraKomitenta = Nz(ADO_Lookup(CNN_CurrentDataBase, "BBIDKomitent", "tRN", "[IDRN] = " & pIDRN), 0)
    NazivKomitenta = Nz(ADO_Lookup(CNN_CurrentDataBase, "Naziv", "Komitenti", "[Sifra] = " & SifraKomitenta), "")
    Radnik = Nz(ADO_Lookup(CNN_CurrentDataBase, "ImeIPrezime", "tRadnici", "[SifraRadnika] = " & SifraRadnika), "")
    
    DoCmd.OpenForm "LokacijaNapravljenihDelovaZag", acNormal
    
    If Not IsLoaded("LokacijaNapravljenihDelovaZag") Then
        MsgBox "Ne može da se otvori forma [LokacijaNapravljenihDelovaZag]", vbExclamation, "QBigTehn"
        retValOk = False
        Exit Function
    Else
    
        [Forms]![LokacijaNapravljenihDelovaZag]![IDRN] = pIDRN
        [Forms]![LokacijaNapravljenihDelovaZag]![IDPredmet] = IDPredmet
        [Forms]![LokacijaNapravljenihDelovaZag]![IDPredmet].Requery
        [Forms]![LokacijaNapravljenihDelovaZag]![KolicinaIskontrolisanihDelova] = BrojZavrsenihDelova
        [Forms]![LokacijaNapravljenihDelovaZag]![IDVrstaKvaliteta] = IDVrstaKvaliteta
        [Forms]![LokacijaNapravljenihDelovaZag]![ProveraUnosaKolicina] = ProveraUnosaKolicina
        [Forms]![LokacijaNapravljenihDelovaZag]![BrojCrteza] = BrojCrteza
        [Forms]![LokacijaNapravljenihDelovaZag]![IdentBroj] = IdentBroj
        '[Forms]![LokacijaNapravljenihDelovaZag]![BBNazivPredmeta] = BBNazivPredmeta
        [Forms]![LokacijaNapravljenihDelovaZag]![NazivDela] = NazivDela
        [Forms]![LokacijaNapravljenihDelovaZag]![NazivKomitenta] = NazivKomitenta
        [Forms]![LokacijaNapravljenihDelovaZag]![SifraRadnika] = SifraRadnika
        [Forms]![LokacijaNapravljenihDelovaZag]![Radnik] = Radnik
        If ProveraUnosaKolicina = False Then
            [Forms]![LokacijaNapravljenihDelovaZag]![IDRN].Visible = False
            [Forms]![LokacijaNapravljenihDelovaZag]![Label_IDRN].Visible = False
            [Forms]![LokacijaNapravljenihDelovaZag]![IDVrstaKvaliteta].Enabled = True
            [Forms]![LokacijaNapravljenihDelovaZag]![IDVrstaKvaliteta] = Null
            '[Forms]![LokacijaNapravljenihDelovaZag]![IdentBroj].Left = [Forms]![LokacijaNapravljenihDelovaZag]![IDRN].Left
            '[Forms]![LokacijaNapravljenihDelovaZag]![IdentBroj].Width = [Forms]![LokacijaNapravljenihDelovaZag]![IdentBroj].Width + [Forms]![LokacijaNapravljenihDelovaZag]![IDRN].Width + 10
            '[Forms]![LokacijaNapravljenihDelovaZag]![Label_IdentBroj].Left = [Forms]![LokacijaNapravljenihDelovaZag]![IdentBroj].Left
            '[Forms]![LokacijaNapravljenihDelovaZag]![Label_IdentBroj].Width = [Forms]![LokacijaNapravljenihDelovaZag]![IdentBroj].Width
            
            '**** MODIFIKOVANO 16-10-2024 **********
            [Forms]![LokacijaNapravljenihDelovaZag]![IdentBroj].Enabled = True
            '[Forms]![LokacijaNapravljenihDelovaZag]![IdentBroj] = Null
            [Forms]![LokacijaNapravljenihDelovaZag]![IdentBroj].Requery
            ' *****************************
            [Forms]![LokacijaNapravljenihDelovaZag].Caption = "Pregled lokacije iskontrolisanih delova"
            [Forms]![LokacijaNapravljenihDelovaZag]![DugmePripremiPrenos].Enabled = True
            [Forms]![LokacijaNapravljenihDelovaZag]![DugmePripremiTrebovanje].Enabled = True
            [Forms]![LokacijaNapravljenihDelovaZag]![DugmeKarticaDela].Enabled = True
            [Forms]![LokacijaNapravljenihDelovaZag]![DugmeLokacijeDelova].Enabled = True
        Else
            [Forms]![LokacijaNapravljenihDelovaZag].Caption = "Unos lokacije iskontrolisanih delova"
            [Forms]![LokacijaNapravljenihDelovaZag]![DugmePripremiPrenos].Enabled = False
            [Forms]![LokacijaNapravljenihDelovaZag]![DugmePripremiTrebovanje].Enabled = False
            [Forms]![LokacijaNapravljenihDelovaZag]![DugmeKarticaDela].Enabled = False
            [Forms]![LokacijaNapravljenihDelovaZag]![DugmeLokacijeDelova].Enabled = False
        End If
        'Forms![LokacijaNapravljenihDelovaZag].Requery
        'Forms![LokacijaNapravljenihDelovaZag]![Podforma].SourceObject = podFormName
       'Forms![LokacijaNapravljenihDelovaZag]![Podforma].Requery
    End If
    
    Forms![LokacijaNapravljenihDelovaZag].DefinisiPodformu
    'Call PronadjiSlogNaFormi(Forms("LokacijaNapravljenihDelovaZag"), "IDRN=" & pIDRN)
    
Exit_Point:
On Error Resume Next
    OtvoriFormuZaLokacijuDelova = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "OtvoriFormuZaLokacijuDelova"
 retValOk = False
 On Error GoTo Exit_Point
 
End Function

Public Function DefinisiOperacijeIBrojKomadaDoradeIliSkarta(ByVal IDPostupka As Long, ByVal Komada As Long, ByVal nIDPredmet As Long, ByVal stIdentBroj As String, ByVal nVarijanta As Long, _
                                ByVal nSifraRadnika As Long, ByVal nOperacija As Long, ByVal stRJgrupaRC As String, ByVal bBezPostupka As Boolean, _
                                Optional pDorada As Boolean = False, Optional pSkart As Boolean = False, Optional pDoradaOperacije As Long = 0) As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    retValOk = True
    
    Dim stSQL As String
    Dim rst As ADODB.Recordset
    Dim rstTehPostupak As DAO.Recordset
    
    'ftDodatiPostupkeZaDoraduIliSkart(
          '    @ZaIDPredmet int = Null
          '  , @ZaIdentBroj nvarchar(20)=Null
          '  , @ZaVarijanta int = Null
          '  , @ZaOperaciju int=Null
          '  , @Kontrolor int
          '  , @KomadaDoradeIliSkarta int
    stSQL = TextSelectQForUDFT("ftDodatiPostupkeZaDoraduIliSkart", nIDPredmet, stIdentBroj, nVarijanta, nOperacija)
    Set rst = ADO_GetRST(BBCFG.CNNString, stSQL)
    If rst.EOF And rst.BOF Then
     'ne postoje stavke u recordsetu
     retValOk = False
     GoTo Exit_Point
    End If
    
    Set rstTehPostupak = CurrentDb.OpenRecordset("tTehPostupak", DB_OPEN_DYNASET, dbSeeChanges)
    
    While Not rst.EOF
        rstTehPostupak.AddNew    ' Enable editing.
        rstTehPostupak![SifraRadnika] = nSifraRadnika
        rstTehPostupak![IDPredmet] = rst![IDPredmet]
        rstTehPostupak![IdentBroj] = rst![IdentBroj]
        rstTehPostupak![Varijanta] = rst![Varijanta]
        rstTehPostupak![PrnTimer] = rst![PrnTimer]
        rstTehPostupak![DatumIVremeUnosa] = rst![DatumIVremeUnosa]
        rstTehPostupak![Operacija] = rst![Operacija]
        rstTehPostupak![RJgrupaRC] = rst![RJgrupaRC]
        rstTehPostupak![Toznaka] = rst![Toznaka]
        rstTehPostupak![Komada] = Komada
        rstTehPostupak![Potpis] = CurrentUser
        rstTehPostupak![SimbolRadnik] = True
        rstTehPostupak![SimbolPostupak] = True
        rstTehPostupak![SimbolOperacija] = True
        rstTehPostupak![DatumIVremeZavrsetka] = rst![DatumIVremeUnosa]
        rstTehPostupak![ZavrsenPostupak] = True
        rstTehPostupak![Napomena] = IIf(pDorada, "DORADA", IIf(pSkart, Srpski("SKART"), ""))
        rstTehPostupak![IDRN] = rst![IDRN]
        rstTehPostupak![IDVrstaKvaliteta] = IIf(pDorada, 1, IIf(pSkart, 2, 0))
        rstTehPostupak![DoradaOperacije] = pDoradaOperacije
        
        rstTehPostupak.Update
        rst.MoveNext
    Wend
    
       
Exit_Point:
    On Error Resume Next
    rst.Close
    Set rst = Nothing
    
    rstTehPostupak.Close
    Set rstTehPostupak = Nothing
    
    DefinisiOperacijeIBrojKomadaDoradeIliSkarta = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "DefinisiOperacijeIBrojKomadaDoradeIliSkarta"
    retValOk = False
    Resume Exit_Point
End Function

Public Function NalogPostojiUTehPostupku(ByVal IDRN As Long) As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim stSQL As String
    
    
    stSQL = ""
    stSQL = stSQL & "SELECT ZavrsenPostupak" & vbCrLf
    stSQL = stSQL & " FROM  tTehPostupak" & vbCrLf
    stSQL = stSQL & " WHERE IDRN=" & IDRN & vbCrLf
    
    retValOk = Nz(ADO_Lookup(CNN_CurrentDataBase, "ZavrsenPostupak", stSQL), False)

Exit_Point:
 On Error Resume Next
       NalogPostojiUTehPostupku = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "NalogPostojiUTehPostupku"
 retValOk = False
 Resume Exit_Point

End Function

Public Function KreirajPorukuZbogDoradeIliSkarta(ByVal stIdentBroj As String, ByVal Komada As Integer, ByVal nSifraRadnika As Long, _
                                                    Optional pDorada As Boolean = False, Optional pSkart As Boolean = False, Optional stZaKoga As String = "") As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim Poruka As String
    Dim stSQL As String
    Dim stSQLWhere As String
    Dim chNavodnici As String
    Dim Radnik As String
    
        retValOk = True
        Radnik = Nz(ADO_Lookup(CNN_CurrentDataBase, "ImeIPrezime", "tRadnici", "[SifraRadnika] = " & nSifraRadnika), "")
        If BBCFG.SQLDB Then
            chNavodnici = Chr(39)
        Else
            chNavodnici = Chr(34)
        End If
    
        If pDorada Then
            Poruka = "Zbog DORADE"
        End If
        If pSkart Then
            Poruka = "Zbog " & Srpski("SKARTA")
        End If
        
        If stZaKoga = "" Then
            stZaKoga = "ZaSve"
        End If
        
        Poruka = Poruka & " kontrolor " & Radnik & " je kreirao-la novi nalog i njegov broj je '" & stIdentBroj & "'" & vbCrLf
        'Poruka = Poruka & "
        
        stSQL = ""
        stSQL = stSQL & "    INSERT INTO T_Planer" & vbCrLf
        stSQL = stSQL & "            (" & vbCrLf
        stSQL = stSQL & "              KadaDatum" & vbCrLf
        stSQL = stSQL & "            , KadaVreme" & vbCrLf
        stSQL = stSQL & "            , Subject" & vbCrLf
        stSQL = stSQL & "            , Poruka" & vbCrLf
        stSQL = stSQL & "            , OdKoga" & vbCrLf
        stSQL = stSQL & "            , ZaKoga" & vbCrLf
        stSQL = stSQL & "            )" & vbCrLf
        stSQL = stSQL & "   VALUES" & vbCrLf
        stSQL = stSQL & "            (" & vbCrLf
        stSQL = stSQL & "            " & SQLFormatDatuma(Date) & vbCrLf
        stSQL = stSQL & "            ," & SQLFormatVreme(Time) & vbCrLf
        stSQL = stSQL & "            ," & chNavodnici & Replace("Otvoren novi nalog", chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
        stSQL = stSQL & "            ," & chNavodnici & Replace(Poruka, chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
        stSQL = stSQL & "            ," & chNavodnici & Replace(CurrentUser(), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
        stSQL = stSQL & "            ," & chNavodnici & Replace(stZaKoga, chNavodnici, chNavodnici & chNavodnici) & chNavodnici
        stSQL = stSQL & "            )" & vbCrLf
        
        retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)
            
            'IDVPFR = ADO_IDENTITY
            
Exit_Point:
    On Error Resume Next
   
    KreirajPorukuZbogDoradeIliSkarta = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "KreirajPorukuZbogDoradeIliSkarta"
    retValOk = False
    Resume Exit_Point
End Function

Public Function PostojiUBaziNalogZaDefinisaniTehPostupak(ByVal nIDPredmet As Integer, ByVal stIdentBroj As String, ByVal nVarijanta As Integer) As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim stSQL As String
    Dim IDRN As Long
    Dim stSQLWhere As String
    
    retValOk = True
    stSQL = ""
   
    stSQLWhere = ""
    stSQLWhere = stSQLWhere & "([IDPredmet]=" & stR(nIDPredmet) & ")"
    stSQLWhere = stSQLWhere & " AND ([IdentBroj]='" & stIdentBroj & "')"
    stSQLWhere = stSQLWhere & " AND ([Varijanta]=" & stR(nVarijanta) & ")"
    
    IDRN = Nz(ADO_Lookup(CNN_CurrentDataBase, "IDRN", "tRN", stSQLWhere), 0)
    
    If IDRN <> 0 Then
        retValOk = True
    Else
        retValOk = False
    End If

Exit_Point:
 On Error Resume Next
 PostojiUBaziNalogZaDefinisaniTehPostupak = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "PostojiUBaziNalogZaDefinisaniTehPostupak"
    retValOk = False
    Resume Exit_Point
End Function

Public Function PotrebnaPromenaStatusaRNUZavrsen(ByVal nIDPredmet As Long, ByVal stIdentBroj As String, ByVal nVarijanta As Long, ByVal nOperacija As Long) As Boolean
On Error GoTo Err_Point
    
    Dim stSQL As String
    Dim NapravljenoKomada As Long
    Dim PotrebnoKomada As Long
    Dim retValOk As Boolean
                
    stSQL = ""
    stSQL = stSQL & " SELECT Sum(tTehPostupak.Komada) AS UkupnoNapravljeno"
    stSQL = stSQL & " FROM tTehPostupak"
    stSQL = stSQL & " WHERE (((tTehPostupak.ZavrsenPostupak)=" & SQLFormatBoolean(True) & ") AND ((tTehPostupak.IDPredmet)=" & nIDPredmet & ") AND ((tTehPostupak.IdentBroj)='" & stIdentBroj & "') AND ((tTehPostupak.Varijanta)=" & nVarijanta & ") AND ((tTehPostupak.Operacija)=" & nOperacija & "))"
    
    NapravljenoKomada = Nz(ADO_Lookup(CNN_CurrentDataBase, "UkupnoNapravljeno", stSQL), 0) 'Nz(rstPotrebanBroj!UkupnoNapravljeno)
        
    'PotrebnoKomada = PotrebneKolicineZaRN(nIDPredmet, stIdentBroj, nVarijanta) 'Nz(ADO_Lookup(CNN_CurrentDataBase, "PotrebnoKomada", stSQL), 0) 'Nz(rstPotrebanBroj!PotrebnoKomada, 0)
    
    stSQL = ""
    stSQL = stSQL & " SELECT tRN.Komada AS PotrebnoKomada"
    stSQL = stSQL & " FROM tRN"
    stSQL = stSQL & " WHERE (tRN.IDPredmet=" & nIDPredmet & ")"
    stSQL = stSQL & " AND (tRN.IdentBroj ='" & stIdentBroj & "')"
    stSQL = stSQL & " AND (tRN.Varijanta = " & nVarijanta & ")"
    
    PotrebnoKomada = Nz(ADO_Lookup(CNN_CurrentDataBase, "PotrebnoKomada", stSQL), 0)
    
    If NapravljenoKomada = PotrebnoKomada Then
        retValOk = True
    Else
        retValOk = False
    End If
    
Exit_Point:
    On Error Resume Next
    PotrebnaPromenaStatusaRNUZavrsen = retValOk
    Exit Function

Err_Point:
    MsgBox err.Description
    retValOk = False
    Resume Exit_Point
End Function

Public Function UkupnoNapravljenoKomadaZaOperacijuRN(ByVal nIDPredmet As Long, ByVal stIdentBroj As String, ByVal nVarijanta As Long, ByVal nOperacija As Long, Optional ByRef bStatusZavrsen As Boolean = False) As Boolean
On Error GoTo Err_Point
    
    Dim stSQL As String
    Dim NapravljenoKomada As Long
                    
    stSQL = ""
    stSQL = stSQL & " SELECT Sum(tTehPostupak.Komada) AS UkupnoNapravljeno"
    stSQL = stSQL & " FROM tTehPostupak"
    stSQL = stSQL & " WHERE (((tTehPostupak.ZavrsenPostupak)=" & SQLFormatBoolean(True) & ") AND ((tTehPostupak.IDPredmet)=" & nIDPredmet & ") AND ((tTehPostupak.IdentBroj)='" & stIdentBroj & "') AND ((tTehPostupak.Varijanta)=" & nVarijanta & ") AND ((tTehPostupak.Operacija)=" & nOperacija & "))"
    
    
    NapravljenoKomada = Nz(ADO_Lookup(CNN_CurrentDataBase, "UkupnoNapravljeno", stSQL), 0) 'Nz(rstPotrebanBroj!UkupnoNapravljeno)
    
    UkupnoNapravljenoKomadaZaOperacijuRN = NapravljenoKomada
    
Exit_Point:
    On Error Resume Next
    Exit Function

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
End Function

Public Function KarticaDela(Optional ByVal IDArtikal, Optional IDMagacin, Optional Profakture As Boolean = False, Optional ZaRezervacije = Null)
'Modifikovano: 02-09-2020 Uvedena nova forma VPKarticaDela i podforma VPKarticaDela_Podforma
On Error GoTo Err_KarticaDela

    Dim DocName As String
    Dim LinkCriteria As String
    Dim ZaIDArtikal
    
    If IsMissing(IDArtikal) Then
     On Error Resume Next
     ZaIDArtikal = Screen.ActiveForm.Recordset("Sifra artikla")
     If err Then
      ZaIDArtikal = Screen.ActiveForm.Recordset("IDArtikal")
     End If
     On Error GoTo Err_KarticaDela
    Else
     ZaIDArtikal = IDArtikal
    End If
    
    If IsNumeric(ZaIDArtikal) And Not IsEmpty(ZaIDArtikal) Then
        'DocName = "Kartica artikla"
        DocName = "VPKarticaDela"
        LinkCriteria = "[Sifra artikla] = " & ZaIDArtikal
        BBOpenForm DocName, , , LinkCriteria
        If Not IsMissing(IDMagacin) Then
         If IsLoaded(DocName) Then
          Forms(DocName)!ComboZaMagacin = IDMagacin
          
          If CBool(Nz(Profakture, False)) Then
          
             Forms(DocName)!OdLevel = 250
             Forms(DocName)!DoLevel = 250
             Forms(DocName)!CheckKarticaProf = True
             Forms(DocName)!CheckZaRezervisi = ZaRezervacije
          End If
          
          Forms(DocName).PrimeniUslove
         
         End If
        End If
    Else
     Beep
    End If
 
Exit_KarticaDela:
    Exit Function

Err_KarticaDela:
    BBErrorMSG err, "KarticaDela"
    Resume Exit_KarticaDela
    
End Function

Public Function PozicijeDelovaPoBrojuCrteza(Optional BrojCrtezaZaPrikaz) As Variant
'Modifikovano: 07-10-2019
'Modifikovano: 11-01-2021 uveden optional parametar BrojCrtezaZaPrikaz
On Error GoTo Err_Point

Dim pBrojCrtezaZaPrikaz
Dim pIDRNZaPrikaz
Dim pAktivnaKontrola As Object
Dim pAktivnaForma As Object
Dim PozicijeDelovaPoBrojuCrteza_FormName As String


PozicijeDelovaPoBrojuCrteza_FormName = "LokacijaNapravljenihDelovaZag"

    pBrojCrtezaZaPrikaz = Null
  On Error Resume Next
    
  If Not IsMissing(BrojCrtezaZaPrikaz) Then
     pBrojCrtezaZaPrikaz = CStr(BrojCrtezaZaPrikaz)
     
     Set pAktivnaKontrola = Screen.ActiveControl
     Set pAktivnaForma = Screen.ActiveControl.Parent
    
     GoTo PrikaziFormu:
  End If
  
    Set pAktivnaKontrola = Screen.ActiveControl
    Set pAktivnaForma = Screen.ActiveControl.Parent
    pBrojCrtezaZaPrikaz = Screen.ActiveControl.Value
    
    If err.Number = 0 Then
   ' err.Clear
   ' On Error GoTo err_Point
    
        If pAktivnaKontrola.ControlSource = "BrojCrteza" Or _
           pAktivnaKontrola.ControlSource = "Broj Crteza" Or _
           pAktivnaKontrola.ControlSource = "tRN.BrojCrteza" Then
           pBrojCrtezaZaPrikaz = Screen.ActiveControl.Value
        Else
           pIDRNZaPrikaz = Null
           pIDRNZaPrikaz = pAktivnaForma.Recordset("IDRN")
       End If
    Else
       pBrojCrtezaZaPrikaz = Null
    End If
    
PrikaziFormu:
err.Clear

 On Error GoTo Err_Point:
 
 
    If Not (pBrojCrtezaZaPrikaz = "" And Not IsEmpty(pBrojCrtezaZaPrikaz)) Then
       pBrojCrtezaZaPrikaz = ADO_Lookup(CNN_CurrentDataBase, "MIN([BrojCrteza])", "tRN")
    End If
        
    On Error Resume Next
        Forms!LokacijaNapravljenihDelovaZag!Podforma.RecordsObject = "ReklamniPanel2"
    On Error GoTo Err_Point:
    'OtvoriFormuZaLokacijuDelova 0, Me!Komada, False, False, IDRadnikZaCurrentUser(), "LokacijaSvihNapravljenihDelovaPoRN", Me!IDRN
 
Exit_Point:
On Error Resume Next
 Application.Forms(pAktivnaForma.Name).SetFocus 'Nisam bas siguran da je ovo dobro
                                                'u stvari jeste kad je poziv sa glavne forme
                                                'ne važi za poziv iz podforme
 'ovo ne radi
 'pAktivnaKontrola.Control.SetFocus
Exit Function

Err_Point:
 BBErrorMSG err, PozicijeDelovaPoBrojuCrteza_FormName
 On Error GoTo Exit_Point
 
End Function

