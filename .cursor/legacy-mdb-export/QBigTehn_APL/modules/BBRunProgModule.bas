Attribute VB_Name = "BBRunProgModule"
Option Compare Database
Option Explicit
Public Function DecodeEnvString(ByVal inpVal As String) As String
On Error GoTo errsub
    Dim lpos As Integer, rpos As Integer
    Dim envString As String
    Dim retVal As String
    Const sep = "%"
    
    retVal = inpVal
    Do
     lpos = InStr(retVal, sep)
     rpos = InStr(lpos + 1, retVal, sep)
     If (lpos > 0) And (lpos < rpos) Then
         envString = Mid(retVal, lpos + 1, rpos - lpos - 1)
         If envString <> "" Then
          If envString = "Date" Then
           envString = Format(Date, "dd-MM-yy")
          Else
           envString = Environ(envString)
          End If
         Else
          envString = ""
         End If
      retVal = Left(retVal, lpos - 1) & envString & Mid(retVal, rpos + 1)
     End If
    Loop While lpos < rpos
exitsub:
    DecodeEnvString = retVal
 Exit Function
errsub:
 MsgBox "Greška u funkciji <DecodeEnvString>"
 Resume exitsub
End Function
Public Function RunProg(cmdProg As String, Optional vbWindowStile As VbAppWinStyle = vbNormalFocus)
 On Error GoTo err_Func
 
 
 Dim retVal
 Dim stProgToRun  As String
 stProgToRun = DecodeEnvString(cmdProg)
 
  retVal = shell(stProgToRun, vbWindowStile)
  If retVal = 0 Then
   MsgBox "Ne može se pokrenuti program " & stProgToRun, vbExclamation, "BBSys"
  End If
exit_Func:
 RunProg = retVal
Exit Function

err_Func:
 BBErrorMSG err, "RunProg(" & cmdProg & " As String, Optional " & vbWindowStile & " As VbAppWinStyle = vbNormalFocus)"
 Resume exit_Func:
End Function
Public Function F_GenerateUserAppCmd(IDServer As Long, UserName As String, AppName As String) As String

 Dim stAppMsAccessPath As String
 Dim stAppPath As String
 Dim stAppMDWPath As String
 Dim stAppCMDPar As String
 Dim stAppWRKGRP As String
 
 Dim stAppCmd As String 'return value
 
stAppMsAccessPath = F_AppMsAccessPath(IDServer, AppName)
stAppPath = F_AppPath(IDServer, AppName)
stAppMDWPath = F_AppMDWPath(IDServer, AppName)
stAppCMDPar = F_AppCmdPar(IDServer, AppName)

If Nz(stAppMDWPath, "") <> "" Then
 stAppWRKGRP = " /wrkgrp " & """" & stAppMDWPath & """ "
Else
 stAppWRKGRP = ""
End If

stAppCmd = """" & stAppMsAccessPath & """ " & """" & stAppPath & """" & stAppWRKGRP & stAppCMDPar
 
 
 F_GenerateUserAppCmd = stAppCmd
End Function
Public Function F_AppMsAccessPath(IDServer As Long, AppName As String) As String
 Dim retVal As String
 retVal = Nz(DLookup("[MsAccessPath]", "T_Apps", "([IDServer] = " & IDServer & ") and ([AppName] = '" & AppName & "')"), "")
 F_AppMsAccessPath = retVal
End Function
Public Function F_AppPath(IDServer As Long, AppName As String) As String
 Dim retVal As String
 retVal = Nz(DLookup("[AppPath]", "T_Apps", "([IDServer] = " & IDServer & ") and ([AppName] = '" & AppName & "')"), "")
 F_AppPath = retVal
End Function
Public Function F_AppMDWPath(IDServer As Long, AppName As String) As String
 Dim retVal As String
 retVal = Nz(DLookup("[MDWPath]", "T_Apps", "([IDServer] = " & IDServer & ") and ([AppName] = '" & AppName & "')"), "")
 F_AppMDWPath = retVal
End Function
Public Function F_AppCmdPar(IDServer As Long, AppName As String) As String
 Dim retVal As String
 retVal = Nz(DLookup("[CmdPar]", "T_Apps", "([IDServer] = " & IDServer & ") and ([AppName] = '" & AppName & "')"), "")
 F_AppCmdPar = retVal
End Function
Public Function RunBatCMDLine(cmdLine As String, Optional vbWindowStile As VbAppWinStyle = vbNormalFocus)
 On Error GoTo err_Func
 
 
 Dim retVal
  '!!!!Ovo NIJE OK: retval = Shell("COMMAND.COM /C " & cmdLine, vbNormalFocus)
  
  retVal = shell(cmdLine, vbWindowStile) 'Ovo je OK
  'retval = Shell("CMD /C " & cmdLine, vbNormalFocus) 'Ovo je OK
  
  If retVal = 0 Then
   MsgBox "Ne može se izvršiti: " & cmdLine, vbExclamation, "BBSys"
  End If
exit_Func:
 RunBatCMDLine = retVal
Exit Function

err_Func:
 BBErrorMSG err, "RunBatCMDLine(" & cmdLine & " As String, Optional " & vbWindowStile & " As VbAppWinStyle = vbNormalFocus)"
 Resume exit_Func:
End Function
Private Function OpenAccessDB_1Ver(stAccessMDBFile As String)
' OpenAccessDB_1Ver("C:\SHARES\AcBaze\BigBit\BB_Tmp.mdb")
' OpenAccessDB_1Ver("C:\SHARES\AcBaze\BigBit\BB_Dnevnik.mdb")
Dim accapp As Access.Application
  
 Set accapp = New Access.Application
 
 accapp.OpenCurrentDatabase (stAccessMDBFile)
 accapp.Visible = True

 

End Function

Private Function OpenAccessDB_2Ver(stAccessMDBFile As String)
' OpenAccessDB_2Ver("C:\SHARES\AcBaze\BigBit\BB_Tmp.mdb")
' OpenAccessDB_2Ver("C:\SHARES\AcBaze\BigBit\BB_Dnevnik.mdb")
  
  
Application.FollowHyperlink stAccessMDBFile


End Function

Private Function OpenAccessDB_3Ver(stAccessMDBFile As String)
' OpenAccessDB_2Ver("C:\SHARES\AcBaze\BigBit\BB_Tmp.mdb")
' OpenAccessDB_2Ver("C:\SHARES\AcBaze\BigBit\BB_Dnevnik.mdb")
  
  
 RunProg stAccessMDBFile


End Function
Public Function OpenAccessDB(ByVal stAccessMDBFile As String, Optional AccessCMDLine, Optional MDWLine, Optional UserName, Optional Password) As String
'Izmena: 15-11-18
' "C:\Program Files (x86)\Microsoft Office\Office14\MSACCESS.EXE" "C:\SHARES\AcBaze\BigBit\BigBit_APL_2010.MDB" /wrkgrp "C:\SHARES\AcBaze\BigBit\Bigbit.mdw" /userNegovan
' "C:\Program Files (x86)\Microsoft Office\Office14\MSACCESS.EXE" "%UserProfile%\AcBaze\T-Group\BigBitTG\BigBit_APL_2010.MDB" /wrkgrp "C:\SHARES\TGroup\AcBaze\BigBitTG\BIGBIT.MDW" /cmd Prva maska
Dim stMDWLine As String
Dim stAccessCMDLine As String
Dim stFullAppCmdLine As String
Dim stUserName As String
Dim stPassword As String
Dim retValRun

If IsMissing(AccessCMDLine) Then
 'stAccessCMDLine = """C:\Program Files (x86)\Microsoft Office\Office14\MSACCESS.EXE"""
 stAccessCMDLine = """" & ReadCFGParametar("MSAccessProg") & """"
Else
 stAccessCMDLine = CStr(Nz(AccessCMDLine, ""))
End If

If IsMissing(MDWLine) Then
 stMDWLine = """" & Application.DBEngine.Properties("SystemDB") & """"
Else
 stMDWLine = CStr(Nz(MDWLine, ""))
End If

If IsMissing(UserName) Then
 stUserName = CurrentUser()
Else
 If Nz(UserName, "") = "" Then
  stUserName = CurrentUser()
 Else
  stUserName = CStr(Nz(UserName, ""))
 End If
End If

If IsMissing(Password) Then
 stPassword = BBCFG.UserPassword()
Else
 If Nz(Password, "") = "" Then
  stPassword = BBCFG.UserPassword()
 Else
  stPassword = CStr(Nz(Password, ""))
 End If
End If

stFullAppCmdLine = stAccessCMDLine & " " & """" & stAccessMDBFile & """" & " /WRKGRP " & stMDWLine & "" & "/user " & stUserName & "/pwd " & stPassword

retValRun = RunProg(stFullAppCmdLine)

OpenAccessDB = stFullAppCmdLine
End Function


