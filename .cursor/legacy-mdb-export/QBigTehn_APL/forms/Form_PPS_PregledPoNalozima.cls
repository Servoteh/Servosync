VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PPS_PregledPoNalozima"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Public Function PrimeniUslove()
   BBTimerStart
    SetProperlyRecordSource BBCFG.CNNString, Me
    'PrikaziTotale
   Me!LabelTrajanjeUpita.Caption = BBTimerTrajanjeSec("Query=")
End Function
Private Function F_PonistiIPrimeni() As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean

    retValOk = True
    Screen.ActiveControl.Value = Null
    PrimeniUslove

Exit_Point:
 On Error Resume Next
    F_PonistiIPrimeni = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "F_PonistiIPrimeni"
 retValOk = False
 Resume Exit_Point
End Function

Private Sub Form_Current()
    If Not Me.Recordset.EOF Then

    Dim Total As Long
    Total = Nz(Me.Recordset.Fields("TotalRows").Value, 0)

    Me.Parent.lblPage.Caption = _
        "Prikaz: " & _
        Me.Parent.ZaOffset + 1 & _
        " - " & _
        Me.Parent.ZaOffset + Me.Parent.ZaPageSize & _
        " od " & Total

End If

End Sub

Private Sub Form_Open(Cancel As Integer)
'Dim i As Integer

 '   Me!UkProcIizvrsenja.FormatConditions.Delete
 '   For i = 0 To Me!ProcIizvrsenja.FormatConditions.Count - 1
 '       Me!UkProcIizvrsenja.FormatConditions.Add acExpression, , "[Email] Like '*' & [domain] & '*'"
 '       Me!UkProcIizvrsenja.FormatConditions(i).ForeColor = Me!ProcIizvrsenja.FormatConditions(i).ForeColor 'RGB(0, 255, 0) ' Zelena boja
 '       Me!UkProcIizvrsenja.FormatConditions(i).ForeColor = Me!ProcIizvrsenja.FormatConditions(i).BackColor
 '   Next i
   PrimeniUslove
End Sub

Private Sub Form_Unload(Cancel As Integer)
    CloseConnectionOnCurrentForm Me
End Sub

