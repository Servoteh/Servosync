VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_UnosRN"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit
Dim pImePodforme As String
Private Function StatusEditDugmeta() As Boolean
  StatusEditDugmeta = (Nz(Me!DugmeEdit, False))
End Function
Private Function PodesiPrikazForme()
On Error GoTo Err_Point
    
    If IsLoaded("PregledPoPredmetima") Then
        Me!DugmeObrisiNalog.Enabled = False
    Else
        Me!DugmeObrisiNalog.Enabled = True
    End If
        
Exit_Point:
On Error Resume Next

Exit Function

Err_Point:
    BBErrorMSG err, "PodesiPrikazForme"
    Resume Next
End Function
Private Function STDWhere() As String
Dim stWhere As String
 stWhere = "([tRN].IDStatusPrimopredaje=F_RN_IDStatusDefLansiran())"
 STDWhere = stWhere
End Function
Private Function PrviIDRN() As Long
On Error GoTo Err_Point
 Dim retVal
 retVal = DMin("[IDRN]", "tRN", STDWhere())
 retVal = CLng(Nz(retVal, 0))
 
Exit_Point:
 On Error Resume Next
 PrviIDRN = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "PrviIDRN"
 retVal = 0
 Resume Exit_Point
End Function
Private Function PoslednjiIDRN() As Long
On Error GoTo Err_Point
 Dim retVal
 Dim stWhere As String
 'stWHERE = "[Ulaz] = False AND [Level] <= " & F_NivoBaze() & " AND [IDFirma] = " & F_IDFirma() & " AND [Godina] = " & F_Godina()
 'stWhere = "((([T_Robna dokumenta].Ulaz)=No) AND (([T_Robna dokumenta].Level) Between [Forms]![IF]![OdLevel] And [Forms]![IF]![OdLevel]) AND (([T_Robna dokumenta].IDFirma)=F_IDFirma()) AND (([T_Robna dokumenta].Godina)=F_Godina()))"
 stWhere = STDWhere()
 retVal = DMax("[IDRN]", "tRN", stWhere)
 retVal = CLng(Nz(retVal, 0))
 
Exit_Point:
 On Error Resume Next
 PoslednjiIDRN = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "PoslednjiIDRN"
 retVal = 0
 Resume Exit_Point
End Function
Private Function PrethodniIDRN() As Long
On Error GoTo Err_Point
 Dim retVal
 Dim stWhere As String
 
 stWhere = STDWhere() & " AND [IDRN]<" & Me!IDRNZaPrikaz
 If Not IsNumeric(Me!IDRNZaPrikaz) Or IsEmpty(Me!IDRNZaPrikaz) Then
  retVal = PoslednjiIDRN
 Else
  retVal = DMax("[IDRN]", "tRN", stWhere)
  retVal = CLng(Nz(retVal, 0))
 End If
 
 If retVal = 0 Then
    retVal = PrviIDRN()
 End If

Exit_Point:
 On Error Resume Next
 PrethodniIDRN = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "PrethodniIDRN"
 retVal = 0
 Resume Exit_Point
End Function
Private Function SledeciIDRN() As Long
On Error GoTo Err_Point
 
Dim retVal
If Not IsNumeric(Me!IDRNZaPrikaz) Or IsEmpty(Me!IDRNZaPrikaz) Then
  retVal = PoslednjiIDRN
 Else
  retVal = DMin("[IDRN]", "tRN", STDWhere() & " AND [IDRN]>" & Me!IDRNZaPrikaz)
  retVal = CLng(Nz(retVal, 0))
 End If
 
 If retVal = 0 Then
    retVal = PoslednjiIDRN()
 End If
 
Exit_Point:
 On Error Resume Next
 SledeciIDRN = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "SledeciIDRN"
 retVal = 0
 Resume Exit_Point
End Function

Public Function PrikaziRNIStavke(Optional parIDRN)
'Modifikovano: 19-01-2020
On Error GoTo Err_PrikaziRNIStavke
Dim pIDRNZaPrikaz As Long
 
 If Not IsMissing(parIDRN) Then
    pIDRNZaPrikaz = parIDRN
 Else
    pIDRNZaPrikaz = Me!IDRNZaPrikaz
 End If
 
 Call PrikaziRN(pIDRNZaPrikaz)
 Call PrikaziStavke(pIDRNZaPrikaz)       ', "IF_Stavke_Pregled")
 'Me!DugmeEdit = False
 
Exit_PrikaziRNIStavke:
    Exit Function

Err_PrikaziRNIStavke:
    MsgBox err.Description
    Resume Exit_PrikaziRNIStavke
    
End Function
Private Function PrikaziRN(Optional parIDRN)
On Error GoTo Err_Point

 Dim pIDRNZaPrikaz As Long
 Dim retValOk As Boolean
 
 retValOk = True
 
 If Not IsMissing(parIDRN) Then
    pIDRNZaPrikaz = parIDRN
 Else
    pIDRNZaPrikaz = Me!IDRNZaPrikaz
 End If
    
    RNP.IDRN = pIDRNZaPrikaz
    'RNP.CheckPiP = Me!CheckPiP
    Me!IDRNZaPrikaz = RNP.IDRN()
    
    If StatusEditDugmeta() Then
        retValOk = PostaviEditabilanRSource(pIDRNZaPrikaz)
        Me![Podforma].SourceObject = "UnosStavkiRN"
        Me!Podforma.LinkMasterFields = "IDRN"
        Me!Podforma.LinkChildFields = "IDRN"
    Else
        retValOk = SetProperlyRecordSource(BBCFG.CNNString, Me)
        Me![Podforma].SourceObject = "PregledStavkiRN"
        'Me!Stavke.LinkMasterFields = "IDRN"
        'Me!Stavke.LinkChildFields = "IDRN"
    End If
    PodesiDugmeEdit
    
Exit_Point:
On Error Resume Next
   PrikaziRN = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "PrikaziRN"
 retValOk = False
 Resume Exit_Point
End Function
Private Function PrikaziStavke(Optional parIDRN, Optional parDocPodforma) As Boolean
'Modifikovano: 19-01-2020
On Error GoTo Err_Point

Dim pIDRNZaPrikaz As Long
Dim stDocPodforma As String
Dim retValOk As Boolean
 
 retValOk = True
 
 If Not IsMissing(parIDRN) Then
    pIDRNZaPrikaz = parIDRN
 Else
    pIDRNZaPrikaz = Nz(Me!IDRNZaPrikaz, 0)
 End If
    
 If Not IsMissing(parDocPodforma) Then
   stDocPodforma = parDocPodforma
 Else
   If StatusEditDugmeta() Then
        stDocPodforma = "UnosStavkiRN" 'Me![Podforma].SourceObject
   Else
        stDocPodforma = "PregledStavkiRN" 'Me![Podforma].SourceObject
   End If
 End If

 
 Me![Podforma].SourceObject = stDocPodforma
 
 
Exit_Point:
On Error Resume Next
   PrikaziStavke = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "PrikaziStavke"
 retValOk = False
 Resume Exit_Point
End Function
Private Function PostaviEditabilanRSource(IDRNZaEdit As Long) As Boolean
On Error GoTo Err_Point
Dim stSQLEditOn As String
Dim retValOk As Boolean
        
      retValOk = True
      stSQLEditOn = "SELECT * FROM [tRN]"
      stSQLEditOn = stSQLEditOn & " WHERE (IDRN = " & IDRNZaEdit & ");"
      
      Set Me.Recordset = ADO_GetRST(BBCFG.CNNString, stSQLEditOn)
      
Exit_Point:
On Error Resume Next
 
 PostaviEditabilanRSource = retValOk

Exit Function

Err_Point:
  BBErrorMSG err, "PostaviEditabilanRSource"
  retValOk = False
  Resume Exit_Point
End Function
Private Function PostaviKomboPolja()
On Error GoTo Err_Point
 
 
 Set Me!ComboNazivDela.Recordset = RST_Combo(CNN_CurrentDataBase, "VrednostiZaKombo", "[Kolona]='NazivDela'", "Vrednost", "Vrednost")
 
 Set Me!ComboMaterijal.Recordset = RST_Combo(CNN_CurrentDataBase, "VrednostiZaKombo", "[Kolona]='Materijal'", "Vrednost", "Vrednost")
 
 Set Me!ComboDimenzijaMaterijala.Recordset = RST_Combo(CNN_CurrentDataBase, "VrednostiZaKombo", "[Kolona]='DimenzijaMaterijala'", "Vrednost", "Vrednost")
 
 'Set Me!ComboVezaSaBrojemCrteza.Recordset = RST_Combo(CNN_CurrentDataBase, "VrednostiZaKombo", "[Kolona]='KS'", "Vrednost", "Vrednost")

Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "PostaviKomboPolja"
 Resume Exit_Point
End Function
Public Function OsveziComboNazivDela()
     Set Me!ComboNazivDela.Recordset = RST_Combo(CNN_CurrentDataBase, "VrednostiZaKombo", "[Kolona]='NazivDela'", "Vrednost", "Vrednost")
End Function
Public Function OsveziComboMaterijal()
     Set Me!ComboMaterijal.Recordset = RST_Combo(CNN_CurrentDataBase, "VrednostiZaKombo", "[Kolona]='Materijal'", "Vrednost", "Vrednost")
End Function
Public Function OsveziComboDimenzijaMaterijala()
     Set Me!ComboDimenzijaMaterijala.Recordset = RST_Combo(CNN_CurrentDataBase, "VrednostiZaKombo", "[Kolona]='DimenzijaMaterijala'", "Vrednost", "Vrednost")
End Function

Private Function EditUkljuciIskljuci(chkEdit As Boolean, Optional SourceObject As String)
On Error GoTo Err_Point

    Dim stSQLEditOn As String
    Dim IDRNZaEdit As Long
    
    On Error Resume Next
    IDRNZaEdit = Me!IDRN
    
    If err Then
     err.Clear
     IDRNZaEdit = 0
    End If
    
     If chkEdit Then
        If PostaviEditabilanRSource(IDRNZaEdit) Then
          Me![Podforma].SourceObject = "UnosStavkiRN"
                    
          Me!Stavke.LinkMasterFields = "IDRN"
          Me!Stavke.LinkChildFields = "IDRN"
        Else
          'NE ZNAM STA OVDE!
        End If
     Else
          
      PrikaziRNIStavke IDRNZaEdit
      
     End If
     
   PodesiPrikazForme
   
Exit Function
    
Exit_Point:
    Exit Function

Err_Point:
    BBErrorMSG err, "EditUkljuciIskljuci"
    Resume Exit_Point
End Function
Private Sub PodesiDugmeEdit()
    With Me.DugmeEdit
        If .Value = True Then
            .Caption = "Edit mod " & Srpski("ukljucen")
            .BackColor = RGB(200, 255, 200)  ' svetlo zelena
            .ForeColor = RGB(0, 80, 0)       ' tamnozelena slova
        Else
            .Caption = "Edit mod " & Srpski("iskljucen")
            .BackColor = RGB(255, 200, 200)  ' svetlo crvena
            .ForeColor = RGB(120, 0, 0)      ' tamnocrvena slova
        End If
    End With
End Sub

Private Sub Dugme___Stop_Click()
On Error GoTo Err_Dugme___Stop_Click


    DoCmd.Close

Exit_Dugme___Stop_Click:
    Exit Sub

Err_Dugme___Stop_Click:
    MsgBox Error$
    Resume Exit_Dugme___Stop_Click
    
End Sub
Private Sub Dugme_Ponisti_unos_Click()
On Error GoTo Err_Dugme_Ponisti_unos_Click


    DoCmd.DoMenuItem A_FORMBAR, A_EDITMENU, A_UNDOFIELD, , A_MENU_VER20

Exit_Dugme_Ponisti_unos_Click:
    Exit Sub

Err_Dugme_Ponisti_unos_Click:
    MsgBox Error$
    Resume Exit_Dugme_Ponisti_unos_Click
    
End Sub

Private Sub Dugme_Printuj_kalkul_Click()
On Error GoTo Err_Dugme_Printuj_kalkul_Click

    Dim stDocName As String
    Dim ID As Long
    
    Select Case Me!TabCtlRN
    Case 0
        'ID = Nz(DLookup("ID", "tStavkeRN_BrOperacija"), 0)
        'If ID <> 0 Then
            stDocName = "rRN"
        'Else
        '    stDocName = "rRN_BezBarKoda"
        'End If
    Case 1
        stDocName = "rRN_tPND"
    Case 2
        stDocName = "rRN_tPDM"
    Case 3
        stDocName = "rRN_tPLP"
    Case 4
        stDocName = "rRN_tKomponente"
    Case 5
        stDocName = "rRN_tNDKomponente"
    End Select
    
    DoCmd.OpenReport stDocName, A_PREVIEW

Exit_Dugme_Printuj_kalkul_Click:
    Exit Sub

Err_Dugme_Printuj_kalkul_Click:
    If err.Number <> 2501 Then MsgBox Error$
    Resume Exit_Dugme_Printuj_kalkul_Click
    
End Sub

Private Sub DugmeDetaljnoKomitenta_Click()
On Error GoTo Err_Dugme_Detaljno_komit_Click

    Dim DocName As String
    Dim LinkCriteria As String

    DocName = "Unos komitenata"
    LinkCriteria = "[Sifra] = " & Me![Sifra komitenta - lista]
    DoCmd.OpenForm DocName, , , LinkCriteria

Exit_Dugme_Detaljno_komit_Click:
    Exit Sub

Err_Dugme_Detaljno_komit_Click:
    MsgBox Error$
    Resume Exit_Dugme_Detaljno_komit_Click

End Sub


Private Sub DugmeEdit_AfterUpdate()
    EditUkljuciIskljuci Me!DugmeEdit
    ProveriZakljucavanje
End Sub

Private Sub DugmeEdit_Click()
    PodesiDugmeEdit
End Sub

Private Sub DugmeEdit_GotFocus()
    Me.AllowEdits = True
End Sub

Private Sub DugmeEdit_LostFocus()
    ProveriZakljucavanje
End Sub

Private Sub DugmeLansiraj_Click()
On Error GoTo Err_DugmeSaglasan_Click


    DugmeRNLansiran

Exit_DugmeSaglasan_Click:
    Exit Sub

Err_DugmeSaglasan_Click:
    MsgBox err.Description
    Resume Exit_DugmeSaglasan_Click

End Sub
Private Sub DugmeLokacijaNapravljenihDelova_Click()
    'DefinisiLokacijuDelova 0, Me!Komada, False, False, "LokacijaSvihNapravljenihDelovaPoRN", Me!IDRN
    OtvoriFormuZaLokacijuDelova Me!IDPredmet, Me!Komada, False, False, IDRadnikZaCurrentUser(), Me!IDRN, "LokacijaSvihNapravljenihDelovaPoRN"
End Sub

Private Sub DugmeMyRequery_Click()
On Error GoTo Err_DugmeMyRequery_Click


    PrikaziRNIStavke
    PostaviKomboPolja

Exit_DugmeMyRequery_Click:
    Exit Sub

Err_DugmeMyRequery_Click:
    MsgBox err.Description
    Resume Exit_DugmeMyRequery_Click
    
End Sub

Private Sub DugmeNoviDokumenat_Click()
On Error GoTo Err_DugmeNoviDok_Click
    
    'Me.UniqueTable = "tRN"
    'Me!ComboIDKomitent.ControlSource = ""
    'UnBoundAllControls
    'Me.RecordSource = "SELECT * FROM [tRN]"
    Dim rs As ADODB.Recordset
    Dim stSQLEditOn As String
    
    stSQLEditOn = "SELECT * FROM [tRN]"
    stSQLEditOn = stSQLEditOn & " WHERE (IDRN > " & PoslednjiIDRN & ")"
      
    'Set Me.Recordset = ADO_GetRST(BBCFG.CNNString,"SELECT * FROM [T_Robna dokumenta] WHERE IDDok>" & PoslednjiIDDok)
    Set Me.Recordset = ADO_GetRST(BBCFG.CNNString, stSQLEditOn)
    Me!DugmeEdit.Caption = "Edit mod ukljuèen"
    Me!DugmeEdit = True
    Me!DugmeEdit.BackColor = RGB(200, 255, 200)  ' svetlo zelena
    Me!DugmeEdit.ForeColor = RGB(0, 80, 0)
            
    Me![Podforma].SourceObject = "UnosStavkiRN"
    
    '***************************************************
    DoCmd.GoToRecord , , AcRecord.acNewRec ' 29-01-2022
    Me!Podforma.LinkMasterFields = "IDRN"
    Me!Podforma.LinkChildFields = "IDRN"
    ' 29-01-2022 DoCmd.GoToRecord , , AcRecord.acNewRec
    '***************************************************
    
    Me!IDPredmet.SetFocus
    
Exit_DugmeNoviDok_Click:
On Error Resume Next
' Set rs = Nothing
    Exit Sub

Err_DugmeNoviDok_Click:
    MsgBox Error$
    Resume Exit_DugmeNoviDok_Click
    
End Sub
Private Sub DugmeNoviDokumenat_MislimDaJeLOSE_Click()
On Error GoTo Err_DugmeNoviDok_Click

    ' 1) Ukljuèi Edit mod (UI only)
    Me!DugmeEdit.Value = True
    
    Me!DugmeEdit.Caption = "Edit mod ukljuèen"
    Me!DugmeEdit.BackColor = RGB(200, 255, 200)  ' svetlo zelena
    Me!DugmeEdit.ForeColor = RGB(0, 80, 0)

    ' 2) Preði na PRAVI novi record (Access kreira autonumber automatski)
    DoCmd.GoToRecord , , acNewRec

    ' 3) Postavi subformu za UNOS (uvek isto za novi RN)
    With Me!Podforma
        .SourceObject = "UnosStavkiRN"
        .LinkMasterFields = "IDRN"
        .LinkChildFields = "IDRN"
    End With

    ' 4) Fokus na prvo polje
    Me!IDPredmet.SetFocus

Exit_DugmeNoviDok_Click:
    Exit Sub

Err_DugmeNoviDok_Click:
    BBErrorMSG err, "DugmeNoviDokumenat_Click"
    Resume Exit_DugmeNoviDok_Click
End Sub

Private Sub DugmeObrisiNalog_Click()
On Error GoTo Err_DugmeObrisiNalog_Click

    Dim stDocName As String
    Dim answer As Variant
    Dim retValOk As Boolean
    retValOk = True
    Dim pZakljucano As Boolean
    
    retValOk = True
    
    pZakljucano = Nz(ADO_Lookup(CNN_CurrentDataBase, "Zakljucano", "tRN", "[IDRN]=" & Me!IDRN), False)
    If pZakljucano Then
        MsgBox "Nalog je " & Srpski("zakljucan")
        Exit Sub
    End If
    
    If NalogPostojiUTehPostupku(CLng(Me!IDRN)) Then
        MsgBox "Po ovom nalogu je " & Srpski("zapoceta") & " proizvodnja i ne " & Srpski("moze") & " se brisati!", vbExclamation, "QBigTehn"
        Exit Sub
    End If
    
    answer = MsgBox("Ovim brišete kompletni postupak!!!" & Chr(13) & " Da li nastavljate BRISANJE?", vbYesNo + vbCritical + vbDefaultButton2, "Brisanje radnog naloga")
    If answer = vbYes Then
        
        'retValOk = retValOk And ZaIDRNDeletetPDM(Me!IDRN)
        'retValOk = retValOk And ZaIDRNDeletetPLP(Me!IDRN)
        'retValOk = retValOk And ZaIDRNDeletetPND(Me!IDRN)
        'retValOk = retValOk And ZaIDRNDeletetStavkeRN(Me!IDRN)
        'retValOk = retValOk And ZaIDRNDeletetRN(Me!IDRN)
        
        retValOk = ADO_ExecSP(BBCFG.CNNString, "spObrisiKompletanNalog", Me!IDRN)
        If retValOk Then
            PrikaziRNIStavke PoslednjiIDRN()
        End If
        
    End If
    
Exit_DugmeObrisiNalog_Click:
    Exit Sub

Err_DugmeObrisiNalog_Click:
    MsgBox err.Description
    Resume Exit_DugmeObrisiNalog_Click

End Sub



Private Sub DugmePrebaciUClipboard_Click()
    SetClipboard Me!txtBarKod
End Sub

Private Sub Form_Activate()
'    DoCmd.Maximize
End Sub

Private Sub Form_AfterInsert()
    Me!IDRNZaPrikaz = Me!IDRN
    RNP.IDRN = Me!IDRN
    'PrikaziRNIStavke
End Sub

Private Sub Form_AfterUpdate()
    Me!IDRNZaPrikaz = Me!IDRN
    RNP.IDRN = Me!IDRN
    
    'Call RNP.SetDataFromForm(Me.Name)
    
    ProveriZakljucavanje  'Modifikovano: 03-02-2020
    
End Sub


Private Sub Form_BeforeUpdate(Cancel As Integer)
    
    'If Not ZatvoriSveOtvoreneForme() Then
    '    'retValOk = False
    '    DoCmd.CancelEvent
    '    'Exit Sub
    '    DoCmd.RunCommand acCmdUndo
    'Else
        
    'End If
    Dim Opis As String
    
    If PostojiDupliIdentBroj(CNN_CurrentDataBase, _
                             Me!IDPredmet, _
                             Me!BrojCrteza, _
                             Me!Varijanta, _
                             Me!Revizija, _
                             Me!IdentBroj, _
                             Nz(Me!IDRN, 0), _
                             Opis) Then
        MsgBox Opis, vbExclamation, "Dupli broj radnog naloga"
        Cancel = True
        Exit Sub
    Else
        Me!DIVIspravkeRN = Now()
        'If Nz(Me!PrnTimer, 0) = 0 Then
        '    Me!PrnTimer = CLng(Timer)
        'End If
    End If

End Sub
Private Sub Form_Current()
On Error GoTo Err_Point

    '*************************
    RNP.IDRN = Me!IDRN
    
    ProveriZakljucavanje
    PodesiPrikazVrstaKvaliteta
    'PrikaziRNIStavke

Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "Form_Current"
 Resume Exit_Point
End Sub
Private Sub Form_Error(DataErr As Integer, Response As Integer)
'Static BrojPokusaja As Long
Dim odgovor

  '''''''''  MsgBox "Form_Error" & DataErr
  '  If IsEmpty(BrojPokusaja) Then
  '      BrojPokusaja = 1
  '  Else
  '      BrojPokusaja = BrojPokusaja + 1
  '  End If
    
    If DataErr = 3022 Then
        odgovor = MsgBox("Broj otpremnice je zauzet!" & vbCr & "Dodeliti novi broj?", vbCritical + vbYesNo, "QMegaTeh")
        If odgovor = vbYes Then
           
           Response = vbCancel 'acDataErrContinue
           SendKeys "%S"
        Else
            Response = vbCancel
        End If
   ' Else
   '     MsgBox Error$
   '     'Response = vbCancel
    End If
End Sub

Private Sub ProveriZakljucavanje()
    Dim userReadOnly As Boolean
    userReadOnly = IsReadOnlyUser()
    
    Application.Echo False
    If Nz(Me!Zakljucano, False) Or Not StatusEditDugmeta() Then
        Me.FormHeader1.BackColor = BBCFG.ColorLock
        Me.Detail0.BackColor = BBCFG.ColorLock
        Me.AllowEdits = False
        Me.AllowDeletions = False
        Me!DugmeObrisiNalog.Enabled = False
        Me!DugmeKopirajPostupke.Enabled = False
        'Me!DugmeKreirajIstiPostupak.Enabled = False
    ElseIf userReadOnly Then
        Me.FormHeader1.BackColor = BBCFG.ColorUnLock
        Me.Detail0.BackColor = BBCFG.ColorUnLock
        Me.AllowEdits = False
        Me.AllowAdditions = False
        Me.AllowDeletions = False
        Me![Dugme -Novi dokumenat].Enabled = False
        Me!DugmeKopirajPostupke.Enabled = False
        Me!DugmeKreirajIstiPostupak.Enabled = False
    Else
        Me.FormHeader1.BackColor = BBCFG.ColorUnLock
        Me.Detail0.BackColor = BBCFG.ColorUnLock
        Me.AllowEdits = True
        Me.AllowDeletions = True
        Me!DugmeObrisiNalog.Enabled = True
        Me!DugmeKopirajPostupke.Enabled = True
        Me!DugmeKreirajIstiPostupak.Enabled = True
    End If
      
    
    Application.Echo True
End Sub


Private Sub Form_Open(Cancel As Integer)
On Error GoTo Err_Point

Dim stFilter As String
    '16-01-2021
    pImePodforme = "PregledStavkiRN"
    
    If Nz(Me.OpenArgs, "") = "CallerMenu" Then
       RNP.Caller = "QPrvaMaska"
    End If
    
    If Me.FilterOn Then
        stFilter = Nz(Me.Filter)
        stFilter = Replace(stFilter, " ", "")
        stFilter = Replace(stFilter, "[IDRN]=", "")
        If IsNumeric(stFilter) Then
            Me!IDRNZaPrikaz = CLng(stFilter)
        Else
            Me!IDRNZaPrikaz = PoslednjiIDRN
        End If
    Else
        If RNP.Caller = "DetaljnoDokument" Then
            Me!IDRNZaPrikaz = RNP.IDRN
        Else
            Me!IDRNZaPrikaz = PoslednjiIDRN()
        End If
    End If
     
    PrikaziRN Me!IDRNZaPrikaz
    PrikaziStavke Me!IDRNZaPrikaz
    
    PodesiPrikazForme
    
    PostaviKomboPolja
    
    ProveriInboxPlanera
    While IsLoaded("PlanerPopUp")
        DoEvents
    Wend
    
    DoCmd.GoToControl "RNDokumentaTrazi"
    
    PrikaziObjekteZaMene
 Exit Sub
Err_Point:
  BBErrorMSG err, "Form_Open"
  Resume Next
End Sub

Private Sub Form_Unload(Cancel As Integer)
    CloseConnectionOnCurrentForm Me
End Sub

Private Sub IdentBroj_BeforeUpdate(Cancel As Integer)
    If InStr(1, Me!IdentBroj, ":", vbTextCompare) <> 0 Then
        MsgBox "U ovom broju ne sme da  se nalazi dvotacka tj :   !!!"
        DoCmd.CancelEvent
    End If
End Sub

Private Sub IDPredmet_AfterUpdate()
    Dim stRetVal As String
    Me!BBNazivPredmeta = Me!IDPredmet.Column(2)
    Me!BBDatumOtvaranja = Nz(Me!IDPredmet.Column(3), Null)
    Me!BBIDKomitent = Me!IDPredmet.Column(4)
    
    stRetVal = ADO_GetValFromUDFS(CNN_CurrentDataBase, "fsSledeciBrojRadnogNaloga", Me!IDPredmet.Column(1), 1)
    Me!IdentBroj = stRetVal
    DoCmd.GoToControl "IdentBroj"
    'Me!PrnTimer = CLng(Timer) '(CLng(Timer() * 100) Mod 100000)
End Sub

Private Sub IDRN_GotFocus()
On Error Resume Next
    Me!IDRNZaPrikaz.SetFocus
    Me!IDRNZaPrikaz = Me!IDRN
End Sub
Private Sub IDRNZaPrikaz_AfterUpdate()
    Call PrikaziRNIStavke(Me!IDRNZaPrikaz)
End Sub

Private Sub IDRNZaPrikaz_GotFocus()
    Me.AllowEdits = True
End Sub

Private Sub IDRNZaPrikaz_LostFocus()
   ProveriZakljucavanje
End Sub
Private Sub RNDokumentaTrazi_AfterUpdate()
    Call PrikaziRNIStavke(Me!RNDokumentaTrazi)
    Me![RNDokumentaTrazi] = Null
    Exit Sub
End Sub
Private Sub RNDokumentaTrazi_GotFocus()
    Me.AllowEdits = True
    Me!RNDokumentaTrazi.Requery
End Sub

Private Sub RNDokumentaTrazi_LostFocus()
    ProveriZakljucavanje
End Sub

Private Sub TabCtlRN_Change()
    Dim stDocName As String
    Dim stLinkCriteria As String
    
    Dim editOn As Boolean
    Dim IDRN As Long

    ' --- trenutni RN ---
    IDRN = Nz(Me!IDRN, 0)
    editOn = (Nz(Me!DugmeEdit.Value, False) = True)

    Select Case Me!TabCtlRN
    Case 0
        If editOn Then
            stDocName = "UnosStavkiRN"
            Me!LblPodforma.Caption = "Unos stavki tehnološkog postupka"
        Else
            stDocName = "PregledStavkiRN"
            Me!LblPodforma.Caption = "Pregled stavki tehnološkog postupka"
        End If
        Me!Podforma.Width = 16860
    Case 1
        stDocName = "UnosStavkiPND"
        Me!Podforma.Width = 16250
        Me!LblPodforma.Caption = "Unos nabavnih delova"
    Case 2
        stDocName = "UnosStavkiPDM"
        Me!Podforma.Width = 16250
        Me!LblPodforma.Caption = "Unos delova za montažu"
    Case 3
        stDocName = "UnosStavkiPLP"
        Me!Podforma.Width = 16250
        Me!LblPodforma.Caption = "Unos limova i profila"
    Case 4
        stDocName = "UnosStavkiKomponente"
        Me!Podforma.Width = 16250
        Me!LblPodforma.Caption = "Sastavni delovi crteža"
    Case 5
        stDocName = "UnosStavkiNDKomponente"
        Me!Podforma.Width = 16250
        Me!LblPodforma.Caption = "Nabavljani delovi crteža"
    End Select
    Me!Podforma.SourceObject = stDocName
    Me!Podforma.SetFocus
    
End Sub

Private Sub txtBarKod_DblClick(Cancel As Integer)
    SetClipboard Me!txtBarKod
End Sub


Private Sub Zakljucavanje_Click()
On Error GoTo Err_Zakljucavanje_Click

RNP.IDRN = Me!IDRN

 If Not IsNull(F_RN_IDRN()) Then
  'ZakOtkDok "T_Robna dokumenta", "IDDok", F_IF_IDDok(), Not Nz(Me!Zakljucano, False)
  ZakOtkDok "tRN", "IDRN", F_RN_IDRN(), Not Nz(Me!Zakljucano, False), True
 End If
 
 Application.Echo False

PrikaziRN

ProveriZakljucavanje
Exit_Zakljucavanje_Click:
 Application.Echo True

Exit Sub

Err_Zakljucavanje_Click:
    MsgBox err.Description
    Resume Exit_Zakljucavanje_Click
    
End Sub

Private Sub Command195_Click()
On Error GoTo Err_Command195_Click


    'Me!PrnTimer = CLng(Timer) '(CLng(Timer() * 100) Mod 100000)

Exit_Command195_Click:
    Exit Sub

Err_Command195_Click:
    MsgBox err.Description
    Resume Exit_Command195_Click
    
End Sub
Private Sub DugmeKopirajPostupke_Click()
On Error GoTo Err_DugmeKopirajPostupke_Click

    If RN_NemaStavke_ADO(CNN_CurrentDataBase(), F_RN_IDRN()) Then
        'stDocName = "IzborNalogaZaPrepisivanje"
        'DoCmd.OpenForm stDocName, , , stLinkCriteria
        IzborNalogaZaPrepisivanje F_RN_IDRN(), Me.Name
    Else
        MsgBox "Po ovom nalogu ste veæ unosili neke postupke!!!" & vbCrLf & "ili niste otvorili novi nalog u koji prepisujete stavke drugog naloga", vbInformation
    End If
    
Exit_DugmeKopirajPostupke_Click:
    Exit Sub

Err_DugmeKopirajPostupke_Click:
    MsgBox err.Description
    Resume Exit_DugmeKopirajPostupke_Click
    
End Sub
Private Sub DugmePrint_PND_PDM_PLP_Click()
On Error GoTo Err_DugmePrint_PND_PDM_PLP_Click

    Dim stDocName As String
    Dim ID As Long
    
    Select Case Me!TabCtlRN
    Case 0
        'ID = Nz(DLookup("ID", "tStavkeRN_BrOperacija"), 0)
        'If ID <> 0 Then
            stDocName = "rRN"
        'Else
        '    stDocName = "rRN_BezBarKoda"
        'End If
    Case 1
        stDocName = "rRN_tPND"
    Case 2
        stDocName = "rRN_tPDM"
    Case 3
        stDocName = "rRN_tPLP"
    Case 4
        stDocName = "rRN_tKomponente"
    Case 5
        stDocName = "rRN_tNDKomponente"
    End Select
    
    DoCmd.OpenReport stDocName, acPreview

Exit_DugmePrint_PND_PDM_PLP_Click:
    Exit Sub

Err_DugmePrint_PND_PDM_PLP_Click:
    MsgBox err.Description
    Resume Exit_DugmePrint_PND_PDM_PLP_Click
    
End Sub
Private Sub DugmeKreirajIstiPostupak_Click()
On Error GoTo Err_DugmeKreirajIstiPostupak_Click

    Dim stDocName As String
    Dim NoviIDRN As Long
    Dim prepisaniIDRN As Long
    
    If BBPitanje("Ovom akcijom kreirate " & Srpski("identican") & " nalog kao prikazan, samo se u polje varijanta upisuje " & _
            Srpski("sledeci") & " " & Srpski("najveci") & " broj" & vbCrLf & "Da li nastavljate?") Then
        prepisaniIDRN = Me!IDRN
        
        'PrepisiZaglavljePostupka NoviIDRN, prepisaniIDRN, Me!IDPredmet.Column(1)
        PrepisiZaglavljePostupka NoviIDRN, prepisaniIDRN
        Me.Filter = ""
        Me.Requery
        DoCmd.GoToRecord , , acLast
        'NoviIDRN = Me!IDRN
        
        PrepisiStavkeIzNaloga NoviIDRN, prepisaniIDRN
        PrepisitPNDIzNaloga NoviIDRN, prepisaniIDRN
        PrepisitPLPIzNaloga NoviIDRN, prepisaniIDRN
        PrepisitPDMIzNaloga NoviIDRN, prepisaniIDRN
        
        PrikaziRNIStavke NoviIDRN
        
    End If
    
Exit_DugmeKreirajIstiPostupak_Click:
    Exit Sub

Err_DugmeKreirajIstiPostupak_Click:
    MsgBox err.Description
    Resume Exit_DugmeKreirajIstiPostupak_Click
    
End Sub
Private Sub DugmeLagerLista_Click()
On Error GoTo Err_DugmeLagerLista_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "Lager lista"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeLagerLista_Click:
    Exit Sub

Err_DugmeLagerLista_Click:
    MsgBox err.Description
    Resume Exit_DugmeLagerLista_Click
    
End Sub
Private Sub DugmeRNSaglasnost()
On Error GoTo Err_DugmeFiskalniRacun_Click
Dim vIDRN As Long
Dim vBrojPredmeta As String
Dim vBBNazivPredmeta As String
Dim vNazivDela As String
Dim vDatumUnosa As Date
Dim BrojStavkiURN

    On Error Resume Next
     DoCmd.RunCommand acCmdSaveRecord
    On Error GoTo Err_DugmeFiskalniRacun_Click
    
    If IsNull(Me!IDRN) Then
      MsgBox "Ne postoji tehnosloški postupak!", vbExclamation, "QMegaTeh"
      Exit Sub
    End If
    
    vIDRN = Me!IDRN
    vBrojPredmeta = Nz(Me!IDPredmet.Column(1), "-")
    vBBNazivPredmeta = Nz(Me!BBNazivPredmeta, "-")
    vNazivDela = Nz(Me![NazivDela], "-")
    If BrojStavkiNaRN(vIDRN) <= 0 Then
     MsgBox "Postupak je bez stavki!", vbExclamation, "BigTehn"
     Exit Sub
    End If
    If UserUGrupi(CurrentUser(), "Saglasnost") Or UserUGrupi(CurrentUser(), "Admins") Or DefiniseSaglasan(IDRadnikZaCurrentUser()) Then
        RNSaglasnost vIDRN, vBrojPredmeta, vBBNazivPredmeta, vDatumUnosa, vNazivDela
    Else
        MsgBox "Niste ovlašæeni za ovaj unos!", vbExclamation, "BigTehn"
    End If
    Exit Sub
      
    On Error Resume Next
    DoCmd.DoMenuItem acFormBar, acRecordsMenu, acSaveRecord, , acMenuVer70
    On Error GoTo Err_DugmeFiskalniRacun_Click
    
Exit_DugmeFiskalniRacun_Click:
    Exit Sub

Err_DugmeFiskalniRacun_Click:
    MsgBox err.Description
    Resume Exit_DugmeFiskalniRacun_Click
    
End Sub


Public Sub RNSaglasnost(ByVal IDRN As Long, ByVal BrojPredmeta As String, ByVal BBNazivPredmeta As String, ByVal DatumUnosa, ByVal NazivDela As String)
    'BBOpenForm "MPNaplata"
    DoCmd.OpenForm "RNSaglasanStatus"
    Forms!RNSaglasanStatus!ZaIDRN = IDRN
    Forms!RNSaglasanStatus!BrojPredmeta = BrojPredmeta
    Forms!RNSaglasanStatus!BBNazivPredmeta = BBNazivPredmeta
    Forms!RNSaglasanStatus!DatumUnosa = DatumUnosa
    Forms!RNSaglasanStatus!NazivDela = NazivDela
    'Forms!RNSaglasanStatus!SifraRadnikaIspravka.Value = Null
    
    Forms!RNSaglasanStatus.Requery
    'Forms!MPNaplata!IznosRacuna = IznosMPRacuna(IDRN, IDProdavnica, IDKasa)
    Forms!RNSaglasanStatus!ZaIDRN.Requery
    Forms!RNSaglasanStatus!BrojPredmeta.Requery
    Forms!RNSaglasanStatus!BBNazivPredmeta.Requery
    Forms!RNSaglasanStatus!DatumUnosa.Requery
    Forms!RNSaglasanStatus!NazivDela.Requery
    'Forms!RNSaglasanStatus!SifraRadnikaIspravka.Requery
    
End Sub
Private Sub DugmeSaglasan_Click()
On Error GoTo Err_DugmeSaglasan_Click


    DugmeRNSaglasnost

Exit_DugmeSaglasan_Click:
    Exit Sub

Err_DugmeSaglasan_Click:
    MsgBox err.Description
    Resume Exit_DugmeSaglasan_Click
    
End Sub
Private Sub DugmeRNLansiran()
On Error GoTo Err_DugmeFiskalniRacun_Click
Dim vIDRN As Long
Dim vBrojPredmeta As String
Dim vBBNazivPredmeta As String
Dim vNazivDela As String
Dim vDatumUnosa As Date
Dim BrojStavkiURN

    On Error Resume Next
     DoCmd.RunCommand acCmdSaveRecord
    On Error GoTo Err_DugmeFiskalniRacun_Click
    
    If IsNull(Me!IDRN) Then
      MsgBox "Ne postoji tehnološki postupak!", vbExclamation, "QMegaTeh"
      Exit Sub
    End If
    
    vIDRN = Me!IDRN
    vBrojPredmeta = Nz(Me!IDPredmet.Column(1), "-")
    vBBNazivPredmeta = Nz(Me!BBNazivPredmeta, "-")
    vNazivDela = Nz(Me![NazivDela], "-")
    
    If BrojStavkiNaRN(vIDRN) <= 0 Then
     MsgBox "Postupak je bez stavki!", vbExclamation, "BigTehn"
     Exit Sub
    End If
    
    If Not PostojiSaglasnost(vIDRN) Then
     MsgBox "Za ovaj postupak još uvek nije data saglasnost!", vbExclamation, "BigTehn"
     Exit Sub
    End If
    
    If UserUGrupi(CurrentUser(), "ZaLansiranje") Or UserUGrupi(CurrentUser(), "Admins") Or DefiniseLansiran(IDRadnikZaCurrentUser()) Then
        RNLansiran vIDRN, vBrojPredmeta, vBBNazivPredmeta, vDatumUnosa, vNazivDela
    Else
        MsgBox "Niste ovlašæeni za ovaj unos!", vbExclamation, "BigTehn"
    End If
    Exit Sub
      
    On Error Resume Next
    DoCmd.DoMenuItem acFormBar, acRecordsMenu, acSaveRecord, , acMenuVer70
    On Error GoTo Err_DugmeFiskalniRacun_Click
    
Exit_DugmeFiskalniRacun_Click:
    Exit Sub

Err_DugmeFiskalniRacun_Click:
    MsgBox err.Description
    Resume Exit_DugmeFiskalniRacun_Click
    
End Sub

Public Sub RNLansiran(ByVal IDRN As Long, ByVal BrojPredmeta As String, ByVal BBNazivPredmeta As String, ByVal DatumUnosa, ByVal NazivDela As String)
    'BBOpenForm "MPNaplata"
    DoCmd.OpenForm "RNLansiranStatus"
    Forms!RNLansiranStatus!ZaIDRN = IDRN
    Forms!RNLansiranStatus!BrojPredmeta = BrojPredmeta
    Forms!RNLansiranStatus!BBNazivPredmeta = BBNazivPredmeta
    Forms!RNLansiranStatus!DatumUnosa = DatumUnosa
    Forms!RNLansiranStatus!NazivDela = NazivDela
    'Forms!RNLansiranStatus!SifraRadnikaIspravka.Value = Null
    
    Forms!RNLansiranStatus.Requery
    'Forms!MPNaplata!IznosRacuna = IznosMPRacuna(IDRN, IDProdavnica, IDKasa)
    Forms!RNLansiranStatus!ZaIDRN.Requery
    Forms!RNLansiranStatus!BrojPredmeta.Requery
    Forms!RNLansiranStatus!BBNazivPredmeta.Requery
    Forms!RNLansiranStatus!DatumUnosa.Requery
    Forms!RNLansiranStatus!NazivDela.Requery
    'Forms!RNLansiranStatus!SifraRadnikaIspravka.Requery
    
End Sub

Private Sub DugmeReportSaSlikama_Click()
On Error GoTo Err_DugmeReportSaSlikama_Click

    Dim stDocName As String

    stDocName = "rRN_SaSlikama"
    DoCmd.OpenReport stDocName, acPreview

Exit_DugmeReportSaSlikama_Click:
    Exit Sub

Err_DugmeReportSaSlikama_Click:
    MsgBox err.Description
    Resume Exit_DugmeReportSaSlikama_Click
    
End Sub


Private Function ZatvoriSveOtvoreneForme() As Boolean
On Error GoTo Err_Point
 Dim frm As Form
 Dim stMsg As String
 Dim retValOk As Boolean
 
 stMsg = ""
 retValOk = True
 
 For Each frm In Application.Forms
  If (frm.Name <> "Prva maska") And (frm.Name <> "UnosRN") And (frm.Name <> "QPrvaMaska") Then
    stMsg = stMsg & vbCrLf & frm.Name
    'frm.Close
  End If
 Next
 If stMsg <> "" Then
   stMsg = "Za promenu aktivnog radnog naloga treba zatvoriti forme: " & vbCrLf & stMsg
   stMsg = stMsg & vbCrLf & vbCrLf & "Da li nastavljate (sa zatvaranjem otvorenih formi)?"
   If Not BBPitanje(stMsg) Then
     retValOk = False
     GoTo Exit_Point
   Else
     While Application.Forms.Count > 2
        For Each frm In Application.Forms
           If (frm.Name <> "Prva maska") And (frm.Name <> "UnosRN") And (frm.Name <> "QPrvaMaska") Then
              DoCmd.Close acForm, frm.Name, acSavePrompt
           End If
        Next
     Wend
    
   End If
 End If
Exit_Point:
  ZatvoriSveOtvoreneForme = retValOk
  Exit Function
Err_Point:
  BBErrorMSG err, "Promeni radni nalog::ZatvoriSveOtvoreneForme"
  retValOk = False
  Resume Exit_Point
End Function

Private Function PodesiPrikazVrstaKvaliteta()
On Error GoTo Err_Point
    If Me!IDVrstaKvaliteta = 0 Then
        Me!IDVrstaKvaliteta.Visible = False
        Me!Label_IDVrstaKvaliteta.Visible = False
    Else
        Me!IDVrstaKvaliteta.Visible = True
        Me!Label_IDVrstaKvaliteta.Visible = True
    End If
Exit_Point:
On Error Resume Next

Exit Function

Err_Point:
    BBErrorMSG err, "PodesiPrikazVrstaKvaliteta"
    Resume Next
End Function

Public Function PostojiDupliIdentBroj(ByVal CNNString As String, _
                                      ByVal IDPredmet As Long, _
                                      ByVal BrojCrteza As String, _
                                      ByVal Varijanta As String, _
                                      ByVal Revizija As String, _
                                      ByVal IdentBroj As String, _
                                      Optional ByVal IDRN_Izuzmi As Long = 0, _
                                      Optional ByRef OpisDuplikata As String) As Boolean
    On Error GoTo Err_Handler

    Dim sql As String
    Dim rs As ADODB.Recordset

    sql = "SELECT TOP 1 BrojCrteza, Varijanta, Revizija " & _
          "FROM tRN " & _
          "WHERE IdentBroj = N'" & Replace(IdentBroj, "'", "''") & "' " & _
          "AND NOT (IDPredmet = " & IDPredmet & _
          " AND BrojCrteza = N'" & Replace(BrojCrteza, "'", "''") & "'" & _
          " AND Varijanta = N'" & Replace(Varijanta, "'", "''") & "'" & _
          " AND Revizija = N'" & Replace(Revizija, "'", "''") & "')" & _
          IIf(IDRN_Izuzmi > 0, " AND IDRN <> " & IDRN_Izuzmi, "")

    Set rs = ADO_GetRST(CNNString, sql, adLockReadOnly)

    If Not rs.EOF Then
        PostojiDupliIdentBroj = True
        OpisDuplikata = "Broj naloga " & IdentBroj & _
                        " veæ postoji za crtež " & _
                        Nz(rs!BrojCrteza, "?") & _
                        IIf(Len(Nz(rs!Varijanta, "")) > 0, " varijanta " & rs!Varijanta, "") & _
                        ", revizija " & Nz(rs!Revizija, "?")
    Else
        PostojiDupliIdentBroj = False
        OpisDuplikata = ""
    End If

Exit_Point:
    On Error Resume Next
    rs.Close
    Set rs = Nothing
    Exit Function

Err_Handler:
    PostojiDupliIdentBroj = False
    OpisDuplikata = ""
    Resume Exit_Point
End Function
Public Sub PrikaziObjekteZaMene()
    If UserUGrupi(CurrentUser(), "Admins") Then
        Me!LblBarKod.Visible = True
        Me!txtBarKod.Visible = True
        Me!DugmePrebaciUClipboard.Visible = True 'DugmePrebaciUClipboard
        Me!PrnTimer.Visible = True
    Else
        Me!LblBarKod.Visible = False
        Me!txtBarKod.Visible = False
        Me!DugmePrebaciUClipboard.Visible = False
        Me!PrnTimer.Visible = False
    End If
End Sub
