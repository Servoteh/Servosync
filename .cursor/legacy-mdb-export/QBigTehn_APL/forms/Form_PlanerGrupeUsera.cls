VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PlanerGrupeUsera"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub UserName_DblClick(Cancel As Integer)
    Me!UserName.RowSource = DRST_UseriNaBazi.GetString(, , ";", ";")
End Sub
