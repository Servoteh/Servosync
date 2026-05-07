Attribute VB_Name = "TextCompare"
Option Compare Database ' Jako bitno zbog funkcije ZameniNasaSlova
Option Explicit
Public Function ZameniStr(ByVal umesto As String, ByVal stavi As String, ByVal stR As String) As String
'Modifikovano: 21-12-2019
Dim nPos As Integer
Dim retstr As String
Dim OstatakZaProveru As String


retstr = Replace(stR, umesto, stavi)

'    RetStr = ""
'    OstatakZaProveru = str
'    nPos = InStr(1, OstatakZaProveru, umesto)
'
'    While Nz(nPos, 0) > 0
'        RetStr = RetStr & Left(OstatakZaProveru, nPos - 1) & stavi
'        OstatakZaProveru = Right(OstatakZaProveru, Len(OstatakZaProveru) - nPos + 1 - Len(umesto))
'        nPos = InStr(1, OstatakZaProveru, umesto)
'    Wend
'    RetStr = RetStr & OstatakZaProveru
ZameniStr = retstr
End Function

Public Function InStrRev(st1, st2) As Variant 'poslednje pojavlivanje st2 u st1
Dim i As Long
i = 1
While InStr(i, st1, st2) <> 0
 i = i + 1
Wend
InStrRev = i - 1
End Function

Public Function IzbaciSveCrtice(ByVal st As Variant) As String
    Dim retVal As String
    Dim tmpst As String
    Dim ch As String
    Dim i As Integer
    
    tmpst = CStr(Nz(st, ""))
    retVal = ""
    For i = 1 To Len(tmpst)
     ch = Mid$(tmpst, i, 1)
     If ch = " " Or ch = "/" Or ch = "\" Or ch = "-" Or ch = "+" Then
       Else
        retVal = retVal & ch
     End If
    Next i
    IzbaciSveCrtice = retVal
End Function

Public Function TextBetween(LeftStr As String, RightStr As String, InputStr As String) As String
 Dim frompos As Long
 Dim topos As Long
 Dim retstr As String
 frompos = InStr(InputStr, LeftStr)
 If frompos > 0 Then
   topos = InStr(frompos, InputStr, RightStr)
   If topos > frompos Then
   Else
    topos = Len(InputStr) + 1
   End If
   retstr = Mid(InputStr, frompos + 1, topos - frompos - 1)
 Else
    retstr = ""
 End If
 TextBetween = retstr
End Function
Public Function ConvertstringToArrayLines(ByVal Value As String)
'Kreirano: 20-12-2019
    'value = StrConv(value, vbUnicode)
    'ConvertstringToArrayLines = Split(Left(Value, Len(Value) - 1), vbCrLf)
    ConvertstringToArrayLines = Split(Value, vbCrLf)
End Function
Public Function ReplaceStringLine(stString As String, stFindLine As String, stReplaceLine As String, Optional intMatch As Integer = 0) As String
'Kreirano: 20-12-2019
'intMatch = 0-Cela linija, 1-Pocetak, 2-Bilo koji deo, 3-Kraj
Dim stRetVal As String
Dim stLines() As String
Dim i As Integer

 stRetVal = ""
 stLines = ConvertstringToArrayLines(stString)
 For i = LBound(stLines) To UBound(stLines)
    Select Case intMatch
    Case 0
        If stLines(i) = stFindLine Then
           stLines(i) = stReplaceLine
        End If
    Case 1
        If stLines(i) Like stFindLine & "*" Then
           stLines(i) = stReplaceLine & Right(stLines(i), Len(stLines(i)) - Len(stFindLine))
        End If
    Case 2
        If stLines(i) Like "*" & stFindLine & "*" Then
           stLines(i) = Replace(stLines(i), stFindLine, stReplaceLine)
        End If
    Case 3
        If stLines(i) Like "*" & stFindLine Then
           stLines(i) = Left(stLines(i), Len(stLines(i)) - Len(stFindLine)) & stReplaceLine
        End If
    End Select
    stRetVal = stRetVal & stLines(i) & vbCrLf
    'Debug.Print i, stLines(i)
 Next i
   'stRetVal = Replace(stString, stFindLine, stReplaceLine)
   ReplaceStringLine = stRetVal
   
End Function
Public Function OstaviSamoSlovaIBrojeve(var, Optional ZameniSrpskaSlova As Boolean = True) As String
'Kreirano: 09-05-2022

On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stRetVal As String
Dim stVar As String
Dim AscChr As Integer
Dim OK As Boolean
Dim i As Integer

retValOk = True
stVar = CStr(Nz(var, ""))

If ZameniSrpskaSlova Then
    stVar = ZameniNasaSlova(stVar)
End If

stRetVal = ""

For i = 1 To Len(stVar)
    AscChr = Asc(Mid(stVar, i, 1))
    
    OK = ((Asc("0") <= AscChr) And (AscChr <= Asc("9")))
    OK = OK Or ((Asc("a") <= AscChr) And (AscChr <= Asc("z")))
    OK = OK Or ((Asc("A") <= AscChr) And (AscChr <= Asc("Z")))
    OK = OK Or (Mid(stVar, i, 1) = "_")
    OK = OK Or (Mid(stVar, i, 1) = "-")
    OK = OK Or (Mid(stVar, i, 1) = ",")
    OK = OK Or (Mid(stVar, i, 1) = ".")
    OK = OK Or (Mid(stVar, i, 1) = "+")
    OK = OK Or (Mid(stVar, i, 1) = "%")
    OK = OK Or (Mid(stVar, i, 1) = "=")
    OK = OK Or (Mid(stVar, i, 1) = ":")
    OK = OK Or (Mid(stVar, i, 1) = " ")
    
    If OK Then
       stRetVal = stRetVal & Mid(stVar, i, 1)
    Else
       stRetVal = stRetVal & "_"
    End If
Next i

Exit_Point:
 On Error Resume Next
       OstaviSamoSlovaIBrojeve = Trim(stRetVal)
Exit Function

Err_Point:
 BBErrorMSG err, "OstaviSamoSlovaIBrojeve"
 retValOk = False
 Resume Exit_Point
End Function
Public Function IzbaciSpecZnake(var) As String
'Kreirano: 09-05-2022

On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stRetVal As String

retValOk = True
stRetVal = CStr(Nz(var, ""))

stRetVal = Replace(stRetVal, Chr(34), " ")   ' replace single quote with space
stRetVal = Replace(stRetVal, Chr(39), " ")   ' replace double quote with space
stRetVal = Replace(stRetVal, Chr(8), "")     ' remove backspace
stRetVal = Replace(stRetVal, Chr(10), "")    ' remove line feed
stRetVal = Replace(stRetVal, Chr(12), "")    ' remove form feed
stRetVal = Replace(stRetVal, Chr(13), "")    ' remove carriage return
stRetVal = Replace(stRetVal, Chr(9), "   ")    ' replace tab with 3 spaces

stRetVal = Replace(stRetVal, "\", " ")    ' replace
stRetVal = Replace(stRetVal, "/", " ")    ' replace
stRetVal = Replace(stRetVal, "&", " ")    ' replace

stRetVal = Replace(stRetVal, "[", " ")    ' replace
stRetVal = Replace(stRetVal, "]", " ")    ' replace

stRetVal = Replace(stRetVal, "{", " ")    ' replace
stRetVal = Replace(stRetVal, "}", " ")    ' replace

Exit_Point:
 On Error Resume Next
       IzbaciSpecZnake = Trim(stRetVal)
Exit Function

Err_Point:
 BBErrorMSG err, "IzbaciSpecZnake"
 retValOk = False
 Resume Exit_Point
End Function

