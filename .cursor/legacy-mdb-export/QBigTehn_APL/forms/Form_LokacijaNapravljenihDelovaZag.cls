VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_LokacijaNapravljenihDelovaZag"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub DugmeKarticaDela_Click()
    Dim IDPredmet As Long
    Dim BrojCrteza As String
    
    IDPredmet = Nz(Me!IDPredmet, 0)
    BrojCrteza = Nz(Me!BrojCrteza, "")
    
    DoCmd.Close
    KarticaLokacijaDela IDPredmet, BrojCrteza
End Sub

Private Sub DugmeLokacijeDelova_Click()
    OtvoriNovuLokaciju "-", 0
End Sub

Private Sub DugmeNaLokacijuRequery_Click()
    Me!NaLokaciju.Requery
End Sub

Private Sub DugmePripremiTrebovanje_Click()
    DoCmd.MoveSize , , Me.Width + 200
    PostaviParametreZaTrebovanje
    Me!DugmePripremiTrebovanje.Visible = False
    Me!DugmePripremiPrenos.Visible = True
    
End Sub

Private Sub DugmeNalepnice_Click()
    Dim stDocName As String
    If KreirajTmpTabeluUTmpBazi("tmp_Nalepnice", "Nalepnice") Then
        'MsgBox "Kreirane su pomocne tabele za " & Srpski("stampanje") & " nalepnica", vbExclamation, "QBigTeh"
        DoCmd.SetWarnings False
        stDocName = "PopuniTablicu_TMP_Nalepnice"
        DoCmd.OpenQuery stDocName, acNormal, acEdit
        DoCmd.SetWarnings False
        If Nz(Me!ProveraUnosaKolicina, False) Then
            DoCmd.OpenReport "Nalepnice", acViewNormal
        Else
            DoCmd.Close acForm, "LokacijaNapravljenihDelovaZag"
            DoCmd.OpenReport "Nalepnice", acViewPreview
        End If
    Else
        MsgBox "Ne može da se kreira pomocna tabela za " & Srpski("stampanje") & " nalepnica", vbExclamation, "QBigTeh"
    End If
End Sub

Private Sub DugmePripremiPrenos_Click()
    DoCmd.MoveSize , , Me.Width + 200
    PostaviParametreZaPrenos
    Me!DugmePripremiPrenos.Visible = False
    Me!DugmePripremiTrebovanje.Visible = True
End Sub

Private Sub DugmeSaLokacijeNaLokaciju_Click()
On Error GoTo Err_Point
    Dim Kolicina As Integer
    
    If Nz(Me!KolicinaZaPrenos, 0) = 0 And Nz(Me!KolicinaZaTrebovanje, 0) = 0 Then
        MsgBox Srpski("Kolicine") & " za prenos ili trebovanje nisu definisane", vbInformation
        Exit Sub
    End If
    
    If Nz(Me!KolicinaZaPrenos, 0) <> 0 And Nz(Me!KolicinaZaTrebovanje, 0) <> 0 Then
        MsgBox Srpski("Kolicine") & " za prenos ili trebovanje su loše definisane", vbInformation
        Exit Sub
    End If
    
    If Nz(Me!KolicinaZaPrenos, 0) < 0 Or Nz(Me!KolicinaZaTrebovanje, 0) < 0 Then
        MsgBox Srpski("Kolicine") & " za prenos ili trebovanje moraju biti " & Srpski("vece") & " od nule", vbInformation
        Exit Sub
    End If
    
    Kolicina = Forms![LokacijaNapravljenihDelovaZag]![Podforma].Form![UkKolicina]
    If Me!KolicinaZaPrenos <> 0 And Me!KolicinaZaPrenos > Kolicina Then
        MsgBox Srpski("Kolicine") & " za prenos moraju biti manje ili jednake od trenutnog broja komada delova na polici sa koje prenosite", vbInformation
        Exit Sub
    End If
    If Me!KolicinaZaTrebovanje <> 0 And Me!KolicinaZaTrebovanje > Kolicina Then
        MsgBox Srpski("Kolicine") & " za trebovanje moraju biti manje ili jednake od trenutnog broja komada delova na polici sa koje trebujete", vbInformation
        Exit Sub
    End If
    
    If Nz(Me!KolicinaZaPrenos, 0) <> 0 And Nz(Me!NaLokaciju, 0) = 0 Then
        MsgBox "Niste izabrali policu na koju premeštate deo", vbInformation
        Exit Sub
    End If
    
    If CLng(Nz(Me!NaLokaciju, 0)) = CLng(Nz(Me!SaLokacije, 0)) Then
        MsgBox "Lokacije su iste i deo neæe biti premešten!!!", vbInformation
        Exit Sub
    Else
        If IzvrsiPrenosIliTrebovanjeDela Then
            Me!Podforma.Requery
            DoCmd.MoveSize , , Me.Width
        End If
    End If
    
Exit_Point:
    On Error Resume Next
    
Exit Sub

Err_Point:
    
    Resume Exit_Point

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

Private Function ProveriDefinisneKolicine(ByVal ProveraUnosaKolicina As Boolean) As Boolean
On Error GoTo Err_Point
    Dim pIDPostupka As Long
    Dim UkupnoKomada As Integer
    Dim retValOk As Boolean
    
    retValOk = True

    If ProveraUnosaKolicina Then
        UkupnoKomada = CLng(Nz(Forms![LokacijaNapravljenihDelovaZag]![Podforma].Form![UkupnaKolicina], 0))
                        'Nz(ADO_Lookup(CNN_CurrentDataBase, "UkupnoKomada", "SELECT SUM(Kolicina) as UkupnoKomada FROM tLokacijeDelova WHERE IDPostupka = " & stR(pIDPostupka)), 0)
        If UkupnoKomada <> CLng(Forms!LokacijaNapravljenihDelovaZag!KolicinaIskontrolisanihDelova) Then
            MsgBox "Niste definisali lokacije za dobar broj napravljenih delova!", vbInformation
            retValOk = False
        End If
    End If
    
Exit_Point:
    On Error Resume Next
    ProveriDefinisneKolicine = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "ProveriDefinisneKolicine"
    retValOk = False
    Resume Exit_Point
End Function
Public Function PrimeniUslove() As Boolean
    Me!Podforma.Requery
End Function

Private Sub DugmeZatvoriFormu_Click()
    If UserUGrupi(CurrentUser(), "Admins") Then
        DoCmd.Close acForm, "LokacijaNapravljenihDelovaZag"
    End If
End Sub


Private Sub Form_Open(Cancel As Integer)
    DoCmd.MoveSize , , 7820
    PrikaziObjekteZaMene
End Sub

Private Sub Form_Unload(Cancel As Integer)
    If ProveriDefinisneKolicine(Nz(Me!ProveraUnosaKolicina, False)) Then
    Else
        DoCmd.CancelEvent
    End If
End Sub

Private Sub IdentBroj_DblClick(Cancel As Integer)
    Me!IdentBroj = Null
    PrimeniUslove
End Sub
Public Sub PrikaziObjekteZaMene()
    If UserUGrupi(CurrentUser(), "Admins") Then
        Me!DugmeZatvoriFormu.Visible = True
    Else
        Me!DugmeZatvoriFormu.Visible = False
    End If
End Sub
Public Function DefinisiPodformu() As Boolean
    If Me!ProveraUnosaKolicina = True Then
        Me!Podforma.SourceObject = "LokacijaNapravljenihDelova"
    Else
        Me!Podforma.SourceObject = "LokacijaSvihNapravljenihDelovaPoRN"
    End If
    PrimeniUslove
End Function
Private Sub IDVrstaKvaliteta_DblClick(Cancel As Integer)
    Me!IDVrstaKvaliteta = Null
    PrimeniUslove
End Sub
Private Sub PrikaziCaptionZaPrenos()
On Error GoTo Err_Point

    Me!DugmeSaLokacijeNaLokaciju.Caption = "Sa lokacije" & vbCrLf & "[" & Me!SaLokacije.Column(1) & "]" & vbCrLf & _
                                        " premesti na lokaciju " & vbCrLf & "[" & Me!NaLokaciju.Column(1) & "]" & vbCrLf & _
                                        Me!KolicinaZaPrenos & " deo-la " & Me!NazivDela

Exit_Point:
    Exit Sub

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
    
End Sub
Public Function PostaviParametreZaPrenos() As Boolean
On Error GoTo Err_Point
    Dim frm As Form
    Dim subFrm As Form
    
    Set frm = Me
    Set subFrm = Forms![LokacijaNapravljenihDelovaZag]![Podforma].Form 'frm!Podforma.Form
    
    Me!KolicinaZaPrenos.Enabled = True
    Me!KolicinaZaPrenos = Forms![LokacijaNapravljenihDelovaZag]![Podforma].Form![UkKolicina]
    Me!KolicinaZaTrebovanje = 0
    Me!KolicinaZaTrebovanje.Enabled = False
    
    Me!SaLokacije = Null
    Me!SaLokacijeOpis = Null
    Me!NaLokaciju = Null
    Me!NaLokacijuOpis = Null
    
    Me!SaLokacije = Forms![LokacijaNapravljenihDelovaZag]![Podforma].Form![IDPozicija] 'subFrm!IDPozicije
    Me!SaLokacijeOpis = Forms![LokacijaNapravljenihDelovaZag]![Podforma].Form![IDPozicija]
    Me!SaLokacije.Requery
    Me!SaLokacijeOpis.Requery
    
    Me!NaLokaciju.Enabled = True
    Me!NaLokacijuOpis.Enabled = True
    Me!DugmeLokacijeDelova.Enabled = True
    Me!NaLokaciju.SetFocus
    Me!Label_Akcija.Caption = "Premesti"
    PrikaziCaptionZaPrenos
    
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "PostaviParametreZaPrenos"
 Resume Exit_Point
End Function

Private Sub KolicinaZaPrenos_AfterUpdate()
    PrikaziCaptionZaPrenos
    Me!DugmeSaLokacijeNaLokaciju.SetFocus
End Sub

Private Sub KolicinaZaTrebovanje_AfterUpdate()
    PrikaziCaptionZaTrebovanje
    Me!DugmeSaLokacijeNaLokaciju.SetFocus
End Sub

Private Sub NaLokaciju_AfterUpdate()
    
    Me!NaLokacijuOpis = Me!NaLokaciju
    Me!NaLokacijuOpis.Requery
    PrikaziCaptionZaPrenos

End Sub
Private Sub PrikaziCaptionZaTrebovanje()
On Error GoTo Err_Point

    Me!DugmeSaLokacijeNaLokaciju.Caption = "Sa lokacije" & vbCrLf & "[" & Me!SaLokacije.Column(1) & "]" & vbCrLf & " trebujete/ " & Srpski("cistite") & vbCrLf & Me!KolicinaZaTrebovanje & " komada dela " & Me!NazivDela

Exit_Point:
    Exit Sub

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
    
End Sub
Public Function PostaviParametreZaTrebovanje() As Boolean
On Error GoTo Err_Point
    Dim frm As Form
    Dim subFrm As Form
    
    Set frm = Me
    Set subFrm = Forms![LokacijaNapravljenihDelovaZag]![Podforma].Form 'frm!Podforma.Form
    
    Me!KolicinaZaPrenos = 0
    Me!KolicinaZaPrenos.Enabled = False
    Me!KolicinaZaTrebovanje.Enabled = True
    Me!KolicinaZaTrebovanje = Forms![LokacijaNapravljenihDelovaZag]![Podforma].Form![UkKolicina]
    
    Me!SaLokacije = Null
    Me!SaLokacijeOpis = Null
    Me!NaLokaciju = Null
    Me!NaLokacijuOpis = Null
    
    Me!SaLokacije = Forms![LokacijaNapravljenihDelovaZag]![Podforma].Form![IDPozicija] 'subFrm!IDPozicije
    Me!SaLokacijeOpis = Forms![LokacijaNapravljenihDelovaZag]![Podforma].Form![IDPozicija]
    Me!SaLokacije.Requery
    Me!SaLokacijeOpis.Requery
    
    Me!NaLokaciju.Enabled = False
    Me!NaLokacijuOpis.Enabled = False
    Me!DugmeLokacijeDelova.Enabled = False
    Me!KolicinaZaTrebovanje.Enabled = True
    Me!KolicinaZaTrebovanje.SetFocus
    Me!Label_Akcija.Caption = "Istrebuj/" & Srpski("Ocisti")
    PrikaziCaptionZaTrebovanje
    
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "PostaviParametreZaPrenos"
 Resume Exit_Point
End Function
Public Function IzvrsiPrenosIliTrebovanjeDela() As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim IdentBroj As String
    Dim IDRN As Long
    Dim IDPredmet As Long
    Dim IDVrstaKvaliteta As Long
    
    retValOk = True
    IdentBroj = Forms![LokacijaNapravljenihDelovaZag]![Podforma].Form![IdentBroj]
    IDVrstaKvaliteta = Forms![LokacijaNapravljenihDelovaZag]![Podforma].Form![IDVrstaKvaliteta]
    IDRN = Nz(ADO_Lookup(CNN_CurrentDataBase, "IDRN", "tRN", "[IdentBroj]='" & IdentBroj & "'"), 0)
    IDPredmet = Nz(ADO_Lookup(CNN_CurrentDataBase, "IDPredmet", "tRN", "[IDRN]=" & IDRN), 0)
    retValOk = ADO_ExecSP(CNN_CurrentDataBase, "spIzvrsiPrenosIliCiscenjeDelaSaLokacije", IDRN, IDPredmet, IDVrstaKvaliteta, Nz(Me!SaLokacije, 0), Nz(Me!NaLokaciju, 0), IIf(Me!KolicinaZaPrenos <> 0, Me!KolicinaZaPrenos, Me!KolicinaZaTrebovanje), IDRadnikZaCurrentUser(), IIf(Me!KolicinaZaPrenos <> 0, 1, 0), IIf(Me!KolicinaZaTrebovanje <> 0, 1, 0))
    
Exit_Point:
    On Error Resume Next
    IzvrsiPrenosIliTrebovanjeDela = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "IzvrsiPrenosIliTrebovanjeDela"
    retValOk = False
    Resume Exit_Point

End Function


Private Sub OtvoriNovuLokaciju(NoviPodatak As String, presponse As Integer)
    Dim screenWidth As Long
    Dim formWidth As Long
    
    Dim oldLeft As Long
    Dim MyForm As Form
    Dim MyControl As control
    
    ' Dobij širinu forme
    Set MyForm = Application.Forms("LokacijaNapravljenihDelovaZag")
    Set MyControl = MyForm![NaLokaciju]
    
    formWidth = Me.WindowWidth
    
    ' Postavi poziciju forme
    oldLeft = Me.WindowLeft
    Me.Move oldLeft + formWidth, Me.WindowTop, formWidth, Me.WindowHeight
    DoCmd.OpenForm "frmPozicije"
    Forms!frmPozicije.SetFocus
    Forms!frmPozicije.NoviSlog
    Forms!frmPozicije!Pozicija = Nz(NoviPodatak, "")
     While IsLoaded("frmPozicije")
        DoEvents
    Wend
    
    MyForm.SetFocus
    Me.Move oldLeft, Me.WindowTop, formWidth, Me.WindowHeight
    'Forms!LokacijaNapravljenihDelovaZag.SetFocus
    MyForm.SetFocus
    On Error Resume Next
    Forms!LokacijaNapravljenihDelovaZag!NaLokaciju.Requery
    'DugmeNaLokacijuRequery_Click
    Forms![LokacijaNapravljenihDelovaZag]![Podforma].Form![IDPozicija].Requery
    Forms![LokacijaNapravljenihDelovaZag]![Podforma].Form![IDPozicijaOpis].Requery
    
    presponse = acDataErrContinue
End Sub
