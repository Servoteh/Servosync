VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_frmRibbonOnForm"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub ZaFormu_AfterUpdate()
    Me.Requery
End Sub

Private Sub ZaFormu_DblClick(Cancel As Integer)
    Me!ZaFormu = Null
    Me.Requery
End Sub

Private Sub ZaGrupuUsera_AfterUpdate()
    Me.Requery
End Sub

Private Sub ZaGrupuUsera_DblClick(Cancel As Integer)
    Me!ZaGrupuUsera = Null
    Me.Requery
End Sub

Private Sub ZaRibbonName_AfterUpdate()
    Me.Requery
End Sub

Private Sub ZaRibbonName_DblClick(Cancel As Integer)
    Me!ZaRibbonName = Null
    Me.Requery
End Sub
