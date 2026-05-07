VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_IzborRadnikaZaDaljiRadZag"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Dim aktivnaForma As Form
Dim aktivanreport As Report
Dim aktivnaKontrola  As control
Dim TipObjekta

Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click

    IzabraniRadnik = -1
    IzabraniPostupak = -1
    DoCmd.Close acForm, "IzborRadnikaZaDaljiRadZag"
    
Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
    
End Sub

Private Function RadnikJeIzabran() As Long
 On Error Resume Next
    'RadnikJeIzabran = CLng(Nz([Forms]![IzborRadnikaZaDaljiRadZag]![IzborRadnikaZaDaljiRad].[Form]![SifraRadnika], 0)) 'Me!SifraRadnika
    IzabraniRadnik = CLng(Nz([Forms]![IzborRadnikaZaDaljiRadZag]![IzborRadnikaZaDaljiRad].[Form]![SifraRadnika], -1)) 'CLng(Nz(Me![SifraRadnika], 0))
    IzabraniPostupak = CLng(Nz([Forms]![IzborRadnikaZaDaljiRadZag]![IzborRadnikaZaDaljiRad].[Form]![IDPostupka], -1)) 'CLng(Nz(Me![IDPostupka], 0))
    DoCmd.Close acForm, "IzborRadnikaZaDaljiRadZag"
    
End Function


Private Sub DugmeIzborRadnikaZaDaljiRad_Click()
    RadnikJeIzabran
End Sub


