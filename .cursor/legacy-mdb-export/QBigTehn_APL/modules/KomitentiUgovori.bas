Attribute VB_Name = "KomitentiUgovori"
Option Compare Database
Option Explicit

Public Function KomitentiUgovoriEvalKonto(Konto As String, VK1, VK2, VK3) As String
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stRetVal As String

retValOk = True
stRetVal = Konto

stRetVal = Replace(stRetVal, "@Konto1", CStr(Nz(VK1, "")))
stRetVal = Replace(stRetVal, "@Konto2", CStr(Nz(VK2, "")))
stRetVal = Replace(stRetVal, "@Konto3", CStr(Nz(VK3, "")))


Exit_Point:
 On Error Resume Next
       KomitentiUgovoriEvalKonto = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "KomitentiUgovoriEvalKonto"
 retValOk = False
 Resume Exit_Point

End Function
Public Function KomitentiUgovoriEvalDefDugPot(DEF As String, VP1, VP2, VP3) As String
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stRetVal As String

retValOk = True
stRetVal = DEF

stRetVal = Replace(stRetVal, "@Proc1", CStr(Nz(VP1, "0")))
stRetVal = Replace(stRetVal, "@Proc2", CStr(Nz(VP2, "0")))
stRetVal = Replace(stRetVal, "@Proc3", CStr(Nz(VP3, "0")))


Exit_Point:
 On Error Resume Next
       KomitentiUgovoriEvalDefDugPot = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "KomitentiUgovoriEvalDefDugPot"
 retValOk = False
 Resume Exit_Point

End Function
