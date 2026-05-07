VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_OdlukePredProvera"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Public Function Decisions_AllResolved(ByVal frm As Form) As Boolean
    On Error GoTo Eh
    Dim rs As DAO.Recordset
    Dim need As Boolean, excl As Boolean, hasAction As Boolean
    Dim v As Variant

    Set rs = frm.RecordsetClone
    If (rs.BOF And rs.EOF) Then
        Decisions_AllResolved = True
        GoTo clean
    End If

    rs.MoveFirst
    Do While Not rs.EOF
        need = (Nz(rs.Fields("NeedsDecision").Value, 0) <> 0)
        If need Then
            excl = (Nz(rs.Fields("IskljuciPrimopredaju").Value, 0) <> 0)
            v = Null
            If Not IsError(rs.Fields("OdlukaAkcija").Value) Then v = rs.Fields("OdlukaAkcija").Value
            hasAction = (Not IsNull(v) And Nz(v, 0) <> 0)

            If Not (excl Or hasAction) Then
                Decisions_AllResolved = False
                GoTo clean
            End If
        End If
        rs.MoveNext
    Loop

    Decisions_AllResolved = True
clean:
    On Error Resume Next
    rs.Close: Set rs = Nothing
    Exit Function
Eh:
    Decisions_AllResolved = False
    Resume clean
End Function

Private Sub cmbOdlukaSve_AfterUpdate()
    Me.cmdPrimeniNaSve.Enabled = (Nz(Me.cmbOdlukaSve.Value, 0) <> 0)
End Sub

Private Sub DugmePrimeniOdluke_Click()
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim stSQL As String
    Dim stMsg As String
    
    retValOk = PrimeniOdlukePredProvera(Me!IDNacrtPrim)
     
    If retValOk Then
       DoCmd.Close acForm, "OdlukePredProvera"
    End If
   
Exit_Point:
    DoCmd.SetWarnings True
    DoCmd.Hourglass False
Exit Sub

Err_Point:
    BBErrorMSG err, "DugmePrimeniOdluke"
    retValOk = False
    Resume Exit_Point

End Sub

Private Sub Form_Current()
    ProveriOdluke
    Me.cmdPrimeniNaSve.Enabled = (Nz(Me.cmbOdlukaSve.Value, 0) <> 0)
End Sub
Public Function ProveriOdluke()
    Me.DugmePrimeniOdluke.Enabled = Decisions_AllResolved(Me!OdlukePredProveraPodforma.Form)
End Function
Public Function PrimeniOdlukePredProvera(ByVal pIDNacrtPrim As Long) As Boolean
On Error GoTo Err_Point
    Dim ws As DAO.Workspace
    Dim db As DAO.Database
    Dim sql1 As String, sql2 As String, sql3 As String

    Set ws = DBEngine.Workspaces(0)
    Set db = CurrentDb

    ws.BeginTrans

    ' 1) ISKLJUÈI (OdlukaAkcija=1): IskljuciPrimopredaju=True, KolicinaZaIzradu=0
    sql1 = _
      "UPDATE (NacrtPrimopredajeStavke AS s " & _
      "INNER JOIN tmp_OdlukePredProvera AS d ON d.IDNacrtStavka = s.IDNacrtStavka) " & _
      "SET s.IskljuciPrimopredaju = " & SQLFormatBoolean(True) & "," & _
      "    s.OdlukaAkcija = 1, " & _
      "    s.KolicinaZaIzradu = 0, " & _
      "    s.DIVOdluke = " & SQLFormatDatumIVreme(Now()) & _
      "WHERE s.IDNacrtPrim = " & pIDNacrtPrim & " AND Nz(d.OdlukaAkcija,0)=1;"
    db.Execute sql1, dbFailOnError

    ' 2) PREDAJ PONOVO (OdlukaAkcija=2): ukljuèi + postavi kolièinu na ciljnu iz d.KolicinaZaIzradu
    sql2 = _
      "UPDATE (NacrtPrimopredajeStavke AS s " & _
      "INNER JOIN tmp_OdlukePredProvera AS d ON d.IDNacrtStavka = s.IDNacrtStavka) " & _
      "SET s.IskljuciPrimopredaju = " & SQLFormatBoolean(False) & "," & _
      "    s.OdlukaAkcija = 2, " & _
      "    s.KolicinaZaIzradu = Nz(d.KolicinaZaIzradu, s.KolicinaZaIzradu), " & _
      "    s.DIVOdluke = " & SQLFormatDatumIVreme(Now()) & _
      "WHERE s.IDNacrtPrim = " & pIDNacrtPrim & " AND Nz(d.OdlukaAkcija,0)=2;"
    db.Execute sql2, dbFailOnError

    ' 3) DOPUNI (OdlukaAkcija=3): ukljuèi + kolièina = Max(0, cilj - veæ predate)
    sql3 = _
      "UPDATE (NacrtPrimopredajeStavke AS s " & _
      "INNER JOIN tmp_OdlukePredProvera AS d ON d.IDNacrtStavka = s.IDNacrtStavka) " & _
      "SET s.IskljuciPrimopredaju = " & SQLFormatBoolean(False) & "," & _
      "    s.OdlukaAkcija = 3, " & _
      "    s.KolicinaZaIzradu = IIf(Nz(d.KolicinaZaIzradu,0) - Nz(d.PrethodnoPredateKolicine,0) > 0, " & _
      "                             Nz(d.KolicinaZaIzradu,0) - Nz(d.PrethodnoPredateKolicine,0), 0), " & _
      "    s.DIVOdluke = " & SQLFormatDatumIVreme(Now()) & _
      "WHERE s.IDNacrtPrim = " & pIDNacrtPrim & " AND Nz(d.OdlukaAkcija,0)=3;"
    db.Execute sql3, dbFailOnError

    ws.CommitTrans
    PrimeniOdlukePredProvera = True

    On Error Resume Next
    Forms!NacrtPrimopredaje!Nacrt_Stavke.Requery
    On Error GoTo 0
    Exit Function

Err_Point:
    On Error Resume Next
    If Not ws Is Nothing Then ws.Rollback
    PrimeniOdlukePredProvera = False
    BBErrorMSG err, "PrimeniOdlukePredProvera"
End Function
Private Sub Form_Close()
    On Error Resume Next
    If CurrentProject.AllForms("NacrtPrimopredaje").IsLoaded Then
        Forms!NacrtPrimopredaje!Nacrt_Stavke.Requery
        Forms!NacrtPrimopredaje.DefinisiEnabledZaDugmice
    End If
End Sub
Public Function PrimeniOdlukuNaSveStavke(ByVal pOdluka As Long) As Boolean
On Error GoTo Err_Point

    Dim db As DAO.Database
    Dim sql As String

    Set db = CurrentDb

    BeginTrans

    ' pOdluka:
    ' 0 = Bez odluke
    ' 1 = Iskljuèi
    ' 2 = Predaj ponovo
    ' 3 = Predaj kao dopunu
    
    sql = ""
    sql = sql & "UPDATE tmp_OdlukePredProvera "
    sql = sql & " SET OdlukaAkcija = " & pOdluka & ";"
    'sql = sql & " WHERE IDNacrtPrim = " & pIDNacrtPrim & ";"

    db.Execute sql, dbFailOnError

    CommitTrans
    PrimeniOdlukuNaSveStavke = True

    Exit Function

Err_Point:
    On Error Resume Next
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

    If MsgBox("Ovom akcijom æete postaviti odluku za SVE stavke u nacrtu." & vbCrLf & _
              "Da li ste sigurni?", _
              vbQuestion + vbYesNo, "Potvrda") = vbNo Then
        Exit Sub
    End If

    If PrimeniOdlukuNaSveStavke(odluka) Then
        Me!OdlukePredProveraPodforma.Form.Requery
        ProveriOdluke
    End If

    Exit Sub

Err_Point:
    BBErrorMSG err, "cmdPrimeniNaSve_Click"
End Sub

