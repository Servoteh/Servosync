Attribute VB_Name = "LIB_Validacija"
Option Compare Database
Option Explicit

Public Function DobarUslovZaIznos(Uslov As Variant) As Boolean
On Error GoTo err_Func
 Dim Vred
 Dim retVal As Boolean
 
 retVal = True
    Vred = Eval(CStr(1) & CStr(Nz(Uslov, "")))
    
exit_Func:
DobarUslovZaIznos = retVal
Exit Function

err_Func:
 'MsgBox "Nekorektno zadat uslov!", , "QMegaTeh"
 retVal = False
 Resume exit_Func:
End Function
Public Function ZadovoljenUslovZaNumVal(ByVal inNumVal As Variant, ByVal inUslov As Variant, Optional inBrojDecimalaZaokruzenja) As Boolean
  On Error GoTo err_Func
  
 Dim stNumVal As String
 Dim stUslov As String
 Dim stExpression As String
 Dim retVal As Boolean
 
 If (Nz(inUslov, "") = "") Or (Nz(inUslov, "") = "*") Then
    retVal = True
    GoTo exit_Func
 Else
    stUslov = CStr(Nz(inUslov, ""))
 End If
 
 If Not IsNumeric(inNumVal) Then
    retVal = False
    GoTo exit_Func
 Else
    If IsMissing(inBrojDecimalaZaokruzenja) Then
        stNumVal = CStr(Nz(inNumVal, 0))
    Else
        stNumVal = CStr(Round(inNumVal, inBrojDecimalaZaokruzenja))
    End If
 End If
 
 
 stExpression = stNumVal & " " & stUslov
 
 retVal = Eval(stExpression)
 
exit_Func:
 ZadovoljenUslovZaNumVal = retVal

Exit Function

err_Func:
 retVal = False
 Resume exit_Func:
End Function
Public Function ZadovoljenUslovZaBoolVal(inBoolVal As Variant, inBoolUslov As Variant) As Boolean
  On Error GoTo err_Func
 
 Dim cBoolVal As Boolean
 Dim cBoolUslov As Boolean
 Dim retVal As Boolean
 
 cBoolVal = CBool(Nz(inBoolVal, False))
 
 If IsNull(inBoolUslov) Then
  retVal = True
 ElseIf CStr(inBoolUslov) = "" Or CStr(inBoolUslov) = "*" Then
  retVal = True
 ElseIf IsNumeric(inBoolUslov) Then
  cBoolUslov = CBool(inBoolUslov)
  retVal = (cBoolVal = cBoolUslov)
 Else
  retVal = False
 End If

exit_Func:
 ZadovoljenUslovZaBoolVal = retVal

Exit Function

err_Func:
 retVal = False
 Resume exit_Func:
End Function
'****************************************************
'Datum: 23-08-2018
'Modifikovano: 04-04-2018
'****************************************************
Public Function PitajDaLiSuDobriDatumiZaGodinu(ZaGodinu As Long, ParamArray Arg()) As Boolean
'? DobriDatumiZaGodinu("01-01-18","15-08-19")
    On Error GoTo Err_Point

Dim retValOk
Dim DatumZaProveru As String
Dim i As Integer
Dim stMsgBox As String


retValOk = True

For i = LBound(Arg) To UBound(Arg)
 DatumZaProveru = Nz(Arg(i), "")
 retValOk = retValOk And IsDate(DatumZaProveru)
 If retValOk Then
   retValOk = retValOk And Year(DatumZaProveru) = ZaGodinu
 End If
 If Not retValOk Then
   Exit For
 End If
Next i

Exit_Point:
    If Not retValOk Then
       stMsgBox = "Datumi nisu u okviru zadate godine."
       stMsgBox = stMsgBox & vbCrLf & "Da li ipak želite da ih memorišete?"
       retValOk = BBPitanje(stMsgBox, vbDefaultButton2)
     Else
       retValOk = True
     End If
  
  PitajDaLiSuDobriDatumiZaGodinu = retValOk
Exit Function

Err_Point:
    'MsgBox Error$
    BBErrorMSG err, "PitajDaLiSuDobriDatumiZaGodinu"
    retValOk = False
    Resume Exit_Point
End Function


