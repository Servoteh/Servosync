VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_UR_UnosT"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub PrikaziControle()
Dim i As Integer
Dim txtName As String
Dim sledeceLevo As Long
Dim ctrl As control

' On Error Resume Next


'   For Each ctrl In Me.Controls
'   If ctrl.ControlType = acTextBox Then
'                'Debug.Print ctrl.Name, ctrl.Properties("ControlType")
'    If ctrl.Properties("ControlSource") = "42" Then
'        ctrl.Visible = False
'    End If
'   End If
'   Next
'? TypeName(Me.Controls(txtName))

sledeceLevo = 8
 For i = 0 To CurrentDb.TableDefs("UR_UnosT").Fields.Count() - 1
 
    txtName = CurrentDb.TableDefs("UR_UnosT").Fields(i).Name
    
    If Me.Controls(txtName).Properties("Section") = acDetail Then
    
        Me.Controls(txtName).Properties("ControlSource") = txtName
        Me.Controls(txtName).Properties("Visible") = True
        Me.Controls(txtName).Properties("Left") = sledeceLevo
        Me.Controls(txtName).Properties("Tabindex") = i
                
        Me.Controls(txtName & "_Label").Properties("Visible") = True
        Me.Controls(txtName & "_Label").Properties("Left") = sledeceLevo
        
        sledeceLevo = sledeceLevo + Me.Controls(txtName).Properties("Width")
    End If
    
 Next i
    
End Sub
Private Sub Form_Open(Cancel As Integer)
    PrikaziControle
End Sub

Private Function PostojiKontrolaNaFormi(ctrlName As String) As Boolean
    Dim retVal As Boolean
    Dim ctrl As control
    retVal = False
    For Each ctrl In Me.Controls
        retVal = retVal Or ctrl.Name = ctrlName
    Next
    PostojiKontrolaNaFormi = retVal
End Function
