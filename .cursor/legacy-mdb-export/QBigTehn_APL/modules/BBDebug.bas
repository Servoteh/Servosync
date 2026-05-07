Attribute VB_Name = "BBDebug"
Option Compare Database
Option Explicit

Public Function DebugPrintTimer(Optional stPoruka As String = "", Optional timerFrom As Single = 0, Optional ResetTimer As Boolean = False) As String
Dim CurrentTimer As Single
Dim stRetVal As String
Static PoslednjiCheckTime As Single

CurrentTimer = Timer
stRetVal = stPoruka & " : " & CurrentTimer

If Round(timerFrom) > 0.001 Then
 PoslednjiCheckTime = timerFrom
ElseIf Abs(PoslednjiCheckTime) <= 0.01 Or ResetTimer Then
 PoslednjiCheckTime = CurrentTimer
End If
stRetVal = stRetVal & " -  " & PoslednjiCheckTime & " = " & CurrentTimer - PoslednjiCheckTime


 If CurrentUser = "Negovan" Then
  Debug.Print stRetVal
 End If
 PoslednjiCheckTime = CurrentTimer
 DebugPrintTimer = stRetVal
End Function
Public Function DebugPrint(Optional AnyValue)
 If BBCFG.SysRazvojAPL And CurrentUser = "Negovan" Then
   Debug.Print AnyValue
 End If
End Function


