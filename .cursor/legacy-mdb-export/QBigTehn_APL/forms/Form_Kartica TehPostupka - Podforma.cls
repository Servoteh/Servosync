VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Kartica TehPostupka - Podforma"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit
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
    
  Me!UkNapravljenoKomada = SumRST("NapravljenoKomada")
  Me!UkUtrosenoVremeURaduSati = SumRST("UtrosenoVremeURaduSati")
  Me!UkSati = SumRST("Sati")
  Me!UkMinuti = Round(SumRST("Minuti"), 4) 'Round(Me!UkUlazKol - Me!UkIzlazKol, 4)
  
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "PrikaziTotale"
 Resume Exit_Point
End Function
Public Function PrimeniUslove()
  SetProperlyRecordSource BBCFG.CNNString, Me
  PrikaziTotale
End Function



Private Sub DugmeObrisiPostupak_Click()
    ObrisiPostupakZaIDPostupka (Me!IDPostupka)
End Sub

Private Sub Form_Open(Cancel As Integer)
    PrimeniUslove
End Sub

Private Sub Napomena_DblClick(Cancel As Integer)
On Error GoTo Err_ComboOpis_DblClick

    Dim stDocName As String
    Dim stLinkCriteria As String
     
    Set BBTehn = Nothing
    BBTehn.IDPostupka = Nz(Me!IDPostupka, 0)
    
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
