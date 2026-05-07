VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_frmMRP_Akcija"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub cmdRegenerisi_Click()
    TempVars!MRP_Akcija = 1
    DoCmd.Close acForm, Me.Name
End Sub

Private Sub cmdNovi_Click()
    TempVars!MRP_Akcija = 2
    DoCmd.Close acForm, Me.Name
End Sub

Private Sub cmdCancel_Click()
    TempVars!MRP_Akcija = 0
    DoCmd.Close acForm, Me.Name
End Sub
