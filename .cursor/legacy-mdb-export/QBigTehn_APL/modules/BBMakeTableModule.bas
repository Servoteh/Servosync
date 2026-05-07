Attribute VB_Name = "BBMakeTableModule"
Option Compare Database
Option Explicit

Public Sub BBMakeTableFromQuery(imeTabele As String, ImeUpita As String, Optional UBazi, Optional ForsirajLink As Boolean = True)

On Error GoTo err_Sub

 Dim stSQL As String
 Dim ImeBaze As String
 If IsMissing(UBazi) Then
  ImeBaze = BBCFG.BB_TMP_FileName 'BazaZaTip("TMP") '"D:\AcBaze\DukicServis\BigBit_TG\BB_Tmp.mdb"
 Else
  ImeBaze = UBazi
 End If
 
 If Not FileExists(ImeBaze) Then
  MsgBox "Ne postoji baza " & ImeBaze, vbCritical, "QMegaTeh"
  Exit Sub
 End If
 
 If Not PostojiQuery(ImeUpita) Then
  MsgBox "Ne postoji upit " & ImeUpita, vbCritical, "QMegaTeh"
  Exit Sub
 End If
 
 stSQL = "SELECT [" & ImeUpita & "].* INTO " & imeTabele & "  IN '" & ImeBaze & "' FROM [" & ImeUpita & "];"
 
 DoCmd.SetWarnings False
 DoCmd.Hourglass True
 DoCmd.RunSQL stSQL
 
 If ForsirajLink Then
  Call ForsirajNoviLinkZaTabelu(imeTabele, imeTabele, ";DATABASE=" & ImeBaze)
 End If
 
Exit_Sub:
  DoCmd.Hourglass False
 DoCmd.SetWarnings True
 
 Exit Sub

err_Sub:
 BBErrorMSG err, "BBMakeTable"
 Resume Exit_Sub:
End Sub

Public Function BBMakeTable(imeTabele As String, Optional PrvoPolje As DAO.Field, Optional UBazi, Optional ObrisiAkoPostoji As Boolean = False) As Boolean
'"C:\SHARES\AcBaze\Testovi\BB_Tmp.mdb"
On Error GoTo err_Func
    
 Dim retVal As Boolean
 Dim ImeBaze As String
 
 Dim NovaBaza As DAO.Database
 Dim NovaTabela As DAO.TableDef
 Dim NovoPolje As DAO.Field
 
 retVal = True
 
 If IsMissing(UBazi) Then
  ImeBaze = BBCFG.BB_TMP_FileName 'BazaZaTip("TMP") '"D:\AcBaze\DukicServis\BigBit_TG\BB_Tmp.mdb"
 Else
  ImeBaze = UBazi
 End If
 
 If Not FileExists(ImeBaze) Then
  MsgBox "Ne postoji baza " & ImeBaze, vbCritical, "QMegaTeh"
  retVal = False
  BBMakeTable = retVal
  Exit Function
 Else
  Set NovaBaza = DAO.OpenDatabase(ImeBaze)
 End If

 If PostojiTabelaUBazi(imeTabele, NovaBaza) Then
  If ObrisiAkoPostoji Then
    NovaBaza.TableDefs.Delete imeTabele
  Else
    MsgBox "U bazi " & ImeBaze & " postoji tabela " & imeTabele, vbExclamation, "QMegaTeh"
    GoTo exit_Func
  End If
 End If

 Set NovaTabela = NovaBaza.CreateTableDef(imeTabele)
 'Ne može da se kreira tabela ako nema bar jedno polje
 If IsMissing(PrvoPolje) Or (PrvoPolje Is Nothing) Then  'Nikad nije missing
    Set NovoPolje = NovaTabela.CreateField("ID", dbLong, 4)
 Else
    Set NovoPolje = PrvoPolje
 End If
 
 'Ne može da se kreira tabela ako nema bar jedno polje
 NovaTabela.Fields.Append NovoPolje
 
 NovaBaza.TableDefs.Append NovaTabela

exit_Func:
On Error Resume Next
 NovaBaza.Close
 Set NovaBaza = Nothing
 Set NovaTabela = Nothing
 Set NovoPolje = Nothing

  BBMakeTable = retVal
 
Exit Function
 
err_Func:
 retVal = False
 BBErrorMSG err, "BBMakeTable"
 Resume exit_Func:
End Function

Public Function BBMakeTableDefsForAllTables(ImeBaze As String, Optional ObrisiAkoPostoji As Boolean = False) As Boolean
'"C:\SHARES\AcBaze\Testovi\BB_Tmp.mdb"
On Error GoTo err_Func
    
 Dim retVal As Boolean
 Dim imeTabele As String
 
 Dim Baza As DAO.Database
 Dim NovaTabela As DAO.TableDef
 Dim NovoPolje As DAO.Field
 Dim NoviIndex As DAO.Index
 
 Dim rstTable As DAO.Recordset
 Dim tblDef As DAO.TableDef
 Dim fieldDef As DAO.Field
 Dim propDef As DAO.Properties
 
 retVal = True
 
 If Not FileExists(ImeBaze) Then
  
   If BBPitanje("Ne postoji baza " & ImeBaze & vbCrLf & "Da li želite da je kreiram?") Then
    retVal = BBCreateDatabase(ImeBaze)
    If retVal Then
     Set Baza = DAO.OpenDatabase(ImeBaze)
    Else
     BBMsgBox_BigBit "Ne može da se kreira baza " & ImeBaze
     retVal = False
     BBMakeTableDefsForAllTables = retVal
     Exit Function
    End If
   Else
    retVal = False
    BBMakeTableDefsForAllTables = retVal
    Exit Function
   End If
 Else
  Set Baza = DAO.OpenDatabase(ImeBaze)
 End If
 
 
'***************************************************************
'Poèetak pravlenja tabele svih tabela
'***************************************************************
 imeTabele = "BBTables"
 
 If PostojiTabelaUBazi(imeTabele, Baza) Then
  If ObrisiAkoPostoji Then
    Baza.TableDefs.Delete imeTabele
  Else
    MsgBox "U bazi " & ImeBaze & " postoji tabela " & imeTabele, vbExclamation, "QMegaTeh"
    retVal = False
    GoTo exit_Func
  End If
 End If

 Set NovaTabela = Baza.CreateTableDef(imeTabele)
 
 Set NovoPolje = NovaTabela.CreateField("ImeTabele", dbText, 64)
    ' NovoPolje.
 NovaTabela.Fields.Append NovoPolje
 
 Set NovoPolje = NovaTabela.CreateField("CNNString", dbText, 255)
     NovoPolje.AllowZeroLength = True
 NovaTabela.Fields.Append NovoPolje
 
 Set NoviIndex = NovaTabela.CreateIndex("PrimaryKey")
     NoviIndex.Fields.Append NoviIndex.CreateField("ImeTabele")
     NoviIndex.Primary = True
     NoviIndex.Required = True
     
 NovaTabela.Indexes.Append NoviIndex
 
 Baza.TableDefs.Append NovaTabela
 
 Set rstTable = Baza.OpenRecordset(imeTabele, RecordsetTypeEnum.dbOpenTable)
 
 For Each tblDef In CurrentDb.TableDefs
  If (tblDef.Attributes And dbSystemObject) = 0 Then
     rstTable.AddNew
     rstTable!imeTabele = tblDef.Name
     rstTable!CNNString = tblDef.Connect
     rstTable.Update
  Else
   '  MsgBox tblDef.Name
  End If
 Next
 rstTable.Close
 Set rstTable = Nothing
'***************************************************************
'Zavšeno pravlenje tabele svih tabela
'***************************************************************
'***************************************************************
'Poèetak pravlenja tabele svih polja u tabeli
'***************************************************************
 imeTabele = "BBTables_Fields"
 
 If PostojiTabelaUBazi(imeTabele, Baza) Then
  If ObrisiAkoPostoji Then
    Baza.TableDefs.Delete imeTabele
  Else
    MsgBox "U bazi " & ImeBaze & " postoji tabela " & imeTabele, vbExclamation, "QMegaTeh"
    retVal = False
    GoTo exit_Func
  End If
 End If

 Set NovaTabela = Baza.CreateTableDef(imeTabele)
 
 Set NovoPolje = NovaTabela.CreateField("ImeTabele", dbText, 64)
    ' NovoPolje.
 NovaTabela.Fields.Append NovoPolje
 
 Set NovoPolje = NovaTabela.CreateField("ImePolja", dbText, 64)
     NovoPolje.AllowZeroLength = False
 NovaTabela.Fields.Append NovoPolje
 
 Set NovoPolje = NovaTabela.CreateField("Type", dbLong, 4)
 NovaTabela.Fields.Append NovoPolje
 
 Set NovoPolje = NovaTabela.CreateField("Size", dbInteger, 4)
 NovaTabela.Fields.Append NovoPolje
 
 Set NovoPolje = NovaTabela.CreateField("DefaultValue", dbText, 255)
     NovoPolje.AllowZeroLength = True
 NovaTabela.Fields.Append NovoPolje
 
 Set NovoPolje = NovaTabela.CreateField("AllowZeroLength", dbBoolean, 1)
 NovaTabela.Fields.Append NovoPolje
 
  Set NovoPolje = NovaTabela.CreateField("Required", dbBoolean, 1)
 NovaTabela.Fields.Append NovoPolje
 
 Set NoviIndex = NovaTabela.CreateIndex("PrimaryKey")
     NoviIndex.Fields.Append NoviIndex.CreateField("ImeTabele")
     NoviIndex.Fields.Append NoviIndex.CreateField("ImePolja")
     NoviIndex.Primary = True
     NoviIndex.Required = True
     
 NovaTabela.Indexes.Append NoviIndex
 
 Baza.TableDefs.Append NovaTabela
 
 Set rstTable = Baza.OpenRecordset(imeTabele, RecordsetTypeEnum.dbOpenTable)
 
 For Each tblDef In CurrentDb.TableDefs
  If (tblDef.Attributes And dbSystemObject) = 0 Then
     For Each fieldDef In tblDef.Fields
         rstTable.AddNew
         rstTable!imeTabele = tblDef.Name
         rstTable!ImePolja = fieldDef.Name
         rstTable!Type = fieldDef.Type
         rstTable!Size = fieldDef.Size
         rstTable!DefaultValue = fieldDef.DefaultValue
         rstTable!AllowZeroLength = fieldDef.AllowZeroLength
         rstTable!Required = fieldDef.Required

         rstTable.Update
     Next
  Else
   '  MsgBox tblDef.Name
  End If
 Next
 rstTable.Close
 Set rstTable = Nothing
 Set fieldDef = Nothing
'***************************************************************
'Zavšeno pravlenje tabele svih polja u tabeli
'***************************************************************

'***************************************************************
'Poèetak pravlenja tabele svih propertisa za sva polja u svim tabelama
'***************************************************************
 imeTabele = "BBTables_Fields_Properties"
 
 If PostojiTabelaUBazi(imeTabele, Baza) Then
  If ObrisiAkoPostoji Then
    Baza.TableDefs.Delete imeTabele
  Else
    MsgBox "U bazi " & ImeBaze & " postoji tabela " & imeTabele, vbExclamation, "QMegaTeh"
    retVal = False
    GoTo exit_Func
  End If
 End If

 Set NovaTabela = Baza.CreateTableDef(imeTabele)
 
 Set NovoPolje = NovaTabela.CreateField("ImeTabele", dbText, 64)
    ' NovoPolje.
 NovaTabela.Fields.Append NovoPolje
 
 Set NovoPolje = NovaTabela.CreateField("ImePolja", dbText, 64)
     NovoPolje.AllowZeroLength = False
 NovaTabela.Fields.Append NovoPolje
 
 Set NovoPolje = NovaTabela.CreateField("Properties", dbText, 64)
 NovaTabela.Fields.Append NovoPolje
  
 Set NovoPolje = NovaTabela.CreateField("Value", dbText, 255)
     NovoPolje.AllowZeroLength = True
 NovaTabela.Fields.Append NovoPolje
 
 Set NoviIndex = NovaTabela.CreateIndex("PrimaryKey")
     NoviIndex.Fields.Append NoviIndex.CreateField("ImeTabele")
     NoviIndex.Fields.Append NoviIndex.CreateField("ImePolja")
     NoviIndex.Fields.Append NoviIndex.CreateField("Properties")
     NoviIndex.Primary = True
     NoviIndex.Required = True
     
 NovaTabela.Indexes.Append NoviIndex
 
 Baza.TableDefs.Append NovaTabela
 
 Set rstTable = Baza.OpenRecordset(imeTabele, RecordsetTypeEnum.dbOpenTable)
 
 Dim i As Integer
 For Each tblDef In CurrentDb.TableDefs
  If (tblDef.Attributes And dbSystemObject) = 0 Then
     For Each fieldDef In tblDef.Fields
         
         On Error Resume Next
         
         For i = 0 To fieldDef.Properties.Count
            rstTable.AddNew
            rstTable!imeTabele = tblDef.Name
            rstTable!ImePolja = fieldDef.Name
            rstTable!Properties = fieldDef.Properties(i).Name
            rstTable!Value = fieldDef.Properties(i).Value
            rstTable.Update
         Next
         
         On Error GoTo err_Func
         
     Next
  Else
   '  MsgBox tblDef.Name
  End If
 Next
 rstTable.Close
 Set rstTable = Nothing
 Set fieldDef = Nothing
'***************************************************************
'Zavšeno pravlenje tabele svih propertisa za sva polja u svim tabelama
'***************************************************************
 
exit_Func:
On Error Resume Next
  rstTable.Close
  Set rstTable = Nothing
 Baza.Close
 Set Baza = Nothing
 Set NovaTabela = Nothing
 Set NovoPolje = Nothing
 Set tblDef = Nothing
 
  BBMakeTableDefsForAllTables = retVal
 
Exit Function
 
err_Func:
 retVal = False
 BBErrorMSG err, "BBMakeTable"
 Resume exit_Func:
End Function
Public Sub BBCreateTableFromSyncDB(imeTabele As String, ImeBaze As String, SyncTblName As String, SynchDBName As String)
 Dim SynchDB As DAO.Database
 Dim rstFields As DAO.Recordset
 
 Set SynchDB = OpenDatabase(SynchDBName)
 Set rstFields = SynchDB.OpenRecordset("BBTables_Fields", RecordsetTypeEnum.dbOpenTable)
 
 
End Sub
