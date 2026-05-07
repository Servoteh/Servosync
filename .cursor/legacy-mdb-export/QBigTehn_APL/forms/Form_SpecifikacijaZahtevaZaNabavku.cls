VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_SpecifikacijaZahtevaZaNabavku"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit
Private Sub ComboKatBroj_AfterUpdate()
    'Kataloski brojStavke
    If Nz(Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![Kataloski brojStavke], "") <> "" And Nz(Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![Kataloski brojStavke], "") <> "-" Then
        If BBPitanje("Postoji opisno definisan kataloški broj artikla." & vbCrLf & "Da li želite da ga predefinišete?") Then
            Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![OpisStavke] = Left(Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![EXT_R_Artikli.Naziv], CurrentDb.TableDefs("EXT_SpecifikacijaZahtevaNabavke").Fields("OpisStavke").Size)
            Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![Kataloski brojStavke] = Left(Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![EXT_R_Artikli.Kataloski broj], CurrentDb.TableDefs("EXT_SpecifikacijaZahtevaNabavke").Fields("Kataloski brojStavke").Size)
            Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![Jedinica mereStavke] = Left(Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![EXT_R_Artikli.Jedinica mere], CurrentDb.TableDefs("EXT_SpecifikacijaZahtevaNabavke").Fields("Jedinica mereStavke").Size)
        End If
    Else
        'If Nz(Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![OpisStavke], "") = "" Then
         Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![OpisStavke] = Left(Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![EXT_R_Artikli.Naziv], CurrentDb.TableDefs("EXT_SpecifikacijaZahtevaNabavke").Fields("OpisStavke").Size)
         Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![Kataloski brojStavke] = Left(Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![EXT_R_Artikli.Kataloski broj], CurrentDb.TableDefs("EXT_SpecifikacijaZahtevaNabavke").Fields("Kataloski brojStavke").Size)
         Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![Jedinica mereStavke] = Left(Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![EXT_R_Artikli.Jedinica mere], CurrentDb.TableDefs("EXT_SpecifikacijaZahtevaNabavke").Fields("Jedinica mereStavke").Size)
    End If
End Sub

Private Sub ComboKatBroj_NotInList(NewData As String, Response As Integer)
 Dim NoviPodatak As Integer, Title As String, MsgDialog As Integer
    'Const MB_YESNO = 4
    'Const MB_ICONEXCLAMATION = 48
    'Const MB_DEFBUTTON1 = 0, IDYES = 6, IDNO = 7
    'Const CLR_WHITE = 16777215
    'Const NORMAL = 1

     
      'DoCmd.DoMenuItem acFormBar, acEditMenu, acUndo, , acMenuVer70
      'DoCmd.DoMenuItem acFormBar, acEditMenu, acUndo, , acMenuVer70

     'Title = "Podatak nije u listi"
     'MsgDialog = MB_YESNO + MB_ICONEXCLAMATION + MB_DEFBUTTON1

     'NoviPodatak = MsgBox("Zelite da unesete novi podatak u listu?", MsgDialog, Title)

     'If NoviPodatak = IDYES Then

     '   DoCmd.OpenForm "Unos komitenata"
     '   DoCmd.GoToRecord A_FORM, "Unos komitenata", A_NEWREC
     '   Forms![Unos komitenata]![Naziv] = NewData
     '   DoCmd.GoToControl "Naziv"

     'End If
     Me![Kataloski brojStavke] = NewData
     Me![ComboKatBroj] = 0
     DoCmd.GoToControl "OpisStavke"
     
     Response = DATA_ERRCONTINUE

End Sub



Private Sub ComboNazivArtikla_AfterUpdate()
    'Kataloski brojStavke
    If Nz(Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![OpisStavke], "") <> "" And Nz(Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![Kataloski brojStavke], "") <> "-" Then
        If BBPitanje("Postoji opisno definisan naziv artikla." & vbCrLf & "Da li želite da ga predefinišete?") Then
            Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![OpisStavke] = Left(Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![EXT_R_Artikli.Naziv], CurrentDb.TableDefs("EXT_SpecifikacijaZahtevaNabavke").Fields("OpisStavke").Size)
            Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![Kataloski brojStavke] = Left(Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![EXT_R_Artikli.Kataloski broj], CurrentDb.TableDefs("EXT_SpecifikacijaZahtevaNabavke").Fields("Kataloski brojStavke").Size)
            Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![Jedinica mereStavke] = Left(Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![EXT_R_Artikli.Jedinica mere], CurrentDb.TableDefs("EXT_SpecifikacijaZahtevaNabavke").Fields("Jedinica mereStavke").Size)
        End If
    Else
        'If Nz(Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![OpisStavke], "") = "" Then
         Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![OpisStavke] = Left(Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![EXT_R_Artikli.Naziv], CurrentDb.TableDefs("EXT_SpecifikacijaZahtevaNabavke").Fields("OpisStavke").Size)
         Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![Kataloski brojStavke] = Left(Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![EXT_R_Artikli.Kataloski broj], CurrentDb.TableDefs("EXT_SpecifikacijaZahtevaNabavke").Fields("Kataloski brojStavke").Size)
         Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![Jedinica mereStavke] = Left(Forms![UnosZahtevaZaNabavku]![SpecifikacijaZahtevaZaNabavku].Form![EXT_R_Artikli.Jedinica mere], CurrentDb.TableDefs("EXT_SpecifikacijaZahtevaNabavke").Fields("Jedinica mereStavke").Size)
    End If
End Sub

Private Sub ComboNazivArtikla_NotInList(NewData As String, Response As Integer)
 Dim NoviPodatak As Integer, Title As String, MsgDialog As Integer
    'Const MB_YESNO = 4
    'Const MB_ICONEXCLAMATION = 48
    'Const MB_DEFBUTTON1 = 0, IDYES = 6, IDNO = 7
    'Const CLR_WHITE = 16777215
    'Const NORMAL = 1

     
      'DoCmd.DoMenuItem acFormBar, acEditMenu, acUndo, , acMenuVer70
      'DoCmd.DoMenuItem acFormBar, acEditMenu, acUndo, , acMenuVer70

     'Title = "Podatak nije u listi"
     'MsgDialog = MB_YESNO + MB_ICONEXCLAMATION + MB_DEFBUTTON1

     'NoviPodatak = MsgBox("Zelite da unesete novi podatak u listu?", MsgDialog, Title)

     'If NoviPodatak = IDYES Then

     '   DoCmd.OpenForm "Unos komitenata"
     '   DoCmd.GoToRecord A_FORM, "Unos komitenata", A_NEWREC
     '   Forms![Unos komitenata]![Naziv] = NewData
     '   DoCmd.GoToControl "Naziv"

     'End If
     Me!OpisStavke = NewData
     Me!ComboNazivArtikla = 0
     DoCmd.GoToControl "OpisStavke"
     
     Response = DATA_ERRCONTINUE
End Sub

Private Sub ComboPronadjiKatBroj_AfterUpdate()
' Find the record that matches the control.
    Me.RecordsetClone.FindFirst "[IDStavke] = " & Me![ComboPronadjiKatBroj]
    Me.Bookmark = Me.RecordsetClone.Bookmark
    Me![ComboPronadjiKatBroj] = Null
End Sub

Private Sub ComboPronadjiKatBroj_Enter()
    Me.AllowEdits = True
End Sub

Private Sub ComboPronadjiKatBroj_GotFocus()
  Me!ComboPronadjiKatBroj.Requery
End Sub

Private Sub ComboPronadjiNazivArt_AfterUpdate()
' Find the record that matches the control.
    Me.RecordsetClone.FindFirst "[IDStavke] = " & Me![ComboPronadjiNazivArt]
    Me.Bookmark = Me.RecordsetClone.Bookmark
    Me![ComboPronadjiNazivArt] = Null
End Sub
Private Sub ComboPronadjiNazivArt_GotFocus()
    Me!ComboPronadjiNazivArt.Requery
End Sub

Private Sub Dugme_Nova_Stavka_Click()
    DoCmd.GoToRecord , , acNewRec
    DoCmd.GoToControl "ComboKatBroj"
End Sub


Private Sub SifraDobavljaca_DblClick(Cancel As Integer)
 Dim stDocName As String
  Dim stLinkCriteria As String

 
  stDocName = "IzborZaKomitenta"
  DoCmd.OpenForm stDocName, , , stLinkCriteria

  While IsLoaded("IzborZaKomitenta")
       DoEvents
  Wend
 
End Sub
