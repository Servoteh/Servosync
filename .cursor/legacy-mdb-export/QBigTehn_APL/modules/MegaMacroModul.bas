Attribute VB_Name = "MegaMacroModul"
Option Compare Database
Option Explicit

' Ispis makroa u Immediate prozor (Ctrl+G)
Public Sub IspisiSveMakroe()
    Dim mac As AccessObject
    For Each mac In CurrentProject.AllMacros
        Debug.Print mac.Name
    Next mac
    Debug.Print "*** Ukupno makroa: " & CurrentProject.AllMacros.Count & " ***"
End Sub

' Prikaz makroa u MessageBox-u
Public Sub PrikaziSveMakroe()
    Dim mac As AccessObject
    Dim txt As String
    If CurrentProject.AllMacros.Count = 0 Then
        MsgBox "Nema makroa u ovoj aplikaciji.", vbInformation, "Makroi"
        Exit Sub
    End If

    For Each mac In CurrentProject.AllMacros
        txt = txt & mac.Name & vbCrLf
    Next mac

    MsgBox "Makroi u aplikaciji:" & vbCrLf & vbCrLf & txt, vbInformation, "Makroi"
End Sub
' --------------------------------------------------
' Izvezi makro u tekstualni fajl i otvori ga u Notepadu
' --------------------------------------------------
Public Sub PrikaziSadrzajMakroa(macroName As String)
    Dim tempFile As String
    ' Generišemo ime privremenog fajla u TEMP folderu
    tempFile = Environ$("TEMP") & "\MacroDef_" & macroName & ".txt"
    
    On Error GoTo ErrHandler
    ' Export makro u tekst (Access XML text format)
    Application.SaveAsText acMacro, macroName, tempFile
    
    ' Otvorimo ga u Notepadu za lak pregled
    shell "notepad.exe """ & tempFile & """", vbNormalFocus
    Exit Sub

ErrHandler:
    MsgBox "Greška pri izvozu makroa '" & macroName & "': " & err.Description, _
           vbExclamation, "Prikaz makroa"
End Sub

' --------------------------------------------------
' Primer poziva za AutoKeys
' --------------------------------------------------
Public Sub PrikaziAutoKeys()
    PrikaziSadrzajMakroa "AutoKeys"
End Sub


