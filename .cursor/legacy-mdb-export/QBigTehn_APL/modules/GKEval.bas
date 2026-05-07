Attribute VB_Name = "GKEval"
Option Compare Database
Option Explicit
Private ProzorUSvet As String
Private LikeFilter As String
'Private Const InicQDefBrutoStanje As String = "APGK_BrutoStanje"
Private pQDefBrutoStanje As String
Private pQDefAOPStanje As String

Private Function Din(Iznos) As String
Din = ""
On Error Resume Next
    If IsNull(Iznos) Or IsEmpty(Iznos) Or Iznos = "" Or Iznos = 0 Then
        Din = ""
    Else
        Din = Format$(Iznos, "##,###.00")
    End If
End Function
Public Function GKVrednostIzraza(Izraz) As Variant 'string => variant 22-01-2022
'modifikovano: 09-09-2023
Dim poslednjaleva As Long
Dim prvadesnaizaposlednjeleve As Long
Dim duzinastringa As Long
Dim srceizraza As String
Dim vrednostsrcaizraza As Variant
Dim retVal As Variant 'string => variant 22-01-2022

'ProzorUSvet = ""
    Izraz = CStr(Nz(Izraz, ""))
    Izraz = Replace(Izraz, " ", "")
    Izraz = Replace(Izraz, Chr(13), "")
    Izraz = Replace(Izraz, Chr(10), "")
    Izraz = Replace(Izraz, Chr(12), "")
    Izraz = Replace(Izraz, Chr(8), "")
    
    poslednjaleva = InStrRev(Izraz, "(")
    prvadesnaizaposlednjeleve = InStr(poslednjaleva + 1, Izraz, ")")
    duzinastringa = Len(Izraz)
    
    If poslednjaleva < prvadesnaizaposlednjeleve Then
        srceizraza = Mid$(Izraz, poslednjaleva + 1, prvadesnaizaposlednjeleve - poslednjaleva - 1)
        vrednostsrcaizraza = VrednostIzrazaBezZagrada(srceizraza)
        retVal = GKVrednostIzraza(Left$(Izraz, poslednjaleva - 1) & CStr(vrednostsrcaizraza) & Right$(Izraz, duzinastringa - prvadesnaizaposlednjeleve))
    Else
        retVal = VrednostIzrazaBezZagrada(Izraz)
    End If
    
    GKVrednostIzraza = retVal
End Function
Private Function VrednostIzraza(Izraz) As Currency
    ' izraz je tipa D202* + P433* - D021*
    Dim v
    Izraz = Trim(CStr(Nz(Izraz, "")))
    
    If InStr(Izraz, "+") Then
        v = VrednostIzraza(Left$(Izraz, InStr(Izraz, "+") - 1)) + VrednostIzraza(Right$(Izraz, Len(Izraz) - InStr(Izraz, "+")))
    ElseIf InStr(Izraz, "-") Then
        v = VrednostIzraza(Left$(Izraz, InStr(Izraz, "-") - 1)) - VrednostIzraza(Right$(Izraz, Len(Izraz) - InStr(Izraz, "-")))
    Else
        v = VrednostClanaIzraza(Izraz)
    End If
   VrednostIzraza = v
End Function

Private Function VrednostClanaIzraza(cizraz) As Currency
    'cizraz je tipa D201* ili A201
    'sto znaci zbir dugovne strane GK na stavkama cija su konta like 201*
    
    On Error GoTo err_ZRVrednostClanaIzraza

    Dim v, DugPotPS, likeUslov

    cizraz = Trim(CStr(Nz(cizraz, "")))
    DugPotPS = UCase$(Left$(cizraz, 3))
        
    If (DugPotPS = "PSD") Or (DugPotPS = "PSP") Then
        likeUslov = Right$(cizraz, Len(cizraz) - 3)
    Else
    DugPotPS = UCase$(Left$(cizraz, 2))
        If (DugPotPS = "AB") Or (DugPotPS = "AC") Then
            likeUslov = Right$(cizraz, Len(cizraz) - 2)
        Else
            DugPotPS = UCase$(Left$(cizraz, 1))
            likeUslov = Right$(cizraz, Len(cizraz) - 1)
        End If
    End If

    'If UCase$(DugPot) <> "D" And UCase$(DugPot) <> "P" And UCase$(DugPot) <> "A" And Not IsNumeric(Eval(cizraz)) Then
    '    GoTo err_ZRVrednostClanaIzraza
    'End If
    
    
    
    If UCase$(DugPotPS) = "D" Then
        v = DSum("[UkPrometDuguje]", QDefBrutoStanje, "[Konto] Like '" & likeUslov & "'")
    ElseIf UCase$(DugPotPS) = "P" Then
        v = DSum("[UkPrometPotrazuje]", QDefBrutoStanje, "[Konto] Like '" & likeUslov & "'")
    ElseIf UCase$(DugPotPS) = "PSD" Then
        v = DSum("[PSDuguje]", QDefBrutoStanje, "[Konto] Like '" & likeUslov & "'")
    ElseIf UCase$(DugPotPS) = "PSP" Then
        v = DSum("[PSPotrazuje]", QDefBrutoStanje, "[Konto] Like '" & likeUslov & "'")
    ElseIf UCase$(DugPotPS) = "A" Then
        'v = DSum("[Vred]", QDefAOPStanje, "[AOP] Like '" & likeUslov & "'")
        v = ADO_Lookup(CNN_CurrentDataBase, "[Vred]", QDefAOPStanje, "[AOP] Like '" & Replace(likeUslov, "*", "%") & "'")
    'ElseIf UCase$(DugPotPS) = "AB" Then
    '    v = DSum("[Iznos_2]", "ZR_Stavke_TG", "[AOP] Like '" & likeUslov & "'")
    'ElseIf UCase$(DugPotPS) = "AC" Then
    '    v = DSum("[Iznos_3]", "ZR_Stavke_TG", "[AOP] Like '" & likeUslov & "'")
    Else
        v = Eval(cizraz)
    End If
    
    'Debug.Print cizraz, Din(v)
    If Not IsNumeric(cizraz) Then
        ProzorUSvet = ProzorUSvet & Chr(13) & Chr(10) & cizraz & " = " & Din(v)
        LikeFilter = LikeFilter & ", " & cizraz
        
    End If
    
exit_ZRVrednostClanaIzraza:
    VrednostClanaIzraza = Nz(v, 0)
Exit Function

err_ZRVrednostClanaIzraza:
    v = 0
    Resume exit_ZRVrednostClanaIzraza
End Function
Private Function VrednostIzrazaBezZagrada(Izraz) As Variant
    Dim v
    Izraz = Trim(CStr(Nz(Izraz, "")))
    
    If InStr(Izraz, "NOT") Then
        v = Not VrednostIzrazaBezZagrada(Right$(Izraz, Len(Izraz) - InStr(Izraz, "NOT") - 2))
    ElseIf InStr(Izraz, "AND") Then
        v = VrednostIzrazaBezZagrada(Left$(Izraz, InStr(Izraz, "AND") - 1)) And VrednostIzrazaBezZagrada(Right$(Izraz, Len(Izraz) - InStr(Izraz, "AND") - 2))
    ElseIf InStr(Izraz, "XOR") Then
        v = VrednostIzrazaBezZagrada(Left$(Izraz, InStr(Izraz, "XOR") - 1)) Xor VrednostIzrazaBezZagrada(Right$(Izraz, Len(Izraz) - InStr(Izraz, "XOR") - 2))
    ElseIf InStr(Izraz, "OR") Then
        v = VrednostIzrazaBezZagrada(Left$(Izraz, InStr(Izraz, "OR") - 1)) Or VrednostIzrazaBezZagrada(Right$(Izraz, Len(Izraz) - InStr(Izraz, "OR") - 1))
    ElseIf InStr(Izraz, "<=") Then
        v = VrednostIzrazaBezZagrada(Left$(Izraz, InStr(Izraz, "<=") - 1)) <= VrednostIzrazaBezZagrada(Right$(Izraz, Len(Izraz) - InStr(Izraz, "<=") - 1))
    ElseIf InStr(Izraz, ">=") Then
        v = VrednostIzrazaBezZagrada(Left$(Izraz, InStr(Izraz, ">=") - 1)) >= VrednostIzrazaBezZagrada(Right$(Izraz, Len(Izraz) - InStr(Izraz, ">=") - 1))
    ElseIf InStr(Izraz, "<") Then
        v = VrednostIzrazaBezZagrada(Left$(Izraz, InStr(Izraz, "<") - 1)) < VrednostIzrazaBezZagrada(Right$(Izraz, Len(Izraz) - InStr(Izraz, "<")))
    ElseIf InStr(Izraz, ">") Then
        v = VrednostIzrazaBezZagrada(Left$(Izraz, InStr(Izraz, ">") - 1)) > VrednostIzrazaBezZagrada(Right$(Izraz, Len(Izraz) - InStr(Izraz, ">")))
    ElseIf InStr(Izraz, "=") Then
        v = VrednostIzrazaBezZagrada(Left$(Izraz, InStr(Izraz, "=") - 1)) = VrednostIzrazaBezZagrada(Right$(Izraz, Len(Izraz) - InStr(Izraz, "=")))
    Else
        v = VrednostIzraza(Izraz)
    End If
   VrednostIzrazaBezZagrada = v
End Function


Public Property Get QDefBrutoStanje() As String

 If (Nz(pQDefBrutoStanje, "") = "") Then
    'pQDefBrutoStanje = "APGK_BrutoStanje"
    pQDefBrutoStanje = "tmp_APGK_BrutoStanje"
 End If
 
 QDefBrutoStanje = pQDefBrutoStanje

End Property

Public Property Let QDefBrutoStanje(ByVal vNewValue As String)
    pQDefBrutoStanje = vNewValue
End Property

Public Property Get QDefAOPStanje() As String
'Kreirano: 22-01-2022
 If (Nz(QDefAOPStanje, "") = "") Then
    pQDefAOPStanje = "T_GK_IZV_Stavke"
 End If
 
 QDefAOPStanje = pQDefAOPStanje

End Property

Public Property Let QDefAOPStanje(ByVal vNewValue As String)
'Kreirano: 22-01-2022
    pQDefAOPStanje = vNewValue
End Property

