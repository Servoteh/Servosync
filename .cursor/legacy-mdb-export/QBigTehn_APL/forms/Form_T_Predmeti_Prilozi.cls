VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_T_Predmeti_Prilozi"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Public Function PrimeniUslove()
    Me.Requery
End Function
Private Sub ProveriZakljucavanje()
On Error GoTo err_Sub


 Exit Sub
 
If Not BBCFG.SysProveraZakljucavanja Then
 Exit Sub
End If


BBCFG.SetAppEcho False, "Form_Current"
If Nz(Me!Zakljucano, False) Then
        Me.FormHeader.BackColor = BBCFG.ColorLock
        Me.Detail.BackColor = BBCFG.ColorLock
        Me.AllowEdits = False
        Me.AllowDeletions = False
        
        'Me!DugmeNapraviIzlazniDok.Enabled = False
        
  Else
        Me.FormHeader.BackColor = BBCFG.ColorUnLock
        Me.Detail.BackColor = BBCFG.ColorUnLock
        Me.AllowEdits = True
        Me.AllowDeletions = True
        
        'Me!DugmeNapraviIzlazniDok.Enabled = True
        
  End If
Exit_Sub:
 BBCFG.SetAppEcho True, "Form_Current"
Exit Sub
err_Sub:
 'BBErrorMSG Err, "Ulazna faktura/ProveriZakljucavanje"
 Resume Exit_Sub
End Sub
Private Function ComboRequery()

On Error GoTo Err_Point
Dim retValOk As Boolean
retValOk = True


Exit_Point:
 On Error Resume Next
       ComboRequery = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "ComboRequery"
 retValOk = False
 Resume Exit_Point

End Function
Private Function SledeciBrojPriloga() As String

On Error GoTo Err_Point
Dim retValOk As Boolean
Dim pIDPredmet As Long
Dim stRetVal As String
Dim intRetVal As Integer


retValOk = True
IDPredmet = Nz(Me.Parent!IDPredmet, -1)
If pIDPredmet = -1 Then
    intRetVal = 0
Else
    intRetVal = 1 + ADO_Lookup(CNN_CurrentDataBase, "CountOfPrilog", "SELECT COUNT(*) as CountOfPrilog FROM T_Predmeti_Prilozi WHERE IDPredmet=" & CStr(pIDPredmet))
End If

stRetVal = Format(intRetVal, "000")

Exit_Point:
 On Error Resume Next
       SledeciBrojPriloga = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "SledeciBrojPriloga"
 stRetVal = "000"
 retValOk = False
 Resume Exit_Point

End Function
Private Sub DugmeNoviSlog_Click()

On Error GoTo Err_Point
    
    DoCmd.GoToRecord , , acNewRec
    'DoCmd.GoToControl "Prilog_DatumPrijema"
    Me!Prilog_RB = SledeciBrojPriloga
    DoCmd.GoToControl "Prilog_RB"

Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "DugmeNoviSlog_Click"
 Resume Exit_Point

End Sub

Private Sub Form_Current()
    ProveriZakljucavanje
    ComboRequery
End Sub

Private Sub Zakljucano_AfterUpdate()
    ProveriZakljucavanje
End Sub
