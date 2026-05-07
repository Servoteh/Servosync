VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_frmUSysRibbons"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub btnCopyXML_Click()
    On Error GoTo ErrHandler

    Me!RibbonXML.SetFocus
    Me!RibbonXML.selstart = 0
    Me!RibbonXML.sellength = Len(Me!RibbonXML.Text)

    DoCmd.RunCommand acCmdCopy

    MsgBox "XML je kopiran u clipboard.", vbInformation, "PDM Ribbon"

ExitHere:
    Exit Sub

ErrHandler:
    MsgBox "Greška pri kopiranju XML-a: " & err.Description, vbCritical
    Resume ExitHere
End Sub


Private Sub DugmePronadjiIZameni_Click()
On Error GoTo Err_DugmePronadjiIZameni_Click

    Dim stDocName As String

    DoCmd.SetWarnings False
    stDocName = "BAZE_PronadjiIZameni"
    DoCmd.OpenQuery stDocName, acNormal, acEdit

Exit_DugmePronadjiIZameni_Click:
    Me.Requery
    DoCmd.SetWarnings True
    Exit Sub

Err_DugmePronadjiIZameni_Click:
    MsgBox err.Description
    Resume Exit_DugmePronadjiIZameni_Click

End Sub
