VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Digitron"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit


Private Sub BrojDecimala_AfterUpdate()
     Me![DigitronPodforma].Form![VredIzraza].DecimalPlaces = Me![BrojDecimala]
     Me![DigitronPodforma].Form![Total].DecimalPlaces = Me![BrojDecimala]
End Sub

Private Sub ComboDatum_GotFocus()
    Me!ComboDatum.Requery
End Sub

Private Sub ComboOpis_GotFocus()
    Me!ComboOpis.Requery
End Sub

Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click


    DoCmd.Close

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
    
End Sub
Private Sub DugmeObrisiDigitron_Click()
On Error GoTo Err_DugmeObrisiDigitron_Click

    Dim stDocName As String
    
    DoCmd.SetWarnings False
    stDocName = "ObrisiDigitron"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    
    DugmeNoviSlog_Click

Exit_DugmeObrisiDigitron_Click:
    DoCmd.SetWarnings True
   Exit Sub

Err_DugmeObrisiDigitron_Click:
    MsgBox err.Description
    Resume Exit_DugmeObrisiDigitron_Click
    
End Sub
Private Sub DugmePrint_Click()
On Error GoTo Err_DugmePrint_Click

    Dim stDocName As String
    
    Dim BigBit As DAO.Database
    Dim rst As DAO.Recordset

     DoCmd.DoMenuItem acFormBar, acRecordsMenu, acSaveRecord, , acMenuVer70
     
    Set BigBit = CurrentDb
    Set rst = BigBit.OpenRecordset("Digitron", dbOpenDynaset)
    
     If rst.RecordCount > 0 Then
        DoCmd.Minimize
        stDocName = "Digitron"
        BBOpenReport stDocName, acPreview
    End If
Exit_DugmePrint_Click:
    Set rst = Nothing
    Set BigBit = Nothing
    Exit Sub

Err_DugmePrint_Click:
    MsgBox err.Description
    Resume Exit_DugmePrint_Click
    
End Sub
Private Sub DugmeNoviSlog_Click()
On Error GoTo Err_DugmeNoviSlog_Click


    DoCmd.GoToRecord , , acNewRec
    Me![DATUM] = Date
    DoCmd.GoToControl "DigitronPodforma"
    DoCmd.GoToControl "Izraz"

Exit_DugmeNoviSlog_Click:
    Exit Sub

Err_DugmeNoviSlog_Click:
    MsgBox err.Description
    Resume Exit_DugmeNoviSlog_Click
    
End Sub
Private Sub Form_Current()
    'Forms![Digitron]![DigitronPodforma].Form![VredIzraza].DecimalPlaces = Nz(Me![BrojDecimala],0)
    On Error Resume Next
    Me![DigitronPodforma].Form![VredIzraza].DecimalPlaces = Me![BrojDecimala]
    Me![DigitronPodforma].Form![Total].DecimalPlaces = Me![BrojDecimala]
End Sub

Private Sub Form_Open(Cancel As Integer)
    
    DoCmd.GoToRecord , , acLast
    Me![DigitronPodforma].Form![VredIzraza].DecimalPlaces = Me![BrojDecimala]
     Me![DigitronPodforma].Form![Total].DecimalPlaces = Me![BrojDecimala]
    
End Sub
Sub ComboDatum_AfterUpdate()
    ' Find the record that matches the control.
    Me.RecordsetClone.FindFirst "[IdZagDig] = " & Me![ComboDatum]
    Me.Bookmark = Me.RecordsetClone.Bookmark
    Me![ComboDatum] = Null
End Sub

Sub ComboOpis_AfterUpdate()
    ' Find the record that matches the control.
    Me.RecordsetClone.FindFirst "[IdZagDig] = " & Me![ComboOpis]
    Me.Bookmark = Me.RecordsetClone.Bookmark
    Me![ComboOpis] = Null
End Sub


