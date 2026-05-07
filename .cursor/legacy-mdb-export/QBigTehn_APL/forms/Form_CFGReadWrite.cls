VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_CFGReadWrite"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Function PrimeniUslove()
On Error GoTo Err_Point


    If Me!Podforma.SourceObject <> "ReklamniPanel" Then
        Me!Podforma.Form.PrimeniUslove
    End If
    Me!ZaParametar.Requery

Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "PrimeniUslove"
 Resume Exit_Point
End Function

Private Sub AktivnaFirma_AfterUpdate()
    Me!ZaIDFirma = Me!AktivnaFirma
    PrimeniUslove
End Sub

Private Sub Dugme_SetCNNTest_Click()
    'CNN_SetTest
End Sub

Private Sub DugmeExportAll_Click()
On Error GoTo Err_Export

    Dim stDocName As String
    Dim stPoruka As String
    
 stPoruka = "Svi izabrani parametri ce biti exportovani i u CFG_Global i u CFG_Lokal"
 stPoruka = stPoruka & " bez obzira na to da li su definisani kao Globalni ili Lokalni parametri."
 stPoruka = stPoruka & vbCrLf & vbCrLf & "Da li zaista želite to da uradite?"
 
 If BBPitanje(stPoruka, vbDefaultButton2) Then
    DoCmd.SetWarnings False
    
    stDocName = "CFG_Apl_Parametri_DEF_ExportU_CFG_Global"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    
    stDocName = "CFG_Apl_Parametri_DEF_ExportU_CFG_Lokal"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    
    PrimeniUslove
 End If
Exit_Export:
    DoCmd.SetWarnings True
    Exit Sub

Err_Export:
    MsgBox err.Description
    Resume Exit_Export
End Sub

Private Sub DugmeExportULokal_Click()
On Error GoTo Err_Export

    Dim stDocName As String
    
 If BBPitanje("Da li ste sigurni?") Then
    DoCmd.SetWarnings False
    stDocName = "CFG_Apl_Parametri_DEF_ExportU_CFG_Lokal"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    PrimeniUslove
 End If
Exit_Export:
    DoCmd.SetWarnings True
    Exit Sub

Err_Export:
    MsgBox err.Description
    Resume Exit_Export
    
End Sub

Private Sub DugmeImportIzGlobal_Click()
On Error GoTo Err_Import

    Dim stDocName As String
    
    If Not BBPitanje("Da li ste sigurni?") Then
      Exit Sub
    End If
    
    DoCmd.SetWarnings False
    
    stDocName = "CFG_Global_ImportUAPL_DEF"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    
    'stDocName = "CFG_Global_ImportUAPL_DozvoljeneVrednosti"
    'DoCmd.OpenQuery stDocName, acNormal, acEdit
    
Exit_Import:
    DoCmd.SetWarnings True
    PrimeniUslove
    
    Exit Sub

Err_Import:
    MsgBox err.Description
    Resume Exit_Import
End Sub

Private Sub DugmeImportIzLokal_Click()
On Error GoTo Err_Import

    Dim stDocName As String
    
    If Not BBPitanje("Da li ste sigurni?") Then
      Exit Sub
    End If
    
    DoCmd.SetWarnings False
    
    stDocName = "CFG_Lokal_ImportUAPL_DEF"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    
    'stDocName = "CFG_Lokal_ImportUAPL_DozvoljeneVrednosti"
    'DoCmd.OpenQuery stDocName, acNormal, acEdit
    
Exit_Import:
    DoCmd.SetWarnings True
    PrimeniUslove
    
    Exit Sub

Err_Import:
    MsgBox err.Description
    Resume Exit_Import

End Sub

Private Sub DugmePrikaziSve_Click()
    Me!ZaKatPar = Null
    Me!ZaParametar = Null
    Me!ZaVrednostParametra = Null
    Me!ZaOpis = Null
    Me!ZaImaDef = Null
    Me!ZaImaGlobal = Null
    Me!ZaImaLokal = Null
    Me!ZaDefGlobal = Null
    Me!ZaDefLokal = Null
    
    PrimeniUslove
End Sub

Private Sub DugmePrimeniUslove_Click()
    PrimeniUslove
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
        
    If (CurrentUser() = "Negovan") Or UserUGrupi(CurrentUser(), "PowerFulUsers") Then
     Me!Toggle_Definicije.Enabled = True
     Me!Toggle_Sys.Enabled = True
    Else
     Me!Toggle_Definicije.Enabled = False
     Me!Toggle_Sys.Enabled = False
    End If
    
    Set AktivnaFirma.Recordset = RST_Combo(CNN_CurrentDataBase, "Radni fajlovi", "", "IDBaze", "IDBaze", "Firma")
    Set ZaIDFirma.Recordset = RST_Combo(CNN_CurrentDataBase, "Radni fajlovi", "", "IDBaze", "IDBaze", "Firma")
    
    Me!ZaIDFirma = BBCFG.Firma.IDFirma
    Me!AktivnaFirma = BBCFG.Firma.IDFirma 'BBCFG.Firma.Naziv
    
End Sub

Private Sub FrameCFGParametri_AfterUpdate()
    If Me!FrameCFGParametri = 1 Then
        Me!Podforma.SourceObject = "CFG_SviParametri_DEF"
    ElseIf Me!FrameCFGParametri = 2 Then
        Me!Podforma.SourceObject = "CFG_Global"
    ElseIf Me!FrameCFGParametri = 3 Then
        Me!Podforma.SourceObject = "CFG_Lokal"
    ElseIf Me!FrameCFGParametri = 4 Then
        Me!Podforma.SourceObject = "CFG_Sys"
    ElseIf Me!FrameCFGParametri = 5 Then
        Me!Podforma.SourceObject = "CFG_KatParPrip"
    ElseIf Me!FrameCFGParametri = 9 Then
        Me!Podforma.SourceObject = "CFG_DozvoljeneVrednosti"
    Else
        Me!Podforma.SourceObject = "ReklamniPanel"
    End If
End Sub

Private Sub DugmeReLoadPar_Click()
On Error GoTo Err_DugmeReLoadPar_Click

    Dim tmp As String
    'MsgBox "Ova opcija ne radi u lIB-u!", vbExclamation, "Negovan"
    Set BBCFG = Nothing
    tmp = BBCFG.Firma.Naziv ' da se ponovo inicijalizuje...
           'BBMsgBox "Sacekajte ... ", 5
           
    MsgBox "Novi parametri su postavljeni.", vbInformation, "QMegaTeh"

Exit_DugmeReLoadPar_Click:
    Exit Sub

Err_DugmeReLoadPar_Click:
    MsgBox err.Description
    Resume Exit_DugmeReLoadPar_Click
    
End Sub

Private Sub FrameOstalo_AfterUpdate()
    If Me!FrameOstalo = 1 Then
        Me!Podforma.SourceObject = "Dokumentacija"
    ElseIf Me!FrameOstalo = 5 Then
        Me!Podforma.SourceObject = "EDI"
    ElseIf Me!FrameOstalo = 9 Then
        Me!Podforma.SourceObject = "ODBC_Synch_Design"
    Else
        Me!Podforma.SourceObject = "ReklamniPanel"
    End If
End Sub

Private Sub ZaIDFirma_AfterUpdate()
    Me!AktivnaFirma = Me!ZaIDFirma
    PrimeniUslove
End Sub

Private Sub ZaKatPar_GotFocus()
    Me!ZaKatPar.Requery
End Sub

Private Sub ZaOpis_DblClick(Cancel As Integer)
    Me!ZaOpis = Null
    PrimeniUslove
End Sub

Private Sub ZaParametar_DblClick(Cancel As Integer)
    Me!ZaParametar = Null
    PrimeniUslove
End Sub

Private Sub DugmeRevInfo_Click()
On Error GoTo Err_DugmeRevInfo_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "_APPRev"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeRevInfo_Click:
    Exit Sub

Err_DugmeRevInfo_Click:
    MsgBox err.Description
    Resume Exit_DugmeRevInfo_Click
    
End Sub
Private Sub DugmeODBCSynchDesign_Click()
On Error GoTo Err_DugmeODBCSynchDesign_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "ODBC_Synch_Design"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeODBCSynchDesign_Click:
    Exit Sub

Err_DugmeODBCSynchDesign_Click:
    MsgBox err.Description
    Resume Exit_DugmeODBCSynchDesign_Click
    
End Sub
Private Sub DugmeEDI_Click()
On Error GoTo Err_DugmeEDI_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "EDI"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeEDI_Click:
    Exit Sub

Err_DugmeEDI_Click:
    MsgBox err.Description
    Resume Exit_DugmeEDI_Click
    
End Sub
Private Sub DugmeOtvoriFormuBBCFG_Click()
On Error GoTo Err_DugmeOtvoriFormuBBCFG_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "BBCFG"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeOtvoriFormuBBCFG_Click:
    Exit Sub

Err_DugmeOtvoriFormuBBCFG_Click:
    MsgBox err.Description
    Resume Exit_DugmeOtvoriFormuBBCFG_Click
    
End Sub

Private Sub ZaKatPar_DblClick(Cancel As Integer)
    Me!ZaKatPar = Null
    PrimeniUslove
End Sub

Private Sub ZaVrednostParametra_DblClick(Cancel As Integer)
    Me!ZaVrednostParametra = Null
    PrimeniUslove
End Sub
Private Sub DugmeExportUGlobal_Click()
On Error GoTo Err_Export

    Dim stDocName As String
    
 If BBPitanje("Da li ste sigurni?") Then
    DoCmd.SetWarnings False
    stDocName = "CFG_Apl_Parametri_DEF_ExportU_CFG_Global"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    PrimeniUslove
 End If
Exit_Export:
    DoCmd.SetWarnings True
    Exit Sub

Err_Export:
    MsgBox err.Description
    Resume Exit_Export
    
End Sub
