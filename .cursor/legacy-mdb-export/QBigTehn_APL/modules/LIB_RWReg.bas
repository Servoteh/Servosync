Attribute VB_Name = "LIB_RWReg"
Option Compare Database
Option Explicit

Public Enum REG_TOPLEVEL_KEYS
 HKEY_CLASSES_ROOT = &H80000000
 HKEY_CURRENT_CONFIG = &H80000005
 HKEY_CURRENT_USER = &H80000001
 HKEY_DYN_DATA = &H80000006
 HKEY_LOCAL_MACHINE = &H80000002
 HKEY_PERFORMANCE_DATA = &H80000004
 HKEY_USERS = &H80000003
End Enum
Private Const REG_SZ = 1
Private Const STANDARD_RIGHTS_READ = &H20000
Private Const KEY_QUERY_VALUE = &H1&
Private Const KEY_ENUMERATE_SUB_KEYS = &H8&
Private Const KEY_NOTIFY = &H10&
Private Const Synchronize = &H100000
Private Const KEY_READ = ((STANDARD_RIGHTS_READ Or _
                        KEY_QUERY_VALUE Or _
                        KEY_ENUMERATE_SUB_KEYS Or _
                        KEY_NOTIFY) And _
                        (Not Synchronize))
Private Const MAXLEN = 256
Private Const ERROR_SUCCESS = &H0&

Const REG_NONE = 0
Const REG_EXPAND_SZ = 2
Const REG_BINARY = 3
Const REG_DWORD = 4
Const REG_DWORD_LITTLE_ENDIAN = 4
Const REG_DWORD_BIG_ENDIAN = 5
Const REG_LINK = 6
Const REG_MULTI_SZ = 7
Const REG_RESOURCE_LIST = 8

Type FILETIME
    dwLowDateTime As Long
    dwHighDateTime As Long
End Type


Private Declare PtrSafe Function RegCreateKey Lib _
   "advapi32.dll" Alias "RegCreateKeyA" _
   (ByVal Hkey As Long, ByVal lpSubKey As _
   String, phkResult As Long) As Long

Private Declare PtrSafe Function RegCloseKey Lib _
   "advapi32.dll" (ByVal Hkey As Long) As Long

Private Declare PtrSafe Function RegSetValueEx Lib _
   "advapi32.dll" Alias "RegSetValueExA" _
   (ByVal Hkey As Long, ByVal _
   lpValueName As String, ByVal _
   Reserved As Long, ByVal dwType _
   As Long, lpData As Any, ByVal _
   cbData As Long) As Long


Private Declare PtrSafe Function apiRegOpenKeyEx Lib "advapi32.dll" _
        Alias "RegOpenKeyExA" (ByVal Hkey As Long, _
        ByVal lpSubKey As String, ByVal ulOptions As Long, _
        ByVal samDesired As Long, ByRef phkResult As Long) _
        As Long



Private Declare PtrSafe Function apiRegQueryValueEx Lib "advapi32.dll" _
        Alias "RegQueryValueExA" (ByVal Hkey As Long, _
        ByVal lpValueName As String, ByVal lpReserved As Long, _
        ByRef lpType As Long, lpData As Any, _
        ByRef lpcbData As Long) As Long

Private Declare PtrSafe Function apiRegQueryInfoKey Lib "advapi32.dll" _
        Alias "RegQueryInfoKeyA" (ByVal Hkey As Long, _
        ByVal lpClass As String, ByRef lpcbClass As Long, _
        ByVal lpReserved As Long, ByRef lpcSubKeys As Long, _
        ByRef lpcbMaxSubKeyLen As Long, _
        ByRef lpcbMaxClassLen As Long, _
        ByRef lpcValues As Long, _
        ByRef lpcbMaxValueNameLen As Long, _
        ByRef lpcbMaxValueLen As Long, _
        ByRef lpcbSecurityDescriptor As Long, _
        ByRef lpftLastWriteTime As FILETIME) As Long

Function ReadStringFromRegistry(ByVal lngKeyToGet As Long, _
                            ByVal strKeyName As String, _
                            ByVal strValueName As String) _
                            As String
Dim lnghKey As Long
Dim strClassName As String
Dim lngClassLen As Long
Dim lngReserved As Long
Dim lngSubKeys As Long
Dim lngMaxSubKeyLen As Long
Dim lngMaxClassLen As Long
Dim lngValues As Long
Dim lngMaxValueNameLen As Long
Dim lngMaxValueLen As Long
Dim lngSecurity As Long
Dim ftLastWrite As FILETIME
Dim lngType As Long
Dim lngData As Long
Dim lngTmp As Long
Dim strRet As String
Dim varRet As Variant
Dim lngRet As Long
    
    On Error GoTo ReadStringFromRegistry_Err
        
    'Open the key first
    lngTmp = apiRegOpenKeyEx(lngKeyToGet, _
                strKeyName, 0&, KEY_READ, lnghKey)

    'Are we ok?
    If Not (lngTmp = ERROR_SUCCESS) Then err.Raise _
                                lngTmp + vbObjectError

    lngReserved = 0&
    strClassName = String$(MAXLEN, 0):  lngClassLen = MAXLEN

    'Get boundary values
    lngTmp = apiRegQueryInfoKey(lnghKey, strClassName, _
        lngClassLen, lngReserved, lngSubKeys, lngMaxSubKeyLen, _
        lngMaxClassLen, lngValues, lngMaxValueNameLen, _
        lngMaxValueLen, lngSecurity, ftLastWrite)

    'How we doin?
    If Not (lngTmp = ERROR_SUCCESS) Then err.Raise _
                                lngTmp + vbObjectError
    
    'Now grab the value for the key
    strRet = String$(MAXLEN - 1, 0)
    lngTmp = apiRegQueryValueEx(lnghKey, strValueName, _
                lngReserved, lngType, ByVal strRet, lngData)
    Select Case lngType
      Case REG_SZ
        lngTmp = apiRegQueryValueEx(lnghKey, strValueName, _
                lngReserved, lngType, ByVal strRet, lngData)
        varRet = Left(strRet, lngData - 1)
      Case REG_DWORD
        lngTmp = apiRegQueryValueEx(lnghKey, strValueName, _
                lngReserved, lngType, lngRet, lngData)
        varRet = lngRet
      Case REG_BINARY
        lngTmp = apiRegQueryValueEx(lnghKey, strValueName, _
                lngReserved, lngType, ByVal strRet, lngData)
        varRet = Left(strRet, lngData)
    End Select
    
    'All quiet on the western front?
    If Not (lngTmp = ERROR_SUCCESS) Then err.Raise _
                                lngTmp + vbObjectError

ReadStringFromRegistry_Exit:
    ReadStringFromRegistry = varRet
    lngTmp = RegCloseKey(lnghKey)
    Exit Function
ReadStringFromRegistry_Err:
    varRet = "Error: Key or Value Not Found."
    Resume ReadStringFromRegistry_Exit
End Function
Function WriteStringToRegistry(Hkey As _
  REG_TOPLEVEL_KEYS, strPath As String, strValue As String, _
  strdata As String) As Boolean
 
'WRITES A STRING VALUE TO REGISTRY:
'PARAMETERS:

'Hkey: Top Level Key as defined by
'REG_TOPLEVEL_KEYS Enum (See Declarations)

'strPath - 'Full Path of Subkey
'if path does not exist it will be created

'strValue ValueName

'strData - Value Data

'Returns: True if successful, false otherwise

'EXAMPLE:
'WriteStringToRegistry(HKEY_LOCAL_MACHINE, _
"Software\Microsoft", "CustomerName", "FreeVBCode.com")
'
'WriteStringToRegistry(HKEY_LOCAL_MACHINE, "Software\BigBit\MalaKasa", "MojeIme", "Slavisa")
'==============================================================================================

Dim bAns As Boolean

On Error GoTo ErrorHandler
   Dim keyhand As Long
   Dim r As Long
   r = RegCreateKey(Hkey, strPath, keyhand)
   If r = 0 Then
        r = RegSetValueEx(keyhand, strValue, 0, _
           REG_SZ, ByVal strdata, Len(strdata))
        r = RegCloseKey(keyhand)
    End If
    
   WriteStringToRegistry = (r = 0)

Exit Function

ErrorHandler:
    WriteStringToRegistry = False
    Exit Function
    
End Function

