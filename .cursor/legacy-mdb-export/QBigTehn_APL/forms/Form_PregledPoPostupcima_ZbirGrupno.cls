VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PregledPoPostupcima_ZbirGrupno"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Public Function PrimeniUslove()
  SetProperlyRecordSource BBCFG.CNNString, Me
  PrikaziTotale
End Function
Private Function SumRST(stImeKolone As String) As Double
 Dim rs As Object
 Dim Total As Double

    Total = 0
    Set rs = Me.Recordset.Clone
 
 While Not rs.EOF
  Total = Total + Nz(rs(stImeKolone).Value, 0)
  rs.MoveNext
 Wend
 SumRST = Total
End Function
Private Function PrikaziTotale()
On Error GoTo Err_Point
  
  Me!UkDaniURadu = Round(SumRST("SumOfDani"), 4)
  Me!UkSatiURadu = Round(SumRST("SumOfSati"), 4)
  Me!UkMinutiURadu = Round(SumRST("SumOfMinuti"), 4)
  Me!UkVremeSatiIzracunato = Round(SumRST("SumOfVremeUSekundama"), 4) / 3600
  Me!UkSatiNormirano = Round(SumRST("UkVreme"), 4)
  Me!UkRazlika = Round(Round(Round(SumRST("SumOfVremeUSekundama"), 4) / 3600, 2) - Round(SumRST("UkVreme"), 4), 2)
  
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "PrikaziTotale"
 Resume Exit_Point
End Function

Private Sub BrojPredmeta_DblClick(Cancel As Integer)
    Forms![PregledPoPostupcima]!ZaPredmet = Me!IDPredmet
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

