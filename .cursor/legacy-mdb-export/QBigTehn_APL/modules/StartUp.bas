Attribute VB_Name = "StartUp"
Option Compare Database
Option Explicit
Public Function AutoExec()
 Dim startFormName As String
 startFormName = Nz(Command(), "")
 ' If Nz(Command(), "") <> "" Then
 ' Call BBStart(Command())
 'End If
 If startFormName = "Z" Then
    DoCmd.OpenForm "Zastita"
 Else
  BBStart startFormName
 End If
End Function
Public Function GetCommandLine(Optional MaxArgs)
    'Declare variables.
    Dim c, cmdLine, CmdLnLen, InArg, i, NumArgs
    'See if MaxArgs was provided.
    If IsMissing(MaxArgs) Then MaxArgs = 10
    'Make array of the correct size.
    ReDim ArgArray(MaxArgs)
    NumArgs = 0: InArg = False
    'Get command line arguments.
    cmdLine = Command()
    CmdLnLen = Len(cmdLine)
    'Go thru command line one character
    'at a time.
    For i = 1 To CmdLnLen
        c = Mid(cmdLine, i, 1)
        'Test for space or tab or ...
        If (c <> " " And c <> vbTab And c <> "," And c <> ";") Then
            'Neither space nor tab.
            'Test if already in argument.
            If Not InArg Then
            'New argument begins.
            'Test for too many arguments.
                If NumArgs = MaxArgs Then Exit For
                NumArgs = NumArgs + 1
                InArg = True
            End If
            'Concatenate character to current argument.
            ArgArray(NumArgs) = ArgArray(NumArgs) & c
        Else
            'Found a space or tab.
            'Set InArg flag to False.
            InArg = False
        End If
    Next i
    'Resize array just enough to hold arguments.
    ReDim Preserve ArgArray(NumArgs)
    'Return Array in Function name.
    GetCommandLine = ArgArray()
End Function
Public Sub TestGetCommandLine(a As Variant)
 'Dim a As Variant
 Dim i As Integer
 
 'a = GetCommandLine()
 If IsArray(a) Then
  For i = 1 To UBound(a)
   Debug.Print "a(" & i & ")=" & a(i)
  Next i
 Else
  Debug.Print "Nije niz"
 End If
End Sub

Public Function IntroComment(stComment As String)
On Error GoTo Err_Point

If IsLoaded("Intro") Then
    If Nz(Forms!Intro!OpisPoslaKojiSeRadi, "") = "" Then
     Forms!Intro!OpisPoslaKojiSeRadi = stComment
    Else
     Forms!Intro!OpisPoslaKojiSeRadi = Forms!Intro!OpisPoslaKojiSeRadi & "   ->  " & BBTimerTrajanjeSec() & Chr(13) & Chr(10)
     Forms!Intro!OpisPoslaKojiSeRadi = Forms!Intro!OpisPoslaKojiSeRadi & stComment
    End If
 Forms!Intro.Repaint
 'Forms!Intro!OpisPoslaKojiSeRadi.SetFocus
End If

Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "IntroComment"
 Resume Exit_Point
End Function
Public Function Postavi_Lokal_CFG() As Boolean
'Kreirano: 14-01-2021
'Modifikovano: 21-10-2021
'Modifikovano: 28-10-2021 Uvek se forsira link!
On Error GoTo Err_Point

    Dim stLokalFileName As String
    Dim retValOk As Boolean

 retValOk = True
 
 '28-10-2021 If Not Nz(ReadParametar("CFG_Sys", "SysSuspendForsirajLink_BB_CFG_Lokal"), False) Then
 
    stLokalFileName = FindFile(CurrentProject.Path & "\BB_CFG_Lokal.MDB") 'trazi ga u  direktorijumu
    If FileExists(stLokalFileName) Then
     'retValOk = ForsirajNoveLinkoveZaTipBaze_NETREBA_20102021("LOKAL_CFG", stLokalFileName)
     retValOk = ForsirajNoveLinkoveZaIDBaze(IDBazeZaTipBaze("LOKAL_CFG"), stLokalFileName)
     'Ovde uskladjujemo CNN_CFG_Lokal sa linkovima
        If retValOk Then 'ako je forsiranje proslo TRUE
           CNN_CFG_Lokal = CreateAccess_CNNString(stLokalFileName)
           retValOk = BBCreateProperty("CNN_CFG_Lokal", , CNN_CFG_Lokal) 'kreira ga ili mu menja vrednost
           retValOk = retValOk And UpisiNoviCNNStringZaTipBaze("LOKAL_CFG", stLokalFileName) 'Ipak upisujemo bazu jer je Access
        End If
    Else
      retValOk = False 'ne postoji ocekivani lokalni fajl
    End If
 
 '28-10-2021 End If
  
 
Exit_Point:
 On Error Resume Next
 Postavi_Lokal_CFG = retValOk
 
Exit Function

Err_Point:
 BBErrorMSG err, "Postavi_Lokal_CFG"
 Resume Exit_Point
End Function
Public Function Postavi_Lokal_TMP() As Boolean
'Kreirano: 14-01-2021
'Modifikovano: 21-10-2021
'Modifikovano: 28-10-2021 Uvek se forsira link!
On Error GoTo Err_Point

    Dim stLokalFileName As String
    Dim retValOk As Boolean

 retValOk = True
 
 '28-10-2021 If Not Nz(ReadParametar("CFG_Sys", "SysSuspendForsirajLink_BB_TMP"), False) Then
    stLokalFileName = FindFile(CurrentProject.Path & "\BB_TMP.MDB") 'trazi ga u  direktorijumu
    If FileExists(stLokalFileName) Then
     retValOk = ForsirajNoveLinkoveZaIDBaze(IDBazeZaTipBaze("TMP"), stLokalFileName)
     'Ovde uskladjujemo CNN_TempDB sa linkovima
        If retValOk Then 'ako je forsiranje proslo TRUE
           CNN_TempDB = CreateAccess_CNNString(stLokalFileName)
           retValOk = BBCreateProperty("CNN_TempDB", , CNN_TempDB) 'kreira ga ili mu menja vrednost
           retValOk = retValOk And UpisiNoviCNNStringZaTipBaze("TMP", stLokalFileName) 'Ipak upisujemo bazu jer je Access
        End If
    Else
      retValOk = False 'ne postoji ocekivani lokalni fajl
    End If
 '28-10-2021 End If
  
 
Exit_Point:
 On Error Resume Next
 Postavi_Lokal_TMP = retValOk
 
Exit Function

Err_Point:
 BBErrorMSG err, "Postavi_Lokal_TMP"
 Resume Exit_Point
End Function
Private Function RefreshDaoLink()
Dim retValOk

    retValOk = ForsirajNoviLinkZaTabelu("_T_Rev", SourceTableNameZaTabelu("_T_Rev"), "ODBC;" & CNN_CurrentDataBase())
    'retValOk = ForsirajNoviLinkZaTabelu("es_order", SourceTableNameZaTabelu("es_order"), "ODBC;" & CNN_ESDB)
    'retvalok = ForsirajNoviLinkZaTabelu("ODBC_Synch_Request", SourceTableNameZaTabelu("ODBC_Synch_Request"), "ODBC;" & CNN_MasterDB)
    
End Function
Public Function BBStart_OLD(Optional startFormName As String = "") As Boolean
'Modifikovano: 18-01-2021
'Modifikovano: 27-10-2021
'Modifikovano: 28-10-2021
'Modifikovano: 04-11-2021
'Modifikovano: 10-01-2022 => Dim FinalStartFormName As String preneto u [Bliski susret]
' On Error Resume Next

    Dim stComment As String
    '10-01-2022  Dim FinalStartFormName As String
    Dim StartTime As Single
    
    StartTime = Timer
    BBTimerStart
    DoCmd.OpenForm "Intro"
    DoCmd.RepaintObject acForm, "Intro"
    
    IntroComment "F_CheckBBFIT"
    Call F_CheckBBFIT
    
    IntroComment "Postavi_Lokal_CFG"
    Postavi_Lokal_CFG
    
    IntroComment "Postavi_Lokal_TMP"
    Postavi_Lokal_TMP
    
    IntroComment "RefreshDaoLink"
    RefreshDaoLink
    
    Set BBCFG = Nothing
    AktivnaFirma = ""
   
    IntroComment "RegSQLAccess_Login"
    BBCFG.SQLAccess_Login_ID = RegSQLAccess_Login(CNN_CurrentDataBase, F_FirmaZaBaze(), False)


    If ReadParametar("CFG_Sys", "SysVodiDnevnik") Then
        UpisiUDnevnik Environ("COMPUTERNAME") & "/" & CurrentUser, "BBStart", "<BigBit>", "Start"
    End If
    
    If Zastita.Zasticen Then
        QuitBigBit
    End If
    
    IntroComment "PrikaziLoseReference"
    PrikaziLoseReference
    
    IntroComment "SetStartupProperties"
    SetStartupProperties
    
    IntroComment "SetStartupProperties"
    If Not F_CheckLink("Radni fajlovi") Then
        'BBOpenForm "Baze"
        DoCmd.Close acForm, "Intro"
        BBMsgBox_BigBit "Nemate konekciju sa bazom!", , , vbRed
        DoCmd.OpenForm "Baze"
        Exit Function
    End If
    
    '*******************************************************************************************
    'Ukinuto: 27-10-2021 odavde
    '*******************************************************************************************
    'IntroComment "IDAktivneBaze"
    'Set db = CurrentDb
    'Set rstRadniFajlovi = db.OpenRecordset("Radni fajlovi", dbOpenDynaset)
    '
    'connectSTR = db.TableDefs("R_Tarife").Connect
    'connectSTR = Right$(connectSTR, Len(connectSTR) - InStr(1, connectSTR, "="))
    '
    'rstRadniFajlovi.FindFirst "[Naziv baze] = '" & connectSTR & "'"
    'If rstRadniFajlovi.NoMatch Then
    '   IDAktivneBaze = 0
    'Else
    '   IDAktivneBaze = rstRadniFajlovi("IDBaze") 'globalna promenljiva
    'End If

    'rstRadniFajlovi.Close
    'Set rstRadniFajlovi = Nothing
    'db.Close
    'Set db = Nothing
    
    'IntroComment "InicSPECIJAL"
    'varRet = InicSPECIJAL()
    
    '*******************************************************************************************
    'Ukinuto: 27-10-2021 dovde
    '*******************************************************************************************
    
    IntroComment "PostaviGlobalneParametre"
    PostaviGlobalneParametre
    
    IntroComment "RegUser (0)"
    RegUser (0) 'u stvari se ne izvršava ništa
    
    'Samo da se inicijalizuje BBCFG
    IntroComment "AppName=" & BBCFG.AppName
    
    '27-10-2023
        EnableOrDisableHistoryTriggersRoba
    
    
    IntroComment "StartnoZakljucavanjeRoba"
    StartnoZakljucavanjeRoba
    
    IntroComment "StartnoZakljucavanjeGK"
    StartnoZakljucavanjeGK
    
    IntroComment "P_PorukeTimerForm"
    If F_ProveraPorukaInterval > 0 Then BBOpenForm "P_PorukeTimerForm"
    
    IntroComment "FP_Server"
    If F_ServerZaGaleb Then BBOpenForm "FP_Server", , , , , acHidden
    
    'Ovde se završava SVE pre pokretanja startne forme
    '**********************************************************************
    
    IntroComment "FinalStartFormName"
    'Pocinjemo od argumenta funkcije BBStart
    FinalStartFormName = Trim(Nz(startFormName, ""))
    'ako je on = "" onda citamo Command() parametar /CMD
    If Nz(FinalStartFormName, "") = "" Then
     FinalStartFormName = Trim(Nz(Command(), ""))
    End If
    
    'ako je on = "" onda Citamo "CFG_Lokal"
    If Nz(FinalStartFormName, "") = "" Then
     FinalStartFormName = Trim(Nz(ReadParametar("CFG_Lokal", "StartFormName"), ""))
    End If
    
    stComment = "QBigTeh Start total time = " & Timer - StartTime & " sec."
    IntroComment stComment
    
    'If CurrentUser() = "Negovan" Then
       BBStart_LogText = Forms!Intro!OpisPoslaKojiSeRadi
       'MsgBox Forms!Intro!OpisPoslaKojiSeRadi, , "QBigTeh"
    'End If
    
    
    
        
    IntroComment "Close Form Intro"
    DoCmd.Close acForm, "Intro"
    
    'pa ako postoji forma sa imenom FinalStartFormName onda je otvaramo
    If Nz(FinalStartFormName, "") <> "" Then
     If PostojiForma(FinalStartFormName) Then
        BBOpenForm FinalStartFormName
     ElseIf CurrentUser() = "Negovan" Then 'inaèe obaveštavamo samo usera Negovan da forma ne postoji
        BBMsgBox_BigBit "Ne postoji forma " & FinalStartFormName
     End If
    End If

    BBStart_OLD = True
    
End Function
Public Function BBStart(Optional startFormName As String = "") As Boolean
'Modifikovano: 18-01-2021
'Modifikovano: 27-10-2021
'Modifikovano: 28-10-2021
'Modifikovano: 04-11-2021
'Modifikovano: 10-01-2022 => Dim FinalStartFormName As String preneto u [Bliski susret]
' On Error Resume Next

    Dim stComment As String
    '10-01-2022  Dim FinalStartFormName As String
    Dim StartTime As Single
    
    StartTime = Timer
    BBTimerStart
    DoCmd.OpenForm "Intro"
    DoCmd.RepaintObject acForm, "Intro"
    
    IntroComment "F_CheckBBFIT"
    Call F_CheckBBFIT
    
    IntroComment "Postavi_Lokal_CFG"
    Postavi_Lokal_CFG
    
    IntroComment "Postavi_Lokal_TMP"
    Postavi_Lokal_TMP
    
    IntroComment "RefreshDaoLink"
    RefreshDaoLink
    
    Set BBCFG = Nothing
    AktivnaFirma = ""
   
    IntroComment "RegSQLAccess_Login"
    BBCFG.SQLAccess_Login_ID = RegSQLAccess_Login(CNN_CurrentDataBase, F_FirmaZaBaze(), False)


    If ReadParametar("CFG_Sys", "SysVodiDnevnik") Then
        UpisiUDnevnik Environ("COMPUTERNAME") & "/" & CurrentUser, "BBStart", "<BigBit>", "Start"
    End If
    
    If Zastita.Zasticen Then
        QuitBigBit
    End If
    
    IntroComment "PrikaziLoseReference"
    PrikaziLoseReference
    
    IntroComment "SetStartupProperties"
    SetStartupProperties
    
    IntroComment "SetStartupProperties"
    'If Not F_CheckLink("Radni fajlovi") Then  '_T_Rev
    If Not F_CheckLink("_T_Rev") Then
        'BBOpenForm "Baze"
        DoCmd.Close acForm, "Intro"
        BBMsgBox_BigBit "Nemate konekciju sa bazom!", , , vbRed
         DoCmd.OpenForm "Baze"
        Exit Function
    End If
    
    '*******************************************************************************************
    'Ukinuto: 27-10-2021 odavde
    '*******************************************************************************************
    'IntroComment "IDAktivneBaze"
    'Set db = CurrentDb
    'Set rstRadniFajlovi = db.OpenRecordset("Radni fajlovi", dbOpenDynaset)
    '
    'connectSTR = db.TableDefs("R_Tarife").Connect
    'connectSTR = Right$(connectSTR, Len(connectSTR) - InStr(1, connectSTR, "="))
    '
    'rstRadniFajlovi.FindFirst "[Naziv baze] = '" & connectSTR & "'"
    'If rstRadniFajlovi.NoMatch Then
    '   IDAktivneBaze = 0
    'Else
    '   IDAktivneBaze = rstRadniFajlovi("IDBaze") 'globalna promenljiva
    'End If

    'rstRadniFajlovi.Close
    'Set rstRadniFajlovi = Nothing
    'db.Close
    'Set db = Nothing
    
    'IntroComment "InicSPECIJAL"
    'varRet = InicSPECIJAL()
    
    '*******************************************************************************************
    'Ukinuto: 27-10-2021 dovde
    '*******************************************************************************************
    
    IntroComment "PostaviGlobalneParametre"
    PostaviGlobalneParametre
    
    IntroComment "RegUser (0)"
    RegUser (0) 'u stvari se ne izvršava ništa
    
    'Samo da se inicijalizuje BBCFG
    IntroComment "AppName=" & BBCFG.AppName
    
    '27-10-2023
    '    EnableOrDisableHistoryTriggersRoba
    
    
  '  IntroComment "StartnoZakljucavanjeRoba"
  '  StartnoZakljucavanjeRoba
    
  '  IntroComment "StartnoZakljucavanjeGK"
  '  StartnoZakljucavanjeGK
    
    IntroComment "P_PorukeTimerForm"
    If F_ProveraPorukaInterval > 0 Then BBOpenForm "P_PorukeTimerForm"
    
   ' IntroComment "FP_Server"
   ' If F_ServerZaGaleb Then BBOpenForm "FP_Server", , , , , acHidden
    
    'Ovde se završava SVE pre pokretanja startne forme
    '**********************************************************************
    
    IntroComment "FinalStartFormName"
    'Pocinjemo od argumenta funkcije BBStart
    FinalStartFormName = Trim(Nz(startFormName, ""))
    'ako je on = "" onda citamo Command() parametar /CMD
    If Nz(FinalStartFormName, "") = "" Then
     FinalStartFormName = Trim(Nz(Command(), ""))
    End If
    
    'ako je on = "" onda Citamo "CFG_Lokal"
    If Nz(FinalStartFormName, "") = "" Then
     FinalStartFormName = Trim(Nz(ReadParametar("CFG_Lokal", "StartFormName"), ""))
    End If
    
    stComment = "QMegaTeh Start total time = " & Timer - StartTime & " sec."
    IntroComment stComment
    
    'If CurrentUser() = "Negovan" Then
       BBStart_LogText = Forms!Intro!OpisPoslaKojiSeRadi
       'MsgBox Forms!Intro!OpisPoslaKojiSeRadi, , "MegaAPL"
    'End If
    
    'If PromeniRibbon("GlavniMeni") Then
    '    IntroComment "Promenjen Ribbon na: " & "GlavniMeni"
    'Else
    '    IntroComment "Ribbon nije promenjen na: " & "GlavniMeni"
    'End If
    
        
    IntroComment "Close Form Intro"
    DoCmd.Close acForm, "Intro"
    
     ' 1) Resetuj na default ribbon (osnovni / prazan iz Options)
    'DoCmd.ShowToolbar "Ribbon", acToolbarYes
    'CommandBars.ExecuteMso "MinimizeRibbon"   ' sakrij
    'CommandBars.ExecuteMso "MinimizeRibbon"   ' ponovo prikaži da osveži
    
    'pa ako postoji forma sa imenom FinalStartFormName onda je otvaramo
    If Nz(FinalStartFormName, "") <> "" Then
     If PostojiForma(FinalStartFormName) Then
        BBOpenForm FinalStartFormName
     ElseIf CurrentUser() = "Negovan" Then 'inaèe obaveštavamo samo mena (kao usera) da forma ne postoji
        BBMsgBox_BigBit "Ne postoji forma " & FinalStartFormName
     End If
    End If
    
    BBStart = True
    
End Function

Public Sub SetStartupProperties()
'Modifikovano: 17-12-2020
'Ovde NE moraju da budu dostupne CFG tabele
On Error GoTo Err_Point
 
 'Dim propVal As Boolean
 
    ChangeProperty "AppTitle", dbText, "QMegaTeh"
    'ChangeProperty "StartupForm", dbText, "Prva maska"
    ChangeProperty "StartupShowDBWindow", dbBoolean, False
    ChangeProperty "StartupShowStatusBar", dbBoolean, True
    ChangeProperty "AllowBuiltinToolbars", dbBoolean, True
    
    'propVal = CBool(ReadCFGParametar("AllowFullMenus", True))
    'propVal = CBool(Nz(ReadParametar("CFG_Lokal", "AllowFullMenus"), True))
    'ChangeProperty "AllowFullMenus", dbBoolean, True
    ChangeProperty "AllowFullMenus", dbBoolean, False
    
    ChangeProperty "AllowBreakIntoCode", dbBoolean, False
    ChangeProperty "AllowSpecialKeys", dbBoolean, False
    
    'Ako se sledeca linija remuje onda radi postavka iz forme Info
    'tj. kada se iskljuci AllowBypassKey=false ne radi SHIFT kod startovanja APL
    'moze da bude opasno - CUVAJ SE!
    'ChangeProperty "AllowBypassKey", dbBoolean, True
    
    ChangeProperty "AllowToolbarChanges", dbBoolean, False
    
    SetOption "Confirm Record Changes", True
    SetOption "Confirm Action Queries", True
    SetOption "Confirm Document Deletions", True



Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "SetStartupProperties"
 Resume Exit_Point
End Sub
Function ChangeProperty(strPropName As String, varPropType As Variant, varPropValue As Variant) As Integer
    Dim dbs As DAO.Database, prp As DAO.Property
    Const conPropNotFoundError = 3270
    Dim Poruka As String
    Dim odgovor

    Set dbs = CurrentDb
    On Error GoTo Change_Err
    If dbs.Properties(strPropName) <> varPropValue Then
     dbs.Properties(strPropName) = varPropValue
    End If
    
    ChangeProperty = True

Change_Bye:
    dbs.Close
    Set dbs = Nothing
    Set prp = Nothing
    Exit Function

Change_Err:
    If err = conPropNotFoundError Then  ' Property not found.
    
        
        Poruka = "Property ne postoji." & vbCrLf
        Poruka = Poruka & vbCrLf
        Poruka = Poruka & "Name = " & strPropName & vbCrLf
        Poruka = Poruka & " Type = " & varPropType & vbCrLf
        Poruka = Poruka & "Value = " & varPropValue & vbCrLf
        Poruka = Poruka & vbCrLf
        Poruka = Poruka & "Da li želite da kreirate " & strPropName & "?"
        odgovor = MsgBox(Poruka, vbExclamation + vbYesNo, "QMegaTeh")
        If odgovor = vbYes Then
            'Ovde se kreira novi!
             Set prp = dbs.CreateProperty(strPropName, _
                     varPropType, varPropValue)
             dbs.Properties.Append prp
             ChangeProperty = True
        Else
             ChangeProperty = False
        End If
        Resume Next
    Else
        ' Unknown error.
        BBErrorMSG err, "ChangeProperty"
        ChangeProperty = False
        Resume Change_Bye
    End If
End Function
Public Function ExecCMD()
    Dim cmdLine As String
    
    cmdLine = Command
    
    If Nz(cmdLine, "") <> "" Then
        BBOpenForm cmdLine
    Else
        'DoCmd.Quit
        QuitBigBit
    End If
End Function
Public Function StartKafe()
'Dim RetVal As Boolean

    Call F_CheckBBFIT
    
    'RetVal = ForsirajLokalneLinkove()
    UpisiUDnevnik Environ("COMPUTERNAME") & "/" & CurrentUser, "StartKafe", "<BigBit>", "Start"
    
    If CurrentUser = "Konobar" Then
        BBOpenForm BBCFG.KonobarAPL ' "PrvaMaskaKOnobar"
        If ReadParametar("CFG_Global", "KafeScenario") <> "Kelvin" Then
            If Nz(ReadParametar("CFG_Lokal", "Kafe.ReklamniPanel_LogIn"), False) Then
                BBOpenForm "ReklamniPanel_LogIn"
            End If
        End If
    Else
        BBOpenForm "Tehnologija"
    End If
End Function
Public Function StartZalihe()
'Dim RetVal As Boolean

    Call F_CheckBBFIT
    'RetVal = ForsirajLokalneLinkove()
    UpisiUDnevnik Environ("COMPUTERNAME") & "/" & CurrentUser, "StartZalihe", "<BigBit>", "Start"
    If CurrentUser = "Kasa" Then
        BBOpenForm "Kasa" 'BBCFG.KonobarAPL ' "PrvaMaskaKOnobar"
    Else
        BBOpenForm "Zalihe"
    End If
End Function
Public Function QuitBigBit(Optional bQuit As Boolean = True, Optional bRegUserLogOff As Boolean = True, Optional bUpisiUDnevnik As Boolean = True)
 Dim UserIComp As String
 'On Error Resume Next
   If bRegUserLogOff Then RegUser 1
   If bUpisiUDnevnik Then
      UserIComp = Environ("COMPUTERNAME") & "/" & CurrentUser
      UpisiUDnevnik UserIComp, "QuitBigBit", "<BigBit>", "Quit"
   End If
   If bQuit Then DoCmd.Quit
End Function
Public Sub EnableOrDisableHistoryTriggersRoba()
'Kreirano: 27-10-2023
On Error GoTo Err_Point

Dim stSQLCmdENABLETrigger As String
Dim stSQLCmdDISABLETrigger As String

stSQLCmdENABLETrigger = ""
stSQLCmdDISABLETrigger = ""
   
       If fsPostojiTriger("trg_RobnaDokumenta_UpisiUHistory") Then
        stSQLCmdENABLETrigger = stSQLCmdENABLETrigger & "ENABLE TRIGGER [dbo].[trg_RobnaDokumenta_UpisiUHistory] ON  [dbo].[T_Robna dokumenta];" & vbCrLf
        stSQLCmdDISABLETrigger = stSQLCmdDISABLETrigger & "DISABLE TRIGGER [dbo].[trg_RobnaDokumenta_UpisiUHistory] ON  [dbo].[T_Robna dokumenta];" & vbCrLf
       End If
       
       If fsPostojiTriger("trg_RobneStavke_UpisiUHistory") Then
        stSQLCmdENABLETrigger = stSQLCmdENABLETrigger & "ENABLE TRIGGER [dbo].[trg_RobneStavke_UpisiUHistory] ON  [dbo].[T_Robne stavke];" & vbCrLf
        stSQLCmdDISABLETrigger = stSQLCmdDISABLETrigger & "DISABLE TRIGGER [dbo].[trg_RobneStavke_UpisiUHistory] ON  [dbo].[T_Robne stavke];" & vbCrLf
       End If

    If Nz(ReadCFGParametar("EnableHistoryTriggersRoba", False), False) Then
        If stSQLCmdENABLETrigger <> "" Then
            ADO_ExecSQL BBCFG.CNNString, stSQLCmdENABLETrigger
        End If
    Else
        If stSQLCmdDISABLETrigger <> "" Then
            ADO_ExecSQL BBCFG.CNNString, stSQLCmdDISABLETrigger
        End If
    End If


Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "EnableOrDisableHistoryTriggersRoba"
 Resume Exit_Point
End Sub

