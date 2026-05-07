Attribute VB_Name = "MegaSetFormBackColor"
Option Compare Database
Option Explicit

' Pomoæno: da li RecordSource ima traženo polje (npr. ColorKey)
Private Function PostojiPoljeURecordSource(frm As Form, ByVal FieldName As String) As Boolean
    On Error GoTo done
    Dim f As DAO.Field
    For Each f In frm.RecordsetClone.Fields
        If StrComp(f.Name, FieldName, vbTextCompare) = 0 Then
            PostojiPoljeURecordSource = True
            Exit Function
        End If
    Next f
done:
End Function

' Glavna: primeni 6 CF pravila na SVE TextBox/ComboBox kontrole u Detail sekciji
' Boje su blage; po potrebi promeni RGB vrednosti.
Public Sub PrimeniColorKeyZaBojuPozadine(ByVal frm As Form)
On Error GoTo ErrH
    Dim ctl As control
    Dim fc As FormatConditions
    Dim rule As FormatCondition

    ' 0) zaštita: mora postojati polje ColorKey u RecordSource-u
    If Not PostojiPoljeURecordSource(frm, "ColorKey") Then
        MsgBox "RecordSource ne sadrži polje 'ColorKey'.", vbExclamation, "ApplyColorKeyCF"
        Exit Sub
    End If

    ' 1) iskljuèi Access-ovo alterniranje da ne remeti naše boje
    With frm.Section(acDetail)
        .AlternateBackColor = .BackColor
    End With

    ' 2) naði sve TextBox/ComboBox iz Detail sekcije i zalepi 6 pravila
    For Each ctl In frm.Controls
        If ctl.Section = acDetail Then
            If ctl.ControlType = acTextBox Or ctl.ControlType = acComboBox Then
                Set fc = ctl.FormatConditions
                On Error Resume Next
                fc.Delete   ' poèisti stara pravila (ako ih ima)
                On Error GoTo ErrH

                Set rule = fc.Add(acExpression, , "[ColorKey]=0")
                rule.BackColor = RGB(235, 235, 235)  ' siva
                
                Set rule = fc.Add(acExpression, , "[ColorKey]=1")
                rule.BackColor = RGB(255, 255, 240) 'RGB(255, 250, 205) 'RGB(255, 255, 224) 'RGB(255, 255, 210) 'RGB(255, 242, 204)  ' žuta

                Set rule = fc.Add(acExpression, , "[ColorKey]=2")
                rule.BackColor = RGB(220, 240, 255)  ' plavièasta
                
                Set rule = fc.Add(acExpression, , "[ColorKey]=3")
                rule.BackColor = RGB(226, 239, 218)  ' zelena
                
                Set rule = fc.Add(acExpression, , "[ColorKey]=4")
                rule.BackColor = RGB(237, 226, 246)  ' ljubièasta

                Set rule = fc.Add(acExpression, , "[ColorKey]=5")
                rule.BackColor = RGB(252, 228, 214)  ' narandžasta
            End If
        End If
    Next ctl

    Exit Sub
ErrH:
    MsgBox "PrimeniColorKeyZaBojuPozadine: " & err.Description, vbExclamation
End Sub

' Overload: poziv po imenu forme (forma mora biti otvorena)
Public Sub PrimeniColorKeyZaBojuPozadine_ByFormName(ByVal FormName As String)
On Error GoTo ErrH
    If Not CurrentProject.AllForms(FormName).IsLoaded Then
        MsgBox "Forma '" & FormName & "' nije otvorena.", vbExclamation
        Exit Sub
    End If
    PrimeniColorKeyZaBojuPozadine Forms(FormName)
    Exit Sub
ErrH:
    MsgBox err.Description, vbExclamation, "PrimeniColorKeyZaBojuPozadine_ByFormName"
End Sub
