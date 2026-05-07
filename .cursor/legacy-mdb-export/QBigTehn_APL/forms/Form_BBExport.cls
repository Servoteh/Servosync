VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BBExport"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Dim aktivnaForma As Form
Dim aktivanreport As Report
Dim aktivnaKontrola  As control
Dim TipObjekta

Private Sub Form_Open(Cancel As Integer)
On Error Resume Next


OdrediSpisakTabela
'OdrediSpisakUpita

Set aktivnaForma = Screen.ActiveForm
'Set aktivnaKontrola = Screen.ActiveForm.ActiveControl
Set aktivnaKontrola = Screen.ActiveControl
Set aktivanreport = Screen.ActiveReport


TipObjekta = Application.CurrentObjectType

'If tipobjekta = acReport Then
'   MsgBox ("Aktivan report " & aktivanReport.Name)
'   DoCmd.OutputTo acOutputReport, aktivanReport.Name
'   DoCmd.Close acForm, "BBTools"
'End If

If Screen.ActiveControl.Name = Screen.ActiveForm.ActiveControl.Name Then

Else
    Set aktivnaForma = Screen.ActiveForm.ActiveControl.Form
End If

'*******************************************
    Me!txtAktivnaForma = aktivnaForma.Name
    Me!txtAktivnaKontrola = aktivnaKontrola.ControlSource
'*******************************************

 If Nz(aktivnaKontrola.ControlSource, "") = "" Then
    Me!DugmeFilterZaSelekciju.Enabled = False
    Me!DugmeFilterOsimZaSelekciju.Enabled = False
    Me!DugmeSortirajOdADoZ.Enabled = False
    Me!DugmeSortirajOdZDoA.Enabled = False
    Me!DugmePonistiFilter.Enabled = False
    Me!FilterFor.Enabled = False
    'Cancel = True
 End If
 If Nz(aktivnaForma.RecordSource, "") = "" Then
    Me!DugmeExportUXLS.Enabled = False
 End If
 '*******************************************
    Me!txtAktivnaForma = aktivnaForma.Name
    Me!txtAktivnaKontrola = aktivnaKontrola.ControlSource
    ' ? Screen.ActiveForm.ActiveControl.Form.Filter
    ' ? Screen.ActiveForm.ActiveControl.Parent.name
'*******************************************
Me.Caption = "Frm:" & aktivnaForma.Name & "    Ctrl:" & aktivnaKontrola.ControlSource
End Sub

Private Sub DodajFilterZa()
    
    If Not aktivnaForma.FilterOn Then aktivnaForma.Filter = ""
    
    If Nz(aktivnaForma.Filter, "") <> "" Then
        aktivnaForma.Filter = aktivnaForma.Filter & " and (Cstr([" & aktivnaKontrola.ControlSource & "]) = '" & aktivnaKontrola & "')"
    Else
       '  aktivnaForma.Filter = "([" & aktivnaKontrola.ControlSource & "] = '" & aktivnaKontrola & "')"
         aktivnaForma.Filter = "(Cstr([" & aktivnaKontrola.ControlSource & "]) = '" & aktivnaKontrola & "')"
    End If
    
    aktivnaForma.FilterOn = True
    DoCmd.Close acForm, "BBExport"
End Sub
Private Sub DodajFilterOsimZa()
    
    If Not aktivnaForma.FilterOn Then aktivnaForma.Filter = ""
    
    If Nz(aktivnaForma.Filter, "") <> "" Then
        aktivnaForma.Filter = aktivnaForma.Filter & " and (Cstr([" & aktivnaKontrola.ControlSource & "]) <> '" & aktivnaKontrola & "')"
    Else
         aktivnaForma.Filter = "(Cstr([" & aktivnaKontrola.ControlSource & "]) <> '" & aktivnaKontrola & "')"
    End If
    
    aktivnaForma.FilterOn = True
    DoCmd.Close acForm, "BBExport"
End Sub
Private Sub DodajOpstiFilter_OLD()
    
    If Not aktivnaForma.FilterOn Then aktivnaForma.Filter = ""
    
    If Nz(aktivnaForma.Filter, "") <> "" Then
        aktivnaForma.Filter = aktivnaForma.Filter & " and (Cstr([" & aktivnaKontrola.ControlSource & "]) " & Me!FilterFor
    Else
         aktivnaForma.Filter = "(Cstr([" & aktivnaKontrola.ControlSource & "]) " & Me!FilterFor & ")"
    End If
    
    aktivnaForma.FilterOn = True
    DoCmd.Close acForm, "BBExport"
End Sub
Private Sub DodajOpstiFilter()
    
    If Not aktivnaForma.FilterOn Then aktivnaForma.Filter = ""
    
    If Nz(aktivnaForma.Filter, "") <> "" Then
        aktivnaForma.Filter = aktivnaForma.Filter & " and (Cstr([" & aktivnaKontrola.ControlSource & "]) like '*" & Me!FilterFor & "*')"
    Else
         'aktivnaForma.Filter = "(Cstr([" & aktivnaKontrola.ControlSource & "]) " & Me!FilterFor & ")"
         aktivnaForma.Filter = "(Cstr([" & aktivnaKontrola.ControlSource & "]) like '*" & Me!FilterFor & "*')"
    End If
    aktivnaForma.FilterOn = True
    DoCmd.Close acForm, "BBTools"
End Sub


Private Sub DugmeExportUXLS_Click()
Dim dlgSaveAs As FileDialog
Dim ImeFajla As String

ImeFajla = BazaZaTip("BB_EXPORT") & aktivnaForma.RecordSource & ".XLS"

Set dlgSaveAs = Application.FileDialog(msoFileDialogSaveAs)
dlgSaveAs.Title = "QMegaTeh"
dlgSaveAs.ButtonName = "Snimi fajl"
dlgSaveAs.InitialFileName = ImeFajla
dlgSaveAs.InitialView = msoFileDialogViewDetails


'If dlgSaveAs.SelectedItems.Count > 0 Then
If dlgSaveAs.Show Then
    ImeFajla = dlgSaveAs.SelectedItems(1)
    DoCmd.TransferSpreadsheet acExport, acSpreadsheetTypeExcel8, aktivnaForma.RecordSource, ImeFajla
End If
Set dlgSaveAs = Nothing
    
End Sub

Private Sub DugmeExportXML_Click()
    Dim dlgSaveAs As FileDialog
Dim ImeFajla, ImeFajlaShema, ImeFajlaPres As String
Dim retVal

ImeFajla = BazaZaTip("BB_EXPORT") & Me!ListaObjekata & ".XML"
ImeFajlaShema = BazaZaTip("BB_EXPORT") & Me!ListaObjekata & ".XSD"
ImeFajlaPres = BazaZaTip("BB_EXPORT") & Me!ListaObjekata & ".XSL"

Set dlgSaveAs = Application.FileDialog(msoFileDialogSaveAs)
dlgSaveAs.Title = "QMegaTeh"
dlgSaveAs.ButtonName = "Snimi fajl"
dlgSaveAs.InitialFileName = ImeFajla
dlgSaveAs.InitialView = msoFileDialogViewDetails


'If dlgSaveAs.SelectedItems.Count > 0 Then
If dlgSaveAs.Show Then
    ImeFajla = dlgSaveAs.SelectedItems(1)
    'ExportXML acExportTable, aktivnaForma.RecordSource, ImeFajla
    ExportXML acExportTable, Me!ListaObjekata, ImeFajla, ImeFajlaShema, ImeFajlaPres
    'DoCmd.TransferSpreadsheet acExport, acSpreadsheetTypeExcel8, aktivnaForma.RecordSource, ImeFajla
    MsgBox "Gotovo", , "QMegaTeh"
End If
Set dlgSaveAs = Nothing
End Sub

Private Sub DugmeFilterOsimZaSelekciju_Click()
    DodajFilterOsimZa
End Sub

Private Sub DugmeFilterZaSelekciju_Click()
    DodajFilterZa
End Sub

Private Sub DugmeOdrediSpisakUpita_Click()
    Me!ListaObjekata.ControlSource = ""
    OdrediSpisakUpita
End Sub

Private Sub DugmeOutput_Click()
On Error Resume Next
Dim col As Variant
Dim colst As String
For Each col In Me!ListaObjekata.ItemsSelected
    colst = Me!ListaObjekata.ItemData(col)
    DoCmd.OutputTo acOutputTable, colst, , , Me!CheckAutoStart
Next

End Sub
Private Sub DugmePonistiFilter_Click()
    PonistiFilter
End Sub

Private Sub DugmeSortirajOdADoZ_Click()
    SortirajOdADoZ
End Sub

Private Sub DugmeSortirajOdZDoA_Click()
    SortirajOdZDoA
End Sub

Private Sub FilterFor_AfterUpdate()
    DodajOpstiFilter
End Sub



Private Sub PonistiFilter()
    aktivnaForma.FilterOn = False
    aktivnaForma.OrderByOn = False
    
    DoCmd.Close acForm, "BBExport"
End Sub

Private Sub SortirajOdADoZ()
    'aktivnaForma.RecordSource.Sort = aktivnaKontrola.ControlSource
    aktivnaForma.OrderBy = aktivnaKontrola.ControlSource
    aktivnaForma.OrderByOn = True
    DoCmd.Close acForm, "BBExport"
End Sub
Private Sub SortirajOdZDoA()
    'aktivnaForma.RecordSource.Sort = aktivnaKontrola.ControlSource
    aktivnaForma.OrderBy = aktivnaKontrola.ControlSource & " DESC"
    aktivnaForma.OrderByOn = True
    DoCmd.Close acForm, "BBExport"
End Sub

'This example illustrates how to use the FileFialog object to display a dialog box
'that allow the user to select one or more files. The selected files are then added
'to a listbox named FileList.

Private Sub DugmeOpenFile_Click()
 
   ' Requires reference to Microsoft Office 11.0 Object Library.

   Dim fDialog As Office.FileDialog
   Dim varFile As Variant

   ' Clear listbox contents.
   'Me.FileList.RowSource = ""

   ' Set up the File Dialog.
   Set fDialog = Application.FileDialog(msoFileDialogFilePicker)

   With fDialog

      ' Allow user to make multiple selections in dialog box
      .AllowMultiSelect = True
            
      ' Set the title of the dialog box.
      .Title = "Please select one or more files"

      ' Clear out the current filters, and add our own.
      .Filters.Clear
      .Filters.Add "Access Databases", "*.MDB"
      .Filters.Add "Access Projects", "*.ADP"
      .Filters.Add "All Files", "*.*"

      ' Show the dialog box. If the .Show method returns True, the
      ' user picked at least one file. If the .Show method returns
      ' False, the user clicked Cancel.
      If .Show = True Then

         'Loop through each file selected and add it to our list box.
         For Each varFile In .SelectedItems
           ' Me.FileList.AddItem varFile
         Next

      Else
         MsgBox "You clicked Cancel in the file dialog box."
      End If
   End With
End Sub
Private Sub DugmeOdrediSpisakTabela_Click()
    OdrediSpisakTabela
End Sub
Public Sub OdrediSpisakTabelaFOR()
 Dim i As Integer
    For i = 1 To CurrentDb.TableDefs.Count
        Me.ListaObjekata.AddItem CurrentDb.TableDefs(i - 1).Name
    Next
End Sub
Public Sub OdrediSpisakTabela()
Dim otb As TableDef
    For Each otb In CurrentDb.TableDefs
     If Not (otb.Name Like "MSys*") Then
        Me.ListaObjekata.AddItem otb.Name
     End If
    Next
End Sub
Public Sub OdrediSpisakUpita()
Dim qdf As QueryDef
    For Each qdf In CurrentDb.QueryDefs
        Me.ListaObjekata.AddItem qdf.Name
        'Debug.Print qdf.Name
    Next
End Sub
Private Sub Command20_Click()
On Error GoTo Err_Command20_Click

    Dim oApp As Object

    Set oApp = CreateObject("Excel.Application")
    oApp.Visible = True
    'Only XL 97 supports UserControl Property
    On Error Resume Next
    oApp.UserControl = True

Exit_Command20_Click:
    Exit Sub

Err_Command20_Click:
    MsgBox err.Description
    Resume Exit_Command20_Click
    
End Sub
Private Sub Command22_Click()
On Error GoTo Err_Command22_Click

    Dim stDocName As String

    stDocName = Me!TableList
    DoCmd.OutputTo acOutputTable, stDocName
    

Exit_Command22_Click:
    Exit Sub

Err_Command22_Click:
    MsgBox err.Description
    Resume Exit_Command22_Click
    
End Sub
Private Sub CheckProducts()   'primer iz HELP-a
    
    Dim intState As Integer
    Dim intCurrentType As Integer
    Dim strCurrentName As String

    intCurrentType = Application.CurrentObjectType
    strCurrentName = Application.CurrentObjectName
    
    If intCurrentType = acForm And strCurrentName = "Products" Then
        intState = SysCmd(acSysCmdGetObjectState, intCurrentType, _
                   strCurrentName)
             
        ' Products form changed but not saved.
        If intState = acObjStateDirty + acObjStateOpen Then
            
            ' Close Products form and save changes.
            DoCmd.Close intCurrentType, strCurrentName, acSaveYes
        End If
    End If
End Sub


Private Sub ListaObjekata_DblClick(Cancel As Integer)
    'DoCmd.OpenTable Me!ListaObjekata, acViewNormal, acReadOnly
    DugmeOutput_Click
End Sub
Private Sub DugmePogledajTabelu_Click()
On Error GoTo Err_DugmePogledajTabelu_Click

    Dim stDocName As String
   ' Dim MyForm As Form

   ' stDocName = "Adrese"
   ' Set MyForm = Screen.ActiveForm
   ' DoCmd.SelectObject acTable, stDocName, True
   ' DoCmd.PrintOut
   ' DoCmd.SelectObject acForm, MyForm.Name, False
   
   If Me!ListaObjekata.ItemsSelected.Count > 0 Then
    
    'ovo radi kada nije MultiSelect   stDocName = Me!ListaObjekata
    'Me!ListaObjekata.ItemsSelected
    'stDocName = Me!ListaObjekata.ItemData(0)
    stDocName = Me!ListaObjekata.ItemData(Me!ListaObjekata.ItemsSelected(0))
    If Me!ListaObjekata.ItemsSelected.Count > 1 Then
     If Not BBPitanje("Izabrali ste više od jedne tabele." & vbCrLf & "Biæe vam prikazana samo " & stDocName) Then
        Exit Sub
     End If
    End If
    DoCmd.Close acForm, "BBExport"
    DoCmd.OpenTable stDocName, acViewNormal, acReadOnly
   End If

Exit_DugmePogledajTabelu_Click:
    Exit Sub

Err_DugmePogledajTabelu_Click:
    MsgBox err.Description
    Resume Exit_DugmePogledajTabelu_Click
    
End Sub
Private Sub DugmeLokExport_Click()
On Error Resume Next
Dim tipzaout
Dim ImeObjekta As String
    If TipObjekta = acForm Then
        tipzaout = acOutputForm
        ImeObjekta = aktivnaForma.Name
    ElseIf TipObjekta = acReport Then
        tipzaout = acOutputReport
        ImeObjekta = aktivanreport.Name
        DoCmd.Close acReport, ImeObjekta
    End If

 DoCmd.OutputTo tipzaout, ImeObjekta
 DoCmd.Close acForm, "BBTools"
End Sub
Private Sub DugmePosaljiMail_Click()
On Error GoTo Err_DugmePosaljiMail_Click

    Dim stDocName, Subject As String
    Subject = Me![Komitenti.Naziv] & " Faktura: " & Me![Broj dokumenta] & " ID: " & Forms![Izlazna faktura]![IDDok]

    stDocName = "Faktura - BEOROL"
    'BBOpenReport stDocName, acPreview
    'DoCmd.SendObject acSendReport, stDocName, , "beorol@my-trion.net", , , subject
    'DoCmd.SendObject acSendReport, stDocName, , "beorol@my-trion.net", , , Subject, Subject
    DoCmd.SendObject acSendReport, stDocName, , "magacin.r@beorol.co.yu", , , Subject, Subject
    

Exit_DugmePosaljiMail_Click:
    Exit Sub

Err_DugmePosaljiMail_Click:
    MsgBox err.Description
    Resume Exit_DugmePosaljiMail_Click
    
End Sub
Private Sub PosaljiMail_Click()
On Error GoTo Err_PosaljiMail_Click

    Dim stDocName As String
    Dim Subject As String

   Subject = "Slanje mailom: " & aktivanreport.Name

    stDocName = aktivanreport.Name

    'DoCmd.SendObject acReport, stDocName, , "magacin.r@beorol.co.yu", , , subject, subject
    DoCmd.SendObject acReport, stDocName, , , , , Subject, Subject

Exit_PosaljiMail_Click:
    Exit Sub

Err_PosaljiMail_Click:
    MsgBox err.Description
    Resume Exit_PosaljiMail_Click
    
End Sub
Private Sub ExportXLSX_Click()
   ExportXLS "BigBitPodaci_" & Format(Date, "dd-MM-yyyy")
End Sub
Private Sub ExportXLS(imeXLSXFajla As String)
'DoCmd.SendObject acSendQuery, stDocName, , Nz(Me!Email, ""), , , "Faktura broj " & Me![Broj dokumenta] & " od " & Me![Datum dokumenta], "Automatski generisana poruka" & vbCrLf & "<<BigBit>>"
On Error GoTo Err_DugmeNapraviPDF_Click

Dim stDocName As String
Dim ImeFajla As String
Dim dlgSaveAs As FileDialog

'stDocName = imeXLSXFajla
    

ImeFajla = imeXLSXFajla
ImeFajla = PopraviCistoImeFajla(ImeFajla)
ImeFajla = BazaZaTip("BB_EXPORT") & ImeFajla & ".XLSX"

Set dlgSaveAs = Application.FileDialog(msoFileDialogSaveAs)
dlgSaveAs.Title = "QMegaTeh"
'dlgSaveAs.ButtonName = "Save" '"Snimi fajl"
dlgSaveAs.InitialFileName = ImeFajla
'dlgSaveAs.Filters.Clear
'dlgSaveAs.Filters.Add "PDF Document", "PDF"

dlgSaveAs.InitialView = msoFileDialogViewDetails

If dlgSaveAs.Show Then
    ImeFajla = dlgSaveAs.SelectedItems(1)
    'DoCmd.TransferSpreadsheet acExport, acSpreadsheetTypeExcel12, stDocName, imeFajla
    Dim col As Variant
    Dim colst As String

   For Each col In Me!ListaObjekata.ItemsSelected
    colst = Me!ListaObjekata.ItemData(col)
    DoCmd.TransferSpreadsheet acExport, acSpreadsheetTypeExcel12Xml, colst, ImeFajla
   ' ExportXLS colst
   Next
    
End If
Set dlgSaveAs = Nothing
    

Exit_DugmeNapraviPDF_Click:
    Exit Sub

Err_DugmeNapraviPDF_Click:
    MsgBox err.Description
    Resume Exit_DugmeNapraviPDF_Click
    
End Sub

Private Sub UsersQuery_Click()
 DoCmd.Close acForm, "BBExport"
 BBOpenForm "BB_UsersQuery"
End Sub
