VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PregledPoPredmetima"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Dim aktivnaForma As Form
Dim aktivanreport As Report
Dim aktivnaKontrola  As control
Private pstSourceObject As String
Private Function TrebaPrimenitiUslove(Optional lColor) As Boolean
   TrebaPrimenitiUslove = F_TrebaPrimenitiUslove(lColor, Me, Me!DugmePrimeniUslove)
End Function
Public Sub PostaviDefaultDatume(frm As Form)
    On Error Resume Next
    
    '=== Za naloge ===
    If IsNull(frm!OdDatumaNaloga) Or frm!OdDatumaNaloga = "" Then
        frm!OdDatumaNaloga = #1/1/1900#
    End If
    
    If IsNull(frm!DoDatumaNaloga) Or frm!DoDatumaNaloga = "" Then
        frm!DoDatumaNaloga = #12/31/2999#
    End If

    '=== Za predmete ===
    If IsNull(frm!OdDatumaPredmeta) Or frm!OdDatumaPredmeta = "" Then
        frm!OdDatumaPredmeta = #1/1/1900#
    End If
    
    If IsNull(frm!DoDatumaPredmeta) Or frm!DoDatumaPredmeta = "" Then
        frm!DoDatumaPredmeta = #12/31/2999#
    End If
End Sub

Public Function PrimeniUslove(Optional stSourceObject)
On Error GoTo Err_Point
    Dim prikaziInfo As Boolean
    
    Call PostaviDefaultDatume(Me)
    'ReklamniPanel
    
    If IsMissing(stSourceObject) Then
       stSourceObject = pstSourceObject
    Else
       pstSourceObject = stSourceObject
    End If
    Me!Podforma.SourceObject = stSourceObject
    
    If stSourceObject <> "ReklamniPanel" Then
    
        DoEvents     ' kljuèno – pusti Access da kreira praznu podformu
        prikaziInfo = (stSourceObject = "PregledTehnoloskihPostupaka")
        PrikaziInfoOStrani prikaziInfo
        
        Me!Podforma.Form.NapuniPodformu
    
        F_TrebaPrimenitiUslove vbBlack, Me, Me!DugmePrimeniUslove
    End If
    
Exit_Point:
    On Error Resume Next
    Exit Function
    
Err_Point:
    BBErrorMSG err, "PrimeniUslove"
    Resume Exit_Point
End Function
Public Function PrimeniUslovePrioritet(Optional stSourceObject)
On Error GoTo Err_Point
    Dim prikaziInfo As Boolean
    Call PostaviDefaultDatume(Me)
    
    If IsMissing(stSourceObject) Then
       stSourceObject = pstSourceObject
    Else
       pstSourceObject = stSourceObject
    End If
    Me!Podforma.SourceObject = stSourceObject
    If stSourceObject <> "ReklamniPanel" Then
        DoEvents
        prikaziInfo = (stSourceObject = "PregledTehnoloskihPostupaka")
        PrikaziInfoOStrani prikaziInfo
        F_TrebaPrimenitiUslove vbBlack, Me, Me!DugmePrimeniUslove
    End If
Exit_Point:
    On Error Resume Next
    Exit Function
    
Err_Point:
    BBErrorMSG err, "PrimeniUslove"
    Resume Exit_Point
End Function
Private Sub DoDatumaNaloga_DblClick(Cancel As Integer)
    Call PopupCalendar(Screen.ActiveControl)
End Sub

Private Sub DoDatumaPredmeta_DblClick(Cancel As Integer)
    Call PopupCalendar(Screen.ActiveControl)
End Sub

Private Sub DugmeKarticaPostupka_Click()
    KarticaTehnoloskogPostupka Me.Podforma!IDRN
End Sub

Private Sub DugmeLokacijaNapravljenihDelova_Click()
    OtvoriFormuZaLokacijuDelova Me.Podforma!IDPredmet, Me.Podforma!Komada, False, False, IDRadnikZaCurrentUser(), Me.Podforma!IDRN, "LokacijaSvihNapravljenihDelovaPoRN"
End Sub

Private Sub DugmePrimeniUslove_Click()
    PrimeniUslove
End Sub

Private Sub DugmePrint_Click()
    PreviewPDFCrtez_Binary
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
Private Sub DugmeDetaljnoPostupak_Click()
On Error GoTo Err_DugmeDetaljnoPostupak_Click

    'DetaljnoPostupak Me.Podforma![IDRN]
    PrikaziDokRN Me.Podforma![IDRN]
Exit_DugmeDetaljnoPostupak_Click:
    Exit Sub

Err_DugmeDetaljnoPostupak_Click:
    MsgBox err.Description
    Resume Exit_DugmeDetaljnoPostupak_Click
    
End Sub

Private Sub Form_Open(Cancel As Integer)
    'DoCmd.Maximize
    'PrimeniUslove
    
    pstSourceObject = "ReklamniPanel"
    'Call BB_PravaPristupaPodesiFormu(Me)
    
    'PostaviKomboPolja
    Me!ZaStatusPrimopredaje = F_RN_IDStatusDefLansiran()
    Me!ZaStatusPrimopredaje.Requery
    Me!PageNumber = 1
    Me!PageSize = 200
    
    DoCmd.GoToControl "OdDatumaNaloga"
    TrebaPrimenitiUslove (255)
    
    
End Sub

Private Sub OdDatumaNaloga_DblClick(Cancel As Integer)
    Call PopupCalendar(Screen.ActiveControl)
End Sub


Private Sub OdDatumaPredmeta_DblClick(Cancel As Integer)
    Call PopupCalendar(Screen.ActiveControl)
End Sub

Private Sub ZaBrCrteza_GotFocus()
    Me!ZaBrCrteza.Requery
End Sub

Private Sub ZaIdentBroj_DblClick(Cancel As Integer)
    ObrisiVrednostKontrole
End Sub


Public Function PrimeniUslovePosleBrisanjaVrednosti()
    ObrisiVrednostKontrole
End Function

Private Sub ZaIdentBroj_GotFocus()
    Me!ZaIdentBroj.Requery
End Sub

Private Sub ZaPredmet_DblClick(Cancel As Integer)
    ObrisiVrednostKontrole
End Sub
Private Sub DugmeObrisiNalog_Click()
On Error GoTo Err_DugmeObrisiNalog_Click

    Dim stDocName As String
    Dim answer As Variant
    Dim retValOk As Boolean
    retValOk = True
    Dim pZakljucano As Boolean
    Dim pZaIDRN As Long
    
    retValOk = True
    pZakljucano = Nz(ADO_Lookup(CNN_CurrentDataBase, "Zakljucano", "tRN", "[IDRN]=" & Me!IDRN), False)
    If pZakljucano Then
        MsgBox "Nalog je " & Srpski("zakljucan")
        Exit Sub
    End If
    
    If NalogPostojiUTehPostupku(CLng(Me!IDRN)) Then
        MsgBox "Po ovom nalogu je " & Srpski("zapoceta") & " proizvodnja i ne " & Srpski("moze") & " se brisati!", vbExclamation, "QBigTehn"
        Exit Sub
    End If
    If IsNumeric(Me!IDRN) Then
        answer = MsgBox("Ovim brišete kompletni oznaèeni postupak!!!" & Chr(13) & " Da li nastavljate BRISANJE?", vbYesNo + vbCritical + vbDefaultButton2, "Brisanje radnog naloga")
        If answer = vbYes Then
        
            'retValOk = retValOk And ZaIDRNDeletetPDM(Me!IDRN)
            'retValOk = retValOk And ZaIDRNDeletetPLP(Me!IDRN)
            'retValOk = retValOk And ZaIDRNDeletetPND(Me!IDRN)
            'retValOk = retValOk And ZaIDRNDeletetStavkeRN(Me!IDRN)
            'retValOk = retValOk And ZaIDRNDeletetRN(Me!IDRN)
            retValOk = ADO_ExecSP(CNN_CurrentDataBase, "spObrisiKompletanNalog", Me!IDRN)
            
        End If
    End If
    
Exit_DugmeObrisiNalog_Click:
    If retValOk Then PrimeniUslove
    Exit Sub

Err_DugmeObrisiNalog_Click:
    MsgBox err.Description
    retValOk = False
    Resume Exit_DugmeObrisiNalog_Click
    
End Sub


Private Sub ZaBrCrteza_DblClick(Cancel As Integer)
    ObrisiVrednostKontrole
End Sub

Private Sub ZaNazivDela_DblClick(Cancel As Integer)
    ObrisiVrednostKontrole
End Sub

Private Sub ZaMaterijal_DblClick(Cancel As Integer)
    ObrisiVrednostKontrole
End Sub


Private Sub ZaDimMaterijala_DblClick(Cancel As Integer)
    ObrisiVrednostKontrole
End Sub
Private Sub Obrisi_DoDatumaNaloga_Click()
    ObrisiVrednostPrethodneKontrole
End Sub

Private Sub Obrisi_DoDatumaPredmeta_Click()
    ObrisiVrednostPrethodneKontrole
End Sub

Private Sub Obrisi_OdDatumaNaloga_Click()
    ObrisiVrednostPrethodneKontrole
End Sub

Private Sub Obrisi_OdDatumaPredmeta_Click()
    ObrisiVrednostPrethodneKontrole
End Sub

Private Sub ZaVezaSa_GotFocus()
    Me!ZaVezaSa.Requery
End Sub
Private Sub cmdSledecaStrana_Click()
    Me!PageNumber = Nz(Me!PageNumber, 1) + 1
    Call PrimeniUslove
    
End Sub
Private Sub cmdPrethodnaStrana_Click()
    Dim p As Long
    p = Nz(Me!PageNumber, 1)

    If p > 1 Then
        Me!PageNumber = p - 1
        Call PrimeniUslove
        
    End If
End Sub
Public Sub PrikaziInfoOStrani(ByVal Prikazi As Boolean)
On Error GoTo Err_Point

    Dim ukSlogova As Long
    Dim ukStrana As Long
    Dim page As Long
    Dim PageSize As Long
    
    If Prikazi Then
        Me!cmdPrethodnaStrana.Visible = True
        Me!cmdSledecaStrana.Visible = True
        Me!lblStranaInfo.Visible = True
        
        page = Nz(Me!PageNumber, 1)
        PageSize = Nz(Me!PageSize, 200)
    
        ' === generiši EXEC spPregledRNPoPredmetima_Count ... ===
       
        ukSlogova = Nz(ADO_GetValFromScalar(CNN_CurrentDataBase, "fsPregledRNPoPredmetima_Count", _
                                Forms![PregledPoPredmetima]![OdDatumaNaloga].Value, _
                                Forms![PregledPoPredmetima]![DoDatumaNaloga].Value, _
                                Forms![PregledPoPredmetima]![OdDatumaPredmeta].Value, _
                                Forms![PregledPoPredmetima]![DoDatumaPredmeta].Value, _
                                Forms![PregledPoPredmetima]![ZaIdentBroj].Value, _
                                Forms![PregledPoPredmetima]![ZaPredmet].Value, _
                                Forms![PregledPoPredmetima]![ZaKomitenta].Value, _
                                Forms![PregledPoPredmetima]![LansiranRN].Value, _
                                Forms![PregledPoPredmetima]![ZaBrCrteza].Value, _
                                Forms![PregledPoPredmetima]![ZaNazivDela].Value, _
                                Forms![PregledPoPredmetima]![ZaMaterijal].Value, _
                                Forms![PregledPoPredmetima]![ZaDimMaterijala].Value, _
                                Forms![PregledPoPredmetima]![SaglasanRN].Value, _
                                Forms![PregledPoPredmetima]![ZaVezaSa].Value, _
                                Forms![PregledPoPredmetima]![ZaIDVrstaKvaliteta].Value, _
                                Forms![PregledPoPredmetima]![StatusRN].Value, _
                                Forms![PregledPoPredmetima]![ZaVarijanta].Value, _
                                Forms![PregledPoPredmetima]![ZaRevizija].Value, _
                                Forms![PregledPoPredmetima]![ZaStatusPrimopredaje].Value), 0)
        ' === izvrši COUNT ===
        'ukSlogova = Nz(ADO_Lookup(CNN_CurrentDataBase(), "TotalCount", sqlTotal), 0)
    
        ' === izraèunaj ukupan broj strana (ceiling) ===
        If PageSize > 0 Then
            ukStrana = (ukSlogova + PageSize - 1) \ PageSize
        Else
            ukStrana = 1
        End If
    
        ' === prikaži info ===
        'Me!lblStranaInfo.Caption = _
            "Strana " & page & " / " & ukStrana & _
            " (ukupno " & ukSlogova & " radnih naloga)"
        Me!lblStranaInfo.Caption = _
            page & " / " & ukStrana & _
            " (ukupno " & ukSlogova & ")"
    Else
        Me!cmdPrethodnaStrana.Visible = False
        Me!cmdSledecaStrana.Visible = False
        Me!lblStranaInfo.Visible = False
    End If
Exit_Point:
    Exit Sub

Err_Point:
    BBErrorMSG err, "PrikaziInfoOStrani"
    Resume Exit_Point
End Sub

