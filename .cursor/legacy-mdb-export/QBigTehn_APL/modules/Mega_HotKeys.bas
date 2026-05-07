Attribute VB_Name = "Mega_HotKeys"
Option Compare Database
Option Explicit

Private Sub OdrediAktivnuFormuIKontrolu(ByRef txtAktivnaForma As String, ByRef txtAktivnaPodForma As String, ByRef txtAktivnaKontrola As String)
Dim aktivnaForma As Form
Dim aktivnaPodforma As Form
Dim aktivnaKontrola As control

On Error Resume Next
Set aktivnaForma = Screen.ActiveForm
Set aktivnaKontrola = Screen.ActiveControl

If Screen.ActiveControl.Name <> Screen.ActiveForm.ActiveControl.Name Then
    Set aktivnaPodforma = Screen.ActiveForm.ActiveControl.Form
End If

'*******************************************
    txtAktivnaForma = aktivnaForma.Name
    txtAktivnaPodForma = aktivnaPodforma.Name
    txtAktivnaKontrola = aktivnaKontrola.ControlSource
'*******************************************

Set aktivnaForma = Nothing
Set aktivnaPodforma = Nothing
Set aktivnaKontrola = Nothing

End Sub
