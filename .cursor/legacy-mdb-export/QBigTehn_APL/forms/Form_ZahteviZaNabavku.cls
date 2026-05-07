VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_ZahteviZaNabavku"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Function ClearCurrentVal()
   Screen.ActiveControl.Value = Null
   PrimeniUslove
End Function
Private Sub CmbKomitent_AfterUpdate()
    Me.Requery
    DoCmd.GoToControl "CmbKomitent"
End Sub

Private Sub CmbPronadji_AfterUpdate()
    Dim rs As Object

    Set rs = Me.Recordset.Clone
    rs.FindFirst "[IDZahtevaZaNabavku] = " & stR(Me![CmbPronadji])
    Me.Bookmark = rs.Bookmark
    Me!CmbPronadji = Null
    DoCmd.GoToControl "CmbPronadji"
End Sub

Private Sub CmbPronadji_GotFocus()
    Me!CmbPronadji.Requery
End Sub
Private Sub DatumZahteva_AfterUpdate()
    If IsNull(Me![RokZaPonudu]) And Not IsNull(Me![DatumZahteva]) Then
        Me![RokZaPonudu] = DateAdd("d", NullToZero(Me![URokuDana]), Me![DatumZahteva])
    End If
    Me![URokuDana] = RastojanjeIzmedjuDatuma(Me![DatumZahteva], Me![RokZaPonudu])
End Sub

Private Sub Do_Datuma_AfterUpdate()
    Me.Requery
    DoCmd.GoToControl "[cmbKomitent]"
End Sub

Public Function PrimeniUslove()
    Me.Requery
End Function

Private Sub F_URokuDana_F_GotFocus()
    DoCmd.GoToControl "URokuDana_F"
End Sub

Private Sub DugmeDetaljnoUpit_Click()
On Error GoTo Err_DugmeSetaljnoZahtev_Click

    Dim stDocName As String
    Dim stLinkCriteria As String
    Dim IDUpita As Long
    
    IDUpita = Nz(DLookup("IDUpita", "T_UpitDobavljacu", "IDTrebVeza = " & Me!IDZahtevaZaNabavku), 0)
    If IDUpita <> 0 Then
        stDocName = "UpitDobavljacu"
        
        stLinkCriteria = "[IDUpita]=" & IDUpita
        DoCmd.OpenForm stDocName, , , stLinkCriteria
    Else
        MsgBox "Nije kreiran upit dobavljaèu za nabavku delova", vbInformation
    End If
    
Exit_DugmeSetaljnoZahtev_Click:
    Exit Sub

Err_DugmeSetaljnoZahtev_Click:
    MsgBox err.Description
    Resume Exit_DugmeSetaljnoZahtev_Click

End Sub

Private Sub DugmePrimeniUslove_Click()
    PrimeniUslove
End Sub

Private Sub F_URokuDana_GotFocus()
    DoCmd.GoToControl "URokuDana"
End Sub

Private Sub Form_Activate()
    Me!IDPredmet.Requery
End Sub


Private Sub Form_AfterUpdate()
    Dim db As DAO.Database
    Dim qdf As DAO.QueryDef
    Dim qdfStavke As DAO.Recordset
    If (NullToZero(Me![IDPredmet]) <> 0) Then
        Set db = CurrentDb
        Set qdf = db.QueryDefs("PredmetiQry")
        qdf.Parameters("ID") _
          = Me!IDPredmet
        Set qdfStavke = qdf.OpenRecordset()
      
         qdfStavke.Edit
         qdfStavke![Opis] = Me!Opis
         qdfStavke.Update
            
        qdfStavke.Close
        Set qdfStavke = Nothing
        qdf.Close
        Set qdf = Nothing
        db.Close
        Set db = Nothing
    End If


End Sub

Private Sub Form_Current()
     Me![URokuDana] = RastojanjeIzmedjuDatuma(Me![DatumZahteva], Me![RokZaPonudu])
     Me!IDPredmet.Requery
End Sub

Private Sub Form_Open(Cancel As Integer)
     If UserUGrupi(CurrentUser, "Korisnici") Or UserUGrupi(CurrentUser, "Admins") Then
            Me.AllowDeletions = True
        Else
            Me.AllowDeletions = False
        End If
    DoCmd.Maximize
On Error Resume Next
    Me.Requery
    DoCmd.GoToControl "CmbPronadji"
    
End Sub
Private Sub IDPredmet_DblClick(Cancel As Integer)
    DugmePredmeti_Click
End Sub

Private Sub IDPredmet_Enter()
    If (Me![IDPredmet] = 0 Or IsNull(Me![IDPredmet])) Then
        Me!IDPredmet.Locked = False
    Else
        If UserUGrupi(CurrentUser, "Korisnici") Or UserUGrupi(CurrentUser, "Admins") Then
            Me!IDPredmet.Locked = False
        Else
            Me!IDPredmet.Locked = True
        End If
    End If
End Sub



Private Sub IDRadniNalog_GotFocus()
    Me!IDRadniNalog.Requery
End Sub

Private Sub Od_Datuma_AfterUpdate()
    Me.Requery
    DoCmd.GoToControl "[Do datuma]"
End Sub

Private Sub RokZaPonudu_AfterUpdate()
 Me![URokuDana] = RastojanjeIzmedjuDatuma(Me![DatumZahteva], Me![RokZaPonudu])
End Sub

Private Sub URokuDana_AfterUpdate()
   If Not IsNull(Me![DatumZahteva]) Then
        Me![RokZaPonudu] = DateAdd("d", NullToZero(Me![URokuDana]), Me![DatumZahteva])
   End If

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


Private Sub DugmePredmeti_Click()
On Error GoTo Err_DugmePredmeti_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "Predmeti"
    
    stLinkCriteria = "[IDPredmet]=" & Me![IDPredmet]
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmePredmeti_Click:
    Exit Sub

Err_DugmePredmeti_Click:
    MsgBox err.Description
    Resume Exit_DugmePredmeti_Click
    
End Sub
Private Sub Ponisti_filter_Click()
On Error GoTo Err_Ponisti_filter_Click

    Me!ZaDobavljaca = Null
    Me!ZaInicijatoraZahteva = Null
    Me!ZaStatus = Null
    Me!ZaBrojPredmeta = Null
    Me!ZaBrojZahteva = Null
    Me.Requery

Exit_Ponisti_filter_Click:
    Exit Sub

Err_Ponisti_filter_Click:
    MsgBox Error$
    Resume Exit_Ponisti_filter_Click
    
End Sub

Private Sub DugmePredmet_Click()
On Error GoTo Err_DugmePredmet_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "Predmeti"
    If (Me![IDPredmet] = 0 Or IsNull(Me![IDPredmet])) Then
        MsgBox "Ne postoji otvoren predmet po ovom zahtevu!!!"
    Else
        stLinkCriteria = "[IDPredmet]=" & Me![IDPredmet]
        DoCmd.OpenForm stDocName, , , stLinkCriteria
    End If
    
Exit_DugmePredmet_Click:
    Exit Sub

Err_DugmePredmet_Click:
    MsgBox err.Description
    Resume Exit_DugmePredmet_Click
    
End Sub

Private Sub URokuDana_F_AfterUpdate()
      If Not IsNull(Me![DatumZahteva]) Then
        Me![RokZaPonudu] = DateAdd("d", NullToZero(Me![URokuDana_F]), Me![DatumZahteva])
   End If

End Sub


Private Sub ZaProdavca_AfterUpdate()
     Me.Requery
    DoCmd.GoToControl "ZaProdavca"
End Sub





Private Sub ZaDobavljaca_GotFocus()
    Me!ZaDobavljaca.Requery
End Sub
Private Sub ZaStatus_AfterUpdate()
     Me.Requery
    DoCmd.GoToControl "ZaStatus"
End Sub
Private Sub DugmeTabelaStatusa_Click()
On Error GoTo Err_DugmeTabelaStatusa_Click

    Dim stDocName As String

    stDocName = "UnosStatusa"
    DoCmd.OpenForm "UnosStatusa"
    
Exit_DugmeTabelaStatusa_Click:
    Exit Sub

Err_DugmeTabelaStatusa_Click:
    MsgBox err.Description
    Resume Exit_DugmeTabelaStatusa_Click
    
End Sub


Private Sub DugmeDetaljnoZahtev_Click()
On Error GoTo Err_DugmeDetaljnoZahtev_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "ZahteviZaNabavku"
    
    stLinkCriteria = "[IDZahtevaZaNabavku]=" & Me![IDZahteviPonude]
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeDetaljnoZahtev_Click:
    Exit Sub

Err_DugmeDetaljnoZahtev_Click:
    MsgBox err.Description
    Resume Exit_DugmeDetaljnoZahtev_Click
    
End Sub
Private Sub DugmeSetaljnoZahtev_Click()
On Error GoTo Err_DugmeSetaljnoZahtev_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "UnosZahtevaZaNabavku"
    
    stLinkCriteria = "[IDZahtevaZaNabavku]=" & Me![IDZahteviPonude]
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeSetaljnoZahtev_Click:
    Exit Sub

Err_DugmeSetaljnoZahtev_Click:
    MsgBox err.Description
    Resume Exit_DugmeSetaljnoZahtev_Click
    
End Sub
Private Sub DugmeRealizacijaZahteva_Click()
On Error GoTo Err_DugmeRealizacijaZahteva_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "SpecifikacijaNabavkeIUpiti"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeRealizacijaZahteva_Click:
    Exit Sub

Err_DugmeRealizacijaZahteva_Click:
    MsgBox err.Description
    Resume Exit_DugmeRealizacijaZahteva_Click
    
End Sub
