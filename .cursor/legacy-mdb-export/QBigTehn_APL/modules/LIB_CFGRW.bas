Attribute VB_Name = "LIB_CFGRW"
Option Compare Database
Option Explicit

Private Const OnNotExistCNN_OpenCNNFormDialog = False

Private pCNN_FIT
Private pCNN_CurrentDataBase
Private pCNN_CFG_Lokal
Private pCNN_CFG_Global
Private pCNN_MasterDB
Private pCNN_SHUTTLE
Private pCNN_ESDB
Private pCNN_TempDB
Private pCNN_CFG_Sys

Private pGodina
Private pIDFirma
Private Function AppNameZaCnn() As String

On Error GoTo Err_Point
Dim retValOk As Boolean

Exit_Point:
 On Error Resume Next
       AppNameZaCnn = "QBigTeh_" & CurrentUser() & "(" & Environ("ComputerName") & "\" & Environ("UserName") & ")"
Exit Function

Err_Point:
 BBErrorMSG err, "AppNameZaCnn"
 retValOk = False
 Resume Exit_Point
End Function
Public Property Get Godina() As Long
If IsEmpty(pGodina) Then
   pGodina = Year(Date)
End If
    Godina = pGodina
End Property
Public Property Let Godina(ByVal vNewValue As Long)
    pGodina = vNewValue
End Property

Public Function F_Godina() As Long
    F_Godina = Godina
End Function
Public Function F_BBAktGodina() As Long
    F_BBAktGodina = Godina
End Function

Public Property Get IDFirma() As Long
'Kreirano: 28-10-2021
    If IsEmpty(pIDFirma) Then
       pIDFirma = 0
    End If
        IDFirma = pIDFirma
End Property

Public Property Let IDFirma(ByVal nIDFirma As Long)
'Kreirano: 28-10-2021
    'If ADO_Lookup(CNN_CurrentDataBase, "[BrojSlogova]", "SELECT Count(*) as BrojSlogova FROM [Radni fajlovi] WHERE IDBaze = " & str(nIDFirma)) = 1 Then
      pIDFirma = nIDFirma
    '  BBCFG.IDFirma = nIDFirma
    ' Else
    '  'Ne postoji firma sa zadatim ID
    '  MsgBox "Ne postoji firma ID=" & nIDFirma & vbCrLf & vbCrLf & "Aktivna firma nece biti promenjena.", vbExclamation, "QMegaTeh"
    ' End If
     
End Property

Public Function F_IDFirma() As Long
    F_IDFirma = IDFirma
End Function

Public Function CNNReset()
   pCNN_CurrentDataBase = Empty
   pCNN_CFG_Lokal = Empty
   pCNN_CFG_Global = Empty
   pCNN_MasterDB = Empty
   pCNN_SHUTTLE = Empty
   pCNN_ESDB = Empty
   pCNN_TempDB = Empty
   pCNN_FIT = Empty
   pCNN_CFG_Sys = Empty
End Function

Public Property Let CNN_CurrentDataBase(vNewValue As String)
    pCNN_CurrentDataBase = vNewValue
End Property
Public Property Get CNN_CurrentDataBase() As String
 
  If IsEmpty(pCNN_CurrentDataBase) Then
     pCNN_CurrentDataBase = BBReadProperty("CNN_CurrentDataBase", False)
  End If
  
  If Nz(pCNN_CurrentDataBase, "") = "" Then 'Mora da postoji ovaj CNN String
        pCNN_CurrentDataBase = ""
        If OnNotExistCNN_OpenCNNFormDialog Then
            DoCmd.OpenForm "CNN", , , , , , "CNN_CurrentDataBase"
        End If
  End If
  
  CNN_CurrentDataBase = SetParToCNNString("APP", AppNameZaCnn, pCNN_CurrentDataBase)
  
End Property
Public Property Get CNN_CFG_Lokal() As String
  Dim CFGFileName As String
  
  If IsEmpty(pCNN_CFG_Lokal) Then
     pCNN_CFG_Lokal = BBReadProperty("CNN_CFG_Lokal", False)
  End If
  
  If Nz(pCNN_CFG_Lokal, "") = "" Then
        CFGFileName = FindFile("BB_CFG_Lokal.MDB")
  
        If CFGFileName <> "" Then
           pCNN_CFG_Lokal = "Provider=Microsoft.Jet.OLEDB.4.0"
          'pCNN_CFG_Lokal = pCNN_CFG_Lokal & ";Password=" '& stPassword
          'pCNN_CFG_Lokal = pCNN_CFG_Lokal & ";User ID=Kasa" '& stUserName
          pCNN_CFG_Lokal = pCNN_CFG_Lokal & ";Data Source=" & CFGFileName
          pCNN_CFG_Lokal = pCNN_CFG_Lokal & ";Persist Security Info=True"
          'pCNN_CFG_Lokal = pCNNString & ";Jet OLEDB:System database=" & Application.DBEngine.Properties("SystemDB") ' & stExtMDW
        Else
          pCNN_CFG_Lokal = ""
          If OnNotExistCNN_OpenCNNFormDialog Then
            DoCmd.OpenForm "CNN", , , , , , "CNN_CFG_Lokal"
          End If
        End If
  End If
 
  CNN_CFG_Lokal = pCNN_CFG_Lokal
  
End Property
Public Property Let CNN_CFG_Lokal(vNewValue As String)
    pCNN_CFG_Lokal = vNewValue
End Property
Public Property Get CNN_CFG_Global() As String
 
  If IsEmpty(pCNN_CFG_Global) Then
     pCNN_CFG_Global = BBReadProperty("CNN_CFG_Global", False)
  End If
  
  If Nz(pCNN_CFG_Global, "") = "" Then 'Mora da postoji ovaj CNN String
        pCNN_CFG_Global = ""
        If OnNotExistCNN_OpenCNNFormDialog Then
            DoCmd.OpenForm "CNN", , , , , , "CNN_CFG_Global"
        End If
  End If
  
  CNN_CFG_Global = pCNN_CFG_Global
  
End Property
Public Property Let CNN_CFG_Global(vNewValue As String)
    pCNN_CFG_Global = vNewValue
End Property
Public Property Get CNN_MasterDB() As String

  If IsEmpty(pCNN_MasterDB) Then
     pCNN_MasterDB = BBReadProperty("CNN_MasterDB", False)
  End If
  
  If Nz(pCNN_MasterDB, "") = "" Then 'Mora da postoji ovaj CNN String
        pCNN_MasterDB = ""
        If OnNotExistCNN_OpenCNNFormDialog Then
           DoCmd.OpenForm "CNN", , , , , , "CNN_MasterDB"
        End If
  End If
  
  CNN_MasterDB = pCNN_MasterDB
  
End Property
Public Property Let CNN_MasterDB(vNewValue As String)
    pCNN_MasterDB = vNewValue
End Property

Public Property Get CNN_SHUTTLE() As String

  If IsEmpty(pCNN_SHUTTLE) Then
     pCNN_SHUTTLE = BBReadProperty("CNN_SHUTTLE", False)
  End If
  
  If Nz(pCNN_SHUTTLE, "") = "" Then 'Mora da postoji ovaj CNN String
        pCNN_SHUTTLE = ""
        If OnNotExistCNN_OpenCNNFormDialog Then
            DoCmd.OpenForm "CNN", , , , , , "CNN_SHUTTLE"
        End If
  End If
  
  CNN_SHUTTLE = pCNN_SHUTTLE
  
End Property
Public Property Let CNN_SHUTTLE(vNewValue As String)
    pCNN_SHUTTLE = vNewValue
End Property
Public Property Let CNN_ESDB(vNewValue As String)
    pCNN_ESDB = vNewValue
End Property
Public Property Get CNN_ESDB() As String

  If IsEmpty(pCNN_ESDB) Then
     pCNN_ESDB = BBReadProperty("CNN_ESDB", False)
  End If
  
  If Nz(pCNN_ESDB, "") = "" Then 'Mora da postoji ovaj CNN String
        pCNN_ESDB = ""
        If OnNotExistCNN_OpenCNNFormDialog Then
            DoCmd.OpenForm "CNN", , , , , , "CNN_ESDB"
        End If
  End If
  
  CNN_ESDB = pCNN_ESDB
  
End Property
Public Property Let CNN_TempDB(vNewValue As String)
    pCNN_TempDB = vNewValue
End Property
Public Property Get CNN_TempDB() As String

  If IsEmpty(pCNN_TempDB) Then
     pCNN_TempDB = BBReadProperty("CNN_TempDB", False)
  End If
  
  If Nz(pCNN_TempDB, "") = "" Then 'Mora da postoji ovaj CNN String
        pCNN_TempDB = ""
        If OnNotExistCNN_OpenCNNFormDialog Then
            DoCmd.OpenForm "CNN", , , , , , "CNN_TempDB"
        End If
  End If
  
  CNN_TempDB = pCNN_TempDB
  
End Property
Public Property Let CNN_FIT(vNewValue As String)
    pCNN_FIT = vNewValue
End Property
Public Property Get CNN_FIT() As String

  If IsEmpty(pCNN_FIT) Then
     pCNN_FIT = BBReadProperty("CNN_FIT", False)
  End If
  
  If Nz(pCNN_FIT, "") = "" Then 'Mora da postoji ovaj CNN String
        pCNN_FIT = ""
        If OnNotExistCNN_OpenCNNFormDialog Then
            DoCmd.OpenForm "CNN", , , , , , "CNN_FIT"
        End If
  End If
  
  CNN_FIT = pCNN_FIT
  
End Property
Public Property Let CNN_CFG_Sys(vNewValue As String)
    pCNN_CFG_Sys = vNewValue
End Property
Public Property Get CNN_CFG_Sys() As String
'Kreirano: 02-02-2021

  If IsEmpty(pCNN_CFG_Sys) Then
     pCNN_CFG_Sys = BBReadProperty("CNN_CFG_Sys", False)
  End If
  
  If Nz(pCNN_CFG_Sys, "") = "" Then
    pCNN_CFG_Sys = CNN_CurrentDataBase 'Trazimo ga u CurrentDataBase
  End If
  
  If Nz(pCNN_CFG_Sys, "") = "" Then 'Mora da postoji ovaj CNN String
        pCNN_CFG_Sys = ""
        If OnNotExistCNN_OpenCNNFormDialog Then
            DoCmd.OpenForm "CNN", , , , , , "CNN_CFG_Sys"
        End If
  End If
  
  CNN_CFG_Sys = pCNN_CFG_Sys
  
End Property
Public Function CNN_CurrentAPL() As String
'Kreirano: 25-01-2021

  CNN_CurrentAPL = CreateAccess_CNNString(CurrentDb.Name)
  
End Function

Public Function FindFile(stPatternFileName As String, Optional stNotPatternFileName = "") As String
'Kreirano: 14-10-2020
'Modifikovano: 14-01-2021
On Error GoTo Err_Point
Dim stFileName As String
Dim stFolder As String
Dim stRetVal As String

    stFolder = FolderFromPath(stPatternFileName)
    If stFolder = "" Then
       stFolder = CurrentDBPath
    End If
    stFileName = stFolder & FileNameFromPath(stPatternFileName)
    stFileName = Dir(stFileName)
    
    While (stFileName Like stNotPatternFileName) And (stFileName <> "")
       stFileName = Dir()
    Wend
    
    If stFileName <> "" Then
       stRetVal = stFolder & stFileName
    Else
       stRetVal = ""
    End If
    

Exit_Point:
 On Error Resume Next
 FindFile = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "FindFile"
 stRetVal = ""
 Resume Exit_Point
End Function
Function BBCreateProperty(strPropName As String, Optional varPropType = dbText, Optional varPropValue) As Boolean
'Datum rev: 05-09-2018
'ako NE postoji kreira ga
'ako Postoji menja mu vrednost

On Error GoTo Err_Point
    
    Dim dbs As DAO.Database
    Dim prp As DAO.Property
    Dim retValOk As Boolean
    Const conPropNotFoundError = 3270
    

    Set dbs = CurrentDb
    retValOk = True
    
    On Error Resume Next
    dbs.Properties(strPropName) = IIf(Nz(varPropValue, "Null") = "", "Null", Nz(varPropValue, "Null")) 'Ne prihvata prazan string = ""
    
    If err = conPropNotFoundError Then  ' Property ne postoji.
       On Error GoTo Err_Point
       
        Set prp = dbs.CreateProperty(strPropName, _
                varPropType, varPropValue)
        dbs.Properties.Append prp
        retValOk = True
        'MsgBox "Property " & strPropName & " je kreiran!", vbExclamation + vbOKOnly, "QMegaTeh"

    ElseIf err <> 0 Then
        BBErrorMSG err, "BBCreateProperty"
        retValOk = False
        Resume Exit_Point
    Else
       retValOk = True
    End If

Exit_Point:
 On Error Resume Next
    dbs.Close
    Set dbs = Nothing
    Set prp = Nothing
    BBCreateProperty = retValOk
 Exit Function
 
Err_Point:
    BBErrorMSG err, "BBCreateProperty"
    retValOk = False
    Resume Exit_Point
End Function
Public Function BBReadProperty(varPropName As Variant, Optional ShowErrMsg As Boolean = True) As Variant
'Modifikovano: 14-10-2020
On Error GoTo Err_Point
 Dim retVal
 'retVal = Null
 retVal = CurrentDb.Properties(varPropName)
 
Exit_Point:
On Error Resume Next
 BBReadProperty = retVal
Exit Function
Err_Point:
 If ShowErrMsg Then
   BBErrorMSG err, "BBReadProperty(" & CStr(varPropName) & ")"
 End If
 retVal = Null
 Resume Exit_Point
End Function
Function BBChangeProperty(strPropName As String, varPropType As Variant, varPropValue As Variant) As Boolean

    Dim dbs As DAO.Database
    Dim prp As DAO.Property
    Const conPropNotFoundError = 3270
    Dim Poruka As String
    Dim odgovor

    Set dbs = CurrentDb
    On Error GoTo Change_Err
    If dbs.Properties(strPropName) <> varPropValue Then
     dbs.Properties(strPropName) = varPropValue
    End If
    
    BBChangeProperty = True

Change_Bye:
    dbs.Close
    Set dbs = Nothing
    Set prp = Nothing
    Exit Function

Change_Err:
    If err = conPropNotFoundError Then  ' Property not found.
    
        
        Poruka = "Property ne postoji." & vbCrLf
        Poruka = Poruka & vbCrLf
        Poruka = Poruka & "Name = " & strPropName & vbCrLf
        Poruka = Poruka & " Type = " & varPropType & vbCrLf
        Poruka = Poruka & "Value = " & varPropValue & vbCrLf
        Poruka = Poruka & vbCrLf
        Poruka = Poruka & "Da li želite da kreirate " & strPropName & "?"
        odgovor = MsgBox(Poruka, vbExclamation + vbYesNo, "QMegaTeh")
        If odgovor = vbYes Then
            'Ovde se kreira novi!
             Set prp = dbs.CreateProperty(strPropName, _
                     varPropType, varPropValue)
             dbs.Properties.Append prp
             BBChangeProperty = True
        Else
             BBChangeProperty = False
        End If
        Resume Next
    Else
        ' Unknown error.
        BBErrorMSG err, "ChangeProperty"
        BBChangeProperty = False
        Resume Change_Bye
    End If
End Function
Public Function ReadParametar(TablePropName As String, ByVal txtParametar As String, Optional SetDefaultTableName As String = "CFG_Apl_Parametri_DEF", Optional ByVal IDFirma) As Variant
'Modifikovano: 14-10-2020
'Modifikovani: 02-02-2021
'Modifikovano: 25-10-2021

On Error GoTo Err_Point
 Dim pCNNString As String
 Dim retVal As Variant
 Dim stWhere As String
 Dim pIDFirma As Long
 
 If IsMissing(IDFirma) Or IsNull(IDFirma) Then
  pIDFirma = F_IDFirma()
 Else
  pIDFirma = CLng(IDFirma)
 End If
 
    err.Clear

    If TablePropName = "CFG_Lokal" Then
      pCNNString = CNN_CFG_Lokal
      stWhere = "([Parametar] = '" & txtParametar & "') AND ([IDFirma] = " & stR(pIDFirma) & ")"
    ElseIf TablePropName = "CFG_Global" Then
      pCNNString = CNN_CFG_Global
      stWhere = "([Parametar] = '" & txtParametar & "') AND ([IDFirma] = " & stR(pIDFirma) & ")"
    ElseIf TablePropName = "CFG_Sys" Then
      pCNNString = CNN_CFG_Sys
      stWhere = "([Parametar] = '" & txtParametar & "')"
    Else
      pCNNString = "" 'lokalna tabela
      stWhere = "([Parametar] = '" & txtParametar & "')"
    End If
    
    On Error Resume Next
    
    If pCNNString <> "" Then
      'retVal = ADO_Lookup(pCNNString, "Vrednost", "SELECT Vrednost FROM " & TablePropName & stWhere)
      retVal = ADO_Lookup(pCNNString, "Vrednost", TablePropName, stWhere)
    Else 'lokalna tabela
      retVal = DLookup("Vrednost", TablePropName, stWhere)
    End If
    
    If (err.Number <> 0 Or IsNull(retVal)) And (SetDefaultTableName <> "") Then      'ako ne postoji u izabranoj TablePropName, ili je NULL
     err.Clear                                          'ond procitaj default vrednost iz CFG_Apl_Parametri_DEF
     stWhere = "([Parametar] = '" & txtParametar & "')"
     retVal = DLookup("[Vrednost]", SetDefaultTableName, stWhere)
     If err.Number <> 0 Then
        retVal = Null
     End If
    End If
    
    If IsEmpty(retVal) Then
     retVal = Null
    End If

Exit_Point:
On Error Resume Next
 ReadParametar = retVal
Exit Function

Err_Point:
  BBErrorMSG err, "ReadParametar"
 retVal = Null
 Resume Exit_Point
End Function
Public Function WriteParametar(TablePropName As String, ByVal txtParametar As String, ByVal txtVal As Variant, Optional ByVal IDFirma, Optional ByVal txtOpis As Variant = Null) As Boolean
'Modifikovano: 22-09-18
'Modifikovano: 16-10-2020
'Modifikovano: 25-10-2021

On Error GoTo err_WriteCFGProp

Dim retVal As Boolean
Dim ADOrst As New ADODB.Recordset
Dim DAOrst As DAO.Recordset
Dim pCNNString As String
Dim stWhere As String
 Dim pIDFirma As Long
 
 If IsMissing(IDFirma) Or IsNull(IDFirma) Then
  pIDFirma = F_IDFirma()
 Else
  pIDFirma = CLng(IDFirma)
 End If
 
    err.Clear

    If TablePropName = "CFG_Lokal" Then
      pCNNString = CNN_CFG_Lokal
      stWhere = "([Parametar] = '" & txtParametar & "') AND ([IDFirma] = " & stR(pIDFirma) & ")"
    ElseIf TablePropName = "CFG_Global" Then
      pCNNString = CNN_CFG_Global
      stWhere = "([Parametar] = '" & txtParametar & "') AND ([IDFirma] = " & stR(pIDFirma) & ")"
    ElseIf TablePropName = "CFG_Sys" Then
      pCNNString = CNN_CFG_Sys 'nema IDFirma
      stWhere = "([Parametar] = '" & txtParametar & "')"
    Else
      pCNNString = "" 'lokalna tabela i nema IDFirma
      stWhere = "([Parametar] = '" & txtParametar & "')"
    End If
    
    If pCNNString <> "" Then
      Set ADOrst = ADO_GetRST(pCNNString, "SELECT * FROM " & TablePropName & " WHERE " & stWhere)
      
      If ADOrst.EOF Then
        ADOrst.AddNew
        
        If TablePropName <> "CFG_Sys" Then 'nema IDFirma
            ADOrst("IDFirma") = pIDFirma
        End If
        ADOrst("Parametar") = txtParametar
        ADOrst("Vrednost") = txtVal
        ADOrst("Opis") = Left(txtOpis, ADOrst("Opis").DefinedSize)
        
        ADOrst.Update
        retVal = True
      Else
        ADOrst("Vrednost") = txtVal
        ADOrst.Update
        retVal = True
      End If
    Else 'lokalna tabela i nema IDFirma
      Set DAOrst = CurrentDb.OpenRecordset("SELECT * FROM " & TablePropName & " WHERE " & stWhere)
      If DAOrst.EOF Then
        DAOrst.AddNew
        DAOrst("Parametar") = txtParametar
        DAOrst("Vrednost") = txtVal
        DAOrst("Opis") = txtOpis
        DAOrst.Update
        retVal = True
      Else
        DAOrst.Edit
        DAOrst("Vrednost") = txtVal
        DAOrst.Update
        retVal = True
      End If
    End If

    
    
exit_err_WriteCFGProp:
On Error Resume Next
    If ADOrst.State <> adStateClosed Then
        ADOrst.Close
    End If
    If Not (DAOrst Is Nothing) Then
        DAOrst.Close
    End If
    Set ADOrst = Nothing
    Set DAOrst = Nothing
    
    WriteParametar = retVal
    
Exit Function

err_WriteCFGProp:
    retVal = False
    BBErrorMSG err, "WriteParametar"
Resume exit_err_WriteCFGProp
End Function
Public Function DeleteParametar(TablePropName As String, ByVal txtParametar As String, ByVal IDFirma As Long) As Boolean
'Modifikovano: 25-10-2021
On Error GoTo Err_Point

Dim retVal As Boolean
Dim ADOrst As New ADODB.Recordset
Dim DAOrst As DAO.Recordset
Dim pCNNString As String
Dim stWhere As String

Dim pIDFirma As Long
 
 If IsMissing(IDFirma) Or IsNull(IDFirma) Then
  pIDFirma = F_IDFirma()
 Else
  pIDFirma = CLng(IDFirma)
 End If
 
    err.Clear

    If TablePropName = "CFG_Lokal" Then
      pCNNString = CNN_CFG_Lokal
      stWhere = "([Parametar] = '" & txtParametar & "') AND ([IDFirma] = " & stR(pIDFirma) & ")"
    ElseIf TablePropName = "CFG_Global" Then
      pCNNString = CNN_CFG_Global
      stWhere = "([Parametar] = '" & txtParametar & "') AND ([IDFirma] = " & stR(pIDFirma) & ")"
    ElseIf TablePropName = "CFG_Sys" Then
      pCNNString = CNN_CFG_Sys
      stWhere = "([Parametar] = '" & txtParametar & "')"
    Else
      pCNNString = "" 'lokalna tabela
      stWhere = "([Parametar] = '" & txtParametar & "')"
    End If
    
    If pCNNString <> "" Then
      Set ADOrst = ADO_GetRST(pCNNString, "SELECT * FROM " & TablePropName & " WHERE " & stWhere)
      If Not ADOrst.EOF Then
        ADOrst.Delete
        retVal = True
      Else
        'nema sloga za brisanje
        retVal = True 'mozda i false
      End If
    Else 'lokalna tabela
      Set DAOrst = CurrentDb.OpenRecordset("SELECT * FROM " & TablePropName & " WHERE " & stWhere)
      If Not DAOrst.EOF Then
        DAOrst.Delete
        DAOrst.Update
        retVal = True
      Else
        'nema sloga za brisanje
        retVal = True 'mozda i false
      End If
    End If

    
    
Exit_Point:
On Error Resume Next
    If ADOrst.State <> adStateClosed Then
        ADOrst.Close
    End If
    If Not (DAOrst Is Nothing) Then
        DAOrst.Close
    End If
    Set ADOrst = Nothing
    Set DAOrst = Nothing
    
    DeleteParametar = retVal
    
Exit Function

Err_Point:
    retVal = False
    BBErrorMSG err, "DeleteParametar"
Resume Exit_Point
End Function
Public Function ParametarUKategoriji(ByVal txtParametar As String, KategorijaParametra) As Boolean
 Dim retValOk As Boolean
 Dim stKatPar As String
 Dim stWhere As String
 stKatPar = Trim(Nz(KategorijaParametra, "*"))
 
 If stKatPar = "*" Then
    retValOk = True
 Else
    stWhere = "([Parametar] = '" & txtParametar & "')"
    stWhere = stWhere & " AND ([KatPar] like '" & stKatPar & "')"
    retValOk = (DCount("*", "CFG_APL_KatParPrip", stWhere) > 0)
 End If
 ParametarUKategoriji = retValOk
End Function
Public Function ParametarPostojiUTabeli(ByVal TablePropName As String, ByVal txtParametar As String, Optional errSilent As Boolean = True, Optional ByVal IDFirma) As Boolean
'Modifikovano: 25-10-2021
On Error GoTo Err_Point

 Dim retValOk As Boolean
 Dim stWhere As String
 Dim pCNNString As String
  Dim pIDFirma As Long
 
 If IsMissing(IDFirma) Or IsNull(IDFirma) Then
  pIDFirma = F_IDFirma()
 Else
  pIDFirma = CLng(IDFirma)
 End If
 
 If TablePropName = "CFG_Lokal" Then
      pCNNString = CNN_CFG_Lokal
      stWhere = "([Parametar] = '" & txtParametar & "') AND ([IDFirma] = " & stR(pIDFirma) & ")"
    ElseIf TablePropName = "CFG_Global" Then
      pCNNString = CNN_CFG_Global
      stWhere = "([Parametar] = '" & txtParametar & "') AND ([IDFirma] = " & stR(pIDFirma) & ")"
    ElseIf TablePropName = "CFG_Sys" Then
      pCNNString = CNN_CFG_Sys
      stWhere = "([Parametar] = '" & txtParametar & "')"
    Else
      pCNNString = "" 'lokalna tabela
      stWhere = "([Parametar] = '" & txtParametar & "')"
    End If
    
    
    
    If pCNNString <> "" Then
        retValOk = (Nz(ADO_Lookup(pCNNString, "BrojSlogova", "SELECT COUNT(*) as BrojSlogova FROM " & TablePropName & " WHERE " & stWhere), 0) > 0)
    Else
        retValOk = (DCount("*", TablePropName, stWhere) > 0)
    End If
    
Exit_Point:
 On Error Resume Next
 ParametarPostojiUTabeli = retValOk
Exit Function
Err_Point:
 If Not errSilent Then
  BBErrorMSG err, "ParametarPostojiUTabeli(" & TablePropName & ", " & txtParametar & ")"
 End If
 retValOk = False
 Resume Exit_Point
End Function
Public Function OtvoriFormuCFGReadWrite()

 If UserUGrupi(CurrentUser, "PowerfulUsers") Or CurrentUser = "Negovan" Then
    DoCmd.OpenForm "CFGReadWrite"
 Else
    'DoCmd.OpenForm ("BBCFG")
    DoCmd.OpenForm "CFGReadWrite"
 End If
End Function

Public Function SamoDozvoljeneVrednostiParametra(txtParametar As String) As Boolean
On Error GoTo Err_Point

 Dim retValOk As Boolean
 Dim stWhere As String
 
 stWhere = "([Parametar] = '" & txtParametar & "')"
 retValOk = CBool(Nz(DLookup("[SamoDozvoljeneVrednosti]", "CFG_Apl_Parametri_DEF", stWhere), False))
 SamoDozvoljeneVrednostiParametra = retValOk
Err_Point:

End Function

Public Function ReadCFGParametar(ByVal txtParametar As String, Optional DefaultVal As Variant, Optional ByVal IDFirma) As Variant
'************************************************************************************************************************************************
'Modifikovano: 06-02-2019
'Modifikovano: 18-08-2019 dodato Optional DefaultVal As Variant
'Parametar mora da bude definisan u tabeli CFG_Apl_Parametri_DEF, inace se vraca DefaultVal tj. NULL ako DefaultVal nije proslednjena
'a da bi se uzela vrednost iz tabele (CFG_Global ili CFG_Lokal) u kojoj je uneta vrednost MORA da bude kolona [GlobalPar] ili [LokalPar] cekirana
'redosled uzimanja parametara je 1.CFG_Lokal -> 2.CFG_Global -> 3.CFG_Apl_Parametri_DEF
'************************************************************************************************************************************************
'Modifikovano: 25-10-2021
'Modifikovano: 27-01-2021 => On Error GoTo err_Point
'************************************************************************************************************************************************
On Error GoTo Err_Point
Dim retValOk As Boolean

Dim DEFPostoji As Boolean
Dim DEFGlobalniParametar As Boolean
Dim DEFLokalniParametar As Boolean

Dim PostojiLokalniParametar As Boolean
Dim PostojiGlobalniParametar As Boolean
Dim retVal As Variant
Dim DoEval As Boolean
Dim stImeTabeleZaParametar As String
 Dim pIDFirma As Long
 
 If IsMissing(IDFirma) Or IsNull(IDFirma) Then
  pIDFirma = F_IDFirma()
 Else
  pIDFirma = CLng(IDFirma)
 End If


DEFPostoji = ParametarPostojiUTabeli("CFG_Apl_Parametri_DEF", txtParametar, True, pIDFirma)

If DEFPostoji Then
  DEFGlobalniParametar = CBool(Nz(DLookup("[GlobalPar]", "CFG_Apl_Parametri_DEF", "[Parametar] = '" & txtParametar & "'"), False))
  DEFLokalniParametar = CBool(Nz(DLookup("[LokalPar]", "CFG_Apl_Parametri_DEF", "[Parametar] = '" & txtParametar & "'"), False))
  DoEval = CBool(Nz(DLookup("[DoEval]", "CFG_Apl_Parametri_DEF", "[Parametar] = '" & txtParametar & "'"), False))
Else
 If Not IsMissing(DefaultVal) Then
  retVal = DefaultVal
 Else
  retVal = Null
 End If
 ReadCFGParametar = retVal
 Exit Function
End If
  
   If DEFLokalniParametar Then
      If DEFGlobalniParametar Then
         retVal = ReadParametar("CFG_Lokal", txtParametar, "CFG_Global", pIDFirma)
         If IsNull(retVal) Then
            retVal = ReadParametar("CFG_Apl_Parametri_DEF", txtParametar, "", pIDFirma)
         End If
      Else
         retVal = ReadParametar("CFG_Lokal", txtParametar, "CFG_Apl_Parametri_DEF", pIDFirma)
      End If
   ElseIf DEFGlobalniParametar Then
     retVal = ReadParametar("CFG_Global", txtParametar, "CFG_Apl_Parametri_DEF", pIDFirma)
   Else
     retVal = ReadParametar("CFG_Apl_Parametri_DEF", txtParametar, "", pIDFirma)
   End If
   

Exit_Point:
 On Error Resume Next
   
   If DoEval Then
    ReadCFGParametar = Eval(retVal)
    If err.Number <> 0 Then
      ReadCFGParametar = retVal
    End If
   Else
    ReadCFGParametar = retVal
   End If

Exit Function

Err_Point:
 BBErrorMSG err, "ReadCFGParametar"
 retValOk = False
 Resume Exit_Point
End Function

Public Function GetLIBCNN(ByVal stCNNName As String) As String
On Error GoTo Err_Point
Dim stRetVal As String

stRetVal = Eval(stCNNName & "()")

Exit_Point:
 On Error Resume Next
 GetLIBCNN = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "GetLIBCNN"
 stRetVal = ""
 Resume Exit_Point
End Function
Public Function RFReadParameter(Par As String, Optional ByVal IDFirma, Optional errSilent As Boolean = False) As Variant
'Modifikovano: 25-10-2021

On Error GoTo err_RFReadParameter

Dim rst As New ADODB.Recordset
Dim retVal
Dim pIDFirma As Long
 
 If IsMissing(IDFirma) Or IsNull(IDFirma) Then
  pIDFirma = F_IDFirma()
 Else
  pIDFirma = CLng(IDFirma)
 End If

    
    Set rst = ADO_GetRST(CNN_CurrentDataBase, "SELECT * FROM [Radni fajlovi] WHERE [IDBaze] = " & stR(pIDFirma))
    
    If rst.EOF And rst.BOF Then
       GoTo exit_RFReadParameter:
    End If
      
    On Error Resume Next
    retVal = rst(Par)
 
exit_RFReadParameter:
On Error Resume Next
    rst.Close
    Set rst = Nothing
    RFReadParameter = retVal
Exit Function

err_RFReadParameter:
    Select Case err.Number
        Case 3265
         MsgBox "Error: " & err.Number & " Parametar [" & Par & "] nije definisan u tabeli [Radni fajlovi]", _
                vbExclamation + vbOKOnly, "QMegaTeh"
    Case Else
     MsgBox "Error: " & err.Number & " " & err.Description
    End Select
    retVal = Null
    Resume exit_RFReadParameter
End Function
Public Function ReadParameter(Par As String, Optional ByVal IDFirma, Optional errSilent As Boolean = False) As Variant
 ReadParameter = RFReadParameter(Par, IDFirma, errSilent)
End Function
