VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_B_ZaliheArtPoMagPodforma"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Sub Form_Error(DataErr As Integer, Response As Integer)
  MsgBox "DataErr=" & DataErr
  If DataErr = 2580 Then
   Me.RecordSource = ""
   Response = acDataErrContinue
  End If
End Sub
