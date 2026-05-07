VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_ReklamniPanel_LogIn"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Public Function PrimeniUslove()
    Me!TehnPregled.Form.PrimeniUslove
End Function
Private Function PostaviFokusNaPrijavu()
    Dim WshShell As Object
    Set WshShell = CreateObject("WScript.Shell")

    DoCmd.GoToControl "UnetiPassword"
    WshShell.SendKeys "%K"
    'SendKeys "%B"
    
End Function
Private Sub DugmeClipBoard_Click()
    Me!UnetiPassword = GetClipboard
    UnetiPassword_AfterUpdate
End Sub


Private Sub DugmePregledPostupaka_Click()
On Error GoTo Err_DugmeVPregledDokumenata_Click

    Dim stDocName As String
    Dim stLinkCriteria As String
    
    KorisnikAplikacije = 0
    
    Me!ZavrsiNalogDrugogRadnika = False
    ZavrsiNalogDrugogRadnika_AfterUpdate
    
    Me!OtvoriNoviNalogBezuslovno = False
    OtvoriNoviNalogBezuslovno_AfterUpdate
    
    If Nz(Me!PregledView, False) = True Then
        Me!PregledView = False
        PregledView_AfterUpdate
    End If
    
    stDocName = "UnosPassworda"
    DoCmd.OpenForm stDocName, , , stLinkCriteria
                
    While IsLoaded("UnosPassworda")
         DoEvents
    Wend
    
    If KorisnikAplikacije <> 0 Then
        DoCmd.Close acForm, "ReklamniPanel_Login"
        'stDocName = "PregledPoPostupcima"
        stDocName = "RNPregledZag"
        DoCmd.OpenForm stDocName, , , stLinkCriteria
        'Forms!PregledPoPostupcima!DugmeDetaljnoNalog.Enabled = False
        Forms!RNPregledZag![Dugme - Detalji dokumenta].Enabled = False
    End If
    
Exit_DugmeVPregledDokumenata_Click:
    Exit Sub

Err_DugmeVPregledDokumenata_Click:
    MsgBox err.Description
    Resume Exit_DugmeVPregledDokumenata_Click

End Sub

Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click
   
If CurrentUser() <> "Negovan" Then
    DoCmd.Quit
End If
    DoCmd.Close
    
Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click

End Sub

Private Sub Form_Open(Cancel As Integer)
    DoCmd.Maximize
    'PripremiPanel
    DoCmd.GoToControl "UnetiPassword"
    'PrikaziObjekteZaMene
End Sub


Private Sub PregledView_AfterUpdate()
    If Me!PregledView Then
        Me!TehnPregled.Visible = True
        Me!LabelZaRadnika.Visible = True
        Me!ZaRadnika.Visible = True
    Else
        Me!TehnPregled.Visible = False
        Me!LabelZaRadnika.Visible = False
        Me!ZaRadnika.Visible = False
    End If
    DoCmd.GoToControl "UnetiPassword"
End Sub
Private Sub UnetiPassword_AfterUpdate()
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim UnetiPassword As String
    Dim IDRadnika As Long
    Dim Podatak As Variant
    Dim NoviRadnikSifra As Long
    
    retValOk = True
    Podatak = Nz(Me![UnetiPassword], "")
    
    Me![UnetiPassword] = Null
    
    If Podatak = "Quit" Then
        DoCmd.Quit
    ElseIf Podatak = "Close" Then
        DoCmd.Close
    ElseIf Podatak <> "" Then
        IDRadnika = Nz(ADO_Lookup(CNN_CurrentDataBase, "SifraRadnika", "tRadnici", "IDKartice='" & Podatak & "' AND Aktivan=" & SQLFormatBoolean(True)), -1)
        If IDRadnika = -1 Then
            MsgBox "U bazi NE POSTOJI radnik sa " & Srpski("procitanim") & " brojem kartice!!!", vbInformation, "QBigTehn"
            Me!UnetiPassword = Null
            Me!ZavrsiNalogDrugogRadnika = False
            Me!OtvoriNoviNalogBezuslovno = False
            'PostaviFokusNaPrijavu
            Me!UnetiPassword.SetFocus
            retValOk = False
        Else
            retValOk = SpremiPodatkeZaOtvaranjeFormeBarKod_Unos(IDRadnika, Me!ZavrsiNalogDrugogRadnika, Me!OtvoriNoviNalogBezuslovno)
            If retValOk Then
                OtvoriFormuBarKod_Unos
            Else
                Me!UnetiPassword = Null
                Me!UnetiPassword.SetFocus
            End If
        End If
    Else
        MsgBox "Uneti podatak nije broj kartice radnika!", vbInformation, "QBigTehn"
        Me!UnetiPassword = Null
        Me!UnetiPassword.SetFocus
        retValOk = False
    End If
    
       
Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
    BBErrorMSG err, "UnetiPassword_AfterUpdate"
    Resume Exit_Point
End Sub

Private Sub ZaRadnika_AfterUpdate()
    PrimeniUslove
    DoCmd.GoToControl "UnetiPassword"
End Sub

Private Sub ZaRadnika_DblClick(Cancel As Integer)
    Me!ZaRadnika = Null
    PrimeniUslove
    'DoCmd.GoToControl "UnetiPassword"
    PostaviFokusNaPrijavu
End Sub

Private Sub ZavrsiNalogDrugogRadnika_AfterUpdate()
    ZavrsiNalogDrugogRadnikaAfterUpdate
End Sub
Private Sub OtvoriNoviNalogBezuslovno_AfterUpdate()
    OtvoriNoviNalogBezuslovnoAfterUpdate
End Sub

Private Sub ZavrsiNalogDrugogRadnika_Click()
    If Me!OtvoriNoviNalogBezuslovno Then
        If Me!ZavrsiNalogDrugogRadnika Then
           MsgBox "Ne možete da zahtevate da zatvorite nalog nekog radnika, " & vbCrLf & "ako ste " & Srpski("oznacili") & " da koristite alat za rad sa više naloga!", vbCritical, "QBigTehn"
           Me!ZavrsiNalogDrugogRadnika = False
           ZavrsiNalogDrugogRadnika_AfterUpdate
        End If
    End If
End Sub
Private Sub OtvoriNoviNalogBezuslovno_Click()
    If Me!ZavrsiNalogDrugogRadnika Then
        If Me!OtvoriNoviNalogBezuslovno Then
           MsgBox "Ne možete da zahtevate da koristite alat za rad sa više naloga, " & vbCrLf & "ako ste " & Srpski("oznacili") & " da zatvorite nalog nekog radnika!", vbCritical, "QBigTehn"
           Me!OtvoriNoviNalogBezuslovno = False
           OtvoriNoviNalogBezuslovno_AfterUpdate
        End If
    End If
End Sub
Public Function ZavrsiNalogDrugogRadnikaAfterUpdate() As Boolean
    If Me!ZavrsiNalogDrugogRadnika Then
        Me!ZavrsiNalogDrugogRadnika.ForeColor = 2366701
    Else
        Me!ZavrsiNalogDrugogRadnika.ForeColor = 8280378
    End If
    DoCmd.GoToControl "UnetiPassword"
End Function
Public Function OtvoriNoviNalogBezuslovnoAfterUpdate() As Boolean
    If Me!OtvoriNoviNalogBezuslovno Then
        Me!OtvoriNoviNalogBezuslovno.ForeColor = 2366701
    Else
        Me!OtvoriNoviNalogBezuslovno.ForeColor = 8280378
    End If
    DoCmd.GoToControl "UnetiPassword"
End Function

Public Sub PrikaziObjekteZaMene()
    If UserUGrupi(CurrentUser(), "Admins") Then
        Me!DugmeTest.Visible = True
        Me!DugmeClipBoard.Visible = True
    Else
        Me!DugmeTest.Visible = False
        Me!DugmeClipBoard.Visible = False
    End If
End Sub
