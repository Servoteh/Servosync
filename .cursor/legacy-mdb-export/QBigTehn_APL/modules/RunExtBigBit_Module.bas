Attribute VB_Name = "RunExtBigBit_Module"
Option Compare Database
Option Explicit
Private Function DecodeEnvString(ByVal inpVal As String) As String
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

Public Function RunExtBigBit(Optional CMDLinePar) As Boolean
' debug.print RunExtBigBit("/CMD GKNalog")
On Error GoTo Err_Point
  Dim stMsAccessProg
  Dim stBigBitExtAPL
  Dim stBigBitExtMDW
  Dim stBigBitExtUserName
  Dim stBigBitExtPwd
  Dim stCMDLinePar
  Dim stFullAppCmdLine
  Dim retVal
  Dim MsgYesNo
  Dim retValOk As Boolean
  Dim stInputVal As String
  
pocetak:
  retValOk = True
  stMsAccessProg = ReadParametar("CFG_Lokal", "MSAccessProg")
  If Nz(stMsAccessProg, "") = "" Then
    stMsAccessProg = ReadParametar("CFG_Global", "MSAccessProg")
  End If
  stMsAccessProg = Nz(stMsAccessProg, "")
  
  If Nz(stMsAccessProg, "") = "" Then
    ' NEMA APLIKACIJE
    retValOk = False
    MsgBox "MsAccessProg nije zadata.", vbExclamation, "QMegaTeh"
    MsgYesNo = MsgBox("Da li želite da kreiram MsAccessProg parametar u CFG_Global tabeli?", vbYesNo, "QMegaTeh")
    If MsgYesNo = vbYes Then
     stInputVal = "C:\Program Files (x86)\Microsoft Office\Office14\MSACCESS.EXE"
     stInputVal = InputBox("MsAccessProg", "QMegaTeh", stInputVal)
     If stInputVal <> "" Then
      retValOk = WriteParametar("CFG_Global", "MsAccessProg", stInputVal)
      If retValOk Then
         MsgBox "U tabelu CFG_Global je upisan parametar MsAccessProg=" & stInputVal & vbCrLf & "Morate ponovo da pokrenete ovu opciju.", vbInformation, "QMegaTeh"
         GoTo pocetak:
      Else
         MsgBox "U tabelu CFG_Global nije upisan parametar MsAccessProg", vbExclamation, "QMegaTeh"
         GoTo Exit_Point
      End If
     End If
    End If
    retValOk = False
    GoTo Exit_Point
  End If
  
  stBigBitExtAPL = ReadParametar("CFG_Lokal", "BigBitExtAPL")
  If Nz(stBigBitExtAPL, "") = "" Then
    stBigBitExtAPL = ReadParametar("CFG_Global", "BigBitExtAPL")
  End If
  
  If Nz(stBigBitExtAPL, "") = "" Then
    ' NEMA APLIKACIJE
    retValOk = False
    MsgBox "BigBitExtAPL nije zadata.", vbExclamation, "QMegaTeh"
    MsgYesNo = MsgBox("Da li želite da kreiram BigBitExtAPL parametar u CFG_Global tabeli?", vbYesNo, "QMegaTeh")
    If MsgYesNo = vbYes Then
     stInputVal = Application.CurrentProject.Path & "\BigBit_APL_LIB.MDB"
     'stInputVal = "C:\SHARES\AcBaze\BigBit\BigBit_APL_2010.MDB"
     stInputVal = InputBox("BigBitExtAPL", "QMegaTeh", stInputVal)
     If stInputVal <> "" Then
      retValOk = WriteParametar("CFG_Global", "BigBitExtAPL", stInputVal)
      If retValOk Then
         MsgBox "U tabelu CFG_Global je upisan parametar BigBitExtAPL=" & stInputVal & vbCrLf & "Morate ponovo da pokrenete ovu opciju.", vbInformation, "QMegaTeh"
         GoTo pocetak:
      Else
         MsgBox "U tabelu CFG_Global nije upisan parametar BigBitExtAPL", vbExclamation, "QMegaTeh"
         GoTo Exit_Point
      End If
     End If
    End If
    retValOk = False
    GoTo Exit_Point
  End If
  
  stBigBitExtMDW = ReadParametar("CFG_Lokal", "BigBitExtMDW")
  If Nz(stBigBitExtMDW, "") = "" Then
    stBigBitExtMDW = ReadParametar("CFG_Global", "BigBitExtMDW")
  End If
  
  If Nz(stBigBitExtMDW, "") = "" Then
    stBigBitExtMDW = Application.DBEngine.Properties("SystemDB")
  End If
  stBigBitExtMDW = Nz(stBigBitExtMDW, "")
  
  
  stBigBitExtUserName = ReadParametar("CFG_Lokal", "BigBitExtUserName")
  If Nz(stBigBitExtUserName, "") = "" Then
    stBigBitExtUserName = ReadParametar("CFG_Global", "BigBitExtUserName")
  End If
  stBigBitExtUserName = Nz(stBigBitExtUserName, "Korisnik")
  
  stBigBitExtPwd = ReadParametar("CFG_Lokal", "BigBitExtPwd")
  If Nz(stBigBitExtPwd, "") = "" Then
    stBigBitExtPwd = ReadParametar("CFG_Global", "BigBitExtPwd")
  End If
  stBigBitExtPwd = Nz(stBigBitExtPwd, "")
  
  If IsMissing(CMDLinePar) Then
    stCMDLinePar = "/CMD Prva maska"
  Else
    stCMDLinePar = CStr(CMDLinePar)
  End If
  
  'za test stBigBitExtAPL = "C:\SHARES\AcBaze\BigBit\EXTENDED\Digitron.mdb"
  'OpenAccessDB stBigBitExtAPL, stMsAccessProg, stBigBitExtMDW, stBigBitExtUserName, stBigBitExtPwd
  
  stFullAppCmdLine = stMsAccessProg & " " & """" & stBigBitExtAPL & """" & " /WRKGRP " & stBigBitExtMDW & "" & " /user " & stBigBitExtUserName & " /pwd " & stBigBitExtPwd & " " & stCMDLinePar
  stFullAppCmdLine = DecodeEnvString(stFullAppCmdLine)
  retVal = shell(stFullAppCmdLine, vbMaximizedFocus)
  
Exit_Point:
On Error Resume Next

 RunExtBigBit = retValOk
 
Exit Function
Err_Point:
 MsgBox "Err.Number: " & err.Number & vbCrLf & err.Description
 retValOk = False
 Resume Exit_Point
End Function
