Attribute VB_Name = "BB2CMD"
Option Compare Database
Option Explicit
Public Sub UpdateNewFieldDefault(NovaBaza As DAO.Database, NovaTabela As DAO.TableDef, NovoPolje As DAO.Field)
 Dim txtSQLUpdate As String
 Dim apostrof As String
    
    If IsNull(NovoPolje.DefaultValue) Or (NovoPolje.DefaultValue = "") Then
     Exit Sub
    End If
    
    If (NovoPolje.Type = dbChar) Or (NovoPolje.Type = dbMemo) Or (NovoPolje.Type = dbText) Then
     apostrof = ""
    Else
     apostrof = ""
    End If
    txtSQLUpdate = "UPDATE [" & NovaTabela.Name & "] SET [" & NovaTabela.Name & "].[" & NovoPolje.Name & "] = " & apostrof & NovoPolje.DefaultValue & apostrof & " WHERE ((([" & NovaTabela.Name & "].[" & NovoPolje.Name & "]) Is Null));"
    'Debug.Print txtSQLUpdate
    'QueryExecute ImeNoveBaze, sqlUpdate
     NovaBaza.Execute txtSQLUpdate
End Sub

Public Function KreirajPoljeUTabeliPoModelu(ExpImp_DatabaseName As String, ExpImp_TableName As String, ExpImp_FieldName As String, _
                              BB_DatabaseName As String, BB_TableName As String, BB_FieldName As String, Optional ByRef stRetVal As String) As Boolean
' Print KreirajPoljeUTabeliPoModelu("C:\SHARES\Makovica\AcBaze\BigBit18\Mak18\Makovica_T_18.MDB", "Komitenti", "IDVozac", "C:\SHARES\Makovica\AcBaze\BigBit18\MOD\BB_T_MOD.MDB", "Komitenti", "IDVozac")
                              
On Error GoTo Err_Point

    Dim dbExpImp As DAO.Database
    Dim dbBigBit As DAO.Database
    Dim tblExpImp As DAO.TableDef
    Dim tblBigBit As DAO.TableDef
    Dim fldExpImp As DAO.Field
    Dim fldBigBit As DAO.Field
    Dim prop As Property
    Dim i As Integer
    Dim retValOk As Boolean
    
    retValOk = True
    Set dbExpImp = DAO.OpenDatabase(ExpImp_DatabaseName)
    Set dbBigBit = DAO.OpenDatabase(BB_DatabaseName)
    
    Set tblExpImp = dbExpImp.TableDefs(ExpImp_TableName)
    Set tblBigBit = dbBigBit.TableDefs(BB_TableName)
    
    Set fldBigBit = tblBigBit.Fields(BB_FieldName)
    Set fldExpImp = tblExpImp.CreateField(ExpImp_FieldName, fldBigBit.Type, fldBigBit.Size)
    
        
    'For i = 1 To fldBigBit.Properties.Count - 1
    '  On Error Resume Next
    '  If fldExpImp.Properties(i).Name <> "Name" Then
    '  fldExpImp.Properties(i).Value = fldBigBit.Properties(i).Value
    '   If Err.Number > 0 Then
    '       stRetVal = stRetVal & Format(i, "##0") & "  "
    '       stRetVal = stRetVal & fldBigBit.Properties(i).Name & " ="
    '       stRetVal = stRetVal & fldBigBit.Properties(i).Value
    '       stRetVal = stRetVal & "Err.Number: " & Err.Number & "  Err.Description: " & Err.Description & vbCrLf
    '   End If
    '  End If
    'Next i
    'Err.Clear
    'On Error GoTo err_Point
    
    'ovde postavljamo propertise:
    On Error Resume Next 'jer neki ne mogu da se postave (npr AllowZeroLength ako je number...
    fldExpImp.DefaultValue = fldBigBit.DefaultValue
    fldExpImp.AllowZeroLength = fldBigBit.AllowZeroLength
    'fldExpImp.FieldSize = fldBigBit.FieldSize
    fldExpImp.Required = fldBigBit.Required
    'fldExpImp.Size = fldBigBit.Size
    fldExpImp.ValidationRule = fldBigBit.ValidationRule
    fldExpImp.ValidationText = fldBigBit.ValidationText
    
    err.Clear
    On Error GoTo Err_Point
    
    tblExpImp.Fields.Append fldExpImp
    UpdateNewFieldDefault dbExpImp, tblExpImp, fldExpImp
    
    'neki propertisi mogu da se dodaju tek kada je field/polje dodato u tabelu
    'ali ipak
    On Error Resume Next 'možda ne postoji u fldBigBit
    Set prop = fldExpImp.CreateProperty("Description", fldBigBit.Properties("Description").Type, fldBigBit.Properties("Description").Value)
    fldExpImp.Properties.Append prop
    On Error Resume Next
    
Exit_Point:
On Error Resume Next
    
    Set fldExpImp = Nothing
    Set fldBigBit = Nothing
    
    Set tblExpImp = Nothing
    Set tblBigBit = Nothing
    
    dbExpImp.Close
    Set dbExpImp = Nothing
    
    dbBigBit.Close
    Set dbBigBit = Nothing
    
    KreirajPoljeUTabeliPoModelu = retValOk
Exit Function
Err_Point:
    retValOk = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura KreirajPoljeUTabeliPoModelu se prekida.", vbCritical, "QMegaTeh"
    Resume Exit_Point
 
End Function
Public Function ExportXSDForTables(Optional ImeBaze, Optional imeTabele)
' AcImportXMLOption  sub: ImportXML
' AcExportXMLObjectType sub: ExportXML

  On Error GoTo err_Sub
    Dim Baza As DAO.Database
    Dim pImeTabele
    Dim Tabela As DAO.TableDef
    Dim pImeFajlaXSD As String
    Dim retVal As Boolean
    
    retVal = True
    If IsMissing(ImeBaze) Then
     Set Baza = CurrentDb
    Else
     If IsNull(ImeBaze) Then
        Set Baza = CurrentDb
     Else
        Set Baza = DAO.OpenDatabase(ImeBaze)
     End If
    End If
    
    
    If IsMissing(imeTabele) Then pImeTabele = CurrentDb.TableDefs(0).Name '"MSysTab"
    If IsNull(imeTabele) Then pImeTabele = CurrentDb.TableDefs(0).Name

    'pImeFajla = "D:\tmp\XML\" & pImeTabele & ".XSD"
    pImeFajlaXSD = "D:\tmp\XML\" & pImeTabele & ".XSD"
    Set Tabela = Baza.TableDefs(pImeTabele)
    'DoCmd.OutputTo acOutputTable, pImeTabele, acFormatxm
    'ExportXML acExportTable, pImeTabele, "D:\tmp\XML\" & pImeTabele & ".XML", "D:\tmp\XML\" & pImeTabele & ".XSD"
    'ExportXML acExportTable, pImeTabele, , pImeFajlaXSD, , , , acExportAllTableAndFieldProperties
    'ExportXML acExportTable, "BazeIFirme", , pImeFajlaXSD, , , , acExportAllTableAndFieldProperties 'Šalju se i indexi
    ExportXML acExportTable, "BazeIFirme", , pImeFajlaXSD, , , , acExportAllTableAndFieldProperties 'Šalju se i indexi
    
Exit_Sub:
    On Error Resume Next
    Set Tabela = Nothing
    Baza.Close
    Set Baza = Nothing
    ExportXSDForTables = retVal
  Exit Function
err_Sub:
  retVal = False
  BBErrorMSG err, "ExportXSDForTables"
  Resume Exit_Sub
End Function
Public Sub ExportKomitentiRobnaDokIStavke()
    Dim objRobnaDok As AdditionalData
    Dim objRobneStavke As AdditionalData
    
    
    Set objRobnaDok = Application.CreateAdditionalData
    
    ' Add the Orders and Order Details tables to the data to be exported.
    Set objRobneStavke = objRobnaDok.Add("T_Robna Dokumenta")
    objRobneStavke.Add "T_Robne stavke"
    
    ' Export the contents of the Customers table. The Orders and Order
    ' Details tables will be included in the XML file.
    Application.ExportXML ObjectType:=acExportTable, DataSource:="Komitenti", _
                          DataTarget:="D:\tmp\XML\KomitentiIDok.xml", _
                          AdditionalData:=objRobnaDok
                          
  Set objRobnaDok = Nothing
  Set objRobneStavke = Nothing
End Sub

Public Sub ExportArtikliGrupePodgrupe()
    Dim objRobnaDok As AdditionalData
    Dim objRobneStavke As AdditionalData
    
    
    Set objRobnaDok = Application.CreateAdditionalData
    
    ' Add the Orders and Order Details tables to the data to be exported.
    Set objRobneStavke = objRobnaDok.Add("R_Grupa")
    objRobneStavke.Add "R_Podgrupa"
    
    ' Export the contents of the Customers table. The Orders and Order
    ' Details tables will be included in the XML file.
    Application.ExportXML ObjectType:=acExportTable, DataSource:="R_Artikli", _
                          DataTarget:="D:\tmp\XML\ArtikliIGrupePodg.xml", _
                          AdditionalData:=objRobnaDok
                          
  Set objRobnaDok = Nothing
  Set objRobneStavke = Nothing
End Sub

