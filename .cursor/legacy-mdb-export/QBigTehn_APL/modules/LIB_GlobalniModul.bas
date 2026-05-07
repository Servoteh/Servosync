Attribute VB_Name = "LIB_GlobalniModul"
Option Compare Database
Option Explicit
Private pCurrentUser As String
Public Property Get CurrentUser() As String
    If pCurrentUser = "" Then
        If Application.CurrentUser = "Admin" Then
            pCurrentUser = "Negovan"
        Else
            pCurrentUser = Application.CurrentUser
        End If
    End If
    CurrentUser = pCurrentUser
End Property

Public Property Let CurrentUser(ByVal vNewValue As String)
    pCurrentUser = vNewValue
End Property
Function IsLoaded(MyFormName As String) As Boolean
'Modifikovano: 18-01-2020
' Accepts: a form name
' Purpose: determines if a form is loaded
' Returns: True if specified the form is loaded;
'          False if the specified form is not loaded.
' From: Access's Northwind database example (nwind.mdb)
    
    Dim i As Integer

    IsLoaded = False
    For i = 0 To Forms.Count - 1
        If Forms(i).FormName = MyFormName Then
            IsLoaded = True
            Exit Function       ' Quit function once form has been found.
        End If
    Next

End Function
Function IsLoadedReport(MyReportName)
' Kreirano: 19-01-2019
' Accepts: a report name
' Purpose: determines if a report is loaded
' Returns: True if specified the report is loaded;
'          False if the specified report is not loaded.

    
    Dim i

    IsLoadedReport = False
    For i = 0 To Reports.Count - 1
        If Reports(i).ReportName = MyReportName Then
            IsLoadedReport = True
            Exit Function       ' Quit function once report has been found.
        End If
    Next

End Function
Public Function UserUGrupi(ImeUsera As String, ImeGrupe As String) As Boolean
On Error GoTo err_UserUGrupi
    Dim usr As User
    Dim grp As Group
    
    UserUGrupi = False
    Set grp = DBEngine.Workspaces(0).Groups(ImeGrupe)
    
    For Each usr In grp.Users
        If usr.Name = ImeUsera Then
         UserUGrupi = True
         Exit For
        End If
    Next
exit_UserUGrupi:
    Set usr = Nothing
    Set grp = Nothing
Exit Function
err_UserUGrupi:
    Resume exit_UserUGrupi
End Function
Public Function DoChLeft(ByVal st As String, ByVal n As Integer, Optional ch As String = " ") As String

    Dim tmpst As Variant
    Dim i As Integer
    tmpst = st
    For i = Len(tmpst) + 1 To n
        tmpst = ch & tmpst
    Next i
    DoChLeft = tmpst
End Function
Public Function DoChRight(ByVal st As String, ByVal n As Integer, Optional ch As String = " ") As String

    Dim tmpst As Variant
    Dim i As Integer
    tmpst = st
    For i = Len(tmpst) + 1 To n
        tmpst = tmpst & ch
    Next i
    DoChRight = tmpst
End Function
Public Function BBOpenSysForm(stSysFormName As String, Optional SaPitanjem As Boolean = False)
On Error Resume Next

Dim stImeForme As String
    
stImeForme = stSysFormName
If CurrentUser <> "Negovan" Then
    DoCmd.OpenForm stImeForme
    Exit Function
End If
If SaPitanjem Then
 stImeForme = InputBox("Koju formu otvaraš?", "QMegaTeh", stImeForme)
End If
If Nz(stImeForme, "") <> "" Then
   DoCmd.OpenForm stImeForme
End If
End Function


''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'                     UTILITY FUNCTIONS                        '
'                                                              '
'       This module contains useful functions that you         '
'       can use in expressions on your forms and reports.      '
'                                                              '
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

Public Function SUM(ByRef ctl As control) As Variant
'Kreirano: 06-01-2021
On Error GoTo Err_Point

 If ctl.Parent.Recordset Is Nothing Then
    SUM = Null
 ElseIf TypeOf ctl.Parent.Recordset Is ADODB.Recordset Then
    SUM = ADO_Sum(ctl.Name, ctl.Parent.Recordset)
 Else
    SUM = DSum(ctl.Name, ctl.Parent.RecordSource)
 End If


Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "QBigTeh_LIB:Sum"
 Resume Exit_Point
End Function
Function FRound(X, n As Variant) As Double
Dim i, v, nv As Variant

    If IsNull(X) Then

        FRound = 0#

    Else
        v = 1
        For i = 1 To n
            v = v * 10
        Next i
        nv = X * v
        nv = Int(nv + 0.5)

        nv = nv / v
        FRound = nv
    End If
    
End Function


Function KontrolniBroj(BROJ As String) As String

Dim pBroj As String
Dim cifra As String
Dim K, Tezina As Long
Dim tz As Long

 pBroj = BROJ
 Tezina = 1
 tz = 0

 While pBroj <> ""

       Tezina = Tezina + 1

       cifra = Right(pBroj, 1)
       pBroj = Left(pBroj, Len(pBroj) - 1)

       Select Case cifra
            Case "1"
                K = 1
            Case "2"
                K = 2
            Case "3"
                K = 3
            Case "4"
                K = 4
            Case "5"
                K = 5
            Case "6"
                K = 6
            Case "7"
                K = 7
            Case "8"
                K = 8
            Case "9"
                K = 9
            Case "0"
                K = 0
            Case Else
                Tezina = Tezina - 1
                K = 0
       End Select

       tz = tz + K * Tezina

 Wend
 
 tz = tz Mod 11
 tz = 11 - tz
 If (tz = 10) Or (tz = 11) Then tz = 0
 KontrolniBroj = CStr(tz)

End Function

Function NulaBlanko(AnyValue As Variant)

  If AnyValue = 0 Then
        NulaBlanko = ""
    Else
        NulaBlanko = AnyValue
    End If
    

End Function

Function NullToZero(AnyValue As Variant) As Variant
On Error GoTo Err_NullToZero
' Accepts: a variant value
' Purpose: converts null values to zeros
' Returns: a zero or non-null value
' From: User's Guide Chapter 17


'    If IsEmpty(anyValue) Then
'        NullToZero = 0
'    ElseIf IsNull(anyValue) Then
'        NullToZero = 0
'    Else
'        NullToZero = anyValue
'    End If
    NullToZero = Nz(AnyValue, 0)
Exit_NullToZero:
    Exit Function

Err_NullToZero:
   ' MsgBox Err.Description
   ' MsgBox Err.Number
    NullToZero = 0
    Resume Exit_NullToZero
End Function
Function RastojanjeIzmedjuDatuma(ByVal dat1, ByVal dat2) As Long
'Modifikovano: 18-02-2022
 On Error GoTo Err_Point
    Dim d_Rast As Long

    If Not (IsNull(dat1) Or IsNull(dat2)) Then
     On Error Resume Next
        d_Rast = CVDate(dat2) - CVDate(dat1)
      If err.Number <> 0 Then
         d_Rast = 0
      End If
      On Error GoTo Err_Point
    Else
        d_Rast = 0
    End If
Exit_Point:
On Error Resume Next
    RastojanjeIzmedjuDatuma = d_Rast
Exit Function

Err_Point:
    BBErrorMSG err, "RastojanjeIzmedjuDatuma"
    d_Rast = 0
    Resume Exit_Point
End Function


Function MOJRound(X, n As Variant) As Double

Dim i, v, nv As Variant


   If Not IsNumeric(X) Then

      MOJRound = 0#

   Else
        v = 1
        For i = 1 To n
            v = v * 10
        Next i
        nv = X * v
        nv = Int(nv + 0.5)

        nv = nv / v
        MOJRound = nv
     
 End If

End Function
'********************************************************
'Postoji u modulu GALEB_FP550
'********************************************************
Sub Wait(n As Long)
 Dim StartTime As Variant
 StartTime = Timer
 n = n / 1000
 While Timer < StartTime + n
 Wend
End Sub
'*********************************************************

Function ZeroToNull(AnyValue As Variant) As Variant
On Error GoTo exit_Func
' Accepts: a variant value
' Purpose: converts nzeros values to null
' Returns:
' From: User's Guide Chapter 17
' Modifikovano:03-01-2020

    If IsNull(AnyValue) Then
        ZeroToNull = Null
    ElseIf IsNumeric(AnyValue) Then
        If AnyValue = 0 Then
           ZeroToNull = Null
        Else
           ZeroToNull = AnyValue
        End If
    Else
        ZeroToNull = AnyValue
    End If
exit_Func:
On Error Resume Next
End Function

Function ZeroStrToNull(AnyValue As Variant) As Variant
    If CStr(Nz(AnyValue, "")) = "" Then
        ZeroStrToNull = Null
    Else
        ZeroStrToNull = AnyValue
    End If
End Function
Public Function IzDatumaMesecIDan(DATUM As Variant) As String
Dim retstr As String
If IsDate(DATUM) Then
        retstr = Mid(DATUM, 4, 2) & Left(DATUM, 2)
Else
        retstr = ""
End If
IzDatumaMesecIDan = retstr
End Function
Public Function ObrniDatum_OLD(DATUM As Variant) As String
'Modifikovano: 07-06-2020
'Uamenjeno 24-12-2021

On Error GoTo Err_Point
   Dim retstr As String
   
   Dim Dan As String
   Dim Mesec As String
   Dim Godina As String
    
    If IsDate(DATUM) Then
        'RetStr = Right(Datum, 2) & Mid(Datum, 4, 2) & Left(Datum, 2)
        Dan = DoChLeft(DatePart("d", DATUM), 2, "0")
        Mesec = DoChLeft(DatePart("M", DATUM), 2, "0")
        Godina = Right(DoChLeft(DatePart("YYYY", DATUM), 4, "0"), 2)
        
        retstr = Godina & Mesec & Dan
        retstr = Replace(retstr, " ", "0")
    Else
        retstr = ""
    End If
    
Exit_Point:
 On Error Resume Next
    ObrniDatum_OLD = retstr
Exit Function

Err_Point:
 BBErrorMSG err, "ObrniDatum_OLD"
 Resume Exit_Point
End Function
Public Function ObrniDatum(DATUM As Variant) As String
On Error GoTo Err_Point
'Modifikovano 24-12-2021
    Dim retstr As String
    If IsDate(DATUM) Then
        'retstr = Right(Datum, 2) & Mid(Datum, 4, 2) & Left(Datum, 2)
        retstr = Right(Format(Year(DATUM), "0000"), 2) & Format(Month(DATUM), "00") & Format(Day(DATUM), "00")
    Else
        retstr = ""
    End If
ObrniDatum = retstr
Exit_Point:
 On Error Resume Next
    ObrniDatum = retstr
Exit Function

Err_Point:
 BBErrorMSG err, "ObrniDatum"
 Resume Exit_Point
End Function

Public Function ObrniVelikiDatum(DATUM As Variant) As String
    Dim retstr As String
    If IsDate(DATUM) Then
        retstr = DatePart("yyyy", DATUM) & DoChLeft(DatePart("m", DATUM), 2, "0") & DoChLeft(DatePart("d", DATUM), 2, "0")
    Else
        retstr = ""
    End If
ObrniVelikiDatum = retstr
End Function
Public Sub UradiRepairICompact(fName As String)
    DBEngine.RepairDatabase fName
    
    If FileExists(Mid(fName, 1, Len(fName) - 3) & "bak") Then
       Kill Mid(fName, 1, Len(fName) - 3) & "bak"
    End If
    Name fName As Mid(fName, 1, Len(fName) - 3) & "bak"
        DBEngine.CompactDatabase Mid(fName, 1, Len(fName) - 3) & "bak", fName
End Sub

Public Function FileSize(fName) As Long
    Dim f As Integer
        f = FreeFile
        Open fName For Binary Shared As #f
        FileSize = LOF(f)
        Close f
End Function
Public Function FixWidthRight(ByVal inputVal As Variant, ByVal n As Integer, Optional ch As String = " ") As String
Dim stRetVal As String

stRetVal = Nz(inputVal, "")
stRetVal = DoChRight(stRetVal, n, ch)
stRetVal = Left(stRetVal, n)
FixWidthRight = stRetVal
End Function

Public Function MyMid(st, nPos, nlen) As Variant
MyMid = ""
On Error Resume Next
    If IsNull(st) Or IsEmpty(st) Or st = "" Then
        MyMid = ""
    Else
        MyMid = Mid$(st, nPos, nlen)
    End If
End Function

Public Function Din(Iznos) As String
Din = ""
On Error Resume Next
    If IsNull(Iznos) Or IsEmpty(Iznos) Or Iznos = "" Or Iznos = 0 Then
        Din = ""
    Else
        Din = Format$(Iznos, "##,##0.00")
    End If
End Function
Public Function Din0(Iznos, Optional listsep = "") As String
Din0 = ""
On Error Resume Next
    If IsNull(Iznos) Or IsEmpty(Iznos) Or Iznos = "" Or Iznos = 0 Then
        Din0 = ""
    Else
        Din0 = Format$(Iznos, "##" & listsep & "###")
    End If
End Function
Public Function DobreReference() As Boolean
' Looping variable.
Dim refLoop As Reference
' Output variable.
Dim strReport As String

' Test whether there are broken references.
If Application.BrokenReference = True Then
    DobreReference = False
    strReport = "Sledece reference su prekinute:" & vbCr

    ' Test validity of each reference.
    For Each refLoop In Application.References
        If refLoop.IsBroken = True Then
            strReport = strReport & "    " & refLoop.Name & vbCr
        End If
    Next refLoop
    MsgBox strReport, vbCritical, "QMegaTeh"
Else
    DobreReference = True
    'strReport = "Sve reference u ovoj bazi su dobre."
End If
End Function

Public Sub IskljuciAutoCorrect(MForm As Form)
Dim MyCtl As control

For Each MyCtl In MForm.Controls
    If MyCtl.ControlType = acComboBox Or _
       MyCtl.ControlType = acListBox Or _
       MyCtl.ControlType = acTextBox Then
        
        MyCtl.AllowAutoCorrect = False
       
    End If
Next
End Sub
Public Sub PrikaziLoseReference()
Dim r As Reference
Dim strInfo As String
Dim ImaLosih As Boolean

ImaLosih = False

For Each r In Application.References
    ImaLosih = ImaLosih Or r.IsBroken
    strInfo = strInfo & r.Name & " " & r.Major & "." & r.Minor & "   " & IIf(r.IsBroken, "Broken", "Ok") & vbCrLf
Next
        
If ImaLosih Then
    MsgBox "Current References: " & vbCrLf & strInfo, vbCritical, "QMegaTeh"
End If

End Sub
Public Sub PrikaziSveReference()
Dim r As Reference
Dim strInfo As String

For Each r In Application.References
    strInfo = strInfo & r.Name & " " & r.Major & "." & r.Minor & "   " & IIf(r.IsBroken, "Broken", "Ok") & vbCrLf
    Debug.Print r.Name & " " & r.Major & "." & r.Minor & "   " & IIf(r.IsBroken, "Broken", "Ok"), r.Guid, r.Major, r.Minor ' & vbCrLf
Next
    MsgBox "Current References: " & vbCrLf & strInfo, vbInformation, "QMegaTeh"


End Sub
Public Function PostojiReferenca(stRefName As String) As Boolean
'stRefName je naziv reference ili puna putanja do fajla
Dim r As Reference
Dim retValOk As Boolean

 retValOk = False
 For Each r In Application.References
     'strInfo = strInfo & r.Name & " " & r.Major & "." & r.Minor & "   " & IIf(r.IsBroken, "Broken", "Ok") & vbCrLf
     retValOk = retValOk Or (r.Name = stRefName) Or (r.fullPath = stRefName)
 Next
 PostojiReferenca = retValOk
 
End Function
Public Function GetRefPath(ByVal stRefName As String) As String
'Kreirano: 22-10-21
'stRefName je naziv reference ili puna putanja do fajla
On Error GoTo Err_Point
Dim r As Reference
Dim retValOk As Boolean

 retValOk = False
 For Each r In Application.References
     
     retValOk = retValOk Or (r.Name = stRefName) Or (r.fullPath = stRefName)
     
     If retValOk Then
      Exit For
     End If
 
 Next r
 
Exit_Point:
 On Error Resume Next
 If retValOk Then
    GetRefPath = r.fullPath
 Else
    GetRefPath = ""
 End If

Exit Function

Err_Point:
 BBErrorMSG err, "GetRefPath"
 retValOk = False
 Resume Exit_Point
End Function
Public Sub WinKeyboard()
 Dim retVal
 Dim stAppName
    stAppName = ReadParametar("CFG_LOKAL", "KBD.Prog.Putanja")
    retVal = shell(stAppName, vbNormalNoFocus)
End Sub
Public Function MojDanUNedelji(DATUM As Variant) As String
On Error Resume Next
Dim rbrdan
Dim retVal As String
    rbrdan = Weekday(DATUM)
  Select Case rbrdan
    Case 1: retVal = "Nedelja"
    Case 2: retVal = "Ponedeljak"
    Case 3: retVal = "Utorak"
    Case 4: retVal = "Sreda"
    Case 5: retVal = "Cetvrtak"
    Case 6: retVal = "Petak"
    Case 7: retVal = "Subota"
    Case Else
        retVal = "-"
  End Select
  MojDanUNedelji = retVal
End Function
Public Function DatumUIntervalu(DATUM, OdDatuma, DoDatuma) As Boolean
    Dim retVal As Boolean
    Dim D_OdDatuma As Date
    Dim D_DoDatuma As Date
    Dim D_Datum As Date
    
    If IsNull(OdDatuma) And IsNull(DoDatuma) Then
     retVal = True
    Else
     D_OdDatuma = CDate(Nz(OdDatuma, #1/1/1901#))
     D_DoDatuma = CDate(Nz(DoDatuma, #12/31/2099#))
     D_Datum = CDate(DATUM)
     retVal = (D_OdDatuma <= D_Datum) And (D_Datum <= D_DoDatuma)
    End If
    DatumUIntervalu = retVal
End Function
Public Function DatIVremeUIntervalu(DatumIVreme, OdDatuma, OdVremena, DoDatuma, DoVremena) As Boolean
    Dim retVal As Boolean
    Dim D_OdDatIVrem As Date
    Dim D_DoDatIVrem As Date
    Dim D_DatIVrem As Date
    
    
    D_OdDatIVrem = CDate(Nz(OdDatuma, #1/1/1901#) & " " & Nz(OdVremena, #12:00:00 AM#))
    D_DoDatIVrem = CDate(Nz(DoDatuma, #12/31/2099#) & " " & Nz(DoVremena, #11:59:59 PM#))
    D_DatIVrem = CDate(DatumIVreme)
    retVal = (D_OdDatIVrem <= D_DatIVrem) And (D_DatIVrem <= D_DoDatIVrem)
    'Between IIf(IsNull([Forms]![AP]![OdVremena]),CDate(#01-01-91#+#0:00:00#),CDate([Forms]![AP]![Od datuma]+[Forms]![AP]![Odvremena])) And IIf(IsNull([Forms]![AP]![DoVremena]),CDate(#31-12-2099#+#0:00:00#),CDate([Forms]![AP].[Do datuma]+[Forms]![AP]![DoVremena]))
      
    DatIVremeUIntervalu = retVal
End Function
Public Function VremeUIntervalu(Vreme, OdVremena, DoVremena) As Boolean
    Dim retVal As Boolean
    Dim D_Vrem As Date
    Dim D_OdVrem As Date
    Dim D_DoVrem As Date
    
    If IsNull(OdVremena) And IsNull(DoVremena) Then
     retVal = True
    Else
     D_OdVrem = CDate(Nz(OdVremena, #12:00:00 AM#))
     D_DoVrem = CDate(Nz(DoVremena, #11:59:59 PM#))
     D_Vrem = CDate(Vreme)
     retVal = (D_OdVrem <= D_Vrem) And (D_Vrem <= D_DoVrem)
    End If
      
    VremeUIntervalu = retVal
End Function
Public Function DatumDoDatuma(DATUM, DoDatuma, Optional UljucenaGranica As Boolean = True) As Boolean
    Dim retVal As Boolean
    Dim D_DoDatuma As Date
    Dim D_Datum As Date
    
    D_DoDatuma = CDate(Nz(DoDatuma, #12/31/2099#))
    D_Datum = CDate(DATUM)
    If UljucenaGranica Then
        retVal = (D_Datum <= D_DoDatuma)
    Else
        retVal = (D_Datum < D_DoDatuma)
    End If
    
    DatumDoDatuma = retVal
End Function
Public Function VremeDoVremena(Vreme, DoVremena, Optional UljucenaGranica As Boolean = True) As Boolean
    Dim retVal As Boolean
    Dim D_Vrem As Date
    Dim D_DoVrem As Date
    
    D_DoVrem = CDate(Nz(DoVremena, #11:59:59 PM#))
    D_Vrem = CDate(Vreme)
    
    If UljucenaGranica Then
        retVal = (D_Vrem <= D_DoVrem)
    Else
        retVal = (D_Vrem < D_DoVrem)
    End If
    
    VremeDoVremena = retVal
End Function
Public Function DatIVremeDoDatIVreme(DatumIVreme, DoDatuma, DoVremena, Optional UljucenaGranica As Boolean = True) As Boolean
    Dim retVal As Boolean
    Dim D_OdDatIVrem As Date
    Dim D_DoDatIVrem As Date
    Dim D_DatIVrem As Date
    
    D_DoDatIVrem = CDate(Nz(DoDatuma, #12/31/2099#) + Nz(DoVremena, #11:59:59 PM#))
    D_DatIVrem = CDate(DatumIVreme)
    If UljucenaGranica Then
        retVal = (D_DatIVrem <= D_DoDatIVrem)
    Else
        retVal = (D_DatIVrem < D_DoDatIVrem)
    End If
      
    DatIVremeDoDatIVreme = retVal
End Function
Public Function StringToHex(st As String, Optional sep As String = " ") As String
 Dim i As Integer
 Dim retVal As String
 
 retVal = ""
 For i = 1 To Len(st)
  retVal = retVal & Hex(Asc(Mid(st, i, 1))) & sep
 Next i
 StringToHex = retVal
End Function
Public Function HexToString(st As String, Optional sep As String = " ") As String
' chr(&H01) +chr(&H24) +chr(&H22) +chr(&H21) +chr(&H05) +chr(&H30) +chr(&H30) +chr(&H36) +chr(&H3C) +chr(&H03)
 Dim i As Integer
 Dim retVal As String
 
 retVal = ""
 For i = 1 To Len(st) Step 2
  retVal = retVal & Hex(Asc(Mid(st, i, 1))) & sep
 Next i
 HexToString = retVal
End Function

Public Function F_KorigovanaKolicina(Kolicina As Currency, JedMere As Variant, Koef As Double, Optional BrDecZaKG As Byte = 3) As Currency
 Dim BrDecZaok As Byte
 Dim retVal As Currency
 
 If Nz(JedMere, "Kg") = "Kom" Then
    BrDecZaok = 0
 Else
    BrDecZaok = BrDecZaKG
 End If
 retVal = Round(Kolicina * Koef, BrDecZaok)
 If retVal = 0 And BrDecZaok = 0 Then
  retVal = 1
 End If
 F_KorigovanaKolicina = retVal
End Function

Public Sub ZakljucajOtkljucajPoljeNaFormi(ImeForme As String, ImeKolone As String)
    Static LockedColor
    
    If Forms(ImeForme).Controls(ImeKolone).Locked Then LockedColor = Forms(ImeForme).Controls(ImeKolone).BackColor
    
    Forms(ImeForme).Controls(ImeKolone).Locked = Not Forms(ImeForme).Controls(ImeKolone).Locked
    
    If Forms(ImeForme).Controls(ImeKolone).Locked Then
        If Nz(LockedColor, "") = "" Then LockedColor = 16777164
        Forms(ImeForme).Controls(ImeKolone).BackColor = LockedColor
        Forms(ImeForme).Controls(ImeKolone).TabStop = False
    Else
        Forms(ImeForme).Controls(ImeKolone).BackColor = ColorConstants.vbWhite
        Forms(ImeForme).Controls(ImeKolone).TabStop = True
    End If
End Sub

Public Function OstaviSamoCifre(InputStr) As String
On Error Resume Next
Dim inst As String
Dim retVal As String
Dim i As Integer
retVal = ""
    inst = Trim(CStr(Nz(InputStr, "")))
    For i = 1 To Len(inst)
        If IsNumeric(Mid$(inst, i, 1)) Then retVal = retVal & Mid$(inst, i, 1)
    Next i
    OstaviSamoCifre = retVal
End Function
Public Function MaxVal(X As Variant, Y As Variant) As Variant
On Error Resume Next

  If X < Y Then
   MaxVal = Y
  Else
   MaxVal = X
  End If
  
End Function



