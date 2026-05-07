VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_RNPregled"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Public Function PrimeniUslove()
   BBTimerStart
    SetProperlyRecordSource BBCFG.CNNString, Me
    PrikaziTotale
   Me!LabelTrajanjeUpita.Caption = BBTimerTrajanjeSec("Query=")
End Function

Private Sub BrojCrteza_DblClick(Cancel As Integer)
    Forms!RNPregledZag!ZaBrojCrteza = Me!BrojCrteza
    Forms!RNPregledZag.PrimeniUslove
End Sub

Private Sub Form_Current()
On Error Resume Next

    'Call RNP.SetDataFromForm(Forms![RNPregledZag]![RNPregledStavkePodforma])
    Set RNP = Nothing
    RNP.IDRN = Me!IDRN
    'MsgBox F_RN_IDRN() & "   " & F_RN_IdentBroj() & "   " & F_RN_IDPredmet() & "   " & F_RN_Varijanta()
    Forms![RNPregledZag]![RNPregledStavkePodforma].Form.PrimeniUslove
    Forms![RNPregledZag]![RNPregledPostupciPodforma].Form.PrimeniUslove
    
End Sub
Private Sub BrojPredmeta_DblClick(Cancel As Integer)
    Forms!RNPregledZag!ZaPredmet = Me!IDPredmet
    Forms!RNPregledZag.PrimeniUslove
    'Form_Current
End Sub
Private Sub IdentBroj_DblClick(Cancel As Integer)
    Forms!RNPregledZag!ZaIdentBroj = Me!IdentBroj
    Forms!RNPregledZag.PrimeniUslove
    'Form_Current
End Sub


Private Sub Naziv_DblClick(Cancel As Integer)
    Forms!RNPregledZag!ZaKomitenta = Me!SifraKomitenta
    Forms!RNPregledZag.PrimeniUslove
End Sub

Private Sub RJgrupaRC_DblClick(Cancel As Integer)
    Forms!RNPregledZag!ZaRJgrupaRC = Me!RJgrupaRC
    Forms!RNPregledZag.PrimeniUslove
    'Form_Current
End Sub
Private Function PrikaziTotale()
On Error GoTo Err_Point

  Me!UkTezinaNeobrDela = SumRST("TezinaNeobrDela") '=Sum([TezinaNeobrDela])
  Me!UkTezinaObrDela = SumRST("TezinaObrDela") '=Sum([TezinaObrDela])
  Me!UkNormiranoVreme = SumRST("NormiranoVreme") '=Sum([NormiranoVreme])
  
  Me!UkUtrosenoVreme = SumRST("UtrosenoVremeMinuta") '=Sum([UtrosenoVreme])
  Me!UkRazlika = SumRST("UtrosenoVremeMinuta") - SumRST("NormiranoVreme") '=Sum(IIf(Round([UtrosenoVreme],0)=0,0,[UtrosenoVreme]-[NormiranoVreme]))
  
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "PrikaziTotale"
 Resume Exit_Point
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
