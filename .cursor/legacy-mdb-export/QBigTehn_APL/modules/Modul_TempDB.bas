Attribute VB_Name = "Modul_TempDB"
Option Compare Database
Option Explicit


Public Function KreirajTmpTabeluUTmpBazi(TableName As String, QueryName As String, Optional TmpDBName As String, Optional ForsirajNoviLink As Boolean = True, Optional ByRef recaff As Long, Optional IndexOnField1 As String, Optional IndexOnField2 As String, Optional IndexOnField3 As String) As Boolean
   KreirajTmpTabeluUTmpBazi = PripremiTMPTabeluUTMPBazi(TableName, QueryName, TmpDBName, ForsirajNoviLink, recaff, IndexOnField1, IndexOnField2, IndexOnField3)
End Function
Public Function PripremiTMPTabeluUTMPBazi(TableName As String, QueryName As String, Optional TmpDBName As String, Optional ForsirajNoviLink As Boolean = True, Optional ByRef recaff As Long, Optional IndexOnField1 As String, Optional IndexOnField2 As String, Optional IndexOnField3 As String) As Boolean
On Error GoTo Err_Point
 Dim retValOk As Boolean
 Dim stSQL As String
 Dim imeTMPbaze As String
 Dim BigBitDB As DAO.Database
 Dim TempDB As DAO.Database
 Dim OkCreateIndex As Boolean
 'Dim tmpQuery As QueryDef

 retValOk = True
 If IsMissing(TmpDBName) Or Nz(TmpDBName, "") = "" Then
   imeTMPbaze = BBCFG.BB_TMP_FileName
 Else
   imeTMPbaze = TmpDBName
 End If

 'TableName = "tmp_B_ZaliheArtPoMagIProd"
 'QName = "B_ZaliheArtPoMagIProd"
  If PostojiQuery(QueryName) Or PostojiTabelaUBazi(QueryName, CurrentDb) Then
   stSQL = "SELECT [" & QueryName & "].* INTO [" & TableName & "] IN '" & imeTMPbaze & "' FROM [" & QueryName & "];"
  Else
   stSQL = "SELECT Q.* INTO [" & TableName & "] IN '" & imeTMPbaze & "' FROM (" & QueryName & ") as Q;"
   'stSQL = "SELECT Q.*  FROM (SELECT * FROM ftMPZalihe(DEFAULT,DEFAULT,'0','0',DEFAULT,'2017-09-24','4402',DEFAULT,null)) as Q;"
  End If
  
 DoCmd.Hourglass True
  
  Set TempDB = OpenDatabase(imeTMPbaze)
  'ako tabela postoji brišemo je
  If PostojiTabelaUBazi(TableName, TempDB) Then
        On Error Resume Next
          TempDB.Execute ("DROP TABLE [" & TableName & "];")
          If err Then
             BBErrorMSG err
             err.Clear
             retValOk = False
             GoTo Exit_Point:
          End If
        On Error GoTo Err_Point
  End If
  
  Set BigBitDB = CurrentDb
  'Set tmpQuery = BigBitDB.CreateQueryDef(stSQL)
  'tmpQuery.Connect = BBCFG.CNNString
  'tmpQuery.Execute
  
  On Error Resume Next
  BigBitDB.Execute stSQL, dbSeeChanges
  If err Then 'verovatno ima parametara
   err.Clear
   On Error GoTo Err_Point
   DoCmd.SetWarnings False
    DoCmd.RunSQL stSQL
   DoCmd.SetWarnings True
  End If
  
  recaff = BigBitDB.RecordsAffected ' !!!OvoNeRadi!!!
   
  OkCreateIndex = True
  If Nz(IndexOnField1, "") <> "" Then
   OkCreateIndex = OkCreateIndex And CreateIndex(IndexOnField1, TableName, imeTMPbaze, False, True)
  End If
  If Nz(IndexOnField2, "") <> "" Then
   OkCreateIndex = OkCreateIndex And CreateIndex(IndexOnField2, TableName, imeTMPbaze, False, True)
  End If
  If Nz(IndexOnField3, "") <> "" Then
   OkCreateIndex = OkCreateIndex And CreateIndex(IndexOnField3, TableName, imeTMPbaze, False, True)
  End If
  
 If ForsirajNoviLink Then
  retValOk = retValOk And ForsirajNoviLinkZaTabelu(TableName, TableName, ";DATABASE=" & imeTMPbaze, , , True)
 End If
Exit_Point:
  On Error Resume Next
  TempDB.Close
  BigBitDB.Close
  
  DoCmd.Hourglass False
  DoCmd.SetWarnings True
  PripremiTMPTabeluUTMPBazi = retValOk
 Exit Function

Err_Point:
 BBErrorMSG err, "PripremiTmpTabeluUTmpBazi"
 retValOk = False
 Resume Exit_Point:
 
'   If DBEngine.Errors.Count > 0 Then
'      For Each errloop In DBEngine.Errors
'         MsgBox "Error number: " & errloop.Number & vbCr & _
'            errloop.Description
'      Next errloop
'   End If
End Function
Public Function CreateIndex(FieldName As String, TableName As String, DBName As String, Optional UNIQUE As Boolean = False, Optional SilentMSG As Boolean = True)
'CREATE [ UNIQUE ] INDEX index ON table (field [ASC|DESC][, field [ASC|DESC], …]) [WITH { PRIMARY | DISALLOW NULL | IGNORE NULL }]
' CreateIndex("Sifra artikla","tmp_MPPopis","C:\SHARES\VuleMarket\QBigBit\BB_TMP.mdb")
 On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim dbs As DAO.Database
    Dim SQLCmd As String
    
    retValOk = True
    SQLCmd = "CREATE"
    If UNIQUE Then
       SQLCmd = SQLCmd & " UNIQUE"
    End If
    SQLCmd = SQLCmd & " INDEX [inx_" & FieldName & "] ON [" & TableName & "]([" & FieldName & "]);"
    
    Set dbs = OpenDatabase(DBName)
    dbs.Execute SQLCmd
    
Exit_Point:
 On Error Resume Next
    dbs.Close
    CreateIndex = retValOk
Exit Function

Err_Point:
 If Not SilentMSG Then
  BBErrorMSG err, "CreateIndex(" & FieldName & ", " & TableName & ", " & DBName & ")"
 End If
 retValOk = False
 Resume Exit_Point:
End Function

'*******************************************************
Public Function KreirajTMPTabeluUTMPBazi_IzBBQueryDef(TableName As String, BBQueryName As String, Optional TmpDBName As String, Optional ForsirajNoviLink As Boolean = True, Optional ByRef recaff As Long, Optional IndexOnField1 As String, Optional IndexOnField2 As String, Optional IndexOnField3 As String) As Boolean
'26-11-2021
On Error GoTo Err_Point
 Dim retValOk As Boolean
 Dim stSQL As String

    stSQL = PassTroughQueryEvalAllPar(BBQueryName)
    retValOk = PassTroughQuerySave(BBQueryName, stSQL, CNN_CurrentDataBase)
    If retValOk Then
       retValOk = KreirajTmpTabeluUTmpBazi(TableName, BBQueryName, TmpDBName, ForsirajNoviLink, recaff, IndexOnField1, IndexOnField2, IndexOnField3)
    Else
       retValOk = False
    End If
 
Exit_Point:
  On Error Resume Next
  KreirajTMPTabeluUTMPBazi_IzBBQueryDef = retValOk
 Exit Function

Err_Point:
 BBErrorMSG err, "KreirajTMPTabeluUTMPBazi_IzBBQueryDef"
 retValOk = False
 Resume Exit_Point:
End Function
