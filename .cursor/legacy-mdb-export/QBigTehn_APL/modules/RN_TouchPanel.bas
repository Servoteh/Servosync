Attribute VB_Name = "RN_TouchPanel"
Option Compare Database
Option Explicit

Public actFrm As Form
Public actCtl As control
Public Function OpenKeyboardNumeric()
    Dim InputString
    
    
    Dim ctlTop As Integer
    Dim ctlLeft As Integer
    Dim ctlWidth As Integer
    Dim ctlHeight As Integer
    Dim winTop As Integer
    Dim winLeft As Integer
    Dim winWidth As Integer
    Dim winHeight As Integer
    
    Dim intCurTop As Integer
    Dim intCurLeft As Integer
    Dim BorderWidthLeft As Integer
    Dim BorderWidthTop As Integer
    Dim headHight As Integer
    
    Dim PozicionirajKeyb As Boolean
    
    PozicionirajKeyb = False
    
    If Forms.Count > 0 Then
        PozicionirajKeyb = True
        
        Set actFrm = Screen.ActiveForm
        winTop = actFrm.WindowTop
        winLeft = actFrm.WindowLeft
        winWidth = actFrm.WindowWidth
        winHeight = actFrm.WindowHeight
        
        intCurTop = actFrm.CurrentSectionTop
        intCurLeft = actFrm.CurrentSectionLeft
        
        'BorderWidth = actFrm.BorderWidth
        BorderWidthLeft = 400
        BorderWidthTop = 600
        
        
        ' headHight = actFrm.Section(acHeader).Height
        If actFrm.Controls.Count > 0 Then
            PozicionirajKeyb = PozicionirajKeyb And True
            Set actCtl = Screen.ActiveControl
            ctlTop = actCtl.Top
            ctlLeft = actCtl.Left
            ctlWidth = actCtl.Width
            ctlHeight = actCtl.height
             
             If actCtl.ControlType = acTextBox Or _
                actCtl.ControlType = acComboBox Or _
                actCtl.ControlType = acListBox Then
    
                InputString = actCtl.Value
             End If
        End If
    End If
    
        DoCmd.OpenForm "KeyboardNumeric"
        'Forms!KeyboardNumeric.UnetaRec = InputString
        
        If Forms!KeyboardNumeric.Moveable And PozicionirajKeyb Then
            'Forms!KeyboardNumeric.Move _
            'left:=winLeft + ctlLeft + 400, top:=winTop + ctlTop + 600 + ctlHeight + headHight ', Width:=400, Height:=300
            
            Forms!KeyboardNumeric.Move _
            Left:=winLeft + intCurLeft + ctlLeft + BorderWidthLeft, Top:=winTop + intCurTop + ctlTop + ctlHeight + BorderWidthTop
        End If
End Function
Public Function OpenKeyboard()
    Dim InputString
    If Forms.Count > 0 Then
        Set actFrm = Screen.ActiveForm
        If actFrm.Controls.Count > 0 Then
            Set actCtl = Screen.ActiveControl
             If actCtl.ControlType = acTextBox Or _
                actCtl.ControlType = acComboBox Or _
                actCtl.ControlType = acListBox Then
    
                InputString = actCtl.Value
             End If
        End If
    End If
    DoCmd.OpenForm "Keyboard"
    Forms!Keyboard.UnetaRec = InputString
    
End Function
Public Function OtvoriKeyboardNumericSaOpisom(ByVal stFormName As String) As Boolean
On Error GoTo Err_Point
    Dim InputString
    Dim retValOk As Boolean
    Dim ctlTop As Integer
    Dim ctlLeft As Integer
    Dim ctlWidth As Integer
    Dim ctlHeight As Integer
    Dim winTop As Integer
    Dim winLeft As Integer
    Dim winWidth As Integer
    Dim winHeight As Integer
    
    Dim intCurTop As Integer
    Dim intCurLeft As Integer
    Dim BorderWidthLeft As Integer
    Dim BorderWidthTop As Integer
    Dim headHight As Integer
    
    Dim PozicionirajKeyb As Boolean
    
    Dim stLinkCriteria As String
    
    retValOk = True
    PozicionirajKeyb = False
    
    If Forms.Count > 0 Then
        PozicionirajKeyb = True
        
        Set actFrm = Screen.ActiveForm
        winTop = actFrm.WindowTop
        winLeft = actFrm.WindowLeft
        winWidth = actFrm.WindowWidth
        winHeight = actFrm.WindowHeight
        
        intCurTop = actFrm.CurrentSectionTop
        intCurLeft = actFrm.CurrentSectionLeft
        
        'BorderWidth = actFrm.BorderWidth
        BorderWidthLeft = 400
        BorderWidthTop = 600
        
        
        ' headHight = actFrm.Section(acHeader).Height
        If actFrm.Controls.Count > 0 Then
            PozicionirajKeyb = PozicionirajKeyb And True
            Set actCtl = Screen.ActiveControl
            ctlTop = actCtl.Top
            ctlLeft = actCtl.Left
            ctlWidth = actCtl.Width
            ctlHeight = actCtl.height
             
             If actCtl.ControlType = acTextBox Or _
                actCtl.ControlType = acComboBox Or _
                actCtl.ControlType = acListBox Then
    
                InputString = actCtl.Value
             End If
        End If
    End If
    
        'DoCmd.OpenForm "KeyboardNumeric"
        'Forms!KeyboardNumeric.UnetaRec = InputString
    
        'DoCmd.OpenForm "KeyboardSaPostupkom"
        DoCmd.OpenForm stFormName
        
        If Forms!KeyboardSaPostupkom.Moveable And PozicionirajKeyb Then
            'Forms!KeyboardNumeric.Move _
            'left:=winLeft + ctlLeft + 400, top:=winTop + ctlTop + 600 + ctlHeight + headHight ', Width:=400, Height:=300
            
            Forms!KeyboardSaPostupkom.Move _
            Left:=winLeft + intCurLeft + ctlLeft + BorderWidthLeft, Top:=winTop + intCurTop + ctlTop + ctlHeight + BorderWidthTop
        End If
        
Exit_Point:
 On Error Resume Next
 OtvoriKeyboardNumericSaOpisom = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "OtvoriKeyboardNumericSaOpisom"
    retValOk = False
    Resume Exit_Point
End Function

