Attribute VB_Name = "BBSetFormControls"
Option Compare Database
Option Explicit
Private Const T_APL_FormeIKontrole = "T_APL_FormeIKontrole"
Public Function SaveControlProp(stFormName As String, stControlName As String, stControlPropName As String, Optional stControlPropValue1, Optional stControlPropValue2) As Boolean
'Kreirano 18-05-19

On Error GoTo Err_Point

    Dim retVal As Boolean
    Dim db As DAO.Database
    Dim rs As DAO.Recordset
    Dim stSQL As String
    
    Set db = CurrentDb
    If Not PostojiTabelaUBazi(T_APL_FormeIKontrole, db) Then
      err.Raise vbObjectError + 1, "QMegaTeh", "Ne postoji tabela " & T_APL_FormeIKontrole
    End If
    stSQL = "SELECT * FROM " & T_APL_FormeIKontrole
    stSQL = stSQL & " WHERE"
    stSQL = stSQL & " ([FormName]='" & stFormName & "')"
    stSQL = stSQL & " AND ([ControlName]='" & stControlName & "')"
    stSQL = stSQL & " AND ([ControlPropName]='" & stControlPropName & "')"
    
    Set rs = db.OpenRecordset(stSQL)

    If rs.BOF And rs.EOF Then
        rs.AddNew
        rs("FormName") = stFormName
        rs("ControlName") = stControlName
        rs("ControlPropName") = stControlPropName
        If Not IsMissing(stControlPropValue1) Then
            rs("ControlPropValue1") = stControlPropValue1
        End If
        If Not IsMissing(stControlPropValue2) Then
            rs("ControlPropValue2") = stControlPropValue2
        End If
        rs("PoslednjaIzmena") = Now()
        rs.Update
        retVal = True
    Else
        rs.Edit
        If Not IsMissing(stControlPropValue1) Then
            rs("ControlPropValue1") = stControlPropValue1
        End If
        If Not IsMissing(stControlPropValue2) Then
            rs("ControlPropValue2") = stControlPropValue2
        End If
        rs("PoslednjaIzmena") = Now()
        rs.Update
        retVal = True
    End If
    
exit_err_Point:
On Error Resume Next
    rs.Close
    Set rs = Nothing
    Set db = Nothing
    SaveControlProp = retVal
Exit Function
Err_Point:
    retVal = False
    BBErrorMSG err, "SaveControlProp"
Resume exit_err_Point
End Function
Public Function SaveAllControls1Val(stFormName As String, stPropName As String, stPropValKljucnaRec As String) As Integer
On Error GoTo Err_Point
'***********************************************************************************************************************
'Dodaje u tabelu T_APL_FormeIKontrole sve kontrole koje zadovoljavaju kljucnu rec stPropValKljucnaRec
'Kreirano: 18-05-2020
'primer: SaveAllControls1Val("Ulazna faktura - Podforma", "ControlSource", "SUM(")
'***********************************************************************************************************************
Dim MyForm As Form
Dim MyControl As control
Dim brojKontrola As Integer
Dim retValOk As Boolean

brojKontrola = 0
retValOk = True
DoCmd.OpenForm stFormName, acDesign, , , , acIcon
Set MyForm = Application.Forms(stFormName)

'Debug.Print "Forma: " & stFormName
    
    For Each MyControl In MyForm.Controls
       If (MyControl.ControlType = acComboBox) Or _
         (MyControl.ControlType = acTextBox) Then
          If MyControl.Properties(stPropName).Value Like "*" & stPropValKljucnaRec & "*" Then
           'Debug.Print "     " & MyControl.Name, MyControl.Properties(stPropName).Name, MyControl.Properties(stPropName).Value
           retValOk = SaveControlProp(stFormName, MyControl.Name, MyControl.Properties(stPropName).Name, MyControl.Properties(stPropName).Value)
           brojKontrola = brojKontrola + 1
          End If
       End If
    Next
DoCmd.Close acForm, stFormName, acSavePrompt

Exit_Point:
On Error Resume Next

'If BrojKontrola > 0 Then
'    MsgBox "SaveAllControls za " & BrojKontrola & " kontrola.", vbInformation, "QMegaTeh"
'End If

SaveAllControls1Val = brojKontrola
Exit Function

Err_Point:

    MsgBox err.Description & vbCrLf & vbCrLf & "SaveAllControls"
    retValOk = False
    Resume Exit_Point

End Function

Public Function SetSumOnForm(MyForm As Form, SetSumYes As Boolean) As Integer
On Error GoTo Err_Point
'
'Kreirano: 18-05-2020
'Modifikovano: 19-05-2020
'
Const stPropValKljucnaRec = "SUM("
'Const stPropName = "ControlSource"

Dim MyControl As control
Dim brojKontrola As Integer
Dim pTestVal As String

brojKontrola = 0
    For Each MyControl In MyForm.Controls
       If (MyControl.ControlType = acComboBox) Or _
          (MyControl.ControlType = acTextBox) Then
          
          If SetSumYes Then
             pTestVal = Nz(MyControl.tag, "")
          Else
             pTestVal = Nz(MyControl.ControlSource, "")
          End If
          If pTestVal Like "*" & stPropValKljucnaRec & "*" Then
             If SetSumYes Then
                MyControl.ControlSource = MyControl.tag
             Else
                 MyControl.tag = MyControl.ControlSource
                 MyControl.ControlSource = ""
             End If
             brojKontrola = brojKontrola + 1
          End If
       End If
    Next

Exit_Point:
On Error Resume Next

SetSumOnForm = brojKontrola
Exit Function

Err_Point:
    BBErrorMSG err, "SetSumOnForm" & vbCrLf & "Kontrola: " & MyControl.Name
    'MsgBox err.Description & vbCrLf & vbCrLf & "SetNoSum"
    Resume Exit_Point

End Function
Public Function SetSumCtlFromTag(stFormName As String) As Boolean
'Kreirano: 19-05-2020
Dim MyForm As Form

DoCmd.OpenForm stFormName, acDesign
Set MyForm = Forms(stFormName)
SetSumOnForm MyForm, True
'DoCmd.Save acForm, stFormName
DoCmd.Close acForm, stFormName, acSavePrompt
End Function
