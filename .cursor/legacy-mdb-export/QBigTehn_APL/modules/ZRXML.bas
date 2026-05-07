Attribute VB_Name = "ZRXML"
Option Compare Database
Option Explicit

Public Function XmlTag(tag As String, Vrednost) As String
'modifikovano: 13-01-2023
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim retVal As String

retVal = ""
retValOk = True
   
   If tag = "" Then
        retVal = ""
   Else
   
        retVal = "<" & tag
        If IsNull(Vrednost) Then
          retVal = retVal & " i:nil = ""true""" & "/>"
        ElseIf Nz(Vrednost, 0) = 0 Then
          retVal = retVal & " i:nil = ""true""" & "/>"
        Else
          retVal = retVal & ">" & Round(Nz(Vrednost, 0), 0) & "</" & tag & ">"
        End If
    End If
   
Exit_Point:
 On Error Resume Next
      'Print #tkf, "<a:Vrednosti" & IIf(Round(Nz(ZRStavkeZaExport![Iznos_1], 0), 0) = 0, " i:nil = ""true""" & "/>", ">" & Round(Nz(ZRStavkeZaExport![Iznos_1], 0), 0) & "</a:Vrednosti>")
         XmlTag = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "XmlTag"
 retValOk = False
 Resume Exit_Point

End Function
