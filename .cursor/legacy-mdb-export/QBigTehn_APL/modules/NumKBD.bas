Attribute VB_Name = "NumKBD"
Option Compare Database
Option Explicit
Public KbdEditCtl As control
Public KbdEditForm As Form


Public Sub OpenNumKbd(ByRef ctlForEdit As control, ByRef frmForEdit As Form)
Dim frm As Form
Dim ctl As control
Dim leftPos As Long
Dim topPos As Long

' On Error Resume Next

Set KbdEditCtl = ctlForEdit
Set KbdEditForm = frmForEdit
DoCmd.OpenForm "KbdNum"
'pLeft = ctlForEdit.Left + ctlForEdit.Width
'pTop = ctlForEdit.Top + ctlForEdit.Height
'If pTop + Forms!KbdNum.Detail.Height > frmForEdit.Detail.Height Then
' pTop = pTop - (pTop + Forms!KbdNum.Detail.Height - frmForEdit.Detail.Height)
'End If
leftPos = Nz(ReadParametar("CFG_Lokal", "Kasa_IzborArtiklaPanel_LeftPos"), 8000)
leftPos = leftPos - 4000

topPos = Nz(ReadParametar("CFG_Lokal", "Kasa_IzborArtiklaPanel_TopPos"), -200)
topPos = topPos + 2500

Forms!KbdNum.Move leftPos, topPos

'Forms!KbdNum!UnetaRec =
Exit Sub
  
  If Forms.Count > 0 Then
        Set frm = Screen.ActiveForm
        If frm.Controls.Count > 0 Then
            Set ctl = Screen.ActiveControl
            If ctl.ControlType = acCommandButton Then 'ako je pozvan preko dugmeta
                On Error Resume Next
                Set ctl = Screen.PreviousControl
            End If
            
             If ctl.ControlType = acTextBox Or ctl.ControlType = acComboBox Or ctl.ControlType = acListBox Then
                'KBD.DozvoljenEdit = True
             Else
                'KBD.DozvoljenEdit = False
             End If
             
        End If
    End If
    
    DoCmd.OpenForm "KbdNum"
    
End Sub
