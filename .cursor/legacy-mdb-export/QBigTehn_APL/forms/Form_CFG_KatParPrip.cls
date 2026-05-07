VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_CFG_KatParPrip"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Public Function PrimeniUslove()
 Me.Requery
End Function
Private Sub ComboPronadjiParametar_GotFocus()
  Me!ComboPronadjiParametar.Requery
End Sub

Private Sub KatPar_DblClick(Cancel As Integer)
   Me.Parent!ZaKatPar = Me!KatPar
    PrimeniUslove
End Sub

Private Sub Parametar_DblClick(Cancel As Integer)
    Me.Parent!ZaParametar = Me!Parametar
    PrimeniUslove
End Sub

Private Sub Vrednost_DblClick(Cancel As Integer)
    Me.Parent!ZaVrednostParametra = Me!Vrednost
    PrimeniUslove
End Sub

Private Sub Form_AfterInsert()
  Me!KatPar.DefaultValue = "= """ & Me!KatPar & """"
End Sub

Private Sub ZaImaGlobal_AfterUpdate()
    Me.Requery
End Sub

Private Sub ZaImaLokal_AfterUpdate()
    Me.Requery
End Sub
Private Sub DugmeExport_Click()
On Error GoTo Err_DugmeExport_Click

    Dim stDocName As String

    DoCmd.SetWarnings False
    stDocName = "CFG_APL_ExportUGlobal"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    
    stDocName = "CFG_APL_ExportULokal"
    DoCmd.OpenQuery stDocName, acNormal, acEdit

Exit_DugmeExport_Click:
    DoCmd.SetWarnings True
    Me.Requery
    Exit Sub

Err_DugmeExport_Click:
    MsgBox err.Description
    Resume Exit_DugmeExport_Click
    
End Sub
Private Sub DugmeImport_Click()
On Error GoTo Err_DugmeImport_Click

    Dim stDocName As String
    
    DoCmd.SetWarnings False
    
    stDocName = "CFG_Global_ImportUAPL_DEF"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    
    stDocName = "CFG_Global_ImportUAPL_DozvoljeneVrednosti"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    
    stDocName = "CFG_Global_ImportUAPL"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    
    
    
    stDocName = "CFG_Lokal_ImportUAPL_DEF"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    
    stDocName = "CFG_Lokal_ImportUAPL_DozvoljeneVrednosti"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    
    stDocName = "CFG_Lokal_ImportUAPL"
    DoCmd.OpenQuery stDocName, acNormal, acEdit

Exit_DugmeImport_Click:
    DoCmd.SetWarnings True
    Me.Requery
    Exit Sub

Err_DugmeImport_Click:
    MsgBox err.Description
    Resume Exit_DugmeImport_Click
    
End Sub
Private Sub ComboPronadjiParametar_AfterUpdate()
    ' Find the record that matches the control.
    Dim rs As Object

    Set rs = Me.Recordset.Clone
    rs.FindFirst "[Parametar] = '" & Me![ComboPronadjiParametar] & "'"
    If Not rs.EOF Then Me.Bookmark = rs.Bookmark
    Me![ComboPronadjiParametar] = Null
End Sub

