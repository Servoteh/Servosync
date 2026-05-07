VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BarKod_Status"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Function PrimeniUslove()
  ' BBTimerStart
    SetProperlyRecordSource BBCFG.CNNString, Me
  ' Me!LabelTrajanjeUpita.Caption = BBTimerTrajanjeSec("Query=")
End Function

Private Sub Form_Close()
    If Not IsNull(Me!Napomena) Or Me!Napomena <> "" Then
        Call UpisiNapomenu(Me!IDPostupka, Me!Napomena)
    End If
End Sub

Private Sub Form_Load()
    PrimeniUslove
    'If Me!txtPotrebnoKomada > 999 Then
    '    Me!txtPotrebnoKomada.FontSize = 14
    'End If
End Sub

Private Sub Form_Open(Cancel As Integer)
'    DoCmd.MoveSize 10, 10

    
    'If Me.PotrebnoKomada > 999 Then Me!PotrebnoKomada.FontSize = 14
    PrikaziObjekteZaMene
End Sub
Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click


    DoCmd.Close

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
    
End Sub

Private Sub Form_Timer()
    Me!VremeTrajanja = Me!VremeTrajanja - 1
    Me!VremeTrajanja.Visible = True
    'Me!Vreme.Requery
    If Me!VremeTrajanja < 0 Then
        DoCmd.Close acForm, Me.Name
    Else
        Me.Repaint
    End If
End Sub
Private Sub DugmeTest_Click()
On Error GoTo Err_Command180_Click

    MsgBox "IDPostupka: " & Nz(Me!IDPostupka, "<NULL>") & " -" & BBTehn.IDPostupka & vbCrLf & "IDRadnika: " & Nz(Me!SifraRadnika, "<NULL>") & " -" & BBTehn.IDRadnik & vbCrLf & "IDPredmeta: " & Nz(Me!IDPredmet, "<NULL>") & " -" & BBTehn.IDPredmet

Exit_Command180_Click:
    Exit Sub

Err_Command180_Click:
    MsgBox err.Description
    Resume Exit_Command180_Click
End Sub
Public Sub PrikaziObjekteZaMene()
    If UserUGrupi(CurrentUser(), "Admins") Then
        Me!DugmeTest.Visible = True 'DugmePrebaciUClipboard
    Else
        Me!DugmeTest.Visible = False
    End If
End Sub
