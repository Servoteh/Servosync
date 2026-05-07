Attribute VB_Name = "ADO_Module"
Option Compare Database
Option Explicit

Public ADO_IDENTITY As Variant
Public ADO_ROWCOUNT As Long
Public ADO_ROWCOUNT_WITH_ERROR As Long
Public ADO_EXECUTE_DURATION As Single '  Uveden 18-11-2021

Public Function ADO_TestConnection(ByVal CNNString, ConnectionTimeout) As Boolean
On Error GoTo Err_Point
    
Dim retValOk As Boolean
Dim cnn As New ADODB.Connection
    
    cnn.ConnectionString = CNNString
    cnn.ConnectionTimeout = ConnectionTimeout 'Potroši što manje vremena
    
    cnn.Open
    If cnn.State = adStateOpen Then
     retValOk = True
    Else
     retValOk = False
    End If
 err.Clear

Exit_Point:
' On Error Resume Next
   If cnn.State = adStateOpen Then
    cnn.Close
   End If
    Set cnn = Nothing
    ADO_TestConnection = retValOk
Exit Function

Err_Point:
 err.Clear
 retValOk = False
 Resume Exit_Point
End Function
Public Function F_CNNString(Optional TypeCNN As String = "ODBC", Optional CNNString) As String
On Error GoTo Err_Point
Dim retVal As String

    If IsMissing(CNNString) Then
     retVal = LIB_CFGRW.CNN_CurrentDataBase
    Else
     retVal = CNNString
    End If

    If TypeCNN = "ODBC" Then
       retVal = Replace(retVal, "ODBC;", "")
       retVal = "ODBC;" & retVal
    ElseIf TypeCNN = "SQL" Then
       retVal = Replace(retVal, "ODBC;", "")
    Else
       retVal = retVal
      'BBMsgBox "Nepoznat tip traženog CNNString-a"
    End If
Exit_Point:
 On Error Resume Next
 F_CNNString = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "F_CNNString(" & TypeCNN & "...)"
End Function

Public Function ADO_ExecSP(CNNString As String, SPName As String, ParamArray Arg()) As Boolean
'Kreirano: 22-10-2020
'Modifikovano: 31-01-2021 -> retValOk = (pCMD.ActiveConnection.Errors.Count = 0)
'Modifikovano: 04-04-2023 => provera da li ima greske i kada he pCMD.ActiveConnection.Errors.Count > 0
On Error GoTo Err_Point

Dim pCMD As New ADODB.Command

Dim i As Integer
Dim spBrojParametara As Integer
Dim InBrojParametara As Integer
Dim stPoruka As String
Dim retValOk As Boolean

DoCmd.Hourglass True
pCMD.ActiveConnection = CNNString
pCMD.CommandType = adCmdStoredProc
pCMD.CommandText = SPName

pCMD.Parameters.Refresh 'posle ove komande svi parametri su definisani!
 'cmd.Parameters(0) = @RETURN_VALUE
 spBrojParametara = pCMD.Parameters.Count() - 1
 InBrojParametara = UBound(Arg()) - LBound(Arg()) + 1
 If InBrojParametara <> spBrojParametara Then
  DoCmd.Hourglass False
  
  stPoruka = "Neuskladjeni parametri za " & SPName
  stPoruka = stPoruka & vbCrLf & "potrebno " & CStr(spBrojParametara) & ", prosledjeno " & CStr(InBrojParametara)
  stPoruka = stPoruka & vbCrLf & vbCrLf & "Parametri koji nedostaju:" & vbCrLf
  For i = InBrojParametara + 1 To spBrojParametara
       stPoruka = stPoruka & pCMD.Parameters(i).Name & vbCrLf
   Next i
  stPoruka = stPoruka & vbCrLf & "Da li želite da za njih prosledim 'DEFAULT'?"
  stPoruka = stPoruka & vbCrLf & "(ako odgovorite sa No proces se prekida)"
  If BBPitanje(stPoruka) Then
   For i = InBrojParametara + 1 To spBrojParametara
       pCMD.Parameters(i).Value = Empty
   Next i
  Else
   retValOk = False
   GoTo Exit_Point
  End If
 End If

 For i = 1 To InBrojParametara
 ' problem sa datumom!
  pCMD.Parameters(i).Value = Arg(i - 1)
Next i

pCMD.CommandTimeout = 180 '10 '180 '3 minuta !!

pCMD.Execute

'provera da li je bilo gresaka zbog kojih komanda nije izvršena
    retValOk = True
    For i = 0 To pCMD.ActiveConnection.Errors.Count - 1
        retValOk = (retValOk And Left(CStr(pCMD.ActiveConnection.Errors.Item(i).SQLState), 1) = "0")
    Next i

Exit_Point:
On Error Resume Next

Set pCMD = Nothing
DoCmd.Hourglass False
ADO_ExecSP = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "ADO_ExecSP(" & SPName & "...)"
    retValOk = False
    Resume Exit_Point

End Function
'***********************************************************************************
'Ceo modul prepakovan i preradjen pocev od 07-10-2020
'***********************************************************************************
Public Function ADO_GetRST(ByVal CNNString As String, ByVal SQLText As String, _
                                             Optional ByVal pLockType As LockTypeEnum = adLockOptimistic, _
                                             Optional ByVal pCursorLocation As CursorLocationEnum = adUseClient, _
                                             Optional ByVal pCursorType As CursorTypeEnum = adOpenKeyset, _
                                             Optional ByVal OnErrShowDetails As Boolean = True, _
                                             Optional ByVal CommandTimeout As Integer = 180, _
                                             Optional ByVal pSort As String = "" _
                          ) As ADODB.Recordset
                          
'**********************
'Kreirano: 23-10-2018
'Modifikovano: 30-11-2020 dodat parametar Optional CommandTimeout As Integer = 180
'Modifikovano: 31-10-2022 dodat parametar Optional pSort As String = ""
'**********************
On Error GoTo Err_Point

 Dim cn As ADODB.Connection
 Dim rs As ADODB.Recordset
 
    Set cn = New ADODB.Connection
                              
    '**********************
    'Modifikovano: 09-11-2025 - Kako ADO "zna" šta da koristi
    'If Left(CNNString, 7) = "DRIVER=" Then
    '    cn.ConnectionString = "Provider=MSDASQL;" & CNNString
    'Else
    '    cn.ConnectionString = CNNString
    'End If

    cn.ConnectionString = CNNString
    
    cn.CommandTimeout = CommandTimeout
    cn.Open
    
    Set rs = New ADODB.Recordset
 
 With rs
 Set .ActiveConnection = cn
     .Source = SQLText
     .LockType = pLockType 'adLockOptimistic
     .CursorLocation = pCursorLocation 'adUseClient
     .CursorType = pCursorType 'adOpenKeyset
     
     If pSort <> "" Then
     .Sort = pSort
     End If

    .Open
 End With
  
Exit_Point:

On Error Resume Next
 Set ADO_GetRST = rs
 Set rs = Nothing
 Set cn = Nothing
Exit Function

Err_Point:
    If OnErrShowDetails Then
        BBErrorMSG err, "ADO_GetRST"
        SetClipboard err
    End If
    Resume Exit_Point

End Function

Public Function ADO_Lookup(ByVal CNNString As String, ByVal Expr As String, ByVal Domain As String, Optional Criteria) As Variant
'Modifikovano: 16-01-2021
On Error GoTo Err_Point

Dim rst As ADODB.Recordset
Dim retVal As Variant
Dim stSQL As String
Dim stKolonaVrednost

retVal = Null
If Trim(Domain) Like "SELECT*" Then
    stSQL = "SELECT " & Expr & " as Vrednost FROM (" & Trim(Domain) & ") as qtmp"
    stKolonaVrednost = "vrednost"
Else
    stSQL = "SELECT " & Expr & " as Vrednost FROM " & ADO_PopraviNazivTabeleIliKolone(Trim(Domain))
    stKolonaVrednost = "vrednost"
End If

If stSQL Like "*WHERE*" Then
   
ElseIf Not IsMissing(Criteria) Then
   stSQL = stSQL & " WHERE " & Criteria
End If

Set rst = ADO_GetRST(CNNString, stSQL, , , adOpenStatic)
'rst.Filter = Criteria

If Not rst.EOF Then
    retVal = rst(stKolonaVrednost).Value
Else
   retVal = Null
End If

Exit_Point:
 On Error Resume Next
 
 ADO_Lookup = retVal
 rst.Close
 Set rst = Nothing
 
Exit Function

Err_Point:
 BBErrorMSG err, "ADO_Lookup"
 retVal = Null
 Resume Exit_Point
End Function
Public Function ADO_ExecSQL(ByVal CNNString As String, ByVal stSQLText As String, Optional ByVal OnErrShowDetails As Boolean = True, Optional ByVal pCommandTimeout As Integer = 30) As Boolean
'Kreirano: 23-10-2020
'Modifikovano: 18-11-2021 => uveden parametar Optional pCommandTimeout As Integer = 30
'Modifikovano: 04-04-2023 => provera da li je bilo gresaka zbog kojih komanda nije izvršena sada i kada je count > 0
'Modifikovano: 11-09-2025 => Upisujem u tablici SQL_Log kako je prošlo izvršavanje funkcije
On Error GoTo Err_Point

Dim pCMD As New ADODB.Command
'Dim stPoruka As String
Dim retValOk As Long
Dim i As Integer

''Upisujem u tablici SQL_Log kako je prošlo izvršavanje funkcije
'Dim t0 As Double, t1 As Double
't0 = Timer
    
 ADO_EXECUTE_DURATION = Timer

DoCmd.Hourglass True
pCMD.ActiveConnection = CNNString
pCMD.CommandType = adCmdText
pCMD.CommandText = stSQLText

pCMD.CommandTimeout = pCommandTimeout
pCMD.Execute

'Upisujem u tablici SQL_Log kako je prošlo izvršavanje funkcije
    
'provera da li je bilo gresaka zbog kojih komanda nije izvršena
    retValOk = True
    For i = 0 To pCMD.ActiveConnection.Errors.Count - 1
        retValOk = (retValOk And Left(CStr(pCMD.ActiveConnection.Errors.Item(i).SQLState), 1) = "0")
    Next i


Exit_Point:
On Error Resume Next

    ADO_IDENTITY = pCMD.ActiveConnection.Execute("SELECT @@IDENTITY as v")!v
    ADO_ROWCOUNT = pCMD.ActiveConnection.Execute("SELECT @@ROWCOUNT as v")!v
    ADO_ROWCOUNT_WITH_ERROR = 0
    
    ADO_EXECUTE_DURATION = Timer - ADO_EXECUTE_DURATION

    pCMD.ActiveConnection.Close
    Set pCMD = Nothing
    DoCmd.Hourglass False
    
    ''Upisujem u tablici SQL_Log kako je prošlo izvršavanje funkcije
    't1 = Timer
    'If retValOk Then
    '    Call LogSQL(stSQLText, Round(t1 - t0, 2), "OK")
    'Else
    '    Call LogSQL(stSQLText, Round(t1 - t0, 2), "Failed", err.Description)
    'End If
    
    ADO_ExecSQL = retValOk
Exit Function

Err_Point:
    If OnErrShowDetails Then
       ADO_EXECUTE_DURATION = Timer - ADO_EXECUTE_DURATION
       BBErrorMSG err, "Trajanje=" & stR(ADO_EXECUTE_DURATION) & " sec." & vbCrLf & "ADO_ExecSQL(" & CNNString & "," & stSQLText & "," & OnErrShowDetails & ")"
    End If
    retValOk = False
    Resume Exit_Point

End Function

Public Function ADO_PostojiTabelaUBazi(ByVal stCNNString As String, ByVal stTableName As String) As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stSQL As String

If GetParFromCnnString("DRIVER=", stCNNString) Like "*SQL*" Then
    
    stSQL = "SELECT so.name FROM sys.all_objects as so"
    stSQL = stSQL & " WHERE so.type = 'U' AND so.name = '" & stTableName & "'"
    retValOk = (ADO_GetRST(stCNNString, stSQL).RecordCount > 0)
    
Else 'verovatno gadja access bazu
    'stSQL = "SELECT so.name FROM MSysObjects as so"
    'stSQL = stSQL & " WHERE so.type = 1 AND so.name = '" & stTableName & "'"
    'retValOk = (GetADORst(stSQL, stCNNString, dbReadOnly, adUseClient, adOpenStatic).RecordCount > 0)
    'retValOk = (GetADORst(stSQL, stCNNString, adLockOptimistic).RecordCount > 0)
    'retValOk = (GetADORst(stSQL, stCNNString).RecordCount > 0)
    stSQL = "SELECT 0 as Nista FROM " & ADO_PopraviNazivTabeleIliKolone(stTableName) & " WHERE 0=1"
    On Error Resume Next
        retValOk = (ADO_GetRST(stCNNString, stSQL, , , adOpenStatic, False).Fields.Count > 0)
        retValOk = (retValOk And (err.Number = 0))
    On Error GoTo Err_Point
    
End If



Exit_Point:
 On Error Resume Next
 ADO_PostojiTabelaUBazi = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "ADO_PostojiTabelaUBazi"
 retValOk = False
 Resume Exit_Point
End Function
Private Function ADO_PopraviNazivTabeleIliKolone(ByVal Name As String) As String
Dim stRetVal As String
stRetVal = Trim(Name)

 If (Left(stRetVal, 1) <> "[") Then stRetVal = "[" & stRetVal
 If (Right(stRetVal, 1) <> "]") Then stRetVal = stRetVal & "]"
 ADO_PopraviNazivTabeleIliKolone = stRetVal
 
End Function
Public Function ADO_CreateTable(CNNString As String, TableName As String, FirstColumn As String) As Boolean
Dim retValOk As Boolean
Dim stSQL As String
 
 stSQL = "CREATE TABLE " & ADO_PopraviNazivTabeleIliKolone(TableName) & " (" & FirstColumn & ")"
 retValOk = ADO_ExecSQL(CNNString, stSQL)
 ADO_CreateTable = retValOk
 
End Function
Public Function ADO_AddTableColumn(CNNString As String, TableName As String, NewColumn As String) As Boolean
Dim retValOk As Boolean
Dim stSQL As String
 stSQL = "ALTER TABLE " & ADO_PopraviNazivTabeleIliKolone(TableName) & " ADD COLUMN " & ADO_PopraviNazivTabeleIliKolone(NewColumn)
 retValOk = ADO_ExecSQL(CNNString, stSQL)
 ADO_AddTableColumn = retValOk
End Function

Public Function ADO_PostojiKolonaUTabeli(CNNString As String, TableName As String, FieldName As String) As Boolean
'Modifikovano: 06-12-2020
On Error GoTo Err_Point
 Dim retVal As Boolean
 Dim stSQL As String
 Dim rs As New ADODB.Recordset
 
 stSQL = "SELECT " & ADO_PopraviNazivTabeleIliKolone(FieldName) & " as Kolona FROM " & ADO_PopraviNazivTabeleIliKolone(TableName) & " WHERE 1=0;"
 Set rs = ADO_GetRST(CNNString, stSQL, , , , False)
 If rs.State = adStateOpen Then
    retVal = (rs("Kolona").Name = "Kolona")
 Else
    retVal = False
 End If
Exit_Point:
On Error Resume Next
 rs.Close
 Set rs = Nothing
 ADO_PostojiKolonaUTabeli = retVal

Exit Function

Err_Point:
 BBErrorMSG err, "ADO_PostojiKolonaUTabeli"
 retVal = False
 Resume Exit_Point
End Function
Public Function ADO_IsIdentity(CNNString As String, TableName As String) As Boolean
 Dim retVal As Boolean
 Dim stSQL As String
 
 stSQL = ""
 
 If IsAccessCNNString(CNNString) Then
 '*************************************
 'TREBA REŠITI
    retVal = False
 '*************************************
 Else
    stSQL = stSQL & "SELECT COUNT(*) as Result"
    stSQL = stSQL & " FROM"
    stSQL = stSQL & "    ("
    stSQL = stSQL & "       SELECT  is_identity as jeste"
    stSQL = stSQL & "       FROM Sys.Columns"
    stSQL = stSQL & "       WHERE   sys.columns.object_id = object_id('" & TableName & "')"
    stSQL = stSQL & "               AND is_identity = 1"
    stSQL = stSQL & "     ) as IdentityKolone"
    retVal = ADO_GetRST(CNNString, stSQL)!result >= 1
 End If
 
Exit_Point:
 On Error Resume Next
 ADO_IsIdentity = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "ADO_IsIdentity"
 retVal = False
 Resume Exit_Point
End Function
Public Function IsAccessCNNString(ByVal CNNString As String) As Boolean
Dim retVal As Boolean
  
  retVal = GetParFromCnnString("PROVIDER=", CNNString) Like "*JET*"
   
 IsAccessCNNString = retVal
End Function
Public Function ADO_DBTypeTostring(t As ADODB.DataTypeEnum, Precision As Variant) As String
  Dim stRetVal As String
  
  Select Case t
  Case ADODB.DataTypeEnum.adBoolean: stRetVal = "Bit"
  Case ADODB.DataTypeEnum.adVarWChar
       stRetVal = "STRING(" & Precision & ")"
  Case ADODB.DataTypeEnum.adInteger: stRetVal = "Int"
  Case Else
       stRetVal = "STRING"
  End Select
  ADO_DBTypeTostring = stRetVal
End Function
Public Function ADO_FieldDefToString(ADO_Field As ADODB.Field) As String
Dim stRetVal As String

  stRetVal = "[" & ADO_Field.Name & "] " & ADO_DBTypeTostring(ADO_Field.Type, ADO_Field.Precision)
  
  ADO_FieldDefToString = stRetVal
  
End Function
Public Function ADO_KreirajTabeluPoModeluRecordseta(CNNString As String, TableName As String, ADO_rst_Fields As ADODB.Fields) As Boolean
'? ADO_KreirajTabeluPoModeluRecordseta(CNN_SHUTTLE,"Test99",GetADORst("SELECT * FROM PRODAVCI",CNN_MasterDB).Fields)
'Kreirano: 23-10-2020
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stNewColumn As String
Dim BrojDodatihKolona As Integer
Dim i As Integer
    
    If Not ADO_PostojiTabelaUBazi(CNNString, TableName) Then
        retValOk = ADO_CreateTable(CNNString, TableName, ADO_FieldDefToString(ADO_rst_Fields(0)))
    Else
       retValOk = True
    End If

    If retValOk Then
        For i = 1 To ADO_rst_Fields.Count - 1
          If Not ADO_PostojiKolonaUTabeli(CNNString, TableName, ADO_rst_Fields(i).Name) Then
            retValOk = retValOk And ADO_AddTableColumn(CNNString, TableName, ADO_FieldDefToString(ADO_rst_Fields(i)))
            BrojDodatihKolona = BrojDodatihKolona + 1
          End If
         Next i
    End If

Exit_Point:
 On Error Resume Next
 ADO_KreirajTabeluPoModeluRecordseta = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "ADO_KreirajTabeluPoModeluRecordseta"
 retValOk = False
 Resume Exit_Point
End Function
Public Function ADO_ExportTable(CNNString_FROM As String, TableOrSelectSQL_FROM As String, CNNString_TO As String, TableName_TO As String, Optional ByVal SQLWHERE = "", Optional CreateTable As Boolean = False, Optional OnErrorShowMsg As Boolean = True) As Boolean
' ? ADO_ExportTable(CFGRW.CNN_MasterDB,"Prodavci",CFGRW.CNN_SHUTTLE,"Prodavci",,True)
'***********************************************************
'KREIRANO 21-10-2019
'Modifikovano: 22-12-2019
'Modifikovano: 12-08-2021
'***********************************************************
 On Error GoTo Err_Point
 Dim retValOk As Boolean


 Dim rst_FROM As ADODB.Recordset
 Dim pCNN_TO As New ADODB.Connection
 Dim stSQL_FROM As String
 
 
 Dim CmdRetVal As Long
 Dim stSQLText As String
 Dim stSQLTextValues As String
 Dim Ispravno As Long
 Dim NEIspravno As Long
 Dim i As Integer
 Dim PorukeOGreskama As Boolean
 Dim VrednostKolone
 Dim KolonaZaExport() As String
 Dim TipKoloneZaExport() As DataTypeEnum
 Dim SizeKoloneZaExport() As Integer
 Dim BrojKolonaZaExport As Integer
 
 retValOk = True
 
 If Left(TableOrSelectSQL_FROM, 6) = "SELECT" Then
    stSQL_FROM = TableOrSelectSQL_FROM
 Else
    stSQL_FROM = "SELECT * FROM " & ADO_PopraviNazivTabeleIliKolone(TableOrSelectSQL_FROM)
 End If
  
 If SQLWHERE <> "" Then
   stSQL_FROM = stSQL_FROM & " WHERE " & SQLWHERE
 End If
 
 Set rst_FROM = ADO_GetRST(CNNString_FROM, stSQL_FROM, , adUseClient, adOpenStatic)
 
 If CreateTable Then
    If Not ADO_PostojiTabelaUBazi(CNNString_TO, TableName_TO) Then
       retValOk = ADO_KreirajTabeluPoModeluRecordseta(CNNString_TO, TableName_TO, rst_FROM.Fields)
    End If
 End If
  
 BrojKolonaZaExport = 0
 For i = 0 To rst_FROM.Fields.Count - 1
  If ADO_PostojiKolonaUTabeli(CNNString_TO, TableName_TO, rst_FROM.Fields(i).Name) Then
    ReDim Preserve KolonaZaExport(BrojKolonaZaExport)
    ReDim Preserve SizeKoloneZaExport(BrojKolonaZaExport)
    ReDim Preserve TipKoloneZaExport(BrojKolonaZaExport)
    KolonaZaExport(BrojKolonaZaExport) = rst_FROM.Fields(i).Name
    SizeKoloneZaExport(BrojKolonaZaExport) = rst_FROM.Fields(i).Precision 'CurrentDb.TableDefs(TableName_TO).Fields(rst_FROM.Fields(i).Name).Size
    TipKoloneZaExport(BrojKolonaZaExport) = rst_FROM.Fields(i).Type 'CurrentDb.TableDefs(TableName_TO).Fields(rst_FROM.Fields(i).Name).Type
    BrojKolonaZaExport = BrojKolonaZaExport + 1
  End If
 Next i
 
 pCNN_TO.Open CNNString_TO
 
If Not IsAccessCNNString(pCNN_TO) Then
 If ADO_IsIdentity(CNNString_TO, TableName_TO) Then
    stSQLText = "SET IDENTITY_INSERT " & ADO_PopraviNazivTabeleIliKolone(TableName_TO) & " ON"
    pCNN_TO.Execute stSQLText
 End If
End If

 Ispravno = 0
 NEIspravno = 0
 'PorukeOGreskama = True
 PorukeOGreskama = OnErrorShowMsg
 
 While Not rst_FROM.EOF
        stSQLText = "INSERT INTO [" & TableName_TO & "]"
        stSQLText = stSQLText & " (" & "[" & KolonaZaExport(0) & "]"
        'stSQLTextValues = " VALUES ('" & Replace(rst_FROM.Fields(KolonaZaExport(0)), "'", " ") & "'"
        stSQLTextValues = " SELECT '" & Replace(rst_FROM.Fields(KolonaZaExport(0)), "'", " ") & "'"
        
        For i = 1 To BrojKolonaZaExport - 1

                stSQLText = stSQLText & ", " & "[" & KolonaZaExport(i) & "]"
                VrednostKolone = rst_FROM.Fields(KolonaZaExport(i))
                
                If Not IsNull(VrednostKolone) Then
                  VrednostKolone = Replace(rst_FROM.Fields(KolonaZaExport(i)), "'", " ")
                End If
                
                 If TipKoloneZaExport(i) = ADODB.adVarWChar Then
                    VrednostKolone = "'" & Left(VrednostKolone, SizeKoloneZaExport(i)) & "'"
                 ElseIf (TipKoloneZaExport(i) = ADODB.adDBDate) Or (TipKoloneZaExport(i) = ADODB.adDBTimeStamp) Then    '12-08-2021
                    VrednostKolone = SQLFormatDatumIVreme(VrednostKolone, True)
                 ElseIf TipKoloneZaExport(i) = ADODB.adBoolean Then
                    VrednostKolone = SQLFormatBoolean(VrednostKolone)
                 Else
                   VrednostKolone = "'" & VrednostKolone & "'"
                 End If
                
                '*****************************************
                '12-08-2021
                If IsNull(VrednostKolone) Then
                    VrednostKolone = "''"
                End If
                '*****************************************
                stSQLTextValues = stSQLTextValues & ", " & VrednostKolone
           
        Next i
        stSQLText = stSQLText & ")"
        stSQLTextValues = stSQLTextValues ' & ")"
        
        stSQLText = stSQLText & stSQLTextValues
        'Debug.Print stSQLText
        
        On Error Resume Next
        pCNN_TO.Execute stSQLText
        If err.Number <> 0 Then
           NEIspravno = NEIspravno + 1
           If PorukeOGreskama Then
            BBErrorMSG err
            PorukeOGreskama = BBPitanje("Da li da prikazujem poruke o greškama?")
           End If
           
        Else
           Ispravno = Ispravno + 1
        End If
        err.Clear
        On Error GoTo Err_Point
        'Debug.Print "Ispravno: " & Ispravno, "NEIspravno: " & NEIspravno
        rst_FROM.MoveNext
 Wend
 
Exit_Point:
On Error Resume Next

If Not IsAccessCNNString(pCNN_TO) Then
 If ADO_IsIdentity(CNNString_TO, TableName_TO) Then
    pCNN_TO.Execute "SET IDENTITY_INSERT " & ADO_PopraviNazivTabeleIliKolone(TableName_TO) & " OFF"
 End If
End If

 pCNN_TO.Close
 rst_FROM.Close
 Set rst_FROM = Nothing
 
 ADO_ExportTable = retValOk
 ADO_ROWCOUNT = Ispravno
 ADO_ROWCOUNT_WITH_ERROR = NEIspravno
 'MsgBox "EXPORT:" & vbCrLf & "Uspešno = " & Ispravno & vbCrLf & "NEUspešno = " & NEIspravno, vbInformation, "QBigBit"
Exit Function

Err_Point:
    retValOk = False
    MsgBox err.Description
    Resume Exit_Point
End Function
Public Function ADO_SledeciAutoID(ByVal CNNString As String, ByVal stImeTabele As String, ByVal stID As String, Optional intKorak As Long = 1) As Long
On Error GoTo Err_Point
Dim lintRetVal As Long
Dim stSQL As String
  
  'If Left(stImeTabele, 1) <> "[" Then
  '   stImeTabele = "[" & stImeTabele & "]"
  'End If
  
  'If Left(stID, 1) <> "[" Then
  '   stID = "[" & stID & "]"
  'End If
  
  stSQL = "SELECT Max(" & stID & ") as MaxID FROM " & stImeTabele
  
  
  lintRetVal = Nz(ADO_Lookup(CNNString, "MaxID", stSQL), 0) + intKorak
  
Exit_Point:
  On Error Resume Next
  ADO_SledeciAutoID = lintRetVal
Exit Function

Err_Point:
    BBErrorMSG err, "ADO_SledeciAutoID"
    lintRetVal = 0
    Resume Exit_Point
End Function
Public Function ADO_SQLFormatZaVal(val As Variant, Tip As Variant, Optional Size As Integer = 0) As Variant
'Modifikovano: 15-08-2021
Dim retVal

    retVal = val
    
    If Not IsNull(retVal) Then
      retVal = Replace(retVal, "'", " ")
    End If
    
     If Tip = ADODB.adVarWChar Then
        If Size > 0 Then
           retVal = "'" & Left(retVal, Size) & "'"
        Else
           retVal = "'" & retVal & "'"
        End If
     ElseIf Tip = ADODB.adDBDate Then
        retVal = SQLFormatDatumIVreme(retVal, True)
     ElseIf Tip = ADODB.adDate Then
        retVal = SQLFormatDatumIVreme(retVal, True)
     ElseIf Tip = ADODB.adDBTimeStamp Then    '12-08-2021
        retVal = SQLFormatDatumIVreme(retVal, True)
     ElseIf Tip = ADODB.adBoolean Then
        retVal = SQLFormatBoolean(retVal)
     ElseIf Tip = ADODB.adInteger Or Tip = ADODB.adDecimal Or Tip = ADODB.adDouble Or Tip = ADODB.adTinyInt Or Tip = ADODB.adSmallInt Then
        'Ne pipaj nista
     Else
       retVal = "'" & retVal & "'"
     End If
   ADO_SQLFormatZaVal = retVal
End Function
Public Function ADO_UpdateTable(CNNString_FROM As String, TableOrSelectSQL_FROM As String, CNNString_TO As String, TableName_TO As String, _
                                ByVal PK_FieldName1 As String, Optional ByVal PK_FieldName2 As String = "", Optional ByVal PK_FieldName3 As String = "", _
                                Optional OnErrorShowMsg As Boolean = True) As Boolean
'? ADO_UpdateTable(CNN_SHUTTLE, "NOVO_R_Grupa", CNN_SHUTTLE, "R_Grupa" ,"ID")
'***********************************************************
'KREIRANO 26-10-2019
'Modifikovano: 22-12-2019
'Modifikovano: 15-08-2021
'***********************************************************
 On Error GoTo Err_Point
 Dim retValOk As Boolean


 Dim rst_FROM As ADODB.Recordset
 Dim pCNN_TO As New ADODB.Connection
 Dim stSQL_FROM As String
 
 
 Dim CmdRetVal As Long
 Dim stSQLText As String
 Dim stSQLTextValues As String
 Dim Ispravno As Long
 Dim NEIspravno As Long
 Dim i As Integer
 Dim PorukeOGreskama As Boolean
 Dim VrednostKolone
 Dim KolonaZaExport() As String
 Dim TipKoloneZaExport() As DataTypeEnum
 Dim SizeKoloneZaExport() As Integer
 Dim BrojKolonaZaExport As Integer
 
 retValOk = True
 
 If Left(TableOrSelectSQL_FROM, 6) = "SELECT" Then
    stSQL_FROM = TableOrSelectSQL_FROM
 Else
    stSQL_FROM = "SELECT * FROM " & ADO_PopraviNazivTabeleIliKolone(TableOrSelectSQL_FROM)
 End If

 Set rst_FROM = ADO_GetRST(CNNString_FROM, stSQL_FROM, , adUseClient, adOpenStatic)
   
 BrojKolonaZaExport = 0
 For i = 0 To rst_FROM.Fields.Count - 1
  If ADO_PostojiKolonaUTabeli(CNNString_TO, TableName_TO, rst_FROM.Fields(i).Name) Then
    ReDim Preserve KolonaZaExport(BrojKolonaZaExport)
    ReDim Preserve SizeKoloneZaExport(BrojKolonaZaExport)
    ReDim Preserve TipKoloneZaExport(BrojKolonaZaExport)
    KolonaZaExport(BrojKolonaZaExport) = rst_FROM.Fields(i).Name
    SizeKoloneZaExport(BrojKolonaZaExport) = rst_FROM.Fields(i).Precision 'CurrentDb.TableDefs(TableName_TO).Fields(rst_FROM.Fields(i).Name).Size
    TipKoloneZaExport(BrojKolonaZaExport) = rst_FROM.Fields(i).Type 'CurrentDb.TableDefs(TableName_TO).Fields(rst_FROM.Fields(i).Name).Type
    BrojKolonaZaExport = BrojKolonaZaExport + 1
  End If
 Next i
 
 pCNN_TO.Open CNNString_TO
 
If Not IsAccessCNNString(pCNN_TO) Then
 If ADO_IsIdentity(CNNString_TO, TableName_TO) Then
    stSQLText = "SET IDENTITY_INSERT " & ADO_PopraviNazivTabeleIliKolone(TableName_TO) & " ON"
    pCNN_TO.Execute stSQLText
 End If
End If

 Ispravno = 0
 NEIspravno = 0
 'PorukeOGreskama = True
 PorukeOGreskama = OnErrorShowMsg
 
 While Not rst_FROM.EOF
        stSQLText = "UPDATE [" & TableName_TO & "] SET "
        stSQLTextValues = ""
        For i = 0 To BrojKolonaZaExport - 1
            If (KolonaZaExport(i) <> PK_FieldName1) _
                And (KolonaZaExport(i) <> PK_FieldName2) _
                And (KolonaZaExport(i) <> PK_FieldName3) Then
                
                VrednostKolone = rst_FROM.Fields(KolonaZaExport(i))
                VrednostKolone = ADO_SQLFormatZaVal(VrednostKolone, rst_FROM.Fields(KolonaZaExport(i)).Type, rst_FROM.Fields(KolonaZaExport(i)).Precision)
                
                '*****************************************
                '15-08-2021
                If IsNull(VrednostKolone) Then
                    VrednostKolone = "''"
                End If
                '*****************************************
                
                If stSQLTextValues <> "" Then
                   stSQLTextValues = stSQLTextValues & ", "
                End If
                
                stSQLTextValues = stSQLTextValues & "[" & KolonaZaExport(i) & "]="
                stSQLTextValues = stSQLTextValues & VrednostKolone
            End If
        Next i
        
        stSQLText = stSQLText & stSQLTextValues
        VrednostKolone = ADO_SQLFormatZaVal(rst_FROM.Fields(PK_FieldName1), rst_FROM.Fields(PK_FieldName1).Type, rst_FROM.Fields(PK_FieldName1).Precision)
        stSQLText = stSQLText & " WHERE ([" & PK_FieldName1 & "]=" & VrednostKolone & ")"
        If PK_FieldName2 <> "" Then
            VrednostKolone = ADO_SQLFormatZaVal(rst_FROM.Fields(PK_FieldName2), rst_FROM.Fields(PK_FieldName2).Type, rst_FROM.Fields(PK_FieldName2).Precision)
            stSQLText = stSQLText & " AND ([" & PK_FieldName2 & "]=" & VrednostKolone & ")"
        End If
        If PK_FieldName3 <> "" Then
            VrednostKolone = ADO_SQLFormatZaVal(rst_FROM.Fields(PK_FieldName3), rst_FROM.Fields(PK_FieldName3).Type, rst_FROM.Fields(PK_FieldName3).Precision)
            stSQLText = stSQLText & " AND ([" & PK_FieldName3 & "]=" & VrednostKolone & ")"
        End If
        '*****************************************************************
        'OVDE SE RADI UPDATE
        On Error Resume Next
        pCNN_TO.Execute stSQLText
        'MsgBox stSQLText
        '*****************************************************************
        If err.Number <> 0 Then
           NEIspravno = NEIspravno + 1
           If PorukeOGreskama Then
            BBErrorMSG err
            PorukeOGreskama = BBPitanje("Da li da prikazujem poruke o greškama?")
           End If
           
        Else
           Ispravno = Ispravno + 1
        End If
        err.Clear
        On Error GoTo Err_Point
        'Debug.Print "Ispravno: " & Ispravno, "NEIspravno: " & NEIspravno
        rst_FROM.MoveNext
 Wend
 
Exit_Point:
On Error Resume Next

If Not IsAccessCNNString(pCNN_TO) Then
 If ADO_IsIdentity(CNNString_TO, TableName_TO) Then
    pCNN_TO.Execute "SET IDENTITY_INSERT " & ADO_PopraviNazivTabeleIliKolone(TableName_TO) & " OFF"
 End If
End If

 pCNN_TO.Close
 rst_FROM.Close
 Set rst_FROM = Nothing
 
 ADO_UpdateTable = retValOk
 ADO_ROWCOUNT = Ispravno
 ADO_ROWCOUNT_WITH_ERROR = NEIspravno
 'MsgBox "EXPORT:" & vbCrLf & "Uspešno = " & Ispravno & vbCrLf & "NEUspešno = " & NEIspravno, vbInformation, "QBigTeh"
Exit Function

Err_Point:
    retValOk = False
    MsgBox err.Description
    Resume Exit_Point
End Function
Public Function ADO_SumRstField(ByVal fldName As String, rst As ADODB.Recordset) As Variant
'**********************
'Kreirano: 31-10-2020
'**********************
On Error GoTo Err_Point

  Dim sumVal As Double
  Dim retValErrNumber As Long
  
  retValErrNumber = 0
  sumVal = 0
    
  'If rst Is Nothing Then
  '  Set rst = Screen.ActiveForm.Recordset.Clone
  'End If
   
  If rst Is Nothing Then
    GoTo Exit_Point
  End If
  
  If rst.RecordCount > 0 Then rst.MoveFirst
  While Not rst.EOF
    sumVal = sumVal + Nz(rst(fldName).Value, 0)
    rst.MoveNext
  Wend
    
Exit_Point:
On Error Resume Next
  If retValErrNumber = 0 Then
    ADO_SumRstField = sumVal
  Else
    ADO_SumRstField = "#Error:" & retValErrNumber
  End If
Exit Function

Err_Point:
 retValErrNumber = err.Number
 Resume Exit_Point
End Function
Private Function NETREBA_EvalRSTExpresion(Expresion As String, rec As ADODB.Record) As Variant
'Kreirano: 07-11-2020
On Error GoTo Err_Point
Dim retVal As Double
Dim stExpresion As String
Dim stArrayExpresion() As String
Dim OdBrojClanovaNiza As Integer
Dim DoBrojClanovaNiza As Integer
Dim i As Integer

stExpresion = Expresion
stArrayExpresion = Split(Expresion, "+")

OdBrojClanovaNiza = LBound(stArrayExpresion)
DoBrojClanovaNiza = UBound(stArrayExpresion)
For i = OdBrojClanovaNiza To DoBrojClanovaNiza
   Debug.Print stArrayExpresion(i) & IIf(i < DoBrojClanovaNiza, "+", "");
Next i
For i = 0 To rec.Fields.Count
  stExpresion = Replace(stExpresion, rec.Fields(i).Name, rec.Fields(i).Value)
Next i
    'retVal = Eval(stExpresion)

Exit_Point:
 On Error Resume Next
 NETREBA_EvalRSTExpresion = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "EvalRSTExpresion"
 Resume Exit_Point
End Function
Public Function ADO_Sum_SPORO(ByVal Expresion As String, rst As ADODB.Recordset) As Variant
'**********************
'Kreirano: 07-11-2020
'**********************
On Error GoTo Err_Point

  Dim sumVal As Double
  Dim stExpresion As String
  Dim retValErrNumber As Long
  Dim i As Integer
  
  retValErrNumber = 0
  sumVal = 0
 
  If rst Is Nothing Then
    GoTo Exit_Point
  End If
    
  If rst.RecordCount > 0 Then rst.MoveFirst
  While Not rst.EOF
        stExpresion = Expresion
        stExpresion = Replace(stExpresion, "[", "")
        stExpresion = Replace(stExpresion, "]", "")
      
        For i = 0 To rst.Fields.Count - 1
            If rst.Fields(i).Type = adDouble Or adCurrency Or adDecimal Or adInteger Or adNumeric Or adSingle Or adSmallInt Or adTinyInt Or adVarNumeric Then
             stExpresion = Replace(stExpresion, rst.Fields(i).Name, Nz(rst.Fields(i).Value, 0))
            End If
        Next i
        
        sumVal = sumVal + Eval(stExpresion)
        rst.MoveNext
  Wend
    
Exit_Point:
On Error Resume Next
  If retValErrNumber = 0 Then
    ADO_Sum_SPORO = sumVal
  Else
    ADO_Sum_SPORO = "#Error:" & retValErrNumber
  End If
Exit Function

Err_Point:
 retValErrNumber = err.Number
 Resume Exit_Point
End Function
Public Function ADO_Sum(ByVal Expresion As String, rst As ADODB.Recordset) As Variant

'**********************
'Kreirano: 07-11-2020
'**********************
On Error GoTo Err_Point

  Dim sumVal As Double
  Dim stExpresion As String
  Dim retValErrNumber As Long
  Dim i As Integer
  
  retValErrNumber = 0
  sumVal = 0
 
  If rst Is Nothing Then
    GoTo Exit_Point
  End If
  
  stExpresion = Expresion
  stExpresion = Replace(stExpresion, "[", "")
  stExpresion = Replace(stExpresion, "]", "")
  
  On Error Resume Next
  If stExpresion = rst.Fields(Expresion).Name Then
     If err.Number = 0 Then
        On Error GoTo Err_Point
            sumVal = ADO_SumRstField(stExpresion, rst)
        GoTo Exit_Point
     Else
        err.Clear
        On Error GoTo Err_Point
     End If
  End If
  
  If rst.RecordCount > 0 Then rst.MoveFirst
  While Not rst.EOF
    stExpresion = Expresion
    stExpresion = Replace(stExpresion, "[", "")
    stExpresion = Replace(stExpresion, "]", "")
    
    For i = 0 To rst.Fields.Count - 1
         If rst.Fields(i).Type = adDouble Or adCurrency Or adDecimal Or adInteger Or adNumeric Or adSingle Or adSmallInt Or adTinyInt Or adVarNumeric Then
            'stExpresion = Replace(stExpresion, rst.Fields(i).Name, "rst(""" & rst.Fields(i).Name & """)")
            stExpresion = Replace(stExpresion, rst.Fields(i).Name, Nz(rst.Fields(i).Value, 0))
         End If
    Next i
        
    sumVal = sumVal + Eval(stExpresion)
    rst.MoveNext
  Wend
    
Exit_Point:
On Error Resume Next
  If retValErrNumber = 0 Then
    ADO_Sum = sumVal
  Else
    ADO_Sum = "#Error:" & retValErrNumber
  End If
Exit Function

Err_Point:
 retValErrNumber = err.Number
 Resume Exit_Point
End Function
Public Function GetParFromCnnString(stPar As String, CNNString As String) As String
'? GetParFromCnnString("UID", "ODBC;DRIVER=SQL Server;SERVER=bbsql.algrosso.com;UID=ReadOnly;PWD=BBRO.124578;APP=QBigBit;DATABASE=AlGrosso")
'Kreirano: 22-09-2019
On Error GoTo Err_Point
Dim stRetVal As String
Dim nPos As Integer

nPos = InStr(CNNString, stPar)
If nPos = 0 Then
  GoTo Exit_Point
End If
stRetVal = Right(CNNString, Len(CNNString) - nPos - Len(stPar) + 1)

nPos = InStr(stRetVal, ";")
If nPos > 0 Then
stRetVal = Left(stRetVal, nPos - 1)
End If
stRetVal = Trim(stRetVal)

If Left(stRetVal, 1) = "=" Then
   stRetVal = Replace(stRetVal, "=", "")
End If
stRetVal = Trim(stRetVal)

Exit_Point:
On Error Resume Next
GetParFromCnnString = stRetVal
Exit Function

Err_Point:
BBErrorMSG err, "GetParFromCnnString"
stRetVal = ""
Resume Exit_Point
End Function
Public Function SetParToCNNString(ByVal stPar As String, ByVal stNewValue As String, ByVal CNNString As String) As String
 'Kreirano: 03-11-2021
' ? SetParToCNNString("APP", "QBigBit_" & CurrentUser() & "(" & Environ("ComputerName") & "\" & Environ("UserName") & ")", CNN_CurrentDataBase)
On Error GoTo Err_Point
Dim stRetVal As String

stRetVal = CNNString
stRetVal = GetParFromCnnString(stPar, CNNString)
stRetVal = stPar & "=" & stRetVal

'Ako postoji, zameni ga
stRetVal = Replace(CNNString, stRetVal, stPar & "=" & stNewValue)

'ako ne postoji, dodaj ga
If GetParFromCnnString(stPar, stRetVal) <> stNewValue Then
 If Trim(CNNString) = "" Then
   stRetVal = CNNString & stPar & "=" & stNewValue
 Else
   stRetVal = CNNString & ";" & stPar & "=" & stNewValue
 End If
End If

Exit_Point:
 On Error Resume Next
       SetParToCNNString = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "SetParToCNNString"
 Resume Exit_Point
End Function
Public Function SQLFormatVreme(Vreme As Variant, Optional SaApostrofima As Boolean = True) As Variant
'Kreirano: 09-08-2019
'Modifikovano: 25-03-2022 Format(Vreme, "Hh:Nn:Ss") => Format(Vreme, "Hh\:Nn\:Ss")
'Modifikovano: 29-03-2022  za Vreme="'Null'" i Vreme="Null"
Dim retVal As Variant
 
 
 If IsNull(Vreme) Then
    retVal = Null
 ElseIf Trim(Nz(Vreme, "'Null'")) = "'Null'" Then
        retVal = Null
 ElseIf Trim(Nz(Vreme, "Null")) = "Null" Then
        retVal = Null
 
 ElseIf IsDate(Vreme) Then
  retVal = Format(Vreme, "Hh\:Nn\:Ss")
  If SaApostrofima Then
   retVal = "'" & retVal & "'"
  End If
 Else
  retVal = CStr(Vreme)
 End If
 SQLFormatVreme = retVal
End Function
Public Function SQLFormatDatuma(DATUM As Variant, Optional SaApostrofima As Boolean = True) As Variant
'Public Function SQLFormatDatuma(Datum As Variant, SaApostrofima As Boolean) As Variant
'Modifikovano: 09-08-2019
'Modifikovano: 25-03-2022 Format(Datum, "yyyy-MM-dd") => Format(Datum, "yyyy\-MM\-dd")
'Modifikovano: 25-03-2022  za format "25.03.2022."
'Modifikovano: 29-03-2022  za Datum="'Null'" i Datum="Null"
Dim retVal As Variant

 
 If IsNull(DATUM) Then
        retVal = Null
ElseIf Trim(Nz(DATUM, "'Null'")) = "'Null'" Then
        retVal = Null
ElseIf Trim(Nz(DATUM, "Null")) = "Null" Then
        retVal = Null

ElseIf IsDate(DATUM) Then
        retVal = Format(DATUM, "yyyy\-MM\-dd")
        If SaApostrofima Then
         retVal = "'" & retVal & "'"
        End If
        
ElseIf Not IsNumeric(Right(CStr(DATUM), 1)) Then 'jebo sam ti kevu!
         retVal = Left(CStr(DATUM), Len(CStr(DATUM)) - 1)
         retVal = Format(retVal, "yyyy\-MM\-dd")
        If SaApostrofima Then
         retVal = "'" & retVal & "'"
        End If
Else
  retVal = CStr(DATUM)
End If
 
 SQLFormatDatuma = retVal

End Function
Public Function SQLFormatDatumIVreme(DatumIVreme As Variant, Optional SaApostrofima As Boolean = True) As Variant
'Kreirano: 23-12-2019
  Dim retVal As Variant
  If IsNull(DatumIVreme) Then
    retVal = Null
  Else
    retVal = SQLFormatDatuma(DatumIVreme, False) & " " & SQLFormatVreme(DatumIVreme, False)
    If SaApostrofima Then
       retVal = "'" & retVal & "'"
    End If
  End If
  SQLFormatDatumIVreme = retVal
End Function

Public Function SQLFormatBoolean(ByVal val As Variant) As Variant
Dim retVal As Variant
 If IsNull(val) Then
    retVal = Null
 ElseIf val Then
  retVal = 1
 Else
  retVal = 0
 End If
 SQLFormatBoolean = retVal
End Function
Public Function CheckFieldToSQL(ByVal val As Variant) As Variant
Dim retVal As Variant
 If IsNull(val) Then
    retVal = Null
 ElseIf val Then
  retVal = 1
 Else
  retVal = 0
 End If
 CheckFieldToSQL = retVal
End Function
Public Function AccesArgToSQL(Optional Arg As Variant) As String
 Dim RetArg As String
 
 If IsMissing(Arg) Then
   RetArg = "DEFAULT"
 ElseIf Arg = "<DEFAULT>" Then
   RetArg = "DEFAULT"
 ElseIf IsNull(Arg) Then
   RetArg = "null"
 ElseIf Left(CStr(Arg), 1) = "'" And Right(CStr(Arg), 1) = "'" Then
   RetArg = CStr(Arg)
 ElseIf IsNumeric(Arg) Then
   RetArg = Arg
 Else
  RetArg = "'" & Arg & "'"
 End If
 AccesArgToSQL = RetArg
End Function
Public Function ADO_GetValFromUDFS(CNNString As String, fName As String, ParamArray Arg()) As Variant
'Kreirano: 24-12-2019
On Error GoTo err_GetValFromUDFS

Dim pCMD As New ADODB.Command

Dim i As Integer
Dim spBrojParametara As Integer
Dim InBrojParametara As Integer
Dim stPoruka As String
Dim CmdRetVal As Variant

DoCmd.Hourglass True
pCMD.ActiveConnection = CNNString
pCMD.CommandType = adCmdStoredProc
pCMD.CommandText = fName

pCMD.Parameters.Refresh 'posle ove komande svi parametri su definisani!
 'cmd.Parameters(0) = @RETURN_VALUE
 spBrojParametara = pCMD.Parameters.Count() - 1
 InBrojParametara = UBound(Arg()) - LBound(Arg()) + 1
 If InBrojParametara <> spBrojParametara Then
  DoCmd.Hourglass False
  
  stPoruka = "Neuskladjeni parametri za " & fName
  stPoruka = stPoruka & vbCrLf & "potrebno " & CStr(spBrojParametara) & ", prosledjeno " & CStr(InBrojParametara)
  stPoruka = stPoruka & vbCrLf & vbCrLf & "Parametri koji nedostaju:" & vbCrLf
  For i = InBrojParametara + 1 To spBrojParametara
       stPoruka = stPoruka & pCMD.Parameters(i).Name & vbCrLf
   Next i
  stPoruka = stPoruka & vbCrLf & "Da li želite da za njih prosledim 'DEFAULT'?"
  stPoruka = stPoruka & vbCrLf & "(ako odgovorite sa No proces se prekida)"
  If BBPitanje(stPoruka) Then
   For i = InBrojParametara + 1 To spBrojParametara
       pCMD.Parameters(i).Value = Empty
   Next i
  Else
   CmdRetVal = False
   GoTo exit_GetValFromUDFS
  End If
 End If


 For i = 1 To InBrojParametara
 ' problem sa datumom!
  pCMD.Parameters(i).Value = Arg(i - 1)
' SQLText = SQLText & " " & Cmd.Parameters(I).Name & " = " & Cmd.Parameters(I).Value & ","
' Debug.Print i, pCMD.Parameters(i).Name, pCMD.Parameters(i).Value
Next i

pCMD.CommandTimeout = 180 '3 minuta !!

pCMD.Execute
'CmdRetVal = pCmd.Parameters("@RETURN_VALUE")
CmdRetVal = pCMD.Parameters(0)

exit_GetValFromUDFS:
On Error Resume Next
    pCMD.ActiveConnection.Close
    Set pCMD = Nothing
    DoCmd.Hourglass False
    ADO_GetValFromUDFS = CmdRetVal
Exit Function

err_GetValFromUDFS:

    BBErrorMSG err, "ADO_GetValFromUDFS(" & fName & "...)"
    CmdRetVal = False
    Resume exit_GetValFromUDFS
End Function
Public Function BackupCurrentSQLDB(stDestFileName As String) As Boolean
'Kreirano: 11-06-2020
'Modifikovano: 14-11-2021 => umesto stCNNString = CnnMasterDB stavljeno stCNNString = CNN_CurrentDataBase
'BACKUP DATABASE [EcoTipTedex] TO  DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL13.SQLEXPRESS\MSSQL\Backup\EcoTipTedex\EcoTipTedex_MOJE_11062020.bak' WITH NOFORMAT, NOINIT,  NAME = N'EcoTipTedex-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim stCNNString As String
    Dim stDataBase As String
    Dim stSQLCmd As String

    stCNNString = CNN_CurrentDataBase
    stDataBase = GetParFromCnnString("DATABASE=", stCNNString)
    stSQLCmd = "BACKUP DATABASE " & stDataBase
    stSQLCmd = stSQLCmd & " TO DISK = N'" & stDestFileName & "'"
    stSQLCmd = stSQLCmd & " WITH NOFORMAT, NOINIT,  NAME = N'" & stDataBase & "-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10"
    'Debug.Print stSQLCMD
    retValOk = ADO_ExecSQL(stCNNString, stSQLCmd, True) 'PassTroughExecuteSQL(stSQLCmd, stCNNString, True)

  
Exit_Point:
 On Error Resume Next
 BackupCurrentSQLDB = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "BackupCurrentSQLDB"
 retValOk = False
 Resume Exit_Point
End Function
Public Function ADO_GetRSTFromUDFT(CNNString As String, fName As String, ParamArray Arg()) As ADODB.Recordset
On Error GoTo err_GetRSFromUDFT

Dim fparam As String, narg As String
Dim i As Integer
Dim rst As ADODB.Recordset

Set rst = New ADODB.Recordset
rst.CursorLocation = adUseClient

fparam = "("
For i = LBound(Arg) To UBound(Arg)
 narg = AccesArgToSQL(Arg(i))
 If fparam = "(" Then
  fparam = fparam & narg
 Else
  fparam = fparam & "," & narg
 End If
Next i
fparam = fparam & ")"

rst.Open "SELECT * FROM " & fName & fparam, CNNString, adOpenKeyset, adLockOptimistic
'rst.Properties("Unique Table") = "T_Robne stavke"
Set ADO_GetRSTFromUDFT = rst

exit_GetRSFromUDFT:
Exit Function

err_GetRSFromUDFT:
    'MsgBox Error$
    BBErrorMSG err, "ADO_GetRSTFromUDFT"
    Resume exit_GetRSFromUDFT
End Function
Public Function ADO_GetRSTFromSP(CNNString, SPName As String, ParamArray Arg()) As ADODB.Recordset
On Error GoTo err_GetRSFromSP
'Call GetRSFromSP("spPregledArtikala", "%", "%", "%", "%")

Dim cmd As New ADODB.Command

Dim i As Integer

cmd.ActiveConnection = CNNString
cmd.ActiveConnection.CursorLocation = adUseClient
cmd.CommandType = adCmdStoredProc
cmd.CommandText = SPName

cmd.Parameters.Refresh 'posle ove komande svi parametri su definisani!
' cmd.Parameters(0) = @RETURN_VALUE
For i = 1 To cmd.Parameters.Count() - 1
 cmd.Parameters(i).Value = Arg(i - 1)
 'sqltext = sqltext & " " & Cmd.Parameters(I).Name & " = " & Cmd.Parameters(I).Value & ","
 'Debug.Print I, Cmd.Parameters(I).Name, Cmd.Parameters(I).Value
Next i
'Debug.Print sqltext
Set ADO_GetRSTFromSP = cmd.Execute

'Debug.Print "Broj slogova=" & rs.RecordCount
'cmd.ActiveConnection.Close 'ako se zatvori konekcija gubi se recordset

exit_GetRSFromSP:

Exit Function

err_GetRSFromSP:
    'MsgBox Error$
    BBErrorMSG err, "ADO_GetRSTFromSP"
    Resume exit_GetRSFromSP

End Function
Public Function ADO_OpenQuery(CNNString As String, stSQLText As String)
'Kreirano: 26-01-2021
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stQueryName As String
    stQueryName = "~ADO_OpenQuery~"
    'PassTroughQuerySave Me!QueryName, stSQLText, F_CNNString("ODBC"), False
    retValOk = PassTroughQuerySave(stQueryName, stSQLText, CNNString, False)
    DoCmd.OpenQuery stQueryName
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, ""
 Resume Exit_Point
End Function

Public Function ADO_UpdateColumn(CNNString As String, TableName As String, Column As String, NewVal As Variant, Optional Where As String = "", Optional ByVal OnErrShowDetails As Boolean = True, Optional ByVal pCommandTimeout As Integer = 30) As Boolean
'CNN_CurrentDataBase,"T_Robna dokumenta","IDDokIF",NewIDDok,"IDDok = " & Me!ComboIzDok)
'Kreirano: 30-01-2022
On Error GoTo Err_Point
Dim retValOk As Boolean

Dim stTableName As String
Dim stColumn As String
Dim stWhere As String
Dim stSQL As String

stTableName = ADO_PopraviNazivTabeleIliKolone(TableName)
stColumn = ADO_PopraviNazivTabeleIliKolone(Column)
stWhere = Replace(Where, "WHERE", "")
If stWhere <> "" Then
   stWhere = " WHERE " & stWhere
End If

stSQL = ""
stSQL = stSQL & " UPDATE " & stTableName & vbCrLf
stSQL = stSQL & " SET " & stColumn & "=" & CStr(NewVal) & vbCrLf
stSQL = stSQL & " " & stWhere

retValOk = ADO_ExecSQL(CNNString, stSQL, OnErrShowDetails, pCommandTimeout)
Exit_Point:
 On Error Resume Next
       ADO_UpdateColumn = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "ADO_UpdateColumn"
 retValOk = False
 Resume Exit_Point
End Function

Public Function DAO_UpdateColumn(TableName As String, Column As String, NewVal As Variant, Optional Where As String = "", Optional ByVal OnErrShowDetails As Boolean = True, Optional ByVal pCommandTimeout As Integer = 30) As Boolean
'CNN_CurrentDataBase,"T_Robna dokumenta","IDDokIF",NewIDDok,"IDDok = " & Me!ComboIzDok)
'Kreirano: 20-12-2022
On Error GoTo Err_Point
Dim retValOk As Boolean

Dim stTableName As String
Dim stColumn As String
Dim stWhere As String
Dim stSQL As String
retValOk = True

stTableName = ADO_PopraviNazivTabeleIliKolone(TableName)
stColumn = ADO_PopraviNazivTabeleIliKolone(Column)
stWhere = Replace(Where, "WHERE", "")
If stWhere <> "" Then
   stWhere = " WHERE " & stWhere
End If

stSQL = ""
stSQL = stSQL & " UPDATE " & stTableName & vbCrLf
stSQL = stSQL & " SET " & stColumn & "=" & CStr(NewVal) & vbCrLf
stSQL = stSQL & " " & stWhere

DoCmd.SetWarnings False
DoCmd.RunSQL stSQL
'retValOk = ADO_ExecSQL(CNNString, stSQL, OnErrShowDetails, pCommandTimeout)
Exit_Point:
 On Error Resume Next
        DoCmd.SetWarnings True
        DAO_UpdateColumn = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "DAO_UpdateColumn"
 retValOk = False
 Resume Exit_Point
End Function

Public Function SqlSafeDate_OLD(ByVal inputDate As String, Optional SaApostrofima As Boolean = True) As String
    Dim d As Date
    Dim tempDate As String
    Dim success As Boolean
    Dim retVal As Variant
    
    On Error GoTo ErrorHandler
    inputDate = Trim(inputDate)
    
    ' Pokušaj sa direktnim CDate
    If IsDate(inputDate) Then
        d = CDate(inputDate)
        SqlSafeDate_OLD = Format(d, "yyyy-mm-dd")
        Exit Function
    End If

    ' Ako nije prošao, pokušaj da dekodiraš poznate formate ruèno

    ' Format: dd.mm.yyyy
    If inputDate Like "##.##.####" Then
        tempDate = Mid(inputDate, 4, 2) & "/" & Left(inputDate, 2) & "/" & Right(inputDate, 4)
        If IsDate(tempDate) Then
            d = CDate(tempDate)
            SqlSafeDate_OLD = Format(d, "yyyy-mm-dd")
            Exit Function
        End If
    End If

    ' Format: dd-Mmm-yy (npr. 20-Maj-25)
    If inputDate Like "##-???-##" Then
        If IsDate(inputDate) Then
            d = CDate(inputDate)
            SqlSafeDate_OLD = Format(d, "yyyy-mm-dd")
            Exit Function
        End If
    End If

    ' Format: mm/dd/yyyy or m/d/yyyy (standardni amerièki)
    If IsDate(inputDate) Then
        d = CDate(inputDate)
        SqlSafeDate_OLD = Format(d, "yyyy-mm-dd")
        Exit Function
    End If

ErrorHandler:
    SqlSafeDate_OLD = "NULL"
End Function

Public Function SQLFormatPDMDatuma(ByVal inputDate As Variant, Optional SaApostrofima As Boolean = True) As String
    Dim retVal As Date
    Dim tempDate As String
    
    On Error GoTo ErrorHandler
    
    ' Provera na Null ili prazan unos
    If IsNull(inputDate) Or Trim(inputDate) = "" Then
        SQLFormatPDMDatuma = "NULL"
        Exit Function
    End If
    
    inputDate = Trim(inputDate)

    ' Direktna konverzija ako je prepoznat datum
    If IsDate(inputDate) Then
        retVal = CDate(inputDate)
        GoTo FormatOutput
    End If

    ' Format: dd.mm.yyyy
    If inputDate Like "##.##.####" Then
        tempDate = Mid(inputDate, 4, 2) & "/" & Left(inputDate, 2) & "/" & Right(inputDate, 4)
        If IsDate(tempDate) Then
            retVal = CDate(tempDate)
            GoTo FormatOutput
        End If
    End If

    ' Format: dd-Mmm-yy
    If inputDate Like "##-???-##" Then
        If IsDate(inputDate) Then
            retVal = CDate(inputDate)
            GoTo FormatOutput
        End If
    End If

    ' Poslednja šansa ako je prepoznat kao datum u lokalnom formatu
    If IsDate(inputDate) Then
        retVal = CDate(inputDate)
        GoTo FormatOutput
    End If

ErrorHandler:
    SQLFormatPDMDatuma = "NULL"
    Exit Function

FormatOutput:
    If SaApostrofima Then
        SQLFormatPDMDatuma = "'" & Format(retVal, "yyyy-mm-dd") & "'"
    Else
        SQLFormatPDMDatuma = Format(retVal, "yyyy-mm-dd")
    End If
End Function


Public Function ConvertAccessToSQLParam(v As Variant) As String
    Dim vt As VbVarType

    On Error GoTo SafeNull
    vt = varType(v)

    Select Case vt

        Case vbNull, vbEmpty
            ConvertAccessToSQLParam = "NULL"

        Case vbString
            If Trim(v) = "" Then
                ConvertAccessToSQLParam = "NULL"
            Else
                ConvertAccessToSQLParam = "'" & Replace(v, "'", "''") & "'"
            End If

        Case vbInteger, vbLong, vbByte, vbCurrency, vbSingle, vbDouble
            ConvertAccessToSQLParam = CStr(v)

        Case vbBoolean
            ConvertAccessToSQLParam = IIf(v, "1", "0")

        Case vbDate
            ConvertAccessToSQLParam = "'" & Format$(v, "yyyy-mm-dd") & "'"

        Case vbVariant
            ' možda null ili empty
            If IsNull(v) Or v = "" Then
                ConvertAccessToSQLParam = "NULL"
            Else
                ConvertAccessToSQLParam = "'" & Replace(CStr(v), "'", "''") & "'"
            End If

        Case Else
            ' OBJEKTI: ComboBox.Column, Recordset, Controls...
            GoTo SafeNull

    End Select

    Exit Function

SafeNull:
    ConvertAccessToSQLParam = "NULL"
End Function
Public Function SQLParam_Debug(v As Variant, ParamName As String) As String
    Dim vt As VbVarType
    Dim result As String
    
    On Error GoTo ErrHandler
    
    vt = varType(v)
    
    ' PRIKAŽI TIP VARIJABLE
    Debug.Print "---------------------------------------"
    Debug.Print "Parametar: "; ParamName
    Debug.Print "VarType: "; vt; " ("; TypeName(v); ")"
    
    ' LOG PRAVE VREDNOSTI
    If IsObject(v) Then
        Debug.Print "Vrednost: [OBJECT]"
        SQLParam_Debug = "NULL"
        Exit Function
    Else
        Debug.Print "Vrednost: "; IIf(IsNull(v), "(NULL)", v)
    End If
    
    Select Case vt
    
        Case vbNull, vbEmpty
            result = "NULL"
            
        Case vbString
            If Trim(v) = "" Then
                result = "NULL"
            Else
                result = "'" & Replace(v, "'", "''") & "'"
            End If
        
        Case vbInteger, vbLong, vbByte, vbCurrency, vbSingle, vbDouble
            result = CStr(v)
            
        Case vbBoolean
            result = IIf(v, "1", "0")
        
        Case vbDate
            result = "'" & Format$(v, "yyyy-mm-dd") & "'"
        
        Case vbVariant
            If IsNull(v) Or v = "" Then
                result = "NULL"
            Else
                result = "'" & Replace(CStr(v), "'", "''") & "'"
            End If
        
        Case Else
            result = "NULL"   ' sve ostalo tretiramo kao NULL
        
    End Select
    
    Debug.Print "SQLParam result: "; result
    SQLParam_Debug = result
    Exit Function

ErrHandler:
    Debug.Print ">>> GREŠKA U PARAMETRU: "; ParamName
    Debug.Print ">>> Err.Number: "; err.Number
    Debug.Print ">>> Err.Description: "; err.Description
    SQLParam_Debug = "NULL"
End Function
Public Function ADO_GetValFromScalar(CNNString As String, funName As String, ParamArray Arg()) As Variant
On Error GoTo Err_Point

Dim cnn As New ADODB.Connection
Dim rst As New ADODB.Recordset
Dim sql As String
Dim i As Long

cnn.Open CNNString

'--- Sastavi SELECT fn(p1,p2,p3) ---
sql = "SELECT dbo." & funName & "("

For i = LBound(Arg) To UBound(Arg)
    If IsNull(Arg(i)) Or Arg(i) = "" Then
        sql = sql & "NULL,"
    ElseIf IsDate(Arg(i)) Then
        sql = sql & "'" & Format(Arg(i), "yyyy-mm-dd") & "',"
    ElseIf IsNumeric(Arg(i)) Then
        sql = sql & Arg(i) & ","
    Else
        sql = sql & "N'" & Replace(Arg(i), "'", "''") & "',"
    End If
Next i

sql = Left(sql, Len(sql) - 1) & ")"   ' ukloni zadnju zarez

rst.Open sql, cnn, adOpenStatic, adLockReadOnly

If Not rst.EOF Then
    ADO_GetValFromScalar = rst.Fields(0).Value
Else
    ADO_GetValFromScalar = Null
End If

rst.Close
cnn.Close

Exit Function

Err_Point:
    ADO_GetValFromScalar = Null
    
End Function

Public Function ADO_ExecSP_WithOutput( _
    CNNString As String, _
    SPName As String, _
    ByRef OutValue As Variant, _
    ParamArray Arg()) As Boolean
' Kreirano: 19-12-2025 - NISAM TESTIRAO
' Namena: Izvršava SP i vraæa OUTPUT parametar (npr. IDPlan)
' Napomena: OUTPUT parametar mora biti POSLEDNJI u SP

On Error GoTo Err_Point

Dim pCMD As New ADODB.Command
Dim i As Integer
Dim spBrojParametara As Integer
Dim InBrojParametara As Integer
Dim stPoruka As String
Dim retValOk As Boolean

DoCmd.Hourglass True

pCMD.ActiveConnection = CNNString
pCMD.CommandType = adCmdStoredProc
pCMD.CommandText = SPName

' Uèitavamo definiciju parametara iz SQL Server-a
pCMD.Parameters.Refresh

' Broj parametara u SP (bez @RETURN_VALUE)
spBrojParametara = pCMD.Parameters.Count - 1

' Broj ulaznih parametara koje prosleðujemo
InBrojParametara = UBound(Arg) - LBound(Arg) + 1

' Oèekujemo: svi ulazni + 1 OUTPUT
If InBrojParametara <> spBrojParametara - 1 Then
    DoCmd.Hourglass False

    stPoruka = "Neuskladjeni parametri za " & SPName
    stPoruka = stPoruka & vbCrLf & "Oèekivano (bez OUTPUT): " & CStr(spBrojParametara - 1)
    stPoruka = stPoruka & vbCrLf & "Prosleðeno: " & CStr(InBrojParametara)

    MsgBox stPoruka, vbCritical
    retValOk = False
    GoTo Exit_Point
End If

' Postavljanje INPUT parametara
'For i = 1 To InBrojParametara
'    pCMD.Parameters(i).Value = Arg(i - 1)
'Next i
' Zamenjeno 31-01-2026
For i = 1 To InBrojParametara
    With pCMD.Parameters(i)
        Select Case .Type
            Case adDate, adDBTimeStamp, adDBDate
                .Value = CDate(Arg(i - 1))
            Case adInteger, adSmallInt, adBigInt
                .Value = CLng(Arg(i - 1))
            Case Else
                .Value = Arg(i - 1)
        End Select
    End With
Next

' OUTPUT parametar je poslednji
pCMD.Parameters(spBrojParametara).Direction = adParamOutput

pCMD.CommandTimeout = 180

' Provera
    'Dim j As Integer
    'For j = 0 To pCMD.Parameters.Count - 1
    '    Debug.Print pCMD.Parameters(j).Name, _
                pCMD.Parameters(j).Type, _
                pCMD.Parameters(j).Value
    'Next

' Izvršenje
pCMD.Execute

' Preuzimanje OUTPUT vrednosti
OutValue = pCMD.Parameters(spBrojParametara).Value

' Provera SQL grešaka
retValOk = True
For i = 0 To pCMD.ActiveConnection.Errors.Count - 1
    retValOk = (retValOk And Left(CStr(pCMD.ActiveConnection.Errors.Item(i).SQLState), 1) = "0")
Next i

Exit_Point:
On Error Resume Next
Set pCMD = Nothing
DoCmd.Hourglass False
ADO_ExecSP_WithOutput = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "ADO_ExecSP_WithOutput(" & SPName & "...)"
    retValOk = False
    Resume Exit_Point
End Function
Public Function ADO_SQLValue(v As Variant) As String
    If IsNull(v) Then
        ADO_SQLValue = "NULL"
    ElseIf varType(v) = vbString Then
        ADO_SQLValue = "N'" & Replace(v, "'", "''") & "'"
    ElseIf IsDate(v) Then
        ADO_SQLValue = "'" & Format(v, "yyyy-mm-dd hh:nn:ss") & "'"
    Else
        ADO_SQLValue = CStr(v)
    End If
End Function

Public Function SQL_Bit(ByVal v As Variant) As String
    If IsNull(v) Then
        SQL_Bit = "NULL"
    ElseIf (v = True) Or (v = -1) Or (v = 1) Then
        SQL_Bit = "1"
    Else
        SQL_Bit = "0"
    End If
End Function

Public Function SQL_Num(ByVal v As Variant) As String
    ' Vraca broj kao SQL literal sa tackom (.), ili NULL
    If IsNull(v) Or v = "" Then
        SQL_Num = "NULL"
    Else
        SQL_Num = Replace(CStr(v), ",", ".")
    End If
End Function

Public Function SQL_Long(ByVal v As Variant) As String
    If IsNull(v) Or v = "" Then
        SQL_Long = "NULL"
    Else
        SQL_Long = CStr(CLng(v))
    End If
End Function
