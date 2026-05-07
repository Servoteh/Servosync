VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BBBackup"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub UradiBackup()
On Error GoTo err_Sub:
  Dim retVal
    If IsNull(Me!fileBackup) Then
        MsgBox "Nije izabran fajl za backup.", , "QMegaTeh"
        GoTo Exit_Sub
    End If
    If IsNull(Me!fileBackupDestination) Then
        MsgBox ("Nije izabran fajl u koji se kopira.")
        GoTo Exit_Sub
    End If
    If Me!fileBackup = Me!fileBackupDestination Then
        MsgBox ("Ne mozete da radite backup u isti fajl.")
        GoTo Exit_Sub
    End If
    If Not FileExists(Me!fileBackup) Then
        MsgBox ("Fajl koji zelite da kopirate ne postoji.")
        GoTo Exit_Sub
    End If
    If FileExists(Me!fileBackupDestination) Then
        If MsgBox("Fajl u koji želite da kopirate veæ postoji, da li želite da pišete preko njega?", vbYesNo + vbExclamation, "QMegaTeh") = vbNo Then
            GoTo Exit_Sub
        End If
    End If
       
        'FileCopy Me!fileBackup, Me!fileBackupDestination
        CopyFile Me!fileBackup, Me!fileBackupDestination, False
        If Me!CheckMakeZip Then
         retVal = ZipFile(Me!fileBackupDestination, Me!ZIPFileName)
        End If
        
        MsgBox "Backup je uradjen.", , "QMegaTeh"
Exit_Sub:

Exit Sub

err_Sub:
'If Err.Number = 70 Then 'Fajl je otvoren

BBErrorMSG err, "Backup"
Resume Exit_Sub:
End Sub

Private Sub SetDefaultData()
    Dim nav As String
    nav = Chr(34)
    Me!fileBackup = VezaSaBazom()
    'Me!fileBackup.DefaultValue = Me!fileBackup
    Me!fileBackupDestination = DefaultFileBackupDestination(Me!fileBackup)
    'Me!fileBackupDestination.DefaultValue = Me!fileBackupDestination
    Me!ZIPFileName = DefaultZIPFileName(Me!fileBackupDestination)
    Me!DownloadDestinationFolder = DefaultDownloadDestinationFolder()
    'Me!ZIPCmdToZip.DefaultValue = """" & Nz(ReadParametar("CFG_Lokal", "Zip2Zip"), """C:\Program Files\7-Zip\7z.exe""" & " a") & """"
    'Me!ZIPCmdToExtract.DefaultValue = nav & Nz(ReadParametar("CFG_Lokal", "Zip2Extract"), """C:\Program Files\7-Zip\7z.exe""" & " x -y -o") & nav
    'ok Me!ZIPCmdToExtract.DefaultValue = """pera"""
    Me!ZIPCmdToZip.DefaultValue = """C:\Program Files\7-Zip\7z.exe" & " a"""
End Sub
Private Function DefaultFileBackupDestination(stFileBackup As String) As String
    Dim retVal As String
    Dim stEXT As String
    stEXT = ExtFromPath(stFileBackup)
    retVal = Left$(stFileBackup, Len(stFileBackup) - Len(stEXT) - 1) & "_" & Format$(Date, "ddMMyyyy") & ".MDB"
    'retVal = FolderFromPath(stFileBackup) & FileNameFromPath(stFileBackup) & ".BAK"
    'Me!fileBackupDestination = Left$(VezaSaBazom(), Len(VezaSaBazom()) - 4) & Format$(Date, "dd-MM-yy") & ".BAK"
    DefaultFileBackupDestination = retVal
End Function
Private Function DefaultZIPFileName(stFileBackup As String) As String
    Dim retVal As String
    Dim stEXT As String
    stEXT = ExtFromPath(stFileBackup)
    retVal = Left$(stFileBackup, Len(stFileBackup) - Len(stEXT) - 1) & ".ZIP"
    DefaultZIPFileName = retVal
End Function
Private Function DefaultDownloadDestinationFolder() As String
    Dim retVal As String

    retVal = Nz(ReadParametar("CFG_Lokal", "DownloadDestinationFolder"), "\\tsclient\C\")
    retVal = retVal & FileNameFromPath(Me!ZIPFileName)
    
    DefaultDownloadDestinationFolder = retVal
End Function

Private Sub BackupFolder_DblClick(Cancel As Integer)
   Dim IzabraniFajl As String

     IzabraniFajl = Nz(OpenFolder(Nz(Me!BackupFolder, "")), "")
     Me!BackupFolder = IIf(IzabraniFajl = "", Me!BackupFolder, IzabraniFajl)
End Sub

Private Sub BatFileName_DblClick(Cancel As Integer)
    Dim IzabraniFajl As String
    If FileExists(Nz(Me!BatFileName, "")) Then
     IzabraniFajl = Nz(OpenFile(Nz(Me!BatFileName, "")), "")
    Else
     IzabraniFajl = Nz(SaveAsFile(Nz(Me!BatFileName, "")), "")
    End If
    Me!BatFileName = IIf(IzabraniFajl = "", Me!BatFileName, IzabraniFajl)
End Sub

Private Sub DownloadDestinationFolder_DblClick(Cancel As Integer)
 Dim IzabraniFolder As String
    IzabraniFolder = Nz(SaveAsFile(Me!DownloadDestinationFolder), "")
    Me!DownloadDestinationFolder = IIf(IzabraniFolder = "", Me!DownloadDestinationFolder, IzabraniFolder)
End Sub

Private Sub DugmeUradiBackup_Click()
    UradiBackup
End Sub

Private Sub fileBackup_AfterUpdate()
    Me!fileBackupDestination = DefaultFileBackupDestination(Me!fileBackup)
    Me!ZIPFileName = DefaultZIPFileName(Me!fileBackupDestination)
End Sub

Private Sub fileBackup_DblClick(Cancel As Integer)
    Me!fileBackup = Nz(SelectFile(Me!fileBackup), Me!fileBackup)
End Sub

Private Sub fileBackupDestination_AfterUpdate()
    Me!ZIPFileName = DefaultZIPFileName(Me!fileBackupDestination)
End Sub

Private Sub fileBackupDestination_DblClick(Cancel As Integer)
 Dim IzabraniFajl As String
    IzabraniFajl = Nz(SaveAsFile(Me!fileBackupDestination), "")
    Me!fileBackupDestination = IIf(IzabraniFajl = "", Me!fileBackupDestination, IzabraniFajl)
End Sub


Private Sub Form_Open(Cancel As Integer)
   DoCmd.GoToRecord , , acLast
   SetDefaultData
End Sub
Private Sub DugmeDownload_Click()
On Error GoTo Err_DugmeDownload_Click

' If Not DirExists(Me!DownloadDestinationFolder) Then
'  MsgBox "Ne postoji putanja " & Me!DownloadDestinationFolder, vbCritical, "QMegaTeh"
'  GoTo Exit_DugmeDownload_Click
' End If
 
 If Not FileExists(Me!ZIPFileName) Then
  MsgBox "Ne postoji fajl " & Me!ZIPFileName, vbCritical, "QMegaTeh"
  GoTo Exit_DugmeDownload_Click
 End If
  
 FileCopy Me!ZIPFileName, DownloadDestinationFolder
  
Exit_DugmeDownload_Click:
    Exit Sub

Err_DugmeDownload_Click:
   ' MsgBox Err.Description
    BBErrorMSG err, "Download"
    Resume Exit_DugmeDownload_Click
    
End Sub

Private Sub DugmeNapraviFajl_Click()
On Error GoTo Err_DugmeNapraviFajl_Click

    Dim stDocName As String
    
    Me!BatCmdS = NapraviBackupFile(Me!fileBackup, Me!BackupFolder)
    Me.BatCmdS.Requery

Exit_DugmeNapraviFajl_Click:
    Exit Sub

Err_DugmeNapraviFajl_Click:
    MsgBox err.Description
    Resume Exit_DugmeNapraviFajl_Click
    
End Sub
Private Function NapraviBackupFile(stFileBackup As String, stFolderBackup As String) As String
On Error GoTo Err_NapraviBackupFile

    Dim retVal As String
    Dim ZIPFileName As String
    Dim stEXT As String
    retVal = ""
    
    stEXT = ExtFromPath(FileNameFromPath(stFileBackup))
    ZIPFileName = Left$(FileNameFromPath(stFileBackup), Len(FileNameFromPath(stFileBackup)) - Len(stEXT) - 1) & "_%Date%" & ".ZIP"
    
    
    retVal = "COPY " & stFileBackup & " " & stFolderBackup & "\" & FileNameFromPath(stFileBackup)
    retVal = retVal & vbCrLf & Me!ZIPCmdToZip & " " & stFolderBackup & "\" & ZIPFileName & " " & stFolderBackup & "\" & FileNameFromPath(stFileBackup)

   

Exit_NapraviBackupFile:
      NapraviBackupFile = retVal
    Exit Function

Err_NapraviBackupFile:
    MsgBox err.Description
    Resume Exit_NapraviBackupFile
    
End Function

