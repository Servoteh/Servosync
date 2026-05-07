Attribute VB_Name = "SHUTTLE"
Option Compare Database
Option Explicit

Public Function ImateNoviSHUTTLE() As Boolean
On Error GoTo Err_Point
  Dim ODBCSync As New ODBC_Synch_Class
  Dim retVal As Boolean
  Dim OK As Boolean
  
  If BBCFG.SysDisabledSynch Then
     ImateNoviSHUTTLE = False
     Exit Function
  End If
  retVal = False
     
  OK = True
  If ODBCSync.CheckRequest Then
   retVal = ODBCSync.HasRequest
  Else
   retVal = False
  End If
  
Exit_Point:
On Error Resume Next
   Set ODBCSync = Nothing
   ImateNoviSHUTTLE = retVal
  Exit Function
  
Err_Point:
  BBErrorMSG err, "ImateNoviSHUTTLE"
  Resume Exit_Point:
End Function
Public Function VM_PrihvatiSHUTTLE() As Boolean
On Error GoTo Err_Point
  Dim ODBCSync As New ODBC_Synch_Class
  Dim retValOk As Boolean
  
  If BBCFG.SysDisabledSynch Then
     VM_PrihvatiSHUTTLE = False
     Exit Function
  End If
  
  retValOk = False
  retValOk = ODBCSync.Synchronize
  
Exit_Point:
On Error Resume Next
   Set ODBCSync = Nothing
   VM_PrihvatiSHUTTLE = retValOk
  Exit Function
  
Err_Point:
  BBErrorMSG err, "VM_PrihvatiSHUTTLE"
  retValOk = False
  Resume Exit_Point:
End Function
Public Function SHUTTLE_ODBCSynch_MPDokumenta_Upload() As Boolean
On Error GoTo Err_Point
  Dim ODBCSync As New ODBC_Synch_Class
  Dim OK As Boolean
  Dim retValOk As Boolean
  
  If BBCFG.SysDisabledSynch Then
     SHUTTLE_ODBCSynch_MPDokumenta_Upload = False
     Exit Function
  End If
  
  retValOk = True
  BBCFG.SysSuspendSynch = False
  
  DoCmd.OpenForm BBCFG.ODBC_Synch_FormName, acNormal, , , , acHidden
  Forms(BBCFG.ODBC_Synch_FormName).Visible = False
  DoCmd.OpenForm "ODBC_Synch_PorukaOSinhronizaciji", acNormal
  DoEvents
  
  OK = ODBCSync.OpenConnection
  If OK Then
   OK = CreateShuttleLink("SHUTTLE_MPDokumenta", "T_MPDokumenta", BazaZaTip("SHUTTLE"))
   OK = OK And CreateShuttleLink("SHUTTLE_MPStavke", "T_MPStavke", BazaZaTip("SHUTTLE"))
   If OK Then
    retValOk = ODBCSync.ExecuteProc(2000, True, True)
   Else
    retValOk = False
   End If
  Else
   retValOk = False
  End If
  DoCmd.Close acForm, BBCFG.ODBC_Synch_FormName
  DoCmd.Close acForm, "ODBC_Synch_PorukaOSinhronizaciji"
  If retValOk Then
    BBMsgBox_BigBit "Sinhronizacija uspešno završena.", 10
  Else
    BBMsgBox_BigBit "Sinhronizacija nije uspešno završena!"
  End If
Exit_Point:
On Error Resume Next
   Set ODBCSync = Nothing
   SHUTTLE_ODBCSynch_MPDokumenta_Upload = retValOk
  Exit Function
  
Err_Point:
  BBErrorMSG err, "ODBCSynch_MPDokumenta_Upload"
  retValOk = False
  Resume Exit_Point:
End Function
Public Function ImateNoviSHUTTLE_OLD() As Boolean
On Error Resume Next
    Dim UradjenPrijem As Boolean
    Dim KoJePoslao As String
    Dim KoPrima As String

'***********************************************************
' OVO TREBA URADITI!
'***********************************************************
    ImateNoviSHUTTLE_OLD = False
Exit Function
    
    UradjenPrijem = True
    UradjenPrijem = Nz(DLookup("[Prijem]", "SHUTTLE_Info"), True)
    If Not UradjenPrijem Then
        KoJePoslao = Nz(DLookup("[KoJePoslao]", "SHUTTLE_Info"), "")
        KoPrima = BigBit_UID()
        UradjenPrijem = (KoJePoslao = KoPrima)
    End If
        
    ImateNoviSHUTTLE_OLD = (Not UradjenPrijem)
End Function
Public Sub VM_PrihvatiSHUTTLE_OLD()
On Error GoTo Err_VM_PrihvatiSHUTTLE

    Dim stDocName As String
    Dim OK As Boolean

    DoCmd.SetWarnings False
        
            OK = True
 
            stDocName = "SHUTTLE_ImportR_Grupa"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
            

            stDocName = "SHUTTLE_ImportR_Podgrupa"
            DoCmd.OpenQuery stDocName, acNormal, acEdit

            stDocName = "SHUTTLE_ImportR_Poreklo"
            DoCmd.OpenQuery stDocName, acNormal, acEdit

            stDocName = "SHUTTLE_ImportR_Tarife"
            DoCmd.OpenQuery stDocName, acNormal, acEdit

            stDocName = "SHUTTLE_ImportKNG_Artikli"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
        
        If False Then
            stDocName = "SHUTTLE_ImportRasterDefZag"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
            
            stDocName = "SHUTTLE_ImportRasterDefVrsta"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
            
            stDocName = "SHUTTLE_ImportRasterDefKolona"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
            
            stDocName = "SHUTTLE_ImportRasterDefStavkeVrsta"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
            
            stDocName = "SHUTTLE_ImportRasterDefStavkeKolona"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
        End If
        
            stDocName = "SHUTTLE_ImportR_Artikli"
            DoCmd.OpenQuery stDocName, acNormal, acEdit


            stDocName = "SHUTTLE_ImportR_Vrste dokumenata"
            DoCmd.OpenQuery stDocName, acNormal, acEdit

            stDocName = "SHUTTLE_ImportCenovnik_VM"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
       

            stDocName = "SHUTTLE_ImportPozicije"
            DoCmd.OpenQuery stDocName, acNormal, acEdit

        
            stDocName = "SHUTTLE_ImportVrste sifara"
            DoCmd.OpenQuery stDocName, acNormal, acEdit

  
            stDocName = "SHUTTLE_ImportKomitenti"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
      
            stDocName = "SHUTTLE_ImportProdavci"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
                      
            stDocName = "SHUTTLE_ImportRadniNalozi"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
            
            stDocName = "SHUTTLE_ImportVrsteNaloga"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
            
            
            '=========================
            stDocName = "SHUTTLE_UpdateR_Grupa"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
            

            stDocName = "SHUTTLE_UpdateR_Podgrupa"
            DoCmd.OpenQuery stDocName, acNormal, acEdit

            stDocName = "SHUTTLE_UpdateR_Poreklo"
            DoCmd.OpenQuery stDocName, acNormal, acEdit

            stDocName = "SHUTTLE_UpdateR_Tarife"
            DoCmd.OpenQuery stDocName, acNormal, acEdit

            stDocName = "SHUTTLE_UpdateKNG_Artikli"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
        
        
            stDocName = "SHUTTLE_UpdateR_Artikli"
            DoCmd.OpenQuery stDocName, acNormal, acEdit


            stDocName = "SHUTTLE_UpdateR_Vrste dokumenata"
            DoCmd.OpenQuery stDocName, acNormal, acEdit

            stDocName = "SHUTTLE_UpdateCenovnik_VM"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
       

            stDocName = "SHUTTLE_UpdatePozicije"
            DoCmd.OpenQuery stDocName, acNormal, acEdit

        
            stDocName = "SHUTTLE_UpdateVrste sifara"
            DoCmd.OpenQuery stDocName, acNormal, acEdit

  
            stDocName = "SHUTTLE_UpdateKomitenti"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
      
            stDocName = "SHUTTLE_UpdateProdavci"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
                      
            stDocName = "SHUTTLE_UpdateRadniNalozi"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
            
            stDocName = "SHUTTLE_UpdateVrsteNaloga"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
            '=========================
            
            
            stDocName = "SHUTTLE_UpdateInfoPrijem"
            DoCmd.OpenQuery stDocName, acNormal, acEdit
            
            
    
    DoCmd.SetWarnings True
    If OK Then
        MsgBox "Podaci su uspesno prihvaceni!", vbInformation, "QMegaTeh"
    Else
        MsgBox "Neki podaci nisu uspesno prihvaceni!", vbCritical, "QMegaTeh"
    End If

    
Exit_VM_PrihvatiSHUTTLE:
    DoCmd.SetWarnings True
    
    Exit Sub

Err_VM_PrihvatiSHUTTLE:
    MsgBox err.Description
    MsgBox "Greska na upitu Q: " & stDocName, vbExclamation, "QMegaTeh"
    OK = False
    Resume Next
    
End Sub

Public Function SHUTTLE_Export(IzTabele As String, UTabelu As String, Optional stWhere)
'? SHUTTLE_Export("Magacini", "SHUTTLE_Magacini")
'
'INSERT INTO SHUTTLE_Magacini ( IDMagacin, Magacin, UlicaIBroj, Mesto, ProsecneCene, VrstaMag, KontoMag )
'SELECT Magacini.IDMagacin, Magacini.Magacin, Magacini.UlicaIBroj, Magacini.Mesto, Magacini.ProsecneCene, Magacini.VrstaMag, Magacini.KontoMag
'FROM Magacini LEFT JOIN SHUTTLE_Magacini ON Magacini.IDMagacin = SHUTTLE_Magacini.IDMagacin
'WHERE (((SHUTTLE_Magacini.IDMagacin) Is Null));

On Error GoTo Err_Point

 Dim retValOk As Boolean
 Dim db As DAO.Database
 Dim fldUTabelu As DAO.Field
 Dim tblUTabelu As New DAO.TableDef
 Dim stSQLInsert As String
 Dim stSQLSELECT As String
 Dim stSQL As String
 Dim i As Integer
 
 retValOk = True
 Set db = CurrentDb
 Set tblUTabelu = db.TableDefs(UTabelu)
 
 stSQLInsert = "INSERT INTO [" & UTabelu & "] ( "
 stSQLSELECT = "SELECT "
 
' For Each fldUTabelu In tblUTabelu.Fields
'  stSQLInsert = stSQLInsert & "[" & fldUTabelu.Name & "], "
' Next

For i = 1 To tblUTabelu.Fields.Count
 stSQLInsert = stSQLInsert & "[" & tblUTabelu.Fields(i - 1).Name & "]"
 stSQLSELECT = stSQLSELECT & "[" & IzTabele & "]." & "[" & tblUTabelu.Fields(i - 1).Name & "]"
 If i < tblUTabelu.Fields.Count Then
   stSQLInsert = stSQLInsert & ", "
   stSQLSELECT = stSQLSELECT & ", "
 Else
   stSQLInsert = stSQLInsert & ") "
 End If
Next i

 stSQL = stSQLInsert & vbCrLf & stSQLSELECT
 stSQL = stSQL & vbCr & "FROM [" & IzTabele & "]"
 
 If Not IsMissing(stWhere) Then
  stSQL = stSQL & vbCrLf & Nz(stWhere, "")
 End If
 
 db.Execute stSQL
 
Exit_Point:
 On Error Resume Next
 Set fldUTabelu = Nothing
 Set tblUTabelu = Nothing
 db.Close
 Set db = Nothing
 
 SHUTTLE_Export = retValOk
 'SHUTTLE_Export = stSQL
Exit Function

Err_Point:
BBErrorMSG err, "SHUTTLE_Export"
retValOk = False
Resume Exit_Point:

End Function
'*********************
Private Function SHUTTLE_Test_NEPOKRECI()
 ' Database.
    Dim XF
    Dim dbRep As DAO.Database
    Dim dbNew As DAO.Database

    ' For copying tables and indexes.
    Dim tblRep As DAO.TableDef
    Dim tblNew As DAO.TableDef
    Dim fldRep As DAO.Field
    Dim fldNew As DAO.Field
    Dim idxRep As DAO.Index
    Dim idxNew As DAO.Index

    ' For copying data.
    Dim rstRep As DAO.Recordset
    Dim rstNew As DAO.Recordset
    Dim rec1 As DAO.Recordset
    Dim rec2 As DAO.Recordset
    Dim intC As Integer

    ' For copying table relationships.
    Dim relRep As DAO.Relation
    Dim relNew As DAO.Relation

    ' For copying queries.
    Dim qryRep As DAO.QueryDef
    Dim qryNew As DAO.QueryDef

    ' For copying startup options.
    Dim avarSUOpt
    Dim strSUOpt As String
    Dim varValue
    Dim varType
    Dim prpRep As DAO.Property
    Dim prpNew As DAO.Property

    ' For importing forms, reports, modules, and macros.
    Dim appNew As New Access.Application
    Dim doc As DAO.Document

    ' Open the database, not in exclusive mode.
    Set dbRep = OpenDatabase(Forms!CMDB_frmUpgrade.TxtDatabase, False)


    ' Open the new database
    Set dbNew = CurrentDb

    DoEvents

    ' Turn on the hourglass.
    DoCmd.Hourglass True

    '********************
    Debug.Print "Copy Tables"
    '********************
If Forms!CMDB_frmUpgrade.CkTables = True Then
    Forms!CMDB_frmUpgrade.LstMessages.AddItem "Copying Tables:"

    ' Loop through the collection of table definitions.
    For Each tblRep In dbRep.TableDefs
    Set rec1 = dbRep.OpenRecordset("SELECT MSysObjects.Name FROM MsysObjects WHERE ([Name] = '" & tblRep.Name & "') AND ((MSysObjects.Type)=4 or (MSysObjects.Type)=6)")

    If rec1.EOF Then
      XF = 0
    Else
      XF = 1
    End If

        ' Ignore system tables and CMDB tables.
        If InStr(1, tblRep.Name, "MSys", vbTextCompare) = 0 And _
            InStr(1, tblRep.Name, "CMDB", vbTextCompare) = 0 And _
            XF = 0 Then

            '***** Table definition
            ' Create a table definition with the same name.
            Set tblNew = dbNew.CreateTableDef(tblRep.Name)
            Forms!CMDB_frmUpgrade.LstMessages.AddItem "--> " & tblRep.Name & ""

            ' Set properties.
            tblNew.ValidationRule = tblRep.ValidationRule
            tblNew.ValidationText = tblRep.ValidationText

            ' Loop through the collection of fields in the table.
            For Each fldRep In tblRep.Fields

                ' Ignore replication-related fields:
                ' Gen_XXX, s_ColLineage, s_Generation, s_GUID, s_Lineage
                If InStr(1, fldRep.Name, "s_", vbTextCompare) = 0 And _
                    InStr(1, fldRep.Name, "Gen_", vbTextCompare) = 0 Then

                    '***** Field definition
                    Set fldNew = tblNew.CreateField(fldRep.Name, fldRep.Type, _
                        fldRep.Size)

                    ' Set properties.
                    On Error Resume Next
                    fldNew.Attributes = fldRep.Attributes
                    fldNew.AllowZeroLength = fldRep.AllowZeroLength
                    fldNew.DefaultValue = fldRep.DefaultValue
                    fldNew.Required = fldRep.Required
                    fldNew.Size = fldRep.Size

                    ' Append the field.
                    tblNew.Fields.Append fldNew
                    'On Error GoTo Err_NewShell
                End If
            Next fldRep

            '***** Index definition

            ' Loop through the collection of indexes.
            For Each idxRep In tblRep.Indexes

                ' Ignore replication-related indexes:
                ' s_Generation, s_GUID
                If InStr(1, idxRep.Name, "s_", vbTextCompare) = 0 Then

                    ' Ignore indices set as part of Relation Objects
                    If Not idxRep.Foreign Then

                        ' Create an index with the same name.
                        Set idxNew = tblNew.CreateIndex(idxRep.Name)

                        ' Set properties.
                        idxNew.Clustered = idxRep.Clustered
                        idxNew.IgnoreNulls = idxRep.IgnoreNulls
                        idxNew.Primary = idxRep.Primary
                        idxNew.Required = idxRep.Required
                        idxNew.UNIQUE = idxRep.UNIQUE

                        ' Loop through the collection of index fields.
                        For Each fldRep In idxRep.Fields
                            ' Create an index field with the same name.
                            Set fldNew = idxNew.CreateField(fldRep.Name)
                            ' Set properties.
                            fldNew.Attributes = fldRep.Attributes
                            ' Append the index field.
                            idxNew.Fields.Append fldNew
                        Next fldRep

                        ' Append the index to the table.
                        tblNew.Indexes.Append idxNew
                    End If
                End If
            Next idxRep

            ' Append the table.
            dbNew.TableDefs.Append tblNew
        End If
    Next tblRep
 End If '******************************* FALI!!!!
End Function
