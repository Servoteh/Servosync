VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PlanSporneStavkePodforma"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub Form_AfterUpdate()
    If CurrentProject.AllForms("PlanSporneStavke").IsLoaded Then
        Forms!PlanSporneStavke.cmdPrimeniNaSve.Enabled = _
            (Nz(Forms!PlanSporneStavke.cmbOdlukaSve.Value, 0) <> 0)
    End If
End Sub
Private Sub OdlukaAkcija_AfterUpdate()
On Error Resume Next
    DoCmd.RunCommand acCmdSaveRecord
    Forms!PlanSporneStavke.ProveriOdluke
End Sub
