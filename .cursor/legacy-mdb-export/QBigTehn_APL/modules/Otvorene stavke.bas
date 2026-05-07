Attribute VB_Name = "Otvorene stavke"
Option Compare Database   'Use database order for string comparisons
Option Explicit

Function DugIznosZaZatvaranje(ZaKonto As String, Saldo As Double) As Double
         If (KontoKupca() = ZaKonto) And (Saldo > 0) Then
            DugIznosZaZatvaranje = -Saldo
    ElseIf (KontoKupca() = ZaKonto) And (Saldo < 0) Then
            DugIznosZaZatvaranje = -Saldo
    Else
            DugIznosZaZatvaranje = 0#
    End If
End Function

