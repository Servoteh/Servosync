Attribute VB_Name = "LIB_PIB"
Option Compare Database
Option Explicit
Public Function DobarPIB(ByVal stPIB As String) As Boolean
'Modifikovano: 20-10-2021
'Modifikovano: 17-03-2021
On Error Resume Next
Dim c0 As Integer
Dim c1 As Integer
Dim c2 As Integer
Dim c3 As Integer
Dim c4 As Integer
Dim c5 As Integer
Dim c6 As Integer
Dim c7 As Integer
Dim c8 As Integer
Dim zadnji As String

Dim PIB As String

PIB = Trim(stPIB)
If Left(PIB, 2) = "SR" Then
   PIB = Trim(Right(PIB, Len(PIB) - 2))
Else
   PIB = Trim(PIB)
End If


zadnji = Right(PIB, 1)
PIB = Left(PIB, 8)
If Len(PIB) <> 8 Then
   DobarPIB = False
Else
       c8 = (CInt(Mid(PIB, 1, 1)) + 10) Mod 10
       If c8 = 0 Then
         c8 = 10
       End If
       c8 = (c8 * 2) Mod 11
       c7 = (CInt(Mid(PIB, 2, 1)) + c8) Mod 10
       If c7 = 0 Then
         c7 = 10
       End If
       c7 = (c7 * 2) Mod 11
       c6 = (CInt(Mid(PIB, 3, 1)) + c7) Mod 10
       If c6 = 0 Then
         c6 = 10
       End If
       c6 = (c6 * 2) Mod 11
       c5 = (CInt(Mid(PIB, 4, 1)) + c6) Mod 10
       If c5 = 0 Then
         c5 = 10
       End If
       c5 = (c5 * 2) Mod 11
       c4 = (CInt(Mid(PIB, 5, 1)) + c5) Mod 10
       If c4 = 0 Then
         c4 = 10
       End If
       c4 = (c4 * 2) Mod 11
       c3 = (CInt(Mid(PIB, 6, 1)) + c4) Mod 10
       If c3 = 0 Then
         c3 = 10
       End If
       c3 = (c3 * 2) Mod 11
       c2 = (CInt(Mid(PIB, 7, 1)) + c3) Mod 10
       If c2 = 0 Then
         c2 = 10
       End If
       c2 = (c2 * 2) Mod 11
       c1 = (CInt(Mid(PIB, 8, 1)) + c2) Mod 10
       If c1 = 0 Then
         c1 = 10
       End If
       c1 = (c1 * 2) Mod 11
       c0 = (11 - c1) Mod 10
       If c0 <> zadnji Then
        DobarPIB = False
       Else
        DobarPIB = True
       End If
       'return(pib || to_char(c0));
     
End If
End Function
Public Function DobarGLN(GLN As Variant) As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean
retValOk = False

If Nz(GLN, "") = "" Then
    retValOk = False
ElseIf (Len(Nz(GLN, "")) <= 5) Or Len(Nz(GLN, "")) > 14 Then
    retValOk = False
ElseIf Not IsNumeric(Nz(GLN, "")) Then
    retValOk = False
Else
    retValOk = True
End If


Exit_Point:
 On Error Resume Next
       DobarGLN = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "DobarGLN"
 retValOk = False
 Resume Exit_Point

End Function
