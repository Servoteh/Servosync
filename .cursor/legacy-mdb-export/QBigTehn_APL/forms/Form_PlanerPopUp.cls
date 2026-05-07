VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PlanerPopUp"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Dim AktivanPlaner  As Boolean
Private Sub PodesiDatumeIVremeSTDDanas()
 
    Me![OdDatuma] = Date
    Me![DoDatuma] = Date ' DateAdd("d", 1, Date)
    
    PrimeniUslove
  
  Me![OdDatuma].Requery
  Me![DoDatuma].Requery
  
End Sub
Private Sub PodesiDatumeIVremeSTDJuce()
    Me![OdDatuma] = DateAdd("d", -1, Date)
    Me![DoDatuma] = DateAdd("d", -1, Date) 'Date
  
   PrimeniUslove

  Me![OdDatuma].Requery
  Me![DoDatuma].Requery

End Sub
Private Sub DugmeSTDJuce_Click()
On Error GoTo Err_DugmeSTD_Click

   PodesiDatumeIVremeSTDJuce
   
Exit_DugmeSTD_Click:
    Exit Sub

Err_DugmeSTD_Click:
    MsgBox err.Description
    Resume Exit_DugmeSTD_Click
    
End Sub

Private Sub DoDatuma_DblClick(Cancel As Integer)
    Me!DoDatuma = Date
    PrimeniUslove
End Sub

Private Sub DugmeSTDDanas_Click()
On Error GoTo Err_DugmeSTD_Click

   PodesiDatumeIVremeSTDDanas
   
Exit_DugmeSTD_Click:
    Exit Sub

Err_DugmeSTD_Click:
    MsgBox err.Description
    Resume Exit_DugmeSTD_Click
    
End Sub
Private Sub PodesiDatumePrethodniDan()

    If Not IsDate(Me![OdDatuma]) Then Me![OdDatuma] = Date
    If Not IsDate(Me![DoDatuma]) Then Me![DoDatuma] = Date
    
    Me![OdDatuma] = DateAdd("d", -1, Me![OdDatuma])
    Me![DoDatuma] = DateAdd("d", -1, Me![DoDatuma])
    
   PrimeniUslove

  Me![OdDatuma].Requery
  Me![DoDatuma].Requery

End Sub
Private Sub PodesiDatumeNaredniDan()
    
    If Not IsDate(Me![OdDatuma]) Then Me![OdDatuma] = Date
    If Not IsDate(Me![DoDatuma]) Then Me![DoDatuma] = Date
    
    Me![OdDatuma] = DateAdd("d", 1, Me![OdDatuma])
    Me![DoDatuma] = DateAdd("d", 1, Me![DoDatuma])
    
    PrimeniUslove
  Me![OdDatuma].Requery
  Me![DoDatuma].Requery
End Sub
Private Sub DugmeNaredniDan_Click()
    PodesiDatumeNaredniDan
End Sub

Private Sub DugmePrethodniDan_Click()
  PodesiDatumePrethodniDan
End Sub
Private Sub DoDatuma_AfterUpdate()
    PrimeniUslove
End Sub

Private Sub DoVremena_AfterUpdate()
    PrimeniUslove
End Sub

Private Sub Form_Close()
    AktivanPlaner = False
End Sub

Private Sub Form_Open(Cancel As Integer)
    AktivanPlaner = True
    'Me!ZaCheckUradjeno = Null
    'Me!ZaCheckUradjeno = CBool(ReadParametar("CFG_Global", "Planer_Uradjeno"))
    Me!ZaCheckUradjeno = Eval(ReadParametar("CFG_Global", "Planer_Uradjeno"))
    'Me!ZaCheckUradjeno = Null
    PrimeniUslove
    DoCmd.GoToControl "OdDatuma"
End Sub
Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click

If Me.TimerInterval = 0 Then
   DoCmd.Close acForm, "PlanerPopUp", acSavePrompt
Else
    DoCmd.Minimize
End If

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
    
End Sub

Private Sub Form_Timer()
    If DCount("*", "PlanerProvera") > 0 Then
     DoCmd.Restore
     AktivanPlaner = True
     PrimeniUslove
    Else
        BBMsgBox_BigBit "Nemate poruka", 3
    End If
End Sub

Private Sub IDPlaner_Change()
    MsgBox "IDPlaner_Change"
End Sub

Private Sub OdDatuma_AfterUpdate()
    PrimeniUslove
End Sub

Private Sub OdDatuma_DblClick(Cancel As Integer)
    Me!OdDatuma = Date
    PrimeniUslove
End Sub

Private Sub OdVremena_AfterUpdate()
    PrimeniUslove
End Sub
Function PrikaziIzabraniPlaner()
   Me!PlanerSingleSubForm.Requery
   DoCmd.GoToControl "PlanerSingleSubForm"
   DoCmd.GoToRecord , , acFirst
   On Error Resume Next
   DoCmd.GoToControl "KadaDatum"
End Function

Public Function PrimeniUslove()
    
    Me!ZaIDPlaner = Null
    
    Me!PlanerSingleSubForm.Requery
    Me!PlanerTabSubForm.Requery
    'DoCmd.GoToControl "PlanerSingleSubForm"
    'DoCmd.GoToRecord , , acFirst
End Function

Private Sub DugmePrimeniUslove_Click()
On Error GoTo Err_DugmePrimeniUslove_Click

   PrimeniUslove

Exit_DugmePrimeniUslove_Click:
    Exit Sub

Err_DugmePrimeniUslove_Click:
    MsgBox err.Description
    Resume Exit_DugmePrimeniUslove_Click
    
End Sub

Private Sub ZaDatum_AfterUpdate()
    Me!OdDatuma = Me!ZaDatum
    Me!DoDatuma = Me!ZaDatum
    PrimeniUslove
End Sub
Private Sub DugmeDefault_Click()
On Error GoTo Err_DugmeDefault_Click

    Me!OdDatuma = CVDate(DateAdd("d", -ReadParametar("CFG_Global", "Planer_BrojDanaUnazad"), Date))
    Me!DoDatuma = CVDate(DateAdd("d", ReadParametar("CFG_Global", "Planer_BrojDanaUnapred"), Date))
    Me!OdVremena = CStr(TimeSerial(0, 0, 0))
    Me!DoVremena = CStr(TimeSerial(23, 59, 59))
    Me!ZaSubjekt = Null
    Me!ZaOdKoga = Null
    Me!ZaZaKoga = Null
    Me!ZaCheckUradjeno = False
    Me!ZaKoJeUradio = Null
    
    PrimeniUslove
Exit_DugmeDefault_Click:
    Exit Sub

Err_DugmeDefault_Click:
    MsgBox err.Description
    Resume Exit_DugmeDefault_Click
    
End Sub
