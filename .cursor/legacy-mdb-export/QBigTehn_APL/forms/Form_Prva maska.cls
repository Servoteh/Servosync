VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Prva maska"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit

Private Sub Command212_Click()
On Error GoTo Err_DugmePregledKomitenata_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "Predmeti"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmePregledKomitenata_Click:
    Exit Sub

Err_DugmePregledKomitenata_Click:
    MsgBox err.Description
    Resume Exit_DugmePregledKomitenata_Click
End Sub

Private Sub Command216_Click()
On Error GoTo Err_DugmeVPregledDokumenata_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "AARadnika"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeVPregledDokumenata_Click:
    Exit Sub

Err_DugmeVPregledDokumenata_Click:
    MsgBox err.Description
    Resume Exit_DugmeVPregledDokumenata_Click

End Sub

Private Sub Dugme_Kraj_rada_Click()
On Error GoTo Err_Dugme_Kraj_rada_Click

    
    DoCmd.Close
    

Exit_Dugme_Kraj_rada_Click:
    Exit Sub

Err_Dugme_Kraj_rada_Click:
    MsgBox Error$
    Resume Exit_Dugme_Kraj_rada_Click
    
End Sub

Private Sub DugmeKreiranjeNalogaZaNoviPredmet_Click()
On Error GoTo Err_DugmeVPregledDokumenata_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "KreirajNoveNalogeZaIDPredmet"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeVPregledDokumenata_Click:
    Exit Sub

Err_DugmeVPregledDokumenata_Click:
    MsgBox err.Description
    Resume Exit_DugmeVPregledDokumenata_Click

End Sub

Private Sub DugmePPS_Click()
On Error GoTo Err_DugmeVPregledDokumenata_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "PPS"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeVPregledDokumenata_Click:
    Exit Sub

Err_DugmeVPregledDokumenata_Click:
    MsgBox err.Description
    Resume Exit_DugmeVPregledDokumenata_Click

End Sub

Private Sub DugmePregledDelovaPoLokacija_Click()
On Error GoTo Err_DugmeVPregledDokumenata_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "PregledDelovaPoLokacijama"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeVPregledDokumenata_Click:
    Exit Sub

Err_DugmeVPregledDokumenata_Click:
    MsgBox err.Description
    Resume Exit_DugmeVPregledDokumenata_Click

End Sub


'Private Sub Form_Activate()
'    DoCmd.Maximize
'End Sub

'Private Sub Form_Close()

'    If CurrentUser <> "Negovan" Then
'         DoCmd.Quit
'    End If
'End Sub
Private Sub DugmeGrupaZaLL_Click()
On Error GoTo Err_DugmePregledKomitenata_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

   '    DoCmd.OpenForm "Lager lista"
    'stDocName = "frmDefParametriUnos"
    stDocName = "frmPozicije"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmePregledKomitenata_Click:
    Exit Sub

Err_DugmePregledKomitenata_Click:
    MsgBox err.Description
    Resume Exit_DugmePregledKomitenata_Click
End Sub

Private Sub DugmeKarticaPostupka_Click()
On Error GoTo Err_DugmeVPregledDokumenata_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "Kartica TehPostupka"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeVPregledDokumenata_Click:
    Exit Sub

Err_DugmeVPregledDokumenata_Click:
    MsgBox err.Description
    Resume Exit_DugmeVPregledDokumenata_Click

End Sub

Private Sub DugmeLagerLista_Click()
On Error GoTo Err_DugmePregledKomitenata_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "Lager lista"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmePregledKomitenata_Click:
    Exit Sub

Err_DugmePregledKomitenata_Click:
    MsgBox err.Description
    Resume Exit_DugmePregledKomitenata_Click
End Sub

Private Sub DugmeOperacije_Click()
On Error GoTo Err_DugmeUnosKomitenata_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "UnosOperacije"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeUnosKomitenata_Click:
    Exit Sub

Err_DugmeUnosKomitenata_Click:
    MsgBox err.Description
    Resume Exit_DugmeUnosKomitenata_Click

End Sub

Private Sub DugmePregledPostupaka_Click()
On Error GoTo Err_DugmeVPregledDokumenata_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "PregledPoPostupcima"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeVPregledDokumenata_Click:
    Exit Sub

Err_DugmeVPregledDokumenata_Click:
    MsgBox err.Description
    Resume Exit_DugmeVPregledDokumenata_Click

End Sub

Private Sub DugmePregledPostupakaDetaljno_Click()
On Error GoTo Err_DugmeVPregledDokumenata_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "RNPregledZag"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeVPregledDokumenata_Click:
    Exit Sub

Err_DugmeVPregledDokumenata_Click:
    MsgBox err.Description
    Resume Exit_DugmeVPregledDokumenata_Click

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



Private Sub DugmePreuziIzBB_Click()
    PreuzmiIzBB
End Sub

Private Sub DugmeUnosRadnihJedinica_Click()
On Error GoTo Err_DugmeUnosArtikala_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "UnosRadnihJedinica"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeUnosArtikala_Click:
    Exit Sub

Err_DugmeUnosArtikala_Click:
    MsgBox err.Description
    Resume Exit_DugmeUnosArtikala_Click

End Sub

Private Sub DugmeVrsteRadnika_Click()

On Error GoTo Err_DugmeUnosArtikala_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "VrsteRadnika"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeUnosArtikala_Click:
    Exit Sub

Err_DugmeUnosArtikala_Click:
    MsgBox err.Description
    Resume Exit_DugmeUnosArtikala_Click
    
End Sub



'Private Sub Form_Open(Cancel As Integer)
'Dim X As Variant
' If Not IsLoaded("Prva maska") Then
'    X = InicSPECIJAL()
'    X = Func_InicNizObjZaPovezivanje()
' End If
'End Sub

Private Sub DugmeAlati_Click()
On Error GoTo Err_DugmeAlati_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "Alati"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeAlati_Click:
    Exit Sub

Err_DugmeAlati_Click:
    MsgBox err.Description
    Resume Exit_DugmeAlati_Click
    
End Sub
Private Sub DugmeVUnosDok_Click()
On Error GoTo Err_DugmeVUnosDok_Click

    Dim stDocName As String
    Dim stLinkCriteria As String
    
    RNP.Caller = "Prva maska"
    stDocName = "UnosRN"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeVUnosDok_Click:
    Exit Sub

Err_DugmeVUnosDok_Click:
    MsgBox err.Description
    Resume Exit_DugmeVUnosDok_Click
    
End Sub
Private Sub DugmeVPregledDokumenata_Click()
On Error GoTo Err_DugmeVPregledDokumenata_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "PregledPoPredmetima"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeVPregledDokumenata_Click:
    Exit Sub

Err_DugmeVPregledDokumenata_Click:
    MsgBox err.Description
    Resume Exit_DugmeVPregledDokumenata_Click
    
End Sub
Private Sub DugmeUnosArtikala_Click()
On Error GoTo Err_DugmeUnosArtikala_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "Unos / Pregled radnika"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeUnosArtikala_Click:
    Exit Sub

Err_DugmeUnosArtikala_Click:
    MsgBox err.Description
    Resume Exit_DugmeUnosArtikala_Click
    
End Sub

Private Sub DugmeUnosKomitenata_Click()
On Error GoTo Err_DugmeUnosKomitenata_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "RadniciPoMasinama"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeUnosKomitenata_Click:
    Exit Sub

Err_DugmeUnosKomitenata_Click:
    MsgBox err.Description
    Resume Exit_DugmeUnosKomitenata_Click
    
End Sub
Private Sub DugmePregledKomitenata_Click()
On Error GoTo Err_DugmePregledKomitenata_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "Pregled komitenata"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmePregledKomitenata_Click:
    Exit Sub

Err_DugmePregledKomitenata_Click:
    MsgBox err.Description
    Resume Exit_DugmePregledKomitenata_Click
    
End Sub

'Option Compare Database   'Use database order for string comparisons
'Option Explicit
Public Sub PrikaziAktivnuFirmu()
    Me.Requery
    Me.Repaint
    'DoCmd.Restore
    Me![Firma_] = F_AFNaziv() 'BBCFG.Firma.Naziv 'DLookup("[Firma]", "Radni fajlovi", "[IDBaze] = " & F_IDAktivneBaze())
    'Me![F_NazivBaze] = BBCFG.cnnString 'DLookup("[Naziv Baze]", "Radni fajlovi", "[IDBaze] = " & F_IDAktivneBaze())
    Me![F_NazivBaze] = Replace(BBCFG.CnnStringBezPWD(), "ODBC;", "")
End Sub
Private Sub PrikaziAPPRev()
  Me!BBAppRev.Caption = F_APPRev()
  Me!txtCurrentUser = CurrentUser() & " (" & Environ("UserName") & ")"
  'Me!LabelWinUser.Caption = Environ("UserName")
End Sub

Private Sub ComboGodina_AfterUpdate()
    'BBAktGodina = Me!ComboGodina
    BBCFG.Godina = Me!ComboGodina
End Sub



Private Sub Dugme_Popravi_bazu_Click()
On Error GoTo Err_Dugme_Popravi_bazu_Click

    Dim DocName As String
    Dim LinkCriteria As String

    ' DocName = "Oporavak baze"
    DocName = "Alati"
    BBOpenForm DocName, , , LinkCriteria

Exit_Dugme_Popravi_bazu_Click:
    Exit Sub

Err_Dugme_Popravi_bazu_Click:
    MsgBox Error$
    Resume Exit_Dugme_Popravi_bazu_Click
    
End Sub

Private Function IzborBaze()
On Error GoTo Err_IzborBaze

    Dim DocName As String
    Dim LinkCriteria As String
    
        DocName = "Izbor radnog fajla"
        BBOpenForm DocName, , , LinkCriteria
        
    
Exit_IzborBaze:
    Exit Function

Err_IzborBaze:
    MsgBox Error$
    Resume Exit_IzborBaze
    
End Function

Private Sub Firma__DblClick(Cancel As Integer)
On Error Resume Next
  '  BBOpenForm "Firme"
  If BBCFG.SQLDB Then
   'BBOpenForm "IzaberiFirmu"
   DoCmd.OpenForm "IzaberiFirmu"
  Else
    IzborBaze
  End If
End Sub

Private Sub Form_Activate()
    
    PrikaziAktivnuFirmu
    
End Sub

Private Sub Form_Close()

    If CurrentUser <> "Negovan" Then
        'DoCmd.Quit
        QuitBigBit
    Else
        QuitBigBit False, True, True
    End If
End Sub
Private Function F_ComboGodinaRowSource() As String
Dim G As Integer
Dim stListRetVal As String
stListRetVal = ""
For G = 2000 To 2100
   stListRetVal = stListRetVal & ";" & CStr(G)
Next G
F_ComboGodinaRowSource = stListRetVal
End Function
Private Sub Form_Open(Cancel As Integer)
' On Error Resume Next
    
    PrikaziAPPRev
    
    'BBPravaPristupa.BB_PravaPristupaPodesiFormu Me
        
    If Zastita.Zasticen Then
        'DoCmd.Quit
        QuitBigBit
    End If
    
    Me!Label_BigBit.Caption = BBCFG.AppName
        
    If BBCFG.CNNString Like "*UID=ReadOnly*" Then
      Me!LabelRO.Visible = True
      'Me!Label_BigBit.BorderColor = ColorConstants.vbRed
      'Me!Label_BigBit.BorderColor = ColorConstants.vbBlue
      'Me!Label_BigBit.BorderColor = &HFF0000 '0xFF0000
    Else
     Me!LabelRO.Visible = False
    End If
    
    If DemoApl Then Me!LabelDemo.Visible = True Else Me!LabelDemo.Visible = False
    Me.Requery
    
    DoCmd.Maximize
    Me!ComboGodina.RowSource = F_ComboGodinaRowSource()
    'DoCmd.GoToControl "Godina"
    
    If F_BBUnlockAktGodina() Then Me!Godina.Locked = False
    If F_BBUnlockAktOJ() Then Me!OJ.Locked = False
    If F_BBUnlockAktOD() Then Me!OD.Locked = False
    
    'If Not BBCFG.CarinskiMagacin Then
    ' Me!OptionCarinskiMagacin.Enabled = False
    'End If
    
    'If BBCFG.SQLDB Then
    '  Me!OptionVPPlaniranjeZaliha.Enabled = False
    'End If
    
    Rem REM Call BB_PravaPristupaPodesiFormu(Me)
   ' Me!DugmeMPShuttle.Enabled = CBool(Nz(ReadParametar("CFG_Sys", "PrvaMaska.DugmeMPShuttle.Enabled"), True))
   ' Me!DugmeImport.Enabled = CBool(Nz(ReadParametar("CFG_Sys", "PrvaMaska.DugmeImport.Enabled"), True))
   ' If Nz(ReadParametar("CFG_Global", "Planer_Start"), False) Then
   '  If Planer.BrojNeobradjenihPoruka > 0 Then
   '     BBOpenForm "PlanerPopUp"
   '  End If
   ' End If
    
   ' If Nz(ReadCFGParametar("KomitentiUgovoriOnOff", "Off"), "Off") = "Off" Then
   '     'BBOpenForm stForm
   '     Me!Option_Ugovori.Enabled = False
   ' End If
   ProveriInboxPlanera
   
   If F_PrebaciKomitenteIzEXTBaze() Then
        Me!DugmePreuziIzBB.Visible = True
   Else
        Me!DugmePreuziIzBB.Visible = False
   End If
End Sub


Private Sub Form_Unload(Cancel As Integer)
    'fp_ClosePort False
End Sub

Private Sub Godina_AfterUpdate()
    'BBAktGodina = Me!Godina
    BBCFG.Godina = Me!Godina
End Sub

Private Sub Godina_DblClick(Cancel As Integer)
    BBOpenForm "IzaberiFirmu"
End Sub

Private Sub Godina_LostFocus()
    BBCFG.Godina = Me!Godina
End Sub


Private Sub Label_BigBit_DblClick(Cancel As Integer)
    BBOpenForm "Dnevnik"
End Sub
Private Sub BBAppRev_DblClick(Cancel As Integer)
 
 OtvoriFormuCFGReadWrite
 
End Sub
Private Sub DugmeCFG_Click()
On Error GoTo Err_DugmeCFG_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    'stDocName = "CFGReadWrite"
    'BBOpenForm stDocName, , , stLinkCriteria
    
    OtvoriFormuCFGReadWrite

Exit_DugmeCFG_Click:
    Exit Sub

Err_DugmeCFG_Click:
    MsgBox err.Description
    Resume Exit_DugmeCFG_Click
    
End Sub
Private Sub DugmePregledPoruka_Click()
On Error GoTo Err_DugmePregledPoruka_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "PlanerPopUp"
    BBOpenForm stDocName, , , stLinkCriteria

Exit_DugmePregledPoruka_Click:
    Exit Sub

Err_DugmePregledPoruka_Click:
    MsgBox err.Description
    Resume Exit_DugmePregledPoruka_Click
    
End Sub

Private Sub DugmeImport_Click()
On Error GoTo Err_DugmeImport_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "EXT_IMPORT"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeImport_Click:
    Exit Sub

Err_DugmeImport_Click:
    MsgBox err.Description
    Resume Exit_DugmeImport_Click
    
End Sub
