Attribute VB_Name = "_Test"
Option Compare Database
Option Explicit
Option Base 0

Public Function RaccunText() As String

    'RaccunText = StrConv(StrConv("Raèun", vbUnicode), vbFromUnicode, 2074)
    RaccunText = Prevedi("Raèun", 0, 99)

End Function
Public Function TestKafe() As Boolean
 If CurrentUser = "Negovan" Then
    TestKafe = True
 Else
    TestKafe = False
 End If
End Function
Private Function Test_OpenedRecordsets()
Dim db As DAO.Database
Dim rst As DAO.Recordset
Set db = CurrentDb
For Each rst In db.Recordsets
    Debug.Print rst.Name
Next rst
Set rst = Nothing
Set db = Nothing
End Function
Private Function DisplayApplicationInfo(obj As Object) As Integer
    Dim objApp As Object, intI As Integer, strProps As String
    On Error Resume Next
        ' Form Application property.
        Set objApp = obj.Application
        MsgBox "Application Visible property = " & objApp.Visible
        If objApp.UserControl = True Then
        For intI = 0 To objApp.DBEngine.Properties.Count - 1
            strProps = strProps & objApp.DBEngine.Properties(intI).Name & ", "
            Debug.Print objApp.DBEngine.Properties(intI).Name & " = " & objApp.DBEngine.Properties(intI)

Next intI
        End If
        MsgBox Left(strProps, Len(strProps) - 2) & ".", vbOK, "DBEngine Properties"
End Function

Private Function Test_Import_OLD()
    DoCmd.TransferDatabase acImport, "Microsoft Access", _
    "C:\Documents and Settings\Slavisa\My Documents\AcBaze97\BigBit97\BB_T.MDB", acTable, "T_PK1", _
    "T_PK1_X", True
End Function
Private Function Test_Export()
    DoCmd.TransferDatabase acExport, "Microsoft Access", _
    "C:\Documents and Settings\Slavisa\My Documents\AcBaze97\BigBit97\TEST.MDB", acTable, "T_PK1_X", _
    "T_PK1", True
End Function
Private Sub TestAllReports()
 On Error Resume Next
    Dim obj As AccessObject, dbs As Object
    Dim RPT As Report
    Set dbs = Application.CurrentProject
    Dim BrojObradjenihReporta As Long

    BrojObradjenihReporta = 0
    For Each obj In dbs.AllReports
      
      '  Debug.Print obj.Name
      DoCmd.OpenReport obj.Name, acViewDesign, , , acWindowNormal
      Set RPT = Reports(obj.Name)
      If RPT.OnOpen <> "" Then
        Debug.Print BrojObradjenihReporta; RPT.Name; RPT.OnOpen
      End If
      DoCmd.Close acReport, obj.Name, acSaveNo
      '  If obj.IsLoaded = True Then
      '      ' Print name of obj.
      '      Set rpt = Reports(obj.Name)
      '      Debug.Print obj.Name
      '      Debug.Print obj.CurrentView
      '      Debug.Print rpt.OnOpen
      '  End If
      BrojObradjenihReporta = BrojObradjenihReporta + 1
    Next obj
End Sub
Private Sub TestReport()
    Dim obj As AccessObject, dbs As Object
    Dim RPT As Report
    Set dbs = Application.CurrentProject
    DoCmd.OpenReport "TestReport", acViewPreview
    Set RPT = Reports("TestReport")
   ' rpt.HasData
    
End Sub
Private Function TestImport() As Boolean

On Error GoTo err_Func
 Dim Import As New BBImport_Class
 
 Import.ImeFajlaZaImport = OpenFileDialog()
 TestImport = Import.LinkTableToXLS()
 If TestImport Then
  'Import.PrikaziStavkeZaImport
   DoCmd.OpenQuery "Q_ProfakturaStavkeZaImport_XLS", acViewNormal, acReadOnly
 'Import.ImportedRST.MoveLast
 'Debug.Print "Broj slogova: " & Import.ImportedRST.RecordCount()
End If
exit_Func:
On Error Resume Next
 Set Import = Null

Exit Function
 
err_Func:
  BBErrorMSG err, "TestImport"
  Resume exit_Func:
End Function
Private Sub XXX_ExportReport()

   Const CREATE_REPORTML = 16

    Application.ExportXML _
        ObjectType:=acExportReport, _
        DataSource:="Invoice", _
        DataTarget:="C:\Invoice.xml", _
        PresentationTarget:="C:\InvoiceReport.xsl", _
        ImageTarget:="C:\Images", _
        OtherFlags:=CREATE_REPORTML

End Sub
Private Sub TestSPPar()
 Dim stPar As String
 stPar = "Forms!AP![ZaCenovnik]"
 On Error Resume Next
 Debug.Print stPar; "="; AccesArgToSQL(Eval(stPar))
End Sub
Public Sub ReadDBProperties()
On Error Resume Next
 Dim BigBitDB As DAO.Database
 Dim i As Integer
 
 Set BigBitDB = CurrentDb
 For i = 0 To BigBitDB.Properties.Count - 1
  Debug.Print i, BigBitDB.Properties(i).Name & " = " & BigBitDB.Properties(i).Value, BigBitDB.Properties(i).Type
 Next i
 BigBitDB.Close
 Set BigBitDB = Nothing
End Sub

Public Sub TestZaImportIzPlata()
 KreirajTmpTabeluUTmpBazi "tmp_StavkeGKZaImport", "SELECT * FROM [T_Glavna knjiga] WHERE 0=1"
End Sub
Public Function Test_spES_Insert_Update_KS() As Boolean
Dim retValOk As Boolean

'EXECUTE spES_Insert_Update_KS @IDFirma=F_IDFirma(), @Godina=Forms![KnjigaStatusaDokumenata]![ZaGodinu], @OdLevel=Forms![KnjigaStatusaDokumenata]![OdLevel], @DoLevel=Forms![KnjigaStatusaDokumenata]![DoLevel], @ZaUlaz=Cbool(IIF(Forms![KnjigaStatusaDokumenata]![UlaznaDokumenta] = "DA",True,False)), @ZaMagacinDOK=Forms![KnjigaStatusaDokumenata]![ZaMagacin], @OdDatumaDok=Forms![KnjigaStatusaDokumenata]![Od datuma], @DoDatumaDok=Forms![KnjigaStatusaDokumenata]![Do datuma], @ZaVrstuDok=Forms![KnjigaStatusaDokumenata]![Za vrstu]
', @OsimZaVrstuDok=DEFAULT, @ZaBrojNaloga=DEFAULT, @ZaVrstuNaloga=DEFAULT, @ZaIDRadniNalog=Forms![KnjigaStatusaDokumenata]![ZaRadniNalog], @ZaKS=Forms![KnjigaStatusaDokumenata]![ZaKS], @ZaKomitenta=Forms![KnjigaStatusaDokumenata]![Za komitenta], @ZaMISP=DEFAULT, @ZaRegion=Forms![KnjigaStatusaDokumenata]![ZaRegion], @ZaRegion2=Forms![KnjigaStatusaDokumenata]![ZaRegion2], @ZaMesto=Forms![KnjigaStatusaDokumenata]![ZaMesto], @ZaVrstuKomitenta=DEFAULT, @ZaProdavcaNaKomitentu=DEFAULT
', @ZaProdavcaNaDok=Forms![KnjigaStatusaDokumenata]![ZaProdavcaNaDok], @ZaPrimioFakturu=Forms![KnjigaStatusaDokumenata]![ZaPrimioFakturu], @ZaIsporuceno=Forms![KnjigaStatusaDokumenata]![ZaIsporuceno], @ZaUtovarioUVozilo=Forms![KnjigaStatusaDokumenata]![ZaUtovarioUVozilo], @ZaPripremioRobu=Forms![KnjigaStatusaDokumenata]![ZaPripremioRobu], @ZaKomentar=Forms![KnjigaStatusaDokumenata]![ZaKomentar], @ZaIDDok=DEFAULT, @CheckUpdate=Forms![KnjigaStatusaDokumenata]![CheckEsUpdate], @CheckInsert=Forms![KnjigaStatusaDokumenata]![CheckEsAppend]

retValOk = True
'retvalOk = ExecSPByRefPar("spES_Insert_Update_KS", "@IDFirma=" & F_IDFirma(), "@Godina=" & Forms![KnjigaStatusaDokumenata]![ZaGodinu], "@OdLevel=" & Forms![KnjigaStatusaDokumenata]![OdLevel], "@DoLevel=" & Forms![KnjigaStatusaDokumenata]![DoLevel], _
                    "@ZaUlaz=" & CBool(IIf(Forms![KnjigaStatusaDokumenata]![UlaznaDokumenta] = "DA", True, False)), "@ZaMagacinDOK=" & Forms![KnjigaStatusaDokumenata]![ZaMagacin], "@OdDatumaDok=" & Forms![KnjigaStatusaDokumenata]![Od datuma], _
                    "@DoDatumaDok=" & Forms![KnjigaStatusaDokumenata]![Do datuma], "@ZaVrstuDok=" & Forms![KnjigaStatusaDokumenata]![Za vrstu] _
                    )
 retValOk = ExecSPFromBBQueryDef("spES_Insert_Update_KS")
Test_spES_Insert_Update_KS = retValOk
End Function
Public Function Test_KreirajKontroleIzRSTNaFormi(adodbRST As ADODB.Recordset, stFormName As String)
Dim i As Integer
    For i = 0 To adodbRST.Fields.Count - 1
       CreateControl stFormName, acTextBox, acDetail, , adodbRST.Fields(i).Name
    Next i
End Function
Public Function Test_ObrisiSveKontroleNaFormi(stFormName As String)
  Dim ctl As control
  
  For Each ctl In Forms(stFormName).Controls
    DeleteControl stFormName, ctl.Name
  Next
End Function
Public Function Test_ADO_OpenForm()
    Dim rst As New ADODB.Recordset
    Dim stSQLText As String
    Dim stFormName As String

stFormName = "~ADO_OpenQuery~"
stSQLText = "SELECT * FROM T_JM"
 
 DoCmd.OpenForm stFormName, acDesign
 Test_ObrisiSveKontroleNaFormi stFormName
 
 Set rst = ADO_GetRST(BBCFG.CNNString, stSQLText)
 
 Test_KreirajKontroleIzRSTNaFormi rst, stFormName
 
 DoCmd.OpenForm stFormName, acFormDS
 
 Set Forms(stFormName).Recordset = rst
 
 rst.Close
 Set rst = Nothing
 
End Function
Public Function TestListSQLDB() As ADODB.Recordset
'18-06-2021
Dim stSQL As String
'stSQL = "SELECT TOP (10) r.*  FROM [RUMetalTrade].[dbo].[_RegAccess] as r ORDER BY Login_Time DESC"
stSQL = "SELECT name FROM master.sys.databases ORDER BY name"
    Set TestListSQLDB = ADO_GetRST(CNN_CurrentDataBase, stSQL)
End Function
Public Function BBFR_ReadJson() As String
Dim stJSon As String
Dim stFileName As String
Dim retValOk As Boolean
Dim arrJson() As Variant
Dim stRetValBase64 As String
Dim bytes() As Byte
Dim JPGFileName As String
Dim stRetVal As String

 stFileName = "C:\Users\Negovan\source\repos\VSBBFR\VSDCRequestSubmitter\bin\Debug\Result\Response_VS0005.Json"
 stJSon = ReadFileToString(stFileName)
 
 arrJson = (GetJSONNodeList("*", stJSon, retValOk))
 'Prikazi2DimNiz arrJson
 stRetValBase64 = VredIz2DimNiza(arrJson, "*verificationQRCode*") 'root.verificationQRCode
 'stRetVal = VredIz2DimNiza(arrJson, "*journal*") 'root.verificationQRCode
 stRetVal = VredIz2DimNiza(arrJson, "*district*") 'root.verificationQRCode
 
 If Len(stRetValBase64) > 0 Then
      bytes = Base64Decode(stRetValBase64)
      JPGFileName = "C:\Users\Negovan\source\repos\VSBBFR\VSDCRequestSubmitter\bin\Debug\Result\Response_VS0005_QRCode.JPG"
      
      Open JPGFileName For Binary As #1
      Put #1, 1, bytes
      Close #1
      
      'OpenAnyFile JPGFileName
 
 End If
 
 BBFR_ReadJson = stRetVal
 
End Function

Private Function GetRefPath(ByVal stRefName As String) As String
'Kreirano: 22-10-21
'stRefName je naziv reference ili puna putanja do fajla
On Error GoTo Err_Point
Dim r As Reference
Dim retValOk As Boolean

 retValOk = False
 For Each r In Application.References
     
     retValOk = retValOk Or (r.Name = stRefName) Or (r.fullPath = stRefName)
     
     If retValOk Then
      Exit For
     End If
 
 Next r
 
Exit_Point:
 On Error Resume Next
 If retValOk Then
    GetRefPath = r.fullPath
 Else
    GetRefPath = ""
 End If

Exit Function

Err_Point:
 BBErrorMSG err, "GetRefPath"
 retValOk = False
 Resume Exit_Point
End Function
Private Function GetMyLibVer_Test(stMyLibRefName) As String
On Error GoTo Err_Point
Dim stRetVal As String
Dim stCNN_LIB As String

stCNN_LIB = CreateAccess_CNNString(GetRefPath(stMyLibRefName))
stRetVal = ADO_Lookup(stCNN_LIB, "[VerDatum]", "_AppRev")

Exit_Point:
 On Error Resume Next
       GetMyLibVer_Test = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "GetMyLibVer_Test"
 stRetVal = "Unknown!"
 Resume Exit_Point
End Function

Private Function TEST_ADO_OpenTable(stImeTabele As String) As Boolean
'Kreirano 22-10-2021
 On Error GoTo Err_Point
    Dim Poruka As String
    Dim rst As ADODB.Recordset
    
    Set rst = ADO_GetRST(CNN_CFG_Lokal, "SELECT * FROM CFG_Lokal", dbOptimistic, adUseClient, adOpenKeyset)
    
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

Private Sub FR_PrikaziFR()
On Error GoTo Err_Point

   Dim base64file As String
   Dim bytes() As Byte
   Dim bc
   Dim ResponseJsonFile As String
   Dim PDFFileName As String
    
   ResponseJsonFile = "C:\Users\Negovan\source\repos\FRDLL\FRDLL\bin\Debug\Result\Novo\001_Response.Json"
   
   Open ResponseJsonFile For Binary As #1
   base64file = ""
   While Not EOF(1)
       bc = Input(1, #1)
       base64file = base64file & bc
       'Debug.Print

   Wend
   Close #1
     
   If Len(base64file) > 0 Then
      bytes = Base64Decode(base64file)
      PDFFileName = "C:\Users\Negovan\source\repos\FRDLL\FRDLL\bin\Debug\Result\Novo\001_Response.PDF"
      
      Open PDFFileName For Binary As #1
      Put #1, 1, bytes
      Close #1
      
      OpenAnyFile PDFFileName
   Else
       MsgBox "001_Response.Json ne postoji!", vbCritical, "QMegaTeh"
   End If
 
Exit_Point:
On Error Resume Next
    Close #1
    Exit Sub

Err_Point:
    BBErrorMSG err, "FR_PrikaziFR"
    Resume Exit_Point
    
End Sub
Private Sub TesteKasa_MPRacun()
'NE RADI DOBRO!!!

 Dim appAccess As Access.Application
 
 ' Create instance of Access Application object.
 Set appAccess = CreateObject("Access.Application")
 
 ' Open WizCode database in Microsoft Access window.
 appAccess.OpenCurrentDatabase "C:\SHARES\AcBaze\QBigBit\Kasa\QBigBit_Kasa_LIB.accdb /CMD Kasa_CMD_PrikaziMPRacun, 1127926, 4402, 1", False
 
 ' Run Sub procedure.
 'Kasa_CMD_PrikaziMPRacun(1127926,4402,1)
 appAccess.Run "Kasa_CMD_PrikaziMPRacun", 1127926, 4402, 1
 Set appAccess = Nothing
 
End Sub




Public Function PostBrojIzMesta(stMesto As String) As String
    
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stRetVal As String
Dim stTMP As String


retValOk = True
stTMP = Trim(stMesto)
stRetVal = ""

While IsNumeric(Left(stTMP, 1))
    stRetVal = stRetVal & Left(stTMP, 1)
    stTMP = Right(stTMP, Len(stTMP) - 1)
Wend

Exit_Point:
 On Error Resume Next
       PostBrojIzMesta = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "PostBrojIzMesta"
 retValOk = False
 Resume Exit_Point

End Function
Private Function DobarGLN(GLN As Variant) As Boolean
'preneto u LIB => Public Function DobarGLN(GLN As Variant) As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean
retValOk = False

If Nz(GLN, "") = "" Then
    retValOk = False
ElseIf (Len(Nz(GLN, "")) <= 5) Or Len(Nz(GLN, "")) > 14 Then
    retValOk = False
ElseIf Not IsNumeric(Nz(GLN, "")) Then
    retValOk = False
Else
    retValOk = True
End If


Exit_Point:
 On Error Resume Next
       DobarGLN = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "DobarGLN"
 retValOk = False
 Resume Exit_Point

End Function
'' 97 09704353P30148213101130
'' 97 3804353P000142151201130
' 97 54 91000000048193021
Public Sub Test_ADO_Konekcija()
    On Error GoTo ErrHandler
    Dim cnn As Object
    Set cnn = CreateObject("ADODB.Connection")
    cnn.Open "Provider=MSDASQL;DRIVER=SQL Server;SERVER=MEGABAYT\SQLEXPRESS;Trusted_Connection=Yes;DATABASE=QBigTehn;"
    MsgBox "Konekcija uspešno otvorena!", vbInformation
    cnn.Close
    Exit Sub
ErrHandler:
    MsgBox "Greška #" & err.Number & vbCrLf & err.Description, vbCritical
End Sub

