Attribute VB_Name = "LIB_RunProg"
Option Compare Database
Option Explicit

Declare PtrSafe Function ShellExecute Lib "shell32.dll" Alias "ShellExecuteA" (ByVal hwnd As Long, _
    ByVal lpOperation As String, ByVal lpFile As String, ByVal lpParameters As String, _
    ByVal lpDirectory As String, ByVal lpnShowCmd As Long) As Long


Public Sub ShellEx(ByVal Path As String, Optional ByVal Parameters As String, Optional ByVal HideWindow As Boolean)

    If Dir(Path) > "" Then
        ShellExecute 0, "open", Path, Parameters, "", IIf(HideWindow, 0, 1)
    End If

End Sub

'run executable
'ShellEx "c:\mytool.exe"

'open file with default app
'ShellEx "c:\someimage.jpg"

'open explorer window
'ShellEx "c:\"

