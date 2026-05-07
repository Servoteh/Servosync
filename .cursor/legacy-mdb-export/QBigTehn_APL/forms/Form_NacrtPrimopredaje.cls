VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_NacrtPrimopredaje"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Sub ProveriZakljucavanje()
    Application.Echo False
    If Nz(Me!Zakljucano, False) Then
        Me.FormHeader.BackColor = BBCFG.ColorLock
        Me.Detail.BackColor = BBCFG.ColorLock
        Me.AllowEdits = False
        Me.AllowDeletions = False
        
    Else
        Me.FormHeader.BackColor = BBCFG.ColorUnLock
        Me.Detail.BackColor = BBCFG.ColorUnLock
        Me.AllowEdits = True
        Me.AllowDeletions = True
    End If
      
    Application.Echo True
End Sub


Private Sub DugmeKreirajPrimopredaju_Click()
On Error GoTo ErrH
    Dim IDNacrtPrim As Long
    Dim SifraRadnika As Long
    Dim OK As Boolean
    Dim RokIzrade As Variant

    If Not UserUGrupi(CurrentUser(), "KreirajPrimoPred") And Not UserUGrupi(CurrentUser(), "Admins") Then
        MsgBox "Ne pripadate grupi koja sme da kreira primopredaju.", vbExclamation
        Exit Sub
    End If
    
    IDNacrtPrim = Nz(Me!IDNacrtPrim, 0)
    If IDNacrtPrim = 0 Then
        MsgBox "Nacrt nije snimljen (IDNacrtPrim=0).", vbExclamation
        Exit Sub
    End If

    SifraRadnika = IDRadnikZaCurrentUser
    
    If Not DijalogRokIzrade(RokIzrade) Then
        MsgBox "Kreiranje primopredaje je otkazano.", vbInformation
        GoTo CleanUp
    End If
    
    Dim RokSQL As String

    If IsDate(RokIzrade) Then
        RokSQL = Format(RokIzrade, "yyyy-mm-dd")
    Else
        RokSQL = Null
    End If

    ' zaštita od dvoklika i indikator rada
    Me!DugmeKreirajPrimopredaju.Enabled = False
    
    DoCmd.Hourglass True

    OK = ADO_ExecSP(CNN_CurrentDataBase, "spKreirajRNZaNacrtPrimopredaje", IDNacrtPrim, SifraRadnika, RokSQL)

    If OK Then
        If PromeniStatusCrtezaPriRaduSaNacrtom(IDNacrtPrim, 2) Then
            If DefinisiStatusNacrtaPrimopredaje(IDNacrtPrim, 1) Then
                MsgBox "RN su kreirani (status: U OBRADI) i status crteža i nacrta je ažuriran.", vbInformation
            Else
                MsgBox "RN su kreirani (status: U OBRADI) i status nacrta NIJE promenjen.", vbInformation
            End If
        Else
            If DefinisiStatusNacrtaPrimopredaje(IDNacrtPrim, 1) Then
                MsgBox "RN su kreirani (status: U OBRADI), ali status crteža NIJE promenjen, status nacrta JE promenjen .", vbExclamation
            Else
                MsgBox "RN su kreirani (status: U OBRADI) i status crteža i status nacrta NIJE promenjen.", vbInformation
            End If
        End If
        
        ' osveži prikaz
        On Error Resume Next
        Call ADO_ExecSP(CNN_CurrentDataBase, "spZakOtk", "NacrtPrimopredaje", Null, Null, stR(Nz(IDNacrtPrim, 0)), SQLFormatBoolean(True))
        'Me!IDStatusNacrtaPrimopredaje.Requery
        'Me!Nacrt_Stavke.Requery
        'DefinisiEnabledZaDugmice
        Call KreirajPorukuPoslePrimopredaje(Nz(Me!BrojNacrta, ""), Me!SifraRadnika, "TEHNOLOG")
                            
        OsveziNakonPrimopredaje
                
        On Error GoTo 0
    Else
        MsgBox "Radni nalozi NISU kreirani za nacrt " & IDNacrtPrim & ".", vbExclamation
    End If

CleanUp:
    DoCmd.Hourglass False
    Exit Sub

ErrH:
    BBErrorMSG err, "DugmeKreirajPrimopredaju_Click"
    Resume CleanUp
End Sub

Private Sub DugmeObrisiNacrt_Click()
Dim stDocName As String
    Dim answer As Variant
    Dim retValOk As Boolean
    retValOk = True
    Dim pZakljucano As Boolean
    
    retValOk = True
    
    pZakljucano = Nz(ADO_Lookup(CNN_CurrentDataBase, "Zakljucano", "NacrtPrimopredaje", "[IDNacrtPrim]=" & Me!IDNacrtPrim), False)
    If pZakljucano Then
        MsgBox "Nacrt je " & Srpski("zakljucan")
        Exit Sub
    End If
    
    answer = MsgBox("Ovim brišete kompletni nacrt primopredaje!!!" & Chr(13) & " Da li nastavljate BRISANJE?", vbYesNo + vbCritical + vbDefaultButton2, "Brisanje nacrta primopredaje")
    If answer = vbYes Then
        retValOk = ADO_ExecSP(BBCFG.CNNString, "spObrisiNacrtPrimopredaje", Me!IDNacrtPrim)
        If retValOk Then Me.Requery
    End If
    
Exit_DugmeObrisiNalog_Click:
    Exit Sub

Err_DugmeObrisiNalog_Click:
    MsgBox err.Description
    Resume Exit_DugmeObrisiNalog_Click

End Sub

Private Sub DugmeOdlukePredProvera_Click()
    Dim retValOk As Boolean
    retValOk = KreirajTmpTabeluUTmpBazi("tmp_OdlukePredProvera", "Q_OdlukePredProvere", , , , "IDNacrtStavka")
    OtvoriFormuZaOdlukePredProvera Me!IDNacrtPrim, Me!TipNacrta, Nz(Me!IDGlavniCrtez, 0), Me!BrojNacrta, Me!DatumNacrta
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

Private Sub Form_Close()
    On Error Resume Next
    ' Pozovi osveženje u glavnoj formi:
    'Forms!PDM_PregledCreta.RefreshNacrt ZaglavljeID
    Forms![PDMCrteziPregled]![tabCtlPodform1].Form.OsveziPrikaz
End Sub


Private Sub Form_Current()
On Error GoTo Err_Point
    ProveriZakljucavanje
    If Nz(Me!IDNacrtPrim, 0) = 0 Then Exit Sub
    DefinisiEnabledZaDugmice
    
Exit_Point:
    Exit Sub

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
End Sub
Public Sub DefinisiEnabledZaDugmice()
On Error GoTo Err_Point
    Dim ID As Long
    ID = Nz(Me!IDNacrtPrim, 0)
    If ID = 0 Then GoTo Exit_Point

    ' 1) Ako je nacrt veæ predat (header status <> 0) › oba dugmeta iskljuèi
    If NacrtJePredat(ID) Then
        Me!DugmeKreirajPrimopredaju.Enabled = False
        Me!DugmeOdlukePredProvera.Enabled = False
        Me!DugmeObrisiNacrt.Enabled = False
        GoTo Exit_Point
    End If

    ' 2) U suprotnom: ako postoje nerešene stavke › Kreiraj=Off, Odluke=On
    If DisableDugmeKreirajRN(ID) Then
        Me!DugmeKreirajPrimopredaju.Enabled = False
        Me!DugmeOdlukePredProvera.Enabled = True
        Me!DugmeObrisiNacrt.Enabled = True
    Else
        ' Nema blokirajuæih uslova › Kreiraj=On, Odluke=Off
        Me!DugmeKreirajPrimopredaju.Enabled = True
        Me!DugmeOdlukePredProvera.Enabled = False
        Me!DugmeObrisiNacrt.Enabled = True
    End If

Exit_Point:
    Exit Sub

Err_Point:
    MsgBox err.Description, vbExclamation, "Greška"
    Resume Exit_Point
End Sub




Private Sub Form_Load()
    ' Uvek otvori formu za unos novog zapisa
    'Me.DataEntry = True
    
    ' Ako želiš i podrazumevanu vrednost za kombo:
    'If Nz(Me.OpenArgs, "") = "Nacrt" Then
    '    Me!DugmePrviSlog.Enabled = False
    '    Me!DugmePrethodniSlog.Enabled = False
    '    Me!DugmeSledeciSlog.Enabled = False
    '    Me!DugmePoslednjiSlog.Enabled = False
    '    Me!NacrtPrimopredajeTrazi.Enabled = False
    '    Me!Zakljucano.Enabled = False
    '    Me!Zakljucavanje.Enabled = False
        ' (ako je naziv kontrole isti kao polja, i Me!IDStatusNacrtaPrimopredaje radi)
    'End If
End Sub

Private Sub DugmeNoviSlog_Click()
On Error GoTo Err_DugmeNoviSlog_Click


    DoCmd.GoToRecord , , acNewRec
    DoCmd.GoToControl "IDPredmet"
Exit_DugmeNoviSlog_Click:
    Exit Sub

Err_DugmeNoviSlog_Click:
    MsgBox err.Description
    Resume Exit_DugmeNoviSlog_Click
    
End Sub

Private Sub Form_Open(Cancel As Integer)
    DoCmd.Maximize
    DoCmd.GoToRecord , , acLast
End Sub

Private Sub Form_Unload(Cancel As Integer)
    DBEngine.Idle dbFreeLocks
End Sub

Private Sub IDPredmet_AfterUpdate()
    OdrediBrojNacrta
    'DoCmd.GoToControl "BrojNacrta"
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
Private Sub NacrtPrimopredajeTrazi_AfterUpdate()
On Error GoTo Err_Point

   If Me.FilterOn Then
    Me.Filter = "IDNacrtPrim=" & Me![NacrtPrimopredajeTrazi]
   Else
    PronadjiSlogNaFormi Me, "IDNacrtPrim=" & Me![NacrtPrimopredajeTrazi]
   End If
   Me![NacrtPrimopredajeTrazi] = Null
Exit Sub

Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "NacrtPrimopredajeTrazi_AfterUpdate"
 Resume Exit_Point
End Sub

Private Sub NacrtPrimopredajeTrazi_GotFocus()
    Me!NacrtPrimopredajeTrazi.Requery
End Sub

Private Sub TipNacrta_AfterUpdate()
    OdrediBrojNacrta
End Sub

Private Sub Zakljucavanje_Click()
On Error GoTo Err_Zakljucavanje_Click
 

 If Not IsNull(Me!IDNacrtPrim) Then
  ZakOtkDok "NacrtPrimopredaje", "IDNacrtPrim", Me!IDNacrtPrim, Not Nz(Me!Zakljucano, False)
 End If
 
 Application.Echo False
   Me.Recalc
   ProveriZakljucavanje
Exit_Zakljucavanje_Click:
 Application.Echo True
Exit Sub

Err_Zakljucavanje_Click:
    MsgBox err.Description
    Resume Exit_Zakljucavanje_Click

End Sub

Private Sub OdrediBrojNacrta()
    Dim stRetVal As String
    If Not IsNull(Me!IDPredmet) And Not IsNull(Me!TipNacrta) Then
        stRetVal = ADO_GetValFromUDFS(CNN_CurrentDataBase, "fsSledeciBrojNacrtaPrimopredaje", Me!IDPredmet.Column(1), 1, Me!TipNacrta)
        Me!BrojNacrta = stRetVal
    End If
End Sub
Private Sub OvoJeNacrt()
On Error GoTo Err_Point

        'Me!lblNazivForme.Caption = "Profaktura"
        'Me.Caption = "Profaktura"
        ''Me!BoxZag.BackColor = RGB(153, 204, 255)
        'Me!BoxZag.BackColor = RGB(237, 247, 249)
        
        ''Me!TekstZaFakturu.DefaultValue = "'Profaktura'"
        
        'Me!LabelLevel.Visible = True
        'Me!Level.Visible = True
        'Me!Level.ValidationRule = "BETWEEN 250 AND 250"
        'Me!Level.ValidationText = "Dozvoljene vrednosti su od 250 do 250"
        'Me!Level.DefaultValue = 250
        'Me!Level.Enabled = False
        'Me!OdLevel = 250
        'Me!DoLevel = 250
        
        'Me!DugmeFiskalniRacun.Enabled = False
        'Me!DugmePrebaciNaProf.Enabled = False
        
Exit_Point:
On Error Resume Next

Exit Sub

Err_Point:
   MsgBox err.Description
   Resume Next
End Sub

Private Sub OvoJePrimopredaja()
On Error GoTo Err_Point

        'Me!lblNazivForme.Caption = "Profaktura"
        'Me.Caption = "Profaktura"
        ''Me!BoxZag.BackColor = RGB(153, 204, 255)
        'Me!BoxZag.BackColor = RGB(237, 247, 249)
        
        ''Me!TekstZaFakturu.DefaultValue = "'Profaktura'"
        
        'Me!LabelLevel.Visible = True
        'Me!Level.Visible = True
        'Me!Level.ValidationRule = "BETWEEN 250 AND 250"
        'Me!Level.ValidationText = "Dozvoljene vrednosti su od 250 do 250"
        'Me!Level.DefaultValue = 250
        'Me!Level.Enabled = False
        'Me!OdLevel = 250
        'Me!DoLevel = 250
        
        'Me!DugmeFiskalniRacun.Enabled = False
        'Me!DugmePrebaciNaProf.Enabled = False
        
Exit_Point:
On Error Resume Next

Exit Sub

Err_Point:
   MsgBox err.Description
   Resume Next
End Sub
Public Function DisableDugmeKreirajRN(ByVal IDNacrtPrim As Long) As Boolean
On Error GoTo Err_Point
    Dim stSQL As String
    Dim retValOk As Boolean
    Dim rst As DAO.Recordset
    
    stSQL = ""
    
    stSQL = stSQL & "SELECT *"
    stSQL = stSQL & " FROM NacrtPrimopredajeStavke"
    stSQL = stSQL & " WHERE IDNacrtPrim = " & CStr(IDNacrtPrim)
    stSQL = stSQL & " AND (Nz(PredProveraIDNacrtPrim,0) <> 0 OR Nz(PredProveraIDRN,0) <> 0)"
    stSQL = stSQL & " AND Nz(IskljuciPrimopredaju,0) = 0"
    stSQL = stSQL & " AND Nz(OdlukaAkcija,0) = 0"
    
    Set rst = CurrentDb.OpenRecordset(stSQL, dbOpenDynaset, dbSeeChanges)
    If rst.RecordCount > 0 Then
        retValOk = True
    Else
        retValOk = False
    End If
    
Exit_Point:
    On Error Resume Next
    rst.Close
    Set rst = Nothing
    DisableDugmeKreirajRN = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "DisableDugmeKreirajRN"
    retValOk = True
    Resume Exit_Point
End Function
Public Function NacrtJePredat(ByVal IDNacrtPrim As Long) As Boolean
On Error GoTo Err_Point
    Dim stSQL As String
    Dim rst As DAO.Recordset

    stSQL = "SELECT Nz(IDStatusNacrtaPrimopredaje,0) AS St" & _
            " FROM NacrtPrimopredaje" & _
            " WHERE IDNacrtPrim=" & CStr(IDNacrtPrim) & ";"

    Set rst = CurrentDb.OpenRecordset(stSQL, dbOpenSnapshot)

    If rst.EOF Then
        ' ako nema headera, ponašaj se restriktivno
        NacrtJePredat = True
    Else
        NacrtJePredat = (Nz(rst!st, 0) <> 0)
    End If

Exit_Point:
    On Error Resume Next
    If Not rst Is Nothing Then rst.Close
    Set rst = Nothing
    Exit Function

Err_Point:
    BBErrorMSG err, "NacrtJePredat"
    NacrtJePredat = True   ' fail-safe
    Resume Exit_Point
End Function

Private Function OtvoriFormuZaOdlukePredProvera(IDNacrtPrim As Long, TipNacrta As Long, IDGlavniCrtez As Long, BrojNacrta As String, DatumNacrta As Date) As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean
retValOk = True

    If IsLoaded("OdlukePredProvera") Then
        MsgBox "Morate zatvoriti prethodni dijalog za export.", vbExclamation, "QBigTeh"
        retValOk = False
        Exit Function
    End If
        
    DoCmd.Hourglass True
    DoCmd.OpenForm "OdlukePredProvera"
    
    If Not IsLoaded("OdlukePredProvera") Then
        MsgBox "Ne može da se otvori forma [ER_Export]", vbExclamation, "QBigTeh"
        retValOk = False
        Exit Function
    Else
        Forms!OdlukePredProvera!IDNacrtPrim = IDNacrtPrim
        Forms!OdlukePredProvera!TipNacrta = TipNacrta
        Forms!OdlukePredProvera!IDGlavniCrtez = IDGlavniCrtez
        Forms!OdlukePredProvera!BrojNacrta = BrojNacrta
        Forms!OdlukePredProvera!DatumNacrta = DatumNacrta
        Forms!OdlukePredProvera!TipNacrta.Requery
        Forms!OdlukePredProvera!IDGlavniCrtez.Requery
    End If
    
Exit_Point:
On Error Resume Next

    DoCmd.Hourglass False
    OtvoriFormuZaOdlukePredProvera = retValOk
    
Exit Function

Err_Point:
    BBErrorMSG err, "OtvoriFormuZaOdlukePredProvera"
    retValOk = False
    Resume Exit_Point
End Function
' Pozovi nakon kreiranja primopredaje / promene statusa
Public Sub OsveziNakonPrimopredaje()
On Error GoTo ErrH
    Dim ID As Long
    ID = Nz(Me!IDNacrtPrim, 0)
    If ID = 0 Then Exit Sub

    ' 1) Saèuvaj izmene na formi (ako ih ima)
    If Me.Dirty Then Me.Dirty = False
    DoCmd.RunCommand acCmdSaveRecord

    ' 2) Ubrzaj i spreèi treperenje
    DoCmd.Echo False
    Me.Painting = False

    ' 3) Requery glavne forme i vrati se na isti zapis
    Me.Requery
    With Me.RecordsetClone
        .FindFirst "IDNacrtPrim=" & ID
        If Not .NoMatch Then Me.Bookmark = .Bookmark
    End With

    ' 4) Requery subforme / listova ako ih ima
    On Error Resume Next
    Me!Nacrt_Stavke.Requery
    On Error GoTo ErrH

    '' 5) Zakljuèaj/otkljuèaj formu i dugmad na osnovu novog stanja
    'Dim jePredat As Boolean
    'jePredat = NacrtJePredat(id)

    'Me.AllowEdits = Not jePredat
    'Me.AllowAdditions = Not jePredat
    'Me.AllowDeletions = Not jePredat
    ProveriZakljucavanje
    
    ' po tvojoj logici za dugmad:
    DefinisiEnabledZaDugmice

clean:
    Me.Painting = True
    DoCmd.Echo True
    Exit Sub
ErrH:
    Me.Painting = True
    DoCmd.Echo True
    MsgBox err.Description, vbExclamation, "OsveziNakonPrimopredaje"
End Sub
Public Function DijalogRokIzrade(ByRef RokIzrade As Variant) As Boolean

    gDialogResultOK = False
    gRokIzradeResult = Null
    
    DoCmd.OpenForm "dlgRokIzrade", , , , , acDialog
    
    If gDialogResultOK Then
    
        RokIzrade = gRokIzradeResult
        DijalogRokIzrade = True
        
    Else
    
        RokIzrade = Null
        DijalogRokIzrade = False
        
    End If

End Function

