Attribute VB_Name = "PDM_Common"
Option Compare Database
Option Explicit
Public PDMSklop As New PDM_Class

Public Function F_PDM_IDCrteza() As Long
   F_PDM_IDCrteza = Nz(PDMSklop.IDCrtez(), -1)
End Function
Public Function F_PDM_BrojCrteza() As String
   F_PDM_BrojCrteza = PDMSklop.BrojCrteza
End Function
Public Function F_PDM_Revizija() As String
   F_PDM_Revizija = PDMSklop.Revizija
End Function
Public Function F_PDM_TrebaIDCrtez() As Long
   F_PDM_TrebaIDCrtez = Nz(PDMSklop.TrebaIDCrtez(), -1)
End Function
Public Function F_PDM_ZaPodSklopTrebaIDCrtez() As Long
   F_PDM_ZaPodSklopTrebaIDCrtez = Nz(PDMSklop.ZaPodSklopTrebaIDCrtez(), -1)
End Function
Public Function F_PDM_ZaPodPodSklopTrebaIDCrtez() As Long
   F_PDM_ZaPodPodSklopTrebaIDCrtez = Nz(PDMSklop.ZaPodPodSklopTrebaIDCrtez(), -1)
End Function
Sub KreirajTabeluISpisakFajlova()
    Dim db As DAO.Database
    Dim tdf As DAO.TableDef
    Dim fld As DAO.Field
    Dim rs As DAO.Recordset
    Dim FolderPath As String
    Dim fName As String
    
    FolderPath = "C:\PDMExport\XML\" ' ‹ <<< OVDE UNESI PUTANJU

    ' Prvo obriši tabelu ako veæ postoji
    On Error Resume Next
    DoCmd.DeleteObject acTable, "ListaFajlova"
    On Error GoTo 0
    
    ' Kreiranje nove tabele
    Set db = CurrentDb
    Set tdf = db.CreateTableDef("ListaFajlova")
    
    ' Polje ID - Autonumber
    Set fld = tdf.CreateField("ID", dbLong)
    fld.Attributes = dbAutoIncrField
    tdf.Fields.Append fld
    
    ' Polje NazivFajla - tekst
    tdf.Fields.Append tdf.CreateField("NazivFajla", dbText, 255)
    
    db.TableDefs.Append tdf
    
    ' Otvori recordset za unos podataka
    Set rs = db.OpenRecordset("ListaFajlova", dbOpenDynaset)

    ' Uèitaj fajlove iz foldera
    If Right(FolderPath, 1) <> "\" Then FolderPath = FolderPath & "\"
    fName = Dir(FolderPath & "*.*")
    
    Do While fName <> ""
        rs.AddNew
        rs!NazivFajla = fName
        rs.Update
        fName = Dir
    Loop
    
    rs.Close
    Set rs = Nothing
    Set tdf = Nothing
    Set db = Nothing

    MsgBox "Završeno. Tabela 'ListaFajlova' je kreirana i popunjena."
End Sub
'***********************************************************************
Public Function UveziPDM_XMLFajl(ByVal stPathFile As String)
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim docID As String
    Dim Attr_Revision As String
    Dim IDCrtez As Long
    'Dim stPathFile As String
    Dim messageError As String
    Dim PDMSklopMessageError As String
    Dim bCritical As Boolean
    Dim staraRevizijaPostoji As Boolean
    
    bCritical = False
    
    ObrisiPodatkeTablicePDM_Document
    
    retValOk = ImportXMLWithReferences(stPathFile)
    
    If retValOk Then
        docID = DLookup("DocID", "PDM_Document", "Transaction = " & True)
        Attr_Revision = DLookup("Attr_Revision", "PDM_Document", "Transaction = " & True)
        
        ' Da li postoji ista revizija?
        IDCrtez = Nz(ADO_Lookup(CNN_CurrentDataBase, "[IDCrtez]", "[PDMCrtezi]", _
                    "[BrojCrteza] = '" & docID & "' AND Revizija = '" & Attr_Revision & "'"), 0)
        If IDCrtez <> 0 Then
            ' Isto: veæ imaš tu reviziju, preskoèi import
            UpisiXMLImportLog stPathFile, Now(), True, "Podaci iz XML fajl NISU importovani... crtež veæ postoji u bazi", bCritical
            PremestiXMLFile stPathFile, True
            Exit Function
        End If

        retValOk = ProveriXMLFajl(messageError, bCritical)
        If retValOk Then
            retValOk = UpisiPDMSklopoveUTabeluCrtezi(PDMSklopMessageError)
            If retValOk Then
                ' Provera: da li postoji neka STARA revizija istog BrojCrteza (revizija <> nova)
                staraRevizijaPostoji = (Nz(ADO_Lookup(CNN_CurrentDataBase, "[IDCrtez]", "[PDMCrtezi]", _
                    "[BrojCrteza] = '" & Replace(docID, "'", "''") & "' AND Revizija <> '" & Replace(Attr_Revision, "'", "''") & "'"), 0) <> 0)
                
                ''***MODIFIKOVANO 02-08-2025 START ***********
                '' Dohvati ID novog (upravo ubaèenog) crteža
                IDCrtez = Nz(ADO_Lookup(CNN_CurrentDataBase, "[IDCrtez]", "[PDMCrtezi]", _
                            "[BrojCrteza] = '" & Replace(docID, "'", "''") & "' AND Revizija = '" & Replace(Attr_Revision, "'", "''") & "'"), 0)
        
                '' Ako je postojala stara revizija, zameni reference na nju novom revizijom
                If staraRevizijaPostoji And IDCrtez <> 0 Then
                    ZameniIDCrtezaStareRevizijeUKomponentama docID, Attr_Revision, IDCrtez
                End If
                ''***MODIFIKOVANO 02-08-2025 KRAJ ***********
        
                retValOk = PopuniKomponentePDMCrteza(messageError)
                If retValOk Then
                    'PrikaziCrtezIReference F_PDM_IDCrteza()
                    PremestiXMLFile stPathFile, True
                    UpisiXMLImportLog stPathFile, Now(), True, "Podaci iz XML fajl su USPEŠNO IMPORTOVANI", bCritical
                Else
                    'MsgBox "Podaci iz XML fajl NISU importovani u tablicu KomponentePDMCrteža!", vbCritical
                    PremestiXMLFile stPathFile, False
                    UpisiXMLImportLog stPathFile, Now(), False, messageError, True
                End If
            Else
                'MsgBox "Podaci iz XML fajl NISU importovani u tablicu PDMCrteži!", vbCritical
                PremestiXMLFile stPathFile, False
                UpisiXMLImportLog stPathFile, Now(), False, "Podaci iz XML fajl NISU importovani  " & PDMSklopMessageError, True
                Exit Function
            End If
            
        Else
            'MsgBox "XML fajl NIJE validan!", vbCritical
            PremestiXMLFile stPathFile, False
            UpisiXMLImportLog stPathFile, Now(), False, messageError, bCritical
        End If
    Else
        ' XML fajl nije mogao da se parsira
        UpisiXMLImportLog stPathFile, Now(), False, "XML fajl NIJE DOBRO struktuiran", True
    End If

Exit_Point:
    On Error Resume Next
    UveziPDM_XMLFajl = retValOk
Exit Function

Err_Point:
    UpisiXMLImportLog stPathFile, Now(), False, "XML fajl NIJE IMPORTOVAN", True
    retValOk = False
    Resume Exit_Point
End Function
Public Function UpisiPDMSklopoveUTabeluCrtezi(ByRef stErrPoruka As String) As Boolean
On Error GoTo Err_Point
 
    Dim db As DAO.Database
    Dim TabDok As DAO.Recordset
    Dim NoviIDCrtez As Long
    Dim retValOk As Boolean
    Dim stSQL As String
    Dim stSQLWhere As String
    Dim chNavodnici As String
    Dim IDCrtez As Long

    Dim stPDMSQL As String
    Dim stRev As Variant
    Dim lNabavka As Integer
    
    Dim Attr_Name As String
    Dim Attr_Weight As Double
    Dim rawWeight As String
    Dim w As Double

    retValOk = True
    stPDMSQL = ""
    stPDMSQL = stPDMSQL & " SELECT PDM_Document.*"
    stPDMSQL = stPDMSQL & " FROM PDM_Document;"

    DoCmd.Hourglass True
   
    
       chNavodnici = Chr(39)
    
       'chNavodnici = Chr(34)
    
    
    'Set rstPDM_Document = ADO_GetRST(CNN_CurrentDataBase, stPDMSQL, dbOptimistic, adUseClient, adOpenKeyset, True)
    
    Dim rstPDM_Document As DAO.Recordset
    Set db = CurrentDb
    Set rstPDM_Document = db.OpenRecordset("PDM_Document", dbOpenDynaset)
    
    If rstPDM_Document Is Nothing Then
        'MsgBox "Ne postoji podatak u fajlu," & vbCrLf & "ili su svi sklopovi/delovi iz fajla veæ uèitani", vbInformation
        stErrPoruka = "Ne postoji podatak u fajlu, ili su svi sklopovi/delovi iz fajla veæ uèitani"
    Else
        rstPDM_Document.MoveFirst
        While Not rstPDM_Document.EOF
            
            stRev = rstPDM_Document!Attr_Revision
            
            If IsNull(stRev) Or Len(Trim$(stRev & "")) = 0 Then
                stRev = "A"
            End If
            
            If rstPDM_Document![Attr_Oznaka] Like "*[!0-9]*" Then
                lNabavka = 1
            Else
                lNabavka = 0
            End If
            
            rawWeight = Trim$(Nz(rstPDM_Document!Attr_Weight, ""))
            If rawWeight = "" Then
                ' Nema unete vrednosti — postavi na 0
                Attr_Weight = 0
            ElseIf Not IsNumeric(rawWeight) Then
                ' Nije broj (npr. sadrži slova ili više taèaka) — oznaèi grešku
                Attr_Weight = -1
            Else
                ' Validan broj ili decimalni (npr. "2.43" ili "100")
                ' Konvertuj ga u Double (ili Long ako ti treba integer)
                w = CDbl(rawWeight)
                Attr_Weight = w
            End If

            Attr_Name = Nz(rstPDM_Document![Attr_Name], "NEMA PODATAK")
            
            stSQLWhere = ""
            stSQLWhere = stSQLWhere & "([BrojCrteza]='" & rstPDM_Document!docID & "')"
            'stSQLWhere = stSQLWhere & " AND ([Revizija]='" & rstPDM_Document!Attr_Revision & "')"
            stSQLWhere = stSQLWhere & " AND ([Revizija]='" & stRev & "')"
            
            IDCrtez = Nz(ADO_Lookup(CNN_CurrentDataBase, "[IDCrtez]", "SELECT IDCrtez FROM PDMCrtezi WHERE " & stSQLWhere), -1)
            
            If IDCrtez = -1 Then  ' NOVI SLOG
                stSQL = ""
                stSQL = stSQL & "    INSERT INTO PDMCrtezi" & vbCrLf
                stSQL = stSQL & "            (" & vbCrLf
                'stSQL = stSQL & "              IDCrtez" & vbCrLf
                stSQL = stSQL & "              pdmWeID" & vbCrLf
                'stSQL = stSQL & "            , Transaction" & vbCrLf
                stSQL = stSQL & "            , TransactionDate" & vbCrLf
                stSQL = stSQL & "            , DesignDate" & vbCrLf
                stSQL = stSQL & "            , DesignBy" & vbCrLf
                stSQL = stSQL & "            , ApprovedDate" & vbCrLf
                stSQL = stSQL & "            , ApprovedBy" & vbCrLf
                stSQL = stSQL & "            , BrojCrteza" & vbCrLf
                stSQL = stSQL & "            , Revizija" & vbCrLf
                stSQL = stSQL & "            , Kolicina" & vbCrLf
                stSQL = stSQL & "            , KataloskiBroj" & vbCrLf
                stSQL = stSQL & "            , Naziv" & vbCrLf
                
                stSQL = stSQL & "            , Materijal" & vbCrLf
                stSQL = stSQL & "            , RN" & vbCrLf
                stSQL = stSQL & "            , Dimenzije" & vbCrLf
                stSQL = stSQL & "            , Oznaka" & vbCrLf
                stSQL = stSQL & "            , Tezina" & vbCrLf
                stSQL = stSQL & "            , [Naziv fajla]" & vbCrLf
                stSQL = stSQL & "            , PDMStatusCrteza" & vbCrLf
                stSQL = stSQL & "            , Comment" & vbCrLf
                stSQL = stSQL & "            , WhereUsed" & vbCrLf
                stSQL = stSQL & "            , Naziv_projekta" & vbCrLf
                stSQL = stSQL & "            , DIVUnosa" & vbCrLf
                stSQL = stSQL & "            , Potpis" & vbCrLf
                stSQL = stSQL & "            , IDStatusCrteza" & vbCrLf
                stSQL = stSQL & "            , Nabavka" & vbCrLf   ' <-- novo polje
                stSQL = stSQL & "            )" & vbCrLf
                'Replace(stJSonPoslat, chNavodnici, chNavodnici & chNavodnici)
                stSQL = stSQL & "   VALUES" & vbCrLf
                stSQL = stSQL & "            (" & vbCrLf
                stSQL = stSQL & "             " & chNavodnici & rstPDM_Document!DocPDMWeID & chNavodnici & vbCrLf
                stSQL = stSQL & "            , " & SQLFormatPDMDatuma(rstPDM_Document![TransactionDate]) & vbCrLf
                stSQL = stSQL & "            , " & SQLFormatPDMDatuma(rstPDM_Document![Attr_DesignDate]) & vbCrLf
                stSQL = stSQL & "            , " & chNavodnici & rstPDM_Document![Attr_DesignBy] & chNavodnici & vbCrLf
                stSQL = stSQL & "            , " & SQLFormatPDMDatuma(rstPDM_Document![Attr_ApprovedDate]) & vbCrLf
                stSQL = stSQL & "            , " & chNavodnici & rstPDM_Document![Attr_Approved_by] & chNavodnici & vbCrLf
                stSQL = stSQL & "            , " & chNavodnici & rstPDM_Document![docID] & chNavodnici & vbCrLf
                'stSQL = stSQL & "            , " & chNavodnici & Nz(rstPDM_Document![Attr_Revision], "A") & chNavodnici & vbCrLf
                stSQL = stSQL & "            , " & chNavodnici & stRev & chNavodnici & vbCrLf
                stSQL = stSQL & "            , " & CInt(rstPDM_Document![Attr_Reference_Count]) & vbCrLf
                stSQL = stSQL & "            , " & chNavodnici & rstPDM_Document![Attr_Bb_Kataloski_broj] & chNavodnici & vbCrLf
                stSQL = stSQL & "            , " & chNavodnici & rstPDM_Document![Attr_Naziv] & chNavodnici & vbCrLf
                stSQL = stSQL & "            , " & chNavodnici & rstPDM_Document![Attr_Materijal] & chNavodnici & vbCrLf
                stSQL = stSQL & "            , " & chNavodnici & rstPDM_Document![Attr_RN] & chNavodnici & vbCrLf
                stSQL = stSQL & "            , " & chNavodnici & rstPDM_Document![Attr_Dimenzije] & chNavodnici & vbCrLf
                stSQL = stSQL & "            , " & chNavodnici & rstPDM_Document![Attr_Oznaka] & chNavodnici & vbCrLf
                'stSQL = stSQL & "            , " & chNavodnici & rstPDM_Document![Attr_Weight] & chNavodnici & vbCrLf
                'stSQL = stSQL & "            , " & IIf(Len(rstPDM_Document![Attr_Weight]) <> 0, rstPDM_Document![Attr_Weight], 0) & vbCrLf
                stSQL = stSQL & "            , " & Attr_Weight & vbCrLf
                stSQL = stSQL & "            , " & chNavodnici & rstPDM_Document![Attr_Name] & chNavodnici & vbCrLf
                stSQL = stSQL & "            , " & chNavodnici & rstPDM_Document![Attr_State] & chNavodnici & vbCrLf
                stSQL = stSQL & "            , " & chNavodnici & rstPDM_Document![Attr_Comment] & chNavodnici & vbCrLf
                stSQL = stSQL & "            , " & chNavodnici & rstPDM_Document![Attr_WhereUsed] & chNavodnici & vbCrLf
                stSQL = stSQL & "            , " & chNavodnici & rstPDM_Document![Attr_Naziv_projekta] & chNavodnici & vbCrLf
                stSQL = stSQL & "            , " & SQLFormatDatumIVreme(Now()) & vbCrLf
                stSQL = stSQL & "            , " & chNavodnici & CurrentUser() & chNavodnici & vbCrLf
                stSQL = stSQL & "            , " & 0 & vbCrLf
                stSQL = stSQL & "            , " & lNabavka & vbCrLf ' <-- vrednost za Nabavka
                stSQL = stSQL & "            )" & vbCrLf
                
                'SetClipboard stSQL
                
                retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)
                
                If retValOk Then
                    IDCrtez = ADO_IDENTITY 'ADO_Lookup(CNN_CurrentDataBase, "SELECT @@IDENTITY")
                End If
                'If rstPDM_Document![transaction] = True Then ' Kolona "transaction" u PDM_Document oznaæava da li je taj slog vodeæi slog xml fajla
                '    PDMSklop.IDCrtez = IDCrtez
                'End If
                If lNabavka = 1 Then
                    DodajDeoNabavkeUTablicuArtikli rstPDM_Document![Attr_Oznaka], rstPDM_Document![Attr_Name], "Materijal"
                End If
            Else
                '1. UPDATE
            End If
            
            rstPDM_Document.MoveNext
        Wend
    End If

Exit_Point:
On Error Resume Next
    rstPDM_Document.Close
    Set rstPDM_Document = Nothing
    db.Close
    Set db = Nothing
    
    UpisiPDMSklopoveUTabeluCrtezi = retValOk
    DoCmd.Hourglass False

Exit Function

Err_Point:
    'Debug.Print stSQL
    'MsgBox Err & " - UpisiPDMSklopoveUTabeluCrtezi"
    stErrPoruka = "Nije mogao da se insertuje fajl " & Attr_Name
    retValOk = False
    Resume Exit_Point

End Function
                
Public Function PopuniKomponentePDMCrteza(ByRef stPoruka As String) As Boolean
    On Error GoTo Err_Handler

    Dim db As DAO.Database
    Dim rs As DAO.Recordset
    Dim sql As String
    Dim pZaIDCrtez As Variant
    Dim pTrebaIDCrtez As Variant
    Dim BrojGresaka As Long
    Dim retValOk As Boolean
    Dim glavnaRevision As String
    Dim referencaRevision As String
    Dim referencaDocID As String

    retValOk = True
    Set db = CurrentDb

    sql = "SELECT h.DocID AS Glavni_DocID, h.Attr_Revision AS Glavni_Revision, " & _
          "r.DocID AS Referenca_DocID, r.Attr_Revision AS Referenca_Revision, " & _
          "r.Attr_Reference_Count " & _
          "FROM PDM_Document AS h " & _
          "LEFT JOIN PDM_Document AS r ON h.DocID = r.ParentDocID " & _
          "WHERE ((Not (r.DocID) Is Null)) " & _
          "ORDER BY h.DocID, r.DocID"

    Set rs = db.OpenRecordset(sql, dbOpenSnapshot)

    Do While Not rs.EOF
        ' --- pripremi vrednosti
        glavnaRevision = Nz(rs!Glavni_Revision, "")
        referencaRevision = Nz(rs!Referenca_Revision, "")
        referencaDocID = Nz(rs!Referenca_DocID, "")

        ' --- Naði ID glavnog crteža (parent)
        pZaIDCrtez = ADO_Lookup(CNN_CurrentDataBase, "IDCrtez", "PDMCrtezi", _
                      "BrojCrteza = '" & Replace(rs!Glavni_DocID, "'", "''") & _
                      "' AND Revizija = '" & Replace(glavnaRevision, "'", "''") & "'")

        ' --- Naði ID reference (child)
        pTrebaIDCrtez = ADO_Lookup(CNN_CurrentDataBase, "IDCrtez", "PDMCrtezi", _
                      "BrojCrteza = '" & Replace(referencaDocID, "'", "''") & _
                      "' AND Revizija = '" & Replace(referencaRevision, "'", "''") & "'")

        ' --- Ako su oba ID uspešno pronaðena
        If Not IsNull(pZaIDCrtez) And Not IsNull(pTrebaIDCrtez) Then
            ' 1. Ako je došla nova revizija podsklopa, zameni stare u roditeljskim vezama
            Call ZameniIDCrtezaStareRevizijeUKomponentama(referencaDocID, referencaRevision, pTrebaIDCrtez)

            ' 2. Ubaci (ili upsert) vezu parent › child iz XML-a
            Call DodajSlogKomponentePDMCrteza(pZaIDCrtez, pTrebaIDCrtez, Nz(rs!Attr_Reference_Count, 1))
        Else
            BrojGresaka = BrojGresaka + 1
        End If

        rs.MoveNext
    Loop

    If BrojGresaka > 0 Then
        stPoruka = "Popunjavanje završeno, ali ima " & BrojGresaka & " reda-ova koje nije bilo moguæe upariti. Proverite šta je importovano."
        retValOk = False
    Else
        stPoruka = "Popunjavanje komponenti PDMCrteza je uspešno završeno."
    End If

Exit_Function:
    On Error Resume Next
    If Not rs Is Nothing Then rs.Close: Set rs = Nothing
    Set db = Nothing

    PopuniKomponentePDMCrteza = retValOk
    Exit Function

Err_Handler:
    stPoruka = "Podaci iz XML fajl NISU importovani u tablicu KomponentePDMCrteža"
    retValOk = False
    Resume Exit_Function
End Function

Public Function DodajSlogKomponentePDMCrteza(ByVal ZaIDCrtez As Long, ByVal TrebaIDCrtez As Long, ByVal PotrebnoKomada As Integer) As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stWhere As String
Dim stSQL As String
Dim IDKomponenteCrteza As Long
 retValOk = True
 stWhere = "[ZaIDCrtez] = " & ZaIDCrtez & " AND [TrebaIDCrtez] = " & TrebaIDCrtez
 IDKomponenteCrteza = Nz(ADO_Lookup(CNN_CurrentDataBase, "[IDKomponenteCrteza]", "[KomponentePDMCrteza]", stWhere), 0)
 If IDKomponenteCrteza = 0 Then
    'INSERT
    stSQL = ""
    stSQL = stSQL & " INSERT INTO [dbo].[KomponentePDMCrteza]"
    stSQL = stSQL & "        ([ZaIDCrtez]"
    stSQL = stSQL & "        ,[TrebaIDCrtez]"
    stSQL = stSQL & "        ,[PotrebnoKomada])"
    stSQL = stSQL & "  Values"
    stSQL = stSQL & "        ('" & CStr(ZaIDCrtez) & "'"
    stSQL = stSQL & "        ,'" & CStr(TrebaIDCrtez) & "'"
    stSQL = stSQL & "        ,'" & CStr(PotrebnoKomada) & "')"
    
    retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)
End If

Exit_Point:
 On Error Resume Next
    DodajSlogKomponentePDMCrteza = retValOk
Exit Function

Err_Point:
 'BBErrorMSG err, "DodajSlogKomponentePDMCrteza"
 retValOk = False
 Resume Exit_Point

End Function

Public Function PremestiXMLFile(ByVal sFullPath As String, ByVal bSuccess As Boolean) As Boolean
    On Error GoTo Err_Point
    Dim retValOk As Boolean: retValOk = True
    
    Dim fso As Object
    Dim sDestFolder As String
    Dim sFileName As String
    Dim destPath As String
    Dim timeStamp As String
    
    ' Odredi mape
    sDestFolder = IIf(bSuccess, F_PDM_XMLFolderImportovano, F_PDM_XMLFolderNeuspelo)
    If Right(sDestFolder, 1) <> "\" Then sDestFolder = sDestFolder & "\"
    
    Set fso = CreateObject("Scripting.FileSystemObject")
    sFileName = fso.GetFileName(sFullPath)
    destPath = sDestFolder & sFileName
    
    ' Ako fajl s istim imenom veæ postoji, dodaj timestamp u naziv
    If fso.FileExists(destPath) Then
        timeStamp = "_" & Format(Now(), "yyyyMMdd_HHmmss")
        destPath = sDestFolder & _
                   fso.GetBaseName(sFileName) & _
                   timeStamp & "." & _
                   fso.GetExtensionName(sFileName)
    End If
    
    ' Kreiraj mapu ako ne postoji
    If Not fso.FolderExists(sDestFolder) Then
        fso.CreateFolder sDestFolder
    End If
    
    ' Preseli fajl (original æe se obrisati)
    fso.MoveFile sFullPath, destPath
    
    PremestiXMLFile = True
    Exit Function

Err_Point:
    UpisiXMLImportLog sFullPath, Now(), False, "Greška pri premeštanju XML fajla: " & err.Description, False
    PremestiXMLFile = False
    Resume Next
End Function


Public Function UpisiXMLImportLog(ByVal PutanjaFajla As String, ByVal ImportTimestamp As Date, _
                                    ByVal Uspesno As Boolean, ByVal StatusPoruka As String, ByVal Kriticno As Boolean) As Boolean
   ' On Error GoTo ErrHandler
    On Error GoTo Err_Point
    
    Dim retValOk As Boolean
    Dim fso As Object
    Dim NazivFajla As String
    Dim stSQL As String
    Dim sSuccess As String
    Dim sMsg As String
    Dim sKriticno As String
    
    retValOk = True
    
    Set fso = CreateObject("Scripting.FileSystemObject")
    NazivFajla = fso.GetFileName(PutanjaFajla)
    
    ' Pripremi vrednost kolone Uspesno (bit)
    sSuccess = IIf(Uspesno, "1", "0")
    ' Pripremi vrednost kolone Kriticno (bit)
    sKriticno = IIf(Kriticno, "1", "0")
    ' Pripremi vrednost kolone StatusPoruka (NULL ili tekst)
    If Len(Trim$(StatusPoruka)) = 0 Then
        sMsg = "NULL"
    Else
        sMsg = "'" & Replace(StatusPoruka, "'", "''") & "'"
    End If
    
    ' Sastavi INSERT INTO ... VALUES (...)
    ' FORMAT za SQL Server DATETIME: 'YYYY-MM-DD HH:NN:SS'
    stSQL = "INSERT INTO PDMXMLImportLog " & _
           "(NazivFajla, PutanjaFajla, ImportTimestamp, Uspesno, StatusPoruka, Kriticno) " & _
           "VALUES (" & _
             "'" & Replace(NazivFajla, "'", "''") & "', " & _
             "'" & Replace(PutanjaFajla, "'", "''") & "', " & _
             "'" & Format(ImportTimestamp, "yyyy\-mm\-dd HH:nn:ss") & "', " & _
             sSuccess & ", " & _
             sMsg & ", " & _
             sKriticno & _
           ");"
    
    ' Izvrši INSERT
    'conn.Execute sSQL
    retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)

'ErrHandler:
    ' U sluèaju greške vrati False
'    LogImportXMP = False
Exit_Point:
 On Error Resume Next
       UpisiXMLImportLog = retValOk
Exit Function

Err_Point:
 retValOk = False
 Resume Exit_Point
End Function


Public Function ObrisiPodatkeTablicePDM_Document() As Boolean
    Dim db As DAO.Database
    Dim retValOk As Boolean
    Set db = CurrentDb
    On Error GoTo Err_Point
     
    retValOk = True
    ' briše sve zapise iz PDM_Document
    db.Execute "DELETE * FROM PDM_Document;", dbFailOnError

Exit_Point:
    On Error Resume Next
    Set db = Nothing
    ObrisiPodatkeTablicePDM_Document = retValOk
Exit Function

Err_Point:
    MsgBox "Greška prilikom brisanja: " & err.Number & " – " & err.Description, vbExclamation
    retValOk = False
    Resume Exit_Point
End Function

Public Function FieldExistsInTable(ByVal tdf As DAO.TableDef, ByVal stFieldName As String) As Boolean
    On Error GoTo ErrHandler
    Dim fld As DAO.Field
    Set fld = tdf.Fields(stFieldName)
    FieldExistsInTable = True
    Exit Function
ErrHandler:
    FieldExistsInTable = False
End Function
Public Function ProveriXMLFajl(ByRef stPoruka As String, ByRef bKriticno As Boolean) As Boolean
    On Error GoTo Err_Handler

    Dim db As DAO.Database
    Dim rs As DAO.Recordset
    Dim tdf As DAO.TableDef
    Dim sql As String
    Dim totalRowCount As Long
    Dim FieldName As Variant
    Dim mandatoryFields As Collection
    Dim conditionList As Collection
    Dim lengthFields As Collection
    Dim fieldType As Integer
    Dim invalidFields As String
    Dim isValid As Boolean
    Dim countInvalid As Long
    Dim condition As Variant
    
    Dim rsRevs As DAO.Recordset
    Dim docID As String
    Dim rev As String
    Dim prevRev As String
    Dim prevExists As Variant
    Dim skipRevError As Boolean
    Dim sqlRevs As String
    
    skipRevError = False
    
    Set db = CurrentDb
    Set tdf = db.TableDefs("PDM_Document")

    ' --- definicija obaveznih polja
    Set mandatoryFields = New Collection
    mandatoryFields.Add "DocID"
    mandatoryFields.Add "Attr_Oznaka"
    mandatoryFields.Add "Attr_Reference_Count"

    ' ---  uslovi (prihvatamo "odobreno" i "Izmena bez revizije")
    Set conditionList = New Collection
    conditionList.Add "Nz(Trim([Attr_State]), '') In ('odobreno','Izmena bez revizije')"
    
    invalidFields = ""
    isValid = True

    ' --- ukupno slogova
    Set rs = db.OpenRecordset("SELECT COUNT(*) AS TotalCount FROM PDM_Document", dbOpenSnapshot)
    totalRowCount = rs!TotalCount
    rs.Close: Set rs = Nothing
    
    ' --- provera svakog polja ponaosob da nije prazno/null
    For Each FieldName In mandatoryFields
        If FieldExistsInTable(tdf, CStr(FieldName)) Then
            fieldType = tdf.Fields(FieldName).Type
            Select Case fieldType
                Case dbText, dbMemo
                    sql = "SELECT COUNT(*) AS Broj FROM PDM_Document WHERE Nz(Trim([" & FieldName & "]), '') = ''"
                Case dbInteger, dbLong, dbDouble, dbCurrency, dbSingle, dbByte, dbDate
                    sql = "SELECT COUNT(*) AS Broj FROM PDM_Document WHERE [" & FieldName & "] IS NULL"
                Case Else
                    GoTo SkipField ' preskoèi nepoznate tipove
            End Select

            Set rs = db.OpenRecordset(sql, dbOpenSnapshot)
            countInvalid = rs!BROJ
            rs.Close: Set rs = Nothing

            If countInvalid > 0 Then
                invalidFields = invalidFields & "Prvi uslov: polje [" & FieldName & "] nema vrednost u " & countInvalid & " slogova. "
                isValid = False
            End If
        End If
SkipField:
    Next
    
    ' ' --- dodatni uslovi
    For Each condition In conditionList
        sql = "SELECT COUNT(*) AS Broj FROM PDM_Document WHERE NOT (" & condition & ")"
        Set rs = db.OpenRecordset(sql, dbOpenSnapshot)
        countInvalid = rs!BROJ
        rs.Close: Set rs = Nothing

        If countInvalid > 0 Then
            invalidFields = invalidFields & _
                " Drugi uslov: [" & condition & "] nije ispunjen u › " & countInvalid & " slogova. "
            isValid = False
        End If
    Next

    ' --- PROVERA MAKSIMALNE DUZINE (20 znakova) za DocID i Attr_Oznaka
    Set lengthFields = New Collection
    lengthFields.Add "DocID"
    lengthFields.Add "Attr_Oznaka"

    For Each FieldName In lengthFields
        If FieldExistsInTable(tdf, CStr(FieldName)) Then
            sql = "SELECT COUNT(*) AS Broj FROM PDM_Document " & _
                  "WHERE LEN(Nz(Trim([" & FieldName & "]), '')) > 20"
            Set rs = db.OpenRecordset(sql, dbOpenSnapshot)
            countInvalid = rs!BROJ
            rs.Close: Set rs = Nothing

            If countInvalid > 0 Then
                invalidFields = invalidFields & _
                    " Treæi uslov - Polje [" & FieldName & "] prelazi 20 znakova u " & countInvalid & " slogova. "
                isValid = False
            End If
        End If
    Next

    ' --- PROVERA DUPLIKATA za kombinaciju Attr_Oznaka, Attr_Revision i ParentDocID
    If FieldExistsInTable(tdf, "Attr_Oznaka") And FieldExistsInTable(tdf, "Attr_Revision") And FieldExistsInTable(tdf, "ParentDocID") Then
        sql = _
            "SELECT [Attr_Oznaka] & '-' & [Attr_Revision] & '-' & [ParentDocID] AS Komponenta, COUNT(*) AS Cnt " & _
            "FROM PDM_Document " & _
            "GROUP BY [Attr_Oznaka], [Attr_Revision], [ParentDocID] " & _
            "HAVING COUNT(*) > 1"
        Set rs = db.OpenRecordset(sql, dbOpenSnapshot)
        Do While Not rs.EOF
            invalidFields = invalidFields & _
                " Èetvrti uslov nije ispunjen - postoje duplirane komponente : " & rs!Komponenta & vbCrLf
            isValid = False
            rs.MoveNext
        Loop
        rs.Close: Set rs = Nothing
    End If
    
    '' --- PROVERA PRESKOÈENE REVIZIJE (npr. došla C, ali B ne postoji u bazi)
    'sqlRevs = "SELECT DISTINCT DocID, Attr_Revision FROM PDM_Document"
    'Set rsRevs = db.OpenRecordset(sqlRevs, dbOpenSnapshot)
    'Do While Not rsRevs.EOF And Not skipRevError
    '    docID = Nz(rsRevs!docID, "")
    '    rev = Trim(Nz(rsRevs!Attr_Revision, ""))  ' koristimo originalno ime, ali rukujemo Null u VBA
    '    If rev <> "" Then
    '        Dim prevCheck As String
    '        prevCheck = ""
    '        If Len(rev) = 1 Then
    '            rev = UCase$(rev)
    '            If rev <> "A" Then
    '                prevCheck = Chr$(Asc(rev) - 1) ' prethodna slova: B -> A, C -> B
    '            End If
    '        ElseIf IsNumeric(rev) Then
    '            ' ako je broj, uzmi prethodni ceo broj
    '            prevCheck = CStr(CLng(rev) - 1)
    '        End If
   '
    '        If prevCheck <> "" Then
    '            ' proveri da li ta prethodna revizija postoji u glavnoj bazi
    '            prevExists = ADO_Lookup(CNN_CurrentDataBase, "IDCrtez", "PDMCrtezi", _
    '                "[BrojCrteza] = '" & Replace(docID, "'", "''") & "' AND Revizija = '" & Replace(prevCheck, "'", "''") & "'")
    '            If Nz(prevExists, 0) = 0 Then
    '                invalidFields = "Preskoèena revizija: za crtež " & docID & " došla revizija '" & rev & "', a prethodna '" & prevCheck & "' ne postoji u bazi. " '& invalidFields
    '                isValid = False
    '                skipRevError = True
    '                ' možeš odmah izaæi ako hoæeš da ne gomilaš druge greške, ali ovde nastavljamo da prikupimo sve
    '            End If
    '        End If
    '    End If
    '    rsRevs.MoveNext
    'Loop
    'If Not rsRevs Is Nothing Then
    '    rsRevs.Close: Set rsRevs = Nothing
    'End If
    
    ' --- prikaži detalje ako nešto nije validno
    If Not isValid Then
        stPoruka = invalidFields
        bKriticno = True
    End If

    ProveriXMLFajl = isValid

Exit_Function:
    On Error Resume Next
    Set tdf = Nothing
    Set db = Nothing
    Exit Function

Err_Handler:
    stPoruka = "Greška u funkciji ProveriXMLFajl: " & err.Description
    ProveriXMLFajl = False
    Resume Exit_Function
End Function

Private Sub ZameniIDCrtezaStareRevizijeUKomponentama(ByVal BrojCrteza As String, ByVal NewRevizija As String, ByVal NoviIDCrtez As Long)
    On Error GoTo ErrHandler
    
    Dim rsOld As ADODB.Recordset
    Dim rsParent As ADODB.Recordset
    Dim rsConflict As ADODB.Recordset
    Dim sqlStareRevizije As String
    Dim sqlParent As String
    Dim sqlConflict As String
    Dim stariIDCrtez As Long
    Dim ZaIDCrtez As Long
    Dim stWhere As String
    Dim IDKomponenteCrteza As Long
    
    ' 1. Uzmi sve stare revizije istog BrojCrteza koje nisu nova revizija
    sqlStareRevizije = "SELECT IDCrtez FROM PDMCrtezi WHERE BrojCrteza = '" & Replace(BrojCrteza, "'", "''") & "' AND Revizija <> '" & Replace(NewRevizija, "'", "''") & "'"
    Set rsOld = ADO_GetRST(CNN_CurrentDataBase, sqlStareRevizije)
    
    Do While Not rsOld.EOF
        stariIDCrtez = Nz(rsOld!IDCrtez, 0)
        If stariIDCrtez > 0 Then
        ' 2. Za svaki parent koji koristi staru reviziju kao komponentu
            sqlParent = "SELECT * FROM KomponentePDMCrteza WHERE TrebaIDCrtez = " & stariIDCrtez
            Set rsParent = ADO_GetRST(CNN_CurrentDataBase, sqlParent)
            
            Do While Not rsParent.EOF
                ZaIDCrtez = Nz(rsParent!ZaIDCrtez, 0)
                IDKomponenteCrteza = rsParent!IDKomponenteCrteza
                
                ' 3. Provera: da li taj parent veæ ima novu reviziju kao komponentu
                stWhere = "[ZaIDCrtez] = " & ZaIDCrtez & " AND [TrebaIDCrtez] = " & NoviIDCrtez
                sqlConflict = "SELECT * FROM KomponentePDMCrteza WHERE " & stWhere
                Set rsConflict = ADO_GetRST(CNN_CurrentDataBase, sqlConflict)
                
                'If Not rsConflict.EOF Then
                '    'Šta ovde radim
                'Else
                '    Call ADO_UpdateColumn(CNN_CurrentDataBase, "KomponentePDMCrteza", "TrebaIDCrtez", NoviIDCrtez, "IDKomponenteCrteza = " & IDKomponenteCrteza)
                'End If

                'Set rsConflict = Nothing
                If Not rsConflict.EOF Then
                    ' Veæ postoji veza parent › nova revizija: obriši staru vezu
                    Call ADO_ExecSQL(CNN_CurrentDataBase, "DELETE FROM KomponentePDMCrteza WHERE IDKomponenteCrteza = " & IDKomponenteCrteza)
                Else
                    ' Ne postoji nova veza: zameni staru reviziju sa novom (samo update TrebaIDCrtez)
                    Call ADO_UpdateColumn(CNN_CurrentDataBase, "KomponentePDMCrteza", "TrebaIDCrtez", NoviIDCrtez, "IDKomponenteCrteza = " & IDKomponenteCrteza)
                End If

                If Not rsConflict Is Nothing Then
                    rsConflict.Close
                    Set rsConflict = Nothing
                End If
                
                rsParent.MoveNext
            Loop

            rsParent.Close
            Set rsParent = Nothing
        End If

        rsOld.MoveNext
    Loop

    rsOld.Close
    Set rsOld = Nothing

Exit_Sub:
    On Error Resume Next
    If Not rsConflict Is Nothing Then rsConflict.Close
    If Not rsParent Is Nothing Then rsParent.Close
    If Not rsOld Is Nothing Then rsOld.Close
    Exit Sub

ErrHandler:
    Debug.Print " ZameniIDCrtezaStareRevizijeUKomponentama ERROR " & err.Number & ": " & err.Description
    Debug.Print "  sqlParent: " & sqlParent
    Debug.Print "  sqlConflict: " & sqlConflict
    Resume Exit_Sub
End Sub


'***********************************************************************


Public Function F_PDM_XMLFolder() As String
     'F_PDM_XMLFolder = Nz(ReadParametar("CFG_Global", "PDM_XMLFolder"), "C:\PDMExport\XML\")
     F_PDM_XMLFolder = Nz(ReadCFGParametar("PDM_XMLFolder", "C:\PDMExport\XML\"), "C:\PDMExport\XML\")
End Function
Public Function F_PDM_XMLFolderImportovano() As String
     'F_PDM_XMLFolder = Nz(ReadParametar("CFG_Global", "PDM_XMLFolderImportovano"), "C:\PDMExport\XML\Importovano\")
     F_PDM_XMLFolderImportovano = Nz(ReadCFGParametar("PDM_XMLFolderImportovano", "C:\PDMExport\Importovano\"), "C:\PDMExport\Importovano\")
End Function
Public Function F_PDM_XMLFolderNeuspelo() As String
     'F_PDM_XMLFolder = Nz(ReadParametar("CFG_Global", "PDM_XMLFolderNeuspelo"), "C:\PDMExport\XML\Neuspelo\")
     F_PDM_XMLFolderNeuspelo = Nz(ReadCFGParametar("PDM_XMLFolderNeuspelo", "C:\PDMExport\Neuspelo\"), "C:\PDMExport\Neuspelo\")
End Function

Public Function UradiPrimopredajuGlavnogCrteza(ByRef NoviIDRN As Long, ByVal ZaIDCrteza As Long, ByVal ZaIDPredmeta As Long, Optional BrojKomada As Long) As Boolean
On Error GoTo Err_DugmePrepisiStavkeIzNaloga_Click

    Dim stSQL As String
    Dim stSQLWhere As String
    Dim retValOk As Boolean
    Dim IDRN As Long
    Dim chNavodnici As String
    Dim rst As ADODB.Recordset
    
    stSQL = ""
    
    If BBCFG.SQLDB Then
        chNavodnici = Chr(39)
    Else
        chNavodnici = Chr(34)
    End If
    
    stSQL = stSQL & " SELECT PDMCrtezi.*"
    stSQL = stSQL & " FROM PDMCrtezi"
    stSQL = stSQL & " WHERE (((PDMCrtezi.IDCrtez)=" & ZaIDCrteza & "));"
    
    


    Set rst = ADO_GetRST(CNN_CurrentDataBase, stSQL)
    
    stSQL = ""
            stSQL = stSQL & "    INSERT INTO tRN" & vbCrLf
            stSQL = stSQL & "            (" & vbCrLf
            stSQL = stSQL & "              IDPredmet" & vbCrLf
            stSQL = stSQL & "            , IdentBroj" & vbCrLf
            stSQL = stSQL & "            , Varijanta" & vbCrLf
            stSQL = stSQL & "            , BBIDKomitent" & vbCrLf
            stSQL = stSQL & "            , BBNazivPredmeta" & vbCrLf
            stSQL = stSQL & "            , BBDatumOtvaranja" & vbCrLf
            stSQL = stSQL & "            , DatumUnosa" & vbCrLf
            stSQL = stSQL & "            , Komada" & vbCrLf
            stSQL = stSQL & "            , BrojCrteza" & vbCrLf
            stSQL = stSQL & "            , Proizvod" & vbCrLf
            
            stSQL = stSQL & "            , TezinaNeobrDela" & vbCrLf
            stSQL = stSQL & "            , NazivDela" & vbCrLf
            stSQL = stSQL & "            , IdentMaterijala" & vbCrLf
            stSQL = stSQL & "            , Materijal" & vbCrLf
            stSQL = stSQL & "            , DimenzijaMaterijala" & vbCrLf
            stSQL = stSQL & "            , JM" & vbCrLf
            stSQL = stSQL & "            , TezinaObrDela" & vbCrLf
            stSQL = stSQL & "            , Napomena" & vbCrLf
            stSQL = stSQL & "            , StatusRN" & vbCrLf
            stSQL = stSQL & "            , RokIzrade" & vbCrLf
            
            stSQL = stSQL & "            , DIVUnosaRN" & vbCrLf
            stSQL = stSQL & "            , DIVIspravkeRN" & vbCrLf
            stSQL = stSQL & "            , SifraRadnika" & vbCrLf
            stSQL = stSQL & "            , Zakljucano" & vbCrLf
            stSQL = stSQL & "            , Potpis" & vbCrLf
            stSQL = stSQL & "            , PrnTimer" & vbCrLf
            stSQL = stSQL & "            , VezaSaBrojemCrteza" & vbCrLf
            stSQL = stSQL & "            , IDVrstaKvaliteta" & vbCrLf
            stSQL = stSQL & "            , Revizija" & vbCrLf
            stSQL = stSQL & "            , IDStatusPrimopredaje" & vbCrLf
            
            stSQL = stSQL & "            )" & vbCrLf
            stSQL = stSQL & "   VALUES" & vbCrLf
            stSQL = stSQL & "            (" & vbCrLf
            stSQL = stSQL & "            " & stR(rst![IDPredmet]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![IdentBroj], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            'stSQL = stSQL & "            ," & chNavodnici & Replace(ADO_GetValFromUDFS(CNN_CurrentDataBase, "fsSledeciBrojRadnogNaloga", BrojPredmeta, 1), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![Varijanta] + 1) & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![BBIDKomitent]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![BBNazivPredmeta], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatuma(rst![BBDatumOtvaranja], False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatuma(rst![DatumUnosa], False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![Komada]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![BrojCrteza], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![Proizvod], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            
            stSQL = stSQL & "            ," & stR(rst![TezinaObrDela]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![NazivDela], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![IdentMaterijala]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![Materijal], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![DimenzijaMaterijala], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![JM], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![TezinaObrDela]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![Napomena], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & SQLFormatBoolean(rst![StatusRN]) & vbCrLf
            
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatuma(rst![RokIzrade], False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatumIVreme(Now(), False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatumIVreme(Now(), False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![SifraRadnika]) & vbCrLf
            stSQL = stSQL & "            ," & SQLFormatBoolean(False) & vbCrLf
            
            stSQL = stSQL & "            ," & chNavodnici & Replace(CurrentUser(), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(0) & vbCrLf
            
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![VezaSaBrojemCrteza], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(0) & vbCrLf
            stSQL = stSQL & "            ," & "UBACI REVIZIJU" & vbCrLf
            stSQL = stSQL & "            ," & "UBACI IDSTATUS" & vbCrLf
            stSQL = stSQL & "            )" & vbCrLf
            
            'SetClipboard stSQL
            
            retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)
            
            NoviIDRN = ADO_IDENTITY 'ADO_Lookup(CNN_CurrentDataBase, "SELECT @@IDENTITY")

    
Exit_DugmePrepisiStavkeIzNaloga_Click:
    DoCmd.SetWarnings False
    DoCmd.Close acForm, "UradiPrimopredajuGlavnogCrteza", acSaveYes
    Exit Function
    
Err_DugmePrepisiStavkeIzNaloga_Click:
    MsgBox err.Description
    Resume Exit_DugmePrepisiStavkeIzNaloga_Click
    
End Function

Public Function UradiPrimopredajuKomponentiGlavnogCrteza(ByRef NoviIDRN As Long, ByVal ZaIDCrteza As Long, ByVal ZaIDPredmeta As Long, Optional BrojKomada As Long) As Boolean
On Error GoTo Err_DugmePrepisiStavkeIzNaloga_Click

    Dim stSQL As String
    Dim stSQLWhere As String
    Dim retValOk As Boolean
    Dim IDRN As Long
    Dim chNavodnici As String
    Dim rst As ADODB.Recordset
    
    stSQL = ""
    
    If BBCFG.SQLDB Then
        chNavodnici = Chr(39)
    Else
        chNavodnici = Chr(34)
    End If
    
    stSQL = stSQL & " SELECT PDMCrtezi.*"
    stSQL = stSQL & " FROM PDMCrtezi"
    stSQL = stSQL & " WHERE (((PDMCrtezi.IDCrtez)=" & ZaIDCrteza & "));"
    
    


    Set rst = ADO_GetRST(CNN_CurrentDataBase, stSQL)
    
    stSQL = ""
            stSQL = stSQL & "    INSERT INTO tRN" & vbCrLf
            stSQL = stSQL & "            (" & vbCrLf
            stSQL = stSQL & "              IDPredmet" & vbCrLf
            stSQL = stSQL & "            , IdentBroj" & vbCrLf
            stSQL = stSQL & "            , Varijanta" & vbCrLf
            stSQL = stSQL & "            , BBIDKomitent" & vbCrLf
            stSQL = stSQL & "            , BBNazivPredmeta" & vbCrLf
            stSQL = stSQL & "            , BBDatumOtvaranja" & vbCrLf
            stSQL = stSQL & "            , DatumUnosa" & vbCrLf
            stSQL = stSQL & "            , Komada" & vbCrLf
            stSQL = stSQL & "            , BrojCrteza" & vbCrLf
            stSQL = stSQL & "            , Proizvod" & vbCrLf
            
            stSQL = stSQL & "            , TezinaNeobrDela" & vbCrLf
            stSQL = stSQL & "            , NazivDela" & vbCrLf
            stSQL = stSQL & "            , IdentMaterijala" & vbCrLf
            stSQL = stSQL & "            , Materijal" & vbCrLf
            stSQL = stSQL & "            , DimenzijaMaterijala" & vbCrLf
            stSQL = stSQL & "            , JM" & vbCrLf
            stSQL = stSQL & "            , TezinaObrDela" & vbCrLf
            stSQL = stSQL & "            , Napomena" & vbCrLf
            stSQL = stSQL & "            , StatusRN" & vbCrLf
            stSQL = stSQL & "            , RokIzrade" & vbCrLf
            
            stSQL = stSQL & "            , DIVUnosaRN" & vbCrLf
            stSQL = stSQL & "            , DIVIspravkeRN" & vbCrLf
            stSQL = stSQL & "            , SifraRadnika" & vbCrLf
            stSQL = stSQL & "            , Zakljucano" & vbCrLf
            stSQL = stSQL & "            , Potpis" & vbCrLf
            stSQL = stSQL & "            , PrnTimer" & vbCrLf
            stSQL = stSQL & "            , VezaSaBrojemCrteza" & vbCrLf
            stSQL = stSQL & "            , IDVrstaKvaliteta" & vbCrLf
            stSQL = stSQL & "            , Revizija" & vbCrLf
            stSQL = stSQL & "            , IDStatusPrimopredaje" & vbCrLf
            
            stSQL = stSQL & "            )" & vbCrLf
            stSQL = stSQL & "   VALUES" & vbCrLf
            stSQL = stSQL & "            (" & vbCrLf
            stSQL = stSQL & "            " & stR(rst![IDPredmet]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![IdentBroj], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            'stSQL = stSQL & "            ," & chNavodnici & Replace(ADO_GetValFromUDFS(CNN_CurrentDataBase, "fsSledeciBrojRadnogNaloga", BrojPredmeta, 1), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![Varijanta] + 1) & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![BBIDKomitent]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![BBNazivPredmeta], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatuma(rst![BBDatumOtvaranja], False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatuma(rst![DatumUnosa], False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![Komada]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![BrojCrteza], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![Proizvod], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            
            stSQL = stSQL & "            ," & stR(rst![TezinaObrDela]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![NazivDela], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![IdentMaterijala]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![Materijal], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![DimenzijaMaterijala], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![JM], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![TezinaObrDela]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![Napomena], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & SQLFormatBoolean(rst![StatusRN]) & vbCrLf
            
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatuma(rst![RokIzrade], False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatumIVreme(Now(), False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatumIVreme(Now(), False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![SifraRadnika]) & vbCrLf
            stSQL = stSQL & "            ," & SQLFormatBoolean(False) & vbCrLf
            
            stSQL = stSQL & "            ," & chNavodnici & Replace(CurrentUser(), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(0) & vbCrLf
            
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![VezaSaBrojemCrteza], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(0) & vbCrLf
            stSQL = stSQL & "            ," & "UBACI REVIZIJU" & vbCrLf
            stSQL = stSQL & "            ," & "UBACI IDSTATUS" & vbCrLf
            stSQL = stSQL & "            )" & vbCrLf
            
            'SetClipboard stSQL
            
            retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)
            
            NoviIDRN = ADO_IDENTITY 'ADO_Lookup(CNN_CurrentDataBase, "SELECT @@IDENTITY")

    
Exit_DugmePrepisiStavkeIzNaloga_Click:
    DoCmd.SetWarnings False
    DoCmd.Close acForm, "UradiPrimopredajuKomponentiGlavnogCrteza", acSaveYes
    Exit Function
    
Err_DugmePrepisiStavkeIzNaloga_Click:
    MsgBox err.Description
    Resume Exit_DugmePrepisiStavkeIzNaloga_Click
    
End Function




Public Function DetaljnoCrtez(IDCrtez) As String
  On Error GoTo Err_DugmeDetaljnoCrtez

    Dim stDocName As String
    Dim stLinkCriteria As String
    Dim UF As Boolean
    Dim Blagajna As Boolean
    Dim stavkazatrazenje, IDNal As Long
    Dim LevelDok
    Dim fkctrl As control
        
    'DoCmd.Echo False, "Sacekajte..."
    If IDCrtez > 0 Then
       stDocName = PrikaziCrtez(IDCrtez)
    Else
        MsgBox "Ova stavka nema detaljno crtež!", vbInformation, "BigBit"
    End If
Exit_DugmeDetaljnoCrtez:
    On Error Resume Next
    'DoCmd.Echo True
    DetaljnoCrtez = stDocName
Exit Function

Err_DugmeDetaljnoCrtez:
    MsgBox err.Description
    Resume Exit_DugmeDetaljnoCrtez
    
End Function
Public Function PrikaziCrtez(IDCrtez) As String
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim stLinkCriteria As String
    Dim stDocName As String
    Dim IDCrtezZaPrikaz As Long
    Dim stOpenArgs As String
    Dim CheckNabavka As Boolean
    
    retValOk = False
    
    If Not IsNumeric(IDCrtez) Then
      retValOk = False
      GoTo Exit_Point
    End If
    
    If IDCrtez <= 0 Then
      retValOk = False
      GoTo Exit_Point
    End If
    
    '******************************************
    IDCrtezZaPrikaz = CLng(IDCrtez) '!!!!!!
    '******************************************
    stLinkCriteria = "[IDCrtez] = " & IDCrtezZaPrikaz
       
    'CheckNabavka = Nz(DLookup("[Level]", "T_Robna dokumenta", "[IDCrtez] = " & IDCrtezZaPrikaz), 0)
    CheckNabavka = Nz(ADO_Lookup(CNN_CurrentDataBase, "[Nabavka]", "PDMCrtezi", stLinkCriteria), 0)
    If CheckNabavka = True Then
     'stDocName = "Profaktura"
     stDocName = "PDMSklop"
     stOpenArgs = "Nabavka"
    Else
     'stDocName = "Izlazna faktura"
     stDocName = "PDMSklop"
    End If
    If IsLoaded(stDocName) Then
      DoCmd.Close acForm, stDocName, acSavePrompt
      Set PDMSklop = Nothing
    End If
    stLinkCriteria = "[IDCrtez]=" & IDCrtezZaPrikaz
    'PDMSklop.IDCrtez = IDCrtezZaPrikaz '!!!!!!!!!!!!
    PDMSklop.Caller = "DetaljnoCrtez"
    BBOpenForm stDocName, , , stLinkCriteria, , , stOpenArgs
    retValOk = IsLoaded(stDocName)
    If retValOk Then
      Forms!PDMSklop.PrikaziCrtezIReference IDCrtezZaPrikaz
    End If

    
Exit_Point:
 On Error Resume Next
 'PrikaziCrtez = retValOk
    PrikaziCrtez = stDocName
Exit Function

Err_Point:
 BBErrorMSG err, "PrikaziCrtez"
 retValOk = False
 Resume Exit_Point
End Function


Public Function DodajDeoNabavkeUTablicuArtikli(ByVal stKataloskiBroj As String, ByVal stNaziv As String, ByVal stGrupa As String) As Boolean
On Error GoTo Err_Point
 
    Dim stSQL As String
    Dim stSQLWhere As String
    Dim chNavodnici As String
    Dim SifraArtikla As Long

    Dim retValOk As Boolean
    
    retValOk = True

    DoCmd.Hourglass True
    chNavodnici = Chr(39)
    
    stSQLWhere = ""
    stSQLWhere = stSQLWhere & "([Kataloski broj]='" & stKataloskiBroj & "')"
    
    'SifraArtikla = Nz(ADO_Lookup(CNN_CurrentDataBase, "[Sifra artikla]", "SELECT [Sifra artikla] FROM EXT_R_Artikli WHERE " & stSQLWhere), -1)
    SifraArtikla = Nz(DLookup("[Sifra artikla]", "EXT_R_Artikli", stSQLWhere), -1)
    
    If SifraArtikla = -1 Then  ' NOVI SLOG
        stSQL = ""
        stSQL = stSQL & "    INSERT INTO R_Artikli" & vbCrLf
        stSQL = stSQL & "            (" & vbCrLf
        stSQL = stSQL & "              [Kataloski broj]" & vbCrLf
        'stSQL = stSQL & "            , BarKod" & vbCrLf
        stSQL = stSQL & "            , Naziv" & vbCrLf
        'stSQL = stSQL & "            , Poreklo" & vbCrLf
        stSQL = stSQL & "            , Grupa" & vbCrLf
        'stSQL = stSQL & "            , Podgrupa" & vbCrLf
        'stSQL = stSQL & "            , BrojCrteza" & vbCrLf
        'stSQL = stSQL & "            , Revizija" & vbCrLf
        'stSQL = stSQL & "            , Kolicina" & vbCrLf
        'stSQL = stSQL & "            , KataloskiBroj" & vbCrLf
        'stSQL = stSQL & "            , Naziv" & vbCrLf
        stSQL = stSQL & "            )" & vbCrLf
        
        stSQL = stSQL & "   VALUES" & vbCrLf
        stSQL = stSQL & "            (" & vbCrLf
        stSQL = stSQL & "             " & chNavodnici & stKataloskiBroj & chNavodnici & vbCrLf
        stSQL = stSQL & "            , " & chNavodnici & stNaziv & chNavodnici & vbCrLf
        stSQL = stSQL & "            , " & chNavodnici & stGrupa & chNavodnici & vbCrLf
        stSQL = stSQL & "            )" & vbCrLf
        
        'SetClipboard stSQL
        
        'retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)
        CurrentDb.Execute stSQL, dbFailOnError
        
        'If retValOk Then
        '    SifraArtikla = ADO_IDENTITY 'ADO_Lookup(CNN_CurrentDataBase, "SELECT @@IDENTITY")
        'End If
        
    Else
        '1. UPDATE
    End If
    
   
Exit_Point:
On Error Resume Next
    
    DodajDeoNabavkeUTablicuArtikli = retValOk
    DoCmd.Hourglass False

Exit Function

Err_Point:

    MsgBox err & " - Nije mogao da se insertuje artikal " & stKataloskiBroj
    retValOk = False
    Resume Exit_Point

End Function

Public Sub PregledGdeSeCrtezKoristi(ByVal ZaIDCrtez As Long, _
                                            ByVal BrojCrteza As String, _
                                            ByVal Revizija As String, _
                                            ByVal Naziv As String)

    DoCmd.OpenForm "GdeSeCrtezKoristi"

    With Forms!GdeSeCrtezKoristi

        .ZaIDCrtez = ZaIDCrtez
        .BrojCrteza = BrojCrteza
        .Revizija = Revizija
        .Naziv = Naziv

        .Podforma.SourceObject = "PregledSklopovaGdeSeCrtezKoristi"

        'OVO JE KLJUÈ
        '.PushStack ZaIDCrtez, BrojCrteza, Revizija, BrojKomada, Naziv
        '.OsveziCaption
        
        .PreviewTree (ZaIDCrtez)

    End With

End Sub

'Public Function NapuniTmpPDMKataloske(ByVal IDCrtez As Long) As Boolean
Public Function NapuniTmpPDMKataloske(ByVal IDCrtez As Long, Optional ByVal TopLevelOnly As Boolean = False) As Boolean
On Error GoTo Err_Handler
    ' Za brojCrteza=1127465 i call NapuniTmpPDMKataloske(6377)
    Dim rsADO As ADODB.Recordset
    Dim rsDAO As DAO.Recordset
    Dim db As DAO.Database

    Dim KatBroj As String
    Dim SifraArt As Variant

    NapuniTmpPDMKataloske = False

    Dim OK As Boolean
    Dim stSQL As String
              
    'Ok = PripremiTMPTabeluUTMPBazi("tmp_B_ZaliheArtPoMagIProd", "B_ZaliheArtPoMagIProd", , True, , "IDObjekat", "IDArtikal")
    'stSQL = "SELECT *"
    'stSQL = stSQL & " FROM ftBOMNabavniDelovi("
    'stSQL = stSQL & stR(IDCrtez)
    'stSQL = stSQL & ")"
    stSQL = "SELECT *"
    stSQL = stSQL & " FROM ftBOMNabavniDelovi("
    stSQL = stSQL & stR(IDCrtez) & ","
    stSQL = stSQL & IIf(TopLevelOnly, "1", "0")
    stSQL = stSQL & ")"

    OK = PassTroughQuerySave("ODBC_ftBOMNabavniDelovi", stSQL, CNN_CurrentDataBase)
    OK = PripremiTMPTabeluUTMPBazi("tmp_PDM_KataloskiBrojevi", "ODBC_ftBOMNabavniDelovi", , True, , "KataloskiBroj", "IDCrtez")

    ' 3) Otvori TMP tabelu za upis
    Set db = CurrentDb
    Set rsDAO = db.OpenRecordset("tmp_PDM_KataloskiBrojevi", dbOpenDynaset)
    If Not rsDAO.EOF Then rsDAO.MoveFirst
    ' 4) Prebaci podatke
    Do While Not rsDAO.EOF

        KatBroj = Nz(rsDAO!KataloskiBroj, "")

        If Len(KatBroj) > 0 Then

            ' mapiranje na robnu evidenciju
            SifraArt = DLookup( _
                "[Sifra artikla]", _
                "EXT_R_Artikli", _
                "[Kataloski broj] = '" & Replace(KatBroj, "'", "''") & "'" _
            )

            rsDAO.Edit

            If Not IsNull(SifraArt) Then
                rsDAO!SifraArtikla = CLng(SifraArt)
            Else
                rsDAO!SifraArtikla = Null
            End If

            rsDAO.Update
        End If

        rsDAO.MoveNext
    Loop

    NapuniTmpPDMKataloske = True

Exit_Point:
    On Error Resume Next
    rsDAO.Close
    Set rsDAO = Nothing
    Set db = Nothing
    Exit Function

Err_Handler:
    BBErrorMSG err, "NapuniTmpPDMKataloske"
    Resume Exit_Point
End Function

Public Sub PregledPotrebnihGotovihDelovaZaCrtez(ByVal ZaIDCrtez As Long, _
                                            ByVal BrojCrteza As String, _
                                            ByVal Revizija As String, _
                                            ByVal BrojKomada As Long, _
                                            ByVal Naziv As String)

    DoCmd.OpenForm "PotrebniGotoviDeloviZaCrtez"

    With Forms!PotrebniGotoviDeloviZaCrtez

        .ZaIDCrtez = ZaIDCrtez
        .BrojCrteza = BrojCrteza
        .Revizija = Revizija
        .BrojKomadaZaIzradu = BrojKomada
        .Naziv = Naziv

        .Podforma.SourceObject = "PregledGotovihDelovaZaCrtez"

        'OVO JE KLJUÈ
        '.PushStack ZaIDCrtez, BrojCrteza, Revizija, BrojKomada, Naziv
        '.OsveziCaption
        
        .PreviewTree (ZaIDCrtez)
        .Podforma2.SourceObject = "PotrebneTopLevelKomponenteZaCrtez"
        
    End With

End Sub

Public Sub PregledPotrebnihKomponentiZaCrtez(ByVal ZaIDCrtez As Long, _
                                            ByVal BrojCrteza As String, _
                                            ByVal Revizija As String, _
                                            ByVal BrojKomada As Long, _
                                            ByVal Naziv As String)

    DoCmd.OpenForm "PotrebneKomponenteZaCrtez"

    With Forms!PotrebneKomponenteZaCrtez

        .ZaIDCrtez = ZaIDCrtez
        .BrojCrteza = BrojCrteza
        .Revizija = Revizija
        .BrojKomadaZaIzradu = BrojKomada
        .Naziv = Naziv

        .Podforma.SourceObject = "PregledPotrebnihKomponentiZaCrtez"

        'OVO JE KLJUÈ
        '.PushStack ZaIDCrtez, BrojCrteza, Revizija, BrojKomada, Naziv
        '.OsveziCaption
        
        .PreviewTree (ZaIDCrtez)

    End With

End Sub
