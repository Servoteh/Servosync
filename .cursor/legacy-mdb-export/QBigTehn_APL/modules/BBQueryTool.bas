Attribute VB_Name = "BBQueryTool"
Option Compare Database
Option Explicit
Const ODBC_DataTypeEnum = "ODBC_DataTypeEnum" ' ime tabele
Const BBQueryDef = "BBQueryDef" ' ime tabele
Const BBQueryParDef = "BBQueryParDef" ' ime tabele
Public Const TmpAccQuery = "~Acc_Tmp~"
Private Function DozvoljenZnakZaSQLArg(ch As String) As Boolean
'Kreirano: 09-11-2020
'@Pera_01,
'!!ne važi za Access: Forms![Ovo_Ono]![Var ijabla-Broj_001]

Dim retValOk

retValOk = False
retValOk = retValOk Or ((Asc("0") <= Asc(ch)) And (Asc(ch) <= Asc("9")))
retValOk = retValOk Or ((Asc("a") <= Asc(ch)) And (Asc(ch) <= Asc("z")))
retValOk = retValOk Or ((Asc("A") <= Asc(ch)) And (Asc(ch) <= Asc("Z")))
retValOk = retValOk Or ch = "_"

DozvoljenZnakZaSQLArg = retValOk
End Function
Public Function ReplaceSQLArgWithValue(ByVal stQuery As String, ByVal stArgName As String, ByVal stArgVal As String, Optional Delimiter = ",") As String
'Kreirano: 09-11-2020
' ReplaceSQLArgWithValue("@Arg, @Arg2", "@Arg", "xx") trebe da bude "xxx, @Arg2"
'Problem su arg tipa @Arg,@Arg2... treba u prvom prolazu zameniti samo @Arg a ne i @Arg2
'? ReplaceSQLArgWithValue("SELECT Nesto FROM Imefunkcije(@Par1,@Par2,@Par3)","@Par1","<<Vrednost>>")

On Error GoTo Err_Point
Dim stRetVal As String
Dim pDelimeter As String
Dim i As Integer
Dim ArgArray() As String
Dim OkToReplace As Boolean
Dim sledeciznak As String

ArgArray = Split(stQuery, Delimiter, , vbTextCompare)
stRetVal = ""

For i = LBound(ArgArray) To UBound(ArgArray)

    If i = LBound(ArgArray) Then 'Ako je prvi clan niza ide posebna prica
        pDelimeter = ""
        stRetVal = stRetVal & Replace(ArgArray(i), stArgName, stArgVal)
    'ElseIf i = UBound(ArgArray) Then 'Ako je poslednji clan niza ide opet posebna prica
    '    pDelimeter = Delimiter
    '    stRetVal = stRetVal & pDelimeter & Replace(ArgArray(i), stArgName, stArgVal)
    ElseIf Trim(ArgArray(i)) = Trim(stArgName) Then
        pDelimeter = Delimiter
        'stRetVal = stRetVal & pDelimeter & stArgVal '<- Ako NE CUVAM razmake
        stRetVal = stRetVal & pDelimeter & Replace(ArgArray(i), Trim(stArgName), stArgVal) '<- Ako CUVAM razmake
    Else
        If stRetVal = "" Then
            pDelimeter = ""
        Else
            pDelimeter = Delimiter
        End If
        
        OkToReplace = (Left(Trim(ArgArray(i)), Len(Trim(stArgName))) = Trim(stArgName))
        sledeciznak = Mid(Trim(ArgArray(i)), Len(Trim(stArgName)) + 1, 1)
        If OkToReplace And (sledeciznak <> "") Then
           OkToReplace = Not DozvoljenZnakZaSQLArg(sledeciznak)
        End If
        
        If OkToReplace Then
            stRetVal = stRetVal & pDelimeter & Replace(ArgArray(i), Trim(stArgName), stArgVal)
        Else
            stRetVal = stRetVal & pDelimeter & ArgArray(i)
        End If
    End If
Next

Exit_Point:
 On Error Resume Next
 ReplaceSQLArgWithValue = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, ""
 Resume Exit_Point
End Function

Public Function PostojiQuery(QName As String) As Boolean
 On Error GoTo err_PostojiQuery
 Dim retVal As Boolean
 retVal = (CurrentDb.QueryDefs(QName).Name = QName)
 
exit_PostojiQuery:
 PostojiQuery = retVal
 
Exit Function

err_PostojiQuery:
 retVal = False
 err.Clear
 Resume exit_PostojiQuery
End Function
Public Function ExecuteSQLActionQuery(stSQLText As String, ByRef recaff As Long, Optional EvalPar As Boolean = True, Optional stUBazi) As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim qDef As DAO.QueryDef
Dim Par As Parameter

 retValOk = True
 
 If Left(stSQLText, 6) = "BBCMD:" Then 'onda je to neka BBCMD funkcija ili funkcija iz APL
  Eval (Replace(stSQLText, "BBCMD:", ""))
  ExecuteSQLActionQuery = retValOk
  Exit Function
 End If
 
 Set qDef = CurrentDb.CreateQueryDef("", stSQLText)
 For Each Par In qDef.Parameters
   qDef.Parameters(Par.Name) = Eval(Par.Name)
 Next
  
' If qDef.Type = dbQAction Then
   qDef.Execute dbSeeChanges
   recaff = qDef.RecordsAffected
' End If

Exit_Point:
On Error Resume Next
 qDef.Close
 Set qDef = Nothing
 ExecuteSQLActionQuery = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "ExecuteSQLActionQuery=" & stSQLText
 retValOk = False
 Resume Exit_Point
End Function

Public Function AccQueryEvalPar(SQLText As String, ParamArray Par()) As String

Dim stRetVal As String
Dim stPar As String
Dim i As Integer
    
     'SQLText = "SELECT MASTER_R_Tarife.* INTO R_Tarife IN ' & [Forms]![SHUTTLE_ODBCSynch]![ShuttleBaza] & 'FROM MASTER_R_Tarife;"
     stRetVal = SQLText
     For i = LBound(Par()) To UBound(Par())
      stPar = Par(i)
      stRetVal = Replace(stRetVal, stPar, Eval(stPar))
      'Debug.Print "par(" & i & ")=", par(i), TypeName(par(i))
    Next i
    
AccQueryEvalPar = stRetVal
End Function

'****************
Public Function DodajACCParametreUTabelu(SQLText As String, QName As String) As Boolean
On Error GoTo Err_Point

Dim qDef As QueryDef
Dim retValOk As Boolean
Dim DoBrojaParametara As Integer
Dim TabelaParametara As DAO.Recordset
Dim i As Integer

retValOk = True
retValOk = AccQuerySave(TmpAccQuery, SQLText)
If Not retValOk Then
 DodajACCParametreUTabelu = False
 Exit Function
End If
Set qDef = CurrentDb.QueryDefs(TmpAccQuery)

DoBrojaParametara = qDef.Parameters.Count() - 1
Set TabelaParametara = CurrentDb.OpenRecordset("BBQueryParDef", dbOpenDynaset)

For i = 0 To DoBrojaParametara
  TabelaParametara.FindFirst "([Name]= '" & qDef.Parameters(i).Name & "') AND ([QueryName]= '" & QName & "')"
  If TabelaParametara.NoMatch Then
     TabelaParametara.AddNew
        TabelaParametara!Rbr = i
        TabelaParametara!QueryName = QName
        TabelaParametara!Name = qDef.Parameters(i).Name
        TabelaParametara!Type = qDef.Parameters(i).Type
        'TabelaParametara!Size = QDef.Parameters(i).Size
        'TabelaParametara!Precision = QDef.Parameters(i).Precision
        TabelaParametara!Direction = qDef.Parameters(i).Direction
        TabelaParametara!AccMapValue = qDef.Parameters(i).Name
     TabelaParametara.Update
  Else
      TabelaParametara.Edit
        TabelaParametara!Rbr = i
        TabelaParametara!QueryName = QName
        TabelaParametara!Name = qDef.Parameters(i).Name
        TabelaParametara!Type = qDef.Parameters(i).Type
        'TabelaParametara!Size = QDef.Parameters(i).Size
        'TabelaParametara!Precision = QDef.Parameters(i).Precision
        TabelaParametara!Direction = qDef.Parameters(i).Direction
        TabelaParametara!AccMapValue = qDef.Parameters(i).Name
     TabelaParametara.Update
  End If
 'Debug.Print Cmd.Parameters(i).Name
Next i

Exit_Point:
On Error Resume Next
qDef.Close
Set qDef = Nothing

TabelaParametara.Close
Set TabelaParametara = Nothing

 DodajACCParametreUTabelu = retValOk
 
Exit Function
 
Err_Point:
    BBErrorMSG err, "DodajACCParametreUTabelu"
    retValOk = False
    err.Clear
    Resume Exit_Point
End Function
Public Function DodajODBCParametreUTabelu(ProcName As String, QName As String) As Boolean
'Modifikovano: 06-11-2021 => da ne kvari adDBDate
On Error GoTo Err_Point

Dim cmd As New ADODB.Command
Dim retValOk As Boolean
Dim DoBrojaParametara As Integer
Dim TabelaParametara As DAO.Recordset
Dim i As Integer

retValOk = True
cmd.ActiveConnection = F_CNNString("SQL")
cmd.CommandType = adCmdStoredProc
cmd.CommandText = ProcName

cmd.Parameters.Refresh 'posle ove komande svi parametri su definisani!

' cmd.Parameters(0) = @RETURN_VALUE


DoBrojaParametara = cmd.Parameters.Count() - 1
Set TabelaParametara = CurrentDb.OpenRecordset("BBQueryParDef", dbOpenDynaset)

For i = 0 To DoBrojaParametara

 TabelaParametara.FindFirst "([Name]= '" & cmd.Parameters(i).Name & "') AND ([QueryName]= '" & QName & "')"
  If TabelaParametara.NoMatch Then
     TabelaParametara.AddNew
        TabelaParametara!Rbr = i
        TabelaParametara!QueryName = QName
        TabelaParametara!Name = cmd.Parameters(i).Name
        TabelaParametara!Type = cmd.Parameters(i).Type
        TabelaParametara!Size = cmd.Parameters(i).Size
        TabelaParametara!Precision = cmd.Parameters(i).Precision
        TabelaParametara!Direction = cmd.Parameters(i).Direction
        TabelaParametara!AccMapValue = "DEFAULT"
     TabelaParametara.Update
  Else
      TabelaParametara.Edit
        TabelaParametara!Rbr = i
        TabelaParametara!QueryName = QName
        TabelaParametara!Name = cmd.Parameters(i).Name
        If ((TabelaParametara!Type = adDBDate) And (cmd.Parameters(i).Type = adVarWChar)) Then    'adDBDate dolazi iz SQL-a kao adVarWChar, pa kad ga ja popravim "rucno"
            'NE RADI NISTA                                                                        'ova opcija ga "kvari"
        Else
            TabelaParametara!Type = cmd.Parameters(i).Type
        End If
        TabelaParametara!Size = cmd.Parameters(i).Size
        TabelaParametara!Precision = cmd.Parameters(i).Precision
        TabelaParametara!Direction = cmd.Parameters(i).Direction
        'TabelaParametara!AccMapValue = "DEFAULT"
     TabelaParametara.Update
  End If
 'Debug.Print Cmd.Parameters(i).Name
Next i

Exit_Point:
On Error Resume Next
cmd.ActiveConnection.Close
TabelaParametara.Close
Set TabelaParametara = Nothing

 DodajODBCParametreUTabelu = retValOk
 
Exit Function
 
Err_Point:
    BBErrorMSG err, "DodajODBCParametreUTabelu"
    retValOk = False
    err.Clear
    Resume Exit_Point
End Function
Public Function DBTypeText(numType As Integer) As String
Dim stRetVal As String
 stRetVal = Nz(DLookup("dbTypeText", ODBC_DataTypeEnum, "dbTypeCode =" & numType), "Uknown")
 DBTypeText = stRetVal
End Function

Public Function PassTroughParEval(ParType As ADODB.DataTypeEnum, AccMapValue As String) As Variant
'Public Function PassTroughParEval(ParType As Integer, AccMapValue As String) As Variant
'**********************************************************
'Modifikovano 09-08-2019
'dodato ParType = adDBTime
'Modifikovano: 17-11-2020
'Modifikovano: 08-12-2021
'**********************************************************
On Error GoTo Err_Point

Dim stArgVal As String

  If AccMapValue = "DEFAULT" Then
      stArgVal = "DEFAULT"
   ElseIf AccMapValue = "Null" Then
      stArgVal = "Null"
   Else
     On Error Resume Next
     stArgVal = Nz(Eval(AccMapValue), "Null")
     If err Then
      stArgVal = AccMapValue
     End If
     
     If ParType = adDBTime Then
        stArgVal = SQLFormatVreme(stArgVal)
     ElseIf ParType = adDBDate Then                    'IsDate(stArgVal) Or (ParType = adDBDate) Then
        stArgVal = SQLFormatDatuma(stArgVal, True)
     ElseIf ParType = adDate Then                    '08-12-2021
        stArgVal = SQLFormatDatuma(stArgVal, True)
     ElseIf (ParType = adBoolean) Then
        stArgVal = SQLFormatBoolean(stArgVal)
     'ElseIf IsDate(stArgVal) And (ParType <> adDouble) Then '28-02-2020
     'ElseIf IsDate(stArgVal) And (ParType <> adDouble) And (Len(stArgVal) >= 8) Then  '08-12-2021
     ElseIf IsDate(stArgVal) And (ParType <> adDouble) And (Len(stArgVal) >= 8) And (ParType <> adVarWChar) Then '23-05-2024
        stArgVal = SQLFormatDatuma(stArgVal, False)
     End If
     On Error GoTo Err_Point
   End If
    
   If (stArgVal = "Null") Or (stArgVal = "DEFAULT") Then
     'sve je OK
   ElseIf ParType = adVarChar Or ParType = adLongVarChar _
       Or ParType = adVarWChar Or ParType = adLongVarWChar _
       Or ParType = adWChar Then
       
      'dodaj apostrofe na pocetak i kraj
      'stArgVal = "'" & stArgVal & "'"
      stArgVal = "N'" & stArgVal & "'" '04-02-2024 dodato N !!!!!!!!
   End If
    
Exit_Point:

  PassTroughParEval = stArgVal

Exit Function

Err_Point:
  BBErrorMSG err, "PassTroughParEval"
  Resume Exit_Point
End Function
Public Function SQLTextSelectPar(QueryName As String) As String
 Dim pSQLTextSelectPar As String
 
    pSQLTextSelectPar = ""
    pSQLTextSelectPar = pSQLTextSelectPar & "SELECT " & BBQueryParDef & ".* "
    pSQLTextSelectPar = pSQLTextSelectPar & "FROM " & BBQueryParDef & " "
    pSQLTextSelectPar = pSQLTextSelectPar & "WHERE(((" & BBQueryParDef & ".QueryName) = '" & QueryName & "')) "
    pSQLTextSelectPar = pSQLTextSelectPar & "ORDER BY " & BBQueryParDef & ".Rbr;"
    
  SQLTextSelectPar = pSQLTextSelectPar
End Function

Public Function PassTroughQueryMakeSQLTextFromTDefSProc(ByVal QueryName As String, EvalPar As Boolean, ByRef ErrorCode As Long) As String
 On Error GoTo Err_Point
 Dim stRetVal As String
 Dim rstPar As DAO.Recordset
 Dim SQL_RstPar As String
 Dim stArgVal As String
 'Dim SQLTextSelectPar As String
 Dim ProcName
 
 ErrorCode = 0
 ProcName = DLookup("ProcName", BBQueryDef, "QueryName= '" & QueryName & "'")
 
 If IsNull(ProcName) Then
     err.Clear
  err.Raise vbObjectError + 513, "BBMakeSQLText", "Ne postoji definicaja za query [" & QueryName & "] u tabeli [BBQueryDef]"
 End If
      
stRetVal = ""
 Set rstPar = CurrentDb.OpenRecordset(SQLTextSelectPar(QueryName))
 If rstPar.EOF Then
  err.Clear
  err.Raise vbObjectError + 514, "BBMakeSQLText", "Ne postoji definicaja parametara za query [" & QueryName & "] u tabeli [BBQueryParDef]"
  Rem, "BBMakeSQLText", "Ne postoji definicaja za " & QueryName
 End If
 While Not rstPar.EOF
  If rstPar!Direction = 1 Then
 
   stArgVal = PassTroughParEval(rstPar!Type, rstPar!AccMapValue)
   
   rstPar.Edit
    rstPar!Value = stArgVal
   rstPar.Update
   
   If Not EvalPar Then
     stArgVal = rstPar!AccMapValue
   End If
   If stRetVal = "" Then
    stRetVal = stRetVal & rstPar!Name & "=" & stArgVal
   Else
    stRetVal = stRetVal & ", " & rstPar!Name & "=" & stArgVal
   End If
  End If 'rst!Direction = 1
  rstPar.MoveNext
 Wend
 stRetVal = "EXECUTE " & ProcName & " " & stRetVal
Exit_Point:
 On Error Resume Next
 rstPar.Close
 Set rstPar = Nothing
 PassTroughQueryMakeSQLTextFromTDefSProc = stRetVal
 err.Clear
Exit Function

Err_Point:
  BBErrorMSG err, "PassTroughQueryMakeSQLTextFromTDefSProc"
  ErrorCode = err.Number
  Resume Exit_Point
End Function

Public Function PassTroughQueryMakeSQLTextFromTDefSQLText(ByVal QueryName As String, EvalPar As Boolean, ByRef ErrorCode As Long) As String
 On Error GoTo Err_Point
 'Dim stRetVal As String
 Dim rstPar As DAO.Recordset
 'Dim SQL_RstPar As String
 Dim stArgVal As String
 'Dim SQLTextSelectPar As String
 Dim SQLText As String
 
 ErrorCode = 0
 SQLText = Nz(DLookup("SQLText", BBQueryDef, "QueryName= '" & QueryName & "'"), "")
 
 If SQLText = "" Then
     err.Clear
  err.Raise vbObjectError + 513, "BBMakeSQLText", "Ne postoji definicaja za query [" & QueryName & "] u tabeli [BBQueryDef]"
 End If
 
   
'stRetVal = ""
 Set rstPar = CurrentDb.OpenRecordset(SQLTextSelectPar(QueryName))
 'If rstPar.EOF Then
 ' Err.Clear
 ' Err.Raise vbObjectError + 514, "BBMakeSQLText", "Ne postoji definicaja parametara za query [" & QueryName & "] u tabeli [BBQueryParDef]"
 ' Rem, "BBMakeSQLText", "Ne postoji definicaja za " & QueryName
 'End If
 While Not rstPar.EOF
  If rstPar!Direction = 1 Then
 
   stArgVal = PassTroughParEval(rstPar!Type, rstPar!AccMapValue)
   
   rstPar.Edit
    rstPar!Value = stArgVal
   rstPar.Update
   If EvalPar Then
      'SQLText = Replace(SQLText, rstPar!Name, rstPar!Value)
      SQLText = ReplaceSQLArgWithValue(SQLText, rstPar!Name, rstPar!Value)
   End If
   
  End If 'rst!Direction = 1
  rstPar.MoveNext
 Wend
 
Exit_Point:
 On Error Resume Next
 rstPar.Close
 Set rstPar = Nothing
 PassTroughQueryMakeSQLTextFromTDefSQLText = SQLText
 err.Clear
Exit Function

Err_Point:
  BBErrorMSG err, "PassTroughQueryMakeSQLTextFromTDefSQLText"
  ErrorCode = err.Number
  Resume Exit_Point
End Function
Public Function PassTroughQueryMakeSQLTextFromTDefUDF(ByVal QueryName As String, EvalPar As Boolean, ByRef ErrorCode As Long) As String
'Modifikovano: 08-11-2020
 On Error GoTo Err_Point
 Dim stRetVal As String
 Dim rstPar As DAO.Recordset
 Dim SQL_RstPar As String
 Dim stArgVal As String
 'Dim SQLTextSelectPar As String
 Dim ProcName
 
 ErrorCode = 0
 ProcName = DLookup("ProcName", BBQueryDef, "QueryName= '" & QueryName & "'")
 
 If IsNull(ProcName) Then
     err.Clear
  err.Raise vbObjectError + 513, "BBMakeSQLText", "Ne postoji definicaja za query [" & QueryName & "] u tabeli [BBQueryDef]"
 End If
      
stRetVal = ""
 Set rstPar = CurrentDb.OpenRecordset(SQLTextSelectPar(QueryName))
 If rstPar.EOF Then
  err.Clear
  err.Raise vbObjectError + 514, "BBMakeSQLText", "Ne postoji definicaja parametara za query [" & QueryName & "] u tabeli [BBQueryParDef]"
  Rem, "BBMakeSQLText", "Ne postoji definicaja za " & QueryName
 End If
 While Not rstPar.EOF
  If rstPar!Direction = 1 Then
 
   stArgVal = PassTroughParEval(rstPar!Type, rstPar!AccMapValue)
   
   rstPar.Edit
    rstPar!Value = stArgVal
   rstPar.Update
   
   If Not EvalPar Then
     'stArgVal = rstPar!AccMapValue
     stArgVal = rstPar!Name
   End If
   If stRetVal = "" Then
    stRetVal = stRetVal & stArgVal
   Else
    stRetVal = stRetVal & ", " & stArgVal
   End If
  End If 'rst!Direction = 1
  rstPar.MoveNext
 Wend
 stRetVal = "SELECT * FROM " & ProcName & "( " & stRetVal & ")"
Exit_Point:
 On Error Resume Next
 rstPar.Close
 Set rstPar = Nothing
 PassTroughQueryMakeSQLTextFromTDefUDF = stRetVal
 err.Clear
Exit Function

Err_Point:
  BBErrorMSG err, "PassTroughQueryMakeSQLTextFromTDefTF"
  ErrorCode = err.Number
  Resume Exit_Point
End Function
Public Function PassTroughQueryMakeSQLTextFromTDef_NETREBA(ByVal QueryName As String, EvalPar As Boolean, ByRef ErrorCode As Long) As String
Dim ProcType As String
Dim SQLText As String

   ProcType = Nz(DLookup("ProcType", BBQueryDef, "QueryName= '" & QueryName & "'"), "")
   
   If ProcType = "SP" Then
    SQLText = PassTroughQueryMakeSQLTextFromTDefSProc(QueryName, EvalPar, ErrorCode)
   ElseIf ProcType = "SQL" Then
    SQLText = PassTroughQueryMakeSQLTextFromTDefSQLText(QueryName, EvalPar, ErrorCode)
   Else
    SQLText = "Nepoznat ProcType za " & QueryName & "!"
    MsgBox SQLText, vbExclamation, "QMegaTeh"
   End If
   PassTroughQueryMakeSQLTextFromTDef_NETREBA = SQLText
End Function
Public Function PassTroughQueryMakeSQLTextFromTDef(ByVal QueryName As String, Optional ByVal EvalPar As Boolean = True, Optional ByRef ErrorCode As Long) As String
On Error GoTo Err_Point
   
   Dim stRetValSQLText As String
   Dim ProcType As String
   
   ProcType = Nz(DLookup("ProcType", BBQueryDef, "QueryName= '" & QueryName & "'"), "")
   
   If ProcType = "SP" Then
    stRetValSQLText = PassTroughQueryMakeSQLTextFromTDefSProc(QueryName, False, ErrorCode)
   ElseIf ProcType = "SQL" Then
    stRetValSQLText = PassTroughQueryMakeSQLTextFromTDefSQLText(QueryName, False, ErrorCode)
   ElseIf ProcType = "UDF" Then
    stRetValSQLText = PassTroughQueryMakeSQLTextFromTDefUDF(QueryName, False, ErrorCode)
   Else
    stRetValSQLText = "Nepoznat ProcType -> (" & Nz(ProcType, "") & ")"
    MsgBox stRetValSQLText, vbExclamation, "QMegaTeh"
   End If

Exit_Point:
On Error Resume Next
    PassTroughQueryMakeSQLTextFromTDef = stRetValSQLText
Exit Function

Err_Point:
    BBErrorMSG err, "PassTroughQueryMakeSQLTextFromTDef"
    Resume Exit_Point
    
End Function
Private Function AutoMapPar(ByVal inPar As String, rstKontroleNaFormi As ADODB.Recordset, ImeForme As String) As String
'Modifikovano: 22-11-2020
On Error GoTo Err_Point

    Dim tmpVal
    Dim retVal As String
    Dim parBezA As String

    parBezA = Replace(inPar, "@", "")

     rstKontroleNaFormi.MoveFirst
     rstKontroleNaFormi.Find "ImeKontrole= '" & parBezA & "'"
     If Not rstKontroleNaFormi.EOF Then
        retVal = "Forms![" & ImeForme & "]![" & parBezA & "]"
     Else
       retVal = inPar
     End If
   
Exit_Point:
 On Error Resume Next
     
     AutoMapPar = retVal

Exit Function

Err_Point:
 BBErrorMSG err, "AutoMapPar"
 retVal = inPar
 Resume Exit_Point
End Function

Public Sub PassTroughQueryAutoMap(QueryName As String)
'Modifikovano: 22-11-2020

 On Error GoTo Err_Point
 Dim stRetValAutoMapPar As String
 Dim rstPar As DAO.Recordset
 Dim rstKontroleNaFormi As ADODB.Recordset
 Dim stArgVal As String
 Dim ProcName
 Dim stParFormName As String
 
 ProcName = DLookup("ProcName", BBQueryDef, "QueryName= '" & QueryName & "'")
 
 If IsNull(ProcName) Then
  err.Clear
  err.Raise vbObjectError + 513, "BBMakeSQLText", "Ne postoji definicaja za query [" & QueryName & "] u tabeli " & BBQueryParDef
 End If
    
   
 Set rstPar = CurrentDb.OpenRecordset(SQLTextSelectPar(QueryName))
 If rstPar.EOF Then
  err.Clear
  err.Raise vbObjectError + 514, "BBMakeSQLText", "Ne postoji definicaja parametara za query [" & QueryName & "] u tabeli " & BBQueryParDef
 End If
 
 stParFormName = DLookup("AccParFormName", BBQueryDef, "QueryName= '" & QueryName & "'")
 If IsLoaded(stParFormName) Then
    Set rstKontroleNaFormi = DRST_KontroleNaFormi(Forms(stParFormName))
 Else
    MsgBox "Za koriscenje ove opcije" & vbCrLf & "forma [" & stParFormName & "]" & vbCrLf & "mora da bude otvorena.", vbExclamation, "QBigBit_LIB"
    GoTo Exit_Point
 End If
 If rstKontroleNaFormi.EOF And rstKontroleNaFormi.BOF Then
  err.Clear
  err.Raise vbObjectError + 515, "BBMakeSQLText", "Ne postoji definicaja vrednosti parametara za query [" & QueryName & "] u tabeli " & BBQueryParDef
 End If
 
 While Not rstPar.EOF
 
  If rstPar!Direction = 1 Then
   stRetValAutoMapPar = AutoMapPar(rstPar!Name, rstKontroleNaFormi, stParFormName)
   If stRetValAutoMapPar <> rstPar!Name Then
    rstPar.Edit
    rstPar!AccMapValue = stRetValAutoMapPar
    rstPar.Update
   End If
  End If
  rstPar.MoveNext
 Wend

Exit_Point:
 On Error Resume Next
 rstPar.Close
 Set rstPar = Nothing
 rstKontroleNaFormi.Close
 Set rstKontroleNaFormi = Nothing
 err.Clear
Exit Sub

Err_Point:
  BBErrorMSG err, "PassTroughQueryAutoMap"
  Resume Exit_Point
End Sub

Public Function PassTroughQueryEvalAllPar(QueryName As String, Optional SaveArgVal As Boolean = False) As String
'? PassTroughQueryEvalAllPar("ODBC_CFG_Global")
'Modifikovano: 10-02-2019
'Modifikovano: 09-11-2020

 On Error GoTo Err_Point
 Dim SQLTextRetVal As String
 Dim rstPar As DAO.Recordset
 Dim stArgVal As String
 Dim stSQLProcType As String

 
 SQLTextRetVal = Nz(DLookup("SQLText", BBQueryDef, "QueryName= '" & QueryName & "'"), "")
 stSQLProcType = Nz(DLookup("ProcType", BBQueryDef, "QueryName= '" & QueryName & "'"), "")
 
 If SQLTextRetVal = "" Then
     err.Clear
  err.Raise vbObjectError + 513, "PassTroughQueryEvalAllPar", "Ne postoji definicaja za query [" & QueryName & "] u tabeli " & BBQueryParDef
 End If
    
 Set rstPar = CurrentDb.OpenRecordset(SQLTextSelectPar(QueryName))
 
 While Not rstPar.EOF
 
  If rstPar!Direction = 1 Then
   stArgVal = PassTroughParEval(rstPar!Type, rstPar!AccMapValue)
   
   If stSQLProcType = "SP" Then 'jer su ovde parametri proslednjeni u obliku @Par=Forms!...
      SQLTextRetVal = Replace(SQLTextRetVal, rstPar!AccMapValue, stArgVal)
      'NE OVO ZA SADA!!! SQLTextRetVal = ReplaceSQLArgWithValue(SQLTextRetVal, rstPar!AccMapValue, stArgVal)
   
   ElseIf stSQLProcType = "UDF" Then 'jer su ovde parametri proslednjeni u obliku @Par=Forms!...
      'SQLTextRetVal = Replace(SQLTextRetVal, rstPar!Name, stArgVal)
      SQLTextRetVal = ReplaceSQLArgWithValue(SQLTextRetVal, rstPar!Name, stArgVal)
      
   ElseIf stSQLProcType = "SQL" Then
      SQLTextRetVal = Replace(SQLTextRetVal, rstPar!Name, stArgVal)
      'SQLTextRetVal = ReplaceSQLArgWithValue(SQLTextRetVal, rstPar!Name, stArgVal)
   Else
      'MsgBox "Nepoznat SQLProcType = " & stSQLProcType
      SQLTextRetVal = Replace(SQLTextRetVal, rstPar!Name, stArgVal)
   End If
    If SaveArgVal Then
     rstPar.Edit
      rstPar!Value = stArgVal
     rstPar.Update
    End If
  End If
  rstPar.MoveNext
 Wend

Exit_Point:
 On Error Resume Next
 rstPar.Close
 Set rstPar = Nothing
  PassTroughQueryEvalAllPar = SQLTextRetVal
 err.Clear
Exit Function

Err_Point:
  BBErrorMSG err, "PassTroughQueryEvalAllPar"
  Resume Exit_Point
End Function
Public Function IsPassTroughQuery(QName As String) As Boolean
'QueryDefTypeEnum.dbQSelect = 0
'QueryDefTypeEnum.dbQSQLPassThrough = 112
On Error Resume Next

Dim retValOk As Boolean
 retValOk = (CurrentDb.QueryDefs(QName).Type = QueryDefTypeEnum.dbQSQLPassThrough)
 If err Then
    retValOk = False
    err.Clear
 End If
 
 IsPassTroughQuery = retValOk
End Function

Public Function PassTroughQuerySave(QName As String, SQLText As String, Optional CNNString, Optional AccQueryRenameIfExist = False) As Boolean
'Modifikovano: 07-11-2020 Optional AccQueryRenameIfExist = False, a bilo je True
On Error GoTo err_Func

Dim retValOk As Boolean
'Dim SQLText As String
Dim qDef As New QueryDef
Dim tmpPostojiQuery As Boolean
Dim ErrorCode As Long
Dim stCNNString As String

Dim StartTime As Single
Dim endTime As Single

StartTime = Timer()

    retValOk = True
    If IsMissing(CNNString) Then
      stCNNString = F_CNNString("ODBC")
    Else
      stCNNString = F_CNNString("ODBC", CNNString)
    End If
    'SQLText = PassTroughQuerySQLText(QName, ErrorCode)
    If ErrorCode <> 0 Then
     retValOk = False
     GoTo exit_Func
    End If
    qDef.Connect = stCNNString
    qDef.sql = SQLText
    qDef.Name = QName
    
    tmpPostojiQuery = PostojiQuery(qDef.Name)
    If tmpPostojiQuery And AccQueryRenameIfExist And Not IsPassTroughQuery(qDef.Name) Then
       'ako postoji Query i ako nije ODBC(PassTrough) onda mu promeni ime, dodaj prefiks ACC_
        CurrentDb.QueryDefs(qDef.Name).Name = "ACC_" & CurrentDb.QueryDefs(qDef.Name).Name
        CurrentDb.QueryDefs.Refresh
        ' i dodaj novi
        CurrentDb.QueryDefs.Append qDef
        CurrentDb.QueryDefs.Refresh
    ElseIf tmpPostojiQuery Then
        'ako postoji promeni mu propertise
        CurrentDb.QueryDefs(qDef.Name).Connect = stCNNString
        CurrentDb.QueryDefs(qDef.Name).sql = SQLText
        CurrentDb.QueryDefs(qDef.Name).ODBCTimeout = 180
        CurrentDb.QueryDefs.Refresh
    Else
        'ako ne postoji kreiraj novi
        qDef.ODBCTimeout = 180
        CurrentDb.QueryDefs.Append qDef
        CurrentDb.QueryDefs.Refresh
    End If
exit_Func:
   On Error Resume Next
   Set qDef = Nothing
   PassTroughQuerySave = retValOk
   endTime = Timer
   'Debug.Print EndTime - StartTime
   Application.Echo True, "PassTroughQuerySave: Time elapsed= " & endTime - StartTime
Exit Function
err_Func:
 BBErrorMSG err, "PassTroughQuerySave"
 retValOk = False
 Resume exit_Func:
End Function
Public Function AccQuerySave(QName As String, SQLText As String) As Boolean
On Error GoTo err_Func

Dim retValOk As Boolean
'Dim SQLText As String
Dim qDef As New QueryDef
Dim tmpPostojiQuery As Boolean
Dim ErrorCode As Long

Dim StartTime As Single
Dim endTime As Single

StartTime = Timer()

    retValOk = True
 
    qDef.sql = SQLText
    qDef.Name = QName
    
    tmpPostojiQuery = PostojiQuery(qDef.Name)
    If tmpPostojiQuery Then
        'ako postoji promeni mu propertise
        CurrentDb.QueryDefs(qDef.Name).Connect = ""
        CurrentDb.QueryDefs(qDef.Name).sql = SQLText
        CurrentDb.QueryDefs.Refresh
    Else
        'ako ne postoji kreiraj novi
        CurrentDb.QueryDefs.Append qDef
        CurrentDb.QueryDefs.Refresh
    End If
exit_Func:
   On Error Resume Next
   Set qDef = Nothing
   AccQuerySave = retValOk
   endTime = Timer
   'Debug.Print EndTime - StartTime
   Application.Echo True, "Time elapsed= " & endTime - StartTime
Exit Function
err_Func:
 BBErrorMSG err, "PassTroughQuerySave"
 retValOk = False
 Resume exit_Func:
End Function
Public Function SetProperlyRecordSource(ByVal CNNString As String, _
                                        Optional FormOrReport As Object, _
                                        Optional ODBCQName, _
                                        Optional ACCQName, _
                                        Optional NoSet, _
                                        Optional ByVal pSort As String = "" _
                                        ) As Boolean
On Error GoTo Err_Point

 Dim stRecordSource As String
 Dim OK As Boolean
 Dim SQLText As String
 Dim ErrorCode As Long
 
 Dim pODBCQName As String
 Dim pACCQName As String
 Dim pNoSet As Boolean
 Dim pUniqueTable As String
 
 Dim pSetAsRST As Boolean
 Dim pRecalcSum As Boolean
 
 Dim pProcType As String
 
 Dim StartTime As Single
 Dim endTime As Single
 Dim retValOk As Boolean
 
 Dim pLockType As Integer
 Dim pCursorLocation As Integer
 Dim pCursorType As Integer
 Dim pCommandTimeout As Integer
 
 Dim pDisconectedRST As Boolean
 
 retValOk = True
 StartTime = Timer()
 DoCmd.Hourglass True
 
 If IsMissing(FormOrReport) Or (FormOrReport Is Nothing) Then
  Set FormOrReport = Screen.ActiveForm
 End If
 
 If IsMissing(ODBCQName) Then
     pODBCQName = Nz(DLookup("[QueryName]", BBQueryDef, "[AccRSFormName]= '" & FormOrReport.Name & "'"), "")
 Else
     pODBCQName = ODBCQName
 End If ' IsMissing(ODBCQName)
 
 If IsMissing(NoSet) Then
  pNoSet = Nz(DLookup("[NoSet]", BBQueryDef, "[QueryName]= '" & pODBCQName & "'"), False)
 Else
  pNoSet = Nz(CBool(NoSet), False)
 End If
 
 If pNoSet Then
   SetProperlyRecordSource = retValOk
   DoCmd.Hourglass False
   endTime = Timer()
   Application.Echo True, "SetProperlyRecordSource: Time elapsed= " & endTime - StartTime
   Exit Function
 End If
 
 If IsMissing(ACCQName) Then
     pACCQName = Nz(DLookup("[AccQueryName]", BBQueryDef, "[AccRSFormName]= '" & FormOrReport.Name & "'"), "")
 Else
     pACCQName = ACCQName
 End If ' IsMissing(ACCQName)
 
 'If Nz(DLookup("[UseAccQuery]", BBQueryDef, "[AccRSFormName]= '" & FormOrReport.Name & "'"), False) Then    '17-01-2021
 If Nz(DLookup("[UseAccQuery]", BBQueryDef, "[QueryName]= '" & pODBCQName & "'"), False) Then               '17-01-2021
    If pACCQName Like "*SELECT*" Then '15-11-2020 to ne može da stane u AccQueryName
       'cela SQL recenica
       stRecordSource = Nz(DLookup("[ACCSqlText]", BBQueryDef, "[AccRSFormName]= '" & FormOrReport.Name & "'"), False)
    Else
       stRecordSource = pACCQName 'ime upita
    End If
  GoTo Exit_Point
 End If
 
 pUniqueTable = Nz(DLookup("[UniqueTable]", BBQueryDef, "[QueryName]= '" & pODBCQName & "'"), "")
 
 '********************************************************************
 On Error Resume Next
 FormOrReport.Controls("LabelTrajanjeUpita").Caption = "Sacekajte..."
 err.Clear
 On Error GoTo Err_Point
 '********************************************************************
 
   If True Then 'BBCFG.SQLDB Then
      'SQLText = PassTroughQueryMakeSQLTextFromTDef(pODBCQName, True, ErrorCode)
      'SQLText = Nz(DLookup("[SQLText]", BBQueryDef, "[AccRSFormName]= '" & FormOrReport.Name & "'"), "")
      If Nz(pODBCQName, "") = "" Then
       BBMsgBox_BigBit "Nije definisan RecordSource za formu/report " & FormOrReport.Name
      Else
       SQLText = PassTroughQueryEvalAllPar(pODBCQName)
    
           ' Ok = (ErrorCode = 0) And PassTroughQuerySave(pODBCQName, SQLText)
             OK = (ErrorCode = 0)
            If OK Then
                'pSetAsRST = Nz(DLookup("[SetAsRST]", BBQueryDef, "[AccRSFormName]= '" & FormOrReport.Name & "'"), False)
                If TypeOf FormOrReport Is Report Then
                    pSetAsRST = False 'Modifikovano: 28-10-2020 report ne može da radi sa ADODB.Recordset-om!!!
                Else
                    pSetAsRST = Nz(DLookup("[SetAsRST]", BBQueryDef, "[QueryName]= '" & pODBCQName & "'"), False) 'Modifikovano: 05-11-2019
                End If
                If pSetAsRST Then
                        '*****************************************************************************************************************
                         pLockType = DLookup("[LockType]", BBQueryDef, "[QueryName]= '" & pODBCQName & "'") 'Modifikovano: 30-11-2020
                         pCursorLocation = DLookup("[CursorLocation]", BBQueryDef, "[QueryName]= '" & pODBCQName & "'") 'Modifikovano: 30-11-2020
                         pCursorType = DLookup("[CursorType]", BBQueryDef, "[QueryName]= '" & pODBCQName & "'") 'Modifikovano: 30-11-2020
                         pCommandTimeout = DLookup("[CommandTimeout]", BBQueryDef, "[QueryName]= '" & pODBCQName & "'") 'Modifikovano: 30-11-2020
                         pDisconectedRST = DLookup("[DisconectedRST]", BBQueryDef, "[QueryName]= '" & pODBCQName & "'") 'Modifikovano: 25-12-2020
                         
                        '*****************************************************************************************************************
                        PrebaciSUMuTAG FormOrReport 'zbog pucanja u Accessu novijem od Access-a 2010
                                                    ' koji ne ume da radi Sum() na ADO recordsetu
                        '*****************************************************************************************************************
                        If pDisconectedRST Then 'Modifikovano: 25-12-2020
                            Set FormOrReport.Recordset = ADO_GetDRST(F_CNNString("SQL", CNNString), SQLText, pLockType, pCursorLocation, pCursorType, True, pCommandTimeout, pSort)
                        Else
                            Set FormOrReport.Recordset = ADO_GetRST(F_CNNString("SQL", CNNString), SQLText, pLockType, pCursorLocation, pCursorType, True, pCommandTimeout, pSort)
                        End If
                        '*****************************************************************************************************************
    
                        If pUniqueTable <> "" Then
                            FormOrReport.UniqueTable = pUniqueTable
                        End If
                        'Set FormOrReport.Recordset = GetUpdatableADORst(SQLText)
                        'pRecalcSum = CBool(Nz(DLookup("[RecalcSum]", BBQueryDef, "[AccRSFormName]= '" & FormOrReport.Name & "'"), False)) '17-01-2021
                        pRecalcSum = CBool(Nz(DLookup("[RecalcSum]", BBQueryDef, "[QueryName]= '" & pODBCQName & "'"), False)) '17-01-2021
                        
                        If pRecalcSum Then
                           RecalcSumFieldsOnForm FormOrReport, FormOrReport.Recordset.Clone
                        End If
                    
                        SetProperlyRecordSource = retValOk
                        DoCmd.Hourglass False
                        endTime = Timer()
                        ADO_EXECUTE_DURATION = Timer - StartTime
                        Application.Echo True, "SetProperlyRecordSource: Time elapsed= " & stR(ADO_EXECUTE_DURATION) & " sec."
                        
                        On Error Resume Next
                        FormOrReport.Controls("LabelTrajanjeUpita").Caption = "Query=" & stR(ADO_EXECUTE_DURATION) & " sec."
                        
                        err.Clear
                    Exit Function
                Else
                    pProcType = Nz(DLookup("[ProcType]", BBQueryDef, "[AccRSFormName]= '" & FormOrReport.Name & "'"), "")
                    If pProcType <> "Acc" Then
                      OK = PassTroughQuerySave(pODBCQName, SQLText, F_CNNString("ODBC", CNNString)) 'i promeni ime Access Upita
                    Else
                     OK = True
                    End If
                    If OK Then
                        stRecordSource = pODBCQName
                    Else
                        stRecordSource = pACCQName
                    End If
                End If
            Else
                stRecordSource = pACCQName
            End If
      End If
   Else
    'Ovo se nikada ne izvršava
     stRecordSource = pACCQName
   End If
Exit_Point:

On Error Resume Next
   FormOrReport.RecordSource = stRecordSource
   If err Then
     MsgBox "Error # " & stR(err.Number) & " was generated by " _
            & err.Source & Chr(13) & err.Description, , "QMegaTeh"
     err.Clear
     retValOk = False
   End If
   
   endTime = Timer()
   ADO_EXECUTE_DURATION = endTime - StartTime
   Application.Echo True, "SetProperlyRecordSource: Time elapsed= " & stR(ADO_EXECUTE_DURATION) & " sec."
      
   SetProperlyRecordSource = retValOk
   DoCmd.Hourglass False
   'vec je On Error Resume Next
   FormOrReport.Controls("LabelTrajanjeUpita").Caption = "Query=" & stR(ADO_EXECUTE_DURATION) & " sec."
  err.Clear

Exit Function

Err_Point:
 MsgBox "Error # " & stR(err.Number) & " was generated by " _
            & err.Source & Chr(13) & err.Description, , "QMegaTeh"
 err.Clear
 retValOk = False
 Resume Exit_Point
End Function
Private Function ReplaceNz(stSQLText As String) As String

 ReplaceNz = Replace(stSQLText, "NZ(", "IsNull(")

End Function
Private Function ReplaceCSTR(stSQLText As String) As String
'Kreirano: 20-08-2019
'? ReplaceCstr("SELECT Cstr([Forms![xx]!Vrednost), x.AAAA FROM x")
 Dim iPosLZ As Integer
 Dim iPosDZ As Integer
 Dim IPosCSTR As Integer
 Dim iBrojLevih As Integer
 Dim iBrojDesnih As Integer
 Dim stZaZamenu As String
 Dim stRetVal As String
 Dim i As Integer
 
 stRetVal = stSQLText
 
 IPosCSTR = InStr(stRetVal, "CSTR(")
 If IPosCSTR = 0 Then
  ReplaceCSTR = stRetVal
  Exit Function
 End If
 
 iPosLZ = InStr(IPosCSTR, stRetVal, "(")
 iBrojLevih = 0
 iBrojDesnih = 0
 
 For i = iPosLZ To Len(stRetVal)
  If Mid(stRetVal, i, 1) = ")" Then
    iBrojDesnih = iBrojDesnih + 1
    If iBrojLevih = iBrojDesnih Then
        iPosDZ = i
        Exit For
    End If
  ElseIf Mid(stRetVal, i, 1) = "(" Then
    iBrojLevih = iBrojLevih + 1
  End If
 Next
 'stZaZamenu = Replace(Mid(stRetVal, IPosCSTR, iPosDZ - IPosCSTR), "CSTR", "CAST") & " AS nvarchar(MAX))"
 stZaZamenu = "CAST" & Mid(stRetVal, IPosCSTR + 4, iPosDZ - IPosCSTR - 4) & " AS nvarchar(MAX))"
 
 stRetVal = Left(stRetVal, IPosCSTR - 1) & stZaZamenu & Right(stRetVal, Len(stRetVal) - iPosDZ)
 ReplaceCSTR = ReplaceCSTR(stRetVal)
 'ReplaceCstr = Replace(stSQLText, "CSTR(", "CAST(")

End Function
Public Function ConvertAccSQLToODBC(stSQLText As String) As String
  Dim stRetVal As String
  stRetVal = stSQLText
  stRetVal = Replace(stRetVal, "DISTINCTROW", "")
  stRetVal = Replace(stRetVal, "NZ(", "IsNull(")
  stRetVal = Replace(stRetVal, """", "'") '*
  stRetVal = Replace(stRetVal, "'*", "'%")
  stRetVal = Replace(stRetVal, "*'", "%'")
  stRetVal = Replace(stRetVal, "&", "+")
  
  stRetVal = ReplaceCSTR(stRetVal)
  
  ConvertAccSQLToODBC = stRetVal
End Function
'**************************************
'Kreirano: 06-12-2018
Public Function EvalParForStoredAccessQuery(AccQueryName As String) As String
On Error Resume Next
 Dim stRetVal As String
 Dim stVredPar As String
 Dim ppar As DAO.Parameter
 
 stRetVal = CurrentDb.QueryDefs(AccQueryName).sql
 stRetVal = ConvertAccSQLToODBC(stRetVal)
 
 For Each ppar In CurrentDb.QueryDefs(AccQueryName).Parameters
  stVredPar = PassTroughParEval(ppar.Type, ppar.Name)
   If err Then
     stVredPar = "<<error value>>"
   End If
  'stRetVal = Replace(stRetVal, ppar.Name, stVredPar)
  stRetVal = ReplaceSQLArgWithValue(stRetVal, ppar.Name, stVredPar)
 Next
 
 EvalParForStoredAccessQuery = stRetVal
 
End Function

Public Function TEST_GetUpdatableADORst(SQLText As String) As ADODB.Recordset
'**********************
'Kreirano: 06-09-2019
'**********************
 Dim cn As ADODB.Connection
 Dim rs As ADODB.Recordset

 
   'Create a new ADO Connection object
   Set cn = New ADODB.Connection

   'Use the Access 10 and SQL Server OLEDB providers to
   'open the Connection
   With cn
      .Provider = "Microsoft.Access.OLEDB.10.0"
      .Properties("Data Provider").Value = "SQLOLEDB"
      .Properties("Data Source").Value = "P50\SQLEXPRESS"
      .Properties("User ID").Value = "QBigBit"
      .Properties("Password").Value = "QbigBit.9496"
      .Properties("Initial Catalog").Value = "VuleMarket"
      .Open
   End With
   
 Set rs = New ADODB.Recordset
 With rs
 Set .ActiveConnection = cn
 '.Source = "SELECT * FROM R_Artikli" OK
  .Source = SQLText
 .LockType = adLockOptimistic
 '.CursorLocation = adUseClient
 .CursorType = adOpenKeyset
 .Open
 End With
 'Set the form's Recordset property to the ADO recordset
 Set TEST_GetUpdatableADORst = rs
 On Error Resume Next
  
 Set rs = Nothing
 Set cn = Nothing
End Function

Public Function SumADORstField_NETREBA(fldName As String, Optional rst As ADODB.Recordset) As Variant
'**********************
'Kreirano: 07-12-2018
'**********************
On Error GoTo Err_Point

  Dim sumVal As Double
  Dim retValErrNumber As Long
  
  retValErrNumber = 0
  sumVal = 0
    
  If rst Is Nothing Then
   If Screen.ActiveForm.RecordsetClone Is Nothing Then
    'err.Raise 123, "SumADORstField"
    err.Raise vbObjectError + 513, "SumADORstField", "ADODB.Recordset nije definisan "
    GoTo Exit_Point
   Else
    Set rst = Screen.ActiveForm.RecordsetClone
   End If
  End If
    
  rst.MoveFirst
  While Not rst.EOF
    sumVal = sumVal + Nz(rst(fldName).Value, 0)
    rst.MoveNext
  Wend
    
Exit_Point:
On Error Resume Next
  If retValErrNumber = 0 Then
    SumADORstField_NETREBA = sumVal
  Else
    SumADORstField_NETREBA = "#Error:" & retValErrNumber
  End If
Exit Function

Err_Point:
 retValErrNumber = err.Number
 Resume Exit_Point
End Function
Public Function PrebaciSUMuTAG(FormOrReport As Object)
On Error GoTo Err_Point
 
 Dim ctl As control
 
For Each ctl In FormOrReport.Controls
  If ctl.ControlType = acTextBox Then
   If ctl.ControlSource Like "*Sum(*" Then
        ctl.tag = ctl.ControlSource
        ctl.ControlSource = ""
   End If
  End If
Next

Exit_Point:
On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, FormOrReport.Name & "::PrebaciSUMuTAG"
 Resume Exit_Point
End Function

Public Function RecalcSumFieldsOnForm(FormOrReport As Object, rst As ADODB.Recordset)
On Error GoTo Err_Point

 Dim ctl As control
 Dim stControlSource As String
 Dim stFieldName As String
 
  For Each ctl In FormOrReport.Controls
  If ctl.ControlType = acTextBox Then
   If ctl.ControlSource Like "*Sum(*" Then
        stControlSource = ctl.ControlSource
        ctl.tag = stControlSource
        ctl.ControlSource = ""
   End If
   
   stControlSource = ctl.tag
   If stControlSource Like "*Sum(*" Then
    ctl.ControlSource = ""
    stFieldName = Trim(stControlSource)
    stFieldName = Replace(stFieldName, "Sum(", "")
    stFieldName = Left(stFieldName, Len(stFieldName) - 1) 'skidamo poslednju ")" 'stFieldName = Replace(stFieldName, ")", "")
    stFieldName = Replace(stFieldName, "[", "")
    stFieldName = Replace(stFieldName, "]", "")
    stFieldName = Replace(stFieldName, "=", "")
    stFieldName = Trim(stFieldName)
    'ctl = ADO_SumRstField(stFieldName, rst)
    ctl = ADO_Sum(stFieldName, rst)
   End If
  End If
  Next
Exit_Point:
On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, FormOrReport.Name & "::RecalcSumFieldsOnForm"
 Resume Exit_Point
End Function
Public Function SetProperlyRecordSet(CNNString As String, Optional FormOrReport As Object, Optional ODBCQName, Optional ACCQName, Optional NoSet) As String
'**********************
'Kreirano: 07-12-2018
'Modifikovano 06-09-2019
'**********************

On Error GoTo Err_Point

 Dim stRecordSource As String
 Dim OK As Boolean
 Dim SQLText As String
 Dim ErrorCode As Long
 
 Dim pODBCQName As String
 Dim pACCQName As String
 Dim pNoSet As Boolean
 Dim pUniqueTable As String
 'Dim cn As ADODB.Connection
 'Dim rs As ADODB.Recordset

 
 If IsMissing(FormOrReport) Or (FormOrReport Is Nothing) Then
  Set FormOrReport = Screen.ActiveForm
 End If
 
 If IsMissing(ACCQName) Then
     pACCQName = Nz(DLookup("[AccQueryName]", BBQueryDef, "[AccRSFormName]= '" & FormOrReport.Name & "'"), "")
 Else
     pACCQName = ACCQName
 End If ' IsMissing(ACCQName)
 
 If Nz(DLookup("[UseAccQuery]", BBQueryDef, "[AccRSFormName]= '" & FormOrReport.Name & "'"), False) Then
  stRecordSource = pACCQName
  GoTo Exit_Point
 End If
 
 If IsMissing(ODBCQName) Then
     pODBCQName = Nz(DLookup("[QueryName]", BBQueryDef, "[AccRSFormName]= '" & FormOrReport.Name & "'"), "")
 Else
     pODBCQName = ODBCQName
 End If ' IsMissing(ODBCQName)
     
 If IsMissing(NoSet) Then
  pNoSet = Nz(DLookup("[NoSet]", BBQueryDef, "[QueryName]= '" & pODBCQName & "'"), False)
 Else
  pNoSet = Nz(CBool(NoSet), False)
 End If
 
 If pNoSet Then
   Exit Function
 End If
 
 pUniqueTable = Nz(DLookup("[UniqueTable]", BBQueryDef, "[QueryName]= '" & pODBCQName & "'"), "")
 
   If True Then 'BBCFG.SQLDB Then
      'SQLText = PassTroughQueryMakeSQLTextFromTDef(pODBCQName, True, ErrorCode)
      'SQLText = Nz(DLookup("[SQLText]", BBQueryDef, "[AccRSFormName]= '" & FormOrReport.Name & "'"), "")
      If Nz(pODBCQName, "") = "" Then
       BBMsgBox_BigBit "Nije definisan RecordSource za formu/report " & FormOrReport.Name
      Else
       SQLText = PassTroughQueryEvalAllPar(pODBCQName)
       OK = (ErrorCode = 0) 'And PassTroughQuerySave(pODBCQName, SQLText)
       If OK Then
          stRecordSource = pODBCQName
          SetProperlyRecordSet = SQLText
          
          Set FormOrReport.Recordset = ADO_GetRST(F_CNNString("SQL", CNNString), SQLText)
          If pUniqueTable <> "" Then
             FormOrReport.UniqueTable = pUniqueTable
          End If
          RecalcSumFieldsOnForm FormOrReport, FormOrReport.Recordset.Clone
          
          Exit Function
       Else
          stRecordSource = pACCQName
       End If
      End If
   Else
      stRecordSource = pACCQName
   End If
Exit_Point:
 On Error Resume Next
 FormOrReport.RecordSource = stRecordSource
   If err Then
     MsgBox "Error # " & stR(err.Number) & " was generated by " _
            & err.Source & Chr(13) & err.Description, , "QMegaTeh"
 err.Clear
   End If
Exit Function

Err_Point:
 MsgBox "Error # " & stR(err.Number) & " was generated by " _
            & err.Source & Chr(13) & err.Description, , "QMegaTeh"
 err.Clear
 Resume Exit_Point
End Function

Public Sub CloseConnectionOnCurrentForm(ByRef frm As Form)
'Kreirano: 30-09-2019
'Poziva se na event UNLOAD forme
'Modifikovano 12-12-2020 -> dodat uslov Err.Number <> -2147217843 za prikaz poruke o gresci
'                           posle sortiranja ima problem...
'Modifikovano 15-04-2021 -> disconected RST nema otvorenu konekciju a jeste ADODB.Recordset
On Error GoTo Err_Point

If frm.Recordset Is Nothing Then
   Exit Sub
End If
 If TypeOf frm.Recordset Is ADODB.Recordset Then
   'Close the ADO connection we opened
   Dim cn As ADODB.Connection
   Set cn = frm.Recordset.ActiveConnection
    If Not (cn Is Nothing) Then
        cn.Close
        Set cn = Nothing
   End If
 End If
 
Exit_Point:
On Error Resume Next
Exit Sub

Err_Point:
 If err.Number <> -2147217843 Then
    BBErrorMSG err, frm.Name & "::CloseConnectionOnCurrentForm"
 End If
 Resume Exit_Point
End Sub
Public Sub CloseConnectionOnCurrentReport(ByRef RPT As Report)
'Kreirano: 30-09-2019
'Poziva se na event UNLOAD forme
On Error GoTo Err_Point

If RPT.Recordset Is Nothing Then
   Exit Sub
End If
 If TypeOf RPT.Recordset Is ADODB.Recordset Then
   'Close the ADO connection we opened
   Dim cn As ADODB.Connection
   Set cn = RPT.Recordset.ActiveConnection
   cn.Close
   Set cn = Nothing
 End If
 
Exit_Point:
On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, RPT.Name & "::Form_Unload"
 Resume Exit_Point
End Sub

Public Function ExecSPByRefPar(SPName As String, ParamArray Arg()) As Boolean
'Kreirano: 20-03-2020
'Opis: Izvrsava sp preko referenciranih parametara tipa "@Par1=<<vrednost1>>","@Par1=<<vrednost2>>",...
'Modifikovano: 22-04-2020 dodata provera za OUT par
'Modifikovano: 15-12-2020 -> F_CNNString("SQL")
'Modifikovano: 31-01-2021 -> retValOk = (pCMD.ActiveConnection.Errors.Count = 0)
On Error GoTo Err_Point

Dim pCMD As New ADODB.Command

Dim i As Integer, j As Integer

Dim spBrojParametara As Integer
Dim InBrojParametara As Integer
Dim stPoruka As String
Dim CNNString As String
Dim retValOk As Boolean

Dim stParName As String
Dim stInPar As String
Dim stInParName As String
Dim stInParVal As String
Dim intPosJednako As Integer

DoCmd.Hourglass True
pCMD.ActiveConnection = F_CNNString("SQL") 'BBCFG.CNNString
pCMD.CommandType = adCmdStoredProc
pCMD.CommandText = SPName

pCMD.Parameters.Refresh 'posle ove komande svi parametri su definisani!
 'cmd.Parameters(0) = @RETURN_VALUE
 spBrojParametara = pCMD.Parameters.Count() - 1
 InBrojParametara = UBound(Arg()) - LBound(Arg()) + 1
 
 'svim definisanim parametrima prvo dodelimo vrednost DEFAULT tj. Empty
 For i = 1 To spBrojParametara
  pCMD.Parameters(i).Value = Empty
 Next i
 
 For i = 1 To InBrojParametara
       For j = 1 To spBrojParametara
          If pCMD.Parameters(j).Direction = adParamInput Then
            stParName = Trim(pCMD.Parameters(j).Name)
            stInPar = Trim(Arg(i - 1))
            intPosJednako = InStr(stInPar, "=")
            stInParName = Trim(Left(stInPar, intPosJednako - 1))
          
             If stParName = stInParName Then
                stInParVal = Trim(Right(stInPar, Len(stInPar) - intPosJednako))
                
                'Debug.Print pCMD.Parameters(j).Name & "=" & stInParVal
                If stInParVal <> "Null" Then
                  pCMD.Parameters(j).Value = stInParVal
                Else
                  pCMD.Parameters(j).Value = Null
                End If
                
                Exit For ' j
             End If 'stParName = stInParName
          Else 'pCMD.Parameters(j).Direction = adParamInput
             pCMD.Parameters(j).Value = Null 'mora da se nesto dodeli pa makar i null!
          End If 'pCMD.Parameters(j).Direction = adParamInput
       Next j
   
 Next i

pCMD.CommandTimeout = 180 '3 minuta !!

pCMD.Execute

'CmdRetVal = pCmd.Parameters("@RETURN_VALUE")
'CmdRetVal = (pCMD.Parameters(0) = 0)
'31-01-201
retValOk = (pCMD.ActiveConnection.Errors.Count = 0)


Exit_Point:
On Error Resume Next

Set pCMD = Nothing
DoCmd.Hourglass False
ExecSPByRefPar = retValOk
Exit Function

Err_Point:

    BBErrorMSG err, "ExecSPByRefPar(" & SPName & "...)"
    retValOk = False
    Resume Exit_Point

End Function


Public Function ExecSPFromBBQueryDef(BBQueryName As String, Optional CNNString) As Boolean
'Kreirano: 22-03-2020
'Modifikovano 15-12-2020 -> F_CNNString("SQL")
'Modifikovano: 03-11-2021 dodat opcioni parametar CNNString
'Modifikovano: 18-11-2021 -> cita se parametar CommandTimeOut iz BBQueryDef i prosledjuje komandi ADO_ExecSQL
'Modifikovano: 09-01-2022 -> pogresno je prosledjivao parametar CommandTimeOut komandi ADO_ExecSQL
'!!!BBQueryName NE SME DA VRACA RECORDSET!!!
'MORA DA BUDE AKCIONI UPIT

On Error GoTo Err_Point
  Dim retValOk As Boolean
  Dim stSQLQuery As String
  Dim pCNNString As String
  Dim pCommandTimeout As Integer
  
  If IsMissing(CNNString) Then
    'pCNNString = F_CNNString("SQL")
    pCNNString = CNN_CurrentDataBase
  Else
    pCNNString = CStr(CNNString)
  End If
  
  stSQLQuery = PassTroughQueryEvalAllPar(BBQueryName)
  pCommandTimeout = Nz(DLookup("CommandTimeOut", BBQueryDef, "QueryName= '" & BBQueryName & "'"), 30)
  retValOk = ADO_ExecSQL(pCNNString, stSQLQuery, , pCommandTimeout) 'PassTroughExecuteSQL(stSQLQuery)


Exit_Point:
 On Error Resume Next
 ExecSPFromBBQueryDef = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "ExecSPFromBBQueryDef"
 retValOk = False
 Resume Exit_Point
End Function


Public Function PopraviBBQueryDefZaUDF(QueryName As String) As String
'Kreirano: 08-11-2020
On Error GoTo Err_Point
Dim rstQueryDef As DAO.Recordset
Dim rstQueryParDef As DAO.Recordset
Dim stSQL As String

Set rstQueryDef = CurrentDb.OpenRecordset("SELECT * FROM BBQueryDef WHERE QueryName='" & QueryName & "'", dbOpenDynaset)
While Not rstQueryDef.EOF
    stSQL = rstQueryDef!SQLText
    Set rstQueryParDef = CurrentDb.OpenRecordset("SELECT * FROM BBQueryParDef WHERE QUeryName='" & rstQueryDef!QueryName & "'", dbOpenForwardOnly)
    While Not rstQueryParDef.EOF
      'stSQL = Replace(stSQL, rstQueryParDef!AccMapValue, rstQueryParDef!Name)
      stSQL = ReplaceSQLArgWithValue(stSQL, rstQueryParDef!AccMapValue, rstQueryParDef!Name)
      rstQueryParDef.MoveNext
    Wend
    rstQueryParDef.Close
    
 rstQueryDef.MoveNext
Wend

Exit_Point:
 On Error Resume Next
    PopraviBBQueryDefZaUDF = stSQL
 rstQueryDef.Close
 Set rstQueryDef = Nothing
 
 rstQueryParDef.Close
 Set rstQueryParDef = Nothing
Exit Function

Err_Point:
 BBErrorMSG err, "PopraviBBQueryDefZaUDF"
 Resume Exit_Point
End Function
Public Function BBQueryDefPar_GetSQLName(adTypeCode As ADODB.DataTypeEnum) As String
Dim stRetVal As String
    stRetVal = Nz(DLookup("[SQLName]", ODBC_DataTypeEnum, "dbTypeCode=" & adTypeCode), "")
    BBQueryDefPar_GetSQLName = stRetVal
End Function
Public Function BBQuerdefPar_CreateDeclarePart(stQueryName As String, Optional SetNullAsDefault As Boolean = True) As String
 'Kreirano: 12-11-2020
On Error GoTo Err_Point
Dim rstQueryParDef As DAO.Recordset
Dim stRetVal As String

    stRetVal = ""
    
    Set rstQueryParDef = CurrentDb.OpenRecordset("SELECT * FROM " & BBQueryParDef & " WHERE QUeryName='" & stQueryName & "' ORDER BY RBr", dbOpenForwardOnly)
    While Not rstQueryParDef.EOF
      stRetVal = stRetVal & "DECLARE " & rstQueryParDef!Name & " " & BBQueryDefPar_GetSQLName(rstQueryParDef!Type)
      If SetNullAsDefault Then
         stRetVal = stRetVal & " = null" & vbCrLf
      Else
         stRetVal = stRetVal & vbCrLf
      End If
      rstQueryParDef.MoveNext
    Wend
    If Len(stRetVal) > 0 Then
        stRetVal = stRetVal & ";"
    End If
    rstQueryParDef.Close
    

Exit_Point:
 On Error Resume Next
    BBQuerdefPar_CreateDeclarePart = stRetVal
    
    rstQueryParDef.Close
    Set rstQueryParDef = Nothing
 
Exit Function

Err_Point:
 BBErrorMSG err, "BBQuerdefPar_CreateDeclarePart"
 Resume Exit_Point

End Function
