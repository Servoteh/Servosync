VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PregledStavkiPrimopredajaRN"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit
Public Function PrimeniUslove()
    SetProperlyRecordSource BBCFG.CNNString, Me
End Function
Private Function xrSum(stFieldName As String) As Double
On Error GoTo Err_Point
Dim i As Long
Dim retVal As Variant

While Not Me.RecordsetClone.EOF
   retVal = retVal + Me.RecordsetClone(stFieldName).Value
Wend
Exit_Point:
On Error Resume Next
   xrSum = retVal
Exit Function
Err_Point:
 MsgBox err.Description
 err.Clear
 Resume Exit_Point
End Function


Private Function SumDAORstField(fldName As String, Optional rst As DAO.Recordset) As Variant
'**********************
'Kreirano:
'**********************
On Error GoTo Err_Point

  Dim sumVal As Double
  Dim retValErrNumber As Long
  
  retValErrNumber = 0
  sumVal = 0
    
  If rst Is Nothing Then
   If Screen.ActiveForm.RecordsetClone Is Nothing Then
    'err.Raise 123, "SumADORstField"
    err.Raise vbObjectError + 513, "SumADORstField", "ADODB.Recordset nije definisan "
    GoTo Exit_Point
   Else
    Set rst = Screen.ActiveForm.RecordsetClone
   End If
  End If
    
  rst.MoveFirst
  While Not rst.EOF
    sumVal = sumVal + rst(fldName).Value
    rst.MoveNext
  Wend
    
Exit_Point:
On Error Resume Next
  If retValErrNumber = 0 Then
    SumDAORstField = sumVal
  Else
    SumDAORstField = "#Error:" & retValErrNumber
  End If
Exit Function

Err_Point:
 retValErrNumber = err.Number
 Resume Exit_Point
End Function

Private Sub DugmeSum_Click()
    PrikaziTotale
End Sub

Private Sub Form_Current()
    ProveriZakljucavanje
End Sub

Private Sub ProveriZakljucavanje()
'Application.Echo False
    Dim userReadOnly As Boolean
    userReadOnly = IsReadOnlyUser()
    
    If Nz(Forms![Primopredaja].Zakljucano, False) = True Then

        Me.Detail0.BackColor = BBCFG.ColorLock
        Me.FormFooter2.BackColor = BBCFG.ColorLock
        
        Me.AllowEdits = False
        Me.AllowDeletions = False
        Me.AllowAdditions = False
        
    ElseIf userReadOnly Then
        Me.AllowEdits = False
        Me.AllowAdditions = False
        Me.AllowDeletions = False
    Else
        Me.Detail0.BackColor = BBCFG.ColorUnLock
        Me.FormFooter2.BackColor = BBCFG.ColorUnLock
        Me.AllowEdits = True
        Me.AllowDeletions = True
        Me.AllowAdditions = True
        
    End If
  'Application.Echo True
End Sub


Private Sub Form_Open(Cancel As Integer)
 
    BBTimerStart
    SetProperlyRecordSource BBCFG.CNNString, Me
    PrikaziTotale
    Me!LabelTrajanjeUpita.Caption = BBTimerTrajanjeSec("Query=")
 
End Sub

Private Sub Form_Unload(Cancel As Integer)
On Error GoTo Err_Point

If Me.Recordset Is Nothing Then
   Exit Sub
End If
 If TypeOf Me.Recordset Is ADODB.Recordset Then
   'Close the ADO connection we opened
   Dim cn As ADODB.Connection
   Set cn = Me.Recordset.ActiveConnection
   cn.Close
   Set cn = Nothing
 End If
 
Exit_Point:
On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, Me.Name & "::Form_Unload"
 Resume Exit_Point
End Sub
Private Function SumRST(stImeKolone As String) As Double
 Dim rs As Object
 Dim Total As Double

    Total = 0
    Set rs = Me.Recordset.Clone
 
 While Not rs.EOF
  Total = Total + Nz(rs(stImeKolone).Value, 0)
  rs.MoveNext
 Wend
 SumRST = Total
End Function
Private Function PrikaziTotale()
On Error GoTo Err_Point
  
  Me!ukUkupno = Round(SumRST("Ukupno"), 4)
  
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "PrikaziTotale"
 Resume Exit_Point
End Function
Private Sub DugmePrikaziSkicu_Click()
On Error GoTo Err_DugmePrikaziSkicu_Click

    Dim stDocName As String
    Dim stLinkCriteria As String
    
    'stDocName = "StavkeRNSlike"
    'DoCmd.OpenForm stDocName, , , stLinkCriteria
    If Nz(Me!IDStavkeRN, 0) <> 0 Then
        DefinisiPrikaziSkicu Me!IDRN, Me.Parent!IdentBroj, Me!Operacija
    Else
        MsgBox "Ne postoji definisana operacija za koju želite da definišete skicu!", vbInformation
    End If
    
Exit_DugmePrikaziSkicu_Click:
    Exit Sub

Err_DugmePrikaziSkicu_Click:
    MsgBox err.Description
    Resume Exit_DugmePrikaziSkicu_Click
    
End Sub

