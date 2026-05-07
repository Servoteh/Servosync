Attribute VB_Name = "BBCMD_SYS"
'************************************
' Datum: 12-08-18
'************************************
Option Compare Database
Option Explicit

Public Function IzberiMDBFajl(ByRef ImeFajla) As Variant
 Dim retVal
    retVal = IzaberiBazu
    If Nz(retVal, "") <> "" Then
        ImeFajla = retVal
    End If
    IzberiMDBFajl = ImeFajla
End Function
Private Sub AppendDeleteField(tdfTemp As TableDef, strCommand As String, strName As String, Optional varType, Optional varSize)

    With tdfTemp

        ' Check first to see if the TableDef object is
        ' updatable. If it isn't, control is passed back to
        ' the calling procedure.
        If .Updatable = False Then
            MsgBox "TableDef not Updatable! " & _
                "Unable to complete task."
            Exit Sub
        End If

        ' Depending on the passed data, append or delete a
        ' field to the Fields collection of the specified
        ' TableDef object.
        If strCommand = "APPEND" Then
            .Fields.Append .CreateField(strName, _
                varType, varSize)
        Else
            If strCommand = "DELETE" Then .Fields.Delete _
                strName
        End If
    
    End With

End Sub
Public Function DodajNovaPoljaUTabelu(IzBaze As String, UBazu As String, imeTabele As String) As Boolean

On Error GoTo err_DodajNovaPoljaUTabelu

 'IzBaze = "D:\AcBaze\MojBigBit\TG\BB_T_TG.mdb"
 'UBazu = "D:\AcBaze\MojBigBit\Test_Tabele.MDB"
 'ImeTabele = "R_Tarife"
 
 Dim retVal As Boolean
 Dim dbIzBaze As DAO.Database
 Dim dbUBazu As DAO.Database
 
 Dim IzTabele As DAO.TableDef
 Dim UTabelu As DAO.TableDef
 
 Dim polje As DAO.Field
 Dim NovoPolje As DAO.Field
 
 Dim nQuery As DAO.QueryDef
 
 Dim i As Integer
 
 retVal = True
 Set dbIzBaze = OpenDatabase(IzBaze)
 'Set dbIzBaze = CurrentDb
 Set IzTabele = dbIzBaze.TableDefs(imeTabele)
 
 'PrikaziPoljaIzTabele IzTabele
 
 Set dbUBazu = OpenDatabase(UBazu)
 Set UTabelu = dbUBazu.TableDefs(imeTabele)
 
 If Not UTabelu.Updatable Then
    MsgBox "Tabela " & imeTabele & " u bazi " & UBazu & " nije UPDATABLE. Proces se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    GoTo exit_DodajNovaPoljaUTabelu
 End If
 
 'PrikaziPoljaIzTabele UTabelu
 
 For Each polje In IzTabele.Fields
    If Not PostojiPoljeUTabeli(polje.Name, UTabelu) Then
        'mora da se kreira novo polje za !
        Set NovoPolje = UTabelu.CreateField(polje.Name, polje.Type, polje.Size)
        'If polje.Type = dbText Then
        '    novopolje.AllowZeroLength = polje.AllowZeroLength
        'End If
        'novopolje.DefaultValue = polje.DefaultValue
        'novopolje.Required = polje.Required
        'novopolje.ValidationRule = polje.ValidationRule
        'novopolje.ValidationText = polje.ValidationText
        
        'neki propertisi ne mogu da se prepisu i bas me briga
        'neka prepise ono sto moze
        On Error Resume Next
        For i = 1 To polje.Properties.Count
            NovoPolje.Properties(i).Value = polje.Properties(i).Value
        Next i
        On Error GoTo err_DodajNovaPoljaUTabelu
        UTabelu.Fields.Append NovoPolje
        UpdateNewFieldDefault dbUBazu, UTabelu, NovoPolje
    End If
 Next polje
   
    
exit_DodajNovaPoljaUTabelu:
On Error Resume Next
 Set UTabelu = Nothing
 Set IzTabele = Nothing
 dbUBazu.Close
 dbIzBaze.Close
 Set dbUBazu = Nothing
 Set dbIzBaze = Nothing
 DodajNovaPoljaUTabelu = retVal
 Exit Function
 
err_DodajNovaPoljaUTabelu:
    'Debug.Print "Polje = " & polje.Name; "i= ", i, Err.Number, Err.Description
    MsgBox "ErrNo: " & err.Number & vbCrLf _
            & err.Description & vbCrLf _
            & "Proces dodavanja polja u tabelu " & imeTabele _
            & " se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    Resume exit_DodajNovaPoljaUTabelu
End Function

Public Function PostojiPoljeUTabeli(imepolje As String, Tabela As DAO.TableDef) As Boolean
 Dim retVal As Boolean
 retVal = False
 On Error Resume Next
  retVal = (Tabela.Fields(imepolje).Name = imepolje)
  PostojiPoljeUTabeli = retVal
End Function

Public Sub PrikaziPoljaIzTabele(Tabela As DAO.TableDef)
Dim polje As DAO.Field
Dim stPoruka

    stPoruka = "Name     Type    Size  " & vbCrLf
    For Each polje In Tabela.Fields
        stPoruka = stPoruka & polje.Name & polje.Type & polje.Size & vbCrLf
    Next polje
    MsgBox stPoruka, , "BigBit - Polja iz tabele"
End Sub
Public Function QueryExecute(UBazi As String, SQLUpit As String, Optional ByRef recaff As Long) As Boolean

On Error GoTo err_IzvrsiUpitUBazi

 Dim retVal As Boolean
 Dim dbUBazi As DAO.Database
 
 retVal = True
 Set dbUBazi = OpenDatabase(UBazi)
 
 If Not dbUBazi.Updatable Then
    MsgBox "Baza " & UBazi & " nije UPDATABLE. Proces se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    GoTo exit_IzvrsiUpitUBazi
 End If
    dbUBazi.Execute SQLUpit
    If Not IsMissing(recaff) Then
     recaff = dbUBazi.RecordsAffected
    End If
exit_IzvrsiUpitUBazi:
On Error Resume Next
 
 dbUBazi.Close
 Set dbUBazi = Nothing
 QueryExecute = retVal
 Exit Function
 
err_IzvrsiUpitUBazi:
    MsgBox "ErrNo: " & err.Number & vbCrLf _
            & err.Description & vbCrLf _
            & "Funkcija QueryExecute " & SQLUpit & " u bazi " & UBazi _
            & " se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    Resume exit_IzvrsiUpitUBazi
End Function
Public Function KreirajUpitUBazi(ImeBaze As String, ImeUpita As String, SQLText As String) As Boolean
On Error GoTo err_KreirajUpitUBazi
Dim db As DAO.Database
    Dim qDef As DAO.QueryDef
    Dim retVal As Boolean
    If ImeBaze = "CurrentDB" Then
     Set db = CurrentDb
    Else
     Set db = OpenDatabase(ImeBaze)
    End If
    'kreirmo PRIVREMENI objekat (jer mu je ime "")
    'Set QDef = db.CreateQueryDef("", "SELECT [R_Tarife].* FROM [R_Tarife];")
    retVal = True
    Set qDef = db.CreateQueryDef(ImeUpita, SQLText)
    
    'ovo ne treba jer je vec dodat u komandi db.CreateQueryDef(ImeUpita, SQLText)
    'db.QueryDefs.Append qdef
    
exit_KreirajUpitUBazi:
   ' On Error Resume Next
    db.Close
    Set db = Nothing
    Set qDef = Nothing
    KreirajUpitUBazi = retVal
Exit Function

err_KreirajUpitUBazi:
    MsgBox "ErrNo: " & err.Number & vbCrLf _
            & err.Description & vbCrLf _
            & "Proces kreiranja upita " & SQLText & " sa imenom " & ImeUpita & " u bazi " & ImeBaze _
            & " se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    Resume exit_KreirajUpitUBazi
End Function
Public Sub OtvoriObjekatUDizajnModu(TipObjekta As String, ImeObjekta As String)
    If TipObjekta = "Table" Then
        DoCmd.OpenTable ImeObjekta, acViewDesign
    ElseIf TipObjekta = "Query" Then
        DoCmd.OpenQuery ImeObjekta, acViewDesign
    ElseIf TipObjekta = "Form" Then
        BBOpenForm ImeObjekta, acViewDesign
    ElseIf TipObjekta = "Report" Then
        BBOpenReport ImeObjekta, acViewDesign
    ElseIf TipObjekta = "Module" Then
        DoCmd.OpenModule ImeObjekta
    End If
End Sub
Public Function OtvoriObjekat(TipObjekta As String, ImeObjekta As String, View As Long) As Boolean
On Error GoTo err_OtvoriObjekat
 Dim retVal As Boolean
    retVal = True
    
    If TipObjekta = "Table" Then
        DoCmd.OpenTable ImeObjekta, View
    ElseIf TipObjekta = "Query" Then
        DoCmd.OpenQuery ImeObjekta, View
    ElseIf TipObjekta = "Form" Then
        BBOpenForm ImeObjekta, View
    ElseIf TipObjekta = "Report" Then
        BBOpenReport ImeObjekta, View
    ElseIf TipObjekta = "Module" Then
        DoCmd.OpenModule ImeObjekta
    End If
exit_OtvoriObjekat:

    OtvoriObjekat = retVal
Exit Function
err_OtvoriObjekat:
    MsgBox "ErrNo: " & err.Number & vbCrLf _
            & err.Description & vbCrLf _
            & "Komanda OtvoriObjekat, objekat: " & ImeObjekta & " tipa " & TipObjekta _
            & " se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    Resume exit_OtvoriObjekat
End Function

Public Function UradiIzmene(Izmene As String, ZaKljucnuRec, ZaBazu, ZaTipObjekta, ImeIzBaze As String, ImeUBazi As String) As Boolean
 On Error GoTo err_UradiIzmene
 
    Dim QIzmeneDef As DAO.QueryDef
    Dim QIzmene As DAO.Recordset
    Dim retVal
    
    retVal = True
    
    Set QIzmeneDef = CurrentDb.QueryDefs(Izmene)
    QIzmeneDef.Parameters("ZaKljucnuRec") = ZaKljucnuRec
    QIzmeneDef.Parameters("ZaBazu") = ZaBazu
    QIzmeneDef.Parameters("ZaTipObjekta") = ZaTipObjekta
    Set QIzmene = QIzmeneDef.OpenRecordset()
   ' QIzmene.MoveFirst
    While Not QIzmene.EOF
        'Debug.Print QIzmene!Redosled, QIzmene!RedosledDet, QIzmene!Komanda, QIzmene!Parametar
        Select Case QIzmene!komanda
        Case "AppendFields"
            retVal = DodajNovaPoljaUTabelu(ImeIzBaze, ImeUBazi, QIzmene!Parametar)
        Case "TableFieldSetDefaultValue"
            retVal = PostaviDefaultVrednostiUtabeli(ImeIzBaze, ImeUBazi, QIzmene!Parametar)
        Case "QueryExecute"
            retVal = QueryExecute(ImeUBazi, QIzmene!Parametar)
        Case "ExportForm"
            retVal = PosaljiFormu(ImeUBazi, QIzmene!Parametar)
        Case "ExportReport"
            retVal = PosaljiReport(ImeUBazi, QIzmene!Parametar)
        Case "ExportQuery"
            retVal = PosaljiUpit(ImeUBazi, QIzmene!Parametar)
        Case "ExportModule"
            retVal = PosaljiModul(ImeUBazi, QIzmene!Parametar)
        'Case "ExportFunction" 'Ovo ne radi dobro!?
        '    retval = PosaljiFunkciju(ImeUBazi, QIzmene!Parametar)
        Case Else
            MsgBox "Nepoznata komanda u proceduri UradiIzmene!", vbCritical, "QMegaTeh"
            retVal = False
        End Select
        QIzmene.MoveNext
    Wend
exit_UradiIzmene:
 On Error Resume Next
    QIzmeneDef.Close
    Set QIzmeneDef = Nothing
    QIzmene.Close
    Set QIzmene = Nothing
    UradiIzmene = retVal
Exit Function
err_UradiIzmene:
     MsgBox "ErrNo: " & err.Number & vbCrLf _
            & err.Description & vbCrLf _
            & "Function UradiIzmene se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    
    Resume exit_UradiIzmene

End Function

Public Function PostaviDefaultVrednostUtabeliZaPoljeSPEC(ImeBaze As String, imeTabele As String, ImePolja As String, defVrednost As Variant) As Boolean
    On Error GoTo err_PostaviDefaultVrednost
  'D:\AcBaze\Testovi\T1\BB_T_Test.MDB
 Dim retVal As Boolean
 Dim dbUBazi As DAO.Database
 Dim UTabeli As DAO.TableDef
 Dim polje As DAO.Field
 
 retVal = True
 Set dbUBazi = OpenDatabase(ImeBaze)
 Set UTabeli = dbUBazi.TableDefs(imeTabele)
 
 If Not UTabeli.Updatable Then
    MsgBox "Tabela " & imeTabele & " u bazi " & ImeBaze & " nije UPDATABLE. Proces se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    GoTo exit_PostaviDefaultVrednost
 End If

 Set polje = UTabeli.Fields(ImePolja)
 polje.DefaultValue = defVrednost

    
exit_PostaviDefaultVrednost:
On Error Resume Next
 Set UTabeli = Nothing
 dbUBazi.Close
 Set dbUBazi = Nothing
 PostaviDefaultVrednostUtabeliZaPoljeSPEC = retVal
 Exit Function
 
err_PostaviDefaultVrednost:
    'Debug.Print "Polje = " & polje.Name; "i= ", i, Err.Number, Err.Description
    MsgBox "ErrNo: " & err.Number & vbCrLf _
            & err.Description & vbCrLf _
            & "Proces promene default vrednosti polja " & ImePolja & " u tabelu " & imeTabele _
            & " se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    Resume exit_PostaviDefaultVrednost
End Function

Public Function PostaviDefaultVrednostiUtabeli(IzBaze As String, UBazu As String, imeTabele As String) As Boolean
    On Error GoTo err_DodajNovaPoljaUTabelu
    
 Dim retVal As Boolean
 Dim dbIzBaze As DAO.Database
 Dim dbUBazu As DAO.Database
 
 Dim IzTabele As DAO.TableDef
 Dim UTabelu As DAO.TableDef
 
 Dim polje As DAO.Field
 Dim NovoPolje As DAO.Field
 
 Dim nQuery As DAO.QueryDef
 
 Dim i As Integer
 
 retVal = True
 Set dbIzBaze = OpenDatabase(IzBaze)
 'Set dbIzBaze = CurrentDb
 Set IzTabele = dbIzBaze.TableDefs(imeTabele)
 
 Set dbUBazu = OpenDatabase(UBazu)
 Set UTabelu = dbUBazu.TableDefs(imeTabele)
 
 If Not UTabelu.Updatable Then
    MsgBox "Tabela " & imeTabele & " u bazi " & UBazu & " nije UPDATABLE. Proces se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    GoTo exit_DodajNovaPoljaUTabelu
 End If
 
 For Each polje In IzTabele.Fields
    If PostojiPoljeUTabeli(polje.Name, UTabelu) Then
        
        Set NovoPolje = UTabelu.Fields(polje.Name)
        NovoPolje.DefaultValue = polje.DefaultValue
        
        'neki propertisi ne mogu da se prepisu i bas me briga
        'neka prepise ono sto moze
        On Error Resume Next
        For i = 1 To polje.Properties.Count
            NovoPolje.Properties(i).Value = polje.Properties(i).Value
        Next i
        On Error GoTo err_DodajNovaPoljaUTabelu
    End If
 Next polje
   
    
exit_DodajNovaPoljaUTabelu:
On Error Resume Next
 Set UTabelu = Nothing
 Set IzTabele = Nothing
 dbUBazu.Close
 dbIzBaze.Close
 Set dbUBazu = Nothing
 Set dbIzBaze = Nothing
 PostaviDefaultVrednostiUtabeli = retVal
 Exit Function
 
err_DodajNovaPoljaUTabelu:
    'Debug.Print "Polje = " & polje.Name; "i= ", i, Err.Number, Err.Description
    MsgBox "ErrNo: " & err.Number & vbCrLf _
            & err.Description & vbCrLf _
            & "Proces promene default vrednosti polja u tabeli " & imeTabele _
            & " se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    Resume exit_DodajNovaPoljaUTabelu
End Function

Private Function XXXXZameniFormu(IzBaze As String, UBazu As String, ImeForme As String) As Boolean
        On Error GoTo err_ZameniFormu

 'IzBaze = "D:\AcBaze\MojBigBit\BigBit_APL.mdb"
 'UBazu = "D:\AcBaze\Testovi\T1\BB_T_Test.MDB"
 'ImeForme = "Unos / Pregled tarifa i stopa"
 
 Dim retVal As Boolean
 Dim dbIzBaze As DAO.Database
 Dim dbUBazu As DAO.Database
 
 
 

 retVal = True
 Set dbIzBaze = OpenDatabase(IzBaze)
 Set dbUBazu = OpenDatabase(UBazu)
 
 If Not dbUBazu.Updatable Then
    MsgBox "Baza " & IzBaze & " nije UPDATABLE. Proces se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    GoTo exit_ZameniFormu
 End If
   
   Debug.Print dbIzBaze.Containers.Count
    
exit_ZameniFormu:
On Error Resume Next
 dbUBazu.Close
 dbIzBaze.Close
 Set dbUBazu = Nothing
 Set dbIzBaze = Nothing
 XXXXZameniFormu = retVal
 Exit Function
 
err_ZameniFormu:
    'Debug.Print "Polje = " & polje.Name; "i= ", i, Err.Number, Err.Description
    MsgBox "ErrNo: " & err.Number & vbCrLf _
            & err.Description & vbCrLf _
            & "Proces zamene forme " & ImeForme _
            & " se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    Resume exit_ZameniFormu
End Function
Public Function PosaljiTabelu(UBazu As String, imeTabele As String) As Boolean
'ako je link ka tabeli, onda ce poslati samo link!
'ako je tabela lokalna, poslace tabelu sa sadrzajem
On Error GoTo err_Posalji
Dim retVal As Boolean
retVal = True
    DoCmd.TransferDatabase acExport, "Microsoft Access", UBazu, acTable, imeTabele, imeTabele
exit_Posalji:
    PosaljiTabelu = retVal
Exit Function

err_Posalji:
 MsgBox "ErrNo: " & err.Number & vbCrLf _
            & err.Description & vbCrLf _
            & "Proces slanja tabele " & imeTabele _
            & " se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    Resume exit_Posalji
End Function

Public Function PosaljiFormu(UBazu As String, ImeForme As String) As Boolean
On Error GoTo err_Posalji
Dim retVal As Boolean
retVal = True
    DoCmd.TransferDatabase acExport, "Microsoft Access", UBazu, acForm, ImeForme, ImeForme
exit_Posalji:
    PosaljiFormu = retVal
Exit Function

err_Posalji:
 MsgBox "ErrNo: " & err.Number & vbCrLf _
            & err.Description & vbCrLf _
            & "Proces slanja forme " & ImeForme _
            & " se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    Resume exit_Posalji
End Function
Public Function PosaljiFormuIzBazeUBazu_NeRadi(IzBaze As String, UBazu As String, ImeForme As String) As Boolean
On Error GoTo err_Posalji
Dim retVal As Boolean
Dim dbIzBaze As DAO.Database
retVal = True

   Set dbIzBaze = OpenDatabase(IzBaze)
   
   Debug.Print dbIzBaze.Containers.Count
   
    'DoCmd.TransferDatabase acExport, "Microsoft Access", UBazu, acForm, ImeForme, ImeForme
    
exit_Posalji:
 On Error Resume Next
    dbIzBaze.Close
    Set dbIzBaze = Nothing
    
    PosaljiFormuIzBazeUBazu_NeRadi = retVal
Exit Function

err_Posalji:
 MsgBox "ErrNo: " & err.Number & vbCrLf _
            & err.Description & vbCrLf _
            & "Proces slanja forme " & ImeForme _
            & " se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    Resume exit_Posalji
End Function
Public Function PosaljiReport(UBazu As String, ImeReporta As String) As Boolean
On Error GoTo err_Posalji
Dim retVal As Boolean
retVal = True
    DoCmd.TransferDatabase acExport, "Microsoft Access", UBazu, acReport, ImeReporta, ImeReporta
exit_Posalji:
    PosaljiReport = retVal
Exit Function

err_Posalji:
 MsgBox "ErrNo: " & err.Number & vbCrLf _
            & err.Description & vbCrLf _
            & "Proces slanja reporta " & ImeReporta _
            & " se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    Resume exit_Posalji
End Function

Public Function PosaljiUpit(UBazu As String, ImeUpita As String) As Boolean
On Error GoTo err_Posalji
Dim retVal As Boolean
retVal = True
    DoCmd.TransferDatabase acExport, "Microsoft Access", UBazu, acQuery, ImeUpita, ImeUpita
exit_Posalji:
    PosaljiUpit = retVal
Exit Function

err_Posalji:
 MsgBox "ErrNo: " & err.Number & vbCrLf _
            & err.Description & vbCrLf _
            & "Proces slanja upita " & ImeUpita _
            & " se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    Resume exit_Posalji
End Function

Public Function PosaljiModul(UBazu As String, ImeModula As String) As Boolean
On Error GoTo err_Posalji
Dim retVal As Boolean
retVal = True
    DoCmd.TransferDatabase acExport, "Microsoft Access", UBazu, acModule, ImeModula, ImeModula
exit_Posalji:
    PosaljiModul = retVal
Exit Function

err_Posalji:
 MsgBox "ErrNo: " & err.Number & vbCrLf _
            & err.Description & vbCrLf _
            & "Proces slanja modula " & ImeModula _
            & " se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    Resume exit_Posalji
End Function

Public Function PosaljiFunkciju(UBazu As String, ImeFunkcije As String) As Boolean
On Error GoTo err_Posalji
Dim retVal As Boolean
retVal = True
    'DoCmd.TransferDatabase acExport, "Microsoft Access", UBazu, acFunction, ImeFunkcije, ImeFunkcije
exit_Posalji:
    PosaljiFunkciju = retVal
Exit Function

err_Posalji:
 MsgBox "ErrNo: " & err.Number & vbCrLf _
            & err.Description & vbCrLf _
            & "Proces slanja funkcije " & ImeFunkcije _
            & " se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    Resume exit_Posalji
End Function
''''''''''''''''''''''''''''''''''''''''
Public Function NapraviBazuIzmena(Izmene As String, ZaKljucnuRec, ZaBazu, ZaTipObjekta, ImeIzBaze As String, ImeUBazi As String) As Boolean
 On Error GoTo err_UradiIzmene
 
    Dim QIzmeneDef As DAO.QueryDef
    Dim QIzmene As DAO.Recordset
    Dim retVal
    
    retVal = True
    
    Set QIzmeneDef = CurrentDb.QueryDefs(Izmene)
    QIzmeneDef.Parameters("ZaKljucnuRec") = ZaKljucnuRec
    QIzmeneDef.Parameters("ZaBazu") = ZaBazu
    QIzmeneDef.Parameters("ZaTipObjekta") = ZaTipObjekta
    Set QIzmene = QIzmeneDef.OpenRecordset()
   ' QIzmene.MoveFirst
    While Not QIzmene.EOF
        'Debug.Print QIzmene!Redosled, QIzmene!RedosledDet, QIzmene!Komanda, QIzmene!Parametar
        Select Case QIzmene!TipObjekta
        Case "Table"
            retVal = PosaljiTabelu(ImeUBazi, QIzmene!ImeObjekta)
        Case "Form"
            retVal = PosaljiFormu(ImeUBazi, QIzmene!ImeObjekta)
        Case "Report"
            retVal = PosaljiReport(ImeUBazi, QIzmene!ImeObjekta)
        Case "Query"
            retVal = PosaljiUpit(ImeUBazi, QIzmene!ImeObjekta)
        Case "Module"
            retVal = PosaljiModul(ImeUBazi, QIzmene!ImeObjekta)
        Case Else
            MsgBox "Nepoznat tip objekta u proceduri NapraviBazuIzmene!", vbCritical, "QMegaTeh"
            retVal = False
        End Select
        QIzmene.MoveNext
    Wend
exit_UradiIzmene:
 On Error Resume Next
    QIzmeneDef.Close
    Set QIzmeneDef = Nothing
    QIzmene.Close
    Set QIzmene = Nothing
    NapraviBazuIzmena = retVal
Exit Function
err_UradiIzmene:
     MsgBox "ErrNo: " & err.Number & vbCrLf _
            & err.Description & vbCrLf _
            & "Function NapraviBazuIzmena se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    
    Resume exit_UradiIzmene

End Function
Public Function PostojiTabelaUBazi(ByVal imeTabele As String, ByRef UBazi As DAO.Database) As Boolean
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
    PostojiTabelaUBazi = retVal
Exit Function

err_ObradaGreske:
    retVal = False
    If err.Number <> 3265 Then
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Function PostojiTabelaUBazi se prekida.", vbCritical, "QMegaTeh"
    End If
    Resume exit_PosleGreske
End Function
Public Function SynchIndexesInTable(ImeDobreBaze As String, ImeNoveBaze As String, imeTabele As String, ImeNoveTabele As String, ByRef stRretVal As String) As Boolean
On Error GoTo err_ObradaGreske
    Dim DobraBaza As DAO.Database
    Dim NovaBaza As DAO.Database
    Dim DobraTabela As DAO.TableDef
    Dim NovaTabela As DAO.TableDef
    Dim retVal As Boolean
    
    
    retVal = True
    Set DobraBaza = DAO.OpenDatabase(ImeDobreBaze)
    Set NovaBaza = DAO.OpenDatabase(ImeNoveBaze)
    Set DobraTabela = DobraBaza.TableDefs(imeTabele)
    Set NovaTabela = NovaBaza.TableDefs(ImeNoveTabele)
    
    retVal = SynchIndexesInTable_OP(DobraTabela, NovaTabela, stRretVal)
    
exit_PosleGreske:
On Error Resume Next

    Set DobraTabela = Nothing
    DobraBaza.Close
    Set DobraBaza = Nothing
    
    Set NovaTabela = Nothing
    NovaBaza.Close
    Set NovaBaza = Nothing
    SynchIndexesInTable = retVal
Exit Function
err_ObradaGreske:
        retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura SynchIndexesInTable se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Function
Public Function SynchIndexesInTable_OP(ByRef DobraTabela As TableDef, ByRef NovaTabela As TableDef, ByRef stRretVal) As Boolean
On Error GoTo err_ObradaGreske
 Dim DobarIndex As DAO.Index
 Dim NoviIndex As DAO.Index
 Dim retVal As Boolean
 Dim i As Integer
 Dim Poruka As String
  
  retVal = True
     For Each DobarIndex In DobraTabela.Indexes
      If Not DobarIndex.Foreign Then
                Set NoviIndex = NovaTabela.CreateIndex(DobarIndex.Name)
                NoviIndex.Clustered = DobarIndex.Clustered
                'NoviIndex.DistinctCount = DobarIndex.DistinctCount
                NoviIndex.Fields = DobarIndex.Fields
                'NoviIndex.Foreign = DobarIndex.Foreign
                NoviIndex.IgnoreNulls = DobarIndex.IgnoreNulls
                NoviIndex.Name = DobarIndex.Name
                NoviIndex.Primary = DobarIndex.Primary
                'NoviIndex.Properties = DobarIndex.Properties
                NoviIndex.Required = DobarIndex.Required
                NoviIndex.UNIQUE = DobarIndex.UNIQUE
        
                On Error Resume Next
                 For i = 1 To DobarIndex.Properties.Count
                   NoviIndex.Properties(i).Value = DobarIndex.Properties(i).Value
                 Next i
                On Error GoTo err_ObradaGreske
        NovaTabela.Indexes.Append NoviIndex
       End If
     Next DobarIndex
exit_PosleGreske:
Set NoviIndex = Nothing
Set DobarIndex = Nothing
SynchIndexesInTable_OP = retVal
Exit Function

err_ObradaGreske:
    If err.Number = 3283 Then 'Primarni index veæ postoji
        Resume Next
    ElseIf err.Number = 3284 Then 'index veæ postoji
        Resume Next
    ElseIf err.Number = 3022 Then 'index ne može da se napravi
        Poruka = "NE može da se doda index " & NoviIndex.Name & " u tabeli " & NovaTabela.Name & vbCrLf
        Poruka = Poruka & "Err.Number " & err.Number & "  Err.Description: " & err.Description
        stRretVal = stRretVal & Poruka & vbCrLf
        
        retVal = False
        Resume Next
    Else
        'MsgBox "ErrNo: " & Err.Number & vbCrLf _
        '            & Err.Description & vbCrLf _
        '            & "Procedura SynchIndexesInTable_OP se prekida!", vbCritical, "QMegaTeh"
        Poruka = "NE može da se doda index " & NoviIndex.Name & " u tabeli " & NovaTabela.Name & " Procedura SynchIndexesInTable_OP se prekida!" & vbCrLf
        Poruka = Poruka & "Err.Number " & err.Number & "  Err.Description: " & err.Description
        stRretVal = stRretVal & Poruka & vbCrLf
        retVal = False
        Resume exit_PosleGreske
    End If
End Function
Public Function DeleteAllIndexesInAllTables(ImeNoveBaze As String, ByRef stRretVal As String, Optional DeleteRelations As Boolean = False) As Boolean
'Datum: 20-08-2018
On Error GoTo err_ObradaGreske
    Dim NovaBaza As DAO.Database
    Dim Tabela As DAO.TableDef
    Dim retVal As Boolean
    Dim TrebaBrisatiIndexe As Boolean
    retVal = True
    Set NovaBaza = DAO.OpenDatabase(ImeNoveBaze)
    
    For Each Tabela In NovaBaza.TableDefs
        
        'TrebaBrisatiIndexe = True
        'TrebaBrisatiIndexe = TrebaBrisatiIndexe And ((Tabela.Attributes And dbSystemObject) <> dbSystemObject)
        'TrebaBrisatiIndexe = TrebaBrisatiIndexe And ((Tabela.Attributes And dbAttachedTable) <> dbAttachedTable)
        'TrebaBrisatiIndexe = TrebaBrisatiIndexe And ((Tabela.Attributes And dbAttachedODBC) <> dbAttachedODBC)
        'TrebaBrisatiIndexe = TrebaBrisatiIndexe And ((Tabela.Attributes And 2) <> 2) 'neki MSys...
        
        TrebaBrisatiIndexe = ((Tabela.Attributes = 0) Or (Tabela.Attributes = 1)) 'SAMO OVO! korigovano 20-08-18
        ' Attributes=0 to su korisnicke vidljive tabele, Attributes=1 korisnicke HIDDEN tabele
        'If Not CBool(Tabela.Attributes And dbSystemObject) Then 'NE brisati indexe u sistemskoj tabeli
        If TrebaBrisatiIndexe Then
         retVal = retVal And DeleteIndexesInTable_OP(Tabela, stRretVal)
        End If
    Next Tabela
    If DeleteRelations Then
     'retval = retval And DeleteRelations_OP(DobraBaza, NovaBaza)
    End If
exit_PosleGreske:
On Error Resume Next

    Set Tabela = Nothing
    NovaBaza.Close
    Set NovaBaza = Nothing
    DeleteAllIndexesInAllTables = retVal
Exit Function
err_ObradaGreske:
        retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura DeleteAllIndexesInAllTables se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Function
Public Function ReadAllIndexesInAllTables(ImeNoveBaze As String, ByRef stRretVal As String) As Boolean
On Error GoTo err_ObradaGreske
    Dim NovaBaza As DAO.Database
    Dim Tabela As DAO.TableDef
    Dim retVal As Boolean
    
    retVal = True
    Set NovaBaza = DAO.OpenDatabase(ImeNoveBaze)
    
    For Each Tabela In NovaBaza.TableDefs
        If Not CBool(Tabela.Attributes And dbSystemObject) Then 'NE èitamo indexe u sistemskim tabelama
         retVal = retVal And ReadIndexesInTable_OP(Tabela, stRretVal)
        End If
    Next Tabela
exit_PosleGreske:
On Error Resume Next

    Set Tabela = Nothing
    NovaBaza.Close
    Set NovaBaza = Nothing
    ReadAllIndexesInAllTables = retVal
Exit Function
err_ObradaGreske:
        retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura ReadAllIndexesInAllTables se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Function

Public Function DeleteIndexesInTable(ImeNoveBaze As String, ImeNoveTabele As String, ByRef stRretVal As String) As Boolean
On Error GoTo err_ObradaGreske
    Dim NovaBaza As DAO.Database
    Dim NovaTabela As DAO.TableDef
    Dim retVal As Boolean
    
    
    retVal = True

    Set NovaBaza = DAO.OpenDatabase(ImeNoveBaze)

    Set NovaTabela = NovaBaza.TableDefs(ImeNoveTabele)
    
    retVal = DeleteIndexesInTable_OP(NovaTabela, stRretVal)
    
exit_PosleGreske:
On Error Resume Next

    
    Set NovaTabela = Nothing
    NovaBaza.Close
    Set NovaBaza = Nothing
    DeleteIndexesInTable = retVal
Exit Function
err_ObradaGreske:
        retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura DeleteIndexesInTable se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Function
Public Function DeleteIndexesInTable_OP(ByRef NovaTabela As TableDef, ByRef stRretVal As String) As Boolean

On Error GoTo err_ObradaGreske
 Dim Index As DAO.Index
 Dim retVal As Boolean
 Dim BrojObrisanih As Integer
 
  'strRetVal = strRetVal & vbCrLf
  retVal = True
  
  Do
    BrojObrisanih = 0
     For Each Index In NovaTabela.Indexes
     On Error Resume Next
      NovaTabela.Indexes.Delete Index.Name
      If err Then
       'strRetVal = strRetVal & "U tabeli " & NovaTabela.Name & " NIJE obrisan Index " & Index.Name & "(" & Err.Description & ")" & vbCrLf
       stRretVal = stRretVal & "U tabeli " & NovaTabela.Name & " NIJE obrisan Index " & Index.Name & vbCrLf
       stRretVal = stRretVal & "(" & err.Description & ")" & vbCrLf & vbCrLf
      Else
       stRretVal = stRretVal & "U tabeli " & NovaTabela.Name & " obrisan Index " & Index.Name & vbCrLf
       BrojObrisanih = BrojObrisanih + 1
      End If
      On Error GoTo err_ObradaGreske
     Next Index
  If BrojObrisanih = 0 Then Exit Do
  Loop While NovaTabela.Indexes.Count > 0
  
exit_PosleGreske:
Set Index = Nothing
DeleteIndexesInTable_OP = retVal
Exit Function

err_ObradaGreske:
    If err.Number = 3281 Then 'Index je
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura DeleteIndexesInTable_OP se nastavlja!", vbCritical, "QMegaTeh"
        Resume Next
    Else
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura DeleteIndexesInTable_OP se prekida!", vbCritical, "QMegaTeh"
        retVal = False
    Resume exit_PosleGreske
    End If
End Function
Public Function ReadIndexesInTable(ImeNoveBaze As String, ImeNoveTabele As String, ByRef stRretVal As String) As Boolean
On Error GoTo err_ObradaGreske
    Dim NovaBaza As DAO.Database
    Dim NovaTabela As DAO.TableDef
    Dim retVal As Boolean
    
    
    retVal = True

    Set NovaBaza = DAO.OpenDatabase(ImeNoveBaze)

    Set NovaTabela = NovaBaza.TableDefs(ImeNoveTabele)
    
    retVal = ReadIndexesInTable_OP(NovaTabela, stRretVal)
    
exit_PosleGreske:
On Error Resume Next

    
    Set NovaTabela = Nothing
    NovaBaza.Close
    Set NovaBaza = Nothing
    ReadIndexesInTable = retVal
Exit Function
err_ObradaGreske:
        retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura ReadIndexesInTable se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Function
Private Function BBDescOfIndex(ByRef Index As DAO.Index) As String
 Dim i As Integer
 Dim stRetVal As String
 
 'stRetVal = "P=" & CStr(index.Primary)
 'stRetVal = stRetVal & " F=" & CStr(index.Foreign) & " "
 'For i = 0 To index.Fields.Count - 1
 ' stRetVal = stRetVal & "[" & index.Fields(i).Name & "]"
 'Next i
 ' ***************
  If Index.Foreign Then
        stRetVal = stRetVal & "Foreign=" & Index.Fields
  Else
        If Index.Primary Then
           stRetVal = stRetVal & "Primary= " & Index.Fields
        Else
           stRetVal = stRetVal & "Index= " & Index.Fields
        End If
  End If
     
 ' ***************
 BBDescOfIndex = stRetVal
End Function
Public Function ReadIndexesInTable_OP(ByRef NovaTabela As TableDef, ByRef stRretVal As String) As Boolean
On Error GoTo err_ObradaGreske
 Dim Index As DAO.Index
 Dim retVal As Boolean
 Dim i As Integer
 
  retVal = True
     For Each Index In NovaTabela.Indexes
      stRretVal = stRretVal & "U tabeli " & NovaTabela.Name & " postoji Index " & Index.Name & " " & BBDescOfIndex(Index) & vbCrLf
     Next Index
      
exit_PosleGreske:
Set Index = Nothing
ReadIndexesInTable_OP = retVal
Exit Function

err_ObradaGreske:
    If err.Number = 0 Then
        Resume Next
    Else
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura ReadIndexesInTable_OP se prekida!", vbCritical, "QMegaTeh"
        retVal = False
    Resume exit_PosleGreske
    End If
End Function
Public Function PKForTable_OP(Tabela As DAO.TableDef) As String
 Dim Index As DAO.Index
 Dim stRetVal As String
 
 stRetVal = ""
  For Each Index In Tabela.Indexes
      If Index.Primary Then
        stRetVal = Index.Name & "=" & Index.Fields
        Exit For
      End If
  Next
  PKForTable_OP = stRetVal
End Function
Public Function ShowTablesWithoutPK(ImeNoveBaze As String, ByRef stRretVal As String) As Boolean
On Error GoTo err_ObradaGreske
    Dim NovaBaza As DAO.Database
    Dim Tabela As DAO.TableDef
    Dim retVal As Boolean
    Dim Rbr As Integer
    Dim pkName As String
    
    Rbr = 0
    retVal = True
    Set NovaBaza = DAO.OpenDatabase(ImeNoveBaze)
    
    For Each Tabela In NovaBaza.TableDefs
        If Not CBool(Tabela.Attributes And dbSystemObject) Then 'NE èitamo indexe u sistemskim tabelama
         'retval = retval And ReadIndexesInTable_OP(Tabela, strRetVal)
            pkName = PKForTable_OP(Tabela)
            If Nz(pkName, "") = "" Then
               Rbr = Rbr + 1
               stRretVal = stRretVal & DoChLeft(CStr(Rbr) & ".", 4, 0) & " " & Tabela.Name & vbCrLf
            End If
        End If
    Next Tabela
exit_PosleGreske:
On Error Resume Next

    Set Tabela = Nothing
    NovaBaza.Close
    Set NovaBaza = Nothing
    ShowTablesWithoutPK = retVal
Exit Function
err_ObradaGreske:
        retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura ShowTablesWithoutPK se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske

End Function

Public Function PostojiRelacija(ByRef DobraRelacija As DAO.Relation, ByRef NovaBaza As DAO.Database, Optional ByRef stNapomena As String) As Boolean
Dim retVal As Boolean
Dim IstaPolja As Boolean
Dim IsteTabele As Boolean
Dim i As Integer
Dim Relacija As DAO.Relation
     
retVal = False
IstaPolja = False
stNapomena = ""
 
  For Each Relacija In NovaBaza.Relations
    IsteTabele = (DobraRelacija.ForeignTable = Relacija.ForeignTable)
    IsteTabele = IsteTabele And (DobraRelacija.Table = Relacija.Table)
    IstaPolja = False
    If IsteTabele Then
       If (DobraRelacija.Fields.Count = Relacija.Fields.Count) Then
            IstaPolja = True
          For i = 0 To DobraRelacija.Fields.Count - 1
            IstaPolja = IstaPolja And ((DobraRelacija.Fields(i).Name = Relacija.Fields(i).Name) And (DobraRelacija.Fields(i).ForeignName = Relacija.Fields(i).ForeignName))
          Next i
        Else
            IstaPolja = False
        End If
    End If
    retVal = IsteTabele And IstaPolja
    
    If retVal Then 'pronadjena je odgovarajuca relacija
     If (DobraRelacija.Attributes <> Relacija.Attributes) Then 'da li ima iste atribute?
       stNapomena = "Treba da bude Attributes = " & DobraRelacija.Attributes & "  a u ovoj bazi je = " & Relacija.Attributes
     Else
       stNapomena = ""
     End If
     GoTo Exit_Function
    End If
  Next Relacija
Exit_Function:
  PostojiRelacija = retVal
End Function
Private Function BBCreateRelation(stUBazi As String, stOdTabele As String, stKaTabeli As String, _
                                                                  stOdPolje As String, stKaPolje As String, Optional RealAttr) As Boolean
On Error GoTo Err_Point
   Dim retValOk As Boolean
   Dim dbUBazi As DAO.Database
   Dim stRelationName As String
   Dim relNew As DAO.Relation
   
   retValOk = True
   Set dbUBazi = OpenDatabase(stUBazi)
   'Set tdfOdTabele = dbUBazi.TableDefs(stOdTabele)

    stRelationName = "Rel_" & stOdTabele & "_" & stKaTabeli
    
      ' Create EmployeesDepartments Relation object, using
      ' the names of the two tables in the relation.
      Set relNew = dbUBazi.CreateRelation(stRelationName, stOdTabele, stKaTabeli, RealAttr)
      
         'dbRelationUpdateCascade + dbRelationDeleteCascade)

      ' Create Field object for the Fields collection of the
      ' new Relation object. Set the Name and ForeignName
      ' properties based on the fields to be used for the
      ' relation.
      relNew.Fields.Append relNew.CreateField(stOdPolje)
      relNew.Fields(stOdPolje).ForeignName = stKaPolje
      dbUBazi.Relations.Append relNew

      ' Print report.
     ' Debug.Print "Properties of " & relNew.Name & _
     '    " Relation"
     ' Debug.Print "  Table = " & relNew.Table
     ' Debug.Print "  ForeignTable = " & _
     '    relNew.ForeignTable
     ' Debug.Print "Fields of " & relNew.Name & " Relation"

     ' With relNew.Fields!DeptID
     '    Debug.Print "  " & .Name
     '    Debug.Print "    Name = " & .Name
     '    Debug.Print "    ForeignName = " & .ForeignName
     ' End With

    '  Debug.Print "Indexes in " & tdfEmployees.Name & _
    '     " TableDef"
    '  For Each idxLoop In tdfEmployees.Indexes
    '     Debug.Print "  " & idxLoop.Name & _
    '        ", Foreign = " & idxLoop.Foreign
    '  Next idxLoop

      ' Delete new objects because this is a demonstration.
    '  .Relations.Delete relNew.Name
    '  .TableDefs.Delete tdfNew.Name
    '  tdfEmployees.Fields.Delete "DeptID"
    '  .Close
   'End With
Exit_Point:
 On Error Resume Next
 
 dbUBazi.Close
 Set dbUBazi = Nothing
 Set relNew = Nothing
 
 BBCreateRelation = retValOk
 
Exit Function
Err_Point:
 BBErrorMSG err, "BBCreateRelation"
 retValOk = False
 Resume Exit_Point
End Function
Private Function SynchAllRelations_OP(ByRef DobraBaza As DAO.Database, ByRef NovaBaza As DAO.Database, ByRef stRretVal As String) As Boolean
On Error GoTo err_ObradaGreske
 Dim DobraRelacija As DAO.Relation
 Dim NovaRelacija As DAO.Relation
 Dim NovoPolje As DAO.Field
 Dim brojac As Long
 Dim i As Integer
 Dim retVal As Boolean
 
 retVal = True
     For Each DobraRelacija In DobraBaza.Relations
      DoEvents
      If Not PostojiRelacija(DobraRelacija, NovaBaza) Then
        Set NovaRelacija = NovaBaza.CreateRelation()
        NovaRelacija.ForeignTable = DobraRelacija.ForeignTable
        NovaRelacija.Name = DobraRelacija.Name
        'NovaRelacija.PartialReplica = DobraRelacija.PartialReplica
        'NovaRelacija.Properties = DobraRelacija.Properties
        NovaRelacija.Table = DobraRelacija.Table
        NovaRelacija.Attributes = DobraRelacija.Attributes
        'NovaRelacija.Fields = DobraRelacija.Fields
        
        For i = 0 To DobraRelacija.Fields.Count - 1
            Set NovoPolje = NovaRelacija.CreateField(DobraRelacija.Fields(i).Name)
            NovoPolje.ForeignName = DobraRelacija.Fields(i).ForeignName
            NovaRelacija.Fields.Append NovoPolje
        Next i
        
        On Error Resume Next 'Ima propertisa koji ne postoje u ovom kontekstu
        For i = 0 To DobraRelacija.Properties.Count - 1
            If DobraRelacija.Properties(i).Name <> "PartialReplica" Then '!!!Užassno sporo radi sa ovim properties-om !!!!!
             NovaRelacija.Properties(i).Value = DobraRelacija.Properties(i).Value
            End If
        Next i
        On Error Resume Next
         brojac = 0
         Do
          brojac = brojac + 1
         NovaBaza.Relations.Append NovaRelacija
         
         If err.Number = 3626 Then
            stRretVal = stRretVal & "NIJE dodata " & StringOpisRelacije(NovaRelacija) & vbCrLf
            stRretVal = stRretVal & err.Description & vbCrLf
            err.Clear
            Exit Do
         ElseIf err Then
              If brojac > 100 Then
                 ' GoTo err_ObradaGreske
                 stRretVal = stRretVal & "NIJE dodata " & StringOpisRelacije(NovaRelacija) & vbCrLf
                 ' MsgBox "ErrNo: " & Err.Number & vbCrLf _
                 '   & Err.Description & vbCrLf _
                 '   & "Procedura SynchAllRelations nastavlja izvršavanje za sledeæu relaciju.", vbCritical, "QMegaTeh"
                 Exit Do
              End If
             NovaRelacija.Name = NovaRelacija.Table & NovaRelacija.ForeignTable & brojac
             err.Clear
          Else
             stRretVal = stRretVal & "Dodata je " & StringOpisRelacije(NovaRelacija) & vbCrLf
             Exit Do
         End If
         Loop
        
        On Error GoTo err_ObradaGreske

      End If
     Next DobraRelacija
exit_PosleGreske:
Set NovaRelacija = Nothing
Set DobraRelacija = Nothing
SynchAllRelations_OP = retVal
Exit Function
err_ObradaGreske:
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura SynchAllRelations se prekida. Brojac = " & brojac, vbCritical, "QMegaTeh"
        retVal = False
    Resume exit_PosleGreske

End Function
Public Function SynchAllRelations(ImeDobreBaze As String, ImeNoveBaze As String, ByRef stRretVal As String) As Boolean
On Error GoTo err_ObradaGreske
    Dim DobraBaza As DAO.Database
    Dim NovaBaza As DAO.Database
    Dim retVal As Boolean
    
    retVal = True
    Set DobraBaza = DAO.OpenDatabase(ImeDobreBaze)
    Set NovaBaza = DAO.OpenDatabase(ImeNoveBaze)
    
    retVal = SynchAllRelations_OP(DobraBaza, NovaBaza, stRretVal)
    
exit_PosleGreske:
On Error Resume Next

    DobraBaza.Close
    Set DobraBaza = Nothing
    
    NovaBaza.Close
    Set NovaBaza = Nothing
    SynchAllRelations = retVal
Exit Function
err_ObradaGreske:
        retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura SynchAllRelations se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Function
Public Sub CheckRelations(ImeDobreBaze As String, ImeNoveBaze As String, ByRef stRretVal As String)
'13-11-2018
    Dim DobraBaza As DAO.Database
    Dim NovaBaza As DAO.Database
    Dim DobraRelacija As DAO.Relation
    Dim txtMSG As String
    Dim i As Integer
    Dim ImaNeuskladjenih As Boolean
    Dim stNapomena As String
    Dim boolPostojiRelacija As Boolean
    Set DobraBaza = DAO.OpenDatabase(ImeDobreBaze)
    Set NovaBaza = DAO.OpenDatabase(ImeNoveBaze)
    
    ImaNeuskladjenih = False
    For Each DobraRelacija In DobraBaza.Relations
       stNapomena = ""
       boolPostojiRelacija = PostojiRelacija(DobraRelacija, NovaBaza, stNapomena)
       If Not boolPostojiRelacija Or stNapomena <> "" Then
              ImaNeuskladjenih = True
              If Not boolPostojiRelacija Then
                txtMSG = "Ne postoji relacija "
              End If
              txtMSG = txtMSG & "Name: [" & DobraRelacija.Name & "]" & "    ->  " & stNapomena & vbCrLf
              txtMSG = txtMSG & "========================================" & vbCrLf
              txtMSG = txtMSG & DoChRight("Table", 40, " ") & "ForeignTable" & vbCrLf
              txtMSG = txtMSG & DoChRight(DobraRelacija.Table, 40, " ") & DobraRelacija.ForeignTable & vbCrLf
              txtMSG = txtMSG & "========================================" & vbCrLf
              For i = 0 To DobraRelacija.Fields.Count - 1
                txtMSG = txtMSG & i & ".    " & DoChRight(DobraRelacija.Fields(i).Name, 40, " ") & DobraRelacija.Fields(i).ForeignName & vbCrLf & vbCrLf
                ' txtMSG = txtMSG & "Field(" & i & ").name = " & DobraRelacija.Fields(i).Name & Space(10)
                ' txtMSG = txtMSG & "Field(" & i & ").ForeignName = " & DobraRelacija.Fields(i).ForeignName & vbCrLf
              Next i
              
              'MsgBox txtMSG, vbExclamation, "QMegaTeh"
              stRretVal = stRretVal & txtMSG & vbCrLf
           
       End If
       
     Next DobraRelacija

Set DobraRelacija = Nothing
    ''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
    
    DobraBaza.Close
    Set DobraBaza = Nothing
    NovaBaza.Close
    Set NovaBaza = Nothing
    txtMSG = "Završena provera." & vbCrLf
    If ImaNeuskladjenih Then
       txtMSG = txtMSG & "Imate neuskladjenih relacija!"
       'MsgBox txtMSG, vbExclamation, "QMegaTeh"
       stRretVal = txtMSG & vbCrLf & stRretVal
    Else
        txtMSG = txtMSG & "Nemate neuskladjenih relacija."
       ' MsgBox txtMSG, vbInformation, "QMegaTeh"
       stRretVal = txtMSG & vbCrLf & stRretVal
    End If
   
End Sub
Public Sub ReadAllRelations(ImeNoveBaze As String, ByRef stRretVal As String)
    Dim NovaBaza As DAO.Database
    Dim Relacija As DAO.Relation
    Dim txtMSG As String
    Dim i As Integer

    Set NovaBaza = DAO.OpenDatabase(ImeNoveBaze)
    
    For Each Relacija In NovaBaza.Relations
        txtMSG = "Postoji relacija: "
        txtMSG = txtMSG & "Name: [" & Relacija.Name & "]" & vbCrLf
        txtMSG = txtMSG & "========================================" & vbCrLf
        txtMSG = txtMSG & DoChRight("Table", 40, " ") & "ForeignTable" & vbCrLf
        txtMSG = txtMSG & DoChRight(Relacija.Table, 40, " ") & Relacija.ForeignTable & vbCrLf
        txtMSG = txtMSG & "========================================" & vbCrLf
        For i = 0 To Relacija.Fields.Count - 1
            txtMSG = txtMSG & i & ".    " & DoChRight(Relacija.Fields(i).Name, 40, " ") & Relacija.Fields(i).ForeignName & vbCrLf & vbCrLf
        Next i
        stRretVal = stRretVal & txtMSG & vbCrLf
     Next Relacija

    Set Relacija = Nothing
    NovaBaza.Close
    Set NovaBaza = Nothing
    txtMSG = "Završena provera." & vbCrLf
   
End Sub
Public Sub DeleteAllRelations(ImeNoveBaze As String, ByRef stRretVal As String)
    Dim NovaBaza As DAO.Database
    Dim Relacija As DAO.Relation
    Dim txtMSG As String
    Dim i As Integer
    Dim BrojRelacijaZaBrisanje As Long

    Set NovaBaza = DAO.OpenDatabase(ImeNoveBaze)
   
    
Do
    BrojRelacijaZaBrisanje = NovaBaza.Relations.Count
    stRretVal = stRretVal & "Broj relacija za brisanje = " & BrojRelacijaZaBrisanje & vbCrLf
    For Each Relacija In NovaBaza.Relations
        
        txtMSG = "Relacija: "
        txtMSG = txtMSG & "Name: [" & Relacija.Name & "]"
        
        'txtMSG = txtMSG & vbCrLf
        'txtMSG = txtMSG & "========================================" & vbCrLf
        'txtMSG = txtMSG & DoChRight("Table", 40, " ") & "ForeignTable" & vbCrLf
        'txtMSG = txtMSG & DoChRight(Relacija.Table, 40, " ") & Relacija.ForeignTable & vbCrLf
        'txtMSG = txtMSG & "========================================" & vbCrLf
        'For i = 0 To Relacija.Fields.Count - 1
        '    txtMSG = txtMSG & i & ".    " & DoChRight(Relacija.Fields(i).Name, 40, " ") & Relacija.Fields(i).ForeignName & vbCrLf & vbCrLf
        'Next i
        If (CBool(NovaBaza.TableDefs(Relacija.Table).Attributes = dbSystemObject) _
           Or (CBool(NovaBaza.TableDefs(Relacija.ForeignTable).Attributes = dbSystemObject))) Then
           ' Ne brišemo sistemsske relacije
          stRretVal = stRretVal & txtMSG & " se ne briše" & vbCrLf
        Else
         On Error Resume Next
         NovaBaza.Relations.Delete Relacija.Name
         If err Then
          stRretVal = stRretVal & txtMSG & " NIJE obrisana" & vbCrLf
         Else
          stRretVal = stRretVal & txtMSG & " je obrisana" & vbCrLf
         End If
        End If
        
     Next Relacija
Loop While (NovaBaza.Relations.Count > 0) And (BrojRelacijaZaBrisanje > NovaBaza.Relations.Count)

    Set Relacija = Nothing
    NovaBaza.Close
    Set NovaBaza = Nothing
    txtMSG = "Završeno brisanje." & vbCrLf
    stRretVal = stRretVal & txtMSG & vbCrLf
End Sub

Public Function SynchAllTablesIndexRelations(ImeDobreBaze As String, ImeNoveBaze As String, ByRef stRretVal As String, CheckUskladiIndexe As Boolean, CheckUskladiRelacije As Boolean) As Boolean
' SynchAllTables "D:\AcBaze\Testovi\T1\BB_T_Test.mdb", "D:\AcBaze\Testovi\T2\BB_T_Test.mdb"
' SynchAllTables "D:\AcBaze\MojBigBit\TG\BB_T_TG.mdb", "D:\AcBaze\Testovi\T2\BB_T_Test.mdb"
On Error GoTo err_ObradaGreske
    Dim DobraBaza As DAO.Database
    Dim NovaBaza As DAO.Database
    Dim DobraTabela As DAO.TableDef
    Dim retVal As Boolean
    
    retVal = True
    Set DobraBaza = DAO.OpenDatabase(ImeDobreBaze) 'CurrentDb
    Set NovaBaza = DAO.OpenDatabase(ImeNoveBaze)
    
    For Each DobraTabela In DobraBaza.TableDefs
        retVal = retVal And SynchTable_OP(DobraBaza, NovaBaza, DobraTabela, stRretVal, CheckUskladiIndexe, False)
        'DoEvents
        'Debug.Print "Uradio tabelu " & DobraTabela.Name
    Next DobraTabela
    If CheckUskladiRelacije Then
     retVal = retVal And SynchAllRelations_OP(DobraBaza, NovaBaza, stRretVal)
    End If
exit_PosleGreske:
On Error Resume Next

    Set DobraTabela = Nothing
    DobraBaza.Close
    Set DobraBaza = Nothing
    
    NovaBaza.Close
    Set NovaBaza = Nothing
    SynchAllTablesIndexRelations = retVal
Exit Function
err_ObradaGreske:
        retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura SynchAllTables se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Function
Public Sub UpdateNewFieldDefault(NovaBaza As DAO.Database, NovaTabela As DAO.TableDef, NovoPolje As DAO.Field)
'Modifikovano 04-02-2019

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
    ' ako je NULL onda txtSQLUpdate = "UPDATE [" & NovaTabela.Name & "] SET [" & NovaTabela.Name & "].[" & NovoPolje.Name & "] = " & apostrof & NovoPolje.DefaultValue & apostrof & " WHERE ((([" & NovaTabela.Name & "].[" & NovoPolje.Name & "]) Is Null));"
    txtSQLUpdate = "UPDATE [" & NovaTabela.Name & "] SET [" & NovaTabela.Name & "].[" & NovoPolje.Name & "] = " & apostrof & NovoPolje.DefaultValue & apostrof & ";"
    'Debug.Print txtSQLUpdate
    'QueryExecute ImeNoveBaze, sqlUpdate
     NovaBaza.Execute txtSQLUpdate
End Sub
Public Sub SynchTextFieldSize_OP(ByRef DobroPolje As DAO.Field, ByRef NovaBaza As DAO.Database, stNovaTabela As String, ByRef NovoPolje As DAO.Field)
'Kreirano 21-01-2019
Dim stSQL As String
 If (NovoPolje.Size <> DobroPolje.Size) And _
    (NovoPolje.Type = DAO.DataTypeEnum.dbText) Then '(NovoPolje.Type = 10) , DAO.DataTypeEnum.dbText = 10 ali je zato ADODB.DataTypeEnum.adError = 10!!!!
     'NovoPolje.Size = DobroPolje.Size
     stSQL = "ALTER TABLE [" & stNovaTabela & "] " _
            & "ALTER COLUMN [" & NovoPolje.Name & "] TEXT(" & DobroPolje.Size & ");" '!!ako stavim CHAR onda upise SPACE do pune dužine
            
     NovaBaza.Execute (stSQL)
 End If

End Sub
Private Function SynchTable_OP(ByRef DobraBaza As DAO.Database, ByRef NovaBaza As DAO.Database, ByRef DobraTabela As DAO.TableDef, ByRef stRretVal As String, CheckUskladiIndexe As Boolean, CheckUskladiRelacije As Boolean) As Boolean
'Modifikovano: 21-01-2019
On Error GoTo err_ObradaGreske
   
    Dim NovaTabela As DAO.TableDef
    Dim DobroPolje As DAO.Field
    Dim NovoPolje As DAO.Field
    Dim i As Integer
    Dim retVal As Boolean
    
    
    retVal = True
         
     If Not CBool(DobraTabela.Attributes And dbSystemObject) Then
        If Not PostojiTabelaUBazi(DobraTabela.Name, NovaBaza) Then
        
            Set NovaTabela = NovaBaza.CreateTableDef(DobraTabela.Name)
            For Each DobroPolje In DobraTabela.Fields
            
                Set NovoPolje = NovaTabela.CreateField(DobroPolje.Name, DobroPolje.Type, DobroPolje.Size)
                
                On Error Resume Next
                For i = 1 To DobroPolje.Properties.Count
                    NovoPolje.Properties(i).Value = DobroPolje.Properties(i).Value
                Next i
                On Error GoTo err_ObradaGreske
                NovaTabela.Fields.Append NovoPolje
                'UpdateNewFieldDefault NovaBaza, NovaTabela, NovoPolje
            Next DobroPolje
            NovaBaza.TableDefs.Append NovaTabela
            If CheckUskladiIndexe Then
             SynchIndexesInTable_OP DobraTabela, NovaTabela, stRretVal
            End If
        'End If
        Else
            ' ovde treba uskladiti polja
            ''''''''''''''''''''''''''''''''''''''''''''''''''
            Set NovaTabela = NovaBaza.TableDefs(DobraTabela.Name)
            For Each DobroPolje In DobraTabela.Fields
             If Not PostojiPoljeUTabeli(DobroPolje.Name, NovaTabela) Then
               'mora da se kreira novo polje za !
                Set NovoPolje = NovaTabela.CreateField(DobroPolje.Name, DobroPolje.Type, DobroPolje.Size)
       
                On Error Resume Next
                For i = 1 To DobroPolje.Properties.Count
                    NovoPolje.Properties(i).Value = DobroPolje.Properties(i).Value
                Next i
                On Error GoTo err_ObradaGreske
                NovaTabela.Fields.Append NovoPolje
                UpdateNewFieldDefault NovaBaza, NovaTabela, NovoPolje
             Else 'postoji polje ali možda nije isti Size, ...
               Set NovoPolje = NovaTabela.Fields(DobroPolje.Name)
               On Error Resume Next 'ako ne može da se uskladi fieldSize jer je deo relacije
               SynchTextFieldSize_OP DobroPolje, NovaBaza, NovaTabela.Name, NovoPolje
               On Error GoTo err_ObradaGreske
             End If
            Next DobroPolje
            ''''''''''''''''''''''''''''''''''''''''''''''''''
         If CheckUskladiIndexe Then
             SynchIndexesInTable_OP DobraTabela, NovaTabela, stRretVal
            End If
        End If
     End If
    If CheckUskladiRelacije Then
     retVal = retVal And SynchAllRelations_OP(DobraBaza, NovaBaza, stRretVal)
    End If
exit_PosleGreske:
On Error Resume Next
    
    Set NovaTabela = Nothing
    Set DobroPolje = Nothing
    Set NovoPolje = Nothing
 
    SynchTable_OP = retVal
    
Exit Function
err_ObradaGreske:
        retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura SynchTable_OP se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Function
Public Function SynchTable(ImeDobreBaze As String, ImeNoveBaze As String, imeTabele As String, ByRef stRretVal As String, Optional CheckUskladiIndexe As Boolean = True, Optional CheckUskladiRelacije As Boolean = True) As Boolean
On Error GoTo err_ObradaGreske
    Dim DobraBaza As DAO.Database
    Dim NovaBaza As DAO.Database
    Dim DobraTabela As DAO.TableDef
    Dim retVal As Boolean
    
    
    retVal = True
    Set DobraBaza = DAO.OpenDatabase(ImeDobreBaze)
    Set NovaBaza = DAO.OpenDatabase(ImeNoveBaze)
    Set DobraTabela = DobraBaza.TableDefs(imeTabele)
    
    retVal = SynchTable_OP(DobraBaza, NovaBaza, DobraTabela, stRretVal, CheckUskladiIndexe, CheckUskladiRelacije)
    
exit_PosleGreske:
On Error Resume Next

    Set DobraTabela = Nothing
    DobraBaza.Close
    Set DobraBaza = Nothing
    
    NovaBaza.Close
    Set NovaBaza = Nothing
    SynchTable = retVal
Exit Function
err_ObradaGreske:
        retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura SynchTable se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Function
Public Function BBReadFieldProperties(BB_DatabaseName As String, BB_TableName As String, BB_FieldName As String, ByRef stRetVal As String) As Boolean
On Error GoTo Err_Point

    Dim dbBigBit As DAO.Database
    Dim tblBigBit As DAO.TableDef
    Dim fldBigBit As DAO.Field
    Dim prop As DAO.Properties
    Dim retValOk As Boolean
    Dim i As Integer
    
    retValOk = True
    Set dbBigBit = DAO.OpenDatabase(BB_DatabaseName)
    Set tblBigBit = dbBigBit.TableDefs(BB_TableName)
    Set fldBigBit = tblBigBit.Fields(BB_FieldName)
    
    For i = 1 To fldBigBit.Properties.Count - 1
      On Error Resume Next
      stRetVal = stRetVal & Format(i, "##0") & "  "
      stRetVal = stRetVal & fldBigBit.Properties(i).Name & " ="
      stRetVal = stRetVal & fldBigBit.Properties(i).Value
      If err.Number > 0 Then
        stRetVal = stRetVal & "Err.Number: " & err.Number & "  Err.Description: " & err.Description & vbCrLf
      End If
      stRetVal = stRetVal & vbCrLf
    Next i
  
    
    
On Error GoTo Err_Point
Exit_Point:
On Error Resume Next
    
    Set fldBigBit = Nothing
    Set tblBigBit = Nothing
    dbBigBit.Close
    Set dbBigBit = Nothing
    
    BBReadFieldProperties = retValOk
Exit Function
Err_Point:
    retValOk = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura BBReadFieldProperties se prekida.", vbCritical, "QMegaTeh"
    Resume Exit_Point
 

End Function

Public Function KreirajPoljeUTabeliPoModelu(ExpImp_DatabaseName As String, ExpImp_TableName As String, ExpImp_FieldName As String, _
                              BB_DatabaseName As String, BB_TableName As String, BB_FieldName As String, ByRef stRetVal As String) As Boolean
                              
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

Public Function CheckAllTables(ImePrveBaze As String, ImeDrugeBaze As String, ByRef stRretVal As String) As Boolean
On Error GoTo err_ObradaGreske
    Dim PrvaBaza As DAO.Database
    Dim DrugaBaza As DAO.Database
    Dim TabelaPrveBaze As DAO.TableDef
    Dim TabelaDrugeBaze As DAO.TableDef
    Dim PoljePrveBaze As DAO.Field
    Dim PoljeDrugeBaze As DAO.Field
    Dim i As Integer
    Dim retValOk As Boolean
    
    retValOk = True
    Set PrvaBaza = DAO.OpenDatabase(ImePrveBaze)
    Set DrugaBaza = DAO.OpenDatabase(ImeDrugeBaze)
    
    For Each TabelaPrveBaze In PrvaBaza.TableDefs
    
     If Not CBool(TabelaPrveBaze.Attributes And dbSystemObject) Then
        If Not PostojiTabelaUBazi(TabelaPrveBaze.Name, DrugaBaza) Then
            stRretVal = stRretVal & vbCrLf & "Baza " & ImeDrugeBaze & " ne sadrži tabelu: " & TabelaPrveBaze.Name
        Else
            Set TabelaDrugeBaze = DrugaBaza.TableDefs(TabelaPrveBaze.Name)
            For Each PoljePrveBaze In TabelaPrveBaze.Fields
             If Not PostojiPoljeUTabeli(PoljePrveBaze.Name, TabelaDrugeBaze) Then
               stRretVal = stRretVal & vbCrLf & "Tabela " & TabelaDrugeBaze.Name & " nema polje " & PoljePrveBaze.Name
             End If
            Next PoljePrveBaze
            ''''''''''''''''''''''''''''''''''''''''''''''''''
        End If
     End If
    Next TabelaPrveBaze
    
exit_PosleGreske:
On Error Resume Next
    
    Set TabelaPrveBaze = Nothing
    Set TabelaDrugeBaze = Nothing
    PrvaBaza.Close
    Set PrvaBaza = Nothing
    
    DrugaBaza.Close
    Set DrugaBaza = Nothing
    CheckAllTables = retValOk
Exit Function
err_ObradaGreske:
    retValOk = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura CheckAllTables se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Function
'**************************************************************************************************
Public Function CheckFieldDet(ByRef PoljePrveBaze As DAO.Field, ByRef PoljeDrugeBaze As DAO.Field) As String
'**************************************************************************************************
'Kreirano: 21-01-2019

On Error GoTo Err_Point
Dim stRetVal As String
Dim stPropName As String
Dim i As Integer

stRetVal = ""
For i = 1 To PoljePrveBaze.Properties.Count
  stPropName = PoljePrveBaze.Properties(i - 1).Name
  
  If PoljePrveBaze.Properties(stPropName).Value <> PoljeDrugeBaze.Properties(stPropName).Value Then
   stRetVal = stRetVal & PoljePrveBaze.Name & "." & stPropName & "= " & PoljePrveBaze.Properties(stPropName).Value
   stRetVal = stRetVal & " !-!-! " & PoljeDrugeBaze.Name & "." & stPropName & "= " & PoljeDrugeBaze.Properties(stPropName).Value & vbCrLf
  End If
Next i

Exit_Point:
 On Error Resume Next
 CheckFieldDet = stRetVal
Exit Function

Err_Point:
 Resume Next
End Function
'**************************************************************************************************
Public Function CheckField(ByRef PoljePrveBaze As DAO.Field, ByRef PoljeDrugeBaze As DAO.Field) As String
'**************************************************************************************************
'Kreirano: 21-01-2019

On Error GoTo Err_Point
Dim stRetVal As String
Dim stFieldName As String
Dim i As Integer

stFieldName = PoljePrveBaze.Name
'stRetVal = stFieldName & ": " & vbCrLf
stRetVal = ""

If PoljePrveBaze.AllowZeroLength <> PoljeDrugeBaze.AllowZeroLength Then
 stRetVal = stRetVal & stFieldName & ".AllowZeroLength= " & PoljeDrugeBaze.AllowZeroLength & ", (" & PoljePrveBaze.AllowZeroLength & ")" & vbCrLf
End If

If PoljePrveBaze.DefaultValue <> PoljeDrugeBaze.DefaultValue Then
stRetVal = stRetVal & stFieldName & ".DefaultValue= " & PoljeDrugeBaze.DefaultValue & ", (" & PoljePrveBaze.DefaultValue & ")" & vbCrLf
End If

If PoljePrveBaze.Required <> PoljeDrugeBaze.Required Then
 stRetVal = stRetVal & stFieldName & ".Required= " & PoljeDrugeBaze.Required & ", (" & PoljePrveBaze.Required & ")" & vbCrLf
End If

If PoljePrveBaze.Size <> PoljeDrugeBaze.Size Then
 stRetVal = stRetVal & stFieldName & ".Size= " & PoljeDrugeBaze.Size & ", (" & PoljePrveBaze.Size & ")" & vbCrLf
End If

If PoljePrveBaze.Type <> PoljeDrugeBaze.Type Then
 stRetVal = stRetVal & stFieldName & ".Type= " & PoljeDrugeBaze.Type & ", (" & PoljePrveBaze.Type & ")" & vbCrLf
End If

If PoljePrveBaze.ValidationRule <> PoljeDrugeBaze.ValidationRule Then
 stRetVal = stRetVal & stFieldName & ".ValidationRule= " & PoljeDrugeBaze.ValidationRule & ", (" & PoljePrveBaze.ValidationRule & ")" & vbCrLf
End If

Exit_Point:
 On Error Resume Next
 CheckField = stRetVal
Exit Function

Err_Point:
 Resume Next
End Function
Public Function CheckTable(ImePrveBaze As String, ImeDrugeBaze As String, imeTabele As String, ByRef stRretVal As String) As Boolean
'*********************************************************************
'Modifikovano 21-01-2019
'Dodata provera polja
'*********************************************************************
On Error GoTo err_ObradaGreske
    Dim PrvaBaza As DAO.Database
    Dim DrugaBaza As DAO.Database
    Dim TabelaPrveBaze As DAO.TableDef
    Dim TabelaDrugeBaze As DAO.TableDef
    Dim PoljePrveBaze As DAO.Field
    Dim PoljeDrugeBaze As DAO.Field
    Dim retVal As Boolean
    Dim stTMP As String
    
    retVal = True
    Set PrvaBaza = DAO.OpenDatabase(ImePrveBaze)
    Set DrugaBaza = DAO.OpenDatabase(ImeDrugeBaze)
    
    Set TabelaPrveBaze = PrvaBaza.TableDefs(imeTabele)
    
     ' If Not CBool(TabelaPrveBaze.Attributes And dbSystemObject) Then
        If Not PostojiTabelaUBazi(TabelaPrveBaze.Name, DrugaBaza) Then
            stRretVal = stRretVal & vbCrLf & "Baza " & ImeDrugeBaze & " ne sadrži tabelu: " & TabelaPrveBaze.Name
        Else
            Set TabelaDrugeBaze = DrugaBaza.TableDefs(TabelaPrveBaze.Name)
            For Each PoljePrveBaze In TabelaPrveBaze.Fields
             If Not PostojiPoljeUTabeli(PoljePrveBaze.Name, TabelaDrugeBaze) Then
               stRretVal = stRretVal & vbCrLf & "Tabela " & TabelaDrugeBaze.Name & " nema polje " & PoljePrveBaze.Name
             Else
               Set PoljeDrugeBaze = TabelaDrugeBaze.Fields(PoljePrveBaze.Name)
               stTMP = CheckField(PoljePrveBaze, PoljeDrugeBaze)
               If Nz(stTMP, "") <> "" Then
                stRretVal = stRretVal & vbCrLf & stTMP
               End If
             End If
            Next PoljePrveBaze
            ''''''''''''''''''''''''''''''''''''''''''''''''''
        End If
     ' End If

    
exit_PosleGreske:
On Error Resume Next
    
    Set TabelaPrveBaze = Nothing
    Set TabelaDrugeBaze = Nothing
    PrvaBaza.Close
    Set PrvaBaza = Nothing
    
    DrugaBaza.Close
    Set DrugaBaza = Nothing
    CheckTable = retVal
Exit Function
err_ObradaGreske:
    retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura UporediTabeleUBazama se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Function
'***********************
'test
Public Sub TestProcitajTabeluIzBaze(ImeDobreBaze As String, imeTabele As String)
'TestProcitajTabeluIzBaze "D:\AcBaze\Testovi\T2\BB_T_Test.mdb", "T_Robna dokumenta"
'TestProcitajTabeluIzBaze "D:\AcBaze\FinoVino\BigBit2014\Vino2014\bb_t_14.MDB","CENOVNIK"
On Error GoTo err_ObradaGreske
    'Dim wrkJet As Workspace
    Dim DobraBaza As DAO.Database
    Dim DobraTabela As DAO.TableDef
    Dim DobroPolje As DAO.Field
    Dim DobarIndex As DAO.Index
    Dim DobarProperty As DAO.Properties
    Dim i As Integer
    
    'Set wrkJet = CreateWorkspace("", "admin", "", dbUseJet)
    
    Set DobraBaza = OpenDatabase(ImeDobreBaze) 'CurrentDb
    
    'For Each DobraTabela In DobraBaza.TableDefs
    Set DobraTabela = DobraBaza.TableDefs(imeTabele)
        Debug.Print "Tabela: " & DobraTabela.Name & "  Ima polja: " & DobraTabela.Fields.Count
           ' For Each DobroPolje In DobraTabela.Fields
           '     Debug.Print "       Polje:" & DobroPolje.Name
           ' Next DobroPolje
            For Each DobarIndex In DobraTabela.Indexes
                Debug.Print "       Index:" & DobarIndex.Name, DobarIndex.Fields, DobarIndex.Foreign
                    'For Each DobarProperty In DobarIndex.Fields
            Next DobarIndex
    'Next DobraTabela
exit_PosleGreske:
On Error Resume Next
    'wrkJet.Close
    Set DobraTabela = Nothing
    DobraBaza.Close
    Set DobraBaza = Nothing
Exit Sub
err_ObradaGreske:
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura TestProcitajTabeleIPoljaIzBaze se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Sub
'***********************
'test
Public Sub TESTProcitajRelacijeIzBaze(ImeDobreBaze As String)
' TESTProcitajRelacijeIzBaze "D:\AcBaze\Testovi\T1\BB_T_Test.mdb"
On Error GoTo err_ObradaGreske
    'Dim wrkJet As Workspace
    Dim DobraBaza As DAO.Database
    Dim DobraTabela As DAO.TableDef
    Dim DobroPolje As DAO.Field
    Dim DobarIndex As DAO.Index
    Dim DobarProperty As DAO.Properties
    Dim DobraRelacija As DAO.Relation
    Dim i As Integer
    
    'Set wrkJet = CreateWorkspace("", "admin", "", dbUseJet)
    
    Set DobraBaza = OpenDatabase(ImeDobreBaze) 'CurrentDb
    
    
            For Each DobraRelacija In DobraBaza.Relations
                Debug.Print "Relacija:" & DobraRelacija.Name, DobraRelacija.Table, DobraRelacija.ForeignTable
            Next DobraRelacija
            
exit_PosleGreske:
On Error Resume Next
    DobraBaza.Close
    Set DobraBaza = Nothing
Exit Sub
err_ObradaGreske:
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura TESTProcitajRelacijeIzBaze se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Sub

Public Function BBCreateDatabase(ByVal ImeNoveBaze As String, Optional ObrisiAkoPostoji As Boolean = False) As Boolean
On Error GoTo Err_Point
   Dim wrkDefault As Workspace
   Dim dbsNew As DAO.Database
   Dim prpLoop As Property
   Dim postojiBaza As Boolean
   Dim retVal As Boolean

   retVal = True
   
    ' Proveri da li se ime fajla zavrsava sa .MDB, ako ne, dodaj .MDB
    If Not (ImeNoveBaze Like "*.MDB") Then
        ImeNoveBaze = ImeNoveBaze & ".MDB"
    End If
    postojiBaza = (Dir(ImeNoveBaze) <> "")
    If postojiBaza Then
        If ObrisiAkoPostoji Then
            Kill ImeNoveBaze
        Else
            retVal = False
            BBCreateDatabase = retVal
            Exit Function
        End If
    End If
    
    ' Get default Workspace.
    Set wrkDefault = DBEngine.Workspaces(0)

   
    ' Create a new encrypted database with the specified
    ' collating order.
    Set dbsNew = wrkDefault.CreateDatabase(ImeNoveBaze, dbLangGeneral, dbVersion40)
Exit_Point:
 On Error Resume Next
    dbsNew.Close
    BBCreateDatabase = retVal
Exit Function
Err_Point:
  BBErrorMSG err, "BBCreateDatabase"
  retVal = False
  Resume Exit_Point
End Function
Public Function PosaljiSadrzajTabele(IzBaze As String, IzImeTabele As String, UBazu As String, UImeTabele As String, Optional WhereUslov As String = "") As Boolean
On Error GoTo err_ObradaGreske

Dim LinkedTableNameIzTabele As String
Dim LinkedTableNameUTabelu As String
Dim PostojiLinkovanaTabela As Boolean
Dim txtSQL As String
Dim QAppend As QueryDef
    
Dim retVal As Boolean

retVal = True
LinkedTableNameIzTabele = "~bbtmpIZT~"
LinkedTableNameUTabelu = "~bbtmpUT~"

PostojiLinkovanaTabela = False
PostojiLinkovanaTabela = CurrentDb.TableDefs(LinkedTableNameIzTabele).Name = LinkedTableNameIzTabele
If PostojiLinkovanaTabela Then
    DoCmd.DeleteObject acTable, LinkedTableNameIzTabele
End If

PostojiLinkovanaTabela = False
PostojiLinkovanaTabela = CurrentDb.TableDefs(LinkedTableNameUTabelu).Name = LinkedTableNameUTabelu
If PostojiLinkovanaTabela Then
    DoCmd.DeleteObject acTable, LinkedTableNameUTabelu
End If

 DoCmd.TransferDatabase acLink, "Microsoft Access", IzBaze, acTable, IzImeTabele, LinkedTableNameIzTabele
 DoCmd.TransferDatabase acLink, "Microsoft Access", UBazu, acTable, UImeTabele, LinkedTableNameUTabelu
 
 txtSQL = "INSERT INTO [" & LinkedTableNameUTabelu & "] SELECT [" & LinkedTableNameIzTabele & "].* FROM [" & LinkedTableNameIzTabele & "]"
 If Trim(WhereUslov) <> "" Then
    txtSQL = txtSQL & " WHERE " & WhereUslov & ";"
 Else
    txtSQL = txtSQL & ";"
 End If
 'kreirmo PRIVREMENI objekat (jer mu je ime "")
 Set QAppend = CurrentDb.CreateQueryDef("", txtSQL)
 QAppend.Execute
 ' MsgBox "Poslato " & QAppend.RecordsAffected
exit_PosleGreske:
PosaljiSadrzajTabele = retVal

Exit Function
err_ObradaGreske:
    If err.Number = 3265 Then
     Resume Next
    ' ElseIf Err.Number = 7874 Then
    '  Resume Next
    Else
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Function PosaljiSadrzajTabele se prekida.", vbCritical, "QMegaTeh"
        
    End If
    retVal = False
    Resume exit_PosleGreske

End Function
Public Function KreirajTabeluUBazi(ImeDobreBaze As String, ImeDobreTabele As String, ImeNoveBaze As String, ImeNoveTabele As String, ByRef stRretVal As String, Optional CheckUskladiIndexe As Boolean = True) As Boolean

On Error GoTo err_ObradaGreske
    Dim DobraBaza As DAO.Database
    Dim NovaBaza As DAO.Database
    Dim DobraTabela As DAO.TableDef
    Dim NovaTabela As DAO.TableDef
    Dim DobroPolje As DAO.Field
    Dim NovoPolje As DAO.Field
    Dim i As Integer
    Dim retVal As Boolean
    
    retVal = True
    
    Set DobraBaza = DAO.OpenDatabase(ImeDobreBaze) 'CurrentDb
    Set NovaBaza = DAO.OpenDatabase(ImeNoveBaze)
    
    Set DobraTabela = DobraBaza.TableDefs(ImeDobreTabele)
       
     If Not CBool(DobraTabela.Attributes And dbSystemObject) Then
        If Not PostojiTabelaUBazi(DobraTabela.Name, NovaBaza) Then
        
            Set NovaTabela = NovaBaza.CreateTableDef(DobraTabela.Name)
            For Each DobroPolje In DobraTabela.Fields
            
                Set NovoPolje = NovaTabela.CreateField(DobroPolje.Name, DobroPolje.Type, DobroPolje.Size)
                
                On Error Resume Next
                For i = 1 To DobroPolje.Properties.Count
                    NovoPolje.Properties(i).Value = DobroPolje.Properties(i).Value
                Next i
                On Error GoTo err_ObradaGreske
                NovaTabela.Fields.Append NovoPolje
               ' UpdateNewFieldDefault NovaBaza, NovaTabela, NovoPolje
               ' ako je nova tabela ne moze da se radi update!!
            Next DobroPolje
            NovaBaza.TableDefs.Append NovaTabela
            If CheckUskladiIndexe Then
             SynchIndexesInTable_OP DobraTabela, NovaTabela, stRretVal
            End If
        'End If
        Else
            ' ovde treba uskladiti polja
            ''''''''''''''''''''''''''''''''''''''''''''''''''
            Set NovaTabela = NovaBaza.TableDefs(DobraTabela.Name)
            For Each DobroPolje In DobraTabela.Fields
             If Not PostojiPoljeUTabeli(DobroPolje.Name, NovaTabela) Then
               'mora da se kreira novo polje za !
                Set NovoPolje = NovaTabela.CreateField(DobroPolje.Name, DobroPolje.Type, DobroPolje.Size)
       
                On Error Resume Next
                For i = 1 To DobroPolje.Properties.Count
                    NovoPolje.Properties(i).Value = DobroPolje.Properties(i).Value
                Next i
                On Error GoTo err_ObradaGreske
                NovaTabela.Fields.Append NovoPolje
                UpdateNewFieldDefault NovaBaza, NovaTabela, NovoPolje
             End If
            Next DobroPolje
            ''''''''''''''''''''''''''''''''''''''''''''''''''
        End If
     End If
    
exit_PosleGreske:
On Error Resume Next
    
    Set NovaTabela = Nothing
    Set DobraTabela = Nothing
    DobraBaza.Close
    Set DobraBaza = Nothing
    
    NovaBaza.Close
    Set NovaBaza = Nothing
    KreirajTabeluUBazi = retVal
Exit Function
err_ObradaGreske:
        retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura KreirajTabeluUBazi se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Function

Public Function ObrisiTabeluUBazi(ImeBaze As String, imeTabele As String) As Boolean
On Error GoTo err_ObradaGreske
    Dim Baza As DAO.Database
    
    Dim retVal As Boolean
    
    retVal = True
    
    Set Baza = DAO.OpenDatabase(ImeBaze)
       

        If PostojiTabelaUBazi(imeTabele, Baza) Then
        
            Baza.Execute "DROP TABLE " & imeTabele & ";", dbFailOnError
                      
        End If

    
exit_PosleGreske:
On Error Resume Next
    
    Baza.Close
    Set Baza = Nothing
    
    
    ObrisiTabeluUBazi = retVal
Exit Function
err_ObradaGreske:
        retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura ObrisiTabeluUBazi se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Function

Public Function LinkTable(ByVal BB_Database As String, ByVal BB_Object As String, ByVal ExpImp_Database As String, ByVal ExpImp_Object As String) As Boolean

On Error GoTo err_ObradaGreske

Dim PostojiTabela As Boolean
Dim PostojiLinkovanaTabela As Boolean

Dim retVal As Boolean

retVal = True
PostojiTabela = False
PostojiLinkovanaTabela = False

PostojiTabela = CurrentDb.TableDefs(BB_Object).Name = BB_Object
PostojiLinkovanaTabela = IsLinkedTableAccess(BB_Object)

If PostojiLinkovanaTabela Then
    DoCmd.DeleteObject acTable, BB_Object
    PostojiTabela = False
End If

If Not PostojiTabela Then
 DoCmd.TransferDatabase acLink, "Microsoft Access", ExpImp_Database, acTable, ExpImp_Object, BB_Object
Else
 retVal = False
End If
 
exit_PosleGreske:
LinkTable = retVal

Exit Function
err_ObradaGreske:
    If err.Number = 3265 Then
     Resume Next
    ' ElseIf Err.Number = 7874 Then
    '  Resume Next
    Else
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Function LinkTable se prekida.", vbCritical, "QMegaTeh"
                    
      retVal = False
      Resume exit_PosleGreske
    End If
    
End Function
Public Function UnLinkTable(ByVal BB_Object As String) As Boolean
On Error GoTo err_ObradaGreske

Dim PostojiLinkovanaTabela As Boolean
Dim retVal As Boolean

retVal = True
PostojiLinkovanaTabela = False
PostojiLinkovanaTabela = IsLinkedTableAccess(BB_Object)

If PostojiLinkovanaTabela Then
    DoCmd.DeleteObject acTable, BB_Object
Else
    retVal = False
End If


exit_PosleGreske:
UnLinkTable = retVal

Exit Function
err_ObradaGreske:
    If err.Number = 3265 Then
     Resume Next
    ' ElseIf Err.Number = 7874 Then
    '  Resume Next
    Else
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Function LinkTable se prekida.", vbCritical, "QMegaTeh"
                    
      retVal = False
      Resume exit_PosleGreske
    End If
    
End Function
Public Function IzvrsiKomandu(ByVal komanda As String, ByVal BB_Database As String, ByVal BB_Object As String, ByVal ExpImp_Database As String, ByVal ExpImp_Object As String, ByVal SQL_Upit As String, ByVal WhereCond As String, ByRef stRretVal As String, ParamArray OtherArgs()) As Boolean
 On Error GoTo err_IzvrsiKomandu
 
    Dim retVal
    
    retVal = True
        BB_Database = ZameniSTDPromenljive(BB_Database)
        BB_Object = ZameniSTDPromenljive(BB_Object)
        ExpImp_Database = ZameniSTDPromenljive(ExpImp_Database)
        ExpImp_Object = ZameniSTDPromenljive(ExpImp_Object)
        SQL_Upit = ZameniSTDPromenljive(SQL_Upit)

      
        Select Case komanda
        Case "CreateDatabase"
            retVal = BBCreateDatabase(ExpImp_Database, True)
        Case "CompactDatabase"
            retVal = BBCompactDatabase(ExpImp_Database, stRretVal)
         Case "CompactDatabaseDecrypt"
            retVal = BBCompactDatabaseDecrypt(ExpImp_Database, stRretVal)
        Case "ExportTableDef"
            retVal = KreirajTabeluUBazi(BB_Database, BB_Object, ExpImp_Database, ExpImp_Object, stRretVal, True)
        Case "ExportTablePod"
            retVal = PosaljiSadrzajTabele(BB_Database, BB_Object, ExpImp_Database, ExpImp_Object, WhereCond)
        Case "LinkTable"
            retVal = LinkTable(BB_Database, BB_Object, ExpImp_Database, ExpImp_Object)
        Case "UnLinkTable"
            retVal = UnLinkTable(BB_Object)
        Case "DeleteTable"
            retVal = ObrisiTabeluUBazi(BB_Database, BB_Object)
        Case "CheckAllTables"
            retVal = CheckAllTables(BB_Database, ExpImp_Database, stRretVal)
        Case "CheckTable"
            retVal = CheckTable(BB_Database, ExpImp_Database, BB_Object, stRretVal)
        Case "ReadRelationInTable"
            retVal = ReadRelationInTable(ExpImp_Database, ExpImp_Object, stRretVal)
        Case "SynchAllTablesIndexRelations"
            retVal = SynchAllTablesIndexRelations(BB_Database, ExpImp_Database, stRretVal, True, True)
        Case "SynchAllTablesAndIndex"
            retVal = SynchAllTablesIndexRelations(BB_Database, ExpImp_Database, stRretVal, True, False)
        Case "SynchAllTablesNoIndexNoRelations"
            retVal = SynchAllTablesIndexRelations(BB_Database, ExpImp_Database, stRretVal, False, False)
        Case "CheckIndexesInTable"
            retVal = CheckIndexesInTable(BB_Database, ExpImp_Database, BB_Object, stRretVal)
        Case "SynchIndexesInTable"
            retVal = SynchIndexesInTable(BB_Database, ExpImp_Database, BB_Object, ExpImp_Object, stRretVal)
        Case "DeleteIndexesInTable"
            retVal = DeleteIndexesInTable(ExpImp_Database, ExpImp_Object, stRretVal)
        Case "ReadAllIndexesInAllTables"
            retVal = ReadAllIndexesInAllTables(ExpImp_Database, stRretVal)
        Case "DeleteAllIndexesInAllTables"
            retVal = DeleteAllIndexesInAllTables(ExpImp_Database, stRretVal, False)
        Case "ReadIndexesInTable"
            retVal = ReadIndexesInTable(ExpImp_Database, ExpImp_Object, stRretVal)
        Case "CheckAllIndexesInAllTables"
            retVal = CheckAllIndexesInAllTables(BB_Database, ExpImp_Database, stRretVal)
        Case "CheckRelations"
            CheckRelations BB_Database, ExpImp_Database, stRretVal
            retVal = True
        Case "ReadAllRelations"
            ReadAllRelations ExpImp_Database, stRretVal
            retVal = True
        Case "DeleteAllRelations"
            DeleteAllRelations ExpImp_Database, stRretVal
            retVal = True
        Case "SynchAllRelations"
            retVal = SynchAllRelations(BB_Database, ExpImp_Database, stRretVal)
        Case "SynchTable"
            retVal = SynchTable(BB_Database, ExpImp_Database, BB_Object, stRretVal, True, True)
        Case "AppendFields"
            retVal = DodajNovaPoljaUTabelu(BB_Object, ExpImp_Object, SQL_Upit)
        Case "TableFieldSetDefaultValue"
            retVal = PostaviDefaultVrednostiUtabeli(BB_Object, ExpImp_Object, SQL_Upit)
        Case "OpenTableDesign"
            retVal = OtvoriObjekat("Table", BB_Object, acViewDesign)
        Case "OpenTableView"
            retVal = OtvoriObjekat("Table", BB_Object, acViewNormal)
        Case "QueryExecute"
            retVal = QueryExecute(ExpImp_Database, SQL_Upit)
        Case "ExportForm"
            retVal = PosaljiFormu(ExpImp_Database, BB_Object)
        Case "ExportReport"
            retVal = PosaljiReport(ExpImp_Object, SQL_Upit)
        Case "ExportQuery"
            retVal = PosaljiUpit(ExpImp_Object, SQL_Upit)
        Case "ExportModule"
            retVal = PosaljiModul(ExpImp_Object, SQL_Upit)
         Case "ReadAllDBProperties"
            retVal = ReadAllDBProperties(ExpImp_Database, stRretVal)
        Case "ConvertToAcc2002"
            retVal = BBCOnvertToAcc2002(ExpImp_Database, stRretVal)
        'Case "ExportFunction" 'Ovo ne radi dobro!?
        '    retval = PosaljiFunkciju(ExpImp_Object, SQL_Upit)
        Case "ShowTablesWithoutPK"
            retVal = ShowTablesWithoutPK(ExpImp_Database, stRretVal)
        Case "BBReadFieldProperties"
            retVal = BBReadFieldProperties(BB_Database, BB_Object, CStr(OtherArgs(0)), stRretVal)
        Case "KreirajPoljeUTabeliPoModelu"
            retVal = KreirajPoljeUTabeliPoModelu(ExpImp_Database, ExpImp_Object, CStr(OtherArgs(1)), BB_Database, BB_Object, CStr(OtherArgs(0)), stRretVal)
        Case "SynchAllRelationsForTable"
            retVal = SynchAllRelationsForTable(BB_Database, ExpImp_Database, ExpImp_Object, stRretVal)
        'Case "BBCreateRelation"
            'retval = BBCreateRelation(ExpImp_Database, ExpImp_Object,ExpImp_Object
        Case "RunLocalQuery"
            retVal = RunLocalQuery(BB_Object)
        Case Else
            MsgBox "Nepoznata komanda u proceduri IzvrsiKomandu!", vbCritical, "QMegaTeh"
            retVal = False
        End Select
        
exit_IzvrsiKomandu:
 On Error Resume Next
    IzvrsiKomandu = retVal
Exit Function
err_IzvrsiKomandu:
     MsgBox "ErrNo: " & err.Number & vbCrLf _
            & err.Description & vbCrLf _
            & "Function IzvrsiKomandu se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    
    Resume exit_IzvrsiKomandu

End Function
Public Function BBRunProgZaSveRadneFajlove(ByVal stImePrograma As String, Optional ByVal ImeBazeRF) As Boolean
On Error GoTo Err_Point

 Dim rstRF As DAO.Recordset
 Dim stExpImpDataBaseName As String
 Dim stImeBazeRF As String
 Dim retValOk As Boolean
 Dim brojac As Integer
 Dim lintErrNo As Long
 Dim stErrDesc As String
 Dim stMsg As String
 
 brojac = 0
 retValOk = True
 If Not IsMissing(ImeBazeRF) Then
  stImeBazeRF = CStr(ImeBazeRF)
  retValOk = ForsirajNoviLinkZaTabelu("ExpImp_RadniFajlovi", "Radni Fajlovi", stImeBazeRF)
   If Not retValOk Then
      MsgBox "Tabela ExpImp_RadniFajlovi nije dostupna u bazi = " & stImeBazeRF, vbExclamation, "QMegaTeh"
      BBRunProgZaSveRadneFajlove = False
      Exit Function
   End If
 End If
 
 Set rstRF = CurrentDb.OpenRecordset("ExpImp_RadniFajlovi")
 
 While Not rstRF.EOF
  brojac = brojac + 1
  DoEvents
  stExpImpDataBaseName = Nz(rstRF![Naziv baze], "")
   If IsLoaded("BB_Prog") Then
      Forms![BB_Prog]!Komentar = Format(brojac, "0\.") & " " & stExpImpDataBaseName & vbCrLf & Forms![BB_Prog]!Komentar
      Forms![BB_Prog]!Komentar.Requery
      DoEvents
      Forms![BB_Prog]!Komentar.Requery
   End If
  
   If FileExists(stExpImpDataBaseName) Then
    On Error Resume Next
       BBRunProg stImePrograma, stExpImpDataBaseName
       lintErrNo = err.Number
       stErrDesc = err.Description
       On Error GoTo Err_Point
       
    If lintErrNo <> 0 Then
       stMsg = "Za " & stExpImpDataBaseName & "  Err.Number: " & CStr(lintErrNo) & " Err.Description: " & stErrDesc & vbCrLf
       Forms![BB_Prog]!Komentar = "Za " & stExpImpDataBaseName & "  Err.Number: " & CStr(lintErrNo) & " Err.Description: " & stErrDesc & vbCrLf & Forms![BB_Prog]!Komentar
       stMsg = stMsg & "Da li nastavljate proces?"
       If Not BBPitanje(stMsg) Then
          GoTo Exit_Point
       End If
    End If
   Else
       MsgBox "Ne postoji ExpImp_Database = " & stExpImpDataBaseName, vbExclamation, "QMegaTeh"
    End If
  rstRF.MoveNext
 Wend
 
Exit_Point:

 On Error Resume Next
 rstRF.Close
 Set rstRF = Nothing
 BBRunProgZaSveRadneFajlove = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "BBRunProgZaSveRadneFajlove"
 retValOk = False
 Resume Exit_Point
End Function
Public Sub BBRunProg(ByVal ImePrograma As String, Optional ExpImpDataBaseName)
    Dim QDefRstProg As DAO.QueryDef
    Dim rstProg As DAO.Recordset
    Dim txtSQL As String
    Dim retVal As Boolean
    Dim stRretVal As String
    Dim Poruka As String
    Dim stExpImpDataBaseName As String
    
    retVal = True
    txtSQL = "SELECT BB_ProgLines.* FROM BB_ProgLines WHERE (((BB_ProgLines.DoIt)=True) AND ((BB_ProgLines.IDProg)=[ProgName])) ORDER BY BB_ProgLines.IDSort;"
     
    Set QDefRstProg = CurrentDb.CreateQueryDef("", txtSQL)
    QDefRstProg.Parameters("[ProgName]") = ImePrograma
    
    'Set rstProg = QDefRstProg.OpenRecordset(dbOpenForwardOnly, dbOpenDynaset) ', dbSeeChanges)
    Set rstProg = QDefRstProg.OpenRecordset(dbOpenDynaset)
    
    While Not rstProg.EOF
        stRretVal = ""
        
        If Not IsMissing(ExpImpDataBaseName) Then
         stExpImpDataBaseName = CStr(ExpImpDataBaseName)
        Else
         stExpImpDataBaseName = Nz(rstProg!ExpImp_Database, "")
        End If
        
    '  Debug.Print rstProg!Rbr, rstProg!Komanda, Nz(rstProg!BB_Database, ""), Nz(rstProg!BB_Object, ""), Nz(rstProg!ExpImp_Database, ""), Nz(rstProg!ExpImp_Object, ""), Nz(rstProg!SQL_Upit, "")
    If rstProg!DoIt Then
       retVal = IzvrsiKomandu(rstProg!BBCmd, Nz(rstProg!BB_Database, ""), Nz(rstProg!BB_Object, ""), stExpImpDataBaseName, Nz(rstProg!ExpImp_Object, ""), Nz(rstProg!SQL_Query, ""), Nz(rstProg!WhereCond, ""), stRretVal, Nz(rstProg!BB_Field, ""), Nz(rstProg!ExpImp_Field, ""))
       Poruka = Now() & vbCrLf & "Komanda [" & rstProg!BBCmd & "] " & IIf(retVal, "JE USPEŠNO", "NIJE USPEŠNO") & " izvršena."
    Else
       Poruka = Now() & vbCrLf & "Komanda [" & rstProg!BBCmd & "] " & "NIJE izvršena (DoIt = False)."
    End If
    
       rstProg.Edit
       rstProg!result = Poruka & vbCrLf & stRretVal
       rstProg.Update
     rstProg.MoveNext
    Wend
    QDefRstProg.Close
    Set QDefRstProg = Nothing
    rstProg.Close
    Set rstProg = Nothing
End Sub
Private Function ZameniSTDPromenljive(ByVal inPar As String) As String
 Dim retVal As String
 retVal = inPar
 While InStr(retVal, "%Date%") <> 0
    retVal = Left(retVal, InStr(retVal, "%Date%") - 1) & Date & Right(retVal, Len(retVal) - InStr(retVal, "%Date%") - 5)
 Wend
 While InStr(retVal, "%CurrentDBName%") <> 0
    retVal = Left(retVal, InStr(retVal, "%CurrentDBName%") - 1) & CurrentDb.Name & Right(retVal, Len(retVal) - InStr(retVal, "%CurrentDBName%") - 14)
 Wend
 ZameniSTDPromenljive = retVal
End Function

Public Function TestParArr(ParamArray OtherArgs())
Dim i As Integer

     Debug.Print "LBound = " & LBound(OtherArgs())
     Debug.Print "UBound = " & UBound(OtherArgs())
     
     For i = LBound(OtherArgs()) To UBound(OtherArgs())
      Debug.Print "par(" & i & ")=", OtherArgs(i), TypeName(OtherArgs(i))
    Next i
    
End Function
Public Sub TestProcitajIndexe(ByRef imeTabele As String)
On Error GoTo err_ObradaGreske
 Dim bb As DAO.Database
 Dim DobarIndex As DAO.Index
 Dim DobraTabela As DAO.TableDef
 Dim i As Integer
 
 Set bb = CurrentDb
 Set DobraTabela = bb.TableDefs(imeTabele)
     For Each DobarIndex In DobraTabela.Indexes
      'If Not DobarIndex.Foreign Then
                 Debug.Print "=======>"; DobarIndex.Fields
                 For i = 0 To DobarIndex.Properties.Count - 1
                   Debug.Print DobarIndex.Properties(i).Name & "=" & DobarIndex.Properties(i).Value
                 Next i
      ' End If
     Next DobarIndex
exit_PosleGreske:
Set DobraTabela = Nothing
bb.Close
Set bb = Nothing
Set DobarIndex = Nothing
Exit Sub
err_ObradaGreske:
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura TestProcitajIndexe se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske

End Sub

Private Function CheckIndexesInTable_OP(ByRef DobraBaza As DAO.Database, ByRef NovaBaza As DAO.Database, ByRef DobraTabela As DAO.TableDef, ByRef NovaTabela As DAO.TableDef, ByRef stRretVal As String) As Boolean
On Error GoTo err_ObradaGreske
    
    Dim DobarIndex As DAO.Index
    Dim NoviIndex As DAO.Index
    Dim retVal As Boolean
    Dim PostojiIndexUNovojTabeli As Boolean
    
    retVal = True
    
     For Each DobarIndex In DobraTabela.Indexes
     PostojiIndexUNovojTabeli = False
     For Each NoviIndex In NovaTabela.Indexes
        If DobarIndex.Fields = NoviIndex.Fields Then
          If (DobarIndex.Primary = NoviIndex.Primary) And (DobarIndex.Foreign = NoviIndex.Foreign) Then
              PostojiIndexUNovojTabeli = True
          End If
        End If
     Next
     If Not PostojiIndexUNovojTabeli Then
      If DobarIndex.Foreign Then
        'MsgBox "Ne postoji index-foreign key " & DobarIndex.Fields
        stRretVal = stRretVal & "U tabeli " & NovaTabela.Name & " ne postoji index-foreign key " & DobarIndex.Fields & vbCrLf
      Else
        'MsgBox "Ne postoji index " & DobarIndex.Fields
         If DobarIndex.Primary Then
            stRretVal = stRretVal & "U tabeli " & NovaTabela.Name & " ne postoji PrimaryKey " & DobarIndex.Fields & vbCrLf
         Else
            stRretVal = stRretVal & "U tabeli " & NovaTabela.Name & " ne postoji index " & DobarIndex.Fields & vbCrLf
         End If
      End If
     Else 'postoji index
      If DobarIndex.Foreign Then
        'strRetVal = strRetVal & "U tabeli " & ImeTabele & " postoji index-foreign key " & DobarIndex.Fields & vbCrLf
      Else
        'strRetVal = strRetVal & "U tabeli " & ImeTabele & " postoji index " & DobarIndex.Fields & vbCrLf
      End If
     End If
     ' If Not DobarIndex.Foreign Then
     '           Set NoviIndex = NovaTabela.CreateIndex(DobarIndex.Name)
     '           NoviIndex.Clustered = DobarIndex.Clustered
     '           'NoviIndex.DistinctCount = DobarIndex.DistinctCount
     '           NoviIndex.Fields = DobarIndex.Fields
     '           'NoviIndex.Foreign = DobarIndex.Foreign
     '           NoviIndex.IgnoreNulls = DobarIndex.IgnoreNulls
     '           NoviIndex.Name = DobarIndex.Name
     '           NoviIndex.Primary = DobarIndex.Primary
     '           'NoviIndex.Properties = DobarIndex.Properties
     '           NoviIndex.Required = DobarIndex.Required
     '           NoviIndex.Unique = DobarIndex.Unique
     '
     '           On Error Resume Next
     '            For i = 1 To DobarIndex.Properties.Count
     '              NoviIndex.Properties(i).Value = DobarIndex.Properties(i).Value
     '            Next i
     '           On Error GoTo err_ObradaGreske
     '   'NovaTabela.Indexes.Append NoviIndex
     '  End If
     Next DobarIndex

exit_PosleGreske:
On Error Resume Next
    Set NoviIndex = Nothing
    Set DobarIndex = Nothing
    
    CheckIndexesInTable_OP = retVal
Exit Function
err_ObradaGreske:
        retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura CheckIndexesInTable_OP se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Function
Public Function CheckIndexesInTable(ImeDobreBaze As String, ImeNoveBaze As String, imeTabele As String, ByRef stRretVal As String) As Boolean
' CheckIndexesInTable("C:\SHARES\AcBaze\BigBit\TG\BB_t_TG.mdb","D:\AcBaze\FinoVino\BigBit2014\VINO2014\BB_t_14.mdb","R_Artikli")
On Error GoTo err_ObradaGreske
    Dim DobraBaza As DAO.Database
    Dim NovaBaza As DAO.Database
    Dim DobraTabela As DAO.TableDef
    Dim NovaTabela As DAO.TableDef
    Dim retVal As Boolean
    Dim PostojiIndexUNovojTabeli As Boolean
    
    retVal = True
    Set DobraBaza = DAO.OpenDatabase(ImeDobreBaze) 'CurrentDb
    Set NovaBaza = DAO.OpenDatabase(ImeNoveBaze)
    
    Set DobraTabela = DobraBaza.TableDefs(imeTabele)
    Set NovaTabela = NovaBaza.TableDefs(imeTabele)
    
    retVal = CheckIndexesInTable_OP(DobraBaza, NovaBaza, DobraTabela, NovaTabela, stRretVal)


exit_PosleGreske:
On Error Resume Next

    Set NovaTabela = Nothing
    Set DobraTabela = Nothing
    DobraBaza.Close
    Set DobraBaza = Nothing
    NovaBaza.Close
    Set NovaBaza = Nothing
    CheckIndexesInTable = retVal
Exit Function
err_ObradaGreske:
        retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura CheckIndexesInTable se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Function

Public Function CheckAllIndexesInAllTables(ImeDobreBaze As String, ImeNoveBaze As String, ByRef stRretVal As String) As Boolean
' CheckIndexesInTable("C:\SHARES\AcBaze\BigBit\TG\BB_t_TG.mdb","D:\AcBaze\FinoVino\BigBit2014\VINO2014\BB_t_14.mdb")
On Error GoTo err_ObradaGreske
    Dim DobraBaza As DAO.Database
    Dim NovaBaza As DAO.Database
    Dim DobraTabela As DAO.TableDef
    Dim NovaTabela As DAO.TableDef
    
    Dim retVal As Boolean
    Dim PostojiIndexUNovojTabeli As Boolean
    
    retVal = True
    Set DobraBaza = DAO.OpenDatabase(ImeDobreBaze) 'CurrentDb
    Set NovaBaza = DAO.OpenDatabase(ImeNoveBaze)
    
    'Set DobraTabela = DobraBaza.TableDefs(ImeTabele)
    
    For Each DobraTabela In DobraBaza.TableDefs
     If Not CBool(DobraTabela.Attributes And dbSystemObject) Then
        Set NovaTabela = NovaBaza.TableDefs(DobraTabela.Name)
        retVal = retVal And CheckIndexesInTable_OP(DobraBaza, NovaBaza, DobraTabela, NovaTabela, stRretVal)
     End If
sledecatabela:
    Next DobraTabela
    
exit_PosleGreske:
On Error Resume Next

    Set NovaTabela = Nothing
    Set DobraTabela = Nothing
    DobraBaza.Close
    Set DobraBaza = Nothing
    
    NovaBaza.Close
    Set NovaBaza = Nothing
    CheckAllIndexesInAllTables = retVal
Exit Function
err_ObradaGreske:
    If err.Number = 3265 Then
        'MsgBox "ErrNo: " & Err.Number & vbCrLf _
                    & Err.Description & vbCrLf _
                    & "Ne postoji tabela " & DobraTabela.Name & "!", vbCritical, "QMegaTeh"
        stRretVal = stRretVal & "Ne postoji tabela " & DobraTabela.Name & vbCrLf
        Resume sledecatabela
    Else
        retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura CheckAllIndexesInAllTables se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    End If
    
End Function

Public Sub BBOpenDatabase_TEST(DBName As String)
'   "D:\AcBaze\Testovi\T1\BB_T_Test.mdb"
   Dim wrkJet As Workspace
   Dim dbsNovaBaza As DAO.Database

   ' Create Microsoft Jet Workspace object.
 '  Set wrkJet = CreateWorkspace("", "admin", "", dbUseJet)

   
   ' Open Database object from saved Microsoft Jet database
   ' for exclusive use.
   MsgBox "Opening DBName..."
   'Set dbsNovaBaza = wrkJet.OpenDatabase(DBName, False)
   Set dbsNovaBaza = OpenDatabase(DBName, False)
   'Set CurrentDb = dbsNovaBaza
   
    'EditujUpitUBazi "", dbsNovaBaza
    'dbsNovaBaza.c
    
   dbsNovaBaza.Close
   'wrkJet.Close

End Sub
Public Sub EditujUpitUBazi_TEST(Upit As Variant, dbsDataBase As DAO.Database)
On Error GoTo err_Sub
Dim retVal
Dim qDef As DAO.QueryDef
Dim imeTMPupita As String
imeTMPupita = "~ExpImpTmp~"

On Error Resume Next
    If dbsDataBase.QueryDefs(imeTMPupita).Name = imeTMPupita Then
        dbsDataBase.QueryDefs.Delete imeTMPupita
    End If
On Error GoTo err_Sub
    If Nz(Upit, "") = "" Then
            Upit = "SELECT x from x" 'mora nesto
        
    End If
    Set qDef = dbsDataBase.CreateQueryDef(imeTMPupita, Upit)
    DoCmd.OpenQuery imeTMPupita, acViewDesign
exit_PosleGreske:
On Error Resume Next
    Set qDef = Nothing
Exit Sub
err_Sub:
If err.Number = 3265 Then
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "", vbCritical, "QMegaTeh"
        Resume Next
    Else
        retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura EditujUpit se prekida.", vbCritical, "QMegaTeh"
        Resume exit_PosleGreske
    End If
End Sub

Public Function BBCompactDatabase(ByVal NazivBaze As String, Optional ByRef stRretVal) As Boolean
On Error GoTo Err_Compact

Dim errloop
Dim f As Integer
Dim cDB As DAO.Database
Dim retVal As Boolean
    
    retVal = True
    Set cDB = CurrentDb

    If IsNull(NazivBaze) Then
        MsgBox "Nije izabran fajl", vbInformation, "QMegaTeh"
        retVal = False
        GoTo Exit_Compact
        End If
    If NazivBaze = cDB.Name Then
        retVal = False
        MsgBox ("Ne može se raditi COMPACT na aktivnoj bazi")
        GoTo Exit_Compact
    End If
        
    If FileExists(Mid(NazivBaze, 1, Len(NazivBaze) - 3) & "bak") Then
        Kill Mid(NazivBaze, 1, Len(NazivBaze) - 3) & "bak"
    End If
        
    Name NazivBaze As Mid(NazivBaze, 1, Len(NazivBaze) - 3) & "bak"
    'DBEngine.CompactDatabase Mid(NazivBaze, 1, Len(NazivBaze) - 3) & "bak", NazivBaze, , dbDecrypt
    DBEngine.CompactDatabase Mid(NazivBaze, 1, Len(NazivBaze) - 3) & "bak", NazivBaze
      
Exit_Compact:
On Error Resume Next
    Set cDB = Nothing
    BBCompactDatabase = retVal
Exit Function

Err_Compact:
    retVal = False
    For Each errloop In DBEngine.Errors
        MsgBox "Compaction unsuccessful!" & vbCr & _
            "Error number: " & errloop.Number & _
            vbCr & errloop.Description

    Next errloop
 Resume Exit_Compact
End Function
Public Function BBCompactDatabaseDecrypt(ByVal fName As String, ByRef stRretVal) As Boolean
Dim retVal As Boolean
    retVal = True
    
    If Not BBPitanje("Ako nisi vlasnik baze OVO NE SMES DA RADIS jer ce baza biti obrisana!!!!" & vbCrLf & "Nastavljas na svoju odgovornost?", vbDefaultButton2) Then
       BBCompactDatabaseDecrypt = False
       Exit Function
    End If
    
    If FileExists(Mid(fName, 1, Len(fName) - 3) & "bak") Then
       Kill Mid(fName, 1, Len(fName) - 3) & "bak"
    End If
    Name fName As Mid(fName, 1, Len(fName) - 3) & "bak"
    DBEngine.CompactDatabase Mid(fName, 1, Len(fName) - 3) & "bak", fName, , dbDecrypt
    BBCompactDatabaseDecrypt = retVal
End Function
Public Function ReadAllDBProperties(ByVal DBName As String, Optional ByRef retValString As String) As Boolean
'Modifikovano: 05-02-2021

   Dim dbTest As DAO.Database
   Dim prpLoop As Property
   Dim retValOk As Boolean

   retValOk = True
   If DBName = "" Or DBName = "CurrentDB" Then
      Set dbTest = CurrentDb
   Else
    Set dbTest = OpenDatabase(DBName)
   End If
   
   With dbTest
      retValString = .Name & ", version " & .Version & vbCrLf
      For Each prpLoop In .Properties
         On Error Resume Next
         If prpLoop <> "" Then
          retValString = retValString & "  " & prpLoop.Name & " = " & prpLoop & vbCrLf
         End If
         On Error GoTo 0
      Next prpLoop
      
   End With
   Set prpLoop = Nothing
   dbTest.Close
   Set dbTest = Nothing
 ReadAllDBProperties = retValOk
End Function
Private Function StringOpisRelacije(ByRef Relacija As DAO.Relation) As String
 Dim txtMSG As String
 Dim i As Integer
    txtMSG = "Relacija "
    txtMSG = txtMSG & "Name: [" & Relacija.Name & "]" & vbCrLf
    txtMSG = txtMSG & "========================================" & vbCrLf
    txtMSG = txtMSG & DoChRight("Table", 40, " ") & "Relacija" & vbCrLf
    txtMSG = txtMSG & DoChRight(Relacija.Table, 40, " ") & Relacija.ForeignTable & vbCrLf
    txtMSG = txtMSG & "========================================" & vbCrLf
    For i = 0 To Relacija.Fields.Count - 1
     txtMSG = txtMSG & i & ".    " & DoChRight(Relacija.Fields(i).Name, 40, " ") & Relacija.Fields(i).ForeignName & vbCrLf & vbCrLf
     ' txtMSG = txtMSG & "Field(" & i & ").name = " & DobraRelacija.Fields(i).Name & Space(10)
     ' txtMSG = txtMSG & "Field(" & i & ").ForeignName = " & DobraRelacija.Fields(i).ForeignName & vbCrLf
    Next i
    StringOpisRelacije = txtMSG
End Function

Public Function BBCOnvertToAcc2002(ByVal fName As String, ByRef stRretVal) As Boolean
Dim retValOk As Boolean
Dim stDestFileName As String
Dim stBackupFileName As String

retValOk = True

stDestFileName = fName
stBackupFileName = Left(fName, Len(fName) - 4) & ".OLD"

If FileExists(stBackupFileName) Then
  stRretVal = "Postoji fajl " & stBackupFileName & " Proces konverzije se prekida."
  retValOk = False
  BBCOnvertToAcc2002 = retValOk
  Exit Function
Else
   Name fName As stBackupFileName
   On Error Resume Next
   Application.ConvertAccessProject stBackupFileName, stDestFileName, acFileFormatAccess2002
   If err.Number <> 0 Then
    stRretVal = "err.Number: " & err.Number & " " & err.Description
    err.Clear
    Name stBackupFileName As fName
    retValOk = False
   End If
End If
   
BBCOnvertToAcc2002 = retValOk

End Function
Public Function KreirajPoljeUTabeli(ImeBaze As String, imeTabele As String, ImePolja As String, _
                                    TipPolja As DAO.DataTypeEnum, SizePolja As Integer, Optional NovoPoljeDefaultVal) As Boolean

On Error GoTo err_ObradaGreske
    Dim Baza As DAO.Database
    Dim Tabela As DAO.TableDef
    Dim NovoPolje As DAO.Field
    Dim retVal As Boolean
    
    retVal = True
    
    Set Baza = DAO.OpenDatabase(ImeBaze)
    
    Set Tabela = Baza.TableDefs(imeTabele)
    Set NovoPolje = Tabela.CreateField(ImePolja, TipPolja, SizePolja)
    If Not IsMissing(NovoPoljeDefaultVal) Then
     NovoPolje.DefaultValue = NovoPoljeDefaultVal
    End If
    Tabela.Fields.Append NovoPolje
    
exit_PosleGreske:
On Error Resume Next
    
    Set Tabela = Nothing
    Baza.Close
    KreirajPoljeUTabeli = retVal
Exit Function
err_ObradaGreske:
        retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura KreirajPoljeUTabeli se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Function
'***********************************************
'01.04.2018.
'Kreiraj polje u bazi, u tabeli...
'*************************************************
Public Function X_KreirajPoljeUTabeli(stImeBaze As String, _
                                    stImeTabele As String, _
                                    stImePolja As String, _
                                    intDBType As Integer, _
                                    Optional intSize As Integer, _
                                    Optional DefaultVal) As Boolean

On Error GoTo err_KreirajPoljeUTabeli

 'stImeBaze = "C:\SHARES\AcBaze\MalaKasa\MalaKasa_T.mdb"
 'stImeBaze = "C:\TMP\MalaKasa_T.mdb"
 'stImeTabele = "Dokumenta"
 'primer: ?  KreirajPoljeUTabeli("C:\TMP\MalaKasa_T.mdb", "Dokumenta","Godina",dbLong,,0)
 
 Dim retVal As Boolean
 
 Dim dbUBazi As DAO.Database
 Dim tbdefUTabeli As DAO.TableDef
 Dim fieldNovoPolje As DAO.Field

 Dim i As Integer
 
 retVal = True
 Set dbUBazi = OpenDatabase(stImeBaze)
 Set tbdefUTabeli = dbUBazi.TableDefs(stImeTabele)
 
 If Not tbdefUTabeli.Updatable Then
    MsgBox "Tabela " & stImeTabele & " u bazi " & stImeBaze & " nije UPDATABLE. Proces se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    GoTo exit_KreirajPoljeUTabeli
 End If
 
 'PrikaziPoljaIzTabele tbdefUTabeli
 If Not PostojiPoljeUTabeli(stImePolja, tbdefUTabeli) Then
                
        Set fieldNovoPolje = tbdefUTabeli.CreateField(stImePolja, intDBType, intSize)
        If Not IsMissing(intSize) Then
           fieldNovoPolje.Size = intSize
        End If
        If Not IsMissing(DefaultVal) Then
         fieldNovoPolje.DefaultValue = DefaultVal
        End If
        
        'If fieldNovoPolje.Type = dbText Then
        '    fieldNovoPolje.AllowZeroLength = ?
        'End If
        'fieldNovoPolje.DefaultValue = DefaultVal
        'fieldNovoPolje.Required = Required
        'fieldNovoPolje.ValidationRule = ValidationRule
        'fieldNovoPolje.ValidationText = ValidationText
        
        'neki propertisi ne mogu da se prepisu i bas me briga
        'neka prepise ono sto moze
        'On Error Resume Next
        'For i = 1 To polje.Properties.Count
        '    NovoPolje.Properties(i).Value = polje.Properties(i).Value
        'Next i
        'On Error GoTo err_KreirajPoljeUTabeli
        tbdefUTabeli.Fields.Append fieldNovoPolje
        UpdateNewFieldDefault dbUBazi, tbdefUTabeli, fieldNovoPolje
 Else
    MsgBox "Polje " & stImePolja & " postoji u tabeli " & stImeTabele, vbExclamation, "QMegaTeh"
    retVal = False
    GoTo exit_KreirajPoljeUTabeli
 End If
    
exit_KreirajPoljeUTabeli:
On Error Resume Next
 Set tbdefUTabeli = Nothing
 dbUBazi.Close
 Set dbUBazi = Nothing
 X_KreirajPoljeUTabeli = retVal
 Exit Function
 
err_KreirajPoljeUTabeli:
    'Debug.Print "Polje = " & polje.Name; "i= ", i, Err.Number, Err.Description
    MsgBox "ErrNo: " & err.Number & vbCrLf _
            & err.Description & vbCrLf _
            & "Proces dodavanja polja u tabelu " & stImeTabele _
            & " se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    Resume exit_KreirajPoljeUTabeli
End Function

Public Function SynchAllRelationsForTable(ImeDobreBaze As String, ImeNoveBaze As String, stTableName As String, ByRef stRretVal As String) As Boolean
On Error GoTo err_ObradaGreske
    Dim DobraBaza As DAO.Database
    Dim NovaBaza As DAO.Database
    Dim retVal As Boolean
    
    retVal = True
    Set DobraBaza = DAO.OpenDatabase(ImeDobreBaze)
    Set NovaBaza = DAO.OpenDatabase(ImeNoveBaze)
    
    retVal = SynchAllRelationsForTable_OP(DobraBaza, NovaBaza, stTableName, stRretVal)
    
exit_PosleGreske:
On Error Resume Next

    DobraBaza.Close
    Set DobraBaza = Nothing
    
    NovaBaza.Close
    Set NovaBaza = Nothing
    SynchAllRelationsForTable = retVal
Exit Function
err_ObradaGreske:
        retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura SynchAllRelationsForTable se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Function
Private Function SynchAllRelationsForTable_OP(ByRef DobraBaza As DAO.Database, ByRef NovaBaza As DAO.Database, stTableName As String, ByRef stRretVal As String) As Boolean
On Error GoTo err_ObradaGreske
 Dim DobraRelacija As DAO.Relation
 Dim NovaRelacija As DAO.Relation
 Dim NovoPolje As DAO.Field
 Dim brojac As Long
 Dim i As Integer
 Dim retVal As Boolean
 
 retVal = True
     For Each DobraRelacija In DobraBaza.Relations
      DoEvents
    If DobraRelacija.Table = stTableName Then
      If Not PostojiRelacija(DobraRelacija, NovaBaza) Then
        Set NovaRelacija = NovaBaza.CreateRelation()
        NovaRelacija.ForeignTable = DobraRelacija.ForeignTable
        NovaRelacija.Name = DobraRelacija.Name
        'NovaRelacija.PartialReplica = DobraRelacija.PartialReplica
        'NovaRelacija.Properties = DobraRelacija.Properties
        NovaRelacija.Table = DobraRelacija.Table
        NovaRelacija.Attributes = DobraRelacija.Attributes
        'NovaRelacija.Fields = DobraRelacija.Fields
        
        For i = 0 To DobraRelacija.Fields.Count - 1
            Set NovoPolje = NovaRelacija.CreateField(DobraRelacija.Fields(i).Name)
            NovoPolje.ForeignName = DobraRelacija.Fields(i).ForeignName
            NovaRelacija.Fields.Append NovoPolje
        Next i
        
        On Error Resume Next 'Ima propertisa koji ne postoje u ovom kontekstu
        For i = 0 To DobraRelacija.Properties.Count - 1
            If DobraRelacija.Properties(i).Name <> "PartialReplica" Then '!!!Užassno sporo radi sa ovim properties-om !!!!!
             NovaRelacija.Properties(i).Value = DobraRelacija.Properties(i).Value
            End If
        Next i
        On Error Resume Next
         brojac = 0
         Do
          brojac = brojac + 1
         NovaBaza.Relations.Append NovaRelacija
         
         If err.Number = 3626 Then
            stRretVal = stRretVal & "NIJE dodata " & StringOpisRelacije(NovaRelacija) & vbCrLf
            stRretVal = stRretVal & err.Description & vbCrLf
            err.Clear
            Exit Do
         ElseIf err Then
              If brojac > 100 Then
                 ' GoTo err_ObradaGreske
                 stRretVal = stRretVal & "NIJE dodata " & StringOpisRelacije(NovaRelacija) & vbCrLf
                 ' MsgBox "ErrNo: " & Err.Number & vbCrLf _
                 '   & Err.Description & vbCrLf _
                 '   & "Procedura SynchAllRelations nastavlja izvršavanje za sledeæu relaciju.", vbCritical, "QMegaTeh"
                 Exit Do
              End If
             NovaRelacija.Name = NovaRelacija.Table & NovaRelacija.ForeignTable & brojac
             err.Clear
          Else
             stRretVal = stRretVal & "Dodata je " & StringOpisRelacije(NovaRelacija) & vbCrLf
             Exit Do
         End If
         Loop
        
        On Error GoTo err_ObradaGreske

      End If
End If 'If DobraRelacija.Table = stTableName Then
     Next DobraRelacija
exit_PosleGreske:
Set NovaRelacija = Nothing
Set DobraRelacija = Nothing
SynchAllRelationsForTable_OP = retVal
Exit Function
err_ObradaGreske:
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura SynchAllRelationsForTable_OP se prekida. Brojac = " & brojac, vbCritical, "QMegaTeh"
        retVal = False
    Resume exit_PosleGreske

End Function
Public Function RenameLokalTable(stStaroIme As String, stNovoIme As String) As Boolean
On Error GoTo err_Func:

Dim retVal As Boolean
    retVal = True
    
  If PostojiTabelaUBazi(stStaroIme, CurrentDb) Then
     If Not PostojiTabelaUBazi(stNovoIme, CurrentDb) Then
      CurrentDb.TableDefs(stStaroIme).Name = stNovoIme
      retVal = True
     Else
      retVal = False
      BBMsgBox_BigBit "Veæ postoji tabela " & stNovoIme
     End If
  Else
     retVal = False
     BBMsgBox_BigBit "Ne postoji tabela " & stStaroIme
  End If
  
exit_Func:
  
  RenameLokalTable = retVal
  Exit Function

err_Func:
  BBErrorMSG err, "RenameTable(" & stStaroIme & ", " & stNovoIme & ")"
  retVal = False
  Resume exit_Func:
End Function
'********************************************************************
'12-08-18
'********************************************************************
Public Function Check2Tables(ImePrveBaze As String, ImeDrugeBaze As String, ImePrveTabele As String, ImeDrugeTabele, ByRef stRretVal As String) As Boolean

On Error GoTo err_ObradaGreske
    Dim PrvaBaza As DAO.Database
    Dim DrugaBaza As DAO.Database
    Dim TabelaPrveBaze As DAO.TableDef
    Dim TabelaDrugeBaze As DAO.TableDef
    Dim PoljePrveBaze As DAO.Field
    Dim PoljeDrugeBaze As DAO.Field
    Dim retVal As Boolean
    
    retVal = True
    Set PrvaBaza = DAO.OpenDatabase(ImePrveBaze)
    Set DrugaBaza = DAO.OpenDatabase(ImeDrugeBaze)
    
    Set TabelaPrveBaze = PrvaBaza.TableDefs(ImePrveTabele)
    
     ' If Not CBool(TabelaPrveBaze.Attributes And dbSystemObject) Then
        If Not PostojiTabelaUBazi(ImeDrugeTabele, DrugaBaza) Then
            stRretVal = stRretVal & vbCrLf & "Baza " & ImeDrugeBaze & " ne sadrži tabelu: " & ImeDrugeTabele
        Else
            Set TabelaDrugeBaze = DrugaBaza.TableDefs(ImeDrugeTabele)
            For Each PoljePrveBaze In TabelaPrveBaze.Fields
             If Not PostojiPoljeUTabeli(PoljePrveBaze.Name, TabelaDrugeBaze) Then
               stRretVal = stRretVal & vbCrLf & "Tabela " & TabelaDrugeBaze.Name & " nema polje " & PoljePrveBaze.Name
             End If
            Next PoljePrveBaze
            ''''''''''''''''''''''''''''''''''''''''''''''''''
        End If
     ' End If

    
exit_PosleGreske:
On Error Resume Next
    
    Set TabelaPrveBaze = Nothing
    Set TabelaDrugeBaze = Nothing
    PrvaBaza.Close
    Set PrvaBaza = Nothing
    
    DrugaBaza.Close
    Set DrugaBaza = Nothing
    Check2Tables = retVal
Exit Function
err_ObradaGreske:
    retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura Check2Tables se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Function

Private Function Synch2Tables_OP(ByRef DobraBaza As DAO.Database, ByRef NovaBaza As DAO.Database, ByRef DobraTabela As DAO.TableDef, ImeNoveTabele As String, ByRef stRretVal As String, CheckUskladiIndexe As Boolean, CheckUskladiRelacije As Boolean) As Boolean
On Error GoTo err_ObradaGreske
   
    Dim NovaTabela As DAO.TableDef
    Dim DobroPolje As DAO.Field
    Dim NovoPolje As DAO.Field
    Dim i As Integer
    Dim retVal As Boolean
    
    
    retVal = True
         
     If Not CBool(DobraTabela.Attributes And dbSystemObject) Then
        If Not PostojiTabelaUBazi(ImeNoveTabele, NovaBaza) Then
        
            Set NovaTabela = NovaBaza.CreateTableDef(ImeNoveTabele)
            For Each DobroPolje In DobraTabela.Fields
            
                Set NovoPolje = NovaTabela.CreateField(DobroPolje.Name, DobroPolje.Type, DobroPolje.Size)
                
                On Error Resume Next
                For i = 1 To DobroPolje.Properties.Count
                    NovoPolje.Properties(i).Value = DobroPolje.Properties(i).Value
                Next i
                On Error GoTo err_ObradaGreske
                NovaTabela.Fields.Append NovoPolje
                'UpdateNewFieldDefault NovaBaza, NovaTabela, NovoPolje
            Next DobroPolje
            NovaBaza.TableDefs.Append NovaTabela
            If CheckUskladiIndexe Then
             SynchIndexesInTable_OP DobraTabela, NovaTabela, stRretVal
            End If
        'End If
        Else
            ' ovde treba uskladiti polja
            ''''''''''''''''''''''''''''''''''''''''''''''''''
            Set NovaTabela = NovaBaza.TableDefs(ImeNoveTabele)
            For Each DobroPolje In DobraTabela.Fields
             If Not PostojiPoljeUTabeli(DobroPolje.Name, NovaTabela) Then
               'mora da se kreira novo polje za !
                Set NovoPolje = NovaTabela.CreateField(DobroPolje.Name, DobroPolje.Type, DobroPolje.Size)
       
                On Error Resume Next
                For i = 1 To DobroPolje.Properties.Count
                    NovoPolje.Properties(i).Value = DobroPolje.Properties(i).Value
                Next i
                On Error GoTo err_ObradaGreske
                NovaTabela.Fields.Append NovoPolje
                UpdateNewFieldDefault NovaBaza, NovaTabela, NovoPolje
             End If
            Next DobroPolje
            ''''''''''''''''''''''''''''''''''''''''''''''''''
         If CheckUskladiIndexe Then
             SynchIndexesInTable_OP DobraTabela, NovaTabela, stRretVal
            End If
        End If
     End If
    If CheckUskladiRelacije Then
     retVal = retVal And SynchAllRelations_OP(DobraBaza, NovaBaza, stRretVal)
    End If
exit_PosleGreske:
On Error Resume Next
    
    Set NovaTabela = Nothing
    Set DobroPolje = Nothing
    Set NovoPolje = Nothing
 
    Synch2Tables_OP = retVal
    
Exit Function
err_ObradaGreske:
        retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura Synch2Tables_OP se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Function
Public Function Synch2Tables(ImeDobreBaze As String, ImeNoveBaze As String, ImeDobreTabele As String, ImeNoveTabele As String, ByRef stRretVal As String, Optional CheckUskladiIndexe As Boolean = True, Optional CheckUskladiRelacije As Boolean = True) As Boolean
On Error GoTo err_ObradaGreske
    Dim DobraBaza As DAO.Database
    Dim NovaBaza As DAO.Database
    Dim DobraTabela As DAO.TableDef
    Dim retVal As Boolean
    
    
    retVal = True
    Set DobraBaza = DAO.OpenDatabase(ImeDobreBaze)
    Set NovaBaza = DAO.OpenDatabase(ImeNoveBaze)
    Set DobraTabela = DobraBaza.TableDefs(ImeDobreTabele)
    
    retVal = Synch2Tables_OP(DobraBaza, NovaBaza, DobraTabela, ImeNoveTabele, stRretVal, CheckUskladiIndexe, CheckUskladiRelacije)
    
exit_PosleGreske:
On Error Resume Next

    Set DobraTabela = Nothing
    DobraBaza.Close
    Set DobraBaza = Nothing
    
    NovaBaza.Close
    Set NovaBaza = Nothing
    Synch2Tables = retVal
Exit Function
err_ObradaGreske:
        retVal = False
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                    & err.Description & vbCrLf _
                    & "Procedura Synch2Tables se prekida.", vbCritical, "QMegaTeh"
    Resume exit_PosleGreske
    
End Function
Public Function ReadRelationInTable(ImeNoveBaze As String, ImeNoveTabele As String, ByRef stRretVal As String) As Boolean
'13-11-2018
On Error GoTo Err_Point

    Dim NovaBaza As DAO.Database
    Dim Relacija As DAO.Relation
    Dim txtMSG As String
    Dim i As Integer
    Dim retValOk As Boolean
    
    retValOk = True
    Set NovaBaza = DAO.OpenDatabase(ImeNoveBaze)
    
    For Each Relacija In NovaBaza.Relations
      If Relacija.Table = ImeNoveTabele Then
        txtMSG = "Relacija: "
        txtMSG = txtMSG & "Name: [" & Relacija.Name & "]" & "   Atributes:" & Relacija.Attributes & vbCrLf
        txtMSG = txtMSG & "========================================" & vbCrLf
        txtMSG = txtMSG & DoChRight("Table", 40, " ") & "ForeignTable" & vbCrLf
        txtMSG = txtMSG & DoChRight(Relacija.Table, 40, " ") & Relacija.ForeignTable & vbCrLf
        txtMSG = txtMSG & "========================================" & vbCrLf
        For i = 0 To Relacija.Fields.Count - 1
            txtMSG = txtMSG & i & ".    " & DoChRight(Relacija.Fields(i).Name, 40, " ") & Relacija.Fields(i).ForeignName & vbCrLf & vbCrLf
        Next i
        stRretVal = stRretVal & txtMSG & vbCrLf
      End If
     Next Relacija
Exit_Point:
   On Error Resume Next
    Set Relacija = Nothing
    NovaBaza.Close
    Set NovaBaza = Nothing
    txtMSG = "Završena provera." & vbCrLf
    ReadRelationInTable = retValOk
Exit Function
Err_Point:
  retValOk = False
  Resume Exit_Point
End Function

Public Function RunLocalQuery(QName As String, Optional ByRef recaff As Long) As Boolean
'*************************************************************
'Kreirano: 06.01.2019.
'Izvrsava upit u OVOJ bazi
'*************************************************************
On Error GoTo err_IzvrsiUpitUBazi

 Dim retVal As Boolean
 Dim dbUBazi As DAO.Database
 Dim SQLUpit As String
 
 retVal = True
 Set dbUBazi = CurrentDb
 SQLUpit = dbUBazi.QueryDefs(QName).sql
 
 If Not dbUBazi.Updatable Then
    MsgBox "CurrentDb nije UPDATABLE. Proces se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    GoTo exit_IzvrsiUpitUBazi
 End If
    dbUBazi.Execute SQLUpit
    If Not IsMissing(recaff) Then
     recaff = dbUBazi.RecordsAffected
     MsgBox "RecordsAffected = " & recaff, vbInformation, "QMegaTeh"
    End If
exit_IzvrsiUpitUBazi:
On Error Resume Next
 
 dbUBazi.Close
 Set dbUBazi = Nothing
 RunLocalQuery = retVal
 Exit Function
 
err_IzvrsiUpitUBazi:
    MsgBox "ErrNo: " & err.Number & vbCrLf _
            & err.Description & vbCrLf _
            & "Funkcija RunLocalQuery " & SQLUpit & " u bazi CurrentDB" _
            & " se prekida.", vbCritical, "QMegaTeh"
    retVal = False
    Resume exit_IzvrsiUpitUBazi
End Function

