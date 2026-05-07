Attribute VB_Name = "OtvaranjeFormi"
Option Compare Database
Option Explicit

Public Function UnosProfaktura(Optional IDDok As Long) As Boolean
'Kreirano: 11-01-2020
'Modifikovano: 24-01-2020
'Modifikovano: 24-02-2020
On Error GoTo Err_Point
Dim stImeForme As String
Dim retValOk As Boolean
Dim stMsg As String
 
 retValOk = True
 stImeForme = "IF"  ' ReadCFGParametar("FORM.IF", "IF") '*********** 11-01-20 Za sada!
 If IsLoaded(stImeForme) Then
  stMsg = "Za prikaz Profakture potrebno je zatvoriti formu (IF) za unos Fakture."
  stMsg = stMsg & vbCrLf & "Da li nastavljate proces?"
  stMsg = stMsg & vbCrLf
  stMsg = stMsg & vbCrLf & "(ako odgovorite ""Yes"" forma (IF) za unos Fakture ce biti zatvorena)"
  If Not BBPitanje(stMsg) Then
     GoTo Exit_Point
  Else
     DoCmd.Close acForm, stImeForme
  End If
 End If
 IFP.Caller = "UnosProfaktura"
 BBOpenForm stImeForme, , , , , , "Profaktura"
 'Forms(stImeForme).OvoJeProfaktura
 'Forms(stImeForme)!ZaIDDok = IDDok
 'Forms(stImeForme)!IDDokIzRobnog.DefaultValue = IDDok
 'Forms(stImeForme).PrimeniUslove
Exit_Point:
 On Error Resume Next
 UnosProfaktura = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "UnosProfaktura"
 retValOk = False
 Resume Exit_Point
End Function
