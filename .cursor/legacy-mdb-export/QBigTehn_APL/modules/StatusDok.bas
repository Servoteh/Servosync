Attribute VB_Name = "StatusDok"
Option Compare Database
Option Explicit

Public Function AGDesifrujBarKod(BarKod As String, polje As String, Vrednost As Variant) As Boolean
Dim retVal As Boolean
Dim pozdvt As Integer
Dim Separator As String

      If InStr(1, BarKod, ":", vbTextCompare) >= 1 Then
            Separator = ":"
 ElseIf InStr(1, BarKod, "è", vbTextCompare) >= 1 Then
            Separator = "è"
 ElseIf InStr(1, BarKod, "È", vbTextCompare) >= 1 Then
            Separator = "È"
 ElseIf InStr(1, BarKod, ";", vbTextCompare) >= 1 Then
            Separator = ";"
 ElseIf InStr(1, BarKod, " ", vbTextCompare) >= 1 Then
            Separator = " "
 Else
            Separator = ":"
 End If

polje = ""
Vrednost = Null
pozdvt = InStr(1, BarKod, Separator, vbTextCompare)

If pozdvt > 0 Then
    polje = Left$(BarKod, pozdvt - 1)
    Vrednost = Right$(BarKod, Len(BarKod) - pozdvt)
    retVal = True
Else
    retVal = False
End If
    AGDesifrujBarKod = retVal
            
End Function

Public Function FTestF(bc As String) As Boolean
'Dim bc As String
Dim polje As String
Dim Vred
 ' bc = "IDDok:1234"
  
    AGDesifrujBarKod bc, polje, Vred
    Debug.Print polje & " = " & Vred
    FTestF = True
End Function
Public Function spSaveStatusDokumenta(ByVal IDStavke, ByVal IDDok, ByVal PrimioFakturu, ByVal UtovarioUVozilo, ByVal Isporuceno, ByVal Komentar, ByVal Napomena, ByVal PripremioRobu) As Boolean
'Public Function spSaveStatusDokumenta(ByVal IDStavke, ByVal IDDok As Long, ByVal PrimioFakturu As Boolean, ByVal UtovarioUVozilo As Long, ByVal Isporuceno As Boolean, ByVal Komentar As String, ByVal Napomena As String, ByVal PripremioRobu As Long) As Boolean
'Kreirano: 12-01-2021
    '[ID] [int] IDENTITY(1,1) NOT NULL,
    '[IDDok] [int] NULL,
    '[PrimioFakturu] [bit] NULL,
    '[UtovarioUVozilo] [int] NULL,
    '[Isporuceno] [bit] NULL,
    '[Komentar] [nvarchar](50) NULL,
    '[Napomena] [nvarchar](max) NULL,
    '[PripremioRobu] [int] NULL,
      
On Error GoTo Err_Point
Dim retValOk As Boolean

retValOk = ExecSPByRefPar("spSaveStatusDokumenta", "@ID = " & CStr(Nz(IDStavke, "Null")) _
                                                 , "@IDDok = " & CStr(Nz(IDDok, "Null")) _
                                                 , "@PrimioFakturu = " & IIf(IsNull(PrimioFakturu), "Null", SQLFormatBoolean(PrimioFakturu)) _
                                                 , "@UtovarioUVozilo = " & CStr(Nz(UtovarioUVozilo, "Null")) _
                                                 , "@Isporuceno = " & IIf(IsNull(Isporuceno), "Null", SQLFormatBoolean(Isporuceno)) _
                                                 , "@Komentar = " & Komentar _
                                                 , "@Napomena = " & Napomena _
                                                 , "@PripremioRobu = " & CStr(Nz(PripremioRobu, "Null")) _
                          )

Exit_Point:
 On Error Resume Next
       spSaveStatusDokumenta = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "spSaveStatusDok"
 retValOk = False
 Resume Exit_Point
End Function
