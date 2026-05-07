Attribute VB_Name = "BBSys"
Option Compare Database
Option Explicit

Public Sub TurnOffSubDataSheets()
'
'
'Ovu proceduru treba pokrenuti UNUTAR .MDB fajla sa tabelama
'
'Takodje, treba iskljuciti Track Name Auto Correct Info
'
Dim MyDB As DAO.Database
Dim MyProperty As DAO.Property
Dim propName As String, propVal As String, rplpropValue As String
Dim propType As Integer, i As Integer
Dim intCount As Integer

On Error GoTo tagError

Set MyDB = CurrentDb
propName = "SubDataSheetName"
propType = 10
propVal = "[None]"
rplpropValue = "[Auto]"
intCount = 0

For i = 0 To MyDB.TableDefs.Count - 1
    If (MyDB.TableDefs(i).Attributes And dbSystemObject) = 0 Then
        If MyDB.TableDefs(i).Properties(propName).Value = rplpropValue Then
             MyDB.TableDefs(i).Properties(propName).Value = propVal
             intCount = intCount + 1
        End If
    End If
tagFromErrorHandling:
Next i

MyDB.Close

If intCount > 0 Then
    MsgBox "The " & propName & " value for " & intCount & " non-system tables has been updated to " & propVal & "."
End If

Exit Sub

tagError:
If err.Number = 3270 Then
    Set MyProperty = MyDB.TableDefs(i).CreateProperty(propName)
    MyProperty.Type = propType
    MyProperty.Value = propVal
    MyDB.TableDefs(i).Properties.Append MyProperty
    intCount = intCount + 1
    Resume tagFromErrorHandling
Else
    MsgBox err.Description & vbCrLf & vbCrLf & " u TurnOffSubDataSheets proceduri."
End If
End Sub

Public Sub TurnOffAllawAutoCorrect()
'
'
'Ovu proceduru treba pokrenuti UNUTAR .MDB fajla koji predstavlja APLIKACIJU
'
'MOZE DA POTRAJE!!!
'
'
Dim propName As String
Dim oldPropVal As Boolean, NewPropVal As Boolean
Dim MyForm As Form
Dim MyControl As control
Dim i As Integer
Dim BrojFormi As Integer, brojKontrola As Integer

On Error GoTo tagError

propName = "AllowAutoCorrect"
oldPropVal = True
NewPropVal = False
BrojFormi = CurrentProject.AllForms.Count
brojKontrola = 0

For i = 0 To CurrentProject.AllForms.Count - 1

    DoCmd.OpenForm CurrentProject.AllForms(i).Name, acDesign, , , , acIcon
    Set MyForm = Application.Forms(CurrentProject.AllForms(i).Name)
    
    Debug.Print "Forma: " & CurrentProject.AllForms(i).Name
    
    For Each MyControl In MyForm.Controls
      If (MyControl.ControlType = acComboBox) Or _
         (MyControl.ControlType = acTextBox) Then
             If MyControl.Properties(propName) = oldPropVal Then
                Debug.Print "     " & MyControl.Name, MyControl.ControlType
                'MyControl.AllowAutoCorrect = False
                MyControl.Properties(propName) = NewPropVal
                brojKontrola = brojKontrola + 1
              End If
      End If
    Next
    DoCmd.Close acForm, CurrentProject.AllForms(i).Name, acSaveYes

Next i
    
tagFromErrorHandling:


If brojKontrola > 0 Then
    MsgBox propName & " vrednost je promenjena na " & brojKontrola & " kontrola."
End If

Exit Sub

tagError:

    MsgBox err.Description & vbCrLf & vbCrLf & " u TurnOffAllawAutoCorrect proceduri."
    Resume tagFromErrorHandling

End Sub
Public Sub TurnOffFilter()
'
'
'Ovu proceduru treba pokrenuti UNUTAR .MDB fajla koji predstavlja APLIKACIJU
'
'MOZE DA POTRAJE!!!
'
'
Dim propName As String
Dim oldPropVal As String, NewPropVal As String
Dim MyForm As Form
Dim i As Integer
Dim BrojFormi As Integer

On Error GoTo tagError

propName = "Filter"
NewPropVal = ""
BrojFormi = CurrentProject.AllForms.Count

For i = 0 To CurrentProject.AllForms.Count - 1

    DoCmd.OpenForm CurrentProject.AllForms(i).Name, acDesign, , , , acIcon
    Set MyForm = Application.Forms(CurrentProject.AllForms(i).Name)
    
    Debug.Print "Forma: " & CurrentProject.AllForms(i).Name
    
    MyForm.Properties(propName) = NewPropVal
    DoCmd.Close acForm, CurrentProject.AllForms(i).Name, acSaveYes

Next i
    
tagFromErrorHandling:


If i > 0 Then
    MsgBox propName & " vrednost je promenjena na " & i & " formi."
End If

Exit Sub

tagError:

    MsgBox err.Description & vbCrLf & vbCrLf & " u TurnOffFilter proceduri."
    Resume tagFromErrorHandling

End Sub
Public Sub SetPropForAllForms(propName As String, NewPropVal)
'FilterOnLoad = False
'
'
'Ovu proceduru treba pokrenuti UNUTAR .MDB fajla koji predstavlja APLIKACIJU
'
'MOZE DA POTRAJE!!!
'
'
Dim oldPropVal As String
Dim MyForm As Form
Dim i As Integer
Dim BrojFormi As Integer

On Error GoTo tagError

BrojFormi = CurrentProject.AllForms.Count

For i = 0 To CurrentProject.AllForms.Count - 1

    DoCmd.OpenForm CurrentProject.AllForms(i).Name, acDesign, , , , acIcon
    Set MyForm = Application.Forms(CurrentProject.AllForms(i).Name)
    
   ' If MyForm.Properties(propName).Value = True Then
     Debug.Print "Forma: " & CurrentProject.AllForms(i).Name, propName & " = " & MyForm.Properties(propName).Value
   ' End If
    'MyForm.Properties(propName) = NewPropVal
    DoCmd.Close acForm, CurrentProject.AllForms(i).Name, acSaveYes

Next i
    
tagFromErrorHandling:


If i > 0 Then
    MsgBox propName & " vrednost je promenjena na " & i & " formi."
End If

Exit Sub

tagError:

    MsgBox err.Description & vbCrLf & vbCrLf & " u TurnOffFilter proceduri."
    Resume tagFromErrorHandling

End Sub
Public Sub ZakljucajFormu(ByRef MyForm As Form)

Dim MyControl As control
Dim errPoruka As String

On Error GoTo tagError

    MyForm.AllowEdits = False
    MyForm.AllowAdditions = False
    MyForm.AllowDeletions = False
    
    'Forms!MPRacun![MPRacun-Podforma].[Form].AllowEdits = False
    'Forms!MPRacun![MPRacun-Podforma].[Form].AllowAdditions = False
    'Forms!MPRacun![MPRacun-Podforma].[Form].AllowDeletions = False
    
    On Error Resume Next
    For Each MyControl In MyForm.Controls
      ' If (MyControl.ControlType = acComboBox) Or _
      '   (MyControl.ControlType = acTextBox) Or _
      '   (MyControl.ControlType = acCommandButton) Or _
      '   (MyControl.ControlType = acSubform) Then
         
          MyControl.Locked = True
          MyControl.Enabled = False
      'End If
    Next
    
tagFromErrorHandling:


Exit Sub

tagError:
    errPoruka = err.Description & vbCrLf & vbCrLf & " u ZakljucajFormu proceduri."
    errPoruka = errPoruka & vbCrLf & "Kontrola: " & MyControl.Name
    MsgBox errPoruka
    Resume tagFromErrorHandling

End Sub
Public Sub KreirajTabeluIndexa()
Dim MyDB As DAO.Database
Dim TblInd As DAO.Recordset

Dim i As Integer, j As Integer
Dim idxLoop As Index

On Error GoTo tagError

Set MyDB = CurrentDb
Set TblInd = MyDB.OpenRecordset("BBS_Indexi", dbOpenTable)

For i = 0 To MyDB.TableDefs.Count - 1
    If (MyDB.TableDefs(i).Attributes And dbSystemObject) = 0 Then ' nije sistemska tabela
           
           ' Debug.Print i; MyDB.TableDefs(i).Name
            For Each idxLoop In MyDB.TableDefs(i).Indexes
                ' Debug.Print Tab(20); idxLoop.Name; Tab(32); idxLoop.Fields
                TblInd.AddNew
                TblInd!TableName = MyDB.TableDefs(i).Name
                TblInd!IndexName = idxLoop.Name
                TblInd!IndexExpr = idxLoop.Fields
                TblInd.Update
            Next
         
    End If
 Next i
tagFromErrorHandling:
On Error Resume Next
TblInd.Close
Set TblInd = Nothing
MyDB.Close

Exit Sub

tagError:
    MsgBox err.Description & vbCrLf & vbCrLf & " u proceduri KreirajTabeluIndexa."
    Resume tagFromErrorHandling
End Sub
Public Sub TESTReadInAllQueryProperties(Optional ByVal propName As String = "RecordLocks", Optional ByVal propValue = "*")

Dim MyDB As DAO.Database
Dim MyProperty As DAO.Property
'Dim propVal As String
Dim rplpropValue As String
Dim propType As Integer
Dim i As Integer
Dim intCount As Integer

On Error GoTo tagError
Set MyDB = CurrentDb

' propName = "SubDataSheetName"
' propType = 10
' propVal = "[None]"
' rplpropValue = "[Auto]"
intCount = 0

On Error Resume Next
 For i = 0 To CurrentDb.QueryDefs.Count - 1

      If CStr(MyDB.QueryDefs(i).Properties(propName)) Like CStr(propValue) Then
        Debug.Print i, propName & "=" & MyDB.QueryDefs(i).Properties(propName), MyDB.QueryDefs(i).Name
      End If
tagFromErrorHandling:
Next i


' If intCount > 0 Then
'     MsgBox "The " & propName & " value for " & intCount & " non-system tables has been updated to " & propVal & "."
' End If

MyDB.Close
Set MyDB = Nothing

Exit Sub

tagError:

    ' MsgBox Err.Description & vbCrLf & vbCrLf & " in QueryReadProp routine."
    ' Debug.Print "err=" & Err.Number, MyDB.QueryDefs(i).Name
    Debug.Print i, propName & "=" & "err:" & err.Number, MyDB.QueryDefs(i).Name
    Resume tagFromErrorHandling:
End Sub
Public Sub ReadQueryProperties(QueryName As String)

Dim MyDB As DAO.Database
Dim MyProperty As DAO.Property
Dim propVal As String
Dim rplpropValue As String
Dim propType As Integer
Dim i As Integer
Dim intCount As Integer

On Error GoTo tagError
Set MyDB = CurrentDb

' propName = "SubDataSheetName"
' propType = 10
' propVal = "[None]"
' rplpropValue = "[Auto]"
intCount = 0

 For i = 0 To CurrentDb.QueryDefs(QueryName).Properties.Count - 1
        Debug.Print i, MyDB.QueryDefs(QueryName).Properties(i).Name, MyDB.QueryDefs(QueryName).Properties(i).Value
tagFromErrorHandling:
 Next i



MyDB.Close
Set MyDB = Nothing

Exit Sub

tagError:

     ' Debug.Print i, MyDB.QueryDefs(QueryName).Properties(i).Name & " err:" & Err.Number & " " & Err.Description & vbCrLf & vbCrLf & " in ReadQueryProperties routine."
     Debug.Print i, MyDB.QueryDefs(QueryName).Properties(i).Name & " err:" & err.Number & " " & err.Description
    Resume tagFromErrorHandling:
End Sub

Private Sub TestAllForms()
    Dim obj As AccessObject, dbs As Object
    Set dbs = Application.CurrentProject
    ' Search for open AccessObject objects in AllForms collection.
    For Each obj In dbs.AllForms
        If obj.IsLoaded = True Then
            ' Print name of obj.
            Debug.Print obj.Name, "Loaded"
        Else
            Debug.Print obj.Name, obj.Properties("FilterOnLoad")
        End If
    Next obj
End Sub
Public Sub SetRecordsNoLocksInAllForms()
'
'
'Ovu proceduru treba pokrenuti UNUTAR .MDB fajla koji predstavlja APLIKACIJU
'
'MOZE DA POTRAJE!!!
'
'
Dim propName As String
Dim NewPropVal As Byte
Dim MyForm As Form
Dim i As Integer
Dim BrojPopravljenihFormi As Integer

On Error GoTo tagError

propName = "RecordLocks"
NewPropVal = 0 ' NoLocks
BrojPopravljenihFormi = 0

For i = 0 To CurrentProject.AllForms.Count - 1

    DoCmd.OpenForm CurrentProject.AllForms(i).Name, acDesign, , , , acIcon
    Set MyForm = Application.Forms(CurrentProject.AllForms(i).Name)
    
    If MyForm.Properties(propName) <> NewPropVal Then
     Debug.Print "Forma: " & MyForm.Name, MyForm.Properties(propName)
     MyForm.Properties(propName) = NewPropVal
     BrojPopravljenihFormi = BrojPopravljenihFormi + 1
    End If
    DoCmd.Close acForm, CurrentProject.AllForms(i).Name, acSaveYes

Next i
    
tagFromErrorHandling:

    MsgBox propName & " vrednost je promenjena na " & BrojPopravljenihFormi & " formi."

Exit Sub

tagError:

    MsgBox err.Description & vbCrLf & vbCrLf & " u SetRecordsNoLocksInAllForms proceduri."
    Resume tagFromErrorHandling

End Sub
Public Sub SetRecordsNoLocksInAllQueries()

Dim MyDB As DAO.Database
Dim MyProperty As DAO.Property
Dim propName As String
Dim propValue As Byte
Dim rplpropValue As Byte
Dim propType As Integer
Dim i As Integer
Dim intCountZamena As Integer
Dim intCountDodavanje As Integer

On Error GoTo tagError
Set MyDB = CurrentDb

 propName = "RecordLocks"
 propType = dbByte
 propValue = 2      ' EditidRecord
 rplpropValue = 0   ' NoLocks
 intCountZamena = 0
 intCountDodavanje = 0

' On Error Resume Next
 For i = 0 To CurrentDb.QueryDefs.Count - 1
      If MyDB.QueryDefs(i).Properties(propName) = propValue Then
        Debug.Print i, "Zamena " & propName & "=" & MyDB.QueryDefs(i).Properties(propName), MyDB.QueryDefs(i).Name
        ' MyDB.QueryDefs(i).Properties(propName) = rplpropValue
        intCountZamena = intCountZamena + 1
      Else
        Debug.Print i, "Zamena " & propName & "=" & MyDB.QueryDefs(i).Properties(propName), MyDB.QueryDefs(i).Name
      End If
tagFromErrorHandling:
Next i

     MsgBox "Propertis " & propName & " je ZAMENJEN= " & intCountZamena & " +  DODAT= " & intCountDodavanje & " na upitima. Vrednost=" & rplpropValue & "."

MyDB.Close
Set MyDB = Nothing

Exit Sub

tagError:
    If err.Number = 3270 Then
        ' Set MyProperty = MyDB.QueryDefs(i).CreateProperty(propName)
        ' MyProperty.Type = propType
        ' MyProperty.Value = rplpropValue
        ' MyDB.QueryDefs(i).Properties.Append MyProperty
        Debug.Print i, "Dodavanje " & propName & "=" & rplpropValue, MyDB.QueryDefs(i).Name
        intCountDodavanje = intCountDodavanje + 1
    Resume tagFromErrorHandling
    Else
     MsgBox err.Description & vbCrLf & vbCrLf & " u SetRecordsNoLocksInAllQueries proceduri."
    ' Debug.Print "err=" & Err.Number, MyDB.QueryDefs(i).Name
    ' Debug.Print i, propName & "=" & "err:" & Err.Number, MyDB.QueryDefs(i).Name
     Resume tagFromErrorHandling:
    End If
End Sub

Public Function ListaSvihFormi() As String
 Dim i As Integer
 Dim chsep As String
 Dim retVal As String
 
 chsep = ";"
 retVal = ""
    For i = 0 To CurrentProject.AllForms.Count - 1
        retVal = retVal & chsep & CurrentProject.AllForms(i).Name
    Next i
 ListaSvihFormi = retVal
End Function
Public Function ListaOtvorenihFormi() As String
 Dim i As Integer
 Dim chsep As String
 Dim retVal As String
 
 chsep = ";"
 retVal = ""
    For i = 0 To Application.Forms.Count - 1
        retVal = retVal & chsep & Application.Forms.Item(i).Name
    Next i
 ListaOtvorenihFormi = retVal
End Function
Public Function ListaSvihTabela(Optional stPutanjeDoAccessBaze As String = "") As String
'Modifikovano: 23-09-2019

On Error GoTo Err_Point
 Dim i As Integer
 Dim chsep As String
 Dim retVal As String
 Dim dbUBazi As DAO.Database
 
 chsep = ";"
 retVal = ""
 
 If IsMissing(stPutanjeDoAccessBaze) Or Nz(stPutanjeDoAccessBaze) = "" Then
  Set dbUBazi = CurrentDb
 Else
  Set dbUBazi = OpenDatabase(stPutanjeDoAccessBaze)
 End If
 
    For i = 0 To dbUBazi.TableDefs.Count - 1
        retVal = retVal & chsep & dbUBazi.TableDefs(i).Name
    Next i

Exit_Point:
 On Error Resume Next
 dbUBazi.Close
 Set dbUBazi = Nothing
 ListaSvihTabela = retVal

Exit Function

Err_Point:
 BBErrorMSG err, "ListaSvihTabela"
 Resume Exit_Point
End Function
Public Function DisplayApplicationInfo(obj As Object) As Integer
    Dim objApp As Object, intI As Integer, strProps As String
    On Error Resume Next
        ' Form Application property.
        Set objApp = obj.Application
        MsgBox "Application Visible property = " & objApp.Visible
        If objApp.UserControl = True Then
        For intI = 0 To objApp.DBEngine.Properties.Count - 1
            strProps = strProps & objApp.DBEngine.Properties(intI).Name & ", "
        Next intI
        End If
        MsgBox Left(strProps, Len(strProps) - 2) & ".", vbOK, "DBEngine Properties"
End Function

Public Function UsersAndGroups()
'Modifikovano: 04-02-2020
On Error GoTo Err_Point

Dim stInputRetVal As String
Dim stMsg As String

    stMsg = ""
    stMsg = stMsg & vbCrLf & "1 - Access Accounts"
    stMsg = stMsg & vbCrLf & "2 - Access Permissions"
    stMsg = stMsg & vbCrLf & "3 - BigBit Permissions"
    stMsg = stMsg & vbCrLf
    stMsg = stMsg & vbCrLf & "0 - Cancel"
   Do
    stInputRetVal = InputBox(stMsg, "QMegaTeh", "0")
   Loop Until stInputRetVal = "1" Or stInputRetVal = "2" Or stInputRetVal = "3" Or stInputRetVal = "0" Or stInputRetVal = ""
   
   Select Case stInputRetVal
     Case "1": DoCmd.RunCommand acCmdUserAndGroupAccounts
     Case "2": DoCmd.RunCommand acCmdUserAndGroupPermissions
     Case "3": BBOpenForm "BBPravaPristupa"
     Case Else
        GoTo Exit_Point
   End Select
   
Exit_Point:
 On Error Resume Next
 
Exit Function

Err_Point:
 BBErrorMSG err, "UsersAndGroups"
 Resume Exit_Point
End Function
Public Function ListaSvihUpitaCijiTextSadrziRec(stTrazenaRec As String) As String
'************************
'Pažljivo
'Vrlo sporo radi!
'************************
 Dim i As Integer
 Const chsep = vbCrLf '";"
 Dim stRetVal As String
     For i = 0 To CurrentDb.QueryDefs.Count - 1
      If InStr(CurrentDb.QueryDefs(i).sql, stTrazenaRec) > 0 Then
       stRetVal = stRetVal & chsep & CurrentDb.QueryDefs(i).Name
       Debug.Print CurrentDb.QueryDefs(i).Name
      End If
      'Debug.Print i
     Next i
     ListaSvihUpitaCijiTextSadrziRec = stRetVal
End Function
Public Function ListaSvihUpitaCijiNazivSadrziRec(stTrazenaRec As String) As String
'************************
'Pažljivo
'Vrlo sporo radi!
'************************
 Dim i As Integer
 Const chsep = vbCrLf '";"
 Dim stRetVal As String
     For i = 0 To CurrentDb.QueryDefs.Count - 1
      If InStr(CurrentDb.QueryDefs(i).Name, stTrazenaRec) > 0 Then
       stRetVal = stRetVal & chsep & CurrentDb.QueryDefs(i).Name
      End If
     Next i
     ListaSvihUpitaCijiNazivSadrziRec = stRetVal
End Function
'========================================================================================
'Public Function HideNavigationPane_NeRadi()
'Datum: 31-08-18
 'select the navigation pange
'ovo ne radi u Accessu 2003 => Call DoCmd.NavigateTo("acNavigationCategoryObjectType")
 'hide the selected object
 'Call DoCmd.RunCommand(acCmdWindowHide)
 'End Function
'========================================================================================

Public Sub HideNavPane(bVisible As Boolean)
'Datum: 31-08-18
    On Error GoTo Error_Handler
Exit Sub

    If Not SysCmd(acSysCmdRuntime) Then  '= False Then 'ako nije RunTime
        If bVisible Then
            '            DoCmd.SelectObject acTable, , True
            DoCmd.SelectObject acModule, , True
            DoCmd.RunCommand acCmdWindowUnhide
        Else
            '           DoCmd.SelectObject acTable, , True
            '           DoCmd.SelectObject acTable, "_Rev", True
            '           DoCmd.NavigateTo ("acNavigationCategoryObjectType")
                        
            DoCmd.SelectObject acModule, , True
            DoCmd.RunCommand acCmdWindowHide
        End If
    End If
 
Error_Handler_Exit:
    On Error Resume Next
    Exit Sub
 
Error_Handler:
    MsgBox "The following error has occured" & vbCrLf & vbCrLf & _
           "Error Number: " & err.Number & vbCrLf & _
           "Error Source: HideNavPane" & vbCrLf & _
           "Error Description: " & err.Description _
           , vbOKOnly + vbCritical, "An Error has Occured!"
    Resume Error_Handler_Exit
End Sub
Public Sub CountObjects()
' Created: 28-11-2018

    Dim qdf As DAO.QueryDef
    Dim obj As Object
    Dim tdf As DAO.TableDef
    Dim i As Long
    Dim amp As String
    Dim TotalObj As Long
    
    amp = ""
    i = 0
    Debug.Print
    For Each tdf In CurrentDb.TableDefs
        If Left(tdf.Name, 4) = "MSys" Then
            i = i + 1
        End If
    Next tdf
    Debug.Print "Number of tables: " & amp; CurrentDb.TableDefs.Count; "    (Msys = " & i & ")"
    
    'Determine number of queries
    Debug.Print "Number of Queries: " & amp; CurrentDb.QueryDefs.Count
    
    'Determine number of forms
    Debug.Print "Number of Forms: " & amp; CurrentProject.AllForms.Count
    
    'Determine number of Macros
    Debug.Print "Number of Macros: " & amp; CurrentProject.AllMacros.Count
    
    'Determine number of reports
    Debug.Print "Number of Reports: " & amp; CurrentProject.AllReports.Count
 
    TotalObj = CurrentDb.TableDefs.Count + CurrentDb.QueryDefs.Count + CurrentProject.AllForms.Count + CurrentProject.AllMacros.Count + CurrentProject.AllReports.Count
    Debug.Print "==================================="
    Debug.Print "Total of Objects: " & amp; TotalObj
    
End Sub

Public Function OpenTable(stImeTabele As String) As Boolean
'Kreirano 20-12-2019
 On Error GoTo Err_Point
    Dim Poruka As String
    
    If Not PostojiTabelaUBazi(stImeTabele, CurrentDb) Then
     MsgBox "Ne postoji tabela.", vbExclamation, "QMegaTeh"
    ElseIf SysCheckLink(stImeTabele) Then
      DoCmd.OpenTable stImeTabele, acNormal, acEdit
    Else
      Poruka = "Tabela nije dostupna." & vbCrLf & vbCrLf
      Poruka = Poruka & "CnnString: " & CurrentDb.TableDefs(stImeTabele).Connect
      MsgBox Poruka, vbExclamation, "QMegaTeh"
    End If

Exit_Point:
    Exit Function

Err_Point:
    MsgBox err.Description
    Resume Exit_Point

End Function
Public Function ListaSvihReporta(Optional stLikeUslov As String = "*", Optional chsep As String = ";") As String
On Error GoTo Err_Point
 Dim i As Integer
 Dim retVal As String
 
 retVal = ""
 If Nz(stLikeUslov, "") = "" Then
    stLikeUslov = "*"
 End If
    For i = 0 To CurrentProject.AllReports.Count - 1
        If CurrentProject.AllReports(i).Name Like stLikeUslov Then
            If retVal <> "" Then retVal = retVal & chsep
            retVal = retVal & CurrentProject.AllReports(i).Name
        End If
    Next i
Exit_Point:
 On Error Resume Next
       ListaSvihReporta = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "ListaSvihReporta"
 Resume Exit_Point
End Function
