Attribute VB_Name = "LIB_SlovimaIznos"
Option Compare Database
'Option Explicit

Global Const sep = ""

Function BL_Slovima(Iznos As Double) As String
'Preuzeto od Srdjana Mitrovica - Hany iz firme Blue Line

Dim tmp1 As Long
Dim tmp2 As Long
Dim tmpstr As Variant

Dim rounded As Double

Dim pare As Long
Dim dosto As Long
Dim dohiljadu As Long
Dim hiljade As Long
Dim desetice As Long
Dim stotice As Long

Dim rezultat As String

rezultat = ""
Iznos = Abs(Iznos)
rounded = Format(Iznos, "00.00")
dosto = Fix(rounded)               ' celobrojna vrednost je ovde (tamo levo)
pare = (rounded - dosto) * 100

'  Pare


' Da li ima i dinara, ili su samo pare
If dosto <> 0 Then rezultat = rezultat & " i "

' Ovde su pare kao XX/100
rezultat = rezultat & Format(pare, "00") & "/100."

' Ovde su pare u recima
'If pare <> 0 Then
'    If dosto <> 0 Then rezultat = rezultat & Sep & "i" & Sep
'
'    tmp1 = pare - Fix(pare / 10) * 10
'    tmp2 = (pare - tmp1) / 10
''                      | Kad nemas program za konvertovanje muskog
''                      | u zenski rod, pravis dve kolone u tabeli,
''                      | musku i onu drugu.
'    tmpstr = DLookup("[Z Jedinice]", "[ZZ Brojevi]", "[Broj]=" & Str$(pare))
'    If IsNull(tmpstr) Then
'        rezultat = rezultat & DLookup("[Z Desetice]", "[ZZ Brojevi]", "[Broj]=" & Str$(tmp2))
'        rezultat = rezultat & Sep & DLookup("[Z Jedinice]", "[ZZ Brojevi]", "[Broj]=" & Str$(tmp1))
'
'        If (tmp1 > 1) And (tmp1 < 5) Then
'            ' Ne znam zasto ovo radim, jer ustvari nije bitno
'            ' da li imas pare ili imas para.
'            rezultat = rezultat & Sep & "pare"
'        Else
'            rezultat = rezultat & Sep & "para"
'        End If
'    Else
'        If (pare > 1) And (pare < 5) Then
'            rezultat = rezultat & tmpstr & Sep & "pare"
'        Else
'            rezultat = rezultat & tmpstr & Sep & "para"
'        End If
'    End If
'End If
'' I end sa parama, sada idemo na ozbiljnije stvari

'  Dinari (k'o dolari, Srbija do Tokija)

If dosto <> 0 Then
    If ((dosto - Fix(dosto / 10) * 10) = 1) And ((dosto - Fix(dosto / 100) * 100) <> 11) Then
    ' Da li je 11 dinar(a) ili 51 dinar, pitamo se mi...
        rezultat = sep & "dinar" & rezultat
    Else
        rezultat = sep & "dinara" & rezultat
    End If
Else
    ' Kroz ova vrata se izlazi samo ako je covek pazario za manje od 1 Din.
    ' (Which is not likely to happen, ali nema veze)
    BL_Slovima = rezultat
    Exit Function
End If

'  Desetice     (ovde se stize samo ako ih ima)

dohiljadu = dosto
dosto = dohiljadu - Fix(dohiljadu / 100) * 100
dohiljadu = Fix(dohiljadu / 100)    ' Ovde je neobradjeni ostatak
                                    ' (normalizovan - bez zadnjih nula)

tmp1 = dosto - Fix(dosto / 10) * 10
tmp2 = (dosto - tmp1) / 10

tmpstr = DLookup("[M Jedinice]", "[ZZ Brojevi]", "[Broj]=" & stR$(dosto))
If IsNull(tmpstr) Then
    rezultat = DLookup("[M Jedinice]", "[ZZ Brojevi]", "[Broj]=" & stR$(tmp1)) & rezultat
    rezultat = DLookup("[M Desetice]", "[ZZ Brojevi]", "[Broj]=" & stR$(tmp2)) & sep & rezultat
Else
    rezultat = tmpstr & rezultat
End If

'  Stotice

hiljade = dohiljadu
dohiljadu = hiljade - Fix(hiljade / 10) * 10
hiljade = Fix(hiljade / 10)                 ' Ovde su hiljade i ostalo,
                                            ' ako je covek imao toliko para
                                            ' (bez zadnjih nula, naravno)

If dohiljadu <> 0 Then
    ' O, srpski jezike...
    If dohiljadu > 1 And dohiljadu < 5 Then
        rezultat = sep & "stotine" & sep & rezultat
    Else
        rezultat = sep & "stotina" & sep & rezultat
    End If
    rezultat = DLookup("[Z Jedinice]", "[ZZ Brojevi]", "[Broj]=" & stR$(dohiljadu)) & rezultat
End If


'  Hiljade

stotice = hiljade - Fix(hiljade / 1000) * 1000
desetice = stotice - Fix(stotice / 100) * 100
stotice = Fix(stotice / 100)
tmp1 = desetice - Fix(desetice / 10) * 10
tmp2 = (desetice - tmp1) / 10

hiljade = Fix(hiljade / 1000)            ' Ovde su sada meleoni i ostalo
                                         ' (ko zna kad ce inflacija)

' Ovde sam brckao u subotu,
' j.... li ga da li sam ga napravio kako treba (hani)
If stotice <> 0 Or desetice <> 0 Then
    ' Opet prokleti izuzeci
    If tmp1 > 1 And tmp1 < 5 And tmp2 <> 1 Then
        rezultat = sep & "hiljade" & sep & rezultat
    Else
        rezultat = sep & "hiljada" & sep & rezultat
    End If
End If

tmpstr = DLookup("[Z Jedinice]", "[ZZ Brojevi]", "[Broj]=" & stR$(desetice))
If IsNull(tmpstr) Then
    rezultat = DLookup("[M Jedinice]", "[ZZ Brojevi]", "[Broj]=" & stR$(tmp1)) & rezultat
    rezultat = DLookup("[M Desetice]", "[ZZ Brojevi]", "[Broj]=" & stR$(tmp2)) & sep & rezultat
Else
    rezultat = tmpstr & rezultat
End If

If stotice <> 0 Then
    If stotice > 1 And stotice < 5 Then
        rezultat = sep & "stotine" & sep & rezultat
    Else
        rezultat = sep & "stotina" & sep & rezultat
    End If
    rezultat = DLookup("[Z Jedinice]", "[ZZ Brojevi]", "[Broj]=" & stR$(stotice)) & rezultat
End If

'  E, sad je stvarno dosta,
'  Kad naidje inflacija, zovite me...

If hiljade <> 0 Then rezultat = stR$(hiljade) & sep & "miliona" & sep & rezultat

BL_Slovima = rezultat

' PS: Tekst za ovu skladbu ukomponovao je Hani, programlija iz Pirot.
'     Ako padezi nisu u redu, prisetite se mog pirotskog porekla.
End Function

Function Slovima(BROJ, Optional DevValuta = "RSD") As String

Dim rez
Dim nzDevValutaJ As String
Dim nzDevValutaM As String

Select Case DevValuta
 Case "EUR": nzDevValutaJ = "eur"
             nzDevValutaM = "eura"
 Case "USD": nzDevValutaJ = "dolar"
             nzDevValutaM = "dolara"
 Case "CHF": nzDevValutaJ = "švajcarskifranak"
             nzDevValutaM = "švajcarskihfranaka"
 'Case "GBP": nzDevValutaJ = "britanskafunta"
 '            nzDevValutaM = "britanskihfunti"
Case "RSD", "Din", "Din."
            nzDevValutaJ = "dinar"
            nzDevValutaM = "dinara"
Case Else
            nzDevValutaJ = DevValuta
            nzDevValutaM = DevValuta
End Select

If Not IsNumeric(BROJ) Then
    Slovima = ""
    Exit Function
End If

If BROJ = 0 Then
  Slovima = "nula"
  Exit Function
End If

ReDim imebr(9)
imebr(1) = "jedan"
imebr(2) = "dva"
imebr(3) = "tri"
imebr(4) = "cetiri"
imebr(5) = "pet"
imebr(6) = "šest"
imebr(7) = "sedam"
imebr(8) = "osam"
imebr(9) = "devet"

If BROJ < 0 Then
    BROJ = Abs(BROJ)
    rez = "minus"
Else
    rez = ""
End If

celi = Int(BROJ)
dec = ((BROJ - celi) * 100) Mod 100
cbr = stR(celi)
'If Right$(cbr, 1) = "1" Then dinslv = "dinar" Else dinslv = "dinara"
'If Right$(cbr, 1) = "1" Then dinslv = nzDevValuta Else dinslv = nzDevValuta & "a"
If Right$(cbr, 1) = "1" Then dinslv = nzDevValutaJ Else dinslv = nzDevValutaM
Duzina = 16 - Len(cbr)
cbroj = String(Duzina, "0") & Right(cbr, Len(cbr) - 1)

i = 1

Do While i < 15
 tric = Mid(cbroj, i, 3)
 trojka = val(tric)

 If tric <> "000" Then
   cs = val(Mid(tric, 1, 1))
   cd = val(Mid(tric, 2, 1))
   cj = val(Mid(tric, 3, 1))
   Select Case cs
     Case 2
       rez = rez & "dve"
     Case Is > 2
       rez = rez & imebr(cs)
   End Select

   Select Case cs
     Case 1
       rez = rez & "stotinu"
     Case 2, 3, 4
       rez = rez & "stotine"
     Case Is > 4
       rez = rez & "stotina"
   End Select

   If cj = 0 Then Sl1 = "" Else Sl1 = imebr(cj)

   Select Case cd
     Case 4
       rez = rez & "cetr"
     Case 6
       rez = rez & "šez"
     Case 5
       rez = rez & "pe"
     Case 9
       rez = rez & "deve"
     Case 2, 3, 7, 8
       rez = rez & imebr(cd)
     Case 1
       Sl1 = ""
       Select Case cj
         Case 0
           rez = rez & "deset"
         Case 1
           rez = rez & "jeda"
         Case 4
           rez = rez & "cetr"
         Case Else
           rez = rez & imebr(cj)
       End Select

       If cj > 0 Then rez = rez & "naest"
    End Select

   If cd > 1 Then rez = rez & "deset"

   If (i = 4 Or i = 10) And cd <> 1 Then
     If cj = 1 Then
       Sl1 = "jedna"
     ElseIf cj = 2 Then
       Sl1 = "dve"
     End If
   End If

   rez = rez & Sl1

    Select Case i
     Case 1
       rez = rez & "bilion"
       If cj > 1 Or cd = 1 Then rez = rez & "a"
     Case 4
       rez = rez & "milijard"
       If ((trojka Mod 100) > 11 And _
          (trojka Mod 100) < 19) Then
         rez = rez & "i"
       ElseIf cj = 1 Then
         rez = rez & "a"
       ElseIf cj > 4 Or cj = 0 Then
         rez = rez & "i"
       ElseIf cj > 1 Then
         rez = rez & "e"
       End If
     Case 7
       rez = rez & "milion"
       If ((trojka Mod 100) > 11 And _
          (trojka Mod 100) < 19) Or cj <> 1 Then
         rez = rez & "a"
       End If
     Case 10
       rez = rez & "hiljad"
       If ((trojka Mod 100) > 11 And _
          (trojka Mod 100) < 19) Or cj = 1 Then
         rez = rez & "a"
       ElseIf trojka = 1 Then
         rez = rez & "u"
       ElseIf cj > 4 Or cj = 0 Then
         rez = rez & "a"
       ElseIf cj > 1 Then
         rez = rez & "e"
       End If
   End Select
 End If
 i = i + 3
Loop

Slovima = rez & dinslv & " i " & DoChLeft(Trim(stR(dec)), 2, "0") & "/100"

End Function


