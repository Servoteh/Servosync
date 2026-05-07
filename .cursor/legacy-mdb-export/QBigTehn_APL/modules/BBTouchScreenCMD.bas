Attribute VB_Name = "BBTouchScreenCMD"
Option Compare Database
Option Explicit
'**********************************************************
'*         NAVIGACIJA  & +, -
'**********************************************************
Public Function BBTSPlusMinus(PlusMinus As String, Optional Kol = 1)
    Dim PrevAktCtl As control
    Set PrevAktCtl = Screen.PreviousControl
    If PrevAktCtl.ControlType <> AcControlType.acTextBox Then Exit Function
    If PrevAktCtl.Locked Then Exit Function
    If Not PrevAktCtl.Parent.AllowEdits Then Exit Function
    If Not PrevAktCtl.Enabled Then Exit Function
    
    If IsNumeric(PrevAktCtl.Value) Then
     If PlusMinus = "+" Then
      PrevAktCtl.Value = PrevAktCtl.Value + Kol
     ElseIf PlusMinus = "-" Then
      PrevAktCtl.Value = PrevAktCtl.Value - Kol
     End If
    End If
    On Error Resume Next
    PrevAktCtl.SetFocus
    Set PrevAktCtl = Nothing
End Function
Public Function BBTSUndo()
On Error Resume Next
  DoCmd.RunCommand acCmdUndo
End Function

Public Function BBTSDeleteRecord()
On Error Resume Next
    DoCmd.RunCommand acCmdSelectRecord
    DoCmd.RunCommand acCmdDeleteRecord
End Function

Public Function BBTSMovePreviousRecord(Optional SubFormName)
On Error Resume Next
    If Not IsMissing(SubFormName) Then
     DoCmd.GoToControl SubFormName
    End If
    
    DoCmd.GoToRecord , , acPrevious
End Function
Public Function BBTSMoveNextRecord(Optional SubFormName)
On Error Resume Next
    If Not IsMissing(SubFormName) Then
     DoCmd.GoToControl SubFormName
    End If
    DoCmd.GoToRecord , , acNext
End Function
Public Function BBTSMoveFirstRecord(Optional SubFormName)
'Kreirano: 03-11-2021
On Error Resume Next
    If Not IsMissing(SubFormName) Then
     DoCmd.GoToControl SubFormName
    End If
    DoCmd.GoToRecord , , acFirst
End Function
Public Function BBTSMoveLastRecord(Optional SubFormName)
'Kreirano: 03-11-2021
On Error Resume Next
    If Not IsMissing(SubFormName) Then
     DoCmd.GoToControl SubFormName
    End If
    DoCmd.GoToRecord , , acLast
End Function
Public Function BBTSSaveRecord()
On Error Resume Next
   ' DoCmd.RunCommand acCmdSave
   ' DoCmd.DoMenuItem acFormBar, acRecordsMenu, acSaveRecord, , acMenuVer70
    DoCmd.RunCommand acCmdSaveRecord
End Function
