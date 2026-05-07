VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BBTools"
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

End Sub

Private Sub DodajFilterZa()
On Error GoTo Err_Point

    If Not aktivnaForma.FilterOn Then aktivnaForma.Filter = ""
    
    If Nz(aktivnaForma.Filter, "") <> "" Then
        aktivnaForma.Filter = aktivnaForma.Filter & " and (Cstr([" & aktivnaKontrola.ControlSource & "]) = '" & aktivnaKontrola & "')"
    Else
       '  aktivnaForma.Filter = "([" & aktivnaKontrola.ControlSource & "] = '" & aktivnaKontrola & "')"
         aktivnaForma.Filter = "(Cstr([" & aktivnaKontrola.ControlSource & "]) = '" & aktivnaKontrola & "')"
    End If
    
    aktivnaForma.FilterOn = True
    DoCmd.Close acForm, "BBTools"


Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "DodajFilterZa"
 Resume Exit_Point
End Sub
Private Sub DodajFilterOsimZa()
On Error GoTo Err_Point
    
    If Not aktivnaForma.FilterOn Then aktivnaForma.Filter = ""
    
    If Nz(aktivnaForma.Filter, "") <> "" Then
        aktivnaForma.Filter = aktivnaForma.Filter & " and (Cstr([" & aktivnaKontrola.ControlSource & "]) <> '" & aktivnaKontrola & "')"
    Else
         aktivnaForma.Filter = "(Cstr([" & aktivnaKontrola.ControlSource & "]) <> '" & aktivnaKontrola & "')"
    End If
    
    aktivnaForma.FilterOn = True
    DoCmd.Close acForm, "BBTools"
    
Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "DodajFilterZa"
 Resume Exit_Point
End Sub
Private Sub DodajOpstiFilter()
'Modifikovano: 28-08-2020
On Error GoTo Err_Point

    If Not aktivnaForma.FilterOn Then aktivnaForma.Filter = ""
    
    If Nz(aktivnaForma.Filter, "") <> "" Then
        aktivnaForma.Filter = aktivnaForma.Filter & " and (Cstr([" & aktivnaKontrola.ControlSource & "]) like '*" & Me!FilterFor & "*')"
    Else
         'aktivnaForma.Filter = "(Cstr([" & aktivnaKontrola.ControlSource & "]) " & Me!FilterFor & ")"
         aktivnaForma.Filter = "(Cstr([" & aktivnaKontrola.ControlSource & "]) like '*" & Me!FilterFor & "*')"
    End If
    aktivnaForma.FilterOn = True

Exit_Point:
 On Error Resume Next
 
 DoCmd.Close acForm, "BBTools"

Exit Sub

Err_Point:
 BBErrorMSG err, "DodajOpstiFilter"
 Resume Exit_Point
End Sub


Private Sub DugmeExport_Click()
On Error GoTo Err_Point

  '  DoCmd.OutputTo acOutputForm, aktivnaForma.Name
  DoCmd.Close acForm, "BBTools"
  BBOpenForm "BBExport", acNormal, , , , acDialog


Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "DugmeExport_Click"
 Resume Exit_Point
End Sub

Private Sub DugmeExportUXLS_Click()
On Error GoTo Err_Point
'Set MSCOM = CreateObject("MSCOMMLib.MSComm.1")
' C:\Program Files\Microsoft Office\OFFICE11\msacc.olb


Dim dlgSaveAs As FileDialog
Dim ImeFajla As String

'imeFajla = BazaZaTip("BB_EXPORT") & aktivnaForma.RecordSource & ".XLS"
'ImeFajla = BazaZaTip("BB_EXPORT") & aktivnaForma.RecordSource & ".XLSX"
ImeFajla = BazaZaTip("BB_EXPORT") & aktivnaForma.Name & ".XLSX"

Set dlgSaveAs = Application.FileDialog(msoFileDialogSaveAs)
dlgSaveAs.Title = "QMegaTeh"
dlgSaveAs.ButtonName = "Snimi fajl"
dlgSaveAs.InitialFileName = ImeFajla
dlgSaveAs.InitialView = msoFileDialogViewDetails


'If dlgSaveAs.SelectedItems.Count > 0 Then
If dlgSaveAs.Show Then
    ImeFajla = dlgSaveAs.SelectedItems(1)
    'DoCmd.TransferSpreadsheet acExport, acSpreadsheetTypeExcel8, aktivnaForma.RecordSource, imeFajla
    DoCmd.TransferSpreadsheet acExport, acSpreadsheetTypeExcel12, aktivnaForma.RecordSource, ImeFajla
    'DoCmd.OutputTo acOutputForm, aktivnaForma.Name, acSpreadsheetTypeExcel12, ImeFajla, True
End If

 
Exit_Point:
 On Error Resume Next
 Set dlgSaveAs = Nothing
 DoCmd.Close acForm, "BBTools"
Exit Sub

Err_Point:
 BBErrorMSG err, ""
 Resume Exit_Point
End Sub

Private Sub DugmeExportXML_Click()
On Error GoTo Err_Point

    Dim dlgSaveAs As FileDialog
    Dim ImeFajla As String
    Dim retVal

ImeFajla = BazaZaTip("BB_EXPORT") & aktivnaForma.RecordSource & ".XML"

Set dlgSaveAs = Application.FileDialog(msoFileDialogSaveAs)
dlgSaveAs.Title = "QMegaTeh"
dlgSaveAs.ButtonName = "Snimi fajl"
dlgSaveAs.InitialFileName = ImeFajla
dlgSaveAs.InitialView = msoFileDialogViewDetails


'If dlgSaveAs.SelectedItems.Count > 0 Then
If dlgSaveAs.Show Then
    ImeFajla = dlgSaveAs.SelectedItems(1)
    'ExportXML acExportTable, aktivnaForma.RecordSource, ImeFajla
    'ExportXML acExportTable, "Komitenti", ImeFajla
    DoCmd.OutputTo acOutputForm
    'DoCmd.TransferSpreadsheet acExport, acSpreadsheetTypeExcel8, aktivnaForma.RecordSource, ImeFajla
End If
Set dlgSaveAs = Nothing
DoCmd.Close acForm, "BBTools"

Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "DugmeExportXML_Click"
 Resume Exit_Point
End Sub

Private Sub DugmeFilterOsimZaSelekciju_Click()
    DodajFilterOsimZa
End Sub

Private Sub DugmeFilterZaSelekciju_Click()
    DodajFilterZa
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
On Error GoTo Err_Point

    aktivnaForma.FilterOn = False
    aktivnaForma.OrderByOn = False
    
    DoCmd.Close acForm, "BBTools"

Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "PonistiFilter"
 Resume Exit_Point
End Sub

Private Sub SortirajOdADoZ()
On Error GoTo Err_Point

    'aktivnaForma.RecordSource.Sort = aktivnaKontrola.ControlSource
    aktivnaForma.OrderBy = aktivnaKontrola.ControlSource
    aktivnaForma.OrderByOn = True
    DoCmd.Close acForm, "BBTools"
    
Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "SortirajOdADoZ"
 Resume Exit_Point
End Sub
Private Sub SortirajOdZDoA()
On Error GoTo Err_Point
    'aktivnaForma.RecordSource.Sort = aktivnaKontrola.ControlSource
    aktivnaForma.OrderBy = aktivnaKontrola.ControlSource & " DESC"
    aktivnaForma.OrderByOn = True
    DoCmd.Close acForm, "BBTools"
    
Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "SortirajOdADoZ"
 Resume Exit_Point
End Sub

'This example illustrates how to use the FileFialog object to display a dialog box
'that allow the user to select one or more files. The selected files are then added
'to a listbox named FileList.

Private Sub DugmeOpenFile_Click()
On Error GoTo Err_Point
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
  
Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "DugmeOpenFile_Click"
 Resume Exit_Point
End Sub

Private Sub PosaljiMail_Click()
On Error GoTo Err_PosaljiMail_Click

    Dim Subject As String
    
    Dim tipzaout
    Dim ImeObjekta As String
    
    If TipObjekta = acForm Then
        ImeObjekta = aktivnaForma.Name
    ElseIf TipObjekta = acReport Then
        ImeObjekta = aktivanreport.Name
    End If
Subject = "Slanje mailom: " & ImeObjekta
  

    'DoCmd.SendObject acReport, stDocName, , "beorol@beorol.rs", , , subject, subject
    DoCmd.SendObject TipObjekta, ImeObjekta, , , , , Subject, Subject

Exit_PosaljiMail_Click:
    Exit Sub

Err_PosaljiMail_Click:
    MsgBox err.Description
    Resume Exit_PosaljiMail_Click
    
End Sub

Private Sub UsersQuery_Click()
On Error GoTo Err_Point

 DoCmd.Close acForm, "BBTools"
 BBOpenForm "BB_UsersQuery"

Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "UsersQuery_Click"
 Resume Exit_Point
End Sub
