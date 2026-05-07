VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PregledPoPostupcima_SviZapocetiPostupci"
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
On Error GoTo Err_DugmePrikaziSkicu_Click

    Dim stDocName As String
    Dim stLinkCriteria As String
    If Me!RJgrupaRC Like "8.4" Or Me!RJgrupaRC Like "8.3" Then
        Set BBTehn = Nothing
        BBTehn.IDPostupka = Me!IDPostupka
        BBTehn.IdentBroj = Me![IdentBroj]
        BBTehn.Operacija = Me!Operacija
        BBTehn.RJgrupaRC = Me!RJgrupaRC
        
        If Nz(Me!IDPostupka, 0) <> 0 Then
            DefinisiPrikaziDokumentaciju Me!IDPostupka, Me![IdentBroj], Me!Operacija
        Else
            MsgBox "Ne postoji definisana operacija za koju želite da definišete dokumentaciju!", vbInformation
        End If
    Else
        MsgBox "Za definisana operacija ne možete da definišete dokumentaciju!", vbInformation
    End If
    
Exit_DugmePrikaziSkicu_Click:
    Exit Sub

Err_DugmePrikaziSkicu_Click:
    MsgBox err.Description
    Resume Exit_DugmePrikaziSkicu_Click
End Sub

Private Sub DugmeObrisiPostupak_Click()
    ZaIDPostupkaDeletettTehPostupak Me!IDPostupka
    PrimeniUslove
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
