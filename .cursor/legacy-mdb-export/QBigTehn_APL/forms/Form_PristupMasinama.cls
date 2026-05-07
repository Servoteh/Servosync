VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PristupMasinama"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit


Private Sub IDMasine_GotFocus()
    Me!IDMasine.Requery
End Sub

Private Sub IDMasineSifra_GotFocus()
    Me!IDMasineSifra.Requery
End Sub
