VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_DigitronPodforma"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False

Option Compare Database
Option Explicit


Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click


    DoCmd.Close

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
    
End Sub

Private Sub Form_AfterDelConfirm(Status As Integer)
    DoCmd.SetWarnings True
End Sub


Private Sub Form_Delete(Cancel As Integer)
    DoCmd.SetWarnings False
End Sub
Private Sub Command13_Click()
On Error GoTo Err_Command13_Click

    Dim stDocName As String

    stDocName = "ObrisiDigitron"
    DoCmd.SetWarnings False
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    Me.Requery
Exit_Command13_Click:
    DoCmd.SetWarnings True
    Exit Sub

Err_Command13_Click:
    MsgBox err.Description
    Resume Exit_Command13_Click
    
End Sub
Private Sub DugmePrint_Click()
On Error GoTo Err_DugmePrint_Click

    Dim stDocName As String
    
    Dim BigBit As DAO.Database
    Dim rst As DAO.Recordset


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
