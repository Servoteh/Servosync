VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Prva maskaPregledi"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit
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

Private Sub Dugme_Kraj_rada_Click()
On Error GoTo Err_Dugme_Kraj_rada_Click

    DoCmd.Close

Exit_Dugme_Kraj_rada_Click:
    Exit Sub

Err_Dugme_Kraj_rada_Click:
    MsgBox Error$
    Resume Exit_Dugme_Kraj_rada_Click
    
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



Private Sub Dugmecck_Click()
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

Private Sub DugmePregledPoruka_Click()
On Error GoTo Err_DugmePregledPoruka_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    'stDocName = "P_PregledPoruka"
    'BBOpenForm stDocName, , , stLinkCriteria
    
    'stDocName = "DataCollector"
    'BBOpenForm stDocName, , , stLinkCriteria

    stDocName = "PlanerPopUp"
    BBOpenForm stDocName, , , stLinkCriteria

Exit_DugmePregledPoruka_Click:
    Exit Sub

Err_DugmePregledPoruka_Click:
    MsgBox err.Description
    Resume Exit_DugmePregledPoruka_Click
    
End Sub

Private Sub DugmeRekapitulacije_Click()
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

Private Sub DugmePersonalnaAdministracija_Click()
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
    'Me!ComboGodina.RowSource = F_ComboGodinaRowSource()
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
   
   
End Sub


Private Sub Form_Unload(Cancel As Integer)
    'fp_ClosePort False
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


