VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Izbor radnog fajla"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit

Private Sub ComboNadjiFirmu_AfterUpdate()
'On Error Resume Next
'Me![IDBaze].Visible = True
'DoCmd.GoToControl "IDBaze"
'DoCmd.FindRecord Me![ComboNadjiFirmu]
'Me![ComboNadjiFirmu] = Null
'DoCmd.GoToControl "ComboNadjiFirmu"
'Me![IDBaze].Visible = False
    
    Me.RecordsetClone.FindFirst "[IDBaze] = " & Me![ComboNadjiFirmu]
    Me.Bookmark = Me.RecordsetClone.Bookmark
    Me![ComboNadjiFirmu] = Null
End Sub

Private Sub Detail0_DblClick(Cancel As Integer)
    DetaljnoRadniFajl
End Sub

Private Sub Dugme_Stop_Click()
On Error GoTo Err_Dugme_stop_Click


    DoCmd.Close

Exit_Dugme_stop_Click:
    Exit Sub

Err_Dugme_stop_Click:
    MsgBox Error$
    Resume Exit_Dugme_stop_Click
    
End Sub

Private Function OvdeIzaberiBazu()
    Dim NewDbName  As Variant
    NewDbName = IzaberiBazu()
    If Not IsNull(NewDbName) Then
        Me![Naziv baze] = NewDbName
    End If
End Function

Private Sub DugmeIzaberiBazu_Click()
  OvdeIzaberiBazu
End Sub

Private Sub DugmeKreirajNovuBazu_Click()
On Error GoTo err_DugmeKreirajNovuBazu

Dim varRet As Variant
Dim IzStareBaze As Variant
Dim answer As Long

'IzStareBaze = BazaZaTip("MOD_T")
IzStareBaze = Me!ModlaZaKreiranjeBaze


If Not FileExists(CStr(IzStareBaze)) Then
    answer = MsgBox("Baza " & IzStareBaze & " ne postoji." & vbCr & _
                   "Ako zelite da izaberete drugu bazu iz koje cete kreirati novu " _
                  & "kliknite Ok, a ako prekidate proces kliknite Cancel", vbExclamation + vbOKCancel)
    If answer = vbCancel Then GoTo exit_DugmeKreirajNovuBazu
    IzStareBaze = IzaberiBazu()
   
End If

If IsNull(IzStareBaze) Then
    MsgBox "Ne postoji [BazaZaTip='MOD_T']!" & vbCr & _
           "Proces kreiranja baze se prekida!", vbCritical + vbOKOnly
    varRet = False
    GoTo exit_DugmeKreirajNovuBazu
End If

    
varRet = KreirajNovuBazu(IzStareBaze, Me![Naziv baze])

If varRet Then
 PoveziSeSaNovomBazom
 BBStart
End If

exit_DugmeKreirajNovuBazu:

Exit Sub
err_DugmeKreirajNovuBazu:

Select Case err.Number
       Case Else
            MsgBox "ErrNo: " & err.Number & "  " & err.Description
End Select
    
Resume exit_DugmeKreirajNovuBazu

End Sub

Private Sub PoveziSeSaNovomBazom()
Dim varRetOK As Boolean
 'RaskiniVezuSaObjektima
 'PoveziObjekte (Me![Naziv baze])
 'DoCmd.Quit
 DoCmd.Hourglass True
 varRetOK = ForsirajNoveLinkoveZaIDBaze(IDBazeZaTipBaze("BigBit_T"), Me![Naziv baze])
 varRetOK = varRetOK And Postavi_CFG_T_Tabele(False, True, True, True)  '26-10-2019: moraju da se promene linkaovi za UplatniRacuni
                                                                        ', SemezaKOntiranje, stavke sema za kontiranje ALI NE Za RadniFajlovi
 HideNavPane False
 
 DoCmd.Hourglass False
    If Not varRetOK Then
        MsgBox "Povezivanje nije uspelo!", vbCritical + vbOKOnly, "QMegaTeh"
    Else
        PostaviGlobalneParametre
        MsgBox "Povezivanje uspešno obavljeno.", vbOKOnly, "QMegaTeh"
    End If
End Sub

Private Sub DugmePoveziSe_Click()
    RegUser (1)
    PoveziSeSaNovomBazom
    BBStart
End Sub

Private Sub Firma_AfterUpdate()
   If Nz(Me![Naziv baze], "") = "" Then
    Me![Naziv baze] = KreirajNazivBaze(Me!Firma, Me!DefaultDirNovaBaza)
   End If
End Sub
Private Function KreirajNazivBaze(stImeFirme As String, stDefaultDir As String) As String
   Dim retVal As String
    retVal = stDefaultDir & "\" & stImeFirme & "\" & "BB_T.MDB"
    KreirajNazivBaze = retVal
End Function
Private Sub Form_Open(Cancel As Integer)
    DoCmd.Maximize
    'DoCmd.GoToControl "IDBaze"
    'DoCmd.FindRecord F_IDAktivneBaze()
    Me.RecordsetClone.FindFirst "[IDBaze] = " & F_IDAktivneBaze()
    If Not Me.RecordsetClone.NoMatch Then
     Me.Bookmark = Me.RecordsetClone.Bookmark
    End If
    DoCmd.GoToControl "ComboNadjiFirmu"
    
    On Error Resume Next
    
    'If Not UserUGrupi(CurrentUser(), "PowerFulUsers") And (CurrentUser <> "Negovan") Then
    If F_SysTipKorisnika = 0 And (CurrentUser <> "Negovan") Then
     Me!DugmeIzaberiBazu.Enabled = False
     Me!DugmePoveziSe.Enabled = False
     Me!DugmeKreirajNovuBazu.Enabled = False
     Me!ModlaZaKreiranjeBaze.Enabled = False
     Me!DefaultDirNovaBaza.Enabled = False
     Me![Naziv baze].Enabled = False
     Me!DugmePSStart.Enabled = False
     Me!ComboNadjiFirmu.Enabled = False
     Me!DugmePrepisiIzCFGRadniFajlovi.Enabled = False
     Me!DugmePrepisiUplatneRacuneIzCFG.Enabled = False
    End If
    If CurrentUser = "Negovan" Then
      Me!IDBaze.Visible = True
      Me!LabelIDBaze.Visible = True
    End If
End Sub


Private Sub DetaljnoRadniFajl()
On Error GoTo Err_DetaljnoRadniFajl

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "RadniFajlDetaljno"
    
    stLinkCriteria = "[IDBaze]=" & Me![IDBaze]
    BBOpenForm stDocName, , , stLinkCriteria

Exit_DetaljnoRadniFajl:
    Exit Sub

Err_DetaljnoRadniFajl:
    MsgBox err.Description
    Resume Exit_DetaljnoRadniFajl
    
End Sub
Private Sub DugmeDetaljnoRadniFajl_Click()
On Error GoTo Err_DugmeDetaljnoRadniFajl_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "RadniFajlDetaljno"
    
    stLinkCriteria = "[IDBaze]=" & Me![IDBaze]
    BBOpenForm stDocName, , , stLinkCriteria

Exit_DugmeDetaljnoRadniFajl_Click:
    Exit Sub

Err_DugmeDetaljnoRadniFajl_Click:
    MsgBox err.Description
    Resume Exit_DugmeDetaljnoRadniFajl_Click
    
End Sub
Private Sub DugmeBaze_Click()
On Error GoTo Err_DugmeBaze_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "Baze"
    BBOpenForm stDocName, , , stLinkCriteria

Exit_DugmeBaze_Click:
    Exit Sub

Err_DugmeBaze_Click:
    MsgBox err.Description
    Resume Exit_DugmeBaze_Click
    
End Sub

Private Sub DugmePSStart_Click()
On Error GoTo Err_DugmePSStart_Click

    Dim stDocName As String
    Dim stLinkCriteria As String
    Dim odgovor
    
    odgovor = MsgBox("OVU OPCIJU KORISTITE NA SOPSTVENU ODGOVORNOST. DA NASTAVIM?", vbCritical + vbYesNo, "QMegaTeh")
    If odgovor = vbYes Then
        stDocName = "PS_START"
        BBOpenForm stDocName, , , stLinkCriteria
    End If

Exit_DugmePSStart_Click:
    Exit Sub

Err_DugmePSStart_Click:
    MsgBox err.Description
    Resume Exit_DugmePSStart_Click
    
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
Private Sub DugmePrepisiIzCFGRadniFajlovi_Click()
On Error GoTo Err_DugmePrepisiIzCFGRadniFajlovi_Click

    Dim stDocName As String

    stDocName = "RadniFajlovi_PrepisiIzCFG"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    Me.Requery

Exit_DugmePrepisiIzCFGRadniFajlovi_Click:
    Exit Sub

Err_DugmePrepisiIzCFGRadniFajlovi_Click:
    MsgBox err.Description
    Resume Exit_DugmePrepisiIzCFGRadniFajlovi_Click
    
End Sub
Private Sub Naziv_baze_DblClick(Cancel As Integer)
  OvdeIzaberiBazu
End Sub
Private Sub DugmePrepisiUplatneRacuneIzCFG_Click()
On Error GoTo Err_DugmePrepisiUplatneRacuneIzCFG_Click

    Dim stDocName As String

    stDocName = "UplatniRacuni_PrepisiIzCFG"
    DoCmd.OpenQuery stDocName, acNormal, acEdit

Exit_DugmePrepisiUplatneRacuneIzCFG_Clic:
    Exit Sub

Err_DugmePrepisiUplatneRacuneIzCFG_Click:
    MsgBox err.Description
    Resume Exit_DugmePrepisiUplatneRacuneIzCFG_Clic
    
End Sub
