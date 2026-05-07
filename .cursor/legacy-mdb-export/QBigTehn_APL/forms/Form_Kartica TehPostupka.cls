VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Kartica TehPostupka"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit

Private Sub Button38_Click()
On Error GoTo Err_Button38_Click


    Screen.PreviousControl.SetFocus
    DoCmd.FindNext

Exit_Button38_Click:
    Exit Sub

Err_Button38_Click:
    MsgBox Error$
    Resume Exit_Button38_Click
    
End Sub

Private Sub Dugme_Stop_Click()
On Error GoTo Err_Dugme_stop_Click


    DoCmd.Close

Exit_Dugme_stop_Click:
    Exit Sub

Err_Dugme_stop_Click:
    MsgBox Error$
    Resume Exit_Dugme_stop_Click
    
End Sub

Private Sub Form_Current()
    PrimeniUslove
End Sub

Private Sub Form_Open(Cancel As Integer)
    
    DoCmd.Maximize
End Sub


Private Sub ZaNaloga_AfterUpdate()
    'DoCmd.GoToControl ("IDRN")
    'DoCmd.FindRecord (Me![ZaNaloga])
    'Me![ZaNaloga] = Null
    'DoCmd.GoToControl ("ZaNaloga")
    Call NadjiRadniNalog
    PrimeniUslove
End Sub

Private Sub ZaRadnika_AfterUpdate()
    PrimeniUslove
End Sub

Private Sub ZaRJgrupaRC_AfterUpdate()
    PrimeniUslove
End Sub
Public Function PrimeniUslove()
   
   'Me!Podforma.SourceObject = ""
   'Me!Podforma.SourceObject = "Kartica TehPostupka - Podforma"
   Forms![Kartica TehPostupka]![Podforma].Form.PrimeniUslove
End Function
