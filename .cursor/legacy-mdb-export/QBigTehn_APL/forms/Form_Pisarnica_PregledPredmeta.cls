VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Pisarnica_PregledPredmeta"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Public Function PrimeniUslove() As Boolean
On Error GoTo Err_Point

Dim retValOk As Boolean
Dim aktivnaKontrola

   retValOk = True
   On Error Resume Next
    Set aktivnaKontrola = Screen.ActiveControl
   On Error GoTo Err_Point
   
    SetProperlyRecordSource CNN_CurrentDataBase, Me
    
    On Error Resume Next
    aktivnaKontrola.SetFocus
    
Exit_Point:
 On Error Resume Next
       PrimeniUslove = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "PrimeniUslove"
 retValOk = False
 Resume Exit_Point

End Function
Private Function ClearCurrentVal()

   Screen.ActiveControl.Value = Null
   PrimeniUslove
   
End Function

Private Sub DATUMP_DblClick(Cancel As Integer)
    Me!OdDATUMP = Me!DATUMP
    Me!DoDATUMP = Me!DATUMP
    PrimeniUslove
End Sub

Private Sub DoDATUMP_DblClick(Cancel As Integer)
    If IsNull(Me!DoDATUMP) Then
       Me!DoDATUMP = Date
       PrimeniUslove
    Else
        Call ClearCurrentVal
        PrimeniUslove
    End If
End Sub



Private Sub DugmePrintDnevnaKnjiga_Click()
    
    If IsNull(Me!OdDATUMP) Then
       MsgBox "Morate izabrati datum od kojeg želite štampu.", vbExclamation, "BBPisarnica"
       Exit Sub
    End If
    If IsNull(Me!DoDATUMP) Then
       MsgBox "Morate izabrati datum do kojeg želite štampu.", vbExclamation, "BBPisarnica"
       Exit Sub
    End If
    If Me!OdDATUMP <> Me!DoDATUMP Then
        MsgBox "Možete izabrati samo jedan dan za štampu.", vbExclamation, "BBPisarnica"
       Exit Sub
       'If Not BBPitanje("Da li zaista želite štampu za zadati period?", vbDefaultButton2) Then
       ' Exit Sub
       'End If
    End If
    DoCmd.OpenReport "DnevnaKnjiga", acViewPreview
End Sub

Private Sub DugmePrintDostavnaKnjiga_Click()
    DoCmd.OpenReport "DostavnaKnjiga", acViewPreview
End Sub

Private Sub DugmeStop_Click()
    On Error GoTo Err_DugmeStop_Click


    If Me.Dirty Then Me.Dirty = False
    DoCmd.Close

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
End Sub

Private Sub Form_Open(Cancel As Integer)
    DoCmd.GoToControl "ZaGodina"
    Me!ZaGodina = Year(Date)
        PrimeniUslove
    DoCmd.GoToControl "ZaGodina"
End Sub

Private Sub OdDATUMP_DblClick(Cancel As Integer)
    If IsNull(Me!OdDATUMP) Then
       Me!OdDATUMP = Date
       PrimeniUslove
    Else
        Call ClearCurrentVal
        PrimeniUslove
    End If
End Sub

Private Sub ZaGodina_DblClick(Cancel As Integer)
    If IsNull(Me!ZaGodina) Then
       Me!ZaGodina = Year(Date)
       PrimeniUslove
    Else
        Call ClearCurrentVal
        PrimeniUslove
    End If
End Sub

Private Sub ZaSTRANKA_AfterUpdate()
    
    'NE MOŽE OVAKO!
    'If Not IsNull(Me!ZaSTRANKA) Then
    '    Me!ZaSTRANKA = Lat2Cyr(Me!ZaSTRANKA)
    'End If
    
    Call PrimeniUslove
End Sub
