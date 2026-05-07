Attribute VB_Name = "LIB_JMBG"
Option Compare Database
Option Explicit

Function Dobar_JMBG(ByVal JMBG As String) As Boolean
On Error GoTo Err_Dobar_JMBG

Dim retVal As Boolean
Dim kbroj As Long

' jmbg je uvek broj, ali broj je i 080296.710028 pa mora obrada greske!
If Not IsNumeric(JMBG) Then
    retVal = False
ElseIf Len(JMBG) <> 13 Then 'dugacak je 13 brojeva
  retVal = False
Else
    kbroj = CInt(Mid(JMBG, 1, 1)) * 7
    kbroj = kbroj + CInt(Mid(JMBG, 2, 1)) * 6
    kbroj = kbroj + CInt(Mid(JMBG, 3, 1)) * 5
    kbroj = kbroj + CInt(Mid(JMBG, 4, 1)) * 4
    kbroj = kbroj + CInt(Mid(JMBG, 5, 1)) * 3
    kbroj = kbroj + CInt(Mid(JMBG, 6, 1)) * 2
    kbroj = kbroj + CInt(Mid(JMBG, 7, 1)) * 7
    kbroj = kbroj + CInt(Mid(JMBG, 8, 1)) * 6
    kbroj = kbroj + CInt(Mid(JMBG, 9, 1)) * 5
    kbroj = kbroj + CInt(Mid(JMBG, 10, 1)) * 4
    kbroj = kbroj + CInt(Mid(JMBG, 11, 1)) * 3
    kbroj = kbroj + CInt(Mid(JMBG, 12, 1)) * 2

    kbroj = 11 - (kbroj Mod 11)
    'algoritam ne objasnjava situaciju kada je zbir deljiv sa 11
    'verovatno ne moze da bude 0 (eto zadatka za Isidoru!)
    'ali za svaki slucaj:
    If kbroj = 11 Then kbroj = 0
    retVal = kbroj = CInt(Mid(JMBG, 13, 1))
End If
Exit_Dobar_JMBG:
    Dobar_JMBG = retVal
Exit Function
Err_Dobar_JMBG:
    retVal = False
    Resume Exit_Dobar_JMBG
End Function


