Attribute VB_Name = "POPDV_Module"
Option Compare Database
Option Explicit
Public Function MozeEvalDefKonto(Izraz As Variant) As Boolean
On Error GoTo Err_Point

 Dim stIzraz As String
 Dim curVredIzraza As Currency
 Dim retValOk As Boolean
 
 retValOk = True
 stIzraz = Trim(CStr(Nz(Izraz, "")))
 
 If stIzraz <> "" Then
  stIzraz = Replace(stIzraz, "D", "1")
  stIzraz = Replace(stIzraz, "P", "1")
  curVredIzraza = Eval(stIzraz)
 End If
Exit_Point:

On Error Resume Next
 MozeEvalDefKonto = retValOk
Exit Function

Err_Point:
 retValOk = False
 Resume Exit_Point
 
End Function
'Public Function ReadHeaderLinePOPDV(Sekcija As String, ImeKolone As String, Red As String, Optional ImeTabele = "APL_PDV_POPDV_DEF") As String
'Public Function ReadHeaderLinePOPDV(Sekcija As String, ImeKolone As String, Red As String, Optional ImeTabele = "POPDV_DEF") As String
Public Function F_POPDV_OJ() As String
 F_POPDV_OJ = Nz(ReadParametar("CFG_Global", "POPDV_OJ"), "")
End Function
Public Function F_POPDV_PoreskiSavetnik() As String
 F_POPDV_PoreskiSavetnik = Nz(ReadParametar("CFG_Global", "POPDV_PoreskiSavetnik"), "")
End Function
Public Function F_POPDV_JMBGPoreskiSavetnik() As String
 F_POPDV_JMBGPoreskiSavetnik = Nz(ReadParametar("CFG_Global", "POPDV_JMBGPoreskiSavetnik"), "")
End Function
Public Function F_POPDV_OdgovornoLice() As String
 F_POPDV_OdgovornoLice = Nz(ReadParametar("CFG_Global", "POPDV_OdgovornoLice"), "")
End Function
Public Function F_POPDV_TipPodnosioca() As String
 F_POPDV_TipPodnosioca = Nz(ReadParametar("CFG_Global", "POPDV_TipPodnosioca"), "")
End Function
Public Function F_POPDV_MesecnaIliKvartalnaObaveza() As String
'1 mesecni
'3 kvartalni

 F_POPDV_MesecnaIliKvartalnaObaveza = Nz(ReadParametar("CFG_Global", "POPDV_MesecnaIliKvartalnaObaveza"), "")
End Function

Public Function ReadHeaderLinePOPDV(Sekcija, ImeKolone, Red, Optional imeTabele = "POPDV_DEF") As String

   Dim stRetVal
   Dim stEvalRetVal
   Dim stWhere As String
   If IsNull(Sekcija) Or IsNull(ImeKolone) Or IsNull(Red) Then
      stRetVal = ""
   Else
      stWhere = "H" & Sekcija & Red
      stRetVal = DLookup(ImeKolone, imeTabele, "[PDVOznaka] = '" & stWhere & "'")
        If stRetVal Like "*@*" Then
         'Between NZOdDatuma([Forms]![APGK]![POPDVOdDatumaPorPerioda]) And NZDoDatuma([Forms]![APGK]![POPDVDoDatumaPorPerioda])
         stRetVal = Replace(stRetVal, "@OdDatuma", Format([Forms]![APGK]![POPDVOdDatumaPorPerioda], "dd.MM.yyyy."))
         stRetVal = Replace(stRetVal, "@DoDatuma", Format([Forms]![APGK]![POPDVDoDatumaPorPerioda], "dd.MM.yyyy."))
        End If
       On Error Resume Next
         stEvalRetVal = Eval(stRetVal)
       If err.Number = 0 Then
        stRetVal = stEvalRetVal
       End If
       
   End If
   ReadHeaderLinePOPDV = Nz(stRetVal, "")
End Function
Public Function SekcijaZaPOPDVOznaku(PDVOznaka, Optional imeTabele = "POPDV_DEF")
   SekcijaZaPOPDVOznaku = DLookup("[Sekcija]", imeTabele, "Cyr2Lat([PDVOznaka]) = '" & Cyr2Lat(PDVOznaka) & "'")
End Function
Public Function BrojKolonaZaPOPDVOznaku(PDVOznaka, Optional imeTabele = "POPDV_DEF") As Integer
   BrojKolonaZaPOPDVOznaku = Nz(DLookup("[BrojKolona]", imeTabele, "Cyr2Lat([PDVOznaka]) = '" & Cyr2Lat(PDVOznaka) & "'"), 0)
End Function
Public Function AktivneKoloneZaPOPDVOznaku(PDVOznaka, Optional imeTabele = "POPDV_DEF") As String
   AktivneKoloneZaPOPDVOznaku = Nz(DLookup("[AktivneKolone]", imeTabele, "Cyr2Lat([PDVOznaka]) = '" & Cyr2Lat(PDVOznaka) & "'"), "")
End Function
Public Function RBrZaPOPDVOznaku(PDVOznaka, Optional imeTabele = "POPDV_DEF") As Long
   RBrZaPOPDVOznaku = Nz(DLookup("[RBr]", imeTabele, "Cyr2Lat([PDVOznaka]) = '" & Cyr2Lat(PDVOznaka) & "'"), 0)
End Function
Public Function ReadHeaderLinePOPDVZaOznaku(PDVOznaka, ImeKolone, Red, Optional imeTabele = "POPDV_DEF") As String

   Dim stRetVal
   Dim stEvalRetVal
   Dim stWhere As String
   Dim Sekcija
   
   Sekcija = DLookup("[Sekcija]", imeTabele, "Cyr2Lat([PDVOznaka]) = '" & Cyr2Lat(PDVOznaka) & "'")
   
   If IsNull(Sekcija) Or IsNull(ImeKolone) Or IsNull(Red) Then
      stRetVal = ""
   Else
      stWhere = "H" & Sekcija & Red
      stRetVal = DLookup(ImeKolone, imeTabele, "[PDVOznaka] = '" & stWhere & "'")
        If stRetVal Like "*@*" Then
         'Between NZOdDatuma([Forms]![APGK]![POPDVOdDatumaPorPerioda]) And NZDoDatuma([Forms]![APGK]![POPDVDoDatumaPorPerioda])
         stRetVal = Replace(stRetVal, "@OdDatuma", Format([Forms]![APGK]![POPDVOdDatumaPorPerioda], "dd.MM.yyyy."))
         stRetVal = Replace(stRetVal, "@DoDatuma", Format([Forms]![APGK]![POPDVDoDatumaPorPerioda], "dd.MM.yyyy."))
        End If
       On Error Resume Next
         stEvalRetVal = Eval(stRetVal)
       If err.Number = 0 Then
        stRetVal = stEvalRetVal
       End If
       
   End If
   ReadHeaderLinePOPDVZaOznaku = Nz(stRetVal, "")
End Function
Public Function POPDVPripremiTMPZaObrazac(Optional IntOdDubine As Integer = -1, Optional BrojDecimala As Integer = 0) As Boolean
On Error GoTo Err_Point
Dim QDefActionQuery As DAO.QueryDef

 Dim retValOk As Boolean
 Dim i As Integer
 Dim stMaxI
 Dim intMaxI As Integer
 Dim StvarnoOdDubine As Integer
 
 retValOk = True
 Set QDefActionQuery = CurrentDb.QueryDefs("POPDV_PopuniVrednostiUTmp")
 
 If IntOdDubine <= 0 Then
    '26-11-2021 retValOk = PripremiTMPTabeluUTMPBazi("tmp_POPDV_Report", "POPDV_StavkeZaTMP", , , , "PDVOznaka", "Sekcija", "Rbr")
    retValOk = KreirajTMPTabeluUTMPBazi_IzBBQueryDef("tmp_POPDV_Report", "ftPOPDV_StavkeZaTMP", , , , "PDVOznaka", "Sekcija", "Rbr")
    'DoCmd.SetWarnings False
    StvarnoOdDubine = 1
 Else
    StvarnoOdDubine = IntOdDubine
 End If
 
    stMaxI = DMax("[Header]", "POPDV_Def", "IsNumeric([Header]) = True")
    stMaxI = Nz(stMaxI, "1")
 
 On Error Resume Next
 intMaxI = Eval(stMaxI)
 If err.Number <> 0 Then
   intMaxI = 5
 End If
 On Error GoTo Err_Point
 
 'If CurrentUser = "Negovan" Then
 ' intMaxI = InputBox("Do dubine=", "QMegaTeh", intMaxI)
 'End If
 For i = StvarnoOdDubine To intMaxI
  QDefActionQuery.Parameters("ZaHeader").Value = i
  QDefActionQuery.Execute
 Next
 
 'DoCmd.OpenQuery "POPDV_PopuniVrednostiUTmp"
 
 DoCmd.SetWarnings True
 'DoCmd.OpenReport "POPDV_Obrazac", acViewPreview
Exit_Point:
On Error Resume Next
DoCmd.SetWarnings True
QDefActionQuery.Close
Set QDefActionQuery = Nothing
POPDVPripremiTMPZaObrazac = retValOk
Exit Function
Err_Point:
 BBErrorMSG err, "POPDVPripremiTMPZaObrazac"
 retValOk = False
 Resume Exit_Point
End Function

Public Function POPDV_VrednostKoloneZaKnjizenje(Kolona As Integer, Duguje As Double, Potrazuje As Double, K1Def, K2Def, K3Def, K4Def) As Currency
On Error GoTo Err_Point
Dim retVal As Currency
Dim Formula

  If Kolona = 1 Then
    Formula = K1Def
  ElseIf Kolona = 2 Then
    Formula = K2Def
  ElseIf Kolona = 3 Then
    Formula = K3Def
  ElseIf Kolona = 4 Then
    Formula = K4Def
  Else
    Formula = 0
  End If
  
  If Trim(Nz(Formula, "")) = "" Then
     Formula = 0
  End If

  Formula = CStr(Formula)
  Formula = Replace(Formula, "D", "(" & Duguje & ")")
  Formula = Replace(Formula, "P", "(" & Potrazuje & ")")
  
  On Error Resume Next
   retVal = Eval(Formula)
  If err.Number <> 0 Then
  err.Clear
     retVal = 0
  End If
  On Error GoTo Err_Point
  
Exit_Point:
  On Error Resume Next
  POPDV_VrednostKoloneZaKnjizenje = retVal
Exit Function

Err_Point:
  BBErrorMSG err, "POPDV_VrednostKoloneZaKnjizenje(" & Kolona & ", " & Duguje & ", " & Potrazuje & ", " & K1Def & ", " & K2Def & ", " & K3Def & ", " & K4Def & ")"
  Resume Exit_Point:
End Function
Public Function POPDV_VrednostIzrKolone(stH As String, Kolona As Integer, K1Def, K2Def, K3Def, K4Def, K1Val, K2Val, K3Val, K4Val, BrDec As Integer) As Currency
' ? POPDV_VrednostIzrKolone(1,"1.1K1+1.2K1+1.3K1+1.4K1","","","","POPDV_ZaIZRTMP","01-01-18", "31-12-18")
' ? POPDV_VrednostIzrKolone("1",1,"1.1K1+1.2K1+1.3K1+1.4K1","","","",1,2,3,4)
' ? POPDV_VrednostIzrKolone(1, 1, "1.1K1+1.2K1+1.3K1+1.4K1", "", "", "", 1, 2, 3, 4)
'? POPDV_VrednostIzrKolone(3,1,"[3.10K2]+[3à.9K1]+[4.1.4K2]+[4.2.4K3]","[x]","[x]","[x]",0,0,0,0,0)
On Error GoTo Err_Point

Dim stQueryName As String
'Dim stOdDatuma As String
'Dim stDoDatuma As String

Dim QDefRstVred As DAO.QueryDef
'Dim Par As DAO.Parameter
Dim rstVred As DAO.Recordset
Dim stKolName As String
Dim retVal As Currency
Dim Formula

If stH = 0 Then
         If Kolona = 1 Then
          retVal = K1Val
        ElseIf Kolona = 2 Then
          retVal = K2Val
        ElseIf Kolona = 3 Then
          retVal = K3Val
        ElseIf Kolona = 4 Then
          retVal = K4Val
        Else
          retVal = 0
        End If
  POPDV_VrednostIzrKolone = Round(retVal, BrDec) 'Din0(retVal, ",")
  Exit Function
End If

If Kolona = 1 Then
    Formula = K1Def
  ElseIf Kolona = 2 Then
    Formula = K2Def
  ElseIf Kolona = 3 Then
    Formula = K3Def
  ElseIf Kolona = 4 Then
    Formula = K4Def
  Else
    Formula = "0"
  End If
  
  If Trim(Nz(Formula, "")) = "" Then
     Formula = "0"
  End If
  Formula = CStr(Formula)
  
  If Formula = "0" Or Formula = "x" Or Formula = "[x]" Then
   retVal = 0
   POPDV_VrednostIzrKolone = Round(retVal, BrDec) 'Din0(retVal, ",")
  Exit Function
  End If


 stQueryName = "tmp_POPDV_Report"

'If IsMissing(OdDatuma) Then
' stOdDatuma = "01-01-1901"
'Else
' stOdDatuma = CStr(OdDatuma)
'End If

'If IsMissing(DoDatuma) Then
' stDoDatuma = "31-12-2099"
'Else
' stDoDatuma = CStr(DoDatuma)
'End If


Set QDefRstVred = CurrentDb.CreateQueryDef("", "SELECT * FROM " & stQueryName & " WHERE [Sekcija] <> 'H'")

'If stH = "1" And K2Def Like "[8*" Then
' Debug.Print "[8à.1K2]"
'End If
'For Each Par In QDefRstVred.Parameters
' If Par.Name Like "*OdDat*" Then
'    Par.Value = CVDate(stOdDatuma)
'  ElseIf Par.Name Like "*DoDat*" Then
'    Par.Value = CVDate(stDoDatuma)
'  Else
'   Par.Value = Null
' End If
'Next

Set rstVred = QDefRstVred.OpenRecordset(DB_OPEN_DYNASET, dbSeeChanges)
  
 Formula = Cyr2Lat(Formula)
 
While Not rstVred.EOF
  
  If Nz(rstVred!K1Def, "") <> "" Then
   stKolName = "[" & rstVred!PDVOznaka & "K1]"
   stKolName = Cyr2Lat(stKolName)
   'Formula = Replace(Formula, (rstVred!K1Def), CStr(Nz(rstVred!K1Val, 0)))
   Formula = Replace(Formula, stKolName, CStr(Nz(rstVred!K1Val, 0)))
  End If

  If Nz(rstVred!K2Def, "") <> "" Then
   stKolName = "[" & rstVred!PDVOznaka & "K2]"
   stKolName = Cyr2Lat(stKolName)
   Formula = Replace(Formula, stKolName, CStr(Nz(rstVred!K2Val, 0)))
  End If

  If Nz(rstVred!K3Def, "") <> "" Then
   stKolName = "[" & rstVred!PDVOznaka & "K3]"
   stKolName = Cyr2Lat(stKolName)
   Formula = Replace(Formula, stKolName, CStr(Nz(rstVred!K3Val, 0)))
  End If

  If Nz(rstVred!K4Def, "") <> "" Then
   stKolName = "[" & rstVred!PDVOznaka & "K4]"
   stKolName = Cyr2Lat(stKolName)
   Formula = Replace(Formula, stKolName, CStr(Nz(rstVred!K4Val, 0)))
  End If

 rstVred.MoveNext
Wend

 
 retVal = Eval(Formula)
 'retVal = Round(retVal, BrDec)
 'retVal = 150

Exit_Point:
  On Error Resume Next
  rstVred.Close
  Set rstVred = Nothing
  POPDV_VrednostIzrKolone = Round(retVal, BrDec) 'Din0(retVal, ",")
Exit Function

Err_Point:
  BBErrorMSG err, "POPDV_VrednostIzrKolone(" & Kolona & ", " & K1Def & ", " & K2Def & ", " & K3Def & ", " & K4Def & ", " & stQueryName & ")"
  retVal = 0 '-999999
  Resume Exit_Point:
End Function
Public Function POPDVVredZaXML(Kolona As Integer, PDVOznaka As String) As String
On Error GoTo Err_Point
 Dim stRetVal As String
 Dim stKol As String
 
 stKol = "[K" & Trim(CStr(Kolona)) & "Val]"
 On Error Resume Next
 stRetVal = CStr(Nz(DLookup(stKol, "tmp_POPDV_Report", "[PDVOznaka] = '" & PDVOznaka & "'"), "!!BBError!!"))
 If err.Number <> 0 Then
    On Error GoTo Err_Point
    err.Raise vbObjectError + 513, "POPDVVredZaXML", "Ne postoji polje " & stKol
 End If
Exit_Point:

On Error Resume Next
  POPDVVredZaXML = stRetVal
Exit Function

Err_Point:
  BBErrorMSG err, "POPDVVredZaXML(" & Kolona & ", " & PDVOznaka & ")"
  stRetVal = "!!BBError!!"
  Resume Exit_Point:
End Function

Public Function POPDV_AOPIznos(AOPOznaka As String) As Currency
On Error GoTo Err_Point
 Dim stRetVal As String
 Dim Kolona As Integer
 Dim stKol As String
 Dim AOPOznakaSaUglastimZag As String
 Dim stAopKolona As String
 Dim AOPZbir As Currency
 
 
 AOPOznakaSaUglastimZag = AOPOznaka
 AOPOznakaSaUglastimZag = Replace(AOPOznakaSaUglastimZag, "[", "")
 AOPOznakaSaUglastimZag = Replace(AOPOznakaSaUglastimZag, "]", "")
 AOPOznakaSaUglastimZag = "[" & AOPOznakaSaUglastimZag & "]"

AOPZbir = 0

For Kolona = 1 To 4
 stKol = "[K" & Trim(CStr(Kolona)) & "Val]"
 

 stAopKolona = "[K" & Trim(CStr(Kolona)) & "AOP]"
 
 On Error Resume Next
 AOPZbir = AOPZbir + CCur(Nz(DSum(stKol, "tmp_POPDV_Report", stAopKolona & "  = '" & AOPOznakaSaUglastimZag & "'"), 0))
 If err.Number <> 0 Then
    On Error GoTo Err_Point
    err.Raise vbObjectError + 513, "POPDV_AOPIznos", "Ne postoji polje " & stKol & " za AOP " & AOPOznaka
 End If
Next Kolona
Exit_Point:

On Error Resume Next
  POPDV_AOPIznos = AOPZbir
Exit Function

Err_Point:
  BBErrorMSG err, "POPDV_AOPIznos(" & AOPOznaka & ")"
  AOPZbir = 0
  Resume Exit_Point:
End Function

Public Function POPDV_KolEnabled(BrKol As Integer, AktivneKolone As String) As Boolean
Dim RetValBool As Boolean
  
  If Len(AktivneKolone) < BrKol Then
    RetValBool = True
  Else
   RetValBool = (Mid(AktivneKolone, BrKol, 1) = "1")
  End If
  POPDV_KolEnabled = RetValBool
End Function
Public Sub POPDV_PodesiIznoseZaSlogUpdate(NovaPDVOznaka As String, ByRef K1Iznos As Currency, ByRef K2Iznos As Currency, ByRef K3Iznos As Currency, ByRef K4Iznos As Currency)
'modifikovano: 17-06-2019
'On Error Resume Next

  Dim AktivneKolone As String
  
  'AktivneKolone = DLookup("[AktivneKolone]", "POPDV_DEF", "[PDVOznaka] = '" & NovaPDVOznaka & "'")
  'AktivneKolone = DLookup("[AktivneKolone]", "POPDV_DEF", "cyr2lat([PDVOznaka]) = '" & Cyr2Lat(NovaPDVOznaka) & "'")
  AktivneKolone = AktivneKoloneZaPOPDVOznaku(NovaPDVOznaka)
  
  
  If Not POPDV_KolEnabled(1, AktivneKolone) Then
    K1Iznos = 0#
  End If
  
  If Not POPDV_KolEnabled(2, AktivneKolone) Then
    K2Iznos = 0#
  End If
  
 If Not POPDV_KolEnabled(3, AktivneKolone) Then
    K3Iznos = 0#
 End If
 
 If Not POPDV_KolEnabled(4, AktivneKolone) Then
    K4Iznos = 0#
 End If
End Sub
Public Sub POPDV_PodesiDefZaSlogUpdate(NovaPDVOznaka As String, ByRef K1Def As Variant, ByRef K2Def As Variant, ByRef K3Def As Variant, ByRef K4Def As Variant)
'Modifikovano: 17-06-2019

  Dim AktivneKolone As String
  
  'AktivneKolone = DLookup("[AktivneKolone]", "POPDV_DEF", "[PDVOznaka] = '" & NovaPDVOznaka & "'")
  AktivneKolone = AktivneKoloneZaPOPDVOznaku(NovaPDVOznaka)
  
  If Not POPDV_KolEnabled(1, AktivneKolone) Then
    K1Def = Null
  End If
  
  If Not POPDV_KolEnabled(2, AktivneKolone) Then
    K2Def = Null
  End If
  
 If Not POPDV_KolEnabled(3, AktivneKolone) Then
    K3Def = Null
 End If
 
 If Not POPDV_KolEnabled(4, AktivneKolone) Then
    K4Def = Null
 End If
End Sub
Public Function POPDVPripremiTMPZaObrazacIzStareEvidencije(POPDVIDPrijave As String) As Boolean
Dim retValOk As Boolean
Dim stSQLText As String
   stSQLText = "SELECT * FROM POPDV_StavkeZaTMP_StaraEvidencija WHERE POPDVIDPrijave = '" & POPDVIDPrijave & "'"
   retValOk = PripremiTMPTabeluUTMPBazi("tmp_POPDV_Report", stSQLText, , , , "PDVOznaka", "Sekcija", "Rbr")
   POPDVPripremiTMPZaObrazacIzStareEvidencije = retValOk
End Function
Public Function POPDV_KontoImaPDVSemu(ByVal Konto As String) As Boolean ', ByVal PDVStatusKomitenta, ByVal VrstaNaloga) As Boolean
Dim intBrojSema As Integer

intBrojSema = DCount("*", "POPDV_SemeKontaZaKnjizenje", "[Konto] = '" & Konto & "'")

POPDV_KontoImaPDVSemu = (intBrojSema > 0)
 
End Function
Public Function POPDV_ProknjiziStavkuGKPoSemi(StavkaID As Long) As Boolean
On Error GoTo Err_Point

Dim qDef As DAO.QueryDef
Dim retValOk As Boolean

retValOk = True
Set qDef = CurrentDb.QueryDefs("POPDV_ProknjiziStavkuGKPoSemi")
qDef.Parameters("ZaStavkaID") = StavkaID
qDef.Execute dbSeeChanges


Exit_Point:
On Error Resume Next
 qDef.Close
 Set qDef = Nothing

 POPDV_ProknjiziStavkuGKPoSemi = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "POPDV_ProknjiziStavkuGKPoSemi"
 retValOk = False
 Resume Exit_Point
End Function

Public Function POPDV_VredZaPDVOznaku5_3(PDVOznaka5_2_vrednost As Currency, PDVOznaka8e_5_vrednost As Currency) As Currency
Dim retVal As Currency
    If PDVOznaka5_2_vrednost > 0 Then
        If PDVOznaka8e_5_vrednost > 0 Then
            retVal = PDVOznaka5_2_vrednost
        Else
            retVal = PDVOznaka5_2_vrednost + Abs(PDVOznaka8e_5_vrednost)
        End If
    Else
        If PDVOznaka8e_5_vrednost > 0 Then
            retVal = 0
        Else
            If Abs(PDVOznaka5_2_vrednost) > Abs(PDVOznaka8e_5_vrednost) Then
                retVal = 0
            Else
                retVal = Abs(PDVOznaka8e_5_vrednost) - Abs(PDVOznaka5_2_vrednost)
            End If
        End If
    End If
    POPDV_VredZaPDVOznaku5_3 = retVal
End Function
Public Function POPDV_VredZaPDVOznaku8e_6(PDVOznaka5_2_vrednost As Currency, PDVOznaka5_5_vrednost As Currency, PDVOznaka8e_5_vrednost As Currency) As Currency
Dim retVal As Currency
Dim PDVOznaka5 As Currency

PDVOznaka5 = PDVOznaka5_2_vrednost + PDVOznaka5_5_vrednost

    If PDVOznaka8e_5_vrednost > 0 Then
        If PDVOznaka5 > 0 Then
            retVal = PDVOznaka8e_5_vrednost
        Else
            retVal = PDVOznaka8e_5_vrednost + Abs(PDVOznaka5)
        End If
    Else
        If PDVOznaka5 > 0 Then
            retVal = 0
        Else
            If Abs(PDVOznaka8e_5_vrednost) > Abs(PDVOznaka5) Then
                retVal = 0
            Else
                retVal = Abs(PDVOznaka5) - Abs(PDVOznaka8e_5_vrednost)
            End If
        End If
    End If
    POPDV_VredZaPDVOznaku8e_6 = retVal
End Function
'********************************************************
'Datum kreiranja: 22-08-18
'********************************************************
Public Function POPDV_ZadovoljenUslovZaSemu(StavkaID As Long, Konto As String, PDVOznaka As String, Uslov) As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean

 If Trim(Nz(Uslov, "")) = "" Then
    retValOk = True
    POPDV_ZadovoljenUslovZaSemu = retValOk
    Exit Function
 End If
  
 
Exit_Point:
On Error Resume Next
 POPDV_ZadovoljenUslovZaSemu = retValOk

Exit Function

Err_Point:
 BBErrorMSG err, "POPDV_ZadovoljenUslovZaSemu"
 retValOk = False
 Resume Exit_Point
End Function
'********************************************************
'Datum kreiranja: 23-08-18
'********************************************************
Public Function POPDV_ZadovoljenUslovZaPDVStatusKomitenta(ByVal PDVStatusKomitenta, ByVal Uslov) As Boolean
On Error GoTo Err_Point

Dim retValOk As Boolean
Dim stUslov As String
Dim stPDVStatusKomitenta As String

stUslov = Trim(CStr(Nz(Uslov, "")))
stPDVStatusKomitenta = Trim(CStr(Nz(PDVStatusKomitenta, "<<Null>>")))

 If (stUslov = "") Or (stUslov = "*") Then
    retValOk = True
 Else
    retValOk = (stPDVStatusKomitenta Like stUslov)
 End If
 
Exit_Point:
On Error Resume Next
 POPDV_ZadovoljenUslovZaPDVStatusKomitenta = retValOk

Exit Function

Err_Point:
 BBErrorMSG err, "POPDV_ZadovoljenUslovZaPDVStatusKomitenta"
 retValOk = False
 Resume Exit_Point
End Function
'********************************************************
'Datum kreiranja: 23-08-18
'********************************************************
Public Function POPDV_ZadovoljenUslovZaVrstuNaloga(ByVal VrstaNaloga, ByVal Uslov) As Boolean
On Error GoTo Err_Point

Dim retValOk As Boolean
Dim stUslov As String
Dim stVrstaNaloga As String

stUslov = Trim(CStr(Nz(Uslov, "")))
stVrstaNaloga = Trim(CStr(Nz(VrstaNaloga, "<<Null>>")))

 If (stUslov = "") Or (stUslov = "*") Then
    retValOk = True
 Else
    retValOk = (stVrstaNaloga Like stUslov)
 End If
 
Exit_Point:
On Error Resume Next
 POPDV_ZadovoljenUslovZaVrstuNaloga = retValOk

Exit Function

Err_Point:
 BBErrorMSG err, "POPDV_ZadovoljenUslovZaVrstuNaloga"
 retValOk = False
 Resume Exit_Point
End Function
