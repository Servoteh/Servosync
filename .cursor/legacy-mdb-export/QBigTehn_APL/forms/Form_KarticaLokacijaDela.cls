VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_KarticaLokacijaDela"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit
Public Function PrimeniUslove()
   BBTimerStart
    SetProperlyRecordSource BBCFG.CNNString, Me
   Me!LabelTrajanjeUpita.Caption = BBTimerTrajanjeSec("Query=")
   PrikaziTotale
End Function
Private Function SumRST(stImeKolone As String) As Double
 Dim rs As Object
 Dim Total As Double

    Total = 0
    Set rs = Me.Recordset.Clone
 
 While Not rs.EOF
  Total = Total + rs(stImeKolone).Value
  rs.MoveNext
 Wend
 SumRST = Total
End Function
Private Function PrikaziTotale()
On Error GoTo Err_Point

  Me!UkPostavljenaKol = SumRST("Postavljeno")
  Me!UkUklonjenaKol = SumRST("Uklonjeno")
  Me!PreostaloKol = Round(Me!UkPostavljenaKol - Me!UkUklonjenaKol, 4)
  
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "PrikaziTotale"
 Resume Exit_Point
End Function

Private Sub BrojCrteza_DblClick(Cancel As Integer)
    Me!ZaBrojCrteza = Me!BrojCrteza
    PrimeniUslove
End Sub

Private Sub BrojNaloga_DblClick(Cancel As Integer)
    Me!ZaIdentBroj = Me!BrojNaloga
    PrimeniUslove
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

Private Sub Form_Open(Cancel As Integer)
    DoCmd.Maximize
    PrimeniUslove
End Sub

Private Sub OdDatuma_DblClick(Cancel As Integer)
    If IsNull(Me!OdDatuma) Then
      Me!OdDatuma = F_OdDatuma()
    Else
      Me!OdDatuma = Null
    End If
    PrimeniUslove
End Sub

Private Sub Radnik_DblClick(Cancel As Integer)
    Me!ZaRadnika = Me!SifraRadnika
    PrimeniUslove
End Sub

Private Sub ZaBrojCrteza_DblClick(Cancel As Integer)
    Me!ZaBrojCrteza = Null
    PrimeniUslove
End Sub

Private Sub ZaBrojCrteza_GotFocus()
    Me!ZaBrojCrteza.Requery
End Sub

Private Sub ZaDeoNazivaPolice_DblClick(Cancel As Integer)
    Me!ZaDeoNazivaPolice = Null
    PrimeniUslove
End Sub

Private Sub ZaIdentBroj_DblClick(Cancel As Integer)
    Me!ZaIdentBroj = Null
    PrimeniUslove
End Sub

Private Sub ZaIdentBroj_GotFocus()
    Me!ZaIdentBroj.Requery
End Sub

Private Sub ZaRadnika_DblClick(Cancel As Integer)
    Me!ZaRadnika = Null
    PrimeniUslove
End Sub
