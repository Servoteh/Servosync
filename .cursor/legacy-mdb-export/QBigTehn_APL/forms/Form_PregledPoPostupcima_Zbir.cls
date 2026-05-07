VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PregledPoPostupcima_Zbir"
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



Private Sub DugmeIspravke_Click()
On Error GoTo Err_DugmeKarticaPostupka_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "BarKod_Ispravka"
    If Me!IDTehPostupka <> 0 Then
        stLinkCriteria = "[IDPostupka]=" & Me![IDTehPostupka]
        DoCmd.OpenForm stDocName, , , stLinkCriteria
    Else
        MsgBox "Nema unosa postupka po ovom nalogu!!!"
    End If
    
Exit_DugmeKarticaPostupka_Click:
    Exit Sub

Err_DugmeKarticaPostupka_Click:
    MsgBox err.Description
    Resume Exit_DugmeKarticaPostupka_Click

End Sub

Private Sub Form_Load()
    PrimeniUslove
End Sub

Private Sub IdentBroj_DblClick(Cancel As Integer)
    Forms![PregledPoPostupcima]!ZaIdentBroj = Me!IdentBroj
    PrimeniUslove
End Sub

Private Sub Napomena_DblClick(Cancel As Integer)
On Error GoTo Err_ComboOpis_DblClick

    Dim stDocName As String
    Dim stLinkCriteria As String
     
    Set BBTehn = Nothing
    BBTehn.IDPostupka = Nz(Me!IDTehPostupka, 0)
    
    If BBTehn.IDPostupka <> 0 Then
        stDocName = "MemoPromena"
        DoCmd.OpenForm stDocName, , , stLinkCriteria
    Else
        MsgBox "Ne postoji evidentirani unos po ovoj operaciji"
    End If
    
Exit_ComboOpis_DblClick:
    Exit Sub

Err_ComboOpis_DblClick:
    MsgBox err.Description
    Resume Exit_ComboOpis_DblClick

End Sub

Private Sub Naziv_DblClick(Cancel As Integer)
    Forms![PregledPoPostupcima]!ZaKomitenta = Me!SifraKomitenta
    PrimeniUslove
End Sub

Private Sub RJgrupaRC_DblClick(Cancel As Integer)
    Forms![PregledPoPostupcima]!ZaRJgrupaRC = Me!RJgrupaRC
    PrimeniUslove
End Sub

