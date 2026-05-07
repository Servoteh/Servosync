VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BarKod_Unos"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Public Function PrimeniUslove() As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim BrojZavrsenihKomada As Integer
    Dim stDocName As String
    Dim BezPostupka As Boolean
    Dim Dorada As Boolean
    Dim Skart As Boolean
    Dim DoradaOperacije As Long
    
    stDocName = "BarKod_Unos"
    Dorada = False
    Skart = False
    DoradaOperacije = -1
    
    If BBTehn.IDPostupka = -1 Then
        Me!SifraRadnika = BBTehn.IDRadnik
        Me!SimbolRadnik = True
       ' Me!DatumIVremeUnosa = Now()
        Me!ProcitajBarKod = Null
        PostaviFokusNaBarKod
    Else
        Call PronadjiSlogNaFormi(Forms(stDocName), "IDPostupka=" & BBTehn.IDPostupka)
        
        BrojZavrsenihKomada = OtvoriFormuZaUnosKolicineNapravljenihDelova(BBTehn, Dorada, Skart, DoradaOperacije)
        
        BezPostupka = Nz(ADO_Lookup(CNN_CurrentDataBase, "BezPostupka", "tOperacije", "RJgrupaRC = '" & BBTehn.RJgrupaRC & "'"), False)
        retValOk = OznaciDaJeZavrsenPostupak(BBTehn.IDPostupka, BrojZavrsenihKomada, BBTehn.IDPredmet, BBTehn.IdentBroj, _
                                            BBTehn.Varijanta, BBTehn.IDRadnik, BBTehn.Operacija, BBTehn.RJgrupaRC, BezPostupka, Dorada, Skart, DoradaOperacije)
        DoCmd.Close acForm, "BarKod_Unos"
        DoCmd.OpenForm "ReklamniPanel_Login"
    End If
           
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "PrimeniUslove"
 Resume Exit_Point
End Function

Private Sub DugmeClipBoard_Click()
    Me!ProcitajBarKod = GetClipboard
    'ProcitajBarKod_AfterUpdate
End Sub

Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click


    DoCmd.Close

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
    
End Sub


Private Sub DugmeTest_Click()
On Error GoTo Err_Command180_Click

    MsgBox "IDPostupka: " & Nz(Me!IDPostupka, "<NULL>") & " -" & BBTehn.IDPostupka & vbCrLf & "IDRadnika: " & Nz(Me!SifraRadnika, "<NULL>") & " -" & BBTehn.IDRadnik & vbCrLf & "IDPredmeta: " & Nz(Me!IDPredmet, "<NULL>") & " -" & BBTehn.IDPredmet

Exit_Command180_Click:
    Exit Sub

Err_Command180_Click:
    MsgBox err.Description
    Resume Exit_Command180_Click
End Sub

Private Sub Form_Open(Cancel As Integer)

    If UserUGrupi(CurrentUser(), "Admins") Then
        Me!DugmeTest.Visible = True
        Me!DugmeClipBoard.Visible = True
    Else
        Me!DugmeTest.Visible = False
        Me!DugmeClipBoard.Visible = False
    End If
    
    DoCmd.Maximize
    DoCmd.GoToRecord , , acNewRec
    DoCmd.GoToControl "ProcitajBarKod"
    
    If F_BBTehn_ZavrsiNalogDrugogRadnika() Then
        Me!DugmeZavrsiNalogDrugogRadnika.Visible = True
        Me!Radnik.ForeColor = Me!DugmeZavrsiNalogDrugogRadnika.ForeColor
        Me!Radnik.FontBold = True
    Else
        Me!DugmeZavrsiNalogDrugogRadnika.Visible = False
    End If
End Sub
Private Function PostaviFokusNaBarKod()
    Dim WshShell As Object
    Set WshShell = CreateObject("WScript.Shell")

    DoCmd.GoToControl "ProcitajBarKod"
    WshShell.SendKeys "%B"
    'SendKeys "%B"
    
End Function

Private Sub ProcitajBarKod_AfterUpdate()
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim UnetiBarKod As String
    Dim IDRadnika As Long
    Dim RadnikJeDefinisan As Boolean
    Dim PostupakJeDefinisan As Boolean
    Dim OperacijaJeDefinisana As Boolean
    Dim Separator As String
    
    Dim chSrpskoSlovo1 As String
    Dim chSrpskoSlovo2 As String
    
    Dim IDPredmet As Long
    Dim IdentBroj As String
    Dim Varijanta As Long
    Dim PrnTimer As Long
    Dim SimbolPostupak As Boolean
    
    chSrpskoSlovo1 = Chr(200) ' "È"
    chSrpskoSlovo2 = Chr(232) ' "è"
    
    retValOk = True
    UnetiBarKod = Nz(Me!ProcitajBarKod, "")
    Separator = ":"
    
    Me![ProcitajBarKod] = Null
    IDRadnika = Nz(Me!SifraRadnika, -1)
    RadnikJeDefinisan = Nz(Me!SimbolRadnik, False)
    PostupakJeDefinisan = Nz(Me!SimbolPostupak, False)
    OperacijaJeDefinisana = Nz(Me!SimbolOperacija, False)
    
    If InStr(1, UnetiBarKod, chSrpskoSlovo1, vbTextCompare) Or InStr(1, UnetiBarKod, chSrpskoSlovo2, vbTextCompare) Then
        BBMsgBox "GREŠKA", "Na " & Srpski("racunaru") & " je definisana Srpska tastatura.", "Za rad sa BarKod " & Srpski("citacem") & " zahteva se Engleska tastatura", 10, vbYes, 14, 12
        PostaviFokusNaBarKod
        Exit Sub
    End If
       
    If (IDRadnika = -1) Or (BBTehn.IDRadnik = -1) Or (IDRadnika <> BBTehn.IDRadnik) Or (RadnikJeDefinisan = False) Then
        BBMsgBox "GREŠKA", "Ne POSTOJI DEFINISANI RADNIK koji unosi podatke!" & vbCrLf & "Verovatno ste " & Srpski("slucajno") & " pritisnuli taster Esc na tastaturi," & vbCrLf & _
                    "ili ste nekom drugom, meni nepoznatom radnjom, poništili vaše PREDSTAVLJANJE." & vbCrLf & "Morate opet da " & Srpski("procitate") & " broj vaše identifikacione kartice!", , 60, vbYes, 10
        DoCmd.Close acForm, "BarKod_Unos"
        DoCmd.OpenForm "ReklamniPanel_Login"
        Exit Sub
    End If
    
    If Not ((BrojSeparatoraUBarKodu(UnetiBarKod, Separator) = 4) And (Left(UnetiBarKod, 3) = "RNZ" Or Left(UnetiBarKod, 1) = "S")) Then
        BBMsgBox "GREŠKA", "Nepoznat unos!", , 3, vbYes, 22
        PostaviFokusNaBarKod
        Exit Sub
    End If
    
    If Not PostupakJeDefinisan Then
        If Left(UnetiBarKod, 1) = "S" Then
            BBMsgBox "LOŠ REDOSLED UNOSA BARKOD-a", "Niste definisali nalog!", "Operaciju morate uneti poslednju !", 3, vbYes, 22, 18
            PostaviFokusNaBarKod
            Exit Sub
        End If
        
        retValOk = SacuvajRNZIzUnosaBarKoda(BBTehn, UnetiBarKod)
        
    ElseIf Not OperacijaJeDefinisana Then
        If Left(UnetiBarKod, 3) = "RNZ" Then
            BBMsgBox "LOŠ UNOS BARKOD-a", "Nalog ste veæ definisali!", "Morate uneti operaciju!", 3, vbYes, 22, 18
            PostaviFokusNaBarKod
            Exit Sub
        End If
        
        retValOk = SacuvajRNSIzUnosaBarKoda(BBTehn, UnetiBarKod)
    Else
        
    End If
    
    
Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
    BBErrorMSG err, "ProcitajBarKod_AfterUpdate"
    retValOk = False
    Resume Exit_Point
End Sub

Public Function SacuvajRNZIzUnosaBarKoda(ByRef bTehn As BBTehn_Class, stBarKod As String) As Boolean
On Error Resume Next
    'Modifikovano: 20-06-2024
    Dim stBarKodPom As String
    Dim DuzstBarKodPom, i, Pos As Integer
    Dim ind As Boolean
    Dim retValOk As Boolean
    Dim Masina, RadNaMasini As Long
    Dim BrojOperacijaLogovanogRadnikaURN As Integer
    Dim Operacija As Long
    Dim RJgrupaRC As String
    
    Dim pIDPredmet As Long
    Dim stIdentBroj As String
    Dim pVarijanta As Long
    Dim pPrnTimer As Long
    Dim BezPostupka As Boolean
    Dim PotrebnoKomada As Integer
    Dim OperacijaJeZavrsna As Boolean
    Dim BrojZavrsenihKomada As Integer
    Dim ZatvoriBarKodUnos As Boolean
    
    ZatvoriBarKodUnos = False
    
    retValOk = True
    
    stBarKodPom = stBarKod
    DuzstBarKodPom = Len(stBarKodPom)
    i = 0
    ind = True
    
    While DuzstBarKodPom <> 0 And ind
        Pos = InStr(1, stBarKodPom, ":", vbTextCompare)
        Select Case i
        Case 0
        Case 1
            pIDPredmet = CLng(Left(stBarKodPom, Pos - 1))
        Case 2
            stIdentBroj = Left(stBarKodPom, Pos - 1)
        Case 3
            pVarijanta = CLng(Left(stBarKodPom, Pos - 1))
         Case 4
            pPrnTimer = CLng(stBarKodPom)
            ind = False
        End Select
        i = i + 1
        stBarKodPom = Mid(stBarKodPom, Pos + 1)
        DuzstBarKodPom = Len(stBarKodPom)
    Wend
    
    If Not PostojiUBaziNalogZaDefinisaniTehPostupak(pIDPredmet, stIdentBroj, pVarijanta) Then
        BBMsgBox "GREŠKA!!!", "Izabrali ste nalog koji ne postoji u BAZI!!!" & vbCrLf & "Proverite sa tehnologom da vam odštampa pravi nalog", , 5, 0, 18, , 255
        retValOk = False
        Call BBTSUndo
        'DoCmd.Close acForm, "BarKod_Unos"
        'DoCmd.OpenForm "ReklamniPanel_Login"
        ZatvoriBarKodUnos = True
        GoTo Exit_Point
    End If
    
    Me!IDPredmet = pIDPredmet
    Me!IdentBroj = stIdentBroj
    Me!Varijanta = pVarijanta
    Me!PrnTimer = pPrnTimer
    
    bTehn.IDPredmet = pIDPredmet
    bTehn.IdentBroj = stIdentBroj
    bTehn.Varijanta = pVarijanta
    
    BrojOperacijaLogovanogRadnikaURN = BrojOperacijaZaRadnikaUProcitanomRN(pIDPredmet, stIdentBroj, pVarijanta, bTehn.IDRadnik)
    Select Case BrojOperacijaLogovanogRadnikaURN
        Case -1
            BBMsgBox "GREŠKA!!!", "Došlo je do greške u " & Srpski("citanju") & " podataka!!!", , 5, 0, 18, , 255
            retValOk = False
            Call BBTSUndo
            'DoCmd.Close acForm, "BarKod_Unos"
            'DoCmd.OpenForm "ReklamniPanel_Login"
            ZatvoriBarKodUnos = True
            GoTo Exit_Point
        Case 0
            BBMsgBox "GREŠKA!!!", "Izabrali ste nalog u kojem nema OPERACIJA koju vi treba da radite!!!", , 5, 0, 18, , 255
            retValOk = False
            Call BBTSUndo
            'DoCmd.Close acForm, "BarKod_Unos"
            'DoCmd.OpenForm "ReklamniPanel_Login"
            ZatvoriBarKodUnos = True
            GoTo Exit_Point
        Case 1
            Me!SimbolPostupak = True
            retValOk = ProcitajOperacijuZaRadnikaUProcitanomRN(pIDPredmet, stIdentBroj, pVarijanta, bTehn.IDRadnik, Operacija, RJgrupaRC)
            Me![Operacija] = Operacija
            Me!RJgrupaRC = RJgrupaRC
            Me!Toznaka = "0"
            Me!Komada = 0
            Me!SimbolOperacija = True
           ' Me!DatumIVremeUnosa = Now()
            bTehn.Operacija = Operacija
            'Modifikovano: 04-07-2024
            BezPostupka = Nz(ADO_Lookup(CNN_CurrentDataBase, "BezPostupka", "tOperacije", "RJgrupaRC = '" & RJgrupaRC & "'"), False)
            OperacijaJeZavrsna = Nz(ADO_Lookup(CNN_CurrentDataBase, "ZnacajneOperacijeZaZavrsen", "tOperacije", "RJgrupaRC = '" & RJgrupaRC & "'"), False)
            '*** Sve ovo ispod menjam jednom funkcijom - 04-07-2024
            'If ProveriKolicine(pIDPredmet, stIdentBroj, pVarijanta, Operacija, 1) Then
            '
            '    Call BBTSSaveRecord
            '    bTehn.IDPostupka = Me!IDPostupka
            '    UpisiIDRNutTehPostupak bTehn.IDPostupka, bTehn.IDPredmet, bTehn.IdentBroj, bTehn.Varijanta
            '
            '    'Modifikovano: 04-07-2024
            '    'BezPostupka = Nz(ADO_Lookup(CNN_CurrentDataBase, "BezPostupka", "tOperacije", "RJgrupaRC = '" & RJgrupaRC & "'"), False)
            '    'bOperacijaJeZavrsna = Nz(ADO_Lookup(CNN_CurrentDataBase, "ZnacajneOperacijeZaZavrsen", "tOperacije", "RJgrupaRC = '" & RJgrupaRC & "'"), False)
            '
            '    If BezPostupka = True Then
            '        Call OznaciDaJeZavrsenPostupak(bTehn.IDPostupka, PotrebneKolicineZaRN(pIDPredmet, stIdentBroj, pVarijanta), _
            '                pIDPredmet, stIdentBroj, pVarijanta, bTehn.IDRadnik, Operacija, RJgrupaRC, BezPostupka) 'ZatvoriPostupak (bTehn.IDPostupka)
            '    ElseIf bOperacijaJeZavrsna = True Then
            '        'Otvaram formu [KeyboardSaPostupkom] za unos broja napravljenih komada
            '        BrojZavrsenihKomada = OtvoriFormuZaUnosKolicineNapravljenihDelova(bTehn, Dorada, Skart, DoradaOperacije)
            '
            '        retValOk = OznaciDaJeZavrsenPostupak(bTehn.IDPostupka, BrojZavrsenihKomada, bTehn.IDPredmet, bTehn.IdentBroj, bTehn.Varijanta, _
            '                                              bTehn.IDRadnik, bTehn.Operacija, bTehn.RJgrupaRC, BezPostupka, Dorada, Skart, DoradaOperacije)
            '        If retValOk And BrojZavrsenihKomada <> 0 Then
            '            'MsgBox "Ovde unosimo kvalitet"
            '            DefinisiKvalitetiIPozicijuDelova bTehn.IDPostupka, BrojZavrsenihKomada
            '            While IsLoaded("KvalitetIPozicijeDelovaZag")
            '                DoEvents
            '            Wend
            '        End If
            '
            '        'DoCmd.Close acForm, "BarKod_Unos"
            '        'DoCmd.OpenForm "ReklamniPanel_Login"
            '        ZatvoriBarKodUnos = True
            '        GoTo exit_Point
            '    Else
            '        PotrebnoKomada = PotrebneKolicineZaRN(pIDPredmet, stIdentBroj, pVarijanta)
            '        PrikaziFormuZaBarKodStatus Operacija, BezPostupka, 0, PotrebnoKomada
            '        While IsLoaded("BarKod_Status")
            '            DoEvents
            '        Wend
            '        'DoCmd.Close acForm, "BarKod_Unos"
            '        'DoCmd.OpenForm "ReklamniPanel_Login"
            '        ZatvoriBarKodUnos = True
            '        GoTo exit_Point
            '    End If
            'Else
            '    BBMsgBox "GREŠKA!!!", "PROVERITE BROJ KOMADA", "Radite operaciju po kojoj je napravljeno potreban broj komada!!!", 5, vbYes, 16, 14, 125
            '    'DugmePonistiUnos_Click
            '    Call BBTSUndo
            '    retValOk = False
            '    'DoCmd.Close acForm, "BarKod_Unos"
            '    'DoCmd.OpenForm "ReklamniPanel_Login"
            '    ZatvoriBarKodUnos = True
            '    GoTo exit_Point
            'End If
            
            retValOk = EvidentirajSveOstaleDetaljeTehPostupka(bTehn, ZatvoriBarKodUnos, BezPostupka, OperacijaJeZavrsna)
            
        Case Else
            Me!SimbolPostupak = True
            PostaviFokusNaBarKod
    End Select
    
Exit_Point:
    On Error Resume Next
    SacuvajRNZIzUnosaBarKoda = retValOk
    If ZatvoriBarKodUnos Then
        DoCmd.Close acForm, "BarKod_Unos"
        DoCmd.OpenForm "ReklamniPanel_Login"
    End If
Exit Function

Err_Point:
    BBErrorMSG err, "SacuvajRNZIzUnosaBarKoda"
    retValOk = False
    Resume Exit_Point
End Function

Public Function SacuvajRNSIzUnosaBarKoda(ByRef bTehn As BBTehn_Class, stBarKod As String) As Boolean
On Error Resume Next
    Dim retValOk As Boolean
    Dim PrnTimerIzBarKoda As String
    Dim stBarKodPom As String
    Dim DuzstBarKodPom, i, Pos As Integer
    Dim ind As Boolean
    Dim IDPristupaMasine As Long
    Dim BrojOperacija As Integer
    
    Dim pOperacija As Long
    Dim stRJgrupaRC As String
    Dim stToznaka As String
    Dim BezPostupka As Boolean
    Dim PotrebnoNapravitiKomada As Long
    Dim OperacijaJeZavrsna As Boolean
    Dim BrojZavrsenihKomada As Integer
    
    Dim ZatvoriBarKodUnos As Boolean
    
    ZatvoriBarKodUnos = False
    
   
    
    stBarKodPom = stBarKod
    DuzstBarKodPom = Len(stBarKodPom)
    i = 0
    ind = True
    
    While DuzstBarKodPom <> 0 And ind
        Pos = InStr(1, stBarKodPom, ":", vbTextCompare)
        Select Case i
        Case 0
        Case 1
            pOperacija = Left(stBarKodPom, Pos - 1)
        Case 2
            stRJgrupaRC = Left(stBarKodPom, Pos - 1)
        Case 3
            stToznaka = Left(stBarKodPom, Pos - 1)
         Case 4
            PrnTimerIzBarKoda = stBarKodPom
            ind = False
        End Select
        i = i + 1
        stBarKodPom = Mid(stBarKodPom, Pos + 1)
        DuzstBarKodPom = Len(stBarKodPom)
    Wend
    
    Me![Operacija] = pOperacija
    Me![RJgrupaRC] = stRJgrupaRC
    Me![Toznaka] = stToznaka
    
    bTehn.Operacija = pOperacija
    bTehn.RJgrupaRC = stRJgrupaRC
        
    IDPristupaMasine = Nz(ADO_Lookup(CNN_CurrentDataBase, "IDPristupMasini", "tPristupMasini", "RJgrupaRC='" & stRJgrupaRC & "'" & " And SifraRadnika=" & bTehn.IDRadnik), 0)
    BezPostupka = Nz(ADO_Lookup(CNN_CurrentDataBase, "BezPostupka", "tOperacije", "RJgrupaRC = '" & stRJgrupaRC & "'"), False)
    
    'Modifikovano: 20-06-2024
    '*** bOperacijaJeZavrsna je promenljiva kojom je definisano da li je to ZAVRSNA KOMTROLA
    OperacijaJeZavrsna = Nz(ADO_Lookup(CNN_CurrentDataBase, "ZnacajneOperacijeZaZavrsen", "tOperacije", "RJgrupaRC = '" & stRJgrupaRC & "'"), False)
                
    If PrnTimerIzBarKoda <> Me!PrnTimer Then
        BBMsgBox "GREŠKA!!!", "Izabrali ste operaciju koja ne pripada definisanom NALOGU!!!", , 5, 0, 18, , 255
    ElseIf IDPristupaMasine <> 0 Then
        Me!Komada = 0
        Me!SimbolOperacija = True
        'Me!DatumIVremeUnosa = Now()
        '*** Sve ovo ispod menjam jednom funkcijom - 04-07-2024
        'If ProveriKolicine(bTehn.IDPredmet, bTehn.IdentBroj, bTehn.Varijanta, pOperacija, 1) Then
        '    Call BBTSSaveRecord
        '    bTehn.IDPostupka = Me!IDPostupka
        '    '********** 24-06-2024
        '    UpisiIDRNutTehPostupak bTehn.IDPostupka, bTehn.IDPredmet, bTehn.IdentBroj, bTehn.Varijanta
        '    '*** Grana ispod je za tehnoloski postupak koji se odmah zatvara
        '    If BezPostupka = True Then
        '        Call OznaciDaJeZavrsenPostupak(bTehn.IDPostupka, PotrebneKolicineZaRN(bTehn.IDPredmet, bTehn.IdentBroj, bTehn.Varijanta), _
        '                bTehn.IDPredmet, bTehn.IdentBroj, bTehn.Varijanta, bTehn.IDRadnik, bTehn.Operacija, bTehn.RJgrupaRC, BezPostupka) 'ZatvoriPostupak (Me!IDPostupka)
        '    '*** Grana ispod je za ZAVRSNU KONTROLU
        '    ElseIf bOperacijaJeZavrsna = True Then
        '        BrojZavrsenihKomada = OtvoriFormuZaUnosKolicineNapravljenihDelova(bTehn, Dorada, Skart, DoradaOperacije)
        '
        '        retValOk = OznaciDaJeZavrsenPostupak(bTehn.IDPostupka, BrojZavrsenihKomada, bTehn.IDPredmet, bTehn.IdentBroj, bTehn.Varijanta, _
        '                                             bTehn.IDRadnik, bTehn.Operacija, bTehn.RJgrupaRC, BezPostupka, Dorada, Skart, DoradaOperacije)
        '
        '        If retValOk And BrojZavrsenihKomada <> 0 Then
        '            'MsgBox "Ovde unosimo kvalitet"
        '            DefinisiKvalitetiIPozicijuDelova bTehn.IDPostupka, BrojZavrsenihKomada
        '            While IsLoaded("KvalitetIPozicijeDelovaZag")
        '                DoEvents
        '            Wend
        '        End If
        '
        '        DoCmd.Close acForm, "BarKod_Unos"
        '        DoCmd.OpenForm "ReklamniPanel_Login"
        '    Else
        '        PotrebnoNapravitiKomada = PotrebneKolicineZaRN(bTehn.IDPredmet, bTehn.IdentBroj, bTehn.Varijanta)
        '        PrikaziFormuZaBarKodStatus pOperacija, BezPostupka, 0, PotrebnoNapravitiKomada
        '        While IsLoaded("BarKod_Status")
        '            DoEvents
        '        Wend
        '        DoCmd.Close acForm, "BarKod_Unos"
        '        DoCmd.OpenForm "ReklamniPanel_Login"
        '    End If
        '    '********** 24-06-2024
        'Else
        '    BBMsgBox "GREŠKA!!!", "PROVERITE BROJ KOMADA", "Radite operaciju po kojoj je napravljeno potreban broj komada!!!", 5, vbYes, 16, 14, 125
        '    'DugmePonistiUnos_Click
        '    Call BBTSUndo
        '    DoCmd.Close acForm, "BarKod_Unos"
        '    DoCmd.OpenForm "ReklamniPanel_Login"
        'End If
        retValOk = EvidentirajSveOstaleDetaljeTehPostupka(bTehn, ZatvoriBarKodUnos, BezPostupka, OperacijaJeZavrsna)
    Else
        Me!Operacija = ""
        Me!RJgrupaRC = ""
        Me!Toznaka = ""
        BBMsgBox "GREŠKA!!!", "Izabrali ste operaciju koja ne pripada vašim dodeljenim mašinama!!!", , 5, 0, 18, , 255
        PostaviFokusNaBarKod
    End If
      
Exit_Point:
    On Error Resume Next
    SacuvajRNSIzUnosaBarKoda = retValOk
    If ZatvoriBarKodUnos Then
        DoCmd.Close acForm, "BarKod_Unos"
        DoCmd.OpenForm "ReklamniPanel_Login"
    End If
Exit Function

Err_Point:
    BBErrorMSG err, "SacuvajRNSIzUnosaBarKoda"
    retValOk = False
    Resume Exit_Point
End Function

Public Function EvidentirajSveOstaleDetaljeTehPostupka(ByRef objTehn As BBTehn_Class, ByRef bZatvoriBarKodUnos As Boolean, _
                                                    ByVal bBezPostupka As Boolean, ByVal bOperacijaJeZavrsna As Boolean) As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim pOperacija As Long
    Dim pRJgrupaRC As String
    Dim BrojZavrsenihKomada As Long
    Dim PotrebnoKomada As Long
    Dim bDorada As Boolean
    Dim bSkart As Boolean
    Dim nDoradaOperacije As Long
    Dim StatusZavrsen As Boolean
    Dim pIDRN As Long
    
    retValOk = True
    bDorada = False
    bSkart = False
    nDoradaOperacije = 0
    StatusZavrsen = False
    
    If ProveriKolicine(objTehn.IDPredmet, objTehn.IdentBroj, objTehn.Varijanta, objTehn.Operacija, 1, StatusZavrsen) Then
        Call BBTSSaveRecord
        objTehn.IDPostupka = Me!IDPostupka
        
        pIDRN = ProcitajIDRNIUpisiUtTehPostupak(objTehn.IDPostupka, objTehn.IDPredmet, objTehn.IdentBroj, objTehn.Varijanta)
        
        If bBezPostupka = True Then
            Call OznaciDaJeZavrsenPostupak(objTehn.IDPostupka, PotrebneKolicineZaRN(objTehn.IDPredmet, objTehn.IdentBroj, objTehn.Varijanta), _
                    objTehn.IDPredmet, objTehn.IdentBroj, objTehn.Varijanta, objTehn.IDRadnik, objTehn.Operacija, objTehn.RJgrupaRC, bBezPostupka) 'ZatvoriPostupak (objTehn.IDPostupka)
                        
        ElseIf bOperacijaJeZavrsna = True Then
            'Otvaram formu [KeyboardSaPostupkom] za unos broja napravljenih komada
            BrojZavrsenihKomada = OtvoriFormuZaUnosKolicineNapravljenihDelova(objTehn, bDorada, bSkart, nDoradaOperacije)
        
            retValOk = OznaciDaJeZavrsenPostupak(objTehn.IDPostupka, BrojZavrsenihKomada, objTehn.IDPredmet, objTehn.IdentBroj, objTehn.Varijanta, _
                                                  objTehn.IDRadnik, objTehn.Operacija, objTehn.RJgrupaRC, bBezPostupka, bDorada, bSkart, nDoradaOperacije)
            If retValOk And BrojZavrsenihKomada <> 0 Then
                'MsgBox "Ovde unosimo kvalitet"
                OtvoriFormuZaLokacijuDelova objTehn.IDPredmet, BrojZavrsenihKomada, bDorada, bSkart, objTehn.IDRadnik, pIDRN, "LokacijaNapravljenihDelova", True
                While IsLoaded("LokacijaNapravljenihDelovaZag")
                    DoEvents
                Wend
                If PotrebnaPromenaStatusaRNUZavrsen(objTehn.IDPredmet, objTehn.IdentBroj, objTehn.Varijanta, objTehn.Operacija) Then
                    'retValOk = ADO_UpdateColumn(CNN_CurrentDataBase, "tRN", "StatusRN", SQLFormatBoolean(True), "IDRN=" & pIDRN)
                    retValOk = ADO_ExecSP(CNN_CurrentDataBase, "spUpdateStatustRN", pIDRN, SQLFormatBoolean(True))
                    ZakOtkDok "tRN", "IDRN", pIDRN, True
                End If
            End If
            
            'DoCmd.Close acForm, "BarKod_Unos"
            'DoCmd.OpenForm "ReklamniPanel_Login"
            bZatvoriBarKodUnos = True
            'GoTo exit_Point
        Else
            PotrebnoKomada = PotrebneKolicineZaRN(objTehn.IDPredmet, objTehn.IdentBroj, objTehn.Varijanta)
            PrikaziFormuZaBarKodStatus pOperacija, bBezPostupka, 0, PotrebnoKomada
            While IsLoaded("BarKod_Status")
                DoEvents
            Wend
            'DoCmd.Close acForm, "BarKod_Unos"
            'DoCmd.OpenForm "ReklamniPanel_Login"
            bZatvoriBarKodUnos = True
            'GoTo exit_Point
        End If
    Else
        BBMsgBox "GREŠKA!!!", "PROVERITE BROJ KOMADA", "Radite operaciju po kojoj je napravljeno potreban broj komada!!!", 5, vbYes, 16, 14, 125
        'DugmePonistiUnos_Click
        Call BBTSUndo
        retValOk = False
        'DoCmd.Close acForm, "BarKod_Unos"
        'DoCmd.OpenForm "ReklamniPanel_Login"
        bZatvoriBarKodUnos = True
        'GoTo exit_Point
    End If
       
Exit_Point:
    On Error Resume Next
    EvidentirajSveOstaleDetaljeTehPostupka = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "EvidentirajSveOstaleDetaljeTehPostupka"
    retValOk = False
    Resume Exit_Point

End Function

