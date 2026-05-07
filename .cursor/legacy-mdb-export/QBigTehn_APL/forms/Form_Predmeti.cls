VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Predmeti"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub CmbPronadji_AfterUpdate()
On Error Resume Next
    DoCmd.GoToControl ("IDPredmet")
    DoCmd.FindRecord Me![CmbPronadji]
    DoCmd.GoToControl "CmbPronadji"
    Me![CmbPronadji] = Null
End Sub

Private Sub Command36_Click()
On Error GoTo Err_DugmeOtvoriPonudu_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "USLUGA Faktura"
    
    stLinkCriteria = "[IDDok]=" & Me![ComboIDDokUSL]
    DoCmd.OpenForm stDocName, , , stLinkCriteria
    Forms![Usluga faktura]![ComboPredmet] = Forms![Predmeti]![IDPredmet]
    
Exit_DugmeOtvoriPonudu_Click:
    Exit Sub

Err_DugmeOtvoriPonudu_Click:
    MsgBox err.Description
    Resume Exit_DugmeOtvoriPonudu_Click

End Sub
Private Sub DugmeNoviPredmet_Click()
On Error GoTo Err_DugmeNoviPredmet_Click


    If F_PrebaciPredmeteIzEXTBaze() = False Then
        DoCmd.GoToRecord , , acNewRec
        DoCmd.GoToControl "BrojPredmeta"
        On Error Resume Next
        Me!DatumOtvaranja = Date
        ' Me![BrojPredmeta] = NullToZero(DMax("[BrojPredmeta]", "Predmeti")) + 1
        On Error Resume Next
        Me![BrojPredmeta] = CStr(CLng(Nz(DMax("[NajveciBroj]", "NajveciBrojPredmeta"), 0)) + 1)
        On Error GoTo Err_DugmeNoviPredmet_Click
        If IsNull(Me![BrojPredmeta]) Then
            Me![BrojPredmeta] = Date & "/" & Me![IDPredmet]
        End If

    Else
        DugmePreuziPredmeteIzExtBaze
    End If
   


Exit_DugmeNoviPredmet_Click:
    Exit Sub

Err_DugmeNoviPredmet_Click:
    MsgBox err.Description
    Resume Exit_DugmeNoviPredmet_Click
    
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
Private Sub DugmeSacuvaj_Click()
On Error GoTo Err_DugmeSacuvaj_Click


    DoCmd.DoMenuItem acFormBar, acRecordsMenu, acSaveRecord, , acMenuVer70

Exit_DugmeSacuvaj_Click:
    Exit Sub

Err_DugmeSacuvaj_Click:
    MsgBox err.Description
    Resume Exit_DugmeSacuvaj_Click
    
End Sub



Private Sub Form_BeforeUpdate(Cancel As Integer)
    If Me!IDVrstaPosla = 0 Then
        MsgBox "Niste definisali vrstu posla!!!"
        DoCmd.CancelEvent
        DoCmd.GoToControl "IDVrstaPosla"
    End If
End Sub

Private Sub Form_Open(Cancel As Integer)
    DoCmd.GoToRecord , , acLast
End Sub

Private Sub IDKomitent_Enter()
If Not IsNull(Me!IDKomitent) Then
    Me!IDKomitent.Locked = True
Else
    Me!IDKomitent.Locked = False
End If

End Sub

Private Sub DugmeOtvoriPonudu_Click()
On Error GoTo Err_DugmeOtvoriPonudu_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "Profaktura"
    
    stLinkCriteria = "[IDDok]=" & Me![ComboIDDokIF]
    DoCmd.OpenForm stDocName, , , stLinkCriteria
    Forms![Profaktura]![ComboPredmet] = Forms![Predmeti]![IDPredmet]
    
Exit_DugmeOtvoriPonudu_Click:
    Exit Sub

Err_DugmeOtvoriPonudu_Click:
    MsgBox err.Description
    Resume Exit_DugmeOtvoriPonudu_Click
    
End Sub

Private Sub DugmePromeniKomitenta_Click()
On Error GoTo Err_DugmePromeniKomitenta_Click

    Dim stDocName As String
    Dim stLinkCriteria As String
    Dim answer As Variant
    
    answer = MsgBox("Ovde možete promeniti komitenta za prikazani predmet." & vbCrLf & "Da li nastavljate akciju?", vbYesNo + vbInformation + vbDefaultButton2)
    If answer = vbYes Then
        stDocName = "UnosPredmetaIspraviKomitenta"
        DoCmd.OpenForm stDocName, , , stLinkCriteria
    End If
Exit_DugmePromeniKomitenta_Click:
    Exit Sub

Err_DugmePromeniKomitenta_Click:
    MsgBox err.Description
    Resume Exit_DugmePromeniKomitenta_Click
    
End Sub
Private Sub DugmePreuziPredmeteIzExtBaze()
    On Error GoTo Err_Point
    Dim retValOk As Boolean
    
    retValOk = True
    
    If retValOk Then
        retValOk = retValOk And DodajNovePredmeteIzBigBita
    Else
        GoTo Exit_Point:
    End If
    
Exit_Point:
    If retValOk Then
        BBMsgBox_BigBit "Podaci su preuzeti", 1
    Else
        BBMsgBox_BigBit "Podaci NISU preuzeti", 1
    End If
    Exit Sub

Err_Point:
    MsgBox Error$
    retValOk = False
    Resume Exit_Point
End Sub

