Attribute VB_Name = "RegionalSettings"
Option Compare Database
Option Explicit
'Kreirano: 11-06-2022

Const pGodina_p = 2022
Const pMesec_p = 6
Const pDan_p = 14
Const pSat_p = 18
Const pMinut_p = 45
Const pSekund_p = 59
Const pShortDateStringFormat_p = "14-06-22"
Const pLongDateStringFormat_p = "14.06.2022."
Const pShortTimeStringFormat_p = "18:45"
Const pLongTimeStringFormat_p = "18:45:59"
Const pDecimalSeparator = "."
Const pTimeSeparator = ":"

Private Function DobarShortDateFormat() As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean

retValOk = (Format(DateSerial(pGodina_p, pMesec_p, pDan_p), "Short date") = pShortDateStringFormat_p)

Exit_Point:
 On Error Resume Next
       DobarShortDateFormat = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "DobarShortDateFormat"
 retValOk = False
 Resume Exit_Point
End Function
Private Function DobarLongDateFormat() As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean

retValOk = (Format(DateSerial(pGodina_p, pMesec_p, pDan_p), "Long date") = pLongDateStringFormat_p)

Exit_Point:
 On Error Resume Next
       DobarLongDateFormat = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "DobarLongDateFormat"
 retValOk = False
 Resume Exit_Point
End Function
Private Function DobarShortTimeFormat() As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean

retValOk = (Format(TimeSerial(pSat_p, pMinut_p, pSekund_p), "Short time") = pShortTimeStringFormat_p)

Exit_Point:
 On Error Resume Next
       DobarShortTimeFormat = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "DobarShortTimeFormat"
 retValOk = False
 Resume Exit_Point
End Function
Private Function DobarLongTimeFormat() As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean

retValOk = (Format(TimeSerial(pSat_p, pMinut_p, pSekund_p), "Long time") = pLongTimeStringFormat_p)

Exit_Point:
 On Error Resume Next
       DobarLongTimeFormat = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "DobarLongTimeFormat"
 retValOk = False
 Resume Exit_Point
End Function
Private Function DobarDecimalniSimbol() As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean

retValOk = (pDecimalSeparator = CreateObject("WScript.Shell").RegRead("HKCU\Control Panel\International\sDecimal"))

Exit_Point:
 On Error Resume Next
       DobarDecimalniSimbol = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "DobarDecimalniSimbol"
 retValOk = False
 Resume Exit_Point
End Function
Private Function DobarTimeSeparator() As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean

retValOk = (pTimeSeparator = CreateObject("WScript.Shell").RegRead("HKCU\Control Panel\International\sTime"))

Exit_Point:
 On Error Resume Next
       DobarTimeSeparator = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "DobarTimeSeparator"
 retValOk = False
 Resume Exit_Point
End Function
Public Function DobarRegionalSetings(Optional ByRef stPoruka As String = "") As Boolean
  
On Error GoTo Err_Point
Dim retValOk As Boolean

retValOk = True
 If Not DobarShortDateFormat Then
    retValOk = False
    stPoruka = stPoruka & "ShortDateFormat - Nije dobar" & vbCrLf
 End If
 
 If Not DobarLongDateFormat Then
    retValOk = False
    stPoruka = stPoruka & "LongDateFormat - Nije dobar" & vbCrLf
 End If

 If Not DobarShortTimeFormat Then
    retValOk = False
    stPoruka = stPoruka & "ShortTimeFormat - Nije dobar" & vbCrLf
 End If
 
If Not DobarLongTimeFormat Then
    retValOk = False
    stPoruka = stPoruka & "LongTimeFormat - Nije dobar" & vbCrLf
End If

If Not DobarDecimalniSimbol Then
    retValOk = False
    stPoruka = stPoruka & "DecimalSeparator - Nije dobar" & vbCrLf
End If

If Not DobarTimeSeparator Then
    retValOk = False
    stPoruka = stPoruka & "TimeSeparator - Nije dobar" & vbCrLf
End If

Exit_Point:

On Error Resume Next
       DobarRegionalSetings = retValOk
       'Debug.Print stPoruka
Exit Function

Err_Point:
 BBErrorMSG err, "DobarRegionalSetings"
 retValOk = False
 Resume Exit_Point

End Function

