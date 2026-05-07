VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Pregled komitenata"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit

Private Sub Dugme_detaljno_komit_Click()
On Error GoTo Err_Dugme_Detaljno_komit_Click

    Dim DocName As String
    Dim LinkCriteria As String

    'If Me![Vrsta sifre] = "KUPDOB" Then
    '   DocName = "Unos komitenata"
    'Else
       'DocName = "Unos sifara"
       DocName = "Unos komitenata"
    'End If
    LinkCriteria = "[Sifra] = Forms![Pregled komitenata]![Sifra]"
    DoCmd.OpenForm DocName, , , LinkCriteria

Exit_Dugme_Detaljno_komit_Click:
    Exit Sub

Err_Dugme_Detaljno_komit_Click:
    MsgBox Error$
    Resume Exit_Dugme_Detaljno_komit_Click
    
End Sub

Private Sub Dugme_Novi_komitent_Click()
On Error GoTo Err_Dugme_novi_komitent_Click

    If F_PrebaciKomitenteIzEXTBaze() = False Then
        DoCmd.OpenForm "Unos komitenata", acNormal
        DoCmd.GoToRecord , , A_NEWREC
        DoCmd.GoToControl "Naziv"
    Else
        DugmePreuziKomitenteIzExtBaze
    End If
   

Exit_Dugme_novi_komitent_Click:
    Exit Sub

Err_Dugme_novi_komitent_Click:
    MsgBox Error$
    Resume Exit_Dugme_novi_komitent_Click
    
End Sub

Private Sub Dugme_print_Click()
On Error GoTo Err_Dugme_print_Click

    Dim DocName As String

    DocName = "Pregled komitenata"
    DoCmd.OpenReport DocName, A_PREVIEW

Exit_Dugme_print_Click:
    Exit Sub

Err_Dugme_print_Click:
    MsgBox Error$
    Resume Exit_Dugme_print_Click
    
End Sub

Private Sub Dugme_Stop_Click()
On Error GoTo Err_Dugme_stop_Click


    DoCmd.Close

Exit_Dugme_stop_Click:
    Exit Sub

Err_Dugme_stop_Click:
    MsgBox Error$
    Resume Exit_Dugme_stop_Click
    
End Sub

Private Sub DugmeRequery_Click()

End Sub



Private Sub Form_BeforeUpdate(Cancel As Integer)
    MsgBox " Ne mozete da menjate podatke komitenata u ovom programu!!!" & Chr(13) & " Za to koristite BigBit!!!"
    DoCmd.CancelEvent
    
End Sub

Private Sub Form_Open(Cancel As Integer)
 On Error Resume Next
    DoCmd.GoToControl "Sifra"
    DoCmd.GoToControl "ZaVrstuSifre"
    DoCmd.Maximize
End Sub



Private Sub PronadjiPoNazivu_AfterUpdate()
    DoCmd.GoToControl ("Sifra")
    DoCmd.FindRecord (Me![PronadjiPoNazivu])
    Me![PronadjiPoNazivu] = Null
    DoCmd.GoToControl ("PronadjiPoNazivu")
End Sub

Private Sub ZaMesto_AfterUpdate()
Me.Requery
End Sub

Private Sub ZaNaziv_AfterUpdate()
Me.Requery
End Sub

Private Sub ZaPDVStatus_AfterUpdate()
Me.Requery
End Sub

Private Sub ZaPIB_AfterUpdate()
    Me.Requery
End Sub

Private Sub ZaProdavca_AfterUpdate()
Me.Requery
End Sub

Private Sub ZaRabat_AfterUpdate()

    Me.Requery
     
End Sub

Private Sub ZaRegion_AfterUpdate()
    Me.Requery
End Sub

Private Sub ZaVrstuSifre_AfterUpdate()

    ' SendKeys "+{F9}"
     Me.Requery
     DoCmd.GoToControl ("ZaVrstuSifre")
End Sub
Private Sub DugmePreuziKomitenteIzExtBaze()
    On Error GoTo Err_Point
    Dim retValOk As Boolean
    
    retValOk = True
    
    retValOk = retValOk And UradiImportIzTabeleUTabelu("EXT_Vrste sifara", "Vrste sifara", stSQL_Append_VrsteKomitentaIzBigBita)
    
    If retValOk Then
        retValOk = retValOk And DodajNoveProdavceIzBigBita
    Else
        GoTo Exit_Point:
    End If
    If retValOk Then
        retValOk = retValOk And DodajNoveKomitenteIzBigBita
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
