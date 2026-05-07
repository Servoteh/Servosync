Attribute VB_Name = "LIB_DAOLinkTable"
Option Compare Database
Option Explicit
Public Function F_CheckLink(strTable As String, Optional strDB As String = "") As Boolean
    
    ' Checks the Link for the named table.
    ' (Actually, CheckLink also returns False if
    '  table doesn't exist.)
    '
    ' From Access 2000 Developer's Handbook, Volume II
    ' by Litwin, Getz, and Gilbert (Sybex)
    ' Copyright 1999.  All rights reserved.
    '
    ' In:
    '    strTable - table to check
    ' Out:
    '    Return Value - True if successful; False otherwise

Dim retVal As Boolean
    On Error Resume Next

    Dim varRet As Variant
    
    ' Check for failure. If can't determine the name of
    ' the first field in the table, link must be bad.
    varRet = CurrentDb.TableDefs(strTable).Fields(0).Name
    If err.Number <> 0 Then
    '******************************************************
    'Modifikovano: 08.01.2019.
    'mozda postoji view/query koji radi kao tabela
        retVal = (CurrentDb.QueryDefs(strTable).Name = strTable)
    Else
        'retval = True 'Ovo važi SAMO ako je link ka Access bazi!!!!
        'modifikovano 04.12.2019.
        'ako je ODBC konekcija onda BigBit zna ime kolone ali to ne znaci da je konekcija ispravna!!
        'pa mora da se proveri (modifikovano 04.12.2019.)
        If IsLinkedTableAccess(strTable) Then
         retVal = True
        Else
         retVal = True 'ipak za sada, jer "Radni fajlovi" nisu upisani u BB_FIT -------retval = SysCheckLink(strTable)
        End If
    End If
  If strDB <> "" And retVal Then
    retVal = (CurrentDb.TableDefs(strTable).Connect = strDB)
  End If
  
  F_CheckLink = retVal
End Function
Public Function IsLinkedTableAccess(TableName As String) As Boolean
    Dim retVal As Boolean
    retVal = False
    On Error Resume Next
    retVal = (CurrentDb.TableDefs(TableName).Attributes And dbAttachedTable)
    IsLinkedTableAccess = retVal
End Function
Public Function IsLinkedODBC(TableName As String) As Boolean
    Dim retVal As Boolean
    retVal = False
    On Error Resume Next
    retVal = (CurrentDb.TableDefs(TableName).Attributes And dbAttachedODBC)
    IsLinkedODBC = retVal
End Function
Public Function LinkTableODBC(ByVal TableName As String, ByVal SourceTableName As String, ByVal CNNString As String, Optional UserName As String, Optional Password As String) As Boolean
On Error GoTo err_LinkODBC
Dim retValOk As Boolean
Dim tdf As DAO.TableDef
Dim BigBit As DAO.Database
retValOk = True
    
    'DoCmd.TransferDatabase acLink, "ODBC Database", "ODBC;DSN=DataSource1;UID=User2;PWD=www;LANGUAGE=us_english;DATABASE=pubs", acTable, "Authors", "dboAuthors"
    If Nz(UserName, "") <> "" Then
     CNNString = CNNString & ";UID=" & UserName
    End If
    If Nz(Password, "") <> "" Then
     CNNString = CNNString & ";PWD=" & Password
    End If
    DoCmd.TransferDatabase acLink, "ODBC Database", CNNString, acTable, SourceTableName, TableName
    'Ovo sledeæe mi baš i nije potpuno jasno zašto
    'ali sam primetio da uvek bude prvo konektovan sa Trusted_Connection=Yes
    'pa tek kod drugog prolaza zapamti UID i PWD    !!??
    'zato idu sledeæe linije koda
    Set BigBit = CurrentDb
    Set tdf = BigBit.TableDefs(TableName)
    tdf.Connect = CNNString
    tdf.RefreshLink
    '*****************************************************************
     
exit_LinkODBC:
  On Error Resume Next
  LinkTableODBC = retValOk
  Set BigBit = Nothing
  Set tdf = Nothing
Exit Function

err_LinkODBC:
 retValOk = False
 BBErrorMSG err, "LinkTableODBC"
 Resume exit_LinkODBC
End Function
Public Function LinkTableTXT(ByVal TableName As String, ByVal SourceTableName As String, ByVal CNNString As String, Optional UserName As String, Optional Password As String) As Boolean
'Text;DSN=Txt_Link_001_LinkSpecification;FMT=Delimited;HDR=NO;IMEX=2;CharacterSet=437;DATABASE=E:\SHARES\SuperSpace\IMPORT
On Error GoTo err_LinkTXT
Dim retValOk As Boolean
'Dim TDF As DAO.TableDef
'Dim BigBit As DAO.Database

retValOk = True

    DoCmd.TransferText acLinkDelim, TableName & "_Specification", TableName, CNNString, True

exit_LinkTXT:
  On Error Resume Next
  LinkTableTXT = retValOk
'  Set BigBit = Nothing
'  Set TDF = Nothing
Exit Function

err_LinkTXT:
 retValOk = False
 BBErrorMSG err, "LinkTableTXT"
 Resume exit_LinkTXT
End Function
Public Function LinkTableAccess(ByVal TableName As String, ByVal SourceTableName As String, ByVal CNNString As String, Optional UserName As String, Optional Password As String) As Boolean
On Error GoTo err_LinkAccess
Dim retValOk As Boolean
Dim DatabaseName As String

retValOk = True
    If CNNString Like ";DATABASE=*" Then
     DatabaseName = Right$(CNNString, Len(CNNString) - 10)
    Else 'CnnString je veæ DatabaseName
     DatabaseName = CNNString
    End If
    DoCmd.TransferDatabase acLink, "Microsoft Access", DatabaseName, acTable, SourceTableName, TableName

exit_LinkAccess:
  LinkTableAccess = retValOk
Exit Function

err_LinkAccess:
 retValOk = False
 BBErrorMSG err, "LinkTableAccess"
 Resume exit_LinkAccess
End Function

Public Function LIB_PostojiTabelaUBazi(ByVal imeTabele As String, ByRef UBazi As DAO.Database) As Boolean
On Error GoTo err_ObradaGreske
    Dim retVal As Boolean
    'Dim UBazi As DAO.Database
    retVal = False
    'Set UBazi = DAO.OpenDatabase(ImeBaze)
    
    retVal = (UBazi.TableDefs(imeTabele).Name = imeTabele)
    
    
exit_PosleGreske:
    On Error Resume Next
    'UBazi.Close
    'Set UBazi = Nothing
    LIB_PostojiTabelaUBazi = retVal
Exit Function

err_ObradaGreske:
    retVal = False
    If err.Number <> 3265 Then
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Function LIB_PostojiTabelaUBazi se prekida.", vbCritical, "QMegaTeh"
    End If
    Resume exit_PosleGreske
End Function
Function ForsirajNoviLinkZaTabelu(ByVal TableName As String, ByVal SourceTableName As String, ByVal NewCnnString As String, Optional UserName As String, Optional Password As String, Optional ByRef Silent As Boolean = False) As Boolean
 On Error GoTo ForsirajNoviLinkZaTabelu_Err
 
 Dim tdf As DAO.TableDef
 Dim BigBit As DAO.Database
 Dim retValOk As Boolean
 Dim odgovor As Long
 
 Dim TipLinkovaneTabele As String
 Dim TipNovogLinka As String
 
 retValOk = True
 Set BigBit = CurrentDb
 
 If Not PostojiTabelaUBazi(TableName, BigBit) Then
    If Silent Then
     odgovor = vbYes
    Else
     odgovor = MsgBox("Tabala " & TableName & " ne postoji. Želite da kreiram link?", vbYesNo, "QMegaTeh")
    End If
     
     If odgovor = vbYes Then
       ' Silent = BBPitanje("Da li da uradim forsiranje svih novih linkova bez novih pitanja?")
     Else
      retValOk = False
      ForsirajNoviLinkZaTabelu = retValOk
      Exit Function
     End If
 End If
 
 If PostojiTabelaUBazi(TableName, BigBit) Then
    Set tdf = BigBit.TableDefs(TableName)
    If ((tdf.Attributes And dbAttachedTable) = dbAttachedTable) Then
       If tdf.Connect Like "Text*" Then
        TipLinkovaneTabele = "Text"
       Else
        TipLinkovaneTabele = "Access"
       End If
    ElseIf ((tdf.Attributes And dbAttachedODBC) = dbAttachedODBC) Then
       TipLinkovaneTabele = "ODBC"
    Else
       TipLinkovaneTabele = "UNKNOWN"
    End If
    
    If NewCnnString Like ";DATABASE=*" Then
       TipNovogLinka = "Access"
    ElseIf NewCnnString Like "*ODBC*" Then
       TipNovogLinka = "ODBC"
    ElseIf NewCnnString Like "*TXT" Then
       TipNovogLinka = "Text"
    Else
       TipNovogLinka = "UNKNOWN"
    End If
    
    If TipLinkovaneTabele <> TipNovogLinka Then
      If IsLinkedODBC(TableName) Or IsLinkedTableAccess(TableName) Then
         DoCmd.DeleteObject acTable, TableName
         BigBit.TableDefs.Refresh
      End If
    ElseIf TipLinkovaneTabele = "Text" Then
         DoCmd.DeleteObject acTable, TableName
         BigBit.TableDefs.Refresh
    End If
    
 End If
 
 If Not PostojiTabelaUBazi(TableName, BigBit) Then
      'DoCmd.TransferDatabase acLink, "ODBC Database", TableName, acTable
      'Set tdf = BigBit.CreateTableDef(TableName, dbAttachedODBC, TableName, NewCnnString)
      'BigBit.TableDefs.Append tdf
      If NewCnnString Like "*ODBC*" Then
        retValOk = LinkTableODBC(TableName, SourceTableName, NewCnnString, UserName, Password)
      ElseIf (NewCnnString Like "TEXT*") Or Right(NewCnnString, 4) = ".txt" Then
        retValOk = LinkTableTXT(TableName, SourceTableName, NewCnnString, UserName, Password)
      Else
        retValOk = LinkTableAccess(TableName, SourceTableName, NewCnnString, UserName, Password)
      End If
  GoTo ForsirajNoviLinkZaTabelu_Exit
 
 End If
 
 Set tdf = BigBit.TableDefs(TableName)
 
 If ((tdf.Attributes And dbAttachedTable) = dbAttachedTable) Then 'Access link
     If NewCnnString Like ";DATABASE=*" Then
      tdf.Connect = NewCnnString
     Else
      tdf.Connect = ";DATABASE=" & NewCnnString
     End If
      
      On Error Resume Next
      tdf.RefreshLink 'Ovo je sporo!!!
      retValOk = F_CheckLink(TableName) 'I OVO JE SPORO!!!
      On Error GoTo ForsirajNoviLinkZaTabelu_Err
      
 ElseIf ((tdf.Attributes And dbAttachedODBC) = dbAttachedODBC) Then  'ODBC link
     tdf.Connect = NewCnnString
     tdf.RefreshLink
     retValOk = F_CheckLink(TableName)
 Else
     retValOk = False ' Tabela nije linkovana
 End If
 
ForsirajNoviLinkZaTabelu_Exit:
    On Error Resume Next
    Set BigBit = Nothing
    Set tdf = Nothing
    ForsirajNoviLinkZaTabelu = retValOk
    Exit Function
ForsirajNoviLinkZaTabelu_Err:
    
    BBErrorMSG err, "ForsirajNoviLinkZaTabelu(" & TableName & ")"
    retValOk = False
    Resume ForsirajNoviLinkZaTabelu_Exit

End Function
Public Function PreimenujLinkSvihTabeleIzSQLBaze() As String
On Error GoTo ErrorFunc

Dim StatusOK As Boolean
Dim retVal As String
Dim tdf As TableDef
   
    For Each tdf In CurrentDb.TableDefs
            If tdf.Name Like "dbo*" Then
               tdf.Name = Replace(tdf.Name, "dbo_", "")
            End If
            retVal = retVal & tdf.Name & ";"
    Next tdf
exit_Func:
    PreimenujLinkSvihTabeleIzSQLBaze = retVal
Exit Function
ErrorFunc:
    MsgBox err.Description
    Resume exit_Func
End Function
