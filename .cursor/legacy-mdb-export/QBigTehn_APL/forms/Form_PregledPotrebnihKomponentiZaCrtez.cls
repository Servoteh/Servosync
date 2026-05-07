VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PregledPotrebnihKomponentiZaCrtez"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Public Function PrimeniUslove()
   BBTimerStart
    SetProperlyRecordSource BBCFG.CNNString, Me
   Me!LabelTrajanjeUpita.Caption = BBTimerTrajanjeSec("Query=")
End Function

Private Sub Form_Click()
    DugmeTree
End Sub

Private Sub Form_Load()
    PrimeniUslove
End Sub

Private Sub DugmeTree()
On Error GoTo Err_Handler

    'DoCmd.MoveSize , , Me.Width + 200

    Dim ID As Long
    ID = Nz(Me!IDCrtez, 0)
    
    If ID = 0 Then
        MsgBox "Nije zadat ID crteža (ZaIDCrtez je 0 ili Null).", vbInformation, "TreeView"
        Exit Sub
    End If
    
    ' 1) Postavi SourceObject subforme (ako veæ nije)
    If Forms!PotrebneKomponenteZaCrtez!Podforma1.SourceObject <> "Form.frmPDMTreeView_Sub" Then
        Forms!PotrebneKomponenteZaCrtez!Podforma1.SourceObject = "Form.frmPDMTreeView_Sub"
        DoEvents            ' da Access stigne da uèita formu u subformu
    End If

    ' 2) Prosledi ID subformi
    Forms!PotrebneKomponenteZaCrtez!Podforma1.Form.SetIDCrtez ID
    Me.Parent.ProsiriFormu

Exit_Handler:
    Exit Sub

Err_Handler:
    MsgBox "Greška: " & err.Number & " - " & err.Description, vbExclamation, "DugmeTree_Click"
    Resume Exit_Handler
End Sub


