VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_RibbonOnClickDetails"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub ZaFormName_AfterUpdate()
    Me.Requery
End Sub

Private Sub ZaFormName_DblClick(Cancel As Integer)
    Me!ZaFormName = Null
    Me.Requery
End Sub
