VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_MRP_Potreba"
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
    
    retValOk = True
    
    pZakljucano = Nz(ADO_Lookup(CNN_CurrentDataBase, "Zakljucano", "MRP_Potrebe", "[IDPotreba]=" & Me!IDPotreba), False)
    If pZakljucano Then
        MsgBox "Dokument planiranja nabavka je " & Srpski("zakljucan")
        Exit Sub
    End If
    
    answer = MsgBox("Ovim brišete kompletni dokument planiranja nabavke!!!" & Chr(13) & " Da li nastavljate BRISANJE?", vbYesNo + vbCritical + vbDefaultButton2, "Brisanje nacrta primopredaje")
    If answer = vbYes Then
        retValOk = ADO_ExecSP(BBCFG.CNNString, "spMRP_ObrisiPotrebu", Me!IDPotreba)
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
    
    ID = Nz(Me!IDPlan, 0)
    If ID = 0 Then Exit Sub
    
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
    BrojDokumenta = "TEST"
    Rezervisi = False
    IDMagacinDOK = 1
    IDRadnogNaloga = Nz(DLookup("IDRadniNalog", "EXT_Radninalozi", "IDPredmet = " & Me!IDPredmet), 0)
    SifraKomitenta = Nz(DLookup("IDKomitent", "EXT_Predmeti", "IDPredmet = " & Me!IDPredmet), 0)
    NewIDDok = KreirajNalogMagacinu(False, Date, "NALMA", BBIDProdavacZaCurrentUser(), IDRadnogNaloga, 250, IDMagacinDOK, _
                                           "Nalog magacinu za rezervaciju", SifraKomitenta, BrojDokumenta, _
                                         Rezervisi, "Beograd", Date, "-", 1, _
                                         0, "-", "-", "-", Me![IDPredmet])
    ' Dodavanje stavki za novi dokument
    'If F_Prof_KoeficijentRezervacije() <> 0 Then
        DodajStavkeUNalogMagacinu NewIDDok, "PlaniranjeStavkeZaKnjizenjeNALMA", ID, True
    'End If

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



Private Sub Form_BeforeUpdate(Cancel As Integer)
    Me!DIVIzmena = Now()
    Me!DIVIzmenaKorisnik = CurrentUser()
End Sub

Private Sub Form_Current()
On Error GoTo Err_Point
    ProveriZakljucavanje
    If Nz(Me!IDPotreba, 0) = 0 Then Exit Sub
    'DefinisiEnabledZaDugmice
    
Exit_Point:
    Exit Sub

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
End Sub
Private Sub DugmeNoviSlog_Click()
On Error GoTo Err_DugmeNoviSlog_Click


    DoCmd.GoToRecord , , acNewRec
    Me.DatumPotrebe = Date
    Me.Izvor = 2
    DoCmd.GoToControl "IDPredmet"
    
Exit_DugmeNoviSlog_Click:
    Exit Sub

Err_DugmeNoviSlog_Click:
    MsgBox err.Description
    Resume Exit_DugmeNoviSlog_Click
    
End Sub
Private Sub Form_Load()

    'Call DefinisiEnabledZaDugmice

End Sub

Private Sub Form_Open(Cancel As Integer)
    DoCmd.Maximize
    If Me.OpenArgs = "NEW" Then
        Me.DataEntry = True
    End If

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

Private Sub IDPotrebaTrazi_AfterUpdate()
On Error GoTo Err_Point

   If Me.FilterOn Then
    Me.Filter = "IDPotreba=" & Me![IDPotrebaTrazi]
   Else
    PronadjiSlogNaFormi Me, "IDPotreba=" & Me![IDPotrebaTrazi]
   End If
   Me![IDPotrebaTrazi] = Null
Exit Sub

Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "IDPotrebaTrazi_AfterUpdate"
 Resume Exit_Point
End Sub

Private Sub Zakljucavanje_Click()
On Error GoTo Err_Zakljucavanje_Click
 

 If Not IsNull(Me!IDPotreba) Then
  ZakOtkDok "MRP_Potrebe", "IDPotreba", Me!IDPotreba, Not Nz(Me!Zakljucano, False)
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

