Attribute VB_Name = "BBHotKeys"
Option Compare Database
Option Explicit
Public Function B_ZaliheArtPoMag(Optional IDArtikalZaPrikaz) As Variant
'Modifikovano: 07-10-2019
'Modifikovano: 11-01-2021 uveden optional parametar IDArtikalZaPrikaz
On Error GoTo Err_Point

Dim pIDArtikalZaPrikaz
Dim pAktivnaKontrola As Object
Dim pAktivnaForma As Object
Dim B_ZaliheArtPoMag_FormName As String


B_ZaliheArtPoMag_FormName = "B_ZaliheArtPoMag"

    pIDArtikalZaPrikaz = Null
  On Error Resume Next
    
  If Not IsMissing(IDArtikalZaPrikaz) Then
     pIDArtikalZaPrikaz = CLng(IDArtikalZaPrikaz)
     
     Set pAktivnaKontrola = Screen.ActiveControl
     Set pAktivnaForma = Screen.ActiveControl.Parent
    
     GoTo PrikaziFormu:
  End If
  
    Set pAktivnaKontrola = Screen.ActiveControl
    Set pAktivnaForma = Screen.ActiveControl.Parent
    pIDArtikalZaPrikaz = Screen.ActiveControl.Value
    
    If err.Number = 0 Then
   ' err.Clear
   ' On Error GoTo err_Point
    
        If pAktivnaKontrola.ControlSource = "IDArtikal" Or _
           pAktivnaKontrola.ControlSource = "SifraArtikla" Or _
           pAktivnaKontrola.ControlSource = "PDM_PlaniranjeStavke.SifraArtikla" Or _
           pAktivnaKontrola.ControlSource = "Profakture stavke.SifraArtikla" Then
           pIDArtikalZaPrikaz = Screen.ActiveControl.Value
        Else
           pIDArtikalZaPrikaz = Null
           pIDArtikalZaPrikaz = pAktivnaForma.Recordset("SifraArtikla")
           
           If err.Number <> 0 Then
            err.Clear
            pIDArtikalZaPrikaz = pAktivnaForma.Recordset("IDArtikal")
           End If
           
           If err.Number <> 0 Then
            err.Clear
            pIDArtikalZaPrikaz = pAktivnaForma.Recordset("PDM_PlaniranjeStavke.SifraArtikla")
           End If
           
           If err.Number <> 0 Then
            err.Clear
            pIDArtikalZaPrikaz = pAktivnaForma.Recordset("Profakture stavke.SifraArtikla")
           End If
           
           If err.Number <> 0 Then
            err.Clear
            pIDArtikalZaPrikaz = pAktivnaForma.Controls(imeKontroleCijiJeControlSource(pAktivnaForma, "SifraArtikla"))
           End If
           
           If err.Number <> 0 Then
            err.Clear
            pIDArtikalZaPrikaz = pAktivnaForma.Controls(imeKontroleCijiJeControlSource(pAktivnaForma, "IDArtikal"))
           End If
           'If IsNumeric(pAktivnaForma.Recordset("SifraArtikla")) Then
           '   pIDArtikalZaPrikaz = pAktivnaForma.Recordset("SifraArtikla")
           'ElseIf IsNumeric(pAktivnaForma.Recordset("IDArtikal")) Then
           '   pIDArtikalZaPrikaz = pAktivnaForma.Recordset("IDArtikal")
           'Else
           '   pIDArtikalZaPrikaz = Null
           'End If
       End If
    Else
       pIDArtikalZaPrikaz = Null
    End If
    
PrikaziFormu:
err.Clear

 On Error GoTo Err_Point:
 DoCmd.OpenForm B_ZaliheArtPoMag_FormName
 If IsLoaded(B_ZaliheArtPoMag_FormName) Then
    If Not ((IsNumeric(pIDArtikalZaPrikaz) And Not IsEmpty(pIDArtikalZaPrikaz))) Then
       pIDArtikalZaPrikaz = DMin("[Sifra artikla]", "EXT_R_Artikli")
    End If
        
    On Error Resume Next
        Forms!B_ZaliheArtPoMag!B_ZaliheArtPoMagPodforma.Visible = False
    On Error GoTo Err_Point:
      Forms(B_ZaliheArtPoMag_FormName)!IDArtikalZaPrikaz = CLng(Nz(pIDArtikalZaPrikaz, 0))
      Forms(B_ZaliheArtPoMag_FormName).Filter = ("[Sifra Artikla] = " & stR(Nz(pIDArtikalZaPrikaz, 0)))
      Forms(B_ZaliheArtPoMag_FormName).FilterOn = True
        
      'If Forms(B_ZaliheArtPoMag_FormName)!CheckPripremiOnLine Then
        Forms(B_ZaliheArtPoMag_FormName).PripremiPodatke
      'End If
      
      Forms(B_ZaliheArtPoMag_FormName)!B_ZaliheArtPoMagPodforma.Visible = True
    
 End If
 
Exit_Point:
On Error Resume Next
 'Application.Forms(pAktivnaForma.Name).SetFocus 'Nisam bas siguran da je ovo dobro
                                                'u stvari jeste kad je poziv sa glavne forme
                                                'ne važi za poziv iz podforme
  ' Ispravio sam
    If Not pAktivnaForma Is Nothing Then
        If IsLoaded(pAktivnaForma.Name) Then
            Forms(pAktivnaForma.Name).SetFocus
        End If
    End If
Exit Function

Err_Point:
 BBErrorMSG err, B_ZaliheArtPoMag_FormName
 On Error GoTo Exit_Point
 
End Function

'***********
Public Function B_SaldaKomitenta(Optional ByVal SifraZaTrazenje As Long = -1, Optional ZaKonto1, Optional ZaKonto2) As Variant
'Modifikovano: 09-10-2019
On Error GoTo Err_Point

Dim pIDKomitentZaPrikaz
Dim pZaKonto1
Dim pAktivnaKontrola As Object
Dim pAktivnaForma As Object
Dim tmpImeKontrole

If SifraZaTrazenje <> -1 Then
       pIDKomitentZaPrikaz = SifraZaTrazenje
    Else
     pIDKomitentZaPrikaz = Null
     On Error Resume Next
     Set pAktivnaKontrola = Screen.ActiveControl
     Set pAktivnaForma = Screen.ActiveControl.Parent
     pIDKomitentZaPrikaz = Screen.ActiveControl.Value

     If err.Number = 0 Then
        ' err.Clear
        ' On Error GoTo err_Point
    
        If pAktivnaKontrola.ControlSource = "Sifra" Or _
           pAktivnaKontrola.ControlSource = "IDKomitent" Or _
           pAktivnaKontrola.ControlSource = "Analiticka sifra" Then
           pIDKomitentZaPrikaz = Screen.ActiveControl.Value
        Else
           pIDKomitentZaPrikaz = Null
           pIDKomitentZaPrikaz = pAktivnaForma.Recordset("Sifra")
           
           If err.Number <> 0 Then
                err.Clear
                pIDKomitentZaPrikaz = pAktivnaForma.Recordset("IDKomitent")
           End If
           
           If err.Number <> 0 Then
                err.Clear
                pIDKomitentZaPrikaz = pAktivnaForma.Recordset("Analiticka sifra")
           End If
           
           If err.Number <> 0 Then
                err.Clear
                pIDKomitentZaPrikaz = pAktivnaForma.Controls(imeKontroleCijiJeControlSource(pAktivnaForma, "Sifra"))
           End If
           
           If err.Number <> 0 Then
                err.Clear
                pIDKomitentZaPrikaz = pAktivnaForma.Controls(imeKontroleCijiJeControlSource(pAktivnaForma, "IDKomitent"))
           End If
           
           If err.Number <> 0 Then
                err.Clear
                pIDKomitentZaPrikaz = pAktivnaForma.Controls(imeKontroleCijiJeControlSource(pAktivnaForma, "Analiticka sifra"))
           End If
         
        End If
     Else
       pIDKomitentZaPrikaz = Null
     End If
End If
 err.Clear
On Error GoTo Err_Point

If Not IsMissing(ZaKonto1) Then
   pZaKonto1 = Nz(ZaKonto1, BBCFG.SvaKontaKupaca)
Else
   On Error Resume Next
   pZaKonto1 = pAktivnaForma.Recordset("Konto")
   If err.Number <> 0 Then
      err.Clear
      tmpImeKontrole = imeKontroleCijiJeControlSource(pAktivnaForma, "Konto")
      If IsNull(tmpImeKontrole) Then
        pZaKonto1 = BBCFG.SvaKontaKupaca
      Else
        pZaKonto1 = pAktivnaForma.Controls(tmpImeKontrole)
      End If
      
   End If
   If err.Number <> 0 Then
      err.Clear
      pZaKonto1 = BBCFG.SvaKontaKupaca
   End If
End If
 
 On Error GoTo Err_Point
 DoCmd.OpenForm "B_SaldaKomitenta"
 
 If IsLoaded("B_SaldaKomitenta") Then
    
    Forms!B_SaldaKomitenta!ZaKonto1 = pZaKonto1
    
    If Not IsMissing(ZaKonto2) Then
      Forms!B_SaldaKomitenta!ZaKonto2 = ZaKonto2
    End If
    
    If IsNumeric(pIDKomitentZaPrikaz) And Not IsEmpty(pIDKomitentZaPrikaz) Then
     ' Forms!B_SaldaKomitenta.Filter = ("[Sifra] = " & Str(Nz(pIDKomitentZaPrikaz, 0)))
     ' Forms!B_SaldaKomitenta.FilterOn = True
     '09-01-2022
     PronadjiSlogNaFormi Forms("B_SaldaKomitenta"), ("[Sifra] = " & stR(Nz(pIDKomitentZaPrikaz, 0)))
    End If
    
    Forms!B_SaldaKomitenta.PrimeniUslove
    
 End If
 
Exit_Point:

On Error Resume Next

Exit Function

Err_Point:
 BBErrorMSG err, "B_SaldaKomitenta"
 On Error GoTo Exit_Point
 
End Function
'***********
Public Function B_SaldaKomitenta_OLD(Optional ByVal SifraZaTrazenje = -1) As Variant
  Dim txtAktivnaForma As String
  Dim txtAktivnaPodForma As String
  Dim txtAktivnaKontrola As String
  Dim LinkCriteria As String
  ' Dim SifraZaTrazenje As Variant
  
  On Error Resume Next
   If CLng(Nz(SifraZaTrazenje, -1)) <> -1 Then
        BBOpenForm "B_SaldaKomitenta"
        DoCmd.GoToControl "Sifra"
        DoCmd.FindRecord CLng(SifraZaTrazenje)
        Forms![B_SaldaKomitenta]!PronadjiJKPBroj.SetFocus
        Exit Function
    End If
    
    'SifraZaTrazenje = -1
    OdrediAktivnuFormuIKontrolu txtAktivnaForma, txtAktivnaPodForma, txtAktivnaKontrola
    If txtAktivnaForma <> "" And txtAktivnaKontrola <> "" Then
     If txtAktivnaPodForma = "" Then
       ' txtAktivnaKontrola = Forms(txtAktivnaForma).Controls(txtAktivnaKontrola).Name
        LinkCriteria = "[Sifra] = " & Forms(txtAktivnaForma).Controls(txtAktivnaKontrola)
        SifraZaTrazenje = Forms(txtAktivnaForma).Controls(txtAktivnaKontrola)
     Else
       ' txtAktivnaKontrola = Forms(txtAktivnaForma).Controls(txtAktivnaPodForma).Controls(txtAktivnaKontrola).Name
        LinkCriteria = "[Sifra] = " & Forms(txtAktivnaForma).Controls(txtAktivnaPodForma).Controls(txtAktivnaKontrola)
        SifraZaTrazenje = Forms(txtAktivnaForma).Controls(txtAktivnaPodForma).Controls(txtAktivnaKontrola)
     End If
     
     If txtAktivnaKontrola = "Sifra" Or txtAktivnaKontrola = "Analiticka Sifra" Or txtAktivnaKontrola = "IDKomitent" Or txtAktivnaKontrola = "Sifra komitenta" Then
       '  LinkCriteria = "[Sifra] = " & Forms(txtAktivnaForma).Controls(txtAktivnaKontrola)
       If IsNumeric(SifraZaTrazenje) Then
        LinkCriteria = ""
        SifraZaTrazenje = CLng(SifraZaTrazenje)
       End If
     Else
        LinkCriteria = ""
        SifraZaTrazenje = -1
     End If
    End If
    BBOpenForm "B_SaldaKomitenta", , , LinkCriteria
    If CLng(SifraZaTrazenje) <> -1 Then
        DoCmd.GoToControl "Sifra"
        DoCmd.FindRecord CLng(SifraZaTrazenje)
    End If
End Function

Private Sub OdrediAktivnuFormuIKontrolu(ByRef txtAktivnaForma As String, ByRef txtAktivnaPodForma As String, ByRef txtAktivnaKontrola As String)
Dim aktivnaForma As Form
Dim aktivnaPodforma As Form
Dim aktivnaKontrola As control

On Error Resume Next
Set aktivnaForma = Screen.ActiveForm
Set aktivnaKontrola = Screen.ActiveControl

If Screen.ActiveControl.Name <> Screen.ActiveForm.ActiveControl.Name Then
    Set aktivnaPodforma = Screen.ActiveForm.ActiveControl.Form
End If

'*******************************************
    txtAktivnaForma = aktivnaForma.Name
    txtAktivnaPodForma = aktivnaPodforma.Name
    txtAktivnaKontrola = aktivnaKontrola.ControlSource
'*******************************************

Set aktivnaForma = Nothing
Set aktivnaPodforma = Nothing
Set aktivnaKontrola = Nothing

End Sub


Public Function SracunatiIznosZaUplatu(ByVal Iznos As Currency, ByVal MaxIznos As Currency, ByVal VecUplaceno As Currency, Optional ForceLimit As Boolean = False) As Currency
'Modifikovano: 10-10-2019

    Dim retVal As Currency
    Dim OstatakPara As Currency
    
    If MaxIznos = 0 Then
        SracunatiIznosZaUplatu = Iznos
        Exit Function
    End If
    
    OstatakPara = MaxIznos - VecUplaceno
    
    If Iznos < OstatakPara Then
        retVal = Iznos
    Else
        retVal = OstatakPara
    End If
    
    
    SracunatiIznosZaUplatu = retVal
End Function

Public Function POPDVStavkeGK_PopUp(IDStavkaGK As Variant) As Boolean
On Error GoTo Err_Point

    Dim stDocName As String
    Dim retValOk As Boolean
    Dim stLinkCriteria As String
    Dim ZaStavkaID As Long
    
   retValOk = True
   
   If Not IsNumeric(IDStavkaGK) Then
     retValOk = False
     BBMsgBox_BigBit "Stavka mora da bude evidentirana.", 2
     GoTo Exit_Point
   End If
   
    stDocName = "POPDVStavkeGK_PopUp"
     
  '  If IsMissing(IDStavkaGK) Then
  '   ZaStavkaID = Me![StavkaID]
    
  '  Else
     ZaStavkaID = IDStavkaGK
  '  End If
    
    'stLinkCriteria = "[StavkaID]=" & ZaStavkaID
    'DoCmd.OpenForm stDocName, , , stLinkCriteria, , acDialog 'ako se otvori kao acDialog kod se ne izvršava dalje dok se ne zatvori dialog forma!!!
    DoCmd.OpenForm stDocName, , , stLinkCriteria
    If IsLoaded(stDocName) Then
     Forms(stDocName)!ZaStavkaID = ZaStavkaID
     Forms(stDocName)!StavkaID.DefaultValue = ZaStavkaID
     Forms(stDocName)!Zakljucano = ZakljucanaStavkaGK(ZaStavkaID)
     Forms(stDocName).ProveriZakljucavanje
     Forms(stDocName).Requery
     
    End If
Exit_Point:
    POPDVStavkeGK_PopUp = retValOk
    Exit Function

Err_Point:
    MsgBox err.Description
    retValOk = False
    Resume Exit_Point
    
End Function

'**************************************************************************
'Kreirano: 08-12-2019
'**************************************************************************
Public Function BSMProdaja(Optional IDKomitent, Optional IDArtikal, Optional Godina, Optional VrstaDokumenta)
On Error GoTo Err_BSMProdaja

    Dim stDocName As String
    Dim PrimeniUslove As Boolean
    
    stDocName = "BSM" '"BSMProdaja"
    PrimeniUslove = False
    
    BBOpenForm stDocName
    If Not IsMissing(IDKomitent) Then
        Forms(stDocName)!ZaKomitenta = CLng(IDKomitent)
        PrimeniUslove = True
    End If
    If Not IsMissing(IDArtikal) Then
        Forms(stDocName)!ZaIDArtikal = CLng(IDArtikal)
        PrimeniUslove = True
    End If
    If Not IsMissing(Godina) Then
        Forms(stDocName)!Godina = CLng(Godina)
        PrimeniUslove = True
    End If
    If Not IsMissing(VrstaDokumenta) Then
        Forms(stDocName)!ZaVrstuDokumenta = VrstaDokumenta
        PrimeniUslove = True
    End If
    If PrimeniUslove Then
       Forms(stDocName).PrimeniUslove
    End If
    
Exit_BSMProdaja:
    On Error Resume Next
Exit Function

Err_BSMProdaja:
    BBErrorMSG err, "BSMProdaja"
    Resume Exit_BSMProdaja
    
End Function

Public Function PregledProfaktura(ByVal IDFirma As Variant, ByVal Godina As Variant, ByVal ZaKomitenta As Variant, ByVal ZaProdavca As Variant, ByVal ZaVrstuDok As Variant, ByVal ZaIDPredmet As Variant) As Boolean
'Kreirano: 11-10-2021
On Error GoTo Err_Point

Dim stForm As String
Dim retValOk As Boolean

    stForm = "PregledProfaktura"
    BBOpenForm stForm
    Forms(stForm)!ZaGodinu = Godina
    Forms(stForm)![Za komitenta] = ZaKomitenta
    Forms(stForm)![Za prodavca] = ZaProdavca
    Forms(stForm)![Za vrstu] = ZaVrstuDok
    Forms(stForm)![ZaIDPredmet] = ZaIDPredmet
    
    Forms(stForm).PrimeniUslove
    
    
Exit_Point:
 On Error Resume Next
       PregledProfaktura = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "PregledProfaktura"
 retValOk = False
 Resume Exit_Point
End Function
Public Function PregledPZB(ByVal IDFirma As Variant, ByVal Godina As Variant, ByVal ZaKomitenta As Variant, ByVal ZaProdavca As Variant, ByVal ZaVrstuDok As Variant, ByVal ZaIDPredmet As Variant) As Boolean
'Kreirano: 11-10-2021
On Error GoTo Err_Point

Dim stForm As String
Dim retValOk As Boolean

    stForm = "PZB"
    BBOpenForm stForm
    Forms(stForm)!ZaGodinu = Godina
    Forms(stForm)![Za komitenta] = ZaKomitenta
    Forms(stForm)![Za prodavca] = ZaProdavca
    Forms(stForm)![Za vrstu] = ZaVrstuDok
    Forms(stForm)![ZaIDPredmet] = ZaIDPredmet
    
    Call Forms(stForm).PrimeniUslove("PZB_KnjigaUlazaIzlaza")
    
    
Exit_Point:
 On Error Resume Next
       PregledPZB = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "PregledPZB"
 retValOk = False
 Resume Exit_Point
End Function
Public Function Usluge_PregledDokumenata(ByVal IDFirma As Variant, ByVal Godina As Variant, ByVal CheckUlaznaDok As Variant, ByVal CheckProfakture As Variant, ByVal ZaKomitenta As Variant, ByVal ZaProdavca As Variant, ByVal ZaVrstuDok As Variant, ByVal ZaIDPredmet As Variant) As Boolean
'Kreirano: 12-10-2021
On Error GoTo Err_Point

Dim stForm As String
Dim retValOk As Boolean

    stForm = "USLUGA Pregled dokumenata"
    BBOpenForm stForm
    Forms(stForm)!ZaGodinu = Godina
    Forms(stForm)![Za komitenta] = ZaKomitenta
    Forms(stForm)![Za prodavca] = ZaProdavca
    Forms(stForm)![Za vrstu] = ZaVrstuDok
    Forms(stForm)![ZaIDPredmet] = ZaIDPredmet
    Forms(stForm)![CheckUlaznaDok] = CheckUlaznaDok
    Forms(stForm)![CheckProfakture] = CheckProfakture
    Call Forms(stForm).PostaviFaktureIliProfakture
    
    Call Forms(stForm).PrimeniUslove
    
    
Exit_Point:
 On Error Resume Next
       Usluge_PregledDokumenata = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "Usluge_PregledDokumenata"
 retValOk = False
 Resume Exit_Point
End Function
Public Function PregledTrebovanja(ByVal IDFirma As Variant, ByVal Godina As Variant, ByVal CheckZaAktivno As Variant, ByVal ZaDobavljaca As Variant, ByVal ZaKupca As Variant, ByVal ZaIDPredmet As Variant) As Boolean
'Kreirano: 12-10-2021
On Error GoTo Err_Point

Dim stForm As String
Dim retValOk As Boolean

    stForm = "PT_PregledTrebovanja"
    BBOpenForm stForm
    Forms(stForm)!ZaGodinu = Godina
    Forms(stForm)![ZaKupca] = ZaKupca
    Forms(stForm)![ZaKomitenta] = ZaDobavljaca
    Forms(stForm)![ZaIDPredmet] = ZaIDPredmet
    Forms(stForm)![CheckZaAktivno] = CheckZaAktivno
    
    Call Forms(stForm).PrimeniUslove
    
    
Exit_Point:
 On Error Resume Next
       PregledTrebovanja = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "PregledTrebovanja"
 retValOk = False
 Resume Exit_Point
End Function
Public Function GKDnevnik(ByVal IDFirma As Variant, ByVal Godina As Variant, ZaKonto As Variant, ByVal ZaIDKomitent As Variant, ByVal ZaIDPredmet As Variant) As Boolean
'Kreirano: 12-10-2021
On Error GoTo Err_Point

Dim stForm As String
Dim retValOk As Boolean

    stForm = "Dnevnik glavne knjige"
    BBOpenForm stForm
    Forms(stForm)!Godina = Godina
    Forms(stForm)![ZaKonto] = ZaKonto
    Forms(stForm)![ZaIDKomitent] = ZaIDKomitent
    Forms(stForm)![ZaIDPredmet] = ZaIDPredmet
    
    Call Forms(stForm).PrimeniUslove
    
    
Exit_Point:
 On Error Resume Next
       GKDnevnik = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "GKDnevnik"
 retValOk = False
 Resume Exit_Point
End Function
Public Function GKS_3DatumaZaKomitenta(ByVal ZaIDKomitent As Variant, Optional ByVal IDFirma, Optional ByVal Godina As Variant, Optional ZaKonto1, Optional ZaKonto2) As Boolean
'Kreirano: 12-10-2021
On Error GoTo Err_Point

Dim stForm As String
Dim retValOk As Boolean
    
    retValOk = True
    stForm = "GKS"
    BBOpenForm stForm
    
    If Not IsMissing(IDFirma) Then Forms(stForm)!IDFirma = IDFirma
    If Not IsMissing(Godina) Then Forms(stForm)!ZaGodinu = Godina
    If Not IsMissing(ZaKonto1) Then Forms(stForm)![ZaKonto1] = ZaKonto1
    If Not IsMissing(ZaKonto2) Then Forms(stForm)![ZaKonto2] = ZaKonto2
    Forms(stForm)![ZaKomitenta] = ZaIDKomitent
    Forms(stForm)!FrameGKSalda = 2 '   Forms(stForm)!Podforma.SourceObject = "GKS_3Datuma"
    Forms(stForm)!DugmeStop.SetFocus
    Call Forms(stForm).PrimeniUslove
    
    
Exit_Point:
 On Error Resume Next
       GKS_3DatumaZaKomitenta = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "GKS_3DatumaZaKomitenta"
 retValOk = False
 Resume Exit_Point
End Function

Public Function OpenForm_KomitentiUgovori() As Boolean
'Kreirano: 31-05-2023
On Error GoTo Err_Point

Dim stForm As String
Dim retValOk As Boolean
     
    retValOk = True
    stForm = "Komitenti_Ugovori"
    
    If Nz(ReadCFGParametar("KomitentiUgovoriOnOff", "Off"), "Off") = "On" Then
        
        BBOpenForm stForm
    
    End If
    
          
    
Exit_Point:
 On Error Resume Next
       OpenForm_KomitentiUgovori = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "OpenForm_KomitentiUgovori"
 retValOk = False
 Resume Exit_Point
End Function

Public Function KreirajVirmanIzStavkeGK_PopUp(IDStavkaGK As Variant) As Boolean
On Error GoTo Err_Point

    Dim stDocName As String
    Dim retValOk As Boolean
    Dim stLinkCriteria As String
    Dim IDVirman As Long
    
   retValOk = True
   
   If Not IsNumeric(IDStavkaGK) Then
     retValOk = False
     MsgBox "Stavka mora da bude evidentirana.", vbExclamation, "QBigTeh"
     GoTo Exit_Point
   End If
   
   IDVirman = spKreirajVirmanIzStavkeGK(CLng(IDStavkaGK))
   If IDVirman > 0 Then
         stLinkCriteria = "[IDVirman]=" & IDVirman
   Else
        stLinkCriteria = ""
        MsgBox "Ne može da se kreira nalog za prenos." & vbCrLf & "Molimo vas da ga unesete", vbInformation, "QBigTeh"
   End If
    stDocName = "UnosVirmana"
    'DoCmd.OpenForm stDocName, , , stLinkCriteria, , acDialog 'ako se otvori kao acDialog kod se ne izvršava dalje dok se ne zatvori dialog forma!!!
    DoCmd.OpenForm stDocName, , , stLinkCriteria, , acDialog
    'If IsLoaded(stDocName) Then
      'Forms(stDocName)!IDDokIzGK = IDStavkaGK
    '  Forms(stDocName)!IDDokIzGK.DefaultValue = IDStavkaGK
    '  Forms(stDocName)!IDUKorist = IDUKorist
      'Forms(stDocName)!UKoristZiroRacun =
     'Forms(stDocName)!Zakljucano = ZakljucanaStavkaGK(ZaStavkaID)
     'Forms(stDocName).ProveriZakljucavanje
     'Forms(stDocName).Requery
    ' DoCmd.OpenForm stDocName, , , stLinkCriteria, , acDialog
    'End If
Exit_Point:
    KreirajVirmanIzStavkeGK_PopUp = retValOk
Exit Function

Err_Point:
    MsgBox err.Description
    retValOk = False
    Resume Exit_Point
    
End Function

