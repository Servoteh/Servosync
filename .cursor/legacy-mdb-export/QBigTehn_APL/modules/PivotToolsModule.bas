Attribute VB_Name = "PivotToolsModule"
Option Compare Database
Option Explicit

Public Function KreirajLokalnuTabeluStrukture( _
        Optional ByVal LocalTableName As String = "tStrukturaProizvodaTMP") As Boolean
On Error GoTo Err_Point

    Dim db As DAO.Database
    Dim rsSQL As ADODB.Recordset
    Dim fld As ADODB.Field
    Dim tdf As DAO.TableDef
    Dim f As DAO.Field
    Dim i As Integer
    Dim fldType As Long
    Dim retVal As Boolean
    Dim stSQL As String

    '=== 1??  Formiraj EXEC string pomoæu tvog PassThrough sistema
    stSQL = PassTroughQueryEvalAllPar("ODBC_spStrukturaProizvodaZaIzvestaj")
    If Len(Trim(stSQL)) = 0 Then
        MsgBox "Nije pronaðena definicija SQL teksta za 'spStrukturaProizvodaZaIzvestaj'.", vbExclamation
        GoTo Exit_Point
    End If

    '=== 2??  Brišemo staru lokalnu tabelu
    Set db = CurrentDb
    On Error Resume Next
    db.TableDefs.Delete LocalTableName
    db.TableDefs.Refresh
    On Error GoTo Err_Point

    '=== 3??  Izvršimo SQL i dobijemo Recordset koristeæi tvoj alat
    Set rsSQL = ADO_GetRST(CNN_CurrentDataBase, stSQL, adLockReadOnly, adUseClient, adOpenForwardOnly, True, 180)

    If rsSQL Is Nothing Or (rsSQL.EOF And rsSQL.BOF) Then
        MsgBox "Procedura nije vratila podatke.", vbInformation
        GoTo Exit_Point
    End If

    '=== 4??  Kreiraj lokalnu tabelu u .mdb sa istim kolonama kao rezultat procedure
    Set tdf = db.CreateTableDef(LocalTableName)
    For Each fld In rsSQL.Fields
        Select Case fld.Type
            Case 3, 20, 131
                fldType = dbLong
            Case 5, 6
                fldType = dbDouble
            Case 7, 133, 134, 135
                fldType = dbDate
            Case 11
                fldType = dbBoolean
            Case Else
                fldType = dbText
        End Select
        'Set f = tdf.CreateField(fld.Name, fldType)
        Dim SafeName As String
        SafeName = fld.Name
        SafeName = Replace(SafeName, ".", "_") ' taèke u imenu › donje crte
        If IsNumeric(Left(SafeName, 1)) Then SafeName = "OP_" & SafeName ' ako poèinje cifrom, dodaj prefiks
        Set f = tdf.CreateField(SafeName, fldType)

        tdf.Fields.Append f
    Next fld
    db.TableDefs.Append tdf
    db.TableDefs.Refresh

    '=== 5??  Upisi sve redove iz Recordset-a u lokalnu Access tabelu
    Dim rsLocal As DAO.Recordset
    Set rsLocal = db.OpenRecordset(LocalTableName, dbOpenDynaset)
    Do While Not rsSQL.EOF
        rsLocal.AddNew
        For i = 0 To rsSQL.Fields.Count - 1
            rsLocal.Fields(i).Value = rsSQL.Fields(i).Value
        Next i
        rsLocal.Update
        rsSQL.MoveNext
    Loop
    rsLocal.Close

    '=== 6??  Sve prošlo OK
    retVal = True
    'MsgBox "Lokalna tabela '" & LocalTableName & "' uspešno kreirana iz SQL izvora.", vbInformation

Exit_Point:
    On Error Resume Next
    If Not rsSQL Is Nothing Then rsSQL.Close
    Set rsSQL = Nothing
    Set db = Nothing
    KreirajLokalnuTabeluStrukture = retVal
    Exit Function

Err_Point:
    MsgBox "Greška: " & err.Description, vbCritical, "KreirajLokalnuTabeluStrukture"
    retVal = False
    Resume Exit_Point
End Function

Public Function KreirajLokalnuTablicuIzSP( _
        ByVal SPName As String, _
        Optional ByVal LocalTableName As String = "tSP_Temp" _
    ) As Boolean
On Error GoTo Err_Point

    Dim db As DAO.Database
    Dim rsSQL As ADODB.Recordset
    Dim fld As ADODB.Field
    Dim tdf As DAO.TableDef
    Dim f As DAO.Field
    Dim i As Integer
    Dim fldType As Long
    Dim retVal As Boolean
    Dim stSQL As String

    '=== 1?? Formiraj EXEC string pomoæu tvog PassThrough sistema
    stSQL = PassTroughQueryEvalAllPar(SPName)
    If Len(Trim(stSQL)) = 0 Then
        MsgBox "Nije pronaðena definicija SQL teksta za '" & SPName & "'.", vbExclamation
        GoTo Exit_Point
    End If

    '=== 2?? Obriši staru lokalnu tabelu ako postoji
    Set db = CurrentDb
    On Error Resume Next
    db.TableDefs.Delete LocalTableName
    db.TableDefs.Refresh
    On Error GoTo Err_Point

    '=== 3?? Izvrši SQL i dobij Recordset
    Set rsSQL = ADO_GetRST(CNN_CurrentDataBase, stSQL, _
                            adLockReadOnly, adUseClient, adOpenForwardOnly, True, 180)

    If rsSQL Is Nothing Or (rsSQL.EOF And rsSQL.BOF) Then
        MsgBox "Procedura '" & SPName & "' nije vratila podatke.", vbInformation
        GoTo Exit_Point
    End If

    '=== 4?? Kreiraj novu lokalnu tabelu po strukturi SP-a
    Set tdf = db.CreateTableDef(LocalTableName)
    For Each fld In rsSQL.Fields

        ' Odredi tip polja
        Select Case fld.Type
            Case adInteger, adBigInt, adSmallInt, adTinyInt
                fldType = dbLong
            Case adNumeric, adDecimal, adDouble, adSingle, adCurrency
                fldType = dbDouble
            Case adDate, adDBDate, adDBTime, adDBTimeStamp
                fldType = dbDate
            Case adBoolean
                fldType = dbBoolean
            Case Else
                fldType = dbText
        End Select

        ' Pripremi sigurno ime polja
        Dim SafeName As String
        SafeName = fld.Name
        SafeName = Replace(SafeName, ".", "_")
        SafeName = Replace(SafeName, " ", "_")
        SafeName = Replace(SafeName, "-", "_")
        If IsNumeric(Left(SafeName, 1)) Then SafeName = "F_" & SafeName

        ' Dodaj polje
        Set f = tdf.CreateField(SafeName, fldType)
        If fldType = dbText Then
            f.Size = IIf(fld.DefinedSize > 0 And fld.DefinedSize < 255, fld.DefinedSize, 255)
        End If
        tdf.Fields.Append f
    Next fld

    db.TableDefs.Append tdf
    db.TableDefs.Refresh

    '=== 5?? Upisi sve slogove
    Dim rsLocal As DAO.Recordset
    Set rsLocal = db.OpenRecordset(LocalTableName, dbOpenDynaset)
    Do While Not rsSQL.EOF
        rsLocal.AddNew
        For i = 0 To rsSQL.Fields.Count - 1
            ' konverzija datuma – zaštita od NULL
            If Not IsNull(rsSQL.Fields(i).Value) Then
                If rsSQL.Fields(i).Type = adDate Or _
                   rsSQL.Fields(i).Type = adDBDate Or _
                   rsSQL.Fields(i).Type = adDBTime Or _
                   rsSQL.Fields(i).Type = adDBTimeStamp Then
                       rsLocal.Fields(i).Value = CDate(rsSQL.Fields(i).Value)
                Else
                       rsLocal.Fields(i).Value = rsSQL.Fields(i).Value
                End If
            End If
        Next i
        rsLocal.Update
        rsSQL.MoveNext
    Loop
    rsLocal.Close

    '=== 6?? Sve je prošlo OK
    retVal = True
    'MsgBox "Lokalna tabela '" & LocalTableName & "' uspešno kreirana iz procedure '" & SPName & "'.", vbInformation

Exit_Point:
    On Error Resume Next
    If Not rsSQL Is Nothing Then rsSQL.Close
    Set rsSQL = Nothing
    Set db = Nothing
    KreirajLokalnuTablicuIzSP = retVal
    Exit Function

Err_Point:
    MsgBox "Greška: " & err.Description, vbCritical, "KreirajLokalnuTablicuIzSP"
    retVal = False
    Resume Exit_Point
End Function


