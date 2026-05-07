VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PlaniranjeNabavke"
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
Public Sub DefinisiEnabledZaDugmice_OLD()
On Error GoTo Err_Point
    Dim ID As Long
    ID = Nz(Me!IDPlan, 0)
    If ID = 0 Then GoTo Exit_Point

    ' 1) Ako je nacrt veæ predat (header status <> 0) › oba dugmeta iskljuèi
    If PlaniranjeJePredato(ID) Then
        Me!DugmeDefinisiPotrebneKolicine.Enabled = False
        Me!DugmeOdlukePredProvera.Enabled = False
        Me!DugmeObrisiPlaniranjeNabavke.Enabled = False
        Me!DugmeProknjižiPlaniranje.Enabled = False
        GoTo Exit_Point
    End If

    ' 2) U suprotnom: ako postoje nerešene stavke › Kreiraj=Off, Odluke=On
    If DisableDefinisiPotrebneKolicine(ID) Then
        Me!DugmeProknjižiPlaniranje.Enabled = False
        Me!DugmeDefinisiPotrebneKolicine.Enabled = False
        Me!DugmeOdlukePredProvera.Enabled = True
        Me!DugmeObrisiPlaniranjeNabavke.Enabled = True
    Else
        ' Nema blokirajuæih uslova › Kreiraj=On, Odluke=Off
        Me!DugmeProknjižiPlaniranje.Enabled = True
        Me!DugmeDefinisiPotrebneKolicine.Enabled = True
        Me!DugmeOdlukePredProvera.Enabled = False
        Me!DugmeObrisiPlaniranjeNabavke.Enabled = True
    End If

Exit_Point:
    Exit Sub

Err_Point:
    MsgBox err.Description, vbExclamation, "Greška"
    Resume Exit_Point
End Sub
Public Function DisableDefinisiPotrebneKolicine(ByVal IDPlan As Long) As Boolean
On Error GoTo Err_Point
    Dim stSQL As String
    Dim retValOk As Boolean
    Dim rst As DAO.Recordset
    
    stSQL = ""
    
    stSQL = stSQL & "SELECT *"
    stSQL = stSQL & " FROM PDM_PlaniranjeStavke"
    stSQL = stSQL & " WHERE IDPlan = " & CStr(IDPlan)
    stSQL = stSQL & " AND Nz(PredProveraIDPlan,0) <> 0"
    stSQL = stSQL & " AND Nz(IskljuciNabavku,0) = 0"
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
    DisableDefinisiPotrebneKolicine = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "DisableDefinisiPotrebneKolicine"
    retValOk = True
    Resume Exit_Point
End Function


Private Sub DugmeDefinisiPotrebneKolicine_Click()
On Error GoTo Err_Handler
    Dim ID As Long
    
    ID = Nz(Me!IDPlan, 0)
    If ID = 0 Then Exit Sub
    
    If BBPitanje("Ovim unosite kolièine koje se rezervišu i trebuju. Da li nastavljate?") Then
        Call ADO_ExecSP(CNN_CurrentDataBase, "spPDM_Planiranje_PopuniRezervisanoINabavku", Me!IDPlan)
        Forms![PlaniranjeNabavke]![PlaniranjeNabavkeStavke].Form.Requery
        DefinisiEnabledZaDugmice
    End If

Exit_Point:
    Exit Sub
Err_Handler:
    MsgBox "Greška: " & err.Description, vbCritical
    Resume Exit_Point

End Sub


Private Sub DugmeObrisiPlaniranjeNabavke_Click()
    Dim stDocName As String
    Dim answer As Variant
    Dim retValOk As Boolean
    retValOk = True
    Dim pZakljucano As Boolean
    Dim IDPotreba As Long
    
    retValOk = True
    
    pZakljucano = Nz(ADO_Lookup(CNN_CurrentDataBase, "Zakljucano", "PDM_Planiranje", "[IDPlan]=" & Me!IDPlan), False)
    If pZakljucano Then
        MsgBox "Dokument planiranja nabavka je " & Srpski("zakljucan")
        Exit Sub
    End If
    
    answer = MsgBox("Ovim brišete kompletni dokument planiranja nabavke!!!" & Chr(13) & " Da li nastavljate BRISANJE?", vbYesNo + vbCritical + vbDefaultButton2, "Brisanje nacrta primopredaje")
    If answer = vbYes Then
        IDPotreba = Nz(ADO_Lookup(CNN_CurrentDataBase, "IDPotreba", "MRP_Potrebe", "IDPlan=" & Me!IDPlan), 0)
        retValOk = ADO_ExecSP(BBCFG.CNNString, "spPDM_Planiranje_ObrisiPlan", Me!IDPlan)
        If retValOk And IDPotreba <> 0 Then
            Call ADO_ExecSP(BBCFG.CNNString, "spMRP_Potrebe_PromeniStatus", IDPotreba, 0)
        End If
        If retValOk Then Me.Requery
    End If
    
Exit_DugmeObrisiNalog_Click:
    Exit Sub

Err_DugmeObrisiNalog_Click:
    MsgBox err.Description
    Resume Exit_DugmeObrisiNalog_Click

End Sub

Private Sub DugmeOdlukePredProvera_Click()
On Error GoTo Err_Point

    Dim retValOk As Boolean
    Dim ID As Long
    
    ID = Nz(Me!IDPlan, 0)
    If ID = 0 Then Exit Sub
    
    retValOk = KreirajTmpTabeluUTmpBazi( _
                    "tmp_PlanSporneStavke", _
                    "Q_PlanSporneStavke", _
                    , , , _
                    "IDPlanStavka")
                    
    If Not retValOk Then Exit Sub
    
    Call OtvoriFormuSporneStavke(Me!IDPlan)

Exit_Point:
    Exit Sub

Err_Point:
    BBErrorMSG err, "DugmeSporneStavke_Click"
    Resume Exit_Point

End Sub
Private Sub DugmeProknjižiPlaniranje_Click()
On Error GoTo Err_Point

    Dim rs As ADODB.Recordset
    Dim sql As String
    Dim ID As Long
    Dim IDPotreba As Long

    Dim BrojDokumenta As String
    Dim IDRadnogNaloga As Long
    Dim IDMagacinDOK As Long
    Dim SifraKomitenta As Long
    Dim Rezervisi As Boolean
    Dim NewIDDok As Long
    Dim retValOk As Boolean

    ID = Nz(Me!IDPlan, 0)
    If ID = 0 Then Exit Sub

    ' =====================================
    ' naði vezanu MRP potrebu
    ' =====================================
    IDPotreba = Nz(ADO_Lookup(CNN_CurrentDataBase, _
                          "IDPotreba", _
                          "MRP_Potrebe", _
                          "IDPlan=" & ID), 0)

    ' =====================================
    ' Kreiraj zahtev za nabavku
    ' =====================================
    Call KreirajZahtevZaNabavkuIzPlana(Me!IDPlan, Me!IDPredmet, Me!BrojPlana)

    ' =====================================
    ' Provera artikala
    ' =====================================
    sql = "SELECT TOP 1 BrojCrteza, Naziv " & _
          "FROM PDM_PlaniranjeStavke " & _
          "INNER JOIN PDMCrtezi ON PDM_PlaniranjeStavke.IDCrtezNabavke = PDMCrtezi.IDCrtez " & _
          "WHERE PDM_PlaniranjeStavke.IDPlan=" & ID & _
          " AND IsNull(IskljuciNabavku,0)=0 " & _
          " AND IsNull(Rezervisano,0)>0 " & _
          " AND IsNull(SifraArtikla,'')=''"

    Set rs = ADO_GetRST(BBCFG.CNNString, sql, adLockReadOnly, adUseClient, adOpenForwardOnly)

    If Not rs.EOF Then

        MsgBox "Nije definisana šifra artikla robnog programa za stavku:" & vbCrLf & vbCrLf & _
               rs!BrojCrteza & " - " & rs!Naziv & vbCrLf & vbCrLf & _
               "Pre proknjiženja morate povezati artikle.", _
               vbExclamation, "Planiranje nabavke"

        rs.Close
        Exit Sub

    End If

    rs.Close

    If RezervisanjeVecaOdZaliha(ID) Then Exit Sub

    ' =====================================
    ' KRENI
    ' =====================================
    DoCmd.Hourglass True
    retValOk = True

    BrojDokumenta = 1 + NullToZero(DLookup("[CountOfIDDok]", _
                    "BrojProfakturaPoVrstama", _
                    "[Vrsta dokumenta]='NALMA'"))

    BrojDokumenta = DoChLeft(BrojDokumenta, 4, "0")

    Rezervisi = False
    IDMagacinDOK = 1

    IDRadnogNaloga = Nz(DLookup("IDRadniNalog", _
                     "EXT_Radninalozi", _
                     "IDPredmet=" & Me!IDPredmet), 0)

    SifraKomitenta = Nz(DLookup("IDKomitent", _
                       "EXT_Predmeti", _
                       "IDPredmet=" & Me!IDPredmet), 0)

    NewIDDok = KreirajNalogMagacinu(False, Date, "NALMA", _
                BBIDProdavacZaCurrentUser(), _
                IDRadnogNaloga, _
                250, _
                IDMagacinDOK, _
                "Nalog magacinu za rezervaciju", _
                SifraKomitenta, _
                BrojDokumenta, _
                Rezervisi, _
                "Beograd", _
                Date, "-", 1, 0, "-", "-", "-", _
                Me!IDPredmet)

    If NewIDDok = 0 Then
        retValOk = False
        GoTo Rollback_Point
    End If

    retValOk = DodajStavkeUNalogMagacinu( _
                    NewIDDok, _
                    "PlaniranjeStavkeZaKnjizenjeNALMA", _
                    ID, _
                    True)

    If Not retValOk Then GoTo Rollback_Point

    ' =====================================
    ' SVE USPESNO -> STATUSI
    ' =====================================

    ' MRP potreba = Završeno (4)
    If IDPotreba <> 0 Then
        Call ADO_ExecSP( _
            CNN_CurrentDataBase, _
            "spMRP_Potrebe_PromeniStatus", _
            IDPotreba, _
            4)
    End If
    
    Call ZakOtkDok("MRP_Potrebe", "IDPotreba", IDPotreba, True)

    ' Planiranje = Završeno (4)
    Call ADO_ExecSP( _
        CNN_CurrentDataBase, _
        "spPDM_Planiranje_PromeniStatus", _
        ID, _
        1)
    Call ZakOtkDok("PDM_Planiranje", "IDPlan", ID, True)
    
    MsgBox "Planiranje je uspešno proknjiženo.", vbInformation

    Me.Requery
    GoTo Exit_Point

Rollback_Point:

    MsgBox "Proknjiženje nije uspelo. Statusi nisu promenjeni.", vbCritical

Exit_Point:
    DoCmd.Hourglass False
    Exit Sub

Err_Point:
    DoCmd.Hourglass False
    MsgBox err.Description, vbCritical
End Sub
Private Sub DugmeProknjižiPlaniranje_OLD_Click()
On Error GoTo Err_Point

    Dim rs As ADODB.Recordset
    Dim sql As String
    Dim ID As Long
    
    ID = Nz(Me!IDPlan, 0)
    If ID = 0 Then Exit Sub
    
    Call KreirajZahtevZaNabavkuIzPlana(Me!IDPlan, Me!IDPredmet, Me!BrojPlana)
    
    sql = "SELECT TOP 1 BrojCrteza, Naziv " & _
          "FROM PDM_PlaniranjeStavke INNER JOIN PDMCrtezi ON PDM_PlaniranjeStavke.IDCrtezNabavke = PDMCrtezi.IDCrtez " & _
          "WHERE PDM_PlaniranjeStavke.IDPlan=" & ID & _
          " AND IsNull(IskljuciNabavku,0)=0 " & _
          " AND IsNull(Rezervisano,0)>0 " & _
          " AND IsNull(SifraArtikla,'')=''"
    'Debug.Print sql
    Set rs = ADO_GetRST(BBCFG.CNNString, sql, adLockReadOnly, adUseClient, adOpenForwardOnly)
    
    
    If Not rs.EOF Then
    
        MsgBox "Nije definisana šifra artikla robnog programa za stavku:" & vbCrLf & vbCrLf & _
               rs!BrojCrteza & " - " & rs!Naziv & vbCrLf & vbCrLf & _
               "Pre proknjiženja morate povezati artikle.", _
               vbExclamation, "Planiranje nabavke"
    
        rs.Close
        Exit Sub
    
    End If
    
    rs.Close
    
    If RezervisanjeVecaOdZaliha(Me!IDPlan) Then Exit Sub
    
    'ovde ide proknjiženje
    'Call ProknjiziPlaniranje(ID)
    Dim BrojDokumenta As String
    Dim BrojRadnogNaloga As String
    Dim NoviBrojRadnogNaloga As String
    Dim IDRadnogNaloga As Long
    Dim IDMagacinDOK As Long
    Dim SifraKomitenta As Long
    Dim Rezervisi As Boolean
    Dim NewIDDok As Long
    Dim i As Integer
    Dim DatumOtvaranja As Date
    Dim NazivProizvoda As String
    Dim retValOk As Boolean
    retValOk = True
    
    BrojDokumenta = 1 + NullToZero(DLookup("[CountOfIDDok]", "BrojProfakturaPoVrstama", "[Vrsta dokumenta] = '" & "NALMA" & "'"))
    BrojDokumenta = DoChLeft(BrojDokumenta, 4, "0")
    Rezervisi = False
    IDMagacinDOK = 1
    IDRadnogNaloga = Nz(DLookup("IDRadniNalog", "EXT_Radninalozi", "IDPredmet = " & Me!IDPredmet), 0)
    SifraKomitenta = Nz(DLookup("IDKomitent", "EXT_Predmeti", "IDPredmet = " & Me!IDPredmet), 0)
    NewIDDok = KreirajNalogMagacinu(False, Date, "NALMA", BBIDProdavacZaCurrentUser(), IDRadnogNaloga, 250, IDMagacinDOK, _
                                           "Nalog magacinu za rezervaciju", SifraKomitenta, BrojDokumenta, _
                                         Rezervisi, "Beograd", Date, "-", 1, _
                                         0, "-", "-", "-", Me![IDPredmet])
    If NewIDDok <> 0 Then
        retValOk = DodajStavkeUNalogMagacinu(NewIDDok, "PlaniranjeStavkeZaKnjizenjeNALMA", ID, True)
    End If

Exit_Point:
Exit Sub

Err_Point:
MsgBox err.Description
Resume Exit_Point

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



Private Sub Form_Current()
On Error GoTo Err_Point
    ProveriZakljucavanje
    If Nz(Me!IDPlan, 0) = 0 Then Exit Sub
    DefinisiEnabledZaDugmice
    
Exit_Point:
    Exit Sub

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
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
Private Sub Form_Load()

    Call DefinisiEnabledZaDugmice

End Sub
Private Sub Form_Open(Cancel As Integer)
    DoCmd.Maximize
    DoCmd.GoToRecord , , acLast
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

Private Sub PlaniranjeNabavkeTrazi_AfterUpdate()
On Error GoTo Err_Point

   If Me.FilterOn Then
    Me.Filter = "IDPlan=" & Me![PlaniranjeNabavkeTrazi]
   Else
    PronadjiSlogNaFormi Me, "IDPlan=" & Me![PlaniranjeNabavkeTrazi]
   End If
   Me![PlaniranjeNabavkeTrazi] = Null
Exit Sub

Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "PlaniranjeNabavkeTrazi_AfterUpdate"
 Resume Exit_Point
End Sub

Private Sub Zakljucavanje_Click()
On Error GoTo Err_Zakljucavanje_Click
 

 If Not IsNull(Me!IDPlan) Then
  ZakOtkDok "PDM_Planiranje", "IDPlan", Me!IDPlan, Not Nz(Me!Zakljucano, False)
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

Public Function PlaniranjeJePredato(ByVal IDPlan As Long) As Boolean
On Error GoTo Err_Point
    Dim stSQL As String
    Dim rst As DAO.Recordset

    stSQL = "SELECT Nz(StatusPlaniranja,0) AS St" & _
            " FROM PDM_Planiranje" & _
            " WHERE IDPlan=" & CStr(IDPlan) & ";"

    Set rst = CurrentDb.OpenRecordset(stSQL, dbOpenSnapshot)

    If rst.EOF Then
        ' ako nema headera, ponašaj se restriktivno
        PlaniranjeJePredato = True
    Else
        PlaniranjeJePredato = (Nz(rst!st, 0) <> 0)
    End If

Exit_Point:
    On Error Resume Next
    If Not rst Is Nothing Then rst.Close
    Set rst = Nothing
    Exit Function

Err_Point:
    BBErrorMSG err, "NacrtJePredat"
    PlaniranjeJePredato = True   ' fail-safe
    Resume Exit_Point
End Function

Private Function OtvoriFormuSporneStavke(IDPlan As Long) As Boolean
On Error GoTo Err_Point

Dim retValOk As Boolean
retValOk = True

    If IsLoaded("PlanSporneStavke") Then
        MsgBox "Morate zatvoriti prethodni dijalog.", vbExclamation, "QBigTeh"
        retValOk = False
        Exit Function
    End If
        
    DoCmd.Hourglass True
    DoCmd.OpenForm "PlanSporneStavke"
    
    If Not IsLoaded("PlanSporneStavke") Then
        MsgBox "Forma nije otvorena.", vbExclamation, "QBigTeh"
        retValOk = False
    Else
    
        Forms!PlanSporneStavke!IDPlan = IDPlan
        
    End If
    
Exit_Point:
    DoCmd.Hourglass False
    OtvoriFormuSporneStavke = retValOk
    Exit Function

Err_Point:
    BBErrorMSG err, "OtvoriFormuSporneStavke"
    retValOk = False
    Resume Exit_Point

End Function

Public Function PostojeSporneStavke(IDPlan As Long) As Boolean

Dim rs As DAO.Recordset
Dim sql As String

sql = "SELECT TOP 1 1 FROM viewPlaniranjeOdlukePredProvera " & _
      "WHERE IDPlan=" & IDPlan

Set rs = CurrentDb.OpenRecordset(sql, dbOpenSnapshot)

PostojeSporneStavke = Not rs.EOF

rs.Close

End Function
Public Function PostojeSporneStavkeBezOdluke(IDPlan As Long) As Boolean

Dim rs As DAO.Recordset
Dim sql As String

sql = _
"SELECT TOP 1 1 " & _
"FROM PDM_PlaniranjeStavke " & _
"WHERE IDPlan=" & IDPlan & _
" AND PredProveraIDPlan IS NOT NULL " & _
" AND Nz(OdlukaAkcija,0)=0 " & _
" AND (IskljuciNabavku=0 OR IskljuciNabavku IS NULL)"

Set rs = CurrentDb.OpenRecordset(sql, dbOpenSnapshot)

PostojeSporneStavkeBezOdluke = Not rs.EOF

rs.Close
Set rs = Nothing

End Function
Public Function PlanImaTrebovanje(IDPlan As Long) As Boolean

Dim rs As DAO.Recordset
Dim sql As String

sql = _
"SELECT TOP 1 1 " & _
"FROM PDM_PlaniranjeStavke " & _
"WHERE IDPlan=" & IDPlan & _
" AND Nz(IskljuciNabavku,0)=0 " & _
" AND Nz(Rezervisano,0) + Nz(ZaNabavku,0) = Nz(PotrebnoUkupno,0)"

Set rs = CurrentDb.OpenRecordset(sql, dbOpenSnapshot)

PlanImaTrebovanje = Not rs.EOF

rs.Close
Set rs = Nothing

End Function
Public Function DefinisiEnabledZaDugmice()
On Error GoTo Err_Point

    Dim ID As Long
    
    ID = Nz(Me!IDPlan, 0)
    
    If ID = 0 Then Exit Function
    
    
    '----------------------------------------------------
    ' 1 PLAN JE VEÆ PROKNJIŽEN
    '----------------------------------------------------
    
    If PlaniranjeJePredato(ID) Then
    
        Me!DugmeDefinisiPotrebneKolicine.Enabled = False
        Me!DugmeOdlukePredProvera.Enabled = False
        Me!DugmeObrisiPlaniranjeNabavke.Enabled = False
        Me!DugmeProknjižiPlaniranje.Enabled = False
    
        Exit Function
    
    End If
    
    
    '----------------------------------------------------
    ' 2 POSTOJE SPORNE STAVKE BEZ ODLUKE
    '----------------------------------------------------
    
    If PostojeSporneStavkeBezOdluke(ID) Then
    
        Me!DugmeDefinisiPotrebneKolicine.Enabled = False
        Me!DugmeOdlukePredProvera.Enabled = True
        Me!DugmeProknjižiPlaniranje.Enabled = False
        Me!DugmeObrisiPlaniranjeNabavke.Enabled = True
    
        Exit Function
    
    End If
    
    
    '----------------------------------------------------
    ' 3 SPORNE STAVKE POSTOJE ALI SU REŠENE
    '----------------------------------------------------
    
    If PostojeSporneStavke(ID) Then
    
        'If PlanImaTrebovanje(ID) Then
        
       '     Me!DugmeProknjižiPlaniranje.Enabled = True
       ' Else
        
        '    Me!DugmeProknjižiPlaniranje.Enabled = False
        'End If
        If PlanJeSpremanZaProknjizavanje(ID) Then
            Me!DugmeProknjižiPlaniranje.Enabled = True
        Else
            Me!DugmeProknjižiPlaniranje.Enabled = False
        End If
    
        Me!DugmeDefinisiPotrebneKolicine.Enabled = False
        Me!DugmeOdlukePredProvera.Enabled = False
        Me!DugmeObrisiPlaniranjeNabavke.Enabled = True
    
        Exit Function
    
    Else
    
    
        '----------------------------------------------------
        ' 4 NEMA SPORNIH STAVKI
        '----------------------------------------------------
        If PlanJeSpremanZaProknjizavanje(ID) Then
            Me!DugmeProknjižiPlaniranje.Enabled = True
            Me!DugmeDefinisiPotrebneKolicine.Enabled = False
            Me!DugmeOdlukePredProvera.Enabled = False
            Me!DugmeObrisiPlaniranjeNabavke.Enabled = True
        Else
            Me!DugmeProknjižiPlaniranje.Enabled = False
            Me!DugmeDefinisiPotrebneKolicine.Enabled = True
            Me!DugmeOdlukePredProvera.Enabled = False
            Me!DugmeObrisiPlaniranjeNabavke.Enabled = True
        End If
        
        
    End If

Exit Function


Err_Point:

MsgBox err.Description, vbExclamation, "Greška"

End Function
Public Function PlanJeSpremanZaProknjizavanje(IDPlan As Long) As Boolean

Dim rs As DAO.Recordset
Dim sql As String

sql = _
"SELECT TOP 1 1 " & _
"FROM PDM_PlaniranjeStavke " & _
"WHERE IDPlan=" & IDPlan & _
" AND Nz(IskljuciNabavku,0)=0 " & _
" AND Nz(PotrebnoUkupno,0)>0 " & _
" AND Nz(Rezervisano,0)+Nz(ZaNabavku,0)<Nz(PotrebnoUkupno,0)"

Set rs = CurrentDb.OpenRecordset(sql, dbOpenSnapshot)

PlanJeSpremanZaProknjizavanje = rs.EOF

rs.Close
Set rs = Nothing

End Function

