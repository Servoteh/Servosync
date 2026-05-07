VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "clsTreeViewEvents"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
' objavljeni TreeView s dogaðajima
Public WithEvents tvw As MSComctlLib.TreeView
Attribute tvw.VB_VarHelpID = -1

' NodeClick event
Private Sub tvw_NodeClick(ByVal Node As MSComctlLib.Node)
    ' Node.Tag sadrži IDCrtez
    Dim selectedID As Long
    selectedID = CLng(Node.tag)
    ' primer: prikaži detalje
    'Call ShowDetails(selectedID)
    Call Forms("PDMTreeView").ShowDetails(selectedID)
End Sub

