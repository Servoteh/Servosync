VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Alati"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Function FileExistsLok(strFile As String) As Boolean
  Dim i As Integer
 
  On Error Resume Next
  i = Len(Dir(strFile))
  FileExistsLok = (Not err And i > 0)

End Function

Private Sub AppMenu_Change()
 '  If Me!AppMenu = 5 And BBCFG.SQLDB Then
 '   MsgBox "Ova opcija ne radi kada je baza SQL.", vbInformation, "QMegaTeh"
 '   Exit Sub
 '  End If
   Me!AppPages.Pages(Me!AppMenu.Value).SetFocus
   If Me!AppPages.Value = 5 Then
   If BBCFG.SQLDB Then
    '"Baza je SQL."
    'Me!TextAktivniKorisnici = AktivniUseriNaSQLBazi(BBCFG.CNNString, False)
    Me!TextAktivniKorisnici = AktivniUseriNaSQLBazi(BBCFG.CNNString(), False)
   Else
    Me!TextAktivniKorisnici = AktivniUseriNaBazi(Me!PutanjaDoBazeZaUsere, False)
   End If
    DoCmd.GoToControl "PutanjaDoBazeZaUsere"
   End If
End Sub
Private Sub butBackup_Click()
'Modifikovano: 11-06-2020
'Modifikovano: 04-04-2023
On Error GoTo Err_Point
Dim retValOk As Boolean

    If IsNull(Me!fileBackup) Then
        MsgBox "Nije izabran fajl za backup.", vbExclamation, "QBigTeh"
        GoTo Exit_Point
    End If
    If IsNull(Me!fileBackupDestination) Then
        MsgBox "Nije izabran fajl u koji se kopira.", vbExclamation, "QBigTeh"
        GoTo Exit_Point
    End If
    If Me!fileBackup = Me!fileBackupDestination Then
        MsgBox "Ne mozete da radite backup u isti fajl.", vbExclamation, "QBigTeh"
        GoTo Exit_Point
    End If
     
    If Not FileExists(Me!fileBackup) And Not BBCFG.SQLDB Then
        MsgBox "Fajl koji zelite da kopirate ne postoji.", vbExclamation, "QBigTeh"
        GoTo Exit_Point
    End If
    If FileExists(Me!fileBackupDestination) Then
        If BBCFG.SQLDB Then
            If Not BBPitanje("Fajl u koji smeštate backup vec postoji." & vbCrLf & "Ovaj (novi) backup ce biti dopisan?") Then
                GoTo Exit_Point
            End If
        Else
            If Not BBPitanje("Fajl u koji zelite da kopirate vec postoji, da li zelite da pisete preko njega?") Then
                GoTo Exit_Point
            End If
        End If
    End If

   'FileCopy Me!fileBackup, Me!fileBackupDestination
   Me!Backup_Poruka.Visible = True 'Saèekajte...
   
   BBTimerStart
   
   If BBCFG.SQLDB Then
      retValOk = BackupCurrentSQLDB(Me!fileBackupDestination)
      'retValOk = True 'Zato što vraca False iako je backup uspešan!!!!!!
      'retValOk = FileExists(Me!fileBackupDestination)
      
   Else
    shell "CMD /C copy /Y """ & Me!fileBackup & """ """ & Me!fileBackupDestination & """"
    retValOk = True
   End If
  
  If retValOk Then
   Me!Backup_Poruka = "Backup je uradjen (" & BBTimerTrajanjeSec & ")"
   MsgBox Me!Backup_Poruka, vbInformation, "QMegaTeh"
  Else
   Me!Backup_Poruka = "Backup nije uradjen"
   MsgBox Me!Backup_Poruka, vbExclamation, "QMegaTeh"
  End If

Exit_Point:
On Error Resume Next
    Me!Backup_Poruka.Visible = False
Exit Sub
Err_Point:
 BBErrorMSG err, "butBackup_Click"
 Resume Exit_Point
End Sub

Private Sub butCompact_Click()
Dim errloop
Dim f As Integer
Dim cDB As DAO.Database
    Set cDB = CurrentDb

    If IsNull(Me!fileCompact) Then
        MsgBox ("Nije izabran fajl")
        GoTo done
        End If
    If Me!fileCompact = cDB.Name Then
        MsgBox ("Ne moze se kompactovati aktivna baza")
        GoTo done
        End If
    If MsgBox("Da li da uradim kompact za " & Me!fileCompact & " bazu?", _
            vbYesNo) = vbYes Then
        'On Error GoTo Err_Compact
        
        If FileExists(Mid(Me!fileCompact, 1, Len(Me!fileCompact) - 3) & "bak") Then
            Kill Mid(Me!fileCompact, 1, Len(Me!fileCompact) - 3) & "bak"
            End If
        Name Me!fileCompact As Mid(Me!fileCompact, 1, Len(Me!fileCompact) - 3) & "bak"
        
        If IsNull(Me!CheckDecrypt) Then
           DBEngine.CompactDatabase Mid(Me!fileCompact, 1, Len(Me!fileCompact) - 3) & "bak", Me!fileCompact
        ElseIf Me!CheckDecrypt Then
           DBEngine.CompactDatabase Mid(Me!fileCompact, 1, Len(Me!fileCompact) - 3) & "bak", Me!fileCompact, , dbDecrypt
        Else
           DBEngine.CompactDatabase Mid(Me!fileCompact, 1, Len(Me!fileCompact) - 3) & "bak", Me!fileCompact, , dbEncrypt
        End If
        
        MsgBox "Compact je uradjen!, Nekompaktovan fajl je snimljen kao: " & Mid(Me!fileCompact, 1, Len(Me!fileCompact) - 3) & "bak"
    
        f = FreeFile
        Open Me!fileCompact For Binary Shared As #f
        Me!SizeAfter = LOF(f)
        Close f
        Me!PercentCompaction = (Me!SizeBefore - Me!SizeAfter) / Me!SizeBefore

    End If
    Set cDB = Nothing
    Exit Sub

Err_Compact:

    For Each errloop In DBEngine.Errors
        MsgBox "Compaction unsuccessful!" & vbCr & _
            "Error number: " & errloop.Number & _
            vbCr & errloop.Description

    Next errloop

done:
Set cDB = Nothing
End Sub

Private Sub butCompile_Click()

'    On Error GoTo ErrorHandler
    
    MsgBox ("Please wait while the system is compiled.")
    'DoCmd.Echo False
    Application.Echo False
    
    'Open this form in design view
    RunCommand acCmdDesignView
    RunCommand acCmdViewCode
    
    'compile
    RunCommand acCmdCompileAndSaveAllModules
    
    'close design view and return to form view
    DoCmd.Close
    RunCommand acCmdFormView
    BBOpenForm "Alati"
    
    ' DoCmd.Echo True
    Application.Echo True
    
    'done with compile
    If IsCompiled() Then
        MsgBox ("Ovaj program je kompajliran." & vbCrLf & "Sada morate da uradite compact za njega da biste maksimalno poboljsali performanse.")
    Else
        MsgBox ("Ovaj program se ne može uspešno kompajlirati." & vbCrLf & "Proverite greske koje se javljaju i pokušajte ponovo.")
    End If
    GoTo done

ErrorHandler:
    MsgBox err.Description

done:

End Sub

Private Sub butRepair_Click()
Dim errloop
    If IsNull(Me!fileRepair) Then
        MsgBox ("No file selected")
        GoTo done
        End If

    If MsgBox("Da uradim repair na " & Me!fileRepair & " bazi?", _
            vbYesNo) = vbYes Then
        On Error GoTo Err_Repair
        DBEngine.RepairDatabase Me!fileRepair
        MsgBox "Repair zavrsen!"
    End If

    Exit Sub

Err_Repair:

    For Each errloop In DBEngine.Errors
        MsgBox "Repair unsuccessful!" & vbCr & _
            "Error number: " & errloop.Number & _
            vbCr & errloop.Description

    Next errloop


done:

End Sub

Private Sub PodesiCaptionCompact()
  Dim strCaption As String
  Dim strNewLine As String
    strNewLine = Chr(13) & Chr(10)
   strCaption = "Uradi compact"
   If IsNull(Me!CheckDecrypt) Then
    
   ElseIf Me!CheckDecrypt Then
    strCaption = strCaption & strNewLine & "+" & strNewLine & "dbDecrypt"
   Else
    strCaption = strCaption & strNewLine & "+" & strNewLine & "dbEncrypt"
   End If
   
    Me!butCompact.Caption = strCaption
End Sub

Private Sub CheckDecrypt_AfterUpdate()
    PodesiCaptionCompact
End Sub
Private Function F_IzaberiBackupDestination(stInicFileName As String) As String

On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stRetVal As String

retValOk = True
stRetVal = SaveAsFile(stInicFileName)

If stRetVal = "" Then
    stRetVal = stInicFileName
End If

Exit_Point:
 On Error Resume Next
       F_IzaberiBackupDestination = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "F_IzaberiBackupDestination"
 retValOk = False
 Resume Exit_Point

End Function
Private Sub fileBackupDestination_DblClick(Cancel As Integer)
    Me!fileBackupDestination = F_IzaberiBackupDestination(Me!fileBackupDestination)
End Sub

Private Sub fileCompact_Enter()
    Me!SizeBefore = ""
    Me!SizeAfter = ""
    Me!PercentCompaction = ""
End Sub

Private Sub fileCompact_Exit(Cancel As Integer)
 On Error Resume Next
    If IsNull(Me!fileCompact) Then GoTo done
    Dim f As Integer
    f = FreeFile
    Open Me!fileCompact For Binary Shared As #f
    Me!SizeBefore = LOF(f)
    Me!SizeAfter = ""
    Me!PercentCompaction = ""
    Close f
done:
End Sub

Private Sub Form_Load()
        
        Me!AppPages.Style = 2
If BBCFG.SQLDB Then
          Me!fileBackupDestination = ReadCFGParametar("BackupDestinationFolder", "") & "\" & GetParFromCnnString("DATABASE=", BBCFG.CNNString)
          Me!fileBackupDestination = Me!fileBackupDestination & "_" & Format(Date, "yyyyMMdd") & "_" & Format(Time(), "hhmmss") & ".bak"
Else
         Me!fileBackupDestination = Left$(Me.OpenArgs, Len(Me.OpenArgs) - 4) & Date & ".BAK"
        'Me!fileBackupDestination = Left$(VezaSaBazom(),Len(VezaSaBazom())-4) & Date() & ".BAK"
End If

'if passed argument then limit all functions to passed file
    If Not IsNull(Me.OpenArgs) Then
        Me!fileBackup = Me.OpenArgs
        Me!fileCompact = Me.OpenArgs
        Me!fileRepair = Me.OpenArgs
        'If BBCFG.SQLDB Then
        '  Me!fileBackupDestination = ReadCFGParametar("BackupDestinationFolder", "") & "\" & GetParFromCnnString("DATABASE=", BBCFG.CNNString) & ".bak"
        'Else
        ' Me!fileBackupDestination = Left$(Me.OpenArgs, Len(Me.OpenArgs) - 4) & Date & ".BAK"
        ''Me!fileBackupDestination = Left$(VezaSaBazom(),Len(VezaSaBazom())-4) & Date() & ".BAK"
        'End If
        
        Me!fileBackup.Locked = True
        Me!fileCompact.Locked = True
        Me!fileRepair.Locked = True
    End If
        
    If IsCompiled() Then
        Me!CompileMessage.Caption = "Ovaj program je kompajliran. Dodatne akcije nisu potrebne."
        Me!butCompile.Visible = False
    Else
        Me!CompileMessage.Caption = "Program je u nekompajliranom stanju." & vbCrLf _
                   & "To može da bude uzrok degradacije performansi." & vbCrLf _
                   & "Da li želite da kompajlirate ovaj program?"
    End If
    
    'Me!PutanjaDoBazeZaUsere = VezaSaBazom()
     If BBCFG.SQLDB Then
       Me!PutanjaDoBazeZaUsere = Replace(BBCFG.CnnStringBezPWD, "ODBC;", "")
     Else
       Me!PutanjaDoBazeZaUsere = VezaSaBazom()
     End If
    
    PodesiCaptionCompact
End Sub

Private Sub Form_Open(Cancel As Integer)
'REM Call BB_PravaPristupaPodesiFormu(Me)
    ' DoCmd.Restore
   On Error Resume Next
   If CDbl(SysCmd(acSysCmdAccessVer)) > 8# Then
    butRepair.Enabled = False
   Else
    butRepair.Enabled = True
   End If
   If BBCFG.SQLDB Then
    '11-06-2020 butBackup.Enabled = False
    butCompact.Enabled = False
   End If
End Sub

Private Sub PutanjaDoBazeZaUsere_AfterUpdate()
  If BBCFG.SQLDB Then
    '"Baza je SQL."
    'Me!TextAktivniKorisnici = AktivniUseriNaSQLBazi(BBCFG.CNNString, False)
    Me!TextAktivniKorisnici = AktivniUseriNaSQLBazi(Me!PutanjaDoBazeZaUsere, False)
   Else
    Me!TextAktivniKorisnici = AktivniUseriNaBazi(Me!PutanjaDoBazeZaUsere, False)
   End If
    DoCmd.GoToControl "PutanjaDoBazeZaUsere"
End Sub

Private Sub PutanjaDoBazeZaUsere_DblClick(Cancel As Integer)

   Me!PutanjaDoBazeZaUsere = IzaberiBazu()
   
End Sub

Private Sub selBackup_Click()
    Dim lngFlags As Long
    Dim gfni As adh_accOfficeGetFileNameInfo
    
    On Error GoTo HandleErrors

    With gfni
        .lngFlags = lngFlags
        .strFilter = "All files (*.*)"
        .lngFilterIndex = CInt("1")
        .strFile = ""
        .strDlgTitle = "Izaberi fajl za backup"
        .strOpenTitle = "Izaberi"
        .strFile = ""
        .strInitialDir = ""
    End With
    If adhOfficeGetFileName(gfni, True) = adhcAccErrSuccess Then
        Me!fileBackup = Trim(gfni.strFile)
    End If
    
ExitHere:
    Exit Sub

HandleErrors:
    MsgBox "Error: " & err.Description & " (" & err.Number & ")"
    Resume ExitHere

End Sub

Private Sub selBackupDestination_Click()
    Dim lngFlags As Long
    Dim gfni As adh_accOfficeGetFileNameInfo
    
       
    On Error GoTo HandleErrors

    With gfni
        .lngFlags = lngFlags
        .strFilter = "All Files (*.*)"
        .lngFilterIndex = CInt("1")
        .strFile = ""
        .strDlgTitle = "Select destination for backup"
        .strOpenTitle = "Select"
        .strFile = ""
        .strInitialDir = ""
    End With
    If adhOfficeGetFileName(gfni, True) = adhcAccErrSuccess Then
        Me!fileBackupDestination = Trim(gfni.strFile)
    End If
    
ExitHere:
    Exit Sub

HandleErrors:
    MsgBox "Error: " & err.Description & " (" & err.Number & ")"
    Resume ExitHere

End Sub

Private Sub selCompact_Click()
Dim f As Integer
Dim lngFlags As Long
Dim gfni As adh_accOfficeGetFileNameInfo
    
    On Error GoTo HandleErrors

    With gfni
        .lngFlags = lngFlags
        .strFilter = "MDB Files (*.mdb)"
        .lngFilterIndex = CInt("1")
        .strFile = ""
        .strDlgTitle = "Select a file to compact"
        .strOpenTitle = "Select"
        .strFile = ""
        .strInitialDir = ""
    End With
    If adhOfficeGetFileName(gfni, True) = adhcAccErrSuccess Then
        Me!fileCompact = Trim(gfni.strFile)
        f = FreeFile
        Open Me!fileCompact For Binary Shared As #f
        Me!SizeBefore = LOF(f)
        Me!SizeAfter = ""
        Me!PercentCompaction = ""
        Close f
    End If
    
ExitHere:
    Exit Sub

HandleErrors:
    MsgBox "Error: " & err.Description & " (" & err.Number & ")"
    Resume ExitHere

End Sub
Private Sub selRepair_Click()

    Dim lngFlags As Long
    Dim gfni As adh_accOfficeGetFileNameInfo
    
    On Error GoTo HandleErrors

    With gfni
        .lngFlags = lngFlags
        .strFilter = "MDB Files (*.mdb)"
        .lngFilterIndex = CInt("1")
        .strFile = ""
        .strDlgTitle = "Select a file to repair"
        .strOpenTitle = "Select"
        .strFile = ""
        .strInitialDir = ""
    End With
    If adhOfficeGetFileName(gfni, True) = adhcAccErrSuccess Then
        Me!fileRepair = Trim(gfni.strFile)
    End If
    
ExitHere:
    Exit Sub

HandleErrors:
    MsgBox "Error: " & err.Description & " (" & err.Number & ")"
    Resume ExitHere

End Sub

Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click


    DoCmd.Close

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
    
End Sub

Private Sub TextAktivniKorisnici_DblClick(Cancel As Integer)
  If BBCFG.SQLDB Then
    '"Baza je SQL."
    'Me!TextAktivniKorisnici = AktivniUseriNaSQLBazi(BBCFG.CNNString, False)
    Me!TextAktivniKorisnici = AktivniUseriNaSQLBazi(Me!PutanjaDoBazeZaUsere, False)
   Else
    Me!TextAktivniKorisnici = AktivniUseriNaBazi(Me!PutanjaDoBazeZaUsere, False)
   End If
    DoCmd.GoToControl "PutanjaDoBazeZaUsere"
End Sub
