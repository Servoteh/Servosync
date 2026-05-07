VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PregledDelovaPoLokacijama"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Dim aktivnaForma As Form
Dim aktivanreport As Report
Dim aktivnaKontrola  As control
Public Function PrimeniUslove()
   BBTimerStart
    SetProperlyRecordSource BBCFG.CNNString, Me
   Me!LabelTrajanjeUpita.Caption = BBTimerTrajanjeSec("Query=")
   'Call TrebaPrimenitiUslove(vbBlack)
End Function
Private Function TrebaPrimenitiUslove(Optional lColor) As Boolean
Dim retVal As Boolean

If Not IsMissing(lColor) Then
    Me!DugmePrimeniUslove.ForeColor = lColor
End If
  retVal = (Me!DugmePrimeniUslove.ForeColor = vbRed)
  TrebaPrimenitiUslove = retVal
End Function


Private Sub BrojCrteza_DblClick(Cancel As Integer)
    Me!ZaBrCrteza = Me!BrojCrteza
    PrimeniUslove
End Sub

Private Sub BrojPredmeta_DblClick(Cancel As Integer)
    Me!ZaPredmet = Me!IDPredmet
    PrimeniUslove
End Sub
Private Sub DimenzijaMaterijala_DblClick(Cancel As Integer)
    Me!ZaDimMaterijala = Me!DimenzijaMaterijala
    PrimeniUslove
End Sub

Private Sub DoDatumaNaloga_DblClick(Cancel As Integer)
    Call PopupCalendar(Screen.ActiveControl)
End Sub
Private Sub DugmeKarticaPostupka_Click()
    KarticaLokacijaDela Nz(Me!IDPredmet, 0), Nz(Me!BrojCrteza, "")
End Sub

Private Sub DugmeLokacijaNapravljenihDelova_Click()
    OtvoriFormuZaLokacijuDelova Me!IDPredmet, Me!Komada, False, False, IDRadnikZaCurrentUser(), Me!IDRN, "LokacijaSvihNapravljenihDelovaPoRN"
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
Private Sub DugmeDetaljnoPostupak_Click()
On Error GoTo Err_DugmeDetaljnoPostupak_Click

    PrikaziDokRN Me![IDRN]
    
Exit_DugmeDetaljnoPostupak_Click:
    Exit Sub

Err_DugmeDetaljnoPostupak_Click:
    MsgBox err.Description
    Resume Exit_DugmeDetaljnoPostupak_Click
    
End Sub
Private Sub Form_Open(Cancel As Integer)
    DoCmd.Maximize
    If IsLoaded("Prva maskaMagacin") Then
        Me!DugmeDetaljnoPostupak.Enabled = False
        Me!DugmekarticaPostupka.Enabled = False
    Else
        Me!DugmeDetaljnoPostupak.Enabled = True
        Me!DugmekarticaPostupka.Enabled = True
    End If
    PrimeniUslove
    'Debug.Print Me.FormHeader.BackColor
End Sub

Private Sub IdentBroj_DblClick(Cancel As Integer)
    Me!ZaIdentBroj = Me!IdentBroj
    PrimeniUslove
End Sub

Private Sub Materijal_DblClick(Cancel As Integer)
    Me!ZaMaterijal = Me!Materijal
    PrimeniUslove
End Sub

Private Sub Naziv_DblClick(Cancel As Integer)
    Me!ZaKomitenta = Me!SifraKomitenta
    PrimeniUslove
End Sub

Private Sub NazivDela_DblClick(Cancel As Integer)
    Me!ZaNazivDela = Me!NazivDela
    PrimeniUslove
End Sub

Private Sub OdDatumaNaloga_DblClick(Cancel As Integer)
    Call PopupCalendar(Screen.ActiveControl)
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



