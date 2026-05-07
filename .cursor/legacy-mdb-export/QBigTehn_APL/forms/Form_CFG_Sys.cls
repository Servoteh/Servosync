VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_CFG_Sys"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Public Function PrimeniUslove()
 SetProperlyRecordSource CNN_CFG_Sys, Me
End Function
Private Sub ComboPronadjiParametar_AfterUpdate()
    ' Find the record that matches the control.
    Dim rs As Object

    Set rs = Me.Recordset.Clone
    'rs.FindFirst "[Parametar] = '" & Me![ComboPronadjiParametar] & "'"
    If TypeOf rs Is ADODB.Recordset Then
        rs.Find "[Parametar] = '" & Me![ComboPronadjiParametar] & "'"
    Else
        rs.FindFirst "[Parametar] = '" & Me![ComboPronadjiParametar] & "'"
    End If
    
    If Not rs.EOF Then Me.Bookmark = rs.Bookmark
    Me![ComboPronadjiParametar] = Null
End Sub
Private Sub ComboPronadjiParametar_GotFocus()
    Me!ComboPronadjiParametar.Requery
End Sub

Private Sub DugmePostavi_CFG_T_Tabele_Click()
'    If Postavi_CFG_T_Tabele() Then
'     MsgBox "Tabele/Upiti su uspešno postavljeni.", vbInformation, "QMegaTeh"
'    Else
'     MsgBox "Tabele/Upiti nisu uspešno postavljeni.", vbExclamation, "QMegaTeh"
'    End If
  MsgBox "Tabele/Upiti nisu uspešno postavljeni.", vbExclamation, "QMegaTeh"
End Sub

Private Sub Form_Open(Cancel As Integer)
    PrimeniUslove
End Sub

Private Sub Form_Unload(Cancel As Integer)
    CloseConnectionOnCurrentForm Me
End Sub

Private Sub Parametar_DblClick(Cancel As Integer)
    Me.Parent!ZaParametar = Left(CStr(Nz(Me!Parametar, "<<Null>>")), 100)
    PrimeniUslove
End Sub

Private Sub Vrednost_DblClick(Cancel As Integer)
    Me.Parent!ZaVrednostParametra = Left(CStr(Nz(Me!Vrednost, "<<Null>>")), 100)
    PrimeniUslove
End Sub

