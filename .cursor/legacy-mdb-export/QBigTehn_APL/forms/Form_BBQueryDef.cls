VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BBQueryDef"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Dim AktivanObjekt As Object
Dim aktivnaKontrola As Object
Const imeTMPupita = "~ODBC_Tmp~"
Public Function SnimiSlog()
On Error Resume Next

    DoCmd.RunCommand acCmdSaveRecord
End Function
Private Function BB_NapraviTabeluSvihKontrolaNaFormi(aktForma As Form) As Boolean
On Error GoTo err_Napravi

    Dim BigBit As DAO.Database
    Dim TabKontrole As DAO.Recordset
    Dim ctl As control
    Dim retVal As Boolean
    
    retVal = True
    DoCmd.SetWarnings False
    DoCmd.OpenQuery "tmp_T_KontroleNaFormi_DELETE"
    DoCmd.SetWarnings True
    Set BigBit = CurrentDb
    Set TabKontrole = BigBit.OpenRecordset("tmp_T_KontroleNaFormi")
    
    
    For Each ctl In aktForma.Controls
         On Error GoTo err_Napravi
          TabKontrole.AddNew
          TabKontrole!ImeForme = aktForma.Name
          TabKontrole!ImeKontrole = ctl.Name
          TabKontrole!TipKontrole = ctl.ControlType
         On Error Resume Next
          'TabKontrole!TabOrder = ctl.TabOrder
          'aktForma.Section("Detail").SetTabOrder
          TabKontrole!TabStop = ctl.TabStop
          TabKontrole.Update
    Next
exit_Napravi:
    
    Set TabKontrole = Nothing
    Set BigBit = Nothing
    BB_NapraviTabeluSvihKontrolaNaFormi = retVal
    DoCmd.SetWarnings True
Exit Function
err_Napravi:
   If err.Number = 91 Then
   Else
    MsgBox err.Description & vbCrLf & "Tabela kontrola nije napravljena.", vbExclamation, "QMegaTeh"
   End If
    retVal = False
 Resume exit_Napravi
End Function
Private Sub AccParFormName_DblClick(Cancel As Integer)

 Dim TrebaZatvoritiFormu As Boolean
 Dim ImeForme As String
 
 ImeForme = Me!AccParFormName
 TrebaZatvoritiFormu = False
 
 If Not IsLoaded(ImeForme) Then
 TrebaZatvoritiFormu = True
  DoCmd.OpenForm ImeForme, acDesign, , , , acHidden
 End If
 
 Forms![BBQueryDef]![BBQueryParDef].Form![ComboAccMapValue].RowSource = DRST_KontroleNaFormi(Forms(ImeForme)).GetString(, , ";", ";")
 ' BB_NapraviTabeluSvihKontrolaNaFormi Forms(ImeForme)
 
 If TrebaZatvoritiFormu Then
  DoCmd.Close acForm, ImeForme, acSavePrompt
 End If
 'Forms![BBQueryDef]![BBQueryParDef].Form![ComboAccMapValue].Requery
End Sub

Private Sub AccQueryName_DblClick(Cancel As Integer)
 On Error Resume Next
    DoCmd.OpenQuery Me!AccQueryName, acViewDesign
    If err Then
      MsgBox "Ne postoji memorisan Access Query" & vbCrLf & vbCrLf & "[" & Me!AccQueryName & "]", vbExclamation, "QMegaTeh"
     err.Clear
    End If
End Sub

Private Sub AccRSFormName_DblClick(Cancel As Integer)
On Error GoTo Err_Point
    
    DoCmd.OpenForm Me!AccRSFormName, acDesign

Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "DoCmd.OpenForm " & Me!AccRSFormName & ", acDesign"
 Resume Exit_Point
End Sub

Private Sub Command59_Click()
    EditujUpit Me!SQLText
End Sub

Private Sub Dugme_CreateDeclare_Click()
 On Error Resume Next
    SetClipboard BBQuerdefPar_CreateDeclarePart(Me!QueryName)
End Sub

Private Sub Dugme_CreateScript_Click()
    Dim stSCRIPT As String
    
    stSCRIPT = "USE " & GetParFromCnnString("DATABASE=", CNN_CurrentDataBase) & vbCrLf
    stSCRIPT = stSCRIPT & "GO" & vbCrLf & vbCrLf
    stSCRIPT = stSCRIPT & BBQuerdefPar_CreateDeclarePart(Me!QueryName)
    stSCRIPT = stSCRIPT & vbCrLf
    If Me!ProcType = "SP" Then
        stSCRIPT = stSCRIPT & PassTroughQueryEvalAllPar(Me!QueryName, True) & vbCrLf
    Else
        stSCRIPT = stSCRIPT & Me!SQLText & vbCrLf
    End If
    stSCRIPT = stSCRIPT & vbCrLf
    stSCRIPT = stSCRIPT & "GO" & vbCrLf
    SetClipboard stSCRIPT
End Sub

'Private Sub AccSQLText_DblClick(Cancel As Integer)
'   EditujUpit Me!AccSQLText, False
'End Sub
Private Sub DugmeKreirajParametre_Click()
On Error GoTo Err_DugmeKreirajParametre_Click

 DoCmd.Hourglass True
    If Me!ProcType = "SQL" Then
      'DodajACCParametreUTabelu Me!AccSQLText, Me!QueryName
      DodajACCParametreUTabelu Me!SQLText, Me!QueryName
    Else
     DodajODBCParametreUTabelu Me!ProcName, Me!QueryName
    End If
    Me!BBQueryParDef.Requery

Exit_DugmeKreirajParametre_Click:
  On Error Resume Next
  DoCmd.Hourglass False
Exit Sub

Err_DugmeKreirajParametre_Click:
    DoCmd.Hourglass False
    MsgBox err.Description
    Resume Exit_DugmeKreirajParametre_Click
    
End Sub

Private Sub DugmeLoadFromAccQuery_Click()
On Error GoTo Err_DugmeLoadFromQuery_Click
    Dim stQueryName As String
    
    stQueryName = Me!AccQueryName
    Me!AccSQLText = CurrentDb.QueryDefs(stQueryName).sql
    

Exit_DugmeLoadFromQuery_Click:
    Exit Sub

Err_DugmeLoadFromQuery_Click:
    MsgBox err.Description
    Resume Exit_DugmeLoadFromQuery_Click
    
End Sub
Private Function PassTroughQueryMakeSQLTextFromTDef_NETREBA() As String
On Error GoTo Err_Point
   Dim ErrorCode As Long
   Dim stRetValSQLText As String
   
   If Me!ProcType = "SP" Then
    stRetValSQLText = PassTroughQueryMakeSQLTextFromTDefSProc(Me!QueryName, False, ErrorCode)
   ElseIf Me!ProcType = "SQL" Then
    stRetValSQLText = PassTroughQueryMakeSQLTextFromTDefSQLText(Me!QueryName, False, ErrorCode)
   ElseIf Me!ProcType = "UDF" Then
    stRetValSQLText = PassTroughQueryMakeSQLTextFromTDefUDF(Me!QueryName, False, ErrorCode)
   Else
    stRetValSQLText = "Nepoznat ProcType -> (" & Nz(Me!ProcType, "") & ")"
    MsgBox stRetValSQLText, vbExclamation, "QMegaTeh"
   End If

Exit_Point:
On Error Resume Next
    PassTroughQueryMakeSQLTextFromTDef_NETREBA = stRetValSQLText
Exit Function

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
    
End Function
Private Sub DugmeNapraviSQLText_Click()
On Error GoTo Err_NapraviSQLText_Click
   Dim ErrorCode As Long
   Dim stSQLText As String
   
   'If Me!ProcType = "SP" Then
   ' Me!SQLText = PassTroughQueryMakeSQLTextFromTDefSProc(Me!QueryName, False, ErrorCode)
   'ElseIf Me!ProcType = "SQL" Then
   ' Me!SQLText = PassTroughQueryMakeSQLTextFromTDefSQLText(Me!QueryName, False, ErrorCode)
   'ElseIf Me!ProcType = "UDF" Then
   ' Me!SQLText = PassTroughQueryMakeSQLTextFromTDefUDF(Me!QueryName, False, ErrorCode)
   'Else
   ' MsgBox "Nepoznat ProcType!", vbExclamation, "QMegaTeh"
   'End If
   
   If Not BBPitanje("Da li ste sigurni?") Then
     Exit Sub
   End If
   
   stSQLText = PassTroughQueryMakeSQLTextFromTDef(Me!QueryName, False, ErrorCode)
   If ErrorCode = 0 Then
    Me!SQLText = stSQLText
    DoCmd.RunCommand acCmdSave
    Me!BBQueryParDef.Requery
   Else
    MsgBox "SQLText nije memorisan", vbCritical, "QBigTeh"
   End If

Exit_NapraviSQLText_Click:
On Error Resume Next

Exit Sub

Err_NapraviSQLText_Click:
    BBErrorMSG err, "DugmeNapraviSQLText_Click"
    Resume Exit_NapraviSQLText_Click
    
End Sub

Private Sub DugmeOpenAccQuery_Click()
On Error GoTo Err_DugmeExecute_Click
 Dim qDef As New QueryDef

 If AccQuerySave(TmpAccQuery, Me!SQLText) Then
  DoCmd.OpenQuery TmpAccQuery
 Else
  MsgBox "Nije moguæe uraditi" & vbCrLf & "DoCmd.OpenQuery " & TmpAccQuery, vbExclamation, "QMegaTeh"
 End If
Exit_DugmeExecute_Click:
    Exit Sub

Err_DugmeExecute_Click:
    MsgBox err.Description
    Resume Exit_DugmeExecute_Click
End Sub

Private Sub DugmeOpenPassTroughQuery_Click()
On Error GoTo Err_DugmeExecute_Click
 Dim qDef As New QueryDef

 If PassTroughQuerySave(imeTMPupita, Me!SQLText, F_CNNString(), False) Then
  DoCmd.OpenQuery imeTMPupita
 Else
  MsgBox "Nije moguæe uraditi" & vbCrLf & "DoCmd.OpenQuery " & imeTMPupita & "", vbExclamation, "QMegaTeh"
 End If
Exit_DugmeExecute_Click:
    Exit Sub

Err_DugmeExecute_Click:
    MsgBox err.Description
    Resume Exit_DugmeExecute_Click
    
End Sub
Private Sub EditujUpit(ByVal SQLText As Variant, Optional PassTrough = True)
On Error GoTo Err_Point
Dim retVal
Dim qDef As New QueryDef
'Dim imeTMPupita As String
'imeTMPupita = "~ODBC_Tmp~"

On Error Resume Next
    If CurrentDb.QueryDefs(imeTMPupita).Name = imeTMPupita Then
        CurrentDb.QueryDefs.Delete imeTMPupita
    End If
    If Nz(SQLText, "") = "" Then
        SQLText = "SELECT 1;"
    End If
On Error GoTo Err_Point
    qDef.Name = imeTMPupita
    If PassTrough Then
     qDef.Connect = F_CNNString("ODBC")
    End If
    qDef.sql = SQLText
    CurrentDb.QueryDefs.Append qDef
    CurrentDb.QueryDefs.Refresh
    Rem Set qDef = CurrentDb.CreateQueryDef(imeTMPupita, Upit)
    DoCmd.OpenQuery imeTMPupita, acViewDesign
    
Exit_Point:
 On Error Resume Next
 Set qDef = Nothing
 Exit Sub
Err_Point:
 MsgBox err.Description
 Resume Exit_Point
End Sub

Private Sub DugmePopraviParametre_Click()
    Me!SQLText = PopraviBBQueryDefZaUDF(Me!QueryName)
End Sub

Private Sub DugmeSaveAccQueryToDBDef_Click()
On Error GoTo Err_DugmeSaveQueryToDBDef_Click

    Dim OK As Boolean
    
    OK = AccQuerySave(Me!AccQueryName, Me!AccSQLText)

Exit_DugmeSaveQueryToDBDef_Click:
    Exit Sub

Err_DugmeSaveQueryToDBDef_Click:
    MsgBox err.Description
    Resume Exit_DugmeSaveQueryToDBDef_Click
    
End Sub

Private Sub DugmeStop_Click()
    On Error GoTo Err_DugmeStop_Click


   ' If Me.Dirty Then Me.Dirty = False
    DoCmd.Close

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
End Sub

Private Sub Form_BeforeUpdate(Cancel As Integer)
    Me!PoslednjaIzmena = Now()
End Sub

Private Sub Form_Open(Cancel As Integer)
'Modifikovano: 10-09-2019
'Modifikovano: 28-08-2020 -> ako se traži iz BBQueryDefPregled onda samo otvori formu
'Modifikovano: 04-11-2020
'Modifikovano: 14-11-2020
 Rem On Error Resume Next
 On Error GoTo Err_Point
   Dim stFormName As String
   Dim stRecordSource As String
 
If CurrentUser <> "Negovan" Then
    Cancel = True
    Exit Sub
End If

On Error Resume Next
   Set AktivanObjekt = Screen.ActiveForm
   If err.Number = 0 Then
    Set aktivnaKontrola = Screen.ActiveControl
   Else
    err.Clear
    Set AktivanObjekt = Screen.ActiveReport
   End If
On Error GoTo Err_Point
   
   
   If Not (aktivnaKontrola Is Nothing) Then
      stFormName = aktivnaKontrola.Parent.Name
      'stRecordSource = Left(AktivnaKontrola.Parent.RecordSource, 64)
      stRecordSource = aktivnaKontrola.Parent.RecordSource
   ElseIf Not (AktivanObjekt Is Nothing) Then
      stFormName = AktivanObjekt.Name
      'stRecordSource = Left(AktivanObjekt.RecordSource, 64)
      stRecordSource = AktivanObjekt.RecordSource
   Else
      stFormName = ""
      stRecordSource = ""
   End If
   
   If IsNull(AktivanObjekt) Then
    DoCmd.GoToRecord , , acLast
   ElseIf (AktivanObjekt Is Nothing And aktivnaKontrola Is Nothing) Then
    DoCmd.GoToRecord , , acLast
   ElseIf AktivanObjekt.Name = "BBQueryDef_Pregled" Then
    DoCmd.GoToRecord , , acLast
   Else
    If stFormName = "BBQueryDef" Then
       GoTo Exit_Point
    End If
    ' Find the record that matches the control.
    Dim rs As Object
    Set rs = Me.Recordset.Clone
    rs.FindFirst "[AccRSFormName] = '" & stFormName & "'"
    
    If rs.NoMatch Then
      DoCmd.GoToRecord , , acNewRec
      Me!AccRSFormName.DefaultValue = "'" & stFormName & "'"
      Me!AccParFormName.DefaultValue = "'" & stFormName & "'"
      Me!AccQueryName.DefaultValue = "'" & Left(stRecordSource, 64) & "'"
      'Me!AccSQLText = AktivanObjekt.RecordSource
      Me!AccSQLText = stRecordSource '14-11-2020
    Else
      Me.Bookmark = rs.Bookmark
    End If
   End If
Exit_Point:
   err.Clear
Exit Sub
Err_Point:
 If err = 2475 Or err = 2474 Then
  Resume Next
 Else
  MsgBox "Error # " & stR(err.Number) & " was generated by " _
            & err.Source & Chr(13) & err.Description, , "QMegaTeh"
  Resume Exit_Point
  End If
End Sub

Private Sub Napomena_DblClick(Cancel As Integer)
    Dim col As Collection
    Dim ctl As control
    
    Set col = GetHeaderInputControls(Me!AccParFormName)
    Me!Napomena = ""
    For Each ctl In col
        If Me!Napomena = "" Then
            Me!Napomena = Me!Napomena & ctl.Name
        Else
            Me!Napomena = Me!Napomena & " - " & ctl.Name
        End If
    Next
    Call GetHeaderInputControls(Me!AccParFormName)
End Sub
Public Function GetHeaderInputControls(FormName As String) As Collection

    Dim col As New Collection
    Dim frm As Form
    Dim ctl As control
    
    Set frm = Forms(FormName)
    
    For Each ctl In frm.Section(acHeader).Controls
    
        Select Case ctl.ControlType
            Case acTextBox, acComboBox
                col.Add ctl
        End Select
        
    Next ctl
    
    Set GetHeaderInputControls = col

End Function
Private Sub QueryName_DblClick(Cancel As Integer)
On Error GoTo Err_Point
Dim stSQLText As String
Dim stMsg As String
If PostojiQuery(Me!QueryName) Then
   If BBPitanje("Da li želite da preracunam parametre?" & vbCrLf & "(i upišem važeci CNNString)") Then
        stSQLText = PassTroughQueryEvalAllPar(Me!QueryName, False) 'Ovde parametri dobijaju vrednosti
        PassTroughQuerySave Me!QueryName, stSQLText, F_CNNString("ODBC"), False
        DoCmd.OpenQuery Me!QueryName, acViewDesign
   Else
        DoCmd.OpenQuery Me!QueryName, acViewDesign
   End If
Else
   stMsg = "Ne postoji memorisan (ODBC) Access Query" & vbCrLf & vbCrLf & "[" & Me!QueryName & "]"
   stMsg = stMsg & vbCrLf & vbCrLf & "Da li želite da ga kreiram?" & vbCrLf & "(sa vrednostima parametara i važecim CNNString-om)"
   If BBPitanje(stMsg) Then
       stSQLText = PassTroughQueryEvalAllPar(Me!QueryName, False) 'Ovde parametri dobijaju vrednosti
       PassTroughQuerySave Me!QueryName, stSQLText, F_CNNString("ODBC"), False
       DoCmd.OpenQuery Me!QueryName, acViewDesign
   End If
End If

Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "QueryName_DblClick"
 Resume Exit_Point
End Sub

Private Sub SQLText_DblClick(Cancel As Integer)
   'EditujUpit Me!SQLText
End Sub
Private Sub DugmeAutoMap_Click()
On Error GoTo Err_DugmeAutoMap_Click

    PassTroughQueryAutoMap Me!QueryName
    Me!BBQueryParDef.Requery

Exit_DugmeAutoMap_Click:
    Exit Sub

Err_DugmeAutoMap_Click:
    MsgBox err.Description
    Resume Exit_DugmeAutoMap_Click
    
End Sub
Private Sub DugmeNoviSlog_Click()
On Error GoTo Err_DugmeNoviSlog_Click

 If Not (AktivanObjekt Is Nothing) Then
      Me!AccRSFormName.DefaultValue = "'" & AktivanObjekt.Name & "'"
      Me!AccParFormName.DefaultValue = "'" & AktivanObjekt.Name & "'"
      Me!AccQueryName.DefaultValue = "'" & AktivanObjekt.RecordSource & "'"
 End If
 
    DoCmd.GoToRecord , , acNewRec
    DoCmd.GoToControl "QueryName"

Exit_DugmeNoviSlog_Click:
    Exit Sub

Err_DugmeNoviSlog_Click:
    MsgBox err.Description
    Resume Exit_DugmeNoviSlog_Click
    
End Sub
Private Sub DugmeUzmiSaAktivneForme_Click()
On Error GoTo Err_DugmeUzmiSaAktivneForme_Click

    Me!AccRSFormName = AktivanObjekt.Name
    Me!AccParFormName = AktivanObjekt.Name
    
    If Len(AktivanObjekt.RecordSource) < 64 Then
      Me!AccQueryName = AktivanObjekt.RecordSource
    Else
      Me!AccSQLText = AktivanObjekt.RecordSource
    End If
    
Exit_DugmeUzmiSaAktivneForme_Click:
    Exit Sub

Err_DugmeUzmiSaAktivneForme_Click:
    MsgBox err.Description
    Resume Exit_DugmeUzmiSaAktivneForme_Click
    
End Sub
Private Sub DugmeLoadFromQuery_Click()
On Error GoTo Err_DugmeLoadFromQuery_Click
    Dim stQueryName As String
    
    stQueryName = Me!QueryName
    Me!SQLText = CurrentDb.QueryDefs(stQueryName).sql
    

Exit_DugmeLoadFromQuery_Click:
    Exit Sub

Err_DugmeLoadFromQuery_Click:
    MsgBox err.Description
    Resume Exit_DugmeLoadFromQuery_Click
    
End Sub
Private Sub DugmeSaveQueryToDBDef_Click()
On Error GoTo Err_DugmeSaveQueryToDBDef_Click

    Dim OK As Boolean
    
    OK = PassTroughQuerySave(Me!QueryName, Me!SQLText, F_CNNString())

Exit_DugmeSaveQueryToDBDef_Click:
    Exit Sub

Err_DugmeSaveQueryToDBDef_Click:
    MsgBox err.Description
    Resume Exit_DugmeSaveQueryToDBDef_Click
    
End Sub
Private Sub Combo30_AfterUpdate()
    ' Find the record that matches the control.
    Dim rs As Object

    Set rs = Me.Recordset.Clone
    rs.FindFirst "[QueryName] = '" & Me![Combo30] & "'"
    If Not rs.EOF Then Me.Bookmark = rs.Bookmark
     Me![Combo30] = Null
End Sub

Private Sub Combo32_AfterUpdate()
    ' Find the record that matches the control.
    Dim rs As Object

    Set rs = Me.Recordset.Clone
    rs.FindFirst "[QueryName] = '" & Me![Combo32] & "'"
    If Not rs.EOF Then Me.Bookmark = rs.Bookmark
    Me![Combo32] = Null
End Sub

Private Sub Combo34_AfterUpdate()
    ' Find the record that matches the control.
    Dim rs As Object

    Set rs = Me.Recordset.Clone
    rs.FindFirst "[QueryName] = '" & Me![Combo34] & "'"
    If Not rs.EOF Then Me.Bookmark = rs.Bookmark
End Sub

Private Sub DugmeConvertAccToODBC_Click()
On Error GoTo Err_DugmeConvertAccToODBC_Click

    Me!SQLText = ConvertAccSQLToODBC(Me!AccSQLText)
Exit_DugmeConvertAccToODBC_Click:
    Exit Sub

Err_DugmeConvertAccToODBC_Click:
    MsgBox err.Description
    Resume Exit_DugmeConvertAccToODBC_Click
    
End Sub

Private Sub DugmeEditujUpit_Click()
On Error GoTo Err_DugmeEditujUpit_Click

    Dim stDocName As String

    stDocName = Me!tmpQName
    DoCmd.OpenQuery stDocName, acViewDesign, acEdit

Exit_DugmeEditujUpit_Click:
    Exit Sub

Err_DugmeEditujUpit_Click:
    MsgBox err.Description
    Resume Exit_DugmeEditujUpit_Click
    
End Sub
Private Sub ProcitajSQLTextZaTmpQueryName()
On Error Resume Next

 If Nz(Me!TmpQueryName, "") <> "" Then
    Me!TmpSQLText = CurrentDb.QueryDefs(Me!TmpQueryName).sql
    Me!TmpSQLText.SetFocus
 End If

 If err Then
  err.Clear
  BBMsgBox_BigBit "Ne postoji upit " & Me!TmpQueryName
 End If

End Sub

Private Sub TmpQueryName_AfterUpdate()
   ProcitajSQLTextZaTmpQueryName
End Sub

Private Sub TmpQueryName_DblClick(Cancel As Integer)
   ProcitajSQLTextZaTmpQueryName
End Sub
Private Sub DugmeEvalPar_Click()
On Error GoTo Err_DugmeEvalPar_Click

    Me!SQLText = PassTroughQueryEvalAllPar(Me!QueryName, True)

Exit_DugmeEvalPar_Click:
    Exit Sub

Err_DugmeEvalPar_Click:
    MsgBox err.Description
    Resume Exit_DugmeEvalPar_Click
    
End Sub
Private Sub DugmePrepisiParametre_Click()
On Error GoTo Err_DugmePrepisiParametre_Click

    Dim stQPrepisi As String
    Dim stIzStarogQueryName As String
    Dim stUNoviQueryName As String
    
    stUNoviQueryName = Me!QueryName
    stIzStarogQueryName = Me!ComboIzQueryName
    
    stQPrepisi = "INSERT INTO BBQueryParDef ( QueryName, Name, Type, [Size], [Precision], Direction, AccMapValue, [Value], Rbr )"
    stQPrepisi = stQPrepisi & " SELECT """ & stUNoviQueryName & """ AS Expr1, BBQueryParDef.Name, BBQueryParDef.Type, BBQueryParDef.Size, BBQueryParDef.Precision, BBQueryParDef.Direction, BBQueryParDef.AccMapValue, BBQueryParDef.Value, BBQueryParDef.Rbr"
    stQPrepisi = stQPrepisi & " FROM BBQueryParDef"
    stQPrepisi = stQPrepisi & " WHERE (((BBQueryParDef.QueryName)=""" & stIzStarogQueryName & """));"
    '"ORDER BY BBQueryParDef.Rbr;"

    'DoCmd.OpenQuery stQPrepisi, acNormal, acEdit
    DoCmd.RunSQL stQPrepisi
    Me!BBQueryParDef.Requery
    
Exit_DugmePrepisiParametre_Click:
    Exit Sub

Err_DugmePrepisiParametre_Click:
    MsgBox err.Description
    Resume Exit_DugmePrepisiParametre_Click
    
End Sub
Private Sub DugmePregledSvihBBQ_Click()
On Error GoTo Err_DugmePregledSvihBBQ_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "BBQueryDef_Pregled"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmePregledSvihBBQ_Click:
    Exit Sub

Err_DugmePregledSvihBBQ_Click:
    MsgBox err.Description
    Resume Exit_DugmePregledSvihBBQ_Click
    
End Sub

