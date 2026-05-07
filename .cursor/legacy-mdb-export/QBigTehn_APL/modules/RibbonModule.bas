Attribute VB_Name = "RibbonModule"
Option Compare Database
Option Explicit
Public Function PromeniRibbon(noviRibbon As String) As Boolean
On Error GoTo Err_Point
' Postavlja novi Ribbon
    Dim retValOk As Boolean
    retValOk = True
    
    Application.CurrentDb.Properties("RibbonName") = noviRibbon

    ' Osvežava prikaz Ribbona
    DoCmd.ShowToolbar "Ribbon", acToolbarNo  ' Sakriva trenutni Ribbon
    DoCmd.ShowToolbar "Ribbon", acToolbarYes ' Prikazuje novi Ribbon
    
Exit_Point:
    On Error Resume Next
    PromeniRibbon = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "PromeniRibbon"
    retValOk = False
    Resume Exit_Point
End Function

Public Sub ExitApplication(control As IRibbonControl)
    DoCmd.Quit
End Sub
Public Sub OnRibbonClick(control As IRibbonControl)
On Error GoTo Err_Point

    Dim retValOk As Boolean
    Dim FormName As String
    Dim stOpenArgs As String
    
    retValOk = True
    
    FormName = Nz(NazivFormaZaOnActionRibbonbtnClick(control.ID, stOpenArgs), "")
    
    If FormName = "" Then
        MsgBox "Ne postoji definisana akcija za izabranu komandu.", vbExclamation, "QMegaApl"
        retValOk = False
        Exit Sub
    End If
    If IsLoaded(FormName) Then
        DoCmd.Close acForm, FormName
    End If
    
    If IsLoaded(FormName) Then
        MsgBox "Izabrana forma je veæ otvorena", vbExclamation, "QMegaApl"
        retValOk = False
        Exit Sub
    End If
    
    ' Otvaranje forme sa OpenArgs
    If Len(stOpenArgs) > 0 Then
        'DoCmd.OpenForm FormName, , , , , , stOpenArgs
        BBOpenForm FormName, , , , , , stOpenArgs
    Else
        'DoCmd.OpenForm FormName
        BBOpenForm FormName
    End If
    
    If Not IsLoaded(FormName) Then
        MsgBox "Ne može da se otvori forma [" & FormName & "]. Obavestite administratora.", vbExclamation, "QMegaApl"
        retValOk = False
        Exit Sub
    End If
    
Exit_Point:
    On Error Resume Next
    Exit Sub

Err_Point:
    BBErrorMSG err, "OnRibbonClick"
    retValOk = False
    Resume Exit_Point
End Sub

Public Function NazivFormaZaOnActionRibbonbtnClick(ByVal pBtnIDName As String, Optional ByRef pFormOpenArgs As String) As String
On Error GoTo Err_Point

    Dim rst As DAO.Recordset
    Dim pFormName As String
    
    pFormName = ""
    pFormOpenArgs = ""
    
    Set rst = CurrentDb.OpenRecordset( _
        "SELECT FormName, stOpenArgs FROM RibbonOnClickDetails " & _
        "WHERE btnIDName = '" & Replace(pBtnIDName, "'", "''") & "'", dbOpenSnapshot)
    
    If Not (rst.BOF And rst.EOF) Then
        pFormName = Nz(rst!FormName, "")
        pFormOpenArgs = Nz(rst!stOpenArgs, "")
    End If
    
Exit_Point:
    On Error Resume Next
    rst.Close
    Set rst = Nothing
    NazivFormaZaOnActionRibbonbtnClick = pFormName
    Exit Function

Err_Point:
    MsgBox "Err: " & err.Number & vbCrLf & err.Description, vbExclamation
    Resume Exit_Point
End Function

Public Function RibbonNameZaIzabranuFormuIUsera(pFormName As String) As String
'NazivFormaZaOnActionRibbonbtnClick
On Error GoTo Err_Point
    Dim pRibbonName As Variant
    Dim rstRibbonOnForm As Recordset
    Dim stWhere As String
    Dim pIDGrupe As Long
    Dim pSifraRadnika As Long
    
    pSifraRadnika = IDRadnikZaCurrentUser()
    
    If UserUGrupi(CurrentUser(), "Admins") Then
        pIDGrupe = 0
    Else
        pIDGrupe = Nz(DLookup("IDGrupe", "RibbonRadniciGrupeDef", "SifraRadnika = " & pSifraRadnika), -1)
    End If
    
    stWhere = "[FormName] = '" & pFormName & "' AND [IDGrupe] = " & pIDGrupe
    
    'pRibbonName = ""
    'Set rstRibbonOnForm = CurrentDb.OpenRecordset("RibbonOnForm", dbOpenDynaset)
    
    'rstRibbonOnForm.FindFirst "[FormName] = '" & pFormName & "'"
    
    'If rstRibbonOnForm.NoMatch Then
     'pRibbonName = ""
    'Else
    ' pRibbonName = rstRibbonOnForm!RibbonName
    'End If
    pRibbonName = Nz(DLookup("RibbonName", "RibbonOnForm", stWhere), "")
   
Exit_Point:

   On Error Resume Next
   rstRibbonOnForm.Close
   RibbonNameZaIzabranuFormuIUsera = pRibbonName
Exit Function

Err_Point:
    MsgBox "Err: " & err.Number & vbCrLf & err.Description
    Resume Exit_Point
End Function
Public Sub PopuniTabeluRibbonAllForm()
    Dim db As DAO.Database
    Dim tDef As DAO.TableDef
    Dim fld As DAO.Field
    Dim sqlInsert As String
    Dim obj As AccessObject
    Dim formNames As Collection
    Dim FormName As Variant

    On Error GoTo ErrorHandler

    ' Otvoriti trenutnu bazu
    Set db = CurrentDb

    '' Proveriti da li tabela veæ postoji
    'On Error Resume Next
    'db.TableDefs.Delete "RibbonAllForm"
    'On Error GoTo 0

    '' Kreirati novu tabelu
    'Set tDef = db.CreateTableDef("RibbonAllForm")

    '' Dodati polja
    'Set fld = tDef.CreateField("ID", dbLong)
    'fld.Attributes = dbAutoIncrField ' AutoNumber polje
    
    'tDef.Fields.Append fld

    'Set fld = tDef.CreateField("RibbonName", dbText)
    'fld.AllowZeroLength = True
    'tDef.Fields.Append fld

    'Set fld = tDef.CreateField("FormName", dbText)
    'fld.Required = True ' Obavezno polje
    'tDef.Fields.Append fld

    '' Postaviti indeks za jedinstvene vrednosti u FormName koloni
    'Dim idx As DAO.Index
    'Set idx = tDef.CreateIndex("FormNameIndex")
    'With idx
    '    .Fields.Append .CreateField("FormName")
    '    .UNIQUE = True ' Jedinstvenost
    'End With
    'tDef.Indexes.Append idx

    '' Dodati tabelu u bazu
    'db.TableDefs.Append tDef

    ' Sakupiti nazive formi u kolekciju
    Set formNames = New Collection
    For Each obj In CurrentProject.AllForms
        formNames.Add obj.Name
    Next obj

    ' Sortirati nazive formi (koristi se VBA funkcija za sortiranje)
    Set formNames = SortCollection(formNames)

    ' Popuniti tabelu sortiranim nazivima formi
    For Each FormName In formNames
        sqlInsert = "INSERT INTO RibbonAllForm (FormName) VALUES ('" & Replace(FormName, "'", "''") & "');"
        db.Execute sqlInsert, dbFailOnError
    Next FormName

    MsgBox "Tabela 'RibbonAllForm' je uspešno popunjena sa sortiranim nazivima formi!", vbInformation

CleanUp:
    ' Oèistiti resurse
    'Set idx = Nothing
    'Set fld = Nothing
    'Set tDef = Nothing
    Set db = Nothing
    Exit Sub

ErrorHandler:
    MsgBox "Došlo je do greške: " & err.Description, vbCritical
    Resume CleanUp
End Sub

Private Function SortCollection(col As Collection) As Collection
    Dim i As Long, j As Long
    Dim sortedCol As New Collection
    Dim temp() As String
    Dim tempStr As String

    ' Kopirati kolekciju u niz za sortiranje
    ReDim temp(1 To col.Count)
    For i = 1 To col.Count
        temp(i) = col(i)
    Next i

    ' Sortirati niz (Bubble Sort)
    For i = LBound(temp) To UBound(temp) - 1
        For j = i + 1 To UBound(temp)
            If temp(i) > temp(j) Then
                tempStr = temp(i)
                temp(i) = temp(j)
                temp(j) = tempStr
            End If
        Next j
    Next i

    ' Dodati sortirane vrednosti nazad u kolekciju
    For i = LBound(temp) To UBound(temp)
        sortedCol.Add temp(i)
    Next i

    Set SortCollection = sortedCol
End Function
Public Sub PreuzmiIzBigBitaRibbon(control As IRibbonControl)
    Select Case control.ID
        Case "btnPreuzmiIzBB"
            Call PreuzmiIzBB
        ' dodaj druge dugmiæe po potrebi
    End Select
End Sub
Public Function PreuzmiIzBB() As Boolean
    On Error GoTo Err_Point
    Dim retValOk As Boolean
    
    retValOk = True
    DoCmd.Hourglass True
    
    retValOk = retValOk And UradiImportIzTabeleUTabelu("EXT_Vrste sifara", "Vrste sifara", stSQL_Append_VrsteKomitentaIzBigBita)
    
    If retValOk Then
        retValOk = retValOk And DodajNoveProdavceIzBigBita
    Else
        GoTo Exit_Point:
    End If
    If retValOk Then
        retValOk = retValOk And DodajNoveKomitenteIzBigBita
    Else
        GoTo Exit_Point:
    End If
    If retValOk Then
        retValOk = retValOk And DodajNovePredmeteIzBigBita
    Else
        GoTo Exit_Point:
    End If
    
    If retValOk Then
        retValOk = retValOk And DodajNoveArtikleIzBigBita
    Else
        GoTo Exit_Point:
    End If
    
Exit_Point:
    DoCmd.Hourglass False
    If retValOk Then
        BBMsgBox_BigBit "Podaci su preuzeti", 1
    Else
        BBMsgBox_BigBit "Podaci NISU preuzeti", 1
    End If
    Exit Function

Err_Point:
    MsgBox Error$
    retValOk = False
    Resume Exit_Point
End Function
Public Function GetIkonicaPreuzimanje(control As IRibbonControl, ByRef image)
    Set image = CurrentProject.Images("icImport")
End Function
