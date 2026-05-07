Attribute VB_Name = "FX_HALCOM"
Option Compare Database
Option Explicit

Public Function FX_DopuniTR(tr As String) As String
    Dim tr1, tr2, tr3, ntr, kb As String
    Dim OK As Boolean
    OK = False
    On Error Resume Next
    
    tr1 = Left$(tr, 3)
    tr2 = Mid$(tr, InStr(tr, "-") + 1, Len(tr) - 7)
                        ' Mid$("115-12411-79", InStr("115-12411-79", "-")+1, Len("115-12411-79") - 7)
    tr3 = Right$(tr, 2)
    tr2 = DoChLeft(tr2, 13, "0")
    ntr = tr1 & "-" & tr2 & "-" & tr3
    
    FX_DopuniTR = ntr
End Function
Public Function HALCOM_DopuniTR(tr As String) As String
    Dim tr1, tr2, tr3, ntr, kb As String
    Dim OK As Boolean
    OK = False
    On Error Resume Next
    
    tr1 = Left$(tr, 3)
    tr2 = Mid$(tr, InStr(tr, "-") + 1, Len(tr) - 7)
                        ' Mid$("115-12411-79", InStr("115-12411-79", "-")+1, Len("115-12411-79") - 7)
    tr3 = Right$(tr, 2)
    tr2 = DoChLeft(tr2, 13, "0")
    ntr = tr1 & "-" & tr2 & tr3
    
    HALCOM_DopuniTR = ntr
End Function

Public Function FX_OdrediBrojDokumentaPotrazuje(PozivNaBroj) As String
 On Error Resume Next
    Dim retVal
    Dim plz, pdz As Integer
    plz = InStr(1, PozivNaBroj, "(")
    pdz = InStr(1, PozivNaBroj, ")")
    retVal = Mid$(PozivNaBroj, plz + 1, pdz - plz - 1)
    If IsEmpty(retVal) Or retVal = "" Then retVal = "-"
    FX_OdrediBrojDokumentaPotrazuje = Nz(retVal, "-")
End Function
Public Function FX_OdrediBrojDokumentaDuguje(PozivNaBroj) As String
On Error Resume Next
    Dim retVal
    Dim plz, pdz, pkc As Integer
    pkc = InStr(1, PozivNaBroj, "/")
    plz = InStr(pkc + 1, PozivNaBroj, "(")
    pdz = InStr(pkc + 1, PozivNaBroj, ")")
    retVal = Mid$(PozivNaBroj, plz + 1, pdz - plz - 1)
    
    If IsEmpty(retVal) Or retVal = "" Then retVal = "-"
    FX_OdrediBrojDokumentaDuguje = Nz(retVal, "-")
End Function

Public Function IznosIgnorSep2Dec(InIznos As Variant) As Currency
 Dim i As Integer
 Dim stiznosbezsep As String
 Dim retVal As Currency
 Dim Znak As String
 Dim numznak As Currency
 Dim stIznos As String
    stIznos = CStr(Nz(InIznos, ""))
    stiznosbezsep = "0"
    stIznos = Trim$(stIznos)
    Znak = Left$(stIznos, 1)
    If Znak = "-" Then numznak = -1 Else numznak = 1
    For i = 1 To Len(stIznos)
        If IsNumeric(Mid$(stIznos, i, 1)) Then stiznosbezsep = stiznosbezsep & Mid$(stIznos, i, 1)
    Next i
    
    retVal = CDbl(stiznosbezsep)
    retVal = retVal / 100
    IznosIgnorSep2Dec = numznak * retVal
End Function

Public Function UbaciCrticeUTR(stTR) As String
On Error Resume Next
    Dim retVal As String
    retVal = CStr(stTR)
    retVal = Left$(stTR, 3) & "-" & Mid$(stTR, 4, Len(stTR) - 5) & "-" & Right$(stTR, 2)
    UbaciCrticeUTR = IIf(Nz(retVal, "-") = "", "-", Nz(retVal, "-"))
End Function

Public Function ImeFajlaBezExtiPutanje(stFileName) As String
On Error Resume Next
 Dim retVal As String
    retVal = Left$(stFileName, Len(stFileName) - 4)
    ' InStr(1,"\",stFileName)
    Do While InStr(1, retVal, "\") > 0
     retVal = Right$(retVal, Len(retVal) - InStr(1, retVal, "\"))
    Loop
    ImeFajlaBezExtiPutanje = retVal
End Function
Public Function PutanjaDoFajla(stFileName) As String
On Error GoTo HandleErrors
 Dim retVal As String
  
 retVal = Nz(stFileName, "")
 
 If retVal Like "*\*" Then
  If Nz(stFileName, "") <> "" Then
     retVal = stFileName
     Do While Right$(retVal, 1) <> "\"
      retVal = Left$(retVal, Len(retVal) - 1)
     Loop
  Else
    retVal = ""
  End If
End If
 
ExitHere:
    PutanjaDoFajla = retVal
 Exit Function
 
HandleErrors:
    MsgBox "Error: " & err.Description & " (" & err.Number & ")"
    Resume ExitHere
End Function
Public Function IzaberiFajlZaImport(Optional ZagStr = "Izaberite fajl") As Variant
Dim lngFlags As Long
Dim ImeFajla As Variant
    Dim gfni As adh_accOfficeGetFileNameInfo
    
    On Error GoTo HandleErrors
    
    With gfni
        .lngFlags = lngFlags
        '.strFilter = "TXT Files (*.txt) '.strFilter = "XML Files (*.xml)"
        .lngFilterIndex = CInt("1")
        .strFile = ""
        .strDlgTitle = ZagStr
        .strOpenTitle = "Select"
        .strFile = ""
        .strInitialDir = PutanjaDoFajla(Forms![FX_HAL_KnjizenjeIzvoda]!ImportIzFajla) '"D:\tmp" 'PutanjaDoFajla(Forms![FX_HAL_KnjizenjeIzvoda]!ImportIzFajla)
        '.strFile = "Z:\HALCOM\"
        '.strInitialDir = Forms![FX_HAL_KnjizenjeIzvoda]!ImportIzFajla
        
    End With
    If adhOfficeGetFileName(gfni, True) = adhcAccErrSuccess Then
        ImeFajla = Trim(gfni.strFile)
    Else
        ImeFajla = Null
    End If
    
ExitHere:
    IzaberiFajlZaImport = ImeFajla
    Exit Function

HandleErrors:
    MsgBox "Error: " & err.Description & " (" & err.Number & ")"
    Resume ExitHere
End Function

Public Sub PoveziKomitentePoBrDok(ByVal ImeUpitaUpdate As String, ByVal ImeTabeleZaUpdate As String)
 On Error GoTo err_PoveziKomitentePoBrDok
    Dim rst As DAO.Recordset
    Dim pRST As DAO.Recordset
    
    Set rst = CurrentDb.OpenRecordset(ImeUpitaUpdate, dbOpenForwardOnly)
    Set pRST = CurrentDb.OpenRecordset(ImeTabeleZaUpdate, dbOpenDynaset)
    While Not rst.EOF
        'Debug.Print rst("ID"), rst("NovaSifraKomitenta")
        pRST.FindFirst ("[ID] = " & rst("ID"))
        If Not pRST.NoMatch Then
            pRST.Edit
            pRST("Analiticka sifra") = rst("NovaSifraKomitenta")
            pRST.Update
        End If
        rst.MoveNext
    Wend
exit_PoveziKomitentePoBrDok:
    rst.Close
    Set rst = Nothing
    pRST.Close
    Set pRST = Nothing
Exit Sub
err_PoveziKomitentePoBrDok:
    MsgBox "Error: " & err.Number & vbCrLf & err.Description
    Resume exit_PoveziKomitentePoBrDok
End Sub
