VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_ReklamniPanel1"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Public Sub PomeriIspis()
On Error Resume Next
   Dim TopVal As Integer
   Dim LeftVal As Integer
   
    TopVal = Int((100 * Rnd) + 1) - 50
    LeftVal = Int((100 * Rnd) + 1) - 50
    'Me.Detail.BackColor = Me.Detail.BackColor + TopVal
    Me!LabelProdavnica1.Top = Me!LabelProdavnica1.Top + TopVal
    Me!LabelProdavnica1.Left = Me!LabelProdavnica1.Top + LeftVal
End Sub
