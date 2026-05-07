VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BazeITabele_APL"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Function PrimeniUslove()
 Me.Requery
End Function
Private Sub Name_DblClick(Cancel As Integer)
    Me.Parent!ZaLokalTableName = Me!Name
    PrimeniUslove
End Sub

Private Sub SourceTableName_DblClick(Cancel As Integer)
    Me.Parent!ZaSourceTableName = Me!SourceTableName
    PrimeniUslove
End Sub

Private Sub TipBaze_DblClick(Cancel As Integer)
    Me.Parent!ZaTipBaze = Me!TipBaze
    PrimeniUslove
End Sub
Private Sub DugmeExportUFIT_Click()
On Error GoTo Err_DugmeExportUFIT_Click

    Dim stDocName As String
If BBPitanje("Da li ste sigurni?") Then
    DoCmd.SetWarnings False
     stDocName = "BazeITabele_APL_ExportUFIT"
     DoCmd.OpenQuery stDocName, acNormal, acEdit
    DoCmd.SetWarnings True
    PrimeniUslove
    'NE Radi! MsgBox "Uspešno exportovano " & CurrentDb.RecordsAffected & " slogova.", vbInformation, "QMegaTeh"
End If

Exit_DugmeExportUFIT_Click:
     DoCmd.SetWarnings True
    Exit Sub

Err_DugmeExportUFIT_Click:
    MsgBox err.Description
    Resume Exit_DugmeExportUFIT_Click
    
End Sub
Private Sub DugmeImportIzFIT_Click()
On Error GoTo Err_Point

    Dim stDocName As String
If BBPitanje("Da li ste sigurni?") Then
    DoCmd.SetWarnings False
     stDocName = "BazeITabele_APL_ImportIzFIT"
     DoCmd.OpenQuery stDocName, acNormal, acEdit
    DoCmd.SetWarnings True
    PrimeniUslove
    'NE RADI DOBRO MsgBox "Uspešno importovano " & CurrentDb.RecordsAffected & " slogova.", vbInformation, "QMegaTeh"
End If

Exit_Point:
     DoCmd.SetWarnings True
    Exit Sub

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
    
End Sub
