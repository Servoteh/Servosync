Attribute VB_Name = "Zastita"
Option Compare Database
Option Explicit

Public Const ProgName = "BigBit"
Public Const RegGrana = "Software\BitCo\"
Const LogicalHDName = "C:"
   
Private Function GetserialNumberHD(Optional drvpath = "C:") As String
 On Error GoTo Err_Handler
    Dim retVal As String
    Dim fs, d, s, t
    Set fs = CreateObject("Scripting.FileSystemObject")
    Set d = fs.GetDrive(fs.GetDriveName(fs.GetAbsolutePathName(drvpath)))
    Select Case d.DriveType
        Case 0: t = "Unknown"
        Case 1: t = "Removable"
        Case 2: t = "Fixed"
        Case 3: t = "Network"
        Case 4: t = "CD-ROM"
        Case 5: t = "RAM Disk"
    End Select
    retVal = d.SerialNumber
    s = "Drive " & d.DriveLetter & ": - " & t
    s = s & vbCrLf & "SN: " & retVal
    GetserialNumberHD = retVal
    Exit Function
Err_Handler:
    retVal = "Null"
    MsgBox err.Number & ": " & err.Description
    Resume Next
End Function
Public Function GetComputerName() As String
    GetComputerName = ReadStringFromRegistry(REG_TOPLEVEL_KEYS.HKEY_LOCAL_MACHINE, "System\CurrentControlSet\Control\ComputerName\ComputerName", "ComputerName")
End Function
Public Function DozvoljenoPostavljenjeZastite() As Boolean
   Dim stZaProveru As String
   Dim key As String
   Dim Dan As String
   Dim Mesec As String
   Dim Godina As String

   Dan = DatePart("d", Date)
   Mesec = DatePart("M", Date)
   Godina = DatePart("YYYY", Date)
   
   If CurrentUser = "Negovan" Then
    key = InputBox("Key: ", "BigBit [" & GetComputerName() & "]")
    DozvoljenoPostavljenjeZastite = (key = (Dan & GetComputerName & Mesec & Godina))
   Else
    DozvoljenoPostavljenjeZastite = False
   End If
End Function
Private Function TestInputBox() As String
    Dim InputString As String
    Dim i As Integer
    
    InputString = InputBox("Key: ", "BigBit")
    Debug.Print InputString
    For i = 1 To Len(InputString)
        Debug.Print Mid(InputString, i, 1), Asc(Mid(InputString, i, 1))
    Next i
    TestInputBox = InputString
End Function

Public Function Zasticen() As Boolean
'Modifikovano:21-04-2021
On Error Resume Next

Dim SnHDReg As String
Dim SnHDReal As String
Dim retVal As Boolean
  
  SnHDReg = ReadStringFromRegistry(REG_TOPLEVEL_KEYS.HKEY_LOCAL_MACHINE, RegGrana & ProgName, "HDSn")
  SnHDReal = GetserialNumberHD(LogicalHDName)
  retVal = (SnHDReal <> SnHDReg)
  
  If retVal Then
    'SnHDReg = CurrentDb.Properties("BBHDSn").Value
    SnHDReg = BBReadProperty("BBHDSn", False)
    retVal = (SnHDReal <> SnHDReg)
  End If
  
  'If retVal And CurrentUser() = "Negovan" Then
  ' If Command() = "Zastita" Then
  '  BBOpenForm "Zastita"
  ' End If
  'End If
  
  Zasticen = retVal
End Function

Private Sub TEST_UpisiPodatkeURegistry()
Dim OK As Boolean
   OK = WriteStringToRegistry(REG_TOPLEVEL_KEYS.HKEY_LOCAL_MACHINE, RegGrana & ProgName, "Name", "Negovan Vasic")
   OK = WriteStringToRegistry(REG_TOPLEVEL_KEYS.HKEY_LOCAL_MACHINE, RegGrana & ProgName, "HDSn", GetserialNumberHD(LogicalHDName))
End Sub

Public Function BBReadFromRegHDSN() As String
    BBReadFromRegHDSN = ReadStringFromRegistry(REG_TOPLEVEL_KEYS.HKEY_LOCAL_MACHINE, RegGrana & ProgName, "HDSn")
End Function
Public Function BBReadFromRegName() As String
    BBReadFromRegName = ReadStringFromRegistry(REG_TOPLEVEL_KEYS.HKEY_LOCAL_MACHINE, RegGrana & ProgName, "Name")
End Function
Public Function BBWriteToRegHDSN() As Boolean
    BBWriteToRegHDSN = WriteStringToRegistry(REG_TOPLEVEL_KEYS.HKEY_LOCAL_MACHINE, RegGrana & ProgName, "HDSn", BBReadRealHDSN)
End Function
Public Function BBReadRealHDSN() As String
    BBReadRealHDSN = GetserialNumberHD(LogicalHDName)
End Function
Public Function BBReadRegKey(RegKey As String) As String
    BBReadRegKey = ReadStringFromRegistry(REG_TOPLEVEL_KEYS.HKEY_LOCAL_MACHINE, RegGrana & ProgName, RegKey)
End Function
Public Function BBWriteRegKey(RegKey As String, RegVal As String) As Boolean
    BBWriteRegKey = WriteStringToRegistry(REG_TOPLEVEL_KEYS.HKEY_LOCAL_MACHINE, RegGrana & ProgName, RegKey, RegVal)
End Function
Public Sub OtvoriFormuZastita()
 If DozvoljenoPostavljenjeZastite() Then
    BBOpenForm "Zastita"
 Else
    'DoCmd.Quit
    QuitBigBit
 End If
End Sub
