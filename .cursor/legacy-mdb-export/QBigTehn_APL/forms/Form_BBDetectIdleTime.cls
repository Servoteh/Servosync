VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BBDetectIdleTime"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub Form_Timer()
         ' IDLEMINUTES determines how much idle time to wait for before
         ' running the IdleTimeDetected subroutine.
         Const IDLEMINUTES = 1
 
         Static PrevControlName As String
         Static PrevFormName As String
         Static ExpiredTime
 
         Dim ActiveFormName As String
         Dim ActiveControlName As String
         Dim ExpiredMinutes
 
         On Error Resume Next
 
         ' Get the active form and control name.
 
         ActiveFormName = Screen.ActiveForm.Name
         If err Then
            ActiveFormName = "No Active Form"
            err = 0
         End If
 
         ActiveControlName = Screen.ActiveControl.Name
            If err Then
            ActiveControlName = "No Active Control"
            err = 0
         End If
 
         ' Record the current active names and reset ExpiredTime if:
         '    1. They have not been recorded yet (code is running
         '       for the first time).
         '    2. The previous names are different than the current ones
         '       (the user has done something different during the timer
         '        interval).
         If (PrevControlName = "") Or (PrevFormName = "") _
           Or (ActiveFormName <> PrevFormName) _
           Or (ActiveControlName <> PrevControlName) Then
            PrevControlName = ActiveControlName
            PrevFormName = ActiveFormName
            ExpiredTime = 0
         Else
            ' ...otherwise the user was idle during the time interval, so
            ' increment the total expired time.
            ExpiredTime = ExpiredTime + Me.TimerInterval
         End If
 
         ' Does the total expired time exceed the IDLEMINUTES?
         ExpiredMinutes = (ExpiredTime / 1000) / 60
         If ExpiredMinutes >= IDLEMINUTES Then
            ' ...if so, then reset the expired time to zero...
            ExpiredTime = 0
            ' ...and call the IdleTimeDetected subroutine.
            IdleTimeDetected ExpiredMinutes
         End If
      End Sub
 Private Sub IdleTimeDetected(ExpiredMinutes)
         Dim msg As String
         msg = "No user activity detected in the last "
         msg = msg & ExpiredMinutes & " minute(s)!"
         MsgBox msg, vbExclamation
      End Sub
