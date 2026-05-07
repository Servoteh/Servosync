VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PregledPostupakaSaDokumentacijom"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Function PrimeniUslove()
   BBTimerStart
    SetProperlyRecordSource BBCFG.CNNString, Me
   Me!LabelTrajanjeUpita.Caption = BBTimerTrajanjeSec("Query=")
End Function

Private Sub BrojPredmeta_DblClick(Cancel As Integer)
    Forms![PregledPoPostupcima]!ZaPredmet = Me!IDPredmet
    PrimeniUslove
End Sub

Private Sub DugmeDokumenatacija_Click()
On Error GoTo Err_DugmeRecalc_Click
    
    If Not IsNull(Me!LinkFajla) Then
        RunIt (Me!LinkFajla)
    End If
    
Exit_DugmeRecalc_Click:
    Exit Sub

Err_DugmeRecalc_Click:
    MsgBox err.Description
    Resume Exit_DugmeRecalc_Click
End Sub
Private Sub Form_Load()
    PrimeniUslove
End Sub

Private Sub IdentBroj_DblClick(Cancel As Integer)
    Forms![PregledPoPostupcima]!ZaIdentBroj = Me!IdentBroj
    PrimeniUslove
End Sub
Private Sub Naziv_DblClick(Cancel As Integer)
    Forms![PregledPoPostupcima]!ZaKomitenta = Me!SifraKomitenta
    PrimeniUslove
End Sub

Private Sub RJgrupaRC_DblClick(Cancel As Integer)
    Forms![PregledPoPostupcima]!ZaRJgrupaRC = Me!RJgrupaRC
    PrimeniUslove
End Sub
