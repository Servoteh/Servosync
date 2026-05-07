VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PregledPoPostupcima"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Function TrebaPrimenitiUslove(Optional lColor) As Boolean
Dim retVal As Boolean

If Not IsMissing(lColor) Then
    Me!DugmePrimeniUslove.ForeColor = lColor
End If
  retVal = (Me!DugmePrimeniUslove.ForeColor = vbRed)
  TrebaPrimenitiUslove = retVal
End Function
Public Function PrimeniUslove()
On Error GoTo Err_PrimeniUslove
    
    'If PitanjeZaVelikiPeriod() Then
        FrameIzvestaji_AfterUpdate
        TrebaPrimenitiUslove vbBlack
    'End If
Exit_PrimeniUslove:
    Exit Function

Err_PrimeniUslove:
    MsgBox Error$
    Resume Exit_PrimeniUslove
    
End Function
Private Sub DoDatumaPostupka_DblClick(Cancel As Integer)
    Call PopupCalendar(Screen.ActiveControl)
    TrebaPrimenitiUslove (255)
    DoCmd.GoToControl "OdDatumaPostupkaKraj"
End Sub

Private Sub DoDatumaPostupkaKraj_DblClick(Cancel As Integer)
    Call PopupCalendar(Screen.ActiveControl)
    TrebaPrimenitiUslove (255)
    'DoCmd.GoToControl "DoDatumaPostupka"
End Sub


Private Sub DugmePrimeniUslove_Click()
    PrimeniUslove
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

Private Sub Form_Close()
    If Not IsLoaded("Prva maska") And Not IsLoaded("QPrvaMaska") Then
        DoCmd.OpenForm "ReklamniPanel_LogIn"
    End If
End Sub

Private Sub Form_Open(Cancel As Integer)
    DoCmd.Maximize
    Me!OdDatumaNaloga = DateAdd("d", -F_MaxDanaZaPeriodNaloga(), Date)
    Me!CheckDiV = True
End Sub

Private Sub FrameIzvestaji_AfterUpdate()
    If Me!FrameIzvestaji = 1 Then
        Me!Podforma.SourceObject = "PregledPoPostupcima_Zbir"
        PodesiFilterZavrsenStampu (False)
        PodesiFilterZaPrikazZapocetihPostupaka (True)
    ElseIf Me!FrameIzvestaji = 2 Then
        Me!Podforma.SourceObject = "PregledPoPostupcima_ZbirGrupno"
        PodesiFilterZavrsenStampu (False)
        PodesiFilterZaPrikazZapocetihPostupaka (True)
    ElseIf Me!FrameIzvestaji = 3 Then
        Me!Podforma.SourceObject = "PregledPoPostupcima_LoseEvidentirani"
        PodesiFilterZavrsenStampu (False)
        PodesiFilterZaPrikazZapocetihPostupaka (True)
     ElseIf Me!FrameIzvestaji = 4 Then
        Me!Podforma.SourceObject = "PregledPoPostupcima_SviZapocetiPostupci"
        PodesiFilterZavrsenStampu (False)
        PodesiFilterZaPrikazZapocetihPostupaka (False)
    ElseIf Me!FrameIzvestaji = 5 Then
        Me!Podforma.SourceObject = "PregledPostupakaSaDokumentacijom"
        PodesiFilterZavrsenStampu (False)
        PodesiFilterZaPrikazZapocetihPostupaka False
        Me!ZaKomitenta.Enabled = False
    ElseIf Me!FrameIzvestaji = 6 Then
        Me!Podforma.SourceObject = ""
    Else
        Me!Podforma.SourceObject = "ReklamniPanel"
    End If
End Sub

Private Sub Obrisi_DoDatumaNaloga_Click()
    ObrisiVrednostPrethodneKontrole
End Sub

Private Sub Obrisi_DoDatumaPostupka_Click()
    ObrisiVrednostPrethodneKontrole
End Sub

Private Sub Obrisi_DoDatumaPostupkaKraj_Click()
    ObrisiVrednostPrethodneKontrole
End Sub





Private Sub Obrisi_OdDatumaNaloga_Click()
    ObrisiVrednostPrethodneKontrole
End Sub

Private Sub Obrisi_OdDatumaPostupka_Click()
    ObrisiVrednostPrethodneKontrole
End Sub

Private Sub Obrisi_OdDatumaPostupkaKraj_Click()
    ObrisiVrednostPrethodneKontrole
End Sub


Private Sub OdDatumaPostupka_DblClick(Cancel As Integer)
    Call PopupCalendar(Screen.ActiveControl)
    TrebaPrimenitiUslove (255)
    DoCmd.GoToControl "DoDatumaPostupka"
End Sub

Private Sub OdDatumaPostupkaKraj_Click()
    Call PopupCalendar(Screen.ActiveControl)
    TrebaPrimenitiUslove (255)
    DoCmd.GoToControl "DoDatumaPostupkaKraj"
End Sub





Private Sub ZaBrojCrteza_DblClick(Cancel As Integer)
    ObrisiVrednostKontrole
End Sub

Private Sub ZaIdentBroj_AfterUpdate()
    TrebaPrimenitiUslove (255)
End Sub

Private Sub ZaIdentBroj_DblClick(Cancel As Integer)
    ObrisiVrednostKontrole
End Sub

Private Sub ZaIdentBroj_GotFocus()
    Me!ZaIdentBroj.Requery
End Sub

Private Sub ZaKomitenta_AfterUpdate()
    TrebaPrimenitiUslove (255)
End Sub

Private Sub ZaKomitenta_DblClick(Cancel As Integer)
    ObrisiVrednostKontrole
End Sub

Private Sub ZaKriticnost_DblClick(Cancel As Integer)
    ObrisiVrednostKontrole
End Sub

Private Sub ZaKvalitetDela_DblClick(Cancel As Integer)
    ObrisiVrednostKontrole
End Sub

Private Sub ZaPredmet_AfterUpdate()
    TrebaPrimenitiUslove (255)
End Sub

Private Sub ZaPredmet_DblClick(Cancel As Integer)
    ObrisiVrednostKontrole
End Sub

Private Sub ZaRadnika_AfterUpdate()
    TrebaPrimenitiUslove (255)
End Sub

Private Sub ZaRadnika_DblClick(Cancel As Integer)
    ObrisiVrednostKontrole
End Sub

Private Sub ZaRJgrupaRC_AfterUpdate()
    TrebaPrimenitiUslove (255)
End Sub

Private Sub ZaRJgrupaRC_DblClick(Cancel As Integer)
    ObrisiVrednostKontrole
End Sub

Private Sub ZaTipGreske_DblClick(Cancel As Integer)
    ObrisiVrednostKontrole
End Sub

Private Sub ZaVarijanta_GotFocus()
    Me!ZaVarijanta.Requery
End Sub

Private Sub ZavrsenPostupak_AfterUpdate()
    TrebaPrimenitiUslove (255)
End Sub
Private Sub DugmeKarticaPostupka_Click()
On Error GoTo Err_DugmeKarticaPostupka_Click

    KarticaTehnoloskogPostupka Me!Podforma![IDRN]

Exit_DugmeKarticaPostupka_Click:
    Exit Sub

Err_DugmeKarticaPostupka_Click:
    MsgBox err.Description
    Resume Exit_DugmeKarticaPostupka_Click
    
End Sub
Private Sub OdDatumaNaloga_AfterUpdate()
    TrebaPrimenitiUslove (255)
    DoCmd.GoToControl "DoDatumaNaloga"
End Sub

Private Sub OdDatumaNaloga_DblClick(Cancel As Integer)
    'Me!OdDatumaPredmeta = Null
    'TrebaPrimenitiUslove (255)
    Call PopupCalendar(Screen.ActiveControl)
    OdDatumaNaloga_AfterUpdate
End Sub
Private Sub DoDatumaNaloga_AfterUpdate()
    TrebaPrimenitiUslove (255)
    DoCmd.GoToControl "ZaPredmet"
End Sub

Private Sub DoDatumaNaloga_DblClick(Cancel As Integer)
    'Me!OdDatumaPredmeta = Null
    'TrebaPrimenitiUslove (255)
    Call PopupCalendar(Screen.ActiveControl)
    DoDatumaNaloga_AfterUpdate
End Sub

Public Sub PodesiFiltereDatuma(i As Integer)
    Me!OdDatumaPostupka.Left = Me!OdDatumaPostupka.Left + i
    Me!DoDatumaPostupka.Left = Me!DoDatumaPostupka.Left + i
    Me!Obrisi_OdDatumaPostupka.Left = Me!Obrisi_OdDatumaPostupka.Left + i
    Me!Obrisi_DoDatumaPostupka.Left = Me!Obrisi_DoDatumaPostupka.Left + i
    Me!OdDatumaPostupkaKraj.Left = Me!OdDatumaPostupkaKraj.Left + i
    Me!DoDatumaPostupkaKraj.Left = Me!DoDatumaPostupkaKraj.Left + i
    Me!Obrisi_OdDatumaPostupkaKraj.Left = Me!Obrisi_OdDatumaPostupkaKraj.Left + i
    Me!Obrisi_DoDatumaPostupkaKraj.Left = Me!Obrisi_DoDatumaPostupkaKraj.Left + i
    Me!LabelOdDatumaPostupka.Left = Me!LabelOdDatumaPostupka.Left + i
    Me!LabelOdDatumaPostupkaKraj.Left = Me!LabelOdDatumaPostupkaKraj.Left + i
End Sub
Private Sub DugmePrintZbirno_Click()
On Error GoTo Err_DugmePrintZbirno_Click

    Dim stDocName As String

    stDocName = "PregledPoPostupcima_Zbir"
    DoCmd.OpenReport stDocName, acPreview

Exit_DugmePrintZbirno_Click:
    Exit Sub

Err_DugmePrintZbirno_Click:
    MsgBox err.Description
    Resume Exit_DugmePrintZbirno_Click
    
End Sub
Private Sub DugmeDetaljnoNalog_Click()
On Error GoTo Err_DugmeDetaljnoNalog_Click

        
    'DetaljnoPostupak Me!Podforma![IDRN]
    PrikaziDokRN Me.Podforma![IDRN]

Exit_DugmeDetaljnoNalog_Click:
    Exit Sub

Err_DugmeDetaljnoNalog_Click:
    MsgBox err.Description
    Resume Exit_DugmeDetaljnoNalog_Click
    
End Sub

Public Sub PodesiFilterZavrsenStampu(Prikazi As Boolean)
    'Me!ZavrsenPostupak.Visible = Prikazi
    'Me!Label_ZavrsenPosao.Visible = Prikazi
    Me!DugmePrintZbirno.Visible = Prikazi
    'Me!TretiraniPostupci.Visible = Prikazi
    'Me!LabelTretiraniPostupci.Visible = Prikazi
End Sub
Private Function PitanjeZaVelikiPeriod() As Boolean
On Error GoTo Err_Point

Dim retValOk As Boolean
Dim stPoruka As String
Dim ZaGodinu As Integer
Dim OdDat As Date, DoDat As Date
Dim MaxDana As Integer


retValOk = True

If Me!OdDatumaNaloga.Enabled = False Then
    PitanjeZaVelikiPeriod = retValOk
    Exit Function
End If


ZaGodinu = Year(Date)

If IsDate(Me![OdDatumaNaloga]) Then
  OdDat = Nz(Me![OdDatumaNaloga], F_OdDatuma(ZaGodinu))
Else
    OdDat = F_OdDatuma(ZaGodinu)
End If

DoDat = Nz(Me![DoDatumaNaloga], F_DoDatuma(ZaGodinu))

    MaxDana = F_MaxDanaZaPeriodNaloga()

If DateDiff("d", OdDat, DoDat) > MaxDana Then
   stPoruka = ""
   stPoruka = stPoruka & "Interval koji ste izabrali je dosta veliki" & vbCrLf
   stPoruka = stPoruka & "i zahtevani proces može dugo da traje." & vbCrLf
   stPoruka = stPoruka & "(možda je bolje rešenje da podelite period na manje intervale)" & vbCrLf & vbCrLf
   
   stPoruka = stPoruka & "Da li zaista želite da nastavite?" & vbCrLf
   If Not BBPitanje(stPoruka, vbCritical + vbDefaultButton2) Then
        retValOk = False
   End If
End If

Exit_Point:
 On Error Resume Next
       PitanjeZaVelikiPeriod = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "PitanjeZaVelikiPeriod"
 retValOk = False
 Resume Exit_Point
End Function
Public Sub PodesiFilterZaPrikazZapocetihPostupaka(Prikazi As Boolean)
    Me!OdDatumaNaloga.Enabled = Prikazi
    Me!DoDatumaNaloga.Enabled = Prikazi
   
    Me!ZavrsenPostupak.Visible = Not Prikazi
    Me!Label_ZavrsenPosao.Visible = Not Prikazi
    If Prikazi Then
        Me!ZaKvalitetDela = Null
    End If
    Me!ZaKvalitetDela.Enabled = Not Prikazi
    
End Sub
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

