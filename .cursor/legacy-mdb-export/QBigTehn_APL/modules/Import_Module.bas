Attribute VB_Name = "Import_Module"
Option Compare Database
Option Explicit
Public Function ArtikliICeneZaImport_MapKol(stKolName As String) As String
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stRetVal As String
retValOk = True


stRetVal = "[" & stKolName & "]"

Exit_Point:
 On Error Resume Next
       ArtikliICeneZaImport_MapKol = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "ArtikliICeneZaImport_MapKol"
 retValOk = False
 Resume Exit_Point

End Function
Public Function ArtikliICeneZaImport_PripremiTabeluIzFajla(stImeFajlaZaImport As String, QBBCenovnikZaImport As String) As Boolean
' Print ArtikliICeneZaImport_PripremiTabelu("C:\SHARES\AcBaze\QBigBit\Kasa\QBBCenovnikZaImport.xls").RecordCount
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stFileExt As String
Dim stSQL As String

If PostojiTabelaUBazi(QBBCenovnikZaImport, CurrentDb) Then
   CurrentDb.Execute "DROP TABLE " & QBBCenovnikZaImport & ";", dbFailOnError
End If
    
    retValOk = True
    stFileExt = ExtFromPath(stImeFajlaZaImport)
    
    If (stFileExt = "xls") Or (stFileExt = "xlsx") Or (stFileExt = "xlsb") Then
        'DoCmd.TransferSpreadsheet acLink, acSpreadsheetTypeExcel12Xml, stImeTabele, stImeFajlaZaImport, True
        DoCmd.TransferSpreadsheet acImport, acSpreadsheetTypeExcel12Xml, QBBCenovnikZaImport, stImeFajlaZaImport, True
      ElseIf stFileExt Like "*csv" Then
        'DoCmd.TransferText acLinkDelim, "QBBCenovnikZaImport_Link_Specification_CSV", "QBBCenovnikZaImport", stImeFajlaZaImport
        DoCmd.TransferText acImportDelim, "QBBCenovnikZaImport_Link_Specification_CSV", "QBBCenovnikZaImport", QBBCenovnikZaImport
        
    Else
        KasaErrMsg "Nepoznat format!"
        retValOk = False
    End If
    
    If PostojiTabelaUBazi(QBBCenovnikZaImport, CurrentDb) Then
        'if not PostojiKolonaUTabeli
        CurrentDb.Execute "ALTER TABLE " & QBBCenovnikZaImport & " ADD IDArtikal LONG ;", dbFailOnError
        On Error Resume Next
        If CurrentDb.TableDefs(QBBCenovnikZaImport).Fields("Cena") <> "Cena" Then
           CurrentDb.Execute "ALTER TABLE " & QBBCenovnikZaImport & " ADD Cena Currency;", dbFailOnError
        End If
        On Error GoTo Err_Point
        
        stSQL = ""
        stSQL = stSQL & " UPDATE " & QBBCenovnikZaImport & " "
        stSQL = stSQL & " INNER JOIN R_Artikli ON " & QBBCenovnikZaImport & ".[Kataloski broj] = R_Artikli.[Kataloski broj]"
        stSQL = stSQL & " SET " & QBBCenovnikZaImport & ".IDArtikal = [R_Artikli].[Sifra artikla];"
        CurrentDb.Execute stSQL, dbFailOnError + dbSeeChanges
    
    End If
    
Exit_Point:
 On Error Resume Next
         ArtikliICeneZaImport_PripremiTabeluIzFajla = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "ArtikliICeneZaImport"
 retValOk = False
 Resume Exit_Point
End Function

Public Function fsSifraArtiklaZaKatBarNaz(KatBroj As Variant, BarKod As Variant, Naziv As Variant) As Variant
'? fsSifraArtiklaZaKatBarNaz("SE02252B","8605015079919","DRZAC SAPUNA PLAVI")
    '@KatBroj nvarchar(20),
    '@BarKod nvarchar(32),
    '@Naziv nvarchar(255)
    
On Error GoTo Err_Point
Dim pCMD As New ADODB.Command

Dim i As Integer
Dim spBrojParametara As Integer
Dim InBrojParametara As Integer
Dim stPoruka As String
Dim retValOk As Boolean
Dim retValVar As Variant

DoCmd.Hourglass True
pCMD.ActiveConnection = CNN_CurrentDataBase
pCMD.CommandType = adCmdStoredProc
pCMD.CommandText = "fsSifraArtiklaZaKatBarNaz"

pCMD.Parameters.Refresh 'posle ove komande svi parametri su definisani!
 'cmd.Parameters(0) = @RETURN_VALUE
pCMD.Parameters("@KatBroj").Value = KatBroj
pCMD.Parameters("@BarKod").Value = BarKod
pCMD.Parameters("@Naziv").Value = Naziv

DoCmd.Hourglass False

pCMD.CommandTimeout = 30 '30 sec
pCMD.Execute

'CmdRetVal = pCmd.Parameters("@RETURN_VALUE")
'CmdRetVal = (pCMD.Parameters(0) = 0)
retValOk = (pCMD.ActiveConnection.Errors.Count = 0)
If retValOk Then
   retValVar = pCMD.Parameters("@RETURN_VALUE").Value
Else
    retValVar = Null
End If

pCMD.ActiveConnection.Close 'ako se zatvori konekcija gubi se recordset
Exit_Point:
On Error Resume Next

Set pCMD = Nothing
DoCmd.Hourglass False
fsSifraArtiklaZaKatBarNaz = retValVar

Exit Function

Err_Point:
    'MsgBox Error$
    BBErrorMSG err, "fsSifraArtiklaZaKatBarNaz"
    retValOk = False
    Resume Exit_Point
End Function
Public Function ImportArtikliICene(stCenVrstaDok As String, _
                                    stImeTabeleZaImport As String, _
                                    Optional ByRef BrojInsertArtikli As Long, _
                                    Optional ByRef BrojLosInsertArtikli As Long, _
                                    Optional ByRef BrojInsertCenovnik As Long, _
                                    Optional ByRef BrojLosInsertCenovnik As Long, _
                                    Optional ByRef BrojUpdateCenovnik As Long, _
                                    Optional ByRef BrojLosUpdateCenovnik As Long _
                                    ) As Boolean

                                    
On Error GoTo Err_Point
 Dim retValOk As Boolean
 'Dim stImeFajlaZaImport As String
 Dim rstNoviArtICene As DAO.Recordset
 
 Dim stSQL As String
 Dim IDArtikal As Variant
 Dim stErrMsg As String
 Dim PostojiArtikalUCenovniku As Boolean
 Dim PrikazujPorukeOGreskama As Boolean
 
 retValOk = True
 PrikazujPorukeOGreskama = True
 
 'stImeFajlaZaImport = "C:\SHARES\AcBaze\QBigBit\Kasa\QBBCenovnikZaImport.xls"
 'stImeFajlaZaImport = OpenFile(stImeFajlaZaImport)
 'Set rstNoviArtICene = ArtikliICeneZaImport(stImeFajlaZaImport)
 
 Set rstNoviArtICene = CurrentDb.OpenRecordset(stImeTabeleZaImport, dbOpenSnapshot)
 
 If rstNoviArtICene.EOF And rstNoviArtICene.BOF Then 'nema podataka
    KasaErrMsg "Nema podataka."
    GoTo Exit_Point
 End If
 
 'If PostojiKolona
 
 rstNoviArtICene.MoveFirst
 
 BrojInsertArtikli = 0
 BrojLosInsertArtikli = 0
 BrojInsertCenovnik = 0
 BrojLosInsertCenovnik = 0
 BrojUpdateCenovnik = 0
 BrojLosUpdateCenovnik = 0

 While Not rstNoviArtICene.EOF
      
    IDArtikal = fsSifraArtiklaZaKatBarNaz(rstNoviArtICene!KatBroj, rstNoviArtICene!BarKod, rstNoviArtICene!Naziv)
    If Nz(IDArtikal, -1) = -1 Then
       
       '1. Grupa:
        If Left(Trim(CStr(Nz(rstNoviArtICene!Grupa, "0"))), 10) <> "0" Then
            If Nz(ADO_Lookup(CNN_CurrentDataBase, "Grupa", "R_Grupa", "Grupa='" & CStr(Nz(rstNoviArtICene!Grupa, "0")) & "'"), "null") <> Left(Trim(CStr(Nz(rstNoviArtICene!Grupa, "0"))), 10) Then
                stSQL = ""
                stSQL = stSQL & "INSERT INTO [dbo].[R_Grupa]"
                stSQL = stSQL & "    ("
                stSQL = stSQL & "     [Grupa]"
                stSQL = stSQL & ",    [Opis] )"
                stSQL = stSQL & " VALUES ("
                stSQL = stSQL & "     '" & Left(Trim(CStr(Nz(rstNoviArtICene!Grupa, "0"))), 10) & "'"
                stSQL = stSQL & ",    '" & Left(Trim(CStr(Nz(rstNoviArtICene!Grupa, "0"))), 50) & "')"
                Call ADO_ExecSQL(CNN_CurrentDataBase, stSQL, False)
            End If
        End If
        
        '2. Podgrupa:
        If Left(Trim(CStr(Nz(rstNoviArtICene!Podgrupa, "0"))), 10) <> "0" Then
            If Nz(ADO_Lookup(CNN_CurrentDataBase, "Podgrupa", "R_Podgrupa", "Podgrupa='" & CStr(Nz(rstNoviArtICene!Podgrupa, "0")) & "'"), "null") <> Left(Trim(CStr(Nz(rstNoviArtICene!Podgrupa, "0"))), 10) Then
                stSQL = ""
                stSQL = stSQL & "INSERT INTO [dbo].[R_Podgrupa]"
                stSQL = stSQL & "    ("
                stSQL = stSQL & "     [Podgrupa]"
                stSQL = stSQL & ",    [Opis] )"
                stSQL = stSQL & " VALUES ("
                stSQL = stSQL & "     '" & Left(Trim(CStr(Nz(rstNoviArtICene!Podgrupa, "0"))), 10) & "'"
                stSQL = stSQL & ",    '" & Left(Trim(CStr(Nz(rstNoviArtICene!Podgrupa, "0"))), 50) & "')"
                Call ADO_ExecSQL(CNN_CurrentDataBase, stSQL, False)
            End If
        End If
        
        '3. Poreklo:
        If Left(Trim(CStr(Nz(rstNoviArtICene!Poreklo, "0"))), 10) <> "0" Then
            If Nz(ADO_Lookup(CNN_CurrentDataBase, "Poreklo", "R_Poreklo", "Poreklo='" & CStr(Nz(rstNoviArtICene!Poreklo, "0")) & "'"), "null") <> Left(Trim(CStr(Nz(rstNoviArtICene!Poreklo, "0"))), 10) Then
                stSQL = ""
                stSQL = stSQL & "INSERT INTO [dbo].[R_Poreklo]"
                stSQL = stSQL & "    ("
                stSQL = stSQL & "     [Poreklo]"
                stSQL = stSQL & ",    [Opis] )"
                stSQL = stSQL & " VALUES ("
                stSQL = stSQL & "     '" & Left(Trim(CStr(Nz(rstNoviArtICene!Poreklo, "0"))), 10) & "'"
                stSQL = stSQL & ",    '" & Left(Trim(CStr(Nz(rstNoviArtICene!Poreklo, "0"))), 50) & "')"
                Call ADO_ExecSQL(CNN_CurrentDataBase, stSQL, False)
            End If
        End If
       
       'Debug.Print "Dodajem ", rstNoviArtICene!KatBroj, rstNoviArtICene!BarKod, rstNoviArtICene!Naziv
       
       stSQL = ""
       stSQL = stSQL & "INSERT INTO [dbo].[R_Artikli]"
       stSQL = stSQL & "    ("
       stSQL = stSQL & "     [Kataloski broj]"
       stSQL = stSQL & "    ,[BarKod]"
       stSQL = stSQL & "    ,[PLU]"
       stSQL = stSQL & "    ,[Naziv]"
       stSQL = stSQL & "    ,[Jedinica mere]"
       stSQL = stSQL & "    ,[Poreklo]"
       stSQL = stSQL & "    ,[Grupa]"
       stSQL = stSQL & "    ,[Podgrupa]"
       stSQL = stSQL & "    ,[Tarifa robe]"
       stSQL = stSQL & "    ,[Uvek porez na robu]"
       stSQL = stSQL & "    ,[MP cena]"
       stSQL = stSQL & "    )"
       stSQL = stSQL & " VALUES ("
       'stSQL = stSQL & "     " & IIf(IsNull(rstNoviArtICene!KatBroj), "'Null'", "'" & rstNoviArtICene!KatBroj & "'") ' --[Kataloski broj]"
       stSQL = stSQL & "     '" & Nz(rstNoviArtICene!KatBroj, "Null") & "'" ' --[Kataloski broj]"
       stSQL = stSQL & "    ," & IIf(IsNull(rstNoviArtICene!BarKod), "Null", "'" & rstNoviArtICene!BarKod & "'")   '--[BarKod]"
       stSQL = stSQL & "    ," & stR(SledeciPLU)
       stSQL = stSQL & "    ,'" & Nz(rstNoviArtICene!Naziv, "Null") & "'" ' --[Naziv]"
       stSQL = stSQL & "    ,'" & Nz(rstNoviArtICene!JM, "Null") & "'" '--[Jedinica mere]"
       
       stSQL = stSQL & "    ,'" & Left(Nz(rstNoviArtICene!Poreklo, "0"), 10) & "'" '--[Poreklo]"
       stSQL = stSQL & "    ,'" & Left(Nz(rstNoviArtICene!Grupa, "0"), 10) & "'" '--[Grupa]"
       stSQL = stSQL & "    ,'" & Left(Nz(rstNoviArtICene!Podgrupa, "0"), 10) & "'" '--[Podgrupa]"
       
       stSQL = stSQL & "    ,'" & Nz(PDVTarifaZaStopu(Nz(rstNoviArtICene!PDVStopa, 20)), "3") & "'" '--[Tarifa robe]"
       stSQL = stSQL & "    ,1"  '--[Uvek porez na robu]"
       stSQL = stSQL & "    ," & CStr(Nz(rstNoviArtICene!Cena, 0)) '--[MP cena]"
       stSQL = stSQL & "    )"
       
       retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL, False)
       If retValOk Then
          BrojInsertArtikli = BrojInsertArtikli + 1
          IDArtikal = fsSifraArtiklaZaKatBarNaz(rstNoviArtICene!KatBroj, rstNoviArtICene!BarKod, rstNoviArtICene!Naziv)
       Else
          IDArtikal = Null
          BrojLosInsertArtikli = BrojLosInsertArtikli + 1
       End If
    
    End If 'kraj INSERTa
    
    
    If Nz(IDArtikal, -1) = -1 Then
       If PrikazujPorukeOGreskama Then
            stErrMsg = ""
            stErrMsg = stErrMsg & "Nije dodat Artikal:" & vbCrLf & vbCrLf
            stErrMsg = stErrMsg & " KatBroj = " & Nz(rstNoviArtICene!KatBroj, "Null") & vbCrLf
            stErrMsg = stErrMsg & " Barkod(GTIN) = " & Nz(rstNoviArtICene!BarKod, "Null") & vbCrLf
            stErrMsg = stErrMsg & " Naziv = " & Nz(rstNoviArtICene!Naziv, "Null") & vbCrLf & vbCrLf
            stErrMsg = stErrMsg & "Da li želite da prikazujem naredne poruke o greškama?" & vbCrLf
            
            PrikazujPorukeOGreskama = BBPitanje(stErrMsg)
            
       End If
    'Odavde na dole artikal postoji u tabeli R_Artikli
    Else 'arikal postoji u "R_Artikli" i treba INSERT i UPDATE u Cenovnik
    
       'Debug.Print "Updateujem ", rstNoviArtICene!KatBroj, rstNoviArtICene!BarKod, rstNoviArtICene!Naziv
            stSQL = ""
            stSQL = stSQL & "SELECT Count(*) as BrojSlogova "
            stSQL = stSQL & " FROM [dbo].[Cenovnik]"
            stSQL = stSQL & " WHERE [Sifra artikla]=" & stR(IDArtikal)
            stSQL = stSQL & "   AND [Vrsta dokumenta]='" & stCenVrstaDok & "'"
            
            PostojiArtikalUCenovniku = (Nz(ADO_Lookup(CNN_CurrentDataBase, "BrojSlogova", stSQL), 0) > 0)
       If PostojiArtikalUCenovniku Then
            'radimo update cene u cenovniku
            stSQL = ""
            stSQL = stSQL & "UPDATE [dbo].[Cenovnik]"
            stSQL = stSQL & " SET"
            stSQL = stSQL & " [Cena] = " & CStr(Nz(rstNoviArtICene!Cena, 0))
            stSQL = stSQL & " WHERE [Sifra artikla]=" & stR(IDArtikal)
            stSQL = stSQL & "   AND [Vrsta dokumenta]='" & stCenVrstaDok & "'"
            
            retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL, False)
            If retValOk Then
               BrojUpdateCenovnik = BrojUpdateCenovnik + 1
            Else
               BrojLosUpdateCenovnik = BrojLosUpdateCenovnik + 1
            End If
       Else 'Ne postoji artikal u cenovniku
            ' pa moramo iNSERT
          stSQL = ""
          stSQL = stSQL & "INSERT INTO [dbo].[Cenovnik]"
          stSQL = stSQL & "          ([Sifra artikla]"
          stSQL = stSQL & "          ,[Vrsta dokumenta]"
          stSQL = stSQL & "          ,[Cena]"
          stSQL = stSQL & "          ,[Tarifa]"
                    
          stSQL = stSQL & "          ,[Taksa]"
          stSQL = stSQL & "          ,[CenaBezPDV]"
          stSQL = stSQL & "          ,[Prn]"
          stSQL = stSQL & "          ,[CenaSaPDV]"
          stSQL = stSQL & "          ,[CheckCenaSaPDV]"
                
          stSQL = stSQL & "          )"

          stSQL = stSQL & " Values   ("
          stSQL = stSQL & "           " & stR(IDArtikal)
          stSQL = stSQL & "          ,'" & stCenVrstaDok & "'" '@CenVrstaDok'"
          stSQL = stSQL & "          ," & CStr(Nz(rstNoviArtICene!Cena, 0)) '@Cena'"
          stSQL = stSQL & "          ,'" & Nz(PDVTarifaZaStopu(Nz(rstNoviArtICene!PDVStopa, 20)), "3") & "'" '--[Tarifa robe]"
                    
          stSQL = stSQL & "          ,0"    ' --[Taksa]"
          stSQL = stSQL & "          ," & CStr(Nz(rstNoviArtICene!Cena, 0) / (1# + Nz(rstNoviArtICene!PDVStopa, 20#))) '@Cena'"               '@CenaBezPDV'"
          stSQL = stSQL & "          ,1"                 '--[Prn]
          stSQL = stSQL & "          ," & CStr(Nz(rstNoviArtICene!Cena, 0)) '@Cena'"
          stSQL = stSQL & "          ,1)"

          retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL, False)
          If retValOk Then
              BrojInsertCenovnik = BrojInsertCenovnik + 1
          Else
              BrojLosInsertCenovnik = BrojLosInsertCenovnik + 1
          End If
       End If
    End If
    
    rstNoviArtICene.MoveNext
 Wend
 retValOk = True
 
Exit_Point:
On Error Resume Next
 rstNoviArtICene.Close
 Set rstNoviArtICene = Nothing
 ImportArtikliICene = retValOk

Exit Function
 
Err_Point:
  BBErrorMSG err, "ImportArtikliICeneIzXLS"
  retValOk = False
  Resume Exit_Point:
End Function
