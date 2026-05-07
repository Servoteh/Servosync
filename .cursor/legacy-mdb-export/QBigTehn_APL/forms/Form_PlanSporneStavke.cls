VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PlanSporneStavke"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit


Private Sub Form_Close()
On Error Resume Next
    If CurrentProject.AllForms("PlaniranjeNabavke").IsLoaded Then
        Forms!PlaniranjeNabavke!PlaniranjeNabavkeStavke.Requery
        Forms!PlaniranjeNabavke.DefinisiEnabledZaDugmice
    End If
End Sub

Private Sub Form_Current()

    ProveriOdluke
    Me.cmdPrimeniNaSve.Enabled = (Nz(Me.cmbOdlukaSve.Value, 0) <> 0)

End Sub


Private Sub cmbOdlukaSve_AfterUpdate()

    Me.cmdPrimeniNaSve.Enabled = (Nz(Me.cmbOdlukaSve.Value, 0) <> 0)

End Sub


Public Function ProveriOdluke()

    Me.DugmePrimeniOdluke.Enabled = _
        DecisionsPlan_AllResolved(Me!PlanSporneStavkePodforma.Form)

End Function


Private Sub DugmePrimeniOdluke_Click()

On Error GoTo Err_Point

    Dim retValOk As Boolean

    retValOk = PrimeniOdlukePlaniranje_RowByRow(Me!IDPlan)

    If retValOk Then
        DoCmd.Close acForm, Me.Name
    End If

Exit_Point:

    DoCmd.Hourglass False
    Exit Sub

Err_Point:

    BBErrorMSG err, "DugmePrimeniOdluke_Click"
    Resume Exit_Point

End Sub

Public Function PrimeniOdlukePlaniranje(ByVal pIDPlan As Long) As Boolean
On Error GoTo Err_Point

    Dim db As DAO.Database
    Dim sql1 As String, sql2 As String, sql3 As String
    Dim retValOk As Boolean

    Set db = CurrentDb

    BeginTrans

    ' 1) ISKLJUÈI (OdlukaAkcija=1): IskljuciNabavku=True, sve 0
    sql1 = _
      "UPDATE (PDM_PlaniranjeStavke AS s " & _
      "INNER JOIN tmp_PlanSporneStavke AS d ON d.IDPlanStavka = s.IDPlanStavka) " & _
      "SET s.IskljuciNabavku = True, " & _
      "    s.OdlukaAkcija = 1, " & _
      "    s.Rezervisano = 0, " & _
      "    s.ZaNabavku = 0 " & _
      "WHERE s.IDPlan = " & pIDPlan & " AND d.OdlukaAkcija=1;"
    db.Execute sql1, dbFailOnError

    ' 2) NARUÈI SVE (OdlukaAkcija=2): samo oznaèi odluku; SP æe izraèunati rezervisano/za nabavku
    sql2 = _
      "UPDATE (PDM_PlaniranjeStavke AS s " & _
      "INNER JOIN tmp_PlanSporneStavke AS d ON d.IDPlanStavka = s.IDPlanStavka) " & _
      "SET s.IskljuciNabavku = False, " & _
      "    s.OdlukaAkcija = 2 " & _
      "WHERE s.IDPlan = " & pIDPlan & " AND d.OdlukaAkcija=2;"
    db.Execute sql2, dbFailOnError

    ' 3) DOPUNA (OdlukaAkcija=3): samo oznaèi odluku; SP æe izraèunati rezervisano/za nabavku
    sql3 = _
      "UPDATE (PDM_PlaniranjeStavke AS s " & _
      "INNER JOIN tmp_PlanSporneStavke AS d ON d.IDPlanStavka = s.IDPlanStavka) " & _
      "SET s.IskljuciNabavku = False, " & _
      "    s.OdlukaAkcija = 3 " & _
      "WHERE s.IDPlan = " & pIDPlan & " AND d.OdlukaAkcija=3;"
    db.Execute sql3, dbFailOnError

    ' 4) SP ponovo raèuna Rezervisano i ZaNabavku za ceo plan
    '    (ovde obavezno pozovi preko tvoje ADO_ExecSP ili ADO_ExecSQL, NE preko db.Execute ako SP nije "passthrough")
    retValOk = ADO_ExecSP(CNN_CurrentDataBase, "spPDM_Planiranje_PopuniRezervisanoINabavku", pIDPlan)
    If Not retValOk Then err.Raise vbObjectError + 513, , "Poziv SP-a nije uspeo."

    CommitTrans

    PrimeniOdlukePlaniranje = True
    Exit Function

Err_Point:
    On Error Resume Next
    Rollback
    PrimeniOdlukePlaniranje = False
    Debug.Print sql1
Debug.Print sql2
Debug.Print sql3
    BBErrorMSG err, "PrimeniOdlukePlaniranje"
End Function

Public Function PrimeniOdlukuNaSveStavke(ByVal pOdluka As Long) As Boolean

On Error GoTo Err_Point

    Dim db As DAO.Database
    Dim sql As String

    Set db = CurrentDb

    BeginTrans

    sql = _
    "UPDATE tmp_PlanSporneStavke " & _
    "SET OdlukaAkcija = " & pOdluka

    db.Execute sql, dbFailOnError

    CommitTrans

    PrimeniOdlukuNaSveStavke = True

    Exit Function

Err_Point:

    Rollback
    PrimeniOdlukuNaSveStavke = False
    BBErrorMSG err, "PrimeniOdlukuNaSveStavke"

End Function


Private Sub cmdPrimeniNaSve_Click()

On Error GoTo Err_Point

    Dim odluka As Long

    odluka = CLng(Nz(Me.cmbOdlukaSve.Value, 0))

    If odluka = 0 Then
        MsgBox "Izaberite odluku koju želite da primenite na sve stavke.", _
               vbExclamation, "Masovna odluka"
        Exit Sub
    End If

    If MsgBox("Ovom akcijom æete postaviti odluku za SVE stavke." & vbCrLf & _
              "Da li ste sigurni?", _
              vbQuestion + vbYesNo, "Potvrda") = vbNo Then Exit Sub

    If PrimeniOdlukuNaSveStavke(odluka) Then
    
        Me!PlanSporneStavkePodforma.Form.Requery
        ProveriOdluke
        
    End If

Exit Sub

Err_Point:

    BBErrorMSG err, "cmdPrimeniNaSve_Click"

End Sub

Private Function DecisionsPlan_AllResolved(ByVal frm As Form) As Boolean

    On Error GoTo Eh
    
    Dim rs As DAO.Recordset
    Dim need As Boolean
    Dim excl As Boolean
    Dim hasAction As Boolean
    Dim v As Variant

    Set rs = frm.RecordsetClone
    
    If (rs.BOF And rs.EOF) Then
        DecisionsPlan_AllResolved = True
        GoTo clean
    End If

    rs.MoveFirst
    
    Do While Not rs.EOF
    
        need = (Nz(rs!NeedsDecision, 0) <> 0)
        
        If need Then
        
            excl = (Nz(rs!IskljuciNabavku, 0) <> 0)
            
            v = rs!OdlukaAkcija
            
            hasAction = (Not IsNull(v) And Nz(v, 0) <> 0)

            If Not (excl Or hasAction) Then
            
                DecisionsPlan_AllResolved = False
                GoTo clean
                
            End If
            
        End If
        
        rs.MoveNext
        
    Loop

    DecisionsPlan_AllResolved = True

clean:

    On Error Resume Next
    rs.Close
    Set rs = Nothing
    
    Exit Function

Eh:

    DecisionsPlan_AllResolved = False
    Resume clean

End Function
Public Function PrimeniOdlukePlaniranje_RowByRow(ByVal pIDPlan As Long) As Boolean
On Error GoTo Err_Point

    Dim db As DAO.Database
    Dim rs As DAO.Recordset
    
    Dim IDPlanStavka As Long
    Dim odluka As Long
    
    Dim kolicinaZaNab As Double
    Dim prethodno As Double
    Dim cilj As Double
    
    Dim whereOne As String
    Dim OK As Boolean
    
    Set db = CurrentDb
    
    ' Uzimamo samo one gde je doneta odluka (1/2/3)
    Set rs = db.OpenRecordset( _
        "SELECT IDPlanStavka, OdlukaAkcija, KolicinaZaNabavku, PrethodnoPlaniraneKolicine " & _
        "FROM tmp_PlanSporneStavke " & _
        "WHERE Nz(OdlukaAkcija,0)<>0;", _
        dbOpenSnapshot)
    
    If rs.BOF And rs.EOF Then
        PrimeniOdlukePlaniranje_RowByRow = True
        GoTo clean
    End If
    
    rs.MoveFirst
    Do While Not rs.EOF
    
        IDPlanStavka = CLng(rs!IDPlanStavka)
        odluka = CLng(Nz(rs!OdlukaAkcija, 0))
        
        kolicinaZaNab = CDbl(Nz(rs!KolicinaZaNabavku, 0))
        prethodno = CDbl(Nz(rs!PrethodnoPlaniraneKolicine, 0))
        
        ' Gde update-ujes bas tu stavku, i dodatno osiguras IDPlan
        whereOne = "IDPlanStavka=" & IDPlanStavka & " AND IDPlan=" & pIDPlan
        
        '--- ciljna (konacna) potrebna kolicina za ovu stavku, prema odluci
        Select Case odluka
            Case 1 ' Iskljuci
                cilj = 0
                OK = True
                OK = OK And ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "IskljuciNabavku", SQL_Bit(1), whereOne)
                OK = OK And ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "OdlukaAkcija", SQL_Long(1), whereOne)
                
                ' reset polja koja uticu na preracun
                OK = OK And ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "PotrebnoUkupno", SQL_Num(0), whereOne)
                OK = OK And ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "RucnaKolicina", "NULL", whereOne)
                OK = OK And ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "JeRucnaStavka", SQL_Bit(0), whereOne)
                
            Case 2 ' Nabavi ponovo (cela kolicina)
                cilj = kolicinaZaNab
                OK = True
                OK = OK And ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "IskljuciNabavku", SQL_Bit(0), whereOne)
                OK = OK And ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "OdlukaAkcija", SQL_Long(2), whereOne)
                
                ' postavi potrebnu kolicinu koju SP treba da raspodeli na rezervisano/zanabavku
                OK = OK And ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "PotrebnoUkupno", SQL_Num(cilj), whereOne)
                OK = OK And ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "RucnaKolicina", SQL_Num(cilj), whereOne)
                OK = OK And ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "JeRucnaStavka", SQL_Bit(1), whereOne)
                
            Case 3 ' Nabavi razliku
                cilj = kolicinaZaNab - prethodno
                If cilj < 0 Then cilj = 0
                
                OK = True
                OK = OK And ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "IskljuciNabavku", SQL_Bit(0), whereOne)
                OK = OK And ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "OdlukaAkcija", SQL_Long(3), whereOne)
                
                OK = OK And ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "PotrebnoUkupno", SQL_Num(cilj), whereOne)
                OK = OK And ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "RucnaKolicina", SQL_Num(cilj), whereOne)
                OK = OK And ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "JeRucnaStavka", SQL_Bit(1), whereOne)
                
            Case Else
                OK = True ' ignore
        End Select
        
        If Not OK Then
            err.Raise vbObjectError + 778, , "Nije uspelo ažuriranje stavke IDPlanStavka=" & IDPlanStavka
        End If
        
        rs.MoveNext
    Loop
    
    '--- Na kraju: SP radi preracun Rezervisano i ZaNabavku za ceo plan
    If Not ADO_ExecSP(CNN_CurrentDataBase, "spPDM_Planiranje_PopuniRezervisanoINabavku", pIDPlan) Then
        err.Raise vbObjectError + 779, , "SP spPDM_Planiranje_PopuniRezervisanoINabavku nije uspeo."
    End If
    
    PrimeniOdlukePlaniranje_RowByRow = True
    
clean:
    On Error Resume Next
    If Not rs Is Nothing Then rs.Close
    Set rs = Nothing
    Set db = Nothing
    Exit Function

Err_Point:
    PrimeniOdlukePlaniranje_RowByRow = False
    BBErrorMSG err, "PrimeniOdlukePlaniranje_RowByRow"
    Resume clean
End Function

