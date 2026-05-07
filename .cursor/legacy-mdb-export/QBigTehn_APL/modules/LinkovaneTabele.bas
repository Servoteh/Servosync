Attribute VB_Name = "LinkovaneTabele"
Option Compare Database
Option Explicit
 
' From Access 2000 Developer's Handbook, Volume II
' by Litwin, Getz, and Gilbert (Sybex)
' Copyright 1999.  All rights reserved.

' =================================================
Public Function adhCurrentDBPath() As String
    
    ' Return just the path of the current database,
    ' including the trailing backslash.
    
    ' From Access 2000 Developer's Handbook, Volume II
    ' by Litwin, Getz, and Gilbert (Sybex)
    ' Copyright 1999.  All rights reserved.
    
    ' NOTE: This is only useful if you're using DAO.
    ' If you're using ADO, use the CurrentProject.Path
    ' property instead.
    
    On Error GoTo HandleErrors
    
    Dim intPos As Integer
    Dim strFullPath As String
    
    strFullPath = CurrentDb.Name
    ' Find the last "\" in the file naMe!
    intPos = InStrRev(strFullPath, "\")
    
    ' Given the position of the final "\",
    ' pull of the path portion.
    If intPos > 0 Then
        adhCurrentDBPath = Left$(strFullPath, intPos)
    Else
        adhCurrentDBPath = strFullPath
    End If
    
ExitHere:
    Exit Function
    
HandleErrors:
    Select Case err.Number
        Case Else
            err.Raise err.Number, err.Source, _
             err.Description, err.HelpFile, err.HelpContext
    End Select
    Resume ExitHere
End Function
Function adhVerifyLinks(strDataDatabase As String, _
 strSampleTable As String) As Boolean
    '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ' Na osnovu jedne tabele radi refresh link za sve !!!!!!!!!!!!!!!!!
    ' To u BigBit-u nije dobro
    '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ' Check status of Links and attempt to fix if broken.
    ' If broken, first try the current database directory.
    ' If that fails, present user with file open dialog.
    ' Assumption: all links are to same back-end MDB file.
    '
    ' From Access 2000 Developer's Handbook, Volume II
    ' by Litwin, Getz, and Gilbert. (Sybex)
    ' Copyright 1999. All Rights Reserved.
    '
    ' In:
    '     strDataDatabase - Name of backend data database
    '     strSampleTable  - Name of a linked table to check
    ' Out:
    '     Return Value - True if successful; False otherwise

    On Error GoTo adhVerifyLinksErr

    Dim varReturn As Variant
    Dim strDBDir As String
    Dim strMsg As String
    Dim varFileName As Variant
    Dim intI As Integer
    Dim intNumTables As Integer
    Dim strProcName As String
    Dim strFilter As String
    Dim lngFlags As Long

    Dim db As DAO.Database
    Dim tdf As DAO.TableDef


    strProcName = "adhVerifyLinks"

    ' Verify Links using one sample table.
    varReturn = F_CheckLink(strSampleTable)

    If varReturn Then
        adhVerifyLinks = True
        GoTo adhVerifyLinksDone
    End If
    

    ' Get name of folder where application database
    ' is located.
    strDBDir = adhCurrentDBPath()
    
    If (Dir$(strDBDir & strDataDatabase) <> "") Then
        ' Data database found in current directory.
        varFileName = strDBDir & strDataDatabase
    Else
        ' Let user find data database using common dialog.
        strMsg = "The required file '" & _
         strDataDatabase & _
         "' could not be found." & _
         " You can use the next dialog box" & _
         " to locate the file on your system." & _
         " If you cannot find this file or" & _
         " are unsure what to do choose CANCEL" & _
         " at the next screen and call the" & _
         " database administrator."
        MsgBox strMsg, vbOKOnly + vbCritical, strProcName

        ' Display Open File dialog using
        ' adhCommonFileOpenSave from basFileOpen.
        
        varFileName = IzaberiBazu()
        
        If IsNull(varFileName) Then
            ' User pressed Cancel.
            strMsg = "You can't use this database " & _
             "until you locate '" & strDataDatabase & "'."
            MsgBox strMsg, _
             vbOKOnly + vbCritical, strProcName
            adhVerifyLinks = False
            GoTo adhVerifyLinksDone
        Else
            varFileName = adhTrimNull(stR(varFileName))
        End If
    End If
    
    'Rebuild Links. Check for number of tables first.

    Set db = CurrentDb
    intNumTables = db.TableDefs.Count
    varReturn = SysCmd(acSysCmdInitMeter, _
     "Relinking tables", intNumTables)
    
    ' Loop through all tables. Reattach those
    ' with nonzero-length Connect strings.
    intI = 0

    For Each tdf In db.TableDefs
        ' If connect is blank, its not an Linked table.
        If Len(tdf.Connect) > 0 Then
            intI = intI + 1
            tdf.Connect = ";DATABASE=" & varFileName
    
            ' The RefreshLink might fail if the new
            ' path isn't OK. So trap errors inline.
            On Error Resume Next
            tdf.RefreshLink
            'If one link bad, return False.
            If err.Number <> 0 Then
                adhVerifyLinks = False
                GoTo adhVerifyLinksDone
            End If
        End If

        varReturn = SysCmd(acSysCmdUpdateMeter, intI + 1)
    Next tdf

    adhVerifyLinks = True

adhVerifyLinksDone:
    On Error Resume Next
    varReturn = SysCmd(acSysCmdRemoveMeter)

    Set tdf = Nothing
    Set db = Nothing
    Exit Function

adhVerifyLinksErr:
    Select Case err.Number
    Case Else
        err.Raise err.Number, err.Source, _
         err.Description, err.HelpFile, err.HelpContext
    End Select
    Resume adhVerifyLinksDone
End Function

Sub SeekLocalOrLinkedDAO(ByVal strTable As String, _
 ByVal strCompare As String, _
 Optional ByVal strIndex As String = "PrimaryKey")

    ' Performs DAO Seek on table using the specified
    ' index and search criteria. Works with both
    ' local and linked Access tables.
    '
    ' From Access 2000 Developer's Handbook, Volume II
    ' by Litwin, Getz, and Gilbert. (Sybex)
    ' Copyright 1999. All Rights Reserved.
    '
    ' In:
    '     strTable: Name of table
    '     strCompare: Comma delimited list of search values
    '     strIndex: Name of index. Default is "PrimaryKey"
    ' Out:
    '     Prints to the debug window list of field values
    '     or 'No match was found'.

    Dim db As DAO.Database
    Dim rst As DAO.Recordset
    Dim fld As DAO.Field
    Dim strConnect As String
    Dim strDB As String
    Dim intDBStart As Integer
    Dim intDBEnd As Integer
    
    Const adhcDB = "DATABASE="
    
    Set db = CurrentDb
    ' Grab connection string from tabledef
    strConnect = db.TableDefs(strTable).Connect
    
    ' If connection string is "" then it's a local table.
    ' Otherwise, need to parse database portion of
    ' connection string.
    strDB = ""
    If Len(strConnect) > 0 Then
        intDBStart = InStr(strConnect, adhcDB)
        intDBEnd = InStr(intDBStart + Len(adhcDB), _
         strConnect, ";")
        If intDBEnd = 0 Then intDBEnd = Len(strConnect) + 1
        strDB = Mid(strConnect, intDBStart + Len(adhcDB), _
         intDBEnd - intDBStart)
        
        ' Open the external database.
        Set db = DBEngine.Workspaces(0).OpenDatabase(strDB)
    End If
    
    ' Need to open a table-type recordset to use Seek.
    Set rst = db.OpenRecordset(strTable, dbOpenTable)
    rst.Index = strIndex
    
    rst.Seek "=", strCompare
    
    If Not rst.NoMatch Then
        ' This example is just printing out the
        ' values of each of the fields of the
        ' found record, but you get the idea...
        For Each fld In rst.Fields
            Debug.Print fld.Name & ": " & fld.Value
        Next
    Else
        Debug.Print "No match was found."
    End If
    
    Set fld = Nothing
    rst.Close
    Set rst = Nothing
    If Len(strDB) > 0 Then
        db.Close
    End If
    Set db = Nothing
End Sub

Public Function UzmiSveLinkovaneTabeleIzBaze()
On Error GoTo ErrorFunc

Dim StatusOK As Boolean
Dim db As DAO.Database
Dim tdf As DAO.TableDef
Dim skupljac As DAO.Recordset
Set db = CurrentDb
   
Set skupljac = db.OpenRecordset("SveLinkovaneTabele")
    For Each tdf In db.TableDefs
        If Len(tdf.Connect) > 0 Then
            On Error Resume Next
            tdf.RefreshLink
            If err.Number <> 0 Then StatusOK = False Else StatusOK = True
            On Error GoTo ErrorFunc:
            
            skupljac.AddNew
            skupljac("name") = tdf.Name
            skupljac("SourceTableName") = tdf.SourceTableName
            skupljac("database") = tdf.Connect
            skupljac("Status") = StatusOK
            skupljac.Update
            'Debug.Print tdf.name; tdf.SourceTableName; tdf.Connect
        End If
    Next tdf
exit_Func:
Set skupljac = Nothing
Set tdf = Nothing
Set db = Nothing
Exit Function
ErrorFunc:
    MsgBox err.Description
    Resume exit_Func
End Function
Function ProveriLinkoveSaBazomZaDBName(DBName As String) As Boolean
    

    On Error GoTo ProveriLinkoveErr

    Dim varRet As Variant
    Dim LinkIsOk As Boolean
    Dim linkSTR As String
    Dim db As DAO.Database
    Dim rstTabele, rstbaze As DAO.Recordset
    Dim IDBazeZaDBName As Long
    Dim TableName As String
    

    Set db = CurrentDb
    'Set rstbaze = db.OpenRecordset("Baze", dbOpenDynaset)
    Set rstbaze = db.OpenRecordset(F_Baze_SQL(), dbOpenDynaset)
    
    rstbaze.FindFirst "[Baza] = '" & DBName & "'"
    If rstbaze.NoMatch Then
        MsgBox "Baza " & DBName & " nije definisana u tabeli Baze!", _
        vbCritical + vbOKOnly, "ProveriLinkoveSaBazom"
        varRet = False
        GoTo ProveriLinkoveDone
    End If
    IDBazeZaDBName = rstbaze("IDBaze")
        
    Set rstTabele = db.OpenRecordset("SELECT * FROM BazeiTabele " _
        & "WHERE IDBaze = " & IDBazeZaDBName & " ORDER BY BazeITabele.ID;")
    
    rstTabele.MoveFirst
    varRet = True
    
    While Not rstTabele.EOF
        TableName = rstTabele("Name")
        LinkIsOk = F_CheckLink(TableName) 'adhVerifyLinks(DBName, TableName)
         varRet = varRet And LinkIsOk
         If LinkIsOk Then
            linkSTR = CurrentDb.TableDefs(TableName).Connect
            'linkSTR = Right$(linkSTR, Len(linkSTR) - 10) ' linkstr = ";DATABASE=..." pa "otkidamo" ono sto ne treba
            If ((CurrentDb.TableDefs(TableName).Attributes And dbAttachedODBC) = dbAttachedODBC) Then
                linkSTR = CurrentDb.TableDefs(TableName).Connect
            Else
                linkSTR = Right$(linkSTR, Len(linkSTR) - InStr(1, linkSTR, "DATABASE=") - 8)
            End If
         Else
            linkSTR = "Diconected!"
         End If
        rstTabele.Edit
        rstTabele("CheckLink") = LinkIsOk
        rstTabele("CurrentSourceDataBase") = linkSTR
        rstTabele.Update
        
        rstTabele.MoveNext
    Wend
ProveriLinkoveDone:
    On Error Resume Next
    
    If varRet Then
        ProveriLinkoveSaBazomZaDBName = True
    Else
        ProveriLinkoveSaBazomZaDBName = False
    End If

    Set rstTabele = Nothing
    Set rstbaze = Nothing
    Set db = Nothing
    varRet = SysCmd(acSysCmdRemoveMeter)
    DoCmd.Hourglass False
    On Error GoTo 0
    Exit Function

ProveriLinkoveErr:
    Select Case err
        Case 3021
        'MsgBox "Baza " & DBName & " nema definisanih tabela za proveru linkova."
    Case Else
        MsgBox "Error#" & err.Number & ": " & err.Description, _
         vbOKOnly + vbCritical, "ProveriLinkoveSaBazom"
    End Select
    varRet = False
    Resume ProveriLinkoveDone

End Function
Function ProveriLinkoveSaBazomZaIDBaze(IDBaze As Long) As Boolean
    

    On Error GoTo ProveriLinkoveErr

    Dim varRet As Variant
    Dim LinkIsOk As Boolean
    Dim linkSTR As String
    Dim db As DAO.Database
    Dim rstTabele
    'DIM rstbaze As DAO.Recordset
    'Dim IDBazeZaDBName As Long
    Dim TableName As String
    

    Set db = CurrentDb
    
    
        
    Set rstTabele = db.OpenRecordset("SELECT * FROM BazeiTabele " _
        & "WHERE IDBaze = " & IDBaze & " ORDER BY BazeITabele.ID;")
    
    rstTabele.MoveFirst
    varRet = True
    
    While Not rstTabele.EOF
        TableName = rstTabele("Name")
        LinkIsOk = F_CheckLink(TableName) 'adhVerifyLinks(DBName, TableName)
         varRet = varRet And LinkIsOk
         If LinkIsOk Then
            linkSTR = CurrentDb.TableDefs(TableName).Connect
            'linkSTR = Right$(linkSTR, Len(linkSTR) - 10) ' linkstr = ";DATABASE=..." pa "otkidamo" ono sto ne treba
            If ((CurrentDb.TableDefs(TableName).Attributes And dbAttachedODBC) = dbAttachedODBC) Then
                linkSTR = CurrentDb.TableDefs(TableName).Connect
            ElseIf ((CurrentDb.TableDefs(TableName).Attributes And dbAttachedTable) = dbAttachedTable) Then
                linkSTR = Right$(linkSTR, Len(linkSTR) - InStr(1, linkSTR, "DATABASE=") - 8)
            Else
               linkSTR = "!Lokal table!"
            End If
         Else
            If PostojiTabelaUBazi(TableName, CurrentDb) Then
             linkSTR = "!Diconected!"
            Else
             linkSTR = "!Deleted!"
            End If
         End If
        rstTabele.Edit
        rstTabele("CheckLink") = LinkIsOk
        rstTabele("CurrentSourceDataBase") = linkSTR
        rstTabele.Update
        
        rstTabele.MoveNext
    Wend
ProveriLinkoveDone:
    On Error Resume Next
    
    If varRet Then
        ProveriLinkoveSaBazomZaIDBaze = True
    Else
        ProveriLinkoveSaBazomZaIDBaze = False
    End If

    Set rstTabele = Nothing
    'Set rstbaze = Nothing
    Set db = Nothing
    varRet = SysCmd(acSysCmdRemoveMeter)
    DoCmd.Hourglass False
    On Error GoTo 0
    Exit Function

ProveriLinkoveErr:
    Select Case err
        Case 3021
        'MsgBox "Baza " & DBName & " nema definisanih tabela za proveru linkova."
    Case Else
        MsgBox "Error#" & err.Number & ": " & err.Description, _
         vbOKOnly + vbCritical, "ProveriLinkoveSaBazomZaIDBaze"
    End Select
    varRet = False
    Resume ProveriLinkoveDone

End Function
Function ProveriSveLinkove() As Boolean
    
    On Error GoTo ProveriSveLinkoveErr

    Dim varRet As Variant
    Dim LinkIsOk As Boolean
    Dim db As DAO.Database
    Dim rstbaze As DAO.Recordset
   
    'Set rstBaze = CurrentDb.OpenRecordset("SELECT * FROM Baze;")
    Set db = CurrentDb
    'Set rstbaze = CurrentDb.OpenRecordset("Baze", dbOpenDynaset)
    Set rstbaze = CurrentDb.OpenRecordset(F_Baze_SQL(), dbOpenDynaset)
    
    rstbaze.MoveFirst
    varRet = True
    While (Not rstbaze.EOF)
        LinkIsOk = ProveriLinkoveSaBazomZaIDBaze(rstbaze!IDBaze)
        varRet = varRet And LinkIsOk
        rstbaze.MoveNext
    Wend
    
ProveriSveLinkoveDone:
    On Error Resume Next
    
    If varRet Then
        ProveriSveLinkove = True
    Else
        ProveriSveLinkove = False
    End If

    Set rstbaze = Nothing
    Set db = Nothing
    
    varRet = SysCmd(acSysCmdRemoveMeter)
    DoCmd.Hourglass False
    On Error GoTo 0
    Exit Function

ProveriSveLinkoveErr:
    Select Case err
    Case Else
        MsgBox "Error#" & err.Number & ": " & err.Description, _
         vbOKOnly + vbCritical, "ProveriSveLinkove"
    End Select
    varRet = False
    Resume ProveriSveLinkoveDone

End Function

Public Function RefreshujSveLinkoveUSvimBazama() As Boolean
    
    On Error GoTo Err_Point

    Dim retValOk As Boolean
    Dim RefreshLinkIsOk As Boolean

    Dim rstbaze As DAO.Recordset
    'Set rstbaze = CurrentDb.OpenRecordset("Baze", dbOpenForwardOnly)
    Set rstbaze = CurrentDb.OpenRecordset(F_Baze_SQL(), dbOpenForwardOnly)
  
    retValOk = True
    DoCmd.Hourglass True
    While (Not rstbaze.EOF)
        
        If rstbaze("ForsirajNoviLink") Then
          RefreshLinkIsOk = RefreshujLinkoveZaIDBaze(rstbaze!IDBaze)
        End If
        
        retValOk = retValOk And RefreshLinkIsOk
        
        rstbaze.MoveNext
    Wend
   
    
Exit_Point:
    On Error Resume Next
     DoCmd.Hourglass False
    RefreshujSveLinkoveUSvimBazama = retValOk
    
    rstbaze.Close
    Set rstbaze = Nothing
    
    DoCmd.Hourglass False
    On Error GoTo 0

Exit Function

Err_Point:
     MsgBox "Error#" & err.Number & ": " & err.Description, vbExclamation, "RefreshujSveLinkoveUSvimBazama"
    retValOk = False
    Resume Exit_Point

End Function
Public Function BrojTabelaZaIDBaze(ZaIDBaze As Long) As Integer
  BrojTabelaZaIDBaze = Nz(DCount("*", "BazeITabele", "[IDBaze] = " & ZaIDBaze), 0)
End Function
Public Function ForsirajSveLinkoveUSvimBazama(Optional Silent As Boolean = False) As Boolean
    
    On Error GoTo ProveriSveLinkoveErr

    Dim varRet As Variant
    Dim ForceLinkIsOk As Boolean
    Dim db As DAO.Database
    Dim rstbaze As DAO.Recordset
    Dim MoguDaseForsirajuLinkovi As Boolean
    Dim AccessDBName As String
    
    
    

    'Set rstBaze = CurrentDb.OpenRecordset("SELECT * FROM Baze;")
    Set db = CurrentDb
    'Set rstbaze = db.OpenRecordset("Baze", dbOpenDynaset)
    Set rstbaze = db.OpenRecordset(F_Baze_SQL(), dbOpenDynaset)
    
    rstbaze.MoveFirst
    varRet = True
    While (Not rstbaze.EOF)
        If rstbaze("ForsirajNoviLink") Then
         
         If InStr(rstbaze!Baza, "ODBC;") <> 0 Then
          MoguDaseForsirajuLinkovi = TestConnection(Replace(rstbaze!Baza, "ODBC;", ""), 15) 'Neki ODBC
         Else
          AccessDBName = Replace(rstbaze!Baza, ";DATABASE=", "")
          MoguDaseForsirajuLinkovi = FileExists(AccessDBName)
         End If
         
         If MoguDaseForsirajuLinkovi Then
          ForceLinkIsOk = ForsirajNoveLinkoveZaIDBaze(rstbaze!IDBaze, rstbaze!Baza, Silent)
         Else
          If DirExists(AccessDBName) And BrojTabelaZaIDBaze(rstbaze!IDBaze) = 0 Then
           ForceLinkIsOk = True
          Else
           ForceLinkIsOk = False
          End If
         End If
        Else
         ForceLinkIsOk = True
        End If
        varRet = varRet And ForceLinkIsOk
        rstbaze.MoveNext
    Wend
    
ProveriSveLinkoveDone:
    On Error Resume Next
    ForsirajSveLinkoveUSvimBazama = varRet
    

    Set rstbaze = Nothing
    Set db = Nothing
    
    varRet = SysCmd(acSysCmdRemoveMeter)
    DoCmd.Hourglass False
    On Error GoTo 0
    Exit Function

ProveriSveLinkoveErr:
    Select Case err
    Case Else
        MsgBox "Error#" & err.Number & ": " & err.Description, _
         vbOKOnly + vbCritical, "ProveriSveLinkove"
    End Select
    varRet = False
    Resume ProveriSveLinkoveDone

End Function
Private Function ForsirajNoveLinkove_20102021(DBName As String) As Boolean
    

    On Error GoTo ForsirajNoveLinkoveErr

    Dim varRet As Variant
    Dim LinkIsOk As Boolean
    Dim linkSTR As String
    Dim rstTabele, rstbaze As DAO.Recordset
    Dim IDBazeZaDBName As Long
    Dim TableName As String
    Dim db As DAO.Database
    Dim tdf As DAO.TableDef
    Dim UkTabelaZaForsiranje, UkOk As Long
    Dim NewCnnString As String

    Set db = CurrentDb
    'Set rstbaze = db.OpenRecordset("Baze", dbOpenDynaset)
    Set rstbaze = db.OpenRecordset(F_Baze_SQL(), dbOpenDynaset)
    
    rstbaze.FindFirst "[Baza] = '" & DBName & "'"
    If rstbaze.NoMatch Then
        MsgBox "Baza " & DBName & " nije definisana u tabeli Baze!", _
        vbCritical + vbOKOnly, "ForsirajNoveLinkove"
        varRet = False
        GoTo ForsirajNoveLinkoveDone
    End If
    IDBazeZaDBName = rstbaze("IDBaze")
        
    Set rstTabele = CurrentDb.OpenRecordset("SELECT * FROM BazeITabele " _
        & "WHERE ((IDBaze = " & IDBazeZaDBName & ") AND (SysFitLevel <= " & F_SysFitLevel & ")) ;")
    
    
    
    UkTabelaZaForsiranje = 0
    UkOk = 0
    
    rstTabele.MoveFirst
    varRet = True
    
    While (Not rstTabele.EOF)
        
        TableName = rstTabele("Name")
        Set tdf = db.TableDefs(TableName)
        
        If Len(tdf.Connect) > 0 Then 'Tada je tabela linkovana
                                     'inace ne smemo da radimo refresh
        If (tdf.Attributes And dbAttachedODBC) = dbAttachedODBC Then
            UkTabelaZaForsiranje = UkTabelaZaForsiranje + 1
            NewCnnString = DBName
            
        ElseIf ((tdf.Attributes And dbAttachedTable) = dbAttachedTable) Then 'Access linked table
        'If Len(tdf.Connect) > 0 Then
            UkTabelaZaForsiranje = UkTabelaZaForsiranje + 1
            NewCnnString = tdf.Connect
            NewCnnString = Left$(NewCnnString, InStr(1, NewCnnString, "DATABASE=") - 1)
            NewCnnString = NewCnnString & "DATABASE=" & DBName
        End If
            tdf.Connect = NewCnnString
            ' The RefreshLink might fail if the new
            ' path isn't OK. So trap errors inline.
            On Error Resume Next
            tdf.RefreshLink
            'Ako bar jedan link ima problem vrati False.
            If err.Number <> 0 Then
                varRet = varRet And False
                Select Case err.Number
                 Case 3343
                  MsgBox "Nepoznat format baze na koju forsirate linkove!", vbCritical + vbOKOnly, "QMegaTeh"
                  GoTo ForsirajNoveLinkoveDone
                 Case 3033
                  MsgBox "Nemate prava na promenu linka za tabelu " & TableName, vbCritical + vbOKOnly, "QMegaTeh"
                  Resume Next
                End Select
            Else
                UkOk = UkOk + 1
            End If
            On Error GoTo ForsirajNoveLinkoveErr
        End If
        
        LinkIsOk = F_CheckLink(TableName)
        varRet = varRet And LinkIsOk
        
        linkSTR = CurrentDb.TableDefs(TableName).Connect
        'linkSTR = Right$(linkSTR, Len(linkSTR) - 10) ' linkstr = ";DATABASE=..." pa "otkidamo" ono sto ne treba
        'linkSTR = Right$(linkSTR, Len(linkSTR) - InStr(1, linkSTR, "DATABASE=") - 8)
        
        rstTabele.Edit
        rstTabele("CheckLink") = LinkIsOk
        rstTabele("CurrentSourceDataBase") = linkSTR
        rstTabele.Update
        
        rstTabele.MoveNext
    Wend
ForsirajNoveLinkoveDone:
    On Error Resume Next
    
    If varRet Then
        ForsirajNoveLinkove_20102021 = True
    Else
        ForsirajNoveLinkove_20102021 = False
    End If

    Set rstTabele = Nothing
    Set rstbaze = Nothing
    Set db = Nothing
    varRet = SysCmd(acSysCmdRemoveMeter)
    DoCmd.Hourglass False
    On Error GoTo 0
    Exit Function

ForsirajNoveLinkoveErr:
    Select Case err
    Case 3021
        'MsgBox "Baza " & DBName & " nema definisanih tabela za forsiranje linkova."
    Case 3265
        MsgBox "U bazi" & vbCrLf & DBName & vbCrLf & "ne postoji tabela " & TableName & vbCrLf & "za koju treba forsirati novi link.", vbExclamation, "QMegaTeh"
    Case Else
        MsgBox "Error#" & err.Number & ": " & err.Description, _
         vbOKOnly + vbCritical, "ForsirajNoveLinkove"
    End Select
    varRet = False
    Resume ForsirajNoveLinkoveDone

End Function
Private Function ACC_ForsirajNoveLinkove_NETREBA_20102021(ZaTipBaze As String, NewDbName As String) As Boolean
    

    On Error GoTo ForsirajNoveLinkoveErr

    Dim varRet As Variant
    Dim LinkIsOk As Boolean
    Dim linkSTR As String
    Dim rstTabele, rstbaze As DAO.Recordset
    Dim IDBazeZaTip As Long
    Dim TableName As String
    Dim db As DAO.Database
    Dim tdf As DAO.TableDef
    Dim UkTabelaZaForsiranje, UkOk As Long
    Dim NewCnnString As String

    IDBazeZaTip = IDBazeZaTipBaze(ZaTipBaze)

    Set db = CurrentDb
    'Set rstbaze = db.OpenRecordset("Baze", dbOpenDynaset)
    Set rstbaze = db.OpenRecordset(F_Baze_SQL(ZaTipBaze), dbOpenDynaset)
    If rstbaze.RecordCount = 0 Then
        MsgBox "Tip baze " & ZaTipBaze & " nije definisan u tabeli Baze!", _
        vbCritical + vbOKOnly, "ForsirajNoveLinkove"
        varRet = False
        GoTo ForsirajNoveLinkoveDone
    End If
        
    Set rstTabele = CurrentDb.OpenRecordset("SELECT * FROM BazeITabele " _
        & "WHERE ((IDBaze = " & IDBazeZaTip & ") AND (SysFitLevel <= " & F_SysFitLevel & ")) ;")
    
    
    
    UkTabelaZaForsiranje = 0
    UkOk = 0
    
    rstTabele.MoveFirst
    varRet = True
    
    While (Not rstTabele.EOF)
        
        TableName = rstTabele("Name")
        Set tdf = db.TableDefs(TableName)
        
        If Len(tdf.Connect) > 0 Then 'Tada je tabela linkovana
                                     'inace ne smemo da radimo refresh
        If (tdf.Attributes And dbAttachedODBC) = dbAttachedODBC Then
            UkTabelaZaForsiranje = UkTabelaZaForsiranje + 1
            NewCnnString = NewDbName
            
        ElseIf ((tdf.Attributes And dbAttachedTable) = dbAttachedTable) Then 'Access linked table
        'If Len(tdf.Connect) > 0 Then
            UkTabelaZaForsiranje = UkTabelaZaForsiranje + 1
            NewCnnString = tdf.Connect
            NewCnnString = Left$(NewCnnString, InStr(1, NewCnnString, "DATABASE=") - 1)
            NewCnnString = NewCnnString & "DATABASE=" & NewDbName
        End If
            tdf.Connect = NewCnnString
            ' The RefreshLink might fail if the new
            ' path isn't OK. So trap errors inline.
            On Error Resume Next
            tdf.RefreshLink
            'Ako bar jedan link ima problem vrati False.
            If err.Number <> 0 Then
                varRet = varRet And False
                Select Case err.Number
                 Case 3343
                  MsgBox "Nepoznat format baze na koju forsirate linkove!", vbCritical + vbOKOnly, "QMegaTeh"
                  GoTo ForsirajNoveLinkoveDone
                 Case 3033
                  MsgBox "Nemate prava na promenu linka za tabelu " & TableName, vbCritical + vbOKOnly, "QMegaTeh"
                  Resume Next
                End Select
            Else
                UkOk = UkOk + 1
            End If
            On Error GoTo ForsirajNoveLinkoveErr
        End If
        
        LinkIsOk = F_CheckLink(TableName)
        varRet = varRet And LinkIsOk
        
        linkSTR = CurrentDb.TableDefs(TableName).Connect
        'linkSTR = Right$(linkSTR, Len(linkSTR) - 10) ' linkstr = ";DATABASE=..." pa "otkidamo" ono sto ne treba
        'linkSTR = Right$(linkSTR, Len(linkSTR) - InStr(1, linkSTR, "DATABASE=") - 8)
        
        rstTabele.Edit
        rstTabele("CheckLink") = LinkIsOk
        rstTabele("CurrentSourceDataBase") = linkSTR
        rstTabele.Update
        
        rstTabele.MoveNext
    Wend
ForsirajNoveLinkoveDone:
    On Error Resume Next
    
    If varRet Then
        ACC_ForsirajNoveLinkove_NETREBA_20102021 = True
    Else
        ACC_ForsirajNoveLinkove_NETREBA_20102021 = False
    End If

    Set rstTabele = Nothing
    Set rstbaze = Nothing
    Set db = Nothing
    varRet = SysCmd(acSysCmdRemoveMeter)
    DoCmd.Hourglass False
    On Error GoTo 0
    Exit Function

ForsirajNoveLinkoveErr:
    Select Case err
    Case 3021
        'MsgBox "Baza " & DBName & " nema definisanih tabela za forsiranje linkova."
    Case 3265
        MsgBox "U bazi" & vbCrLf & NewDbName & vbCrLf & "ne postoji tabela " & TableName & vbCrLf & "za koju treba forsirati novi link.", vbExclamation, "QMegaTeh"
    Case Else
        MsgBox "Error#" & err.Number & ": " & err.Description, _
         vbOKOnly + vbCritical, "ForsirajNoveLinkove"
    End Select
    varRet = False
    Resume ForsirajNoveLinkoveDone

End Function
Public Function UpisiNoviCNNStringZaTipBaze(TipBaze As String, NewCnnString As String) As Boolean
'Kreirano: 20-10-2021
On Error GoTo Err_Point

Dim rstbaze As ADODB.Recordset
Dim retVal As Boolean
Dim stMsg As String
       
       
    retVal = True
       
    Set rstbaze = ADO_GetRST(CNN_FIT, F_Baze_SQL(TipBaze), dbOptimistic, adUseClient, adOpenKeyset)
        If rstbaze.RecordCount = 0 Then
            stMsg = "Tip baze " & TipBaze & " nije definisan za SysFITFirma= " & F_FirmaZaBaze() & "!"
            stMsg = stMsg & vbCrLf
            MsgBox stMsg, vbExclamation, "QMegaTeh"
            retVal = False
            GoTo Exit_Point
        End If
    rstbaze("Baza") = NewCnnString
    rstbaze.Update

    
Exit_Point:
On Error Resume Next
    rstbaze.Close
    Set rstbaze = Nothing
    
    UpisiNoviCNNStringZaTipBaze = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "UpisiNoviCNNStringZaTipBaze"
    retVal = False
    Resume Exit_Point
    
End Function
Public Function ForsirajNoveLinkoveZaTipBaze_NETREBA_20102021(TipBaze As String, NewDbName As String) As Boolean
' ? ForsirajNoveLinkoveZaTipBaze("LOKAL_CFG", "C:\SHARES\AcBaze\BigBit\BB_CFG_Lokal.mdb")
'Modifikovano: 19102021
On Error GoTo err_ForsirajNoveLinkoveZaTipBaze
'Dim db As DAO.Database
Dim rstbaze As ADODB.Recordset
Dim varRet As Variant
Dim stMsg As String
    
    
    'Set db = CurrentDb
    Set rstbaze = ADO_GetRST(CNN_FIT, F_Baze_SQL(TipBaze), dbOptimistic, adUseClient, adOpenKeyset)
    
    'rstbaze.FindFirst "[TipBaze] = '" & TipBaze & "'"
    If rstbaze.RecordCount = 0 Then
        stMsg = "Tip baze " & TipBaze & " nije definisan za SysFITFirma= " & F_FirmaZaBaze()
        stMsg = stMsg & vbCrLf & "Forsiranje linkova za " & TipBaze
        stMsg = stMsg & vbCrLf & "na bazu " & NewDbName
        stMsg = stMsg & vbCrLf & "nije izvršeno!"
        MsgBox stMsg, vbExclamation, "QMegaTeh"
        GoTo exit_ForsirajNoveLinkoveZaTipBaze
    End If
    
    'rstbaze.Edit
    rstbaze("Baza") = NewDbName
    rstbaze.Update
    
    'varRet = ACC_ForsirajNoveLinkove(TipBaze, NewDbName)
    varRet = ForsirajNoveLinkoveZaIDBaze(IDBazeZaTipBaze(TipBaze), NewDbName, False)
    
exit_ForsirajNoveLinkoveZaTipBaze:
On Error Resume Next
    rstbaze.Close
    Set rstbaze = Nothing
    
    ForsirajNoveLinkoveZaTipBaze_NETREBA_20102021 = varRet
Exit Function

err_ForsirajNoveLinkoveZaTipBaze:

Select Case err.Number
        Case 3033
        ' User nema prava na promenu linka!
        MsgBox "User " & CurrentUser() & " nema prava na promenu linka za tip baze " & TipBaze, vbCritical, "QMegaTeh"
        Case Else
        BBErrorMSG err, "ForsirajNoveLinkoveZaTipBaze(" & TipBaze & " As String, " & NewDbName & " As String)"
        'MsgBox "Error#" & Err.Number & ": " & Err.Description, _
         vbOKOnly + vbCritical, "ForsirajNoveLinkoveZaTipBaze"
    End Select
    varRet = False
    Resume exit_ForsirajNoveLinkoveZaTipBaze
    
End Function
Public Function ForsirajNoveLinkoveZaIDBaze(IDBaze As Long, CNNString As String, Optional Silent As Boolean = False) As Boolean
On Error GoTo err_ForsirajNoveLinkoveZaIDBaze

Dim rstLinkovaneTabele As DAO.Recordset
Dim varRet As Variant
Dim KorigovanCNNString As String

If CNNString Like "*ODBC*" Then
   KorigovanCNNString = CNNString
ElseIf CNNString Like ";DATABASE=*" Then
   KorigovanCNNString = CNNString
Else
   KorigovanCNNString = ";DATABASE=" & CNNString
End If

    
    Set rstLinkovaneTabele = CurrentDb.OpenRecordset("SELECT * FROM BazeITabele WHERE IDBaze = " & IDBaze, dbOpenDynaset)
    
    While Not rstLinkovaneTabele.EOF
     varRet = ForsirajNoviLinkZaTabelu(rstLinkovaneTabele!Name, rstLinkovaneTabele!SourceTableName, KorigovanCNNString, , , Silent)
     
     'mozda treba
     'CurrentDb.TableDefs(rstLinkovaneTabele!Name).RefreshLink
     
     rstLinkovaneTabele.Edit
     rstLinkovaneTabele!CheckLink = varRet
     If varRet Then
      rstLinkovaneTabele!CurrentSourceDataBase = CurrentDb.TableDefs(rstLinkovaneTabele!Name).Connect
     Else
      rstLinkovaneTabele!CurrentSourceDataBase = "Unknown!"
     End If
     rstLinkovaneTabele.Update
     
     rstLinkovaneTabele.MoveNext
    Wend
exit_ForsirajNoveLinkoveZaIDBaze:
On Error Resume Next
rstLinkovaneTabele.Close
Set rstLinkovaneTabele = Nothing
ForsirajNoveLinkoveZaIDBaze = varRet
Exit Function

err_ForsirajNoveLinkoveZaIDBaze:

Select Case err.Number
        Case 3033
        ' User nema prava na promenu linka!
        MsgBox "User " & CurrentUser() & " nema prava na promenu linka za IDBaze baze " & IDBaze, vbCritical, "QMegaTeh"
        Case Else
        BBErrorMSG err, "ForsirajNoveLinkoveZaIDBaze(" & IDBaze & " As Long, " & CNNString & " As String)"
        'MsgBox "Error#" & Err.Number & ": " & Err.Description, _
         vbOKOnly + vbCritical, "ForsirajNoveLinkoveZaTipBaze"
    End Select
    varRet = False
    Resume exit_ForsirajNoveLinkoveZaIDBaze
    
End Function
Public Function RefreshujLinkoveZaIDBaze(ByVal IDBaze As Long) As Boolean
On Error GoTo Err_Point

Dim rstLinkovaneTabele As DAO.Recordset
Dim retValOk As Boolean

    retValOk = True
    Set rstLinkovaneTabele = CurrentDb.OpenRecordset("SELECT * FROM BazeITabele WHERE IDBaze = " & IDBaze, dbOpenForwardOnly)
    
    While Not rstLinkovaneTabele.EOF
     CurrentDb.TableDefs(rstLinkovaneTabele!Name).RefreshLink
     rstLinkovaneTabele.MoveNext
    Wend
    
Exit_Point:
On Error Resume Next
 rstLinkovaneTabele.Close
 Set rstLinkovaneTabele = Nothing
 RefreshujLinkoveZaIDBaze = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "RefreshujLinkoveZaIDBaze(" & IDBaze & " As Long )" & vbCrLf & "tabela " & rstLinkovaneTabele!Name
 retValOk = False
Resume Exit_Point
    
End Function
Public Function RefreshujLinkoveZaTipBaze(TipBaze As String) As Boolean
  Dim IDBaze
  IDBaze = DLookup("IDBaze", "Baze_Tipovi", "[TipBaze] = '" & TipBaze & "'")
  If IsNumeric(IDBaze) Then
   RefreshujLinkoveZaTipBaze = RefreshujLinkoveZaIDBaze(IDBaze)
  Else
   MsgBox "Ne postoji TipBaze = " & TipBaze, vbExclamation, "QMegaTeh"
   RefreshujLinkoveZaTipBaze = False
  End If
End Function
Public Function ObrisiLinkovaneTabeleZaIDBaze(IDBaze As Long) As Boolean
On Error GoTo err_ObrisiLinkovaneTabeleZaIDBaze
Dim db As DAO.Database
Dim rstbaze As DAO.Recordset
Dim varRet As Variant
Dim Napomena As String
    
    Set db = CurrentDb
    Set rstbaze = db.OpenRecordset("SELECT * FROM BazeITabele WHERE [IDBaze]= " & IDBaze, dbOpenDynaset)
    
    varRet = True
    'rstbaze.MoveFirst 'Nema potrebe
    While Not rstbaze.EOF
     'Debug.Print rstbaze!Name
     'OVDE TREBA OBRISATI LINK
     If PostojiTabelaUBazi(rstbaze!Name, db) Then
        If IsLinkedODBC(rstbaze!Name) Or IsLinkedTableAccess(rstbaze!Name) Then
         'DoCmd.DeleteObject acTable, rstbaze!Name
         db.TableDefs.Delete rstbaze!Name
         Napomena = "Deleted!"
        Else
         Napomena = "Tabela nije linkovana!"
        End If
     Else
         Napomena = "Ne postoji tabela!"
     End If
     rstbaze.Edit
     rstbaze!CurrentSourceDataBase = Napomena
     rstbaze.Update
     rstbaze.MoveNext
    Wend
   
    
exit_ObrisiLinkovaneTabeleZaIDBaze:

 On Error Resume Next
 rstbaze.Close
 Set rstbaze = Nothing
 Set db = Nothing
 ObrisiLinkovaneTabeleZaIDBaze = varRet

Exit Function

err_ObrisiLinkovaneTabeleZaIDBaze:

    BBErrorMSG err, "ObrisiLinkovaneTabeleZaIDBaze"
    varRet = False
    Resume exit_ObrisiLinkovaneTabeleZaIDBaze
    
End Function
Public Function KreirajLinkovaneTabeleZaIDBaze(IDBaze As Long, Optional NewCnnString As String = "") As Boolean
On Error GoTo err_KreirajLinkovaneTabeleZaIDBaze
Dim db As DAO.Database
Dim rstbaze As DAO.Recordset
Dim retValOk As Variant
Dim Napomena As String
    
    Set db = CurrentDb
    Set rstbaze = db.OpenRecordset("SELECT * FROM BazeITabele WHERE [IDBaze]= " & IDBaze, dbOpenDynaset)
    
    retValOk = True
    'rstbaze.MoveFirst 'Nema potrebe
    While Not rstbaze.EOF
     'Debug.Print rstbaze!Name
     'OVDE TREBA KREIRATI LINK
     If Not PostojiTabelaUBazi(rstbaze!Name, db) Then
      
      If Nz(NewCnnString, "") = "" Then NewCnnString = rstbaze!CurrentSourceDataBase
      Napomena = NewCnnString
      If NewCnnString Like "*ODBC*" Then
        retValOk = LinkTableODBC(rstbaze!Name, rstbaze!SourceTableName, NewCnnString)
      Else
        retValOk = LinkTableAccess(rstbaze!Name, rstbaze!SourceTableName, NewCnnString)
      End If
     Else
         Napomena = "Tabela veæ postoji!"
     End If
     rstbaze.Edit
     rstbaze!CurrentSourceDataBase = Napomena
     rstbaze.Update
     rstbaze.MoveNext
    Wend
   
    
exit_KreirajLinkovaneTabeleZaIDBaze:

 On Error Resume Next
 rstbaze.Close
 Set rstbaze = Nothing
 Set db = Nothing
 KreirajLinkovaneTabeleZaIDBaze = retValOk

Exit Function

err_KreirajLinkovaneTabeleZaIDBaze:

    BBErrorMSG err, "KreirajLinkovaneTabeleZaIDBaze"
    retValOk = False
    Resume exit_KreirajLinkovaneTabeleZaIDBaze
    
End Function
Public Function ImeFajlaZaTabelu(Tabela As String) As String
On Error Resume Next
    Dim cnString As String
    Dim retVal As String
    Dim odmesta As Integer
    cnString = CurrentDb.TableDefs(Tabela).Connect
    retVal = Right$(cnString, Len(cnString) - InStr(1, cnString, "DATABASE=") - 8)
    
    ImeFajlaZaTabelu = retVal
End Function

Public Function F_GetConnectionString(TableName As String) As String
'Datum rev: 30.08.2018
 On Error Resume Next
  Dim stRetVal As String
  stRetVal = Nz(CurrentDb.TableDefs(TableName).Connect, "")
  
  If err.Number <> 0 Then
   stRetVal = "Error: " & err.Number & " " & err.Description
  End If
  F_GetConnectionString = stRetVal
End Function
Public Function CreateShuttleLink(SHUTTLE_TableName As String, TableName As String, ByVal SHUTTLE_DBName As String) As Boolean
On Error GoTo Err_Point
 Dim retValOk As Boolean
 Dim BigBit_DB As DAO.Database
 'Dim SHUTTLE_DBName As String
 Dim SHUTTLE_DB As DAO.Database
 Dim tblDef As DAO.TableDef
 Dim SHUTTLE_tblDef As DAO.TableDef
 Dim NovoPolje As DAO.Field
 Dim TrebaObrisati_SHUTTLE_DBName As Boolean
 Dim TrebaObrisati_SHUTTLE_tblDef As Boolean
 
 retValOk = True
 
 If PostojiTabelaUBazi(SHUTTLE_TableName, CurrentDb) Then
  CreateShuttleLink = True
  Exit Function
 End If
 
 SHUTTLE_DBName = Replace(BazaZaTip("SHUTTLE"), ";DATABASE=", "")
 If Not FileExists(SHUTTLE_DBName) Then
   BBCMD_SYS.BBCreateDatabase SHUTTLE_DBName, False
   TrebaObrisati_SHUTTLE_DBName = True
 Else
   TrebaObrisati_SHUTTLE_DBName = False
 End If
 
 Set BigBit_DB = CurrentDb
 Set SHUTTLE_DB = OpenDatabase(SHUTTLE_DBName)
 
 If Not PostojiTabelaUBazi(TableName, SHUTTLE_DB) Then
  Set SHUTTLE_tblDef = SHUTTLE_DB.CreateTableDef(TableName)
  Set NovoPolje = SHUTTLE_tblDef.CreateField("ID", dbInteger)
  SHUTTLE_tblDef.Fields.Append NovoPolje
  SHUTTLE_DB.TableDefs.Append SHUTTLE_tblDef
  SHUTTLE_DB.TableDefs.Refresh
  TrebaObrisati_SHUTTLE_tblDef = True
 Else
  TrebaObrisati_SHUTTLE_tblDef = False
 End If
  
 Set tblDef = BigBit_DB.CreateTableDef(SHUTTLE_TableName)
 tblDef.Connect = ";DATABASE=" & SHUTTLE_DBName
 tblDef.SourceTableName = TableName
 BigBit_DB.TableDefs.Append tblDef
 BigBit_DB.TableDefs.Refresh
 
 If TrebaObrisati_SHUTTLE_tblDef Then
  SHUTTLE_DB.TableDefs.Delete TableName
  SHUTTLE_DB.TableDefs.Refresh
 End If
 
 On Error Resume Next
 If TrebaObrisati_SHUTTLE_DBName Then
  SHUTTLE_DB.Close
  Set SHUTTLE_tblDef = Nothing
  Set SHUTTLE_DB = Nothing
  Kill SHUTTLE_DBName
 End If
 
Exit_Point:

On Error Resume Next
 BigBit_DB.TableDefs.Refresh
 Set NovoPolje = Nothing
 Set tblDef = Nothing
 Set BigBit_DB = Nothing
 
 CreateShuttleLink = retValOk

Exit Function

Err_Point:
 BBErrorMSG err, "CreateShuttleLink"
 retValOk = False
 Resume Exit_Point
End Function
Public Function NapraviFiktivneLinkoveZaSHUTTLE() As Boolean
On Error GoTo Err_Point
Dim BigBitDB As DAO.Database
Dim rstbaze As DAO.Recordset
Dim retValOk As Boolean
Dim IDBaze As Long
Dim SHUTTLE_DBName As String
    
    IDBaze = DLookup("[IDBaze]", "Baze_Tipovi", "[TipBaze]= 'SHUTTLE'")
    SHUTTLE_DBName = BazaZaTip("SHUTTLE")
    
    Set BigBitDB = CurrentDb
    Set rstbaze = BigBitDB.OpenRecordset("SELECT * FROM BazeITabele WHERE [IDBaze]= " & IDBaze, dbOpenDynaset)
    
    retValOk = True
    While Not rstbaze.EOF
     If Not PostojiTabelaUBazi(rstbaze!Name, BigBitDB) Then
        retValOk = retValOk And CreateShuttleLink(rstbaze!Name, rstbaze!SourceTableName, SHUTTLE_DBName)
     End If
     rstbaze.MoveNext
    Wend
   
    
Exit_Point:
 On Error Resume Next
 
 rstbaze.Close
 Set rstbaze = Nothing
 Set BigBitDB = Nothing
 NapraviFiktivneLinkoveZaSHUTTLE = retValOk

Exit Function

Err_Point:

    BBErrorMSG err, "NapraviFiktivneLinkoveZaSHUTTLE"
    retValOk = False
    Resume Exit_Point
End Function
'*************************

Public Function ObrisiNepotrebneLinkovaneTabeleZaFirmu(FirmazaBaze As String) As Boolean
'Modifikovano: 30.12.2018
On Error GoTo err_ObrisiNepotrebneLinkovaneTabeleZaFirmu
Dim db As DAO.Database
Dim tDef As DAO.TableDef
Dim linkedTable As Boolean
Dim trebaObrisatiLink As Boolean

Dim retValOk As Boolean
Dim BrojObrisanih As Integer
Dim UkBrojObrisanih As Integer
Dim BrojPonavljanjaPetlje As Integer
Const MaxBrojPonavljanja = 10
    
    BrojPonavljanjaPetlje = 0
    UkBrojObrisanih = 0
    Set db = CurrentDb
    
point_Repeat:
    BrojPonavljanjaPetlje = BrojPonavljanjaPetlje + 1
    If BrojPonavljanjaPetlje > MaxBrojPonavljanja Then GoTo exit_ObrisiNepotrebneLinkovaneTabeleZaFirmu
    
    BrojObrisanih = 0
    For Each tDef In db.TableDefs
     linkedTable = (tDef.Attributes And dbAttachedODBC) Or (tDef.Attributes And dbAttachedTable)
     'linkedTable = IsLinkedTableAccess(tdef.Name) Or IsLinkedODBC(tdef.Name)
     If linkedTable Then
      trebaObrisatiLink = Not TrebaLinkZaTabelu(FirmazaBaze, tDef.Name)
      If trebaObrisatiLink Then
         'Debug.Print tdef.Name, tdef.Connect, "NEPOTREBAN LINK"
         db.TableDefs.Delete tDef.Name
         BrojObrisanih = BrojObrisanih + 1
      End If
     End If
    Next
    UkBrojObrisanih = UkBrojObrisanih + BrojObrisanih
    If BrojObrisanih > 0 Then
      GoTo point_Repeat
    End If
 retValOk = True
exit_ObrisiNepotrebneLinkovaneTabeleZaFirmu:
On Error Resume Next
    db.Close
    Set db = Nothing
    ObrisiNepotrebneLinkovaneTabeleZaFirmu = retValOk
    MsgBox "Broj obrisanih linkovanih tabela = " & UkBrojObrisanih, vbInformation, "QMegaTeh"
Exit Function
    
    
err_ObrisiNepotrebneLinkovaneTabeleZaFirmu:

    BBErrorMSG err, "ObrisiNepotrebneLinkovaneTabeleZaFirmu"
    retValOk = False
    Resume exit_ObrisiNepotrebneLinkovaneTabeleZaFirmu
    
End Function
Public Function ListaNepotrebnihLinkovaZaFirmu(FirmazaBaze As String) As String
On Error GoTo err_ListaNepotrebnihLinkovaZaFirmu
Dim db As DAO.Database
Dim tDef As DAO.TableDef
Dim linkedTable As Boolean
Dim trebaObrisatiLink As Boolean
Dim stRetVal As String

Dim retValOk As Boolean
Dim BrojNepotrebnih As Integer
    
    stRetVal = ""
    BrojNepotrebnih = 0
    Set db = CurrentDb
    
    For Each tDef In db.TableDefs
     linkedTable = (tDef.Attributes And dbAttachedODBC) Or (tDef.Attributes And dbAttachedTable)
     'linkedTable = IsLinkedTableAccess(tdef.Name) Or IsLinkedODBC(tdef.Name)
     If linkedTable Then
      trebaObrisatiLink = Not TrebaLinkZaTabelu(FirmazaBaze, tDef.Name)
      If trebaObrisatiLink Then
         'db.TableDefs.Delete tdef.Name
         BrojNepotrebnih = BrojNepotrebnih + 1
         stRetVal = stRetVal & stR(BrojNepotrebnih) & ". " & tDef.Name & " (" & TipBazeZaTabelu(tDef.Name) & ")" & vbCrLf '& tdef.Connect & "NEPOTREBAN LINK" & vbCrLf
      End If
     End If
    Next
 retValOk = True
exit_ListaNepotrebnihLinkovaZaFirmu:
On Error Resume Next
    db.Close
    Set db = Nothing
    stRetVal = "Broj nepotrebnih linkovanih tabela = " & BrojNepotrebnih & vbCrLf & stRetVal
    ListaNepotrebnihLinkovaZaFirmu = stRetVal
    'MsgBox "Broj nepotrebnih linkovanih tabela = " & BrojNepotrebnih, vbInformation, "QMegaTeh"
Exit Function
    
    
err_ListaNepotrebnihLinkovaZaFirmu:

    BBErrorMSG err, "ListaNepotrebnihLinkovaZaFirmu"
    retValOk = False
    Resume exit_ListaNepotrebnihLinkovaZaFirmu
    
End Function
'Public Function IspravanLink(stImeTabele, stTrebaDaBudeUBazi As String) As Boolean
 'CLng(DCount("*","Baze_ProveraLinkova","[IDBaze] = " & [IDBaze] & "And [DobarLink] = True"))
'End Function

Public Function F_CurrentSourceZaTabelu(stTableName As String) As String
'Kreirano: 19-02-2020
On Error GoTo Err_Point
Dim stRetVal As String
stRetVal = CurrentDb.TableDefs(stTableName).Connect

Exit_Point:
On Error Resume Next
  F_CurrentSourceZaTabelu = stRetVal
Exit Function

Err_Point:
 stRetVal = err.Description
 Resume Exit_Point
End Function
Public Function F_BrojSlogovaUTabeli(stTableName As String) As Long
'Kreirano: 19-02-2020
On Error GoTo Err_Point
Dim lintRetVal As Long
lintRetVal = DCount("*", stTableName)

Exit_Point:
On Error Resume Next
   F_BrojSlogovaUTabeli = lintRetVal
Exit Function

Err_Point:
 lintRetVal = 0
 Resume Exit_Point
End Function
Public Function SysCheckLink(ByVal imeTabele As String, Optional ByVal ConnectionTimeout, Optional ByVal WithMsg As Boolean = False, Optional OnlyFirstField) As Boolean
'SysCheckLink("tmpTestLink")
 On Error GoTo err_SysCheckLink
 
   Dim retValOk As Boolean
   Dim ImePrvogPolja As Variant
   Dim ODBCPrviSlog As DAO.Recordset
   Dim pCNNString As String
   Dim stKomanda As String
   Dim pConnectionTimeout As Integer
    retValOk = True
    
    If IsMissing(ConnectionTimeout) Or IsNull(ConnectionTimeout) Or Not IsNumeric(ConnectionTimeout) Then
      pConnectionTimeout = F_SysConnectionTimeOut()
    Else
      pConnectionTimeout = CInt(ConnectionTimeout)
    End If
    
    stKomanda = "ImePrvogPolja = CurrentDb.TableDefs(ImeTabele).Fields(0).Name"
    ImePrvogPolja = CurrentDb.TableDefs(imeTabele).Fields(0).Name
  'ako je ODBC link, onda prethodno nije dovoljno
  If IsMissing(OnlyFirstField) Then
   OnlyFirstField = False
  End If
  If IsLinkedODBC(imeTabele) And Not OnlyFirstField Then
     pCNNString = BazaZaTabelu(imeTabele)  'BazaZaTip("BigBit_T") 'Nz(CurrentDb.TableDefs(ImeTabele).Connect, "")
     pCNNString = Replace(pCNNString, "ODBC;", "")
     'pCNNString = Replace(pCNNString, ";DATABASE=", "")
      stKomanda = "TestConnection(pCNNString, pConnectionTimeout)"
     retValOk = TestConnection(pCNNString, pConnectionTimeout)
     If Not retValOk Then
        GoTo exit_SysCheckLink
     End If
      stKomanda = "CurrentDb.TableDefs(ImeTabele).RefreshLink"
     CurrentDb.TableDefs(imeTabele).RefreshLink
      stKomanda = "ODBCPrviSlog"
     Set ODBCPrviSlog = CurrentDb.OpenRecordset("SELECT TOP 1 [" & imeTabele & "].* FROM [" & imeTabele & "];", dbOpenSnapshot, dbReadOnly)
  End If

exit_SysCheckLink:
 On Error Resume Next
  ODBCPrviSlog.Close
  Set ODBCPrviSlog = Nothing
  SysCheckLink = retValOk
Exit Function
err_SysCheckLink:
  retValOk = False
  If WithMsg Then
   MsgBox "err=" & err.Number & "  " & err.Description & vbCrLf & vbCrLf & "Za komandu: " & stKomanda
  End If
  err.Clear
  
  Resume exit_SysCheckLink
End Function
