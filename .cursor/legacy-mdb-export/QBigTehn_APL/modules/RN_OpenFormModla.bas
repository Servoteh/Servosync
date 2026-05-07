Attribute VB_Name = "RN_OpenFormModla"
Option Compare Database
Option Explicit

Dim aktivnaForma As Form
Dim aktivanreport As Report
Dim aktivnaKontrola  As control
Dim TipObjekta
Public Sub ObrisiVrednostKontrole()
On Error Resume Next

Dim txtAktivnaForma As String
Dim txtAktivnaKontrola As String

Set aktivnaForma = Screen.ActiveForm
Set aktivnaKontrola = Screen.ActiveForm.ActiveControl
'Set aktivnaKontrola = Screen.ActiveControl
Set aktivanreport = Screen.ActiveReport


TipObjekta = Application.CurrentObjectType


txtAktivnaForma = aktivnaForma.Name
txtAktivnaKontrola = aktivnaForma.ActiveControl.Name
Forms(txtAktivnaForma).ActiveControl = Null
Forms(txtAktivnaForma)("Podforma").PrimeniUslove
Forms(txtAktivnaForma).PrimeniUslove
DoCmd.GoToControl txtAktivnaKontrola
End Sub
Public Sub PrimeniFiltere(Nuliraj As Boolean)
On Error Resume Next

Dim txtAktivnaForma As String
Dim txtAktivnaKontrola As String

Set aktivnaForma = Screen.ActiveForm
Set aktivnaKontrola = Screen.ActiveForm.ActiveControl
'Set aktivnaKontrola = Screen.ActiveControl
Set aktivanreport = Screen.ActiveReport


TipObjekta = Application.CurrentObjectType


txtAktivnaForma = aktivnaForma.Name
txtAktivnaKontrola = aktivnaForma.ActiveControl.Name
If Nuliraj Then Forms(txtAktivnaForma).ActiveControl = Null
Forms(txtAktivnaForma).Requery
DoCmd.GoToControl txtAktivnaKontrola
End Sub
Public Function ObrisiVrednostPrethodneKontrole() As Boolean
On Error Resume Next

Dim txtAktivnaForma As String
Dim txtAktivnaKontrola As String
Dim txtPreAktivneKontrole As String
Dim ImePrethodneKontrole As String

Set aktivnaForma = Screen.ActiveForm
Set aktivnaKontrola = Screen.ActiveForm.ActiveControl
Set aktivanreport = Screen.ActiveReport

TipObjekta = Application.CurrentObjectType

txtAktivnaForma = aktivnaForma.Name
txtAktivnaKontrola = aktivnaForma.ActiveControl.Name
ImePrethodneKontrole = Mid(txtAktivnaKontrola, 8)
Forms(txtAktivnaForma).Controls(ImePrethodneKontrole) = Null
Forms(txtAktivnaForma)("Podforma").PrimeniUslove
Forms(txtAktivnaForma).PrimeniUslove
DoCmd.GoToControl txtAktivnaKontrola
End Function
