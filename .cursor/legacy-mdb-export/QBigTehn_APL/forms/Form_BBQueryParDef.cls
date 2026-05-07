VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BBQueryParDef"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub ComboAccMapValue_AfterUpdate()
'Modifikovano: 27-08-2020
On Error GoTo Err_Point

Dim inVal
Dim tmpVal
Dim i As Integer

If Me!CheckAutoCorrect Then
    inVal = Me!ComboAccMapValue
    'tmpVal = DLookup("ImeKontrole", "tmp_T_KontroleNaFormi", "ImeKontrole= '" & inVal & "'")
     For i = 0 To Me!ComboAccMapValue.ListCount  'Me!ComboAccMapValue.ListRows
       If inVal = Me!ComboAccMapValue.ItemData(i) Then
          tmpVal = inVal
          Exit For
       End If
    Next i

    If Nz(tmpVal, "") = inVal Then
       Me!AccMapValue = "Forms![" & Me.Parent.Form!AccParFormName & "]![" & inVal & "]"
    End If
End If
Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "ComboAccMapValue_AfterUpdate"
 Resume Exit_Point

End Sub
Private Function KorigujParamtreZaSQLText()
On Error GoTo Err_Point

    Dim stOldVal As String
    Dim stNewVal As String
    Dim stSQLText As String
    
If Me!CheckAutoCorrect Then
    stOldVal = Nz(Me!Name.OldValue, "")
    stNewVal = Me!Name
    If (stOldVal <> stNewVal) And (stOldVal <> "") Then
        stSQLText = Nz(Me.Parent.Form!SQLText, "")
        If stSQLText <> "" Then
            stSQLText = Replace(stSQLText, stOldVal, stNewVal)
            'Ovaj ne radistSQLText = ReplaceSQLArgWithValue(stSQLText, stOldVal, stNewVal)
            Me.Parent.Form!SQLText = stSQLText
        End If
    End If
End If

On Error GoTo Err_Point

Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, ""
 Resume Exit_Point
End Function

Private Sub Form_AfterUpdate()
On Error Resume Next
    Me.Parent!PoslednjaIzmena = Now()
    Me.Parent.Form.SnimiSlog
End Sub

Private Sub Form_BeforeUpdate(Cancel As Integer)
On Error Resume Next
    Me!PoslednjaIzmena = Now()
    
End Sub

Private Sub Name_AfterUpdate()
    KorigujParamtreZaSQLText
End Sub

Private Sub Value_DblClick(Cancel As Integer)

   Me!Value = PassTroughParEval(Me!Type, Me!AccMapValue)
   
End Sub
