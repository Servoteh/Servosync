Attribute VB_Name = "modExportAllModules"
Option Compare Database
Option Explicit

'====================================================
' Author:    ChatGPT & Negovan Vasiæ
' Purpose:   Automatski izvoz svih VBA modula,
'            class modula i formi iz Access fajla
' Modified:  07.11.2025
'====================================================

Public Sub ExportAllModules(Optional ByVal ExportPath As String)
    On Error GoTo Err_Handler
    
    Dim obj As AccessObject
    Dim dbs As Object
    Dim FileName As String
    Dim TotalExported As Long
    
    '=== 1) Ako nije prosleðen folder, pitaj korisnika ===
    If Len(ExportPath) = 0 Then
        ExportPath = BrowseForFolder("Izaberi folder za izvoz modula:")
        If Len(ExportPath) = 0 Then Exit Sub
    End If
    If Right(ExportPath, 1) <> "\" Then ExportPath = ExportPath & "\"
    
    Set dbs = Application.CurrentProject
    
    TotalExported = 0
    
    '=== 2) Standardni moduli ===
    For Each obj In dbs.AllModules
        DoCmd.Save acModule, obj.Name
        FileName = ExportPath & obj.Name & ".bas"
        Application.SaveAsText acModule, obj.Name, FileName
        TotalExported = TotalExported + 1
    Next obj
    
    '=== 3) Class moduli ===
    'For Each obj In dbs.AllClasses
    '    DoCmd.Save acClassModule, obj.Name
    '    FileName = ExportPath & obj.Name & ".cls"
    '    Application.SaveAsText acClassModule, obj.Name, FileName
    '    TotalExported = TotalExported + 1
    'Next obj
    
    '=== 4) Forme ===
    'For Each obj In dbs.AllForms
    '    DoCmd.Save acForm, obj.Name
    '    FileName = ExportPath & obj.Name & ".form"
    '    Application.SaveAsText acForm, obj.Name, FileName
    '    TotalExported = TotalExported + 1
    'Next obj
    
    '=== 5) Izveštaji (ako želiš i njih) ===
    'For Each obj In dbs.AllReports
    '    DoCmd.Save acReport, obj.Name
   '     FileName = ExportPath & obj.Name & ".report"
    '    Application.SaveAsText acReport, obj.Name, FileName
    '    TotalExported = TotalExported + 1
    'Next obj
    
    MsgBox "Izvezeno ukupno " & TotalExported & " objekata u:" & vbCrLf & ExportPath, vbInformation, "Export modula uspešan"

Exit_Here:
    Exit Sub

Err_Handler:
    MsgBox "Greška: " & err.Description, vbExclamation, "ExportAllModules"
    Resume Exit_Here
End Sub


'====================================================
'  Funkcija za izbor foldera preko dijaloga
'====================================================
Private Function BrowseForFolder(Optional ByVal Prompt As String = "Izaberi folder:") As String
    Dim shellApp As Object
    Dim folder As Object
    
    On Error Resume Next
    Set shellApp = CreateObject("Shell.Application")
    Set folder = shellApp.BrowseForFolder(0, Prompt, 0, 0)
    If Not folder Is Nothing Then
        BrowseForFolder = folder.Items.Item.Path
    Else
        BrowseForFolder = ""
    End If
    On Error GoTo 0
End Function

