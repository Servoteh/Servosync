VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Recnik"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Public Function PrimeniUslove()
    Me.Requery
End Function
Private Function ClearCurrentVal()
   Screen.ActiveControl.Value = Null
   PrimeniUslove
End Function
Private Sub Combo6_GotFocus()
    Me!Combo6.Requery
End Sub

Private Sub ComboNaJezik_AfterUpdate()
     Me.Requery
End Sub

Private Sub ComboNaJezik_DblClick(Cancel As Integer)
    BBCFG.IDJezik = Me!ComboNaJezik
End Sub

Private Sub ComboSaJezika_AfterUpdate()
    Me.Requery
End Sub

Private Sub ComboSaJezika_DblClick(Cancel As Integer)
    BBCFG.IDJezik = Me!ComboSaJezika
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
Private Sub Combo6_AfterUpdate()
    ' Find the record that matches the control.
    Dim rs As Object

    Set rs = Me.Recordset.Clone
    rs.FindFirst "[RecSaJezika] = '" & Me![Combo6] & "'"
    If Not rs.EOF Then Me.Bookmark = rs.Bookmark
    Me![Combo6] = Null
End Sub

Private Sub DugmNoviSlog_Click()
On Error GoTo Err_DugmNoviSlog_Click


    DoCmd.GoToRecord , , acNewRec
    DoCmd.GoToControl "RecSaJezika"

Exit_DugmNoviSlog_Click:
    Exit Sub

Err_DugmNoviSlog_Click:
    MsgBox err.Description
    Resume Exit_DugmNoviSlog_Click
    
End Sub

Private Sub Form_BeforeUpdate(Cancel As Integer)
    Me!IDSaJezika = Me!ComboSaJezika
    Me!IDNaJezik = Me!ComboNaJezik
End Sub

Private Sub Form_Open(Cancel As Integer)
    
    Me.Requery
    On Error Resume Next
    
    If (CurrentUser = "Negovan") Or UserUGrupi(CurrentUser(), "PowerFulUsers") Then
        Me!RecSaJezika.Locked = False
    End If
    
    DoCmd.Maximize
    DoCmd.GoToControl "Combo6"
End Sub
Private Sub DugmeOtkljucaj_Click()
On Error GoTo Err_DugmeOtkljucaj_Click


   Me.AllowDeletions = True
   Me!RecSaJezika.Locked = False

Exit_DugmeOtkljucaj_Click:
    Exit Sub

Err_DugmeOtkljucaj_Click:
    MsgBox err.Description
    Resume Exit_DugmeOtkljucaj_Click
    
End Sub

Private Sub DugmeSrpEngRecnik_Click()
On Error GoTo Err_DugmeSrpEngRecnik_Click

    Dim stDocName As String
    Dim LinkCriteria As String

    stDocName = "SRPENG_Recnik"
    BBOpenForm stDocName, , , LinkCriteria
    
Exit_DugmeSrpEngRecnik_Click:
    Exit Sub

Err_DugmeSrpEngRecnik_Click:
    MsgBox err.Description
    Resume Exit_DugmeSrpEngRecnik_Click
    
End Sub

Private Sub RecNaJezik_DblClick(Cancel As Integer)
    Me!ZaRecNaJezik = Me!RecNaJezik
    PrimeniUslove
End Sub

Private Sub RecSaJezika_DblClick(Cancel As Integer)
    Me!ZaRecSaJezika = Me!RecSaJezika
    PrimeniUslove
End Sub
