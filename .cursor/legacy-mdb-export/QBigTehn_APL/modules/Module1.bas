Attribute VB_Name = "Module1"
Option Compare Database
Option Explicit

' Deklaracija Windows API funkcija
Private Declare PtrSafe Function FindWindow Lib "user32" Alias "FindWindowA" ( _
    ByVal lpClassName As String, _
    ByVal lpWindowName As String) As LongPtr

Private Declare PtrSafe Function SetWindowPos Lib "user32" ( _
    ByVal hwnd As LongPtr, _
    ByVal hWndInsertAfter As LongPtr, _
    ByVal X As Long, _
    ByVal Y As Long, _
    ByVal cx As Long, _
    ByVal cy As Long, _
    ByVal uFlags As Long) As Long

' Konstante za SetWindowPos
Private Const SWP_NOSIZE As Long = &H1
Private Const SWP_NOZORDER As Long = &H4
Private Const SWP_SHOWWINDOW As Long = &H40

Sub MoveWindow(windowTitle As String, X As Long, Y As Long)
    Dim hwnd As LongPtr
    hwnd = FindWindow(vbNullString, windowTitle)
    
    If hwnd <> 0 Then
        SetWindowPos hwnd, 0, X, Y, 0, 0, SWP_NOSIZE Or SWP_NOZORDER Or SWP_SHOWWINDOW
    Else
        MsgBox "Prozor sa naslovom '" & windowTitle & "' nije pronaðen.", vbExclamation
    End If
End Sub

Private Sub Form_Open(Cancel As Integer)
    ' Primer pomeranja prozora kada se otvori drugi prozor
    Call MoveWindow("Naslov Prozor", 100, 100)
End Sub

