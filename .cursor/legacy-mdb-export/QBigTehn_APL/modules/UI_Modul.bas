Attribute VB_Name = "UI_Modul"
Option Compare Database
Option Explicit

Public Function F_UIStavkeKolicina(ByVal Kolona As Integer, ByVal UTKolicina As Currency, ByVal UTKol1 As Currency, ByVal UTKol2 As Currency, ByVal UTKol3 As Currency, Optional MinusKol As Boolean = False) As Currency
Dim retVal As Currency
    If Kolona = 0 Then
        retVal = UTKolicina
 ElseIf Kolona = 1 Then
        retVal = UTKol1
 ElseIf Kolona = 2 Then
        retVal = UTKol2
 ElseIf Kolona = 3 Then
        retVal = UTKol3
 Else
    retVal = 0
    MsgBox "Nepoznata Kolona= " & Kolona & " u funkciji  F_UIStavkeKolicina. ", , "QMegaTeh"
 End If
 If MinusKol Then retVal = -retVal
 
 F_UIStavkeKolicina = retVal
End Function

Public Function F_UIStavkeNC(ByVal NabCenaVrsta As Integer, ByVal ProsNabCena As Currency, ByVal CenaKostanjaGP As Currency) As Currency
Dim retVal As Currency
    If NabCenaVrsta = 0 Then
        retVal = ProsNabCena
 ElseIf NabCenaVrsta = 1 Then
        retVal = CenaKostanjaGP
 Else
    retVal = 0
    MsgBox "Nepoznata NabCenaVrsta= " & NabCenaVrsta & " u funkciji  F_UIStavkeNC. ", , "QMegaTeh"
 End If
 F_UIStavkeNC = retVal
End Function

Public Function F_UIStavkeVPC(ByVal VPCenaVrsta As Integer, ByVal ProsNabCena As Currency, ByVal CenaKostanjaGP As Currency, ByVal CenaIzCenovnika As Currency) As Currency
Dim retVal As Currency
    If VPCenaVrsta = 0 Then
        retVal = ProsNabCena
 ElseIf VPCenaVrsta = 1 Then
        retVal = CenaKostanjaGP
 ElseIf VPCenaVrsta = 2 Then
        retVal = CenaIzCenovnika
 Else
    retVal = 0
    MsgBox "Nepoznata VPCenaVrsta= " & VPCenaVrsta & " u funkciji  F_UIStavkeNC. ", , "QMegaTeh"
 End If
 F_UIStavkeVPC = retVal
End Function

