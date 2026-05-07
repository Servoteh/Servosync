VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_SRPENG_Recnik"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Sub ComboEngleski_AfterUpdate()
    ' Find the record that matches the control.
    Me.RecordsetClone.FindFirst "[Engleski] = '" & Me![ComboEngleski] & "'"
    Me.Bookmark = Me.RecordsetClone.Bookmark
    Me.ComboSrpski = Null
End Sub

Private Sub ComboEngleski_NotInList(NewData As String, Response As Integer)
    MsgBox "Zadata rec nije uneta u recnik!"
    Me!ComboEngleski = Null
    Response = DATA_ERRCONTINUE
End Sub

Private Sub ComboSrpski_AfterUpdate()
    ' Find the record that matches the control.
    Me.RecordsetClone.FindFirst "[Srpski] = '" & Me![ComboSrpski] & "'"
    Me.Bookmark = Me.RecordsetClone.Bookmark
    Me.ComboEngleski = Null
    
End Sub

Private Sub ComboSrpski_NotInList(NewData As String, Response As Integer)
 MsgBox "Zadata rec nije uneta u recnik!"
    Me!ComboEngleski = Null
    Response = DATA_ERRCONTINUE
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


