Attribute VB_Name = "KontrolniBrojevi"
Option Compare Database
Option Explicit

Public Function IzbaciCrticu(ulsf As String) As String
Dim sf As String

sf = Left$(ulsf, 2) & Mid$(ulsf, 4, 5)

IzbaciCrticu = sf
End Function

Public Function Kbroj22(sf As String) As String
Dim i As Integer
Dim zb As Long
Dim kbroj As Long

If Left$(sf, 1) = "0" Then
    sf = Mid$(sf, 2, 6) & Left$(sf, 1)
End If

zb = 0
For i = 1 To 6
 zb = zb + Eval(Mid(sf, i, 1)) * (8 - i)
Next i
 zb = zb + Eval(Mid(sf, 7, 1)) * 7
 kbroj = zb Mod 11
 kbroj = 11 - kbroj
 If kbroj = 10 Then
   kbroj = 0
 ElseIf kbroj = 11 Then kbroj = 1
 End If
 
 Kbroj22 = kbroj
End Function
Public Function KBroj97(BROJ As String) As String
'Modifikovano: 25-01-2024 zbog slova u vrednosti broj
'Modifikovano: 29-01-2024

' 97 38 04353P000142151201130
' 97 54 91000000048193021
'A=10, B=11, C=12, D=13, E=14, F=15, G=16, H=17, I=18, J=19, K=20, L=21, M=22, N=23, O=24, P=25, Lj=26, R=27 S=28, T=29, U=30, V=31, Nj=32, H=33, Y=34, Z=35
On Error GoTo err_KB
 Dim kbroj As String
 Dim NumBroj, NumKBroj As Variant
 Dim pBroj As String
 Dim i As Byte
 
  pBroj = UCase(BROJ)
  For i = 1 To 25
    pBroj = Replace(pBroj, Chr(Asc("A") + i - 1), CStr(i + 9))
  Next i
  
  NumBroj = CDec(pBroj)
  NumKBroj = CDec(CDec(NumBroj) * CDec(100)) - CDec(Int(CDec(CDec(CDec(NumBroj) * 100) / 97))) * CDec(97)
  NumKBroj = 98 - NumKBroj
  kbroj = NumKBroj
  If Len(kbroj) = "1" Then kbroj = "0" & kbroj
exit_KB:
  KBroj97 = kbroj
Exit Function
err_KB:
    Select Case err.Number
    Case 6
        MsgBox "Preveliki broj za sracunavanje kontrolnog broja."
    Case Else
    End Select
    kbroj = ""
 GoTo exit_KB
End Function
Public Function DobarKBroj97(BROJ As Variant) As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stBroj As String
Dim stOstatak As String
Dim stRetVal As String

retValOk = True

stBroj = CStr(BROJ)

If Len(stBroj) > 2 Then
    stOstatak = Right(stBroj, Len(stBroj) - 2)
    retValOk = (Left(stBroj, 2) = KBroj97(stOstatak))
Else
    retValOk = False
End If
        
Exit_Point:
 On Error Resume Next
       DobarKBroj97 = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "DobarKBroj97"
 retValOk = False
 Resume Exit_Point

End Function
Public Function KorigujPoModelu(Model As String, BROJ As String) As String

On Error GoTo Err_Point

 Dim stKBroj As String
 Dim stOstatak As String
 Dim stRetVal As String
 
    If Model = "97" Then
        If DobarKBroj97(BROJ) Then
            stRetVal = BROJ
        Else
            stRetVal = KBroj97(BROJ) & BROJ
        End If
    Else
        stRetVal = BROJ
    End If
Exit_Point:
On Error Resume Next
    KorigujPoModelu = stRetVal
Exit Function

Err_Point:
    stRetVal = BROJ
    Resume Exit_Point
End Function

Public Function DobarTR(varTR As Variant) As Boolean
'Modifikovano: 23-01-2021
On Error GoTo Err_Point

    Dim tr1, tr2, tr3, ntr, kb As String
    Dim OK As Boolean
    Dim retValOk As Boolean
    Dim tr As String
    
    OK = False
    
On Error Resume Next
    tr = Nz(varTR, "")
    
    tr1 = Left$(tr, 3)
    tr2 = Mid$(tr, InStr(tr, "-") + 1, Len(tr) - 7)
    ' Mid$("115-12411-79", InStr("115-12411-79", "-")+1, Len("115-12411-79") - 7)
    tr3 = Right$(tr, 2)
    ntr = tr1 & "-" & tr2 & "-" & tr3
    OK = (tr = ntr)
    tr2 = DoChLeft(tr2, 13, "0")
    kb = KBroj97(tr1 & tr2)
    
    retValOk = OK And (kb = tr3)


Exit_Point:
 On Error Resume Next
 DobarTR = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "DobarTR"
 retValOk = False
 Resume Exit_Point
End Function
