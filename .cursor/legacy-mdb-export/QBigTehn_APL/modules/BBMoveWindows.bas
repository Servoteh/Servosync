Attribute VB_Name = "BBMoveWindows"
Option Compare Database
Option Explicit

Declare PtrSafe Function SetWindowPos Lib "user32" ( _
    ByVal hwnd As LongPtr, _
    ByVal hWndInsertAfter As LongPtr, _
    ByVal X As Long, _
    ByVal Y As Long, _
    ByVal cx As Long, _
    ByVal cy As Long, _
    ByVal wFlags As Long) As Long

Declare PtrSafe Function FindWindow Lib "user32" _
    Alias "FindWindowA" ( _
    ByVal lpClassName As String, _
    ByVal lpWindowName As String) As LongPtr

Public Const HWND_TOP = 0  '//moves to top of Zorder
Public Const SWP_NOSIZE = &H1  '//Overwrites cx & cy to not resize window.

Public Function PomeriProzor(frmName As String) As Boolean
    Dim hwnd As LongPtr
    Dim pForm As Form
    Dim pCaption As String
    
    Set pForm = Screen.ActiveForm
    If IsLoaded(frmName) Then
        pCaption = pForm.Caption
        hwnd = FindWindow(vbNullString, pCaption) 'Find the handle of the window based on the title, in this case "Calculator".

        hwnd = SetWindowPos(hwnd, HWND_TOP, 1000, 100, 0, 0, SWP_NOSIZE)
        '^ moves the window. note the two 100's, these are the X and Y positions of the window. the SWP_NOSIZE stops the window size being adjusted.
    End If
    
End Function

