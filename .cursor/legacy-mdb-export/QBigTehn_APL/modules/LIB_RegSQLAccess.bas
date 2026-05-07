Attribute VB_Name = "LIB_RegSQLAccess"
Option Compare Database
Option Explicit
Private Function GetIPAdress()
Dim myWMI As Object
Dim myobj As Object
Dim itm

Set myWMI = GetObject("winmgmts:\\.\root\cimv2")
Set myobj = myWMI.ExecQuery("Select * from Win32_NetworkAdapterConfiguration Where IPEnabled = True")
For Each itm In myobj
  GetIPAdress = itm.IPAddress(0)
  Exit Function
Next
End Function
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
Private Function GetWinUser() As String
   GetWinUser = Environ("UserName")
End Function
Private Function GetComputerName() As String
    GetComputerName = Environ("ComputerName")
End Function
Private Function ExecSQLCMD(stSQLText As String, Optional CNNString, Optional OnErrShowDetails As Boolean = True) As Boolean
   'ExecSQLCMD = PassTroughExecuteSQL(stSQLText, CNNString, OnErrShowDetails)
   ExecSQLCMD = ADO_ExecSQL(CNNString, stSQLText, OnErrShowDetails)
End Function
Public Function RegSQLAccess_Login(CNNString As String, Optional Program_Name As String = "QBigTehn", Optional OnErrShowDetails As Boolean = False) As Long
'Modifikovano: 27-10-2023
'? RegAccess(F_CNNStringIzAPL(F_AccStaraApl()),CurrentDb.Name,false)
On Error GoTo Err_Point

Dim stSQL As String
Dim retValOk As Boolean
Dim RegSQLAccess_Login_ID As Long


stSQL = stSQL & "INSERT INTO [dbo].[_RegAccess] "
stSQL = stSQL & "           ("
stSQL = stSQL & "            [HDSn], "
stSQL = stSQL & "            [WinUser], "
stSQL = stSQL & "            [ComputerName], "
stSQL = stSQL & "            [IPAdress], "
stSQL = stSQL & "            [Program_Name], "
stSQL = stSQL & "            [CNNString] "
stSQL = stSQL & "           )"

stSQL = stSQL & "     VALUES"
stSQL = stSQL & "           ("
stSQL = stSQL & "            '" & GetserialNumberHD() & "', "
stSQL = stSQL & "            '" & GetWinUser() & "', "
stSQL = stSQL & "            '" & GetComputerName() & "', "
stSQL = stSQL & "            '" & GetIPAdress() & "', "
stSQL = stSQL & "            '" & Program_Name & "', "
stSQL = stSQL & "            '" & CNNString & "'"
stSQL = stSQL & "           )"

 retValOk = ExecSQLCMD(stSQL, CNNString, OnErrShowDetails)
 RegSQLAccess_Login_ID = ADO_IDENTITY

Exit_Point:
 On Error Resume Next
 RegSQLAccess_Login = RegSQLAccess_Login_ID
Exit Function

Err_Point:
 If OnErrShowDetails Then
    BBErrorMSG err, "RegAccess"
 End If
 retValOk = False
 RegSQLAccess_Login_ID = 0
 Resume Exit_Point
End Function
