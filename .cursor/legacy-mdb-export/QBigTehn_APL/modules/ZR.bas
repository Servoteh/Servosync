Attribute VB_Name = "ZR"
Option Compare Database
Option Explicit
Public ProzorUSvet As String
Public LikeFilter As String

Public Function VrednostPravilaZaUslov(Uslov, Pravilo) As Boolean
  ' uslov i Pravilo su tipa A001 < A002
  Uslov = Trim(CStr(Nz(Uslov, "")))
  Pravilo = Trim(CStr(Nz(Pravilo, "")))
  Dim v As Boolean
    
    If Nz(Uslov, "") = "" Or VrednostIzraza(Uslov, True) Then
        v = Nz(VrednostIzraza(Pravilo, False))
    Else
        v = True
    End If
   VrednostPravilaZaUslov = v
End Function

Public Function VrednostPravila(Pravilo, ClTg As Boolean) As Variant
  ' Pravilo je tipa A001 < A002
    Dim v
    Pravilo = Trim(CStr(Nz(Pravilo, "")))
    
    If InStr(Pravilo, "NOT") Then
        v = Not VrednostPravila(Right$(Pravilo, Len(Pravilo) - InStr(Pravilo, "NOT") - 2), ClTg)
    ElseIf InStr(Pravilo, "AND") Then
        v = VrednostPravila(Left$(Pravilo, InStr(Pravilo, "AND") - 1), ClTg) And VrednostPravila(Right$(Pravilo, Len(Pravilo) - InStr(Pravilo, "AND") - 2), ClTg)
    ElseIf InStr(Pravilo, "XOR") Then
        v = VrednostPravila(Left$(Pravilo, InStr(Pravilo, "XOR") - 1), ClTg) Xor VrednostPravila(Right$(Pravilo, Len(Pravilo) - InStr(Pravilo, "XOR") - 2), ClTg)
    ElseIf InStr(Pravilo, "OR") Then
        v = VrednostPravila(Left$(Pravilo, InStr(Pravilo, "OR") - 1), ClTg) Or VrednostPravila(Right$(Pravilo, Len(Pravilo) - InStr(Pravilo, "OR") - 1), ClTg)
    ElseIf InStr(Pravilo, "<=") Then
        v = ZRVrednostIzrazaTG(Left$(Pravilo, InStr(Pravilo, "<=") - 1), ClTg) <= ZRVrednostIzrazaTG(Right$(Pravilo, Len(Pravilo) - InStr(Pravilo, "<=") - 1), ClTg)
    ElseIf InStr(Pravilo, ">=") Then
        v = ZRVrednostIzrazaTG(Left$(Pravilo, InStr(Pravilo, ">=") - 1), ClTg) >= ZRVrednostIzrazaTG(Right$(Pravilo, Len(Pravilo) - InStr(Pravilo, ">=") - 1), ClTg)
    ElseIf InStr(Pravilo, "<") Then
        v = ZRVrednostIzrazaTG(Left$(Pravilo, InStr(Pravilo, "<") - 1), ClTg) < ZRVrednostIzrazaTG(Right$(Pravilo, Len(Pravilo) - InStr(Pravilo, "<")), ClTg)
    ElseIf InStr(Pravilo, ">") Then
        v = ZRVrednostIzrazaTG(Left$(Pravilo, InStr(Pravilo, ">") - 1), ClTg) > ZRVrednostIzrazaTG(Right$(Pravilo, Len(Pravilo) - InStr(Pravilo, ">")), ClTg)
    ElseIf InStr(Pravilo, "=") Then
        v = ZRVrednostIzrazaTG(Left$(Pravilo, InStr(Pravilo, "=") - 1), ClTg) = ZRVrednostIzrazaTG(Right$(Pravilo, Len(Pravilo) - InStr(Pravilo, "=")), ClTg)
    Else
        v = ZRVrednostIzrazaTG(Pravilo, ClTg)
    End If
   VrednostPravila = v
End Function

Public Function ZRVrednostIzrazaTG(Izraz, ClTg As Boolean) As Currency
    ' izraz je tipa D202* + P433* - D021*
    Dim v
    Izraz = Trim(CStr(Nz(Izraz, "")))
    
    If InStr(Izraz, "+") Then
        v = ZRVrednostIzrazaTG(Left$(Izraz, InStr(Izraz, "+") - 1), ClTg) + ZRVrednostIzrazaTG(Right$(Izraz, Len(Izraz) - InStr(Izraz, "+")), ClTg)
    ElseIf InStr(Izraz, "-") Then
        v = ZRVrednostIzrazaTG(Left$(Izraz, InStr(Izraz, "-") - 1), ClTg) - ZRVrednostIzrazaTG(Right$(Izraz, Len(Izraz) - InStr(Izraz, "-")), ClTg)
    Else
        If ClTg Then
            v = ZRVrednostClanaIzrazaTG(Izraz)
        Else
            v = ZRVrednostClanaIzrazaPGPS(Izraz)
        End If
    End If
   ZRVrednostIzrazaTG = v
End Function

Public Function ZRVrednostClanaIzrazaTG(cizraz) As Currency
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
        v = DSum("[Duguje]", "ZR_BrutoStanje_TG", "[Konto] Like '" & likeUslov & "'")
    ElseIf UCase$(DugPotPS) = "P" Then
        v = DSum("[Potrazuje]", "ZR_BrutoStanje_TG", "[Konto] Like '" & likeUslov & "'")
    ElseIf UCase$(DugPotPS) = "PSD" Then
        v = DSum("[PSDuguje]", "ZR_BrutoStanje_TG", "[Konto] Like '" & likeUslov & "'")
    ElseIf UCase$(DugPotPS) = "PSP" Then
        v = DSum("[PSPotrazuje]", "ZR_BrutoStanje_TG", "[Konto] Like '" & likeUslov & "'")
    ElseIf UCase$(DugPotPS) = "A" Then
        v = DSum("[Iznos_1]", "ZR_Stavke_TG", "[AOP] Like '" & likeUslov & "'")
    ElseIf UCase$(DugPotPS) = "AB" Then
        v = DSum("[Iznos_2]", "ZR_Stavke_TG", "[AOP] Like '" & likeUslov & "'")
    ElseIf UCase$(DugPotPS) = "AC" Then
        v = DSum("[Iznos_3]", "ZR_Stavke_TG", "[AOP] Like '" & likeUslov & "'")
    Else
        v = Eval(cizraz)
    End If
    
    'Debug.Print cizraz, Din(v)
    If Not IsNumeric(cizraz) Then
        ProzorUSvet = ProzorUSvet & Chr(13) & Chr(10) & cizraz & " = " & Din(v)
        LikeFilter = LikeFilter & ", " & cizraz
        
    End If
    
exit_ZRVrednostClanaIzraza:
    ZRVrednostClanaIzrazaTG = Nz(v, 0)
Exit Function

err_ZRVrednostClanaIzraza:
    v = 0
    Resume exit_ZRVrednostClanaIzraza
End Function

Public Sub ZR_EksportXML_Do15032015(imetkf As String)
'    <ZR_Izvestaj>
'    <ZR_Zaglavlje>
'        <Poreklo>1</Poreklo>
'        <Delovodni_Broj>1</Delovodni_Broj>
'        <Vrsta_Posla>750</Vrsta_Posla>
'        <JMB>06906273</JMB>
'        <Oznaka_Poste></Oznaka_Poste>
'        <Prijemno_Mesto></Prijemno_Mesto>
'        <PIB>101709764</PIB>
'        <Period>12</Period>
'        <Godina>5</Godina>
'        <Kodeks_19>0</Kodeks_19>
'        <Kodeks_20>1</Kodeks_20>
'        <Kodeks_21>0</Kodeks_21>
'        <Kodeks_22>2</Kodeks_22>
'        <Kodeks_23>0</Kodeks_23>
'        <Kodeks_24>0</Kodeks_24>
'        <Kodeks_25>0</Kodeks_25>
'        <Kodeks_26>10</Kodeks_26'>
'    </ZR_Zaglavlje>
'    <AOP_Item>
'        <Redni_Broj>1</Redni_Broj>
'        <Iznos_1>2000</Iznos_1>
'        <Iznos_2>1000</Iznos_2>
'    </AOP_Item>
'</ZR_Izvestaj>
    On Error GoTo errsnimi

    Dim BigBit As DAO.Database
    Dim Q_ZRStavkeZaExport As DAO.QueryDef
    Dim ZRStavkeZaExport As DAO.Recordset
    Dim imeteke As String
    Dim tkf As Variant
    Dim cenast As String
    Dim tmpst As String
    Dim mch As Byte
    Dim i As Integer
    
 
    DoCmd.Hourglass True

    Set BigBit = CurrentDb
    Set Q_ZRStavkeZaExport = BigBit.QueryDefs("ZR_StavkeZaExport")
    Q_ZRStavkeZaExport.Parameters("[Forms]![ZR_UnosZaglavlja]![IDZR]") = [Forms]![ZR_UnosZaglavlja]![IDZR]
    Q_ZRStavkeZaExport.Parameters("[Forms]![ZR_UnosZaglavlja]![ZR_UnosStavki].[Form]![ComboZaObrazac]") = [Forms]![ZR_UnosZaglavlja]![ZR_UnosStavki].[Form]![ComboZaObrazac]
    'QCenovnikZaTXT.Sort ("AOP")

    Set ZRStavkeZaExport = Q_ZRStavkeZaExport.OpenRecordset()
    
   
 
    imeteke = imetkf
    
    tkf = FreeFile
    Open imeteke For Output As tkf 'brisanje sadrzaja fajla i otvaranje novog (praznog) ako ne postoji
    
    Print #tkf, "<ZR_Izvestaj>"
    Print #tkf, "<ZR_Zaglavlje>"
    Print #tkf, "<Poreklo>1</Poreklo>"
    Print #tkf, "<Delovodni_Broj>1</Delovodni_Broj>"
    Print #tkf, "<Vrsta_Posla>" & ZRStavkeZaExport![VrstaPosla] & "</Vrsta_Posla>"
    Print #tkf, "<JMB>" & ZRStavkeZaExport![MaticniBroj] & "</JMB>"
    Print #tkf, "<Oznaka_Poste></Oznaka_Poste>"
    Print #tkf, "<Prijemno_Mesto></Prijemno_Mesto>"
    Print #tkf, "<PIB>" & ZRStavkeZaExport![PIB] & "</PIB>"
    Print #tkf, "<Period>" & ZRStavkeZaExport![BrojMeseciPoslovanja] & "</Period>"
    Print #tkf, "<Godina>" & ZRStavkeZaExport![Godina] & "</Godina>"
    Print #tkf, "<Kodeks_19>" & ZRStavkeZaExport![StatusnaPromena] & "</Kodeks_19>"
    Print #tkf, "<Kodeks_20>" & ZRStavkeZaExport![VelicinaPreduzecaTG] & "</Kodeks_20>"
    Print #tkf, "<Kodeks_21>0</Kodeks_21>"
    Print #tkf, "<Kodeks_22>" & ZRStavkeZaExport![VrstaSvojine] & "</Kodeks_22>"
    Print #tkf, "<Kodeks_23>0</Kodeks_23>"
    Print #tkf, "<Kodeks_24>0</Kodeks_24>"
    Print #tkf, "<Kodeks_25>" & ZRStavkeZaExport![Kodeks25] & "</Kodeks_25>"
    Print #tkf, "<Kodeks_26>" & ZRStavkeZaExport![KojeSeGodinePopunjavaju] & "</Kodeks_26>"
    Print #tkf, "</ZR_Zaglavlje>"
    
   ZRStavkeZaExport.MoveFirst
   Do Until ZRStavkeZaExport.EOF
    Print #tkf, "<AOP_Item>"
    Print #tkf, "<Redni_Broj>" & ZRStavkeZaExport![AOP] & "</Redni_Broj>"
    Print #tkf, "<Iznos_1>" & Round(Nz(ZRStavkeZaExport![Iznos_1], 0), 0) & "</Iznos_1>"
    Print #tkf, "<Iznos_2>" & Round(Nz(ZRStavkeZaExport![Iznos_2], 0), 0) & "</Iznos_2>"
    Print #tkf, "<Iznos_3>" & Round(Nz(ZRStavkeZaExport![Iznos_3], 0), 0) & "</Iznos_3>"
    Print #tkf, "</AOP_Item>"
   
   ZRStavkeZaExport.MoveNext
   Loop
   Print #tkf, "</ZR_Izvestaj>"
   Close tkf
    
    MsgBox "Podaci su uspesno snimljeni!"
   
reserr:
'On Error Resume Next
   Close tkf

   
   Set ZRStavkeZaExport = Nothing
   Set Q_ZRStavkeZaExport = Nothing
   Set BigBit = Nothing
   DoCmd.Hourglass False
 Exit Sub

errsnimi:
  MsgBox "Podaci nisu snimljeni korektno!"
  MsgBox Error$
  Resume reserr

End Sub
Public Sub ZR_EksportXML_BS(imetkf As String)

 
' <ZR_Izvestaj>
'    <Naziv>Bilans stanja</Naziv>
'    <NumerickaPoljaForme>
'        <a:NumerickoPolje xmlns:a="http://schemas.datacontract.org/2004/07/AppDef">
'            <a:Naziv>aop-9001-3</a:Naziv>
'            <a:Vrednosti>1</a:Vrednosti>           '              "i:nil = "true""
'        </a:NumerickoPolje>
'    </NumerickaPoljaForme>
'</ZR_Izvestaj>
    On Error GoTo errsnimi

    Dim BigBit As DAO.Database
    Dim Q_ZRStavkeZaExport As DAO.QueryDef
    Dim ZRStavkeZaExport As DAO.Recordset
    Dim imeteke As String
    Dim tkf As Variant
    Dim cenast As String
    Dim tmpst As String
    Dim mch As Byte
    Dim i As Integer
    
 
    DoCmd.Hourglass True

    Set BigBit = CurrentDb
    Set Q_ZRStavkeZaExport = BigBit.QueryDefs("ZR_StavkeZaExport")
    Q_ZRStavkeZaExport.Parameters("[Forms]![ZR_UnosZaglavlja]![IDZR]") = [Forms]![ZR_UnosZaglavlja]![IDZR]
    Q_ZRStavkeZaExport.Parameters("[Forms]![ZR_UnosZaglavlja]![ZR_UnosStavki].[Form]![ComboZaObrazac]") = "BS"  '[Forms]![ZR_UnosZaglavlja]![ZR_UnosStavki].[Form]![ComboZaObrazac]
    'QCenovnikZaTXT.Sort ("AOP")

    Set ZRStavkeZaExport = Q_ZRStavkeZaExport.OpenRecordset()
    
   
 
    imeteke = imetkf
    
    tkf = FreeFile
    Open imeteke For Output As tkf 'brisanje sadrzaja fajla i otvaranje novog (praznog) ako ne postoji
    tmpst = "<FiForma xmlns=""http://schemas.datacontract.org/2004/07/Domain.Model"" xmlns:i=""http://www.w3.org/2001/XMLSchema-instance""><Naziv>Bilans stanja</Naziv><NumerickaPoljaForme xmlns:a=""http://schemas.datacontract.org/2004/07/AppDef"">"
    
   ' Print #tkf, "<FiForma>"
   ' Print #tkf, "<Naziv>Bilans stanja</Naziv>"
   ' Print #tkf, "<NumerickaPoljaForme>"
   Print #tkf, tmpst
    
   ZRStavkeZaExport.MoveFirst
   
   Do Until ZRStavkeZaExport.EOF
    Print #tkf, "<a:NumerickoPolje>"
    Print #tkf, "<a:Naziv>" & "aop-" & ZRStavkeZaExport![AOP] & "-" & CStr(ZRStavkeZaExport![StartnaKolona] + 0) & "</a:Naziv>"
    'Print #tkf, "<a:Vrednosti>" & Round(Nz(ZRStavkeZaExport![Iznos_1], 0), 0) & "</a:Vrednosti>"
    'Print #tkf, "<a:Vrednosti" & IIf(Round(Nz(ZRStavkeZaExport![Iznos_1], 0), 0) = 0, " i:nil = ""true""" & "/>", ">" & Round(Nz(ZRStavkeZaExport![Iznos_1], 0), 0) & "</a:Vrednosti>")
    Print #tkf, XmlTag("a:Vrednosti", ZRStavkeZaExport![Iznos_1])
    Print #tkf, "</a:NumerickoPolje>"
   
    If ZRStavkeZaExport![BrojKolona] >= 2 Then
        Print #tkf, "<a:NumerickoPolje>"
        Print #tkf, "<a:Naziv>" & "aop-" & ZRStavkeZaExport![AOP] & "-" & CStr(ZRStavkeZaExport![StartnaKolona] + 1) & "</a:Naziv>"
        'Print #tkf, "<a:Vrednosti>" & Round(Nz(ZRStavkeZaExport![Iznos_2], 0), 0) & "</a:Vrednosti>"
        Print #tkf, XmlTag("a:Vrednosti", ZRStavkeZaExport![Iznos_2])
        Print #tkf, "</a:NumerickoPolje>"
    End If
    
    If ZRStavkeZaExport![BrojKolona] >= 3 Then
        Print #tkf, "<a:NumerickoPolje>"
        Print #tkf, "<a:Naziv>" & "aop-" & ZRStavkeZaExport![AOP] & "-" & CStr(ZRStavkeZaExport![StartnaKolona] + 2) & "</a:Naziv>"
        'Print #tkf, "<a:Vrednosti>" & Round(Nz(ZRStavkeZaExport![Iznos_2], 0), 0) & "</a:Vrednosti>"
        Print #tkf, XmlTag("a:Vrednosti", ZRStavkeZaExport![Iznos_3])
        Print #tkf, "</a:NumerickoPolje>"
    End If
   
   ZRStavkeZaExport.MoveNext
   Loop
   Print #tkf, "</NumerickaPoljaForme>"
   
   Print #tkf, "<TekstualnaPoljaForme>"
   
   ZRStavkeZaExport.MoveFirst
   
   Do Until ZRStavkeZaExport.EOF
    Print #tkf, "<TekstualnoPolje>"
    Print #tkf, "<Naziv>" & "aop-" & ZRStavkeZaExport![AOP] & "-" & CStr(ZRStavkeZaExport![StartnaKolona] - 1) & "</Naziv>"
    Print #tkf, "<Vrednosti>" & "" & "</Vrednosti>"
    Print #tkf, "</TekstualnoPolje>"
    
   ZRStavkeZaExport.MoveNext
   Loop
   Print #tkf, "</TekstualnaPoljaForme>"
   
   Print #tkf, "</FiForma>"
   Close tkf
    
    MsgBox "Bilans stanja uspeöno exportovan u fajl:" & vbCrLf & imetkf, vbInformation, "BigZR"
   
reserr:
'On Error Resume Next
   Close tkf

   
   Set ZRStavkeZaExport = Nothing
   Set Q_ZRStavkeZaExport = Nothing
   Set BigBit = Nothing
   DoCmd.Hourglass False
 Exit Sub

errsnimi:
  MsgBox "Bilans stanja NIJE uspeöno exportovan u fajl:" & vbCrLf & imetkf, vbCritical, "BigZR"
  MsgBox Error$
  Resume reserr

End Sub
Public Sub ZR_EksportXML_BU(imetkf As String)

 
' <FiForma>
'    <Naziv>Bilans stanja</Naziv>
'    <NumerickaPoljaForme>
'        <a:NumerickoPolje xmlns:a="http://schemas.datacontract.org/2004/07/AppDef">
'            <a:Naziv>aop-9001-3</a:Naziv>
'            <a:Vrednosti>1</a:Vrednosti>           '              "i:nil = "true""
'        </a:NumerickoPolje>
'    </NumerickaPoljaForme>
'</FiForma>
    On Error GoTo errsnimi

    Dim BigBit As DAO.Database
    Dim Q_ZRStavkeZaExport As DAO.QueryDef
    Dim ZRStavkeZaExport As DAO.Recordset
    Dim imeteke As String
    Dim tkf As Variant
    Dim cenast As String
    Dim tmpst As String
    Dim mch As Byte
    Dim i As Integer
    
 
    DoCmd.Hourglass True

    Set BigBit = CurrentDb
    Set Q_ZRStavkeZaExport = BigBit.QueryDefs("ZR_StavkeZaExport")
    Q_ZRStavkeZaExport.Parameters("[Forms]![ZR_UnosZaglavlja]![IDZR]") = [Forms]![ZR_UnosZaglavlja]![IDZR]
    Q_ZRStavkeZaExport.Parameters("[Forms]![ZR_UnosZaglavlja]![ZR_UnosStavki].[Form]![ComboZaObrazac]") = "BU"  '[Forms]![ZR_UnosZaglavlja]![ZR_UnosStavki].[Form]![ComboZaObrazac]
    'QCenovnikZaTXT.Sort ("AOP")

    Set ZRStavkeZaExport = Q_ZRStavkeZaExport.OpenRecordset()
    
   
 
    imeteke = imetkf
    
    tkf = FreeFile
    Open imeteke For Output As tkf 'brisanje sadrzaja fajla i otvaranje novog (praznog) ako ne postoji
    tmpst = "<FiForma xmlns=""http://schemas.datacontract.org/2004/07/Domain.Model"" xmlns:i=""http://www.w3.org/2001/XMLSchema-instance""><Naziv>Bilans uspeha</Naziv><NumerickaPoljaForme xmlns:a=""http://schemas.datacontract.org/2004/07/AppDef"">"
    
   ' Print #tkf, "<FiForma>"
   ' Print #tkf, "<Naziv>Bilans stanja</Naziv>"
   ' Print #tkf, "<NumerickaPoljaForme>"
   Print #tkf, tmpst
    
   ZRStavkeZaExport.MoveFirst
   
   Do Until ZRStavkeZaExport.EOF
    Print #tkf, "<a:NumerickoPolje>"
    Print #tkf, "<a:Naziv>" & "aop-" & ZRStavkeZaExport![AOP] & "-" & CStr(ZRStavkeZaExport![StartnaKolona] + 0) & "</a:Naziv>"
    Print #tkf, "<a:Vrednosti>" & Round(Nz(ZRStavkeZaExport![Iznos_1], 0), 0) & "</a:Vrednosti>"
    Print #tkf, "</a:NumerickoPolje>"
   
    If ZRStavkeZaExport![BrojKolona] >= 2 Then
        Print #tkf, "<a:NumerickoPolje>"
        Print #tkf, "<a:Naziv>" & "aop-" & ZRStavkeZaExport![AOP] & "-" & CStr(ZRStavkeZaExport![StartnaKolona] + 1) & "</a:Naziv>"
        Print #tkf, "<a:Vrednosti>" & Round(Nz(ZRStavkeZaExport![Iznos_2], 0), 0) & "</a:Vrednosti>"
        Print #tkf, "</a:NumerickoPolje>"
    End If
    
   
   ZRStavkeZaExport.MoveNext
   Loop
   Print #tkf, "</NumerickaPoljaForme>"
   
   Print #tkf, "<TekstualnaPoljaForme>"
   
   ZRStavkeZaExport.MoveFirst
   
   Do Until ZRStavkeZaExport.EOF
    Print #tkf, "<TekstualnoPolje>"
    Print #tkf, "<Naziv>" & "aop-" & ZRStavkeZaExport![AOP] & "-" & CStr(ZRStavkeZaExport![StartnaKolona] - 1) & "</Naziv>"
    Print #tkf, "<Vrednosti>" & "" & "</Vrednosti>"
    Print #tkf, "</TekstualnoPolje>"
    
   ZRStavkeZaExport.MoveNext
   Loop
   Print #tkf, "</TekstualnaPoljaForme>"
   
   Print #tkf, "</FiForma>"
   Close tkf
    
    MsgBox "Bilans uspeha uspeöno exportovan u fajl:" & vbCrLf & imetkf, vbInformation, "BigZR"
   
reserr:
'On Error Resume Next
   Close tkf

   
   Set ZRStavkeZaExport = Nothing
   Set Q_ZRStavkeZaExport = Nothing
   Set BigBit = Nothing
   DoCmd.Hourglass False
 Exit Sub

errsnimi:
  MsgBox "Bilans uspeha NIJE uspeöno exportovan u fajl:" & vbCrLf & imetkf, vbCritical, "BigZR"
  MsgBox Error$
  Resume reserr

End Sub
Public Sub ZR_EksportXML_SI(imetkf As String)

 
' <FiForma>
'    <Naziv>Bilans stanja</Naziv>
'    <NumerickaPoljaForme>
'        <a:NumerickoPolje xmlns:a="http://schemas.datacontract.org/2004/07/AppDef">
'            <a:Naziv>aop-9001-3</a:Naziv>
'            <a:Vrednosti>1</a:Vrednosti>           '              "i:nil = "true""
'        </a:NumerickoPolje>
'    </NumerickaPoljaForme>
'</FiForma>
    On Error GoTo errsnimi

    Dim BigBit As DAO.Database
    Dim Q_ZRStavkeZaExport As DAO.QueryDef
    Dim ZRStavkeZaExport As DAO.Recordset
    Dim imeteke As String
    Dim tkf As Variant
    Dim cenast As String
    Dim tmpst As String
    Dim mch As Byte
    Dim i As Integer
    
 
    DoCmd.Hourglass True

    Set BigBit = CurrentDb
    Set Q_ZRStavkeZaExport = BigBit.QueryDefs("ZR_StavkeZaExport")
    Q_ZRStavkeZaExport.Parameters("[Forms]![ZR_UnosZaglavlja]![IDZR]") = [Forms]![ZR_UnosZaglavlja]![IDZR]
    Q_ZRStavkeZaExport.Parameters("[Forms]![ZR_UnosZaglavlja]![ZR_UnosStavki].[Form]![ComboZaObrazac]") = "SI"  '[Forms]![ZR_UnosZaglavlja]![ZR_UnosStavki].[Form]![ComboZaObrazac]
    'QCenovnikZaTXT.Sort ("AOP")

    Set ZRStavkeZaExport = Q_ZRStavkeZaExport.OpenRecordset()
    
   
 
    imeteke = imetkf
    
    tkf = FreeFile
    Open imeteke For Output As tkf 'brisanje sadrzaja fajla i otvaranje novog (praznog) ako ne postoji
    'tmpst = "<FiForma xmlns=""http://schemas.datacontract.org/2004/07/Domain.Model"" xmlns:i=""http://www.w3.org/2001/XMLSchema-instance""><Naziv>StatistiËki izveötaj</Naziv><NumerickaPoljaForme xmlns:a=""http://schemas.datacontract.org/2004/07/AppDef"">"
    'tmpst = "<FiForma xmlns=""http://schemas.datacontract.org/2004/07/Domain.Model"" xmlns:i=""http://www.w3.org/2001/XMLSchema-instance""><Naziv>StatistiËki izveötaj</Naziv><NumerickaPoljaForme xmlns:a=""http://schemas.datacontract.org/2004/07/AppDef"">"
    tmpst = "<FiForma xmlns=""http://schemas.datacontract.org/2004/07/Domain.Model"" xmlns:i=""http://www.w3.org/2001/XMLSchema-instance""><Naziv>Statistiƒçki izve≈°taj</Naziv><NumerickaPoljaForme xmlns:a=""http://schemas.datacontract.org/2004/07/AppDef"">"
   ' Print #tkf, "<FiForma>"
   ' Print #tkf, "<Naziv>Bilans stanja</Naziv>"
   ' Print #tkf, "<NumerickaPoljaForme>"
   'Print #tkf, "<?xml version=""1.0"" encoding=""utf-8""?>"
   'Print #tkf, StrConv(tmpst, vbUnicode)
   Print #tkf, tmpst
    
   ZRStavkeZaExport.MoveFirst
   
   Do Until ZRStavkeZaExport.EOF
    Print #tkf, "<a:NumerickoPolje>"
    Print #tkf, "<a:Naziv>" & "aop-" & ZRStavkeZaExport![AOP] & "-" & CStr(ZRStavkeZaExport![StartnaKolona] + 0) & "</a:Naziv>"
    Print #tkf, "<a:Vrednosti>" & Round(Nz(ZRStavkeZaExport![Iznos_1], 0), 0) & "</a:Vrednosti>"
    Print #tkf, "</a:NumerickoPolje>"
   
    If ZRStavkeZaExport![BrojKolona] >= 2 Then
        Print #tkf, "<a:NumerickoPolje>"
        Print #tkf, "<a:Naziv>" & "aop-" & ZRStavkeZaExport![AOP] & "-" & CStr(ZRStavkeZaExport![StartnaKolona] + 1) & "</a:Naziv>"
        Print #tkf, "<a:Vrednosti>" & Round(Nz(ZRStavkeZaExport![Iznos_2], 0), 0) & "</a:Vrednosti>"
        Print #tkf, "</a:NumerickoPolje>"
    End If
    
    If ZRStavkeZaExport![BrojKolona] >= 3 Then
        Print #tkf, "<a:NumerickoPolje>"
        Print #tkf, "<a:Naziv>" & "aop-" & ZRStavkeZaExport![AOP] & "-" & CStr(ZRStavkeZaExport![StartnaKolona] + 2) & "</a:Naziv>"
        Print #tkf, "<a:Vrednosti>" & Round(Nz(ZRStavkeZaExport![Iznos_2], 0), 0) & "</a:Vrednosti>"
        Print #tkf, "</a:NumerickoPolje>"
    End If
   
   ZRStavkeZaExport.MoveNext
   Loop
   Print #tkf, "</NumerickaPoljaForme>"
   Print #tkf, "<TekstualnaPoljaForme/>"
   Print #tkf, "</FiForma>"
   Close tkf
    
    MsgBox "StatistiËki izveötaj uspeöno exportovan u fajl:" & vbCrLf & imetkf, vbInformation, "BigZR"
   
reserr:
'On Error Resume Next
   Close tkf

   
   Set ZRStavkeZaExport = Nothing
   Set Q_ZRStavkeZaExport = Nothing
   Set BigBit = Nothing
   DoCmd.Hourglass False
 Exit Sub

errsnimi:
  MsgBox "StatistiËki izveötaj NIJE uspeöno exportovan u fajl:" & vbCrLf & imetkf, vbCritical, "BigZR"
  MsgBox Error$
  Resume reserr

End Sub

Public Function VrednostIzraza(Izraz, ClTg As Boolean) As String
Dim poslednjaleva As Long
Dim prvadesnaizaposlednjeleve As Long
Dim duzinastringa As Long
Dim srceizraza As String
Dim vrednostsrcaizraza As Variant
Dim retVal As String

'ProzorUSvet = ""
    Izraz = CStr(Nz(Izraz, ""))
    poslednjaleva = InStrRev(Izraz, "(")
    prvadesnaizaposlednjeleve = InStr(poslednjaleva + 1, Izraz, ")")
    duzinastringa = Len(Izraz)
    
    If poslednjaleva < prvadesnaizaposlednjeleve Then
        srceizraza = Mid$(Izraz, poslednjaleva + 1, prvadesnaizaposlednjeleve - poslednjaleva - 1)
        vrednostsrcaizraza = VrednostIzrazaBezZagrada(srceizraza, ClTg)
        retVal = VrednostIzraza(Left$(Izraz, poslednjaleva - 1) & CStr(vrednostsrcaizraza) & Right$(Izraz, duzinastringa - prvadesnaizaposlednjeleve), ClTg)
    Else
        retVal = VrednostIzrazaBezZagrada(Izraz, ClTg)
    End If
    
    VrednostIzraza = retVal
End Function
Public Function VrednostIzrazaBezZagrada(Izraz, ClTg As Boolean) As Variant
    Dim v
    Izraz = Trim(CStr(Nz(Izraz, "")))
    
    If InStr(Izraz, "NOT") Then
        v = Not VrednostIzrazaBezZagrada(Right$(Izraz, Len(Izraz) - InStr(Izraz, "NOT") - 2), ClTg)
    ElseIf InStr(Izraz, "AND") Then
        v = VrednostIzrazaBezZagrada(Left$(Izraz, InStr(Izraz, "AND") - 1), ClTg) And VrednostIzrazaBezZagrada(Right$(Izraz, Len(Izraz) - InStr(Izraz, "AND") - 2), ClTg)
    ElseIf InStr(Izraz, "XOR") Then
        v = VrednostIzrazaBezZagrada(Left$(Izraz, InStr(Izraz, "XOR") - 1), ClTg) Xor VrednostIzrazaBezZagrada(Right$(Izraz, Len(Izraz) - InStr(Izraz, "XOR") - 2), ClTg)
    ElseIf InStr(Izraz, "OR") Then
        v = VrednostIzrazaBezZagrada(Left$(Izraz, InStr(Izraz, "OR") - 1), ClTg) Or VrednostIzrazaBezZagrada(Right$(Izraz, Len(Izraz) - InStr(Izraz, "OR") - 1), ClTg)
    ElseIf InStr(Izraz, "<=") Then
        v = VrednostIzrazaBezZagrada(Left$(Izraz, InStr(Izraz, "<=") - 1), ClTg) <= VrednostIzrazaBezZagrada(Right$(Izraz, Len(Izraz) - InStr(Izraz, "<=") - 1), ClTg)
    ElseIf InStr(Izraz, ">=") Then
        v = VrednostIzrazaBezZagrada(Left$(Izraz, InStr(Izraz, ">=") - 1), ClTg) >= VrednostIzrazaBezZagrada(Right$(Izraz, Len(Izraz) - InStr(Izraz, ">=") - 1), ClTg)
    ElseIf InStr(Izraz, "<") Then
        v = VrednostIzrazaBezZagrada(Left$(Izraz, InStr(Izraz, "<") - 1), ClTg) < VrednostIzrazaBezZagrada(Right$(Izraz, Len(Izraz) - InStr(Izraz, "<")), ClTg)
    ElseIf InStr(Izraz, ">") Then
        v = VrednostIzrazaBezZagrada(Left$(Izraz, InStr(Izraz, ">") - 1), ClTg) > VrednostIzrazaBezZagrada(Right$(Izraz, Len(Izraz) - InStr(Izraz, ">")), ClTg)
    ElseIf InStr(Izraz, "=") Then
        v = VrednostIzrazaBezZagrada(Left$(Izraz, InStr(Izraz, "=") - 1), ClTg) = VrednostIzrazaBezZagrada(Right$(Izraz, Len(Izraz) - InStr(Izraz, "=")), ClTg)
    Else
        v = ZRVrednostIzrazaTG(Izraz, ClTg)
    End If
   VrednostIzrazaBezZagrada = v
End Function
Public Function ZRVrednostClanaIzrazaPGPS(cizraz) As Currency
    'cizraz je tipa D201* ili A201
    'sto znaci zbir dugovne strane GK na stavkama cija su konta like 201*
    On Error GoTo err_ZRVrednostClanaIzrazaPGPS

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
        v = DSum("[Duguje]", "PSPG_BrutoStanje_PG", "[Konto] Like '" & likeUslov & "'")
    ElseIf UCase$(DugPotPS) = "P" Then
        v = DSum("[Potrazuje]", "PSPG_BrutoStanje_PG", "[Konto] Like '" & likeUslov & "'")
    ElseIf UCase$(DugPotPS) = "PSD" Then
        v = DSum("[PSDuguje]", "PSPG_BrutoStanje_PG", "[Konto] Like '" & likeUslov & "'")
    ElseIf UCase$(DugPotPS) = "PSP" Then
        v = DSum("[PSPotrazuje]", "PSPG_BrutoStanje_PG", "[Konto] Like '" & likeUslov & "'")
    ElseIf UCase$(DugPotPS) = "A" Then
        v = DSum("[Iznos_3]", "ZR_Stavke_TG", "[AOP] Like '" & likeUslov & "'")
    'ElseIf UCase$(DugPotPS) = "AB" Then
      '  v = DSum("[Iznos_2]", "PSPG_BrutoStanje_PG", "[AOP] Like '" & likeUslov & "'")
    'ElseIf UCase$(DugPotPS) = "AC" Then
       ' v = DSum("[Iznos_3]", "PSPG_BrutoStanje_PG", "[AOP] Like '" & likeUslov & "'")
    Else
        v = Eval(cizraz)
    End If
    
    'Debug.Print cizraz, Din(v)
    If Not IsNumeric(cizraz) Then
        ProzorUSvet = ProzorUSvet & Chr(13) & Chr(10) & cizraz & " = " & Din(v)
        LikeFilter = LikeFilter & ", " & cizraz
        
    End If
    
exit_ZRVrednostClanaIzrazaPGPS:
    ZRVrednostClanaIzrazaPGPS = Nz(v, 0)
Exit Function

err_ZRVrednostClanaIzrazaPGPS:
    v = 0
    Resume exit_ZRVrednostClanaIzrazaPGPS
End Function

