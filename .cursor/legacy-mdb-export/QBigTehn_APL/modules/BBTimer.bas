Attribute VB_Name = "BBTimer"
Option Compare Database
Option Explicit
Private PoslednjiCheckTime As Single
Public Function BBTimerStart()
  PoslednjiCheckTime = Timer
End Function
Public Function BBTimerTrajanjeSec(Optional stPoruka As String = "", Optional timerFrom As Single = 0, Optional ResetTimer As Boolean = False) As String
Dim CurrentTimer As Single
Dim stRetVal As String

CurrentTimer = Timer
'stRetVal = stPoruka & " : " & CurrentTimer
 stRetVal = stPoruka
 
If Round(timerFrom) > 0.001 Then
 PoslednjiCheckTime = timerFrom
ElseIf Abs(PoslednjiCheckTime) <= 0.01 Or ResetTimer Then
 PoslednjiCheckTime = CurrentTimer
End If
'stRetVal = stRetVal & " -  " & PoslednjiCheckTime & " = " & CurrentTimer - PoslednjiCheckTime
stRetVal = stRetVal & CurrentTimer - PoslednjiCheckTime & " sec."

 PoslednjiCheckTime = CurrentTimer
 BBTimerTrajanjeSec = stRetVal
End Function
Public Function BBTimerMsgTrajanje(Optional stPoruka As String = "Trajanje= ")
    MsgBox stPoruka & BBTimerTrajanjeSec, vbInformation, "QMegaTeh"
End Function
