Attribute VB_Name = "LIB_Alati"
' From Access 97 Developer's Handbook
' by Litwin, Getz, and Gilbert (Sybex)
' Copyright 1997.  All rights reserved.
    
Option Compare Database
Option Explicit

' General Errors
Public Const adhcAccErrSuccess = 0
Public Const adhcAccErrUnknown = -1

' File handling
' Sizes for buffers for SplitPath from stdlib.h
Const adhcSP_MAXPATH = 260
Const adhcSP_MAXDRIVE = 3
Const adhcSP_MAXDIR = 256
Const adhcSP_MAXFNAME = 256
Const adhcSP_MAXEXT = 256

' FileExists return values
Public Const adhcFileExistsYes = 1
Public Const adhcFileExistsNo = 0
 
 #If VBA7 Then
 Declare PtrSafe Function adh_accFileExists Lib "msaccess.exe" Alias "#57" _
 (ByVal strSrc As String) As Integer
 Declare PtrSafe Function adh_accFullPath Lib "msaccess.exe" Alias "#58" _
 (ByVal strAbsPath As String, ByVal strFullPath As String, _
 ByVal cchFullPathMax As Integer) As Integer
  Declare PtrSafe Sub adh_accSplitPath Lib "msaccess.exe" Alias "#59" _
 (ByVal strPath As String, ByVal strDrive As String, _
 ByVal strdir As String, ByVal strFName As String, ByVal strExt As String)
 #Else
 Declare PtrSafe Function adh_accFileExists Lib "msaccess.exe" Alias "#57" _
 (ByVal strSrc As String) As Integer
 Declare PtrSafe Function adh_accFullPath Lib "msaccess.exe" Alias "#58" _
 (ByVal strAbsPath As String, ByVal strFullPath As String, _
 ByVal cchFullPathMax As Integer) As Integer
  Declare PtrSafe Sub adh_accSplitPath Lib "msaccess.exe" Alias "#59" _
 (ByVal strPath As String, ByVal strDrive As String, _
 ByVal strdir As String, ByVal strFName As String, ByVal strExt As String)
 #End If
 

 
' Common Dialogs
' GetFileName errors
Public Const adhcAccErrGFNCantOpenDialog = -301
Public Const adhcAccErrGFNUserCancelledDialog = -302


' GetFileNameInfo flags
Public Const adhcGfniConfirmReplace = &H1              ' Prompt if overwriting a file?
Public Const adhcGfniNoChangeDir = &H2                ' Disable the read-only option
Public Const adhcGfniAllowReadOnly = &H4                   ' Don't change to the directory the user selected?
Public Const adhcGfniAllowMultiSelect = &H8            ' Allow multiple-selection?
Public Const adhcGfniDirectoryOnly = &H20              ' Open as directory picker?
Public Const adhcGfniInitializeView = &H40             ' Initialize the view to the lView member or use last selected view?

' Views in the Office Find File dialog
Public Const adhcGfniViewDetails = 0                  ' Details
Public Const adhcGfniViewPreview = 1                  ' Preview
Public Const adhcGfniViewProperties = 2               ' Properties
Public Const adhcGfniViewList = 3                     ' List (typical)

Type adh_accOfficeGetFileNameInfo
    hwndOwner As Long
    strAppName As String * 255
    strDlgTitle As String * 255
    strOpenTitle As String * 255
    strFile As String * 4096
    strInitialDir As String * 255
    strFilter As String * 255
    lngFilterIndex As Long
    lngView As Long
    lngFlags As Long
End Type

Declare PtrSafe Function adh_accOfficeGetFileName Lib "msaccess.exe" _
 Alias "#56" (gfni As adh_accOfficeGetFileNameInfo, ByVal fOpen As Integer) As Long
Declare PtrSafe Function adh_accChooseColor Lib "msaccess.exe" _
 Alias "#53" (ByVal hwnd As Long, RGB As Long) As Long

' Registry
' Predefined root keys for the registry.
Public Const adhcHKEY_CLASSES_ROOT = &H80000000
Public Const adhcHKEY_CURRENT_USER = &H80000001
Public Const adhcHKEY_LOCAL_MACHINE = &H80000002
Public Const adhcHKEY_USERS = &H80000003
Public Const adhcHKEY_PERFORMANCE_DATA = &H80000004

' Data types for data in the registry
Public Const adhcREG_NONE = 0
Public Const adhcREG_SZ = 1
Public Const adhcREG_EXPAND_SZ = 2
Public Const adhcREG_BINARY = 3
Public Const adhcREG_DWORD = 4
Public Const adhcREG_DWORD_LITTLE_ENDIAN = 4
Public Const adhcREG_DWORD_BIG_ENDIAN = 5
Public Const adhcREG_LINK = 6
Public Const adhcREG_MULTI_SZ = 7
Public Const adhcREG_RESOURCE_LIST = 8
Public Const adhcREG_FULL_RESOURCE_DESCRIPTOR = 9
Public Const adhcREG_RESOURCE_REQUIREMENTS_LIST = 10

' Registry Errors
Public Const adhcAccErrRegKeyNotFound = -201
Public Const adhcAccErrRegValueNotFound = -202
Public Const adhcAccErrRegCantSetValue = -203
Public Const adhcAccErrRegSubKeyNotFound = -204
Public Const adhcAccErrRegTypeNotSupported = -205
Public Const adhcAccErrRegCantCreateKey = -206

Declare PtrSafe Function adh_accRegGetVal Lib "msaccess.exe" Alias "#70" _
 (ByVal hkeyRoot As Long, ByVal strSubKey As String, _
 ByVal strValName As String, lpData As Any, ByVal lngMaxLen As Long) As Long
Declare PtrSafe Function adh_accRegWriteVal Lib "msaccess.exe" Alias "#71" _
 (ByVal hkeyRoot As Long, ByVal strSubKey As String, ByVal strValName As String, _
 lpData As Any, ByVal lngType As Long) As Long
Declare PtrSafe Function adh_accRegGetKeyInfo Lib "msaccess.exe" Alias "#72" _
 (ByVal hkeyRoot As Long, ByVal strSubKey As String, _
 lngSubKeys As Long, lngValues As Long) As Long
Declare PtrSafe Function adh_accRegGetValName Lib "msaccess.exe" Alias "#73" _
 (ByVal hkeyRoot As Long, ByVal strSubKey As String, ByVal lngValue As Long, _
 ByVal strValName As String, ByVal lngMaxLen As Long, lngType As Long) As Long
Declare PtrSafe Function adh_accRegWriteKey Lib "msaccess.exe" Alias "#74" _
 (ByVal hkeyRoot As Long, ByVal strSubKey As String, _
 ByVal strClass As String) As Long
Declare PtrSafe Function adh_accRegGetKey Lib "msaccess.exe" Alias "#75" _
 (ByVal hkeyRoot As Long, ByVal strSubKey As String, ByVal lngSubKey As Long, _
 ByVal strName As String, ByVal lngMaxLen As Long) As Long

' Font information
Type adhFontInfo
    fRasterFont As Long
    strName As String * 32
End Type

Declare PtrSafe Function adh_accGetFontCount Lib "msaccess.exe" Alias "#61" _
 (ByVal hdc As Long) As Long
Declare PtrSafe Function adh_accGetFontList Lib "msaccess.exe" Alias "#62" _
 (ByVal hdc As Long, fiFonts() As adhFontInfo) As Long
Declare PtrSafe Function adh_accGetSizeCount Lib "msaccess.exe" Alias "#63" _
 (ByVal hdc As Long, ByVal szFont As String) As Long
Declare PtrSafe Function adh_accGetSizeList Lib "msaccess.exe" Alias "#64" _
 (ByVal hdc As Long, ByVal szFont As String, lSizeList() As Long) As Long

' Get twips from font
Declare PtrSafe Function adh_accTwipsFromFont Lib "msaccess.exe" _
 Alias "#67" (ByVal strFontName As String, ByVal lngSize As Long, _
 ByVal lngWeight As Long, ByVal fItalic As Long, ByVal fUnderline As Long, _
 ByVal lngChars As Long, ByVal strCaption As String, ByVal cchUseMaxWidth As Long, _
 lngWidth As Long, lngHeight As Long) As Integer

' Handle objects
Public Const adhcBitObjSystem = &H10000000
Public Const adhcBitObjHidden = &H20000000

' Table flags
Public Const adhcBitTblLocal = &H1000&
Public Const adhcBitTblAttachedISAM = &H2000&
Public Const adhcBitTblAttachedODBC = &H4000&
Public Const adhcBitTblAll = &H7000&

' Query flags are all part of Jet, but this one just makes
' it clear that you want all queries.
Public Const adhcBitQryAll = &H3FF

Type adhDBObj
    intObjType As Integer
    strName As String
    lngFlags As Long
End Type

Declare PtrSafe Function adh_accGetObjNames Lib "msaccess.exe" Alias "#79" _
 (ByVal varWrk As Variant, ByVal varDB As Variant, ByVal intObjType As Integer, _
 ByVal lngFlags As Long, astrObjects() As String, ByVal intStart As Integer, _
 intItemsFilled As Integer) As Long
 
Declare PtrSafe Function adh_accGetDbobjList Lib "msaccess.exe" Alias "#80" _
 (ByVal varWrk As Variant, ByVal varDB As Variant, ByVal intObjType As Integer, _
 ByVal lngFlags As Long, atypObjects() As adhDBObj, ByVal intStart As Integer, _
 intItemsFilled As Integer) As Long

Declare PtrSafe Function adh_accSortStringArray Lib "msaccess.exe" Alias "#81" _
 (astrObjects() As String) As Long

Declare PtrSafe Function adh_accSortDbobjArray Lib "msaccess.exe" Alias "#82" _
 (atypObjects() As adhDBObj, ByVal fNamesOnly As Long) As Long

' Miscellaneous
Declare PtrSafe Function adh_accGetLanguage Lib "msaccess.exe" Alias "#51" () As Long
Declare PtrSafe Function adh_accGetTbDIB Lib "msaccess.exe" Alias "#60" _
 (ByVal lngBmp As Long, ByVal fLarge As Long, bytBuf() As Byte) As Long

' Programming Functions
Declare PtrSafe Function adh_accIsValidIdentifier Lib "msaccess.exe" Alias "#84" _
 (ByVal strIdentCand As String) As Boolean
Declare PtrSafe Function adh_accGlobalProcExists Lib "msaccess.exe" Alias "#37" _
 (ByVal strProcName As String) As Long
' Get the type of a recordsource. 0 for SQL, 1 for table, 2 for query.
Declare PtrSafe Function adh_accTypeOfStrRS Lib "msaccess.exe" Alias "#83" _
 (ByVal strRS As String) As Integer

Public Const adhcAccRSTypeSQL = 0
Public Const adhcAccRSTypeTable = 1
Public Const adhcAccRSTypeQuery = 2

Declare PtrSafe Function adh_apiSendMessage Lib "user32" Alias "SendMessageA" _
 (ByVal hwnd As Long, ByVal wMsg As Long, ByVal wParam As Long, lParam As Any) As Long

' Create an Information Context
Declare PtrSafe Function adh_apiCreateIC Lib "gdi32" Alias "CreateICA" _
 (ByVal lpDriverName As String, ByVal lpDeviceName As String, _
 ByVal lpOutput As String, lpInitData As Any) As Long
' Close an existing Device Context (or information context)
Declare PtrSafe Function adh_apiDeleteDC Lib "gdi32" Alias "DeleteDC" _
 (ByVal hdc As Long) As Long

' Language Return Values
' To save Public space, most of these are commented out.
' If your situation involves checking for more of these, uncomment the
' ones you care about.
'Public Const adhcArabic = 1025                    'Arabic
'Public Const adhcBulgarian = 1026                 'Bulgarian
'Public Const adhcCatalan = 1027                   'Catalan
'Public Const adhcTraditionalChinese = 1028        'Traditional Chinese
'Public Const adhcCzech = 1029                     'Czech
'Public Const adhcDanish = 1030                    'Danish
Public Const adhcGerman = 1031                    'German
'Public Const adhcGreek = 1032                     'Greek
Public Const adhcUSEnglish = 1033                 'U.S. English
'Public Const adhcCastilianSpanish = 1034          'Castilian Spanish
'Public Const adhcFinnish = 1035                   'Finnish
Public Const adhcFrench = 1036                    'French
'Public Const adhcHebrew = 1037                    'Hebrew
'Public Const adhcHungarian = 1038                 'Hungarian
'Public Const adhcIcelandic = 1039                 'Icelandic
Public Const adhcItalian = 1040                   'Italian
'Public Const adhcJapanese = 1041                  'Japanese
'Public Const adhcKorean = 1042                    'Korean
'Public Const adhcDutch = 1043                     'Dutch
'Public Const adhcNorwegianBokmål = 1044           'Norwegian - Bokmål
'Public Const adhcPolish = 1045                    'Polish
'Public Const adhcBrazilianPortuguese = 1046       'Brazilian Portuguese
'Public Const adhcRhaetoRomanic = 1047             'Rhaeto-Romanic
'Public Const adhcRomanian = 1048                  'Romanian
'Public Const adhcRussian = 1049                   'Russian
'Public Const adhcCroatoSerbian = 1050             'Croato-Serbian (Latin)
'Public Const adhcSlovak = 1051                    'Slovak
'Public Const adhcAlbanian = 1052                  'Albanian
'Public Const adhcSwedish = 1053                   'Swedish
'Public Const adhcThai = 1054                      'Thai
'Public Const adhcTurkish = 1055                   'Turkish
'Public Const adhcUrdu = 1056                      'Urdu
'Public Const adhcBahasa = 1057                    'Bahasa
'Public Const adhcSimplifiedChinese = 2052         'Simplified Chinese
'Public Const adhcSwissGerman = 2055               'Swiss German
Public Const adhcUKEnglish = 2057                 'U.K. English
Public Const adhcMexicanSpanish = 2058            'Mexican Spanish
'Public Const adhcBelgianFrench = 2060             'Belgian French
'Public Const adhcSwissItalian = 2064              'Swiss Italian
'Public Const adhcBelgianDutch = 2067              'Belgian Dutch
'Public Const adhcNorwegianNynorsk = 2068          'Norwegian - Nynorsk
'Public Const adhcPortuguese = 2070                'Portuguese
'Public Const adhcSerboCroatian = 2074             'Serbo-Croatian (Cyrillic)
'Public Const adhcCanadianFrench = 3084            'Canadian French
'Public Const adhcSwissFrench = 4108               'Swiss French

Function adhChooseColor(lngColor As Long) As Long
    ' Use the color chooser exposed by Access.
    
    ' From Access 97 Developer's Handbook
    ' by Litwin, Getz, and Gilbert (Sybex)
    ' Copyright 1997.  All rights reserved.
    Debug.Print "Returned: " & adh_accChooseColor(Application.hWndAccessApp, lngColor)
    adhChooseColor = lngColor
End Function

Function adhOfficeGetFileName(gfni As adh_accOfficeGetFileNameInfo, _
 ByVal fOpen As Integer) As Long
 
    ' Use the Office file selector common dialog
    ' exposed by Access.
    
    ' From Access 97 Developer's Handbook
    ' by Litwin, Getz, and Gilbert (Sybex)
    ' Copyright 1997.  All rights reserved.
    
    Dim lng As Long
     'If CurrentUser = "Negovan" And Not BBCFG_Initialized Then
     
     'ElseIf BBCFG.NoExplorer Then
     '  'imeFajla = Null
     '  adhOfficeGetFileName = adhcAccErrUnknown
     '  MsgBox "Nije dozvoljena upotreba Explorera!", vbExclamation, "QMegaTeh"
     '  Exit Function
     'End If
    
    With gfni
        .strAppName = RTrim$(.strAppName) & vbNullChar
        .strDlgTitle = RTrim$(.strDlgTitle) & vbNullChar
        .strOpenTitle = RTrim$(.strOpenTitle) & vbNullChar
        .strFile = RTrim$(.strFile) & vbNullChar
        .strInitialDir = RTrim$(.strInitialDir) & vbNullChar
        .strFilter = RTrim$(.strFilter) & vbNullChar
        SysCmd acSysCmdClearHelpTopic
        lng = adh_accOfficeGetFileName(gfni, fOpen)
        .strAppName = RTrim$(adhTrimNull(.strAppName))
        .strDlgTitle = RTrim$(adhTrimNull(.strDlgTitle))
        .strOpenTitle = RTrim$(adhTrimNull(.strOpenTitle))
        .strFile = RTrim$(adhTrimNull(.strFile))
        .strInitialDir = RTrim$(adhTrimNull(.strInitialDir))
        .strFilter = RTrim$(adhTrimNull(.strFilter))
    End With
    adhOfficeGetFileName = lng
End Function

Function adhTrimNull(strVal As String) As String
    ' Trim the end of a string, stopping at the first
    ' null character.
    
    ' From Access 97 Developer's Handbook
    ' by Litwin, Getz, and Gilbert (Sybex)
    ' Copyright 1997.  All rights reserved.
    
    Dim intPos As Integer
    intPos = InStr(strVal, vbNullChar)
    If intPos > 0 Then
        adhTrimNull = Left$(strVal, intPos - 1)
    Else
        adhTrimNull = strVal
    End If
End Function

Function adhHandleAccErrors(intErr As Integer) As Boolean
        
    ' A generic error handler for Access function errors.
    
    ' From Access 97 Developer's Handbook
    ' by Litwin, Getz, and Gilbert (Sybex)
    ' Copyright 1997.  All rights reserved.
    
    ' In:
    '    intErr:  the error number
    ' Out:
    '    Return value: True if this function handled the error,
    '     False if it couldn't.
    
    Dim strMsg As String
    Dim fOK As Boolean
    
    fOK = True
    Select Case intErr
        Case adhcAccErrUnknown
            strMsg = "Unknown error"

        ' Registry Errors
        Case adhcAccErrRegKeyNotFound
            strMsg = "Specified registry key not found"
        Case adhcAccErrRegValueNotFound
            strMsg = "Specified registry value not found"
        Case adhcAccErrRegCantSetValue
            strMsg = "Can't set registry value"
        Case adhcAccErrRegSubKeyNotFound
            strMsg = "Specified subkey not found"
        Case adhcAccErrRegTypeNotSupported
            strMsg = "Specified data type not supported"
        Case adhcAccErrRegCantCreateKey
            strMsg = "Can't create specified registry key"

        ' GetFileName errors
        Case adhcAccErrGFNCantOpenDialog
            strMsg = "Can't open common dialog"
        Case adhcAccErrGFNUserCancelledDialog
            strMsg = "User cancelled dialog"
        Case Else
            fOK = False
    End Select
    If fOK Then
        MsgBox strMsg, vbExclamation, "Error in Acc7032.DLL"
    End If
    adhHandleAccErrors = fOK
End Function

Sub adhSplitPath(pstrPath As String, pstrDrive As String, _
 pstrDir As String, pstrFName As String, pstrExt As String)

    ' A wrapper function for the adh_accSplitPath()
    ' function in MSACCESS.EXE.
    '
    ' From Access 97 Developer's Handbook
    ' by Litwin, Getz, and Gilbert (Sybex)
    ' Copyright 1997.  All rights reserved.
    
    ' In:
    '     pstrPath: the path to split up
    '
    ' Out:
    '     pstrDrive: the drive
    '     pstrDir:   the directory
    '     pstrFName: the file name
    '     pstrExt:   the extension
    '
    Dim strDrive As String * adhcSP_MAXDRIVE
    Dim strdir As String * adhcSP_MAXDIR
    Dim strFName As String * adhcSP_MAXFNAME
    Dim strExt As String * adhcSP_MAXEXT

    adh_accSplitPath pstrPath, strDrive, strdir, strFName, strExt

    pstrDrive = adhTrimNull(strDrive)
    pstrDir = adhTrimNull(strdir)
    pstrFName = adhTrimNull(strFName)
    pstrExt = adhTrimNull(strExt)
End Sub

Function adhFullPath(strFilename As String) As String

    ' A wrapper function for the adh_accFullPath() function.
    '
    ' From Access 97 Developer's Handbook
    ' by Litwin, Getz, and Gilbert (Sybex)
    ' Copyright 1997.  All rights reserved.
    
    ' In:
    '     strFileName: relative filename to convert to full path name
    '
    ' Out:
    '     Return Value: full path name for strFileName
    ' For example:
    ' Given that the current directory is "E:\adh\CH19",
    '
    '    adhFullPath("..\AHT\CH06\CH06TXT.DOC")
    '
    ' would return
    '
    '    E:\AHT\CH06\CH06TXT.DOC
    '
    ' The function does not check for the existence of that file,
    ' only converts a relative path into a fully qualified path.
    
    Dim strBuffer As String * adhcSP_MAXPATH
    Dim intRetVal As Integer

    intRetVal = adh_accFullPath(strFilename, strBuffer, adhcSP_MAXPATH)
    adhFullPath = Left(strBuffer, intRetVal)
End Function

Function adhCvtQryTypeToBit(ByVal lngItem As Long) As Long
    ' Convert query constants (dbQSelect, etc.) to the flag
    ' format that the dbObj functions require.
    
    ' From Access 97 Developer's Handbook
    ' by Litwin, Getz, and Gilbert (Sybex)
    ' Copyright 1997.  All rights reserved.
    
    ' In:
    '   lngItem: a query constant (dbQSelect, dbQDDL, etc.)
    ' Out:
    '   Return value: a bitmapped value corresponding to the constant
    
    adhCvtQryTypeToBit = 2 ^ (lngItem / 16 + 1)
End Function

Function adhGetAppInfo(lngFlags As Long) As Long
    ' Set the output based on whether or not
    ' you've selected to see hidden/system objects.
    
    ' From Access 97 Developer's Handbook
    ' by Litwin, Getz, and Gilbert (Sybex)
    ' Copyright 1997.  All rights reserved.
    
    ' In:
    '    lngFlags: value of the flag before calling this function.
    '      New values are OR'd with it.
    ' Out:
    '    Return value: the new value of the flags
    
    If Application.GetOption("Show Hidden Objects") Then
        lngFlags = lngFlags Or adhcBitObjHidden
    Else
        lngFlags = lngFlags And Not adhcBitObjHidden
    End If
    If Application.GetOption("Show System Objects") Then
        lngFlags = lngFlags Or adhcBitObjSystem
    Else
        lngFlags = lngFlags And Not adhcBitObjSystem
    End If
    adhGetAppInfo = lngFlags
End Function

Public Function IzaberiBazu(Optional ZagStr = "Izaberite bazu") As Variant
Dim lngFlags As Long
Dim ImeBaze As Variant
Dim gfni As adh_accOfficeGetFileNameInfo
    
    On Error GoTo HandleErrors
    'If CurrentUser = "Negovan" And Not BBCFG_Initialized Then
    '   Rem on sve moze
    'ElseIf BBCFG.NoExplorer Then
    '   ImeBaze = Null
    '   MsgBox "Nije dozvoljena upotreba Explorera!", vbExclamation, "QMegaTeh"
    '   GoTo ExitHere
    'End If

    With gfni
        .lngFlags = lngFlags
        .strFilter = "MDB Files (*.mdb)"
        .lngFilterIndex = CInt("1")
        .strFile = ""
        .strDlgTitle = ZagStr
        .strOpenTitle = "Select"
        .strFile = ""
        .strInitialDir = ""
    End With
    If adhOfficeGetFileName(gfni, True) = adhcAccErrSuccess Then
        ImeBaze = Trim(gfni.strFile)
    Else
        ImeBaze = Null
    End If
    
ExitHere:
    IzaberiBazu = ImeBaze
    Exit Function

HandleErrors:
    MsgBox "Error: " & err.Description & " (" & err.Number & ")"
    Resume ExitHere
End Function
Public Function OpenFileDialog(Optional ByVal ZagStr = "Izaberi fajl", Optional ByVal stInitialDir) As Variant
Dim lngFlags As Long
Dim ImeFajla As Variant
    Dim gfni As adh_accOfficeGetFileNameInfo
    
    On Error GoTo HandleErrors

    With gfni
        .lngFlags = lngFlags
        .strFilter = "svi fajlovi (*.*)"
        .lngFilterIndex = CInt("1")
        .strFile = ""
        .strDlgTitle = ZagStr
        .strOpenTitle = "Select"
        .strFile = ""
        If Not IsMissing(stInitialDir) Then
         .strInitialDir = CStr(stInitialDir)
        Else
        .strInitialDir = ""
        End If
    End With
    If adhOfficeGetFileName(gfni, True) = adhcAccErrSuccess Then
        ImeFajla = Trim(gfni.strFile)
    Else
        ImeFajla = Null
    End If
    
ExitHere:
    OpenFileDialog = ImeFajla
    Exit Function

HandleErrors:
    MsgBox "Error: " & err.Description & " (" & err.Number & ")"
    Resume ExitHere
End Function
Public Function SortirajKolonu(Optional stImeKolone, Optional frmForma) As Boolean
'Kreirano: 28-12-2021
'Modifikovano: 25-02-2022 => DoCmd.Hourglass True/False, korekcija za []
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stSort As String
Dim pForm As Form

DoCmd.Hourglass True

If IsMissing(frmForma) Then
    Set pForm = Screen.ActiveControl.Parent 'Screen.ActiveForm
Else
    Set pForm = frmForma
End If

If IsMissing(stImeKolone) Then
    stSort = "[" & Screen.ActiveControl.Name & "]"
Else
    stImeKolone = Replace(stImeKolone, "[", "")
    stImeKolone = Replace(stImeKolone, "]", "")
    stSort = "[" & stImeKolone & "]"
End If

 If pForm.OrderBy = stSort Then
        pForm.OrderBy = stSort & " DESC"
 Else
       pForm.OrderBy = stSort
 End If
 pForm.OrderByOn = True

Exit_Point:
 On Error Resume Next
 DoCmd.Hourglass False
       SortirajKolonu = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "SortirajKolonu"
 retValOk = False
 Resume Exit_Point
End Function


