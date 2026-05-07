Attribute VB_Name = "BBSQLModule"
Option Compare Database
Option Explicit

''  %EL428tnkXoK8PY
' Ovo je primer postavljanja RecordSource za moju formu Pregled artikala
'  BBCreateQuery Me.Name, TextSelectQForUDFT("ftArtikli", Me!ZaKatBroj, Me!FilterZaGrupu, Me!ZaPodgrupu, Me!FilterZaPoreklo), F_CNNString()
'  Me.RecordSource = Me.Name
'
'
'=====================================================================
Public Function LinkTableToNewSQLServer(TblName As String, NewCnnString As String)
'? LinkTableToNewSQLServer("dbo_A_Test","ODBC;Description=Beorol;DRIVER=SQL Server;SERVER=P50\SQLEXPRESS;Trusted_Connection=Yes;APP=Microsoft Office 2010;DATABASE=Beorol")
 On Error GoTo Err_Point
 
 Dim tdfLinked As DAO.TableDef
 
 Dim retVal As Boolean
  retVal = True
  
  'Set tdfLinked = CurrentDb.TableDefs(tblName) <- OVO NE RADI A JA
  'NE UMEM DRUGAÈIJE. Ako bar proveravam bez grešaka da li postoji ovakva tabela
  For Each tdfLinked In CurrentDb.TableDefs
   If tdfLinked.Name = TblName Then Exit For
  Next
  
  If (tdfLinked.Name <> TblName) Or Not CBool((tdfLinked.Attributes And dbAttachedODBC)) Then
   retVal = False
   GoTo Exit_Point:
  End If
 
  If tdfLinked.Connect <> NewCnnString Then
   'tdfLinked.Attributes = (tdfLinked.Attributes Or dbAttachSavePWD)
   tdfLinked.Connect = NewCnnString
  End If
   tdfLinked.RefreshLink
 
Exit_Point:
  LinkTableToNewSQLServer = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "LinkTableToNewSQLServer tblName=" & TblName
 retVal = False
End Function
Public Sub ConnectSQLToNewServer(NewCnnString As String)
 Dim rstTabele As DAO.Recordset
 
 Set rstTabele = CurrentDb.OpenRecordset("SELECT SQL_LinkedTables.* FROM SQL_LinkedTables WHERE (((SQL_LinkedTables.ForceNewLink)=True));")
 While Not rstTabele.EOF
 ' Debug.Print rstTabele!TableName
  LinkTableToNewSQLServer rstTabele!TableName, NewCnnString
  rstTabele.Edit
  rstTabele!CNNString = CurrentDb.TableDefs(rstTabele!TableName).Connect
  rstTabele.Update
  rstTabele.MoveNext
  
 Wend
 rstTabele.Close
 Set rstTabele = Nothing
End Sub
Public Sub RefreshLinkedSQLTables()
'Kreirano: 01-01-2016 ???
'Modifikovano: 19-01-2019

On Error GoTo Err_Point
 Dim rstTabele As DAO.Recordset
 
 Set rstTabele = CurrentDb.OpenRecordset("SELECT SQL_LinkedTables.* FROM SQL_LinkedTables WHERE (((SQL_LinkedTables.ForceNewLink)=True));")
 While Not rstTabele.EOF
 ' Debug.Print rstTabele!TableName
  'LinkTableToNewSQLServer rstTabele!TableName, NewCnnString
  rstTabele.Edit
  CurrentDb.TableDefs(rstTabele!TableName).RefreshLink
  rstTabele!CNNString = CurrentDb.TableDefs(rstTabele!TableName).Connect
  rstTabele.Update
  rstTabele.MoveNext
  
 Wend
Exit_Point:
 On Error Resume Next
 rstTabele.Close
 Set rstTabele = Nothing
Exit Sub

Err_Point:
 BBErrorMSG err, "RefreshLinkedSQLTables"
 Resume Exit_Point:
End Sub

Public Function GetRSFromUDFT_NIJEUPDATABLE(fName As String, ParamArray Arg()) As ADODB.Recordset
On Error GoTo err_GetRSFromUDFT
'call GetRSFromUDFT("ftRArtikli","%","%","%","%")
'call GetRSFromUDFT("ftRArtikli","","","","")

Dim cmd As New ADODB.Command
'Dim rs As New ADODB.Recordset

Dim fparam As String, narg As String
Dim i As Integer

fparam = "("
For i = LBound(Arg) To UBound(Arg)
 'Debug.Print "arg(" & i & ")= " & arg(i)
 
 narg = AccesArgToSQL(Arg(i))
 
 If fparam = "(" Then
  fparam = fparam & narg
 Else
  fparam = fparam & "," & narg
 End If
Next i
fparam = fparam & ")"
' Debug.Print "fparam = " & fparam
 
cmd.ActiveConnection = F_CNNString("SQL")
cmd.ActiveConnection.CursorLocation = adUseClient
'Cmd.ActiveConnection.CursorType = adOpenKeyset
'Cmd.ActiveConnection.CursorType = adOpenDynamic

cmd.CommandType = adCmdText
cmd.CommandText = "SELECT * FROM " & fName & fparam

' Debug.Print cmd.commandText

Set GetRSFromUDFT_NIJEUPDATABLE = cmd.Execute

'Debug.Print "Broj slogova=" & rs.RecordCount
'cmd.ActiveConnection.Close 'ako se zatvori konekcija gubi se recordset
exit_GetRSFromUDFT:
Exit Function

err_GetRSFromUDFT:
    'MsgBox Error$
    BBErrorMSG err, "GetRSFromUDFT"
    Resume exit_GetRSFromUDFT
End Function
Public Sub SubGetRSFromUDFT(rst As ADODB.Recordset, fName As String, ParamArray Arg())
'Modifikovano: 15-12-2020   -> F_CNNString("SQL")

On Error GoTo err_GetRSFromUDFT

Dim fparam As String, narg As String
Dim i As Integer
'Dim rst As New ADODB.Recordset

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

rst.Open "SELECT * FROM " & fName & fparam, F_CNNString("SQL"), adOpenKeyset, adLockOptimistic
'rst.Properties("Unique Table") = "T_Robne stavke"

exit_GetRSFromUDFT:
Exit Sub

err_GetRSFromUDFT:
    'MsgBox Error$
    BBErrorMSG err, "SUBGetRSFromUDFT"
    Resume exit_GetRSFromUDFT
End Sub



Public Function TextSelectQForUDFT(fName As String, ParamArray Arg()) As String
On Error GoTo Err_Point

Dim retVal As String
Dim fparam As String, narg As String
Dim i As Integer

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
 
retVal = "SELECT * FROM " & fName & fparam

Exit_Point:
 TextSelectQForUDFT = retVal
 'If BBCFG.SysRazvojAPL And CurrentUser = "Negovan" Then
  '   Debug.Print retVal
 'End If
Exit Function
 
Err_Point:
    BBErrorMSG err, "TextSelectQForUDFT"
    Resume Exit_Point
End Function
Public Function TextSelectQForSP(SPName As String, ParamArray Arg()) As String
On Error GoTo Err_Point

Dim retVal As String
Dim fparam As String, narg As String
Dim i As Integer

fparam = ""
For i = LBound(Arg) To UBound(Arg)
 narg = AccesArgToSQL(Arg(i))
 
 If fparam = "" Then
  fparam = fparam & narg
 Else
  fparam = fparam & "," & narg
 End If
Next i
fparam = fparam & ""
 
retVal = "EXECUTE " & SPName & " " & fparam

Exit_Point:
 TextSelectQForSP = retVal
 
Exit Function
 
Err_Point:
    BBErrorMSG err, "TextSelectQForSP"
    Resume Exit_Point
End Function

Public Function TextExecuteSP(SPName As String, ParamArray Arg()) As String
On Error GoTo Err_Point

Dim cmd As New ADODB.Command
Dim retVal As String
Dim fparam As String, narg As String
Dim BrojProsledjenihParametara As Integer
Dim DoBrojaParametara As Integer
Dim i As Integer

cmd.ActiveConnection = F_CNNString("SQL")
'Cmd.ActiveConnection = "ODBC;Description=Beorol;DRIVER=SQL Server;SERVER=P50\SQLEXPRESS;Trusted_Connection=Yes;APP=Microsoft Office 2010;DATABASE=Beorol"
'Cmd.ActiveConnection.CursorLocation = adUseClient
cmd.CommandType = adCmdStoredProc
cmd.CommandText = SPName

cmd.Parameters.Refresh 'posle ove komande svi parametri su definisani!

' cmd.Parameters(0) = @RETURN_VALUE
fparam = ""

BrojProsledjenihParametara = UBound(Arg) - LBound(Arg) + 1
If BrojProsledjenihParametara <= cmd.Parameters.Count() - 1 Then
 DoBrojaParametara = cmd.Parameters.Count() - 1 'BrojProsledjenihParametara
Else
 DoBrojaParametara = cmd.Parameters.Count() - 1
End If

For i = 1 To DoBrojaParametara
 If i <= BrojProsledjenihParametara Then 'do 17-01-2019 bilo strogo "<" što je GREŠKA!
   narg = AccesArgToSQL(Arg(i - 1))
 Else
   narg = "DEFAULT"
 End If
 If fparam = "" Then
   fparam = fparam & cmd.Parameters(i).Name & " = " & narg
 Else
  fparam = fparam & "," & cmd.Parameters(i).Name & " = " & narg
 End If
  If i <> DoBrojaParametara Then fparam = fparam & vbCrLf
Next i
 
retVal = "EXECUTE " & SPName & vbCrLf & " " & fparam

Exit_Point:
On Error Resume Next
cmd.ActiveConnection.Close

 TextExecuteSP = retVal
 
Exit Function
 
Err_Point:
    BBErrorMSG err, "TextExecuteSP"
    Resume Exit_Point
End Function

Public Function BBCreateQuery(ByVal QName As String, ByVal SQLText As String, Optional CNNString As Variant) As Boolean
'"SELECT * FROM ftPregledArtikala(default,default,default,'%')"
On Error GoTo err_Func
Dim retValOk As Boolean

retValOk = True
 
    Dim qDef As New QueryDef

    If IsMissing(CNNString) Then
      CNNString = F_CNNString()
    End If
    qDef.Connect = CNNString
    qDef.sql = SQLText
    qDef.Name = QName
    If PostojiQuery(qDef.Name) Then
     'ako postoji Query i ako nije ODBC onda mu promeni ime
     If Nz(CurrentDb.QueryDefs(qDef.Name).Connect, "") = "" Then
      CurrentDb.QueryDefs(qDef.Name).Name = "ACC_" & CurrentDb.QueryDefs(qDef.Name).Name
      CurrentDb.QueryDefs.Append qDef
     Else
      'DoCmd.DeleteObject acQuery, qDef.Name
      CurrentDb.QueryDefs(qDef.Name).Connect = CNNString
      CurrentDb.QueryDefs(qDef.Name).sql = SQLText
     End If
    Else
     'qDef.Properties.
     CurrentDb.QueryDefs.Append qDef
    End If
exit_Func:
   On Error Resume Next
   Set qDef = Nothing
   BBCreateQuery = retValOk
Exit Function
err_Func:
 BBErrorMSG err, "BBCreateQuery"
 retValOk = False
 Resume exit_Func:
End Function

Public Function TestConnection_Komplikovana(CNNString As String) As Boolean
On Error GoTo Err_Point
    
  Dim tName As String
  Dim aCNN As ADODB.Connection
  Dim rstTMP As ADODB.Recordset
  Dim retVal As Boolean
  
  retVal = True
  tName = "BBFirme"
  Set aCNN = New ADODB.Connection
  Set rstTMP = New ADODB.Recordset
  
  'aCNN.ConnectionString = "ODBC;Description=BEOROL_NaServeru_SaPasswordom;DRIVER=SQL Server;SERVER=87.237.205.217;UID=Slavisa;PWD=%EL428tnkXoK8PY;APP=Microsoft Office 2010;DATABASE=BEOROL"
  aCNN.ConnectionString = CNNString
  aCNN.Open
  rstTMP.CursorLocation = adUseClient
  'timeout

  '  rstTMP.Open "SELECT * FROM " & tName, aCNN, adOpenKeyset, adLockOptimistic
  rstTMP.Open "SELECT 1", aCNN, adOpenKeyset, adLockOptimistic

err_Exit:
On Error Resume Next
    rstTMP.Close
    aCNN.Close
    Set rstTMP = Nothing
    TestConnection_Komplikovana = retVal
Exit Function

Err_Point:
  retVal = False
  'BBErrorMSG Err, "TEST"
  err.Clear
  Resume err_Exit:
End Function
'******************************
'Proveri OVO
'******************************
'******************************
Private Function LinkOneTable(TblName As String) As Boolean
Dim Con As String
Dim db As DAO.Database
Dim tdf As TableDef

On Error GoTo LOT_Err
LinkOneTable = False

' Build the ODBC connect string
Con = "ODBC;driver={SQL Server};Server=YourServer;" & _
"UID=YourSQLUser;PWD=YourSQLPassword;DATABASE=YourDatabase;" & _
"TABLE=dbo." & TblName

Set db = CurrentDb
Set tdf = db.CreateTableDef(TblName)
tdf.Connect = F_CNNString() 'S$
tdf.SourceTableName = "" 'Name$

' Save password when table is attached
tdf.Attributes = dbAttachSavePWD

db.TableDefs.Append tdf

Set db = Nothing
LinkOneTable = True
LOT_Exit:
Exit Function
LOT_Err:
MsgBox "There was an error linking to table: " & TblName
Resume LOT_Exit
End Function
'******************************
'i OVO
'******************************
' Global rstSuppliers As ADODB.Recordset
Sub MakeRW()
' treba da bude GLOBAL
Dim rstSuppliers As ADODB.Recordset
    DoCmd.OpenForm "Suppliers"
    Set rstSuppliers = New ADODB.Recordset
    rstSuppliers.CursorLocation = adUseClient
    rstSuppliers.Open "Select * From Suppliers", _
         CurrentProject.Connection, adOpenKeyset, adLockOptimistic
    Set Forms("Suppliers").Recordset = rstSuppliers
End Sub
'******************************
Public Sub CloseRST(ByRef rst As ADODB.Recordset)
  If Not rst Is Nothing Then
        If rst.State = adStateOpen Then rst.Close
    End If
    Set rst = Nothing
End Sub

Public Function CStrSQL(ByVal val As Variant, cType As DAO.DataTypeEnum) As String
'****************************************************
'Kreirano: 12-11-2019
'!!! treba razlikovati DAO.DataTypeEnum i ADODB.DataTypeEnum
'****************************************************
On Error GoTo Err_Point

Dim stVal As String

If IsNull(val) Then
   stVal = "Null"
   GoTo Exit_Point
End If

Select Case cType
       Case DAO.DataTypeEnum.dbBigInt
            stVal = val
       Case DAO.DataTypeEnum.dbBinary
            stVal = val
       Case DAO.DataTypeEnum.dbBoolean
            stVal = IIf(CBool(val), "1", "0")
       Case DAO.DataTypeEnum.dbByte
            stVal = val
       Case DAO.DataTypeEnum.dbChar
            stVal = "'" & Replace(CStr(val), "'", "''") & "'"
       Case DAO.DataTypeEnum.dbCurrency
            stVal = val
       Case DAO.DataTypeEnum.dbDate
            stVal = SQLFormatDatuma(val, True)
       Case DAO.DataTypeEnum.dbDecimal
            stVal = val
       Case DAO.DataTypeEnum.dbDouble
            stVal = val
       Case DAO.DataTypeEnum.dbFloat
            stVal = val
       Case DAO.DataTypeEnum.dbGUID
            stVal = val
       Case DAO.DataTypeEnum.dbInteger
            stVal = val
       Case DAO.DataTypeEnum.dbLong
            stVal = val
       Case DAO.DataTypeEnum.dbLongBinary
            stVal = val
       Case DAO.DataTypeEnum.dbMemo
            stVal = "'" & Replace(CStr(val), "'", "''") & "'"
       Case DAO.DataTypeEnum.dbNumeric
            stVal = val
       Case DAO.DataTypeEnum.dbSingle
            stVal = val
       Case DAO.DataTypeEnum.dbText
            stVal = "'" & Replace(CStr(val), "'", "''") & "'"
       Case DAO.DataTypeEnum.dbTime
            stVal = SQLFormatVreme(val, True)
       Case DAO.DataTypeEnum.dbTimeStamp
            stVal = val
       Case DAO.DataTypeEnum.dbVarBinary
            stVal = val
       Case Else
            stVal = val
     End Select
Exit_Point:

 On Error Resume Next
 CStrSQL = stVal
 
Exit Function

Err_Point:
 BBErrorMSG err, "CStrSQL(" & CStr(Nz(val, "<<Null>>")) & "," & cType & ")"
 Resume Exit_Point
End Function
Public Function ExportujTabeluUSQL(IzTabele As String, UTabelu As String, Optional SQLTextImport = "") As Boolean
 On Error GoTo Err_Point
 Dim retValOk As Boolean
 '************
 'Dim pCMD As New ADODB.Command
 Dim rstFROM As DAO.Recordset
 Dim pCNN As New ADODB.Connection
 'Dim CNNString As String
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
 '************
 If SQLTextImport <> "" Then
   Set rstFROM = CurrentDb.OpenRecordset(SQLTextImport, dbOpenDynaset, dbSeeChanges)
 Else
  Set rstFROM = CurrentDb.OpenRecordset(IzTabele, dbOpenDynaset, dbSeeChanges)
 End If
 retValOk = True
 
 'ReDim KoloneZaExport(rstFROM.Fields.Count - 1)
 BrojKolonaZaExport = 0
 For i = 0 To rstFROM.Fields.Count - 1
  'If PostojiPoljeUTabeli(rstFROM.Fields(i).Name, CurrentDb.TableDefs(UTabelu)) Then
  If ADO_PostojiKolonaUTabeli(F_CNNString("SQL"), UTabelu, rstFROM.Fields(i).Name) Then
    ReDim Preserve KolonaZaExport(BrojKolonaZaExport)
    ReDim Preserve SizeKoloneZaExport(BrojKolonaZaExport)
    ReDim Preserve TipKoloneZaExport(BrojKolonaZaExport)
    KolonaZaExport(BrojKolonaZaExport) = rstFROM.Fields(i).Name
    SizeKoloneZaExport(BrojKolonaZaExport) = CurrentDb.TableDefs(UTabelu).Fields(rstFROM.Fields(i).Name).Size
    TipKoloneZaExport(BrojKolonaZaExport) = CurrentDb.TableDefs(UTabelu).Fields(rstFROM.Fields(i).Name).Type
    BrojKolonaZaExport = BrojKolonaZaExport + 1
  End If
 Next i
 
 pCNN.Open F_CNNString("SQL") 'CNNString

  'If IsAutoNumber(UTabelu) Then
  If ADO_IsIdentity(F_CNNString("SQL"), UTabelu) Then
    stSQLText = "SET IDENTITY_INSERT [" & UTabelu & "] ON"
    pCNN.Execute stSQLText
  End If
 
 Ispravno = 0
 NEIspravno = 0
 PorukeOGreskama = True
 
 While Not rstFROM.EOF
        stSQLText = "INSERT INTO [" & UTabelu & "]"
        stSQLText = stSQLText & " (" & "[" & KolonaZaExport(0) & "]"                               'stSQLText = stSQLText & " (" & "[" & rstFROM.Fields(0).Name & "]"
        stSQLTextValues = " VALUES ('" & Replace(rstFROM.Fields(KolonaZaExport(0)), "'", " ") & "'" 'stSQLTextValues = " VALUES ('" & Replace(rstFROM.Fields(0), "'", " ") & "'"
        
        For i = 1 To BrojKolonaZaExport - 1                                                         'For i = 1 To rstFROM.Fields.Count - 1

                stSQLText = stSQLText & ", " & "[" & KolonaZaExport(i) & "]"                  'stSQLText = stSQLText & ", " & "[" & rstFROM.Fields(i).Name & "]"
                VrednostKolone = rstFROM.Fields(KolonaZaExport(i))                                     'VrednostKolone = rstFROM.Fields(i)
                If Not IsNull(VrednostKolone) Then
                  VrednostKolone = Replace(rstFROM.Fields(KolonaZaExport(i)), "'", " ")                        'VrednostKolone = Replace(rstFROM.Fields(i), "'", " ")
                  If TipKoloneZaExport(i) = dbText Then
                    VrednostKolone = Left(VrednostKolone, SizeKoloneZaExport(i))
                  ElseIf TipKoloneZaExport(i) = dbDate Then
                    VrednostKolone = SQLFormatDatumIVreme(VrednostKolone, False)
                  End If
                End If
                
                stSQLTextValues = stSQLTextValues & ", " & "'" & VrednostKolone & "'"
           
        Next i
        stSQLText = stSQLText & ")"
        stSQLTextValues = stSQLTextValues & ")"
        
        stSQLText = stSQLText & stSQLTextValues
        'Debug.Print stSQLText
        
        On Error Resume Next
        pCNN.Execute stSQLText
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
        rstFROM.MoveNext
 Wend
 
Exit_Point:
On Error Resume Next
 'If IsAutoNumber(UTabelu) And IsAutoNumber(IzTabele) Then
 If ADO_IsIdentity(F_CNNString("SQL"), UTabelu) Then
    pCNN.Execute "SET IDENTITY_INSERT [" & UTabelu & "] OFF"
 End If
 
 pCNN.Close
 rstFROM.Close
 Set rstFROM = Nothing
 
 ExportujTabeluUSQL = retValOk
 'MsgBox "EXPORT:" & vbCrLf & "Uspešno = " & Ispravno & vbCrLf & "NEUspešno = " & NEIspravno, vbInformation, "QBigBit"
 '08-01-2022
 MsgBox "EXPORT " & IzTabele & " => " & UTabelu & ":" & vbCrLf & "Uspešno = " & Ispravno & vbCrLf & "NEUspešno = " & NEIspravno, vbInformation, "QBigTeh"
Exit Function

Err_Point:
    retValOk = False
    MsgBox err.Description
    Resume Exit_Point
End Function
Public Function ExportujTabeluUSQLBezIdentityKolone(IzTabele As String, UTabelu As String, Optional SQLTextImport = "") As Boolean
 On Error GoTo Err_Point
 Dim retValOk As Boolean
 '************
 'Dim pCMD As New ADODB.Command
 Dim rstFROM As DAO.Recordset
 Dim pCNN As New ADODB.Connection
 'Dim CNNString As String
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
 '************
 If SQLTextImport <> "" Then
   Set rstFROM = CurrentDb.OpenRecordset(SQLTextImport, dbOpenDynaset, dbSeeChanges)
 Else
  Set rstFROM = CurrentDb.OpenRecordset(IzTabele, dbOpenDynaset, dbSeeChanges)
 End If
 retValOk = True
 
 'ReDim KoloneZaExport(rstFROM.Fields.Count - 1)
 BrojKolonaZaExport = 0
 For i = 0 To rstFROM.Fields.Count - 1
  'If PostojiPoljeUTabeli(rstFROM.Fields(i).Name, CurrentDb.TableDefs(UTabelu)) Then
  If ADO_PostojiKolonaUTabeli(F_CNNString("SQL"), UTabelu, rstFROM.Fields(i).Name) Then
    ReDim Preserve KolonaZaExport(BrojKolonaZaExport)
    ReDim Preserve SizeKoloneZaExport(BrojKolonaZaExport)
    ReDim Preserve TipKoloneZaExport(BrojKolonaZaExport)
    KolonaZaExport(BrojKolonaZaExport) = rstFROM.Fields(i).Name
    SizeKoloneZaExport(BrojKolonaZaExport) = CurrentDb.TableDefs(UTabelu).Fields(rstFROM.Fields(i).Name).Size
    TipKoloneZaExport(BrojKolonaZaExport) = CurrentDb.TableDefs(UTabelu).Fields(rstFROM.Fields(i).Name).Type
    BrojKolonaZaExport = BrojKolonaZaExport + 1
  End If
 Next i
 
 pCNN.Open F_CNNString("SQL") 'CNNString

  'If IsAutoNumber(UTabelu) Then
  'If ADO_IsIdentity(F_CNNString("SQL"), UTabelu) Then
  '  stSQLText = "SET IDENTITY_INSERT [" & UTabelu & "] ON"
  '  pCNN.Execute stSQLText
  'End If
 
 Ispravno = 0
 NEIspravno = 0
 PorukeOGreskama = True
 
 While Not rstFROM.EOF
        stSQLText = "INSERT INTO [" & UTabelu & "]"
        stSQLText = stSQLText & " (" & "[" & KolonaZaExport(0) & "]"                               'stSQLText = stSQLText & " (" & "[" & rstFROM.Fields(0).Name & "]"
        stSQLTextValues = " VALUES ('" & Replace(rstFROM.Fields(KolonaZaExport(0)), "'", " ") & "'" 'stSQLTextValues = " VALUES ('" & Replace(rstFROM.Fields(0), "'", " ") & "'"
        
        For i = 1 To BrojKolonaZaExport - 1                                                         'For i = 1 To rstFROM.Fields.Count - 1

                stSQLText = stSQLText & ", " & "[" & KolonaZaExport(i) & "]"                  'stSQLText = stSQLText & ", " & "[" & rstFROM.Fields(i).Name & "]"
                VrednostKolone = rstFROM.Fields(KolonaZaExport(i))                                     'VrednostKolone = rstFROM.Fields(i)
                If Not IsNull(VrednostKolone) Then
                  VrednostKolone = Replace(rstFROM.Fields(KolonaZaExport(i)), "'", " ")                        'VrednostKolone = Replace(rstFROM.Fields(i), "'", " ")
                  If TipKoloneZaExport(i) = dbText Then
                    VrednostKolone = Left(VrednostKolone, SizeKoloneZaExport(i))
                  ElseIf TipKoloneZaExport(i) = dbDate Then
                    VrednostKolone = SQLFormatDatumIVreme(VrednostKolone, False)
                  End If
                End If
                
                stSQLTextValues = stSQLTextValues & ", " & "'" & VrednostKolone & "'"
           
        Next i
        stSQLText = stSQLText & ")"
        stSQLTextValues = stSQLTextValues & ")"
        
        stSQLText = stSQLText & stSQLTextValues
        'Debug.Print stSQLText
        
        On Error Resume Next
        pCNN.Execute stSQLText
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
        rstFROM.MoveNext
 Wend
 
Exit_Point:
On Error Resume Next
 'If IsAutoNumber(UTabelu) And IsAutoNumber(IzTabele) Then
 'If ADO_IsIdentity(F_CNNString("SQL"), UTabelu) Then
 '   pCNN.Execute "SET IDENTITY_INSERT [" & UTabelu & "] OFF"
 'End If
 
 pCNN.Close
 rstFROM.Close
 Set rstFROM = Nothing
 
 ExportujTabeluUSQLBezIdentityKolone = retValOk
 'MsgBox "EXPORT:" & vbCrLf & "Uspešno = " & Ispravno & vbCrLf & "NEUspešno = " & NEIspravno, vbInformation, "QBigTeh"
 '08-01-2022
 MsgBox "EXPORT " & IzTabele & " => " & UTabelu & ":" & vbCrLf & "Uspešno = " & Ispravno & vbCrLf & "NEUspešno = " & NEIspravno, vbInformation, "QBigTeh"
Exit Function

Err_Point:
    retValOk = False
    MsgBox err.Description
    Resume Exit_Point
End Function

