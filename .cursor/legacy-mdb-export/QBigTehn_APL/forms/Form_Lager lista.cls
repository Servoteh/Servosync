VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Lager lista"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit

Private Sub ComboCenovnik_AfterUpdate()
    Me.Requery
    If IsNull(Me!ComboCenovnik) Then
        Me!DugmeUpisiNabCenuUCenovnik.Caption = "Upiši nab. cenu u []" & " cenovnik"
    Else
        Me!DugmeUpisiNabCenuUCenovnik.Caption = "Upiši nab. cenu u [" & Me!ComboCenovnik & "] cenovnik"
    End If
End Sub



Private Sub Dugme___obrisi_slog_Click()
On Error GoTo Err_Dugme___obrisi_slog_Click


    DoCmd.DoMenuItem A_FORMBAR, A_EDITMENU, A_SELECTRECORD_V2, , A_MENU_VER20
    DoCmd.DoMenuItem A_FORMBAR, A_EDITMENU, A_DELETE_V2, , A_MENU_VER20

Exit_Dugme___obrisi_slog_Click:
    Exit Sub

Err_Dugme___obrisi_slog_Click:
    MsgBox Error$
    Resume Exit_Dugme___obrisi_slog_Click
    
End Sub

Private Sub Dugme___ponisti_unos_Click()
On Error GoTo Err_Dugme___ponisti_unos_Click


    DoCmd.DoMenuItem A_FORMBAR, A_EDITMENU, A_UNDOFIELD, , A_MENU_VER20

Exit_Dugme___ponisti_unos_Click:
    Exit Sub

Err_Dugme___ponisti_unos_Click:
    MsgBox Error$
    Resume Exit_Dugme___ponisti_unos_Click
    
End Sub

Private Sub Dugme___prethodni_sl_Click()
On Error GoTo Err_Dugme___Prethodni_sl_Click


    DoCmd.GoToRecord , , A_PREVIOUS

Exit_Dugme___Prethodni_sl_Click:
    Exit Sub

Err_Dugme___Prethodni_sl_Click:
    MsgBox Error$
    Resume Exit_Dugme___Prethodni_sl_Click
    
End Sub

Private Sub Dugme___Sledeci_slog_Click()
On Error GoTo Err_Dugme___Sledeci_slog_Click


    DoCmd.GoToRecord , , A_NEXT

Exit_Dugme___Sledeci_slog_Click:
    Exit Sub

Err_Dugme___Sledeci_slog_Click:
    MsgBox Error$
    Resume Exit_Dugme___Sledeci_slog_Click
    
End Sub

Private Sub Dugme___Snimi_slog_Click()
On Error GoTo Err_Dugme___Snimi_slog_Click


    DoCmd.DoMenuItem A_FORMBAR, A_FILE, A_SAVERECORD, , A_MENU_VER20

Exit_Dugme___Snimi_slog_Click:
    Exit Sub

Err_Dugme___Snimi_slog_Click:
    MsgBox Error$
    Resume Exit_Dugme___Snimi_slog_Click
    
End Sub





Private Sub Dugme_Printuj_lager_Click()
On Error GoTo Err_Dugme_Printuj_lager_Click

    Dim DocName As String

    DocName = "Izbor za lager listu"
    DoCmd.OpenForm DocName

Exit_Dugme_Printuj_lager_Click:
    Exit Sub

Err_Dugme_Printuj_lager_Click:
    MsgBox Error$
    Resume Exit_Dugme_Printuj_lager_Click
    
End Sub

Private Sub Dugme_requery_Click()
On Error GoTo Err_Dugme_Requery_Click


    Me.Requery

Exit_Dugme_Requery_Click:
    Exit Sub

Err_Dugme_Requery_Click:
    MsgBox Error$
    Resume Exit_Dugme_Requery_Click
    
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
Private Sub Form_Open(Cancel As Integer)
    If F_NivoBaze() > 0 Then
        Me!LabelLevel.Visible = True
        Me!OdLevel.Visible = True
        Me!OdLevel.ValidationRule = "BETWEEN 0 AND " & F_NivoBaze()
        Me!OdLevel.ValidationText = "Dozvoljene vrednosti su od 0 do " & F_NivoBaze()
        Me!DoLevel.Visible = True
        Me!DoLevel.ValidationRule = "BETWEEN 0 AND " & F_NivoBaze()
        Me!DoLevel.ValidationText = "Dozvoljene vrednosti su od 0 do " & F_NivoBaze()
    Else
        Me!LabelLevel.Visible = False
        Me!OdLevel.Visible = False
        Me!DoLevel.Visible = False
 End If
 
 
End Sub

Private Sub Na_dan_AfterUpdate()

    Me.Requery

End Sub

Private Sub Ponisti_filter_Click()
On Error GoTo Err_Ponisti_filter_Click


    Rem DoCmd DoMenuItem A_FORMBAR, A_RECORDSMENU, 6, , A_MENU_VER20

    Me![ZaGrupu] = Null
    Me![ZaPodgrupu] = Null
    Me![ZaPoreklo] = Null
    Me![ZaTarifu] = Null
    Me![ZaDobavljaca] = Null
    Me![ZaMagacin] = Null
    Me![ZaKatBroj] = Null
    Me![NulaKolicine] = True
    Me!OdLevel = CInt(0)
    Me!DoLevel = CInt(F_NivoBaze())
    Me!ZaVrstuRastera = Null
    Me!ZaKolonuRastera = Null
    Me.Requery

Exit_Ponisti_filter_Click:
    Exit Sub

Err_Ponisti_filter_Click:
    MsgBox Error$
    Resume Exit_Ponisti_filter_Click
    
End Sub



Private Sub TraziKataloskiBroj_AfterUpdate()
On Error Resume Next
    Me![Sifra artikla].Visible = True
    DoCmd.GoToControl ("Sifra artikla")
    DoCmd.FindRecord Me![TraziKataloskiBroj]
    DoCmd.GoToControl "TraziKataloskiBroj"
    Me![TraziKataloskiBroj] = Null
    Me![Sifra artikla].Visible = False
End Sub

Private Sub TraziNazivArtikla_AfterUpdate()
On Error Resume Next
    Me![Sifra artikla].Visible = True
    DoCmd.GoToControl ("Sifra artikla")
    DoCmd.FindRecord Me![TraziNazivArtikla]
    DoCmd.GoToControl "TraziNazivArtikla"
    Me![TraziNazivArtikla] = Null
    Me![Sifra artikla].Visible = False
End Sub


Private Sub DugmePopisSaPolicama_Click()
On Error GoTo Err_DugmePopisSaPolicama_Click

    Dim stDocName As String

    stDocName = "PopisnaListaSaPolicama"
    DoCmd.OpenReport stDocName, acPreview

Exit_DugmePopisSaPolicama_Click:
    Exit Sub

Err_DugmePopisSaPolicama_Click:
    MsgBox err.Description
    Resume Exit_DugmePopisSaPolicama_Click
    
End Sub


Private Sub ZaGrupu_AfterUpdate()
    Me.Requery
    DoCmd.GoToControl ("ZaPodgrupu")
    Me![ZaPodgrupu].Requery
    Me!ZaPoreklo.Requery
End Sub

Private Sub ZaPodgrupu_AfterUpdate()
    Me.Requery
    DoCmd.GoToControl ("ZaPoreklo")
    Me!ZaPoreklo.Requery
End Sub

Private Sub ZaPoreklo_AfterUpdate()
    Me.Requery
End Sub

