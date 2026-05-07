Attribute VB_Name = "LIB_BBFileDialog"
Option Compare Database
Option Explicit

Public Function OpenFile(Optional ByVal Path As String = "") As String
Dim dlgOpenFile As FileDialog
Dim ImeFajla As String

ImeFajla = Nz(Path, "")
Set dlgOpenFile = Application.FileDialog(msoFileDialogOpen)
dlgOpenFile.Title = "QMegaTeh"
' dlgOpenFile.ButtonName = "Otvori"
dlgOpenFile.InitialFileName = ImeFajla
dlgOpenFile.InitialView = msoFileDialogViewDetails

If dlgOpenFile.Show Then
    If dlgOpenFile.SelectedItems.Count > 0 Then
     ImeFajla = dlgOpenFile.SelectedItems(1)
    Else
     ImeFajla = ""
    End If
Else
    ImeFajla = ""
End If
Set dlgOpenFile = Nothing
OpenFile = ImeFajla
End Function
Public Function SaveAsFile(Optional ByVal Path As String = "") As String
Dim dlgOpenFile As FileDialog
Dim ImeFajla As String

ImeFajla = Nz(Path, "")
Set dlgOpenFile = Application.FileDialog(msoFileDialogSaveAs)
dlgOpenFile.Title = "QMegaTeh"
' dlgOpenFile.ButtonName = "Otvori"
dlgOpenFile.InitialFileName = ImeFajla
dlgOpenFile.InitialView = msoFileDialogViewDetails

If dlgOpenFile.Show Then
    If dlgOpenFile.SelectedItems.Count > 0 Then
     ImeFajla = dlgOpenFile.SelectedItems(1)
    Else
     ImeFajla = ""
    End If
Else
    ImeFajla = ""
End If
Set dlgOpenFile = Nothing
SaveAsFile = ImeFajla
End Function

Public Function OpenFolder(Optional ByVal Path As String = "") As String
Dim dlgOpenFile As FileDialog
Dim ImeFajla As String

ImeFajla = Nz(Path, "")
Set dlgOpenFile = Application.FileDialog(msoFileDialogFolderPicker)
dlgOpenFile.Title = "QMegaTeh"
' dlgOpenFile.ButtonName = "Otvori"
dlgOpenFile.InitialFileName = ImeFajla
dlgOpenFile.InitialView = msoFileDialogViewDetails

If dlgOpenFile.Show Then
    If dlgOpenFile.SelectedItems.Count > 0 Then
     ImeFajla = dlgOpenFile.SelectedItems(1)
    Else
     ImeFajla = ""
    End If
Else
    ImeFajla = ""
End If
Set dlgOpenFile = Nothing
OpenFolder = ImeFajla
End Function
