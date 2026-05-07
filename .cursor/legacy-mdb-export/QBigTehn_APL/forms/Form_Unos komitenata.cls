VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Unos komitenata"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons

Private Sub ComboPoNazivu_AfterUpdate()
     ' Find the record that matches the control.
    Me.RecordsetClone.FindFirst "[Sifra] = " & Me![ComboPoNazivu]
    Me.Bookmark = Me.RecordsetClone.Bookmark
    Me![ComboPoNazivu] = Null
End Sub

Private Sub ComboPoNazivu_GotFocus()
     If IsLoaded("MPRacun") Then
        Me.AllowEdits = True
    End If
End Sub

Private Sub Dugme_Novi_komitent_Click()
On Error GoTo Err_Dugme_novi_komitent_Click

   
        DoCmd.GoToRecord , , A_NEWREC
        DoCmd.GoToControl "Naziv"
   
Exit_Dugme_novi_komitent_Click:
    Exit Sub

Err_Dugme_novi_komitent_Click:
    Rem MsgBox Error$
    Resume Exit_Dugme_novi_komitent_Click
    
End Sub

Private Sub Dugme_Obrisi_komiten_Click()
On Error GoTo Err_Dugme_Obrisi_komiten_Click


    DoCmd.DoMenuItem A_FORMBAR, A_EDITMENU, A_SELECTRECORD_V2, , A_MENU_VER20
    DoCmd.DoMenuItem A_FORMBAR, A_EDITMENU, A_DELETE_V2, , A_MENU_VER20

Exit_Dugme_Obrisi_komiten_Click:
    Exit Sub

Err_Dugme_Obrisi_komiten_Click:
    MsgBox Error$
    Resume Exit_Dugme_Obrisi_komiten_Click
    
End Sub

Private Sub Dugme_Obrisi_slog_Click()
On Error GoTo Err_Dugme_Obrisi_slog_Click


    DoCmd.DoMenuItem A_FORMBAR, A_EDITMENU, A_SELECTRECORD_V2, , A_MENU_VER20
    DoCmd.DoMenuItem A_FORMBAR, A_EDITMENU, A_DELETE_V2, , A_MENU_VER20

Exit_Dugme_Obrisi_slog_Click:
    Exit Sub

Err_Dugme_Obrisi_slog_Click:
    MsgBox Error$
    Resume Exit_Dugme_Obrisi_slog_Click
    
End Sub

Private Sub Dugme_Ponisti_unos_Click()
On Error GoTo Err_Dugme_Ponisti_unos_Click


    DoCmd.DoMenuItem A_FORMBAR, A_EDITMENU, A_UNDOFIELD, , A_MENU_VER20

Exit_Dugme_Ponisti_unos_Click:
    Exit Sub

Err_Dugme_Ponisti_unos_Click:
    MsgBox "Mozete da ponistite samo tekuci unos ili ispravku!", 48, "Poruka:"
    Resume Exit_Dugme_Ponisti_unos_Click
    
End Sub

Private Sub Dugme_Prethodni_slog_Click()
On Error GoTo Err_Dugme_Prethodni_slog_Click


    DoCmd.GoToRecord , , A_PREVIOUS

Exit_Dugme_Prethodni_slog_Click:
    Exit Sub

Err_Dugme_Prethodni_slog_Click:
    MsgBox Error$
    Resume Exit_Dugme_Prethodni_slog_Click
    
End Sub

Private Sub Dugme_Pronadji_komit_Click()
On Error GoTo Err_Dugme_Pronadji_komit_Click


    DoCmd.DoMenuItem A_FORMBAR, A_EDITMENU, 10, , A_MENU_VER20

Exit_Dugme_Pronadji_komit_Click:
    Exit Sub

Err_Dugme_Pronadji_komit_Click:
    MsgBox Error$
    Resume Exit_Dugme_Pronadji_komit_Click
    
End Sub

Private Sub Dugme_Sledeci_slog_Click()
On Error GoTo Err_Dugme_Sledeci_slog_Click


    DoCmd.GoToRecord , , A_NEXT

Exit_Dugme_Sledeci_slog_Click:
    Exit Sub

Err_Dugme_Sledeci_slog_Click:
    MsgBox Error$
    Resume Exit_Dugme_Sledeci_slog_Click
    
End Sub

Private Sub Dugme_Snimi_komitent_Click()
On Error GoTo Err_Dugme_Snimi_komitent_Click


    DoCmd.DoMenuItem A_FORMBAR, A_FILE, A_SAVERECORD, , A_MENU_VER20

Exit_Dugme_Snimi_komitent_Click:
    Exit Sub

Err_Dugme_Snimi_komitent_Click:
    MsgBox Error$
    Resume Exit_Dugme_Snimi_komitent_Click
    
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

Private Sub Dugme_Trazi_Click()
On Error GoTo Err_Dugme_Trazi_Click


    DoCmd.DoMenuItem A_FORMBAR, A_EDITMENU, 10, , A_MENU_VER20

Exit_Dugme_Trazi_Click:
    Exit Sub

Err_Dugme_Trazi_Click:
    MsgBox Error$
    Resume Exit_Dugme_Trazi_Click
    
End Sub




Private Sub Form_Open(Cancel As Integer)
 On Error Resume Next
    DoCmd.GoToRecord , , acLast
    DoCmd.GoToControl "ComboPoNazivu"
    
End Sub




Private Sub PronadjiPoZRRN_AfterUpdate()
      ' Find the record that matches the control.
    Me.RecordsetClone.FindFirst "[Sifra] = " & Me![PronadjiPoZRRN]
    Me.Bookmark = Me.RecordsetClone.Bookmark
    Me![PronadjiPoZRRN] = Null
End Sub

Private Sub Vrsta_sifre_DblClick(Cancel As Integer)
    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "Vrste sifara"
    DoCmd.OpenForm stDocName, , , stLinkCriteria
End Sub

