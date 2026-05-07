VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PPS_PregledPoOperacijama"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Sub Form_Load()
On Error GoTo Err_Point

    ' Postavi RecordSource na lokalnu tabelu
    Me.RecordSource = "tStrukturaProizvodaTMP"
    Call PostaviConditionalFormat(Me)
    ' Podesi kolone u zavisnosti od podataka
    Call PrikaziOpKolone(Me)

Exit_Point:
    Exit Sub
Err_Point:
    MsgBox "Greška u Form_Load (desna podforma): " & err.Description, vbExclamation
    Resume Exit_Point
End Sub
Public Sub PrikaziOpKolone(frm As Form)
On Error GoTo Err_Point

    Dim db As DAO.Database
    Dim rs As DAO.Recordset
    Dim fldName As String
    Dim lblName As String
    Dim fldStatus As String
    Dim i As Integer
    Dim visibleCount As Integer
    Dim ctrlLeft As Single
    Dim ctrlWidth As Single
    Dim maxCols As Integer
    Dim statusValue As Variant
    
    maxCols = 30
    Set db = CurrentDb
    Set rs = db.OpenRecordset(frm.RecordSource, dbOpenSnapshot)

    ' 1?? Broj vidljivih kolona
    visibleCount = 0
    For i = 1 To maxCols
        fldName = "Op" & i
        If PoljeImaVrednosti(rs, fldName) Then visibleCount = visibleCount + 1
    Next i

    ' 2?? Raspodeli širinu kolona
    If visibleCount > 0 Then
        ctrlWidth = (frm.InsideWidth - 200) / visibleCount
    Else
        ctrlWidth = 1000
    End If
    
    ctrlLeft = 100 ' poèetna pozicija levo

    ' 3?? Prikaz i bojenje kolona
    For i = 1 To visibleCount
        fldName = "Op" & i
        lblName = "Op" & i & "_Label"
        fldStatus = fldName & "_Status"
        
        Dim hasData As Boolean
        hasData = PoljeImaVrednosti(rs, fldName)
        
        On Error Resume Next
        With frm.Controls(fldName)
            .Visible = hasData
            If hasData Then
                .Left = ctrlLeft
                .Width = ctrlWidth
                'ctrlLeft = ctrlLeft + ctrlWidth + 40
            End If
        End With
        On Error GoTo 0
        
        With frm.Controls(lblName)
            .Visible = hasData
            If hasData Then
                .Left = ctrlLeft
                .Width = ctrlWidth
                ctrlLeft = ctrlLeft + ctrlWidth + 40
            End If
        End With
        On Error GoTo 0
        
        ' Ako postoji status kolona, oboji je po vrednosti
        'If hasData Then
        '    On Error Resume Next
        '    statusValue = DLookup(fldStatus, frm.RecordSource)
        '    Select Case statusValue
        '        Case 0
        '            frm.Controls(fldName).BackColor = RGB(235, 240, 245)   ' èeka / nije uraðeno
        '        Case 1
        '            frm.Controls(fldName).BackColor = RGB(255, 220, 140)   ' u toku
        '        Case 2
        '            frm.Controls(fldName).BackColor = RGB(190, 230, 190)   ' završeno
        '        Case Else
        '            frm.Controls(fldName).BackColor = vbWhite
        '    End Select

        '    On Error GoTo 0
        'End If
    Next i
    
    ' 4?? Na kraju: prilagodi velièinu prozora forme
    Dim NovaSirina As Single
    Const Margina As Single = 300 ' prostor za skrolbar i ivice

    If visibleCount > 0 Then
        NovaSirina = (visibleCount * ctrlWidth) + Margina
        frm.Width = NovaSirina
    End If
    
Exit_Point:
    On Error Resume Next
    rs.Close
    Set rs = Nothing
    Set db = Nothing
    Exit Sub

Err_Point:
    MsgBox "Greška u PrikaziOpKolone: " & err.Description, vbExclamation
    Resume Exit_Point
End Sub
Private Function PoljeImaVrednosti(rs As DAO.Recordset, fldName As String) As Boolean
On Error GoTo Err_Point
    Dim ret As Boolean
    ret = False
    
    If rs.Fields.Count = 0 Then GoTo Exit_Point
    If Not PoljePostoji(rs, fldName) Then GoTo Exit_Point
    
    rs.MoveFirst
    Do While Not rs.EOF
        If Not IsNull(rs.Fields(fldName).Value) Then
            ret = True
            Exit Do
        End If
        rs.MoveNext
    Loop

Exit_Point:
    PoljeImaVrednosti = ret
    Exit Function

Err_Point:
    ret = False
    Resume Exit_Point
End Function

Private Function PoljePostoji(rs As DAO.Recordset, fldName As String) As Boolean
    Dim f As DAO.Field
    On Error Resume Next
    Set f = rs.Fields(fldName)
    PoljePostoji = (err.Number = 0)
    err.Clear
End Function

Public Sub PostaviConditionalFormat(frm As Form)
    Dim i As Integer
    Dim ctl As control
    Dim fc0 As FormatCondition
    Dim fc1 As FormatCondition
    Dim fc2 As FormatCondition
    Dim fld As String

    For i = 1 To 30
        fld = "Op" & i
        Set ctl = Nothing
        On Error Resume Next
        Set ctl = frm.Controls(fld)
        On Error GoTo 0
        If Not ctl Is Nothing Then
            ' Oèisti postojeæa pravila
            ctl.FormatConditions.Delete

            ' 0 = nije uraðeno (sivo)
            Set fc0 = ctl.FormatConditions.Add(acExpression, , "[" & fld & "_Status]=0")
            fc0.BackColor = RGB(230, 230, 230)

            ' 1 = u toku (žuto)
            Set fc1 = ctl.FormatConditions.Add(acExpression, , "[" & fld & "_Status]=1")
            fc1.BackColor = RGB(255, 235, 156)

            ' 2 = završeno (zeleno)
            Set fc2 = ctl.FormatConditions.Add(acExpression, , "[" & fld & "_Status]=2")
            fc2.BackColor = RGB(198, 239, 206)
        End If
    Next i
End Sub

