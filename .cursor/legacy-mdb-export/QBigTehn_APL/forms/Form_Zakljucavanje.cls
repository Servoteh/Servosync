VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Zakljucavanje"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub DugmeZakljucajGK_Click()
On Error GoTo Err_DugmeZakljucajGK_Click

If UserUGrupi(CurrentUser(), "Zakljucavanje") Then
    If spZakOtk("T_nalozi", Me!IDFirma, Me!ZaGodinu, Me!OdLevel, Me!DoLevel, Me!OdDatumaGK, Me!DoDatumaGK, Null, True) Then
       MsgBox "Nalozi GK su zakljucani.", vbInformation, "QBigTeh"
    End If
Else
   MsgBox "Nemate prava da zakljucate naloge GK.", vbInformation, "QBigTeh"
End If

Exit_DugmeZakljucajGK_Click:
    Exit Sub

Err_DugmeZakljucajGK_Click:
    MsgBox err.Description
    Resume Exit_DugmeZakljucajGK_Click
    
End Sub
Private Sub DugmeOtkljucajGk_Click()
On Error GoTo Err_DugmeOtkljucajGk_Click

If UserUGrupi(CurrentUser(), "Otkljucavanje") Then
    If spZakOtk("T_nalozi", Me!IDFirma, Me!ZaGodinu, Me!OdLevel, Me!DoLevel, Me!OdDatumaGK, Me!DoDatumaGK, Null, False) Then
       MsgBox "Nalozi GK su otkljucani.", vbInformation, "QBigTeh"
    End If
Else
   MsgBox "Nemate prava da otkljucate naloge GK.", vbInformation, "QBigTeh"
End If


Exit_DugmeOtkljucajGk_Click:
    Exit Sub

Err_DugmeOtkljucajGk_Click:
    MsgBox err.Description
    Resume Exit_DugmeOtkljucajGk_Click
    
End Sub
Private Sub DugmeZakljucajRobu_Click()
On Error GoTo Err_DugmeZakljucajRobu_Click

If UserUGrupi(CurrentUser(), "Zakljucavanje") Then
    If spZakOtk("T_Robna dokumenta", Me!IDFirma, Me!ZaGodinu, Me!OdLevel, Me!DoLevel, Me!OdDatumaRoba, Me!DoDatumaRoba, Null, True) Then
       MsgBox "Robna dokumenta su zakljucana.", vbInformation, "QBigTeh"
    End If
Else
   MsgBox "Nemate prava da zakljucate robna dokumenta.", vbInformation, "QBigTeh"
End If

Exit_DugmeZakljucajRobu_Click:
    Exit Sub

Err_DugmeZakljucajRobu_Click:
    MsgBox err.Description
    Resume Exit_DugmeZakljucajRobu_Click
    
End Sub
Private Sub DugmeOtkljucajRobu_Click()
On Error GoTo Err_DugmeOtkljucajRobu_Click

If UserUGrupi(CurrentUser(), "Otkljucavanje") Then
    If spZakOtk("T_Robna dokumenta", Me!IDFirma, Me!ZaGodinu, Me!OdLevel, Me!DoLevel, Me!OdDatumaRoba, Me!DoDatumaRoba, Null, False) Then
       MsgBox "Robna dokumenta su otkljucana.", vbInformation, "QBigTeh"
    End If
Else
   MsgBox "Nemate prava da otkljucate robna dokumenta.", vbInformation, "QBigTeh"
End If
    
Exit_DugmeOtkljucajRobu_Click:
    Exit Sub

Err_DugmeOtkljucajRobu_Click:
    MsgBox err.Description
    Resume Exit_DugmeOtkljucajRobu_Click
    
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

Private Sub Form_Open(Cancel As Integer)
 On Error Resume Next
 
If F_NivoBaze() > 0 Then
        Me!LabelLevel.Visible = True
        Me!OdLevel.Visible = True
        Me!OdLevel.ValidationRule = "BETWEEN 0 AND " & F_NivoBaze()
        Me!OdLevel.ValidationText = "Dozvoljene vrednosti su od 0 do " & F_NivoBaze()
        Me!DoLevel.Visible = True
        Me!DoLevel.ValidationRule = "BETWEEN 0 AND " & F_NivoBaze()
        Me!DoLevel.ValidationText = "Dozvoljene vrednosti su od 0 do " & F_NivoBaze()
        
        Me!LabelLevel1.Visible = True
        Me!Level.Visible = True
    Else
        Me!LabelLevel.Visible = False
        Me!OdLevel.Visible = False
        Me!DoLevel.Visible = False
        
 End If
'Call BB_PravaPristupaPodesiFormu(Me)
 Me!ZaGodinu = F_Godina()

On Error Resume Next
    DoCmd.GoToControl "OdDatumaRoba"
End Sub
