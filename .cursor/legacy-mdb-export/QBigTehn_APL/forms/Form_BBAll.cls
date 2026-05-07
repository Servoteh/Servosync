VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BBAll"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub BigBit_Click()
On Error GoTo Err_BigBit_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    'StartBigBit
    stDocName = "Prva maska"
    
    BBOpenForm stDocName, , , stLinkCriteria
    'DoCmd.Close acForm, "BBAll"

Exit_BigBit_Click:
    Exit Sub

Err_BigBit_Click:
    MsgBox err.Description
    Resume Exit_BigBit_Click
    
End Sub




Private Sub DugmefrmRibbonOnForm_Click()
On Error GoTo Err_DugmeBBInfo_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = DugmefrmRibbonOnForm.Caption
    BBOpenForm stDocName, , , stLinkCriteria
    

Exit_DugmeBBInfo_Click:
    Exit Sub

Err_DugmeBBInfo_Click:
    MsgBox err.Description
    Resume Exit_DugmeBBInfo_Click

End Sub

Private Sub DugmefrmUSysRibbon_Click()
On Error GoTo Err_DugmeBBInfo_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = DugmefrmUSysRibbon.Caption
    BBOpenForm stDocName, , , stLinkCriteria
    

Exit_DugmeBBInfo_Click:
    Exit Sub

Err_DugmeBBInfo_Click:
    MsgBox err.Description
    Resume Exit_DugmeBBInfo_Click

End Sub

Private Sub DugmeIzborRadnogFajla_Click()
On Error GoTo Err_DugmeIzborRadnogFajla_Click

    Dim DocName As String
    Dim LinkCriteria As String
    
        DocName = "Izbor radnog fajla"
        BBOpenForm DocName, , , LinkCriteria
        
    
Exit_DugmeIzborRadnogFajla_Click:
    Exit Sub

Err_DugmeIzborRadnogFajla_Click:
    MsgBox Error$
    Resume Exit_DugmeIzborRadnogFajla_Click
    
End Sub

Private Sub DugmeOtvoriRibbonOnForm_Click()
On Error GoTo Err_DugmeBBInfo_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = DugmeOtvoriRibbonOnForm.Caption
    BBOpenForm stDocName, , , stLinkCriteria
    

Exit_DugmeBBInfo_Click:
    Exit Sub

Err_DugmeBBInfo_Click:
    MsgBox err.Description
    Resume Exit_DugmeBBInfo_Click

End Sub

Private Sub DugmeOtvoriUDesignu_Click()
 If Not IsNull(Me!MyFormName) Then
    OpenDisignMyForm Me!MyFormName
 End If

End Sub

Private Sub DugmePDMSklopConnector_Click()
On Error GoTo Err_DugmeBBInfo_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = Me!DugmePDMSklopConnector.Caption
    BBOpenForm stDocName, , , stLinkCriteria

Exit_DugmeBBInfo_Click:
    Exit Sub

Err_DugmeBBInfo_Click:
    MsgBox err.Description
    Resume Exit_DugmeBBInfo_Click

End Sub

Private Sub DugmePopuniForme_Click()
    Me!MyFormName.RowSource = BBSys.ListaSvihFormi
End Sub
Private Sub DugmePopuniTabele_Click()
    Me!MyTableName.RowSource = BBSys.ListaSvihTabela
End Sub

Private Sub DugmePopuniUpite_Click()
    Me!MyQueryName.RowSource = BBSys.ListaSvihUpitaCijiNazivSadrziRec(Nz(Me!MyQueryName, ""))
End Sub

Private Sub DugmePrepisiIzCFGRadniFajlovi_Click()
On Error GoTo Err_DugmePrepisiIzCFGRadniFajlovi_Click

    Dim stDocName As String

    stDocName = "RadniFajlovi_PrepisiIzCFG"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    Me.Requery

Exit_DugmePrepisiIzCFGRadniFajlovi_Click:
    Exit Sub

Err_DugmePrepisiIzCFGRadniFajlovi_Click:
    MsgBox err.Description
    Resume Exit_DugmePrepisiIzCFGRadniFajlovi_Click
    
End Sub



Private Sub DugmePrimopredaja_Click()
On Error GoTo Err_DugmeBBInfo_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = Me!DugmePrimopredaja.Caption
    BBOpenForm stDocName, , , stLinkCriteria

Exit_DugmeBBInfo_Click:
    Exit Sub

Err_DugmeBBInfo_Click:
    MsgBox err.Description
    Resume Exit_DugmeBBInfo_Click
End Sub

Private Sub DugmePrvaMaskaMagacin_Click()
On Error GoTo Err_BigBit_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    'StartBigBit
    stDocName = "Prva maskaMagacin"
    
    BBOpenForm stDocName, , , stLinkCriteria
    'DoCmd.Close acForm, "BBAll"

Exit_BigBit_Click:
    Exit Sub

Err_BigBit_Click:
    MsgBox err.Description
    Resume Exit_BigBit_Click

End Sub

Private Sub DugmePrvaMaskaProjektanti_Click()
On Error GoTo Err_BigBit_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    'StartBigBit
    stDocName = "Prva maskaPregledi"
    
    BBOpenForm stDocName, , , stLinkCriteria
    'DoCmd.Close acForm, "BBAll"

Exit_BigBit_Click:
    Exit Sub

Err_BigBit_Click:
    MsgBox err.Description
    Resume Exit_BigBit_Click

End Sub

Private Sub DugmeQPrvaMaska_Click()
On Error GoTo Err_BigBit_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "QPrvaMaska"
    BBOpenForm stDocName, , , stLinkCriteria

Exit_BigBit_Click:
    Exit Sub

Err_BigBit_Click:
    MsgBox err.Description
    Resume Exit_BigBit_Click

End Sub

Private Sub DugmeRadniciPoMasinama_Click()
On Error GoTo Err_DugmeBBInfo_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = Me!DugmeRadniciPoMasinama.Caption
    BBOpenForm stDocName, , , stLinkCriteria

Exit_DugmeBBInfo_Click:
    Exit Sub

Err_DugmeBBInfo_Click:
    MsgBox err.Description
    Resume Exit_DugmeBBInfo_Click

End Sub

Private Sub DugmeUnosRadnika_Click()
On Error GoTo Err_DugmeBBInfo_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = Me!DugmeUnosRadnika.Caption
    BBOpenForm stDocName, , , stLinkCriteria

Exit_DugmeBBInfo_Click:
    Exit Sub

Err_DugmeBBInfo_Click:
    MsgBox err.Description
    Resume Exit_DugmeBBInfo_Click

End Sub

Private Sub MyFormName_AfterUpdate()
 If Not IsNull(Me!MyFormName) Then
    'OpenMyForm Me!MyFormName
 End If
End Sub

Private Sub MyFormName_DblClick(Cancel As Integer)
 If Not IsNull(Me!MyFormName) Then
    OpenMyForm Me!MyFormName
 End If
End Sub

Private Sub MyQueryName_AfterUpdate()
 Dim stDocName As String
    stDocName = "BBT_BrojDokumenataPoGodinama"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
End Sub

Private Sub MyTableName_AfterUpdate()
 If Not IsNull(Me!MyTableName) Then
  If CurrentUser <> "Negovan" Then
    DoCmd.OpenTable Me!MyTableName, acViewNormal, acReadOnly
  Else
   DoCmd.OpenTable Me!MyTableName
  End If
 End If
End Sub


Private Sub CFG_Click()
On Error GoTo Err_CFG_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    'stDocName = "CFGReadWrite"
    'BBOpenForm stDocName, , , stLinkCriteria
    
    OtvoriFormuCFGReadWrite
    
Exit_CFG_Click:
    Exit Sub

Err_CFG_Click:
    MsgBox err.Description
    Resume Exit_CFG_Click
    
End Sub
Private Sub Dnevnik_Click()
On Error GoTo Err_Dnevnik_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "ReklamniPanel_LogIn"
    BBOpenForm stDocName, , , stLinkCriteria

Exit_Dnevnik_Click:
    Exit Sub

Err_Dnevnik_Click:
    MsgBox err.Description
    Resume Exit_Dnevnik_Click
    
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


Private Sub DugmePSStart_Click()
On Error GoTo Err_DugmePSStart_Click

    Dim stDocName As String
    Dim stLinkCriteria As String
    Dim odgovor
    
    odgovor = MsgBox("OVU OPCIJU KORISTITE NA SOPSTVENU ODGOVORNOST. DA NASTAVIM?", vbCritical + vbYesNo, "QMegaTeh")
    If odgovor = vbYes Then
        stDocName = "PS_START"
        'BBOpenForm stDocName, , , stLinkCriteria
        DoCmd.OpenForm stDocName, , , stLinkCriteria
    End If

Exit_DugmePSStart_Click:
    Exit Sub

Err_DugmePSStart_Click:
    MsgBox err.Description
    Resume Exit_DugmePSStart_Click
    
End Sub
Private Sub OpenMyForm(stDocName As String, Optional stLinkCriteria As String = "")
On Error GoTo Err_OpenMyForm

    BBOpenForm stDocName, , , stLinkCriteria

Exit_OpenMyForm:
    Exit Sub

Err_OpenMyForm:
    MsgBox err.Description
    Resume Exit_OpenMyForm
    
End Sub
Private Sub DugmeBBExtra_Click()
On Error GoTo Err_DugmeBBExtra_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "ReklamniPanel_LogIn"
    'BBOpenForm stDocName, , , stLinkCriteria
    DoCmd.OpenForm stDocName, acDesign, , stLinkCriteria
    
Exit_DugmeBBExtra_Click:
    Exit Sub

Err_DugmeBBExtra_Click:
    MsgBox err.Description
    Resume Exit_DugmeBBExtra_Click
    
End Sub
Private Sub DugmeBBInfo_Click()
On Error GoTo Err_DugmeBBInfo_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "ReklamniPanel_LogIn"
    BBOpenForm stDocName, , , stLinkCriteria

Exit_DugmeBBInfo_Click:
    Exit Sub

Err_DugmeBBInfo_Click:
    MsgBox err.Description
    Resume Exit_DugmeBBInfo_Click
    
End Sub
Private Sub DugmeUsersPerm_Click()
On Error GoTo Err_DugmeUsersPerm_Click

    'DoCmd.RunCommand acCmdUserAndGroupPermissions
    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "BarKod_Unos"
    'BBOpenForm stDocName, , , stLinkCriteria
    DoCmd.OpenForm stDocName, acDesign, , stLinkCriteria
    
Exit_DugmeUsersPerm_Click:
    Exit Sub

Err_DugmeUsersPerm_Click:
    MsgBox err.Description
    Resume Exit_DugmeUsersPerm_Click
    
End Sub
Private Sub DugmeUsersAcc_Click()
On Error GoTo Err_DugmeUsersAcc_Click

    
    DoCmd.RunCommand acCmdUserAndGroupAccounts

Exit_DugmeUsersAcc_Click:
    Exit Sub

Err_DugmeUsersAcc_Click:
    MsgBox err.Description
    Resume Exit_DugmeUsersAcc_Click
    
End Sub
Private Sub DugmeImportIzPG_Click()
On Error GoTo Err_DugmeImportIzPG_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "PS_TabeleZaImportIzPG"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeImportIzPG_Click:
    Exit Sub

Err_DugmeImportIzPG_Click:
    MsgBox err.Description
    Resume Exit_DugmeImportIzPG_Click
    
End Sub
Private Sub OpenDisignMyForm(stDocName As String, Optional stLinkCriteria As String = "")
On Error GoTo Err_OpenMyForm

    DoCmd.OpenForm stDocName, acDesign, , stLinkCriteria

Exit_OpenMyForm:
    Exit Sub

Err_OpenMyForm:
    MsgBox err.Description
    Resume Exit_OpenMyForm
    
End Sub
