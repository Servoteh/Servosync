Attribute VB_Name = "LIB_FileManager"
Option Compare Database
Option Explicit

Public Declare PtrSafe Function CopyFile Lib "kernel32" Alias "CopyFileA" ( _
ByVal AExistingFileName As String, _
ByVal ANewFileName As String, _
ByVal AFailIfExists As Boolean _
) As Boolean
' kopira fajl iako je otvoren!!!

Private Declare PtrSafe Function FindExecutable Lib "shell32.dll" Alias "FindExecutableA" (ByVal lpFile As String, ByVal lpDirectory As String, ByVal lpResult As String) As Long

Public Function GetExecutableForFile(strFilename As String) As String
'traži izvršni program za fajl strFileName
'? GetExecutableForFile("C:\SHARES\AcBaze\BigBit\BigBit_APL_2010.MDB")
   Dim lngRetval As Long
   Dim strExecName As String * 255
   lngRetval = FindExecutable(strFilename, vbNullString, strExecName)
   GetExecutableForFile = Left$(strExecName, InStr(strExecName, Chr$(0)) - 1)
End Function

Public Sub RunIt(strNewFullPath As String)
   Dim exeName As String

   exeName = GetExecutableForFile(strNewFullPath)
   shell exeName & " " & Chr(34) & strNewFullPath & Chr(34), vbNormalFocus
End Sub

Public Function FileExists(ByVal strFile As String) As Boolean
'Modifikovano: 17-09-2020
  Dim i As Integer
  Dim atr As Integer
  
  On Error Resume Next
  i = Len(Dir(strFile))
  If i > 0 Then
    atr = GetAttr(strFile)
  Else
    atr = -1
  End If
  
  FileExists = (err.Number = 0) And (i > 0) And (atr <> vbDirectory)

End Function
Public Function DirExists(ByVal strFile As String) As Boolean
'Modifikovano: 17-09-2020
  Dim i As Integer
 
  On Error Resume Next
  i = Len(Dir(strFile, vbDirectory))
  DirExists = (err.Number = 0) And (i > 0)

End Function
Public Function ExtFromPath(strFullPath As String) As String
 Dim nPosExt As Long
    nPosExt = InStrRev(strFullPath, ".")
    'ExtFromPath = Right(strFullPath, Len(strFullPath) - InStrRev(strFullPath, "."))
    If nPosExt > 0 Then
     ExtFromPath = Right(strFullPath, Len(strFullPath) - nPosExt)
    Else
     ExtFromPath = ""
    End If
End Function
Public Function FileNameFromPath(strFullPath As String) As String
    FileNameFromPath = Right(strFullPath, Len(strFullPath) - InStrRev(strFullPath, "\"))
End Function
Public Function FolderFromPath(strFullPath As String) As String
  On Error GoTo HandleErrors
   Dim intPos As Integer
    
    intPos = InStrRev(strFullPath, "\")
    If intPos > 0 Then
        FolderFromPath = Left(strFullPath, InStrRev(strFullPath, "\"))
    Else
        FolderFromPath = ""
    End If
ExitHere:
    Exit Function
    
HandleErrors:
    Select Case err.Number
        Case Else
            err.Raise err.Number, err.Source, _
             err.Description, err.HelpFile, err.HelpContext
    End Select
    Resume ExitHere
End Function
Public Function CurrentDBPath() As String
 On Error GoTo HandleErrors
 Dim retVal As String
    
    retVal = FolderFromPath(CurrentDb.Name) ' CurrentDb.Name ako je DAO, ako je ADO treba currentProject.Path
ExitHere:
    CurrentDBPath = retVal
    Exit Function
    
HandleErrors:
    Select Case err.Number
        Case Else
            err.Raise err.Number, err.Source, _
             err.Description, err.HelpFile, err.HelpContext
    End Select
    Resume ExitHere
End Function
Public Function DefaultZIPFileName(strFilename As String) As String
    Dim retVal As String
    Dim stEXT As String
    stEXT = ExtFromPath(strFilename)
    retVal = Left$(strFilename, Len(strFilename) - Len(stEXT)) & Format$(Date, "dd-MM-yy") & ".ZIP"
    DefaultZIPFileName = retVal
End Function

Public Function ZipFile(FileNameToZip As String, Optional ZIPFileName As String = "") As Long
'? ZipFile("C:\SHARES\AcBaze\BigBit\SRTCT\BB_SrpEngRecnik.mdb","C:\SHARES\AcBaze\BigBit\SRTCT\BB_SrpEngRecnik_09-06-15.ZIP")
On Error GoTo err_Func

'ZipCMD = ZipProg & " a " & "C:\SHARES\AcBaze\BigBit\SRTCT\BB_SrpEngRecnik_" & Date & ".ZIP" & " " & "C:\SHARES\AcBaze\BigBit\SRTCT\BB_SrpEngRecnik.mdb"
'ZipProg = "C:\Program Files\7-Zip\7z.exe"

 Dim ZipCMD As String
 Dim ZipProg As String
 Dim retVal As Long
 
 retVal = 0
 If ZIPFileName = "" Then
  ZIPFileName = DefaultZIPFileName(FileNameToZip)
 End If
 
 ZipProg = InputBox("ZipProg") ' Nz(ReadParametar("CFG_Lokal", "ZipProg"), "C:\Program Files\7-Zip\7z.exe")
 If FileExists(ZipProg) Then
  ZipCMD = ZipProg & " a " & ZIPFileName & " " & FileNameToZip
 
  retVal = shell(ZipCMD, vbNormalFocus)
 Else
  ' ZipCMD = "COMPACT /c"
  MsgBox "Ne postoji ZIP program " & vbCrLf & ZipProg, vbCritical, "QMegaTeh"
 End If
 
 ZipFile = retVal
exit_Func:
 
Exit Function

err_Func:
    BBErrorMSG err, "ZipFile"
    retVal = 0
    GoTo exit_Func:
End Function
Public Function SelectFolder(Optional InpInitialFileName As String = "") As Variant
'***************************************************************************
' Za rad ove procedure je potrebno  Microsoft Office 14.0 Object library
'***************************************************************************
Dim dlgImeFajla As FileDialog
Dim retVal As Variant
Dim varFile As Variant


    Set dlgImeFajla = Application.FileDialog(msoFileDialogFolderPicker)
    
    ' Korisnik može da bira samo jedan fajl
    dlgImeFajla.AllowMultiSelect = False
    dlgImeFajla.Title = "QMegaTeh"
    dlgImeFajla.InitialFileName = InpInitialFileName
    ' Poništi postojeæi filter i postavi novi
    ' dlgImeFajla.Filters.Clear
    '****************
    ' Show the dialog box. If the .Show method returns True, the
      ' user picked at least one file. If the .Show method returns
      ' False, the user clicked Cancel.
      If dlgImeFajla.Show = True Then

         'Loop through each file selected and add it to our list box.
         For Each varFile In dlgImeFajla.SelectedItems
            retVal = varFile
            'Me.FileList.AddItem varFile
         Next

      Else
         retVal = Null
         'MsgBox "You clicked Cancel in the file dialog box."
      End If
    '****************
    
   ' dlgImeFajla.Show
   '
   ' If dlgImeFajla.SelectedItems.Count >= 1 Then
   '     retval = dlgImeFajla.SelectedItems(1)
   ' Else
   '     retval = ""
   ' End If
    SelectFolder = retVal
    Set dlgImeFajla = Nothing
End Function
Public Function SelectFile(Optional InpInitialFileName As String = "") As Variant
'***************************************************************************
' Za rad ove procedure je potrebno  Microsoft Office 14.0 Object library
'***************************************************************************
Dim dlgImeFajla As FileDialog
Dim retVal As Variant
Dim varFile As Variant


    Set dlgImeFajla = Application.FileDialog(msoFileDialogFilePicker)
    
    ' Korisnik može da bira samo jedan fajl
    dlgImeFajla.AllowMultiSelect = False
    dlgImeFajla.Title = "QMegaTeh"
    dlgImeFajla.InitialFileName = InpInitialFileName
    ' Poništi postojeæi filter i postavi novi
    dlgImeFajla.Filters.Clear
    dlgImeFajla.Filters.Add "Access Databases", "*.MDB"
    dlgImeFajla.Filters.Add "Access Databases", "*.ACCDB"
    'dlgImeFajla.Filters.Add "Access Projects", "*.ADP"
    dlgImeFajla.Filters.Add "All Files", "*.*"
    '****************
    ' Show the dialog box. If the .Show method returns True, the
      ' user picked at least one file. If the .Show method returns
      ' False, the user clicked Cancel.
      If dlgImeFajla.Show = True Then

         'Loop through each file selected and add it to our list box.
         For Each varFile In dlgImeFajla.SelectedItems
            retVal = varFile
            'Me.FileList.AddItem varFile
         Next

      Else
         retVal = Null
         'MsgBox "You clicked Cancel in the file dialog box."
      End If
    '****************
    
   ' dlgImeFajla.Show
   '
   ' If dlgImeFajla.SelectedItems.Count >= 1 Then
   '     retval = dlgImeFajla.SelectedItems(1)
   ' Else
   '     retval = ""
   ' End If
    SelectFile = retVal
    Set dlgImeFajla = Nothing
End Function
'*****************************************************************************
Public Function XSaveAsFile(Optional InpInitialFileName As String = "") As Variant
'***************************************************************************
' Za rad ove procedure je potrebno  Microsoft Office 14.0 Object library
'***************************************************************************
Dim dlgImeFajla As FileDialog
Dim retVal As Variant
Dim varFile As Variant


    Set dlgImeFajla = Application.FileDialog(msoFileDialogSaveAs)
    
    ' Korisnik može da bira samo jedan fajl
    dlgImeFajla.AllowMultiSelect = False
    dlgImeFajla.Title = "QMegaTeh"
    dlgImeFajla.InitialFileName = InpInitialFileName
    ' Poništi postojeæi filter i postavi novi
    dlgImeFajla.Filters.Clear
    dlgImeFajla.Filters.Add "Backup files", "*.BAK"
    dlgImeFajla.Filters.Add "All Files", "*.*"
    '****************
    ' Show the dialog box. If the .Show method returns True, the
      ' user picked at least one file. If the .Show method returns
      ' False, the user clicked Cancel.
      If dlgImeFajla.Show = True Then

         'Loop through each file selected and add it to our list box.
         For Each varFile In dlgImeFajla.SelectedItems
            retVal = varFile
            'Me.FileList.AddItem varFile
         Next

      Else
         retVal = Null
         'MsgBox "You clicked Cancel in the file dialog box."
      End If
    '****************
    
   ' dlgImeFajla.Show
   '
   ' If dlgImeFajla.SelectedItems.Count >= 1 Then
   '     retval = dlgImeFajla.SelectedItems(1)
   ' Else
   '     retval = ""
   ' End If
    SelectFile = retVal
    Set dlgImeFajla = Nothing
End Function
Public Function ReadTextFromFile(strFilename As String, Optional MaxLength As Long = 40000) As String
    ReadTextFromFile = ReadFileToString(strFilename, MaxLength)
End Function
Public Function ReadFileToString(strFilename As String, Optional MaxLength As Long = 40000) As String
On Error GoTo Err_Point
 '? ReadFileToString("C:\TMP\spVM_ProizvodnjaUMP.sql")
 Dim strFileContent As String
 Dim stLine As String
 Dim iFile As Integer
 Dim BrojLinija As Long
 
 strFileContent = ""
 BrojLinija = 0
 iFile = FreeFile
 Open strFilename For Input As #iFile
  
 Do While Not EOF(iFile)    ' Loop until end of file.
    'Input #iFile, stLine    ' Read data
    'stLine = Input(1, iFile) ' cita 1 znak
    'strFileContent = strFileContent & stLine
    Line Input #iFile, stLine ' Read data
    BrojLinija = BrojLinija + 1
    If Len(strFileContent) + Len(stLine) > MaxLength Then
      strFileContent = strFileContent & Left(stLine, MaxLength - Len(strFileContent))
      MsgBox "File " & strFilename & " je preveliki. (" & LOF(iFile) & " bajtova." & vbCrLf & _
              "Bice ucitano prvih " & MaxLength & " karaktera." & vbCrLf & _
              "(broj ucitanih linija = " & BrojLinija & ")", vbExclamation, "QMegaTeh"
      Exit Do
    Else
     strFileContent = strFileContent & stLine
    End If
    If Not EOF(iFile) Then
       strFileContent = strFileContent & vbCrLf
    End If
  'If BrojLinija >= 1000 Then
  '  If (BrojLinija Mod 1000) = 0 Then
  '      If Not BBPitanje("Ucitano " & BrojLinija & " linija." & vbCrLf & "Nastavljete ucitavanje?") Then
  '          Exit Do
  '      End If
  '  End If
  'End If
 Loop


' If LOF(iFile) >= 3 Then
'          strFileContent = Input(3, iFile)
'
'
'         If strFileContent = UTF8FileConstant Then
'          MsgBox "JESTE UTF8"
'          strFileContent = strFileContent & Input(LOF(iFile) - 3, iFile)
'
'         Else
'          MsgBox "NIJE UTF8"
'          strFileContent = strFileContent & Input(LOF(iFile) - 3, iFile)
'         End If
' End If
'
'    'strFileContent = Input(LOF(iFile), iFile)
    
Exit_Point:
 On Error Resume Next
 Close #iFile
 ReadFileToString = strFileContent
 
Exit Function

Err_Point:
 MsgBox "err.number: " & err.Number & vbCr & vbCr & err.Description
 Resume Exit_Point
End Function
Public Function SaveStringToFile(stFileName As String, stText As String, Optional UTF8Format As Boolean = True) As Boolean
On Error GoTo Err_Point
    Dim txtFile As Variant
    Dim retValOk As Boolean
   
    retValOk = True
    DoCmd.Hourglass True
    txtFile = FreeFile
    Open stFileName For Output As #txtFile
    'Write #txtFile, stText
    'Print #txtFile, UTF8.UTF8FileConstant
    If UTF8Format Then
     Print #txtFile, UTF8.UTF8FileConstant & UTF8.StrToUTF8(stText)
    Else
     Print #txtFile, stText
    End If
       
       
Exit_Point:
On Error Resume Next
   Close #txtFile
   DoCmd.Hourglass False
   SaveStringToFile = retValOk
 Exit Function

Err_Point:
  BBErrorMSG err, "SaveStringToFile"
  retValOk = False
  Resume Exit_Point
End Function
Public Function OpenAnyFile(stFileName As String) As Boolean
'Modifikovano: 21-12-2019
'prebaceo iz modula KSModul

On Error GoTo Err_Point
Dim shell As Object
Dim retValOk As Boolean

retValOk = True
Set shell = CreateObject("WScript.Shell")
shell.Run Chr(34) & stFileName & Chr(34), 1, False

Exit_Point:
On Error Resume Next
   OpenAnyFile = retValOk
 Exit Function

Err_Point:
  BBErrorMSG err, "OpenAnyFile"
  retValOk = False
  Resume Exit_Point
End Function
