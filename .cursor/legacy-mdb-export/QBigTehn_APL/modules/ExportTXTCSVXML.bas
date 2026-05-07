Attribute VB_Name = "ExportTXTCSVXML"
Option Compare Database
Option Explicit
'*********************************************************************************************
'* Iz Beorola za CarMag
'*********************************************************************************************
Sub ExportUCSVFormat(ByVal ImeCSVDat As String, ImeQryZaExport As String, QrParameter As String, BrFld As Long, AppendFile As Boolean)
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

    imeteke = ImeCSVDat
    CSVdat = FreeFile
    If AppendFile Then
        Open imeteke For Append As #CSVdat
    Else
        Open imeteke For Output As #CSVdat
    End If
    
    Set BigBit = CurrentDb
    Set QryZaExport = BigBit.QueryDefs(ImeQryZaExport)
    
    If Not (QrParameter Like "") Then
        QryZaExport.Parameters(QrParameter) = Eval(QrParameter)
    End If
    
    Set rsQryZaExport = QryZaExport.OpenRecordset()
 
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
                rsOutputlist = (CStr(rsOutputlist))
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
    CSVdat = FreeFile
reserr:
On Error Resume Next
   Close CSVdat
   
   Set rsQryZaExport = Nothing
   rsQryZaExport.Close
   Set QryZaExport = Nothing
   QryZaExport.Close
   Set BigBit = Nothing
   BigBit.Close

   DoCmd.Hourglass False
 Exit Sub

errsnimi:
  'MsgBox "Podaci nisu snimljeni korektno!"
  MsgBox Error$
  Resume reserr
End Sub

'*****************************************************************************************************************************
Public Function PromeniZnakeZaXML(stVred As Variant, Optional stNullVal As String = "") As String
'Modifikovano: 05-12-2021 => bilo je ZameniStr(Str(34), "&quot;", retVal) a treba ZameniStr(Chr(34), "&quot;", retVal)
 Dim retVal As String
 
  If IsNull(stVred) Then
     retVal = stNullVal
  Else
    retVal = stVred
    retVal = ZameniStr("&", "&amp;", retVal)
    retVal = ZameniStr(Chr(34), "&quot;", retVal)
    retVal = ZameniStr("'", "&apos;", retVal)
    retVal = ZameniStr("<", "&lt;", retVal)
    retVal = ZameniStr(">", "&gt;", retVal)
  End If
 
   PromeniZnakeZaXML = retVal
End Function
Public Function SaveXMLTag(stTag As String, Optional stTagPoz As Variant = Null, Optional InputVred As Variant = Null, Optional stFormat As String = "", Optional stTagPar As String = "", Optional stTagParVred As String = "", Optional forceCP As String = "UTF8") As String
 Dim stLin As String
 Dim nav As String
 Dim stVred As String
 nav = Chr(34)
 
 Select Case stTagPoz
 Case True
     stLin = "<" & stTag & ">"
 Case False
    stLin = stLin & "</" & stTag & ">"
 Case Else
 
    If stTagPar = "" Or stTagParVred = "" Then
       stLin = "<" & stTag & ">"
    Else
       stLin = "<" & stTag & " " & stTagPar & "=" & nav & stTagParVred & nav & ">"
    End If
    
   ' If Not IsNull(Vred) Then
        
        stVred = Format(InputVred, stFormat)
        stVred = PromeniZnakeZaXML(stVred)
     
        
       stLin = stLin & stVred
       
       stLin = stLin & "</" & stTag & ">"
   ' End If
    
    If forceCP = "UTF8" Then
      stLin = StrToUTF8(stLin)
    End If
 End Select
 'Print xmlDat, stLin
 'Print #xmlDat, StrToUTF8("<sifArtDob>" & rsQryZaExport.Fields("sifArtDob") & "</sifArtDob>")
 SaveXMLTag = stLin
End Function
Public Sub IFExportCSV(ImeCSVDat As String, ImeQryZaExport As String, QrParameter As String)
'Modifikovano: 18-02-2022
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

    'Set BigBit = DBEngine.Workspaces(0).Databases(0)
    Set BigBit = CurrentDb
    Set QryZaExport = BigBit.QueryDefs(ImeQryZaExport)
       ' za export izlazne fakture imamo parametar [Forms]![Izlazna faktura]![IDDok]
       ' QryZaExport.Parameters("[Forms]![Izlazna faktura]![IDDok]") = [Forms]![Izlazna faktura]![IDDok]
       ' If Not (QrParameter Like "") Then
       '      QryZaExport.Parameters(QrParameter) = Eval(QrParameter)
       ' End If
    Set rsQryZaExport = QryZaExport.OpenRecordset()
 
    imeteke = ImeCSVDat
    CSVdat = FreeFile
    Open imeteke For Output As #CSVdat

       rsQryZaExport.MoveFirst
        For i = 0 To rsQryZaExport.Fields.Count - 1 'BrFld - 1
            rsOutputlist = rsQryZaExport.Fields(i).Name
           If i = rsQryZaExport.Fields.Count - 1 Then 'BrFld - 1 Then
                     Write #CSVdat, rsOutputlist
                Else
                   Write #CSVdat, rsOutputlist;
                End If
        Next i
       Do Until rsQryZaExport.EOF
            
            For i = 0 To rsQryZaExport.Fields.Count - 1 'BrFld - 1
                rsOutputlist = rsQryZaExport.Fields(i).Value
                If rsQryZaExport.Fields(i).Type = dbText Then
                    rsOutputlist = Nz(rsOutputlist, "") 'ako je NULL postavi prazan string
                  ' zamena karaktera: carriage-return i lineFeed, navodnika , zareza
                    rsOutputlist = ZameniStr(Chr(34), Chr(39) & Chr(39), CStr(rsOutputlist))
                    rsOutputlist = ZameniStr(Chr(13), Chr(32), CStr(rsOutputlist))
                    rsOutputlist = ZameniStr(Chr(10), Chr(32), CStr(rsOutputlist))
                    rsOutputlist = ZameniStr(Chr(44), Chr(32), CStr(rsOutputlist))
                    rsOutputlist = ZameniNasaSlova(CStr(rsOutputlist))
                End If
               ' ako je poslednje polje, prelazi u sledeci red
               If i = rsQryZaExport.Fields.Count - 1 Then 'BrFld - 1 Then
                     Write #CSVdat, rsOutputlist
                Else
                   Write #CSVdat, rsOutputlist;
                End If
                
            Next i
            rsQryZaExport.MoveNext
       Loop
       
       
reserr:
On Error Resume Next
   Close #CSVdat
   'Close CSVdat
   rsQryZaExport.Close
   QryZaExport.Close
   BigBit.Close

   DoCmd.Hourglass False
 Exit Sub

errsnimi:
  'MsgBox "Podaci nisu snimljeni korektno!"
  MsgBox "Greska na polju " & i & vbCrLf & Error$
  Resume reserr
End Sub

Public Sub GKExportTXT(ImeTXTDat As String, ImeQryZaExport As String, NizTab() As Integer)
On Error GoTo errsnimi

    Dim BigBit As DAO.Database
    Dim QryZaExport As DAO.QueryDef
    Dim rsQryZaExport As DAO.Recordset
    Dim imeteke As String
    Dim TXTdat As Variant
    Dim rsOutputlist As Variant
    Dim i As Integer
    Dim cistoime As String

    DoCmd.Hourglass True

    Set BigBit = CurrentDb
    Set QryZaExport = BigBit.QueryDefs(ImeQryZaExport)
       
        QryZaExport.Parameters("[Forms]![Dnevnik Glavne Knjige]![Od datuma]") = [Forms]![Dnevnik glavne knjige]![Od datuma]
        QryZaExport.Parameters("[Forms]![Dnevnik Glavne Knjige]![Do datuma]") = [Forms]![Dnevnik glavne knjige]![Do datuma]
        QryZaExport.Parameters("[Forms]![Dnevnik Glavne Knjige]![ZaVrstuNaloga]") = [Forms]![Dnevnik glavne knjige]![ZaVrstuNaloga]
        QryZaExport.Parameters("[Forms]![Dnevnik Glavne Knjige]![OdLevel]") = [Forms]![Dnevnik glavne knjige]![OdLevel]
        QryZaExport.Parameters("[Forms]![Dnevnik Glavne Knjige]![DoLevel]") = [Forms]![Dnevnik glavne knjige]![DoLevel]
        QryZaExport.Parameters("[Forms]![Dnevnik Glavne Knjige]![OdDatumaDok]") = [Forms]![Dnevnik glavne knjige]![OdDatumaDok]
        QryZaExport.Parameters("[Forms]![Dnevnik Glavne Knjige]![DoDatumaDok]") = [Forms]![Dnevnik glavne knjige]![DoDatumaDok]
        QryZaExport.Parameters("[Forms]![Dnevnik Glavne Knjige]![ZaKonto]") = [Forms]![Dnevnik glavne knjige]![ZaKonto]
        QryZaExport.Parameters("[Forms]![Dnevnik Glavne Knjige]![ZaIDKomitent]") = [Forms]![Dnevnik glavne knjige]![ZaIDKomitent]
        QryZaExport.Parameters("[Forms]![Dnevnik Glavne Knjige]![ZaOpisDok]") = [Forms]![Dnevnik glavne knjige]![ZaOpisDok]
        
    Set rsQryZaExport = QryZaExport.OpenRecordset()
 
    imeteke = ImeTXTDat
    TXTdat = FreeFile
    Open imeteke For Output As #TXTdat

       rsQryZaExport.MoveFirst
        For i = 0 To rsQryZaExport.Fields.Count - 1 'BrFld - 1
            rsOutputlist = rsQryZaExport.Fields(i).Name
            
            If NizTab(i, 1) = 0 Then
                rsOutputlist = Left$(DoChRight(rsOutputlist, NizTab(i, 0), " "), NizTab(i, 0))
            Else
                rsOutputlist = Left$(DoChLeft(rsOutputlist, NizTab(i, 0), " "), NizTab(i, 0))
            End If
            
           If i = rsQryZaExport.Fields.Count - 1 Then
                     Print #TXTdat, rsOutputlist & ","
                Else
                   Print #TXTdat, rsOutputlist & ",";
                End If
        Next i
       Do Until rsQryZaExport.EOF
            
            For i = 0 To rsQryZaExport.Fields.Count - 1 'BrFld - 1
                rsOutputlist = rsQryZaExport.Fields(i).Value
                If rsQryZaExport.Fields(i).Type = dbText Then
                    rsOutputlist = Nz(rsOutputlist, "") 'ako je NULL postavi prazan string
                  ' zamena karaktera: carriage-return i lineFeed, navodnika , zareza
                    rsOutputlist = ZameniStr(Chr(34), Chr(39) & Chr(39), CStr(rsOutputlist))
                    rsOutputlist = ZameniStr(Chr(13), Chr(32), CStr(rsOutputlist))
                    rsOutputlist = ZameniStr(Chr(10), Chr(32), CStr(rsOutputlist))
                    'rsOutputlist = ZameniStr(Chr(44), Chr(32), CStr(rsOutputlist))
                    '? rsOutputlist = ZameniNasaSlova(CStr(rsOutputlist))
                End If
                If NizTab(i, 1) = 0 Then
                    rsOutputlist = Left$(DoChRight(rsOutputlist, NizTab(i, 0), " "), NizTab(i, 0))
                Else
                    rsOutputlist = Left$(DoChLeft(rsOutputlist, NizTab(i, 0), " "), NizTab(i, 0))
                End If
               ' ako je poslednje polje, prelazi u sledeci red
               If i = rsQryZaExport.Fields.Count - 1 Then
                     Print #TXTdat, rsOutputlist & ","
                Else
                   Print #TXTdat, rsOutputlist & ",";
                End If
                
            Next i
            rsQryZaExport.MoveNext
       Loop
       
       
reserr:
On Error Resume Next
   Close #TXTdat
   'Close CSVdat
   rsQryZaExport.Close
   QryZaExport.Close
   BigBit.Close

   DoCmd.Hourglass False
 Exit Sub

errsnimi:
  'MsgBox "Podaci nisu snimljeni korektno!"
  MsgBox "Greska na polju " & i & vbCrLf & Error$
  Resume reserr
End Sub

Public Sub PDVUFExportTXT(ImeTXTDat As String, ImeQryZaExport As String, NizTab() As Integer)
On Error GoTo errsnimi

    Dim BigBit As DAO.Database
    Dim QryZaExport As DAO.QueryDef
    Dim rsQryZaExport As DAO.Recordset
    Dim imeteke As String
    Dim TXTdat As Variant
    Dim rsOutputlist As Variant
    Dim i As Integer
    Dim cistoime As String

    DoCmd.Hourglass True

    Set BigBit = CurrentDb
    Set QryZaExport = BigBit.QueryDefs(ImeQryZaExport)
       
        QryZaExport.Parameters("[Forms]![PDV_UF]![OdDatuma]") = [Forms]![PDV_UF]![OdDatuma]
        QryZaExport.Parameters("[Forms]![PDV_UF]![DoDatuma]") = [Forms]![PDV_UF]![DoDatuma]
        QryZaExport.Parameters("[Forms]![PDV_UF]![ComboZaVrstuDok]") = [Forms]![PDV_UF]![ComboZaVrstuDok]
        QryZaExport.Parameters("[Forms]![PDV_UF]![ComboZaPeriod]") = [Forms]![PDV_UF]![ComboZaPeriod]
        QryZaExport.Parameters("[Forms]![PDV_UF]![ZaJestePromet]") = [Forms]![PDV_UF]![ZaJestePromet]
        
    Set rsQryZaExport = QryZaExport.OpenRecordset()
 
    imeteke = ImeTXTDat
    TXTdat = FreeFile
    Open imeteke For Output As #TXTdat

       rsQryZaExport.MoveFirst
        For i = 0 To rsQryZaExport.Fields.Count - 1 'BrFld - 1
            rsOutputlist = rsQryZaExport.Fields(i).Name
            
            If NizTab(i, 1) = 0 Then
                rsOutputlist = Left$(DoChRight(rsOutputlist, NizTab(i, 0), " "), NizTab(i, 0))
            Else
                rsOutputlist = Left$(DoChLeft(rsOutputlist, NizTab(i, 0), " "), NizTab(i, 0))
            End If
            
           If i = rsQryZaExport.Fields.Count - 1 Then
                     Print #TXTdat, rsOutputlist & ","
                Else
                   Print #TXTdat, rsOutputlist & ",";
                End If
        Next i
       Do Until rsQryZaExport.EOF
            
            For i = 0 To rsQryZaExport.Fields.Count - 1 'BrFld - 1
            
                If NizTab(i, 1) = 1 Then 'onda je to iznos
                 rsOutputlist = PUDin(rsQryZaExport.Fields(i).Value)
                Else
                 rsOutputlist = rsQryZaExport.Fields(i).Value
                End If
                
                If rsQryZaExport.Fields(i).Type = dbText Then
                    rsOutputlist = Nz(rsOutputlist, "") 'ako je NULL postavi prazan string
                  ' zamena karaktera: carriage-return i lineFeed, navodnika , zareza
                    rsOutputlist = ZameniStr(Chr(34), Chr(39) & Chr(39), CStr(rsOutputlist))
                    rsOutputlist = ZameniStr(Chr(13), Chr(32), CStr(rsOutputlist))
                    rsOutputlist = ZameniStr(Chr(10), Chr(32), CStr(rsOutputlist))
                    'rsOutputlist = ZameniStr(Chr(44), Chr(32), CStr(rsOutputlist))
                    '? rsOutputlist = ZameniNasaSlova(CStr(rsOutputlist))
                End If
                If NizTab(i, 1) = 0 Then
                    rsOutputlist = Left$(DoChRight(rsOutputlist, NizTab(i, 0), " "), NizTab(i, 0))
                Else
                    rsOutputlist = Left$(DoChLeft(rsOutputlist, NizTab(i, 0), " "), NizTab(i, 0))
                End If
               ' ako je poslednje polje, prelazi u sledeci red
               If i = rsQryZaExport.Fields.Count - 1 Then
                     Print #TXTdat, rsOutputlist & ","
                Else
                   Print #TXTdat, rsOutputlist & ",";
                End If
                
            Next i
            rsQryZaExport.MoveNext
       Loop
       
       
reserr:
On Error Resume Next
   Close #TXTdat
   'Close CSVdat
   rsQryZaExport.Close
   QryZaExport.Close
   BigBit.Close

   DoCmd.Hourglass False
 Exit Sub

errsnimi:
  'MsgBox "Podaci nisu snimljeni korektno!"
  MsgBox "Greska na polju " & i & vbCrLf & Error$
  Resume reserr
End Sub
Public Sub PDVIFExportTXT(ImeTXTDat As String, ImeQryZaExport As String, NizTab() As Integer)
On Error GoTo errsnimi

    Dim BigBit As DAO.Database
    Dim QryZaExport As DAO.QueryDef
    Dim rsQryZaExport As DAO.Recordset
    Dim imeteke As String
    Dim TXTdat As Variant
    Dim rsOutputlist As Variant
    Dim i As Integer
    Dim cistoime As String

    DoCmd.Hourglass True

    Set BigBit = CurrentDb
    Set QryZaExport = BigBit.QueryDefs(ImeQryZaExport)
       
        QryZaExport.Parameters("[Forms]![PDV_IF]![OdDatuma]") = [Forms]![PDV_IF]![OdDatuma]
        QryZaExport.Parameters("[Forms]![PDV_IF]![DoDatuma]") = [Forms]![PDV_IF]![DoDatuma]
        QryZaExport.Parameters("[Forms]![PDV_IF]![ComboZaVrstuDok]") = [Forms]![PDV_IF]![ComboZaVrstuDok]
        QryZaExport.Parameters("[Forms]![PDV_IF]![ComboZaPeriod]") = [Forms]![PDV_IF]![ComboZaPeriod]
        QryZaExport.Parameters("[Forms]![PDV_IF]![ZaJestePromet]") = [Forms]![PDV_IF]![ZaJestePromet]
        
    Set rsQryZaExport = QryZaExport.OpenRecordset()
 
    imeteke = ImeTXTDat
    TXTdat = FreeFile
    Open imeteke For Output As #TXTdat

       rsQryZaExport.MoveFirst
        For i = 0 To rsQryZaExport.Fields.Count - 1 'BrFld - 1
            rsOutputlist = rsQryZaExport.Fields(i).Name
            
            If NizTab(i, 1) = 0 Then
                rsOutputlist = Left$(DoChRight(rsOutputlist, NizTab(i, 0), " "), NizTab(i, 0))
            Else
                rsOutputlist = Left$(DoChLeft(rsOutputlist, NizTab(i, 0), " "), NizTab(i, 0))
            End If
            
           If i = rsQryZaExport.Fields.Count - 1 Then
                     Print #TXTdat, rsOutputlist & ","
                Else
                   Print #TXTdat, rsOutputlist & ",";
                End If
        Next i
       Do Until rsQryZaExport.EOF
            
            For i = 0 To rsQryZaExport.Fields.Count - 1 'BrFld - 1
            
                If NizTab(i, 1) = 1 Then 'onda je to iznos
                 rsOutputlist = PUDin(rsQryZaExport.Fields(i).Value)
                Else
                 rsOutputlist = rsQryZaExport.Fields(i).Value
                End If
                
                If rsQryZaExport.Fields(i).Type = dbText Then
                    rsOutputlist = Nz(rsOutputlist, "") 'ako je NULL postavi prazan string
                  ' zamena karaktera: carriage-return i lineFeed, navodnika , zareza
                    rsOutputlist = ZameniStr(Chr(34), Chr(39) & Chr(39), CStr(rsOutputlist))
                    rsOutputlist = ZameniStr(Chr(13), Chr(32), CStr(rsOutputlist))
                    rsOutputlist = ZameniStr(Chr(10), Chr(32), CStr(rsOutputlist))
                    'rsOutputlist = ZameniStr(Chr(44), Chr(32), CStr(rsOutputlist))
                    '? rsOutputlist = ZameniNasaSlova(CStr(rsOutputlist))
                End If
                If NizTab(i, 1) = 0 Then
                    rsOutputlist = Left$(DoChRight(rsOutputlist, NizTab(i, 0), " "), NizTab(i, 0))
                Else
                    rsOutputlist = Left$(DoChLeft(rsOutputlist, NizTab(i, 0), " "), NizTab(i, 0))
                End If
               ' ako je poslednje polje, prelazi u sledeci red
               If i = rsQryZaExport.Fields.Count - 1 Then
                     Print #TXTdat, rsOutputlist & ","
                Else
                   Print #TXTdat, rsOutputlist & ",";
                End If
                
            Next i
            rsQryZaExport.MoveNext
       Loop
       
       
reserr:
On Error Resume Next
   Close #TXTdat
   'Close CSVdat
   rsQryZaExport.Close
   QryZaExport.Close
   BigBit.Close

   DoCmd.Hourglass False
 Exit Sub

errsnimi:
  'MsgBox "Podaci nisu snimljeni korektno!"
  MsgBox "Greska na polju " & i & vbCrLf & Error$
  Resume reserr
End Sub
Public Function PUDin(Iznos As Currency) As String
Dim retVal As String
retVal = ""
    retVal = Format$(Iznos, "###0.00")
    retVal = ZameniStr(".", ",", retVal)
    PUDin = retVal
End Function

Public Sub IFExportXML_AG(ImeXMLDat As String, ImeQryZaExport As String, ZaIDDok As Long, PIBDobavljaca As String)
On Error GoTo errsnimi

    Dim BigBit As DAO.Database
    Dim QryZaExport As DAO.QueryDef
    Dim rsQryZaExport As DAO.Recordset
    Dim imeteke As String
    Dim xmlDat As Variant
    Dim rsOutputlist As Variant
    Dim cistoime As String
    Dim nav As String
    nav = Chr(34) 'Navodnici

    DoCmd.Hourglass True

    Set BigBit = CurrentDb
    Set QryZaExport = BigBit.QueryDefs(ImeQryZaExport)
       ' za export izlazne fakture imamo parametar [Forms]![Izlazna faktura]![IDDok]
        QryZaExport.Parameters("[ZaIDDok]") = ZaIDDok
        QryZaExport.Parameters("[PIBDobavljaca]") = PIBDobavljaca
    
    Set rsQryZaExport = QryZaExport.OpenRecordset
 
    imeteke = ImeXMLDat
    xmlDat = FreeFile
    Open imeteke For Output As #xmlDat
     Print #xmlDat, "<documents"
     
       rsQryZaExport.MoveFirst
       rsOutputlist = "<fakturaDobavljac pibDobavljac=" & nav & rsQryZaExport.Fields("pibDobavljac") & nav
       rsOutputlist = rsOutputlist & " datum=" & nav & rsQryZaExport.Fields("datum") & nav
       rsOutputlist = rsOutputlist & " idKupac=" & nav & rsQryZaExport.Fields("idKupac") & nav
       rsOutputlist = rsOutputlist & " idFaktura=" & nav & rsQryZaExport.Fields("idFaktura") & nav
       rsOutputlist = rsOutputlist & " infoKey=" & nav & rsQryZaExport.Fields("infoKey") & nav & ">"
        Print #xmlDat, rsOutputlist
       
       Do Until rsQryZaExport.EOF
            rsOutputlist = "<fakturaDobavljacStavke"
                Print #xmlDat, rsOutputlist
            rsOutputlist = " ean = " & nav & rsQryZaExport.Fields("ean") & nav
                Print #xmlDat, rsOutputlist
            rsOutputlist = " kolicina = " & nav & rsQryZaExport.Fields("kolicina") & nav
                Print #xmlDat, rsOutputlist
            rsOutputlist = " cenaBezPDV = " & nav & rsQryZaExport.Fields("cenaBezPDV") & nav
                Print #xmlDat, rsOutputlist
            rsOutputlist = " cenaSaPDV = " & nav & rsQryZaExport.Fields("cenaSaPDV") & nav
                Print #xmlDat, rsOutputlist
            rsOutputlist = " ean = " & nav & rsQryZaExport.Fields("ean") & nav
                Print #xmlDat, rsOutputlist
            rsOutputlist = "/>"
                Print #xmlDat, rsOutputlist

            rsQryZaExport.MoveNext
       Loop
       rsOutputlist = "</fakturaDobavljac"
        Print #xmlDat, rsOutputlist
      rsOutputlist = "</documents"
        Print #xmlDat, rsOutputlist
        
reserr:
On Error Resume Next
   Close #xmlDat
   'Close CSVdat
   rsQryZaExport.Close
   QryZaExport.Close
   BigBit.Close

   DoCmd.Hourglass False
 Exit Sub

errsnimi:
  'MsgBox "Podaci nisu snimljeni korektno!"
  MsgBox "Greska! " & vbCrLf & Error$
  Resume reserr
End Sub
Public Function PopraviCistoImeFajla(ByVal CistoImeFajla As String) As String
Dim retVal As String
Dim i As Integer
Dim zzz As String
Dim ZaZamenu
ZaZamenu = Array("/", "\", "*", "?")    'NE SME DA SE UBACI "."

    retVal = CistoImeFajla
    For i = 1 To Len(retVal)
    zzz = Mid$(retVal, i, 1)
     If zzz = "/" Or zzz = "\" Or zzz = "*" Or zzz = "?" Then
        retVal = Left$(retVal, i - 1) & "_" & Right$(retVal, Len(retVal) - i)
     End If
    Next i
  PopraviCistoImeFajla = retVal
End Function
Public Function BBExportQueryToXML(ByVal QueryName As String, Optional ByVal FileName As String = "BB_TMP", Optional Silent As Boolean = False, Optional CleanUp = True) As Boolean
'Silent = true -> Nema poruka
'CleanUp = true -> briše privremenu bazu
'
On Error GoTo err_Func

Dim dlgSaveAs As FileDialog
Dim retVal
Dim FileNameMDB As String
Dim FileNameXML As String
Dim FileNameXSD As String
Dim FileNameXSL As String

'Dim Ok As Boolean
'Dim errMsg As String
Dim sqlCreateFile As String
Dim ExportTableName As String
Dim LinkedTableName As String

ExportTableName = "tmp_T_" & QueryName
LinkedTableName = "ExpDok"

'FileName = BazaZaTip("BB_EXPORT") & FileName

Set dlgSaveAs = Application.FileDialog(msoFileDialogSaveAs)
dlgSaveAs.Title = "QMegaTeh"
dlgSaveAs.ButtonName = "Export"
dlgSaveAs.InitialFileName = FileName
dlgSaveAs.InitialView = msoFileDialogViewDetails

If Not Silent Then
   If dlgSaveAs.Show Then
      FileName = dlgSaveAs.SelectedItems(1)
      retVal = True
   Else
     retVal = False
     GoTo exit_Func:
   End If
Else
   retVal = True
End If

    FileNameMDB = FileName & ".MDB"
    FileNameXML = FileName & ".XML"
    FileNameXSD = FileName & ".XSD"
    FileNameXSL = FileName & ".XSL"

    If Not FileExists(FileNameMDB) Then
        retVal = BBCreateDatabase(FileNameMDB)
    Else
        retVal = True
    End If
    
    If Not retVal Then
        If Not Silent Then
           MsgBox "Ne može da se kreira privremena baza " & FileNameMDB, vbCritical, "QMegaTeh"
        End If
        GoTo exit_Func
    End If
    
    If Not Silent Then
     If FileExists(FileNameXML) Then
         retVal = MsgBox("Fajl " & FileNameXML & " veæ postoji." & vbCrLf & "Želite da pišem preko njega?", vbYesNo + vbInformation + vbDefaultButton2, "QMegaTeh")
         If retVal = vbNo Then
             retVal = False
             GoTo exit_Func:
         End If
     End If
    End If
    
    sqlCreateFile = "SELECT [" & QueryName & "].* INTO [" & ExportTableName & "] IN '" & FileNameMDB & "' FROM [" & QueryName & "];"
    DoCmd.SetWarnings False
    DoCmd.RunSQL sqlCreateFile
    DoCmd.SetWarnings True

    retVal = LinkTable(CurrentDb.Name, LinkedTableName, FileNameMDB, ExportTableName)
    If retVal Then
     ExportXML acExportTable, LinkedTableName, FileNameXML ', FileNameXSD, FileNameXSL
     If Not Silent Then
      MsgBox "Export je uspešno uraðen.", vbInformation, "QMegaTeh"
     End If
     UnLinkTable LinkedTableName
    Else
     If Not Silent Then
      MsgBox "Nije moguæe linkovati tabelu " & ExportTableName, vbInformation, "QMegaTeh"
     End If
     retVal = False
     GoTo exit_Func:
    End If
    
exit_Func:

On Error Resume Next
Set dlgSaveAs = Nothing
DoCmd.SetWarnings True
UnLinkTable LinkedTableName
BBExportQueryToXML = retVal
If CleanUp Then
 Kill FileNameMDB
End If
Exit Function

err_Func:
 retVal = False
 BBErrorMSG err, "BBExportQueryToXML"
 Resume exit_Func
End Function

Public Sub IFExportXML_DIS(ImeXMLDat As String, ImeQryZaExport As String, ZaIDDok As Long, PIBDobavljaca As String)
' <?xml version='1.0' standalone='yes'?>
On Error GoTo errsnimi

    Dim BigBit As DAO.Database
    Dim QryZaExport As DAO.QueryDef
    Dim rsQryZaExport As DAO.Recordset
    Dim imeteke As String
    Dim xmlDat As Variant
    Dim rsOutputlist As Variant
    Dim cistoime As String
    Dim nav As String
    Dim Rbr As Long
    nav = Chr(34) 'Navodnici

    DoCmd.Hourglass True

    Set BigBit = CurrentDb
    Set QryZaExport = BigBit.QueryDefs(ImeQryZaExport)
       ' za export izlazne fakture imamo parametar [Forms]![Izlazna faktura]![IDDok]
        QryZaExport.Parameters("[ZaIDDok]") = ZaIDDok
       ' QryZaExport.Parameters("[PIBDobavljaca]") = PIBDobavljaca
    
    Set rsQryZaExport = QryZaExport.OpenRecordset
 
    imeteke = ImeXMLDat
    xmlDat = FreeFile
    Open imeteke For Output As #xmlDat
     rsQryZaExport.MoveFirst
     
     'Print #XMLdat, StrToUTF8( "<?xml version='1.0' standalone='yes'?>"
     Print #xmlDat, UTF8FileConstant & "<?xml version=""1.0"" encoding=""UTF-8""?>"
     Print #xmlDat, StrToUTF8("<edi>")
     Print #xmlDat, StrToUTF8("<dokument>")
     
     Print #xmlDat, StrToUTF8("<zaglavlje>")
     Print #xmlDat, StrToUTF8("<brDok>" & rsQryZaExport.Fields("brDok") & "</brDok>")  '<!--Broj dokumenta dobavljaca *OBAVEZNO POLJE-->
     Print #xmlDat, StrToUTF8("<brPor>" & rsQryZaExport.Fields("brPor") & "</brPor>") '<!--Broj porudžbenice DIS *OBAVEZNO POLJE-->"
     Print #xmlDat, StrToUTF8("<datDok>" & rsQryZaExport.Fields("datDok") & "</datDok>")  '01.02.2014</datDok><!--Datum kreiranja dokumenta-->"
     Print #xmlDat, StrToUTF8("<datDos>" & rsQryZaExport.Fields("datDos") & "</datDos>")  '16.02.2014</datDos><!--Datum dospeæa dokumenta-->"
     Print #xmlDat, StrToUTF8("</zaglavlje>")
     
    Print #xmlDat, StrToUTF8("<stavke>")
     
     rsQryZaExport.MoveFirst
     Rbr = 0
    Do Until rsQryZaExport.EOF
     Rbr = Rbr + 1
     Print #xmlDat, StrToUTF8("<stavka>")
      Print #xmlDat, StrToUTF8("<RBr>" & Rbr & "</RBr>")                                            ' <!--Redni broj stavke na dokumentu-->
      Print #xmlDat, StrToUTF8("<sifArtDob>" & rsQryZaExport.Fields("sifArtDob") & "</sifArtDob>")  ' <!--Šifra artikla kod dobavljaèa ako postoji-->"
      Print #xmlDat, StrToUTF8("<barkod>" & rsQryZaExport.Fields("barKod") & "</barkod>")           ' <!--Barkod artikla-->"
      Print #xmlDat, StrToUTF8("<nazArt>" & rsQryZaExport.Fields("nazArt") & "</nazArt>")          ' <!--Naziv artikla-->"
      Print #xmlDat, StrToUTF8("<SifJMDD>" & rsQryZaExport.Fields("JedinicaMere") & "</SifJMDD>")   ' <!--Jedinica mere artikla: KG, KOM, L, M, M2 -->"
      Print #xmlDat, StrToUTF8("<kol>" & rsQryZaExport.Fields("Kol") & "</kol>")               ' <!--Kolièina *OBAVEZNO POLJE-->"
      Print #xmlDat, StrToUTF8("<CenBrt>" & rsQryZaExport.Fields("Fakturna cena") & "</CenBrt>")         ' <!--bruto cena artikla bez rabata i poreza *OBAVEZNO POLJE-->"
      Print #xmlDat, StrToUTF8("<rabatProcUgovor>" & rsQryZaExport.Fields("FRabatProc") & "</rabatProcUgovor>")  '<!--Osnovni rabat(po ugovoru)-->"
      Print #xmlDat, StrToUTF8("<rabatProcAkcija>" & rsQryZaExport.Fields("FKasaProc") & "</rabatProcAkcija>")  ' <!--Promotivni - akcijski rabat-->"
     Print #xmlDat, StrToUTF8("</stavka>")
     
     rsQryZaExport.MoveNext
    Loop
    Print #xmlDat, StrToUTF8("</stavke>")
   Print #xmlDat, StrToUTF8("</dokument>")
 Print #xmlDat, StrToUTF8("</edi>")
reserr:
On Error Resume Next
   Close #xmlDat
   'Close CSVdat
   rsQryZaExport.Close
   QryZaExport.Close
   BigBit.Close

   DoCmd.Hourglass False
 Exit Sub

errsnimi:
  'MsgBox "Podaci nisu snimljeni korektno!"
  MsgBox "Greska! " & vbCrLf & Error$
  Resume reserr
End Sub
Public Function BBExportRstToCSV(ByRef RstZaExport As DAO.Recordset, ByVal ImeCsvFajla As String, Optional SaZaglavljem As Boolean = False, Optional Separator As String = ",", Optional FieldQute = "", Optional NullAs As String = "") As Boolean
   On Error GoTo err_BBExportRstToCSV

    Dim imeteke As String
    Dim tkf As Variant
    Dim cenast As String
    Dim stLine As String
    Dim i As Integer
    Dim UspesnoPoslato As Boolean

    tkf = FreeFile
    Open ImeCsvFajla For Output As tkf  'Ako fajl postoji biæe obrisan!
                                        'Treba proveriti pre poziva ove funkcije sa korisnikom da
                                        'li piše preko postojeæeg fajla!
   If RstZaExport.RecordCount > 0 Then
    RstZaExport.MoveFirst
   End If
   
   If SaZaglavljem Then
    For i = 1 To RstZaExport.Fields().Count
     stLine = stLine & FieldQute & CStr(Nz(RstZaExport.Fields(i - 1).Name, NullAs)) & FieldQute
     If i < RstZaExport.Fields().Count Then
      stLine = stLine & Separator
     End If
    Next i
    Print #tkf, stLine
   End If
   
   Do Until RstZaExport.EOF
    stLine = ""
    For i = 1 To RstZaExport.Fields().Count
     stLine = stLine & FieldQute & CStr(Nz(RstZaExport.Fields(i - 1).Value, NullAs)) & FieldQute
     If i < RstZaExport.Fields().Count Then
      stLine = stLine & Separator
     End If
    Next i
   
   Print #tkf, stLine

   RstZaExport.MoveNext
   Loop
   Close tkf
    
    UspesnoPoslato = True
   
exit_BBExportRstToCSV:
'On Error Resume Next
   Close tkf
   BBExportRstToCSV = UspesnoPoslato
 Exit Function

err_BBExportRstToCSV:
 
  'MsgBox Error$ & "    errno: " & Err.Number
  UspesnoPoslato = False
  Resume exit_BBExportRstToCSV

End Function

Public Function BBExportQueryToCSV(ByVal QueryName As String, ByVal ImeCsvFajla As String, Optional SaZaglavljem As Boolean = False, Optional Separator As String = ",", Optional FieldQute = "", Optional NullAs As String = "") As Boolean
   On Error GoTo err_BBExportQueryToCSV

    Dim BigBit As DAO.Database
    Dim QRstZaExport As DAO.QueryDef
    Dim RstZaExport As DAO.Recordset
    Dim retVal As Boolean
 
    Set BigBit = CurrentDb
    Set QRstZaExport = BigBit.QueryDefs(QueryName)
    'QBosson.Parameters("[ZaDatum]") = ZaDatum
    
    Set RstZaExport = QRstZaExport.OpenRecordset()
    'RstBosson.Sort = "DocumentID"
    retVal = BBExportRstToCSV(RstZaExport, ImeCsvFajla, SaZaglavljem, Separator, FieldQute, NullAs)
 
    
   
exit_BBExportQueryToCSV:
On Error Resume Next
   RstZaExport.Close
   Set RstZaExport = Nothing
   Set QRstZaExport = Nothing
   Set BigBit = Nothing
   BBExportQueryToCSV = retVal
 Exit Function

err_BBExportQueryToCSV:
 
  'MsgBox Error$ & "    errno: " & Err.Number
  retVal = False
  Resume exit_BBExportQueryToCSV

End Function

'******************************************************
'** PREUZETO IZ AlGrosso aplikacije
'*******************************************************
Public Function BBExportXLS(ImeUpitaIliTabele As String, Optional imeXLSXFajla As String = "") As Boolean
'DoCmd.SendObject acSendQuery, stDocName, , Nz(Me!Email, ""), , , "Faktura broj " & Me![Broj dokumenta] & " od " & Me![Datum dokumenta], "Automatski generisana poruka" & vbCrLf & "<<BigBit>>"
On Error GoTo Err_BBExportXLS

Const exclExt = ".xlsx"
Dim ImeFajla As String
Dim dlgSaveAs As FileDialog
Dim OkRetVal As Boolean

'stDocName = imeXLSXFajla
OkRetVal = PostojiTabelaUBazi(ImeUpitaIliTabele, CurrentDb) Or PostojiQuery(ImeUpitaIliTabele)
If Not OkRetVal Then
 BBMsgBox_BigBit "Ne postoji Upit/Tabela " & ImeUpitaIliTabele
 GoTo Exit_BBExportXLS
End If

If IsMissing(imeXLSXFajla) Then
 ImeFajla = ImeUpitaIliTabele
 ImeFajla = PopraviCistoImeFajla(ImeFajla)
 ImeFajla = BazaZaTip("BB_EXPORT") & ImeFajla & exclExt
ElseIf imeXLSXFajla = "" Then
 ImeFajla = ImeUpitaIliTabele
 ImeFajla = PopraviCistoImeFajla(ImeFajla)
 ImeFajla = BazaZaTip("BB_EXPORT") & ImeFajla & exclExt
Else
 ImeFajla = imeXLSXFajla
 ImeFajla = PopraviCistoImeFajla(ImeFajla)
 ImeFajla = ImeFajla & exclExt
End If

Set dlgSaveAs = Application.FileDialog(msoFileDialogSaveAs)
dlgSaveAs.Title = "QMegaTeh"
'dlgSaveAs.ButtonName = "Save" '"Snimi fajl"
dlgSaveAs.InitialFileName = ImeFajla
'dlgSaveAs.Filters.Clear
'dlgSaveAs.Filters.Add "PDF Document", "PDF"

dlgSaveAs.InitialView = msoFileDialogViewDetails

If dlgSaveAs.Show Then
    ImeFajla = dlgSaveAs.SelectedItems(1)
    Dim col As Variant
    Dim colst As String

  ' For Each col In Me!ListaObjekata.ItemsSelected
  '  colst = Me!ListaObjekata.ItemData(col)
    DoCmd.TransferSpreadsheet acExport, acSpreadsheetTypeExcel12Xml, ImeUpitaIliTabele, ImeFajla
  ' Next
Else
  OkRetVal = False
End If
Set dlgSaveAs = Nothing
    

Exit_BBExportXLS:
     BBExportXLS = OkRetVal
    Exit Function

Err_BBExportXLS:
    OkRetVal = False
    'MsgBox Err.Description
    BBErrorMSG err, "BBExportXLS"
    Resume Exit_BBExportXLS
End Function

Public Sub BBMail_IF(IDDok As Long)
 DoCmd.OpenForm "BBMail_IF"
 Forms!BBMail_IF!ZaIDDok = IDDok
 Forms!BBMail_IF.Requery
End Sub
Public Sub BBMail_USL(IDDok As Long)
 DoCmd.OpenForm "BBMail_USL"
 Forms!BBMail_USL!ZaIDDok = IDDok
 Forms!BBMail_USL.Requery
End Sub
