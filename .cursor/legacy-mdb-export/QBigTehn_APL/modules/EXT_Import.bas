Attribute VB_Name = "EXT_Import"
Option Compare Database
Option Explicit

Public Function UradiImportIzTabeleUTabelu(IzTabele As String, UTabelu As String, Optional SQLTextImport = "", Optional SQLTextPostImport = "", Optional Silent As Boolean = False) As Boolean
 On Error GoTo err_UradiImport
 Dim retVal As Boolean
 Dim qst As String
 Dim BrojInsertovanihSlogova As Long
 Dim BrojUpdateSlog As Long
 Dim BrojSlogovaZaInsert As Long
 Dim BrojSlogovaUTabelu As Long
 Dim BigBitDB As DAO.Database

 Dim stPoruka As String
    '26-07-2021 BBTimerStart
    BBTimerStart
    Set BigBitDB = CurrentDb
    
    If Nz(SQLTextImport, "") = "" Then
     qst = "INSERT INTO [" & UTabelu & "] SELECT [" & IzTabele & "].* FROM [" & IzTabele & "];"
    Else
     qst = SQLTextImport
    End If
    
    DoCmd.SetWarnings False
    DoCmd.Hourglass True
    'DoCmd.RunSQL qst
    BrojInsertovanihSlogova = 0
    BrojSlogovaZaInsert = DCount("*", "[" & IzTabele & "]")
    
    On Error Resume Next
     BigBitDB.Execute qst, dbSeeChanges ', dbFailOnError
     ' **
      If err Then 'verovatno ima parametara
         err.Clear
         On Error GoTo err_UradiImport
         DoCmd.RunSQL qst
      End If
     ' **
     BrojInsertovanihSlogova = BigBitDB.RecordsAffected
    
    'BrojInsertovanihSlogova = CurrentDb.RecordsAffected
    
    If Nz(SQLTextPostImport, "") <> "" Then
     On Error Resume Next
     BigBitDB.Execute SQLTextPostImport, dbSeeChanges
    ' **
      If err Then 'verovatno ima parametara
         err.Clear
         On Error GoTo err_UradiImport
         DoCmd.RunSQL SQLTextPostImport
      End If
    ' **
     BrojUpdateSlog = BigBitDB.RecordsAffected
    End If
    
    BrojSlogovaUTabelu = DCount("*", "[" & UTabelu & "]")
    DoCmd.SetWarnings True
    DoCmd.Hourglass False
    
    'If BrojSlogovaZaInsert <> BrojInsertovanihSlogova Then
                stPoruka = "Broj slogova za insert [" & IzTabele & "] = " & BrojSlogovaZaInsert & vbCrLf
     stPoruka = stPoruka & "Broj insertovanih slogova [" & UTabelu & "] = " & BrojInsertovanihSlogova & vbCrLf
     stPoruka = stPoruka & "Broj slogova u tabeli [" & UTabelu & "] = " & BrojSlogovaUTabelu & vbCrLf
     stPoruka = stPoruka & "Razlika = " & BrojSlogovaZaInsert - BrojSlogovaUTabelu & vbCrLf
     stPoruka = stPoruka & "Trajanje (sec.)" & BBTimerTrajanjeSec
     stPoruka = stPoruka & vbCrLf & vbCrLf & IzTabele & ".Connect= " & BigBitDB.TableDefs(IzTabele).Connect
     stPoruka = stPoruka & vbCrLf & vbCrLf & UTabelu & ".Connect= " & BigBitDB.TableDefs(UTabelu).Connect
     If Not Silent Then
      MsgBox stPoruka, vbInformation, "QMegaTeh"
     End If
    'End If
    retVal = True

err_ExitFunc:
    DoCmd.SetWarnings True
    DoCmd.Hourglass False
    BigBitDB.Close
    Set BigBitDB = Nothing
UradiImportIzTabeleUTabelu = retVal

Exit Function

err_UradiImport:
    retVal = False
    If Not Silent Then
     MsgBox "Nije uradjen prenos podataka iz tabele [" & IzTabele & "] u tabelu [" & UTabelu & "]", vbCritical, "QMegaTeh"
    End If
    Resume err_ExitFunc:
End Function

Public Function ImportIzEXTTabele(ImeIzTabele As String, ImeUTabelu As String) As Boolean
On Error GoTo Err_Point

Dim retValOk As Boolean
Dim SQLTextImport As String
Dim SQLTextPostImport As String

retValOk = True
SQLTextImport = Nz(DLookup("SQLTextImport", "EXT_Import_DEF", "[ImeIzTabele] = '" & ImeIzTabele & "' AND [ImeUTabelu] = '" & ImeUTabelu & "'"), "")
SQLTextPostImport = Nz(DLookup("SQLTextPostImport", "EXT_Import_DEF", "[ImeIzTabele] = '" & ImeIzTabele & "' AND [ImeUTabelu] = '" & ImeUTabelu & "'"), "")

retValOk = UradiImportIzTabeleUTabelu(ImeIzTabele, ImeUTabelu, SQLTextImport, SQLTextPostImport, True)

Exit_Point:
On Error Resume Next
ImportIzEXTTabele = retValOk

Exit Function

Err_Point:
 BBErrorMSG err, "ImportIzEXTBaze(" & ImeIzTabele & ", " & ImeUTabelu & ")"
 retValOk = False
 Resume Exit_Point

End Function
Public Function Test_ImportIzTXTFinUTMP(stEDIDef As String, TxtFileName As String) As Boolean
'22-10-2018
'ImportIzTXTFinUTMP("", "E:\SHARES\SuperSpace\IMPORT\IZVOZ_NOVI10.10.2018.TXT")
On Error GoTo Err_Point

Dim retValOk As Boolean
Dim txtInputFile As Variant
Dim stLine As String
Dim LineNumber As Long
Dim stColSep As String

retValOk = True
LineNumber = 0
'stColSep = "~"
stColSep = Chr(179)

txtInputFile = FreeFile
Open TxtFileName For Input As #txtInputFile
Do While Not EOF(1)    ' Check for end of file.
    Line Input #1, stLine    ' Read line of data.
    Debug.Print LineNumber, stLine   ' Print to the Immediate window.
    LineNumber = LineNumber + 1
Loop

 
Exit_Point:
On Error Resume Next
   Close #txtInputFile
   Test_ImportIzTXTFinUTMP = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "ImportIzTXTFinUTMP"
 retValOk = True
 Resume Exit_Point
End Function
Public Function PrevediLinijuUKolone(ByVal stLine As String, ByVal stColSep As String) As Variant
On Error GoTo Err_Point

Dim Kolone() As String
Dim pozSep As Integer
Dim BrojKolone As Integer

BrojKolone = 0
While Len(stLine) > 0
  
  BrojKolone = BrojKolone + 1
  ReDim Preserve Kolone(BrojKolone)
  
  pozSep = InStr(stLine, stColSep)
  
  If pozSep > 0 Then
    Kolone(BrojKolone) = Mid(stLine, 1, pozSep - 1)
    stLine = Right(stLine, Len(stLine) - pozSep)
  Else
    Kolone(BrojKolone) = stLine
    stLine = ""
  End If
  
Wend

Exit_Point:
On Error Resume Next
   Kolone(0) = BrojKolone 'Ovde upisujemo broj kolona
   PrevediLinijuUKolone = Kolone()
Exit Function

Err_Point:
 BBErrorMSG err, "PrevediLinijuUKolone"
 Resume Exit_Point
End Function
Private Function MapaZaKolonu(ByVal stSource As String, Mapa As Variant) As String
Dim i As Integer
Dim stRetVal As String

stRetVal = ""
For i = 1 To UBound(Mapa, 2)
 If Mapa(0, i) = stSource Then
   stRetVal = Mapa(1, i)
   Exit For
 End If
Next i
MapaZaKolonu = stRetVal
End Function
Public Function SnumiSlogUTabelu(tblRSet As DAO.Recordset, Kolone As Variant, Vrednosti As Variant, Mapiranje) As Boolean
On Error GoTo Err_Point

Dim retValOk As Boolean
Dim BrojKolona As Integer
Dim i As Integer
Dim stImePolja As String

retValOk = True
'ReDim Preserve Kolone(15)


BrojKolona = Kolone(0)
'ReDim Preserve Kolone(BrojKolona)
'ReDim Preserve Vrednosti(BrojKolona)

tblRSet.AddNew

For i = 1 To BrojKolona
 'On Error Resume Next
 'tblRSet(Kolone(i)).Value = Vrednosti(i)
 stImePolja = MapaZaKolonu(Kolone(i), Mapiranje)
 If stImePolja <> "" Then
  tblRSet(stImePolja).Value = Vrednosti(i)
 End If
Next i

tblRSet.Update

Exit_Point:
On Error Resume Next
  SnumiSlogUTabelu = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "SnumiSlogUTabelu"
 retValOk = False
 Resume Exit_Point
End Function

Public Function ImportTXTUTMP_SuperSpace(ImeFajla As String) As Boolean
On Error GoTo Err_Point
 Dim retValOk As Boolean
 
 retValOk = True
 
 If Not FileExists(ImeFajla) Then
  MsgBox "Ne postoji fajl" & vbCrLf & ImeFajla, vbCritical, "QMegaTeh"
  retValOk = False
  ImportTXTUTMP_SuperSpace = retValOk
  Exit Function
 End If
  
 
 retValOk = ForsirajNoviLinkZaTabelu("TXT_Link_GK_SuperSpace", "TXT_Link_GK_SuperSpace", ImeFajla)
 'Test_ImportIzTXTFinUTMP
 HideNavPane False
 
 If Not retValOk Then
  MsgBox "Ne moze se kreirati link za fajl: " & vbCrLf & ImeFajla, vbCritical, "QMegaTeh"
  retValOk = False
  ImportTXTUTMP_SuperSpace = retValOk
  Exit Function
 End If
 
 DoCmd.SetWarnings False
 DoCmd.OpenQuery "TXT_Link_GK_SuperSpace_Import_Komitenti"
 DoCmd.SetWarnings True
 
 'KreirajTmpTabeluUTmpBazi "tmp_StavkeZaKnjizenjeUGKPoSemi", "TXT_Link_GK_SuperSpace_QZaImportUTMP", , True, , "IDKomitent", "PIB", "BrojDokumenta"
 Call ObrisiSadrzajTabele("tmp_StavkeZaKnjizenjeUGKPoSemi")
 
 DoCmd.SetWarnings False
 DoCmd.OpenQuery "TXT_Link_GK_SuperSpace_ImportUTMP"
 DoCmd.SetWarnings True
 
  
Exit_Point:
 ImportTXTUTMP_SuperSpace = retValOk
 Exit Function
 
Err_Point:
 BBErrorMSG err, "ImportTXTUTMP_SuperSpace"
 retValOk = False
 Resume Exit_Point
End Function

Public Function UradiImportIzTabeleUSQLTabelu(IzTabele As String, UTabelu As String _
                                            , Optional SQLTextImport = "" _
                                            , Optional SQLTextPostImport = "" _
                                            , Optional Silent As Boolean = False _
                                            , Optional IdentityInsert As Boolean = True) As Boolean
'***********************************************************
'KREIRANO 30-12-18
'MODIFIKOVANO: 12-11-2019
'***********************************************************
 On Error GoTo err_UradiImport
 Dim retValOk As Boolean
 Dim qst As String
 Dim BrojInsertovanihSlogova As Long
 Dim BrojUpdateSlog As Long
 Dim BrojSlogovaZaInsert As Long
 Dim BrojSlogovaUTabelu As Long
 Dim BigBitDB As DAO.Database
 Dim stPoruka As String
    
    BBTimerStart
    
    BrojInsertovanihSlogova = 0
    BrojSlogovaZaInsert = DCount("*", "[" & IzTabele & "]")
    Set BigBitDB = CurrentDb


If IsAutoNumber(UTabelu) Then                   'If IdentityInsert Then
      retValOk = ImportPodToSQL(IzTabele, UTabelu, True, BrojInsertovanihSlogova)
Else
    If Nz(SQLTextImport, "") = "" Then
     qst = "INSERT INTO [" & UTabelu & "] SELECT [" & IzTabele & "].* FROM [" & IzTabele & "];"
    Else
     qst = SQLTextImport
    End If
   
    DoCmd.SetWarnings False
    DoCmd.Hourglass True
    'DoCmd.RunSQL qst
    
    
    On Error Resume Next
     BigBitDB.Execute qst, dbSeeChanges ', dbFailOnError
     ' **
      If err Then 'verovatno ima parametara
        stPoruka = "Error # " & stR(err.Number) & " was generated by " _
            & err.Source & Chr(13) & err.Description
            
        stPoruka = stPoruka & vbCrLf & "BigBitDB.Execute(" & qst & ", dbSeeChanges)"
        stPoruka = stPoruka & vbCrLf & vbCrLf & "Da li zelite da uradim DoCmd.RunSQL?"
         err.Clear
         
         On Error GoTo err_UradiImport
         If BBPitanje(stPoruka) Then
            DoCmd.RunSQL qst
         End If
         
      End If
     ' **
     BrojInsertovanihSlogova = BigBitDB.RecordsAffected
    
    'BrojInsertovanihSlogova = CurrentDb.RecordsAffected
    
    If Nz(SQLTextPostImport, "") <> "" Then
     On Error Resume Next
     BigBitDB.Execute SQLTextPostImport, dbSeeChanges
    ' **
      If err Then 'verovatno ima parametara
         err.Clear
         On Error GoTo err_UradiImport
         DoCmd.RunSQL SQLTextPostImport
      End If
    ' **
     BrojUpdateSlog = BigBitDB.RecordsAffected
    End If
    
   
    DoCmd.SetWarnings True
    DoCmd.Hourglass False
End If

     BrojSlogovaUTabelu = DCount("*", "[" & UTabelu & "]")
    'If BrojSlogovaZaInsert <> BrojInsertovanihSlogova Then
                stPoruka = "Broj slogova za insert [" & IzTabele & "] = " & BrojSlogovaZaInsert & vbCrLf
     stPoruka = stPoruka & "Broj insertovanih slogova [" & UTabelu & "] = " & BrojInsertovanihSlogova & vbCrLf
     stPoruka = stPoruka & "Broj slogova u tabeli [" & UTabelu & "] = " & BrojSlogovaUTabelu & vbCrLf
     stPoruka = stPoruka & "Razlika = " & BrojSlogovaZaInsert - BrojSlogovaUTabelu & vbCrLf
     stPoruka = stPoruka & "Trajanje = " & BBTimerTrajanjeSec
     stPoruka = stPoruka & vbCrLf & vbCrLf & IzTabele & ".Connect= " & BigBitDB.TableDefs(IzTabele).Connect
     stPoruka = stPoruka & vbCrLf & vbCrLf & UTabelu & ".Connect= " & BigBitDB.TableDefs(UTabelu).Connect
     If Not Silent Then
      MsgBox stPoruka, vbInformation, "QMegaTeh"
     End If
    'End If
    retValOk = True

err_ExitFunc:
On Error Resume Next
  
    DoCmd.SetWarnings True
    DoCmd.Hourglass False
    BigBitDB.Close
    Set BigBitDB = Nothing

UradiImportIzTabeleUSQLTabelu = retValOk

Exit Function

err_UradiImport:
    retValOk = False
    If Not Silent Then
     MsgBox "Nije uradjen prenos podataka iz tabele [" & IzTabele & "] u tabelu [" & UTabelu & "]", vbCritical, "QMegaTeh"
    End If
    Resume err_ExitFunc
End Function
Public Function PopraviTMPStavkeGKZaKnjizenje(stTMPTabela As String)
'***********************************************************
'KREIRANO 22-10-19
'***********************************************************
On Error GoTo Err_Point

Dim retValOk As Boolean
Dim stSQL As String

retValOk = True

'************************************************************************
'UPISI IDKomitenta 0
stSQL = "UPDATE tmp_StavkeGKZaImport "
stSQL = stSQL & " SET tmp_StavkeGKZaImport.[Analiticka sifra] = null;"
CurrentDb.Execute stSQL, dbSeeChanges

'UPISI IDKomitenta preko PIB-a
stSQL = "UPDATE Komitenti INNER JOIN tmp_StavkeGKZaImport ON Komitenti.PIB = tmp_StavkeGKZaImport.PIBKomitenta"
stSQL = stSQL & " SET tmp_StavkeGKZaImport.[Analiticka sifra] = [Komitenti].[Sifra];"

CurrentDb.Execute stSQL, dbSeeChanges

'************************************************************************
'UPISI Poziciju
stSQL = "UPDATE tmp_StavkeGKZaImport SET tmp_StavkeGKZaImport.Pozicija =0"
stSQL = stSQL & " WHERE (((Nz(Trim([Pozicija]),'')='')=True));"
CurrentDb.Execute stSQL, dbSeeChanges
'************************************************************************

'************************************************************************
'UPISI PDVStatus komitenata
stSQL = "UPDATE tmp_StavkeGKZaImport SET tmp_StavkeGKZaImport.PDVStatusKomitenta =0"
stSQL = stSQL & " WHERE (((Nz(Trim([PDVStatusKomitenta]),'')='')=True));"
CurrentDb.Execute stSQL, dbSeeChanges
'************************************************************************
'************************************************************************

'UPISI Vrsta sifre komitenata
stSQL = "UPDATE tmp_StavkeGKZaImport SET tmp_StavkeGKZaImport.VrstaSifreKomitenta ='KUPDOB'"
stSQL = stSQL & " WHERE (((Nz(Trim([VrstaSifreKomitenta]),'')='')=True));"
CurrentDb.Execute stSQL, dbSeeChanges
'************************************************************************

Exit_Point:
 On Error Resume Next
 PopraviTMPStavkeGKZaKnjizenje = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "PopraviTMPStavkeGKZaKnjizenje::"
    retValOk = False
    Resume Exit_Point
    
End Function
Public Function TMPStavkeGKZaKnjizenje_DodajNoveKomitente(stTMPTabela As String)
'***********************************************************
'KREIRANO 22-10-19
'***********************************************************
On Error GoTo Err_Point

Dim retValOk As Boolean
Dim stSQL As String

retValOk = True

'************************************************************************
'UPISI IDKomitenta 0
stSQL = "UPDATE tmp_StavkeGKZaImport "
stSQL = stSQL & " SET tmp_StavkeGKZaImport.[Analiticka sifra] = null;"
CurrentDb.Execute stSQL, dbSeeChanges

'UPISI IDKomitenta preko PIB-a
stSQL = "UPDATE Komitenti INNER JOIN tmp_StavkeGKZaImport ON Komitenti.PIB = tmp_StavkeGKZaImport.PIBKomitenta"
stSQL = stSQL & " SET tmp_StavkeGKZaImport.[Analiticka sifra] = [Komitenti].[Sifra];"

CurrentDb.Execute stSQL, dbSeeChanges

'************************************************************************
'UPISI Poziciju
stSQL = "UPDATE tmp_StavkeGKZaImport SET tmp_StavkeGKZaImport.Pozicija =0"
stSQL = stSQL & " WHERE (((Nz(Trim([Pozicija]),'')='')=True));"
CurrentDb.Execute stSQL, dbSeeChanges
'************************************************************************

Exit_Point:
 On Error Resume Next
 TMPStavkeGKZaKnjizenje_DodajNoveKomitente = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "TMPStavkeGKZaKnjizenje_DodajNoveKomitente::"
    retValOk = False
    Resume Exit_Point
    
End Function
Public Function GetColumnListFromTable(stImeTabele As String) As String
'************************************
'Kreirano: 12-11-2019
'************************************
On Error GoTo Err_Point
   Dim tDef As TableDef
   Dim BigBit As DAO.Database
   Dim stRetVal As String
   Dim i As Integer
   
   stRetVal = ""
   Set BigBit = CurrentDb
   
   Set tDef = BigBit.TableDefs(stImeTabele)
   
   For i = 0 To tDef.Fields.Count - 1
     stRetVal = stRetVal & "[" & tDef.Fields(i).Name & "], "
   Next i
   stRetVal = Left(stRetVal, Len(stRetVal) - 2)
   stRetVal = "(" & stRetVal & ")"
Exit_Point:
  On Error Resume Next
  GetColumnListFromTable = stRetVal
  
  Set tDef = Nothing
  BigBit.Close
  Set BigBit = Nothing
  Exit Function
  
Err_Point:
 BBErrorMSG err, "GetColumnListFromTable"
 Resume Exit_Point
End Function
Public Function GetValueListFromFields(flds As DAO.Fields) As String
'************************************
'Kreirano: 12-11-2019
'************************************
On Error GoTo Err_Point
   Dim tDef As TableDef
   Dim BigBit As DAO.Database
   Dim stRetVal As String
   Dim stVal As String
   Dim i As Integer
   
   stRetVal = ""
   Set BigBit = CurrentDb
   
   For i = 0 To flds.Count - 1
      stRetVal = stRetVal & CStrSQL(flds(i), flds(i).Type) & ","
   Next i
   stRetVal = Left(stRetVal, Len(stRetVal) - 1)
   
   stRetVal = "(" & stRetVal & ")"
Exit_Point:
  On Error Resume Next
  GetValueListFromFields = stRetVal
  
  Set tDef = Nothing
  BigBit.Close
  Set BigBit = Nothing
  Exit Function
  
Err_Point:
 BBErrorMSG err, "GetValueListFromFields"
 Resume Exit_Point
End Function
Public Function ImportPodToSQL(IzTabele As String, UTabelu As String, Optional IdentityInsert As Boolean = False, _
                          Optional ByRef UspesnoSlogova As Long, Optional ByRef NeuspesnoSlogova As Long) As Boolean
'************************************
'Kreirano: 12-11-2019
' ImportPodSQL("Komitenti1","Komitenti")
'************************************
On Error GoTo Err_Point

 Dim retValOk As Boolean
 
 Dim rstIzTabele As DAO.Recordset
 Dim BigBit As DAO.Database
 Dim stSQLCmd As String
 Dim stColList As String
 Dim stValList As String
 'Dim UspesnoSlogova As Long
 'Dim NeuspesnoSlogova As Long
 Dim stErrDesc As String
 Dim PrikaziPorukeOGreskama As Boolean
 '************
 Dim pCMD As New ADODB.Command
 Dim CNNString As String
 Dim CmdRetValOk As Boolean
 '************
 retValOk = True
 PrikaziPorukeOGreskama = True
 UspesnoSlogova = 0
 NeuspesnoSlogova = 0
 
 DoCmd.Hourglass True
 
 pCMD.ActiveConnection = BBCFG.CNNString
 pCMD.CommandType = adCmdText
 
 If IdentityInsert Then
    pCMD.CommandText = "SET IDENTITY_INSERT [" & UTabelu & "] ON"
    pCMD.Execute
    'CmdRetVal = pCmd.Parameters("@RETURN_VALUE")
    'CmdRetVal = (pCMD.Parameters(0) = 0)
    CmdRetValOk = (pCMD.ActiveConnection.Errors.Count = 0)
 End If
 '************
 
 stColList = GetColumnListFromTable(IzTabele)
 
 Set BigBit = CurrentDb
 Set rstIzTabele = BigBit.OpenRecordset("SELECT * FROM [" & IzTabele & "]", dbOpenDynaset, dbSeeChanges)
 
 
 While Not rstIzTabele.EOF
  stValList = GetValueListFromFields(rstIzTabele.Fields)
  stSQLCmd = "INSERT INTO [" & UTabelu & "]" & vbCr
  stSQLCmd = stSQLCmd & stColList & vbCr
  stSQLCmd = stSQLCmd & "VALUES" & vbCr
  stSQLCmd = stSQLCmd & stValList
  'Debug.Print stSQLCMD
    pCMD.CommandType = adCmdText
    pCMD.CommandText = stSQLCmd
    On Error Resume Next
    pCMD.Execute
    CmdRetValOk = (pCMD.ActiveConnection.Errors.Count = 0)
    stErrDesc = err.Description
    On Error GoTo Err_Point
    If CmdRetValOk Then
     UspesnoSlogova = UspesnoSlogova + 1
    Else
     NeuspesnoSlogova = NeuspesnoSlogova + 1
     stErrDesc = stErrDesc & vbCr & vbCr & "Da li da prikazujem sledece poruke o greskama?"
     If PrikaziPorukeOGreskama Then
        PrikaziPorukeOGreskama = BBPitanje(stErrDesc)
     End If
    End If
  ' SAMO ZA TESTIRANJE rstIzTabele.MoveLast
  rstIzTabele.MoveNext
 Wend
 
Exit_Point:
  On Error Resume Next
  
  If IdentityInsert Then
    pCMD.CommandText = "SET IDENTITY_INSERT [" & UTabelu & "] OFF"
    pCMD.Execute
    CmdRetValOk = (pCMD.ActiveConnection.Errors.Count = 0)
  End If
  pCMD.ActiveConnection.Close
    
  rstIzTabele.Close
  Set rstIzTabele = Nothing
  BigBit.Close
  Set BigBit = Nothing
  
  ImportPodToSQL = retValOk

Exit Function
  
Err_Point:
 BBErrorMSG err, "ImportPodToSQL"
 retValOk = False
 Resume Exit_Point
End Function

