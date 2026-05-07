Attribute VB_Name = "LIB_Module1_NONAME"
Option Compare Database
Option Explicit
'Modifikovano: 23.08.2019
Declare PtrSafe Sub Sleep Lib "kernel32" (ByVal dwMilliseconds As Long)
'Kreirano: 23.08.2019.
'Ovo radi nesto kao DoEvents
'****************************************************************

' ******** Code Start ********
'This code was originally written by Dev Ashish.
'It is not to be altered or distributed,
'except as part of an application.
'You are free to use it in any application,
'provided the copyright notice is left unchanged.
'
'Code Courtesy of
'Dev Ashish
'
'  structure contains version information about a file. This
'  information is language and code page independent.
Private Type VS_FIXEDFILEINFO
    '  Contains the value 0xFEEFO4BD (szKey)
    dwSignature As Long
    '  Specifies the binary version number of this structure.
    dwStrucVersion As Long
    '  most significant 32 bits of the file's binary version number.
    dwFileVersionMS As Long
    '  least significant 32 bits of the file's binary version number.
    dwFileVersionLS As Long
    '  most significant 32 bits of the binary version number of
    ' the product with which this file was distributed
    dwProductVersionLS As Long
    '  least significant 32 bits of the binary version number of
    ' the product with which this file was distributed
    dwFileFlagsMask As Long
    '  Contains a bitmask that specifies the valid bits in dwFileFlags.
    dwProductVersionMS As Long
    '  Contains a bitmask that specifies the
    '  Boolean attributes of the file.
    dwFileFlags As Long
    '  operating system for which this file was designed.
    dwFileOS As Long
    '  general type of file.
    dwFileType As Long
    '  function of the file.
    dwFileSubtype As Long
    '  most significant 32 bits of the file's 64-bit
    ' binary creation date and time stamp.
    dwFileDateMS As Long
    '  least significant 32 bits of the file's 64-bit binary
    ' creation date and time stamp.
    dwFileDateLS As Long
End Type
 
'  Returns size of version info in Bytes
Private Declare PtrSafe Function apiGetFileVersionInfoSize _
    Lib "version.dll" Alias "GetFileVersionInfoSizeA" _
    (ByVal lptstrFilename As String, _
    lpdwHandle As Long) _
    As Long
 
'  Read version info into buffer
' /* Length of buffer for info *
' /* Information from GetFileVersionSize *
' /* Filename of version stamped file *
Private Declare PtrSafe Function apiGetFileVersionInfo Lib _
    "version.dll" Alias "GetFileVersionInfoA" _
    (ByVal lptstrFilename As String, _
    ByVal dwHandle As Long, _
    ByVal dwLen As Long, _
    lpData As Any) _
    As Long
 
'  returns selected version information from the specified
'  version-information resource.
Private Declare PtrSafe Function apiVerQueryValue Lib _
    "version.dll" Alias "VerQueryValueA" _
    (pBlock As Any, _
    ByVal lpSubBlock As String, _
    lplpBuffer As Long, _
    puLen As Long) _
    As Long
 
Private Declare PtrSafe Sub sapiCopyMem _
    Lib "kernel32" Alias "RtlMoveMemory" _
    (Destination As Any, _
    Source As Any, _
    ByVal Length As Long)
 
Function fGetProductVersion(strExeFullPath As String) As String
'
'  Returns the build number for Office exes
'
' Sample usage (Access 2000)
'      ?fGetProductVersion(SysCmd(acSysCmdAccessDir) & "Frontpg.exe") '
'  Product                  Pre-SR1              Post-SR1
'  ---------------------------------------------------------
'  MSAccess.exe        9.0.0.2719           9.0.0.3822
'  WinWord.exe        9.0.0.2717            9.0.0.3822
'  Excel.exe              9.0.0.2719           9.0.0.3822
'  FrontPg.exe          4.0.2.2717            4.0.2.3821
'  Outlook.exe          9.0.0.2416            9.0.0.2416
'  PowerPnt.exe        9.0.0.2716            9.0.0.3821
'  WinProj.exe          8.0.98.407            Don't have it, sorry.
'
On Error GoTo ErrHandler
Dim lngSize As Long
Dim lngRet As Long
Dim pBlock() As Byte
Dim lpfi As VS_FIXEDFILEINFO
Dim lppBlock As Long
 
    '  GetFileVersionInfo requires us to get the size
    '  of the file version information first, this info is in the format
    '  of VS_FIXEDFILEINFO struct
    lngSize = apiGetFileVersionInfoSize( _
                        strExeFullPath, _
                        lngRet)
 
    '  If the OS can obtain version info, then proceed on
    If lngSize Then
        '  the info in pBlock is always in Unicode format
        ReDim pBlock(lngSize)
        lngRet = apiGetFileVersionInfo(strExeFullPath, 0, _
                                lngSize, pBlock(0))
        If Not lngRet = 0 Then
            '  the same pointer to pBlock can be passed to VerQueryValue
            lngRet = apiVerQueryValue(pBlock(0), _
                                "\", lppBlock, lngSize)
 
            '  fill the VS_FIXEDFILEINFO struct with bytes from pBlock
            '  VerQueryValue fills lngSize with the length of the block.
            Call sapiCopyMem(lpfi, ByVal lppBlock, lngSize)
            '  build the version info strings
            With lpfi
                fGetProductVersion = HIWord(.dwFileVersionMS) & "." & _
                                                LOWord(.dwFileVersionMS) & "." & _
                                                HIWord(.dwFileVersionLS) & "." & _
                                                LOWord(.dwFileVersionLS)
            End With
        End If
    End If
 
ExitHere:
    Erase pBlock
    Exit Function
ErrHandler:
    Resume ExitHere
End Function
 
Private Function LOWord(dw As Long) As Integer
'    retrieves the low-order word from the given 32-bit value.
    If dw And &H8000& Then
        LOWord = dw Or &HFFFF0000
    Else
        LOWord = dw And &HFFFF&
    End If
End Function
 
Private Function HIWord(dw As Long) As Integer
'    retrieves the high-order word from the given 32-bit value.
  HIWord = (dw And &HFFFF0000) \ &H10000
End Function
' ******** Code End *********
Public Sub ListReferences()
Dim refCurr As Reference

  For Each refCurr In Application.References
    Debug.Print refCurr.Name & ": " & refCurr.fullPath & _
      " (" & fGetProductVersion(refCurr.fullPath) & ")"
    Next

End Sub



