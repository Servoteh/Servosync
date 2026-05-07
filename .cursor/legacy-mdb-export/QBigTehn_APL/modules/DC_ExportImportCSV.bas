Attribute VB_Name = "DC_ExportImportCSV"
Option Compare Database
Option Explicit

Sub DC_ExportUCSVFormat(ImeCSVDat As String, ImeQryZaExport As String, QrParameter As String, BrFld As Long)
On Error GoTo errsnimi

    Dim BigBit As DAO.Database
    Dim QryZaExport As DAO.QueryDef
    Dim rsQryZaExport As DAO.Recordset
    Dim imeteke As String
    Dim CSVdat As Variant
    Dim rsOutputlist As Variant
    Dim i As Integer
    Dim cistoime As String

    DoCmd.Hourglass True

    Set BigBit = DBEngine.Workspaces(0).Databases(0)
    Set QryZaExport = BigBit.QueryDefs(ImeQryZaExport)
       ' za export artikala imamo parametar idMag
        QryZaExport.Parameters("[Forms]![DataCollector]![ComboMagacin]") = [Forms]![DataCollector]![ComboMagacin]
        QryZaExport.Parameters("[Forms]![DataCollector]![CmbDCCenovnik]") = [Forms]![DataCollector]![CmbDCCenovnik]
        QryZaExport.Parameters("[Forms]![DataCollector]![CheckCeneSaPDV]") = [Forms]![DataCollector]![CheckCeneSaPDV]
       ' If Not (QrParameter Like "") Then
       '      QryZaExport.Parameters(QrParameter) = Eval(QrParameter)
       ' End If
    Set rsQryZaExport = QryZaExport.OpenRecordset()
 
    imeteke = ImeCSVDat
    CSVdat = FreeFile
    Open imeteke For Output As #CSVdat

       rsQryZaExport.MoveFirst
       Do Until rsQryZaExport.EOF
            
            For i = 0 To BrFld - 1
                rsOutputlist = rsQryZaExport.Fields(i).Value
                If rsQryZaExport.Fields(i).Type = 10 Then
                  ' zamena karaktera: carriage-return i lineFeed, navodnika , zareza
                    rsOutputlist = ZameniStr(Chr(34), Chr(39) & Chr(39), CStr(rsOutputlist))
                    rsOutputlist = ZameniStr(Chr(13), Chr(32), CStr(rsOutputlist))
                    rsOutputlist = ZameniStr(Chr(10), Chr(32), CStr(rsOutputlist))
                    rsOutputlist = ZameniStr(Chr(44), Chr(32), CStr(rsOutputlist))
                    rsOutputlist = ZameniNasaSlova(CStr(rsOutputlist))
                End If
               ' ako je poslednje polje, prelazi u sledeci red
               If i = BrFld - 1 Then
                     Write #CSVdat, rsOutputlist
                Else
                   Write #CSVdat, rsOutputlist;
                End If
                
            Next i
            rsQryZaExport.MoveNext
       Loop
       
       Close CSVdat

   imeteke = ImeCSVDat + ".csv"
   cistoime = ""

   i = Len(ImeCSVDat)
   Do Until (i >= 1) And ((Mid$(ImeCSVDat, i, 1) = ":") Or (Mid$(ImeCSVDat, i, 1) = "\"))
      cistoime = Mid$(ImeCSVDat, i, 1) & cistoime
      i = i - 1
   Loop

   CSVdat = FreeFile
reserr:
On Error Resume Next
   Close CSVdat

   rsQryZaExport.Close
   QryZaExport.Close
   BigBit.Close

   DoCmd.Hourglass False
 Exit Sub

errsnimi:
  'MsgBox "Podaci nisu snimljeni korektno!"
  MsgBox Error$
  Resume reserr
End Sub

Sub DC_ImportIzCSVFormata(ImeCSVDat As String, BrFld As Long)
On Error GoTo errimport
'
    Dim BigBit As DAO.Database
    Dim rsTblZaImport As DAO.Recordset
    Dim imeteke As String
    Dim CSVdat As Variant
    Dim IntputField As Variant
    Dim i, IDDok As Integer

    
    Set BigBit = DBEngine.Workspaces(0).Databases(0)
    Set rsTblZaImport = BigBit.OpenRecordset("DataCollector_tr")
    IDDok = Nz(DMax("[ID]", "DataCollector_tr"), 0) + 1
    DoCmd.Hourglass True
    
    imeteke = ImeCSVDat
    CSVdat = FreeFile
    Open imeteke For Input As #CSVdat
    
        Do While Not EOF(CSVdat)
            rsTblZaImport.AddNew
            
            For i = 1 To BrFld
                Input #CSVdat, IntputField
                rsTblZaImport.Fields(i) = IntputField
            Next i
            '  putanja datoteke
                rsTblZaImport.Fields(BrFld + 1) = ImeCSVDat 'Mid(ImeCSVDat, Len(ImeCSVDat) - InStrRev(ImeCSVDat, "\") - 1, Len(ImeCSVDat))
             ' datum
                rsTblZaImport.Fields(BrFld + 3) = CVDate(Mid$(ImeCSVDat, Len(ImeCSVDat) - 11, 2) & "-" & Mid(ImeCSVDat, Len(ImeCSVDat) - 9, 2) & "-" & Year(Date))
             'vreme
                rsTblZaImport.Fields(BrFld + 4) = (Mid$(ImeCSVDat, Len(ImeCSVDat) - 7, 2) & ":" & Mid(ImeCSVDat, Len(ImeCSVDat) - 5, 2))
                rsTblZaImport.Fields(0) = IDDok
                rsTblZaImport.Update
        Loop
       
       
       Close CSVdat

   CSVdat = FreeFile
reserr:
On Error Resume Next
   Close CSVdat

   rsTblZaImport.Close
   BigBit.Close

   DoCmd.Hourglass False
 Exit Sub

errimport:
  'MsgBox "Podaci nisu snimljeni korektno!"
  MsgBox Error$
  Resume reserr
End Sub
Sub DC_DodajStavkeURobniDok(ByVal NoviIDDok As Long, qdefst As String, ZaIDDC As Long, IDMagZaExp As String)
On Error GoTo GreskaDC_DodajStavkeURobniDok

    Dim BigBit As DAO.Database
    Dim TabStav As DAO.Recordset
    Dim QNoviStav As DAO.QueryDef
    Dim NoviStav As DAO.Recordset
    'Dim IDMag As Variant 'mora variant!
   
    Set BigBit = CurrentDb
    Set TabStav = BigBit.OpenRecordset("T_Robne stavke", DB_OPEN_DYNASET, dbSeeChanges)
    Set QNoviStav = BigBit.QueryDefs(qdefst)
    QNoviStav.Parameters("[Forms]![DataCollector]![ID]") = ZaIDDC
   ' QNoviStav.Parameters("[Forms]![DataCollector]![MagaciniZaExport]") = IDMagZaExp
    Set NoviStav = QNoviStav.OpenRecordset()
    
NoviStav.MoveFirst
Do Until NoviStav.EOF
   TabStav.AddNew                                'Dodaj novi rekord
   TabStav![IDDok] = NoviIDDok
   TabStav![Sifra artikla] = NoviStav![Sifra artikla]
   TabStav![Kolicina] = NoviStav![MogucaKol]
   TabStav![Nabavna cena - neto] = NoviStav![Nabavna cena - neto]
   TabStav![Zavisni trosak - sopstveni] = NoviStav![Zavisni trosak - sopstveni]
   TabStav![Zavisni trosak - dobavljac] = NoviStav![Zavisni trosak - dobavljac]
   TabStav![Kalkulativna VP cena] = NoviStav![Kalkulativna VP cena]
   TabStav![Kalkulativna MP cena] = NoviStav![Kalkulativna MP cena]
   TabStav![Stvarna VP cena] = NoviStav![VPCenaSaRabatom]  'NoviStav![VP cena]
   TabStav![Stvarna MP cena] = NoviStav![MPCenaSaRabatom]   'NoviStav![MP cena]
   TabStav![TAKSA] = NoviStav![TAKSA]
   TabStav![RabatProc] = NoviStav![RabatKomitenta]  'NoviStav![Rabatproc]
   TabStav![KasaProc] = NoviStav![KasaProc]
   TabStav![Odlozeno] = NoviStav![Odlozeno]
   TabStav![Obracunat porez na ulazu - roba] = NoviStav![Obracunat porez na ulazu - roba]
   TabStav![Tarifa - roba - ulaz] = NoviStav![Tarifa - roba - ulaz]
   TabStav![Obracunat porez na usluge] = NoviStav![Obracunat porez na usluge]
   TabStav![Tarifa - usluge - izlaz] = NoviStav![Tarifa - usluge - izlaz]
   TabStav![Obracunat  porez na robu] = True 'NoviStav![Obracunat  porez na robu]
   TabStav![Tarifa - roba - Izlaz] = NoviStav![Tarifa - roba - Izlaz]
   TabStav![IDMagacin] = NoviStav![IDMagacin]
   TabStav![KNGCena] = NoviStav![KNGCena]


   TabStav.Update 'Sacuvaj izmene
   NoviStav.MoveNext
Loop

    NoviStav.Close
    Set NoviStav = Nothing
    TabStav.Close
    Set TabStav = Nothing
    Set QNoviStav = Nothing
    BigBit.Close
    Set BigBit = Nothing
    
    
    
Exit Sub

GreskaDC_DodajStavkeURobniDok:
 MsgBox Error$
 Resume Next

End Sub


