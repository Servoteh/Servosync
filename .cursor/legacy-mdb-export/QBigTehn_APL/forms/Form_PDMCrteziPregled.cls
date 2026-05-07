VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PDMCrteziPregled"
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


Public Function PrimeniFilterZaKontrolu()
    SetujFilterZaKontrolu
    PrimeniUslove
End Function


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



Private Sub DugmeGdeSeKoristi_Click()
    
    PregledGdeSeCrtezKoristi Me!IDCrtez, Me!BrojCrteza, Me!Revizija, Me!NazivCrteza
    
End Sub

Private Sub DugmeNacrtPrimopredaje_Click()
    BBOpenForm "NacrtPrimopredaje", , , , acFormAdd, , "Nacrt"
End Sub


Private Sub DugmePreview_Click()
    PreviewPDFCrtez_Binary
End Sub

Private Sub DugmePrint_Click()
    StampajPDFCrtez_Binary
End Sub

Private Sub DugmeSastavnicaDelova_Click()
        Dim IDCrtez As Long
    Dim stSQL As String
    Dim rs As ADODB.Recordset
    Dim BrojCrteza As String
    Dim Revizija As String
    Dim NajRevizija As String
       
    IDCrtez = Me!IDCrtez
    ' 1) Uzmi broj crteža i reviziju iz selektovanog IDCrtez
    stSQL = "SELECT BrojCrteza, Revizija FROM PDMCrtezi WHERE IDCrtez=" & IDCrtez
    Set rs = ADO_GetRST(BBCFG.CNNString, stSQL, adLockReadOnly, adUseClient, adOpenForwardOnly)
    
    If rs.EOF Then
        MsgBox "Nepostojeæi crtež!", vbCritical
        GoTo Exit_Point
    End If
    
    BrojCrteza = rs!BrojCrteza & ""
    Revizija = rs!Revizija & ""
    rs.Close
    Set rs = Nothing
    
    ' 2) Najnovija revizija za taj broj crteža
    stSQL = "SELECT MAX(Revizija) AS NajRev FROM PDMCrtezi WHERE BrojCrteza='" & BrojCrteza & "'"
    Set rs = ADO_GetRST(BBCFG.CNNString, stSQL, adLockReadOnly, adUseClient, adOpenForwardOnly)
    
    If Not rs.EOF Then
        NajRevizija = rs!NajRev & ""
    End If
    rs.Close
    Set rs = Nothing
    
    ' 3) Uporedi
    If Revizija <> NajRevizija Then
        MsgBox "Izabrani crtež NIJE najnovija revizija (trenutna: " & Revizija & _
               ", najnovija: " & NajRevizija & ").", vbExclamation
        GoTo Exit_Point
    End If
    ' --- kraj provere ---
    

    If Me!BrojKomponenti > 0 Then
        PregledPotrebnihKomponentiZaCrtez Me!IDCrtez, Me!BrojCrteza, Me!Revizija, 1, Me!NazivCrteza
        Forms!PotrebneKomponenteZaCrtez.PushStack Me!IDCrtez, Me!BrojCrteza, Me!Revizija, 1, Me!NazivCrteza
        Forms!PotrebneKomponenteZaCrtez.OsveziCaption
    Else
        MsgBox "Ovaj crtež nije sklop", vbInformation, "QMegaTehn"
    End If

Exit_Point:

End Sub

Private Sub DugmeSastavnicaGotoveRobe_Click()
    Dim IDCrtez As Long
    Dim stSQL As String
    Dim rs As ADODB.Recordset
    Dim BrojCrteza As String
    Dim Revizija As String
    Dim NajRevizija As String
       
    IDCrtez = Me!IDCrtez
    ' 1) Uzmi broj crteža i reviziju iz selektovanog IDCrtez
    stSQL = "SELECT BrojCrteza, Revizija FROM PDMCrtezi WHERE IDCrtez=" & IDCrtez
    Set rs = ADO_GetRST(BBCFG.CNNString, stSQL, adLockReadOnly, adUseClient, adOpenForwardOnly)
    
    If rs.EOF Then
        MsgBox "Nepostojeæi crtež!", vbCritical
        GoTo Exit_Point
    End If
    
    BrojCrteza = rs!BrojCrteza & ""
    Revizija = rs!Revizija & ""
    rs.Close
    Set rs = Nothing
    
    ' 2) Najnovija revizija za taj broj crteža
    stSQL = "SELECT MAX(Revizija) AS NajRev FROM PDMCrtezi WHERE BrojCrteza='" & BrojCrteza & "'"
    Set rs = ADO_GetRST(BBCFG.CNNString, stSQL, adLockReadOnly, adUseClient, adOpenForwardOnly)
    
    If Not rs.EOF Then
        NajRevizija = rs!NajRev & ""
    End If
    rs.Close
    Set rs = Nothing
    
    ' 3) Uporedi
    If Revizija <> NajRevizija Then
        MsgBox "Izabrani crtež NIJE najnovija revizija (trenutna: " & Revizija & _
               ", najnovija: " & NajRevizija & ").", vbExclamation
        GoTo Exit_Point
    End If
    ' --- kraj provere ---
    

    If Me!BrojKomponenti > 0 Then
        NapuniTmpPDMKataloske Me!IDCrtez, True
        PregledPotrebnihGotovihDelovaZaCrtez Me!IDCrtez, Me!BrojCrteza, Me!Revizija, 1, Me!NazivCrteza
        Forms!PotrebniGotoviDeloviZaCrtez.PushStack Me!IDCrtez, Me!BrojCrteza, Me!Revizija, 1, Me!NazivCrteza
        Forms!PotrebniGotoviDeloviZaCrtez.OsveziCaption
    Else
        MsgBox "Ovaj crtež nije sklop", vbInformation, "QMegaTehn"
    End If
Exit_Point:

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
    'Me!ZaStatusCrteza = 0
    Me!ZaProizvodnju = 0
    Me!CheckPostojiPDF = Null
End Sub



Private Sub DugmePrviSlog_Click()
    Me.Recordset.MoveFirst
End Sub
Private Sub DugmePrethodniSlog_Click()
    With Me.Recordset
        If Not .BOF Then .MovePrevious
        If .BOF Then .MoveFirst
    End With
End Sub
Private Sub DugmeSledeciSlog_Click()
    With Me.Recordset
        If Not .EOF Then .MoveNext
        If .EOF Then .MoveLast
   '     Me!PodFrmA.Form.PrikaziCrtezIReference
   End With
End Sub
Private Sub DugmePoslednjiSlog_Click()
    Me.Recordset.MoveLast
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
    tabCtlZaPregledCrteza_Change
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
Private Sub tabCtlZaPregledCrteza_Change()
    If Me!tabCtlZaPregledCrteza.Pages(Me!tabCtlZaPregledCrteza.Value).Name = "PagePrimopredaja" Then
        'Select Case BrojOtvorenihZaglavljaNacrta()
        'Case 0
        '    BBOpenForm "NacrtPrimopredaje", , , , acFormAdd, , "Nacrt"
        'Case Else
            Me!tabCtlPodform1.SourceObject = "SpremiNacrtPrimopredaje"
        'End Select
    ElseIf Me!tabCtlZaPregledCrteza.Pages(Me!tabCtlZaPregledCrteza.Value).Name = "PageNabavka" Then
        Me!tabCtlPodform2.SourceObject = "SpremiPlaniranjeNabavke"
    Else
     Me!tabCtlPodform1.SourceObject = "ReklamniPanelPregled"
    End If
End Sub
