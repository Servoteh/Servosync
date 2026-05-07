VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_IzborPostupakaZaDaljiRadZag"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
'Dim aktivnaForma As Form
'Dim aktivanreport As Report
'Dim aktivnaKontrola  As Control
'Dim TipObjekta

Private Sub DugmeIzborPostupkaZaDaljiRad_Click()
    PostupakJeIzabran
End Sub

Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click

    IzabraniPostupak = -1
    DoCmd.Close acForm, "IzborPostupakaZaDaljiRadZag"
    
Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
    
End Sub

Private Function PostupakJeIzabran() As Boolean
On Error GoTo Err_Point
    'RadnikJeIzabran = CLng(Nz([Forms]![IzborRadnikaZaDaljiRadZag]![IzborRadnikaZaDaljiRad].[Form]![SifraRadnika], 0)) 'Me!SifraRadnika
    IzabraniPostupak = CLng(Nz([Forms]![IzborPostupakaZaDaljiRadZag]![IzborPostupakaZaDaljiRad].[Form]![IDPostupka], -1)) 'CLng(Nz(Me![SifraRadnika], 0))
    DoCmd.Close acForm, "IzborPostupakaZaDaljiRadZag"

Exit_Point:
    Exit Function

Err_Point:
    BBErrorMSG err, "PostupakJeIzabran"
    Resume Exit_Point
End Function

