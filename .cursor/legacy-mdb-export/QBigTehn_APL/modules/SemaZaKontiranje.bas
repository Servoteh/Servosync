Attribute VB_Name = "SemaZaKontiranje"
Option Compare Database
Option Explicit
Function VredIzraza(Izraz As Variant, a, b, c, d, e, f, G, H, i, j, K, L, M, n, o, p, Q, r, s, t, U, v, w, X, Y, Z As Double) As Double
On Error GoTo Err_Izracunaj
   '  A - Nabavna neto cena
   '  B - Zavisni trosak sopstveni - NEOPOREZIV
   '  C - Zavisni trosak dobavljac - OPOREZIV
   '  D - Ukalkulisana razlika u ceni
   '  E - Placen porez dobavljacu
   '  F - Posebna republicka taksa
   '  G - Kalkulativna VP cena - bez poreza i takse
   '  H - Placen porez dobavljacu
   '  I - Ostvarena VP cena
   '  J - Zaduzenje poreza na promet proizvoda - Porez iskazan u fakturi
   '  K - Kalkulativni porez na promet proizvoda kod izlazne fakture (Snabdevanje MP)


    
    Dim pomstr As String
    Dim Duzina As Integer, IJ As Integer, indeks As Integer
    Dim strar As Variant, pom As String
    
     strar = Array(a, b, c, d, e, f, G, H, i, j, K, L, M, n, o, p, Q, r, s, t, U, v, w, X, Y, Z)
     If IsNull(Izraz) Then
       Izraz = ""
     End If
     Izraz = UCase$(Izraz)
     Duzina = Len(Izraz)
    pomstr = ""
    
        For IJ = 0 To (Duzina - 1)
            pom = Mid(Izraz, IJ + 1, 1)
            If (pom >= "A" And pom <= "Z") Then
                indeks = Asc(pom) - Asc("A")
                pomstr = pomstr + CStr(strar(indeks))
            Else
                pomstr = pomstr + pom
            End If
        Next
        
    
        If Duzina = 0 Then VredIzraza = 0# Else VredIzraza = Eval(pomstr)
        
Exit_Izracunaj:
    Exit Function

Err_Izracunaj:
      ' MsgBox Err.Description
      VredIzraza = 0#
      Resume Exit_Izracunaj
    
End Function

Public Function VrednostZaSum(Izraz As String, Dug, Pot, DevDug, DevPot As Double) As Double
    Dim Vred As Variant
    Select Case Izraz
    Case "Duguje"
            Vred = Dug
    Case "Potrazuje"
            Vred = Pot
    Case "DevDuguje"
            Vred = DevDug
    Case "DevPotrazuje"
            Vred = DevPot
    Case Else
            Vred = 0
    End Select
    Vred = Nz(Vred, 0)
    If Not IsNumeric(Vred) Then Vred = 0
    VrednostZaSum = Vred
End Function
Public Function CTVrednostZaSum(Izraz As String, Dug As Currency, Pot As Currency, DevDug As Currency, DevPot As Currency, Saldo As Currency, DevSaldo As Currency) As Currency
    Dim Vred As Variant
    Select Case Izraz
    Case "Duguje"
            Vred = Dug
    Case "Potrazuje"
            Vred = Pot
    Case "DevDuguje"
            Vred = DevDug
    Case "DevPotrazuje"
            Vred = DevPot
    Case "Saldo"
            Vred = Saldo
    Case "DevSaldo"
            Vred = DevSaldo
    Case Else
            Vred = 0
    End Select
    On Error Resume Next
    Vred = CCur(Nz(Vred, 0))
    If Not IsNumeric(Vred) Then Vred = 0
    CTVrednostZaSum = Vred
End Function
