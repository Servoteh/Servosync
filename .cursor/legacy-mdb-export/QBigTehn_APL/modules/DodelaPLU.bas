Attribute VB_Name = "DodelaPLU"
Option Compare Database
Option Explicit

Public Function DodeliPLUUTabeli(Optional stTblName As String = "R_Artikli", Optional LongIntOdPLU As Long = 1)
 ' U tabeli moraju da postoje polja [PLU] i [Sifra artikla]
 On Error GoTo err_Sub
    Dim BigBit As DAO.Database
    Dim Tabela As DAO.Recordset
    Dim NoviPLU As Long
    Dim retValOk As Boolean
    Dim stSQLQuery
    
    Set BigBit = CurrentDb

    retValOk = True
     stSQLQuery = "SELECT [" & stTblName & "].* FROM [" & stTblName & "] ORDER BY [" & stTblName & "].PLU, " & "[" & stTblName & "].[Sifra artikla];"
     Set Tabela = BigBit.OpenRecordset(stSQLQuery)
        Tabela.MoveFirst
    
        NoviPLU = LongIntOdPLU
        Do Until Tabela.EOF ' Until end of file.
            'Debug.Print "Sada radim " & N & " slog."
        
            Tabela.Edit
            Tabela![PLU] = NoviPLU
            Tabela.Update
            Tabela.MoveNext    ' Move to next record.
            NoviPLU = NoviPLU + 1
        Loop
        'Debug.Print "PLU dodeljen na " & N & " slogova."
Exit_Sub:
       
    Tabela.Close
    BigBit.Close
    
    Set Tabela = Nothing
    Set BigBit = Nothing
    DodeliPLUUTabeli = retValOk
 Exit Function
err_Sub:
   retValOk = False
  BBErrorMSG err, "DodeliPLUUTabeli stTblName= " & stTblName
  Resume Exit_Sub:
End Function
Private Function GPPCriteria(Optional Grupa As String = "", Optional Podgrupa As String = "", Optional Poreklo As String = "") As String
    Dim strCriteria As String

    
    strCriteria = ""
    
    If Grupa <> "" Then
     strCriteria = "([Grupa]='" & Grupa & "')"
    End If
    
    If Podgrupa <> "" Then
     If strCriteria = "" Then
      strCriteria = "([Podgrupa]='" & Podgrupa & "')"
     Else
      strCriteria = strCriteria & " AND ([Podgrupa]='" & Podgrupa & "')"
     End If
    End If
    
    If Poreklo <> "" Then
     If strCriteria = "" Then
      strCriteria = "([Poreklo]='" & Poreklo & "')"
     Else
      strCriteria = strCriteria & " AND ([Poreklo]='" & Poreklo & "')"
     End If
    End If
    GPPCriteria = strCriteria
End Function
Public Function SledeciPLU(Optional Grupa As String = "", Optional Podgrupa As String = "", Optional Poreklo As String = "") As Long
    Dim retVal
    Dim strCriteria As String
    strCriteria = GPPCriteria(Grupa, Podgrupa, Poreklo)
    If Grupa <> "VAGA" Then strCriteria = ""
    
    retVal = DMax("[PLU]", "R_Artikli", strCriteria)
    'retval = CLng(Nz(retval,0) + 1)
    SledeciPLU = CLng(Nz(retVal, 0) + 1)
End Function
Public Function SledeciKatBroj(Optional Grupa As String = "", Optional Podgrupa As String = "", Optional Poreklo As String = "") As String
  Dim retVal As String
  Dim numKatBroj
  Dim strCriteria As String
  
  
  strCriteria = "IsNumeric([Kataloski broj])"
  If Grupa = "VAGA" Then
   strCriteria = strCriteria & " AND " & GPPCriteria(Grupa, Podgrupa, Poreklo)
  End If
  
    On Error Resume Next
        numKatBroj = DMax("Format([Kataloski broj],string(5,""0""))", "R_Artikli", strCriteria)
        'numKatBroj = DMax("[NumKatBroj]", "Q_R_Artikli_NumKatBroj", strCriteria)
        
        numKatBroj = Nz(numKatBroj, 0) + 1
        retVal = DoChLeft(CStr(numKatBroj), 5, "0")
        
    SledeciKatBroj = retVal
End Function
Public Function SledeciBrojDokumentaPoTabeli(TipDok As String) As String
'Modifikovano: 07-02-2019

On Error GoTo Err_Point

    Dim stRetVal As String
    Dim Criteria As String
    Dim BigBit As DAO.Database
    Dim Par As DAO.Recordset
    
    stRetVal = ""
    Set BigBit = CurrentDb
    Set Par = BigBit.OpenRecordset("Parametri za rad", dbOpenDynaset, dbSeeChanges)
    If Par.EOF And Par.BOF Then 'tabela nema ni jedan slog
        Par.AddNew
        Par![Korisnik] = "UNKNOWN"
        Par![Poslednji broj fakture] = 0
        Par![Poslednji broj profakture] = 0
        Par![Faktura kroz] = ""
        Par![Profaktura kroz] = ""
        Par.Update
        Par.MoveFirst
    End If
    
    Par.MoveFirst
    If TipDok = "IF" Or TipDok = "USL" Then
       stRetVal = (Par![Poslednji broj fakture] + 1)
       stRetVal = DoChLeft(stRetVal, BBCFG.BrojZnakovaZaBrDok, "0")
       stRetVal = (Par![Faktura prefix]) & stRetVal & (Par![Faktura kroz])
       Par.Edit
       Par![Poslednji broj fakture] = Par![Poslednji broj fakture] + 1
       Par.Update
    ElseIf TipDok = "PROF" Then
       stRetVal = (Par![Poslednji broj profakture] + 1)
       stRetVal = DoChLeft(stRetVal, BBCFG.BrojZnakovaZaBrDok, "0")
       stRetVal = (Par![Profaktura prefix]) & stRetVal & (Par![Profaktura kroz])
       Par.Edit
       Par![Poslednji broj profakture] = Par![Poslednji broj profakture] + 1
       Par.Update
    End If
    
Exit_Point:
    On Error Resume Next
    
    Par.Close
    Set Par = Nothing
    Set BigBit = Nothing
    
    SledeciBrojDokumentaPoTabeli = stRetVal
    
  Exit Function
  
Err_Point:
   BBErrorMSG err, "SledeciBrojDokumentaPoTabeli"
   Resume Exit_Point
Resume Exit_Point

End Function
Public Function fsSledeciBrojDokumenta(IDFirma As Long, Godina As Long, Optional VrstaDokumenta = Null, Optional Prefix, Optional Sufix _
                                        , Optional AutoBrojDok, Optional BrojZnakovaZaBrDok, Optional PovecajZa _
                                        , Optional Tabela As String = "T_Robna dokumenta", Optional Level As Byte = 0) As String
'Kreirano: 07-01-2022
'Modifikovano: 28-01-2022
'Modifikovano: 04-01-2023

'   [dbo].[fsSledeciBrojDokumenta] (
'     @IDFirma int
'    ,@Godina int = null
'    ,@VrstaDokumenta nvarchar(10) = null
'    ,@Prefix as nvarchar(50) = Null
'    ,@Sufix as nvarchar(50) = Null
'    ,@AutoBrojDok as nvarchar(50) = N'CountVrstaDok'
'    ,@BrojZnakovaZaBrDok as smallint
'    ,@Level as tinyint = 0
'    )
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stRetVal

Dim stTabela As String
Dim stKolonaVrsteDokumenta
Dim numPovecajZa As Long
Dim stPrefix As String
Dim stSufix As String
Dim stAutoBrojDok As String
Dim intBrojZnakovaZaBrDok As Integer

retValOk = True

If IsMissing(Tabela) Then
    stTabela = "T_Robna dokumenta"
    stKolonaVrsteDokumenta = "[Vrsta dokumenta]"
 ElseIf Tabela Like "T_CMDok*" Then
    stTabela = Tabela
    stKolonaVrsteDokumenta = "CM_VrstaDok"
  ElseIf Tabela = "T_Nalozi" Then
    stTabela = Tabela
    stKolonaVrsteDokumenta = "[Vrsta naloga]"
 Else
    stTabela = "T_Robna dokumenta"
    stKolonaVrsteDokumenta = "[Vrsta dokumenta]"
 End If
 
  stRetVal = ""
  
  If IsMissing(PovecajZa) Then
     numPovecajZa = 0
  Else
     numPovecajZa = CLng(PovecajZa)
  End If
  
  If IsMissing(Prefix) Then
    If Level < 250 Then '28-01-2022
        stPrefix = F_AutoBrojDokPrefix()
    Else
        stPrefix = Nz(ReadCFGParametar("AutoBrojDokPrefixPROF"), "") '28-01-2022
    End If
  Else
    stPrefix = CStr(Prefix)
  End If
  
  'Modifikovano: 04-01-2023
  stPrefix = Replace(stPrefix, "@VrstaDokumenta", Nz(VrstaDokumenta, ""))
  
  If IsMissing(Sufix) Then
    stSufix = ReadCFGParametar("AutoBrojDokSufix", "")  '05-08-2022 zbog Diplon-a 'F_AutoBrojDokSufix()
  Else
    stSufix = CStr(Sufix)
  End If
  
  If IsMissing(AutoBrojDok) Then
   stAutoBrojDok = BBCFG.AutoBrojDok
  Else
   stAutoBrojDok = CStr(AutoBrojDok)
  End If
  
  'stVrstaDokumenta = Trim(Nz(VrstaDokumenta, ""))
  
  'If IsMissing(Godina) Then
  '  lintGodina = F_Godina
  'Else
  '  lintGodina = CLng(Nz(Godina, 0))
  'End If
  
  If IsMissing(BrojZnakovaZaBrDok) Then
    intBrojZnakovaZaBrDok = BBCFG.BrojZnakovaZaBrDok
  Else
    intBrojZnakovaZaBrDok = CInt(BrojZnakovaZaBrDok)
  End If

   
stRetVal = ADO_GetValFromUDFS(CNN_CurrentDataBase, "fsSledeciBrojDokumenta" _
                                                                           , IDFirma _
                                                                           , Godina _
                                                                           , VrstaDokumenta _
                                                                           , stPrefix _
                                                                           , stSufix _
                                                                           , stAutoBrojDok _
                                                                           , intBrojZnakovaZaBrDok _
                                                                           , Level)


Exit_Point:
 On Error Resume Next
       fsSledeciBrojDokumenta = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "fsSledeciBrojDokumenta"
 retValOk = False
 Resume Exit_Point
End Function
Public Function SledeciBrojDokumenta(stInputVrstaDokumenta As String, Optional Prefix, Optional Sufix, Optional AutoBrojDok, Optional Godina, Optional PovecajZa, Optional Tabela, Optional Level As Byte = 0, Optional OJ) As String
'Modifikovano: 18-04-2019
'Modifikovano: 25-01-2020  -> DCount radi na tabeli [T_Robna dokumenta] uz uslov stWHERE (zbog profaktura)
'                             dodat je i parametar Godina
'                             Ako je zadat parametar Godina = 0 onda se Dcount radi za sve godine
'Modifikovano: 20-08-2020  -> dodat optional parametar PovecajZa
'Modifikovano: 16-12-2021 -> dodat optional parametar Tabela
'Modifikovano: 07-01-2022 -> iskoriscena funkcija fsSledeciBrojDokumenta
'Dodat parametar: 09-01-2022 -> Optional Level as byte = 0
'Modifikovano: 28-01-2022 -> dodat  stPrefix = ReadCFGParametar("AutoBrojDokPrefixPROF") za Level >=250
'!!!!!!!!!!!!!!!! još treba da se radi za stAutoBrojDok = "MaxVrstaDok" kod CM
'Modifikovano: 04-01-2023

On Error GoTo Err_Point

 Dim stRetVal As String
 Dim stPrefix As String
 Dim stSufix As String
 Dim stAutoBrojDok As String
 Dim numPoslednjiBrojDokumenta As Long
 Dim stVrstaDokumenta As String
 Dim lintGodina As Long
 Dim stWhere As String
 Dim numPovecajZa
 Dim stTabela As String
 Dim stKolonaVrsteDokumenta As String
 'Dim stOznakaOJ As String
 
 
 If IsMissing(Godina) Then
    lintGodina = F_Godina
  Else
    lintGodina = CLng(Nz(Godina, 0))
  End If
 
 If IsMissing(Tabela) Then
    stTabela = "T_Robna dokumenta"
    stKolonaVrsteDokumenta = "[Vrsta dokumenta]"
 ElseIf Tabela Like "T_CMDok*" Then
    stTabela = Tabela
    stKolonaVrsteDokumenta = "CM_VrstaDok"
  ElseIf Tabela = "T_Nalozi" Then
    stTabela = Tabela
    stKolonaVrsteDokumenta = "[Vrsta naloga]"
 ElseIf Tabela = "T_MPDokumenta" Then
    stTabela = Tabela
    stKolonaVrsteDokumenta = "[Vrsta dokumenta]"
 Else
    stTabela = "T_Robna dokumenta"
    stKolonaVrsteDokumenta = "[Vrsta dokumenta]"
 End If
 
 '***************************************************************************
 'BEGIN 07-01-2022
 '***************************************************************************
 If stTabela = "T_Robna dokumenta" Then
    stRetVal = fsSledeciBrojDokumenta(F_IDFirma, lintGodina, stInputVrstaDokumenta, Prefix, Sufix, AutoBrojDok, BBCFG.BrojZnakovaZaBrDok, PovecajZa, stTabela, Level)
    GoTo Exit_Point:
 End If
 '***************************************************************************
 'END 07-01-2022
 '***************************************************************************
  stRetVal = ""
  
  If IsMissing(PovecajZa) Then
     numPovecajZa = 0
  Else
     numPovecajZa = CLng(PovecajZa)
  End If
  
  If IsMissing(Prefix) Then
    If Level < 250 Then '28-01-2022
        stPrefix = F_AutoBrojDokPrefix()
    Else
        stPrefix = Nz(ReadCFGParametar("AutoBrojDokPrefixPROF"), "") '28-01-2022
    End If
  Else
    stPrefix = CStr(Prefix)
  End If
  
  'Modifikovano: 04-01-2023
  stPrefix = Replace(stPrefix, "@VrstaDokumenta", stInputVrstaDokumenta)
  
  If IsMissing(Sufix) Then
    stSufix = F_AutoBrojDokSufix()
  Else
    stSufix = CStr(Sufix)
  End If
  
  If IsMissing(AutoBrojDok) Then
   stAutoBrojDok = BBCFG.AutoBrojDok
  Else
   stAutoBrojDok = CStr(AutoBrojDok)
  End If
  
  stVrstaDokumenta = Trim(Nz(stInputVrstaDokumenta, ""))
  
  
  
  stWhere = "([IDFirma] = " & F_IDFirma() & ")"
  If lintGodina <> 0 Then '25-01-2020 Ako je zadat parametar Godina = 0 onda se Dcount radi za sve godine
    stWhere = stWhere & " AND ([Godina] = " & lintGodina & ")"
  End If
 
  stWhere = stWhere & " AND (" & stKolonaVrsteDokumenta & " = '" & stVrstaDokumenta & "')"
  
  '24-01-24
  If Not IsMissing(OJ) Then
     If stTabela = "T_Nalozi" Then
        stWhere = stWhere & " AND ( OJNalog = " & CLng(OJ) & ")"
     Else
        stWhere = stWhere & " AND ( OJ = " & CLng(OJ) & ")"
     End If
     
  End If
  '24-01-24
  
   If (stVrstaDokumenta <> "*") And (stVrstaDokumenta <> "") Then
        
        If stAutoBrojDok = "MaxVrstaDok" Then
         numPoslednjiBrojDokumenta = Nz(DLookup("[MaxOfBroj dokumenta]", "MaxBrojDokPoVrstama", stKolonaVrsteDokumenta & " = '" & stVrstaDokumenta & "'"), 0)
        ElseIf stAutoBrojDok = "CountVrstaDok" Then
         numPoslednjiBrojDokumenta = Nz(DCount("*", stTabela, stWhere), 0)
        Else
         numPoslednjiBrojDokumenta = Nz(DCount("*", stTabela, stWhere), 0)
        End If
   Else
    numPoslednjiBrojDokumenta = Nz(DCount("*", stTabela), 0)
   End If
   
   stRetVal = CStr(1 + numPoslednjiBrojDokumenta + numPovecajZa)
   stRetVal = DoChLeft(stRetVal, BBCFG.BrojZnakovaZaBrDok, "0")
   stRetVal = stPrefix & stRetVal & stSufix
   
Exit_Point:
On Error Resume Next
   
 SledeciBrojDokumenta = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "SledeciBrojDokumenta"
 Resume Exit_Point
End Function
Public Function SledeciBrojDokumentaUsluga(stInputVrstaDokumenta As String, Optional Prefix, Optional Sufix, Optional AutoBrojDok, Optional Godina, Optional pLevel As Byte = 0) As String
'Modifikovano: 06-02-2019
'Modifikovano: 04-01-2023
'Modifikovano: 23-05-2023 dodat parametar Optional pLevel As Byte = 0

On Error GoTo Err_Point
 Dim stRetVal As String
 Dim stPrefix As String
 Dim stSufix As String
 Dim numPoslednjiBrojDokumenta As Long
 Dim stVrstaDokumenta As String
 Dim lintGodina As Long
 Dim stWhere As String
  
  stRetVal = ""
  If IsMissing(Prefix) Then
    stPrefix = F_AutoBrojDokPrefix()
  Else
    stPrefix = CStr(Prefix)
  End If
  
    'Modifikovano: 04-01-2023
    stPrefix = Replace(stPrefix, "@VrstaDokumenta", stInputVrstaDokumenta)
  
  If IsMissing(Sufix) Then
    stSufix = F_AutoBrojDokSufix()
  Else
    stSufix = CStr(Sufix)
  End If
  
  stVrstaDokumenta = Trim(Nz(stInputVrstaDokumenta, ""))
  
  If IsMissing(Godina) Then
    lintGodina = F_Godina
  Else
    lintGodina = CLng(Nz(Godina, 0))
  End If
  
  stWhere = "([IDFirma] = " & F_IDFirma() & ")"
  If lintGodina <> 0 Then '25-01-2020 Ako je zadat parametar Godina = 0 onda se Dcount radi za sve godine
    stWhere = stWhere & " AND ([Godina] = " & lintGodina & ")"
  End If
  stWhere = stWhere & " AND ([Vrsta dokumenta] = '" & stVrstaDokumenta & "')"
  stWhere = stWhere & " AND ([Level] = " & pLevel & ")" '23-05-2023
  
   If (stVrstaDokumenta <> "*") And (stVrstaDokumenta <> "") Then
        
        If BBCFG.AutoBrojDok = "MaxVrstaDok" Then
         numPoslednjiBrojDokumenta = Nz(DLookup("[MaxOfBroj dokumenta]", "MaxBrojDokPoVrstama_USLUGE", "[Vrsta dokumenta] = '" & stVrstaDokumenta & "'"), 0)
        ElseIf BBCFG.AutoBrojDok = "CountVrstaDok" Then
         numPoslednjiBrojDokumenta = Nz(DCount("*", "T_Usluge dokumenta", stWhere), 0)
        Else
         numPoslednjiBrojDokumenta = Nz(DCount("*", "T_Usluge dokumenta", stWhere), 0)
        End If
   Else
    numPoslednjiBrojDokumenta = Nz(DCount("*", "Usluge dokumenta"), 0)
   End If
   
Exit_Point:
On Error Resume Next
   stRetVal = CStr(1 + numPoslednjiBrojDokumenta)
   stRetVal = DoChLeft(stRetVal, BBCFG.BrojZnakovaZaBrDok, "0")
 SledeciBrojDokumentaUsluga = stPrefix & stRetVal & stSufix
Exit Function

Err_Point:
 BBErrorMSG err, "SledeciBrojDokumentaUsluga"
 Resume Exit_Point
End Function
Public Function SledeciBrojDokumentaProfaktura(stInputVrstaDokumenta As String, Optional Prefix, Optional Sufix) As String
'Modifikovano: 06-02-2019
'Modifikovano: 04-01-2023
On Error Resume Next
 Dim stRetVal As String
 Dim stPrefix As String
 Dim stSufix As String
 Dim numPoslednjiBrojDokumenta As Long
 Dim stVrstaDokumenta As String
  
  stRetVal = ""
  If IsMissing(Prefix) Then
    stPrefix = F_AutoBrojDokPrefix()
  Else
    stPrefix = CStr(Prefix)
  End If
  
 'Modifikovano: 04-01-2023
 stPrefix = Replace(stPrefix, "@VrstaDokumenta", Nz(stInputVrstaDokumenta, ""))
 
  If IsMissing(Sufix) Then
    stSufix = F_AutoBrojDokSufix()
  Else
    stSufix = CStr(Sufix)
  End If
  
  
  stVrstaDokumenta = Trim(Nz(stInputVrstaDokumenta, ""))
  
   If (stVrstaDokumenta <> "*") And (stVrstaDokumenta <> "") Then
        
        If BBCFG.AutoBrojDok = "MaxVrstaDok" Then
         numPoslednjiBrojDokumenta = Nz(DLookup("[MaxOfBroj dokumenta]", "MaxBrojDokPoVrstama_PROFAKTURE", "[Vrsta dokumenta] = '" & stVrstaDokumenta & "'"), 0)
        ElseIf BBCFG.AutoBrojDok = "CountVrstaDok" Then
         numPoslednjiBrojDokumenta = Nz(DCount("*", "Profakture", "[Vrsta dokumenta] like '" & stVrstaDokumenta & "'"), 0)
        Else
         numPoslednjiBrojDokumenta = Nz(DCount("*", "Profakture", "[Vrsta dokumenta] like '" & stVrstaDokumenta & "'"), 0)
        End If
   Else
    numPoslednjiBrojDokumenta = Nz(DCount("*", "Robna dokumenta"), 0)
   End If
   
   stRetVal = CStr(1 + numPoslednjiBrojDokumenta)
   stRetVal = DoChLeft(stRetVal, BBCFG.BrojZnakovaZaBrDok, "0")
 SledeciBrojDokumentaProfaktura = stPrefix & stRetVal & stSufix
End Function
Public Function F_BrojTemeljnice(IDNalog, IDKomitent, Optional FieldSize = 10) As String
On Error Resume Next
 Dim retVal As String

  retVal = "/"
  retVal = CStr(Nz(IDNalog, "")) & "/" & CStr(Nz(IDKomitent, ""))
  F_BrojTemeljnice = Right(retVal, FieldSize)

End Function
Public Function SledeciAutoID(ByVal stImeTabele As String, ByVal stID As String, Optional intKorak As Long = 1) As Long
Dim lintRetVal As Long
  If Left(stImeTabele, 1) <> "[" Then
     stImeTabele = "[" & stImeTabele & "]"
  End If
  If Left(stID, 1) <> "[" Then
     stID = "[" & stID & "]"
  End If
  lintRetVal = Nz(DMax(stID, stImeTabele), 0) + intKorak
  SledeciAutoID = lintRetVal
End Function
Public Function SledeciBrojPredmeta(Optional DatumOtvaranja As Date) As String
'***************************************************
'Obrati pažnju na funkciju KreirajIliPronadjiPredmet
'Kreirano: 24-02-2020
'****************************************************
On Error GoTo Err_Point
Dim stBrojPredmeta As String
Dim pDatumOtvaranja As Date

    If IsMissing(DatumOtvaranja) Then
       pDatumOtvaranja = Date
    Else
       pDatumOtvaranja = DatumOtvaranja
    End If
    'stBrojPredmeta = Nz(DMax("[BrojPredmeta]", "Predmeti"), 0) + 1
    'ok stBrojPredmeta = Nz(DMax("Format([BrojPredmeta],String(20,""0""))", "Predmeti", "IsNumeric([BrojPredmeta])=True"), 0)
    stBrojPredmeta = Nz(DMax("Format([BrojPredmeta],String(20,""0""))", "Predmeti"), 0)
    If IsNumeric(stBrojPredmeta) Then
       stBrojPredmeta = stBrojPredmeta + 1
    Else
       stBrojPredmeta = (1 + DMax("[IDPredmet]", "Predmeti")) & F_AutoBrojDokSufix
    End If
    
Exit_Point:
On Error Resume Next
   SledeciBrojPredmeta = stBrojPredmeta
Exit Function

Err_Point:
    BBErrorMSG err, "SledeciBrojPredmeta"
    Resume Exit_Point
    
End Function
Public Function SledeciBrojTrebovanja(Optional nZaGodinu) As String
  Dim noviBrojTreb As String
  Dim ZaGodinu As Integer
  If IsMissing(nZaGodinu) Then
     ZaGodinu = Year(Date)
  Else
     ZaGodinu = CLng(nZaGodinu)
  End If
  
    noviBrojTreb = 1 + Nz(DCount("*", "T_Trebovanja", "Godina=" & ZaGodinu), 0)
    noviBrojTreb = DoChLeft(noviBrojTreb, 5, "0")
    SledeciBrojTrebovanja = noviBrojTreb & F_AutoBrojDokSufix()
End Function
Public Function PostojiRobniDokument(BrojDokumenta As String, VrstaDokumenta As String, Optional Godina) As Boolean
'Kreirano: 20-08-2020
On Error GoTo Err_Point

Dim lintGodina As Long
Dim retValPostoji As Boolean
Dim stWhere

retValPostoji = False
  If IsMissing(Godina) Then
    lintGodina = F_Godina
  Else
    lintGodina = CLng(Nz(Godina, 0))
  End If
stWhere = "([IDFirma] = " & F_IDFirma() & ")"
  If lintGodina <> 0 Then '25-01-2020 Ako je zadat parametar Godina = 0 onda se Dcount radi za sve godine
    stWhere = stWhere & " AND ([Godina] = " & lintGodina & ")"
  End If
  stWhere = stWhere & " AND ([Vrsta dokumenta] = '" & VrstaDokumenta & "')"
  stWhere = stWhere & " AND ([Broj dokumenta] = '" & BrojDokumenta & "')"
  retValPostoji = (DCount("*", "T_Robna dokumenta", stWhere) > 0)
Exit_Point:
 On Error Resume Next
 PostojiRobniDokument = retValPostoji
Exit Function

Err_Point:
 BBErrorMSG err, "PostojiRobniDokument"
 Resume Exit_Point
End Function

Public Function SledeciBrojNaloga(stInputVrstaNaloga As String, Optional Prefix, Optional Sufix, Optional AutoBrojDok, Optional Godina, _
                                  Optional PovecajZa, Optional Tabela = "T_Nalozi", Optional Level As Byte = 0, Optional OJ) As String
'Kreirano: 15-01-2024
On Error GoTo Err_Point

Dim stPrefix As String
Dim stOznakaOJ As String
Dim stBrojNaloga As String

If Nz(ReadCFGParametar("AutoBrojDokPoOJ", False), False) Then

    If IsMissing(Prefix) Or IsNull(Prefix) Then
       If IsMissing(OJ) Then
          stOznakaOJ = ""
       Else
          stOznakaOJ = Nz(ADO_Lookup(CNN_CurrentDataBase, "OznakaOJ", "BBOrgJedinice", "OJ=" & Trim(CStr(OJ))), Trim(CStr(OJ)))
       End If
       stPrefix = stOznakaOJ
    Else
       stPrefix = CStr(Prefix)
    End If
    
    If stPrefix = "00" Or stPrefix = "" Then
        stPrefix = stInputVrstaNaloga & "-"
    Else
        stPrefix = stPrefix & "-" & stInputVrstaNaloga & "-"
    End If
    
    stBrojNaloga = SledeciBrojDokumenta(stInputVrstaNaloga, stPrefix, Sufix, AutoBrojDok, Godina, PovecajZa, Tabela, Level, OJ)
Else
    stBrojNaloga = SledeciBrojDokumenta(stInputVrstaNaloga, stPrefix, Sufix, AutoBrojDok, Godina, PovecajZa, Tabela, Level)
End If

Exit_Point:

On Error Resume Next
    SledeciBrojNaloga = stBrojNaloga
Exit Function

Err_Point:
 BBErrorMSG err, "SledeciBrojNaloga"
 Resume Exit_Point
End Function
