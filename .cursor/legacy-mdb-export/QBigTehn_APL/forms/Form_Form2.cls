VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Form2"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub BrojCrteza_AfterUpdate()
    Me!Podforma.Requery
End Sub

Private Sub IDVrstaKvaliteta_AfterUpdate()
    Me!Podforma.Requery
End Sub
