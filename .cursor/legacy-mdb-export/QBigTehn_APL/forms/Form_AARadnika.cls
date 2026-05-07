VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_AARadnika"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit

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
Private Function TrebaPrimenitiUslove(Optional lColor) As Boolean
   TrebaPrimenitiUslove = F_TrebaPrimenitiUslove(lColor, Me, Me!DugmePrimeniUslove)
End Function
Public Function PrimeniUslove()
    Me!Podforma.Form.PrimeniUslove
    TrebaPrimenitiUslove vbBlack
End Function

Private Sub TabIzbor_DblClick(Cancel As Integer)
    Me!FrameProdaja = 0
    Me!Podforma.SourceObject = "ReklamniPanel"
End Sub
Private Sub FrameIzvestaji_AfterUpdate()
On Error GoTo Err_Point
Dim retValOk As Boolean

    retValOk = True
    
    If Me!FrameIzvestaji = 1 Then
     Me!Podforma.SourceObject = "AA_PoSatu"
     Me!ZaTipUnosa.Enabled = True
    ElseIf Me!FrameIzvestaji = 2 Then
     'Me!Podforma.SourceObject = "AA_LosUnosKomadaNula"
     Me!Podforma.SourceObject = "ReklamniPanel"
     Me!ZaTipUnosa.Enabled = False
    ElseIf Me!FrameIzvestaji = 3 Then
     Me!Podforma.SourceObject = "ReklamniPanel"
    ElseIf Me!FrameIzvestaji = 4 Then
     Me!Podforma.SourceObject = "ReklamniPanel"
    ElseIf Me!FrameIzvestaji = 5 Then
     Me!Podforma.SourceObject = "ReklamniPanel"
    ElseIf Me!FrameIzvestaji = 6 Then
     Me!Podforma.SourceObject = "ReklamniPanel"
    Else
      Me!Podforma.SourceObject = "ReklamniPanel"
    End If

Exit_Point:
 On Error Resume Next
 If Not retValOk Then
    Me!Podforma.SourceObject = "ReklamniPanel"
 End If
Exit Sub

Err_Point:
 BBErrorMSG err, "FrameIzvestaji_AfterUpdate"
 retValOk = False
 Resume Exit_Point

End Sub
Private Sub TabIzbor_Change()
    
   If Me!TabIzbor = 0 Then
        Me!Tab_Uslovi.Visible = True
        FrameIzvestaji_AfterUpdate
    Else
        Me!Tab_Uslovi.Visible = True
    End If
End Sub
Private Sub Dugme_Stop_Click()
On Error GoTo Err_Dugme_stop_Click


    DoCmd.Close

Exit_Dugme_stop_Click:
    Exit Sub

Err_Dugme_stop_Click:
    MsgBox err.Description
    Resume Exit_Dugme_stop_Click
    
End Sub
Private Sub Form_Open(Cancel As Integer)

    Me!OdDatuma = Date
    Me!DoDatuma = Date
    Me!OdVremena = TimeSerial(7, 0, 0)
    Me!DoVremena = TimeSerial(23, 59, 59)
    Me!ZaIDVrsteRadnika = 2
  
End Sub


Private Sub DugmePrimeniUslove_Click()
On Error GoTo Err_DugmeRefresh_Click

    Me!Podforma.Form.PrimeniUslove
    
Exit_DugmeRefresh_Click:
    Exit Sub

Err_DugmeRefresh_Click:
    MsgBox err.Description
    Resume Exit_DugmeRefresh_Click
    
End Sub

Private Sub DugmeNaredniDan_Click()
    PodesiDatumeNaredniDan
End Sub

Private Sub DugmePrethodniDan_Click()
    PodesiDatumePrethodniDan
End Sub

Private Sub PodesiDatumePrethodniDan()
   
    If DatePart("h", ReadCFGParametar("VremePocetkaRadnogDana", TimeSerial(6, 0, 0))) = 0 Then
        If Not IsDate(Me![OdDatuma]) Then Me![OdDatuma] = Date
        If Not IsDate(Me![DoDatuma]) Then Me![DoDatuma] = Date
    Else
        If Not IsDate(Me![OdDatuma]) Then Me![OdDatuma] = DateAdd("d", -1, Date)
        If Not IsDate(Me![DoDatuma]) Then Me![DoDatuma] = Date
    End If

    Me![OdDatuma] = DateAdd("d", -1, Me![OdDatuma])
    Me![DoDatuma] = DateAdd("d", -1, Me![DoDatuma])
    
    
  Me![OdDatuma].Requery
  Me![DoDatuma].Requery
  
  PrimeniUslove
End Sub
Private Sub PodesiDatumeNaredniDan()

 ' Me!OdVremena = TimeSerial(6, 0, 0)
 ' Me!DoVremena = TimeSerial(5, 59, 59)
    
    If DatePart("h", ReadCFGParametar("VremePocetkaRadnogDana", TimeSerial(6, 0, 0))) = 0 Then
        If Not IsDate(Me![OdDatuma]) Then Me![OdDatuma] = Date
        If Not IsDate(Me![DoDatuma]) Then Me![DoDatuma] = Date
    Else
        If Not IsDate(Me![OdDatuma]) Then Me![OdDatuma] = DateAdd("d", -1, Date)
        If Not IsDate(Me![DoDatuma]) Then Me![DoDatuma] = Date
    End If
    Me![OdDatuma] = DateAdd("d", 1, Me![OdDatuma])
    Me![DoDatuma] = DateAdd("d", 1, Me![DoDatuma])
     
  Me![OdDatuma].Requery
  Me![DoDatuma].Requery
  
  PrimeniUslove
End Sub
Private Sub DugmeSTDJuce_Click()
On Error GoTo Err_DugmeSTD_Click

   PodesiDatumeSTDJuce
   
Exit_DugmeSTD_Click:
    Exit Sub

Err_DugmeSTD_Click:
    MsgBox err.Description
    Resume Exit_DugmeSTD_Click
    
End Sub
Private Sub DugmeSTDDanas_Click()
On Error GoTo Err_DugmeSTD_Click

   PodesiDatumeSTDDanas
   
Exit_DugmeSTD_Click:
    Exit Sub

Err_DugmeSTD_Click:
    MsgBox err.Description
    Resume Exit_DugmeSTD_Click
    
End Sub
Private Sub PodesiDatumeSTDDanas()

    Me![OdDatuma] = Date
    Me![DoDatuma] = Me![OdDatuma]
    
    
  Me![OdDatuma].Requery
  Me![DoDatuma].Requery
  
 PrimeniUslove
End Sub
Private Sub PodesiDatumeSTDJuce()
  'Me!OdVremena = TimeSerial(6, 0, 0)
  'Me!DoVremena = TimeSerial(5, 59, 59)
  
    Me![OdDatuma] = DateAdd("d", -1, Date)
    Me![DoDatuma] = Me![OdDatuma]
   
  
  Me![OdDatuma].Requery
  Me![DoDatuma].Requery
 
  PrimeniUslove
  
End Sub


