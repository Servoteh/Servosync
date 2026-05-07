VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PregledNacrtaPrimopredaje"
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


Private Sub BrojCrteza_DblClick(Cancel As Integer)
    SetujFilterZaKontrolu
    PrimeniUslove
End Sub

Private Sub DugmeDetaljnoCrtez_Click()
On Error GoTo Err_DugmeDetaljnoCrtez_Click

    Dim DocName As String
    Dim LinkCriteria As String
    
    On Error Resume Next
    DetaljnoCrtez Me!IDCrtez
    
Exit_DugmeDetaljnoCrtez_Click:
    Exit Sub

Err_DugmeDetaljnoCrtez_Click:
    MsgBox Error$
    Resume Exit_DugmeDetaljnoCrtez_Click

End Sub

Private Sub DugmeNacrtPrimopredaje_Click()
On Error GoTo Err_Dugme_Detaljno_komit_Click

    Dim DocName As String
    Dim LinkCriteria As String
    Dim IDNacrtPrimopredaje As Long
    Dim IDGlavniCrtez As Long
    
    DocName = "NacrtPrimopredaje"
    IDNacrtPrimopredaje = Nz(Me![IDNacrtPrim], 0)
    If IDNacrtPrimopredaje = 0 Then
        IDGlavniCrtez = Me!IDGlavniCrtez
        IDNacrtPrimopredaje = ADO_Lookup(CNN_CurrentDataBase, "IDNacrtPrim", "NacrtPrimopredajeStavke", _
                                "[IDGlavniCrtez] = " & IDGlavniCrtez & " AND [IsGlavni] = " & SQLFormatBoolean(True))
    End If
    LinkCriteria = "[IDNacrtPrim]=" & IDNacrtPrimopredaje
    DoCmd.OpenForm DocName, , , LinkCriteria

Exit_Dugme_Detaljno_komit_Click:
    Exit Sub

Err_Dugme_Detaljno_komit_Click:
    MsgBox Error$
    Resume Exit_Dugme_Detaljno_komit_Click
   
End Sub

Private Sub DugmePotrebneKomponenteZaCrtez_Click()
    If Me!BrojKomada > 0 Then
        PregledPotrebnihKomponentiZaCrtez Me!IDCrtez, Me!BrojCrteza, Me!Revizija, 1, Me!Naziv
    Else
        MsgBox "Ovaj crtež nije sklop", vbInformation, "QMegaTehn"
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


Private Sub Form_Open(Cancel As Integer)
    PrikaziAPPRev
    PostaviStatusnuLiniju
    Me!PrikaziSveStavke = False
    Me!ZaBrojCrteza.Enabled = False
    '****************************
    If Nz(Me.OpenArgs, "") = "Nacrt" Then
       Me!ZaStatusNacrtaPrimopredaje = 0
       OvoJePregledKreiranihNacrta
    Else
       Me!ZaStatusNacrtaPrimopredaje = 1
       OvoJePregledPredatihNacrta
    End If
    '*****************************
    Me!ZaStatusNacrtaPrimopredaje.Locked = True
    Me!ZaStatusNacrtaPrimopredaje.Enabled = False
End Sub


Private Sub PrikaziAPPRev()
  'Me!BBAppRev.Caption = F_APPRev()
  Me!TrenutniUser = CurrentUser() & " (" & Environ("UserName") & ")"
  'Me!LabelWinUser.Caption = Environ("UserName")
End Sub
Private Sub PostaviStatusnuLiniju()
    'Me!NazivAktivneKT = CCKZaSve.NazivAktivneKT
   ' Me!AktivanKorisnik = CurrentUser()
End Sub
Public Function PrimeniUslove()
On Error GoTo Err_Point

    SetProperlyRecordSource BBCFG.CNNString, Me
    PrimeniColorKeyZaBojuPozadine Me

Exit_Point:
On Error Resume Next

Exit Function
Err_Point:
 BBErrorMSG err, "PrimeniUslove"
 Resume Exit_Point:
End Function


Private Sub Form_Load()
    PrimeniUslove
End Sub
Private Sub Form_Unload(Cancel As Integer)
    CloseConnectionOnCurrentForm Me
End Sub

Private Sub PrikaziSveStavke_AfterUpdate()
    Me!ZaBrojCrteza.Enabled = Me!PrikaziSveStavke
    PrimeniUslove
End Sub

Private Sub ZaIDProjektant_GotFocus()
    Me!ZaIDProjektant.Requery
End Sub

Private Sub ZaRadniNalog_GotFocus()
    Me!ZaRadniNalog.Requery
End Sub
Private Sub OvoJePregledKreiranihNacrta()
On Error GoTo Err_Point

        Me!lblNazivForme.Caption = "Crteži spremni za primopredaju"
        Me.Caption = "Kreirani nacrti primporedaje"
    
        
        'Me!DugmeFiskalniRacun.Enabled = False
        'Me!DugmePrebaciNaProf.Enabled = False
        
        'Me!TabCtlZaIF.Pages("Profaktura").Visible = True
        
Exit_Point:
On Error Resume Next

Exit Sub

Err_Point:
   MsgBox err.Description
   Resume Next
End Sub

Private Sub OvoJePregledPredatihNacrta()
On Error GoTo Err_Point

        Me!lblNazivForme.Caption = "Crteži predati u primopredaji"
        Me.Caption = "Predati crteži"
    
        
        'Me!DugmeFiskalniRacun.Enabled = False
        'Me!DugmePrebaciNaProf.Enabled = False
        
        'Me!TabCtlZaIF.Pages("Profaktura").Visible = True
        
Exit_Point:
On Error Resume Next

Exit Sub

Err_Point:
   MsgBox err.Description
   Resume Next
End Sub
