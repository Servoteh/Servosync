VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BBQueryDef_Pregled"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Function ClearCurrentField()
 Screen.ActiveControl = Null
 PrimeniUslove
End Function
Private Function PrimeniUslove()
  Me.Requery
End Function

Private Sub AccParFormName_DblClick(Cancel As Integer)
    Me!ZaAccParFormName = Me!AccParFormName
    PrimeniUslove
End Sub

Private Sub AccRSFormName_DblClick(Cancel As Integer)
    Me!ZaAccRSFormName = Me!AccRSFormName
    PrimeniUslove
End Sub

Private Sub DugmeDetalnoQuery_Click()
On Error GoTo Err_DugmeDetalnoQuery_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "BBQueryDef"
    
    stLinkCriteria = "[QueryName]=" & "'" & Me![QueryName] & "'"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeDetalnoQuery_Click:
    Exit Sub

Err_DugmeDetalnoQuery_Click:
    MsgBox err.Description
    Resume Exit_DugmeDetalnoQuery_Click
    
End Sub

Private Sub ProcName_DblClick(Cancel As Integer)
    Me!ZaProcName = Me!ProcName
    PrimeniUslove
End Sub

Private Sub ProcType_DblClick(Cancel As Integer)
    Me!ZaProcType = Me!ProcType
    PrimeniUslove
End Sub

Private Sub QueryName_DblClick(Cancel As Integer)
    Me!ZaQueryName = Me!QueryName
    PrimeniUslove
End Sub
